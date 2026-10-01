import AppKit
import Foundation
import Testing
@testable import ResourceRunner

private actor SuspendedSystemSink {
    let store: MonitoringSampleStore
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var entered = false

    init(store: MonitoringSampleStore) { self.store = store }

    func appendAfterSuspension(_ sample: TimestampedSample<SystemMetricsSample>,
                               context: CollectionRunContext) async -> Bool {
        entered = true
        await withCheckedContinuation { continuation = $0 }
        return await store.append(sample, context: context)
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

private actor SuspendedFirstClock: MonotonicClock {
    private let origin = ContinuousClock().now
    private var calls = 0
    private var first: CheckedContinuation<ContinuousClock.Instant, Never>?
    private(set) var firstEntered = false

    func now() async -> ContinuousClock.Instant {
        calls += 1
        if calls == 1 {
            firstEntered = true
            return await withCheckedContinuation { first = $0 }
        }
        return origin + .seconds(calls - 1)
    }

    func sleep(until deadline: ContinuousClock.Instant) async throws {}
    func releaseFirst() {
        first?.resume(returning: origin)
        first = nil
    }
}

private actor SchedulerRaceClock: MonotonicClock {
    private let origin = ContinuousClock().now
    private var nowCalls = 0
    private var sleepContinuation: CheckedContinuation<Void, Never>?
    private var oldNowContinuation: CheckedContinuation<ContinuousClock.Instant, Never>?
    private(set) var sleeping = false
    private(set) var oldNowEntered = false

    func now() async -> ContinuousClock.Instant {
        nowCalls += 1
        if nowCalls == 2 {
            oldNowEntered = true
            return await withCheckedContinuation { oldNowContinuation = $0 }
        }
        return origin + .seconds(nowCalls - 1)
    }

    func sleep(until deadline: ContinuousClock.Instant) async throws {
        sleeping = true
        try await withTaskCancellationHandler {
            await withCheckedContinuation { sleepContinuation = $0 }
            try Task.checkCancellation()
        } onCancel: {
            Task { await self.wakeOldTick() }
        }
    }

    func wakeOldTick() {
        sleepContinuation?.resume()
        sleepContinuation = nil
    }
    func releaseOldNow() {
        oldNowContinuation?.resume(returning: origin + .seconds(1))
        oldNowContinuation = nil
    }
}

private actor CountingIntSource: ScheduledSampleSource {
    private(set) var count = 0
    func sample(collectionEpoch: Int) -> Int? { count += 1; return count }
}

private actor CountingIntSink: MonitoringSampleSink {
    private(set) var count = 0
    func append(_ sample: TimestampedSample<Int>) { count += 1 }
}

private actor SuspendedRanking {
    private var continuation: CheckedContinuation<Void, Never>?
    private var calls = 0
    private(set) var entered = false
    func pauseFirst() async {
        calls += 1
        guard calls == 1 else { return }
        entered = true
        await withCheckedContinuation { continuation = $0 }
    }
    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

private actor ScheduleRecorder: CollectionScheduleTarget {
    private(set) var schedules: [CollectionSchedule] = []
    func apply(_ schedule: CollectionSchedule) { schedules.append(schedule) }
}

private actor SuspendedScheduleTarget: CollectionScheduleTarget {
    private var first: CheckedContinuation<Void, Never>?
    private(set) var firstEntered = false
    private(set) var revisions: [Int] = []

    func apply(_ schedule: CollectionSchedule) {}
    func apply(_ schedule: CollectionSchedule, revision: Int) async {
        revisions.append(revision)
        if revision == 1 {
            firstEntered = true
            await withCheckedContinuation { first = $0 }
        }
    }
    func releaseFirst() {
        first?.resume()
        first = nil
    }
}

private actor RevisionRecorder: CollectionScheduleTarget {
    private(set) var revisions: [Int] = []
    func apply(_ schedule: CollectionSchedule) {}
    func apply(_ schedule: CollectionSchedule, revision: Int) { revisions.append(revision) }
}

private final class TickSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var nextValue = 0
    func next() -> Int { lock.withLock { nextValue += 1; return nextValue } }
}

private struct BaselineProbeCPU: CPUSystemMetricsCollecting {
    let ticks: TickSequence
    private var baseline: Int?
    init(ticks: TickSequence) { self.ticks = ticks }
    mutating func resetBaseline() { baseline = nil }
    mutating func collect(at timestamp: ContinuousClock.Instant) throws(CollectorFailure) -> CPUSystemMetrics? {
        let previous = baseline
        baseline = ticks.next()
        guard let previous else { return nil }
        return CPUSystemMetrics(overallUsage: Double(previous), userRatio: Double(previous),
            systemRatio: 0, idleRatio: 100 - Double(previous), coreUsages: [Double(previous)],
            loadAverage: LoadAverage(oneMinute: 0, fiveMinutes: 0, fifteenMinutes: 0))
    }
}

private struct InstantProbeMemory: MemorySystemMetricsCollecting {
    func collect() throws(CollectorFailure) -> MemorySystemMetrics {
        MemorySystemMetrics(totalPhysicalBytes: 100, usedBytes: 50, appBytes: 30,
            wiredBytes: 10, compressedBytes: 10, cachedBytes: 5,
            swapUsedBytes: 2, pressureLevel: .normal)
    }
}

private struct EmptySurveyProbe: ProcessSurveyCollecting {
    mutating func survey() throws(CollectorFailure) -> ProcessSurveyReport {
        ProcessSurveyReport(samples: [], unreadableCount: 0)
    }
}

private func waitForAdmission(_ condition: () async -> Bool) async {
    for _ in 0..<10_000 {
        if await condition() { return }
        await Task.yield()
    }
}

struct CollectionAdmissionTests {
    private func runningGate() -> CollectionAdmission {
        let gate = CollectionAdmission()
        gate.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
        _ = gate.advance(.systemMetrics)
        return gate
    }

    @Test func reverseResponsesAreRejectedAtEveryPhase() throws {
        let gate = runningGate()
        let older = try #require(gate.issue(.systemMetrics))
        let newer = try #require(gate.issue(.systemMetrics))
        let time = ContinuousClock().now
        var source = 0
        var store = 0
        var display = 0
        #expect(gate.admit(newer, phase: .source, timestamp: time + .seconds(1)) { source += 1 } != nil)
        #expect(gate.admit(older, phase: .source, timestamp: time) { source += 1 } == nil)
        #expect(gate.admit(newer, phase: .store, timestamp: time + .seconds(1)) { store += 1 } != nil)
        #expect(gate.admit(older, phase: .store, timestamp: time) { store += 1 } == nil)
        #expect(gate.admit(newer, phase: .display, timestamp: time + .seconds(1)) { display += 1 } != nil)
        #expect(gate.admit(older, phase: .display, timestamp: time) { display += 1 } == nil)
        #expect((source, store, display) == (1, 1, 1))
    }

    @Test func stopResumeInvalidatesOldTokensAndNormalGenerationKeepsEpoch() throws {
        let gate = runningGate()
        let old = try #require(gate.issue(.systemMetrics))
        let time = ContinuousClock().now
        gate.transition(CollectionBoundary(revision: 1, sequence: 1, epoch: 1, stopped: true))
        #expect(!gate.isCurrent(old))
        #expect(gate.issue(.systemMetrics) == nil)
        gate.transition(CollectionBoundary(revision: 2, sequence: 2, epoch: 2, stopped: false))
        _ = gate.advance(.systemMetrics)
        let resumed = try #require(gate.issue(.systemMetrics))
        #expect(resumed.epoch == 2)
        #expect(gate.admit(old, phase: .source, timestamp: time) { true } == nil)
        #expect(gate.admit(resumed, phase: .store, timestamp: time) { true } == true)
        _ = gate.advance(.systemMetrics)
        let changedInterval = try #require(gate.issue(.systemMetrics))
        #expect(changedInterval.epoch == resumed.epoch)
        #expect(!gate.isCurrent(resumed))
        #expect(gate.isCurrent(changedInterval))
    }

    @Test func lateLifecycleApplyCannotOverwriteNewProcessPlan() async {
        let gate = CollectionAdmission()
        let system = SuspendedScheduleTarget()
        let process = RevisionRecorder()
        let lifecycle = MonitoringLifecycleStore(definition: .m2,
            systemMetricsTarget: system, processSurveyTarget: process, admission: gate)
        let initial = SystemLifecycleSnapshot(revision: 0, lowPowerMode: false,
            screenLockState: .unlocked, displayAsleep: false, sessionActive: true)
        let oldUpdate = Task { await lifecycle.update(.systemSnapshot(initial)) }
        await waitForAdmission { await system.firstEntered }
        #expect(await system.firstEntered)
        await lifecycle.update(.popoverPresented(true))
        #expect(await process.revisions == [2])
        #expect(gate.planRevision(for: .processSurvey) == 2)
        await system.releaseFirst()
        await oldUpdate.value
        #expect(await process.revisions == [2])
    }

    @Test func boundaryDuringSinkSuspensionLeavesLatestAndHistoryUntouched() async throws {
        let gate = runningGate()
        let store = MonitoringSampleStore(admission: gate)
        let delayed = SuspendedSystemSink(store: store)
        let context = try #require(gate.issue(.systemMetrics))
        let cpu = CPUSystemMetrics(overallUsage: 20, userRatio: 10, systemRatio: 10,
                                   idleRatio: 80, coreUsages: [20],
                                   loadAverage: LoadAverage(oneMinute: 0, fiveMinutes: 0, fifteenMinutes: 0))
        let memory = MemorySystemMetrics(totalPhysicalBytes: 100, usedBytes: 50, appBytes: 30,
                                         wiredBytes: 10, compressedBytes: 10, cachedBytes: 5,
                                         swapUsedBytes: 2, pressureLevel: .normal)
        let sample = TimestampedSample(timestamp: ContinuousClock().now,
            value: SystemMetricsSample(cpu: .success(cpu), memory: .success(memory)),
            collectionEpoch: context.epoch, context: context)
        let append = Task { await delayed.appendAfterSuspension(sample, context: context) }
        await waitForAdmission { await delayed.entered }
        #expect(await delayed.entered)
        gate.transition(CollectionBoundary(revision: 1, sequence: 1, epoch: 1, stopped: true))
        #expect(gate.currentBoundary.stopped)
        #expect(!gate.isCurrent(context))
        #expect(await store.append(sample, context: context) == false)
        await delayed.resume()
        #expect(await append.value == false)
        let snapshot = await store.snapshot()
        #expect(snapshot.latest == nil)
        #expect(snapshot.recentHistory.isEmpty)
    }

    @Test func olderClockResponseCannotOverwriteNewerCPUBaseline() async throws {
        let gate = runningGate()
        let clock = SuspendedFirstClock()
        let source = SystemMetricsSampleSource(cpuCollector: BaselineProbeCPU(ticks: TickSequence()),
            memoryCollector: InstantProbeMemory(), clock: clock, admission: gate)
        let older = try #require(gate.issue(.systemMetrics))
        let newer = try #require(gate.issue(.systemMetrics))
        let delayed = Task { await source.sample(context: older) }
        await waitForAdmission { await clock.firstEntered }
        let firstAccepted = await source.sample(context: newer)
        if case .success(nil) = firstAccepted?.cpu {} else { Issue.record("새 요청의 첫 CPU tick은 기준점 전용이어야 합니다") }
        await clock.releaseFirst()
        #expect(await delayed.value == nil)
        let third = try #require(gate.issue(.systemMetrics))
        let thirdValue = await source.sample(context: third)
        if case .success(let cpu?) = thirdValue?.cpu {
            #expect(cpu.overallUsage == 1)
        } else { Issue.record("이전 응답이 baseline을 덮었거나 다음 CPU 차분이 사라졌습니다") }
    }

    @Test func processSourceAndHistoryHonorTheSameBoundary() async throws {
        let gate = CollectionAdmission()
        gate.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
        _ = gate.advance(.processSurvey)
        let source = ProcessSurveySampleSource(collector: EmptySurveyProbe(), admission: gate)
        let history = ProcessHistoryStore(admission: gate)
        let valid = try #require(gate.issue(.processSurvey))
        let value = try #require(await source.sample(context: valid))
        #expect(await history.append(TimestampedSample(timestamp: ContinuousClock().now,
            value: value, context: valid), context: valid))
        #expect(await history.rankingInput().surveyFailed == false)

        let stale = try #require(gate.issue(.processSurvey))
        gate.transition(CollectionBoundary(revision: 1, sequence: 1, epoch: 1, stopped: true))
        #expect(await source.sample(context: stale) == nil)
        let failure = ProcessSurveySample(result: .failure(CollectorFailure(metric: .process,
            cause: .systemCall(name: "test", code: -1))))
        #expect(await history.append(TimestampedSample(timestamp: ContinuousClock().now,
            value: failure, context: stale), context: stale) == false)
        #expect(await history.rankingInput().surveyFailed == false)
    }

    @Test func processCPUBaselineRestartsOnNewEpoch() async throws {
        let history = ProcessHistoryStore()
        let id = ProcessIdentity(pid: 42, startTime: 1)
        let origin = ContinuousClock().now
        func sample(cpuTime: UInt64) -> ProcessSurveySample {
            ProcessSurveySample(result: .success(ProcessSurveyReport(samples: [
                ProcessSample(identity: id, executablePath: "/bin/test", uid: 501, parentPID: 1,
                    cpuTimeNanoseconds: cpuTime, residentBytes: 100, isTranslated: false)
            ], unreadableCount: 0)))
        }
        await history.append(TimestampedSample(timestamp: origin, value: sample(cpuTime: 100), collectionEpoch: 0))
        await history.append(TimestampedSample(timestamp: origin + .seconds(2), value: sample(cpuTime: 200), collectionEpoch: 0))
        #expect(try #require(await history.snapshot().first).recentValues.last?.cpuUsagePercent != nil)
        await history.append(TimestampedSample(timestamp: origin + .seconds(4), value: sample(cpuTime: 300), collectionEpoch: 1))
        #expect(try #require(await history.snapshot().first).recentValues.last?.cpuUsagePercent == nil)
    }

    @Test func oldSchedulerWaitingInClockCannotIssueNewGenerationToken() async {
        let gate = runningGate()
        let clock = SchedulerRaceClock()
        let source = CountingIntSource()
        let sink = CountingIntSink()
        let scheduler = MonitoringScheduler(clock: clock, source: source, sink: sink,
            admission: gate, axis: .systemMetrics)
        await scheduler.apply(.running(.seconds(1)))
        await waitForAdmission { await clock.sleeping }
        await clock.wakeOldTick()
        await waitForAdmission { await clock.oldNowEntered }
        await scheduler.apply(.running(.seconds(2)))
        await clock.releaseOldNow()
        for _ in 0..<100 { await Task.yield() }
        #expect(await source.count == 0)
        #expect(await sink.count == 0)
        await scheduler.apply(.paused)
    }
}

