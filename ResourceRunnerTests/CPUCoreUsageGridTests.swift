//
//  CPUCoreUsageGridTests.swift
//  ResourceRunnerTests
//
//  task-002 검증 조건: 코어 칸을 막대·수치·번호로 그리는 격자를 직접 렌더해 잽니다.
//

import AppKit
import SwiftUI
import Testing
@testable import ResourceRunner

private let baseInstant = ContinuousClock().now

/// 상세 팝업의 콘텐츠 폭. 팝업 400pt에서 `.padding()` 기본값 좌우 16pt씩을 뺀 값이라
/// production이 격자에 실제로 주는 폭과 같습니다.
private let detailPopupWidth: CGFloat = 400
private let detailContentWidth: CGFloat = detailPopupWidth - 32

/// 코어 수만큼 서로 다른 사용률을 만듭니다. 값이 겹치면 칸별 채움 높이 단언이 순서를 가리지 못합니다.
private func distinctUsages(coreCount: Int) -> [Double] {
    (0..<coreCount).map { Double($0 * 100 / max(coreCount - 1, 1)) }
}

private func cpuPresentation(coreUsages: [Double]) -> CPUCardPresentation {
    CPUCardPresentation.assemble(
        cpu: CPUSystemMetrics(
            overallUsage: 42,
            userRatio: 30,
            systemRatio: 12,
            idleRatio: 58,
            coreUsages: coreUsages,
            loadAverage: LoadAverage(oneMinute: 1.5, fiveMinutes: 1.25, fifteenMinutes: 1)
        ),
        history: [],
        topApplications: [],
        currentTimestamp: baseInstant
    )
}

@MainActor
private func cpuDetailView(coreUsages: [Double]) -> CPUDetailView {
    CPUDetailView(presentation: cpuPresentation(coreUsages: coreUsages), iconProvider: StubApplicationIconProvider())
}

/// 주어진 폭에서 뷰가 실제로 필요로 하는 높이. `DashboardCardLayoutTests`가 카드에 쓰는 것과 같은 수단입니다.
@MainActor
private func measuredHeight(_ view: some View, width: CGFloat = detailContentWidth) -> CGFloat {
    NSHostingController(rootView: view)
        .sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        .height
}

/// 주어진 폭을 제안했을 때 뷰가 되돌리는 폭. 제안한 값과 다르면 그 차이가 상위 레이아웃으로 새어 나갑니다.
@MainActor
private func measuredWidth(_ view: some View, proposing width: CGFloat) -> CGFloat {
    NSHostingController(rootView: view)
        .sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        .width
}

