//
//  ApplicationCoordinatorTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/11/26.
//

import Foundation
import Testing
@testable import ResourceRunner

/// 다른 테스트 파일들과 같은 폴링 helper. actor 상태가 갱신될 때까지 협력적으로 기다립니다.
private func waitUntil(maxIterations: Int = 10_000, _ condition: () async -> Bool) async {
    var iterations = 0
    while await !condition() && iterations < maxIterations {
        await Task.yield()
        iterations += 1
    }
}

/// `MemorySystemLifecycleSource`를 감싸는 최소 이중, 이후 update를 전혀 보내지 않는 소스를 만드는 데 씁니다.
/// `startMonitoring`이 stream 소비를 initial·popoverPresented 적용보다 먼저 시작하도록 순서가 바뀌면,
/// update가 하나도 오지 않는 이 소스로는 for-await가 영원히 suspend되어 초기 적용이 전혀 일어나지 않으므로
/// 이 테스트가 그 mutation을 잡습니다.
@MainActor
struct ApplicationCoordinatorTests {

    /// task-011 검증 조건: 「system initial snapshot과 초기 popoverPresented = false를 적용하기 전에는
    /// Scheduler를 시작하지 않는다」를 뒤집어 확인합니다 — update가 전혀 없어도 initial 적용만으로
    /// Scheduler가 시작(첫 apply)되어야 합니다.
    @Test func startMonitoringAppliesInitialSnapshotWithoutAnyFurtherStreamUpdate() async {
        let clock = ManualMonotonicClock()
        let sink = MemorySampleSink<Int>()
        let source = MemoryScheduledSampleSource(outcomes: [])
        let scheduler = MonitoringScheduler(clock: clock, source: source, sink: sink)
        let processScheduler = MonitoringScheduler(
            clock: clock,
            source: MemoryScheduledSampleSource(outcomes: []),
            sink: MemorySampleSink<Int>()
        )
        let store = MonitoringLifecycleStore(
            definition: .m2,
            systemMetricsTarget: scheduler,
            processSurveyTarget: processScheduler
        )

        // 이후 어떤 send도 호출하지 않는 순수 initial-only 소스입니다.
        let lifecycleSource = MemorySystemLifecycleSource(initialLowPowerMode: false, initialScreenLockState: .unlocked)

        let task = ApplicationCoordinator.startMonitoring(lifecycleSource, into: store)

        await waitUntil { await scheduler.applyCallCount >= 1 }

        // unlocked·normal·popoverPresented(false) -> 닫힘 2초로 시작. 정확히 한 번만 적용됩니다.
        #expect(await scheduler.applyCallCount == 1)

        task.cancel()
    }

    /// initial이 이미 paused(잠금)인 경우에도 Scheduler가 "시작"(첫 apply)되어야 하며,
    /// 이후 도착하는 update가 초기 적용 위에 순서대로 반영되는지 함께 확인합니다.
    @Test func startMonitoringAppliesInitialThenForwardsSubsequentUpdatesInOrder() async {
        let clock = ManualMonotonicClock()
        let sink = MemorySampleSink<Int>()
        let source = MemoryScheduledSampleSource(outcomes: [])
        let scheduler = MonitoringScheduler(clock: clock, source: source, sink: sink)
        let processScheduler = MonitoringScheduler(
            clock: clock,
            source: MemoryScheduledSampleSource(outcomes: []),
            sink: MemorySampleSink<Int>()
        )
        let store = MonitoringLifecycleStore(
            definition: .m2,
            systemMetricsTarget: scheduler,
            processSurveyTarget: processScheduler
        )

        let lifecycleSource = MemorySystemLifecycleSource(initialLowPowerMode: false, initialScreenLockState: .locked)

        let task = ApplicationCoordinator.startMonitoring(lifecycleSource, into: store)

        await waitUntil { await scheduler.applyCallCount >= 1 }
        #expect(await scheduler.applyCallCount == 1) // locked -> paused로 시작

        lifecycleSource.sendScreenLockState(.unlocked)
        await waitUntil { await scheduler.applyCallCount >= 2 }
        #expect(await scheduler.applyCallCount == 2) // unlocked 복귀 -> normal 닫힘 2초로 재적용

        task.cancel()
    }

