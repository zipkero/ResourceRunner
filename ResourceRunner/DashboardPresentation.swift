//
//  DashboardPresentation.swift
//  ResourceRunner
//
//  Created by zipkero on 8/15/26.
//

import Foundation

/// 그래프 한 점. 인접 점의 시각 간격으로 빈 구간을 판별합니다.
nonisolated struct HistoryPoint: Sendable, Equatable {
    let timestamp: ContinuousClock.Instant
    let value: Double
}

extension HistoryPoint {
    /// 인접한 두 점 사이 간격이 이 값을 넘으면 하나의 선분으로 잇지 않습니다.
    /// CPU Collector가 tick 차분을 포기하는 간격(`SystemMetricsSampling.maximumTickGap`)과 같은 기준을 재사용합니다 —
    /// 그보다 벌어진 두 그래프 점 사이에는 실제로 수집되지 않은 시간이 있다는 뜻이기 때문입니다.
    static let maximumConnectedGap = SystemMetricsSampling.maximumTickGap

    /// 점 목록을 인접 간격으로 나눠 하나의 선으로 이어 그릴 수 있는 연속 구간들로 만듭니다.
    /// 간격이 `maximumConnectedGap`을 넘는 두 점은 서로 다른 구간에 들어가 그 사이가 그래프에서 비어 보입니다.
    /// 빈 입력은 빈 결과를, 점 하나짜리 입력은 그 점 하나만 담은 구간 하나를 돌려줍니다.
    static func connectedSegments(from points: [HistoryPoint]) -> [[HistoryPoint]] {
        guard let first = points.first else { return [] }

        var segments: [[HistoryPoint]] = [[first]]
        for point in points.dropFirst() {
            let lastSegmentIndex = segments.count - 1
            let previous = segments[lastSegmentIndex][segments[lastSegmentIndex].count - 1]
            if previous.timestamp.duration(to: point.timestamp) > maximumConnectedGap {
                segments.append([point])
            } else {
                segments[lastSegmentIndex].append(point)
            }
        }
        return segments
    }
}

/// 실패·중지 상태가 함께 보여주는 마지막 성공 값. 한 번도 성공한 적이 없으면 이 자체가 `nil`이 되어,
/// "성공 이력이 없는 상태에서의 실패·중지"가 `collecting`과 구분되게 표현됩니다(task-011, ANALYSIS §2 「실패 경로」).
nonisolated struct LastKnownCardValue<Presentation: Sendable & Equatable>: Sendable, Equatable {
    let presentation: Presentation
    let timestamp: ContinuousClock.Instant
}

/// 카드 표시 상태. ANALYSIS §3의 계약대로 수집 중·정상·실패·중지 네 경우를 담습니다.
/// `failure`와 `stopped`는 마지막 성공 값을 함께 들고 있어, 실패·중지 tick 뒤에도 카드가 0이나 빈 값으로
/// 바뀌지 않고 복귀 직후에도 빈 화면이 되지 않습니다(task-011).
nonisolated enum ResourceCardState<Presentation: Sendable & Equatable>: Sendable, Equatable {
    /// 앱 시작 직후 아직 유효한 값이 없는 상태.
    case collecting
    /// 마지막으로 성립한 표시 값과 그 시각.
    case normal(Presentation, timestamp: ContinuousClock.Instant)
    /// 이 카드의 지표(또는 프로세스 조사) 수집이 실패한 상태. 마지막 성공 값이 있으면 그대로 들고,
    /// 성공 이력이 없으면 `nil`입니다.
    case failure(lastKnown: LastKnownCardValue<Presentation>?)
    /// 화면을 볼 수 없어 일정이 멈춘 상태. 수집 결과가 아니라 생명주기 경계가 알리는 전이로만 도달합니다
    /// (ANALYSIS §1 「생명주기 경계」, §5 DP16). 마지막 성공 값이 있으면 그대로 들고, 없으면 `nil`입니다.
    case stopped(lastKnown: LastKnownCardValue<Presentation>?)
}

