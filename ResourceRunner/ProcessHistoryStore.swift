//
//  ProcessHistoryStore.swift
//  ResourceRunner
//
//  Created by zipkero on 8/14/26.
//

import Foundation

/// 정체성별 CPU 누적 시간 기준점.
/// 값을 만들 수 있는지와 무관하게 매 조사마다 이번 조사 값으로 새로 갱신됩니다.
nonisolated struct ProcessCPUBaseline: Sendable, Equatable {
    let cpuTimeNanoseconds: UInt64
    let timestamp: ContinuousClock.Instant
}

/// 순위 안정화용 최근 값 하나.
/// 조사마다 채워지며, CPU 사용률은 기준점이 없거나 직전 조사와의 간격이 허용 범위를 넘으면 `nil`입니다.
nonisolated struct ProcessRankingSample: Sendable, Equatable {
    /// 논리 코어 합산 관례를 따르므로 여러 코어를 쓰는 프로세스에서 100을 넘을 수 있습니다.
    let cpuUsagePercent: Double?
    let residentBytes: UInt64
}

/// 10분 증가량 계산에 쓰는 메모리 기준점 하나.
nonisolated struct ProcessMemoryBaselinePoint: Sendable, Equatable {
    let timestamp: ContinuousClock.Instant
    let residentBytes: UInt64
}

/// 정체성 하나가 보관하는 이력 전체.
/// `ProcessHistoryStore` 밖으로는 `ProcessHistorySnapshot`으로만 노출됩니다.
private struct ProcessHistoryEntry {
    var executablePath: String
    /// 매 조사마다 이번 조사 값으로 갱신됩니다. `executablePath`와 같은 이유로 정체성이 아니라
    /// 관찰마다 새로 반영되는 값입니다 — 실행 파일 자체가 바뀌는 일은 없지만 갱신 방식을 통일해 둡니다.
    var isTranslated: Bool
    var cpuBaseline: ProcessCPUBaseline?
    var recentValues: CircularBuffer<ProcessRankingSample>
    var memoryBaselines: CircularBuffer<ProcessMemoryBaselinePoint>
}

/// `ProcessHistoryStore`가 밖으로 내보내는 정체성 하나의 현재 이력.
/// TOP 5 순위 계산(task-006)과 테스트가 이 값을 읽습니다.
nonisolated struct ProcessHistorySnapshot: Sendable, Equatable {
    let identity: ProcessIdentity
    /// 앱 키·표시 이름 유도(task-006 `ApplicationIdentityResolver`)에 쓰는 실행 경로.
    let executablePath: String
    /// 순위 안정화용 최근 값들. 오래된 것부터 시간순이며 최대 3개입니다.
    let recentValues: [ProcessRankingSample]
    /// 10분 증가량 계산용 메모리 기준점들. 오래된 것부터 시간순입니다.
    let memoryBaselines: [ProcessMemoryBaselinePoint]
    /// `P_TRANSLATED` 플래그로 판정한 Rosetta 실행 여부. 상세 영역의 프로세스별 표시(task-010)가 씁니다.
    /// 기본값 `false`로 두어 이 필드가 없던 시절 만들어진 테스트 리터럴이 계속 컴파일되도록 합니다 —
    /// 기본값이 합성 memberwise 초기화 매개변수에 반영되려면 `var`여야 하므로 `var`로 선언합니다.
    /// 실제 값은 `ProcessHistoryStore.append(_:)`가 매 조사마다 채웁니다.
    var isTranslated: Bool = false
}

