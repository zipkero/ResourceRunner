//
//  DashboardPresentation.swift
//  ResourceRunner
//
//  Created by zipkero on 8/15/26.
//

import Foundation

/// 그래프 한 점. 인접 점의 시각 간격으로 빈 구간을 판별합니다.
///
/// `subValue`는 `value`(전체 사용률)와 같은 표본에서 나온 하위 계열 값입니다(예: CPU 그래프의 User 비율).
/// `nil`이면 1계열 그래프라는 뜻이고, CPU 조립 경로는 항상 채웁니다.
/// 연속 구간 분리·버킷 다운샘플링은 `value` 기준 대표 표본만 고르므로, 고른 표본의 `subValue`가
/// 별도 계산 없이 그 표본에 그대로 딸려 나갑니다(ANALYSIS §5 DP8).
nonisolated struct HistoryPoint: Sendable, Equatable {
    let timestamp: ContinuousClock.Instant
    let value: Double
    let subValue: Double?

    init(timestamp: ContinuousClock.Instant, value: Double, subValue: Double? = nil) {
        self.timestamp = timestamp
        self.value = value
        self.subValue = subValue
    }
}

extension HistoryPoint {
    /// CPU 그래프의 아래 밴드(User) 값. `subValue`가 없으면 0입니다.
    var lowerBandValue: Double { subValue ?? 0 }

    /// CPU 그래프의 위 밴드(System) 값. 전체 사용률에서 아래 밴드 값을 뺀 값이며 0 아래로 내려가지 않습니다 —
    /// 두 밴드의 합이 항상 전체 사용률과 같다는 성질이 이 계산 구조에서 나옵니다(SPEC §5.5, ANALYSIS §5 DP7).
    var upperBandValue: Double { max(0, value - lowerBandValue) }
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
    /// CPU 사용량 순위 역할도 겸하므로 순위 전용 필드를 따로 두지 않습니다(ANALYSIS §5 DP1).
    let applications: [ApplicationProcessGroup]
    /// `applications` 목록의 머리글. 어떤 지표의 순위이고 정원이 얼마인지 알립니다(ANALYSIS §5 DP1, DP2).
    let applicationsHeading: String
}

extension CPUCardPresentation {
    /// TOP 5 목록에 시스템 프로세스가 포함되지 않는다는 상시 안내.
    /// Hover나 색상이 아니라 항상 보이는 문구이며 카드 접근성 이름에도 포함됩니다.
    /// 카드 정원(`ApplicationRankingSampling.cardDisplayCount`)에서 문구를 만들어, 정원 숫자가
    /// 이 문자열 밖에 따로 남지 않게 합니다.
    static let topApplicationsCaption = ApplicationRankingSampling.topApplicationsCaption(
        count: ApplicationRankingSampling.cardDisplayCount
    )

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
            .map { HistoryPoint(timestamp: $0.timestamp, value: $0.overallCPUUsage, subValue: $0.userRatio) }

