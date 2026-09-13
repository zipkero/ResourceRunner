//
//  DashboardPresentationTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/15/26.
//

import Darwin
import Foundation
import SwiftUI
import Testing
@testable import ResourceRunner

private let baseInstant = ContinuousClock().now

private func cpuMetrics(overallUsage: Double = 42, userRatio: Double = 30, systemRatio: Double = 12) -> CPUSystemMetrics {
    CPUSystemMetrics(
        overallUsage: overallUsage,
        userRatio: userRatio,
        systemRatio: systemRatio,
        idleRatio: 100 - overallUsage,
        coreUsages: [overallUsage],
        loadAverage: LoadAverage(oneMinute: 0, fiveMinutes: 0, fifteenMinutes: 0)
    )
}

private func historyPoint(secondsFromBase: Double, overallCPUUsage: Double = 10, userRatio: Double = 0) -> SystemMetricsHistoryPoint {
    SystemMetricsHistoryPoint(
        timestamp: baseInstant.advanced(by: .seconds(secondsFromBase)),
        overallCPUUsage: overallCPUUsage,
        userRatio: userRatio,
        swapUsedBytes: 0
    )
}

private func rankingEntry(name: String, value: Double) -> ApplicationRankingEntry {
    ApplicationRankingEntry(key: ApplicationKey(value: "/Applications/\(name).app"), displayName: name, value: value)
}

private func processHistorySnapshot(
    pid: pid_t,
    executablePath: String,
    cpuUsagePercent: Double?,
    residentBytes: UInt64,
    isTranslated: Bool = false
) -> ProcessHistorySnapshot {
    ProcessHistorySnapshot(
        identity: ProcessIdentity(pid: pid, startTime: 0),
        executablePath: executablePath,
        recentValues: [ProcessRankingSample(cpuUsagePercent: cpuUsagePercent, residentBytes: residentBytes)],
        memoryBaselines: [],
        isTranslated: isTranslated
    )
}

// MARK: - 그래프 점의 연속 구간 분리

/// task-008 검증 조건이 고정하는 것: "빈 구간을 직선으로 잇지 않는다".
/// 간격이 벌어진 점 쌍이 하나의 연결 구간에 포함되면 실패하도록 연결 구간 목록을 단언하며,
/// 간격 판정을 제거하면(모든 점을 구간 하나로 합치면) 이 테스트가 실패해야 합니다.
struct HistoryPointConnectedSegmentsTests {

    @Test func emptyPointsProduceNoSegments() {
        #expect(HistoryPoint.connectedSegments(from: []).isEmpty)
    }

    @Test func singlePointProducesOneSegmentWithThatPoint() {
        let point = HistoryPoint(timestamp: baseInstant, value: 10)

        let segments = HistoryPoint.connectedSegments(from: [point])

        #expect(segments == [[point]])
    }

    @Test func adjacentPointsWithinGapStayInOneSegment() {
        let points = (0..<5).map { HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(Double($0))), value: Double($0)) }

        let segments = HistoryPoint.connectedSegments(from: points)

        #expect(segments.count == 1)
        #expect(segments.first?.count == 5)
    }

    /// 중지 구간을 포함한 이력: 정상 구간 두 tick, 큰 간격, 정상 구간 두 tick 순서로 넣으면
    /// 두 개의 분리된 구간이 나와야 합니다. 이 판정을 지우면(항상 하나로 합치면) 이 단언이 실패합니다.
    @Test func gapLargerThanMaximumSplitsIntoSeparateSegments() {
        let gap = HistoryPoint.maximumConnectedGap + .seconds(1)
        let points = [
            HistoryPoint(timestamp: baseInstant, value: 10),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(1)), value: 20),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(1)) + gap, value: 30),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(1)) + gap + .seconds(1), value: 40),
        ]

        let segments = HistoryPoint.connectedSegments(from: points)

        #expect(segments.count == 2)
        #expect(segments[0].count == 2)
        #expect(segments[1].count == 2)
    }

    @Test func gapExactlyAtMaximumStaysConnected() {
        let points = [
            HistoryPoint(timestamp: baseInstant, value: 10),
            HistoryPoint(timestamp: baseInstant + HistoryPoint.maximumConnectedGap, value: 20),
        ]

        let segments = HistoryPoint.connectedSegments(from: points)

        #expect(segments.count == 1)
    }
}

// MARK: - 그래프 다운샘플링(결함 수정 회귀 고정)

/// 이력 링 최대 601점을 실제 팝오버 렌더 폭(약 248pt)에 그대로 찍으면 점 간격이 원본 표본 간격까지 좁아져
/// 사용률 흐름이 뭉개지던 결함을 고정합니다. 아래 단언들은 각각
/// - 평균 대신 min·max로 순간 피크를 남기는지,
/// - 그리디 최소 간격 필터로 후보를 건너뛰지 않아 순간 스파이크·dip이 위치와 상관없이 전부 남는지,
/// - 세그먼트 분리를 버킷 묶음보다 먼저 해서 빈 구간이 보존되는지,
/// - 다운샘플링이 실제로 점 수를 줄이면서도 버킷당 최대 2점(min·max)이라는 상한을 넘지 않는지,
/// - 버킷 폭 상수가 4pt로 고정돼 있는지
/// 를 지우거나 반대로 바꾸면 실패하도록 고른 것입니다.
struct HistoryPointDownsamplingTests {

    @Test func bucketWidthIsFourPixelsPerBucket() {
        #expect(HistoryPoint.minimumDownsampledBucketSpacing == 4)
        #expect(HistoryPoint.downsampledBucketCount(forRenderWidth: 248) == 62)
    }

    @Test func bucketCountIsAtLeastOneForNarrowWidths() {
        #expect(HistoryPoint.downsampledBucketCount(forRenderWidth: 1) == 1)
    }

    /// `Canvas`/`GeometryReader`가 이론상 유한하지 않거나 0 이하인 폭을 넘길 때 `Int(width / ...)`가
    /// trap하지 않고 버킷 1개로 안전하게 처리되는지 확인합니다. 이 방어를 지우면 `Double.nan`·`.infinity`
    /// 입력에서 크래시가 재현됩니다.
    @Test(arguments: [Double.nan, .infinity, -.infinity, 0, -1])
    func bucketCountIsSafeForNonFiniteOrNonPositiveWidths(width: Double) {
        #expect(HistoryPoint.downsampledBucketCount(forRenderWidth: width) == 1)
    }

    /// 첫 버킷(인덱스 0..<3)은 평균(약 48.3)이 아니라 최솟값 0과 최댓값 100이 그대로 남아야 합니다.
    /// 평균으로 바꾸면 이 두 값 중 하나도 결과에 남지 않아 실패합니다.
    /// 둘째 버킷(인덱스 3..<5)도 그리디 필터로 건너뛰지 않고 min(60)·max(70)이 그대로 남습니다.
    @Test func bucketKeepsMinAndMaxInsteadOfAveraging() {
        let points = [
            HistoryPoint(timestamp: baseInstant, value: 0),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(1)), value: 45),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(2)), value: 100),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(3)), value: 60),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(4)), value: 70),
        ]

        let result = HistoryPoint.downsampled(segment: points, bucketCount: 2)

        #expect(result.map(\.value) == [0, 100, 60, 70])
    }

    /// min과 max가 같은 점(버킷 안 값이 전부 같음)이면 하나만 남아야 합니다.
    @Test func bucketWithAllEqualValuesKeepsOnlyOnePoint() {
        let points = (0..<4).map { HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(Double($0))), value: 10) }

        let result = HistoryPoint.downsampled(segment: points, bucketCount: 1)

        #expect(result.count == 1)
    }

    /// 첫 버킷(인덱스 0..<3)의 min·max는 값 크기 순이 아니라 실제 시각 순서(먼저 나온 시각이 앞)로
    /// 배치돼야 합니다 — 최댓값(인덱스 0)이 최솟값(인덱스 2)보다 먼저 나옵니다.
    /// 둘째 버킷(인덱스 3·4)은 값이 같아(10, 10) 한 후보만 남습니다.
    @Test func bucketOrdersMinAndMaxByActualTimestampNotByValue() {
        let points = [
            HistoryPoint(timestamp: baseInstant, value: 100),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(1)), value: 50),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(2)), value: 0),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(3)), value: 10),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(4)), value: 10),
        ]

        let result = HistoryPoint.downsampled(segment: points, bucketCount: 2)

        #expect(result.map(\.value) == [100, 0, 10])
    }

    @Test func fewerPointsThanBucketCountPassThroughLosslessly() {
        let points = (0..<5).map { HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(Double($0))), value: Double($0)) }

        let result = HistoryPoint.downsampled(segment: points, bucketCount: 124)

        #expect(result == points)
    }

    @Test func downsamplingActuallyReducesPointCountAndIsNotANoOp() {
        let points = (0..<601).map { HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(Double($0))), value: Double($0 % 100)) }

        let result = HistoryPoint.downsampled(segment: points, bucketCount: 124)

        #expect(result.count < points.count)
        #expect(result.count <= 124 * 2)
    }

    @Test func emptySegmentDownsamplesToEmpty() {
        #expect(HistoryPoint.downsampled(segment: [], bucketCount: 124).isEmpty)
    }

    @Test func singlePointSegmentDownsamplesToThatPoint() {
        let point = HistoryPoint(timestamp: baseInstant, value: 10)

        #expect(HistoryPoint.downsampled(segment: [point], bucketCount: 124) == [point])
    }

    @Test func resultPointsAreInAscendingTimestampOrder() {
        let points = (0..<601).map { HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(Double($0))), value: sin(Double($0) / 10) * 50 + 50) }

        let result = HistoryPoint.downsampled(segment: points, bucketCount: 124)

        let timestamps = result.map(\.timestamp)
        #expect(timestamps == timestamps.sorted())
    }

    /// 빈 버킷은 값을 지어내지 않고 결과에서 빠집니다(ANALYSIS §5 DP17과 같은 원칙) — 점이 하나뿐인 버킷 구간이면
    /// 다른 버킷들이 비어도 전체 결과 점 수가 입력 점 수를 넘지 않습니다.
    @Test func emptyBucketsProduceNoFabricatedPoints() {
        let points = [
            HistoryPoint(timestamp: baseInstant, value: 10),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(1)), value: 20),
        ]

        let result = HistoryPoint.downsampled(segment: points, bucketCount: 10)

        // 점 수(2)가 버킷 수(10)보다 적어 가드에서 원본을 그대로 돌려주는 경로이므로, 개수만 비교하면
        // 값을 지어내 결과를 바꿔치기해도(개수를 그대로 둔 채) 잡지 못합니다. 원본과의 완전한 값 일치로 고정합니다.
        #expect(result == points)
    }

    /// 세그먼트 분리를 버킷 묶음보다 먼저 해야 합니다. 값 범위가 좁은 구간과 넓은 구간을 큰 간격으로 이은 뒤
    /// 버킷 수 1로 전체를 다운샘플링하면: 순서가 올바르면 두 구간이 각자 다운샘플링되어 2개 구간이 남고,
    /// 순서를 반대로 해 두 구간을 먼저 하나로 합쳐 버킷을 묶으면 값 범위가 넓은 구간(A)의 최솟값·최댓값이
    /// 전역 min·max를 모두 차지해, 값 범위가 좁은 구간(B)이 결과에서 통째로 사라집니다.
    @Test func segmentsAreSplitBeforeBucketingSoGapsAndNarrowRangeSegmentsSurvive() throws {
        let segmentA = [
            HistoryPoint(timestamp: baseInstant, value: 50),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(1)), value: 0),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(2)), value: 100),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(3)), value: 50),
        ]
        let gapStart = segmentA.last!.timestamp + HistoryPoint.maximumConnectedGap + .seconds(1)
        let segmentB = (0..<4).map {
            HistoryPoint(timestamp: gapStart.advanced(by: .seconds(Double($0))), value: 44 + Double($0))
        }

        let result = HistoryPoint.downsampledConnectedSegments(from: segmentA + segmentB, bucketCount: 1)

        // 배열 인덱싱으로 이어지는 아래 단언들이 개수가 다를 때 그대로 crash하지 않도록 개수부터 먼저 확정합니다.
        try #require(result.count == 2)
        #expect(result[0].allSatisfy { $0.timestamp <= segmentA.last!.timestamp })
        #expect(result[1].allSatisfy { $0.timestamp >= segmentB.first!.timestamp })
        #expect(!result[1].isEmpty)
    }

    /// 결과 점 수는 버킷마다 최대 2점(min·max)이라는 상한을 넘지 않아야 합니다.
    /// 이 상한이 실제 렌더 폭에서 평균 점 간격이 `lineWidth`보다 커지는 것을 보장하는 근거입니다
    /// (버킷마다 항상 두 점이 남는 대신, 값이 균일한 버킷은 한 점만 남아 상한 아래로 줄어들 수 있습니다).
    @Test func resultPointCountNeverExceedsTwiceTheBucketCount() {
        let renderWidth = 248.0
        let bucketCount = HistoryPoint.downsampledBucketCount(forRenderWidth: renderWidth)
        let points = (0..<601).map {
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(Double($0))), value: sin(Double($0) / 30) * 50 + 50)
        }

        let result = HistoryPoint.downsampled(segment: points, bucketCount: bucketCount)

        #expect(result.count <= bucketCount * 2)
    }

    /// 5% 평탄 구간 한가운데 표본 하나만 100%인 입력에서, 그 스파이크가 버킷 안 어느 오프셋에 있어도
    /// 결과에서 사라지면 안 됩니다. 그리디 최소 간격 필터를 되살리면(이웃 버킷 경계 근처 오프셋에서)
    /// 이 단언이 실패합니다 — verify가 601개 위치 중 372곳에서 이 방식으로 소실을 발견했습니다.
    @Test func singleSpikeSurvivesAtEveryPositionInTheHistory() {
        let bucketCount = HistoryPoint.downsampledBucketCount(forRenderWidth: 248)

        for spikeIndex in 0..<601 {
            var values = Array(repeating: 5.0, count: 601)
            values[spikeIndex] = 100
            let points = (0..<601).map {
                HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(Double($0))), value: values[$0])
            }

            let result = HistoryPoint.downsampled(segment: points, bucketCount: bucketCount)

            #expect(result.contains { $0.value == 100 }, "스파이크 인덱스 \(spikeIndex)에서 소실됨")
        }
    }

    /// 50% 평탄 구간 한가운데 표본 하나만 0%인 입력에서, 그 dip이 버킷 안 어느 오프셋에 있어도
    /// 결과에서 사라지면 안 됩니다.
    @Test func singleDipSurvivesAtEveryPositionInTheHistory() {
        let bucketCount = HistoryPoint.downsampledBucketCount(forRenderWidth: 248)

        for dipIndex in 0..<601 {
            var values = Array(repeating: 50.0, count: 601)
            values[dipIndex] = 0
            let points = (0..<601).map {
                HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(Double($0))), value: values[$0])
            }

            let result = HistoryPoint.downsampled(segment: points, bucketCount: bucketCount)

            #expect(result.contains { $0.value == 0 }, "dip 인덱스 \(dipIndex)에서 소실됨")
        }
    }

    /// 임의의(비균일) 입력에서도 전역 최댓값·최솟값은 각자 속한 버킷의 극값이므로 결과에 반드시 남습니다.
    @Test func globalMinimumAndMaximumAreAlwaysPreserved() {
        let points = (0..<601).map { index -> HistoryPoint in
            var value = sin(Double(index) / 17) * 40 + 50
            if index == 300 { value = 99 }
            if index == 88 { value = -1 }
            return HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(Double(index))), value: value)
        }
        let bucketCount = HistoryPoint.downsampledBucketCount(forRenderWidth: 248)
        let globalMax = points.map(\.value).max()!
        let globalMin = points.map(\.value).min()!

        let result = HistoryPoint.downsampled(segment: points, bucketCount: bucketCount)

        #expect(result.contains { $0.value == globalMax })
        #expect(result.contains { $0.value == globalMin })
    }

    /// task-004 검증 조건: 다운샘플링 뒤 남은 각 점의 하위 계열 값(`subValue`)은 그 점(전체 사용률 기준으로
    /// 뽑힌 대표 표본)과 같은 시각의 값이어야 합니다. `subValue`를 `value`와 무관한 표시자로 둬,
    /// 대표 표본과 짝이 아닌 시각의 값이 붙으면(예: 버킷의 subValue 최댓값을 따로 골라 붙이면) 어긋나게 합니다.
    @Test func subValueTravelsWithTheSameSampleAsItsChosenOverallValue() throws {
        let points = (0..<601).map { index -> HistoryPoint in
            let value = sin(Double(index) / 17) * 40 + 50
            return HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(Double(index))), value: value, subValue: Double(index))
        }
        let subValueByTimestamp = Dictionary(uniqueKeysWithValues: points.map { ($0.timestamp, $0.subValue) })
        let bucketCount = HistoryPoint.downsampledBucketCount(forRenderWidth: 248)

        let result = HistoryPoint.downsampled(segment: points, bucketCount: bucketCount)

        try #require(!result.isEmpty)
        for point in result {
            #expect(point.subValue == subValueByTimestamp[point.timestamp])
        }
    }
}