    /// task-011 검증 조건: `StatusBarControllerOutput.popoverPresented(_:)`의 실제 전달 로직인
    /// `forwardPopoverPresented`가 `MonitoringLifecycleStore.update(.popoverPresented(_:))`를 호출해
    /// 일정이 실제로 바뀌는지 확인합니다.
    @Test func forwardPopoverPresentedChangesAppliedSchedule() async {
        let clock = ManualMonotonicClock()
        let sink = MemorySampleSink<Int>()
        let source = MemoryScheduledSampleSource(outcomes: [])
        let scheduler = MonitoringScheduler(clock: clock, source: source, sink: sink)
        let processScheduler = MonitoringScheduler(
            clock: clock,
            source: MemoryScheduledSampleSource(outcomes: []),
            sink: MemorySampleSink<Int>()
        )
        let store = MonitoringLifecycleStore(
            definition: .m2,
            systemMetricsTarget: scheduler,
            processSurveyTarget: processScheduler
        )

        await store.update(.systemSnapshot(SystemLifecycleSnapshot(
            revision: 0,
            lowPowerMode: false,
            screenLockState: .unlocked,
            displayAsleep: false,
            sessionActive: true
        )))
        #expect(await scheduler.applyCallCount == 1) // normal 닫힘 2초로 시작

        await ApplicationCoordinator.forwardPopoverPresented(true, to: store)

        #expect(await scheduler.applyCallCount == 2) // 팝오버 열림 -> normal 열림 1초로 재적용
    }

    // MARK: - consumeSystemMetrics 배선

    /// task-007 검증 조건: CPU 지표가 실패했거나(`.failure`) 값을 만들지 못한 tick(`.success(nil)`)에서는
    /// 판정 자체를 건너뛰어 `CharacterStateSource.send(_:)`가 한 번도 호출되지 않아야 합니다.
    /// 이 결정은 `CPUActivityStateEvaluator`가 아니라 `ApplicationCoordinator.consumeSystemMetrics(_:into:)`의
    /// `guard`가 소유하므로, 순수 함수 테스트가 아니라 실제 스토어·source 배선으로 확인합니다.
    @Test func failedOrValuelessCPUTicksNeverTriggerCharacterStateSourceSend() async {
        let store = MonitoringSampleStore()
        let characterStateSource = CharacterStateSource()
        let consumeTask = ApplicationCoordinator.consumeSystemMetrics(store, into: characterStateSource, dashboard: DashboardPresentationStore())

        var received: [CharacterActivityState] = []
        let collectTask = Task { @MainActor in
            for await state in characterStateSource.updates {
                received.append(state)
            }
        }

        let base = ContinuousClock().now
        await store.append(cpuFailureSample(at: base))
        for _ in 0..<50 { await Task.yield() }
        await store.append(cpuValuelessSample(at: base.advanced(by: .seconds(1))))
        for _ in 0..<50 { await Task.yield() }
        await store.append(cpuFailureSample(at: base.advanced(by: .seconds(2))))
        // 관찰할 count 조건이 없는(아무 것도 오지 않아야 하는) 구간이므로 다른 테스트들처럼 고정 횟수만큼 기다립니다.
        for _ in 0..<200 { await Task.yield() }

        #expect(received.isEmpty)

        consumeTask.cancel()
        collectTask.cancel()
    }

