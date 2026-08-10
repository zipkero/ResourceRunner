//
//  MonitoringLifecycleTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/10/26.
//

import Foundation
import Testing
@testable import ResourceRunner

/// 여러 테스트가 actor 상태가 갱신될 때까지 협력적으로 기다리는 데 쓰는 공유 폴링 helper.
/// `SystemLifecycleObserverTests`가 쓰는 것과 같은 패턴입니다.
private func waitUntil(maxIterations: Int = 10_000, _ condition: () async -> Bool) async {
    var iterations = 0
    while await !condition() && iterations < maxIterations {
        await Task.yield()
        iterations += 1
    }
}

// MARK: - 테스트용 수동 시계

/// 실제로 잠들지 않고 테스트가 명시적으로 전진시키는 `MonotonicClock` 구현.
/// `sleep(until:)`은 요청한 deadline에 도달할 때까지 suspend하고, `advance(by:)`가 호출되면
/// 도달한 deadline의 대기자만 깨웁니다. 취소되면 대기자는 `CancellationError`로 재개됩니다.
actor ManualMonotonicClock: MonotonicClock {
    private struct Waiter {
        let id: Int
        let deadline: ContinuousClock.Instant
        let continuation: CheckedContinuation<Void, Error>
    }

    private var current: ContinuousClock.Instant
    private var waiters: [Waiter] = []
    private var nextWaiterID = 0

    init() {
        self.current = ContinuousClock().now
    }

    func now() -> ContinuousClock.Instant {
        current
    }

    func sleep(until deadline: ContinuousClock.Instant) async throws {
        if deadline <= current {
            try Task.checkCancellation()
            return
        }

        let id = nextWaiterID
        nextWaiterID += 1

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                waiters.append(Waiter(id: id, deadline: deadline, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancelWaiter(id: id) }
        }
    }

    private func cancelWaiter(id: Int) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    /// 시간을 수동으로 전진시키고, 도달한 deadline의 대기자를 도착 순서대로 깨웁니다.
    func advance(by duration: Duration) {
        current = current.advanced(by: duration)
        let ready = waiters.filter { $0.deadline <= current }
        waiters.removeAll { $0.deadline <= current }
        for waiter in ready {
            waiter.continuation.resume()
        }
    }
}

// MARK: - 테스트용 샘플 공급자

/// 미리 준비한 결과를 순서대로 돌려주는 `ScheduledSampleSource`.
/// 결과가 바닥나면 실패로 처리해 공급자 실패 경로도 함께 검증할 수 있습니다.
/// `advanceClockBy`를 주면 매 호출마다 그만큼 시계를 전진시켜 "처리에 시간이 걸리는 수집"을 흉내냅니다.
final class MemoryScheduledSampleSource: ScheduledSampleSource, @unchecked Sendable {
    enum Failure: Error { case noMoreOutcomes, injected }

    private let lock = NSLock()
    private var outcomes: [Result<Int, Error>]
    private let advanceClockBy: Duration?
    private let clock: ManualMonotonicClock?
    private(set) var callCount = 0

    init(outcomes: [Result<Int, Error>], advanceClockBy: Duration? = nil, clock: ManualMonotonicClock? = nil) {
        self.outcomes = outcomes
        self.advanceClockBy = advanceClockBy
        self.clock = clock
    }

    func sample() async throws -> Int {
        try Task.checkCancellation()

        lock.lock()
        callCount += 1
        let outcome = outcomes.isEmpty ? nil : outcomes.removeFirst()
        lock.unlock()

        if let advanceClockBy, let clock {
            await clock.advance(by: advanceClockBy)
        }

        guard let outcome else { throw Failure.noMoreOutcomes }
        return try outcome.get()
    }
}

// MARK: - CollectionSchedulePolicy

/// task-009 검증 조건: `unlocked` × normal·lowPower × 팝오버 열림·닫힘,
/// `locked`·`unknown`은 팝오버·전력과 무관하게 `paused`인 12가지 조합을 전수 검증합니다.
struct CollectionSchedulePolicyTests {