@MainActor
struct CollectionBoundaryDisplayTests {
    @Test func workspaceSleepNotificationsReachTheCombinedSnapshot() async throws {
        let workspace = NotificationCenter()
        let observer = SystemLifecycleObserver(notificationCenter: NotificationCenter(),
            workspaceNotificationCenter: workspace, readLowPowerMode: { false },
            readInitialScreenLockState: { .unlocked }, registerScreenLockObserver: { _ in })
        let subscription = observer.start()
        var iterator = subscription.updates.makeAsyncIterator()
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        let asleep = try #require(await iterator.next())
        #expect(asleep.systemAsleep)
        #expect(asleep.boundarySequence == 1)
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        let awake = try #require(await iterator.next())
        #expect(!awake.systemAsleep)
        #expect(awake.boundarySequence == 2)
    }

    @Test func newestSnapshotStillCarriesStopResumeBoundary() async {
        let initial = SystemLifecycleSnapshot(revision: 0, lowPowerMode: false,
            screenLockState: .unlocked, displayAsleep: false, sessionActive: true)
        var continuation: AsyncStream<SystemLifecycleSnapshot>.Continuation!
        let stream = AsyncStream<SystemLifecycleSnapshot>(bufferingPolicy: .bufferingNewest(1)) {
            continuation = $0
        }
        let producer = CombinedSnapshotProducer(initial: initial, continuation: continuation)
        producer.apply(.screenLock(.locked))
        producer.apply(.screenLock(.unlocked))
        var iterator = stream.makeAsyncIterator()
        let latest = await iterator.next()
        #expect(latest?.revision == 2)
        #expect(latest?.screenLockState == .unlocked)
        #expect(latest?.boundarySequence == 2)

        producer.apply(.screenLock(.locked))
        producer.apply(.willSleep)
        producer.apply(.didWake)
        #expect(producer.currentSnapshot.screenLockState == .locked)
        #expect(producer.currentSnapshot.systemAsleep == false)
        #expect(producer.currentSnapshot.boundarySequence == 5)
    }

