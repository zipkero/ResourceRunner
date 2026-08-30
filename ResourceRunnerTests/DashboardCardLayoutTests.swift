//
//  DashboardCardLayoutTests.swift
//  ResourceRunnerTests
//
//  task-015·task-011 검증 조건: 카드 상태별 렌더 높이와 새 표시 요소의 값 없음 자리표시를 확인합니다.
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

/// 카드 전체 합산이 아니라 슬롯별 픽셀만 세기 위한 영역입니다.
/// `ImageRenderer.scale = 1`이고 카드 너비가 248pt로 고정되어 있어 pt와 픽셀이 일치합니다.
private struct CardPixelRegion {
    let x: Range<Int>
    let y: Range<Int>

    static let cpuPlaceholderSummary = CardPixelRegion(x: 0..<248, y: 42..<57)
    static let cpuPlaceholderGraph = CardPixelRegion(x: 0..<248, y: 60..<124)
    static let memoryPlaceholderTrack = CardPixelRegion(x: 210..<238, y: 11..<19)
    static let cpuFirstRankingIcon = CardPixelRegion(x: 8..<20, y: 129..<141)
}

/// 카드 배경(`.quaternary`, 알파 25/255)보다 진한 픽셀만 고릅니다.
private let opaquerThanCardBackground: (NSColor) -> Bool = { $0.alphaComponent > 0.12 }

/// 주어진 색조 범위의 채도 있는 픽셀만 고릅니다. 계열 스와치처럼 색으로 구분되는 요소에 씁니다.
private func swatchHue(_ hueRange: ClosedRange<CGFloat>) -> (NSColor) -> Bool {
    { color in
        color.alphaComponent > 0.1
            && color.saturationComponent > 0.35
            && hueRange.contains(color.hueComponent)
    }
}

/// 값이 없는 상태에서도 카드에 남아 있어야 하는 새 표시 요소 하나와, 그것이 실제로 그려졌는지 보는 수단.
///
/// 요소마다 수단이 다릅니다 — 색으로 구분되는 요소는 렌더 픽셀을 세고, 무채색이거나 좁아 다른 텍스트에
/// 가려지는 요소는 그 요소가 붙어 있는 줄의 이상적 폭을 잽니다.
///
/// 이 목록에 없는 요소는 값 없음 경로에서 어떤 단언도 덮지 않습니다.
/// 줄 조립 배열에서 파생되는 항목(요약 줄·구성 범례 줄·병합 줄 자리표시)은 배열에 조각이 늘면 항목도 함께 늘고,
/// 그 밖의 요소를 카드에 새로 더할 때는 여기에 직접 더해야 합니다.
private struct NewElementProbe<Card> {
    let name: String
    /// 값 없음 상태의 카드와 그 카드를 그린 픽셀을 받아, 요소가 그려졌으면 `nil`을,
    /// 아니면 무엇이 어긋났는지 돌려줍니다.
    let failure: @MainActor (Card, Data) -> String?
}

extension NewElementProbe {
    /// 색으로 구분되는 요소용. 그 자리에 조건을 만족하는 픽셀이 하나도 없으면 실패입니다.
    static func pixels(
        _ name: String,
        in region: CardPixelRegion,
        matching predicate: @escaping (NSColor) -> Bool
    ) -> Self {
        Self(name: name) { _, pixels in
            pixelCount(in: pixels, region: region, matching: predicate) > 0
                ? nil
                : "자리에 그려진 픽셀이 하나도 없습니다"
        }
    }

    /// 픽셀로 가려지는 텍스트 요소용. 두 가지를 함께 봅니다 —
    /// production 줄의 이상적 폭이 모든 조각을 담은 기준 조립과 같아야 하고(요소가 빠지면 여기서 갈립니다),
    /// 기준 조립에서 이 요소만 뺀 폭이 그보다 작아야 합니다(그 등식이 이 요소에 실제로 반응함을 같은 자리에서 보입니다).
    static func lineWidth(
        _ name: String,
        of line: @escaping @MainActor (Card) -> CGFloat,
        fullReference: @escaping @MainActor () -> CGFloat,
        withoutElement: @escaping @MainActor () -> CGFloat
    ) -> Self {
        Self(name: name) { card, _ in
            let full = fullReference()
            let without = withoutElement()
            guard without < full else {
                return "기준 조립에서 이 요소를 빼도 줄 폭이 \(full)에서 \(without)으로 줄지 않아, 폭 등식이 이 요소를 잡지 못합니다"
            }
            let measured = line(card)
            guard measured == full else {
                return "줄의 이상적 폭이 \(measured)로, 모든 조각을 담은 기준 \(full)와 다릅니다"
            }
            return nil
        }
    }