extension ResourceCardState {
    /// 이 상태에서 다음 실패·중지 전이가 이어받을 마지막 성공 값.
    /// `normal`은 그 값 자체를, `failure`·`stopped`는 이미 들고 있던 값을 그대로 물려주고, `collecting`은 없습니다.
    var lastKnownValue: LastKnownCardValue<Presentation>? {
        switch self {
        case .collecting:
            return nil
        case .normal(let presentation, let timestamp):
            return LastKnownCardValue(presentation: presentation, timestamp: timestamp)
        case .failure(let lastKnown), .stopped(let lastKnown):
            return lastKnown
        }
    }
}

/// 어느 카드의 상세 팝업이 카드 옆에 열려 있는지. 도달 가능한 값은 선택 없음·CPU·Memory 셋뿐입니다(ANALYSIS §2 「팝오버 열림과 카드 선택」).
/// 전이는 `DashboardPresentationStore.selectCard(_:)`(카드 활성화)와 `dismissDetail(for:)`(팝업 자신의 닫힘) 둘로만 일어나고,
/// 수집 갱신이나 수집 실패는 이 값을 바꾸지 않습니다(SPEC §5.2).
nonisolated enum DashboardSelection: Sendable, Equatable {
    case none
    case cpu
    case memory
}

/// CPU 카드 표시 값. 전체 사용률, User·System 비율, 최근 10분 그래프 점, 앱 단위 CPU TOP 5를 담습니다.
nonisolated struct CPUCardPresentation: Sendable, Equatable {
    let overallUsage: Double
    let userRatio: Double
    let systemRatio: Double
    /// 표시 직전 10분 창 안으로 골라진 그래프 점. 오래된 것부터 시간순입니다.
    let graphPoints: [HistoryPoint]
    /// 앱 단위 CPU 사용량 TOP 5. 5개보다 많이 들어오면 상위 5개로 자릅니다.
    let topApplications: [ApplicationRankingEntry]
    /// 이 tick의 프로세스 조사가 실패했는지. 실패해도 시스템 지표 수치(전체 사용률 등)는 그대로 표시되고
    /// TOP 5만 실패를 나타냅니다(task-011, ANALYSIS §2 「실패 경로」).
    let topApplicationsFailed: Bool
    /// 카드를 선택했을 때만 쓰이는 상세 지표(task-010, SPEC §5.2).
    let detail: CPUCardDetail
}

/// CPU 상세 영역 전용 값. 기본 카드가 요약(전체 사용률·User·System)만 보여주는 반면
/// 상세는 Idle, 논리 코어별 사용률, Load Average, 앱별 하위 프로세스까지 함께 보여줍니다.
nonisolated struct CPUCardDetail: Sendable, Equatable {
    let idleRatio: Double
    /// 개수는 `host_processor_info`가 보고한 논리 코어 수와 같습니다(SPEC §5.2).
    let coreUsages: [Double]
    let loadAverage: LoadAverage
    /// 앱 단위로 묶은 하위 프로세스 목록. 앱 항목을 펼치면 이 목록이 나타납니다(ANALYSIS §2 「팝오버 열림과 카드 선택」).
    let applications: [ApplicationProcessGroup]
}

extension CPUCardPresentation {
    /// TOP 5 목록에 시스템 프로세스가 포함되지 않는다는 상시 안내.
    /// Hover나 색상이 아니라 항상 보이는 문구이며 카드 접근성 이름에도 포함됩니다.
    static let topApplicationsCaption = "시스템 프로세스는 TOP 5에 포함되지 않습니다"

    /// 시스템 전체 CPU 사용률의 단위 라벨. 코어별 tick 합에서 계산하므로 항상 0~100% 범위이고,
    /// 여러 코어를 합산해 100%를 넘을 수 있는 프로세스 사용률의 단위(`ApplicationProcessDetail.cpuUsageUnitLabel`)와
    /// 화면에서 구분되어야 합니다(SPEC §5.2, SPEC §5.3).
    static let overallUsageUnitLabel = "%"

    /// CPU 카드를 선택·복귀하는 키보드 단축키의 실제 키.
    /// macOS 키보드 탐색(Full Keyboard Access)이 기본값(꺼짐)인 환경에서는 Tab이 표준 `Button`에 닿지 않으므로
    /// 이 단축키가 SPEC §5.13이 요구하는 키보드 수단입니다(ANALYSIS §5 DP15).
    /// `DashboardView`의 `KeyEquivalent` 등록이 이 값에서 유도되어 키 정의가 한 자리로 유지됩니다.
    static let selectionShortcutKey: Character = "1"

