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

// MARK: - 테스트용 저장 대상

/// 스케줄러가 전달한 샘플을 도착 순서대로 그대로 보관하는 `MonitoringSampleSink`.
/// 이력 링 규칙과 표시용 선별은 `MonitoringSampleStore`의 관심사이므로,
/// 스케줄러·생명주기 검증에는 "무엇이 몇 개 도착했는지"만 관찰하는 이 sink를 씁니다.
actor MemorySampleSink<Value: Sendable>: MonitoringSampleSink {
    private(set) var samples: [TimestampedSample<Value>] = []

    func append(_ sample: TimestampedSample<Value>) {
        samples.append(sample)
    }

    var values: [Value] {
        samples.map(\.value)
    }
}

// MARK: - CollectionSchedulePolicy

/// task-003 검증 조건: 팝오버 2 × 전력 2 × 잠금 3 × 디스플레이 슬립 2 × 세션 활성 2 = 48가지 조합에서
/// `CollectionSchedulePlan`의 두 값을 전수 단언합니다.
/// 화면을 볼 수 있는 조합(잠금 `unlocked` · 디스플레이 깨어 있음 · 세션 활성)에서만 두 축이 각각의 주기로 돌고,
/// 나머지 조합은 모두 두 축이 `paused`입니다.
struct CollectionSchedulePolicyTests {

    /// 예상값을 정책과 같은 판정식으로 만들지 않기 위해, 표를 그대로 옮긴 값에서만 계산합니다.
    private static func expectedPlan(lowPowerMode: Bool, popoverPresented: Bool) -> CollectionSchedulePlan {
        let intervals: (system: Duration, process: Duration) = switch (lowPowerMode, popoverPresented) {
        case (false, true): (.seconds(1), .seconds(2))
        case (false, false): (.seconds(2), .seconds(5))
        case (true, true): (.seconds(2), .seconds(4))
        case (true, false): (.seconds(5), .seconds(10))
        }
        return CollectionSchedulePlan(systemMetrics: .running(intervals.system), processSurvey: .running(intervals.process))
    }

    @Test func allCombinationsOfPopoverPowerLockDisplaySleepAndSessionProduceExpectedPlan() {
        var assertedCombinations = 0

        for popoverPresented in [false, true] {
            for lowPowerMode in [false, true] {
                for screenLockState in [ScreenLockState.unlocked, .locked, .unknown] {
                    for displayAsleep in [false, true] {
                        for sessionActive in [true, false] {
                            let lifecycle = MonitoringLifecycle(
                                popoverPresented: popoverPresented,
                                lowPowerMode: lowPowerMode,
                                screenLockState: screenLockState,
                                displayAsleep: displayAsleep,
                                sessionActive: sessionActive
                            )

                            let plan = CollectionSchedulePolicy.plan(for: lifecycle, definition: .m2)

                            let screenObservable = screenLockState == .unlocked && !displayAsleep && sessionActive
                            let expected = screenObservable
                                ? Self.expectedPlan(lowPowerMode: lowPowerMode, popoverPresented: popoverPresented)
                                : .paused
                            #expect(
                                plan == expected,
                                """
                                popover=\(popoverPresented) lowPower=\(lowPowerMode) lock=\(screenLockState) \
                                displayAsleep=\(displayAsleep) sessionActive=\(sessionActive)
                                """
                            )
                            assertedCombinations += 1
                        }
                    }
                }
            }
        }

