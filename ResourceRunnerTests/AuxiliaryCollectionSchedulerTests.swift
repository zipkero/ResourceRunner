import Foundation
import Testing
@testable import ResourceRunner

private actor AuxiliaryIntSource: ScheduledSampleSource {
    private let blockFirst: Bool
    private var first: CheckedContinuation<Void, Never>?
    private(set) var calls = 0
    private(set) var contexts: [CollectionRunContext] = []

    init(blockFirst: Bool = false) { self.blockFirst = blockFirst }

    func sample(collectionEpoch: Int) async -> Int? {
        calls += 1
        let call = calls
        if blockFirst && calls == 1 {
            await withCheckedContinuation { first = $0 }
        }
        return call
    }

    func sample(context: CollectionRunContext) async -> Int? {
        contexts.append(context)
        return await sample(collectionEpoch: context.epoch)
    }

    func releaseFirst() {
        first?.resume()
        first = nil
    }
}

private actor AuxiliaryIntSink: MonitoringSampleSink {
    private let admission: CollectionAdmission
    private(set) var samples: [TimestampedSample<Int>] = []
    private(set) var replayedContexts: [CollectionRunContext] = []

    init(admission: CollectionAdmission) { self.admission = admission }

    func append(_ sample: TimestampedSample<Int>) { samples.append(sample) }
    func append(_ sample: TimestampedSample<Int>, context: CollectionRunContext) async -> Bool {
        admission.admit(context, phase: .store, timestamp: sample.timestamp) {
            samples.append(sample)
            return true
        } ?? false
    }
    func replayCached(_ sample: TimestampedSample<Int>, context: CollectionRunContext) async -> Bool {
        guard admission.isCurrent(context) else { return false }
        replayedContexts.append(context)
        return true
    }
}

private actor AxisScheduleRecorder: CollectionScheduleTarget {
    private(set) var schedules: [CollectionSchedule] = []
    func apply(_ schedule: CollectionSchedule) { schedules.append(schedule) }
}

private func awaitCondition(_ condition: () async -> Bool) async {
    for _ in 0..<10_000 {
        if await condition() { return }
        await Task.yield()
    }
}

struct AuxiliaryCollectionSchedulerTests {
    private func runningGate() -> CollectionAdmission {
        let gate = CollectionAdmission()
        gate.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
        return gate
    }

    @Test func reversedABAPlanDeliveryRebindsCacheAndRefresh() async {
        let gate = runningGate()
        let clock = ManualMonotonicClock()
        let source = AuxiliaryIntSource()
        let sink = AuxiliaryIntSink(admission: gate)
        let scheduler = AuxiliaryCollectionScheduler(clock: clock, source: source, sink: sink,
            admission: gate, axis: .networkMetadata)
        let original = CollectionSchedule.running(.seconds(60))
        let alternate = CollectionSchedule.running(.seconds(30))

        gate.setPlan(original, revision: 1, for: .networkMetadata)
        await scheduler.apply(original, revision: 1)
        await awaitCondition { await sink.samples.count == 1 }
        #expect(await sink.samples.first?.context?.planRevision == 1)

        // B의 target 전달만 지연시키고 C를 먼저 적용합니다.
        gate.setPlan(alternate, revision: 2, for: .networkMetadata)
        gate.setPlan(original, revision: 3, for: .networkMetadata)
        await scheduler.apply(original, revision: 3)
        await scheduler.apply(alternate, revision: 2)
        await scheduler.apply(original, revision: 3)
        await awaitCondition { await sink.replayedContexts.count == 1 }
        #expect(await sink.replayedContexts.map(\.planRevision) == [3])
        #expect(await source.calls == 1)

        await scheduler.requestRefresh()
        await awaitCondition { await sink.samples.count == 2 }
        #expect(await sink.samples.map { $0.context?.planRevision } == [1, 3])
        #expect(await scheduler.startedQueryCount == 2)
        await scheduler.apply(.paused)
    }