// MARK: - CPU 그래프 2계열 밴드 값(task-004, SPEC §5.5, ANALYSIS §5 DP7)

/// 위 밴드(System)는 전체 사용률에서 아래 밴드(User)를 뺀 값으로 유도되므로 두 밴드의 합이 항상
/// 전체 사용률과 같고, 뺀 값이 음수가 되지 않도록 0에서 잘립니다.
struct HistoryPointBandValueTests {

    @Test func lowerAndUpperBandValuesSplitTheOverallValue() {
        let point = HistoryPoint(timestamp: baseInstant, value: 70, subValue: 30)

        #expect(point.lowerBandValue == 30)
        #expect(point.upperBandValue == 40)
        #expect(point.lowerBandValue + point.upperBandValue == point.value)
    }

    /// subValue가 value보다 커도(순간적인 오차나 경계 표본) 위 밴드가 음수로 내려가지 않습니다.
    @Test func upperBandValueIsClampedToZeroWhenSubValueExceedsOverallValue() {
        let point = HistoryPoint(timestamp: baseInstant, value: 20, subValue: 35)

        #expect(point.upperBandValue == 0)
        #expect(point.upperBandValue >= 0)
    }

    /// `subValue`가 없는 1계열 점은 전체 값이 그대로 위 밴드가 됩니다(CPU 아닌 그래프에 쓰일 경우의 안전값).
    @Test func missingSubValueLeavesTheWholeValueInTheUpperBand() {
        let point = HistoryPoint(timestamp: baseInstant, value: 40)

        #expect(point.lowerBandValue == 0)
        #expect(point.upperBandValue == 40)
    }
}

// MARK: - 그래프 가로축: 오른쪽 끝은 그리는 시점의 시각(재작업 회귀 고정)

/// task-008 검증 조건이 고정하는 것: "가로축 오른쪽 끝이 그리는 시점의 시각이라 마지막 샘플이
/// 오래된 상황에서도 빈 구간이 제자리에 보입니다".
/// 창의 오른쪽 끝을 점 자신의 시각(`timestamp`)이 아니라 항상 별도로 주어지는 `currentTimestamp`로 고정해야 하며,
/// 이 판정을 지우고 오른쪽 끝을 마지막 점의 시각으로 되돌리면(예: `currentTimestamp` 대신 `timestamp` 자체를
/// 창 끝으로 쓰면) 아래 단언들이 실패해야 합니다.
struct HistoryPointNormalizedXPositionTests {

    /// 낡은 마지막 샘플의 정규화 좌표가 1(오른쪽 끝)에 들러붙지 않고, 실제 경과 시간만큼 왼쪽으로 밀려납니다.
    /// 오른쪽 끝을 `timestamp` 자체로 되돌리면 이 값이 항상 1이 되어 실패합니다.
    @Test func staleLastSampleDoesNotStickToRightEdge() {
        let staleSampleTimestamp = baseInstant
        // 그리는 시점(currentTimestamp)이 마지막 샘플보다 300초(5분) 뒤입니다 — 예를 들어 중지 구간에서
        // 카드 갱신 자체가 없었던 사이 시간이 그만큼 흘렀다는 뜻입니다.
        let currentTimestamp = baseInstant.advanced(by: .seconds(300))

        let position = HistoryPoint.normalizedXPosition(for: staleSampleTimestamp, currentTimestamp: currentTimestamp)

        // 10분 창에서 5분 전 점은 왼쪽에서 절반 지점(0.5)에 있어야 하며, 결코 오른쪽 끝(1.0)이 아닙니다.
        #expect(abs(position - 0.5) < 0.0001)
        #expect(position < 0.99)
    }

    /// 그리는 시점 자신(`currentTimestamp`)에 찍힌 점만 오른쪽 끝(1.0)에 옵니다.
    @Test func pointAtCurrentTimestampIsAtRightEdge() {
        let position = HistoryPoint.normalizedXPosition(for: baseInstant, currentTimestamp: baseInstant)

        #expect(abs(position - 1.0) < 0.0001)
    }

    /// 창의 왼쪽 끝(`currentTimestamp - timeRange`)에 있는 점은 좌표 0입니다.
    @Test func pointAtWindowStartIsAtLeftEdge() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(600))

        let position = HistoryPoint.normalizedXPosition(for: baseInstant, currentTimestamp: currentTimestamp)

        #expect(abs(position) < 0.0001)
    }
}

// MARK: - CPU 카드 조립

/// task-008 검증 조건: 빈 이력, 중지 구간을 포함한 이력, 10분을 넘는 이력,
/// TOP 5가 5개 미만·초과인 입력을 각각 단언합니다.
struct CPUCardPresentationAssembleTests {

    @Test func emptyHistoryProducesEmptyGraphPoints() {
        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(),
            history: [],
            topApplications: [],
            currentTimestamp: baseInstant
        )