/// 프로세스 조사 tick 사이 간격 판정 기준과 메모리 기준점 링 정책.
nonisolated enum ProcessHistorySampling {
    /// 직전 조사와의 간격이 이 값을 넘으면 CPU 누적 시간을 차분하지 않고 기준점만 갱신합니다.
    /// 이 feature가 프로세스 조사에 쓰는 가장 느린 주기(lowPower·팝오버 닫힘 10초)의 두 배이므로,
    /// 정상 주기의 지연은 값을 버리지 않고 중지·재개나 장시간 지연만 걸러집니다.
    static let maximumTickGap: Duration = .seconds(20)

    /// 순위 안정화에 쓰는 최근 값 링의 고정 크기.
    static let recentValueCount = 3

    /// 10분 증가량 계산이 커버해야 하는 시간 범위.
    static let memoryBaselineWindow: Duration = .seconds(600)

    /// 메모리 기준점 사이 최소 간격.
    /// 조사 주기가 2초든 10초든 이 간격보다 촘촘하면 기준점을 추가하지 않으므로,
    /// 이력 크기가 조사 주기와 무관하게 고정됩니다. 대가는 10분 증가량 기준점 시각이 이 간격만큼 어긋날 수 있다는 것입니다.
    static let minimumMemoryBaselineInterval: Duration = .seconds(30)

    /// `ceil(10분 / 최소 간격)`에 1을 더한 메모리 기준점 링 용량.
    /// `HistoryCapacity.capacity`가 돌려주는 개수(20)만 쓰면 기준점이 정확히 최소 간격으로 채워질 때
    /// 가장 오래된 값과 가장 최근 값 사이 구간이 `(개수 - 1) * 최소 간격` = 570초로 10분(600초)에 30초 못 미쳐,
    /// 10분 창의 가장 오래된 기준점이 실제로는 570초 전 것까지만 확보됩니다.
    /// +1을 더하면 그 구간이 정확히 600초가 되어 창 경계에서 값을 지어내지 않고도 10분을 온전히 덮습니다.
    static let memoryBaselineRingCapacity = HistoryCapacity.capacity(
        timeRange: memoryBaselineWindow,
        samplingInterval: minimumMemoryBaselineInterval
    ) + 1
}

