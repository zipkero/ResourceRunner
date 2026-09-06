import AppKit
import SwiftUI
import Testing
@testable import ResourceRunner

private let applicationListInnerWidth: CGFloat =
    400 - 32 - ApplicationProcessGroupListView.contentLeadingPadding
private let childExecutableName = "Helper"
private let longestChildExecutableName = "Google Chrome Helper (Renderer)"
private let firstChildPID: pid_t = 12345
private let parentDisplayName = "Chrome"
private let fixtureKey = ApplicationKey(value: "/Applications/Google Chrome.app")

private func childProcess(index: Int, executableName: String = childExecutableName) -> ApplicationProcessDetail {
    ApplicationProcessDetail(
        pid: firstChildPID + pid_t(index), executableName: executableName, cpuUsagePercent: 12.3,
        residentBytes: 512 * 1024 * 1024, isTranslated: true
    )
}

private func fixtureGroup(childCount: Int, keySuffix: String = "") -> ApplicationProcessGroup {
    ApplicationProcessGroup(
        key: ApplicationKey(value: fixtureKey.value + keySuffix), displayName: parentDisplayName,
        processes: (0..<childCount).map { childProcess(index: $0) }, sortValue: 12.3
    )
}

private func childName(_ process: ApplicationProcessDetail) -> String {
    "\(process.executableName) (PID \(process.pid))"
}

private enum DetailValueFormatting: String, CaseIterable, CustomStringConvertible {
    case cpu
    case memory

    var description: String { rawValue }

    private static func format(_ bytes: UInt64) -> String {
        DashboardValueColumn.byteText(bytes)
    }

    var valueText: (ApplicationProcessDetail) -> String {
        switch self {
        case .cpu: ApplicationProcessValueFormatting.cpuProcessValueText
        case .memory: { Self.format($0.residentBytes) }
        }
    }

    var groupValueText: (Double?) -> DashboardValueColumn.Value {
        switch self {
        case .cpu: ApplicationProcessValueFormatting.cpuGroupValueText
        case .memory: ApplicationProcessValueFormatting.memoryGroupValueText
        }
    }
}

@MainActor
private func measuredHeight(_ view: some View, width: CGFloat = applicationListInnerWidth) -> CGFloat {
    NSHostingController(rootView: view)
        .sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
}

@MainActor
private func measuredIdealWidth(_ view: some View) -> CGFloat {
    NSHostingController(rootView: view.fixedSize(horizontal: true, vertical: false))
        .sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width
}

@MainActor
private func renderedBitmap(_ view: some View, width: CGFloat = applicationListInnerWidth) -> NSBitmapImageRep? {
    let renderer = ImageRenderer(content: view.frame(width: width))
    renderer.scale = 1
    guard let data = renderer.nsImage?.tiffRepresentation else { return nil }
    return NSBitmapImageRep(data: data)
}

@MainActor
private func tightBitmap(_ view: some View) -> NSBitmapImageRep? {
    let renderer = ImageRenderer(content: view.frame(width: 300, alignment: .leading))
    renderer.scale = 1
    guard let data = renderer.nsImage?.tiffRepresentation else { return nil }
    return NSBitmapImageRep(data: data)
}

private let anyInk: (NSColor) -> Bool = { $0.alphaComponent > 0.01 }
private let iconProbeColor = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
private let iconInk: (NSColor) -> Bool = {
    $0.redComponent > 0.5 && $0.greenComponent < 0.35 && $0.blueComponent < 0.35 && $0.alphaComponent > 0.5
}
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

private func firstInkX(
    in bitmap: NSBitmapImageRep, y: Int, from startX: Int = 0,
    matching predicate: (NSColor) -> Bool = anyInk
) -> Int? {
    (startX..<bitmap.pixelsWide).first { x in pixel(bitmap, x, y).map(predicate) ?? false }
}

private func inkRowIndices(
    in bitmap: NSBitmapImageRep, matching predicate: (NSColor) -> Bool = anyInk
) -> [Int] {
    (0..<bitmap.pixelsHigh).filter { y in
        (0..<bitmap.pixelsWide).contains { x in pixel(bitmap, x, y).map(predicate) ?? false }
    }
}

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

private extension Array where Element == Int {
    var middle: Int? { isEmpty ? nil : self[count / 2] }
}