    /// task-007 검증 조건: 상태가 실제로 바뀌었을 때만 `CharacterStateSource.send(_:)`가 호출되어야 합니다.
    /// 같은 밴드를 여러 tick 유지해도 승격 시점 한 번만 전달되는지, 실패·값 없는 tick을 사이에 끼워도
    /// 배선이 깨지지 않는지를 함께 확인합니다.
    @Test func consumeSystemMetricsSendsOnlyOnActualDisplayedStateChanges() async {
        let store = MonitoringSampleStore()
        let characterStateSource = CharacterStateSource()
        let consumeTask = ApplicationCoordinator.consumeSystemMetrics(store, into: characterStateSource, dashboard: DashboardPresentationStore())

        var received: [CharacterActivityState] = []
        let collectTask = Task { @MainActor in
            for await state in characterStateSource.updates {
                received.append(state)
            }
        }

        let base = ContinuousClock().now

        // 26%를 4초 유지 -> moderate로 승격되는 tick에서만 send가 한 번 옵니다.
        for tick in 0..<3 {
            await store.append(cpuSuccessSample(at: base.advanced(by: .seconds(tick)), overallUsage: 26))
            for _ in 0..<50 { await Task.yield() }
        }
        #expect(received.isEmpty) // 아직 3초 미만이므로 승격 전
        await store.append(cpuSuccessSample(at: base.advanced(by: .seconds(3)), overallUsage: 26))
        await waitUntil { received.count >= 1 }
        #expect(received == [.moderate])

        // 같은 26%를 더 유지해도 이미 moderate이므로 send가 다시 오지 않습니다.
        await store.append(cpuSuccessSample(at: base.advanced(by: .seconds(4)), overallUsage: 26))
        for _ in 0..<50 { await Task.yield() }
        #expect(received == [.moderate])

        // 실패 tick과 값 없는 tick을 사이에 끼워도 배선이 깨지지 않아야 합니다.
        await store.append(cpuFailureSample(at: base.advanced(by: .seconds(5))))
        for _ in 0..<50 { await Task.yield() }
        await store.append(cpuValuelessSample(at: base.advanced(by: .seconds(6))))
        for _ in 0..<50 { await Task.yield() }
        #expect(received == [.moderate])

        // 60%를 4초 유지 -> high로 승격되는 tick에서 send가 한 번 더 옵니다.
        for tick in 7..<10 {
            await store.append(cpuSuccessSample(at: base.advanced(by: .seconds(tick)), overallUsage: 60))
            for _ in 0..<50 { await Task.yield() }
        }
        await store.append(cpuSuccessSample(at: base.advanced(by: .seconds(10)), overallUsage: 60))
        await waitUntil { received.count >= 2 }
        #expect(received == [.moderate, .high])

        consumeTask.cancel()
        collectTask.cancel()
    }

    // MARK: - 프로세스 조사 축 배선

    /// task-014 검증 조건: 프로세스 이력 저장소가 코디네이터에 연결되면, 시스템 지표 tick 하나가
    /// `ProcessHistoryStore.rankingInput()` -> `ApplicationRanking.compute`·`groupByApplication`을 지나
    /// 두 카드의 TOP 5와 상세 하위 프로세스 목록까지 실제로 도달해야 합니다.
    ///
    /// 이 테스트가 고정하는 것은 「두 축이 이 소비 지점에서 만난다」입니다 —
    /// `consumeSystemMetrics`가 순위 계산을 건너뛰고 빈 목록을 넘기도록 되돌리면 아래 단언이 모두 실패합니다.
    @Test func consumeSystemMetricsDeliversProcessSurveyRankingToBothCards() async {
        let store = MonitoringSampleStore()
        let processHistory = ProcessHistoryStore()
        let dashboard = DashboardPresentationStore()
        let consumeTask = ApplicationCoordinator.consumeSystemMetrics(
            store,
            into: CharacterStateSource(),
            dashboard: dashboard,
            processHistory: processHistory
        )

        // CPU 사용률은 기준점이 있어야 나오므로 조사 두 번을 1초 간격으로 넣습니다.
        // 1초 동안 Alpha가 0.5초, Bravo가 0.1초를 써 각각 50%·10%가 됩니다.
        let base = ContinuousClock().now
        await processHistory.append(processSurveySample(
            at: base,
            processes: [
                (path: "/Applications/Alpha.app/Contents/MacOS/Alpha", pid: 101, cpuTimeNanoseconds: 0, residentBytes: 300 * 1024 * 1024),
                (path: "/Applications/Bravo.app/Contents/MacOS/Bravo", pid: 102, cpuTimeNanoseconds: 0, residentBytes: 100 * 1024 * 1024)
            ]
        ))
        await processHistory.append(processSurveySample(
            at: base.advanced(by: .seconds(1)),
            processes: [
                (path: "/Applications/Alpha.app/Contents/MacOS/Alpha", pid: 101, cpuTimeNanoseconds: 500_000_000, residentBytes: 300 * 1024 * 1024),
                (path: "/Applications/Bravo.app/Contents/MacOS/Bravo", pid: 102, cpuTimeNanoseconds: 100_000_000, residentBytes: 100 * 1024 * 1024)
            ]
        ))

        await store.append(cpuSuccessSample(at: base.advanced(by: .seconds(1)), overallUsage: 10))
        await waitUntil {
            if case .normal = dashboard.cpuCard, case .normal = dashboard.memoryCard { return true }
            return false
        }

        guard case .normal(let cpu, _) = dashboard.cpuCard else {
            Issue.record("CPU 카드가 정상 상태가 되지 않았습니다.")
            consumeTask.cancel()
            return
        }
        #expect(cpu.topApplications.map(\.displayName) == ["Alpha", "Bravo"])
        #expect(cpu.topApplications.map(\.value) == [50, 10])
        #expect(cpu.detail.applications.map(\.displayName).sorted() == ["Alpha", "Bravo"])

        guard case .normal(let memory, _) = dashboard.memoryCard else {
            Issue.record("Memory 카드가 정상 상태가 되지 않았습니다.")
            consumeTask.cancel()
            return
        }
        #expect(memory.topApplications.map(\.displayName) == ["Alpha", "Bravo"])
        #expect(memory.detail.currentUsageRanking.map(\.displayName) == ["Alpha", "Bravo"])
        #expect(memory.detail.applications.map(\.displayName).sorted() == ["Alpha", "Bravo"])

        consumeTask.cancel()
    }