    /// 순위 자리용. 카드가 실제로 넘긴 항목·정원 그대로 줄을 하나씩 꺼내, 모든 줄이 아이콘 자리를
    /// 내용 앞에 그대로 두는지 잽니다 — 슬롯 전체의 이상적 폭은 가장 넓은 한 줄만 드러냅니다.
    static func rankingRowIconSlots(
        _ name: String,
        slot: @escaping @MainActor (Card) -> CardRankingSlotView
    ) -> Self {
        Self(name: name) { card, _ in
            let capacity = ApplicationRankingSampling.cardDisplayCount
            let reservedSlotWidth = ApplicationRowIconLayout.cardPointSize + CardRankingSlotView.iconSpacing
            let blankContentWidth = measuredIdealWidth(Text(" ").opacity(0).font(.caption))
            let cardSlot = slot(card)
            let iconKeys = ApplicationRowIconLayout.cardRowIconKeys(
                entries: cardSlot.entries,
                failed: cardSlot.failed,
                capacity: capacity
            )
            guard iconKeys.count == capacity else {
                return "순위 자리의 줄 수가 \(iconKeys.count)로 정원 \(capacity)와 다릅니다"
            }
            for (index, iconKey) in iconKeys.enumerated() {
                let rowWidth = measuredIdealWidth(cardSlot.row(at: index, iconKey: iconKey).font(.caption))
                guard rowWidth == blankContentWidth + reservedSlotWidth else {
                    return "\(index)번째 줄의 이상적 폭이 \(rowWidth)로, 자리표시 내용 + 아이콘 자리 \(blankContentWidth + reservedSlotWidth)와 다릅니다"
                }
            }
            return nil
        }
    }
}

/// 값 없음 CPU 요약 줄의 조각 하나. 기준 조립에서 조각 하나만 빼는 데 씁니다.
private enum CPUSummaryPlaceholderPiece: Equatable {
    case separator(entryIndex: Int)
    case swatch(entryIndex: Int)
    case valueText(entryIndex: Int)
}

/// 값 없음 CPU 요약 줄의 기준 조립 폭. production의 자리표시 분기와 같은 구조·같은 간격으로 그립니다.
@MainActor
private func cpuSummaryPlaceholderWidth(dropping dropped: CPUSummaryPlaceholderPiece? = nil) -> CGFloat {
    measuredIdealWidth(
        HStack(spacing: CPUSeriesPlaceholderLayout.spacing) {
            ForEach(Array(CPUSeriesPlaceholderLayout.entries.enumerated()), id: \.offset) { index, entry in
                if index > 0, dropped != .separator(entryIndex: index) {
                    Text("·")
                }
                if dropped != .swatch(entryIndex: index) {
                    CPUSeriesSwatchView(band: entry.band)
                }
                if dropped != .valueText(entryIndex: index) {
                    Text("\(entry.label) \(entry.valueText)")
                }
            }
        }
        .font(.caption)
    )
}

/// Memory 구성 범례 줄의 기준 조립 폭. production과 같은 순서로 같은 조각을 이어붙입니다.
@MainActor
private func memoryCompositionLegendWidth(droppingSegmentAt dropped: Int? = nil) -> CGFloat {
    let line = MemoryCompositionLegendFormatting.segments.enumerated().reduce(Text("")) { line, pair in
        guard pair.offset != dropped else { return line }
        switch pair.element {
        case .swatch(let category):
            return line + Text(Image(systemName: "square.fill"))
                .foregroundStyle(DashboardColorPalette.memoryComposition(category))
        case .label(let text):
            return line + Text(" \(text)")
        case .separator:
            return line + Text("  ")
        }
    }

    return measuredIdealWidth(
        line
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(MemoryCompositionLegendFormatting.maximumLineCount)
    )
}