    /// CPU 카드를 선택·복귀하는 키보드 단축키의 사람이 읽는 표시. `selectionShortcutKey`에서 유도되어
    /// 키를 바꾸면 표시도 함께 바뀝니다.
    /// 카드에 항상 보이는 표시와 카드 접근성 이름이 이 문자열을 함께 써서 단축키의 존재를 알립니다.
    static var selectionShortcutDisplayText: String { "⌘\(selectionShortcutKey)" }

    /// 최신 시스템 지표, 이력 링, 앱 순위에서 CPU 카드 표시 값을 만듭니다.
    /// - Parameters:
    ///   - history: 시간 창으로는 아직 거르지 않은 이력 값들(예: `MonitoringSampleStore`의 이력 링 전체).
    ///     여기서 `currentTimestamp` 기준 10분 창으로 다시 거릅니다.
    ///   - topApplications: 앱 단위 CPU 사용량 순위. 5개보다 많아도 이 함수가 상위 5개로 자릅니다.
    ///   - processGroups: 상세의 앱별 하위 프로세스 목록(`ApplicationRanking.groupByApplication(_:)`이 만듭니다).
    ///     프로세스 조사 축이 아직 production 코디네이터에 연결되지 않은 동안은 빈 배열이 그대로 전달됩니다.
    ///   - currentTimestamp: 그래프를 그리는 시점의 시각. 가로축 오른쪽 끝이 이 값이 되므로,
    ///     최신 샘플이 오래된 상황에서도 빈 구간이 오른쪽 끝에 붙어 보입니다(ANALYSIS §5 DP3).
    static func assemble(
        cpu: CPUSystemMetrics,
        history: [SystemMetricsHistoryPoint],
        topApplications: [ApplicationRankingEntry],
        topApplicationsFailed: Bool = false,
        processGroups: [ApplicationProcessGroup] = [],
        currentTimestamp: ContinuousClock.Instant
    ) -> CPUCardPresentation {
        let windowStart = currentTimestamp - HistoryCapacity.defaultTimeRange
        let graphPoints = history
            .filter { $0.timestamp >= windowStart }
            .map { HistoryPoint(timestamp: $0.timestamp, value: $0.overallCPUUsage) }

        return CPUCardPresentation(
            overallUsage: cpu.overallUsage,
            userRatio: cpu.userRatio,
            systemRatio: cpu.systemRatio,
            graphPoints: graphPoints,
            topApplications: Array(topApplications.prefix(ApplicationRankingSampling.topCount)),
            topApplicationsFailed: topApplicationsFailed,
            detail: CPUCardDetail(
                idleRatio: cpu.idleRatio,
                coreUsages: cpu.coreUsages,
                loadAverage: cpu.loadAverage,
                applications: ApplicationRanking.sortedForDisplay(groups: processGroups, by: .cpuUsage)
            )
        )
    }
}

/// 프로젝트 기본 격리가 `MainActor`이므로 명시하지 않으면 이 계산도 `MainActor`에 묶여
/// `nonisolated` 계산 맥락에서 자유롭게 쓰기 어려워집니다. 순수 산술이므로 격리에서 떼어냅니다.
nonisolated private extension Duration {
    var secondsAsDouble: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}

extension HistoryPoint {
    /// 다운샘플링 버킷 사이 최소 픽셀 간격.
    /// `HistoryGraphView`의 선 두께(1.0pt)보다 확실히 커야, 인접 버킷이 그리는 선분이 두께에 묻혀
    /// 뭉개지지 않습니다(10분 창을 601개 점까지 담는 이력 링을 폭 248pt 팝오버에 그릴 때의 실측 결함 수정).
    /// 버킷마다 min·max 최대 2점이 남으므로 평균 간격은 이 값의 절반(예: 248pt·62버킷이면 2pt)입니다.
    static let minimumDownsampledBucketSpacing: Double = 4

