//
//  MonitoringSampleStoreTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/10/26.
//

import Testing
@testable import ResourceRunner

/// task-008 검증 조건: 10분 × 1·2·5초의 600·300·120 용량, 나누어떨어지지 않는 주기의 올림,
/// 용량 경계 직전·직후·연속 초과 append, wrap-around 전후 순서,
/// 축소·확대 resize의 최신 항목 보존과 빈 공간 미충전, 빈 버퍼와 첫 샘플을 검증합니다.
struct HistoryCapacityTests {

    @Test(arguments: [
        (Duration.seconds(1), 600),
        (Duration.seconds(2), 300),
        (Duration.seconds(5), 120),
    ])
    func computesCapacityForDefaultTenMinuteRange(samplingInterval: Duration, expectedCapacity: Int) {
        let capacity = HistoryCapacity.capacity(
            timeRange: HistoryCapacity.defaultTimeRange,
            samplingInterval: samplingInterval
        )

        #expect(capacity == expectedCapacity)
    }

    @Test func roundsUpWhenRangeDoesNotDivideEvenly() {
        // 601 / 4 = 150.25 -> ceil = 151
        let capacity = HistoryCapacity.capacity(timeRange: .seconds(601), samplingInterval: .seconds(4))

        #expect(capacity == 151)
    }

    /// 「결과는 항상 1 이상」을 고정합니다.
    /// 범위가 주기보다 짧기만 한 입력은 올림만으로도 1이 나와 하한을 거치지 않으므로,
    /// 올림 결과가 0 이하가 되는 입력을 함께 넣어야 하한이 실제로 검증됩니다.
    @Test(arguments: [
        (Duration.seconds(1), Duration.seconds(600)),    // 올림으로 1
        (Duration.zero, Duration.seconds(1)),            // 올림 결과 0 -> 하한이 필요
        (Duration.seconds(-10), Duration.seconds(1)),    // 올림 결과 음수 -> 하한이 필요
    ])
    func resultIsAlwaysAtLeastOne(timeRange: Duration, samplingInterval: Duration) {
        let capacity = HistoryCapacity.capacity(timeRange: timeRange, samplingInterval: samplingInterval)

        #expect(capacity >= 1)
    }
}

struct CircularBufferTests {

    @Test func emptyBufferReturnsEmptyElements() {
        let buffer = CircularBuffer<Int>(capacity: 3)

        #expect(buffer.elements.isEmpty)
        #expect(buffer.count == 0)
    }

    @Test func firstSampleBecomesTheOnlyCurrentElement() {
        var buffer = CircularBuffer<Int>(capacity: 3)

        buffer.append(1)

        #expect(buffer.elements == [1])
    }

    @Test func appendJustBelowCapacityKeepsAllElementsInOrder() {
        var buffer = CircularBuffer<Int>(capacity: 3)

        buffer.append(1)
        buffer.append(2)

        #expect(buffer.elements == [1, 2])
    }

    @Test func appendAtCapacityKeepsAllElementsInOrderWithoutEviction() {
        var buffer = CircularBuffer<Int>(capacity: 3)

        buffer.append(1)
        buffer.append(2)
        buffer.append(3)

        #expect(buffer.elements == [1, 2, 3])
    }

    @Test func appendBeyondCapacityReplacesOnlyTheOldestElement() {
        var buffer = CircularBuffer<Int>(capacity: 3)

        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        buffer.append(4)

        #expect(buffer.elements == [2, 3, 4])
    }

    @Test func consecutiveOverflowsPreserveOldestFirstOrderAcrossWrapAround() {
        var buffer = CircularBuffer<Int>(capacity: 3)

        for value in 1...10 {
            buffer.append(value)
        }

        // writeIndex가 여러 번 wrap-around한 뒤에도 오래된 것부터 시간순이어야 합니다.
        #expect(buffer.elements == [8, 9, 10])
    }

