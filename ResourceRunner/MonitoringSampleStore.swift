//
//  MonitoringSampleStore.swift
//  ResourceRunner
//
//  Created by zipkero on 8/10/26.
//

import Foundation
import OSLog

#if DEBUG
/// 실기기 중지·재개 관찰에서 이력 링의 누적 개수와 고정 용량을 읽기 위한 로그 경계.
/// `Logger` 문자열 보간은 기본이 `.private`이라 명시하지 않으면 값이 가려지고, `.debug` 수준은
/// Console.app 기본 수집 대상이 아니므로 `.notice`와 `privacy: .public`을 씁니다.
enum MonitoringSampleStoreDebugLog {
    static let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "MonitoringSampleStore")
}
#endif

/// 단조 증가 시각과 값을 묶는 한 tick의 수집 결과.
/// 값 타입은 어느 격리에서도 전달할 수 있어야 하므로 `nonisolated`로 선언합니다.
nonisolated struct TimestampedSample<Value: Sendable>: Sendable {
    let timestamp: ContinuousClock.Instant
    let value: Value
}

/// 시간 범위와 수집 주기에서 양의 고정 용량을 계산하는 순수 정책.
/// 그래프 시간 범위는 `docs/product.md`가 정한 최근 10분 하나입니다.
nonisolated enum HistoryCapacity {
    /// 이력 링과 표시용 선별이 함께 쓰는 시간 범위. 사용자에게 범위 선택을 노출하지 않습니다.
    static let defaultTimeRange: Duration = .seconds(600)

    /// 이 feature가 시스템 지표에 쓸 수 있는 가장 짧은 수집 주기(normal·팝오버 열림 1초).
    /// 용량을 그때그때의 유효 주기로 재계산하면 주기가 느려지는 순간 이미 쌓인 이력이 함께 잘려 나가므로,
    /// 가장 짧은 주기 기준으로 한 번 고정하고 이후 다시 계산하지 않습니다.
    /// 주기가 느려지면 링이 덜 찰 뿐이고, 범위를 벗어난 오래된 항목은 표시 직전 선별이 걸러냅니다.
    static let shortestSamplingInterval: Duration = .seconds(1)

    /// `ceil(시간 범위 / 수집 주기)`로 고정 용량을 계산합니다.
    /// 결과는 항상 1 이상입니다.
    static func capacity(timeRange: Duration, samplingInterval: Duration) -> Int {
        let rangeSeconds = timeRange.secondsAsDouble
        let intervalSeconds = samplingInterval.secondsAsDouble
        guard intervalSeconds > 0 else { return 1 }

        let raw = (rangeSeconds / intervalSeconds).rounded(.up)
        return max(1, Int(raw))
    }
}

/// 프로젝트 기본 격리가 `MainActor`이므로 명시하지 않으면 이 계산도 `MainActor`에 묶입니다.
/// 그러면 `nonisolated`인 `HistoryCapacity.capacity`와 store actor에서 호출할 수 없어
/// Swift 6 언어 모드에서 error가 됩니다. 순수 산술이므로 격리에서 떼어냅니다.
nonisolated private extension Duration {
    var secondsAsDouble: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}

/// 고정 저장 공간·다음 쓰기 위치·현재 개수만 가지고 O(1) 추가와 교체를 하는 값 타입.
/// 용량을 넘으면 가장 오래된 항목 하나만 교체되고, 읽기는 wrap-around 전후 모두 오래된 것부터 시간순입니다.
nonisolated struct CircularBuffer<Element> {
    private var storage: [Element?]
    private var writeIndex: Int = 0
    private(set) var count: Int = 0

    let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0, "용량은 1 이상이어야 합니다.")
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    /// 새 항목을 추가합니다. 용량을 넘으면 가장 오래된 항목 하나만 교체됩니다. O(1)입니다.
    mutating func append(_ element: Element) {
        storage[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        if count < capacity {
            count += 1
        }
    }

    /// 오래된 것부터 시간순으로 정렬된 스냅샷을 반환합니다. 빈 버퍼는 빈 배열을 반환합니다.
    var elements: [Element] {
        guard count > 0 else { return [] }

        // count < capacity면 아직 wrap-around가 일어나지 않았으므로 0번째부터가 오래된 순서입니다.
        // count == capacity면 writeIndex가 가장 오래된 항목을 가리킵니다.
        let oldestIndex = count < capacity ? 0 : writeIndex
        return (0..<count).map { offset in
            storage[(oldestIndex + offset) % capacity]!
        }
    }
}

