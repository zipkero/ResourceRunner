//
//  MonitoringSampleStoreTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/10/26.
//

import Foundation
import Testing
@testable import ResourceRunner

/// 10분 × 1·2·5초의 600·300·120 용량, 나누어떨어지지 않는 주기의 올림, 결과 하한을 검증합니다.
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
}

// MARK: - 테스트용 샘플 조립

/// 전체 사용률만 의미 있게 두고 나머지는 이력 링과 무관한 자리를 채우는 CPU 지표.
private func cpuMetrics(overallUsage: Double) -> CPUSystemMetrics {
    CPUSystemMetrics(
        overallUsage: overallUsage,
        userRatio: overallUsage,
        systemRatio: 0,
        idleRatio: 100 - overallUsage,
        coreUsages: [overallUsage],
        loadAverage: LoadAverage(oneMinute: 0, fiveMinutes: 0, fifteenMinutes: 0)
    )
}

/// Swap 사용 바이트만 의미 있게 두는 Memory 지표.
private func memoryMetrics(swapUsedBytes: UInt64) -> MemorySystemMetrics {
    MemorySystemMetrics(
        totalPhysicalBytes: 16 * 1024 * 1024 * 1024,
        usedBytes: 8 * 1024 * 1024 * 1024,
        appBytes: 4 * 1024 * 1024 * 1024,
        wiredBytes: 2 * 1024 * 1024 * 1024,
        compressedBytes: 2 * 1024 * 1024 * 1024,
        cachedBytes: 1024 * 1024 * 1024,
        swapUsedBytes: swapUsedBytes,
        pressureLevel: .normal
    )
}

/// 두 지표가 모두 성공한 tick. `cpuUsage`가 `nil`이면 값 없이 기준점만 갱신한 tick입니다.
private func sample(
    at timestamp: ContinuousClock.Instant,
    cpuUsage: Double?,
    swapUsedBytes: UInt64 = 0
) -> TimestampedSample<SystemMetricsSample> {
    TimestampedSample(
        timestamp: timestamp,
        value: SystemMetricsSample(
            cpu: .success(cpuUsage.map(cpuMetrics(overallUsage:))),
            memory: .success(memoryMetrics(swapUsedBytes: swapUsedBytes))
        )
    )
}

private let cpuFailure = CollectorFailure(metric: .cpu, cause: .systemCall(name: "host_processor_info", code: 5))
private let memoryFailure = CollectorFailure(metric: .memory, cause: .systemCall(name: "host_statistics64", code: 5))

/// 값을 만들지 않는 최소 시스템 지표 source.
/// 주기 변경(`apply(_:)`)이 저장소의 이력에 손대지 않는지만 관찰하므로 샘플을 공급할 필요가 없습니다.
nonisolated private struct SilentSystemMetricsSampleSource: ScheduledSampleSource {
    func sample() async throws -> SystemMetricsSample {
        throw CancellationError()
    }
}

// MARK: - MonitoringSampleStore

/// task-002 검증 조건: 주기 변경에서의 이력 보존, 값 없는 tick의 링 미추가, 10분 창 선별,
/// 용량 초과 시 가장 오래된 항목만 교체, 긴 중지 뒤 표시용 값이 빈 목록이 되는 것,
/// stream이 최신 조합 하나만 보존하는 것을 검증합니다.
struct MonitoringSampleStoreTests {

    /// 이 테스트가 고정하는 것은 M1의 resize 회귀입니다 —
    /// 1초 주기로 이력을 채운 뒤 주기를 2초·5초로 바꿔도 저장된 값 배열 전체가 그대로여야 합니다.
    /// 용량을 유효 주기로 재계산하도록 되돌리면(2초 -> 300, 5초 -> 120) 400개 중 일부가 사라져 이 테스트가 실패합니다.
    @Test func historySurvivesSamplingIntervalChanges() async {
        let store = MonitoringSampleStore()
        let clock = ManualMonotonicClock()
        let scheduler = MonitoringScheduler(
            clock: clock,
            source: SilentSystemMetricsSampleSource(),
            sink: store
        )
        let base = ContinuousClock().now

        // 1초 주기로 400개를 채웁니다. 용량 600(10분 / 1초)이라 아직 축출은 일어나지 않습니다.
        for index in 0..<400 {
            await store.append(sample(at: base.advanced(by: .seconds(index)), cpuUsage: Double(index % 100)))
        }
        let beforeChange = await store.snapshot().recentHistory
        #expect(beforeChange.count == 400)

        // 팝오버 닫힘·저전력 모드에 해당하는 주기 변경을 실제 `apply(_:)` 경로로 통과시킵니다.
        await scheduler.apply(.running(.seconds(2)))
        await scheduler.apply(.running(.seconds(5)))
        await scheduler.apply(.paused)

        let afterChange = await store.snapshot().recentHistory
        #expect(afterChange == beforeChange)
    }