        return CPUCardPresentation(
            overallUsage: cpu.overallUsage,
            userRatio: cpu.userRatio,
            systemRatio: cpu.systemRatio,
            graphPoints: graphPoints,
            topApplications: Array(topApplications.prefix(ApplicationRankingSampling.cardDisplayCount)),
            topApplicationsFailed: topApplicationsFailed,
            detail: CPUCardDetail(
                idleRatio: cpu.idleRatio,
                coreUsages: cpu.coreUsages,
                loadAverage: cpu.loadAverage,
                applications: ApplicationRanking.sortedForDisplay(groups: processGroups, by: .cpuUsage),
                applicationsHeading: ApplicationRankingSampling.applicationListHeading(
                    metricLabel: "CPU 사용량 순위, 합계 내림차순",
                    count: ApplicationRankingSampling.detailCount
                )
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

/// CPU 그래프에 깔리는 기준선 격자. 값 25·50·75%에 선을 두어 세로 범위(0~100%)를 네 등분하고,
/// 라벨 없이 높이만으로 어림할 수 있게 합니다(SPEC §5.6, ANALYSIS §5 DP10).
/// `HistoryGraphView`와 값이 없는 자리표시(`GraphPlaceholderView`)가 같은 값·같은 변환을 써서
/// 같은 높이에 같은 격자를 그립니다(SPEC §5.8, ANALYSIS §5 DP14).
nonisolated enum HistoryGraphGridline {
    /// 기준선 값(사용률 %). 순서는 그리기에 영향을 주지 않지만, 낮은 값부터 둡니다.
    static let baselineValues: [Double] = [25, 50, 75]

    /// 기준선 값을 그래프 높이 안의 세로 좌표로 바꿉니다. 0%가 그래프 바닥(`height`), 100%가 그래프 천장(0)입니다.
    /// `HistoryGraphView`가 점 값을 좌표로 옮길 때 쓰는 변환과 같은 식이라, 격자와 밴드가 같은 기준을 씁니다.
    static func yPosition(forValue value: Double, height: Double) -> Double {
        height * (1 - value / 100)
    }
}

extension HistoryGraphGridline {
    /// 값 없는 자리표시(`GraphPlaceholderView`)가 그리는 레이어 목록. 값 있는 경로의
    /// `HistoryGraphView.drawOrder`와 같은 방식으로 뷰 밖 상수에 둬, 자리표시 `Canvas`가 이 배열을
    /// 그대로 순회해 그리게 합니다 — 격자를 빼는 mutation이 이 배열 자체를 바꾸므로 단위 테스트로 잡힙니다
    /// (SPEC §5.8, ANALYSIS §5 DP14).
    enum PlaceholderLayer: Equatable {
        case gridlines
    }

    static let placeholderDrawOrder: [PlaceholderLayer] = [.gridlines]
}

extension ResourceCardState where Presentation == CPUCardPresentation {
    /// CPU 카드의 접근성 이름. 현재 사용률과 카드 상태, 겹쳐 그린 두 계열, 기준선,
    /// TOP 5 안내 문구, 선택·복귀 단축키를 포함합니다.
    var cpuAccessibilityLabel: String {
        let shortcut = "단축키 \(CPUCardPresentation.selectionShortcutDisplayText)"
        switch self {
        case .collecting:
            return "CPU 카드, 수집 중, \(shortcut)"
        case .normal(let presentation, _):
            return "CPU 카드, \(presentation.cpuAccessibilityMetricsLabel), "
                + CPUCardPresentation.topApplicationsCaption
                + ", \(shortcut)"
        case .failure(let lastKnown):
            guard let lastKnown else {
                return "CPU 카드, 수집 실패, \(shortcut)"
            }
            return "CPU 카드, 수집 실패, 마지막 \(lastKnown.presentation.cpuAccessibilityMetricsLabel), \(shortcut)"
        case .stopped(let lastKnown):
            guard let lastKnown else {
                return "CPU 카드, 수집 중지, \(shortcut)"
            }
            return "CPU 카드, 수집 중지, 마지막 \(lastKnown.presentation.cpuAccessibilityMetricsLabel), \(shortcut)"
        }
    }
}

extension CPUCardPresentation {
    /// 그래프가 나타내는 두 계열과 라벨 없는 기준선 값까지 카드의 단일 접근성 노드에 모읍니다
    /// (SPEC §5.10, ANALYSIS §5 DP10, DP13).
    fileprivate var cpuAccessibilityMetricsLabel: String {
        let overall = Int(overallUsage.rounded())
        let user = Int(userRatio.rounded())
        let system = Int(systemRatio.rounded())
        let baselines = HistoryGraphGridline.baselineValues
            .map { "\(Int($0.rounded()))%" }
            .joined(separator: "·")
        return "전체 사용률 \(overall)%, User \(user)%, System \(system)%, "
            + "User와 System 두 계열 중첩 그래프, 기준선 \(baselines)"
    }
}

/// 논리 코어 격자의 행·열 분할. 코어 수 하나만으로 행별 코어 인덱스 묶음을 정합니다.
/// 뷰는 여기서 나온 행을 좌표와 그리기로 옮기기만 합니다(SPEC §5.4, DESIGN §5 DP1, DP4).
nonisolated enum CPUCoreGridLayout {
    /// 한 행에 놓을 수 있는 칸의 최대 수. 가용 폭을 인자로 받는 대신 이 상수 하나에 폭 판단을 모읍니다 —
    /// 폭을 인자로 받으면 행·열이 렌더 시점에만 정해져 코어 수를 바꿔 가며 확인할 수 없습니다.
    /// 상세 팝업 콘텐츠 폭 368pt에서 칸 간격 6pt를 빼면 8열의 칸 폭이 40.8pt로
    /// 칸의 화면 수치 `"100%"`(.caption2 실측 28.0pt)를 담고도 남습니다(DESIGN §5 DP1).
    static let maximumColumnCount = 8

    /// 칸 막대의 트랙 높이. 값과 무관하게 고정이라 값이 0이든 100이든 칸 높이가 같고,
    /// 값이 바뀌어도 격자와 그 아래 내용이 밀리지 않습니다(DESIGN §5 DP2).
    static let barHeight: CGFloat = 18

    /// 칸 사이 가로·세로 간격. 열 상한 8의 칸 폭 40.8pt가 이 값을 뺀 나머지에서 나옵니다.
    static let cellSpacing: CGFloat = 6

    /// 코어 인덱스 `0..<coreCount`를 행별로 묶어 왼쪽에서 오른쪽, 위에서 아래 순서로 돌려줍니다.
    /// 마지막 행을 뺀 모든 행의 길이가 같고 마지막 행만 짧을 수 있습니다.
    ///
    /// 행 수를 먼저 정하고 열 수를 되돌려 구하는 두 단계를 거칩니다 —
    /// `열 수 = min(코어 수, 열 상한)` 한 단계로 구하면 코어 14개가 8 + 6으로 들쭉날쭉하게 나뉩니다(DESIGN §5 DP1).
    ///
    /// 코어 수가 0이면 빈 배열입니다. 없는 코어를 빈 행으로도 만들지 않습니다.
    static func rows(coreCount: Int) -> [[Int]] {
        guard coreCount > 0 else { return [] }

        let rowCount = divideRoundingUp(coreCount, by: maximumColumnCount)
        let columnCount = divideRoundingUp(coreCount, by: rowCount)
        return stride(from: 0, to: coreCount, by: columnCount).map { start in
            Array(start..<min(start + columnCount, coreCount))
        }
    }

    /// 나눗셈의 올림. `rows`가 행 수·열 수를 모두 이 헬퍼로 구하므로, 내림으로 바꾸면 코어 수가 열 상한 미만일 때
    /// 행 수가 0이 되어 0으로 나누고, 그 위에서는 열 수가 `maximumColumnCount`를 넘어 팝업 폭을 벗어납니다.
    private static func divideRoundingUp(_ dividend: Int, by divisor: Int) -> Int {
        (dividend + divisor - 1) / divisor
    }
}

/// 펼친 하위 프로세스 행의 들여쓰기와 세 경계 간격. 뷰 본문에 두면 값을 바꿔 가며 확인할 방법이
/// 렌더링밖에 남지 않으므로 계산 자리로 분리했습니다(DESIGN §5 DP5, DP6).
/// 아이콘 자리 크기를 `ApplicationRowIconLayout`에서 가져오므로 그 자리와 같은 격리를 씁니다.
@MainActor
enum ApplicationProcessRowLayout {
    /// `DisclosureGroup` 라벨에서 삼각형이 차지하는 폭(pt). macOS가 정하는 값이라 실측 상수로 둡니다 —
    /// OS가 이 폭을 바꾸면 하위 행이 부모 앱 이름 시작선에서 그만큼 어긋납니다.
    static let disclosureTriangleWidth: CGFloat = 12

    /// 앱 행 라벨의 아이콘 자리와 앱 이름 사이 간격. 들여쓰기가 이 값에서 유도되므로
    /// 라벨 `HStack`이 다른 간격을 쓰면 두 층의 시작선이 어긋납니다.
    static let labelIconSpacing: CGFloat = 6

    /// 하위 행의 왼쪽 들여쓰기. 부모 앱 이름 시작선과 같아지도록 삼각형 폭·아이콘 자리 크기·라벨 간격에서
    /// 유도합니다 — 아이콘 크기가 바뀌면 들여쓰기가 따라가야 정렬이 유지됩니다.
    static let childIndent: CGFloat =
        disclosureTriangleWidth + ApplicationRowIconLayout.detailPointSize + labelIconSpacing

    /// 하위 행끼리의 간격. 같은 앱 안이라 세 경계 중 가장 좁습니다.
    static let betweenChildren: CGFloat = 4

    /// 부모 앱 행과 첫 하위 행 사이 간격. 앱 행에서 그 앱 안쪽으로 들어가는 경계입니다.
    static let parentToFirstChild: CGFloat = 10

    /// `ApplicationProcessGroupListView`의 목록 `VStack`이 행 사이에 두는 간격. 마지막 하위 행과 다음 앱 행
    /// 사이에는 이 값이 이미 들어가므로, 그만큼을 뺀 몫만 펼친 내용 아래에 겁니다.
    /// 목록이 다른 간격을 쓰기 시작하면 마지막 경계가 목표 간격에서 벗어납니다.
    static let listRowSpacing: CGFloat = 2

    /// 마지막 하위 행과 다음 앱 행 사이 간격. 앱 하나를 벗어나는 경계라 세 경계 중 가장 넓습니다.
    static let lastChildToNextApplication: CGFloat = 16

    /// 펼친 내용 아래에 거는 여백. 목록 `VStack`의 간격 위에 더해져 마지막 경계를 만듭니다.
    static let afterLastChild: CGFloat = lastChildToNextApplication - listRowSpacing
}

/// 코어 격자가 화면에 내놓는 문자열. 뷰가 문자열을 직접 조립하지 않게 모아 둡니다.
nonisolated enum CPUCoreUsageFormatting {
    /// 칸에 보이는 정수 퍼센트. 코어 사용률 표현이 문자열 한 줄이던 때의 반올림 규칙을 그대로 씁니다 —
    /// 규칙을 바꾸면 화면 수치와 접근성 값이 갈립니다.
    static func valueText(_ usage: Double) -> String {
        "\(Int(usage.rounded()))%"
    }

    /// 격자 머리글. 코어 수를 인자에서 받아 만듭니다.
    static func headingText(coreCount: Int) -> String {
        "논리 코어 \(coreCount)개 사용률"
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

/// Memory 카드의 Pressure·Swap 병합 줄을 이루는 조립 요소 하나.
///
/// 뷰는 `MemoryPressureSwapLineFormatting.assemble`이 돌려주는 배열을 순서대로 이어붙여
/// `MemoryPressureSwapLineFormatting.maximumLineCount`로 묶어 그리고, 그 결과 잘림이 끝에서 일어납니다 —
/// 이 배열의 순서 자체가 잘림 우선순위입니다(ANALYSIS §5 DP4).
/// `HistoryGraphGridline.drawOrder`와 같은 방식으로 순서·구성을 뷰 밖 값으로 고정해 단위 테스트가 직접 검증합니다.
nonisolated enum MemoryPressureSwapLineSegment: Sendable, Equatable {
    /// Pressure 기호(SF Symbol). 색상 없이도 단계를 구분하는 수단(core SPEC §5.5)이라 항상 맨 앞에 옵니다.
    case symbol(name: String)
    case label(String)
    case separator
    case swapUsage(String)
    case swapChange(String)
    /// 구성 네 항목의 바이트 합. 「사용 중」과 정의가 다른 지표라 뷰가 「구성」 라벨을 함께 그려
    /// 제목 줄의 「사용 중」 수치와 갈려 읽히게 합니다(SPEC §5.3).
    case compositionTotal(String)
}

nonisolated enum MemoryPressureSwapLineFormatting {
    /// 병합 줄에 허용하는 최대 줄 수. 뷰는 이 상수로 `lineLimit`을 걸어 폭이 부족할 때
    /// 줄바꿈 대신 끝에서 잘리게 합니다 — 값을 바꾸면 잘림 동작이 바뀌므로 뷰에 하드코딩하지 않고 이 상수 하나로 고정합니다.
    static let maximumLineCount = 1

    /// 캐시된 값이 없을 때 쓰는 자리표시. 세 실제 단계 기호(원·삼각형·팔각형) 중 어느 것도 아닌
    /// `circle.dashed`를 써서 값을 지어내지 않습니다(§5 DP17, SPEC §5.11).
    static let placeholder: [MemoryPressureSwapLineSegment] = [
        .symbol(name: "circle.dashed"),
        .label("–")
    ]

    /// - Parameters:
    ///   - format: Swap·구성 합계 바이트를 문자열로 바꾸는 함수. 카드가 이미 쓰는 `ByteCountFormatter` 기반 함수를 그대로 받아
    ///     한 줄에 놓인 두 수치가 같은 서식으로 읽히게 합니다.
    /// - Returns: 「Pressure 기호 → Pressure 라벨 → 구분자 → Swap 사용량 → Swap 변화량 → 구분자 → 구성 합계」 순서의 조립 요소.
    ///   변화량 기준점이 없으면 `.swapChange`를 담지 않습니다.
    ///
    ///   구성 합계가 맨 뒤라 폭이 부족할 때 가장 먼저 잘립니다.
    ///   카드 콘텐츠 폭 232pt에 대해 실측한 폭은 대표값 213pt, 16GB 기기 최댓값 228pt입니다.
    ///   Swap 사용량과 10분 변화량이 모두 두 자리 GB로 함께 나오는 극단 입력(예: 세 수치가 모두 35.9 GB)에서만
    ///   233~243pt로 넘쳐 끝이 잘립니다 — DP4가 병합 줄에 대해 이미 받아들인 대가입니다.
    static func assemble(
        pressureDisplay: MemoryPressureDisplay,
        swapUsedBytes: UInt64,
        swapRecentChangeBytes: Int64?,
        compositionTotalBytes: UInt64,
        format: (UInt64) -> String
    ) -> [MemoryPressureSwapLineSegment] {
        var segments: [MemoryPressureSwapLineSegment] = [
            .symbol(name: pressureDisplay.symbolName),
            .label(pressureDisplay.label),
            .separator,
            .swapUsage(format(swapUsedBytes))
        ]
        if let change = swapRecentChangeBytes {
            let sign = change >= 0 ? "+" : "-"
            segments.append(.swapChange("\(sign)\(format(UInt64(abs(change))))"))
        }
        segments.append(.separator)
        segments.append(.compositionTotal(format(compositionTotalBytes)))
        return segments
    }
}

/// Memory 구성 항목 한 종류. 선언 순서가 곧 바 구간 순서이자 범례 순서입니다 —
/// 바와 범례가 모두 `allCases`를 순회하므로 두 자리의 순서가 갈라질 경로가 없습니다(SPEC §5.3, ANALYSIS §5 DP5).
nonisolated enum MemoryCompositionCategory: Sendable, Equatable, CaseIterable {
    case app
    case wired
    case compressed
    case cached

    /// 범례에 쓰는 항목 이름. 색은 보조 수단이라 스와치 옆에 이 이름이 항상 함께 표시됩니다(SPEC §5.3).
    var label: String {
        switch self {
        case .app: return "App"
        case .wired: return "Wired"
        case .compressed: return "Compressed"
        case .cached: return "Cached"
        }
    }
}

/// 구성 네 항목의 바이트. 구간 계산이 항목 순서대로 값을 읽는 자리를 한 곳으로 모읍니다 —
/// 상세 도넛 범례(task-008)도 같은 값을 씁니다.
///
/// 「사용 중」(`MemoryCardPresentation.usedBytes`)은 여기에 담기지 않습니다 —
/// 구성 합계와 「사용 중」은 정의가 다른 별개 지표라 한 계산에 섞이면 화면에서도 갈리지 않습니다
/// (SPEC §5.3, ANALYSIS §5 DP5).
nonisolated struct MemoryCompositionBytes: Sendable, Equatable {
    let app: UInt64
    let wired: UInt64
    let compressed: UInt64
    let cached: UInt64

    subscript(category: MemoryCompositionCategory) -> UInt64 {
        switch category {
        case .app: return app
        case .wired: return wired
        case .compressed: return compressed
        case .cached: return cached
        }
    }

    /// 네 항목의 실제 바이트 합. 카드는 이 값 하나를 「구성」 수치로 보여 주고(SPEC §5.3),
    /// 누적 바가 트랙을 넘어 구간을 잘라도 이 값은 자르지 않습니다.
    /// 실제 시스템에서 합이 `UInt64`를 넘을 수는 없지만, 넘치는 입력에 trap하는 대신 상한에서 멈춥니다.
    var total: UInt64 {
        MemoryCompositionCategory.allCases.reduce(UInt64.zero) { partial, category in
            let (sum, overflowed) = partial.addingReportingOverflow(self[category])
            return overflowed ? .max : sum
        }
    }
}

/// 구성 누적 바의 구간 하나.
nonisolated struct MemoryCompositionSegment: Sendable, Equatable {
    let category: MemoryCompositionCategory
    /// 이 항목의 실제 바이트. 넘침으로 구간 길이가 잘려도 이 값은 자르지 않으므로,
    /// 이 값을 읽는 자리(상세 범례·접근성 이름)의 수치는 언제나 실제 값입니다.
    let bytes: UInt64
    /// 트랙(전체 물리 메모리) 대비 구간 길이 비율. 트랙을 넘는 부분은 잘려 있어 `startRatio + ratio <= 1`입니다.
    let ratio: Double
    /// 트랙 왼쪽 끝에서 이 구간이 시작하는 비율. 앞 항목들의 비율 합입니다.
    let startRatio: Double
}

/// 구성 누적 바·도넛이 공유하는 구간 계산 결과.
nonisolated struct MemoryCompositionLayout: Sendable, Equatable {
    let segments: [MemoryCompositionSegment]
    /// 네 항목 합이 트랙을 넘어 구간을 트랙 끝에서 잘랐는지.
    let isOverflowing: Bool

    /// 구간을 만들 수 없는 입력(전체 물리 메모리 0)의 결과. 없는 값을 0 길이 구간으로도 만들지 않습니다(SPEC §5.11).
    static let empty = MemoryCompositionLayout(segments: [], isOverflowing: false)

    /// 트랙은 전체 물리 메모리이고 각 구간 길이는 「항목 바이트 ÷ 전체 물리 메모리」입니다 —
    /// 네 항목의 합으로 정규화하면 구간이 트랙을 꽉 채우는 대신 실제 바이트에 비례하지 않게 됩니다(SPEC §5.3, ANALYSIS §5 DP5).
    ///
    /// 네 항목의 합이 트랙을 넘을 수 있어(compressor가 물고 있는 페이지가 internal 쪽에도 계상됨)
    /// 누적이 트랙 끝에 닿는 구간은 그 자리에서 자르고, 그 뒤 항목은 길이 0으로 남습니다.
    /// 잘렸다는 사실은 `isOverflowing`으로 함께 돌려주고, 각 구간의 `bytes`는 자르지 않습니다.
    static func make(bytes: MemoryCompositionBytes, totalPhysicalBytes: UInt64) -> MemoryCompositionLayout {
        guard totalPhysicalBytes > 0 else { return .empty }

        let track = Double(totalPhysicalBytes)
        var cumulativeRatio = 0.0
        var segments: [MemoryCompositionSegment] = []
        for category in MemoryCompositionCategory.allCases {
            let categoryBytes = bytes[category]
            let ratio = Double(categoryBytes) / track
            let startRatio = min(cumulativeRatio, 1)
            segments.append(
                MemoryCompositionSegment(
                    category: category,
                    bytes: categoryBytes,
                    ratio: min(ratio, 1 - startRatio),
                    startRatio: startRatio
                )
            )
            cumulativeRatio += ratio
        }
        return MemoryCompositionLayout(segments: segments, isOverflowing: cumulativeRatio > 1)
    }
}

/// 카드 누적 바가 쓰는 구성 구간을 상세 도넛의 각도로 옮긴 결과.
/// 비율과 누적 시작 위치는 다시 계산하지 않고 `MemoryCompositionLayout`의 값을 그대로 보존합니다.
nonisolated struct MemoryCompositionDonutSegment: Sendable, Equatable {
    let category: MemoryCompositionCategory
    let bytes: UInt64
    let ratio: Double
    let startRatio: Double
    let startAngleDegrees: Double
    let endAngleDegrees: Double
}

nonisolated struct MemoryCompositionDonutLayout: Sendable, Equatable {
    /// 12시 방향에서 시작해 시계 방향으로 진행합니다.
    static let startAngleDegrees = -90.0
    static let fullTrackAngleDegrees = 360.0

    let segments: [MemoryCompositionDonutSegment]

    /// 카드 구간 결과를 도넛 각도로만 바꿉니다. 별도의 바이트 분모나 구성 계산은 두지 않습니다.
    static func make(from layout: MemoryCompositionLayout) -> MemoryCompositionDonutLayout {
        MemoryCompositionDonutLayout(segments: layout.segments.map { segment in
            let startAngle = startAngleDegrees + fullTrackAngleDegrees * segment.startRatio
            return MemoryCompositionDonutSegment(
                category: segment.category,
                bytes: segment.bytes,
                ratio: segment.ratio,
                startRatio: segment.startRatio,
                startAngleDegrees: startAngle,
                endAngleDegrees: startAngle + fullTrackAngleDegrees * segment.ratio
            )
        })
    }
}

/// Memory 상세 범례 한 행. 값이 없는 상태에서도 네 항목 이름과 `-` 자리를 유지합니다.
nonisolated struct MemoryCompositionDetailLegendRow: Sendable, Equatable {
    let category: MemoryCompositionCategory
    let label: String
    let valueText: String
}

nonisolated enum MemoryCompositionDetailLegendFormatting {
    /// 상세는 카드 축약 서식이 아니라 호출부의 기존 바이트 서식을 그대로 씁니다.
    static func rows(
        bytes: MemoryCompositionBytes?,
        format: (UInt64) -> String
    ) -> [MemoryCompositionDetailLegendRow] {
        MemoryCompositionCategory.allCases.map { category in
            MemoryCompositionDetailLegendRow(
                category: category,
                label: category.label,
                valueText: bytes.map { format($0[category]) } ?? "-"
            )
        }
    }
}

/// 상세에서 서로 다른 자리를 차지하는 구성 합계와 「사용 중」 표시 값.
/// 도넛 가운데와 별도 줄을 타입으로 나눠, 두 지표를 같은 값이나 같은 자리로 합치지 않습니다.
nonisolated struct MemoryCompositionDetailSummary: Sendable, Equatable {
    struct Metric: Sendable, Equatable {
        let label: String
        let bytes: UInt64
    }

    let donutCenter: Metric
    let usedLine: Metric

    static func make(compositionBytes: MemoryCompositionBytes, usedBytes: UInt64) -> MemoryCompositionDetailSummary {
        MemoryCompositionDetailSummary(
            donutCenter: Metric(label: "구성 합계", bytes: compositionBytes.total),
            usedLine: Metric(label: "사용 중", bytes: usedBytes)
        )
    }
}

/// 구성 범례 줄을 이루는 조립 요소 하나.
///
/// 뷰는 `MemoryCompositionLegendFormatting.segments`를 순서대로 이어붙여 한 줄로 그립니다 —
/// 이 배열의 순서가 곧 화면의 범례 순서이고, 바 구간 순서와 같아야 하므로 그 순서 자체가 검증 대상입니다.
/// `MemoryPressureSwapLineSegment`와 같은 방식으로 순서·구성을 뷰 밖 값으로 고정합니다(ANALYSIS §5 DP15).
nonisolated enum MemoryCompositionLegendSegment: Sendable, Equatable {
    /// 항목 색 스와치. 색은 보조 수단이라 바로 뒤에 `.label`이 반드시 따라옵니다(SPEC §5.3).
    case swatch(MemoryCompositionCategory)
    /// 항목 이름. 색을 지운 화면에서 어느 구간인지 가리는 수단입니다.
    case label(String)
    case separator
}

nonisolated enum MemoryCompositionLegendFormatting {
    /// 구성 바가 들어간 제목 줄과 범례 줄에 허용하는 최대 줄 수.
    /// 바가 제목 줄의 남는 폭을 쓰고 범례가 네 항목을 한 줄에 담으므로, 두 줄 모두 이 상한으로 묶어
    /// 내용이 길어져도 줄바꿈으로 카드가 커지지 않게 합니다(SPEC §5.8) — 뷰에 하드코딩하지 않고 이 상수 하나로 고정합니다.
    static let maximumLineCount = 1

    /// 범례 줄의 조립 결과. 바 구간 순서(App → Wired → Compressed → Cached)와 같은 순서이며,
    /// 각 스와치 바로 뒤에 그 항목의 이름이 붙어 색을 지운 화면에서도 어느 구간인지 읽힙니다(SPEC §5.3).
    ///
    /// 수치는 담지 않습니다 — 네 이름과 네 수치를 한 줄에 담으면 카드 콘텐츠 폭(232pt)에 345pt가 필요하고,
    /// 이름을 네 글자로 줄여도 253pt로 들어가지 않습니다(실측).
    /// 카드에 남는 수치는 병합 줄의 구성 합계 하나이고, 항목별 수치는 상세 범례(SPEC §5.4)와
    /// 카드 접근성 이름(SPEC §5.10)이 맡습니다.
    ///
    /// 그래서 이 값은 상태와 무관한 상수입니다. 캐시된 값이 있든 없든 같은 네 이름이 같은 자리에 남고,
    /// 값 없음을 나타내는 자리표시를 따로 두지 않아도 카드가 흔들리지 않습니다(SPEC §5.8, ANALYSIS §5 DP14).
    static let segments: [MemoryCompositionLegendSegment] = {
        var result: [MemoryCompositionLegendSegment] = []
        for category in MemoryCompositionCategory.allCases {
            if !result.isEmpty {
                result.append(.separator)
            }
            result.append(.swatch(category))
            result.append(.label(category.label))
        }
        return result
    }()
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
/// 현재 사용량 순위는 전용 필드를 두지 않고 앱 목록(`applications`)이 그 역할을 겸합니다 —
/// 같은 지표가 두 자리에 나타나지 않도록 값 모델 형태로 막습니다(ANALYSIS §5 DP1).
/// 최근 증가량 순위는 다른 지표라 별도 필드로 남습니다(SPEC §5.2, SPEC §5.8).
nonisolated struct MemoryCardDetail: Sendable, Equatable {
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let cachedBytes: UInt64
    /// 최근 10분 증가량 순위. 값이 음수일 수 있으므로 `applications`의 합계 값과 표시 방식을 공유하면 안 됩니다 —
    /// `TopApplicationsView`가 이미 쓰는 `UInt64` 변환 경로에 음수를 그대로 넣으면 trap합니다.
    let recentIncreaseRanking: [ApplicationRankingEntry]
    /// `recentIncreaseRanking`의 정원(상세 정원)에 맞춘 시스템 프로세스 제외 안내 문구.
    /// 이 목록만 카드·현재 사용량 순위와 다른 정원(20)을 쓰므로, 뷰가 정원을 골라 문구를 만들지 않고
    /// 조립 시점에 이미 정해진 문구를 그대로 받아 쓰게 합니다(ANALYSIS §5 DP2, DP15).
    let recentIncreaseRankingCaption: String
    /// 앱 단위로 묶은 하위 프로세스 목록. CPU 상세와 같은 그룹(`ApplicationRanking.groupByApplication(_:)`)을 공유하며,
    /// 현재 메모리 사용량 순위 역할도 겸합니다(정체성별 최근 세 개 평균의 앱 단위 합산을 Resident Memory 기준 내림차순 정렬, ANALYSIS §5 DP1).
    let applications: [ApplicationProcessGroup]
    /// `applications` 목록의 머리글. 「현재 사용량」 순위임과 정원을 알립니다(ANALYSIS §5 DP1, DP2).
    let applicationsHeading: String
}

extension MemoryCardDetail {
    /// 구성 시각화 입력. 카드 누적 바와 상세 도넛이 같은 값에서 나오도록 이 자리 하나로 모읍니다.
    var compositionBytes: MemoryCompositionBytes {
        MemoryCompositionBytes(app: appBytes, wired: wiredBytes, compressed: compressedBytes, cached: cachedBytes)
    }
}

extension MemoryCardPresentation {
    /// 카드 구성 누적 바가 그리는 구간. 트랙은 전체 물리 메모리이고 「사용 중」(`usedBytes`)은 입력이 아닙니다
    /// (SPEC §5.3, ANALYSIS §5 DP5).
    var compositionLayout: MemoryCompositionLayout {
        MemoryCompositionLayout.make(bytes: detail.compositionBytes, totalPhysicalBytes: totalPhysicalBytes)
    }

    /// 카드 병합 줄에 놓이는 구성 합계. 「사용 중」(`usedBytes`)과 정의가 다른 지표이므로
    /// 같은 값으로 합치지 않고 각자 라벨을 단 다른 자리에 둡니다(SPEC §5.3).
    var compositionTotalBytes: UInt64 {
        detail.compositionBytes.total
    }

    /// 상세 도넛도 카드와 같은 `compositionLayout`을 입력으로 삼고 각도 변환만 더합니다.
    var compositionDonutLayout: MemoryCompositionDonutLayout {
        MemoryCompositionDonutLayout.make(from: compositionLayout)
    }

    /// 도넛 가운데의 구성 합계와 별도 줄의 「사용 중」 값을 한 자리에서 조립합니다.
    var compositionDetailSummary: MemoryCompositionDetailSummary {
        MemoryCompositionDetailSummary.make(compositionBytes: detail.compositionBytes, usedBytes: usedBytes)
    }

    /// 상세 도넛 하나가 내보내는 접근성 이름. 도넛의 네 구간 수치는 잘리지 않은 원래 바이트를 쓰고,
    /// 링의 기준인 전체 물리 메모리와 구성 합계를 함께 읽습니다(SPEC §5.10, ANALYSIS §5 DP13).
    var compositionDonutAccessibilityLabel: String {
        let composition = detail.compositionBytes
        let categories = MemoryCompositionCategory.allCases.map { category in
            "\(category.label) \(Self.accessibilityByteCount(composition[category]))"
        }.joined(separator: ", ")
        return "Memory 구성 도넛, \(categories), 구성 합계 \(Self.accessibilityByteCount(composition.total)), "
            + "전체 물리 메모리 \(Self.accessibilityByteCount(totalPhysicalBytes))"
    }

    /// 카드의 화면 폭과 무관하게 제목·병합 줄·구성 그래프가 가진 모든 새 수치를 온전히 보존합니다.
    fileprivate var memoryAccessibilityMetricsLabel: String {
        let composition = detail.compositionBytes
        let categories = MemoryCompositionCategory.allCases.map { category in
            "\(category.label) \(Self.accessibilityByteCount(composition[category]))"
        }.joined(separator: ", ")
        var swap = "Swap \(Self.accessibilityByteCount(swapUsedBytes))"
        if let change = swapRecentChangeBytes {
            let sign = change >= 0 ? "+" : "-"
            swap += ", Swap 최근 변화 \(sign)\(Self.accessibilityByteCount(UInt64(abs(change))))"
        }
        return "사용 중 \(Self.accessibilityByteCount(usedBytes)), "
            + "전체 물리 메모리 \(Self.accessibilityByteCount(totalPhysicalBytes)), "
            + "Memory Pressure \(pressureDisplay.label), \(swap), \(categories), "
            + "구성 합계 \(Self.accessibilityByteCount(composition.total))"
    }

    private static func accessibilityByteCount(_ bytes: UInt64) -> String {
        accessibilityByteCountFormatter.string(fromByteCount: Int64(bytes))
    }

    private static let accessibilityByteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()
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
        let trimmedTopApplications = Array(topApplications.prefix(ApplicationRankingSampling.cardDisplayCount))
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
                recentIncreaseRanking: Array(memoryIncrease.prefix(ApplicationRankingSampling.detailCount)),
                recentIncreaseRankingCaption: ApplicationRankingSampling.topApplicationsCaption(
                    count: ApplicationRankingSampling.detailCount
                ),
                applications: ApplicationRanking.sortedForDisplay(groups: processGroups, by: .residentMemory),
                applicationsHeading: ApplicationRankingSampling.applicationListHeading(
                    metricLabel: "현재 사용량 순위, Memory 사용량 합계 내림차순",
                    count: ApplicationRankingSampling.detailCount
                )
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
    /// Memory 카드의 접근성 이름. 현재 단계와 사용 중·구성 수치, 병합 줄 수치,
    /// 선택·복귀 단축키를 포함합니다.
    var memoryAccessibilityLabel: String {
        let shortcut = "단축키 \(MemoryCardPresentation.selectionShortcutDisplayText)"
        switch self {
        case .collecting:
            return "Memory 카드, 수집 중, \(shortcut)"
        case .normal(let presentation, _):
            return "Memory 카드, \(presentation.memoryAccessibilityMetricsLabel), "
                + MemoryCardPresentation.topApplicationsCaption
                + ", \(shortcut)"
        case .failure(let lastKnown):
            guard let lastKnown else {
                return "Memory 카드, 수집 실패, \(shortcut)"
            }
            return "Memory 카드, 수집 실패, 마지막 \(lastKnown.presentation.memoryAccessibilityMetricsLabel), \(shortcut)"
        case .stopped(let lastKnown):
            guard let lastKnown else {
                return "Memory 카드, 수집 중지, \(shortcut)"
            }
            return "Memory 카드, 수집 중지, 마지막 \(lastKnown.presentation.memoryAccessibilityMetricsLabel), \(shortcut)"
        }
    }
}