/// 상세 팝업 콘텐츠와 같은 조립. `CPUDetailPopoverContent`가 상세를 감싸는 여백·폭 규칙을 그대로 옮깁니다.
@MainActor
private func detailPopoverContent(coreUsages: [Double]) -> some View {
    Group {
        cpuDetailView(coreUsages: coreUsages)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
}

/// 줄바꿈 없이 필요로 하는 폭.
@MainActor
private func measuredIdealWidth(_ view: some View) -> CGFloat {
    NSHostingController(rootView: view.fixedSize(horizontal: true, vertical: false))
        .sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        .width
}

/// 뷰를 실제로 그려 비트맵으로 돌려줍니다. `scale = 1`이라 pt와 픽셀이 일치합니다.
@MainActor
private func renderedBitmap(_ view: some View, width: CGFloat = detailContentWidth) -> NSBitmapImageRep? {
    let renderer = ImageRenderer(content: view.frame(width: width))
    renderer.scale = 1
    guard let data = renderer.nsImage?.tiffRepresentation else { return nil }
    return NSBitmapImageRep(data: data)
}

@MainActor
private func gridBitmap(usages: [Double], width: CGFloat = detailContentWidth) -> NSBitmapImageRep? {
    renderedBitmap(CPUCoreUsageGridView(usages: usages), width: width)
}

private let coreBarBackground = NSColor.windowBackgroundColor.usingColorSpace(.sRGB) ?? .white

private func linearized(_ component: CGFloat) -> CGFloat {
    component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
}

private func relativeLuminance(_ color: NSColor) -> CGFloat {
    0.2126 * linearized(color.redComponent)
        + 0.7152 * linearized(color.greenComponent)
        + 0.0722 * linearized(color.blueComponent)
}

private func compositedOverCoreBarBackground(_ color: NSColor) -> NSColor {
    let alpha = color.alphaComponent
    return NSColor(
        srgbRed: color.redComponent * alpha + coreBarBackground.redComponent * (1 - alpha),
        green: color.greenComponent * alpha + coreBarBackground.greenComponent * (1 - alpha),
        blue: color.blueComponent * alpha + coreBarBackground.blueComponent * (1 - alpha),
        alpha: 1
    )
}

private func contrastAgainstCoreBarBackground(_ color: NSColor) -> CGFloat {
    let foreground = relativeLuminance(compositedOverCoreBarBackground(color))
    let background = relativeLuminance(coreBarBackground)
    return (max(foreground, background) + 0.05) / (min(foreground, background) + 0.05)
}

/// 막대 채움은 유채색 불투명 색이고 트랙은 반투명 시스템 색이므로, 배경 대비로 둘을 가릅니다.
private let coreBarTrackContrast: CGFloat = {
    let track = NSColor(DashboardColorPalette.cpuCoreTrack).usingColorSpace(.sRGB) ?? .clear
    return contrastAgainstCoreBarBackground(track)
}()

/// 한 가로줄에서 조건을 만족하는 픽셀이 이어지는 구간들.
private func inkRuns(
    in bitmap: NSBitmapImageRep,
    y: Int,
    x xRange: Range<Int>,
    matching predicate: (NSColor) -> Bool
) -> [Range<Int>] {
    var runs: [Range<Int>] = []
    var start: Int?
    for x in xRange {
        let matched = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB).map(predicate) ?? false
        if matched, start == nil {
            start = x
        } else if !matched, let began = start {
            runs.append(began..<x)
            start = nil
        }
    }
    if let began = start { runs.append(began..<xRange.upperBound) }
    return runs
}

/// 어떤 색이든 칠해진 픽셀. 칸 사이 간격과 마지막 행의 빈 자리는 완전히 투명합니다.
private let anyInk: (NSColor) -> Bool = { $0.alphaComponent > 0.01 }

/// 막대 채움 픽셀. 트랙보다 배경 대비가 큰 픽셀만 채움으로 셉니다.
private let barFillInk: (NSColor) -> Bool = { contrastAgainstCoreBarBackground($0) > coreBarTrackContrast }

/// 세로로 이어지는 잉크 띠 하나. 칸 안의 막대·수치·번호가 각각 하나씩 나옵니다.
private struct InkBand: Equatable {
    let y: Range<Int>
    /// 띠 안에서 잉크가 가장 넓게 퍼진 가로 폭.
    let maximumInkWidth: Int
}

/// 주어진 세로 구간을 위에서 아래로 훑어, 잉크가 있는 가로줄이 이어지는 띠들을 돌려줍니다.
private func inkBands(
    in bitmap: NSBitmapImageRep,
    x xRange: Range<Int>,
    y yRange: Range<Int>
) -> [InkBand] {
    var bands: [InkBand] = []
    var start: Int?
    var widest = 0

    func close(at end: Int) {
        if let began = start {
            bands.append(InkBand(y: began..<end, maximumInkWidth: widest))
            start = nil
            widest = 0
        }
    }

    for y in yRange {
        let runs = inkRuns(in: bitmap, y: y, x: xRange, matching: anyInk)
        if let first = runs.first, let last = runs.last {
            if start == nil { start = y }
            widest = max(widest, last.upperBound - first.lowerBound)
        } else {
            close(at: y)
        }
    }
    close(at: yRange.upperBound)
    return bands
}

/// 격자 렌더에서 한 행의 막대 띠를 가로지르는 가로줄의 y. 칸 높이는 1코어 격자의 렌더 높이로 재서
/// 상수를 테스트에 다시 적지 않습니다.
@MainActor
private func barScanlineY(rowIndex: Int, cellHeight: CGFloat) -> Int {
    Int((cellHeight + CPUCoreGridLayout.cellSpacing) * CGFloat(rowIndex) + CPUCoreGridLayout.barHeight / 2)
}