    @Test func coalescedRunningSnapshotRestartsBothAxesAtNewEpoch() async throws {
        let gate = CollectionAdmission()
        let system = ScheduleRecorder()
        let process = ScheduleRecorder()
        let lifecycle = MonitoringLifecycleStore(definition: .m2,
            systemMetricsTarget: system, processSurveyTarget: process, admission: gate)
        let initial = SystemLifecycleSnapshot(revision: 0, lowPowerMode: false,
            screenLockState: .unlocked, displayAsleep: false, sessionActive: true)
        await lifecycle.update(.systemSnapshot(initial))
        #expect(gate.currentBoundary.sequence == 0)
        var continuation: AsyncStream<SystemLifecycleSnapshot>.Continuation!
        let stream = AsyncStream<SystemLifecycleSnapshot>(bufferingPolicy: .bufferingNewest(1)) { continuation = $0 }
        let producer = CombinedSnapshotProducer(initial: initial, continuation: continuation)
        producer.apply(.screenLock(.locked))
        producer.apply(.screenLock(.unlocked))
        var iterator = stream.makeAsyncIterator()
        let latest = try #require(await iterator.next())
        await lifecycle.update(.systemSnapshot(latest))
        #expect(gate.currentBoundary.sequence == 2)
        #expect(gate.currentBoundary.epoch == 2)
        #expect(gate.currentBoundary.stopped == false)
        #expect(await system.schedules.count == 2)
        #expect(await process.schedules.count == 2)
        let dashboard = DashboardPresentationStore()
        dashboard.observe(gate.currentBoundary, admission: gate)
        if case .stopped = dashboard.memoryCard {} else {
            Issue.record("중지 이벤트가 병합돼도 최종 running 경계가 카드의 중단을 보존해야 합니다")
        }
    }

