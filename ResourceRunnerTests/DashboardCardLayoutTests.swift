//
//  DashboardCardLayoutTests.swift
//  ResourceRunnerTests
//
//  task-015 검증 조건: 카드 뷰의 렌더 높이가 수집 상태·TOP 5 항목 수·조사 실패 여부와 무관하게 같은지 확인합니다.
//

import AppKit
import SwiftUI
import Testing
@testable import ResourceRunner

private let baseInstant = ContinuousClock().now

private func cpuMetrics(userRatio: Double = 30, systemRatio: Double = 12) -> CPUSystemMetrics {
    CPUSystemMetrics(
        overallUsage: 42,
        userRatio: userRatio,
        systemRatio: systemRatio,
        idleRatio: 58,
        coreUsages: [42],
        loadAverage: LoadAverage(oneMinute: 0, fiveMinutes: 0, fifteenMinutes: 0)
    )
}

private func memoryMetrics(
    swapUsedBytes: UInt64 = 0,
    pressureLevel: MemoryPressureLevel = .normal,
    appBytes: UInt64 = 4 * 1024 * 1024 * 1024,
    cachedBytes: UInt64 = 1024 * 1024 * 1024
) -> MemorySystemMetrics {
    MemorySystemMetrics(
        totalPhysicalBytes: 16 * 1024 * 1024 * 1024,
        usedBytes: 8 * 1024 * 1024 * 1024,
        appBytes: appBytes,
        wiredBytes: 2 * 1024 * 1024 * 1024,
        compressedBytes: 2 * 1024 * 1024 * 1024,
        cachedBytes: cachedBytes,
        swapUsedBytes: swapUsedBytes,
        pressureLevel: pressureLevel
    )
}

private func rankingEntries(count: Int) -> [ApplicationRankingEntry] {
    (0..<count).map { index in
        ApplicationRankingEntry(key: ApplicationKey(value: "/Applications/App\(index).app"), displayName: "App\(index)", value: Double(index))
    }
}

private func cpuPresentation(
    topApplicationsCount: Int,
    topApplicationsFailed: Bool = false,
    userRatio: Double = 30,
    systemRatio: Double = 12
) -> CPUCardPresentation {
    CPUCardPresentation.assemble(
        cpu: cpuMetrics(userRatio: userRatio, systemRatio: systemRatio),
        history: [],
        topApplications: rankingEntries(count: topApplicationsCount),
        topApplicationsFailed: topApplicationsFailed,
        currentTimestamp: baseInstant
    )
}

private func memoryPresentation(topApplicationsCount: Int, topApplicationsFailed: Bool = false) -> MemoryCardPresentation {
    MemoryCardPresentation.assemble(
        memory: memoryMetrics(),
        history: [],
        topApplications: rankingEntries(count: topApplicationsCount),
        topApplicationsFailed: topApplicationsFailed,
        currentTimestamp: baseInstant
    )
}

private func swapHistoryPoint(secondsFromBase: Double, swapUsedBytes: UInt64) -> SystemMetricsHistoryPoint {
    SystemMetricsHistoryPoint(
        timestamp: baseInstant.advanced(by: .seconds(secondsFromBase)),
        overallCPUUsage: 0,
        userRatio: 0,
        swapUsedBytes: swapUsedBytes
    )
}

/// task-006 검증 조건이 요구하는 "가장 긴 Pressure 라벨·가장 긴 Swap 값 조합"을 만듭니다.
/// Pressure 세 단계의 라벨 길이는 모두 같으므로(`위험`·`경고`·`정상`), 여기서는 변화량까지 담은
/// 가장 긴 문자열 조합을 얻으려고 Swap 사용량을 크게 잡고 변화 기준점을 함께 둡니다.
private func memoryPresentationWithLongestPressureSwapLine() -> MemoryCardPresentation {
    MemoryCardPresentation.assemble(
        memory: memoryMetrics(swapUsedBytes: 999_000_000_000, pressureLevel: .critical),
        history: [
            swapHistoryPoint(secondsFromBase: 0, swapUsedBytes: 0),
            swapHistoryPoint(secondsFromBase: 15, swapUsedBytes: 500_000_000_000)
        ],
        topApplications: rankingEntries(count: 5),
        currentTimestamp: baseInstant.advanced(by: .seconds(30))
    )
}

/// 순위 항목 전부의 아이콘을 돌려주는 제공자. 아이콘이 있는 행과 없는 행의 높이를 견주는 데 씁니다.
@MainActor
private func allIconsProvider(count: Int) -> StubApplicationIconProvider {
    let images = rankingEntries(count: count).reduce(into: [ApplicationKey: NSImage]()) { result, entry in
        result[entry.key] = NSImage(size: NSSize(width: 16, height: 16))
    }
    return StubApplicationIconProvider(images: images)
}

