//
//  CPUCoreGridVerticalBudgetTests.swift
//  ResourceRunnerTests
//
//  task-003 검증 조건: 격자가 상세 팝업 첫 화면 안에 들어가는지를 코어 수별로 잽니다.
//

import AppKit
import SwiftUI
import Testing
@testable import ResourceRunner

private let baseInstant = ContinuousClock().now

/// production 상세 팝업의 고정 프레임을 직접 써서 세로 예산과 실제 프레임이 어긋나지 않게 합니다.
private let popupWidth = DashboardView.detailPopupWidth
private let popupHeight = DashboardView.detailPopupHeight

/// 팝업 콘텐츠 폭. `.padding()` 기본값 좌우 16pt씩을 뺀 값입니다.
private let detailContentWidth: CGFloat = popupWidth - 32

/// 레거시 스크롤러가 「항상 표시」 설정에서 가져가는 폭. 그 설정으로 직접 재지는 못했고 추정입니다.
private let scrollerWidth: CGFloat = 15
private let narrowedContentWidth: CGFloat = detailContentWidth - scrollerWidth

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

/// production이 `ScrollView` 안에 두는 것과 같은 조립. 팝업 위끝에서부터의 거리를 재려면
/// 상단 여백이 포함된 이 형태로 렌더해야 합니다.
@MainActor
private func popupContent(coreCount: Int) -> some View {
    CPUDetailView(
        presentation: cpuPresentation(coreUsages: distinctUsages(coreCount: coreCount)),
        iconProvider: StubApplicationIconProvider()
    )
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
}

@MainActor
private func measuredHeight(_ view: some View, width: CGFloat) -> CGFloat {
    NSHostingController(rootView: view)
        .sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        .height
}

@MainActor
private func measuredIdealWidth(_ view: some View) -> CGFloat {
    NSHostingController(rootView: view.fixedSize(horizontal: true, vertical: false))
        .sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        .width
}

@MainActor
private func renderedBitmap(_ view: some View, width: CGFloat) -> NSBitmapImageRep? {
    let renderer = ImageRenderer(content: view.frame(width: width))
    renderer.scale = 1
    guard let data = renderer.nsImage?.tiffRepresentation else { return nil }
    return NSBitmapImageRep(data: data)
}

private let anyInk: (NSColor) -> Bool = { $0.alphaComponent > 0.01 }

private func inkRuns(in bitmap: NSBitmapImageRep, y: Int, x xRange: Range<Int>) -> [Range<Int>] {
    var runs: [Range<Int>] = []
    var start: Int?
    for x in xRange {
        let matched = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB).map(anyInk) ?? false
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

/// 렌더된 팝업 콘텐츠에서 격자 첫 행 막대 트랙의 위끝 y.
///
/// 막대 트랙은 칸 폭을 가득 채운 채 트랙 높이만큼 같은 모양으로 이어지는 유일한 요소라,
/// 「같은 잉크 구간이 열 수만큼 10줄 연속으로 반복되는 자리」로 글자 줄과 갈립니다.
/// 찾은 자리에서 위로 걸어 올라가 모서리 둥글기로 좁아진 줄까지 포함한 실제 위끝을 돌려줍니다.
private func gridTopY(in bitmap: NSBitmapImageRep, columnCount: Int) -> Int? {
    let xRange = 0..<bitmap.pixelsWide
    let minimumTrackWidth = 25

    for y in 0..<max(bitmap.pixelsHigh - 10, 0) {
        let runs = inkRuns(in: bitmap, y: y, x: xRange)
        guard runs.count == columnCount,
              runs.allSatisfy({ $0.upperBound - $0.lowerBound >= minimumTrackWidth }),
              (1...9).allSatisfy({ inkRuns(in: bitmap, y: y + $0, x: xRange) == runs })
        else { continue }

        var top = y
        while top > 0, inkRuns(in: bitmap, y: top - 1, x: xRange).count == columnCount {
            top -= 1
        }
        return top
    }
    return nil
}

/// 팝업 위끝(상단 여백 포함)에서 격자 아래끝까지의 거리.
/// 위끝은 렌더된 팝업 콘텐츠에서 픽셀로 찾고, 격자 높이는 격자 뷰를 그대로 재서 더합니다.
@MainActor
private func gridBottomFromPopupTop(coreCount: Int, contentWidth: CGFloat = detailContentWidth) throws -> CGFloat {
    let rows = CPUCoreGridLayout.rows(coreCount: coreCount)
    let columnCount = try #require(rows.first?.count)
    let bitmap = try #require(renderedBitmap(popupContent(coreCount: coreCount), width: contentWidth + 32))
    let top = try #require(
        gridTopY(in: bitmap, columnCount: columnCount),
        "코어 \(coreCount)의 렌더에서 격자 첫 행 막대를 찾지 못했습니다"
    )
    let gridHeight = measuredHeight(
        CPUCoreUsageGridView(usages: distinctUsages(coreCount: coreCount)),
        width: contentWidth
    )
    return CGFloat(top) + gridHeight
}

@Suite("CPU 코어 격자의 세로 예산")
@MainActor
struct CPUCoreGridVerticalBudgetTests {

    @Test("논리 코어 14개에서 격자 아래끝이 팝업 첫 화면 안이다")
    func gridFitsTheFirstScreenOnTheReferenceDevice() throws {
        let bottom = try gridBottomFromPopupTop(coreCount: 14)

        #expect(bottom == 166, "코어 14개의 격자 아래끝이 \(bottom)pt로 166pt와 다릅니다")
        #expect(bottom <= popupHeight, "코어 14개의 격자 아래끝 \(bottom)pt가 팝업 높이 \(popupHeight)pt를 넘습니다")
    }