        #expect(presentation.graphPoints.isEmpty)
        #expect(presentation.overallUsage == 42)
        #expect(presentation.userRatio == 30)
        #expect(presentation.systemRatio == 12)
    }

    /// 중지 구간을 포함한 이력이 그래프 점으로는 그대로 옮겨지되(값 자체를 지어내지 않음),
    /// 연결 구간 분리는 `HistoryPoint.connectedSegments`가 별도로 담당합니다.
    @Test func historyWithGapCarriesAllPointsIntoGraphPoints() {
        let history = [
            historyPoint(secondsFromBase: 0, overallCPUUsage: 10),
            historyPoint(secondsFromBase: 1, overallCPUUsage: 20),
            historyPoint(secondsFromBase: 100, overallCPUUsage: 30),
        ]

        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(),
            history: history,
            topApplications: [],
            currentTimestamp: baseInstant.advanced(by: .seconds(100))
        )

        #expect(presentation.graphPoints.map(\.value) == [10, 20, 30])
        let segments = HistoryPoint.connectedSegments(from: presentation.graphPoints)
        #expect(segments.count == 2, "정상 간격 두 점과 큰 간격 뒤 점이 분리된 구간으로 나뉘어야 합니다.")
    }

    /// 10분을 넘는 이력: 창 밖의 오래된 점은 그래프에 포함되지 않습니다.
    @Test func pointsOlderThanTenMinuteWindowAreExcluded() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(700))
        let history = [
            historyPoint(secondsFromBase: 0, overallCPUUsage: 1),  // 700초 전: 창(600초) 밖
            historyPoint(secondsFromBase: 50, overallCPUUsage: 2), // 650초 전: 창 밖
            historyPoint(secondsFromBase: 200, overallCPUUsage: 3), // 500초 전: 창 안
            historyPoint(secondsFromBase: 700, overallCPUUsage: 4), // 0초 전: 창 안
        ]

        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(),
            history: history,
            topApplications: [],
            currentTimestamp: currentTimestamp
        )

        #expect(presentation.graphPoints.map(\.value) == [3, 4])
    }

    @Test func fewerThanFiveTopApplicationsArePassedThroughUnchanged() {
        let entries = [rankingEntry(name: "A", value: 10), rankingEntry(name: "B", value: 5)]

        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(),
            history: [],
            topApplications: entries,
            currentTimestamp: baseInstant
        )

        #expect(presentation.topApplications == entries)
    }

    @Test func moreThanFiveTopApplicationsAreTrimmedToFive() {
        let entries = (0..<8).map { rankingEntry(name: "App\($0)", value: Double(8 - $0)) }

        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(),
            history: [],
            topApplications: entries,
            currentTimestamp: baseInstant
        )

        #expect(presentation.topApplications.count == 5)
        #expect(presentation.topApplications == Array(entries.prefix(5)))
    }

    /// task-004 검증 조건: 그래프 점마다 그 점의 전체 사용률과 같은 표본에서 나온 User 비율이 `subValue`로 실립니다.
    /// 스냅샷(`cpu.userRatio`, 여기서는 90으로 이력 값들과 다르게 둡니다)을 전체 구간에 덮어씌우면 이 단언이 실패합니다.
    @Test func graphPointsCarryPerSampleUserRatioNotTheLatestSnapshotValue() {
        let history = [
            historyPoint(secondsFromBase: 0, overallCPUUsage: 40, userRatio: 10),
            historyPoint(secondsFromBase: 1, overallCPUUsage: 60, userRatio: 50),
        ]

        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(overallUsage: 42, userRatio: 90, systemRatio: 12),
            history: history,
            topApplications: [],
            currentTimestamp: baseInstant.advanced(by: .seconds(1))
        )

        #expect(presentation.graphPoints.map(\.subValue) == [10, 50])
    }

    /// 위 밴드가 음수가 되지 않고, 아래·위 밴드의 합이 그 점의 전체 사용률과 같습니다(SPEC §5.5).
    @Test func graphPointsBandValuesSumToTheOverallValueAndNeverGoNegative() {
        let history = [
            historyPoint(secondsFromBase: 0, overallCPUUsage: 40, userRatio: 10),
            historyPoint(secondsFromBase: 1, overallCPUUsage: 60, userRatio: 50),
        ]

        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(),
            history: history,
            topApplications: [],
            currentTimestamp: baseInstant.advanced(by: .seconds(1))
        )

        for point in presentation.graphPoints {
            #expect(point.upperBandValue >= 0)
            #expect(point.lowerBandValue + point.upperBandValue == point.value)
        }
    }
}

// MARK: - 접근성 이름

/// task-008 검증 조건: 카드의 접근성 이름에 현재 사용률과 상태, TOP 5의 안내 문구가 포함됩니다.
struct CPUCardAccessibilityLabelTests {

    @Test func collectingStateDescribesCollectingWithoutAUsageValue() {
        let state = ResourceCardState<CPUCardPresentation>.collecting

        #expect(state.cpuAccessibilityLabel.contains("수집 중"))
        #expect(state.cpuAccessibilityLabel.contains("최근 10분 그래프"))
        #expect(state.cpuAccessibilityLabel.contains("데이터 수집 중 · 00:00 / 10:00"))
    }

    /// task-010(재작업, DP15) 검증 조건: 단축키의 존재가 카드 접근성 이름에서 확인되어야 하며,
    /// 수집 중 상태에서도(값이 아직 없어도) 단축키 발견 가능성이 유지되어야 합니다.
    @Test func collectingStateIncludesSelectionShortcut() {
        let state = ResourceCardState<CPUCardPresentation>.collecting

        #expect(state.cpuAccessibilityLabel.contains(CPUCardPresentation.selectionShortcutDisplayText))
    }

    @Test func valuelessFailureAndStoppedStatesKeepTheTimeWindowAndCollectionProgress() {
        let states: [ResourceCardState<CPUCardPresentation>] = [
            .failure(lastKnown: nil),
            .stopped(lastKnown: nil),
        ]

        for state in states {
            #expect(state.cpuAccessibilityLabel.contains("최근 10분 그래프"))
            #expect(state.cpuAccessibilityLabel.contains("데이터 수집 중 · 00:00 / 10:00"))
        }
    }

    @Test func normalStateIncludesGraphSeriesBaselinesAndTopApplicationsHeading() {
        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(overallUsage: 55, userRatio: 40, systemRatio: 15),
            history: [],
            topApplications: [],
            currentTimestamp: baseInstant
        )
        let state = ResourceCardState.normal(presentation, timestamp: baseInstant)

        let label = state.cpuAccessibilityLabel
        #expect(label.contains("전체 사용률 55%"))
        #expect(label.contains("User 40%"))
        #expect(label.contains("System 15%"))
        #expect(label.contains("두 계열 중첩 그래프"))
        #expect(label.contains("기준선 50%"))
        #expect(label.contains("최근 10분 그래프"))
        #expect(label.contains("데이터 수집 중 · 00:00 / 10:00"))
        #expect(label.contains(CPUCardPresentation.topApplicationsAccessibilityText))
        // 화면 머리글이 줄어든 뒤에도 접근성 이름으로 도달하는 정보가 줄지 않았음을 항목별로 잡습니다.
        #expect(label.contains("TOP \(ApplicationRankingSampling.cardDisplayCount)"))
        #expect(label.contains("시스템 프로세스 제외"))
    }

    /// task-010(재작업, DP15) 검증 조건: 단축키 안내는 조립 함수(`assemble(_:)`)를 거친 정상 상태에서도
    /// 접근성 이름에 포함되어야 합니다.
    @Test func normalStateIncludesSelectionShortcut() {
        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(), history: [], topApplications: [], currentTimestamp: baseInstant
        )
        let state = ResourceCardState.normal(presentation, timestamp: baseInstant)

        #expect(state.cpuAccessibilityLabel.contains(CPUCardPresentation.selectionShortcutDisplayText))
    }
}

// MARK: - DashboardPresentationStore: 항상 최신 표시 상태를 보유(DP10)

@MainActor
struct DashboardPresentationStoreTests {

    @Test func startsInCollectingStateBeforeAnyUpdate() {
        let store = DashboardPresentationStore()

        #expect(store.cpuCard == .collecting)
    }

    @Test func firstSuccessfulTickMovesCardToNormal() {
        let store = DashboardPresentationStore()
        let displayValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics()), memory: .success(memoryMetricsForTests()))
            ),
            recentHistory: []
        )

        store.updateCPUCard(with: displayValue, topApplications: [], currentTimestamp: baseInstant)

        guard case .normal(let presentation, let timestamp) = store.cpuCard else {
            Issue.record("정상 상태로 바뀌지 않았습니다.")
            return
        }
        #expect(presentation.overallUsage == 42)
        #expect(timestamp == baseInstant)
    }

    /// DP10이 고정하는 것: 한 번 정상 표시로 바뀐 카드는, 값을 만들지 못한 tick이나 실패 tick이 와도
    /// 다시 수집 중으로 되돌아가지 않고 마지막으로 성립한 표시 상태를 그대로 유지합니다.
    @Test func cardNeverRegressesToCollectingAfterShowingARealValue() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics()), memory: .success(memoryMetricsForTests()))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)

        let valuelessTick = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(1)),
                value: SystemMetricsSample(cpu: .success(nil), memory: .success(memoryMetricsForTests()))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: valuelessTick, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))

        guard case .normal = store.cpuCard else {
            Issue.record("값 없는 tick 뒤 카드가 수집 중으로 되돌아갔습니다.")
            return
        }
    }

    @Test func noLatestSampleKeepsCardCollecting() {
        let store = DashboardPresentationStore()
        let displayValue = SystemMetricsDisplayValue(latest: nil, recentHistory: [])

        store.updateCPUCard(with: displayValue, topApplications: [], currentTimestamp: baseInstant)

        #expect(store.cpuCard == .collecting)
    }
}

private func memoryMetricsForTests(
    swapUsedBytes: UInt64 = 0,
    pressureLevel: MemoryPressureLevel = .normal,
    usedBytes: UInt64 = 8 * 1024 * 1024 * 1024
) -> MemorySystemMetrics {
    MemorySystemMetrics(
        totalPhysicalBytes: 16 * 1024 * 1024 * 1024,
        usedBytes: usedBytes,
        appBytes: 4 * 1024 * 1024 * 1024,
        wiredBytes: 2 * 1024 * 1024 * 1024,
        compressedBytes: 2 * 1024 * 1024 * 1024,
        cachedBytes: 1024 * 1024 * 1024,
        swapUsedBytes: swapUsedBytes,
        pressureLevel: pressureLevel
    )
}

private func formattedMemoryBytesForAccessibility(_ bytes: UInt64) -> String {
    DashboardValueColumn.byteText(bytes)
}

private func swapHistoryPoint(secondsFromBase: Double, swapUsedBytes: UInt64) -> SystemMetricsHistoryPoint {
    SystemMetricsHistoryPoint(
        timestamp: baseInstant.advanced(by: .seconds(secondsFromBase)),
        overallCPUUsage: 0,
        userRatio: 0,
        swapUsedBytes: swapUsedBytes
    )
}

// MARK: - Memory Pressure 단계 표시: 색상 없이 라벨·기호로 구분(SPEC §5.5)

/// task-009 검증 조건이 고정하는 것: "색상만으로 단계를 구분하지 않는다".
/// 색상 속성은 애초에 이 타입에 없으므로, 라벨과 기호 식별자만으로 세 단계가 모두 다른지 단언합니다.
/// 기호나 라벨을 한 값으로 통일하면(예: 세 단계 모두 같은 symbolName을 쓰면) 이 테스트가 실패해야 합니다.
struct MemoryPressureLevelDisplayTests {

    @Test func allThreeLevelsHaveDistinctLabelsAndSymbols() {
        let displays: [MemoryPressureDisplay] = [
            MemoryPressureLevel.normal.display,
            MemoryPressureLevel.warning.display,
            MemoryPressureLevel.critical.display,
        ]

        let labels = Set(displays.map(\.label))
        let symbols = Set(displays.map(\.symbolName))

        #expect(labels.count == 3, "세 단계의 라벨이 모두 달라야 합니다.")
        #expect(symbols.count == 3, "세 단계의 기호가 모두 달라야 합니다.")
    }

    /// 경고·위험에서 정상으로 돌아오면 표시가 최초 정상 표시와 완전히 같아져야 합니다(위험 → 정상 순서).
    @Test func returningToNormalFromCriticalMatchesInitialNormalDisplay() {
        let initialNormal = MemoryPressureLevel.normal.display
        let afterCriticalThenNormal = MemoryPressureLevel.critical.display
        let backToNormal = MemoryPressureLevel.normal.display

        #expect(backToNormal == initialNormal)
        #expect(backToNormal != afterCriticalThenNormal)
    }
}

// MARK: - Pressure·Swap 병합 줄 서식(ANALYSIS §5 DP4)

/// task-006 검증 조건이 고정하는 것: 병합 줄 조립 요소의 순서가
/// 「Pressure 기호 → Pressure 라벨 → 구분자 → Swap 사용량 → Swap 변화량 → 구분자 → 구성 합계」이고,
/// 변화량 기준점이 없으면 그 요소를 담지 않습니다.
/// 배열 전체를 리터럴과 비교해 순서 뒤바꿈·기호 누락·구분자 누락·변화량 위치 이동 mutation을 잡습니다.
/// 구성 합계는 「사용 중」과 다른 지표라 줄 맨 뒤에 자기 자리로 남습니다(SPEC §5.3) —
/// 그 요소를 지우거나 Swap 수치 앞으로 옮기는 mutation도 같은 비교가 잡습니다.
struct MemoryPressureSwapLineFormattingTests {

    private func format(_ bytes: UInt64) -> String { "\(bytes)B" }