    @Test(arguments: [
        (ScreenLockState.unlocked, false, true, Duration.seconds(1)),   // normal, 열림
        (ScreenLockState.unlocked, false, false, Duration.seconds(2)),  // normal, 닫힘
        (ScreenLockState.unlocked, true, true, Duration.seconds(2)),    // lowPower, 열림
        (ScreenLockState.unlocked, true, false, Duration.seconds(5)),   // lowPower, 닫힘
    ])
    func unlockedProducesRunningWithExpectedInterval(
        screenLockState: ScreenLockState,
        lowPowerMode: Bool,
        popoverPresented: Bool,
        expectedInterval: Duration
    ) {
        let lifecycle = MonitoringLifecycle(
            popoverPresented: popoverPresented,
            lowPowerMode: lowPowerMode,
            screenLockState: screenLockState
        )

        let schedule = CollectionSchedulePolicy.schedule(for: lifecycle, definition: .m1)

        #expect(schedule == .running(expectedInterval))
    }

    @Test(arguments: [
        ScreenLockState.locked,
        ScreenLockState.unknown,
    ])
    func lockedOrUnknownIsAlwaysPausedRegardlessOfPowerAndPopover(screenLockState: ScreenLockState) {
        for lowPowerMode in [false, true] {
            for popoverPresented in [false, true] {
                let lifecycle = MonitoringLifecycle(
                    popoverPresented: popoverPresented,
                    lowPowerMode: lowPowerMode,
                    screenLockState: screenLockState
                )

                let schedule = CollectionSchedulePolicy.schedule(for: lifecycle, definition: .m1)

                #expect(schedule == .paused)
            }
        }
    }
}

// MARK: - MonitoringLifecycleStore

/// task-009 검증 조건: 최초 revision은 항상 적용하고 이후 마지막 system revision보다 작거나 같은
/// snapshot은 거부합니다. 팝오버 이벤트는 revision과 무관하게 항상 반영됩니다.
/// 같은 결과를 만드는 이벤트가 반복 도착해도 `apply(_:)`가 다시 호출되지 않습니다.
struct MonitoringLifecycleStoreTests {

    private func makeStore(
        outcomes: [Result<Int, Error>] = []
    ) -> (
        store: MonitoringLifecycleStore<ManualMonotonicClock, MemoryScheduledSampleSource>,
        scheduler: MonitoringScheduler<ManualMonotonicClock, MemoryScheduledSampleSource>,
        sampleStore: MonitoringSampleStore<Int>,
        clock: ManualMonotonicClock
    ) {
        let clock = ManualMonotonicClock()
        let sampleStore = MonitoringSampleStore<Int>(timeRange: .seconds(600), samplingInterval: .seconds(1))
        let source = MemoryScheduledSampleSource(outcomes: outcomes)
        let scheduler = MonitoringScheduler(clock: clock, source: source, sampleStore: sampleStore)
        let store = MonitoringLifecycleStore(definition: .m1, scheduler: scheduler)
        return (store, scheduler, sampleStore, clock)
    }

    @Test func firstSystemSnapshotIsAlwaysApplied() async {
        let (store, scheduler, _, _) = makeStore()

        await store.update(.systemSnapshot(SystemLifecycleSnapshot(revision: 0, lowPowerMode: false, screenLockState: .unlocked)))

        #expect(await scheduler.applyCallCount == 1)
    }

