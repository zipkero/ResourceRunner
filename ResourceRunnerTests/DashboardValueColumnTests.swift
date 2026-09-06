//
//  DashboardValueColumnTests.swift
//  ResourceRunnerTests
//
//  task-005 검증 조건: 값 종류별 서식·열 폭과 네 목록 자리의 실제 정렬을 확인합니다.
//

import AppKit
import SwiftUI
import Testing
@testable import ResourceRunner

private let valueColumnEnglishLocale = Locale(identifier: "en_US")

private let byteUnitProbes: [(bytes: UInt64, unit: String)] = [
    (0, "KB"),
    (1 << 20, "MB"),
    (1 << 30, "GB"),
    (1 << 40, "TB"),
    (1 << 50, "PB"),
    (1 << 60, "EB")
]

private let byteUpperBoundProbes: [UInt64] = [
    (1 << 20) - 1,
    (1 << 30) - 1,
    (1 << 40) - 1,
    (1 << 50) - 1,
    (1 << 60) - 1,
    .max
]

private let signedByteUpperBoundProbes: [Int64] = [
    (1 << 20) - 1,
    (1 << 30) - 1,
    (1 << 40) - 1,
    (1 << 50) - 1,
    (1 << 60) - 1,
    .max
]

@MainActor
private func measuredValueColumnWidth(_ view: some View) -> CGFloat {
    NSHostingController(rootView: view.fixedSize(horizontal: true, vertical: false))
        .sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        .width
}

@MainActor
private func renderedValueColumnBitmap(_ view: some View, width: CGFloat) -> NSBitmapImageRep? {
    let renderer = ImageRenderer(content: view.frame(width: width).environment(\.colorScheme, .light))
    renderer.scale = 1
    guard let data = renderer.nsImage?.tiffRepresentation else { return nil }
    return NSBitmapImageRep(data: data)
}

private struct ValueColumnInkAnchors: Equatable {
    let numberTrailing: Int
    let unitLeading: Int
}

/// 행 오른쪽 끝에 놓인 고정 폭 두 열을 직접 렌더해 숫자 잉크의 오른쪽 끝과 단위 잉크의 시작을 잽니다.
private func valueColumnInkAnchors(
    in bitmap: NSBitmapImageRep,
    kind: DashboardValueColumn.Kind
) -> ValueColumnInkAnchors? {
    let boundary = bitmap.pixelsWide - Int(kind.unitWidth)
    let numberStart = boundary - Int(kind.numberWidth)
    let inked: (Int, Range<Int>) -> Bool = { x, yRange in
        yRange.contains { y in
            (bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB)?.alphaComponent ?? 0) > 0.05
        }
    }
    let yRange = 0..<bitmap.pixelsHigh
    guard
        let numberTrailing = (numberStart..<boundary).reversed().first(where: { inked($0, yRange) }),
        let unitLeading = (boundary..<bitmap.pixelsWide).first(where: { inked($0, yRange) })
    else { return nil }
    return ValueColumnInkAnchors(numberTrailing: numberTrailing, unitLeading: unitLeading)
}

private func rankingEntry(_ index: Int, value: Double) -> ApplicationRankingEntry {
    ApplicationRankingEntry(
        key: ApplicationKey(value: "/Applications/ValueColumn\(index).app"),
        displayName: "앱 \(index)",
        value: value
    )
}

@Suite("대시보드 값 열 서식")
struct DashboardValueColumnFormattingTests {
    @Test("바이트는 1024 기반·KB 하한·소수 한 자리 고정이다")
    func bytesUseBinaryUnitsWithFixedFraction() {
        #expect(DashboardValueColumn.bytes(0, locale: valueColumnEnglishLocale).text == "0.0 KB")
        #expect(DashboardValueColumn.bytes(512, locale: valueColumnEnglishLocale).text == "0.5 KB")
        #expect(DashboardValueColumn.bytes(16 * 1024 * 1024 * 1024, locale: valueColumnEnglishLocale).text == "16.0 GB")
        #expect(DashboardValueColumn.bytes(1024 * 1024 - 1, locale: valueColumnEnglishLocale).unit == "KB")
        #expect(DashboardValueColumn.bytes(1024 * 1024, locale: valueColumnEnglishLocale).unit == "MB")
    }

    @Test("바이트 숫자는 로케일 소수 구분자를 따른다")
    func byteDecimalSeparatorFollowsLocale() {
        let french = DashboardValueColumn.bytes(1536, locale: Locale(identifier: "fr_FR"))
        #expect(french.number == "1,5")
        #expect(french.unit == "KB")
    }