/// 값 없음 Pressure·Swap 병합 줄의 기준 조립 폭. production과 같은 순서로 같은 조각을 이어붙입니다.
@MainActor
private func memoryPressureSwapPlaceholderWidth(droppingSegmentAt dropped: Int? = nil) -> CGFloat {
    let line = MemoryPressureSwapLineFormatting.placeholder.enumerated().reduce(Text("")) { line, pair in
        guard pair.offset != dropped else { return line }
        switch pair.element {
        case .symbol(let name):
            return line + Text(Image(systemName: name))
        case .label(let text):
            return line + Text(" \(text)")
        case .separator:
            return line + Text(" · ")
        case .swapUsage(let text):
            return line + Text("Swap \(text)")
        case .swapChange(let text):
            return line + Text(" (\(text))")
        case .compositionTotal(let text):
            return line + Text("구성 \(text)")
        }
    }

    return measuredIdealWidth(
        line
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(MemoryPressureSwapLineFormatting.maximumLineCount)
    )
}

private func legendPieceName(_ segment: MemoryCompositionLegendSegment, at index: Int) -> String {
    switch segment {
    case .swatch(let category): return "\(category.label) 색 스와치"
    case .label(let text): return "「\(text)」 이름"
    case .separator: return "\(index)번째 항목 사이 간격"
    }
}

private func pressureSwapPieceName(_ segment: MemoryPressureSwapLineSegment, at index: Int) -> String {
    switch segment {
    case .symbol(let name): return "자리표시 기호 「\(name)」"
    case .label(let text): return "자리표시 라벨 「\(text)」"
    default: return "\(index)번째 자리표시 조각"
    }
}

/// task-011이 「새 표시 요소」로 정의한 것 전부 — 그래프 2계열·격자, 구성 바·범례, 병합 줄, 행 아이콘 —
/// 을 값 없음 상태에서 하나씩 확인하는 목록입니다.
/// 제목 줄 텍스트·단축키 줄·순위 caption은 core-resource-monitoring이 만든 기존 요소라 여기에 없습니다.
@MainActor
private enum NewDisplayElement {

    static let cpu: [NewElementProbe<CPUCardView>] =
        cpuSummaryLine + [
            .pixels("CPU User 계열 스와치 색", in: .cpuPlaceholderSummary, matching: swatchHue(0.52...0.68)),
            .pixels("CPU System 계열 스와치 색", in: .cpuPlaceholderSummary, matching: swatchHue(0.0...0.12)),
            .pixels("CPU 그래프 격자", in: .cpuPlaceholderGraph, matching: opaquerThanCardBackground),
            .rankingRowIconSlots("CPU 순위 줄 아이콘 자리", slot: { $0.rankingSlot })
        ]

    static let memory: [NewElementProbe<MemoryCardView>] =
        [.pixels("Memory 구성 바 트랙", in: .memoryPlaceholderTrack, matching: opaquerThanCardBackground)]
        + memoryPressureSwapLine
        + memoryCompositionLegendLine
        + [.rankingRowIconSlots("Memory 순위 줄 아이콘 자리", slot: { $0.rankingSlot })]

    /// 요약 줄은 계열마다 구분자·스와치·텍스트 세 조각을 그리므로 항목도 계열별로 만듭니다.
    private static let cpuSummaryLine: [NewElementProbe<CPUCardView>] =
        CPUSeriesPlaceholderLayout.entries.enumerated().flatMap { index, entry -> [NewElementProbe<CPUCardView>] in
            let pieces: [(String, CPUSummaryPlaceholderPiece)] =
                (index > 0 ? [("\(entry.label) 앞 구분자", .separator(entryIndex: index))] : [])
                + [
                    ("\(entry.label) 스와치 자리", .swatch(entryIndex: index)),
                    ("「\(entry.label) \(entry.valueText)」 텍스트", .valueText(entryIndex: index))
                ]

            return pieces.map { name, piece in
                .lineWidth(
                    "CPU 요약 줄 \(name)",
                    of: { measuredIdealWidth($0.secondaryLine) },
                    fullReference: { cpuSummaryPlaceholderWidth() },
                    withoutElement: { cpuSummaryPlaceholderWidth(dropping: piece) }
                )
            }
        }

