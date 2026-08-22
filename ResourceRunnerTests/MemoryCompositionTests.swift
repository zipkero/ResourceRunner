//
//  MemoryCompositionTests.swift
//  ResourceRunnerTests
//
//  task-007 검증 조건: Memory 구성 구간 계산과 카드 범례 서식을 덮습니다.
//

import Testing
@testable import ResourceRunner

private let gibibyte: UInt64 = 1024 * 1024 * 1024

private func compositionBytes(
    app: UInt64 = 4 * gibibyte,
    wired: UInt64 = 2 * gibibyte,
    compressed: UInt64 = 2 * gibibyte,
    cached: UInt64 = gibibyte
) -> MemoryCompositionBytes {
    MemoryCompositionBytes(app: app, wired: wired, compressed: compressed, cached: cached)
}

/// 「사용 중」만 다르고 구성 네 항목·전체 물리 메모리는 같은 카드 표시 값을 만듭니다.
private func memoryPresentation(usedBytes: UInt64) -> MemoryCardPresentation {
    MemoryCardPresentation.assemble(
        memory: MemorySystemMetrics(
            totalPhysicalBytes: 16 * gibibyte,
            usedBytes: usedBytes,
            appBytes: 4 * gibibyte,
            wiredBytes: 2 * gibibyte,
            compressedBytes: 2 * gibibyte,
            cachedBytes: gibibyte,
            swapUsedBytes: 0,
            pressureLevel: .normal
        ),
        history: [],
        topApplications: [],
        currentTimestamp: ContinuousClock().now
    )
}

struct MemoryCompositionLayoutTests {

    /// 이 테스트가 고정하는 것: 분모가 전체 물리 메모리라는 것과, 누적 시작 비율이 앞 항목들의 비율 합이라는 것.
    /// 분모를 네 항목의 합(9GiB)으로 바꿔 정규화하면 비율이 0.25가 아니라 4/9가 되어 실패하고,
    /// 누적 시작 비율을 0으로 고정해 구간을 겹쳐 그리면 시작 비율 단언이 실패합니다.
    @Test func segmentRatiosAreBytesOverTotalPhysicalMemory() throws {
        let layout = MemoryCompositionLayout.make(bytes: compositionBytes(), totalPhysicalBytes: 16 * gibibyte)

        try #require(layout.segments.count == 4)
        #expect(layout.segments.map(\.category) == [.app, .wired, .compressed, .cached])
        #expect(layout.segments.map(\.bytes) == [4 * gibibyte, 2 * gibibyte, 2 * gibibyte, gibibyte])
        #expect(layout.segments.map(\.ratio) == [0.25, 0.125, 0.125, 0.0625])
        #expect(layout.segments.map(\.startRatio) == [0, 0.25, 0.375, 0.5])
        #expect(layout.isOverflowing == false)
    }

    /// 네 항목 합(20GiB)이 전체 물리 메모리(16GiB)를 넘는 입력.
    /// 자르기를 지우면 세 번째 구간의 비율이 0.25가 아니라 0.375가 되고 네 번째 시작 비율이 1을 넘어 실패합니다.
    @Test func overflowingCompositionIsClippedAtTrackEnd() throws {
        let layout = MemoryCompositionLayout.make(
            bytes: compositionBytes(app: 8 * gibibyte, wired: 4 * gibibyte, compressed: 6 * gibibyte, cached: 2 * gibibyte),
            totalPhysicalBytes: 16 * gibibyte
        )

        try #require(layout.segments.count == 4)
        #expect(layout.isOverflowing)
        #expect(layout.segments.map(\.ratio) == [0.5, 0.25, 0.25, 0])
        #expect(layout.segments.map(\.startRatio) == [0, 0.5, 0.75, 1])
        // 범례에 적히는 수치는 자르지 않습니다 — 길이만 트랙 안으로 들어옵니다.
        #expect(layout.segments.map(\.bytes) == [8 * gibibyte, 4 * gibibyte, 6 * gibibyte, 2 * gibibyte])
        for segment in layout.segments {
            #expect(segment.startRatio + segment.ratio <= 1, "구간이 트랙을 벗어났습니다: \(segment)")
        }
    }

    /// 전체 물리 메모리가 0이면 비율을 만들 기준이 없으므로 구간을 만들지 않습니다.
    /// 이 입력에서 구간을 만들면(예: 길이 0 구간 네 개를 돌려주면) 실패합니다.
    @Test func zeroTotalPhysicalMemoryProducesNoSegments() {
        let layout = MemoryCompositionLayout.make(bytes: compositionBytes(), totalPhysicalBytes: 0)

        #expect(layout.segments.isEmpty)
        #expect(layout.isOverflowing == false)
        #expect(type(of: layout.segments) == [MemoryCompositionSegment].self)
    }

