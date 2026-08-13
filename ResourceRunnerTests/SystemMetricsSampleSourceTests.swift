//
//  SystemMetricsSampleSourceTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/13/26.
//

import Foundation
import Testing
@testable import ResourceRunner

// MARK: - 테스트용 Collector와 시계

/// `CPUSystemMetricsCollecting`이 값 타입 계약이라 source가 복사본을 소유하므로,
/// 호출 기록과 남은 결과는 이 참조 상자에 두어 테스트에서 관찰합니다.
private final class CPUCollectorRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var outcomes: [Result<CPUSystemMetrics?, CollectorFailure>]
    private var observedTimestamps: [ContinuousClock.Instant] = []

    init(outcomes: [Result<CPUSystemMetrics?, CollectorFailure>]) {
        self.outcomes = outcomes
    }

    var timestamps: [ContinuousClock.Instant] {
        lock.lock()
        defer { lock.unlock() }
        return observedTimestamps
    }

    func collect(at timestamp: ContinuousClock.Instant) throws(CollectorFailure) -> CPUSystemMetrics? {
        lock.lock()
        observedTimestamps.append(timestamp)
        let outcome = outcomes.isEmpty ? nil : outcomes.removeFirst()
        lock.unlock()

        switch outcome {
        case .success(let metrics):
            return metrics
        case .failure(let failure):
            throw failure
        case nil:
            return nil
        }
    }
}

private struct FakeCPUCollector: CPUSystemMetricsCollecting {
    let recorder: CPUCollectorRecorder

    mutating func collect(at timestamp: ContinuousClock.Instant) throws(CollectorFailure) -> CPUSystemMetrics? {
        try recorder.collect(at: timestamp)
    }
}

private final class FakeMemoryCollector: MemorySystemMetricsCollecting, @unchecked Sendable {
    private let lock = NSLock()
    private var outcomes: [Result<MemorySystemMetrics, CollectorFailure>]

    init(outcomes: [Result<MemorySystemMetrics, CollectorFailure>]) {
        self.outcomes = outcomes
    }

    func collect() throws(CollectorFailure) -> MemorySystemMetrics {
        lock.lock()
        let outcome = outcomes.isEmpty ? nil : outcomes.removeFirst()
        lock.unlock()

        switch outcome {
        case .success(let metrics):
            return metrics
        case .failure(let failure):
            throw failure
        case nil:
            throw CollectorFailure(metric: .memory, cause: .systemCall(name: "fake.exhausted", code: -1))
        }
    }
}

/// 전진하지 않는 고정 시각을 돌려주면서 읽은 횟수를 세는 `MonotonicClock`.
/// 한 tick이 시각을 몇 번 읽는지 관찰하는 데 씁니다.
private actor RecordingMonotonicClock: MonotonicClock {
    private let instant: ContinuousClock.Instant

    /// 한 tick이 시각을 한 번만 읽는지 세기 위한 진단용 카운터입니다.
    private(set) var nowCallCount = 0

    init(instant: ContinuousClock.Instant) {
        self.instant = instant
    }

    func now() -> ContinuousClock.Instant {
        nowCallCount += 1
        return instant
    }

    func sleep(until deadline: ContinuousClock.Instant) async throws {
        try Task.checkCancellation()
    }
}

private let cpuFixture = CPUSystemMetrics(
    overallUsage: 42,
    userRatio: 30,
    systemRatio: 12,
    idleRatio: 58,
    coreUsages: [40, 44],
    loadAverage: LoadAverage(oneMinute: 1, fiveMinutes: 2, fifteenMinutes: 3)
)

private let memoryFixture = MemorySystemMetrics(
    totalPhysicalBytes: 16 * 1024 * 1024 * 1024,
    usedBytes: 8 * 1024 * 1024 * 1024,
    appBytes: 4 * 1024 * 1024 * 1024,
    wiredBytes: 3 * 1024 * 1024 * 1024,
    compressedBytes: 1024 * 1024 * 1024,
    cachedBytes: 2 * 1024 * 1024 * 1024,
    swapUsedBytes: 512 * 1024 * 1024,
    pressureLevel: .warning
)

private let cpuFailure = CollectorFailure(metric: .cpu, cause: .systemCall(name: "host_processor_info", code: 5))
private let memoryFailure = CollectorFailure(metric: .memory, cause: .systemCall(name: "host_statistics64", code: 5))