    /// SPEC §5.10: 프로세스 조사 실패는 두 카드의 TOP 5만 실패로 바꾸고 시스템 지표 수치는 그대로 둡니다.
    ///
    /// 이 테스트가 고정하는 것은 「조사 실패가 표시 계층까지 실제로 도달한다」입니다.
    /// 조사 실패를 값이 아니라 예외로 되돌리면 `MonitoringScheduler`가 그 tick을 건너뛰어
    /// 저장소에 실패가 도착하지 않고, `topApplicationsFailed`가 production에서 영원히 `false`가 되어
    /// 낡은 TOP 5가 정상인 것처럼 계속 표시됩니다.
    /// 실패가 다음 성공 조사에서 풀리는 것까지 함께 단언해, 한 번 실패하면 영구히 실패로 남지 않음을 고정합니다.
    @Test func processSurveyFailureReachesBothCardsAndClearsOnTheNextSuccess() async {
        let store = MonitoringSampleStore()
        let processHistory = ProcessHistoryStore()
        let dashboard = DashboardPresentationStore()
        let consumeTask = ApplicationCoordinator.consumeSystemMetrics(
            store,
            into: CharacterStateSource(),
            dashboard: dashboard,
            processHistory: processHistory
        )
        let base = ContinuousClock().now

        await processHistory.append(processSurveySample(
            at: base,
            processes: [(path: "/Applications/Alpha.app/Contents/MacOS/Alpha", pid: 101, cpuTimeNanoseconds: 0, residentBytes: 300 * 1024 * 1024)]
        ))
        await processHistory.append(TimestampedSample(
            timestamp: base.advanced(by: .seconds(1)),
            value: ProcessSurveySample(
                result: .failure(CollectorFailure(metric: .process, cause: .systemCall(name: "sysctl(KERN_PROC_ALL).size", code: EPERM)))
            )
        ))

        await store.append(cpuSuccessSample(at: base.advanced(by: .seconds(1)), overallUsage: 42))
        await waitUntil {
            if case .normal(let cpu, _) = dashboard.cpuCard { return cpu.topApplicationsFailed }
            return false
        }

        guard case .normal(let failedCPU, _) = dashboard.cpuCard,
              case .normal(let failedMemory, _) = dashboard.memoryCard else {
            Issue.record("조사 실패 tick에서 카드가 정상 상태로 유지되지 않았습니다.")
            consumeTask.cancel()
            return
        }
        #expect(failedCPU.topApplicationsFailed)
        #expect(failedMemory.topApplicationsFailed)
        // 시스템 지표 수치는 조사 실패와 무관하게 그대로입니다.
        #expect(failedCPU.overallUsage == 42)

        // 다음 성공 조사가 실패 표시를 풀고, 실패 tick이 지우지 않은 기준점 덕분에 사용률이 곧바로 나옵니다.
        await processHistory.append(processSurveySample(
            at: base.advanced(by: .seconds(2)),
            processes: [(path: "/Applications/Alpha.app/Contents/MacOS/Alpha", pid: 101, cpuTimeNanoseconds: 1_000_000_000, residentBytes: 300 * 1024 * 1024)]
        ))
        await store.append(cpuSuccessSample(at: base.advanced(by: .seconds(2)), overallUsage: 42))
        await waitUntil {
            if case .normal(let cpu, _) = dashboard.cpuCard { return !cpu.topApplicationsFailed }
            return false
        }

        guard case .normal(let recoveredCPU, _) = dashboard.cpuCard else {
            Issue.record("성공 조사 후 CPU 카드가 정상 상태가 되지 않았습니다.")
            consumeTask.cancel()
            return
        }
        #expect(!recoveredCPU.topApplicationsFailed)
        #expect(recoveredCPU.topApplications.map(\.displayName) == ["Alpha"])

        consumeTask.cancel()
    }
}

