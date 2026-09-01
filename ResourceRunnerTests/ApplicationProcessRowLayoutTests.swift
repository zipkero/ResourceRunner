//
//  ApplicationProcessRowLayoutTests.swift
//  ResourceRunnerTests
//
//  task-004 검증 조건: 펼친 앱 행을 직접 렌더해 하위 행의 시작 x와 세 경계 간격을 잽니다.
//

import AppKit
import SwiftUI
import Testing
@testable import ResourceRunner

// MARK: - production과 같은 폭·값

/// 앱 목록 안쪽 폭. 상세 팝업 400pt에서 `.padding()` 좌우 16pt씩과 목록의 `.padding(.leading, 8)`을 뺀 값이라
/// production이 앱 행에 실제로 주는 폭과 같습니다.
private let applicationListInnerWidth: CGFloat = 400 - 32 - 8

/// 앱 목록 안쪽 폭에서 재는 하위 행 중 가장 긴 조합. 검증 조건이 지목한 이름과 값 그대로입니다.
private let longestChildExecutableName = "Google Chrome Helper (Renderer)"
private let longestChildValueText = "12.3% · Rosetta"

/// 들여쓰기·간격을 재는 자리에서 쓰는 하위 프로세스 이름. 이 자리에서 재는 것은 경계와 시작선이므로,
/// 이름이 길어 두 줄로 접히면 행 높이가 간격이 아니라 줄 수를 드러내게 됩니다.
private let childExecutableName = "Helper"
private let firstChildPID: pid_t = 12345

/// 부모 앱 이름. 라벨이 하위 행보다 넓어지면 폭 단언이 하위 행이 아니라 라벨을 재게 되므로 짧게 둡니다.
private let parentDisplayName = "Chrome"

private let fixtureKey = ApplicationKey(value: "/Applications/Google Chrome.app")

private func childProcess(index: Int, executableName: String = childExecutableName) -> ApplicationProcessDetail {
    ApplicationProcessDetail(
        pid: firstChildPID + pid_t(index),
        executableName: executableName,
        cpuUsagePercent: 12.3,
        residentBytes: 512 * 1024 * 1024,
        isTranslated: true
    )
}

private func fixtureGroup(childCount: Int, keySuffix: String = "") -> ApplicationProcessGroup {
    ApplicationProcessGroup(
        key: ApplicationKey(value: fixtureKey.value + keySuffix),
        displayName: parentDisplayName,
        processes: (0..<childCount).map { childProcess(index: $0) },
        sortValue: 12.3
    )
}

/// 화면에 보이는 하위 행 텍스트. `ApplicationProcessGroupRow`가 조립하는 것과 같은 문자열입니다.
private func childRowText(index: Int, executableName: String = childExecutableName) -> String {
    let process = childProcess(index: index, executableName: executableName)
    return "\(process.executableName) (PID \(process.pid))"
}

/// 검증 조건이 지목한 가장 긴 하위 행. `"Google Chrome Helper (Renderer) (PID 12345)"`입니다.
private let longestChildRowText = childRowText(index: 0, executableName: longestChildExecutableName)

/// CPU 상세와 Memory 상세가 각각 `ApplicationProcessGroupListView`에 넘기는 값 서식.
/// 두 상세에서 같은 결과가 나오는지를 이 두 조합으로 가릅니다.
private enum DetailValueFormatting: String, CaseIterable, CustomStringConvertible {
    case cpu
    case memory

    var description: String { rawValue }

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()

    private static func format(_ bytes: UInt64) -> String {
        byteCountFormatter.string(fromByteCount: Int64(bytes))
    }

    var valueText: (ApplicationProcessDetail) -> String {
        switch self {
        case .cpu:
            return ApplicationProcessValueFormatting.cpuProcessValueText
        case .memory:
            return { Self.format($0.residentBytes) }
        }
    }

    var groupValueText: (Double?) -> String {
        switch self {
        case .cpu:
            return ApplicationProcessValueFormatting.cpuGroupValueText
        case .memory:
            return { ApplicationProcessValueFormatting.memoryGroupValueText($0, format: Self.format) }
        }
    }
}