        #expect(assertedCombinations == 48) // 2 × 2 × 3 × 2 × 2
    }

    /// 이 테스트가 고정하는 것: 「새로 더한 두 신호 각각이 단독으로 수집을 멈춘다」.
    /// 나머지 네 신호는 모두 수집 가능한 값으로 두고 한 신호만 뒤집으므로,
    /// 판정에서 디스플레이 슬립이나 세션 활성 어느 한쪽을 빼면 그 경우가 실패합니다.
    @Test(arguments: [
        (ScreenLockState.unlocked, true, true),   // 디스플레이 슬립 단독
        (ScreenLockState.unlocked, false, false), // 세션 비활성 단독
        (ScreenLockState.locked, false, true),    // 잠금 단독
        (ScreenLockState.unknown, false, true),   // 잠금 unknown 단독
    ])
    func eachUnobservableSignalAlonePausesBothAxes(
        screenLockState: ScreenLockState,
        displayAsleep: Bool,
        sessionActive: Bool
    ) {
        // 팝오버 열림·normal 전력은 가장 빠른 주기(1초·2초)를 만드는 조합이므로,
        // 이 조합에서 `paused`가 나온다는 것은 신호 하나가 주기 계산 전체를 앞지른다는 뜻입니다.
        let lifecycle = MonitoringLifecycle(
            popoverPresented: true,
            lowPowerMode: false,
            screenLockState: screenLockState,
            displayAsleep: displayAsleep,
            sessionActive: sessionActive
        )

        let plan = CollectionSchedulePolicy.plan(for: lifecycle, definition: .m2)

        #expect(plan.systemMetrics == .paused)
        #expect(plan.processSurvey == .paused)
    }
}

// MARK: - MonitoringLifecycleStore

/// 두 수집 축을 한 쌍으로 다루기 위한 테스트용 묶음.
private struct TestCollectionAxis {
    let scheduler: MonitoringScheduler<ManualMonotonicClock, MemoryScheduledSampleSource, MemorySampleSink<Int>>
    let sink: MemorySampleSink<Int>
}

/// 새로 더한 두 필드까지 매번 적는 대신, 검증 대상 필드만 지정해 snapshot을 만드는 helper.
/// 기본값은 수집이 가능한 상태(잠금 해제·디스플레이 깨어 있음·세션 활성)입니다.
private func lifecycleSnapshot(
    revision: Int,
    lowPowerMode: Bool = false,
    screenLockState: ScreenLockState = .unlocked,
    displayAsleep: Bool = false,
    sessionActive: Bool = true
) -> SystemLifecycleSnapshot {
    SystemLifecycleSnapshot(
        revision: revision,
        lowPowerMode: lowPowerMode,
        screenLockState: screenLockState,
        displayAsleep: displayAsleep,
        sessionActive: sessionActive
    )
}

/// 화면을 볼 수 없게 만드는 신호 하나. 각 신호가 단독으로 두 축을 멈추는지 확인하는 데 씁니다.
/// `@Test(arguments:)`로 넘기므로 테스트 타입 안에 중첩하지 않고 파일 수준 `Sendable` 타입으로 둡니다.
enum UnobservableSignal: CaseIterable, Sendable {
    case locked
    case lockUnknown
    case displayAsleep
    case sessionInactive

    func makeSnapshot(revision: Int) -> SystemLifecycleSnapshot {
        switch self {
        case .locked: lifecycleSnapshot(revision: revision, screenLockState: .locked)
        case .lockUnknown: lifecycleSnapshot(revision: revision, screenLockState: .unknown)
        case .displayAsleep: lifecycleSnapshot(revision: revision, displayAsleep: true)
        case .sessionInactive: lifecycleSnapshot(revision: revision, sessionActive: false)
        }
    }
}

/// task-003 검증 조건: M1의 revision 거부와 중복 일정 억제 규칙이 축마다 그대로 유지되고,
/// 화면을 볼 수 없는 신호 각각에서 두 축의 누적 샘플 수가 늘지 않으며 재개가 놓친 실행을 따라잡지 않고,
/// 한 축의 일정만 바뀌면 다른 축의 실행 중 작업이 취소되지 않는지 검증합니다.
struct MonitoringLifecycleStoreTests {

    private func makeStore(
        definition: CollectionScheduleDefinition = .m2,
        systemOutcomes: [Result<Int, Error>] = [],
        processOutcomes: [Result<Int, Error>] = []
    ) -> (
        store: MonitoringLifecycleStore,
        system: TestCollectionAxis,
        process: TestCollectionAxis,
        clock: ManualMonotonicClock
    ) {
        let clock = ManualMonotonicClock()

        let systemSink = MemorySampleSink<Int>()
        let systemScheduler = MonitoringScheduler(
            clock: clock,
            source: MemoryScheduledSampleSource(outcomes: systemOutcomes),
            sink: systemSink
        )
        let processSink = MemorySampleSink<Int>()
        let processScheduler = MonitoringScheduler(
            clock: clock,
            source: MemoryScheduledSampleSource(outcomes: processOutcomes),
            sink: processSink
        )

        let store = MonitoringLifecycleStore(
            definition: definition,
            systemMetricsTarget: systemScheduler,
            processSurveyTarget: processScheduler
        )
        return (
            store,
            TestCollectionAxis(scheduler: systemScheduler, sink: systemSink),
            TestCollectionAxis(scheduler: processScheduler, sink: processSink),
            clock
        )
    }