    /// 렌더 폭에서 다운샘플링 버킷 수를 계산합니다.
    /// 버킷 하나의 폭이 `minimumDownsampledBucketSpacing` 이상이 되도록 폭을 그 값으로 나누며, 버킷은 항상 1개 이상입니다.
    ///
    /// `width`가 유한하지 않거나(`NaN`·`infinite`) 0 이하면 `Int(width / ...)`가 트랩하거나 의미 없는 값을
    /// 만들 수 있으므로, 그런 입력은 버킷 1개로 안전하게 처리합니다.
    static func downsampledBucketCount(forRenderWidth width: Double) -> Int {
        guard width.isFinite, width > 0 else { return 1 }
        return max(1, Int(width / minimumDownsampledBucketSpacing))
    }

    /// 하나의 연속 구간 안에서 점을 `bucketCount`개의 버킷으로 나눠 각 버킷의 최솟값·최댓값을 실제 시각 순서로
    /// 남깁니다(같으면 하나만). 평균이 아니라 min·max를 남기는 이유는 순간 피크가 CPU 모니터에서 핵심 정보이기 때문입니다.
    ///
    /// 이웃 버킷과의 간격을 이유로 후보를 건너뛰지 않습니다 — 건너뛰면 그 표본이 결과에서 통째로 사라져
    /// 스파이크·dip 같은 순간 극값이 흔적 없이 지워지기 때문입니다(그리디 최소 간격 필터로 인한 결함 수정).
    /// 같은 버킷의 min·max나 인접 버킷 경계에 걸친 두 점이 원본 표본 간격까지 붙어 세로 스트로크처럼 보이는 것은
    /// 급변 구간을 정확히 표현하는 것이라 허용합니다.
    /// 빈 버킷은 결과에서 그냥 빠집니다. 점 수가 `bucketCount` 이하면 잃는 것 없이 그대로 돌려줍니다.
    static func downsampled(segment: [HistoryPoint], bucketCount: Int) -> [HistoryPoint] {
        guard bucketCount > 0, segment.count > bucketCount else { return segment }

        let bucketSize = Double(segment.count) / Double(bucketCount)

        var result: [HistoryPoint] = []
        var start = 0
        for bucketIndex in 1...bucketCount {
            let end = bucketIndex == bucketCount
                ? segment.count
                : Int((Double(bucketIndex) * bucketSize).rounded())
            defer { start = end }
            guard start < end else { continue }

            let bucket = segment[start..<end]
            guard let minIndex = bucket.indices.min(by: { segment[$0].value < segment[$1].value }),
                  let maxIndex = bucket.indices.max(by: { segment[$0].value < segment[$1].value }) else { continue }

            if segment[minIndex].value == segment[maxIndex].value {
                result.append(segment[minIndex])
            } else if minIndex < maxIndex {
                result.append(segment[minIndex])
                result.append(segment[maxIndex])
            } else {
                result.append(segment[maxIndex])
                result.append(segment[minIndex])
            }
        }
        return result
    }

    /// 그래프로 그릴 연속 구간을 만들고, 각 구간 안에서만 다운샘플링합니다.
    ///
    /// 반드시 `connectedSegments`로 먼저 나눈 뒤 구간별로 다운샘플링해야 합니다. 순서를 반대로 해서
    /// 전체 점을 하나로 보고 먼저 버킷을 묶으면, 중지·재개로 갈라진 두 구간의 점이 한 버킷에 섞여 들어가
    /// 값 범위가 좁은 쪽 구간이 통째로 버킷 결과에서 밀려날 수 있습니다(min·max가 모두 다른 구간에서 뽑히는 경우) —
    /// 그러면 중지 구간이 사라지거나(구간 하나로 합쳐짐) 없던 구간이 생기는 것과 같은 잘못된 결과가 됩니다.
    static func downsampledConnectedSegments(from points: [HistoryPoint], bucketCount: Int) -> [[HistoryPoint]] {
        connectedSegments(from: points).map { downsampled(segment: $0, bucketCount: bucketCount) }
    }
}