    @Test("코어 수가 달라져도 격자 아래끝이 첫 화면 안이다", arguments: [8, 10, 16, 24, 32, 56])
    func gridFitsTheFirstScreenAcrossCoreCounts(coreCount: Int) throws {
        let bottom = try gridBottomFromPopupTop(coreCount: coreCount)

        #expect(
            bottom <= popupHeight,
            "코어 \(coreCount)개의 격자 아래끝 \(bottom)pt가 팝업 높이 \(popupHeight)pt를 넘습니다"
        )
    }

    @Test("논리 코어 56개가 첫 화면에 들어가는 마지막 코어 수다")
    func fiftySixCoresIsTheLastCountThatFits() throws {
        let bottom = try gridBottomFromPopupTop(coreCount: 56)

        #expect(bottom == 446, "코어 56개의 격자 아래끝이 \(bottom)pt로 446pt와 다릅니다")
    }

    @Test("코어 57개 이상에서는 격자 아래끝이 첫 화면을 벗어난다", arguments: [57, 65, 80, 128])
    func beyondFiftySixCoresTheGridOverflowsTheFirstScreen(coreCount: Int) throws {
        let bottom = try gridBottomFromPopupTop(coreCount: coreCount)

        #expect(
            bottom > popupHeight,
            "코어 \(coreCount)개의 격자 아래끝이 \(bottom)pt로 첫 화면 안이라, 넘치는 몫이 스크롤로 가는 전제가 성립하지 않습니다"
        )
    }

    @Test(
        "어떤 코어 수에서도 격자의 필요 폭이 콘텐츠 폭을 넘지 않는다",
        arguments: [1, 2, 8, 10, 14, 16, 24, 32, 56, 57, 64, 65, 128]
    )
    func gridNeverNeedsMoreThanTheContentWidth(coreCount: Int) {
        let idealWidth = measuredIdealWidth(CPUCoreUsageGridView(usages: Array(repeating: 100, count: coreCount)))

        #expect(
            idealWidth <= detailContentWidth,
            "코어 \(coreCount)개의 격자가 \(idealWidth)pt를 필요로 해 콘텐츠 폭 \(detailContentWidth)pt를 넘습니다"
        )
    }

    // MARK: - 스크롤 막대가 폭을 가져가는 환경

    @Test(
        "콘텐츠 폭을 스크롤 막대 몫만큼 좁혀도 격자 아래끝이 그대로다",
        arguments: [8, 10, 14, 16, 24, 32, 56]
    )
    func narrowedContentWidthKeepsTheSameGridBottom(coreCount: Int) throws {
        let full = try gridBottomFromPopupTop(coreCount: coreCount)
        let narrowed = try gridBottomFromPopupTop(coreCount: coreCount, contentWidth: narrowedContentWidth)

        #expect(
            narrowed == full,
            "코어 \(coreCount)개에서 폭을 \(scrollerWidth)pt 좁히자 격자 아래끝이 \(full)pt에서 \(narrowed)pt로 달라졌습니다"
        )
        #expect(
            narrowed <= popupHeight,
            "코어 \(coreCount)개의 좁힌 폭 격자 아래끝 \(narrowed)pt가 팝업 높이 \(popupHeight)pt를 넘습니다"
        )
    }

    @Test(
        "좁힌 폭에서도 칸이 화면 수치를 담을 만큼 넓다",
        arguments: [8, 10, 14, 16, 24, 32, 56, 64]
    )
    func cellsStayWideEnoughForTheOnScreenValueWhenNarrowed(coreCount: Int) throws {
        // 칸에 들어가는 가장 넓은 화면 수치. 칸이 이보다 좁아지면 수치가 잘립니다.
        let valueTextWidth = measuredIdealWidth(
            Text(CPUCoreUsageFormatting.valueText(100))
                .dashboardTypography(DashboardStyle.TypographyRole.value)
        )
        #expect(valueTextWidth > 0)

        let columnCount = try #require(CPUCoreGridLayout.rows(coreCount: coreCount).first?.count)
        let bitmap = try #require(
            renderedBitmap(
                CPUCoreUsageGridView(usages: Array(repeating: 100, count: coreCount)),
                width: narrowedContentWidth
            )
        )

        // 막대 트랙은 칸 폭을 가득 채우므로, 그 잉크 폭이 곧 칸에 실제로 배분된 폭입니다.
        let trackY = Int(CPUCoreGridLayout.barHeight / 2)
        let trackWidths = inkRuns(in: bitmap, y: trackY, x: 0..<bitmap.pixelsWide)
            .map { CGFloat($0.upperBound - $0.lowerBound) }

        try #require(trackWidths.count == columnCount, "첫 행의 막대가 \(trackWidths.count)개로 열 수 \(columnCount)와 다릅니다")
        #expect(
            trackWidths.allSatisfy { $0 >= valueTextWidth },
            "코어 \(coreCount)개를 \(narrowedContentWidth)pt에 그리면 칸 폭이 \(trackWidths)로 화면 수치 \(valueTextWidth)pt보다 좁습니다"
        )

        let idealWidth = measuredIdealWidth(CPUCoreUsageGridView(usages: Array(repeating: 100, count: coreCount)))
        #expect(
            idealWidth <= narrowedContentWidth,
            "코어 \(coreCount)개의 격자가 \(idealWidth)pt를 필요로 해 좁힌 폭 \(narrowedContentWidth)pt를 넘습니다"
        )
    }
}