    @Test func firstSystemSnapshotIsAppliedToBothAxes() async {
        let (store, system, process, _) = makeStore()

        await store.update(.systemSnapshot(lifecycleSnapshot(revision: 0)))

        #expect(await system.scheduler.applyCallCount == 1)
        #expect(await process.scheduler.applyCallCount == 1)
    }

    @Test func snapshotWithRevisionLessThanOrEqualToLastIsRejected() async {
        let (store, system, process, _) = makeStore()

        await store.update(.systemSnapshot(lifecycleSnapshot(revision: 5)))
        #expect(await system.scheduler.applyCallCount == 1)

        // 같은 revision -> 거부 (일정이 바뀌어도 revision 검사가 먼저 막아야 함)
        await store.update(.systemSnapshot(lifecycleSnapshot(revision: 5, lowPowerMode: true)))
        #expect(await system.scheduler.applyCallCount == 1)

        // 더 작은 revision -> 거부
        await store.update(.systemSnapshot(lifecycleSnapshot(revision: 3, lowPowerMode: true)))
        #expect(await system.scheduler.applyCallCount == 1)

        // 더 큰 revision -> 적용 (그리고 실제로 일정이 바뀌어야 apply 호출)
        await store.update(.systemSnapshot(lifecycleSnapshot(revision: 6, lowPowerMode: true)))
        #expect(await system.scheduler.applyCallCount == 2)
        #expect(await process.scheduler.applyCallCount == 2)
    }

    @Test func popoverEventIsAlwaysAppliedRegardlessOfRevision() async {
        let (store, system, process, _) = makeStore()

        await store.update(.systemSnapshot(lifecycleSnapshot(revision: 0)))
        #expect(await system.scheduler.applyCallCount == 1)

        // 팝오버 이벤트는 revision 검사 대상이 아니며, 두 축의 일정이 실제로 바뀌므로 적용됩니다.
        await store.update(.popoverPresented(true))
        #expect(await system.scheduler.applyCallCount == 2)
        #expect(await process.scheduler.applyCallCount == 2)
    }

    @Test func repeatedEventsProducingSamePlanDoNotCallApplyAgain() async {
        let (store, system, process, clock) = makeStore(
            systemOutcomes: (1...10).map { .success($0) },
            processOutcomes: (1...10).map { .success($0) }
        )

        await store.update(.systemSnapshot(lifecycleSnapshot(revision: 0)))
        #expect(await system.scheduler.applyCallCount == 1)
        #expect(await process.scheduler.applyCallCount == 1)

        // normal 닫힘 -> 시스템 2초·프로세스 5초. 시스템 축에서 한 tick 진행시켜 샘플 1개를 쌓습니다.
        await clock.advance(by: .seconds(2))
        await waitUntil { await system.sink.samples.count >= 1 }
        #expect(await system.sink.samples.count == 1)

        // popoverPresented(false) -> 이미 false이므로 두 축의 결과 일정이 그대로.
        await store.update(.popoverPresented(false))
        await store.update(.popoverPresented(false))
        await store.update(.systemSnapshot(lifecycleSnapshot(revision: 1)))

        #expect(await system.scheduler.applyCallCount == 1)
        #expect(await process.scheduler.applyCallCount == 1)

        // apply(_:)가 다시 불리지 않아 작업이 재시작되지 않았으므로, 반복된 이벤트들 사이에는
        // 새 샘플이 쌓이지 않고, 다음 tick에서도 누적 샘플 수가 정확히 1개만 더 늘어야 합니다.
        await clock.advance(by: .seconds(2))
        await waitUntil { await system.sink.samples.count >= 2 }
        #expect(await system.sink.samples.count == 2)
    }