/// 카드 뷰 생성 자리를 한 곳으로 모읍니다.
/// 아이콘 제공자를 넘기지 않은 호출은 아이콘을 하나도 얻지 못한 상태(중립 기호 자리)를 그립니다.
@MainActor
private func cpuCardView(
    _ state: ResourceCardState<CPUCardPresentation>,
    iconProvider: (any ApplicationIconProviding)? = nil
) -> CPUCardView {
    CPUCardView(state: state, iconProvider: iconProvider ?? StubApplicationIconProvider())
}

@MainActor
private func memoryCardView(
    _ state: ResourceCardState<MemoryCardPresentation>,
    iconProvider: (any ApplicationIconProviding)? = nil
) -> MemoryCardView {
    MemoryCardView(state: state, iconProvider: iconProvider ?? StubApplicationIconProvider())
}

/// 카드 뷰의 렌더 높이를 잽니다. `NSHostingController.sizeThatFits(in:)`가 주어진 너비에서
/// SwiftUI 뷰가 실제로 필요로 하는 높이를 돌려주므로, `DashboardView`가 카드에 실제로 주는
/// 너비(280pt에서 좌우 padding을 뺀 값)로 재야 슬롯 줄바꿈까지 production과 같은 조건이 됩니다.
@MainActor
private func measuredHeight(_ view: some View, width: CGFloat = 280 - 32) -> CGFloat {
    let controller = NSHostingController(rootView: view)
    return controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
}

/// 카드 뷰를 실제로 그려 픽셀로 돌려줍니다. 텍스트가 아닌 그림 요소(구성 누적 바)는
/// 크기·너비 측정으로는 존재 여부가 드러나지 않아, 그린 결과를 직접 견주는 수단이 필요합니다.
@MainActor
private func renderedPixels(_ view: some View, width: CGFloat = 280 - 32) -> Data? {
    let renderer = ImageRenderer(content: view.frame(width: width))
    renderer.scale = 1
    return renderer.nsImage?.tiffRepresentation
}

/// 카드 뷰가 줄바꿈 없이 필요로 하는 너비. 높이 단언은 `lineLimit(1)` 때문에 줄 내용이 바뀌어도 흔들리지 않으므로,
/// 뷰가 실제로 어떤 문자열을 그리는지는 이 너비로만 관찰할 수 있습니다.
@MainActor
private func measuredIdealWidth(_ view: some View) -> CGFloat {
    let controller = NSHostingController(rootView: view.fixedSize(horizontal: true, vertical: false))
    return controller.sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width
}

/// task-015 검증 조건이 고정하는 것: "첫 수집이 카드를 부풀리지 않는다"와
/// "TOP 5 항목 수·조사 실패가 순위 자리 높이를 바꾸지 않는다".
/// 상태별로 슬롯을 접는 분기(예: `collecting`일 때 그래프·순위 자리 자체를 그리지 않는 코드)를 되살리면
/// 아래 단언들이 실패해야 합니다.
@MainActor
struct DashboardCardHeightTests {

    // MARK: - CPU 카드

    @Test func cpuCardHeightIsSameRegardlessOfTopApplicationsCount() {
        let heights = [0, 3, 5].map { count in
            measuredHeight(cpuCardView(.normal(cpuPresentation(topApplicationsCount: count), timestamp: baseInstant)))
        }

        #expect(Set(heights).count == 1, "TOP 5 항목 수에 따라 CPU 카드 높이가 달라졌습니다: \(heights)")
    }

    @Test func cpuCardHeightIsSameWhenProcessSurveyFails() {
        let normalHeight = measuredHeight(cpuCardView(.normal(cpuPresentation(topApplicationsCount: 5), timestamp: baseInstant)))
        let failedHeight = measuredHeight(
            cpuCardView(.normal(cpuPresentation(topApplicationsCount: 0, topApplicationsFailed: true), timestamp: baseInstant))
        )

        #expect(normalHeight == failedHeight, "프로세스 조사 실패 tick에서 CPU 카드 높이가 달라졌습니다: 정상 \(normalHeight), 실패 \(failedHeight)")
    }