/// 정체성별 CPU 누적 시간·순위 안정화 이력·메모리 기준점을 보관하는 actor.
/// 매 조사에서 관찰되지 않은 정체성은 그 자리에서 제거하므로, 종료되거나 접근에 실패해
/// `ProcessSurveyReport.samples`에서 빠진 프로세스는 다음 조사에서 이력이 사라집니다.
/// 정체성 키가 PID와 시작 시각의 쌍이라 PID가 재사용돼도 새 정체성이 되어 이전 이력을 이어받지 않습니다. SPEC §5.7을 담당합니다.
actor ProcessHistoryStore: MonitoringSampleSink {
    private var entries: [ProcessIdentity: ProcessHistoryEntry] = [:]
    /// 마지막 조사에서 읽지 못한 프로세스 수.
    /// 순위 계산 입력의 일부이므로 정체성별 이력과 같은 시점의 값으로 함께 나가야 합니다.
    private var latestUnreadableCount = 0
    /// 마지막 조사가 실패했는지. 다음 성공 조사까지 유지됩니다.
    /// 시스템 지표 축이 더 빠르게 tick하며 순위를 다시 읽어 가므로, 이 값을 조사 축에서만 바꿔야
    /// 실패 표시가 tick마다 켜졌다 꺼지지 않습니다.
    private var latestSurveyFailed = false

    /// 한 번의 조사 결과를 반영합니다.
    /// 이번 조사에서 관찰된 정체성만 남기고 나머지는 이 호출에서 바로 제거됩니다.
    ///
    /// 실패한 조사는 이력을 전혀 건드리지 않고 실패 사실만 기록합니다.
    /// 관찰된 정체성이 없는 것으로 처리하면 아래 제거 단계가 이력 전체를 지워
    /// 조사 한 번 실패에 그동안 쌓은 CPU 기준점과 메모리 기준점이 모두 사라집니다.
    func append(_ sample: TimestampedSample<ProcessSurveySample>) {
        let timestamp = sample.timestamp

        guard case .success(let report) = sample.value.result else {
            latestSurveyFailed = true
            return
        }

        latestSurveyFailed = false
        latestUnreadableCount = report.unreadableCount
        var observed: Set<ProcessIdentity> = []
        observed.reserveCapacity(report.samples.count)

        for process in report.samples {
            observed.insert(process.identity)

            var entry = entries[process.identity] ?? ProcessHistoryEntry(
                executablePath: process.executablePath,
                isTranslated: process.isTranslated,
                cpuBaseline: nil,
                recentValues: CircularBuffer(capacity: ProcessHistorySampling.recentValueCount),
                memoryBaselines: CircularBuffer(capacity: ProcessHistorySampling.memoryBaselineRingCapacity)
            )
            entry.executablePath = process.executablePath
            entry.isTranslated = process.isTranslated

            let cpuUsagePercent = Self.cpuUsagePercent(process: process, timestamp: timestamp, entry: &entry)
            entry.recentValues.append(ProcessRankingSample(cpuUsagePercent: cpuUsagePercent, residentBytes: process.residentBytes))
            Self.appendMemoryBaselineIfNeeded(process: process, timestamp: timestamp, entry: &entry)

            entries[process.identity] = entry
        }

        // 이번 조사에서 관찰되지 않은 정체성은 이미 사라진 프로세스이므로 이력에서 바로 지웁니다.
        entries = entries.filter { observed.contains($0.key) }
    }

    /// 현재 보관 중인 정체성 전체의 스냅샷. 순서는 보장하지 않습니다.
    func snapshot() -> [ProcessHistorySnapshot] {
        entries.map { identity, entry in
            ProcessHistorySnapshot(
                identity: identity,
                executablePath: entry.executablePath,
                recentValues: entry.recentValues.elements,
                memoryBaselines: entry.memoryBaselines.elements,
                isTranslated: entry.isTranslated
            )
        }
    }

    /// 앱 단위 순위 계산(`ApplicationRanking`)이 한 번에 필요로 하는 입력 묶음.
    /// 정체성별 이력과 읽지 못한 프로세스 수를 따로 읽으면 두 번의 actor 진입 사이에 조사가 끼어들어
    /// 서로 다른 조사의 값이 섞일 수 있으므로 한 번의 호출로 함께 내보냅니다.
    /// 마지막 조사의 실패 여부도 같은 이유로 함께 나갑니다.
    func rankingInput() -> (snapshots: [ProcessHistorySnapshot], unreadableCount: Int, surveyFailed: Bool) {
        (snapshot(), latestUnreadableCount, latestSurveyFailed)
    }

    /// 관찰 중인 정체성 수. 종료된 프로세스 제거를 사전 크기로 단언하는 테스트가 씁니다.
    var identityCount: Int { entries.count }

    /// 직전 누적 CPU 시간과의 차이를 경과 시간으로 나눈 코어 합산 사용률.
    /// 기준점은 값을 만들 수 있는지와 무관하게 항상 이번 조사 값으로 갱신됩니다.
    private static func cpuUsagePercent(
        process: ProcessSample,
        timestamp: ContinuousClock.Instant,
        entry: inout ProcessHistoryEntry
    ) -> Double? {
        let previous = entry.cpuBaseline
        entry.cpuBaseline = ProcessCPUBaseline(cpuTimeNanoseconds: process.cpuTimeNanoseconds, timestamp: timestamp)

        guard let previous else { return nil }

        // 중지·재개나 장시간 지연 구간을 하나의 변화량으로 이어 붙이지 않습니다.
        let elapsed = previous.timestamp.duration(to: timestamp)
        guard elapsed > .zero, elapsed <= ProcessHistorySampling.maximumTickGap else { return nil }

        // 누적 시간이 줄었다면 카운터가 되감긴 것이므로 차분이 의미를 잃어 기준점 갱신으로만 끝냅니다.
        guard process.cpuTimeNanoseconds >= previous.cpuTimeNanoseconds else { return nil }

        let cpuDeltaNanoseconds = process.cpuTimeNanoseconds - previous.cpuTimeNanoseconds
        let elapsedNanoseconds = elapsed.nanosecondsAsDouble
        guard elapsedNanoseconds > 0 else { return nil }

        // 논리 코어 합산 관례를 그대로 따르므로 100을 넘는 값을 자르지 않습니다.
        return Double(cpuDeltaNanoseconds) / elapsedNanoseconds * 100
    }

    /// 최소 간격보다 촘촘한 조사에서는 기준점을 추가하지 않아 링 크기가 조사 주기와 무관하게 유지됩니다.
    private static func appendMemoryBaselineIfNeeded(
        process: ProcessSample,
        timestamp: ContinuousClock.Instant,
        entry: inout ProcessHistoryEntry
    ) {
        if let last = entry.memoryBaselines.elements.last {
            let sinceLast = last.timestamp.duration(to: timestamp)
            guard sinceLast >= ProcessHistorySampling.minimumMemoryBaselineInterval else { return }
        }
        entry.memoryBaselines.append(ProcessMemoryBaselinePoint(timestamp: timestamp, residentBytes: process.residentBytes))
    }
}

/// 프로젝트 기본 격리가 `MainActor`이므로 명시하지 않으면 이 계산도 `MainActor`에 묶여
/// actor 격리 안의 `nonisolated` 정적 함수에서 호출할 수 없습니다. 순수 산술이므로 격리에서 떼어냅니다.
nonisolated private extension Duration {
    var nanosecondsAsDouble: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) * 1e9 + Double(attoseconds) / 1e9
    }
}