    @Test func snapshotWithRevisionLessThanOrEqualToLastIsRejected() async {
        let (store, scheduler, _, _) = makeStore()

        await store.update(.systemSnapshot(SystemLifecycleSnapshot(revision: 5, lowPowerMode: false, screenLockState: .unlocked)))
        #expect(await scheduler.applyCallCount == 1)

        // 같은 revision -> 거부 (schedule이 바뀌어도 revision 검사가 먼저 막아야 함)
        await store.update(.systemSnapshot(SystemLifecycleSnapshot(revision: 5, lowPowerMode: true, screenLockState: .unlocked)))
        #expect(await scheduler.applyCallCount == 1)

        // 더 작은 revision -> 거부
        await store.update(.systemSnapshot(SystemLifecycleSnapshot(revision: 3, lowPowerMode: true, screenLockState: .unlocked)))
        #expect(await scheduler.applyCallCount == 1)

        // 더 큰 revision -> 적용 (그리고 실제로 일정이 바뀌어야 apply 호출)
        await store.update(.systemSnapshot(SystemLifecycleSnapshot(revision: 6, lowPowerMode: true, screenLockState: .unlocked)))
        #expect(await scheduler.applyCallCount == 2)
    }

    @Test func popoverEventIsAlwaysAppliedRegardlessOfRevision() async {
        let (store, scheduler, _, _) = makeStore()

        await store.update(.systemSnapshot(SystemLifecycleSnapshot(revision: 0, lowPowerMode: false, screenLockState: .unlocked)))
        #expect(await scheduler.applyCallCount == 1)

        // 팝오버 이벤트는 revision 검사 대상이 아니며, 일정이 실제로 바뀌므로 적용됩니다.
        await store.update(.popoverPresented(true))
        #expect(await scheduler.applyCallCount == 2)
    }

    @Test func repeatedEventsProducingSameScheduleDoNotCallApplyAgain() async {
        let (store, scheduler, sampleStore, clock) = makeStore(outcomes: (1...10).map { .success($0) })

        await store.update(.systemSnapshot(SystemLifecycleSnapshot(revision: 0, lowPowerMode: false, screenLockState: .unlocked)))
        #expect(await scheduler.applyCallCount == 1)

        // normal 닫힘 -> interval 2초. 한 tick 진행시켜 실제로 샘플 1개를 쌓습니다.
        await clock.advance(by: .seconds(2))
        await waitUntil { await sampleStore.snapshot().count >= 1 }
        #expect(await sampleStore.snapshot().count == 1)

        // popoverPresented(false) -> 이미 false이므로 결과 일정(normal 닫힘 2초)이 그대로.
        await store.update(.popoverPresented(false))
        await store.update(.popoverPresented(false))
        await store.update(.systemSnapshot(SystemLifecycleSnapshot(revision: 1, lowPowerMode: false, screenLockState: .unlocked)))

        #expect(await scheduler.applyCallCount == 1)

        // apply(_:)가 다시 불리지 않아 작업이 재시작되지 않았으므로, 반복된 이벤트들 사이에는
        // 새 샘플이 쌓이지 않고, 다음 tick에서도 누적 샘플 수가 정확히 1개만 더 늘어야 합니다.
        await clock.advance(by: .seconds(2))
        await waitUntil { await sampleStore.snapshot().count >= 2 }
        #expect(await sampleStore.snapshot().count == 2)
    }

    @Test func lockedSnapshotProducesPausedRegardlessOfPriorState() async {
        let (store, scheduler, _, _) = makeStore()

        await store.update(.systemSnapshot(SystemLifecycleSnapshot(revision: 0, lowPowerMode: true, screenLockState: .locked)))

        #expect(await scheduler.applyCallCount == 1)
        // 계산 결과가 이미 paused이므로, 이후 팝오버·전력 변화가 있어도 반복 잠금 상태는 apply를 다시 부르지 않습니다.
        await store.update(.popoverPresented(true))
        #expect(await scheduler.applyCallCount == 1)
    }
}

// MARK: - MonitoringScheduler

/// task-009 검증 조건: 일정 교체 시 기존 작업 취소와 새 generation 하나만 시작,
/// deadline 전진(마지막 실행 완료 시점이 아님), pause 중 버퍼·용량 유지,
/// resume 시 새 유효 주기 resize와 미따라잡기, 취소·이전 generation·공급자 실패가
/// 0 샘플로 바뀌지 않음을 검증합니다.
struct MonitoringSchedulerTests {