// MARK: - consumeSystemMetrics 테스트용 샘플 조립

/// 실행 경로·PID·누적 CPU 시간·Resident Memory만 의미 있게 두고 나머지 자리는 순위 계산과 무관한 값으로 채우는 조사 결과.
private func processSurveySample(
    at timestamp: ContinuousClock.Instant,
    processes: [(path: String, pid: pid_t, cpuTimeNanoseconds: UInt64, residentBytes: UInt64)]
) -> TimestampedSample<ProcessSurveySample> {
    TimestampedSample(
        timestamp: timestamp,
        value: ProcessSurveySample(
            result: .success(
                ProcessSurveyReport(
                    samples: processes.map { process in
                        ProcessSample(
                            identity: ProcessIdentity(pid: process.pid, startTime: 0),
                            executablePath: process.path,
                            uid: 501,
                            parentPID: 1,
                            cpuTimeNanoseconds: process.cpuTimeNanoseconds,
                            residentBytes: process.residentBytes,
                            isTranslated: false
                        )
                    },
                    unreadableCount: 0
                )
            )
        )
    )
}

/// 전체 사용률만 의미 있게 두고 나머지는 판정과 무관한 자리를 채우는 CPU 지표.
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

private func memoryMetrics() -> MemorySystemMetrics {
    MemorySystemMetrics(
        totalPhysicalBytes: 16 * 1024 * 1024 * 1024,
        usedBytes: 8 * 1024 * 1024 * 1024,
        appBytes: 4 * 1024 * 1024 * 1024,
        wiredBytes: 2 * 1024 * 1024 * 1024,
        compressedBytes: 2 * 1024 * 1024 * 1024,
        cachedBytes: 1024 * 1024 * 1024,
        swapUsedBytes: 0,
        pressureLevel: .normal
    )
}

private let cpuFailureForTests = CollectorFailure(metric: .cpu, cause: .systemCall(name: "host_processor_info", code: 5))

/// CPU 지표가 실패한 tick. Memory는 항상 성공값을 담아 CPU만의 실패임을 분명히 합니다.
private func cpuFailureSample(at timestamp: ContinuousClock.Instant) -> TimestampedSample<SystemMetricsSample> {
    TimestampedSample(
        timestamp: timestamp,
        value: SystemMetricsSample(cpu: .failure(cpuFailureForTests), memory: .success(memoryMetrics()))
    )
}

/// CPU가 값을 만들지 못한(기준점만 갱신한) tick.
private func cpuValuelessSample(at timestamp: ContinuousClock.Instant) -> TimestampedSample<SystemMetricsSample> {
    TimestampedSample(
        timestamp: timestamp,
        value: SystemMetricsSample(cpu: .success(nil), memory: .success(memoryMetrics()))
    )
}

/// CPU가 실제 사용률 값을 만든 tick.
private func cpuSuccessSample(at timestamp: ContinuousClock.Instant, overallUsage: Double) -> TimestampedSample<SystemMetricsSample> {
    TimestampedSample(
        timestamp: timestamp,
        value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: overallUsage)), memory: .success(memoryMetrics()))
    )
}