/// 이력 링에 담는 한 tick의 시계열 값.
/// CPU 최근 10분 그래프와 Swap 최근 변화량만 시계열을 요구하므로 그 둘에 필요한 스칼라만 담습니다.
/// 코어별 사용률과 Memory 세부 구성처럼 현재값만 필요한 지표는 최신 스냅샷 쪽에 남습니다.
nonisolated struct SystemMetricsHistoryPoint: Sendable, Equatable {
    let timestamp: ContinuousClock.Instant
    let overallCPUUsage: Double
    let swapUsedBytes: UInt64
}

/// 저장소가 표시 계층으로 내보내는 값. 최신 스냅샷 하나와 시간 범위 안의 이력을 함께 담습니다.
/// 가변 버퍼가 아니라 이 값 하나만 저장소 밖으로 나갑니다.
nonisolated struct SystemMetricsDisplayValue: Sendable {
    /// 마지막으로 수집된 tick. 값을 만들지 못한 tick과 실패한 tick도 그대로 담깁니다.
    let latest: TimestampedSample<SystemMetricsSample>?
    /// 최신 샘플 시각 기준 시간 범위 안의 이력만 오래된 것부터 시간순으로 담습니다.
    let recentHistory: [SystemMetricsHistoryPoint]
}

/// 시스템 지표 이력을 최신 스냅샷 하나와 고정 크기 이력 링으로 나눠 소유하는 actor.
/// 링 용량은 `HistoryCapacity.shortestSamplingInterval` 기준으로 한 번 고정되고 수집 주기가 바뀌어도 변하지 않으므로,
/// 팝오버를 닫거나 저전력 모드로 들어가 주기가 느려져도 이미 쌓인 이력이 사라지지 않습니다.
/// 밖으로 나가는 경로는 `displayValues` stream과 `snapshot()`뿐이며, 샘플과 링은 프로세스 메모리에만 존재하고
/// 재시작 복원 경로가 없습니다.
actor MonitoringSampleStore: MonitoringSampleSink {
    private let timeRange: Duration
    private var history: CircularBuffer<SystemMetricsHistoryPoint>
    private var latest: TimestampedSample<SystemMetricsSample>?

    /// 매 tick의 표시용 값을 내보내는 stream. 최신 조합 하나만 보존하므로 소비가 밀려도
    /// 오래된 조합이 쌓이지 않고 소비자는 항상 마지막 상태를 받습니다.
    nonisolated let displayValues: AsyncStream<SystemMetricsDisplayValue>

    private let continuation: AsyncStream<SystemMetricsDisplayValue>.Continuation

    init(timeRange: Duration = HistoryCapacity.defaultTimeRange) {
        self.timeRange = timeRange
        // `HistoryCapacity.capacity`가 돌려주는 개수(1초 주기에서 600)만 쓰면 항목이 정확히 그 주기로 채워질 때
        // 가장 오래된 값과 가장 최근 값 사이 구간이 `(개수 - 1) * 주기` = 599초에 그쳐 10분 창을 1초 못 미칩니다.
        // +1을 더하면 그 구간이 정확히 시간 범위와 같아져 창의 가장 오래된 끝까지 실제로 덮습니다.
        self.history = CircularBuffer(
            capacity: HistoryCapacity.capacity(
                timeRange: timeRange,
                samplingInterval: HistoryCapacity.shortestSamplingInterval
            ) + 1
        )

        var continuation: AsyncStream<SystemMetricsDisplayValue>.Continuation!
        self.displayValues = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation = $0 }
        self.continuation = continuation
    }

    /// 한 tick의 결과를 반영합니다.
    /// 최신 스냅샷은 매 tick 교체되고, 이력 링에는 전체 CPU 사용률과 Swap 값이 모두 있는 tick만 추가됩니다.
    /// 값을 만들지 못한 tick(`.success(nil)`)과 실패한 tick은 링에 들어가지 않으므로 그 시각이 이력에서 비어 있게 됩니다.
    func append(_ sample: TimestampedSample<SystemMetricsSample>) {
        latest = sample
        if let point = Self.historyPoint(from: sample) {
            history.append(point)
        }
        continuation.yield(snapshot())
#if DEBUG
        // 로그 자체는 실기기 관찰에만 필요하고 이 actor의 임계 구간에 영향을 주면 안 되므로,
        // `notice` 호출을 별도 Task로 분리합니다. 여기서 직접(동기적으로) 호출하면 로깅 시스템
        // 호출 지연이 그대로 이 actor 차례를 늦춰 `ManualMonotonicClock` 기반 타이밍 테스트의
        // 협력 스케줄링 가정을 흔들 수 있습니다.
        let status = debugStatusDescription
        Task.detached(priority: .utility) {
            MonitoringSampleStoreDebugLog.logger.notice("\(status, privacy: .public)")
        }
#endif
    }

    /// 현재 표시용 값을 반환합니다. 이력은 최신 샘플 시각 기준 시간 범위 안의 항목만 담깁니다.
    func snapshot() -> SystemMetricsDisplayValue {
        SystemMetricsDisplayValue(latest: latest, recentHistory: recentHistory())
    }

    /// 축출 기준(개수)과 표시 기준(시각)을 분리합니다.
    /// 링은 개수로만 축출하므로 중지 구간이 있으면 범위를 벗어난 오래된 항목이 남아 있을 수 있고,
    /// 그 항목을 표시로 넘기지 않으려면 최신 샘플 시각에서 시간 범위를 뺀 시점 이후만 골라야 합니다.
    /// 기준을 마지막 이력 항목이 아니라 최신 샘플 시각으로 잡아야, 오래 중지된 뒤 값 없는 tick만 들어온 상황에서도
    /// 이미 범위를 벗어난 이력이 되살아나지 않습니다.
    private func recentHistory() -> [SystemMetricsHistoryPoint] {
        guard let latest else { return [] }

        let windowStart = latest.timestamp - timeRange
        return history.elements.filter { $0.timestamp >= windowStart }
    }

    /// 전체 CPU 사용률과 Swap 값이 모두 있는 tick에서만 이력 항목을 만듭니다.
    /// 한쪽이라도 없으면 그 시각은 이력에서 비어 있어야 하므로 값을 지어내지 않고 `nil`을 돌려줍니다.
    private static func historyPoint(from sample: TimestampedSample<SystemMetricsSample>) -> SystemMetricsHistoryPoint? {
        guard case .success(let cpu) = sample.value.cpu, let cpu,
              case .success(let memory) = sample.value.memory else {
            return nil
        }

        return SystemMetricsHistoryPoint(
            timestamp: sample.timestamp,
            overallCPUUsage: cpu.overallUsage,
            swapUsedBytes: memory.swapUsedBytes
        )
    }

#if DEBUG
    /// 실기기 관찰 수단: 이력 링의 현재 개수와 고정 용량을 사람이 읽을 수 있는 문자열로 남깁니다.
    /// 주기가 바뀌어도 capacity가 그대로인지를 로그에서 바로 확인할 수 있습니다.
    var debugStatusDescription: String {
        "history=\(history.count) capacity=\(history.capacity)"
    }
#endif
}