    @Test func runningScheduleAppendsOneSamplePerTickUsingAnchoredDeadline() async {
        let clock = ManualMonotonicClock()
        let sampleStore = MonitoringSampleStore<Int>(timeRange: .seconds(10), samplingInterval: .seconds(1))
        // sample() 호출마다 0.5초씩 시계를 전진시켜, "처리에 시간이 걸리는 수집"을 흉내냅니다.
        let source = MemoryScheduledSampleSource(
            outcomes: [.success(1), .success(2), .success(3)],
            advanceClockBy: .milliseconds(500),
            clock: clock
        )
        let scheduler = MonitoringScheduler(clock: clock, source: source, sampleStore: sampleStore)

        await scheduler.apply(.running(.seconds(1)))

        // deadline1 = t0+1s. 도달하면 sample()이 호출되고, 그 안에서 시계가 t0+1.5s로 더 전진합니다.
        await clock.advance(by: .seconds(1))
        await waitUntil { await sampleStore.snapshot().count >= 1 }
        #expect(await sampleStore.snapshot().count == 1)

        // deadline2 = deadline1 + 1s = t0+2s. "마지막 실행 완료 시점 + interval" 방식이었다면
        // deadline2가 t0+2.5s가 되어, 여기서 0.5초만 더 전진해도(t0+2.0s) 아직 도달하지 않습니다.
        await clock.advance(by: .milliseconds(500)) // 현재 t0+2.0s
        await waitUntil { await sampleStore.snapshot().count >= 2 }
        #expect(await sampleStore.snapshot().count == 2)
    }

    @Test func scheduleChangeCancelsPreviousTaskAndStartsExactlyOneNewGeneration() async {
        let clock = ManualMonotonicClock()
        let sampleStore = MonitoringSampleStore<Int>(timeRange: .seconds(10), samplingInterval: .seconds(1))
        let source = MemoryScheduledSampleSource(outcomes: (1...20).map { .success($0) })
        let scheduler = MonitoringScheduler(clock: clock, source: source, sampleStore: sampleStore)

        await scheduler.apply(.running(.seconds(1)))
        await scheduler.apply(.running(.seconds(2))) // 일정 교체 -> 이전 작업 취소, 새 generation 하나

        // 이전 작업(1초 주기)이 살아 있었다면 1초 뒤 샘플이 남았을 것입니다.
        // 새 작업(2초 주기)만 살아 있어야 하므로 1초 전진으로는 아직 아무 샘플도 없어야 합니다.
        await clock.advance(by: .seconds(1))
        for _ in 0..<50 { await Task.yield() }
        #expect(await sampleStore.snapshot().isEmpty)

        // 새 작업의 deadline(2초)에 도달하면 정확히 샘플 하나만 쌓입니다.
        await clock.advance(by: .seconds(1)) // 총 2초 전진
        await waitUntil { await sampleStore.snapshot().count >= 1 }
        #expect(await sampleStore.snapshot().count == 1)
    }

    /// `generation`은 `Task.isCancelled`와 별개로 이전 세대 결과를 걸러내는 방어선입니다.
    /// `apply(_:)`가 취소와 같은 동기 구간에서 즉시 전진시키는지(뒤에 오는 `await resize` 같은
    /// suspension 지점 이후로 미루지 않는지) 직접 관찰합니다. 이 순서가 뒤바뀌면, 그 suspension 구간에서
    /// 이전 세대 작업이 이미 취소 확인을 통과해 두고 actor 차례를 기다리던 결과가 아직 갱신 전인
    /// generation과 우연히 일치해 저장될 수 있습니다.
    @Test func generationAdvancesSynchronouslyBeforeAnySuspensionOnEveryApply() async {
        let clock = ManualMonotonicClock()
        let sampleStore = MonitoringSampleStore<Int>(timeRange: .seconds(600), samplingInterval: .seconds(1))
        let source = MemoryScheduledSampleSource(outcomes: [])
        let scheduler = MonitoringScheduler(clock: clock, source: source, sampleStore: sampleStore)

        #expect(await scheduler.generation == 0)

        await scheduler.apply(.running(.seconds(1)))
        #expect(await scheduler.generation == 1)

        await scheduler.apply(.running(.seconds(2))) // 일정 교체
        #expect(await scheduler.generation == 2)

        await scheduler.apply(.paused)
        #expect(await scheduler.generation == 3) // paused도 이전 작업 결과를 모두 무효화하도록 전진합니다.

        await scheduler.apply(.running(.seconds(1))) // resume
        #expect(await scheduler.generation == 4)
    }