    @Test(arguments: UnobservableSignal.allCases)
    func eachUnobservableSignalStopsBothAxesAndResumeDoesNotCatchUp(signal: UnobservableSignal) async {
        let (store, system, process, clock) = makeStore(
            systemOutcomes: (1...20).map { .success($0) },
            processOutcomes: (1...20).map { .success($0) }
        )

        // 팝오버 닫힘·normal -> 시스템 2초·프로세스 5초.
        await store.update(.systemSnapshot(lifecycleSnapshot(revision: 0)))
        await clock.advance(by: .seconds(5))
        await waitUntil {
            let systemCount = await system.sink.samples.count
            let processCount = await process.sink.samples.count
            return systemCount >= 2 && processCount >= 1
        }
        let systemCountBeforePause = await system.sink.samples.count
        let processCountBeforePause = await process.sink.samples.count
        #expect(systemCountBeforePause > 0)
        #expect(processCountBeforePause > 0)

        // 신호 하나만 뒤집어 두 축을 멈춥니다.
        await store.update(.systemSnapshot(signal.makeSnapshot(revision: 1)))
        #expect(await system.scheduler.applyCallCount == 2)
        #expect(await process.scheduler.applyCallCount == 2)

        // 중지 동안 시계를 크게 전진시켜도 두 축의 누적 샘플 수가 정확히 0만큼 늘어야 합니다.
        await clock.advance(by: .seconds(60))
        for _ in 0..<200 { await Task.yield() }
        #expect(await system.sink.samples.count == systemCountBeforePause)
        #expect(await process.sink.samples.count == processCountBeforePause)

        // 재개하면 놓친 실행을 따라잡지 않고 tick 수만큼만 늘어납니다.
        await store.update(.systemSnapshot(lifecycleSnapshot(revision: 2)))
        await clock.advance(by: .seconds(2))
        await waitUntil { await system.sink.samples.count >= systemCountBeforePause + 1 }
        #expect(await system.sink.samples.count == systemCountBeforePause + 1)
        #expect(await process.sink.samples.count == processCountBeforePause) // 프로세스 주기(5초)는 아직 도달 전

        await clock.advance(by: .seconds(3))
        await waitUntil { await process.sink.samples.count >= processCountBeforePause + 1 }
        #expect(await process.sink.samples.count == processCountBeforePause + 1)
        #expect(await system.sink.samples.count == systemCountBeforePause + 2)
    }

    /// 이 테스트가 고정하는 것: 「한 축의 일정 변경이 다른 축을 재시작하지 않는다」.
    /// 시스템 지표 주기가 두 전력 상태에서 같고 프로세스 주기만 다른 정의를 써서,
    /// 저전력 전환이 프로세스 축에만 도달하는 상황을 만듭니다.
    /// 축별 비교를 없애고 plan 하나로 두 축에 그대로 적용하도록 되돌리면,
    /// 시스템 축이 재시작되어 남은 1초 뒤 tick이 사라지므로 이 테스트가 실패합니다.
    @Test func scheduleChangeOnOneAxisDoesNotRestartTheOtherAxis() async {
        let definition = CollectionScheduleDefinition(
            systemMetrics: CollectionScheduleDefinition.AxisIntervals(
                normalPresented: .seconds(1),
                normalDismissed: .seconds(2),
                lowPowerPresented: .seconds(1),
                lowPowerDismissed: .seconds(2)
            ),
            processSurvey: CollectionScheduleDefinition.AxisIntervals(
                normalPresented: .seconds(3),
                normalDismissed: .seconds(4),
                lowPowerPresented: .seconds(5),
                lowPowerDismissed: .seconds(6)
            )
        )
        let (store, system, process, clock) = makeStore(
            definition: definition,
            systemOutcomes: (1...20).map { .success($0) },
            processOutcomes: (1...20).map { .success($0) }
        )

        await store.update(.systemSnapshot(lifecycleSnapshot(revision: 0)))
        #expect(await system.scheduler.applyCallCount == 1) // 시스템 2초
        #expect(await process.scheduler.applyCallCount == 1) // 프로세스 4초

        // 시스템 축 deadline(2초)의 절반만 전진시킨 상태에서 저전력으로 전환합니다.
        await clock.advance(by: .seconds(1))
        await store.update(.systemSnapshot(lifecycleSnapshot(revision: 1, lowPowerMode: true)))

        // 시스템 축 일정은 그대로(2초)이므로 apply가 다시 불리지 않고, 프로세스 축만 6초로 교체됩니다.
        #expect(await system.scheduler.applyCallCount == 1)
        #expect(await process.scheduler.applyCallCount == 2)

        // 시스템 축의 실행 중 작업이 취소되지 않았으므로 원래 기준 deadline인 2초에 tick이 그대로 옵니다.
        await clock.advance(by: .seconds(1))
        await waitUntil { await system.sink.samples.count >= 1 }
        #expect(await system.sink.samples.count == 1)

        // 프로세스 축은 전환 시점에 6초로 다시 시작했으므로 아직 샘플이 없습니다.
        #expect(await process.sink.samples.isEmpty)
    }