extension HistoryPoint {
    /// 그래프 점의 가로축 좌표를 `currentTimestamp`(그리는 시점의 시각) 기준 10분 창 안에서 0...1로 계산합니다.
    /// 0이 창의 왼쪽 끝(`currentTimestamp - timeRange`), 1이 창의 오른쪽 끝(`currentTimestamp`)입니다.
    ///
    /// 창 끝을 점 자신의 시각이 아니라 항상 `currentTimestamp`로 고정해야,
    /// 마지막 샘플이 오래된 상황(중지 뒤 재개 첫 tick이 값을 만들지 못해 카드가 갱신되지 않는 경우 등)에서도
    /// 그 점이 오른쪽 끝에 들러붙지 않고 실제 경과 시간만큼 왼쪽으로 밀려나, 오른쪽에 빈 구간이 제자리에 보입니다
    /// (ANALYSIS §5 DP3, task-008 검증 조건).
    static func normalizedXPosition(
        for timestamp: ContinuousClock.Instant,
        currentTimestamp: ContinuousClock.Instant,
        timeRange: Duration = HistoryCapacity.defaultTimeRange
    ) -> Double {
        let windowStart = currentTimestamp - timeRange
        let total = windowStart.duration(to: currentTimestamp).secondsAsDouble
        guard total > 0 else { return 1 }

        let elapsed = windowStart.duration(to: timestamp).secondsAsDouble
        return elapsed / total
    }
}

extension ResourceCardState where Presentation == CPUCardPresentation {
    /// CPU 카드의 접근성 이름. 현재 사용률과 카드 상태, TOP 5 안내 문구, 선택·복귀 단축키를 포함합니다.
    var cpuAccessibilityLabel: String {
        let shortcut = "단축키 \(CPUCardPresentation.selectionShortcutDisplayText)"
        switch self {
        case .collecting:
            return "CPU 카드, 수집 중, \(shortcut)"
        case .normal(let presentation, _):
            let overall = Int(presentation.overallUsage.rounded())
            let user = Int(presentation.userRatio.rounded())
            let system = Int(presentation.systemRatio.rounded())
            return "CPU 카드, 전체 사용률 \(overall)%, User \(user)%, System \(system)%, "
                + CPUCardPresentation.topApplicationsCaption
                + ", \(shortcut)"
        case .failure(let lastKnown):
            guard let lastKnown else {
                return "CPU 카드, 수집 실패, \(shortcut)"
            }
            let overall = Int(lastKnown.presentation.overallUsage.rounded())
            return "CPU 카드, 수집 실패, 마지막 전체 사용률 \(overall)%, \(shortcut)"
        case .stopped(let lastKnown):
            guard let lastKnown else {
                return "CPU 카드, 수집 중지, \(shortcut)"
            }
            let overall = Int(lastKnown.presentation.overallUsage.rounded())
            return "CPU 카드, 수집 중지, 마지막 전체 사용률 \(overall)%, \(shortcut)"
        }
    }
}

/// Memory Pressure 한 단계의 표시 값. 색상을 지워도 라벨과 기호 형태만으로 세 단계가 구분되게 합니다(SPEC §5.5).
nonisolated struct MemoryPressureDisplay: Sendable, Equatable {
    let label: String
    /// SF Symbol 식별자. 세 단계가 서로 다른 형태(원·삼각형·팔각형)를 가져 색상 없이도 구분됩니다.
    let symbolName: String
}

extension MemoryPressureLevel {
    /// 단계별 라벨과 기호. 정상으로 돌아오면 이 값 자체가 정상 표시로 그대로 되돌아옵니다.
    var display: MemoryPressureDisplay {
        switch self {
        case .normal:
            return MemoryPressureDisplay(label: "정상", symbolName: "checkmark.circle")
        case .warning:
            return MemoryPressureDisplay(label: "경고", symbolName: "exclamationmark.triangle")
        case .critical:
            return MemoryPressureDisplay(label: "위험", symbolName: "xmark.octagon")
        }
    }
}