    @Test func pauseCancelsTaskButDoesNotResizeOrClearBuffer() async {
        let clock = ManualMonotonicClock()
        // timeRange 6초 / interval 2초 -> 용량 3으로, resize가 일어나면 쉽게 관찰됩니다.
        let sampleStore = MonitoringSampleStore<Int>(timeRange: .seconds(6), samplingInterval: .seconds(2))
        let source = MemoryScheduledSampleSource(outcomes: [.success(1), .success(2)])
        let scheduler = MonitoringScheduler(clock: clock, source: source, sampleStore: sampleStore)

        await scheduler.apply(.running(.seconds(2)))

        // 시계를 두 번 전진시켜 실제로 샘플 2개를 쌓은 뒤 pause합니다.
        await clock.advance(by: .seconds(2))
        await waitUntil { await sampleStore.snapshot().count >= 1 }
        await clock.advance(by: .seconds(2))
        await waitUntil { await sampleStore.snapshot().count >= 2 }
        #expect(await sampleStore.snapshot().map(\.value) == [1, 2])

        await scheduler.apply(.paused)

        // pause는 버퍼를 비우지 않으므로 쌓인 샘플이 그대로 남아 있어야 합니다.
        #expect(await sampleStore.snapshot().map(\.value) == [1, 2])

        // pause는 resize도 호출하지 않으므로 용량(3)도 그대로입니다.
        // 시계·클럭 상관없이 store에 직접 2개를 더 append해 용량 경계를 관찰합니다.
        let clockForStamp = ContinuousClock()
        await sampleStore.append(TimestampedSample(timestamp: clockForStamp.now, value: 300))
        await sampleStore.append(TimestampedSample(timestamp: clockForStamp.now, value: 400))

        let snapshot = await sampleStore.snapshot()
        #expect(snapshot.map(\.value) == [2, 300, 400]) // 용량 3 유지 -> 가장 오래된 것(1)만 밀려남
    }

    @Test func resumeResizesToNewIntervalCapacityAndDoesNotCatchUpMissedTicks() async {
        let clock = ManualMonotonicClock()
        let sampleStore = MonitoringSampleStore<Int>(timeRange: .seconds(600), samplingInterval: .seconds(2))
        let source = MemoryScheduledSampleSource(outcomes: (1...20).map { .success($0) })
        let scheduler = MonitoringScheduler(clock: clock, source: source, sampleStore: sampleStore)

        await scheduler.apply(.running(.seconds(2))) // 용량 300 (600/2)
        await scheduler.apply(.paused)

        // pause 동안 시간이 많이 흘러도(놓친 실행이 여러 번 있을 시간) 따라잡지 않아야 합니다.
        await clock.advance(by: .seconds(20))
        for _ in 0..<50 { await Task.yield() }
        #expect(await sampleStore.snapshot().isEmpty)

        await scheduler.apply(.running(.seconds(1))) // resume, 새 유효 주기 1초 -> 용량 600 (600/1)

        // resume 시점부터 다시 anchor를 잡으므로, 1초 뒤에만 샘플 1개가 쌓여야 합니다.
        await clock.advance(by: .seconds(1))
        await waitUntil { await sampleStore.snapshot().count >= 1 }
        #expect(await sampleStore.snapshot().count == 1)

        // 새 용량(600)이 실제로 적용됐는지 확인하기 위해 601개를 채워 경계를 관찰합니다.
        // (이미 1개가 있으므로 600개를 추가로 채우면 정확히 601번째에서 첫 샘플이 밀려나야 합니다.)
        for value in 0..<600 {
            await sampleStore.append(TimestampedSample(timestamp: ContinuousClock().now, value: value))
        }
        let snapshot = await sampleStore.snapshot()
        #expect(snapshot.count == 600) // 용량이 600이라 601개 중 가장 오래된 1개만 교체됨
        #expect(snapshot.first?.value == 0) // 첫 샘플(resume tick)은 이미 밀려났고 그 다음이 오래된 것
    }