    @Test func readingAcrossWrapAroundBoundaryStaysOldestFirst() {
        var buffer = CircularBuffer<Int>(capacity: 4)

        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        buffer.append(4)
        // 여기서 writeIndex가 0으로 wrap. 다음 append가 wrap 경계를 넘습니다.
        buffer.append(5)

        #expect(buffer.elements == [2, 3, 4, 5])
    }

    @Test func shrinkingResizeKeepsOnlyTheNewestElements() {
        var buffer = CircularBuffer<Int>(capacity: 5)
        for value in 1...5 {
            buffer.append(value)
        }

        let resized = buffer.resized(to: 2)

        #expect(resized.elements == [4, 5])
        #expect(resized.capacity == 2)
    }

    @Test func growingResizeDoesNotFillNewSpace() {
        var buffer = CircularBuffer<Int>(capacity: 2)
        buffer.append(1)
        buffer.append(2)

        let resized = buffer.resized(to: 5)

        #expect(resized.elements == [1, 2])
        #expect(resized.count == 2)
        #expect(resized.capacity == 5)
    }

    @Test func growingResizeAllowsFurtherAppendsWithoutPrematureEviction() {
        var buffer = CircularBuffer<Int>(capacity: 2)
        buffer.append(1)
        buffer.append(2)

        var resized = buffer.resized(to: 4)
        resized.append(3)
        resized.append(4)

        #expect(resized.elements == [1, 2, 3, 4])
    }
}

struct MonitoringSampleStoreTests {

    @Test func appendingFirstSampleMakesItTheOnlySnapshotEntry() async {
        let store = MonitoringSampleStore<Int>(samplingInterval: .seconds(1))
        let clock = ContinuousClock()
        let sample = TimestampedSample(timestamp: clock.now, value: 42)

        await store.append(sample)
        let snapshot = await store.snapshot()

        #expect(snapshot.map(\.value) == [42])
    }

    @Test func emptyStoreReturnsEmptySnapshot() async {
        let store = MonitoringSampleStore<Int>(samplingInterval: .seconds(1))

        let snapshot = await store.snapshot()

        #expect(snapshot.isEmpty)
    }

    @Test func snapshotOrdersOldestFirstAfterOverflow() async {
        // 10분 / 5초 = 120 용량이지만 여기서는 작은 주기로 빠르게 경계를 넘기기 위해
        // 시간 범위를 직접 좁혀 용량 3으로 만듭니다.
        let store = MonitoringSampleStore<Int>(timeRange: .seconds(3), samplingInterval: .seconds(1))
        let clock = ContinuousClock()

        for value in 1...5 {
            await store.append(TimestampedSample(timestamp: clock.now, value: value))
        }

        let snapshot = await store.snapshot()

        #expect(snapshot.map(\.value) == [3, 4, 5])
    }

    @Test func resizeToShorterIntervalKeepsOnlyNewestSamples() async {
        let store = MonitoringSampleStore<Int>(timeRange: .seconds(5), samplingInterval: .seconds(1))
        let clock = ContinuousClock()

        for value in 1...5 {
            await store.append(TimestampedSample(timestamp: clock.now, value: value))
        }

        // 용량 5 -> 시간 범위를 그대로 두고 주기를 5초로 늘리면 용량은 1로 줄어듭니다.
        await store.resize(samplingInterval: .seconds(5))
        let snapshot = await store.snapshot()

        #expect(snapshot.map(\.value) == [5])
    }

    @Test func resizeToLargerCapacityDoesNotFabricatePastData() async {
        let store = MonitoringSampleStore<Int>(timeRange: .seconds(2), samplingInterval: .seconds(1))
        let clock = ContinuousClock()

        await store.append(TimestampedSample(timestamp: clock.now, value: 1))
        await store.append(TimestampedSample(timestamp: clock.now, value: 2))

        // 시간 범위를 늘려 용량을 키웁니다. 기존 두 샘플만 남아야 하며 빈 자리를 채우지 않습니다.
        await store.resize(samplingInterval: .seconds(1), timeRange: .seconds(10))
        let snapshot = await store.snapshot()

        #expect(snapshot.map(\.value) == [1, 2])
    }
}