    @Test func reversedABAPlanDeliveryRunsPendingRefreshWithNewestLease() async {
        let gate = runningGate()
        let clock = ManualMonotonicClock()
        let source = AuxiliaryIntSource(blockFirst: true)
        let sink = AuxiliaryIntSink(admission: gate)
        let scheduler = AuxiliaryCollectionScheduler(clock: clock, source: source, sink: sink,
            admission: gate, axis: .storageMetadata)
        let original = CollectionSchedule.running(.seconds(60))
        let alternate = CollectionSchedule.running(.seconds(30))

        gate.setPlan(original, revision: 1, for: .storageMetadata)
        await scheduler.apply(original, revision: 1)
        await awaitCondition { await source.calls == 1 }
        gate.setPlan(alternate, revision: 2, for: .storageMetadata)
        gate.setPlan(original, revision: 3, for: .storageMetadata)
        await scheduler.apply(original, revision: 3)
        await scheduler.apply(alternate, revision: 2)
        await scheduler.apply(original, revision: 3)
        #expect(await scheduler.startedQueryCount == 1)
        await source.releaseFirst()
        await awaitCondition { await sink.samples.count == 1 }
        #expect(await source.contexts.map(\.planRevision) == [1, 3])
        #expect(await sink.samples.map { $0.context?.planRevision } == [3])
        #expect(await scheduler.startedQueryCount == 2)
        await scheduler.apply(.paused)
    }

    @Test func allProfileIntervalsAndUnobservableSignalsMatchApprovedTable() {
        let rows: [(RefreshProfile, Bool, Bool, [Duration])] = [
            (.fast, false, true, [.milliseconds(500), .seconds(1), .seconds(30)]),
            (.fast, false, false, [.seconds(1), .seconds(5), .seconds(60)]),
            (.standard, false, true, [.seconds(1), .seconds(2), .seconds(30)]),
            (.standard, false, false, [.seconds(2), .seconds(5), .seconds(60)]),
            (.energySaving, false, true, [.seconds(2), .seconds(4), .seconds(30)]),
            (.energySaving, false, false, [.seconds(5), .seconds(8), .seconds(60)]),
            (.maximumEnergySaving, false, true, [.seconds(5), .seconds(5), .seconds(30)]),
            (.maximumEnergySaving, false, false, [.seconds(10), .seconds(10), .seconds(60)]),
            (.fast, true, true, [.seconds(2), .seconds(4), .seconds(60)]),
            (.fast, true, false, [.seconds(5), .seconds(10), .seconds(120)]),
            (.standard, true, true, [.seconds(2), .seconds(4), .seconds(60)]),
            (.standard, true, false, [.seconds(5), .seconds(10), .seconds(120)]),
            (.energySaving, true, true, [.seconds(2), .seconds(4), .seconds(60)]),
            (.energySaving, true, false, [.seconds(5), .seconds(10), .seconds(120)]),
            (.maximumEnergySaving, true, true, [.seconds(5), .seconds(5), .seconds(60)]),
            (.maximumEnergySaving, true, false, [.seconds(10), .seconds(10), .seconds(120)])
        ]
        let axes: [CollectionAxis] = [.systemMetrics, .processSurvey, .networkActivity,
            .diskActivity, .networkMetadata, .storageMetadata]
        for (profile, lowPower, presented, expected) in rows {
            for lock in [ScreenLockState.unlocked, .locked, .unknown] {
                for displayAsleep in [false, true] {
                    for sessionActive in [false, true] {
                        for systemAsleep in [false, true] {
                            let lifecycle = MonitoringLifecycle(popoverPresented: presented,
                                lowPowerMode: lowPower, screenLockState: lock,
                                displayAsleep: displayAsleep, sessionActive: sessionActive,
                                systemAsleep: systemAsleep)
                            let plan = CollectionSchedulePolicy.plan(for: lifecycle,
                                definition: .profile(profile))
                            let observable = lock == .unlocked && !displayAsleep && sessionActive && !systemAsleep
                            for (index, axis) in axes.enumerated() {
                                let column = index == 1 ? expected[1] : index >= 4 ? expected[2] : expected[0]
                                #expect(plan[axis] == (observable ? .running(column) : .paused))
                            }
                        }
                    }
                }
            }
        }
    }

    @Test func allSixAxisSchedulesMatchTheApprovedTable() {
        let expected: [(Bool, Bool, [Duration])] = [
            (false, true, [.seconds(1), .seconds(2), .seconds(1), .seconds(1), .seconds(30), .seconds(30)]),
            (false, false, [.seconds(2), .seconds(5), .seconds(2), .seconds(2), .seconds(60), .seconds(60)]),
            (true, true, [.seconds(2), .seconds(4), .seconds(2), .seconds(2), .seconds(60), .seconds(60)]),
            (true, false, [.seconds(5), .seconds(10), .seconds(5), .seconds(5), .seconds(120), .seconds(120)])
        ]
        let axes: [CollectionAxis] = [.systemMetrics, .processSurvey, .networkActivity,
                                      .diskActivity, .networkMetadata, .storageMetadata]
        var checked = 0
        for (lowPower, presented, intervals) in expected {
            for lock in [ScreenLockState.unlocked, .locked, .unknown] {
                for displayAsleep in [false, true] {
                    for sessionActive in [false, true] {
                        for systemAsleep in [false, true] {
                            let lifecycle = MonitoringLifecycle(popoverPresented: presented,
                                lowPowerMode: lowPower, screenLockState: lock,
                                displayAsleep: displayAsleep, sessionActive: sessionActive,
                                systemAsleep: systemAsleep)
                            let plan = CollectionSchedulePolicy.plan(for: lifecycle, definition: .m3)
                            let observable = lock == .unlocked && !displayAsleep && sessionActive && !systemAsleep
                            for (index, axis) in axes.enumerated() {
                                #expect(plan[axis] == (observable ? .running(intervals[index]) : .paused))
                            }
                            checked += 1
                        }
                    }
                }
            }
        }
        #expect(checked == 96)
    }