    @Test func normalLevelWithNoChangeOmitsChangeSegment() {
        let segments = MemoryPressureSwapLineFormatting.assemble(
            pressureDisplay: MemoryPressureLevel.normal.display,
            swapUsedBytes: 0,
            swapRecentChangeBytes: nil,
            compositionTotalBytes: 300,
            format: format
        )

        #expect(segments == [
            .symbol(name: "checkmark.circle"),
            .label("정상"),
            .separator,
            .swapUsage("0B"),
            .separator,
            .compositionTotal("300B")
        ])
    }

    @Test func warningLevelWithZeroChangeIncludesSignedZero() {
        let segments = MemoryPressureSwapLineFormatting.assemble(
            pressureDisplay: MemoryPressureLevel.warning.display,
            swapUsedBytes: 100,
            swapRecentChangeBytes: 0,
            compositionTotalBytes: 300,
            format: format
        )

        #expect(segments == [
            .symbol(name: "exclamationmark.triangle"),
            .label("경고"),
            .separator,
            .swapUsage("100B"),
            .swapChange("+0B"),
            .separator,
            .compositionTotal("300B")
        ])
    }

    @Test func criticalLevelWithLargeNegativeChangeKeepsOrder() {
        let segments = MemoryPressureSwapLineFormatting.assemble(
            pressureDisplay: MemoryPressureLevel.critical.display,
            swapUsedBytes: 5_000_000_000,
            swapRecentChangeBytes: -1_200_000_000,
            compositionTotalBytes: 14_000_000_000,
            format: format
        )

        #expect(segments == [
            .symbol(name: "xmark.octagon"),
            .label("위험"),
            .separator,
            .swapUsage("5000000000B"),
            .swapChange("-1200000000B"),
            .separator,
            .compositionTotal("14000000000B")
        ])
    }

    @Test func placeholderIsDashedSymbolFollowedByDashLabelOnly() {
        #expect(MemoryPressureSwapLineFormatting.placeholder == [
            .symbol(name: "circle.dashed"),
            .label("–")
        ])
    }

    /// 병합 줄이 실제로 잘리는지는 `DashboardCardLayoutTests`의 렌더 높이 단언으로 잡을 수 없습니다 —
    /// production 공용 바이트 서식이 어떤 바이트 값도 카드 콘텐츠 폭을 넘길 만큼 길게 만들지 않아
    /// 줄바꿈 자체가 일어나지 않기 때문입니다. 대신 뷰가 실제로 쓰는 줄 수 상한을 이 상수 하나로 고정해 두고
    /// (`MemoryCardView.pressureSwapLine`이 하드코딩된 `1`이 아니라 이 상수를 참조합니다) 그 값 자체를 단언합니다 —
    /// `HistoryGraphGridline.placeholderDrawOrder`를 상수로 고정해 단언하는 것과 같은 앵커 방식입니다.
    @Test func maximumLineCountIsOne() {
        #expect(MemoryPressureSwapLineFormatting.maximumLineCount == 1)
    }
}

// MARK: - Memory 카드 조립

/// task-009 검증 조건: Swap 최근 변화량의 10분 창 경계 직전·직후 기준점과 값이 하나뿐인 입력을 검증합니다.
struct MemoryCardPresentationAssembleTests {

    @Test func emptyHistoryProducesNoSwapChange() {
        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(swapUsedBytes: 100),
            history: [],
            topApplications: [],
            currentTimestamp: baseInstant
        )

        #expect(presentation.swapRecentChangeBytes == nil)
        #expect(presentation.swapUsedBytes == 100)
    }

    /// 창 안에 값이 하나뿐인 입력: 이력에 현재 tick 하나만 있으면(그보다 앞선 기준점이 없으면) 변화량을 만들지 않습니다.
    ///
    /// `currentTimestamp`는 이력 점과 같은 시각이 아니라 그보다 늦은 시각으로 줍니다 — production에서
    /// `ApplicationCoordinator`는 이력에 값을 넣은 뒤 별도로 관찰한 `ContinuousClock().now`를 넘기므로 항상 이력의
    /// 어떤 시각보다도 늦습니다. 이 관계를 재현하지 않고 같은 시각을 주면, 방금 이 tick이 만든 점 자신을 기준점으로
    /// 삼아 `swapRecentChangeBytes == 0`을 돌려주는 회귀(이력의 어떤 값도 현재 시각보다 이른지 여부만으로 기준점을
    /// 찾던 예전 구현)를 이 테스트가 잡아내지 못합니다.
    @Test func singleValueWithinWindowProducesNoSwapChange() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(15))
        let history = [swapHistoryPoint(secondsFromBase: 10, swapUsedBytes: 500)]

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(swapUsedBytes: 500),
            history: history,
            topApplications: [],
            currentTimestamp: currentTimestamp
        )

        #expect(presentation.swapRecentChangeBytes == nil)
    }

    /// 10분 창 경계 바로 안(포함)의 기준점은 변화량 계산에 쓰입니다.
    @Test func baselineExactlyAtWindowStartIsIncluded() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(600))
        let history = [
            swapHistoryPoint(secondsFromBase: 0, swapUsedBytes: 100), // 정확히 600초 전 = 창의 왼쪽 끝
            swapHistoryPoint(secondsFromBase: 600, swapUsedBytes: 300),
        ]

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(swapUsedBytes: 300),
            history: history,
            topApplications: [],
            currentTimestamp: currentTimestamp
        )

        #expect(presentation.swapRecentChangeBytes == 200)
    }

    /// 10분 창 밖(경계 직전, 601초 전)의 기준점은 변화량 계산에 쓰이지 않습니다.
    @Test func baselineJustBeforeWindowStartIsExcluded() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(601))
        let history = [
            swapHistoryPoint(secondsFromBase: 0, swapUsedBytes: 100), // 601초 전 = 창 밖
            swapHistoryPoint(secondsFromBase: 601, swapUsedBytes: 300),
        ]

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(swapUsedBytes: 300),
            history: history,
            topApplications: [],
            currentTimestamp: currentTimestamp
        )

        #expect(presentation.swapRecentChangeBytes == nil, "창 밖의 기준점을 써서 변화량을 만들면 안 됩니다.")
    }

    @Test func swapChangeCanBeNegativeWhenSwapDecreases() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(60))
        let history = [
            swapHistoryPoint(secondsFromBase: 0, swapUsedBytes: 500),
            swapHistoryPoint(secondsFromBase: 60, swapUsedBytes: 200),
        ]

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(swapUsedBytes: 200),
            history: history,
            topApplications: [],
            currentTimestamp: currentTimestamp
        )

        #expect(presentation.swapRecentChangeBytes == -300)
    }

    @Test func moreThanFiveTopApplicationsAreTrimmedToFive() {
        let entries = (0..<8).map { rankingEntry(name: "App\($0)", value: Double(8 - $0)) }

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(),
            history: [],
            topApplications: entries,
            currentTimestamp: baseInstant
        )

        #expect(presentation.topApplications.count == 5)
        #expect(presentation.topApplications == Array(entries.prefix(5)))
    }

    @Test func fewerThanFiveTopApplicationsArePassedThroughUnchanged() {
        let entries = [rankingEntry(name: "A", value: 10), rankingEntry(name: "B", value: 5)]

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(),
            history: [],
            topApplications: entries,
            currentTimestamp: baseInstant
        )

        #expect(presentation.topApplications == entries)
    }

    /// task-001 검증 조건: 카드 표시 값(`topApplications`)은 카드 정원(5)으로 잘리지만,
    /// 증가량 순위(`recentIncreaseRanking`)는 상세 정원(20)까지 그대로 담겨야 합니다.
    @Test func recentIncreaseRankingIsTrimmedToDetailCountNotCardCount() {
        let entries = (0..<25).map { rankingEntry(name: "App\($0)", value: Double(25 - $0)) }

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(),
            history: [],
            topApplications: [],
            memoryIncrease: entries,
            currentTimestamp: baseInstant
        )

        #expect(presentation.topApplications.count == 0)
        #expect(presentation.detail.recentIncreaseRanking.count == 20)
        #expect(presentation.detail.recentIncreaseRanking == Array(entries.prefix(20)))
    }

    /// task-001 재작업(design/scope) 검증 조건: 증가량 순위 caption은 상세 정원(20)에 맞춘 문구여야 하며,
    /// 뷰가 아니라 `assemble`이 만들어 `detail`에 담아 둡니다. 직접 문자열 비교라 `assemble`이 카드 정원(5)을
    /// 넘기도록 바뀌면 이 단언이 실패합니다.
    @Test func recentIncreaseRankingCaptionMatchesDetailGantryNotCardGantry() {
        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(),
            history: [],
            topApplications: [],
            currentTimestamp: baseInstant
        )

        #expect(presentation.detail.recentIncreaseRankingCaption == "시스템 프로세스는 TOP 20에 포함되지 않습니다")
        #expect(
            presentation.detail.recentIncreaseRankingCaption
                != ApplicationRankingSampling.topApplicationsCaption(
                    count: ApplicationRankingSampling.cardDisplayCount
                )
        )
    }
}

// MARK: - Memory 카드 접근성 이름

/// task-009 검증 조건: 카드 접근성 이름에 현재 단계와 사용 중 메모리가 포함됩니다.
struct MemoryCardAccessibilityLabelTests {

    @Test func collectingStateDescribesCollectingWithoutAValue() {
        let state = ResourceCardState<MemoryCardPresentation>.collecting

        #expect(state.memoryAccessibilityLabel.contains("수집 중"))
    }

    /// task-010(재작업, DP15) 검증 조건: 단축키의 존재가 카드 접근성 이름에서 확인되어야 합니다.
    @Test func collectingStateIncludesSelectionShortcut() {
        let state = ResourceCardState<MemoryCardPresentation>.collecting

        #expect(state.memoryAccessibilityLabel.contains(MemoryCardPresentation.selectionShortcutDisplayText))
    }

    @Test func normalStateIncludesAllCompositionAndMergedLineValuesWithDistinctMetricLabels() {
        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(swapUsedBytes: 3 * 1024 * 1024 * 1024, pressureLevel: .warning),
            history: [
                swapHistoryPoint(secondsFromBase: -60, swapUsedBytes: 2 * 1024 * 1024 * 1024),
                swapHistoryPoint(secondsFromBase: 0, swapUsedBytes: 3 * 1024 * 1024 * 1024),
            ],
            topApplications: [],
            currentTimestamp: baseInstant.advanced(by: .seconds(1))
        )
        let state = ResourceCardState.normal(presentation, timestamp: baseInstant)

        let label = state.memoryAccessibilityLabel
        let gibibyte: UInt64 = 1024 * 1024 * 1024
        #expect(label.contains("Memory Pressure 경고"))
        #expect(label.contains("사용 중 \(formattedMemoryBytesForAccessibility(8 * gibibyte))"))
        #expect(label.contains("전체 물리 메모리 \(formattedMemoryBytesForAccessibility(16 * gibibyte))"))
        #expect(label.contains("Swap \(formattedMemoryBytesForAccessibility(3 * gibibyte))"))
        #expect(label.contains("Swap 최근 변화 +\(formattedMemoryBytesForAccessibility(gibibyte))"))
        #expect(label.contains("App \(formattedMemoryBytesForAccessibility(4 * gibibyte))"))
        #expect(label.contains("Wired \(formattedMemoryBytesForAccessibility(2 * gibibyte))"))
        #expect(label.contains("Compressed \(formattedMemoryBytesForAccessibility(2 * gibibyte))"))
        #expect(label.contains("Cached \(formattedMemoryBytesForAccessibility(gibibyte))"))
        #expect(label.contains("구성 합계 \(formattedMemoryBytesForAccessibility(9 * gibibyte))"))
        #expect(!label.contains("사용 중 및 구성 합계"))
        #expect(label.contains(MemoryCardPresentation.topApplicationsAccessibilityText))
        #expect(label.contains("TOP \(ApplicationRankingSampling.cardDisplayCount)"))
        #expect(label.contains("시스템 프로세스 제외"))
        #expect(label.contains(MemoryCardPresentation.selectionShortcutDisplayText))
    }

    @Test func detailDonutAccessibilityLabelIncludesEveryCompositionValueTotalAndPhysicalMemory() {
        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(),
            history: [],
            topApplications: [],
            currentTimestamp: baseInstant
        )

        let label = presentation.compositionDonutAccessibilityLabel
        let gibibyte: UInt64 = 1024 * 1024 * 1024
        #expect(label.contains("Memory 구성 도넛"))
        #expect(label.contains("App \(formattedMemoryBytesForAccessibility(4 * gibibyte))"))
        #expect(label.contains("Wired \(formattedMemoryBytesForAccessibility(2 * gibibyte))"))
        #expect(label.contains("Compressed \(formattedMemoryBytesForAccessibility(2 * gibibyte))"))
        #expect(label.contains("Cached \(formattedMemoryBytesForAccessibility(gibibyte))"))
        #expect(label.contains("구성 합계 \(formattedMemoryBytesForAccessibility(9 * gibibyte))"))
        #expect(label.contains("전체 물리 메모리 \(formattedMemoryBytesForAccessibility(16 * gibibyte))"))
    }
}