    private static let memoryCompositionLegendLine: [NewElementProbe<MemoryCardView>] =
        MemoryCompositionLegendFormatting.segments.enumerated().map { index, segment in
            .lineWidth(
                "Memory 구성 범례 줄 \(legendPieceName(segment, at: index))",
                of: { measuredIdealWidth($0.compositionLegendLine) },
                fullReference: { memoryCompositionLegendWidth() },
                withoutElement: { memoryCompositionLegendWidth(droppingSegmentAt: index) }
            )
        }

    private static let memoryPressureSwapLine: [NewElementProbe<MemoryCardView>] =
        MemoryPressureSwapLineFormatting.placeholder.enumerated().map { index, segment in
            .lineWidth(
                "Memory 병합 줄 \(pressureSwapPieceName(segment, at: index))",
                of: { measuredIdealWidth($0.pressureSwapLine) },
                fullReference: { memoryPressureSwapPlaceholderWidth() },
                withoutElement: { memoryPressureSwapPlaceholderWidth(droppingSegmentAt: index) }
            )
        }
}

private func pixelCount(
    in renderedPixels: Data,
    region: CardPixelRegion,
    matching predicate: (NSColor) -> Bool
) -> Int {
    guard let bitmap = NSBitmapImageRep(data: renderedPixels) else { return 0 }

    return region.y.reduce(into: 0) { count, y in
        for x in region.x {
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
            if predicate(color) {
                count += 1
            }
        }
    }
}

private func differingPixelCount(
    between lhsPixels: Data,
    and rhsPixels: Data,
    region: CardPixelRegion
) -> Int {
    guard
        let lhs = NSBitmapImageRep(data: lhsPixels),
        let rhs = NSBitmapImageRep(data: rhsPixels),
        lhs.pixelsWide == rhs.pixelsWide,
        lhs.pixelsHigh == rhs.pixelsHigh
    else { return 0 }

    return region.y.reduce(into: 0) { count, y in
        for x in region.x where lhs.colorAt(x: x, y: y) != rhs.colorAt(x: x, y: y) {
            count += 1
        }
    }
}