    @Test func lifecycleAppliesSixTargetsAndRoutesRefreshWithoutNewBoundary() async {
        let gate = CollectionAdmission()
        let clock = ManualMonotonicClock()
        let fast = (0..<4).map { _ in AxisScheduleRecorder() }
        let networkSource = AuxiliaryIntSource()
        let storageSource = AuxiliaryIntSource()
        let networkSink = AuxiliaryIntSink(admission: gate)
        let storageSink = AuxiliaryIntSink(admission: gate)
        let network = AuxiliaryCollectionScheduler(clock: clock, source: networkSource,
            sink: networkSink, admission: gate, axis: .networkMetadata)
        let storage = AuxiliaryCollectionScheduler(clock: clock, source: storageSource,
            sink: storageSink, admission: gate, axis: .storageMetadata)
        let lifecycle = MonitoringLifecycleStore(definition: .m3,
            systemMetricsTarget: fast[0], processSurveyTarget: fast[1],
            networkActivityTarget: fast[2], diskActivityTarget: fast[3],
            networkMetadataTarget: network, storageMetadataTarget: storage, admission: gate)
        let initial = SystemLifecycleSnapshot(revision: 0, lowPowerMode: false,
            screenLockState: .unlocked, displayAsleep: false, sessionActive: true)
        await lifecycle.update(.systemSnapshot(initial))
        await awaitCondition {
            let networkCount = await networkSink.samples.count
            let storageCount = await storageSink.samples.count
            return networkCount == 1 && storageCount == 1
        }
        #expect(await fast[0].schedules == [.running(.seconds(2))])
        #expect(await fast[1].schedules == [.running(.seconds(5))])
        #expect(await fast[2].schedules == [.running(.seconds(2))])
        #expect(await fast[3].schedules == [.running(.seconds(2))])
        await lifecycle.requestAuxiliaryRefresh(.networkMetadata)
        await lifecycle.requestAuxiliaryRefresh(.storageMetadata)
        await awaitCondition {
            let networkCount = await networkSink.samples.count
            let storageCount = await storageSink.samples.count
            return networkCount == 2 && storageCount == 2
        }
        await lifecycle.update(.popoverPresented(true))
        #expect(await fast[0].schedules.last == .running(.seconds(1)))
        #expect(await fast[1].schedules.last == .running(.seconds(2)))
        #expect(await fast[2].schedules.last == .running(.seconds(1)))
        #expect(await fast[3].schedules.last == .running(.seconds(1)))
        #expect(gate.currentBoundary.epoch == 0)
        #expect(await networkSink.samples.count == 2)
        await lifecycle.update(.popoverPresented(true))
        #expect(await fast[0].schedules.count == 2)
        await lifecycle.update(.systemSnapshot(SystemLifecycleSnapshot(revision: 1,
            lowPowerMode: false, screenLockState: .locked, displayAsleep: false,
            sessionActive: true, boundarySequence: 1)))
    }

    @Test func immediateCacheFirstAndStaleOpenRefresh() async {
        let gate = runningGate()
        let clock = ManualMonotonicClock()
        let source = AuxiliaryIntSource()
        let sink = AuxiliaryIntSink(admission: gate)
        let scheduler = AuxiliaryCollectionScheduler(clock: clock, source: source, sink: sink,
            admission: gate, axis: .networkMetadata)
        await scheduler.apply(.running(.seconds(60)))
        await awaitCondition { await sink.samples.count == 1 }
        #expect(await sink.samples.count == 1)
        #expect(await scheduler.cachedSample?.value == 1)

        await clock.advance(by: .seconds(20))
        await scheduler.apply(.running(.seconds(30)))
        #expect(await source.calls == 1)
        #expect(await scheduler.cachedSample?.value == 1)

        await scheduler.apply(.running(.seconds(60)))
        await clock.advance(by: .seconds(20))
        await scheduler.apply(.running(.seconds(30)))
        await awaitCondition { await sink.samples.count == 2 }
        #expect(await sink.samples.map(\.value) == [1, 2])
        #expect(await scheduler.cachedSample?.value == 2)
        await scheduler.apply(.paused)
    }