@Suite("CPU 코어 사용률 격자 렌더")
@MainActor
struct CPUCoreUsageGridRenderTests {

    /// 칸 하나의 렌더 높이. 아래 단언들이 행 배치를 계산하는 기준입니다.
    private var cellHeight: CGFloat { measuredHeight(CPUCoreUsageGridView(usages: [50])) }

    // MARK: - 행·열 배치

    @Test("격자 높이가 task-001이 정한 행 수만큼만 쌓인다", arguments: [1, 8, 9, 10, 13, 14, 16, 24, 64])
    func gridHeightStacksExactlyTheLayoutRowCount(coreCount: Int) {
        let rowCount = CPUCoreGridLayout.rows(coreCount: coreCount).count
        let expected = cellHeight * CGFloat(rowCount) + CPUCoreGridLayout.cellSpacing * CGFloat(rowCount - 1)

        let measured = measuredHeight(CPUCoreUsageGridView(usages: distinctUsages(coreCount: coreCount)))

        #expect(measured == expected, "코어 \(coreCount)의 격자 높이가 \(measured)로, 행 \(rowCount)개분 \(expected)와 다릅니다")
    }

    @Test(
        "마지막 행의 칸 시작 x가 위 행의 같은 열과 같다",
        arguments: [9, 10, 11, 13, 14, 17, 23, 24]
    )
    func lastRowCellsAlignWithTheColumnsAbove(coreCount: Int) throws {
        let rows = CPUCoreGridLayout.rows(coreCount: coreCount)
        try #require(rows.count >= 2)
        let bitmap = try #require(gridBitmap(usages: distinctUsages(coreCount: coreCount)))
        let height = cellHeight

        let firstRowStarts = inkRuns(
            in: bitmap,
            y: barScanlineY(rowIndex: 0, cellHeight: height),
            x: 0..<bitmap.pixelsWide,
            matching: anyInk
        ).map(\.lowerBound)
        let lastRowStarts = inkRuns(
            in: bitmap,
            y: barScanlineY(rowIndex: rows.count - 1, cellHeight: height),
            x: 0..<bitmap.pixelsWide,
            matching: anyInk
        ).map(\.lowerBound)

        #expect(firstRowStarts.count == rows[0].count, "첫 행의 막대 수가 \(firstRowStarts.count)로 행 길이 \(rows[0].count)와 다릅니다")
        #expect(lastRowStarts.count == rows[rows.count - 1].count, "마지막 행의 막대 수가 \(lastRowStarts.count)로 행 길이 \(rows[rows.count - 1].count)와 다릅니다")
        #expect(
            lastRowStarts == Array(firstRowStarts.prefix(lastRowStarts.count)),
            "코어 \(coreCount): 마지막 행 시작 x \(lastRowStarts)가 첫 행 \(firstRowStarts)와 어긋납니다"
        )
    }

    // MARK: - 칸 안 구성

    @Test("칸이 위에서부터 막대 · 수치 · 번호 세 띠로 그려진다")
    func cellDrawsBarThenValueThenCoreNumber() throws {
        // 코어 하나짜리 격자라 칸 하나가 콘텐츠 폭을 그대로 씁니다.
        let bitmap = try #require(gridBitmap(usages: [100]))
        let bands = inkBands(in: bitmap, x: 0..<bitmap.pixelsWide, y: 0..<bitmap.pixelsHigh)

        try #require(bands.count == 3, "칸 안 잉크 띠가 \(bands.count)개입니다: \(bands)")

        let bar = bands[0]
        #expect(
            CGFloat(bar.y.upperBound - bar.y.lowerBound) == CPUCoreGridLayout.barHeight,
            "첫 띠 높이가 \(bar.y.upperBound - bar.y.lowerBound)로 트랙 높이 \(CPUCoreGridLayout.barHeight)와 다릅니다"
        )
        #expect(
            CGFloat(bar.maximumInkWidth) >= detailContentWidth - 2,
            "첫 띠가 칸 폭을 채우지 않아 막대가 아닙니다(폭 \(bar.maximumInkWidth))"
        )
        // 화면 수치 `"100%"`가 코어 번호 `"0"`보다 넓으므로, 두 띠가 뒤바뀌면 이 비교가 뒤집힙니다.
        #expect(
            bands[1].maximumInkWidth > bands[2].maximumInkWidth,
            "수치 띠 폭 \(bands[1].maximumInkWidth)가 번호 띠 폭 \(bands[2].maximumInkWidth)보다 넓지 않아 칸 안 순서가 뒤바뀌었습니다"
        )
    }

    @Test("칸의 이상적 폭이 화면 수치를 담은 조립과 같다")
    func cellIdealWidthMatchesAssemblyIncludingValueText() {
        let full = referenceCellWidth()
        let withoutValueText = referenceCellWidth(includingValueText: false)

        // 감도 자기점검: 수치를 뺀 기준이 전체보다 좁아야 이 등식이 수치에 실제로 반응합니다.
        #expect(withoutValueText < full, "기준 조립에서 화면 수치를 빼도 폭이 \(full)에서 \(withoutValueText)으로 줄지 않습니다")

        let measured = measuredIdealWidth(CPUCoreUsageGridView(usages: [100]))
        #expect(measured == full, "칸의 이상적 폭이 \(measured)로, 막대 · 수치 · 번호를 담은 기준 \(full)와 다릅니다")
    }

    /// production 칸과 같은 조각으로 조립한 기준 폭. 세로 간격은 폭에 영향을 주지 않으므로 두지 않습니다.
    private func referenceCellWidth(includingValueText: Bool = true) -> CGFloat {
        measuredIdealWidth(
            VStack {
                Rectangle().frame(height: CPUCoreGridLayout.barHeight)
                if includingValueText {
                    Text(CPUCoreUsageFormatting.valueText(100))
                        .dashboardTypography(DashboardStyle.TypographyRole.value)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                Text("0").font(.caption2)
            }
        )
    }

    @Test("코어 칸 수치의 %가 칸마다 같은 오른쪽 자리에 놓인다", arguments: [detailContentWidth, 353])
    func coreValuesAlignToTheSameTrailingPosition(width: CGFloat) throws {
        let bitmap = try #require(gridBitmap(usages: Array(repeating: 100, count: 8), width: width))
        let cells = inkRuns(
            in: bitmap,
            y: Int(CPUCoreGridLayout.barHeight / 2),
            x: 0..<bitmap.pixelsWide,
            matching: anyInk
        )
        try #require(cells.count == 8)

        let trailingOffsets = try cells.map { cell in
            let bands = inkBands(in: bitmap, x: cell, y: 0..<bitmap.pixelsHigh)
            try #require(bands.count == 3)
            let valueBand = bands[1].y
            let trailingInk = try #require(cell.reversed().first { x in
                valueBand.contains { y in
                    bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB).map(anyInk) ?? false
                }
            })
            return cell.upperBound - trailingInk
        }
        #expect(Set(trailingOffsets).count == 1, "칸별 % 오른쪽 여백이 \(trailingOffsets)로 갈립니다")
    }

    @Test("최대 코어 수치가 8열 칸과 스크롤러로 좁아진 칸 안에 든다", arguments: [detailContentWidth, 353])
    func widestCoreValueFitsEightColumnCell(width: CGFloat) {
        let spacing = CPUCoreGridLayout.cellSpacing * CGFloat(CPUCoreGridLayout.maximumColumnCount - 1)
        let cellWidth = (width - spacing) / CGFloat(CPUCoreGridLayout.maximumColumnCount)
        let ideal = measuredIdealWidth(
            Text(CPUCoreUsageFormatting.valueText(100))
                .dashboardTypography(DashboardStyle.TypographyRole.value)
        )
        #expect(ideal <= cellWidth, "코어 수치 폭 \(ideal)이 \(width)pt 격자의 칸 폭 \(cellWidth)을 넘습니다")
    }

    // MARK: - 막대 채움

    @Test("코어 단계가 그래프 기준선에서 유도되고 기준선 변경을 따라간다")
    func usageStepsFollowGraphGridlineBoundaries() {
        #expect(CPUCoreUsageStep.boundaries == HistoryGraphGridline.baselineValues)
        #expect(CPUCoreUsageStep.boundaries.count == 3)
        #expect(DashboardColorPalette.RampStep.allCases.count == 4)

        let boundaries = CPUCoreUsageStep.boundaries
        #expect(CPUCoreUsageStep.step(for: boundaries[2]) == .step1)
        #expect(CPUCoreUsageStep.step(for: boundaries[2].nextDown) == .step2)
        #expect(CPUCoreUsageStep.step(for: boundaries[1]) == .step2)
        #expect(CPUCoreUsageStep.step(for: boundaries[1].nextDown) == .step3)
        #expect(CPUCoreUsageStep.step(for: boundaries[0]) == .step3)
        #expect(CPUCoreUsageStep.step(for: boundaries[0].nextDown) == .step4)

        let shiftedBoundaries = [20.0, 40.0, 60.0]
        #expect(CPUCoreUsageStep.step(for: 19.9, boundaries: shiftedBoundaries) == .step4)
        #expect(CPUCoreUsageStep.step(for: 20, boundaries: shiftedBoundaries) == .step3)
        #expect(CPUCoreUsageStep.step(for: 40, boundaries: shiftedBoundaries) == .step2)
        #expect(CPUCoreUsageStep.step(for: 60, boundaries: shiftedBoundaries) == .step1)
    }

    @Test("각 그래프 기준선의 바로 아래와 바로 위에서 코어 단계가 갈린다")
    func valuesAcrossEveryBoundaryUseDifferentSteps() {
        for boundary in CPUCoreUsageStep.boundaries {
            let below = CPUCoreUsageStep.step(for: boundary.nextDown)
            let above = CPUCoreUsageStep.step(for: boundary.nextUp)
            #expect(below != above, "\(boundary)% 바로 아래와 바로 위가 모두 \(below)입니다")
        }
    }

    @Test("단계가 갈리는 두 코어 사용률은 서로 다른 채움 색을 쓴다")
    func usagesInDifferentStepsUseDifferentFillColors() throws {
        let boundary = try #require(CPUCoreUsageStep.boundaries.first)
        let lower = try #require(
            NSColor(DashboardColorPalette.cpuCoreFill(CPUCoreUsageStep.step(for: boundary.nextDown)))
                .usingColorSpace(.sRGB)
        )
        let upper = try #require(
            NSColor(DashboardColorPalette.cpuCoreFill(CPUCoreUsageStep.step(for: boundary)))
                .usingColorSpace(.sRGB)
        )

        #expect(lower != upper)
    }

    @Test("칸의 채움 높이가 그 코어의 값을 따라 커진다")
    func fillHeightFollowsCoreUsage() throws {
        let usages = distinctUsages(coreCount: 8)
        let bitmap = try #require(gridBitmap(usages: usages))
        let y = barScanlineY(rowIndex: 0, cellHeight: cellHeight)
        let cells = inkRuns(in: bitmap, y: y, x: 0..<bitmap.pixelsWide, matching: anyInk)
        try #require(cells.count == usages.count)

        let fillHeights = cells.map { cell in
            (0..<Int(CPUCoreGridLayout.barHeight)).filter { row in
                !inkRuns(in: bitmap, y: row, x: cell, matching: barFillInk).isEmpty
            }.count
        }

        #expect(fillHeights[0] == 0, "값 0인 코어의 칸에 채움 픽셀이 \(fillHeights[0])줄 있습니다")
        #expect(
            CGFloat(fillHeights[usages.count - 1]) == CPUCoreGridLayout.barHeight,
            "값 100인 코어의 채움이 \(fillHeights[usages.count - 1])줄로 트랙 높이 \(CPUCoreGridLayout.barHeight)를 채우지 않습니다"
        )
        #expect(
            fillHeights == fillHeights.sorted(),
            "값이 커지는 순서와 채움 높이 순서가 어긋납니다: \(fillHeights)"
        )
        #expect(
            Set(fillHeights).count > 2,
            "채움 높이가 \(Set(fillHeights).count)가지뿐이라 값에 비례하지 않습니다: \(fillHeights)"
        )
    }

    @Test("막대 트랙 높이가 값과 무관하게 같다")
    func barTrackHeightIsIndependentOfUsage() throws {
        let usages = distinctUsages(coreCount: 8)
        let bitmap = try #require(gridBitmap(usages: usages))
        let y = barScanlineY(rowIndex: 0, cellHeight: cellHeight)
        let cells = inkRuns(in: bitmap, y: y, x: 0..<bitmap.pixelsWide, matching: anyInk)
        try #require(cells.count == usages.count)

        let barBandHeights = cells.map { cell in
            inkBands(in: bitmap, x: cell, y: 0..<Int(cellHeight)).first.map { $0.y.upperBound - $0.y.lowerBound } ?? 0
        }

        #expect(
            Set(barBandHeights).count == 1 && CGFloat(barBandHeights[0]) == CPUCoreGridLayout.barHeight,
            "칸별 트랙 높이가 \(barBandHeights)로 값에 따라 달라집니다"
        )
    }

    @Test("격자 전체 높이가 값 분포와 무관하게 같다")
    func gridHeightIsIndependentOfValueDistribution() {
        let distributions: [[Double]] = [
            Array(repeating: 0, count: 14),
            Array(repeating: 100, count: 14),
            distinctUsages(coreCount: 14),
            distinctUsages(coreCount: 14).reversed()
        ]

        let heights = distributions.map { measuredHeight(CPUCoreUsageGridView(usages: $0)) }

        #expect(Set(heights).count == 1, "값 분포에 따라 격자 높이가 달라졌습니다: \(heights)")
    }

    @Test("값 분포만 다른 두 입력의 격자 그림이 서로 다르다")
    func differentDistributionsRenderDifferently() throws {
        let ascending = distinctUsages(coreCount: 14)
        let descending = Array(ascending.reversed())

        let lhs = try #require(gridBitmap(usages: ascending))
        let rhs = try #require(gridBitmap(usages: descending))

        #expect(differingPixelCount(lhs, rhs) > 0, "값 분포가 다른 두 격자의 픽셀이 하나도 다르지 않습니다")
    }

    @Test("0%와 1%가 같은 칸의 화면 수치로 갈린다")
    func zeroAndOnePercentDifferInTheOnScreenValue() throws {
        let zero = try #require(gridBitmap(usages: [0]))
        let one = try #require(gridBitmap(usages: [1]))
        let barBand = 0..<Int(CPUCoreGridLayout.barHeight)
        let textBand = Int(CPUCoreGridLayout.barHeight)..<zero.pixelsHigh

        // 1%는 트랙 높이의 1/100이라 채움으로는 0%와 갈리지 않습니다 — 최소 채움을 두지 않기 때문입니다.
        #expect(
            differingPixelCount(zero, one, y: barBand) == 0,
            "1% 코어의 막대가 0%와 달라, 최소 채움 없음이 깨졌습니다"
        )
        #expect(
            differingPixelCount(zero, one, y: textBand) > 0,
            "0%와 1%의 화면 수치가 픽셀로 갈리지 않습니다"
        )
    }
}