/// Memory 카드 표시 값. 전체 물리 메모리, 사용 중 메모리, Pressure 단계, Swap 사용량과 최근 변화량,
/// 앱 단위 Memory TOP 5를 담습니다.
nonisolated struct MemoryCardPresentation: Sendable, Equatable {
    let totalPhysicalBytes: UInt64
    let usedBytes: UInt64
    let pressureDisplay: MemoryPressureDisplay
    let swapUsedBytes: UInt64
    /// 10분 창 안 가장 오래된 값과 현재값의 차이. 창 안에 현재값보다 앞선 값이 하나도 없으면 `nil`입니다.
    let swapRecentChangeBytes: Int64?
    /// 앱 단위 메모리 사용량 TOP 5. 5개보다 많이 들어오면 상위 5개로 자릅니다.
    let topApplications: [ApplicationRankingEntry]
    /// 이 tick의 프로세스 조사가 실패했는지. CPU 카드의 같은 필드와 같은 뜻입니다(task-011).
    let topApplicationsFailed: Bool
    /// 카드를 선택했을 때만 쓰이는 상세 지표(task-010, SPEC §5.2).
    let detail: MemoryCardDetail
}

/// Memory 상세 영역 전용 값.
/// 현재 사용량 순위와 최근 증가량 순위는 서로 다른 목록이라 나란히 두지 않고 각자 필드를 둡니다(SPEC §5.2, SPEC §5.8).
nonisolated struct MemoryCardDetail: Sendable, Equatable {
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let cachedBytes: UInt64
    /// 현재 메모리 사용량 순위. 값 자체는 `topApplications`와 같은 목록(정체성별 최근 세 개 평균의 앱 단위 합산)입니다.
    let currentUsageRanking: [ApplicationRankingEntry]
    /// 최근 10분 증가량 순위. 값이 음수일 수 있으므로 `currentUsageRanking`과 표시 방식을 공유하면 안 됩니다 —
    /// `TopApplicationsView`가 이미 쓰는 `UInt64` 변환 경로에 음수를 그대로 넣으면 trap합니다.
    let recentIncreaseRanking: [ApplicationRankingEntry]
    /// 앱 단위로 묶은 하위 프로세스 목록. CPU 상세와 같은 그룹(`ApplicationRanking.groupByApplication(_:)`)을 공유합니다.
    let applications: [ApplicationProcessGroup]
}

extension MemoryCardPresentation {
    /// TOP 5 목록에 시스템 프로세스가 포함되지 않는다는 상시 안내. CPU 카드와 같은 문구를 공유합니다.
    static let topApplicationsCaption = CPUCardPresentation.topApplicationsCaption

    /// Memory 카드를 선택·복귀하는 키보드 단축키의 실제 키. CPU 카드와 다른 단축키를 씁니다(ANALYSIS §5 DP15).
    static let selectionShortcutKey: Character = "2"

    /// Memory 카드를 선택·복귀하는 키보드 단축키의 사람이 읽는 표시. `selectionShortcutKey`에서 유도됩니다.
    static var selectionShortcutDisplayText: String { "⌘\(selectionShortcutKey)" }

    /// 최신 Memory 지표, 이력 링, 앱 순위에서 Memory 카드 표시 값을 만듭니다.
    /// - Parameters:
    ///   - history: 시간 창으로는 아직 거르지 않은 이력 값들. Swap 최근 변화량의 기준점을 여기서 찾습니다.
    ///   - topApplications: 앱 단위 메모리 사용량 순위. 5개보다 많아도 이 함수가 상위 5개로 자릅니다.
    ///   - memoryIncrease: 앱 단위 메모리 증가량 순위(`ApplicationRankingSample.memoryIncrease`).
    ///     상세의 최근 증가량 순위로 그대로 옮겨지며, 프로세스 조사 축이 아직 연결되지 않은 동안은 빈 배열입니다.
    ///   - processGroups: 상세의 앱별 하위 프로세스 목록. CPU 카드와 같은 값을 공유해도 됩니다(같은 앱 키 규칙, DP5).
    ///   - currentTimestamp: 이 tick의 시각. Swap 변화량의 10분 창 오른쪽 끝으로 씁니다.
    static func assemble(
        memory: MemorySystemMetrics,
        history: [SystemMetricsHistoryPoint],
        topApplications: [ApplicationRankingEntry],
        topApplicationsFailed: Bool = false,
        memoryIncrease: [ApplicationRankingEntry] = [],
        processGroups: [ApplicationProcessGroup] = [],
        currentTimestamp: ContinuousClock.Instant
    ) -> MemoryCardPresentation {
        let trimmedTopApplications = Array(topApplications.prefix(ApplicationRankingSampling.topCount))
        return MemoryCardPresentation(
            totalPhysicalBytes: memory.totalPhysicalBytes,
            usedBytes: memory.usedBytes,
            pressureDisplay: memory.pressureLevel.display,
            swapUsedBytes: memory.swapUsedBytes,
            swapRecentChangeBytes: swapRecentChangeBytes(
                currentSwapUsedBytes: memory.swapUsedBytes,
                history: history,
                currentTimestamp: currentTimestamp
            ),
            topApplications: trimmedTopApplications,
            topApplicationsFailed: topApplicationsFailed,
            detail: MemoryCardDetail(
                appBytes: memory.appBytes,
                wiredBytes: memory.wiredBytes,
                compressedBytes: memory.compressedBytes,
                cachedBytes: memory.cachedBytes,
                currentUsageRanking: trimmedTopApplications,
                recentIncreaseRanking: Array(memoryIncrease.prefix(ApplicationRankingSampling.topCount)),
                applications: ApplicationRanking.sortedForDisplay(groups: processGroups, by: .residentMemory)
            )
        )
    }