// MARK: - 렌더 수단 (`DashboardCardLayoutTests`·`CPUCoreUsageGridTests`와 같은 수단)

@MainActor
private func measuredHeight(_ view: some View, width: CGFloat = applicationListInnerWidth) -> CGFloat {
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

/// `scale = 1`이라 pt와 픽셀이 일치합니다.
@MainActor
private func renderedBitmap(_ view: some View, width: CGFloat = applicationListInnerWidth) -> NSBitmapImageRep? {
    let renderer = ImageRenderer(content: view.frame(width: width))
    renderer.scale = 1
    guard let data = renderer.nsImage?.tiffRepresentation else { return nil }
    return NSBitmapImageRep(data: data)
}

/// 폭을 주지 않고 필요한 만큼만 그린 비트맵. 글리프의 좌측 여백(side bearing)을 재는 데 씁니다.
@MainActor
private func tightBitmap(_ view: some View) -> NSBitmapImageRep? {
    let renderer = ImageRenderer(content: view.fixedSize())
    renderer.scale = 1
    guard let data = renderer.nsImage?.tiffRepresentation else { return nil }
    return NSBitmapImageRep(data: data)
}

private let anyInk: (NSColor) -> Bool = { $0.alphaComponent > 0.01 }

/// 아이콘으로 쓰는 단색. 라벨에서 아이콘 자리를 색으로 찾아내 삼각형 폭을 렌더에서 유도합니다.
private let iconProbeColor = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)

private let iconInk: (NSColor) -> Bool = {
    $0.redComponent > 0.5 && $0.greenComponent < 0.35 && $0.blueComponent < 0.35 && $0.alphaComponent > 0.5
}

/// 아이콘의 붉은 기가 조금이라도 섞인 픽셀을 뺀 잉크. 아이콘 오른쪽 경계에서 앱 이름을 찾을 때 씁니다.
private let nonIconInk: (NSColor) -> Bool = {
    $0.alphaComponent > 0.01 && $0.redComponent <= $0.greenComponent + 0.1
}

@MainActor
private func iconProvider() -> StubApplicationIconProvider {
    let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
        iconProbeColor.setFill()
        rect.fill()
        return true
    }
    return StubApplicationIconProvider(images: [fixtureKey: image])
}

private func pixel(_ bitmap: NSBitmapImageRep, _ x: Int, _ y: Int) -> NSColor? {
    bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB)
}

/// 조건을 만족하는 픽셀이 있는 가장 왼쪽 x.
private func firstInkX(
    in bitmap: NSBitmapImageRep,
    y: Int,
    from startX: Int = 0,
    matching predicate: (NSColor) -> Bool = anyInk
) -> Int? {
    (startX..<bitmap.pixelsWide).first { x in pixel(bitmap, x, y).map(predicate) ?? false }
}

/// 조건을 만족하는 픽셀이 하나라도 있는 가로줄들.
private func inkRowIndices(
    in bitmap: NSBitmapImageRep,
    matching predicate: (NSColor) -> Bool = anyInk
) -> [Int] {
    (0..<bitmap.pixelsHigh).filter { y in
        (0..<bitmap.pixelsWide).contains { x in pixel(bitmap, x, y).map(predicate) ?? false }
    }
}

/// 잉크가 있는 가로줄이 이어지는 구간들. 라벨 한 덩어리와 하위 행 하나하나가 각각 한 구간으로 나옵니다.
private func inkBands(in bitmap: NSBitmapImageRep) -> [Range<Int>] {
    var bands: [Range<Int>] = []
    var start: Int?
    for y in 0...bitmap.pixelsHigh {
        let inked = y < bitmap.pixelsHigh
            && (0..<bitmap.pixelsWide).contains { x in pixel(bitmap, x, y).map(anyInk) ?? false }
        if inked, start == nil {
            start = y
        } else if !inked, let began = start {
            bands.append(began..<y)
            start = nil
        }
    }
    return bands
}