    @Test func cancelledOrStaleGenerationResultsAreNotStored() async {
        let clock = ManualMonotonicClock()
        let sampleStore = MonitoringSampleStore<Int>(timeRange: .seconds(600), samplingInterval: .seconds(1))
        let source = MemoryScheduledSampleSource(outcomes: (1...20).map { .success($0) })
        let scheduler = MonitoringScheduler(clock: clock, source: source, sampleStore: sampleStore)

        await scheduler.apply(.running(.seconds(1)))
        // 아직 deadline(1초)에 도달하기 전에 곧바로 다음 세대로 교체합니다.
        await scheduler.apply(.running(.seconds(1)))

        await clock.advance(by: .seconds(1))
        await waitUntil { await sampleStore.snapshot().count >= 1 }

        // 이전 generation의 결과는 저장되지 않고, 살아있는 새 generation의 결과만 하나 저장됩니다.
        #expect(await sampleStore.snapshot().count == 1)
        #expect(await sampleStore.snapshot().first?.value == 1) // 새 generation이 처음부터 다시 outcomes를 소비
    }

    @Test func providerFailureDoesNotProduceZeroSampleAndSchedulerContinues() async {
        let clock = ManualMonotonicClock()
        let sampleStore = MonitoringSampleStore<Int>(timeRange: .seconds(600), samplingInterval: .seconds(1))
        let source = MemoryScheduledSampleSource(outcomes: [.failure(MemoryScheduledSampleSource.Failure.injected), .success(42)])
        let scheduler = MonitoringScheduler(clock: clock, source: source, sampleStore: sampleStore)

        await scheduler.apply(.running(.seconds(1)))

        await clock.advance(by: .seconds(1)) // 첫 실행 -> 실패
        for _ in 0..<200 { await Task.yield() }
        #expect(await sampleStore.snapshot().isEmpty) // 실패가 0 샘플로 바뀌지 않음

        await clock.advance(by: .seconds(1)) // 두 번째 실행 -> 성공
        await waitUntil { await sampleStore.snapshot().count >= 1 }
        #expect(await sampleStore.snapshot().map(\.value) == [42])
    }

    /// 성공 뒤에 실패가 와도, 실패가 직전 성공값을 재사용해 채워 넣는 식으로 "샘플 개수"만 맞추지 않는지
    /// 확인합니다. 성공 1회 + 실패 1회 뒤에는 여전히 성공 샘플 하나만 있어야 합니다.
    @Test func providerFailureAfterSuccessDoesNotFabricateAnAdditionalSample() async {
        let clock = ManualMonotonicClock()
        let sampleStore = MonitoringSampleStore<Int>(timeRange: .seconds(600), samplingInterval: .seconds(1))
        let source = MemoryScheduledSampleSource(outcomes: [
            .success(1),
            .failure(MemoryScheduledSampleSource.Failure.injected),
        ])
        let scheduler = MonitoringScheduler(clock: clock, source: source, sampleStore: sampleStore)

        await scheduler.apply(.running(.seconds(1)))

        await clock.advance(by: .seconds(1)) // 첫 실행 -> 성공(1)
        await waitUntil { await sampleStore.snapshot().count >= 1 }
        #expect(await sampleStore.snapshot().map(\.value) == [1])

        await clock.advance(by: .seconds(1)) // 두 번째 실행 -> 실패
        for _ in 0..<200 { await Task.yield() }
        #expect(await sampleStore.snapshot().map(\.value) == [1]) // 직전 성공값을 재사용한 추가 샘플이 없어야 함
    }