    @Test func mergedRequestsAndMissedDeadlinesNeverOverlap() async {
        let gate = runningGate()
        let clock = ManualMonotonicClock()
        let source = AuxiliaryIntSource(blockFirst: true)
        let sink = AuxiliaryIntSink(admission: gate)
        let scheduler = AuxiliaryCollectionScheduler(clock: clock, source: source, sink: sink,
            admission: gate, axis: .storageMetadata)
        await scheduler.apply(.running(.seconds(30)))
        await awaitCondition { await source.calls == 1 }
        await scheduler.requestRefresh()
        await scheduler.requestRefresh()
        await clock.advance(by: .seconds(200))
        await scheduler.requestRefresh()
        #expect(await scheduler.startedQueryCount == 1)
        await source.releaseFirst()
        await awaitCondition { await sink.samples.count == 2 }
        #expect(await scheduler.startedQueryCount == 2)
        #expect(await sink.samples.map(\.value) == [1, 2])
        await scheduler.apply(.paused)
    }

    @Test func pausedRequestsRunOnceAfterResumeAndOldResultIsDiscarded() async {
        let gate = runningGate()
        let clock = ManualMonotonicClock()
        let source = AuxiliaryIntSource(blockFirst: true)
        let sink = AuxiliaryIntSink(admission: gate)
        let scheduler = AuxiliaryCollectionScheduler(clock: clock, source: source, sink: sink,
            admission: gate, axis: .networkMetadata)
        await scheduler.apply(.running(.seconds(30)))
        await awaitCondition { await source.calls == 1 }
        gate.transition(CollectionBoundary(revision: 1, sequence: 1, epoch: 1, stopped: true))
        await scheduler.apply(.paused)
        await scheduler.requestRefresh()
        await scheduler.requestRefresh()
        await source.releaseFirst()
        await awaitCondition { await scheduler.startedQueryCount == 1 }
        #expect(await sink.samples.isEmpty)
        gate.transition(CollectionBoundary(revision: 2, sequence: 2, epoch: 2, stopped: false))
        await scheduler.apply(.running(.seconds(30)))
        await awaitCondition { await sink.samples.count == 1 }
        #expect(await sink.samples.map(\.value) == [2])
        #expect(await scheduler.startedQueryCount == 2)
        await scheduler.apply(.paused)
    }

    @Test func slowMetadataSourceDoesNotDelayFourFastAxes() async {
        let gate = runningGate()
        let clock = ManualMonotonicClock()
        let slow = AuxiliaryIntSource(blockFirst: true)
        let slowSink = AuxiliaryIntSink(admission: gate)
        let metadata = AuxiliaryCollectionScheduler(clock: clock, source: slow, sink: slowSink,
            admission: gate, axis: .networkMetadata)
        let fastSources = (0..<4).map { _ in AuxiliaryIntSource() }
        let fastSinks = (0..<4).map { _ in AuxiliaryIntSink(admission: gate) }
        let axes: [CollectionAxis] = [.systemMetrics, .processSurvey, .networkActivity, .diskActivity]
        let schedulers = (0..<4).map { index in
            MonitoringScheduler(clock: clock, source: fastSources[index], sink: fastSinks[index],
                admission: gate, axis: axes[index])
        }
        gate.setPlanRevision(1, for: .networkMetadata)
        for axis in axes { gate.setPlanRevision(1, for: axis) }
        await metadata.apply(.running(.seconds(30)), revision: 1)
        for (index, scheduler) in schedulers.enumerated() {
            await scheduler.apply(.running(index == 1 ? .seconds(2) : .seconds(1)), revision: 1)
        }
        await awaitCondition { await slow.calls == 1 }
        await clock.advance(by: .seconds(2))
        await awaitCondition {
            for sink in fastSinks where await sink.samples.isEmpty { return false }
            return true
        }
        #expect(await slowSink.samples.isEmpty)
        for sink in fastSinks { #expect(await sink.samples.count >= 1) }
        await slow.releaseFirst()
        await awaitCondition { await slowSink.samples.count == 1 }
        await metadata.apply(.paused)
        for scheduler in schedulers { await scheduler.apply(.paused) }
    }
}