// MARK: - 렌더에서 유도한 측정값

/// 펼친 앱 행 하나를 렌더해 얻는 좌표들. 상수를 다시 적지 않고 전부 렌더에서 유도합니다.
@MainActor
private struct ExpandedRowProbe {
    let bitmap: NSBitmapImageRep
    /// 라벨 아이콘 자리가 끝나는 x. 삼각형 폭이 바뀌면 이 값이 따라 움직입니다.
    let iconEndX: Int
    /// 부모 앱 이름 글리프의 첫 잉크 x.
    let parentNameInkX: Int
    /// 하위 행 텍스트 글리프의 첫 잉크 x(위에서부터).
    let childInkX: [Int]
    /// 하위 행 잉크 띠의 시작 y(위에서부터).
    let childInkTopY: [Int]

    init?(childCount: Int, formatting: DetailValueFormatting) {
        guard let bitmap = renderedBitmap(
            expandedRow(childCount: childCount, formatting: formatting)
        ) else { return nil }
        self.bitmap = bitmap

        let iconRows = inkRowIndices(in: bitmap, matching: iconInk)
        guard let iconScanline = iconRows.middle else { return nil }
        let iconXs = (0..<bitmap.pixelsWide).filter { x in
            pixel(bitmap, x, iconScanline).map(iconInk) ?? false
        }
        guard let iconEnd = iconXs.last else { return nil }
        iconEndX = iconEnd + 1

        // 아이콘 오른쪽으로 처음 나타나는 잉크가 앱 이름입니다 — 그 사이 간격에는 아무것도 그리지 않습니다.
        guard let nameX = firstInkX(in: bitmap, y: iconScanline, from: iconEndX, matching: nonIconInk) else { return nil }
        parentNameInkX = nameX

        let bands = inkBands(in: bitmap)
        guard bands.count == childCount + 1 else { return nil }
        let childBands = Array(bands.dropFirst())
        childInkTopY = childBands.map(\.lowerBound)

        var inkXs: [Int] = []
        for band in childBands {
            guard let scanline = Array(band).middle,
                  let x = firstInkX(in: bitmap, y: scanline) else { return nil }
            inkXs.append(x)
        }
        childInkX = inkXs
    }
}

private extension Array where Element == Int {
    var middle: Int? { isEmpty ? nil : self[count / 2] }
}

@MainActor
private func expandedRow(childCount: Int, formatting: DetailValueFormatting) -> some View {
    ApplicationProcessGroupRow(
        group: fixtureGroup(childCount: childCount),
        groupValueText: formatting.groupValueText,
        valueText: formatting.valueText,
        iconProvider: iconProvider(),
        isExpanded: .constant(true)
    )
}

@MainActor
private func collapsedRow(formatting: DetailValueFormatting = .cpu) -> some View {
    ApplicationProcessGroupRow(
        group: fixtureGroup(childCount: 3),
        groupValueText: formatting.groupValueText,
        valueText: formatting.valueText,
        iconProvider: iconProvider(),
        isExpanded: .constant(false)
    )
}

/// production 하위 행과 같은 조각으로 조립한 기준. 한 줄 높이와 잉크 시작 y, 이상적 폭을 여기서 얻습니다.
/// 값 문자열까지 production과 같게 맞춰야 합니다 — 글자에 따라 잉크가 줄 상자 안에서 시작하는 높이가 달라집니다.
@MainActor
private func childRowReference(
    name: String = childRowText(index: 0),
    valueText: String = longestChildValueText
) -> some View {
    HStack {
        Text(name)
        Spacer()
        Text(valueText)
    }
    .font(.caption2)
}

/// 글리프가 자기 상자 안에서 왼쪽으로 비워 두는 폭. 시작 x를 글꼴 크기와 무관하게 비교하려면 빼야 합니다.
@MainActor
private func leadingSideBearing(_ view: some View) -> Int? {
    guard let bitmap = tightBitmap(view) else { return nil }
    let rows = inkRowIndices(in: bitmap)
    guard let scanline = rows.middle else { return nil }
    return firstInkX(in: bitmap, y: scanline)
}

