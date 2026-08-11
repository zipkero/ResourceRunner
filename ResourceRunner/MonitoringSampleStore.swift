//
//  MonitoringSampleStore.swift
//  ResourceRunner
//
//  Created by zipkero on 8/10/26.
//

import Foundation
import OSLog

#if DEBUG
/// `MonitoringSampleStore`가 제네릭 actor라 정적 저장 속성을 직접 가질 수 없으므로 분리해 둡니다.
/// task-011 관찰 수단(누적 샘플 수·버퍼 용량)이며 task-010의 실제 잠금·해제 관찰에서도 재사용합니다.
/// `Logger` 문자열 보간은 기본이 `.private`이라 명시하지 않으면 값이 가려지고, `.debug` 수준은
/// Console.app 기본 수집 대상이 아니므로 `.notice`와 `privacy: .public`을 씁니다.
enum MonitoringSampleStoreDebugLog {
    static let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "MonitoringSampleStore")
}
#endif

/// 단조 증가 시각과 값을 묶는 M1 최근 샘플.
/// 값 타입은 어느 격리에서도 전달할 수 있어야 하므로 `nonisolated`로 선언합니다.
nonisolated struct TimestampedSample<Value: Sendable>: Sendable {
    let timestamp: ContinuousClock.Instant
    let value: Value
}

/// 시간 범위와 유효 수집 주기에서 양의 고정 용량을 계산하는 순수 정책.
/// M1의 그래프 시간 범위는 `docs/product.md`가 정한 최근 10분을 기본값으로 둡니다.
nonisolated enum HistoryCapacity {
    /// M1 기본 시간 범위. 범위 변경은 저장소 API로만 노출하고 UI로는 노출하지 않습니다.
    static let defaultTimeRange: Duration = .seconds(600)

    /// `ceil(시간 범위 / 유효 수집 주기)`로 고정 용량을 계산합니다.
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

    /// 새 용량으로 재구성합니다. 축소는 최신 항목만 보존하고, 확대는 새 공간을 채우지 않습니다.
    func resized(to newCapacity: Int) -> CircularBuffer<Element> {
        precondition(newCapacity > 0, "용량은 1 이상이어야 합니다.")

        var newBuffer = CircularBuffer<Element>(capacity: newCapacity)
        let current = elements
        let preserved = current.suffix(newCapacity)
        for element in preserved {
            newBuffer.append(element)
        }
        return newBuffer
    }
}

/// 최근 샘플 순환 버퍼만 변경하는 actor.
/// append·시간순 snapshot·resize만 수행하고 가변 버퍼 참조를 밖으로 내보내지 않습니다.
/// 샘플과 버퍼는 프로세스 메모리에만 존재하며 재시작 복원 경로가 없습니다.
actor MonitoringSampleStore<Value: Sendable> {
    private var buffer: CircularBuffer<TimestampedSample<Value>>
    private var timeRange: Duration

    init(timeRange: Duration = HistoryCapacity.defaultTimeRange, samplingInterval: Duration) {
        self.timeRange = timeRange
        let capacity = HistoryCapacity.capacity(timeRange: timeRange, samplingInterval: samplingInterval)
        self.buffer = CircularBuffer(capacity: capacity)
    }

    /// 새 샘플을 추가합니다. 첫 샘플은 그대로 현재 데이터가 됩니다.
    func append(_ sample: TimestampedSample<Value>) {
        buffer.append(sample)
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

    /// 오래된 것부터 시간순으로 정렬된 불변 스냅샷을 반환합니다.
    func snapshot() -> [TimestampedSample<Value>] {
        buffer.elements
    }

    /// 새 유효 수집 주기로 용량을 재계산해 버퍼를 재구성합니다. 최신 항목만 보존합니다.
    /// 시간 범위 변경도 이 API로만 노출합니다.
    func resize(samplingInterval: Duration, timeRange: Duration? = nil) {
        if let timeRange {
            self.timeRange = timeRange
        }
        let capacity = HistoryCapacity.capacity(timeRange: self.timeRange, samplingInterval: samplingInterval)
        buffer = buffer.resized(to: capacity)
    }

#if DEBUG
    /// task-011 관찰 수단: 누적 샘플 수와 현재 버퍼 용량을 사람이 읽을 수 있는 문자열로 남깁니다.
    /// `MonitoringScheduler`의 실기기 관찰 로그와 task-010의 잠금·해제 관찰에서 재사용합니다.
    var debugStatusDescription: String {
        "count=\(buffer.count) capacity=\(buffer.capacity)"
    }
#endif
}
