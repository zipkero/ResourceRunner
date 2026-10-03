import Foundation
import Testing
@testable import ResourceRunner

struct ResourceRateGraphTests {
    private let now = ContinuousClock().now

    private func point(_ ago: Int, _ first: Double, _ second: Double,
                       epoch: Int = 0, segment: UInt64 = 1,
                       gap: Duration = .seconds(10)) -> RateHistoryPoint {
        RateHistoryPoint(timestamp: now.advanced(by: .seconds(-ago)),
            rate: RatePair(receivedBytesPerSecond: first, sentBytesPerSecond: second)!,
            collectionEpoch: epoch, rateSegment: segment,
            maximumConnectedGap: gap)
    }

    @Test func selectedWindowControlsVisiblePeaksCoordinatesAndProgressWithoutChangingHistory() {
        let history = [point(590, 90_000, 1), point(300, 5_000, 1),
            point(60, 2_000, 1), point(1, 100, 200), point(-1, 999_999, 1)]
        let first = now.advanced(by: .seconds(-90))
        let one = ResourceRateGraph.make(history: history, firstHistoryPointAt: first,
            currentTimestamp: now, timeRange: .oneMinute)
        let five = ResourceRateGraph.make(history: history, firstHistoryPointAt: first,
            currentTimestamp: now, timeRange: .fiveMinutes)
        let ten = ResourceRateGraph.make(history: history, firstHistoryPointAt: first,
            currentTimestamp: now, timeRange: .tenMinutes)
        #expect(history.count == 5)
        #expect(one.visibleSegments.flatMap { $0 }.count == 2)
        #expect(five.visibleSegments.flatMap { $0 }.count == 3)
        #expect(ten.visibleSegments.flatMap { $0 }.count == 4)
        #expect(one.upperBound == 2_000)
        #expect(five.upperBound == 5_000)
        #expect(ten.upperBound == 100_000)
        #expect(one.normalizedX(now.advanced(by: .seconds(-60))) == 0)
        #expect(five.normalizedX(now.advanced(by: .seconds(-300))) == 0)
        #expect(ten.normalizedX(now.advanced(by: .seconds(-600))) == 0)
        #expect(one.normalizedX(now) == 1)
        #expect(one.progressLabel == "")
        #expect(five.progressLabel == "데이터 수집 중 · 01:30 / 05:00")
        #expect(ten.progressLabel == "데이터 수집 중 · 01:30 / 10:00")
    }

    @Test func latterPointsHistoricalGapAndSegmentDefineConnectivity() {
        let history = [
            point(60, 1, 1),
            point(45, 2, 2, gap: .seconds(20)),
            point(30, 3, 3, gap: .seconds(10)),
            point(15, 4, 4, segment: 2, gap: .seconds(20)),
            point(0, 5, 5, epoch: 1, segment: 2, gap: .seconds(20))
        ]
        let graph = ResourceRateGraph.make(history: history,
            firstHistoryPointAt: history.first?.timestamp, currentTimestamp: now,
            timeRange: .oneMinute)
        #expect(graph.visibleSegments.map(\.count) == [2, 1, 1, 1])
        #expect(graph.downsampledSegments(bucketCount: 1).map(\.count) == [2, 1, 1, 1])
    }

    @Test func originalPeaksOfBothSeriesSetOnePositiveAxisBeforeDownsampling() {
        var points = (0..<240).map { index in point(599 - index * 2, 20, 30) }
        points[37] = point(599 - 37 * 2, 8_000, 30)
        points[181] = point(599 - 181 * 2, 20, 18_000)
        let graph = ResourceRateGraph.make(history: points, firstHistoryPointAt: now.advanced(by: .seconds(-599)),
            currentTimestamp: now)
        #expect(graph.upperBound == 20_000)
        #expect(graph.rangeLabel == "0–19.5 KB/s")
        let sampled = graph.downsampledSegments(bucketCount: 5).flatMap { $0 }
        #expect(sampled.contains { $0.rate.receivedBytesPerSecond == 8_000 })
        #expect(sampled.contains { $0.rate.sentBytesPerSecond == 18_000 })
        #expect(sampled.count < points.count)
        #expect(sampled.map(\.timestamp) == sampled.map(\.timestamp).sorted())
        #expect(graph.normalizedY(0) == 1)
        #expect(graph.normalizedY(20_000) == 0)
        #expect(graph.normalizedX(now.advanced(by: .seconds(-600))) == 0)
        #expect(graph.normalizedX(now) == 1)
    }

    @Test func zeroAndAxisBoundariesAndPlaceholderNeverInventPeak() {
        let empty = ResourceRateGraph.make(history: [], firstHistoryPointAt: nil, currentTimestamp: now)
        #expect(empty.visibleSegments.isEmpty)
        #expect(empty.upperBound == nil)
        #expect(empty.rangeLabel == "속도 범위 대기 · B/s")
        #expect(empty.progressLabel == "데이터 수집 중 · 00:00 / 10:00")
        let zero = ResourceRateGraph.make(history: [point(1, 0, 0)],
            firstHistoryPointAt: now.advanced(by: .seconds(-1)), currentTimestamp: now)
        #expect(zero.upperBound == 1_024)
        #expect(zero.rangeLabel == "0–1.0 KB/s")
        #expect(ResourceRateGraph.niceUpperBound(for: 1_024) == 1_024)
        #expect(ResourceRateGraph.niceUpperBound(for: 1_025) == 2_000)
        #expect(ResourceRateGraph.niceUpperBound(for: 2_001) == 5_000)
        #expect(ResourceRateGraph.niceUpperBound(for: 5_001) == 10_000)
        #expect(ResourceRateGraph.niceUpperBound(for: .infinity) == 1_024)
    }