    /// 구성 계산이 「사용 중」에 의존하지 않는다는 것을, 「사용 중」만 다른 두 표시 값이
    /// 같은 구간을 만드는 것으로 확인합니다.
    /// 「사용 중」을 채운 길이로 삼아 그 안을 비율로 나누면 두 결과가 갈리고, 비율 단언도 함께 실패합니다.
    @Test func compositionDoesNotDependOnUsedBytes() throws {
        let low = memoryPresentation(usedBytes: 2 * gibibyte).compositionLayout
        let high = memoryPresentation(usedBytes: 15 * gibibyte).compositionLayout

        #expect(low == high)
        try #require(low.segments.count == 4)
        #expect(low.segments.map(\.ratio) == [0.25, 0.125, 0.125, 0.0625])
    }
}

struct MemoryCompositionLegendTests {

    /// 이 테스트가 고정하는 것: 범례 항목 순서가 바 구간 순서와 같고, 각 색 스와치 뒤에 그 항목의 이름이 붙는다는 것.
    /// 순서를 뒤바꾸거나, 이름을 빼 색 스와치만 남기면 실패합니다.
    ///
    /// 범례는 수치를 담지 않으므로 캐시된 값이 있든 없든 같은 상수입니다 —
    /// 카드에 남는 수치는 병합 줄의 구성 합계 하나이고,
    /// 항목별 수치는 상세 범례(task-008)와 카드 접근성 이름(task-012)이 맡습니다.
    @Test func legendFollowsBarSegmentOrderWithNames() {
        #expect(MemoryCompositionLegendFormatting.segments == [
            .swatch(.app), .label("App"),
            .separator,
            .swatch(.wired), .label("Wired"),
            .separator,
            .swatch(.compressed), .label("Compressed"),
            .separator,
            .swatch(.cached), .label("Cached")
        ])
    }

    /// 범례 줄 수 상한. 뷰가 이 상수로 `lineLimit`을 걸어 폭이 부족해도 두 줄이 되지 않습니다.
    /// 범례가 축소 없이 한 줄에 들어가는 크기라 렌더 높이 측정으로는 이 상한을 판정할 수 없어,
    /// task-006과 같이 상수 자체를 단언해 그 자리를 맡습니다.
    @Test func maximumLineCountIsOne() {
        #expect(MemoryCompositionLegendFormatting.maximumLineCount == 1)
    }
}

struct MemoryCompositionTotalTests {

    /// 이 테스트가 고정하는 것: 카드가 보여 주는 구성 합계가 네 항목 **전부**의 합이라는 것.
    /// 합계가 한 항목만 돌려주거나 한 항목을 빼고 더하면 실패합니다.
    @Test func totalIsTheSumOfAllFourCategories() {
        #expect(compositionBytes().total == 9 * gibibyte)
        #expect(compositionBytes(app: 0, wired: 0, compressed: 0, cached: 0).total == 0)
        #expect(compositionBytes(app: 1, wired: 2, compressed: 4, cached: 8).total == 15)
    }

    /// 넘침으로 바 구간이 트랙 끝에서 잘려도 합계는 실제 바이트 그대로입니다 —
    /// 합계를 잘린 구간 길이에서 유도하면(트랙 상한인 16GiB로 묶이면) 실패합니다.
    @Test func totalKeepsRealBytesWhileSegmentsAreClipped() throws {
        let bytes = compositionBytes(
            app: 10 * gibibyte,
            wired: 4 * gibibyte,
            compressed: 3 * gibibyte,
            cached: 2 * gibibyte
        )
        let layout = MemoryCompositionLayout.make(bytes: bytes, totalPhysicalBytes: 16 * gibibyte)

        try #require(layout.isOverflowing)
        #expect(bytes.total == 19 * gibibyte)
        #expect(layout.segments.map(\.ratio).reduce(0, +) == 1)
    }

    /// 실제 시스템에서는 나올 수 없는 입력이지만, 합이 `UInt64`를 넘을 때 trap하지 않고 상한에서 멈춥니다 —
    /// `+`로 그냥 더하면 이 입력에서 크래시합니다.
    @Test func totalSaturatesInsteadOfTrappingOnOverflow() {
        #expect(compositionBytes(app: .max, wired: 1, compressed: 0, cached: 0).total == .max)
    }

    /// 카드 표시 값이 병합 줄에 넘기는 수치가 「사용 중」이 아니라 구성 합계라는 것을,
    /// 「사용 중」만 다른 두 표시 값이 같은 합계를 내는 것으로 확인합니다.
    /// `compositionTotalBytes`가 `usedBytes`를 돌려주게 바꾸면 두 값이 갈려 실패합니다.
    @Test func cardCompositionTotalIgnoresUsedBytes() {
        let low = memoryPresentation(usedBytes: 2 * gibibyte)
        let high = memoryPresentation(usedBytes: 15 * gibibyte)

        #expect(low.compositionTotalBytes == high.compositionTotalBytes)
        #expect(low.compositionTotalBytes == 9 * gibibyte)
        #expect(low.compositionTotalBytes != low.usedBytes)
    }
}