// MARK: - DashboardPresentationStore: Memory 카드도 항상 최신 표시 상태를 보유(DP10)

@MainActor
struct DashboardMemoryPresentationStoreTests {

    @Test func startsInCollectingStateBeforeAnyUpdate() {
        let store = DashboardPresentationStore()

        #expect(store.memoryCard == .collecting)
    }

    @Test func firstSuccessfulTickMovesCardToNormal() {
        let store = DashboardPresentationStore()
        let displayValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics()), memory: .success(memoryMetricsForTests()))
            ),
            recentHistory: []
        )

        store.updateMemoryCard(with: displayValue, topApplications: [], currentTimestamp: baseInstant)

        guard case .normal(let presentation, let timestamp) = store.memoryCard else {
            Issue.record("정상 상태로 바뀌지 않았습니다.")
            return
        }
        #expect(presentation.usedBytes == 8 * 1024 * 1024 * 1024)
        #expect(timestamp == baseInstant)
    }

    /// 해석할 수 없는 Memory Pressure 원시값은 Collector 단계에서 이미 `CollectorFailure`로 바뀌어
    /// `SystemMetricsSample.memory`가 `.failure`가 됩니다. 이 tick에서는 카드가 임의 단계로 바뀌지 않고
    /// `.failure` 상태로 바뀌어 그 사실을 나타내되, 마지막 성공 값과 그 시각을 그대로 물려받습니다(task-011).
    @Test func memoryFailureTickBecomesFailureStateKeepingLastKnownValue() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics()), memory: .success(memoryMetricsForTests(pressureLevel: .normal)))
            ),
            recentHistory: []
        )
        store.updateMemoryCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)

        let unsupportedPressureValueFailure = CollectorFailure(
            metric: .memory,
            cause: .unsupportedValue(name: "kern.memorystatus_vm_pressure_level", rawValue: 0x03)
        )
        let failureValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(1)),
                value: SystemMetricsSample(cpu: .success(cpuMetrics()), memory: .failure(unsupportedPressureValueFailure))
            ),
            recentHistory: []
        )
        store.updateMemoryCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))

        guard case .failure(let lastKnown) = store.memoryCard, let lastKnown else {
            Issue.record("실패 tick 뒤 카드가 실패 상태로 바뀌지 않았거나 마지막 성공 값을 잃었습니다.")
            return
        }
        #expect(lastKnown.presentation.pressureDisplay == MemoryPressureLevel.normal.display, "임의 단계로 바뀌면 안 됩니다.")
        #expect(lastKnown.timestamp == baseInstant, "마지막 성공 시각이 유지되어야 합니다.")
    }

    @Test func noLatestSampleKeepsCardCollecting() {
        let store = DashboardPresentationStore()
        let displayValue = SystemMetricsDisplayValue(latest: nil, recentHistory: [])

        store.updateMemoryCard(with: displayValue, topApplications: [], currentTimestamp: baseInstant)

        #expect(store.memoryCard == .collecting)
    }
}

// MARK: - task-011: 지표별 실패의 카드 격리

/// task-011 검증 조건이 고정하는 두 가지 —
/// "실패를 0으로 바꾸지 않는다"(실패 tick 뒤 카드 값이 마지막 성공 값과 같고 0이 아님),
/// "한 지표의 실패가 다른 카드를 실패로 만들지 않는다"(실패 tick에서 반대편 카드가 정상이고 값이 그 tick의 값과 같음).
/// 아래 두 단언을 한 테스트 안에서 함께 확인하므로, CPU·Memory 카드 갱신을 하나의 분기로 합치면
/// 어느 한쪽이 실패해야 합니다.
@MainActor
struct DashboardCardFailureIsolationTests {

    private let cpuFailure = CollectorFailure(metric: .cpu, cause: .systemCall(name: "host_processor_info", code: 5))
    private let memoryFailure = CollectorFailure(
        metric: .memory,
        cause: .unsupportedValue(name: "kern.memorystatus_vm_pressure_level", rawValue: 0x03)
    )

    @Test func cpuFailureLeavesMemoryCardNormalWithThatTickValueAndKeepsCPULastKnownValueNonZero() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 42)), memory: .success(memoryMetricsForTests()))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        store.updateMemoryCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)

        let failureValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(1)),
                value: SystemMetricsSample(cpu: .failure(cpuFailure), memory: .success(memoryMetricsForTests(usedBytes: 999)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))
        store.updateMemoryCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))

        guard case .failure(let lastKnown) = store.cpuCard, let lastKnown else {
            Issue.record("CPU 카드가 실패 상태로 바뀌지 않았거나 마지막 값을 잃었습니다.")
            return
        }
        #expect(lastKnown.presentation.overallUsage == 42, "실패가 값을 0으로 바꾸면 안 됩니다.")

        guard case .normal(let memoryPresentation, _) = store.memoryCard else {
            Issue.record("CPU 실패가 Memory 카드까지 실패로 만들었습니다.")
            return
        }
        #expect(memoryPresentation.usedBytes == 999, "Memory 카드는 그 tick의 값으로 계속 갱신되어야 합니다.")
    }

    @Test func memoryFailureLeavesCPUCardNormalWithThatTickValueAndKeepsMemoryLastKnownValueNonZero() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics()), memory: .success(memoryMetricsForTests(usedBytes: 500)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        store.updateMemoryCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)

        let failureValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(1)),
                value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 77)), memory: .failure(memoryFailure))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))
        store.updateMemoryCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))

        guard case .failure(let lastKnown) = store.memoryCard, let lastKnown else {
            Issue.record("Memory 카드가 실패 상태로 바뀌지 않았거나 마지막 값을 잃었습니다.")
            return
        }
        #expect(lastKnown.presentation.usedBytes == 500, "실패가 값을 0으로 바꾸면 안 됩니다.")

        guard case .normal(let cpuPresentation, _) = store.cpuCard else {
            Issue.record("Memory 실패가 CPU 카드까지 실패로 만들었습니다.")
            return
        }
        #expect(cpuPresentation.overallUsage == 77, "CPU 카드는 그 tick의 값으로 계속 갱신되어야 합니다.")
    }

    @Test func bothMetricsFailingInTheSameTickMakesBothCardsFailWithTheirOwnLastKnownValue() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 33)), memory: .success(memoryMetricsForTests(usedBytes: 700)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        store.updateMemoryCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)

        let failureValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(1)),
                value: SystemMetricsSample(cpu: .failure(cpuFailure), memory: .failure(memoryFailure))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))
        store.updateMemoryCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))

        guard case .failure(let cpuLastKnown) = store.cpuCard, let cpuLastKnown else {
            Issue.record("CPU 카드가 실패 상태로 바뀌지 않았습니다.")
            return
        }
        #expect(cpuLastKnown.presentation.overallUsage == 33)

        guard case .failure(let memoryLastKnown) = store.memoryCard, let memoryLastKnown else {
            Issue.record("Memory 카드가 실패 상태로 바뀌지 않았습니다.")
            return
        }
        #expect(memoryLastKnown.presentation.usedBytes == 700)
    }

    /// 성공 이력이 없는 상태에서의 실패는 `collecting`과 구분되어야 합니다.
    @Test func failureWithoutAnySuccessHistoryIsDistinctFromCollecting() {
        let store = DashboardPresentationStore()
        let failureValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .failure(cpuFailure), memory: .success(memoryMetricsForTests()))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant)

        guard case .failure(let lastKnown) = store.cpuCard else {
            Issue.record("성공 이력이 없는 실패가 실패 상태로 나타나지 않았습니다.")
            return
        }
        #expect(lastKnown == nil, "성공 이력이 없으면 마지막 값도 없어야 합니다.")
        #expect(store.cpuCard != .collecting, "성공 이력 없는 실패는 수집 중과 구분되어야 합니다.")
        #expect(
            store.cpuCard.cpuAccessibilityLabel != ResourceCardState<CPUCardPresentation>.collecting.cpuAccessibilityLabel,
            "접근성 이름에서도 수집 중과 구분되어야 합니다."
        )
    }

    /// 프로세스 조사 실패는 두 카드의 TOP 5만 실패로 바꾸고 시스템 지표 수치는 그대로 둡니다.
    @Test func processSurveyFailureMarksOnlyTopApplicationsFailedKeepingSystemMetrics() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 61)), memory: .success(memoryMetricsForTests(usedBytes: 321)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], topApplicationsFailed: true, currentTimestamp: baseInstant)
        store.updateMemoryCard(with: successValue, topApplications: [], topApplicationsFailed: true, currentTimestamp: baseInstant)

        guard case .normal(let cpuPresentation, _) = store.cpuCard else {
            Issue.record("프로세스 조사 실패가 CPU 카드 전체를 실패로 만들면 안 됩니다.")
            return
        }
        #expect(cpuPresentation.overallUsage == 61, "시스템 지표 수치는 그대로 표시되어야 합니다.")
        #expect(cpuPresentation.topApplicationsFailed)

        guard case .normal(let memoryPresentation, _) = store.memoryCard else {
            Issue.record("프로세스 조사 실패가 Memory 카드 전체를 실패로 만들면 안 됩니다.")
            return
        }
        #expect(memoryPresentation.usedBytes == 321, "시스템 지표 수치는 그대로 표시되어야 합니다.")
        #expect(memoryPresentation.topApplicationsFailed)
    }

    /// 실패가 카드 선택 상태를 바꾸지 않습니다(task-010이 세운 동작, 새 실패 상태에서도 유지되어야 함).
    @Test func failureDoesNotChangeCardSelection() {
        let store = DashboardPresentationStore()
        store.selectCard(.cpu)

        let failureValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .failure(cpuFailure), memory: .failure(memoryFailure))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant)
        store.updateMemoryCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant)

        #expect(store.selection == .cpu)
    }
}

// MARK: - task-011: 일정 중지·재개 전이

/// task-011 검증 조건: 중지는 표시 저장소에 중지 전이를 넣어 두 카드가 마지막 성공 값을 유지한 채 중지가
/// 되는지, 재개만으로는 상태가 바뀌지 않고 값이 성립한 첫 tick에서 풀리는지를 확인합니다.
/// CPU는 재개 첫 tick이 기준점만 갱신하므로(§5 DP11) Memory보다 한 tick 늦게 풀립니다.
@MainActor
struct DashboardCollectionStoppedTests {