    /// 이 테스트가 고정하는 것은 "네 상태(수집 중·정상·실패·중지) 모두 같은 슬롯 구성을 그린다"입니다 —
    /// 성공 이력이 없는 실패·중지(`lastKnown: nil`)까지 포함해 비교합니다.
    @Test func cpuCardHeightIsSameAcrossAllFourStates() {
        let presentation = cpuPresentation(topApplicationsCount: 3)
        let lastKnown = LastKnownCardValue(presentation: presentation, timestamp: baseInstant)

        let states: [ResourceCardState<CPUCardPresentation>] = [
            .collecting,
            .normal(presentation, timestamp: baseInstant),
            .failure(lastKnown: nil),
            .failure(lastKnown: lastKnown),
            .stopped(lastKnown: nil),
            .stopped(lastKnown: lastKnown)
        ]

        let heights = states.map { measuredHeight(cpuCardView($0)) }

        #expect(Set(heights).count == 1, "상태에 따라 CPU 카드 높이가 달라졌습니다: \(heights)")
    }

    /// task-004 검증 조건: 요약 둘째 줄에 User·System 계열 스와치를 더해도 카드 높이가 늘지 않습니다.
    /// 스와치 크기는 그 줄의 텍스트 높이를 넘지 않아야 하므로, 비율이 0%·100%로 극단이거나
    /// 자릿수가 늘어(3자리는 아니지만 두 자리 최댓값 99) 텍스트 폭이 달라져도 줄바꿈이 일어나지 않아야 합니다.
    @Test func cpuCardHeightIsSameRegardlessOfUserSystemBandValues() {
        let heights = [(0.0, 0.0), (30.0, 12.0), (99.0, 1.0), (1.0, 99.0)].map { userRatio, systemRatio in
            measuredHeight(cpuCardView(.normal(
                cpuPresentation(topApplicationsCount: 3, userRatio: userRatio, systemRatio: systemRatio),
                timestamp: baseInstant
            )))
        }

        #expect(Set(heights).count == 1, "User·System 비율에 따라 CPU 카드 높이가 달라졌습니다: \(heights)")
    }

    // MARK: - Memory 카드

    @Test func memoryCardHeightIsSameRegardlessOfTopApplicationsCount() {
        let heights = [0, 3, 5].map { count in
            measuredHeight(memoryCardView(.normal(memoryPresentation(topApplicationsCount: count), timestamp: baseInstant)))
        }

        #expect(Set(heights).count == 1, "TOP 5 항목 수에 따라 Memory 카드 높이가 달라졌습니다: \(heights)")
    }

    @Test func memoryCardHeightIsSameWhenProcessSurveyFails() {
        let normalHeight = measuredHeight(memoryCardView(.normal(memoryPresentation(topApplicationsCount: 5), timestamp: baseInstant)))
        let failedHeight = measuredHeight(
            memoryCardView(.normal(memoryPresentation(topApplicationsCount: 0, topApplicationsFailed: true), timestamp: baseInstant))
        )

        #expect(normalHeight == failedHeight, "프로세스 조사 실패 tick에서 Memory 카드 높이가 달라졌습니다: 정상 \(normalHeight), 실패 \(failedHeight)")
    }

    @Test func memoryCardHeightIsSameAcrossAllFourStates() {
        let presentation = memoryPresentation(topApplicationsCount: 3)
        let lastKnown = LastKnownCardValue(presentation: presentation, timestamp: baseInstant)

        let states: [ResourceCardState<MemoryCardPresentation>] = [
            .collecting,
            .normal(presentation, timestamp: baseInstant),
            .failure(lastKnown: nil),
            .failure(lastKnown: lastKnown),
            .stopped(lastKnown: nil),
            .stopped(lastKnown: lastKnown)
        ]

        let heights = states.map { measuredHeight(memoryCardView($0)) }

        #expect(Set(heights).count == 1, "상태에 따라 Memory 카드 높이가 달라졌습니다: \(heights)")
    }

    /// task-006 검증 조건: 가장 긴 Pressure 라벨·가장 긴 Swap 값 조합에서도 Memory 카드 높이가 늘지 않아야 합니다.
    /// 비교 대상은 병합 후 기본 내용과 병합 후 최장 내용이며, 병합 **전** 높이와의 대조는 이 테스트에 없습니다.
    /// 줄 수 제한을 지우는 mutation은 이 높이 단언으로 잡히지 않습니다 —
    /// production 서식이 어떤 바이트 값도 짧은 문자열로 압축해 병합 줄이 콘텐츠 폭을 넘기지 못하므로
    /// 줄바꿈 자체가 일어나지 않습니다. 그 자리는 `maximumLineCountIsOne()`의 상한 상수 단언이 맡습니다.
    @Test func memoryCardHeightIsSameWithLongestPressureSwapLineContent() {
        let mergedDefaultHeight = measuredHeight(memoryCardView(.normal(memoryPresentation(topApplicationsCount: 5), timestamp: baseInstant)))
        let longestHeight = measuredHeight(
            memoryCardView(.normal(memoryPresentationWithLongestPressureSwapLine(), timestamp: baseInstant))
        )

        #expect(mergedDefaultHeight == longestHeight, "가장 긴 Pressure·Swap 병합 줄 내용에서 Memory 카드 높이가 달라졌습니다: 기본 \(mergedDefaultHeight), 최댓값 \(longestHeight)")
    }