    @Test("퍼센트는 정수 반올림과 기존 단위 라벨을 유지한다")
    func percentKeepsIntegerPrecisionAndUnits() {
        let overall = DashboardValueColumn.percent(12.6, unit: CPUCardPresentation.overallUsageUnitLabel)
        let process = DashboardValueColumn.percent(12.3, unit: ApplicationProcessDetail.cpuUsageUnitLabel)
        #expect(overall.number == "13")
        #expect(overall.unit == "%")
        #expect(overall.text == "13%")
        #expect(process.number == "12")
        #expect(process.unit == "% (코어 합산)")
    }

    @Test("부호 있는 바이트는 부호를 숫자 열에 보존한다")
    func signedBytesKeepSignInNumberColumn() {
        #expect(DashboardValueColumn.signedBytes(1536, locale: valueColumnEnglishLocale).text == "+1.5 KB")
        #expect(DashboardValueColumn.signedBytes(-1536, locale: valueColumnEnglishLocale).text == "-1.5 KB")
        #expect(DashboardValueColumn.signedBytes(.min, locale: valueColumnEnglishLocale).number.hasPrefix("-"))
    }
}

@Suite("대시보드 값 열 폭")
@MainActor
struct DashboardValueColumnWidthTests {
    private func maximumWidth(of texts: [String], typography: DashboardStyle.Typography) -> (text: String, width: CGFloat)? {
        texts.map { text in
            (
                text,
                measuredValueColumnWidth(Text(text).dashboardTypography(typography))
            )
        }
        .max { $0.1 < $1.1 }
    }

    @Test("각 값 종류의 전체 숫자 후보 중 최댓값이 고정 숫자 열 안에 든다")
    func widestNumberFitsItsMeasuredColumn() {
        let byteNumbers = byteUpperBoundProbes.map {
            DashboardValueColumn.bytes($0, locale: valueColumnEnglishLocale).number
        }
        let signedByteNumbers = signedByteUpperBoundProbes.flatMap { bytes in
            [
                DashboardValueColumn.signedBytes(bytes, locale: valueColumnEnglishLocale).number,
                DashboardValueColumn.signedBytes(-bytes, locale: valueColumnEnglishLocale).number
            ]
        }
        let probes: [(texts: [String], columnWidth: CGFloat)] = [
            (["0", "9999"], DashboardStyle.ValueColumn.percentNumberWidth),
            (byteNumbers, DashboardStyle.ValueColumn.byteNumberWidth),
            (signedByteNumbers, DashboardStyle.ValueColumn.signedByteNumberWidth)
        ]
        for (texts, columnWidth) in probes {
            guard let widest = maximumWidth(of: texts, typography: DashboardStyle.TypographyRole.value) else {
                Issue.record("숫자 폭 후보가 비었습니다")
                continue
            }
            #expect(
                widest.width <= columnWidth,
                "전체 숫자 후보 \(texts) 중 \(widest.text)의 이상적 폭 \(widest.width)이 숫자 열 \(columnWidth)을 넘습니다"
            )
        }
    }

    @Test("실제 전체 바이트 단위 집합 중 최댓값이 고정 단위 열 안에 든다")
    func widestUnitFitsItsMeasuredColumn() {
        let byteValues = byteUnitProbes.map {
            DashboardValueColumn.bytes($0.bytes, locale: valueColumnEnglishLocale)
        }
        #expect(byteValues.map(\.unit) == byteUnitProbes.map { $0.unit })

        let probes: [(texts: [String], columnWidth: CGFloat)] = [
            ([" %"], DashboardStyle.ValueColumn.compactUnitWidth),
            (byteValues.map { " \($0.unit)" }, DashboardStyle.ValueColumn.byteUnitWidth),
            ([" \(ApplicationProcessDetail.cpuUsageUnitLabel)"], DashboardStyle.ValueColumn.processPercentUnitWidth)
        ]
        for (texts, columnWidth) in probes {
            guard let widest = maximumWidth(of: texts, typography: DashboardStyle.TypographyRole.label) else {
                Issue.record("단위 폭 후보가 비었습니다")
                continue
            }
            #expect(
                widest.width <= columnWidth,
                "전체 단위 후보 \(texts) 중 \(widest.text)의 이상적 폭 \(widest.width)이 단위 열 \(columnWidth)을 넘습니다"
            )
        }
    }
}