    @Test func markCollectionStoppedFreezesBothCardsWithLastKnownValues() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 42)), memory: .success(memoryMetricsForTests(usedBytes: 555)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        store.updateMemoryCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)

        store.markCollectionStopped()

        guard case .stopped(let cpuLastKnown) = store.cpuCard, let cpuLastKnown else {
            Issue.record("CPU 카드가 중지 상태로 바뀌지 않았거나 마지막 값을 잃었습니다.")
            return
        }
        #expect(cpuLastKnown.presentation.overallUsage == 42)

        guard case .stopped(let memoryLastKnown) = store.memoryCard, let memoryLastKnown else {
            Issue.record("Memory 카드가 중지 상태로 바뀌지 않았거나 마지막 값을 잃었습니다.")
            return
        }
        #expect(memoryLastKnown.presentation.usedBytes == 555)
    }

    /// 성공 이력이 없는 상태에서 곧바로 중지되면 마지막 값 없이 `.stopped(lastKnown: nil)`이 되어야 합니다.
    @Test func stoppingBeforeAnySuccessProducesStoppedWithoutLastKnownValue() {
        let store = DashboardPresentationStore()

        store.markCollectionStopped()

        guard case .stopped(let lastKnown) = store.cpuCard else {
            Issue.record("중지 상태로 바뀌지 않았습니다.")
            return
        }
        #expect(lastKnown == nil)
    }

    @Test func resumeAloneDoesNotChangeStateOnlyANextValueBearingTickDoes() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 42)), memory: .success(memoryMetricsForTests(usedBytes: 555)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        store.updateMemoryCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        store.markCollectionStopped()

        // 재개 첫 tick: CPU는 기준점만 갱신하므로(`.success(nil)`) 중지가 유지되고,
        // Memory는 순간값 조회라 곧바로 중지가 풀립니다.
        let resumeFirstTick = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(100)),
                value: SystemMetricsSample(cpu: .success(nil), memory: .success(memoryMetricsForTests(usedBytes: 111)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: resumeFirstTick, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(100)))
        store.updateMemoryCard(with: resumeFirstTick, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(100)))

        guard case .stopped = store.cpuCard else {
            Issue.record("CPU는 재개 첫 tick(기준점 갱신)에서 중지 상태를 유지해야 합니다.")
            return
        }
        guard case .normal(let memoryPresentation, _) = store.memoryCard else {
            Issue.record("Memory는 재개 첫 tick에서 곧바로 중지가 풀려야 합니다.")
            return
        }
        #expect(memoryPresentation.usedBytes == 111)

        // 값이 성립하는 다음 tick에서 CPU도 중지가 풀립니다.
        let resumeSecondTick = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(101)),
                value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 55)), memory: .success(memoryMetricsForTests(usedBytes: 111)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: resumeSecondTick, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(101)))

        guard case .normal(let cpuPresentation, _) = store.cpuCard else {
            Issue.record("값이 성립한 tick에서 CPU 중지가 풀려야 합니다.")
            return
        }
        #expect(cpuPresentation.overallUsage == 55)
    }
}

// MARK: - task-010: 앱별 하위 프로세스 그룹

/// `ApplicationRankingSample`은 앱 키별 합산값만 담고 그 키에 속한 개별 프로세스 목록을 담지 않으므로,
/// "앱 항목을 펼치면 하위 프로세스가 나타난다"(SPEC §5.2, SPEC §5.6)를 만족하려면 `groupByApplication(_:)`가
/// `ProcessHistoryStore.snapshot()` 결과를 별도로 순회해야 합니다. 이 테스트가 그 계산을 검증합니다.
struct ApplicationProcessGroupingTests {

    @Test func processesUnderSameBundleAreGroupedTogether() throws {
        let mainProcess = processHistorySnapshot(
            pid: 100, executablePath: "/Applications/Kiro.app/Contents/MacOS/Electron",
            cpuUsagePercent: 10, residentBytes: 1_000
        )
        let helperProcess = processHistorySnapshot(
            pid: 101,
            executablePath: "/Applications/Kiro.app/Contents/Frameworks/Kiro Helper (Renderer).app/Contents/MacOS/Kiro Helper (Renderer)",
            cpuUsagePercent: 15, residentBytes: 2_000, isTranslated: true
        )
        let otherApp = processHistorySnapshot(
            pid: 200, executablePath: "/Applications/Other.app/Contents/MacOS/Other",
            cpuUsagePercent: 5, residentBytes: 500
        )

        let (groups, _) = ApplicationRanking.groupByApplication(
            snapshots: [mainProcess, helperProcess, otherApp],
            resolver: ApplicationIdentityResolver()
        )

        #expect(groups.count == 2)
        let kiroGroup = try #require(groups.first { $0.displayName == "Kiro" })
        #expect(kiroGroup.processes.count == 2)
        #expect(Set(kiroGroup.processes.map(\.pid)) == [100, 101])

        let helperDetail = try #require(kiroGroup.processes.first { $0.pid == 101 })
        #expect(helperDetail.cpuUsagePercent == 15)
        #expect(helperDetail.residentBytes == 2_000)
        #expect(helperDetail.isTranslated, "Rosetta 여부가 그대로 전달되어야 합니다.")

        let mainDetail = try #require(kiroGroup.processes.first { $0.pid == 100 })
        #expect(!mainDetail.isTranslated)

        let otherGroup = try #require(groups.first { $0.displayName == "Other" })
        #expect(otherGroup.processes.count == 1)
    }

    @Test func emptySnapshotsProduceNoGroups() {
        let (groups, _) = ApplicationRanking.groupByApplication(snapshots: [], resolver: ApplicationIdentityResolver())

        #expect(groups.isEmpty)
    }
}

// MARK: - task-010: 단위 라벨 구분(SPEC §5.2, SPEC §5.3)

/// 시스템 전체 CPU와 프로세스 CPU가 서로 다른 단위 라벨을 가져야 합니다 —
/// 프로세스 CPU는 코어 합산이라 100%를 넘을 수 있고, 두 라벨을 같은 문자열로 되돌리면 이 테스트가 실패해야 합니다.
struct CPUUnitLabelTests {

    @Test func overallAndProcessUsageUnitLabelsDiffer() {
        #expect(CPUCardPresentation.overallUsageUnitLabel != ApplicationProcessDetail.cpuUsageUnitLabel)
    }

    /// 위 부등 단언은 두 상수를 어떤 값으로 바꿔도 서로 다르기만 하면 통과해 각 리터럴 자체를 검증하지
    /// 못합니다(`ApplicationRankingTests`의 `cpuGroupValueText`·`cpuProcessValueText` 단언도 같은 상수를
    /// 그대로 보간해 기대값을 만들므로 자기 참조라 이 값이 바뀌는 mutation을 잡지 못합니다).
    /// 그래서 각 리터럴 값을 여기서 직접 고정합니다.
    @Test func overallUsageUnitLabelIsPercentSign() {
        #expect(CPUCardPresentation.overallUsageUnitLabel == "%")
    }

    @Test func processUsageUnitLabelIndicatesCoreSummation() {
        #expect(ApplicationProcessDetail.cpuUsageUnitLabel == "% (코어 합산)")
    }
}

// MARK: - task-010(재작업, DP15): 카드 선택·복귀 단축키

/// 두 카드가 서로 다른 단축키를 써야 동시에 활성화되는 충돌이 없습니다.
struct DashboardSelectionShortcutTests {

    // cpuAndMemoryShortcutsDiffer(두 상수가 다르다는 단언)는 지웠습니다 — 두 상수가 각각 리터럴
    // "⌘1"·"⌘2"로 고정되는 아래 두 테스트가 성립하면 서로 다르다는 것도 함께 성립하고, 두 상수를 같은
    // 값으로 바꾸는 mutation은 아래 두 테스트가 이미 잡습니다. 반대로 이 테스트 하나만으로는 두 상수를
    // (둘 다 여전히 다르기만 하면) 어떤 값으로 바꿔도 통과해 키 상수 자체를 검증하지 못했습니다.

    /// 카드에 보이는 표시 문자열이 단축키 정의(`selectionShortcutKey`)와 같은 상수에서 유도되는지 고정합니다
    /// (task-016, ANALYSIS §5 DP15). `selectionShortcutKey`를 다른 문자로 바꾸면 이 단언이 함께 실패해야
    /// 표시가 키 정의와 어긋나지 않았다는 것이 확인됩니다.
    @Test func cpuShortcutDisplayTextMatchesDefinedKey() {
        #expect(CPUCardPresentation.selectionShortcutDisplayText == "⌘1")
    }

    @Test func memoryShortcutDisplayTextMatchesDefinedKey() {
        #expect(MemoryCardPresentation.selectionShortcutDisplayText == "⌘2")
    }
}

// MARK: - task-010: CPU 상세 조립

/// task-010 검증 조건: 상세 지표 구성은 항목 존재와 코어별 값 개수를 단언합니다.
struct CPUCardDetailAssembleTests {

    @Test func detailCarriesIdleRatioLoadAverageAndCoreUsageCount() {
        let cpu = CPUSystemMetrics(
            overallUsage: 42, userRatio: 30, systemRatio: 12, idleRatio: 58,
            coreUsages: [10, 20, 30, 40, 50, 60, 70, 80],
            loadAverage: LoadAverage(oneMinute: 1.5, fiveMinutes: 2.5, fifteenMinutes: 3.5)
        )

        let presentation = CPUCardPresentation.assemble(
            cpu: cpu, history: [], topApplications: [], currentTimestamp: baseInstant
        )

        #expect(presentation.detail.idleRatio == 58)
        #expect(presentation.detail.coreUsages.count == 8, "코어별 사용률 개수는 입력 그대로 전달되어야 합니다.")
        #expect(presentation.detail.loadAverage == cpu.loadAverage)
    }

    /// task-002 검증 조건: 앱 목록 머리글이 상세 정원(20)으로 조립됩니다 — 뷰가 정원을 고르지 않고
    /// `assemble`이 이미 완성한 문구를 그대로 받아 씁니다(ANALYSIS §5 DP1, DP2).
    @Test func detailApplicationsHeadingEmbedsDetailGantry() {
        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(), history: [], topApplications: [], currentTimestamp: baseInstant
        )

        #expect(presentation.detail.applicationsHeading == "CPU 사용량 순위, 합계 내림차순 (상위 20개)")
    }

    /// task-008 검증 조건: 시스템 프로세스 제외 사실이 CPU 상세에서도 확인됩니다 —
    /// 착수 전에는 Memory 상세의 증가량 순위 한 자리에만 있어 CPU 쪽에서는 도달하지 않았습니다.
    /// 문구는 이미 있는 상세용 캡션 그대로이고, 두 상세가 같은 상세 정원(20)에서 만든 같은 문구를 씁니다.
    @Test func bothDetailApplicationListsCarryTheSystemProcessExclusionNote() {
        let cpuPresentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(), history: [], topApplications: [], currentTimestamp: baseInstant
        )
        let memoryPresentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(), history: [], topApplications: [], currentTimestamp: baseInstant
        )
        let expected = ApplicationRankingSampling.topApplicationsCaption(
            count: ApplicationRankingSampling.detailCount
        )

        #expect(expected == "시스템 프로세스는 TOP 20에 포함되지 않습니다")
        #expect(cpuPresentation.detail.applicationsExclusionNote == expected)
        #expect(memoryPresentation.detail.applicationsExclusionNote == expected)
    }

    @Test func detailCarriesProcessGroupsThrough() {
        let (groups, _) = ApplicationRanking.groupByApplication(
            snapshots: [processHistorySnapshot(pid: 100, executablePath: "/bin/a", cpuUsagePercent: 10, residentBytes: 1_000)],
            resolver: ApplicationIdentityResolver()
        )

        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(), history: [], topApplications: [], processGroups: groups, currentTimestamp: baseInstant
        )

        // `assemble`은 그룹을 그대로가 아니라 `sortedForDisplay(groups:by:)`를 거쳐 담으므로
        // (상세 화면이 정렬 키를 그대로 표시하도록, 정렬 값이 채워진 그룹과 비교합니다).
        #expect(presentation.detail.applications == ApplicationRanking.sortedForDisplay(groups: groups, by: .cpuUsage))
    }

    /// CPU 상세는 그룹 안 프로세스의 CPU 사용량 합 기준으로 내림차순 정렬되어야 합니다(SPEC §5.2, SPEC §5.6).
    /// CPU와 Memory 기준을 서로 바꾸면, Memory가 더 큰 `LowCPUHighMemory`가 앞에 오게 되어 이 단언이 실패합니다.
    @Test func detailApplicationsAreSortedByCPUUsageDescending() {
        let highCPU = processHistorySnapshot(
            pid: 1, executablePath: "/Applications/HighCPU.app/Contents/MacOS/HighCPU",
            cpuUsagePercent: 50, residentBytes: 10
        )
        let lowCPUHighMemory = processHistorySnapshot(
            pid: 2, executablePath: "/Applications/LowCPUHighMemory.app/Contents/MacOS/LowCPUHighMemory",
            cpuUsagePercent: 5, residentBytes: 1_000_000
        )
        let (groups, _) = ApplicationRanking.groupByApplication(
            snapshots: [lowCPUHighMemory, highCPU],
            resolver: ApplicationIdentityResolver()
        )

        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(), history: [], topApplications: [], processGroups: groups, currentTimestamp: baseInstant
        )

        #expect(presentation.detail.applications.map(\.displayName) == ["HighCPU", "LowCPUHighMemory"])
    }
}

