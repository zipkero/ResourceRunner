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
}