/// 아이콘 뷰가 실제 카드 행에서 이미지를 그리는지 확인할 때 쓰는 단색 이미지 제공자입니다.
/// 두 제공자는 이미지 색만 다르므로 카드 렌더 차이는 아이콘 자리 안에서만 생깁니다.
@MainActor
private func solidIconProvider(color: NSColor) -> StubApplicationIconProvider {
    let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
        color.setFill()
        rect.fill()
        return true
    }
    let key = rankingEntries(count: 1)[0].key
    return StubApplicationIconProvider(images: [key: image])
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
        let heights = (0...5).map { count in
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
        let heights = (0...5).map { count in
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

    /// 병합 줄과 구성 범례 줄은 폭이 모자라도 줄바꿈 대신 끝에서 잘려야 합니다(ANALYSIS §5 DP4, SPEC §5.8).
    /// 상한 상수만 단언하는 `maximumLineCountIsOne()`은 뷰에서 `.lineLimit` 호출 자체를 지우는 변경을 잡지 못하고,
    /// 카드 폭(248pt)에서는 두 줄 모두 넉넉히 들어가 줄바꿈이 일어나지 않아 카드 높이 단언에도 걸리지 않습니다.
    /// 그래서 줄이 확실히 넘치는 좁은 폭에서 재어, 넘쳐도 높이가 늘지 않는지를 봅니다.
    @Test func pressureSwapAndCompositionLegendLinesTruncateInsteadOfWrapping() {
        let card = memoryCardView(.normal(memoryPresentationWithLongestPressureSwapLine(), timestamp: baseInstant))
        let narrowWidth: CGFloat = 40

        let pressureSwapHeight = measuredHeight(card.pressureSwapLine, width: narrowWidth)
        #expect(
            pressureSwapHeight == measuredHeight(card.pressureSwapLine),
            "좁은 폭에서 Pressure·Swap 병합 줄이 \(pressureSwapHeight)로 늘어 줄바꿈이 일어났습니다"
        )

        let legendHeight = measuredHeight(card.compositionLegendLine, width: narrowWidth)
        #expect(
            legendHeight == measuredHeight(card.compositionLegendLine),
            "좁은 폭에서 구성 범례 줄이 \(legendHeight)로 늘어 줄바꿈이 일어났습니다"
        )
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

    /// 새 표시 요소가 모두 있는 정상 상태와 값이 없는 세 상태, 캐시를 쓰는 실패·중지 상태가
    /// 각각 변경 전 기준 높이를 지키는지 한 번에 고정합니다.
    @Test func cardHeightsMatchBaselinesAcrossEveryStateWithNewElements() {
        let cpuPresentation = cpuPresentation(topApplicationsCount: 5)
        let cpuLastKnown = LastKnownCardValue(presentation: cpuPresentation, timestamp: baseInstant)
        let cpuProvider = allIconsProvider(count: 5)
        let cpuStates: [ResourceCardState<CPUCardPresentation>] = [
            .collecting,
            .normal(cpuPresentation, timestamp: baseInstant),
            .failure(lastKnown: nil),
            .failure(lastKnown: cpuLastKnown),
            .stopped(lastKnown: nil),
            .stopped(lastKnown: cpuLastKnown)
        ]
        let cpuHeights = cpuStates.map { measuredHeight(cpuCardView($0, iconProvider: cpuProvider)) }

        #expect(cpuHeights.allSatisfy { $0 == 243.0 }, "CPU 카드 상태별 높이가 기준값 243.0과 다릅니다: \(cpuHeights)")

        let memoryPresentation = memoryPresentationWithLongestPressureSwapLine()
        let memoryLastKnown = LastKnownCardValue(presentation: memoryPresentation, timestamp: baseInstant)
        let memoryProvider = allIconsProvider(count: 5)
        let memoryStates: [ResourceCardState<MemoryCardPresentation>] = [
            .collecting,
            .normal(memoryPresentation, timestamp: baseInstant),
            .failure(lastKnown: nil),
            .failure(lastKnown: memoryLastKnown),
            .stopped(lastKnown: nil),
            .stopped(lastKnown: memoryLastKnown)
        ]
        let memoryHeights = memoryStates.map { measuredHeight(memoryCardView($0, iconProvider: memoryProvider)) }

        #expect(memoryHeights.allSatisfy { $0 == 181.0 }, "Memory 카드 상태별 높이가 기준값 181.0과 다릅니다: \(memoryHeights)")
    }
}

/// 렌더 높이만으로 보이지 않는 값 없음 자리의 실제 그리기 계약을 고정합니다.
@MainActor
struct DashboardCardPlaceholderRenderingTests {