@Suite("네 목록 자리의 값 열 렌더 정렬")
@MainActor
struct DashboardValueColumnAlignmentTests {
    private func expectSameAnchors(
        _ rows: [AnyView],
        width: CGFloat,
        kind: DashboardValueColumn.Kind,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let anchors = try rows.map { row in
            let bitmap = try #require(renderedValueColumnBitmap(row, width: width), sourceLocation: sourceLocation)
            return try #require(valueColumnInkAnchors(in: bitmap, kind: kind), sourceLocation: sourceLocation)
        }
        #expect(
            Set(anchors.map(\.numberTrailing)).count == 1,
            "숫자 열 오른쪽 잉크가 \(anchors.map(\.numberTrailing))로 갈립니다",
            sourceLocation: sourceLocation
        )
        #expect(
            Set(anchors.map(\.unitLeading)).count == 1,
            "단위 열 시작 잉크가 \(anchors.map(\.unitLeading))로 갈립니다",
            sourceLocation: sourceLocation
        )
    }

    @Test("카드 순위 행의 숫자 오른쪽 끝과 단위 시작이 같다")
    func cardRankingRowsAlign() throws {
        let entries = [10, 100, 1000].enumerated().map { rankingEntry($0.offset, value: Double($0.element)) }
        let slot = CardRankingSlotView(
            entries: entries,
            failed: false,
            heading: "",
            value: { DashboardValueColumn.percent($0.value, unit: "%") },
            iconProvider: StubApplicationIconProvider()
        )
        let rows = entries.enumerated().map { AnyView(slot.row(at: $0.offset, iconKey: $0.element.key)) }
        try expectSameAnchors(rows, width: 232, kind: .percent(unit: "%"))
    }

    @Test("상세 앱 목록 행의 숫자 오른쪽 끝과 단위 시작이 같다")
    func applicationGroupRowsAlign() throws {
        let rows = [10.0, 100.0, 1000.0].enumerated().map { index, value in
            let group = ApplicationProcessGroup(
                key: ApplicationKey(value: "/Applications/Group\(index).app"),
                displayName: "그룹 \(index)",
                processes: [],
                sortValue: value
            )
            return AnyView(ApplicationProcessGroupRow(
                group: group,
                groupValue: ApplicationProcessValueFormatting.cpuGroupValueText,
                valueText: ApplicationProcessValueFormatting.cpuProcessValueText,
                iconProvider: StubApplicationIconProvider(),
                isExpanded: .constant(false)
            ))
        }
        try expectSameAnchors(rows, width: 360, kind: .percent(unit: ApplicationProcessDetail.cpuUsageUnitLabel))
    }

    @Test("상세 범례 행의 숫자 오른쪽 끝과 단위 시작이 같다")
    func memoryLegendRowsAlign() throws {
        // 범례 앞부분의 이름·기호 폭은 서로 다르게 두되, 숫자 잉크 자체의 안티앨리어싱 위상 차이가
        // 고정 열의 x 좌표 검증을 흐리지 않도록 끝 글자가 같은 동일 자릿수 값을 씁니다.
        let rows = [1, 2, 3].enumerated().map { index, gibibytes in
            MemoryCompositionDetailLegendRow(
                category: MemoryCompositionCategory.allCases[index],
                label: MemoryCompositionCategory.allCases[index].label,
                value: DashboardValueColumn.bytes(UInt64(gibibytes) * 1024 * 1024 * 1024, locale: valueColumnEnglishLocale)
            )
        }
        let donut = MemoryCompositionDonutView(
            layout: MemoryCompositionDonutLayout(segments: []),
            legendRows: rows,
            centerLabel: "",
            centerValue: "",
            accessibilityLabel: ""
        )
        try expectSameAnchors(rows.map { AnyView(donut.legendRow($0)) }, width: 212, kind: .bytes)
    }

    @Test("상세 증가량 순위 행의 숫자 오른쪽 끝과 단위 시작이 같다")
    func recentIncreaseRowsAlign() throws {
        let entries = [1, 10, 100].enumerated().map { rankingEntry($0.offset, value: Double($0.element * 1024 * 1024 * 1024)) }
        let list = TopApplicationsView(
            entries: entries,
            caption: "",
            value: { DashboardValueColumn.signedBytes(Int64($0.value), locale: valueColumnEnglishLocale) },
            iconProvider: StubApplicationIconProvider()
        )
        try expectSameAnchors(entries.map { AnyView(list.row($0)) }, width: 360, kind: .signedBytes)
    }
}