// MARK: - 시작 x

@Suite("하위 프로세스 행의 들여쓰기")
@MainActor
struct ApplicationProcessRowIndentTests {

    /// 삼각형 폭 12pt를 상수로 단언하지 않습니다 — OS가 그 폭을 바꾸면 유도된 들여쓰기와 부모 이름
    /// 시작선이 어긋나야 하고, 그 어긋남을 잡는 것이 이 등식입니다.
    @Test("펼친 하위 행의 텍스트 시작 x가 부모 앱 이름 시작 x와 같다", arguments: DetailValueFormatting.allCases)
    fileprivate func childTextStartsAtTheParentNameStart(formatting: DetailValueFormatting) throws {
        let probe = try #require(ExpandedRowProbe(childCount: 3, formatting: formatting))
        let parentBearing = try #require(leadingSideBearing(Text(parentDisplayName).font(.caption)))
        let childBearing = try #require(leadingSideBearing(Text(childRowText(index: 0)).font(.caption2)))

        let parentNameStart = probe.parentNameInkX - parentBearing
        let childStarts = probe.childInkX.map { $0 - childBearing }

        #expect(
            childStarts == Array(repeating: parentNameStart, count: childStarts.count),
            "하위 행 시작 x \(childStarts)가 부모 앱 이름 시작 x \(parentNameStart)와 다릅니다"
        )
    }

    /// 위 등식이 항진명제가 아님을 보이는 감도 자기점검. 삼각형 폭 없이 아이콘·간격만으로 유도했다면
    /// 들여쓰기가 아이콘 자리 끝과 같아졌을 것이고, 그 값은 실제 시작선과 다릅니다.
    @Test("아이콘 자리가 끝나는 x와 부모 이름 시작 x가 라벨 간격만큼 떨어져 있다")
    func parentNameStartsOneLabelSpacingAfterTheIcon() throws {
        let probe = try #require(ExpandedRowProbe(childCount: 1, formatting: .cpu))
        let parentBearing = try #require(leadingSideBearing(Text(parentDisplayName).font(.caption)))
        let parentNameStart = probe.parentNameInkX - parentBearing

        #expect(
            CGFloat(parentNameStart - probe.iconEndX) == ApplicationProcessRowLayout.labelIconSpacing,
            "부모 이름 시작 x \(parentNameStart)가 아이콘 자리 끝 \(probe.iconEndX)에서 \(ApplicationProcessRowLayout.labelIconSpacing)pt 떨어져 있지 않습니다"
        )
        #expect(
            CGFloat(probe.iconEndX) == ApplicationProcessRowLayout.disclosureTriangleWidth
                + ApplicationRowIconLayout.detailPointSize,
            "아이콘 자리 끝이 \(probe.iconEndX)로, 삼각형 폭과 아이콘 크기의 합과 다릅니다 — 이 macOS의 삼각형 폭이 \(ApplicationProcessRowLayout.disclosureTriangleWidth)pt가 아닙니다"
        )
    }
}

// MARK: - 세 경계 간격

@Suite("부모–첫 하위 · 하위끼리 · 마지막 하위–다음 앱 세 경계")
@MainActor
struct ApplicationProcessRowSpacingTests {

    /// production 하위 행과 같은 문자열로 조립한 기준 한 줄.
    private func reference(_ formatting: DetailValueFormatting) -> some View {
        childRowReference(valueText: formatting.valueText(childProcess(index: 0)))
    }

    /// 하위 행 한 줄의 높이. 경계 간격을 행 높이에서 갈라내는 기준입니다.
    private func childLineHeight(_ formatting: DetailValueFormatting) -> CGFloat {
        measuredHeight(reference(formatting))
    }

    /// 하위 행 잉크가 자기 줄 상자 안에서 위로 비워 두는 높이.
    private func childInkTopOffset(_ formatting: DetailValueFormatting) throws -> Int {
        let bitmap = try #require(renderedBitmap(reference(formatting)))
        return try #require(inkBands(in: bitmap).first?.lowerBound)
    }

