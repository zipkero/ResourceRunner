//
//  SystemMetricsCollectorTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/13/26.
//

import Foundation
import Testing
@testable import ResourceRunner

// MARK: - 테스트용 tick 원본 공급자

/// 미리 준비한 tick 원본을 순서대로 돌려주는 `CPUTickReading`.
/// 원본이 바닥나면 실패로 처리해 조회 실패 경로도 같은 stub으로 검증할 수 있습니다.
private final class StubCPUTickReader: CPUTickReading, @unchecked Sendable {
    static let exhaustedFailure = CollectorFailure(
        metric: .cpu,
        cause: .systemCall(name: "stub.readCoreTicks", code: -1)
    )

    private let lock = NSLock()
    private var tickOutcomes: [Result<[CPUCoreTicks], CollectorFailure>]
    private let loadAverage: LoadAverage
    private var observedLoadAverageCallCount = 0

    init(
        tickOutcomes: [Result<[CPUCoreTicks], CollectorFailure>],
        loadAverage: LoadAverage = LoadAverage(oneMinute: 1.5, fiveMinutes: 2.5, fifteenMinutes: 3.5)
    ) {
        self.tickOutcomes = tickOutcomes
        self.loadAverage = loadAverage
    }

    /// 값을 만들지 못하는 tick에서 Load Average를 읽지 않는지 세기 위한 진단용 카운터입니다.
    var loadAverageCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return observedLoadAverageCallCount
    }

    func readCoreTicks() throws(CollectorFailure) -> [CPUCoreTicks] {
        lock.lock()
        let outcome = tickOutcomes.isEmpty ? nil : tickOutcomes.removeFirst()
        lock.unlock()

        switch outcome {
        case .success(let ticks):
            return ticks
        case .failure(let failure):
            throw failure
        case nil:
            throw Self.exhaustedFailure
        }
    }

    func readLoadAverage() throws(CollectorFailure) -> LoadAverage {
        lock.lock()
        observedLoadAverageCallCount += 1
        lock.unlock()
        return loadAverage
    }
}

/// 코어 하나의 tick 원본을 짧게 쓰기 위한 helper.
private func ticks(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64 = 0) -> CPUCoreTicks {
    CPUCoreTicks(user: user, system: system, idle: idle, nice: nice)
}

private let baseInstant = ContinuousClock().now

// MARK: - CPU 차분 계산

/// task-001 검증 조건: 첫 tick의 값 부재, 정상 간격의 사용률 산출, 허용 배수 초과 간격의 기준점 전용 갱신,
/// 코어별 값과 전체 값의 관계, User·System·Idle 합을 tick 원본과 시각 주입으로 검증합니다.
struct CPUSystemMetricsCollectorTests {

    @Test func firstTickProducesNoUsage() throws {
        let reader = StubCPUTickReader(tickOutcomes: [.success([ticks(user: 10, system: 10, idle: 80)])])
        var collector = CPUSystemMetricsCollector(reader: reader)

        let metrics = try collector.collect(at: baseInstant)

        #expect(metrics == nil)
        // 값을 만들지 않는 tick에서는 Load Average도 읽지 않습니다.
        #expect(reader.loadAverageCallCount == 0)
    }

    @Test func secondTickProducesUsageFromTickDelta() throws {
        let reader = StubCPUTickReader(tickOutcomes: [
            .success([ticks(user: 0, system: 0, idle: 0), ticks(user: 0, system: 0, idle: 0)]),
            .success([ticks(user: 10, system: 10, idle: 80), ticks(user: 0, system: 0, idle: 100)]),
        ])
        var collector = CPUSystemMetricsCollector(reader: reader)

        #expect(try collector.collect(at: baseInstant) == nil)
        let metrics = try #require(try collector.collect(at: baseInstant.advanced(by: .seconds(1))))

        // 코어0은 200 tick 중 20을 소비, 코어1은 전부 idle입니다.
        #expect(metrics.coreUsages == [20, 0])
        #expect(metrics.overallUsage == 10)
        #expect(metrics.userRatio == 5)
        #expect(metrics.systemRatio == 5)
        #expect(metrics.idleRatio == 90)
        #expect(metrics.loadAverage == LoadAverage(oneMinute: 1.5, fiveMinutes: 2.5, fifteenMinutes: 3.5))
    }

    /// 전체 사용률이 코어별 tick 합에서 나오는지 고정합니다.
    /// 코어별 사용률의 단순 평균이 아니라 tick 합이라 코어마다 진행량이 다를 때 값이 갈립니다.
    @Test func overallUsageComesFromSummedTicksNotCoreAverage() throws {
        let reader = StubCPUTickReader(tickOutcomes: [
            .success([ticks(user: 0, system: 0, idle: 0), ticks(user: 0, system: 0, idle: 0)]),
            // 코어0은 100 tick 전부 사용, 코어1은 300 tick 전부 idle입니다.
            .success([ticks(user: 100, system: 0, idle: 0), ticks(user: 0, system: 0, idle: 300)]),
        ])
        var collector = CPUSystemMetricsCollector(reader: reader)

        _ = try collector.collect(at: baseInstant)
        let metrics = try #require(try collector.collect(at: baseInstant.advanced(by: .seconds(1))))

        #expect(metrics.coreUsages == [100, 0])
        // 코어별 평균이면 50%이지만 tick 합 기준은 100 / 400 = 25%입니다.
        #expect(metrics.overallUsage == 25)
    }