    @Test func delayedConsumerAndReorderedStopCannotReverseRealCards() async throws {
        let gate = CollectionAdmission()
        let dashboard = DashboardPresentationStore()
        let store = MonitoringSampleStore(admission: gate)
        let rankingDelay = SuspendedRanking()
        let processes = ProcessHistoryStore(beforeRankingInput: { await rankingDelay.pauseFirst() })
        let consumer = ApplicationCoordinator.consumeSystemMetrics(store,
            into: CharacterStateSource(), dashboard: dashboard,
            processHistory: processes, admission: gate)
        defer { consumer.cancel() }

        gate.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
        _ = gate.advance(.systemMetrics)
        let old = try #require(gate.issue(.systemMetrics))
        let memory = MemorySystemMetrics(totalPhysicalBytes: 100, usedBytes: 50,
            appBytes: 30, wiredBytes: 10, compressedBytes: 10, cachedBytes: 5,
            swapUsedBytes: 2, pressureLevel: .normal)
        func sample(_ context: CollectionRunContext, at timestamp: ContinuousClock.Instant) -> TimestampedSample<SystemMetricsSample> {
            TimestampedSample(timestamp: timestamp,
                value: SystemMetricsSample(cpu: .success(nil), memory: .success(memory)),
                collectionEpoch: context.epoch, context: context)
        }
        let time = ContinuousClock().now
        #expect(await store.append(sample(old, at: time), context: old))
        await waitForAdmission { await rankingDelay.entered }

        let stop = CollectionBoundary(revision: 1, sequence: 1, epoch: 1, stopped: true)
        gate.transition(stop)
        dashboard.observe(stop, admission: gate)
        if case .stopped = dashboard.memoryCard {} else { Issue.record("중지 상태가 반영되지 않았습니다") }

        let resume = CollectionBoundary(revision: 2, sequence: 2, epoch: 2, stopped: false)
        gate.transition(resume)
        _ = gate.advance(.systemMetrics)
        dashboard.observe(resume, admission: gate)
        let context = try #require(gate.issue(.systemMetrics))
        #expect(await store.append(sample(context, at: time + .seconds(2)), context: context))
        await rankingDelay.resume()
        for _ in 0..<10_000 {
            if case .normal = dashboard.memoryCard { break }
            await Task.yield()
        }
        if case .normal = dashboard.memoryCard {} else { Issue.record("새 경계의 실제 Memory 성공이 표시되지 않았습니다") }
        dashboard.observe(stop, admission: gate)
        if case .normal = dashboard.memoryCard {} else { Issue.record("늦은 중지가 새 성공 카드를 뒤집었습니다") }

        let nextStop = CollectionBoundary(revision: 3, sequence: 3, epoch: 3, stopped: true)
        gate.transition(nextStop)
        dashboard.observe(nextStop, admission: gate)
        let before = await store.snapshot()
        #expect(await store.append(sample(context, at: time + .seconds(3)), context: context) == false)
        let after = await store.snapshot()
        #expect(after.latest?.context == before.latest?.context)
        #expect(after.recentHistory.count == before.recentHistory.count)
        if case .stopped = dashboard.memoryCard {} else { Issue.record("중지 뒤 이전 성공이 카드를 되돌렸습니다") }
    }
}