    /// 목록 `VStack`이 행 사이에 두는 간격. 마지막 경계에 이 값이 더해지므로 렌더에서 직접 잽니다.
    private func listRowSpacing() -> CGFloat {
        measuredHeight(list(groupCount: 2)) - measuredHeight(list(groupCount: 1)) - measuredHeight(collapsedRow())
    }

    private func list(groupCount: Int) -> some View {
        ApplicationProcessGroupListView(
            groups: (0..<groupCount).map { fixtureGroup(childCount: 3, keySuffix: "-\($0)") },
            sortDescription: "CPU 사용률 순",
            groupValueText: DetailValueFormatting.cpu.groupValueText,
            iconProvider: iconProvider(),
            valueText: DetailValueFormatting.cpu.valueText
        )
    }

    /// 세 경계를 렌더에서 갈라냅니다. 상수를 읽지 않으므로 `.padding` 호출을 통째로 지우면 값이 0으로 떨어집니다.
    private func measuredBoundaries() throws -> (betweenChildren: CGFloat, parentToFirstChild: CGFloat, lastChildToNextApplication: CGFloat) {
        let probe = try #require(ExpandedRowProbe(childCount: 3, formatting: .cpu))
        let inkTopOffset = try childInkTopOffset(.cpu)
        let line = childLineHeight(.cpu)
        let collapsedHeight = measuredHeight(collapsedRow())
        let expandedHeight = measuredHeight(expandedRow(childCount: 3, formatting: .cpu))

        let firstChildTop = CGFloat(probe.childInkTopY[0] - inkTopOffset)
        let lastChildTop = CGFloat(probe.childInkTopY[2] - inkTopOffset)

        return (
            betweenChildren: CGFloat(probe.childInkTopY[1] - probe.childInkTopY[0]) - line,
            parentToFirstChild: firstChildTop - collapsedHeight,
            lastChildToNextApplication: expandedHeight - (lastChildTop + line) + listRowSpacing()
        )
    }

    @Test("세 경계의 간격이 4 / 10 / 16pt다")
    func theThreeBoundariesMeasureFourTenSixteen() throws {
        let measured = try measuredBoundaries()

        #expect(measured.betweenChildren == 4, "하위끼리 간격이 \(measured.betweenChildren)pt입니다")
        #expect(measured.parentToFirstChild == 10, "부모–첫 하위 간격이 \(measured.parentToFirstChild)pt입니다")
        #expect(
            measured.lastChildToNextApplication == 16,
            "마지막 하위–다음 앱 간격이 \(measured.lastChildToNextApplication)pt입니다"
        )
    }

    @Test("세 경계에 서로 같은 값이 하나도 없다")
    func theThreeBoundariesAreAllDifferent() throws {
        let measured = try measuredBoundaries()
        let values = [measured.betweenChildren, measured.parentToFirstChild, measured.lastChildToNextApplication]

        #expect(Set(values).count == 3, "세 경계 \(values) 중 같은 값이 있습니다")
    }

    @Test("하위끼리 < 부모–첫 하위 < 마지막 하위–다음 앱 순서다")
    func theBoundariesWidenWithTheDepthTheyCross() throws {
        let measured = try measuredBoundaries()

        #expect(
            measured.betweenChildren < measured.parentToFirstChild,
            "하위끼리 \(measured.betweenChildren)가 부모–첫 하위 \(measured.parentToFirstChild)보다 좁지 않습니다"
        )
        #expect(
            measured.parentToFirstChild < measured.lastChildToNextApplication,
            "부모–첫 하위 \(measured.parentToFirstChild)가 마지막 하위–다음 앱 \(measured.lastChildToNextApplication)보다 좁지 않습니다"
        )
    }

    /// 상수만 단언하면 뷰가 그 상수를 쓰지 않는 mutation이 열린 채로 남으므로, 펼친 행의 렌더 높이를 잽니다.
    @Test(
        "하위가 1·2·3개일 때 펼친 행의 높이가 세 경계 규칙대로만 늘어난다",
        arguments: [1, 2, 3], DetailValueFormatting.allCases
    )
    fileprivate func expandedRowHeightGrowsOnlyByTheBoundaryRule(childCount: Int, formatting: DetailValueFormatting) {
        let line = childLineHeight(formatting)
        let expected = measuredHeight(collapsedRow(formatting: formatting))
            + ApplicationProcessRowLayout.parentToFirstChild
            + line * CGFloat(childCount)
            + ApplicationProcessRowLayout.betweenChildren * CGFloat(childCount - 1)
            + ApplicationProcessRowLayout.afterLastChild

        let measured = measuredHeight(expandedRow(childCount: childCount, formatting: formatting))

        #expect(
            measured == expected,
            "하위 \(childCount)개(\(formatting)) 펼친 행의 높이가 \(measured)로, 규칙대로면 \(expected)입니다"
        )
    }

    @Test("접힌 앱 행 사이 간격이 변경 전과 같다")
    func collapsedRowsKeepTheirPreviousSpacing() {
        // 변경 전 실측값 — 접힘 행 24.0pt, 목록 행 간격 2.0pt.
        #expect(measuredHeight(collapsedRow()) == 24, "접힌 앱 행 높이가 \(measuredHeight(collapsedRow()))입니다")
        #expect(listRowSpacing() == 2, "목록 행 간격이 \(listRowSpacing())입니다")
    }
}