    /// nice tick을 User에 포함시키는지 고정합니다. 따로 두면 User·System·Idle의 합이 100%에 못 미칩니다.
    @Test func niceTicksCountAsUserTime() throws {
        let reader = StubCPUTickReader(tickOutcomes: [
            .success([ticks(user: 0, system: 0, idle: 0, nice: 0)]),
            .success([ticks(user: 10, system: 0, idle: 80, nice: 10)]),
        ])
        var collector = CPUSystemMetricsCollector(reader: reader)

        _ = try collector.collect(at: baseInstant)
        let metrics = try #require(try collector.collect(at: baseInstant.advanced(by: .seconds(1))))

        #expect(metrics.userRatio == 20)
        #expect(metrics.idleRatio == 80)
        #expect(metrics.userRatio + metrics.systemRatio + metrics.idleRatio == 100)
    }

    @Test(arguments: [
        [ticks(user: 25, system: 25, idle: 50)],
        [ticks(user: 100, system: 0, idle: 0)],
        [ticks(user: 0, system: 0, idle: 100)],
        [ticks(user: 33, system: 33, idle: 34)],
        [ticks(user: 1, system: 2, idle: 3), ticks(user: 4, system: 5, idle: 6)],
    ])
    func ratiosStayInRangeAndSumToOneHundred(secondTick: [CPUCoreTicks]) throws {
        let zeroed = [CPUCoreTicks](repeating: ticks(user: 0, system: 0, idle: 0), count: secondTick.count)
        let reader = StubCPUTickReader(tickOutcomes: [.success(zeroed), .success(secondTick)])
        var collector = CPUSystemMetricsCollector(reader: reader)

        _ = try collector.collect(at: baseInstant)
        let metrics = try #require(try collector.collect(at: baseInstant.advanced(by: .seconds(1))))

        #expect(metrics.coreUsages.count == secondTick.count)
        for usage in metrics.coreUsages {
            #expect(usage >= 0 && usage <= 100)
        }
        #expect(metrics.overallUsage >= 0 && metrics.overallUsage <= 100)
        let sum = metrics.userRatio + metrics.systemRatio + metrics.idleRatio
        #expect(abs(sum - 100) < 0.000_001)
        #expect(abs(metrics.overallUsage - (100 - metrics.idleRatio)) < 0.000_001)
    }

    /// 이 단언이 고정하는 것은 "허용 배수를 넘은 간격을 하나의 변화량으로 이어 붙이지 않는다"입니다.
    /// 초과 tick이 값을 만들지 않으면서 기준점은 갱신하므로, 그 다음 정상 간격 tick의 값이
    /// 초과 tick을 기준으로 계산됩니다.
    @Test func gapBeyondMaximumRefreshesBaselineWithoutProducingUsage() throws {
        let reader = StubCPUTickReader(tickOutcomes: [
            .success([ticks(user: 0, system: 0, idle: 0)]),
            .success([ticks(user: 500, system: 0, idle: 500)]),
            .success([ticks(user: 510, system: 0, idle: 590)]),
        ])
        var collector = CPUSystemMetricsCollector(reader: reader)

        _ = try collector.collect(at: baseInstant)
        let afterGap = try collector.collect(at: baseInstant.advanced(by: .seconds(11)))
        #expect(afterGap == nil)
        #expect(reader.loadAverageCallCount == 0)

        let metrics = try #require(try collector.collect(at: baseInstant.advanced(by: .seconds(12))))

        // 첫 기준점(0 tick)이 아니라 초과 tick을 기준으로 10 / 100 = 10%가 나옵니다.
        #expect(metrics.overallUsage == 10)
    }

    @Test func gapExactlyAtMaximumStillProducesUsage() throws {
        let reader = StubCPUTickReader(tickOutcomes: [
            .success([ticks(user: 0, system: 0, idle: 0)]),
            .success([ticks(user: 10, system: 0, idle: 90)]),
        ])
        var collector = CPUSystemMetricsCollector(reader: reader)

        _ = try collector.collect(at: baseInstant)
        let metrics = try collector.collect(at: baseInstant.advanced(by: SystemMetricsSampling.maximumTickGap))

        #expect(metrics?.overallUsage == 10)
    }