    @Test func repeatedApplyWithSameScheduleWouldRestartWork() async {
        // MonitoringScheduler.apply(_:) 자체는 호출될 때마다 항상 작업을 재시작합니다.
        // 「같은 일정 반복에도 중복 수집이 없다」는 보장은 MonitoringLifecycleStore가
        // 같은 결과일 때 apply를 다시 호출하지 않는 데서 나오지, Scheduler 내부에서 막는 것이 아닙니다.
        // 이 테스트는 그 경계를 고정합니다: Scheduler에 같은 일정을 두 번 apply하면
        // applyCallCount가 그대로 2가 되어야 합니다(Scheduler가 스스로 중복을 걸러내지 않음).
        let clock = ManualMonotonicClock()
        let sampleStore = MonitoringSampleStore<Int>(timeRange: .seconds(600), samplingInterval: .seconds(1))
        let source = MemoryScheduledSampleSource(outcomes: [.success(1)])
        let scheduler = MonitoringScheduler(clock: clock, source: source, sampleStore: sampleStore)

        await scheduler.apply(.running(.seconds(1)))
        await scheduler.apply(.running(.seconds(1)))

        #expect(await scheduler.applyCallCount == 2)
    }
}

// MARK: - 메모리 SystemLifecycleSource를 이용한 통합 검증

/// task-009 접근 조건: 잠금 입력은 메모리 `SystemLifecycleSource`로 주입받아
/// 실제 OS 어댑터 없이 store까지 이어지는 흐름을 검증합니다.
struct MemorySystemLifecycleSourceIntegrationTests {

    @MainActor
    @Test func memorySourceSnapshotsDriveStoreScheduleSelectionAcrossAllCombinations() async {
        let memorySource = MemorySystemLifecycleSource(initialLowPowerMode: false, initialScreenLockState: .unlocked)
        let subscription = memorySource.start()

        var received: [SystemLifecycleSnapshot] = [subscription.initial]
        let collector = Task { @MainActor in
            for await snapshot in subscription.updates {
                received.append(snapshot)
            }
        }

        let clock = ManualMonotonicClock()
        let sampleStore = MonitoringSampleStore<Int>(timeRange: .seconds(600), samplingInterval: .seconds(1))
        let source = MemoryScheduledSampleSource(outcomes: [])
        let scheduler = MonitoringScheduler(clock: clock, source: source, sampleStore: sampleStore)
        let store = MonitoringLifecycleStore(definition: .m1, scheduler: scheduler)

        // 초기 snapshot(unlocked, normal)을 store에 반영합니다.
        await store.update(.systemSnapshot(subscription.initial))
        await store.update(.popoverPresented(false))
        #expect(await scheduler.applyCallCount == 1) // normal 닫힘 2초

        await store.update(.popoverPresented(true))
        #expect(await scheduler.applyCallCount == 2) // normal 열림 1초

        memorySource.sendLowPowerMode(true)
        await waitUntil { received.count >= 2 }
        await store.update(.systemSnapshot(received[1]))
        #expect(await scheduler.applyCallCount == 3) // lowPower 열림 2초

        memorySource.sendScreenLockState(.locked)
        await waitUntil { received.count >= 3 }
        await store.update(.systemSnapshot(received[2]))
        #expect(await scheduler.applyCallCount == 4) // locked -> paused

        memorySource.sendScreenLockState(.unknown)
        await waitUntil { received.count >= 4 }
        await store.update(.systemSnapshot(received[3]))
        // 이미 paused이므로 잠금 상태만 바뀌어도(여전히 paused) apply가 다시 불리지 않습니다.
        #expect(await scheduler.applyCallCount == 4)

        memorySource.sendScreenLockState(.unlocked)
        await waitUntil { received.count >= 5 }
        await store.update(.systemSnapshot(received[4]))
        #expect(await scheduler.applyCallCount == 5) // unlocked 복귀, lowPower 열림 2초로 재적용

        collector.cancel()
    }
}