    /// 10분 창 안에서 가장 오래된 값을 기준점으로 찾아 현재값과의 차이를 만듭니다.
    /// 창 밖의(더 오래된) 값은 기준점이 되지 않습니다.
    ///
    /// 기준점 후보에서 창 안 가장 최신 값은 제외합니다 — production에서 `currentTimestamp`는 이력에 값을
    /// 넣은 뒤 별도로 관찰한 벽시계 시각(`ContinuousClock().now`)이라 이력의 어떤 시각보다도 항상 늦고,
    /// `timestamp < currentTimestamp` 비교로는 방금 이 tick이 만든 점 자신조차 걸러내지 못합니다.
    /// 창 안에 값이 이 최신 값 하나뿐이면(창이 막 시작됐거나 중지 뒤 재개 직후라 이력이 한 점으로 줄었으면)
    /// 그 점을 자기 자신의 기준점으로 삼지 않고 변화량을 만들지 않은 채 `nil`을 돌려줍니다.
    private static func swapRecentChangeBytes(
        currentSwapUsedBytes: UInt64,
        history: [SystemMetricsHistoryPoint],
        currentTimestamp: ContinuousClock.Instant
    ) -> Int64? {
        let windowStart = currentTimestamp - HistoryCapacity.defaultTimeRange
        let pointsInWindow = history.filter { $0.timestamp >= windowStart }
        guard let newestTimestamp = pointsInWindow.map(\.timestamp).max(),
              let baseline = pointsInWindow.first(where: { $0.timestamp < newestTimestamp }) else {
            return nil
        }
        return Int64(currentSwapUsedBytes) - Int64(baseline.swapUsedBytes)
    }
}

extension ResourceCardState where Presentation == MemoryCardPresentation {
    /// Memory 카드의 접근성 이름. 현재 단계와 사용 중 메모리, 선택·복귀 단축키를 포함합니다.
    var memoryAccessibilityLabel: String {
        let shortcut = "단축키 \(MemoryCardPresentation.selectionShortcutDisplayText)"
        switch self {
        case .collecting:
            return "Memory 카드, 수집 중, \(shortcut)"
        case .normal(let presentation, _):
            let used = Self.byteCountFormatter.string(fromByteCount: Int64(presentation.usedBytes))
            return "Memory 카드, 사용 중 메모리 \(used), Memory Pressure \(presentation.pressureDisplay.label), "
                + MemoryCardPresentation.topApplicationsCaption
                + ", \(shortcut)"
        case .failure(let lastKnown):
            guard let lastKnown else {
                return "Memory 카드, 수집 실패, \(shortcut)"
            }
            let used = Self.byteCountFormatter.string(fromByteCount: Int64(lastKnown.presentation.usedBytes))
            return "Memory 카드, 수집 실패, 마지막 사용 중 메모리 \(used), \(shortcut)"
        case .stopped(let lastKnown):
            guard let lastKnown else {
                return "Memory 카드, 수집 중지, \(shortcut)"
            }
            let used = Self.byteCountFormatter.string(fromByteCount: Int64(lastKnown.presentation.usedBytes))
            return "Memory 카드, 수집 중지, 마지막 사용 중 메모리 \(used), \(shortcut)"
        }
    }

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()
}