    /// 논리 코어 수가 바뀐 tick은 직전 원본과 대응시킬 수 없으므로 기준점만 갱신합니다.
    @Test func coreCountChangeRefreshesBaselineWithoutProducingUsage() throws {
        let reader = StubCPUTickReader(tickOutcomes: [
            .success([ticks(user: 0, system: 0, idle: 0), ticks(user: 0, system: 0, idle: 0)]),
            .success([ticks(user: 10, system: 0, idle: 90)]),
        ])
        var collector = CPUSystemMetricsCollector(reader: reader)

        _ = try collector.collect(at: baseInstant)

        #expect(try collector.collect(at: baseInstant.advanced(by: .seconds(1))) == nil)
    }

    @Test func rewoundCounterRefreshesBaselineWithoutProducingUsage() throws {
        let reader = StubCPUTickReader(tickOutcomes: [
            .success([ticks(user: 100, system: 100, idle: 100)]),
            .success([ticks(user: 10, system: 10, idle: 10)]),
        ])
        var collector = CPUSystemMetricsCollector(reader: reader)

        _ = try collector.collect(at: baseInstant)

        #expect(try collector.collect(at: baseInstant.advanced(by: .seconds(1))) == nil)
    }

    @Test func tickReadFailureIsThrownAsCPUCollectorFailure() throws {
        let failure = CollectorFailure(metric: .cpu, cause: .systemCall(name: "host_processor_info", code: 5))
        let reader = StubCPUTickReader(tickOutcomes: [.failure(failure)])
        var collector = CPUSystemMetricsCollector(reader: reader)

        #expect(throws: failure) {
            _ = try collector.collect(at: baseInstant)
        }
    }

    @Test func emptyCoreListIsTreatedAsFailure() throws {
        let reader = StubCPUTickReader(tickOutcomes: [.success([])])
        var collector = CPUSystemMetricsCollector(reader: reader)

        #expect(throws: CollectorFailure.self) {
            _ = try collector.collect(at: baseInstant)
        }
    }
}

// MARK: - Memory Pressure 원시값 매핑

/// task-001 검증 조건: 원시값 `0x01`·`0x02`·`0x04`만 세 단계로 해석되고 그 밖의 값은 실패임을 전수 검증합니다.
struct MemoryPressureLevelTests {

    @Test(arguments: [
        (Int32(0x01), MemoryPressureLevel.normal),
        (Int32(0x02), MemoryPressureLevel.warning),
        (Int32(0x04), MemoryPressureLevel.critical),
    ])
    func documentedRawValuesMapToLevels(rawValue: Int32, expected: MemoryPressureLevel) {
        #expect(MemoryPressureLevel(rawValue: rawValue) == expected)
    }

    @Test(arguments: [Int32(0x00), 0x03, 0x05, 0x06, 0x07, 0x08, 0x10, -1, .max, .min])
    func otherRawValuesAreNotInterpreted(rawValue: Int32) {
        #expect(MemoryPressureLevel(rawValue: rawValue) == nil)
    }
}

// MARK: - 실제 시스템 호출 경로

/// task-001 검증 조건 중 실기기 확인: macOS 26.5 Apple silicon에서 연속 두 tick을 수집해
/// 코어 수 일치와 값 범위를, Memory 순간값 조회의 첫 tick 값과 상한을 단언합니다.
struct SystemMetricsRealDevicePathTests {

    @Test func twoConsecutiveRealTicksProduceCoreUsagesForEveryLogicalCore() async throws {
        var collector = CPUSystemMetricsCollector(reader: HostCPUTickReader())

        #expect(try collector.collect(at: ContinuousClock().now) == nil)
        // tick 해상도(10ms) 위에서 코어별 차이가 실제로 쌓이도록 충분히 기다립니다.
        try await Task.sleep(for: .milliseconds(300))
        let metrics = try #require(try collector.collect(at: ContinuousClock().now))

        #expect(metrics.coreUsages.count == ProcessInfo.processInfo.activeProcessorCount)
        for usage in metrics.coreUsages {
            #expect(usage >= 0 && usage <= 100)
        }
        #expect(metrics.overallUsage >= 0 && metrics.overallUsage <= 100)
        #expect(abs(metrics.userRatio + metrics.systemRatio + metrics.idleRatio - 100) < 0.000_001)
        #expect(metrics.loadAverage.oneMinute >= 0)
    }

    @Test func realMemoryCollectProducesValueOnFirstTick() throws {
        let collector = MemorySystemMetricsCollector()

        let metrics = try collector.collect()

        #expect(metrics.totalPhysicalBytes == ProcessInfo.processInfo.physicalMemory)
        #expect(metrics.totalPhysicalBytes > 0)
        #expect(metrics.usedBytes > 0)
        #expect(metrics.usedBytes <= metrics.totalPhysicalBytes)
        #expect(metrics.usedBytes == metrics.appBytes + metrics.wiredBytes + metrics.compressedBytes)
        #expect(metrics.wiredBytes > 0)
    }
}