// MARK: - task-010: Memory 상세 조립 — 현재 사용량과 증가량은 다른 목록

/// task-010 검증 조건: Memory 상세에 현재 사용량 순위와 최근 증가량 순위가 서로 다른 목록으로 나타납니다.
struct MemoryCardDetailAssembleTests {

    @Test func detailCarriesRawMemoryComponents() {
        let memory = memoryMetricsForTests()

        let presentation = MemoryCardPresentation.assemble(
            memory: memory, history: [], topApplications: [], currentTimestamp: baseInstant
        )

        #expect(presentation.detail.appBytes == memory.appBytes)
        #expect(presentation.detail.wiredBytes == memory.wiredBytes)
        #expect(presentation.detail.compressedBytes == memory.compressedBytes)
        #expect(presentation.detail.cachedBytes == memory.cachedBytes)
    }

    /// task-002 검증 조건: 앱 목록 머리글이 「현재 사용량」임을 밝히고 상세 정원(20)으로 조립되며,
    /// CPU 상세의 머리글과 다른 문구를 씁니다(ANALYSIS §5 DP1, DP2).
    @Test func detailApplicationsHeadingStatesCurrentUsageAndDetailGantry() {
        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(), history: [], topApplications: [], currentTimestamp: baseInstant
        )

        #expect(presentation.detail.applicationsHeading == "현재 사용량 순위, Memory 사용량 합계 내림차순 (상위 20개)")
    }

    /// task-010(재작업) 검증 조건: Memory 상세에 Swap 사용량과 증가량이 나타나야 합니다.
    /// `MemoryDetailView`가 렌더링하는 값은 `detail`이 아니라 `presentation` 최상위 필드
    /// (`swapUsedBytes`·`swapRecentChangeBytes`, task-009가 이미 승인한 계산)이므로 여기서 함께 단언합니다.
    @Test func presentationCarriesSwapUsageAndRecentChange() {
        let memory = memoryMetricsForTests(swapUsedBytes: 500)
        // `swapRecentChangeBytes`는 창 안 가장 최신 값을 자기 자신의 기준점으로 삼지 않으므로(task-009),
        // 기준점(0초)과 현재 tick 자신(60초, `currentTimestamp`와 같은 시각)을 함께 이력에 넣어야 변화량이 나옵니다.
        let currentTimestamp = baseInstant.advanced(by: .seconds(60))
        let history = [
            swapHistoryPoint(secondsFromBase: 0, swapUsedBytes: 100),
            swapHistoryPoint(secondsFromBase: 60, swapUsedBytes: 500),
        ]

        let presentation = MemoryCardPresentation.assemble(
            memory: memory, history: history, topApplications: [], currentTimestamp: currentTimestamp
        )

        #expect(presentation.swapUsedBytes == 500)
        #expect(presentation.swapRecentChangeBytes == 400)
    }

    /// 10분 창 안에 이전 기준점이 없으면(이력이 비어 있으면) 변화량을 만들지 않고 `nil`이어야 합니다 —
    /// 값이 없는데 0으로 표시하면 안 되므로, 상세 화면이 이 경우를 구분해서 표시해야 합니다.
    @Test func presentationSwapRecentChangeIsNilWithoutABaseline() {
        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(swapUsedBytes: 500), history: [], topApplications: [], currentTimestamp: baseInstant
        )

        #expect(presentation.swapUsedBytes == 500)
        #expect(presentation.swapRecentChangeBytes == nil)
    }

    /// task-002(재작업) 검증 조건: 「앱 목록과 증가량 순위가 서로 다른 지표를 담는다」.
    /// `currentUsageRanking` 필드가 사라지고 `applications`(앱 목록)가 현재 사용량 순위를 겸하므로,
    /// 두 목록이 서로 다른 앱 구성·다른 순서를 담는지 값으로 직접 비교합니다.
    @Test func applicationsListAndIncreaseRankingCarryDifferentMetrics() {
        let heavyButStable = processHistorySnapshot(
            pid: 1, executablePath: "/Applications/HeavyButStable.app/Contents/MacOS/HeavyButStable",
            cpuUsagePercent: 1, residentBytes: 10_000_000
        )
        let smallButGrowing = processHistorySnapshot(
            pid: 2, executablePath: "/Applications/SmallButGrowing.app/Contents/MacOS/SmallButGrowing",
            cpuUsagePercent: 1, residentBytes: 1_000_000
        )
        let (groups, _) = ApplicationRanking.groupByApplication(
            snapshots: [smallButGrowing, heavyButStable],
            resolver: ApplicationIdentityResolver()
        )
        let increaseTop = [rankingEntry(name: "SmallButGrowing", value: 9_000_000)]

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(),
            history: [],
            topApplications: [],
            memoryIncrease: increaseTop,
            processGroups: groups,
            currentTimestamp: baseInstant
        )

        // `applications`는 Resident Memory 내림차순이므로 HeavyButStable이 앞에 옵니다 — 두 목록이
        // 서로 다른 지표(현재 사용량 vs 최근 증가량)를 담는다는 것을 이름 순서 자체로 보여줍니다.
        #expect(presentation.detail.applications.map(\.displayName) == ["HeavyButStable", "SmallButGrowing"])
        #expect(presentation.detail.recentIncreaseRanking == increaseTop)
        #expect(presentation.detail.applications.map(\.displayName) != presentation.detail.recentIncreaseRanking.map(\.displayName))
    }

    /// task-002 검증 조건: Memory 상세 값이 현재 사용량 순위를 두 자리에 담지 않습니다.
    /// 순위를 담을 수 있는 두 타입이 각각 한 자리씩만 있는지를 세어, 이름이 무엇이든 순위 전용 필드가
    /// 되살아나면 실패합니다. 필드 전체 개수를 세면 지표와 무관한 표시 필드가 늘어도 함께 깨져
    /// 무엇이 잘못됐는지 구분하지 못하므로, 타입으로 좁혀 셉니다.
    @Test func memoryCardDetailDoesNotCarryASeparateCurrentUsageRankingField() {
        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(), history: [], topApplications: [], currentTimestamp: baseInstant
        )

        let children = Mirror(reflecting: presentation.detail).children
        // 값 캐스팅(`is`)은 빈 배열이면 원소 타입과 무관하게 참이 되므로 선언 타입으로 셉니다.
        let rankingFields = children.filter { type(of: $0.value) == [ApplicationRankingEntry].self }
        let groupListFields = children.filter { type(of: $0.value) == [ApplicationProcessGroup].self }

        #expect(
            rankingFields.count == 1,
            "`[ApplicationRankingEntry]` 필드는 최근 증가량 순위 하나여야 합니다 — 현재 사용량 순위 전용 필드가 되살아났는지 확인하세요."
        )
        #expect(
            groupListFields.count == 1,
            "`[ApplicationProcessGroup]` 필드는 순위를 겸하는 앱 목록 하나여야 합니다 — 순위 목록이 따로 생겼는지 확인하세요."
        )
    }

    /// 증가량 순위는 음수를 담을 수 있습니다(메모리가 줄어든 경우) — 이 값이 카드 표시에서 trap하지 않고
    /// 그대로 보관되는지 확인합니다. `TopApplicationsView`의 `UInt64` 변환 경로를 재사용하면 trap하는
    /// 회귀를 막는 것이 이 단언의 목적입니다.
    @Test func recentIncreaseRankingCanContainNegativeValues() {
        let negativeIncrease = [rankingEntry(name: "Shrunk", value: -500)]

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(),
            history: [],
            topApplications: [],
            memoryIncrease: negativeIncrease,
            currentTimestamp: baseInstant
        )

        #expect(presentation.detail.recentIncreaseRanking.first?.value == -500)
    }

    /// Memory 상세는 그룹 안 프로세스의 Resident Memory 합 기준으로 내림차순 정렬되어야 합니다(SPEC §5.2, SPEC §5.6).
    /// CPU와 Memory 기준을 서로 바꾸면, CPU가 더 큰 `HighCPULowMemory`가 앞에 오게 되어 이 단언이 실패합니다.
    @Test func detailApplicationsAreSortedByResidentMemoryDescending() {
        let highCPULowMemory = processHistorySnapshot(
            pid: 1, executablePath: "/Applications/HighCPULowMemory.app/Contents/MacOS/HighCPULowMemory",
            cpuUsagePercent: 90, residentBytes: 10
        )
        let highMemory = processHistorySnapshot(
            pid: 2, executablePath: "/Applications/HighMemory.app/Contents/MacOS/HighMemory",
            cpuUsagePercent: 1, residentBytes: 1_000_000
        )
        let (groups, _) = ApplicationRanking.groupByApplication(
            snapshots: [highCPULowMemory, highMemory],
            resolver: ApplicationIdentityResolver()
        )

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(), history: [], topApplications: [], processGroups: groups, currentTimestamp: baseInstant
        )

        #expect(presentation.detail.applications.map(\.displayName) == ["HighMemory", "HighCPULowMemory"])
    }
}

// MARK: - task-010: 카드 선택 상태 전이

/// task-010 검증 조건: 선택 없음 → CPU → 선택 없음, 선택 없음 → Memory → 선택 없음, CPU → Memory 전이가
/// 카드 활성화만으로 일어납니다.
@MainActor
struct DashboardSelectionTests {

    @Test func startsWithNoSelection() {
        let store = DashboardPresentationStore()

        #expect(store.selection == .none)
    }

    @Test func selectingCPUThenSameCardAgainReturnsToNoSelection() {
        let store = DashboardPresentationStore()

        store.selectCard(.cpu)
        #expect(store.selection == .cpu)

        store.selectCard(.cpu)
        #expect(store.selection == .none)
    }

    @Test func selectingMemoryThenSameCardAgainReturnsToNoSelection() {
        let store = DashboardPresentationStore()

        store.selectCard(.memory)
        #expect(store.selection == .memory)

        store.selectCard(.memory)
        #expect(store.selection == .none)
    }

    @Test func selectingMemoryWhileCPUIsSelectedSwitchesSelection() {
        let store = DashboardPresentationStore()

        store.selectCard(.cpu)
        store.selectCard(.memory)

        #expect(store.selection == .memory)
    }