    /// CPU 값이 없을 때도 두 계열 스와치와 이름은 남고, 수치는 0이 아닌 중립 기호로 표시됩니다.
    @Test func cpuSeriesPlaceholderKeepsBothSwatchesWithoutInventingZeroValues() {
        #expect(CPUSeriesPlaceholderLayout.entries == [
            .init(band: .lower, label: "User", valueText: "–"),
            .init(band: .upper, label: "System", valueText: "–")
        ])
    }

    /// 값이 없는 세 상태(수집 중·성공 이력 없는 실패·중지)가 **새 표시 요소 전부**를 실제로 그리는지
    /// 상태 × 요소로 순회하며 확인합니다.
    ///
    /// 배열·앵커는 그대로 두고 순회 안에서 요소 하나만 조건부로 빼는 변경이 여기서 잡힙니다 —
    /// 그런 변경은 카드 렌더 높이를 바꾸지 않아 크기 단언에는 걸리지 않고, 무채색 텍스트 요소는
    /// 픽셀로도 다른 텍스트에 가려집니다. 한 상태에서만 요소를 비우는 변경은 상태 순회가 잡습니다.
    @Test func everyValuelessStateRendersEveryNewDisplayElement() throws {
        let cpuStates: [ResourceCardState<CPUCardPresentation>] = [
            .collecting,
            .failure(lastKnown: nil),
            .stopped(lastKnown: nil)
        ]
        for state in cpuStates {
            let card = cpuCardView(state)
            let pixels = try #require(renderedPixels(card))
            for element in NewDisplayElement.cpu {
                let failure = element.failure(card, pixels)
                #expect(failure == nil, "값 없음 CPU 카드(\(state))의 \(element.name) — \(failure ?? "")")
            }
        }

        let memoryStates: [ResourceCardState<MemoryCardPresentation>] = [
            .collecting,
            .failure(lastKnown: nil),
            .stopped(lastKnown: nil)
        ]
        for state in memoryStates {
            let card = memoryCardView(state)
            let pixels = try #require(renderedPixels(card))
            for element in NewDisplayElement.memory {
                let failure = element.failure(card, pixels)
                #expect(failure == nil, "값 없음 Memory 카드(\(state))의 \(element.name) — \(failure ?? "")")
            }
        }
    }

    /// 그래프 슬롯만 따로 보아 격자 외에 채도 있는 값 선·점이 들어오지 않았음을 확인합니다.
    /// 요약 줄 스와치가 있든 없든 이 영역 밖이므로 결과를 가릴 수 없습니다.
    @Test func cpuGraphPlaceholderDoesNotRenderInventedZeroValues() throws {
        let pixels = try #require(renderedPixels(cpuCardView(.collecting)))
        let valuePixels = pixelCount(in: pixels, region: .cpuPlaceholderGraph) { color in
            color.alphaComponent > 0.1 && color.saturationComponent > 0.35
        }

        #expect(valuePixels == 0, "값 없음 CPU 카드의 그래프 자리에 0 값으로 읽히는 선이나 점이 그려졌습니다")
    }

    /// Memory 값이 없으면 구성 바는 트랙만 그리고, 구간은 길이 0 네 개조차 만들지 않습니다.
    /// 20% 구간 넷처럼 지어낸 비율을 넣는 변경도 빈 배열 단언에서 함께 실패합니다.
    @Test func memoryCompositionPlaceholderDrawsOnlyTrackWithoutSegments() {
        #expect(MemoryCompositionBarLayout.placeholderSegments.isEmpty)
        #expect(MemoryCompositionBarLayout.layers(for: MemoryCompositionBarLayout.placeholderSegments) == [.track])
    }

    /// 값 없음 트랙은 투명한 같은 크기 자리와 렌더 픽셀이 달라야 합니다.
    /// 트랙 그리기를 비우고 높이만 남기는 변경은 크기 단언으로 보이지 않지만 이 비교에서 실패합니다.
    @Test func memoryCompositionPlaceholderTrackIsActuallyRendered() throws {
        let trackPixels = try #require(renderedPixels(
            MemoryCompositionBarView(segments: MemoryCompositionBarLayout.placeholderSegments)
        ))
        let clearPixels = try #require(renderedPixels(Color.clear.frame(height: 8)))

        #expect(trackPixels != clearPixels)
    }

    /// 순위 한 줄의 요소 순서. 이 배열은 순서만 고정하므로, 줄마다 요소가 실제로 그려지는지는
    /// 아래 `every…CardRankingRowReservesTheSameIconSlot()`이 줄을 하나씩 재서 확인합니다.
    @Test func cardRankingRowsKeepIconSlotBeforeContent() {
        #expect(CardRankingRowLayout.elements == [.icon, .content])
    }

    /// 투명한 `.reserved` 아이콘은 픽셀로 보이지 않으므로 행의 이상적 폭을 잽니다.
    /// 슬롯 전체의 이상적 폭은 가장 넓은 한 줄만 드러내 일부 줄의 자리 손실을 가리므로,
    /// 정원만큼의 줄을 **하나씩** 꺼내 값 없음 줄과 조사 실패 줄 모두 내용 앞에
    /// 12pt 아이콘 자리와 4pt 간격을 그대로 두는지 확인합니다.
    @Test func everyValuelessCardRankingRowReservesTheSameIconSlot() {
        let capacity = ApplicationRankingSampling.cardDisplayCount
        let reservedSlotWidth = ApplicationRowIconLayout.cardPointSize + CardRankingSlotView.iconSpacing
        let blankContentWidth = measuredIdealWidth(Text(" ").opacity(0).font(.caption))
        let failedContentWidth = measuredIdealWidth(Text("TOP \(capacity) 조사 실패").font(.caption))

        for failed in [false, true] {
            let slot = CardRankingSlotView(
                entries: [],
                failed: failed,
                caption: "",
                valueText: { _ in "" },
                iconProvider: StubApplicationIconProvider()
            )
            let iconKeys = ApplicationRowIconLayout.cardRowIconKeys(entries: [], failed: failed, capacity: capacity)

            for (index, iconKey) in iconKeys.enumerated() {
                let contentWidth = failed && index == 0 ? failedContentWidth : blankContentWidth
                let rowWidth = measuredIdealWidth(slot.row(at: index, iconKey: iconKey).font(.caption))

                #expect(
                    rowWidth == contentWidth + reservedSlotWidth,
                    "조사 실패 \(failed) 카드의 \(index)번째 순위 줄이 아이콘 자리를 잃었습니다: \(rowWidth), 기대 \(contentWidth + reservedSlotWidth)"
                )
            }
        }
    }

    /// 값이 있는 줄도 같은 방식으로 하나씩 잽니다. 이름·값이 모든 줄에서 같으므로 줄 사이에 남는 차이는
    /// 아이콘 자리뿐이고, 아이콘 자리는 내용 앞에 12pt와 4pt 간격으로 붙어 있어야 합니다.
    @Test func everyFilledCardRankingRowReservesTheSameIconSlot() {
        let capacity = ApplicationRankingSampling.cardDisplayCount
        let reservedSlotWidth = ApplicationRowIconLayout.cardPointSize + CardRankingSlotView.iconSpacing
        let entries = (0..<capacity).map { index in
            ApplicationRankingEntry(
                key: ApplicationKey(value: "/Applications/Same\(index).app"),
                displayName: "Same",
                value: 1
            )
        }
        let images = entries.reduce(into: [ApplicationKey: NSImage]()) { result, entry in
            result[entry.key] = NSImage(size: NSSize(width: 16, height: 16))
        }
        let slot = CardRankingSlotView(
            entries: entries,
            failed: false,
            caption: "",
            valueText: { _ in "1%" },
            iconProvider: StubApplicationIconProvider(images: images)
        )
        let iconKeys = ApplicationRowIconLayout.cardRowIconKeys(entries: entries, failed: false, capacity: capacity)
        // 아이콘 자리를 뺀 나머지가 production 줄에서 차지하는 폭. `rowContent(at:)`가 HStack에 그대로
        // 펼쳐지므로 같은 간격의 HStack으로 견줍니다.
        let contentWidth = measuredIdealWidth(
            HStack(spacing: CardRankingSlotView.iconSpacing) {
                Text("Same")
                Spacer()
                Text("1%")
            }
            .font(.caption)
        )

        for (index, iconKey) in iconKeys.enumerated() {
            let rowWidth = measuredIdealWidth(slot.row(at: index, iconKey: iconKey).font(.caption))

            #expect(
                rowWidth == contentWidth + reservedSlotWidth,
                "값이 있는 \(index)번째 순위 줄이 아이콘 자리를 잃었습니다: \(rowWidth), 기대 \(contentWidth + reservedSlotWidth)"
            )
        }
    }

    /// 배열 앵커뿐 아니라 값이 있는 카드 첫 행의 아이콘 자리를 실제로 렌더합니다.
    /// 입력 이미지 색만 다른 두 카드의 해당 영역이 같다면 아이콘 뷰가 이미지를 그리지 않은 것입니다.
    @Test func cardRankingRowActuallyRendersProvidedIconInItsSlot() throws {
        let state = ResourceCardState.normal(cpuPresentation(topApplicationsCount: 1), timestamp: baseInstant)
        let redPixels = try #require(renderedPixels(cpuCardView(state, iconProvider: solidIconProvider(color: .systemRed))))
        let bluePixels = try #require(renderedPixels(cpuCardView(state, iconProvider: solidIconProvider(color: .systemBlue))))

        #expect(
            differingPixelCount(between: redPixels, and: bluePixels, region: .cpuFirstRankingIcon) > 0,
            "CPU 카드 첫 순위 행의 아이콘 자리에 제공된 이미지가 실제로 그려지지 않았습니다"
        )
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