@MainActor
private func expandedRow(childCount: Int, formatting: DetailValueFormatting) -> some View {
    ApplicationProcessGroupRow(
        group: fixtureGroup(childCount: childCount), groupValue: formatting.groupValueText,
        valueText: formatting.valueText, iconProvider: iconProvider(), isExpanded: .constant(true)
    )
}

@MainActor
private func collapsedRow(formatting: DetailValueFormatting = .cpu) -> some View {
    ApplicationProcessGroupRow(
        group: fixtureGroup(childCount: 3), groupValue: formatting.groupValueText,
        valueText: formatting.valueText, iconProvider: iconProvider(), isExpanded: .constant(false)
    )
}

@MainActor
private func textLine(_ text: String) -> some View { Text(text).font(.caption2) }

@MainActor
private func leadingSideBearing(_ view: some View) -> Int? {
    guard let bitmap = tightBitmap(view), let scanline = inkRowIndices(in: bitmap).middle else { return nil }
    return firstInkX(in: bitmap, y: scanline)
}

@MainActor
private struct ExpandedRowProbe {
    let iconEndX: Int
    let parentNameInkX: Int
    let nameInkX: [Int]
    let valueInkX: [Int]
    let nameInkTopY: [Int]
    let valueInkTopY: [Int]

    init?(childCount: Int, formatting: DetailValueFormatting) {
        guard let bitmap = renderedBitmap(expandedRow(childCount: childCount, formatting: formatting)) else { return nil }
        let iconRows = inkRowIndices(in: bitmap, matching: iconInk)
        guard let iconScanline = iconRows.middle else { return nil }
        let iconXs = (0..<bitmap.pixelsWide).filter { x in pixel(bitmap, x, iconScanline).map(iconInk) ?? false }
        guard let iconEnd = iconXs.last else { return nil }
        iconEndX = iconEnd + 1
        guard let parentX = firstInkX(in: bitmap, y: iconScanline, from: iconEndX, matching: nonIconInk) else { return nil }
        parentNameInkX = parentX

        let bands = inkBands(in: bitmap)
        guard bands.count == 1 + childCount * 2 else { return nil }
        let childBands = Array(bands.dropFirst())
        let nameBands = stride(from: 0, to: childBands.count, by: 2).map { childBands[$0] }
        let valueBands = stride(from: 1, to: childBands.count, by: 2).map { childBands[$0] }

        func starts(in bands: [Range<Int>]) -> [Int]? {
            var result: [Int] = []
            for band in bands {
                guard let scanline = Array(band).middle,
                      let x = firstInkX(in: bitmap, y: scanline) else { return nil }
                result.append(x)
            }
            return result
        }
        guard let names = starts(in: nameBands), let values = starts(in: valueBands) else { return nil }
        nameInkX = names
        valueInkX = values
        nameInkTopY = nameBands.map(\.lowerBound)
        valueInkTopY = valueBands.map(\.lowerBound)
    }
}

@Suite("하위 프로세스 행의 두 시작선")
@MainActor
struct ApplicationProcessRowIndentTests {
    @Test("이름은 부모 앱 이름과 같고 값은 아이콘 한 칸 더 들어간다", arguments: DetailValueFormatting.allCases)
    fileprivate func childLinesHaveDistinctSemanticStarts(formatting: DetailValueFormatting) throws {
        let probe = try #require(ExpandedRowProbe(childCount: 3, formatting: formatting))
        let process = childProcess(index: 0)
        let parentBearing = try #require(leadingSideBearing(Text(parentDisplayName).font(.caption)))
        let nameBearing = try #require(leadingSideBearing(textLine(childName(process))))
        let valueBearing = try #require(leadingSideBearing(textLine(formatting.valueText(process))))
        let parentStart = probe.parentNameInkX - parentBearing
        let nameStarts = probe.nameInkX.map { $0 - nameBearing }
        let valueStarts = probe.valueInkX.map { $0 - valueBearing }

        #expect(nameStarts == Array(repeating: parentStart, count: 3))
        #expect(valueStarts == nameStarts.map { $0 + Int(ApplicationRowIconLayout.detailPointSize) })
    }