    @Test func lockedSnapshotProducesPausedRegardlessOfPriorState() async {
        let (store, system, process, _) = makeStore()

        await store.update(.systemSnapshot(lifecycleSnapshot(revision: 0, lowPowerMode: true, screenLockState: .locked)))

        #expect(await system.scheduler.applyCallCount == 1)
        #expect(await process.scheduler.applyCallCount == 1)
        // 계산 결과가 이미 paused이므로, 이후 팝오버·전력 변화가 있어도 반복 잠금 상태는 apply를 다시 부르지 않습니다.
        await store.update(.popoverPresented(true))
        #expect(await system.scheduler.applyCallCount == 1)
        #expect(await process.scheduler.applyCallCount == 1)
    }
}

// MARK: - MonitoringScheduler

/// task-009 검증 조건: 일정 교체 시 기존 작업 취소와 새 generation 하나만 시작,
/// deadline 전진(마지막 실행 완료 시점이 아님), pause 중 수집 정지와 이미 전달된 샘플 유지,
/// resume 시 놓친 실행 미따라잡기, 취소·이전 generation·공급자 실패가
/// 0 샘플로 바뀌지 않음을 검증합니다.
/// 주기 변경이 이력 용량을 건드리지 않는다는 것은 저장소 쪽 `MonitoringSampleStoreTests`가 고정합니다.
struct MonitoringSchedulerTests {

    @Test func runningScheduleAppendsOneSamplePerTickUsingAnchoredDeadline() async {
        let clock = ManualMonotonicClock()
        let sink = MemorySampleSink<Int>()
        // sample() 호출마다 0.5초씩 시계를 전진시켜, "처리에 시간이 걸리는 수집"을 흉내냅니다.
        let source = MemoryScheduledSampleSource(
            outcomes: [.success(1), .success(2), .success(3)],
            advanceClockBy: .milliseconds(500),
            clock: clock
        )
        let scheduler = MonitoringScheduler(clock: clock, source: source, sink: sink)

        await scheduler.apply(.running(.seconds(1)))

        // deadline1 = t0+1s. 도달하면 sample()이 호출되고, 그 안에서 시계가 t0+1.5s로 더 전진합니다.
        await clock.advance(by: .seconds(1))
        await waitUntil { await sink.samples.count >= 1 }
        #expect(await sink.samples.count == 1)

        // deadline2 = deadline1 + 1s = t0+2s. "마지막 실행 완료 시점 + interval" 방식이었다면
        // deadline2가 t0+2.5s가 되어, 여기서 0.5초만 더 전진해도(t0+2.0s) 아직 도달하지 않습니다.
        await clock.advance(by: .milliseconds(500)) // 현재 t0+2.0s
        await waitUntil { await sink.samples.count >= 2 }
        #expect(await sink.samples.count == 2)
    }

