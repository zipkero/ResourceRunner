//
//  MemoryCompositionDetailTests.swift
//  ResourceRunnerTests
//
//  task-008 검증 조건: Memory 상세 도넛 각도, 수치 범례, 구성 합계와 「사용 중」 분리를 덮습니다.
//

import SwiftUI
import Testing
@testable import ResourceRunner

private let detailGibibyte: UInt64 = 1024 * 1024 * 1024

private func detailCompositionBytes(
    app: UInt64 = 4 * detailGibibyte,
    wired: UInt64 = 2 * detailGibibyte,
    compressed: UInt64 = 2 * detailGibibyte,
    cached: UInt64 = detailGibibyte
) -> MemoryCompositionBytes {
    MemoryCompositionBytes(app: app, wired: wired, compressed: compressed, cached: cached)
}

private func detailMemoryPresentation(usedBytes: UInt64 = 8 * detailGibibyte) -> MemoryCardPresentation {
    MemoryCardPresentation.assemble(
        memory: MemorySystemMetrics(
            totalPhysicalBytes: 16 * detailGibibyte,
            usedBytes: usedBytes,
            appBytes: 4 * detailGibibyte,
            wiredBytes: 2 * detailGibibyte,
            compressedBytes: 2 * detailGibibyte,
            cachedBytes: detailGibibyte,
            swapUsedBytes: 0,
            pressureLevel: .normal
        ),
        history: [],
        topApplications: [],
        currentTimestamp: ContinuousClock().now
    )
}

struct MemoryCompositionDonutLayoutTests {

    /// 전체 물리 메모리 기준 비율을 정규화하지 않고 12시에서 시계 방향으로 각도로 옮깁니다.
    /// 네 항목 합으로 정규화하거나 시작 방향·회전 방향을 바꾸면 이 단언이 실패합니다.
    @Test func anglesPreserveTrackRatiosWithFixedStartAndDirection() {
        let cardLayout = MemoryCompositionLayout.make(
            bytes: detailCompositionBytes(),
            totalPhysicalBytes: 16 * detailGibibyte
        )
        let donut = MemoryCompositionDonutLayout.make(from: cardLayout)

        #expect(donut.segments.map(\.category) == [.app, .wired, .compressed, .cached])
        #expect(donut.segments.map(\.ratio) == [0.25, 0.125, 0.125, 0.0625])
        #expect(donut.segments.map(\.startAngleDegrees) == [-90, 0, 45, 90])
        #expect(donut.segments.map(\.endAngleDegrees) == [0, 45, 90, 112.5])
    }

    /// 넘친 카드 구간은 이미 트랙 끝에서 잘려 있으므로 각도 합도 한 바퀴를 넘지 않습니다.
    /// 상세 각도 변환에서 원래 바이트 비율을 다시 계산해 넘침 처리를 지우면 실패합니다.
    @Test func overflowingSegmentsNeverExceedOneFullTurn() {
        let cardLayout = MemoryCompositionLayout.make(
            bytes: detailCompositionBytes(
                app: 8 * detailGibibyte,
                wired: 4 * detailGibibyte,
                compressed: 6 * detailGibibyte,
                cached: 2 * detailGibibyte
            ),
            totalPhysicalBytes: 16 * detailGibibyte
        )
        let donut = MemoryCompositionDonutLayout.make(from: cardLayout)

        #expect(donut.segments.map(\.ratio).reduce(0, +) == 1)
        #expect(donut.segments.allSatisfy { $0.endAngleDegrees <= 270 })
        #expect(donut.segments.last?.endAngleDegrees == 270)
    }

    /// 카드와 상세은 같은 `MemoryCompositionLayout.make` 결과를 공유하고 상세은 각도만 더합니다.
    /// 상세 전용 계산에서 네 항목 합을 분모로 쓰면 아래 항목 순서·비율 일치가 깨집니다.
    @Test func detailUsesTheExactCardCompositionLayout() {
        let presentation = detailMemoryPresentation()
        let cardSegments = presentation.compositionLayout.segments
        let donutSegments = presentation.compositionDonutLayout.segments

        #expect(donutSegments.map(\.category) == cardSegments.map(\.category))
        #expect(donutSegments.map(\.bytes) == cardSegments.map(\.bytes))
        #expect(donutSegments.map(\.ratio) == cardSegments.map(\.ratio))
        #expect(donutSegments.map(\.startRatio) == cardSegments.map(\.startRatio))
    }
}

struct MemoryCompositionDetailLegendTests {