@Suite("CPU 상세가 코어 격자를 조립하는지")
@MainActor
struct CPUDetailViewCoreGridTests {

    @Test("코어 수가 늘어난 만큼 CPU 상세 높이가 격자 높이만큼 늘어난다")
    func detailHeightGrowsByTheGridHeight() {
        let fewCores = 8
        let manyCores = 24

        let gridGrowth = measuredHeight(CPUCoreUsageGridView(usages: distinctUsages(coreCount: manyCores)))
            - measuredHeight(CPUCoreUsageGridView(usages: distinctUsages(coreCount: fewCores)))
        let detailGrowth = measuredHeight(cpuDetailView(coreUsages: distinctUsages(coreCount: manyCores)))
            - measuredHeight(cpuDetailView(coreUsages: distinctUsages(coreCount: fewCores)))

        #expect(gridGrowth > 0, "격자가 코어 \(fewCores)개와 \(manyCores)개에서 같은 높이입니다")
        #expect(
            detailGrowth == gridGrowth,
            "CPU 상세 높이가 \(detailGrowth)pt만 늘어, 격자가 늘어난 \(gridGrowth)pt와 다릅니다 — 상세가 격자를 그대로 그리지 않습니다"
        )
    }

    @Test("코어 값 분포만 다른 두 CPU 상세의 그림이 서로 다르다")
    func detailRendersTheGridItself() throws {
        let ascending = distinctUsages(coreCount: 14)
        let descending = Array(ascending.reversed())

        let lhs = try #require(renderedBitmap(cpuDetailView(coreUsages: ascending)))
        let rhs = try #require(renderedBitmap(cpuDetailView(coreUsages: descending)))

        #expect(
            differingPixelCount(lhs, rhs) > 0,
            "코어 값 분포가 다른 두 CPU 상세의 픽셀이 하나도 다르지 않아, 상세가 코어별 값을 그리지 않습니다"
        )
    }

    /// 열 수가 콘텐츠 폭을 나눠떨어뜨리지 않는 코어 수를 함께 넣습니다 —
    /// 14는 7열, 10·9는 5열, 17은 6열이라 균등 분할한 칸 폭이 딱 떨어지지 않습니다.
    private static let unevenAndEvenCoreCounts = [8, 9, 10, 11, 13, 14, 16, 17, 23, 24]

    @Test(
        "격자가 제안받은 폭을 그대로 되돌린다",
        arguments: unevenAndEvenCoreCounts
    )
    func gridReportsExactlyTheProposedWidth(coreCount: Int) {
        let measured = measuredWidth(
            CPUCoreUsageGridView(usages: distinctUsages(coreCount: coreCount)),
            proposing: detailContentWidth
        )

        #expect(
            measured == detailContentWidth,
            "코어 \(coreCount)의 격자가 되돌린 폭이 \(measured)로 제안한 \(detailContentWidth)와 다릅니다 — 칸 폭을 나눈 잔차가 밖으로 새어 나갑니다"
        )
    }

    @Test(
        "상세 팝업 콘텐츠의 폭이 코어 수와 무관하게 400pt다",
        arguments: unevenAndEvenCoreCounts
    )
    func detailPopoverContentWidthStaysExactlyThePopupWidth(coreCount: Int) {
        let measured = measuredWidth(
            detailPopoverContent(coreUsages: distinctUsages(coreCount: coreCount)),
            proposing: detailPopupWidth
        )

        #expect(
            measured == detailPopupWidth,
            "코어 \(coreCount)에서 상세 콘텐츠 폭이 \(measured)로 팝업 폭 \(detailPopupWidth)와 다릅니다 — CPU 상세와 Memory 상세의 팝업 크기가 갈립니다"
        )
    }

    @Test("CPU 상세에 코어 사용률을 쉼표로 이어 붙인 한 줄이 남아 있지 않다")
    func detailNoLongerCarriesTheCommaJoinedCoreLine() {
        let usages = distinctUsages(coreCount: 14)
        let commaJoinedLine = measuredIdealWidth(
            Text("코어별 사용률: " + usages.map(CPUCoreUsageFormatting.valueText).joined(separator: ", "))
                .font(.caption2)
        )

        // 감도 자기점검: 지워진 한 줄이 콘텐츠 폭을 실제로 넘겨야 이 비교가 그 줄에 반응합니다.
        #expect(
            commaJoinedLine > detailContentWidth,
            "쉼표로 이어 붙인 줄의 폭이 \(commaJoinedLine)으로 콘텐츠 폭 \(detailContentWidth) 안이라, 폭 비교가 이 줄을 잡지 못합니다"
        )

        let detailWidth = measuredIdealWidth(cpuDetailView(coreUsages: usages))
        #expect(
            detailWidth <= detailContentWidth,
            "CPU 상세의 이상적 폭이 \(detailWidth)로 콘텐츠 폭 \(detailContentWidth)를 넘습니다"
        )
    }
}

private func differingPixelCount(
    _ lhs: NSBitmapImageRep,
    _ rhs: NSBitmapImageRep,
    y yRange: Range<Int>? = nil
) -> Int {
    guard lhs.pixelsWide == rhs.pixelsWide, lhs.pixelsHigh == rhs.pixelsHigh else { return .max }

    return (yRange ?? 0..<lhs.pixelsHigh).reduce(into: 0) { count, y in
        for x in 0..<lhs.pixelsWide where lhs.colorAt(x: x, y: y) != rhs.colorAt(x: x, y: y) {
            count += 1
        }
    }
}