    /// task-007 검증 조건: 구성 누적 바와 범례 줄을 더한 뒤에도 Memory 카드 렌더 높이가 더하기 전과 같아야 합니다.
    /// 기준값 181.0은 바·범례를 넣기 전 같은 조건(폭 280 − 32, 항목 0개, 정상 상태)에서 실측한 값입니다.
    /// 바 높이를 제목 텍스트 높이보다 크게 잡는 mutation(8 → 30)이 이 단언에서 실패하는 것을 확인했습니다.
    ///
    /// 범례를 두 줄로 만드는 mutation은 이 높이 단언으로 잡히지 않습니다 —
    /// 범례가 축소 없이 한 줄에 들어가는 크기라 줄 수 상한을 2로 바꿔도 줄바꿈 자체가 일어나지 않습니다(실측 확인).
    /// 그 자리는 `maximumLineCountIsOne()`이 맡습니다.
    @Test func memoryCardHeightMatchesBaselineBeforeCompositionBarAndLegend() {
        let height = measuredHeight(memoryCardView(.normal(memoryPresentation(topApplicationsCount: 0), timestamp: baseInstant)))

        #expect(height == 181.0, "구성 바·범례를 더한 뒤 Memory 카드 높이가 기준값 181.0에서 \(height)로 달라졌습니다")
    }

    // MARK: - 순위 행 아이콘

    /// task-010 검증 조건: 아이콘이 있는 경우·없는 경우·조사 실패 경우의 카드 렌더 높이가 서로 같아야 합니다.
    /// 아이콘이 있는 행에만 자리를 두거나 중립 기호 자리를 없애는 mutation은 이 단언이 아니라
    /// `ApplicationRowIconTests`의 자리 크기 단언이 잡습니다 — 여기서 잡는 것은
    /// "아이콘 자리가 카드 높이를 늘리지 않는다"입니다.
    @Test func cardHeightIsSameRegardlessOfRowIconAvailability() {
        let cpuState = ResourceCardState.normal(cpuPresentation(topApplicationsCount: 5), timestamp: baseInstant)
        let cpuFailedState = ResourceCardState.normal(
            cpuPresentation(topApplicationsCount: 0, topApplicationsFailed: true),
            timestamp: baseInstant
        )
        let cpuHeights = [
            measuredHeight(cpuCardView(cpuState, iconProvider: allIconsProvider(count: 5))),
            measuredHeight(cpuCardView(cpuState)),
            measuredHeight(cpuCardView(cpuFailedState))
        ]

        #expect(Set(cpuHeights).count == 1, "아이콘 유무·조사 실패에 따라 CPU 카드 높이가 달라졌습니다: \(cpuHeights)")

        let memoryState = ResourceCardState.normal(memoryPresentation(topApplicationsCount: 5), timestamp: baseInstant)
        let memoryFailedState = ResourceCardState.normal(
            memoryPresentation(topApplicationsCount: 0, topApplicationsFailed: true),
            timestamp: baseInstant
        )
        let memoryHeights = [
            measuredHeight(memoryCardView(memoryState, iconProvider: allIconsProvider(count: 5))),
            measuredHeight(memoryCardView(memoryState)),
            measuredHeight(memoryCardView(memoryFailedState))
        ]

        #expect(Set(memoryHeights).count == 1, "아이콘 유무·조사 실패에 따라 Memory 카드 높이가 달라졌습니다: \(memoryHeights)")
    }