    @Test func epochSegmentAndMoreThanTenSecondsSplitBeforeSamplingWithoutFakeZero() {
        let points = [
            point(100, 12, 20), point(99, 15, 25),
            point(98, 17, 27, segment: 2), point(97, 20, 30, segment: 2),
            point(96, 21, 31, epoch: 1, segment: 3),
            point(80, 22, 32, epoch: 1, segment: 3),
            point(70, 23, 33, epoch: 1, segment: 3)
        ]
        let graph = ResourceRateGraph.make(history: points, firstHistoryPointAt: points[0].timestamp,
            currentTimestamp: now)
        #expect(graph.visibleSegments.map(\.count) == [2, 2, 1, 2])
        #expect(graph.downsampledSegments(bucketCount: 1).map(\.count) == [2, 2, 1, 2])
        #expect(graph.visibleSegments.flatMap { $0 }.count == points.count)
        #expect(!graph.visibleSegments.flatMap { $0 }.contains { $0.rate.receivedBytesPerSecond == 0 })
    }

    @Test func stoppedWindowMovesAndProgressDoesNotRestartAfterOldPointsLeave() {
        let started = now.advanced(by: .seconds(-601))
        let early = point(599, 50, 60)
        let recent = point(2, 10, 20)
        let first = ResourceRateGraph.make(history: [early, recent], firstHistoryPointAt: started,
            currentTimestamp: now)
        #expect(first.progressLabel == "")
        #expect(first.visibleSegments.count == 2)
        let later = ResourceRateGraph.make(history: [early, recent], firstHistoryPointAt: started,
            currentTimestamp: now.advanced(by: .seconds(700)))
        #expect(later.visibleSegments.isEmpty)
        #expect(later.upperBound == nil)
        #expect(later.progressLabel == "")
        let stopping = ResourceRateGraph.make(history: [early, recent], firstHistoryPointAt: started,
            currentTimestamp: now.advanced(by: .seconds(30)))
        #expect(stopping.visibleSegments.count == 1)
        #expect(stopping.normalizedX(recent.timestamp) < first.normalizedX(recent.timestamp))
    }

    @Test func initialProgressUsesIndependentFirstPointEvenWhenRecentHistoryWasFiltered() {
        let started = now.advanced(by: .seconds(-600))
        let onlyRecent = [point(1, 12, 13)]
        let graph = ResourceRateGraph.make(history: onlyRecent, firstHistoryPointAt: started,
            currentTimestamp: now)
        #expect(graph.progressLabel == "")
        #expect(graph.visibleSegments.count == 1)
        let incomplete = ResourceRateGraph.make(history: onlyRecent,
            firstHistoryPointAt: now.advanced(by: .seconds(-60)), currentTimestamp: now)
        #expect(incomplete.progressLabel == "데이터 수집 중 · 01:00 / 10:00")
    }

    @Test func activityStoresKeepFirstValidPointOutsideTheirRecentWindow() async {
        let networkStore = NetworkActivityStore()
        let diskStore = DiskActivityStore()
        for ago in [601, 1] {
            let timestamp = now.advanced(by: .seconds(-ago))
            let measured = RatePair(receivedBytesPerSecond: Double(ago),
                sentBytesPerSecond: Double(ago + 1))!
            let network = NetworkActivitySample(readAt: timestamp, topologyRevision: 1,
                interfaces: [], knownPhysicalRates: measured, representative: measured,
                physicalTotalsComplete: true, status: .rate, rateSegment: 1)
            let disk = DiskActivitySample(readAt: timestamp, topologyRevision: 1,
                devices: [], knownPhysicalRates: measured, representative: measured,
                knownPhysicalOperations: nil, representativeOperations: nil,
                physicalTotalsComplete: true, status: .rate, rateSegment: 1)
            await networkStore.append(TimestampedSample(timestamp: timestamp, value: network))
            await diskStore.append(TimestampedSample(timestamp: timestamp, value: disk))
        }
        let network = await networkStore.snapshot(at: now)
        let disk = await diskStore.snapshot(at: now)
        #expect(network.recentHistory.count == 1)
        #expect(disk.recentHistory.count == 1)
        #expect(network.firstHistoryPointAt == now.advanced(by: .seconds(-601)))
        #expect(disk.firstHistoryPointAt == now.advanced(by: .seconds(-601)))
        #expect(ResourceRateGraph.make(history: network.recentHistory,
            firstHistoryPointAt: network.firstHistoryPointAt, currentTimestamp: now).progressLabel == "")
        #expect(ResourceRateGraph.make(history: disk.recentHistory,
            firstHistoryPointAt: disk.firstHistoryPointAt, currentTimestamp: now).progressLabel == "")
        let networkCard = NetworkCardPresentation.assemble(activity: network,
            metadata: nil, epoch: 0, wasStopped: false).stopping()
        let diskCard = DiskCardPresentation.assemble(activity: disk,
            metadata: nil, epoch: 0, wasStopped: false).stopping()
        #expect(networkCard.recentHistory == network.recentHistory)
        #expect(diskCard.recentHistory == disk.recentHistory)
        #expect(networkCard.firstHistoryPointAt == network.firstHistoryPointAt)
        #expect(diskCard.firstHistoryPointAt == disk.firstHistoryPointAt)
    }
}