// MARK: - 폭

@Suite("가장 긴 하위 행이 앱 목록 안쪽 폭에 들어가는지")
@MainActor
struct ApplicationProcessRowWidthTests {

    /// 검증 조건이 지목한 가장 긴 조합만 쓰는 행. 값 서식이 아니라 폭을 재는 자리라 문자열을 직접 넘깁니다.
    private func longestRow(isExpanded: Bool) -> some View {
        ApplicationProcessGroupRow(
            group: ApplicationProcessGroup(
                key: fixtureKey,
                displayName: parentDisplayName,
                processes: [childProcess(index: 0, executableName: longestChildExecutableName)],
                sortValue: 12.3
            ),
            groupValueText: { _ in longestChildValueText },
            valueText: { _ in longestChildValueText },
            iconProvider: iconProvider(),
            isExpanded: .constant(isExpanded)
        )
    }

    @Test("가장 긴 하위 행이 앱 목록 안쪽 폭 360pt 안에서 한 줄로 남는다")
    func theLongestChildRowFitsTheListWidthOnOneLine() {
        let idealWidth = measuredIdealWidth(longestRow(isExpanded: true))
        #expect(
            idealWidth <= applicationListInnerWidth,
            "가장 긴 하위 행을 담은 펼친 행의 이상적 폭이 \(idealWidth)로 \(applicationListInnerWidth)를 넘습니다"
        )

        // 폭이 모자라면 이름이 두 줄로 접혀 행 높이가 한 줄분을 넘습니다.
        let line = measuredHeight(childRowReference(name: longestChildRowText))
        let expected = measuredHeight(longestRow(isExpanded: false))
            + ApplicationProcessRowLayout.parentToFirstChild
            + line
            + ApplicationProcessRowLayout.afterLastChild
        let measured = measuredHeight(longestRow(isExpanded: true))
        #expect(measured == expected, "가장 긴 하위 행의 펼친 높이가 \(measured)로 한 줄분 \(expected)를 넘습니다")
    }

    /// 46pt 안을 접은 근거의 확인. 들여쓰기만 46pt로 둔 같은 조립이 목록 폭을 넘겨야
    /// 34pt를 고른 것이 폭 예산에 실제로 걸린 선택이 됩니다.
    @Test("들여쓰기를 46pt로 두면 같은 하위 행이 목록 폭을 넘긴다")
    func aFortySixPointIndentOverflowsTheListWidth() {
        let content = childRowReference(name: longestChildRowText)
        let atRejectedIndent = measuredIdealWidth(content.padding(.leading, 46))
        let atChosenIndent = measuredIdealWidth(content.padding(.leading, ApplicationProcessRowLayout.childIndent))

        #expect(
            atRejectedIndent > applicationListInnerWidth,
            "46pt 들여쓰기의 이상적 폭이 \(atRejectedIndent)로 \(applicationListInnerWidth) 안입니다"
        )
        #expect(
            atChosenIndent <= applicationListInnerWidth,
            "\(ApplicationProcessRowLayout.childIndent)pt 들여쓰기의 이상적 폭이 \(atChosenIndent)로 \(applicationListInnerWidth)를 넘습니다"
        )
    }
}