    /// 범례 네 행은 도넛과 같은 순서의 이름과 상세용 바이트 수치를 모두 가집니다.
    /// 수치를 지우거나 카드 축약 서식으로 바꿔치기하면 전체 행 비교가 실패합니다.
    @Test func rowsContainNamesAndDetailedByteValuesInDonutOrder() {
        let rows = MemoryCompositionDetailLegendFormatting.rows(
            bytes: detailCompositionBytes()
        )

        #expect(rows == [
            MemoryCompositionDetailLegendRow(category: .app, label: "App", value: DashboardValueColumn.Value(number: "4.0", unit: "GB", kind: .bytes)),
            MemoryCompositionDetailLegendRow(category: .wired, label: "Wired", value: DashboardValueColumn.Value(number: "2.0", unit: "GB", kind: .bytes)),
            MemoryCompositionDetailLegendRow(category: .compressed, label: "Compressed", value: DashboardValueColumn.Value(number: "2.0", unit: "GB", kind: .bytes)),
            MemoryCompositionDetailLegendRow(category: .cached, label: "Cached", value: DashboardValueColumn.Value(number: "1.0", unit: "GB", kind: .bytes))
        ])
    }

    /// 값이 없을 때도 네 항목 이름은 남고 수치 자리만 `-`가 됩니다.
    @Test func unavailableValuesUseDashWithoutDroppingLegendRows() {
        let rows = MemoryCompositionDetailLegendFormatting.rows(bytes: nil)

        #expect(rows.map(\.label) == ["App", "Wired", "Compressed", "Cached"])
        #expect(rows.map(\.value.text) == ["-", "-", "-", "-"])
    }
}

struct MemoryCompositionDetailSummaryTests {

    /// 도넛 가운데는 구성 합계이고 「사용 중」은 자기 라벨을 단 별도 값입니다.
    /// 가운데 값을 `usedBytes`로 바꾸거나 두 수치를 같은 자리에 합치면 실패합니다.
    @Test func compositionTotalAndUsedBytesHaveDistinctLabelsAndPositions() {
        let summary = MemoryCompositionDetailSummary.make(
            compositionBytes: detailCompositionBytes(),
            usedBytes: 15 * detailGibibyte
        )

        #expect(summary.donutCenter.label == "구성 합계")
        #expect(summary.donutCenter.bytes == 9 * detailGibibyte)
        #expect(summary.usedLine.label == "사용 중")
        #expect(summary.usedLine.bytes == 15 * detailGibibyte)
        #expect(summary.donutCenter != summary.usedLine)
    }
}

@MainActor
private func legendIdealWidth(_ view: some View) -> CGFloat {
    NSHostingController(rootView: view.fixedSize(horizontal: true, vertical: false))
        .sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        .width
}

@MainActor
private func legendDonut(rows: [MemoryCompositionDetailLegendRow]) -> MemoryCompositionDonutView {
    MemoryCompositionDonutView(
        layout: MemoryCompositionDonutLayout(segments: []),
        legendRows: rows,
        centerLabel: "",
        centerValue: "",
        accessibilityLabel: ""
    )
}

@Suite("Memory 상세 범례 정렬")
@MainActor
struct MemoryCompositionDetailLegendAlignmentTests {

    /// 이름 열 폭이 네 구간 이름을 담는지 이름을 다시 재서 확인합니다.
    /// 이름이 길어지거나 라벨 역할 글꼴이 커지면 이 단언이 먼저 실패해 열 폭을 다시 재게 합니다.
    @Test("네 구간 이름의 이상적 폭 최댓값이 이름 열 폭 안에 든다")
    func widestCategoryNameFitsTheNameColumn() {
        let measured = MemoryCompositionCategory.allCases.map { category in
            (
                name: category.label,
                width: legendIdealWidth(
                    Text(category.label).dashboardTypography(DashboardStyle.TypographyRole.label)
                )
            )
        }

        guard let widest = measured.max(by: { $0.width < $1.width }) else {
            Issue.record("구간 이름 후보가 비었습니다")
            return
        }

        #expect(
            widest.width <= MemoryCompositionDonutView.legendNameWidth,
            "가장 넓은 이름 \(widest.name)의 이상적 폭 \(widest.width)이 이름 열 \(MemoryCompositionDonutView.legendNameWidth)을 넘습니다"
        )
    }

    /// 이름 열이 고정돼 네 행의 값 열이 같은 가로 위치에서 시작합니다.
    /// 이름 열 폭을 걷고 `Spacer`로 이름과 값을 양끝에 벌리면 행마다 값 시작 x가 갈려 실패합니다.
    @Test("네 범례 행의 값 열 시작 x가 서로 같다")
    func everyLegendRowStartsItsValueColumnAtTheSameX() {
        let rows = MemoryCompositionDetailLegendFormatting.rows(bytes: detailCompositionBytes())
        let donut = legendDonut(rows: rows)

        let valueStarts = rows.map { row in
            legendIdealWidth(donut.legendRow(row))
                - legendIdealWidth(DashboardAlignedValueView(value: row.value))
        }

        guard let first = valueStarts.first else {
            Issue.record("범례 행이 비었습니다")
            return
        }
        for (row, start) in zip(rows, valueStarts) {
            #expect(
                abs(start - first) < 0.5,
                "\(row.label) 행의 값 열 시작 x \(start)이 첫 행의 \(first)과 다릅니다"
            )
        }
    }
}