    @Test func scheduleChangeCancelsPreviousTaskAndStartsExactlyOneNewGeneration() async {
        let clock = ManualMonotonicClock()
        let sink = MemorySampleSink<Int>()
        let source = MemoryScheduledSampleSource(outcomes: (1...20).map { .success($0) })
        let scheduler = MonitoringScheduler(clock: clock, source: source, sink: sink)

        await scheduler.apply(.running(.seconds(1)))
        await scheduler.apply(.running(.seconds(2))) // 일정 교체 -> 이전 작업 취소, 새 generation 하나

        // 이전 작업(1초 주기)이 살아 있었다면 1초 뒤 샘플이 남았을 것입니다.
        // 새 작업(2초 주기)만 살아 있어야 하므로 1초 전진으로는 아직 아무 샘플도 없어야 합니다.
        await clock.advance(by: .seconds(1))
        for _ in 0..<50 { await Task.yield() }
        #expect(await sink.samples.isEmpty)

        // 새 작업의 deadline(2초)에 도달하면 정확히 샘플 하나만 쌓입니다.
        await clock.advance(by: .seconds(1)) // 총 2초 전진
        await waitUntil { await sink.samples.count >= 1 }
        #expect(await sink.samples.count == 1)
    }

    /// `generation`은 `Task.isCancelled`와 별개로 이전 세대 결과를 걸러내는 방어선입니다.
    /// `apply(_:)`가 취소와 같은 동기 구간에서 즉시 전진시키는지(뒤에 오는 `await clock.now()` 같은
    /// suspension 지점 이후로 미루지 않는지) 직접 관찰합니다. 이 순서가 뒤바뀌면, 그 suspension 구간에서
    /// 이전 세대 작업이 이미 취소 확인을 통과해 두고 actor 차례를 기다리던 결과가 아직 갱신 전인
    /// generation과 우연히 일치해 저장될 수 있습니다.
    @Test func generationAdvancesSynchronouslyBeforeAnySuspensionOnEveryApply() async {
        let clock = ManualMonotonicClock()
        let sink = MemorySampleSink<Int>()
        let source = MemoryScheduledSampleSource(outcomes: [])
        let scheduler = MonitoringScheduler(clock: clock, source: source, sink: sink)

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

    @Test func pauseCancelsTaskButKeepsAlreadyCollectedSamples() async {
        let clock = ManualMonotonicClock()
        let sink = MemorySampleSink<Int>()
        let source = MemoryScheduledSampleSource(outcomes: [.success(1), .success(2), .success(3)])
        let scheduler = MonitoringScheduler(clock: clock, source: source, sink: sink)

        await scheduler.apply(.running(.seconds(2)))

        // 시계를 두 번 전진시켜 실제로 샘플 2개를 쌓은 뒤 pause합니다.
        await clock.advance(by: .seconds(2))
        await waitUntil { await sink.samples.count >= 1 }
        await clock.advance(by: .seconds(2))
        await waitUntil { await sink.samples.count >= 2 }
        #expect(await sink.values == [1, 2])

        await scheduler.apply(.paused)

        // pause는 이미 전달된 샘플을 되돌리지 않고, 중지 동안 새 샘플도 만들지 않습니다.
        #expect(await sink.values == [1, 2])
        await clock.advance(by: .seconds(10))
        for _ in 0..<50 { await Task.yield() }
        #expect(await sink.values == [1, 2])
    }

    @Test func resumeDoesNotCatchUpMissedTicks() async {
        let clock = ManualMonotonicClock()
        let sink = MemorySampleSink<Int>()
        let source = MemoryScheduledSampleSource(outcomes: (1...20).map { .success($0) })
        let scheduler = MonitoringScheduler(clock: clock, source: source, sink: sink)

        await scheduler.apply(.running(.seconds(2)))
        await scheduler.apply(.paused)

        // pause 동안 시간이 많이 흘러도(놓친 실행이 여러 번 있을 시간) 따라잡지 않아야 합니다.
        await clock.advance(by: .seconds(20))
        for _ in 0..<50 { await Task.yield() }
        #expect(await sink.samples.isEmpty)

        await scheduler.apply(.running(.seconds(1))) // resume

        // resume 시점부터 다시 anchor를 잡으므로, 1초 뒤에만 샘플 1개가 쌓여야 합니다.
        await clock.advance(by: .seconds(1))
        await waitUntil { await sink.samples.count >= 1 }
        #expect(await sink.samples.count == 1)

        // 중지 동안 놓친 실행을 몰아서 따라잡지 않으므로, 다음 tick에서도 정확히 하나만 늘어납니다.
        await clock.advance(by: .seconds(1))
        await waitUntil { await sink.samples.count >= 2 }
        #expect(await sink.samples.count == 2)
    }

    @Test func cancelledOrStaleGenerationResultsAreNotStored() async {
        let clock = ManualMonotonicClock()
        let sink = MemorySampleSink<Int>()
        let source = MemoryScheduledSampleSource(outcomes: (1...20).map { .success($0) })
        let scheduler = MonitoringScheduler(clock: clock, source: source, sink: sink)

        await scheduler.apply(.running(.seconds(1)))
        // 아직 deadline(1초)에 도달하기 전에 곧바로 다음 세대로 교체합니다.
        await scheduler.apply(.running(.seconds(1)))

        await clock.advance(by: .seconds(1))
        await waitUntil { await sink.samples.count >= 1 }

        // 이전 generation의 결과는 저장되지 않고, 살아있는 새 generation의 결과만 하나 저장됩니다.
        #expect(await sink.samples.count == 1)
        #expect(await sink.samples.first?.value == 1) // 새 generation이 처음부터 다시 outcomes를 소비
    }

    @Test func providerFailureDoesNotProduceZeroSampleAndSchedulerContinues() async {
        let clock = ManualMonotonicClock()
        let sink = MemorySampleSink<Int>()
        let source = MemoryScheduledSampleSource(outcomes: [.failure(MemoryScheduledSampleSource.Failure.injected), .success(42)])
        let scheduler = MonitoringScheduler(clock: clock, source: source, sink: sink)

        await scheduler.apply(.running(.seconds(1)))

        await clock.advance(by: .seconds(1)) // 첫 실행 -> 실패
        for _ in 0..<200 { await Task.yield() }
        #expect(await sink.samples.isEmpty) // 실패가 0 샘플로 바뀌지 않음

        await clock.advance(by: .seconds(1)) // 두 번째 실행 -> 성공
        await waitUntil { await sink.samples.count >= 1 }
        #expect(await sink.values == [42])
    }

    /// 성공 뒤에 실패가 와도, 실패가 직전 성공값을 재사용해 채워 넣는 식으로 "샘플 개수"만 맞추지 않는지
    /// 확인합니다. 성공 1회 + 실패 1회 뒤에는 여전히 성공 샘플 하나만 있어야 합니다.
    @Test func providerFailureAfterSuccessDoesNotFabricateAnAdditionalSample() async {
        let clock = ManualMonotonicClock()
        let sink = MemorySampleSink<Int>()
        let source = MemoryScheduledSampleSource(outcomes: [
            .success(1),
            .failure(MemoryScheduledSampleSource.Failure.injected),
        ])
        let scheduler = MonitoringScheduler(clock: clock, source: source, sink: sink)

        await scheduler.apply(.running(.seconds(1)))

        await clock.advance(by: .seconds(1)) // 첫 실행 -> 성공(1)
        await waitUntil { await sink.samples.count >= 1 }
        #expect(await sink.values == [1])

        await clock.advance(by: .seconds(1)) // 두 번째 실행 -> 실패
        for _ in 0..<200 { await Task.yield() }
        #expect(await sink.values == [1]) // 직전 성공값을 재사용한 추가 샘플이 없어야 함
    }

    @Test func repeatedApplyWithSameScheduleWouldRestartWork() async {
        // MonitoringScheduler.apply(_:) 자체는 호출될 때마다 항상 작업을 재시작합니다.
        // 「같은 일정 반복에도 중복 수집이 없다」는 보장은 MonitoringLifecycleStore가
        // 같은 결과일 때 apply를 다시 호출하지 않는 데서 나오지, Scheduler 내부에서 막는 것이 아닙니다.
        // 이 테스트는 그 경계를 고정합니다: Scheduler에 같은 일정을 두 번 apply하면
        // applyCallCount가 그대로 2가 되어야 합니다(Scheduler가 스스로 중복을 걸러내지 않음).
        let clock = ManualMonotonicClock()
        let sink = MemorySampleSink<Int>()
        let source = MemoryScheduledSampleSource(outcomes: [.success(1)])
        let scheduler = MonitoringScheduler(clock: clock, source: source, sink: sink)

        await scheduler.apply(.running(.seconds(1)))
        await scheduler.apply(.running(.seconds(1)))

        #expect(await scheduler.applyCallCount == 2)
    }
}

// MARK: - 메모리 SystemLifecycleSource를 이용한 통합 검증

/// task-003 접근 조건: 화면을 볼 수 없는 세 신호와 전력·팝오버 입력을 메모리 `SystemLifecycleSource`로 주입해
/// 실제 OS 어댑터 없이 두 축의 일정 적용까지 이어지는 흐름을 검증합니다.
struct MemorySystemLifecycleSourceIntegrationTests {