private func makeSource(
    cpuOutcomes: [Result<CPUSystemMetrics?, CollectorFailure>],
    memoryOutcomes: [Result<MemorySystemMetrics, CollectorFailure>],
    clock: RecordingMonotonicClock = RecordingMonotonicClock(instant: ContinuousClock().now)
) -> (
    source: SystemMetricsSampleSource<FakeCPUCollector, FakeMemoryCollector, RecordingMonotonicClock>,
    cpuRecorder: CPUCollectorRecorder,
    clock: RecordingMonotonicClock
) {
    let recorder = CPUCollectorRecorder(outcomes: cpuOutcomes)
    let source = SystemMetricsSampleSource(
        cpuCollector: FakeCPUCollector(recorder: recorder),
        memoryCollector: FakeMemoryCollector(outcomes: memoryOutcomes),
        clock: clock
    )
    return (source, recorder, clock)
}

// MARK: - 지표별 실패 격리

/// task-001 검증 조건: 한 지표의 조회 실패가 같은 tick의 다른 지표 값을 함께 없애지 않고,
/// 실패한 지표가 0이나 빈 값으로 바뀌지 않으며, 두 지표가 하나의 샘플 시각을 공유하는지 검증합니다.
struct SystemMetricsSampleSourceTests {

    /// 이 테스트가 고정하는 것은 "한 지표의 실패가 같은 tick의 다른 지표 값을 함께 없애지 않는다"입니다.
    /// source가 실패를 던지도록 되돌리면 `sample()`이 값을 돌려주지 못해 이 테스트가 실패합니다.
    @Test func cpuFailureKeepsMemoryValueInTheSameSample() async {
        let (source, _, _) = makeSource(
            cpuOutcomes: [.failure(cpuFailure)],
            memoryOutcomes: [.success(memoryFixture)]
        )

        let sample = await source.sample()

        #expect(sample.cpu == .failure(cpuFailure))
        #expect(sample.memory == .success(memoryFixture))
    }

    @Test func memoryFailureKeepsCPUValueInTheSameSample() async {
        let (source, _, _) = makeSource(
            cpuOutcomes: [.success(cpuFixture)],
            memoryOutcomes: [.failure(memoryFailure)]
        )

        let sample = await source.sample()

        #expect(sample.cpu == .success(cpuFixture))
        #expect(sample.memory == .failure(memoryFailure))
    }

    /// 두 지표가 모두 실패해도 샘플 자체는 만들어지고, 실패가 0 값으로 바뀌지 않습니다.
    @Test func bothFailuresAreCarriedAsFailuresWithoutThrowing() async {
        let (source, _, _) = makeSource(
            cpuOutcomes: [.failure(cpuFailure)],
            memoryOutcomes: [.failure(memoryFailure)]
        )

        let sample = await source.sample()

        #expect(sample.cpu == .failure(cpuFailure))
        #expect(sample.memory == .failure(memoryFailure))
    }

    /// 값을 만들지 않은 CPU tick(첫 tick·허용 배수 초과)은 실패와 구분되고,
    /// 같은 tick의 Memory 값은 그대로 담깁니다.
    @Test func baselineOnlyCPUTickIsNotAFailure() async {
        let (source, _, _) = makeSource(
            cpuOutcomes: [.success(nil), .success(cpuFixture)],
            memoryOutcomes: [.success(memoryFixture), .success(memoryFixture)]
        )

        let first = await source.sample()
        let second = await source.sample()

        #expect(first.cpu == .success(nil))
        #expect(first.memory == .success(memoryFixture))
        #expect(second.cpu == .success(cpuFixture))
    }

    /// 두 지표가 하나의 샘플 시각을 공유하는지 고정합니다 —
    /// 한 tick에서 시각은 한 번만 읽히고 그 값이 CPU 차분의 기준으로 전달됩니다.
    @Test func oneTickReadsTheTimestampOnceAndSharesIt() async {
        let instant = ContinuousClock().now
        let clock = RecordingMonotonicClock(instant: instant)
        let (source, recorder, _) = makeSource(
            cpuOutcomes: [.success(cpuFixture)],
            memoryOutcomes: [.success(memoryFixture)],
            clock: clock
        )

        _ = await source.sample()

        #expect(await clock.nowCallCount == 1)
        #expect(recorder.timestamps == [instant])
    }
}