// MARK: - CPU·Memory 두 상세

@Suite("두 상세가 같은 앱 목록을 그리는지")
@MainActor
struct DetailViewsShareTheApplicationListTests {

    private func groups(count: Int) -> [ApplicationProcessGroup] {
        (0..<count).map { fixtureGroup(childCount: 3, keySuffix: "-\($0)") }
    }

    private func cpuDetail(groupCount: Int) -> some View {
        CPUDetailView(
            presentation: CPUCardPresentation.assemble(
                cpu: CPUSystemMetrics(
                    overallUsage: 42,
                    userRatio: 30,
                    systemRatio: 12,
                    idleRatio: 58,
                    coreUsages: Array(repeating: 25, count: 8),
                    loadAverage: LoadAverage(oneMinute: 1.5, fiveMinutes: 1.25, fifteenMinutes: 1)
                ),
                history: [],
                topApplications: [],
                processGroups: groups(count: groupCount),
                currentTimestamp: ContinuousClock().now
            ),
            iconProvider: iconProvider()
        )
    }

    private func memoryDetail(groupCount: Int) -> some View {
        let gibibyte: UInt64 = 1024 * 1024 * 1024
        return MemoryDetailView(
            presentation: MemoryCardPresentation.assemble(
                memory: MemorySystemMetrics(
                    totalPhysicalBytes: 16 * gibibyte,
                    usedBytes: 8 * gibibyte,
                    appBytes: 4 * gibibyte,
                    wiredBytes: 2 * gibibyte,
                    compressedBytes: 2 * gibibyte,
                    cachedBytes: gibibyte,
                    swapUsedBytes: 0,
                    pressureLevel: .normal
                ),
                history: [],
                topApplications: [],
                processGroups: groups(count: groupCount),
                currentTimestamp: ContinuousClock().now
            ),
            iconProvider: iconProvider()
        )
    }

    /// 하위 행의 들여쓰기·간격은 `ApplicationProcessGroupRow`가 전부 만들고 그 행을 조립하는 곳은
    /// `ApplicationProcessGroupListView` 하나뿐이므로, 두 상세가 같은 목록 기하를 쓰는지가 곧
    /// 두 상세에서 같은 결과가 나오는지입니다. 펼침 상태는 목록의 `@State`라 여기서는 펼칠 수 없습니다.
    @Test("앱을 하나 더하면 두 상세가 같은 높이만큼 늘어난다")
    func bothDetailsGrowByTheSameApplicationRowGeometry() {
        let rowPitch = measuredHeight(collapsedRow()) + 2

        let cpuGrowth = measuredHeight(cpuDetail(groupCount: 2), width: 400 - 32)
            - measuredHeight(cpuDetail(groupCount: 1), width: 400 - 32)
        let memoryGrowth = measuredHeight(memoryDetail(groupCount: 2), width: 400 - 32)
            - measuredHeight(memoryDetail(groupCount: 1), width: 400 - 32)

        #expect(cpuGrowth == rowPitch, "CPU 상세가 앱 하나에 \(cpuGrowth)pt 늘어, 앱 행 \(rowPitch)pt와 다릅니다")
        #expect(memoryGrowth == rowPitch, "Memory 상세가 앱 하나에 \(memoryGrowth)pt 늘어, 앱 행 \(rowPitch)pt와 다릅니다")
    }
}