    /// task-010이 고정하는 것: "수집 갱신이 선택을 초기화하지 않는다".
    /// 선택 상태에서 수집 결과 갱신과 지표 실패를 연속으로 넣고 선택이 유지되는지 단언하며,
    /// 선택을 표시 값과 함께 재생성하도록 되돌리면(예: 카드 갱신 시 selection도 `.none`으로 되돌리면) 이 테스트가 실패해야 합니다.
    @Test func selectionSurvivesRepeatedCardUpdatesAndFailures() {
        let store = DashboardPresentationStore()
        store.selectCard(.cpu)

        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics()), memory: .success(memoryMetricsForTests()))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        #expect(store.selection == .cpu)

        let failureValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(1)),
                value: SystemMetricsSample(
                    cpu: .failure(CollectorFailure(metric: .cpu, cause: .systemCall(name: "host_processor_info", code: 5))),
                    memory: .success(memoryMetricsForTests())
                )
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))
        store.updateMemoryCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))
        #expect(store.selection == .cpu, "수집 실패가 선택 상태를 바꾸면 안 됩니다.")

        store.updateMemoryCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        #expect(store.selection == .cpu, "다른 카드의 수집 갱신도 선택 상태를 바꾸면 안 됩니다.")
    }

    /// task-010 재작업이 고정하는 것: "팝업 자신의 닫힘"이 선택 해제로 이어집니다(ANALYSIS §2 「팝오버 열림과 카드 선택」, §5 DP14).
    /// `dismissDetail(for:)`를 무력화하면(예: 본문을 비우면) 이 단언이 실패해야 합니다.
    @Test func dismissDetailForSelectedCardClearsSelection() {
        let store = DashboardPresentationStore()
        store.selectCard(.cpu)
        #expect(store.selection == .cpu)

        store.dismissDetail(for: .cpu)
        #expect(store.selection == .none)
    }

    @Test func dismissDetailForSelectedMemoryCardClearsSelection() {
        let store = DashboardPresentationStore()
        store.selectCard(.memory)
        #expect(store.selection == .memory)

        store.dismissDetail(for: .memory)
        #expect(store.selection == .none)
    }

    /// 선택이 이미 다른 카드로 옮겨간 뒤(예: CPU 팝업이 열린 채 ⌘2로 Memory를 선택해 CPU 자식 팝오버가 닫히는 경우)라면,
    /// CPU 쪽의 뒤늦은 자기 닫힘 신호가 방금 옮겨간 Memory 선택을 지우면 안 됩니다 —
    /// 이 가드를 없애면(무조건 `.none`으로 지우면) 이 단언이 실패해야 합니다.
    @Test func dismissDetailForCardThatIsNoLongerSelectedDoesNotClearNewSelection() {
        let store = DashboardPresentationStore()
        store.selectCard(.cpu)
        store.selectCard(.memory)
        #expect(store.selection == .memory)

        store.dismissDetail(for: .cpu)
        #expect(store.selection == .memory, "이미 다른 카드로 옮겨간 선택을 지우면 안 됩니다.")
    }

    /// 선택 없음 상태에서의 자기 닫힘 신호도 안전하게 무시되어야 합니다.
    @Test func dismissDetailWhileNoSelectionStaysNone() {
        let store = DashboardPresentationStore()

        store.dismissDetail(for: .cpu)
        #expect(store.selection == .none)
    }
}

// MARK: - CPU 그래프 레이아웃과 기준선 좌표

/// 눈금 값 집합이 25·50·75%이고 화면에 그리는 기준선은 그 가운데 값 하나이며,
/// 값→세로 좌표 변환이 0%를 그래프 바닥, 100%를 천장에 대응시킵니다(SPEC §5.2).
/// 눈금 값 집합을 바꾸거나, 그리는 기준선을 늘리거나, 변환의 위아래를 뒤집거나 높이를 무시하고
/// 고정 좌표를 돌려주면 아래 단언들이 실패해야 합니다.
struct HistoryGraphGridlineTests {

    @Test func graphSlotHeightIsDerivedFromPlotAxisSpacingAndLabelHeight() {
        #expect(
            HistoryGraphLayout.slotHeight
                == HistoryGraphLayout.plotHeight
                + HistoryGraphLayout.axisSpacing
                + HistoryGraphLayout.axisLabelHeight
        )
        #expect(HistoryGraphLayout.plotHeight == 100)
        #expect(HistoryGraphLayout.slotHeight == 118)
    }

    @Test func graphPlotIsTallerAndLessHorizontallyCompressedThanBefore() {
        let plotWidth: CGFloat = 232
        let previousPlotHeight: CGFloat = 60
        let previousAspectRatio = plotWidth / previousPlotHeight

        #expect(HistoryGraphLayout.plotHeight > previousPlotHeight)
        #expect(plotWidth / HistoryGraphLayout.plotHeight < previousAspectRatio)
    }

    @Test func baselineValuesAreExactlyTwentyFiveFiftySeventyFive() {
        #expect(HistoryGraphGridline.baselineValues == [25, 50, 75])
        #expect(HistoryGraphGridline.lineWidth == 1)
    }

    /// 60pt 높이에서 세 선이 15pt 간격으로 놓입니다(0%가 바닥 60, 100%가 천장 0).
    @Test func yPositionsAreFifteenPointsApartAtSixtyPointHeight() {
        let y25 = HistoryGraphGridline.yPosition(forValue: 25, height: 60)
        let y50 = HistoryGraphGridline.yPosition(forValue: 50, height: 60)
        let y75 = HistoryGraphGridline.yPosition(forValue: 75, height: 60)

        #expect(y75 == 15)
        #expect(y50 == 30)
        #expect(y25 == 45)
    }

    @Test func zeroPercentIsAtTheBottomAndHundredPercentIsAtTheTop() {
        #expect(HistoryGraphGridline.yPosition(forValue: 0, height: 60) == 60)
        #expect(HistoryGraphGridline.yPosition(forValue: 100, height: 60) == 0)
    }

    /// 변환이 높이를 무시하고 고정 좌표를 돌려주면, 높이를 두 배로 늘려도 좌표가 그대로여서 이 단언이 실패합니다.
    @Test func yPositionScalesWithHeight() {
        #expect(HistoryGraphGridline.yPosition(forValue: 50, height: 60) == 30)
        #expect(HistoryGraphGridline.yPosition(forValue: 50, height: 120) == 60)
    }

    /// 화면에 긋는 선은 하나뿐이고, 그 값은 리터럴이 아니라 눈금 값 집합의 가운데 값에서 나옵니다.
    /// 기준선을 둘 이상으로 되돌리거나 눈금 값 집합과 무관한 리터럴로 박으면 실패합니다.
    @Test func exactlyOneBaselineIsDrawnAndItIsTheMiddleTickValue() {
        let ticks = HistoryGraphGridline.baselineValues
        let middle = ticks[ticks.count / 2]

        #expect(HistoryGraphGridline.drawnBaselineValues.count == 1)
        #expect(HistoryGraphGridline.drawnBaselineValues == [middle])
    }
}

// MARK: - 그래프 시간 축과 미수집 구간

struct HistoryGraphTimeAxisTests {

    @Test func emptyPointsMarkTheWholeWindowAsUncollected() {
        let axis = HistoryGraphTimeAxis.make(points: [], currentTimestamp: baseInstant)

        #expect(axis.leadingLabel == "10분 전")
        #expect(axis.trailingLabel == "지금")
        #expect(axis.uncollectedNormalizedWidth == 1)
        #expect(axis.collectionProgressLabel == "데이터 수집 중 · 00:00 / 10:00")
    }

    @Test func firstPointInTheMiddleDeterminesTheUncollectedWidth() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(600))
        let points = [
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(300)), value: 10),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(600)), value: 20),
        ]

        let axis = HistoryGraphTimeAxis.make(points: points, currentTimestamp: currentTimestamp)

        #expect(axis.uncollectedNormalizedWidth == 0.5)
        #expect(axis.collectionProgressLabel == "데이터 수집 중 · 05:00 / 10:00")
    }

    @Test func fullWindowHasNoCollectionProgressTextButKeepsTheSameSlotHeight() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(600))
        let points = [HistoryPoint(timestamp: baseInstant, value: 10)]

        let axis = HistoryGraphTimeAxis.make(points: points, currentTimestamp: currentTimestamp)

        #expect(axis.uncollectedNormalizedWidth == 0)
        #expect(axis.collectionProgressLabel.isEmpty)
        #expect(HistoryGraphLayout.slotHeight == 118)
    }

    @Test func middleGapDoesNotChangeTheFirstPointBasedUncollectedWidth() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(600))
        let pointsWithMiddleGap = [
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(180)), value: 10),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(181)), value: 20),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(590)), value: 30),
        ]

        let axis = HistoryGraphTimeAxis.make(points: pointsWithMiddleGap, currentTimestamp: currentTimestamp)

        #expect(axis.uncollectedNormalizedWidth == 0.3)
        #expect(axis.collectionProgressLabel == "데이터 수집 중 · 07:00 / 10:00")
    }

    @Test func collectionProgressUsesElapsedAndTotalDurations() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(600))
        let points = [HistoryPoint(timestamp: currentTimestamp.advanced(by: .seconds(-42)), value: 10)]

        let axis = HistoryGraphTimeAxis.make(points: points, currentTimestamp: currentTimestamp)

        #expect(axis.collectionProgressLabel == "데이터 수집 중 · 00:42 / 10:00")
    }
}

// MARK: - CPU 그래프 기준선·밴드 그리기 순서

/// `HistoryGraphView.body`는 `drawOrder`를 그대로 순회해 그리므로, 이 배열이 실제 그리기 순서 그 자체입니다.
/// 기준선이 밴드 채움·경계선보다 먼저(가장 뒤에) 와야 부하가 높아 밴드가 그 자리를 덮는 구간에서도
/// 기준선이 반투명 밴드 아래로 비칩니다(SPEC §5.2, DESIGN §5 DP5).
/// 순서를 밴드가 기준선보다 먼저 오도록 바꾸거나, 밴드 채움 불투명도를 1.0(불투명)으로 바꾸거나,
/// 판 테두리·미수집 구간 레이어를 되살리면 아래 단언들이 실패해야 합니다.
@MainActor
struct HistoryGraphViewDrawOrderTests {

    @Test func gridlinesAreDrawnBeforeBandFillsAndBoundaries() {
        #expect(HistoryGraphView.drawOrder.first == .gridlines)
    }

    @Test func drawOrderIsGridlinesThenFillsAndBoundaries() {
        #expect(HistoryGraphView.drawOrder == [
            .gridlines,
            .bandFill(.lower),
            .bandFill(.upper),
            .bandBoundary(.lower),
            .bandBoundary(.upper)
        ])
        #expect(HistoryGraphView.drawOrder.first == .gridlines)
    }

    @Test func bandFillOpacitiesAreTranslucentSoGridlinesShowThrough() {
        #expect(HistoryGraphView.fillOpacity(for: .lower) == 0.60)
        #expect(HistoryGraphView.fillOpacity(for: .upper) == 0.15)
        #expect(HistoryGraphView.fillOpacity(for: .lower) < 1.0)
        #expect(HistoryGraphView.fillOpacity(for: .upper) < 1.0)
    }

    @Test func lowerBoundaryIsDashedAndUpperBoundaryIsSolid() {
        let lower = HistoryGraphView.boundaryStyle(for: .lower)
        let upper = HistoryGraphView.boundaryStyle(for: .upper)

        #expect(lower.dash == [3, 2])
        #expect(upper.dash.isEmpty)
        #expect(lower.lineWidth == upper.lineWidth)
    }
}

// MARK: - 값 없는 자리표시가 그리는 레이어 목록

/// 값이 없는 상태의 그래프 자리는 값 있는 경로와 같은 `HistoryGraphLayout` 높이를 쓰므로,
/// `Canvas`가 기준선을 그리든 안 그리든 `NSHostingController.sizeThatFits(in:)` 높이는 같습니다 —
/// 그래서 기준선 유무는 높이 단언이 아니라 이 목록 자체로 잡습니다(SPEC §5.13, DESIGN §5 DP6).
/// 값 없음 경로가 `HistoryGraphGridline.placeholderDrawOrder`를 그대로 순회해 그리므로,
/// 이 배열이 자리표시의 실제 그리기 내용 그 자체입니다.
@MainActor
struct HistoryGraphGridlinePlaceholderDrawOrderTests {

    @Test func placeholderDrawOrderContainsOnlyGridlines() {
        #expect(HistoryGraphGridline.placeholderDrawOrder == [.gridlines])
        // 값 있음 경로(`HistoryGraphView.drawOrder`)도 같은 기준선 레이어로 시작해,
        // 두 경로가 같은 좌표에 같은 선 하나를 그립니다.
        #expect(HistoryGraphGridline.placeholderDrawOrder.first == .gridlines)
        #expect(HistoryGraphView.drawOrder.first == .gridlines)
        // 미수집 구간을 덮는 레이어가 두 목록 어디에도 없습니다 —
        // 위 두 배열 단언이 그 사실을 목록 전수로 잡습니다.
        #expect(HistoryGraphGridline.placeholderDrawOrder.count == 1)
        #expect(HistoryGraphView.drawOrder.count == 5)
    }
}