    /// task-010 검증 조건: 아이콘을 더한 뒤에도 두 카드의 렌더 높이가 아이콘 전 실측값과 같아야 합니다.
    /// 기준값 243.0·181.0은 행 아이콘을 넣기 전 같은 조건(폭 280 − 32, 정상 상태, 순위 항목 0개)에서 실측한 값이고,
    /// 항목 수가 높이를 바꾸지 않는다는 것은 위 `…RegardlessOfTopApplicationsCount` 단언이 잇습니다.
    /// 여기서는 순위 항목 5개에 아이콘을 모두 채운 상태로 재므로, 그려진 아이콘이 줄 높이를 밀어 올리는지까지 걸립니다.
    @Test func cardHeightsMatchBaselineBeforeRowIcons() {
        let provider = allIconsProvider(count: 5)
        let cpuHeight = measuredHeight(
            cpuCardView(.normal(cpuPresentation(topApplicationsCount: 5), timestamp: baseInstant), iconProvider: provider)
        )
        let memoryHeight = measuredHeight(
            memoryCardView(.normal(memoryPresentation(topApplicationsCount: 5), timestamp: baseInstant), iconProvider: provider)
        )

        #expect(cpuHeight == 243.0, "행 아이콘을 더한 뒤 CPU 카드 높이가 기준값 243.0에서 \(cpuHeight)로 달라졌습니다")
        #expect(memoryHeight == 181.0, "행 아이콘을 더한 뒤 Memory 카드 높이가 기준값 181.0에서 \(memoryHeight)로 달라졌습니다")
    }
}

/// task-007 검증 조건: 카드 병합 줄에 그려지는 수치가 「사용 중」이 아니라 구성 합계인지 확인합니다.
@MainActor
struct MemoryCardCompositionTotalRenderingTests {

    /// 병합 줄이 카드에서 가장 넓은 줄이 되도록 Swap을 크게 잡습니다 —
    /// 그래야 줄 안의 구성 합계 문자열 길이가 카드 전체의 필요 너비에 드러납니다.
    private func presentation(appBytes: UInt64) -> MemoryCardPresentation {
        MemoryCardPresentation.assemble(
            memory: memoryMetrics(swapUsedBytes: 999_000_000_000, pressureLevel: .critical, appBytes: appBytes),
            history: [
                swapHistoryPoint(secondsFromBase: 0, swapUsedBytes: 0),
                swapHistoryPoint(secondsFromBase: 15, swapUsedBytes: 500_000_000_000)
            ],
            topApplications: rankingEntries(count: 5),
            currentTimestamp: baseInstant.advanced(by: .seconds(30))
        )
    }

    /// 「사용 중」·Swap·Pressure·순위가 모두 같고 구성 바이트만 다른 두 카드는
    /// 병합 줄에 서로 다른 구성 합계 문자열을 그리므로 필요한 너비가 달라집니다.
    /// 뷰가 구성 합계 대신 「사용 중」을 그리거나 합계 요소를 통째로 빼면 두 너비가 같아져 실패합니다.
    @Test func cardWidthFollowsCompositionTotalRatherThanUsedBytes() {
        let small = measuredIdealWidth(memoryCardView(.normal(presentation(appBytes: 1024 * 1024), timestamp: baseInstant)))
        let large = measuredIdealWidth(memoryCardView(.normal(presentation(appBytes: 12 * 1024 * 1024 * 1024), timestamp: baseInstant)))

        #expect(small != large)
    }
}

/// task-007 검증 조건: 카드에 구성 누적 바가 실제로 그려지는지 확인합니다.
@MainActor
struct MemoryCardCompositionBarRenderingTests {

    /// 구성 합계는 같고 항목 분포만 다른 두 표시 값. 합계가 같아 병합 줄 문자열도 같으므로,
    /// 두 카드의 그림이 갈리는 자리는 구성 바의 구간뿐입니다.
    private func presentation(app: UInt64, cached: UInt64) -> MemoryCardPresentation {
        MemoryCardPresentation.assemble(
            memory: memoryMetrics(appBytes: app, cachedBytes: cached),
            history: [],
            topApplications: rankingEntries(count: 5),
            currentTimestamp: baseInstant
        )
    }

    /// 바를 카드에서 통째로 지우거나 구간을 그리지 않게 하면 두 그림이 같아져 실패합니다 —
    /// 렌더 높이·너비 단언으로는 잡히지 않는 자리입니다(바 높이 8pt가 제목 텍스트 높이 안에 들어가고,
    /// 바의 너비는 제목 줄의 남는 폭이라 카드 크기에 드러나지 않습니다).
    @Test func cardDrawsCompositionSegments() throws {
        let appHeavy = presentation(app: 8 * 1024 * 1024 * 1024, cached: 0)
        let cacheHeavy = presentation(app: 0, cached: 8 * 1024 * 1024 * 1024)

        try #require(appHeavy.compositionTotalBytes == cacheHeavy.compositionTotalBytes)

        let appHeavyPixels = try #require(renderedPixels(memoryCardView(.normal(appHeavy, timestamp: baseInstant))))
        let cacheHeavyPixels = try #require(renderedPixels(memoryCardView(.normal(cacheHeavy, timestamp: baseInstant))))

        #expect(appHeavyPixels != cacheHeavyPixels)
    }
}