    @Test("시작선은 아이콘 크기와 라벨 간격에서 유도된다")
    func startsAreDerivedFromTheParentLabelGeometry() throws {
        let probe = try #require(ExpandedRowProbe(childCount: 1, formatting: .cpu))
        let parentBearing = try #require(leadingSideBearing(Text(parentDisplayName).font(.caption)))
        let parentStart = probe.parentNameInkX - parentBearing
        #expect(CGFloat(parentStart - probe.iconEndX) == ApplicationProcessRowLayout.labelIconSpacing)
        #expect(ApplicationProcessRowLayout.labelIconSpacing == DashboardStyle.Spacing.labelToContent)
        #expect(ApplicationProcessRowLayout.childIndent == ApplicationProcessRowLayout.disclosureTriangleWidth
            + ApplicationRowIconLayout.detailPointSize + ApplicationProcessRowLayout.labelIconSpacing)
        #expect(ApplicationProcessRowLayout.childValueIndent
            == ApplicationProcessRowLayout.childIndent + ApplicationRowIconLayout.detailPointSize)
    }
}

@Suite("하위 프로세스 행의 네 간격")
@MainActor
struct ApplicationProcessRowSpacingTests {
    private func lineHeight() -> CGFloat { measuredHeight(textLine("Helper")) }

    private func inkTopOffset(_ text: String) throws -> Int {
        let bitmap = try #require(renderedBitmap(textLine(text)))
        return try #require(inkBands(in: bitmap).first?.lowerBound)
    }

    private func list(groupCount: Int) -> some View {
        ApplicationProcessGroupListView(
            groups: (0..<groupCount).map { fixtureGroup(childCount: 3, keySuffix: "-\($0)") },
            sortDescription: "CPU 사용률 순", groupValue: DetailValueFormatting.cpu.groupValueText,
            iconProvider: iconProvider(), valueText: DetailValueFormatting.cpu.valueText
        )
    }

    private func listRowSpacing() -> CGFloat {
        measuredHeight(list(groupCount: 2)) - measuredHeight(list(groupCount: 1)) - measuredHeight(collapsedRow())
    }

    private func measuredBoundaries() throws -> (within: CGFloat, between: CGFloat, top: CGFloat, bottom: CGFloat) {
        let formatting = DetailValueFormatting.cpu
        let process = childProcess(index: 0)
        let probe = try #require(ExpandedRowProbe(childCount: 3, formatting: formatting))
        let line = lineHeight()
        let nameOffset = try inkTopOffset(childName(process))
        let valueOffset = try inkTopOffset(formatting.valueText(process))
        let nameTops = probe.nameInkTopY.map { CGFloat($0 - nameOffset) }
        let valueTops = probe.valueInkTopY.map { CGFloat($0 - valueOffset) }
        return (
            valueTops[0] - nameTops[0] - line,
            nameTops[1] - valueTops[0] - line,
            nameTops[0] - measuredHeight(collapsedRow()),
            measuredHeight(expandedRow(childCount: 3, formatting: formatting))
                - (valueTops[2] + line) + listRowSpacing()
        )
    }

    @Test("네 간격이 2 / 10 / 18 / 26pt다")
    func boundariesMeasureTwoTenEighteenTwentySix() throws {
        let measured = try measuredBoundaries()
        #expect(measured.within == 2)
        #expect(measured.between == 10)
        #expect(measured.top == 18)
        #expect(measured.bottom == 26)
    }

    @Test("네 간격은 모두 다르고 층을 넘을수록 넓어진다")
    func boundariesAreDistinctAndOrdered() throws {
        let measured = try measuredBoundaries()
        let values = [measured.within, measured.between, measured.top, measured.bottom]
        #expect(Set(values).count == 4, "네 경계 \(values) 중 같은 값이 있습니다")
        #expect(measured.within < measured.between)
        #expect(measured.between < measured.top)
        #expect(measured.top < measured.bottom)
    }

    @Test("하위가 1·2·3개일 때 접힘 대비 70pt에서 38pt씩 늘어난다", arguments: [1, 2, 3], DetailValueFormatting.allCases)
    fileprivate func expandedHeightFollowsTheFourBoundaries(childCount: Int, formatting: DetailValueFormatting) {
        let growth = measuredHeight(expandedRow(childCount: childCount, formatting: formatting))
            - measuredHeight(collapsedRow(formatting: formatting))
        #expect(growth == 70 + CGFloat(childCount - 1) * 38)
    }