    @MainActor
    @Test func memorySourceSnapshotsDriveBothAxisSchedulesAcrossAllSignals() async {
        let memorySource = MemorySystemLifecycleSource(initialLowPowerMode: false, initialScreenLockState: .unlocked)
        let subscription = memorySource.start()

        var received: [SystemLifecycleSnapshot] = [subscription.initial]
        let collector = Task { @MainActor in
            for await snapshot in subscription.updates {
                received.append(snapshot)
            }
        }

        let clock = ManualMonotonicClock()
        let systemSink = MemorySampleSink<Int>()
        let systemScheduler = MonitoringScheduler(
            clock: clock,
            source: MemoryScheduledSampleSource(outcomes: []),
            sink: systemSink
        )
        let processSink = MemorySampleSink<Int>()
        let processScheduler = MonitoringScheduler(
            clock: clock,
            source: MemoryScheduledSampleSource(outcomes: []),
            sink: processSink
        )
        let store = MonitoringLifecycleStore(
            definition: .m2,
            systemMetricsTarget: systemScheduler,
            processSurveyTarget: processScheduler
        )

        // 초기 snapshot(unlocked, normal, 화면 켜짐, 세션 활성)을 store에 반영합니다.
        await store.update(.systemSnapshot(subscription.initial))
        await store.update(.popoverPresented(false))
        #expect(await systemScheduler.applyCallCount == 1) // 시스템 2초 / 프로세스 5초
        #expect(await processScheduler.applyCallCount == 1)

        await store.update(.popoverPresented(true))
        #expect(await systemScheduler.applyCallCount == 2) // 시스템 1초 / 프로세스 2초
        #expect(await processScheduler.applyCallCount == 2)

        memorySource.sendLowPowerMode(true)
        await waitUntil { received.count >= 2 }
        await store.update(.systemSnapshot(received[1]))
        #expect(await systemScheduler.applyCallCount == 3) // 시스템 2초 / 프로세스 4초
        #expect(await processScheduler.applyCallCount == 3)

        memorySource.sendDisplayAsleep(true)
        await waitUntil { received.count >= 3 }
        await store.update(.systemSnapshot(received[2]))
        #expect(await systemScheduler.applyCallCount == 4) // 디스플레이 슬립 -> 두 축 paused
        #expect(await processScheduler.applyCallCount == 4)

        memorySource.sendSessionActive(false)
        await waitUntil { received.count >= 4 }
        await store.update(.systemSnapshot(received[3]))
        // 이미 paused이므로 다른 신호가 더해져도(여전히 paused) apply가 다시 불리지 않습니다.
        #expect(await systemScheduler.applyCallCount == 4)
        #expect(await processScheduler.applyCallCount == 4)

        memorySource.sendDisplayAsleep(false)
        await waitUntil { received.count >= 5 }
        await store.update(.systemSnapshot(received[4]))
        // 세션이 아직 비활성이므로 디스플레이만 깨어나도 재개되지 않습니다.
        #expect(await systemScheduler.applyCallCount == 4)
        #expect(await processScheduler.applyCallCount == 4)

        memorySource.sendSessionActive(true)
        await waitUntil { received.count >= 6 }
        await store.update(.systemSnapshot(received[5]))
        #expect(await systemScheduler.applyCallCount == 5) // 세 신호가 모두 풀려 lowPower 열림으로 재적용
        #expect(await processScheduler.applyCallCount == 5)

        memorySource.sendScreenLockState(.locked)
        await waitUntil { received.count >= 7 }
        await store.update(.systemSnapshot(received[6]))
        #expect(await systemScheduler.applyCallCount == 6) // locked -> 두 축 paused
        #expect(await processScheduler.applyCallCount == 6)

        collector.cancel()
    }
}