    /// 전체 CPU 사용률과 Swap 값이 모두 있는 tick만 링에 들어가고, 그렇지 않은 tick의 시각은 이력에서 비어 있습니다.
    /// 최신 스냅샷은 그런 tick에서도 교체됩니다.
    @Test func onlyTicksWithBothCPUUsageAndSwapEnterHistory() async {
        let store = MonitoringSampleStore()
        let base = ContinuousClock().now

        await store.append(sample(at: base, cpuUsage: 10, swapUsedBytes: 100))
        // 값 없이 기준점만 갱신한 tick
        await store.append(sample(at: base.advanced(by: .seconds(1)), cpuUsage: nil))
        // CPU 조회 실패
        await store.append(TimestampedSample(
            timestamp: base.advanced(by: .seconds(2)),
            value: SystemMetricsSample(cpu: .failure(cpuFailure), memory: .success(memoryMetrics(swapUsedBytes: 100)))
        ))
        // Memory 조회 실패 -> Swap 값이 없으므로 이력 항목을 만들 수 없습니다.
        await store.append(TimestampedSample(
            timestamp: base.advanced(by: .seconds(3)),
            value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 20)), memory: .failure(memoryFailure))
        ))
        await store.append(sample(at: base.advanced(by: .seconds(4)), cpuUsage: 30, swapUsedBytes: 300))

        let displayValue = await store.snapshot()

        #expect(displayValue.recentHistory.map(\.overallCPUUsage) == [10, 30])
        #expect(displayValue.recentHistory.map(\.swapUsedBytes) == [100, 300])
        // 값이 빠진 세 tick의 시각은 이력에 없습니다.
        #expect(displayValue.recentHistory.map(\.timestamp) == [base, base.advanced(by: .seconds(4))])
        // 최신 스냅샷은 매 tick 교체되므로 마지막 tick을 담고 있습니다.
        #expect(displayValue.latest?.timestamp == base.advanced(by: .seconds(4)))
    }

    /// 최신 스냅샷은 이력에 들어가지 못한 tick으로도 교체되고, 코어별 사용률처럼 현재값만 필요한 지표를 담습니다.
    @Test func latestSnapshotIsReplacedEvenByTicksWithoutHistoryEntry() async throws {
        let store = MonitoringSampleStore()
        let base = ContinuousClock().now

        await store.append(sample(at: base, cpuUsage: 10))
        await store.append(TimestampedSample(
            timestamp: base.advanced(by: .seconds(1)),
            value: SystemMetricsSample(cpu: .failure(cpuFailure), memory: .success(memoryMetrics(swapUsedBytes: 0)))
        ))

        let displayValue = await store.snapshot()

        #expect(displayValue.latest?.timestamp == base.advanced(by: .seconds(1)))
        #expect(displayValue.latest?.value.cpu == .failure(cpuFailure))
        // 실패한 tick이 직전 성공값을 이력에 한 번 더 넣지 않습니다.
        #expect(displayValue.recentHistory.count == 1)
        // 이력 링에 담지 않는 현재값 지표(Memory 세부 구성)는 최신 스냅샷 쪽에 그대로 남습니다.
        #expect(try displayValue.latest?.value.memory.get().appBytes == 4 * 1024 * 1024 * 1024)
    }

    /// 표시용 값은 최신 샘플 시각에서 10분을 뺀 시점 이후의 항목만 담습니다.
    /// 창 경계 직전 항목은 빠지고 경계 항목과 그 이후 항목은 남습니다.
    @Test func displayValueSelectsOnlyTheTenMinuteWindowFromLatestSampleTime() async {
        let store = MonitoringSampleStore()
        let latestInstant = ContinuousClock().now
        // 링 용량은 600이므로 아래 네 항목은 개수로는 축출되지 않습니다. 창 선별만 관찰합니다.
        let outsideWindow = latestInstant.advanced(by: .seconds(-601))
        let onWindowBoundary = latestInstant.advanced(by: .seconds(-600))
        let insideWindow = latestInstant.advanced(by: .seconds(-599))

        await store.append(sample(at: outsideWindow, cpuUsage: 1))
        await store.append(sample(at: onWindowBoundary, cpuUsage: 2))
        await store.append(sample(at: insideWindow, cpuUsage: 3))
        await store.append(sample(at: latestInstant, cpuUsage: 4))

        let displayValue = await store.snapshot()

        #expect(displayValue.recentHistory.map(\.overallCPUUsage) == [2, 3, 4])
    }

    /// 링 용량(10분 / 1초 = 600)을 넘으면 가장 오래된 항목 하나만 교체됩니다.
    /// 개수 축출만 관찰하려면 601개가 모두 10분 창 안에 있어야 하므로 0.5초 간격으로 채웁니다.
    @Test func exceedingCapacityReplacesOnlyTheOldestEntry() async {
        let store = MonitoringSampleStore()
        let base = ContinuousClock().now

        for index in 0...600 {
            await store.append(
                sample(at: base.advanced(by: .milliseconds(500 * index)), cpuUsage: Double(index % 100), swapUsedBytes: UInt64(index))
            )
        }

        let history = await store.snapshot().recentHistory

        #expect(history.count == 600)
        // 첫 항목(swap 0)만 밀려나고 두 번째 항목부터 순서대로 남습니다.
        #expect(history.first?.swapUsedBytes == 1)
        #expect(history.last?.swapUsedBytes == 600)
    }

    /// 1시간 중지를 시각으로 재현합니다.
    /// 재개 첫 tick은 간격이 허용 범위를 넘어 값 없이 기준점만 갱신하므로 링에 들어가지 않고,
    /// 중지 전 항목은 링에 남아 있어도 최신 샘플 시각 기준 10분 창 밖이라 표시용 값에서 빠집니다.
    @Test func displayValueIsEmptyAfterAnHourLongStop() async {
        let store = MonitoringSampleStore()
        let base = ContinuousClock().now

        for index in 0..<10 {
            await store.append(sample(at: base.advanced(by: .seconds(index)), cpuUsage: Double(index)))
        }
        #expect(await store.snapshot().recentHistory.count == 10)

        let resumeInstant = base.advanced(by: .seconds(3600))
        await store.append(sample(at: resumeInstant, cpuUsage: nil))

        let displayValue = await store.snapshot()

        #expect(displayValue.recentHistory.isEmpty)
        #expect(displayValue.latest?.timestamp == resumeInstant)
    }

    @Test func emptyStoreHasNoLatestSnapshotAndNoHistory() async {
        let store = MonitoringSampleStore()

        let displayValue = await store.snapshot()

        #expect(displayValue.latest == nil)
        #expect(displayValue.recentHistory.isEmpty)
    }

    /// stream은 최신 조합 하나만 보존하므로 소비가 밀려도 오래된 조합이 쌓이지 않습니다.
    /// 세 tick을 먼저 넣은 뒤 처음 받는 값이 마지막 tick의 조합이어야 합니다.
    @Test func displayValueStreamKeepsOnlyTheNewestCombination() async {
        let store = MonitoringSampleStore()
        let base = ContinuousClock().now
        var iterator = store.displayValues.makeAsyncIterator()

        await store.append(sample(at: base, cpuUsage: 10))
        await store.append(sample(at: base.advanced(by: .seconds(1)), cpuUsage: 20))
        await store.append(sample(at: base.advanced(by: .seconds(2)), cpuUsage: 30))

        let received = await iterator.next()

        #expect(received?.latest?.timestamp == base.advanced(by: .seconds(2)))
        #expect(received?.recentHistory.map(\.overallCPUUsage) == [10, 20, 30])
    }
}