    @Test("접힌 앱 행 사이 간격이 변경 전과 같다")
    func collapsedRowsKeepTheirPreviousSpacing() {
        #expect(measuredHeight(collapsedRow()) == 24)
        #expect(listRowSpacing() == ApplicationProcessRowLayout.listRowSpacing)
        #expect(ApplicationProcessRowLayout.listRowSpacing == ApplicationProcessGroupListView.rowSpacing)
        #expect(ApplicationProcessRowLayout.afterLastChild == 24)
    }
}

@Suite("긴 하위 프로세스의 두 줄 폭")
@MainActor
struct ApplicationProcessRowWidthTests {
    private var longestProcess: ApplicationProcessDetail {
        childProcess(index: 0, executableName: longestChildExecutableName)
    }

    @Test("production CPU 값과 긴 이름이 각 줄에서 360pt 안에 들어간다")
    func productionNameAndValueFitOnSeparateLines() {
        let value = ApplicationProcessValueFormatting.cpuProcessValueText(longestProcess)
        let nameWidth = measuredIdealWidth(textLine(childName(longestProcess))
            .padding(.leading, ApplicationProcessRowLayout.childIndent))
        let valueWidth = measuredIdealWidth(textLine(value)
            .padding(.leading, ApplicationProcessRowLayout.childValueIndent))
        #expect(value == "12% (코어 합산) · Rosetta")
        #expect(nameWidth <= applicationListInnerWidth)
        #expect(valueWidth <= applicationListInnerWidth)
    }

    @Test("같은 production 조합을 한 줄로 두면 360pt를 넘는다")
    func productionCombinationCannotFitOnOneLine() {
        let value = ApplicationProcessValueFormatting.cpuProcessValueText(longestProcess)
        let oneLine = HStack {
            Text(childName(longestProcess))
            Spacer()
            Text(value)
        }
        .font(.caption2)
        .padding(.leading, ApplicationProcessRowLayout.childIndent)
        #expect(measuredIdealWidth(oneLine) > applicationListInnerWidth)
    }
}

@Suite("CPU·Memory 공용 하위 행 경로")
@MainActor
struct DetailViewsShareTheApplicationRowTests {
    @Test("CPU와 Memory 모두 같은 두 줄 높이와 시작선 규칙을 쓴다", arguments: DetailValueFormatting.allCases)
    fileprivate func bothFormatsUseTheSameRowGeometry(formatting: DetailValueFormatting) throws {
        let probe = try #require(ExpandedRowProbe(childCount: 2, formatting: formatting))
        let growth = measuredHeight(expandedRow(childCount: 2, formatting: formatting))
            - measuredHeight(collapsedRow(formatting: formatting))
        #expect(probe.nameInkX.count == 2)
        #expect(probe.valueInkX.count == 2)
        #expect(growth == 108)
    }
}

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

    private var collapsedApplicationRowPitch: CGFloat {
        measuredHeight(collapsedRow()) + ApplicationProcessRowLayout.listRowSpacing
    }

    @Test("CPU 상세는 앱 하나를 더하면 접힌 행과 목록 간격만큼 늘어난다")
    func cpuDetailGrowsByOneApplicationRowPitch() {
        let growth = measuredHeight(cpuDetail(groupCount: 2), width: 400 - 32)
            - measuredHeight(cpuDetail(groupCount: 1), width: 400 - 32)

        #expect(
            growth == collapsedApplicationRowPitch,
            "CPU 상세가 앱 하나에 \(growth)pt 늘어, 앱 행 피치 \(collapsedApplicationRowPitch)pt와 다릅니다"
        )
    }

    @Test("Memory 상세는 앱 하나를 더하면 접힌 행과 목록 간격만큼 늘어난다")
    func memoryDetailGrowsByOneApplicationRowPitch() {
        let growth = measuredHeight(memoryDetail(groupCount: 2), width: 400 - 32)
            - measuredHeight(memoryDetail(groupCount: 1), width: 400 - 32)

        #expect(
            growth == collapsedApplicationRowPitch,
            "Memory 상세가 앱 하나에 \(growth)pt 늘어, 앱 행 피치 \(collapsedApplicationRowPitch)pt와 다릅니다"
        )
    }
}
