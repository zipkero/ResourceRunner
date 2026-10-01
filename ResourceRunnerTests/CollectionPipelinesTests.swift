import AppKit
import Foundation
import Testing
@testable import ResourceRunner

private actor PipelineSource<Value: Sendable>: ScheduledSampleSource {
    private let response: @Sendable (CollectionRunContext) async -> Value?
    private(set) var calls = 0
    private(set) var contexts: [CollectionRunContext] = []

    init(_ response: @escaping @Sendable (CollectionRunContext) async -> Value?) {
        self.response = response
    }
    func sample(collectionEpoch: Int) async -> Value? { nil }
    func sample(context: CollectionRunContext) async -> Value? {
        calls += 1
        contexts.append(context)
        return await response(context)
    }
}

private actor PipelineHold {
    private var continuation: CheckedContinuation<Void, Never>?
    private var waitCount = 0
    private(set) var entered = false
    func wait() async {
        entered = true
        await withCheckedContinuation { continuation = $0 }
    }
    func resume() { continuation?.resume(); continuation = nil }
    func waitFirst() async {
        waitCount += 1
        if waitCount == 1 { await wait() }
    }
}

@MainActor
private final class PipelinePresentationSink: CharacterPresentationSink {
    private(set) var labels: [String] = []
    func render(_ presentation: CharacterPresentation) { labels.append(presentation.accessibilityLabel) }
}

private func pipelineWait(_ condition: () async -> Bool) async {
    for _ in 0..<20_000 {
        if await condition() { return }
        await Task.yield()
    }
}

nonisolated private func pipelineSystem(cpuFailure: Bool = false,
                                        memoryFailure: Bool = false) -> SystemMetricsSample {
    let cpu = CPUSystemMetrics(overallUsage: 80, userRatio: 60, systemRatio: 20,
        idleRatio: 20, coreUsages: [80], loadAverage: LoadAverage(oneMinute: 1,
            fiveMinutes: 1, fifteenMinutes: 1))
    let memory = MemorySystemMetrics(totalPhysicalBytes: 1000, usedBytes: 500,
        appBytes: 300, wiredBytes: 100, compressedBytes: 50, cachedBytes: 100,
        swapUsedBytes: 0, pressureLevel: .normal)
    return SystemMetricsSample(
        cpu: cpuFailure ? .failure(CollectorFailure(metric: .cpu,
            cause: .systemCall(name: "injected cpu", code: 1))) : .success(cpu),
        memory: memoryFailure ? .failure(CollectorFailure(metric: .memory,
            cause: .systemCall(name: "injected memory", code: 2))) : .success(memory))
}

nonisolated private func pipelineNetwork(_ at: ContinuousClock.Instant,
                                         revision: UInt64, failure: Bool) -> NetworkActivitySample {
    let rate = RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 20)!
    return NetworkActivitySample(readAt: at, topologyRevision: revision, interfaces: [],
        knownPhysicalRates: failure ? nil : rate, representative: failure ? nil : rate,
        physicalTotalsComplete: !failure, status: failure ? .failure("injected network") : .rate,
        rateSegment: 1)
}

nonisolated private func pipelineDisk(_ at: ContinuousClock.Instant,
                                      revision: UInt64, failure: Bool) -> DiskActivitySample {
    let rate = RatePair(receivedBytesPerSecond: 30, sentBytesPerSecond: 40)!
    return DiskActivitySample(readAt: at, topologyRevision: revision, devices: [],
        knownPhysicalRates: failure ? nil : rate, representative: failure ? nil : rate,
        knownPhysicalOperations: nil, representativeOperations: nil,
        physicalTotalsComplete: !failure, status: failure ? .failure("injected disk") : .rate,
        rateSegment: 1)
}

@MainActor
struct CollectionPipelinesTests {
    private func initial(_ revision: Int = 0, locked: Bool = false,
                         lowPower: Bool = false, sequence: Int = 0) -> SystemLifecycleSnapshot {
        SystemLifecycleSnapshot(revision: revision, lowPowerMode: lowPower,
            screenLockState: locked ? .locked : .unlocked,
            displayAsleep: false, sessionActive: true, boundarySequence: sequence)
    }

    @Test func sixInjectedAxesStartOnlyAfterInitialLifecycleAndSlowAuxDoesNotBlockCardsOrMenu() async throws {
        let clock = ManualMonotonicClock()
        let admission = CollectionAdmission()
        let networkTopology = NetworkTopologyTracker()
        let diskTopology = DiskTopologyTracker()
        let hold = PipelineHold()
        let rankingHold = PipelineHold()
        let system = PipelineSource<SystemMetricsSample> { _ in pipelineSystem() }
        let process = PipelineSource<ProcessSurveySample> { _ in
            ProcessSurveySample(result: .success(ProcessSurveyReport(samples: [], unreadableCount: 0)))
        }
        let network = PipelineSource<NetworkActivitySample> { _ in
            pipelineNetwork(await clock.now(), revision: networkTopology.currentRevision, failure: true)
        }
        let disk = PipelineSource<DiskActivitySample> { _ in
            pipelineDisk(await clock.now(), revision: diskTopology.currentRevision, failure: false)
        }
        let networkMetadata = PipelineSource<NetworkMetadataResult> { context in
            if context.requestSequence == 1 { await hold.wait() }
            return .failure("injected slow network metadata", revision: networkTopology.currentRevision)
        }
        let storageMetadata = PipelineSource<StorageMetadataResult> { _ in
            .failure("injected storage metadata", revision: diskTopology.currentRevision)
        }
        let pipelines = CollectionPipelines.make(clock: clock, admission: admission,
            networkTopology: networkTopology, diskTopology: diskTopology,
            systemSource: system, processSource: process,
            networkSource: { _ in network }, diskSource: disk,
            networkMetadataSource: networkMetadata, storageMetadataSource: storageMetadata)
        let dashboard = DashboardPresentationStore()
        let delivery = CollectionDeliveryStore()
        let ranking = ProcessRankingDeliveryCache()
        let character = CharacterStateSource()
        let menuSink = PipelinePresentationSink()
        let menuTask = ApplicationCoordinator.consume(character, into: menuSink)
        let cpuTask = ApplicationCoordinator.consumeSystemMetrics(pipelines.systemStore,
            into: character, dashboard: dashboard, rankingCache: ranking, admission: admission)
        let rankingTask = ApplicationCoordinator.consumeProcessRanking(pipelines.processStore,
            into: ranking, admission: admission, beforeRankingCompute: { await rankingHold.waitFirst() })
        let networkTask = ApplicationCoordinator.consumeNetworkActivity(pipelines.networkStore,
            into: delivery, admission: admission)
        let diskTask = ApplicationCoordinator.consumeDiskActivity(pipelines.diskStore,
            into: delivery, admission: admission)
        let metadataTask = ApplicationCoordinator.consumeNetworkMetadata(pipelines.networkMetadataStore,
            into: delivery, admission: admission)
        let storageTask = ApplicationCoordinator.consumeStorageMetadata(pipelines.storageMetadataStore,
            into: delivery, admission: admission)
        defer { menuTask.cancel(); cpuTask.cancel(); rankingTask.cancel(); networkTask.cancel(); diskTask.cancel(); metadataTask.cancel(); storageTask.cancel() }
        await clock.advance(by: .seconds(20))
        #expect(await system.calls == 0)
        #expect(await process.calls == 0)
        #expect(await network.calls == 0)
        #expect(await disk.calls == 0)
        #expect(await networkMetadata.calls == 0)
        #expect(await storageMetadata.calls == 0)

        await pipelines.lifecycle.update(.systemSnapshot(initial()))
        await pipelineWait { delivery.storageMetadata?.latest != nil }
        await pipelines.lifecycle.update(.popoverPresented(true))
        await pipelineWait {
            let entered = await hold.entered
            let stored = await storageMetadata.calls
            return entered && stored == 1
        }
        #expect(await networkMetadata.calls == 1)
        await clock.advance(by: .seconds(4))
        await pipelineWait {
            let counts = (await system.calls, await network.calls, await disk.calls, await process.calls)
            return counts.0 >= 1 && counts.1 >= 1 && counts.2 >= 1 && counts.3 >= 1
        }
        await pipelineWait { delivery.networkActivity?.latest != nil && delivery.diskActivity?.latest != nil }
        await pipelineWait { await rankingHold.entered }
        await pipelineWait { delivery.storageMetadata?.latest != nil }
        #expect(await networkMetadata.calls == 1)
        #expect(delivery.networkActivity?.latest?.value.status == .failure("injected network"))
        #expect(delivery.networkActivity?.recentHistory.isEmpty == true)
        #expect(delivery.diskActivity?.latest?.value.status == .rate)
        #expect((delivery.diskActivity?.recentHistory.count ?? 0) >= 1)
        #expect(delivery.storageMetadata?.latest != nil)
        let systemTimestamp = await pipelines.systemStore.snapshot().latest?.timestamp
        let networkTimestamp = delivery.networkActivity?.latest?.timestamp
        let diskTimestamp = delivery.diskActivity?.latest?.timestamp
        let storageTimestamp = delivery.storageMetadata?.latest?.timestamp
        #expect(systemTimestamp != nil)
        #expect(networkTimestamp != nil)
        #expect(diskTimestamp != nil)
        #expect(storageTimestamp != nil)
        #expect(ranking.timestamp == nil)
        #expect(delivery.networkActivity?.latest?.value.readAt == networkTimestamp)
        #expect(delivery.diskActivity?.latest?.value.readAt == diskTimestamp)
        if case .normal = dashboard.cpuCard {} else { Issue.record("CPU card should continue") }
        if case .normal = dashboard.memoryCard {} else { Issue.record("Memory card should continue") }
        #expect(menuSink.labels.first == "ResourceRunner, 낮음")
        await clock.advance(by: .seconds(4))
        await pipelineWait { menuSink.labels.contains("ResourceRunner, 매우 높음") }
        #expect(menuSink.labels.contains("ResourceRunner, 매우 높음"))
        #expect(ranking.timestamp == nil)
        await rankingHold.resume()
        await pipelineWait { ranking.timestamp != nil }
        #expect(ranking.timestamp != nil)
        await hold.resume()
        await pipelines.lifecycle.requestAuxiliaryRefresh(.networkMetadata)
        await pipelineWait { delivery.networkMetadata?.latest != nil }
        #expect(delivery.networkMetadata?.latest != nil)
    }

    @Test func independentMetricFailuresKeepSuccessfulValuesAndNoFabricatedZero() async throws {
        let clock = ManualMonotonicClock()
        let admission = CollectionAdmission()
        let networkTopology = NetworkTopologyTracker()
        let diskTopology = DiskTopologyTracker()
        let system = PipelineSource<SystemMetricsSample> { context in
            context.requestSequence == 1 ? pipelineSystem(cpuFailure: true) :
                pipelineSystem(memoryFailure: true)
        }
        let process = PipelineSource<ProcessSurveySample> { _ in
            .init(result: .failure(CollectorFailure(metric: .process,
                cause: .systemCall(name: "injected process", code: 3))))
        }
        let network = PipelineSource<NetworkActivitySample> { _ in
            pipelineNetwork(await clock.now(), revision: networkTopology.currentRevision, failure: false)
        }
        let disk = PipelineSource<DiskActivitySample> { _ in
            pipelineDisk(await clock.now(), revision: diskTopology.currentRevision, failure: true)
        }
        let networkMetadata = PipelineSource<NetworkMetadataResult> { _ in
            .failure("injected network metadata", revision: networkTopology.currentRevision)
        }
        let storageMetadata = PipelineSource<StorageMetadataResult> { _ in
            .failure("injected storage metadata", revision: diskTopology.currentRevision)
        }
        let pipelines = CollectionPipelines.make(clock: clock, admission: admission,
            networkTopology: networkTopology, diskTopology: diskTopology,
            systemSource: system, processSource: process,
            networkSource: { _ in network }, diskSource: disk,
            networkMetadataSource: networkMetadata, storageMetadataSource: storageMetadata)
        let dashboard = DashboardPresentationStore()
        let delivery = CollectionDeliveryStore()
        let character = CharacterStateSource()
        let ranking = ProcessRankingDeliveryCache()
        let cpuTask = ApplicationCoordinator.consumeSystemMetrics(pipelines.systemStore,
            into: character, dashboard: dashboard, rankingCache: ranking, admission: admission)
        let networkTask = ApplicationCoordinator.consumeNetworkActivity(pipelines.networkStore,
            into: delivery, admission: admission)
        let diskTask = ApplicationCoordinator.consumeDiskActivity(pipelines.diskStore,
            into: delivery, admission: admission)
        defer { cpuTask.cancel(); networkTask.cancel(); diskTask.cancel() }
        await pipelines.lifecycle.update(.systemSnapshot(initial()))
        await pipelines.lifecycle.update(.popoverPresented(true))
        await clock.advance(by: .seconds(1))
        await pipelineWait {
            let counts = (await system.calls, await process.calls, await network.calls, await disk.calls)
            return counts.0 >= 1 && counts.1 >= 1 && counts.2 >= 1 && counts.3 >= 1
        }
        await pipelineWait { delivery.networkActivity?.latest != nil && delivery.diskActivity?.latest != nil }
        await pipelineWait {
            if case .failure = dashboard.cpuCard,
               case .normal = dashboard.memoryCard { return true }
            return false
        }
        if case .failure = dashboard.cpuCard {} else { Issue.record("CPU cause should remain failure") }
        if case .normal = dashboard.memoryCard {} else { Issue.record("Memory success should remain visible") }
        #expect(delivery.networkActivity?.latest?.value.representative ==
            RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 20))
        #expect(delivery.diskActivity?.latest?.value.status == .failure("injected disk"))
        #expect(delivery.diskActivity?.recentHistory.isEmpty == true)
        await clock.advance(by: .seconds(1))
        await pipelineWait { await system.calls >= 2 }
        await pipelineWait {
            if case .failure = dashboard.memoryCard { return true }
            return false
        }
        if case .normal = dashboard.cpuCard {} else { Issue.record("CPU success should remain visible") }
        if case .failure = dashboard.memoryCard {} else { Issue.record("Memory failure cause should remain visible") }
    }

    @Test func cancellationIgnoringOldNetworkResultCannotReplaceResumedDelivery() async throws {
        let clock = ManualMonotonicClock()
        let admission = CollectionAdmission()
        let networkTopology = NetworkTopologyTracker()
        let diskTopology = DiskTopologyTracker()
        let hold = PipelineHold()
        let system = PipelineSource<SystemMetricsSample> { _ in pipelineSystem() }
        let process = PipelineSource<ProcessSurveySample> { _ in
            .init(result: .success(ProcessSurveyReport(samples: [], unreadableCount: 0)))
        }
        let network = PipelineSource<NetworkActivitySample> { context in
            if context.requestSequence == 1 {
                await hold.wait() // 취소 이후에도 오래된 native 응답이 도착하는 경우를 재현합니다.
                return pipelineNetwork(await clock.now(), revision: networkTopology.currentRevision, failure: true)
            }
            return pipelineNetwork(await clock.now(), revision: networkTopology.currentRevision, failure: false)
        }
        let disk = PipelineSource<DiskActivitySample> { _ in
            pipelineDisk(await clock.now(), revision: diskTopology.currentRevision, failure: false)
        }
        let networkMetadata = PipelineSource<NetworkMetadataResult> { _ in
            .failure("metadata", revision: networkTopology.currentRevision)
        }
        let storageMetadata = PipelineSource<StorageMetadataResult> { _ in
            .failure("storage", revision: diskTopology.currentRevision)
        }
        let pipelines = CollectionPipelines.make(clock: clock, admission: admission,
            networkTopology: networkTopology, diskTopology: diskTopology,
            systemSource: system, processSource: process,
            networkSource: { _ in network }, diskSource: disk,
            networkMetadataSource: networkMetadata, storageMetadataSource: storageMetadata)
        let delivery = CollectionDeliveryStore()
        let consumer = ApplicationCoordinator.consumeNetworkActivity(pipelines.networkStore,
            into: delivery, admission: admission)
        defer { consumer.cancel() }

        await pipelines.lifecycle.update(.systemSnapshot(initial()))
        await clock.advance(by: .seconds(2))
        await pipelineWait { await hold.entered }
        #expect(await hold.entered)
        await pipelines.lifecycle.update(.systemSnapshot(initial(1, locked: true, sequence: 1)))
        await pipelines.lifecycle.update(.systemSnapshot(initial(2, sequence: 2)))
        await clock.advance(by: .seconds(2))
        await pipelineWait { await network.calls >= 2 }
        await pipelineWait { delivery.networkActivity?.latest?.value.status == .rate }
        let resumedContext = delivery.networkActivity?.latest?.context
        await hold.resume()
        await pipelineWait { await network.calls >= 2 }
        for _ in 0..<100 { await Task.yield() }
        #expect(delivery.networkActivity?.latest?.value.status == .rate)
        #expect(delivery.networkActivity?.latest?.context == resumedContext)
        #expect(resumedContext?.epoch == admission.currentBoundary.epoch)
    }

    @Test func mountNotificationsAndNetworkSignalsAdvanceCumulativeRevision() async throws {
        let clock = ManualMonotonicClock()
        let admission = CollectionAdmission()
        let networkTopology = NetworkTopologyTracker()
        let diskTopology = DiskTopologyTracker()
        let system = PipelineSource<SystemMetricsSample> { _ in pipelineSystem() }
        let process = PipelineSource<ProcessSurveySample> { _ in
            .init(result: .success(ProcessSurveyReport(samples: [], unreadableCount: 0)))
        }
        let network = PipelineSource<NetworkActivitySample> { _ in
            pipelineNetwork(await clock.now(), revision: networkTopology.currentRevision, failure: false)
        }
        let disk = PipelineSource<DiskActivitySample> { _ in
            pipelineDisk(await clock.now(), revision: diskTopology.currentRevision, failure: false)
        }
        let networkMetadata = PipelineSource<NetworkMetadataResult> { _ in
            .failure("metadata", revision: networkTopology.currentRevision)
        }
        let storageMetadata = PipelineSource<StorageMetadataResult> { _ in
            .failure("storage", revision: diskTopology.currentRevision)
        }
        let pipelines = CollectionPipelines.make(clock: clock, admission: admission,
            networkTopology: networkTopology, diskTopology: diskTopology,
            systemSource: system, processSource: process,
            networkSource: { _ in network }, diskSource: disk,
            networkMetadataSource: networkMetadata, storageMetadataSource: storageMetadata)
        let center = NotificationCenter()
        let observer = ResourceTopologyObserver(networkTopology: networkTopology,
            diskTopology: diskTopology, lifecycle: pipelines.lifecycle,
            workspaceCenter: center, observeNetwork: false)
        _ = observer
        await pipelines.lifecycle.update(.systemSnapshot(initial()))
        await pipelineWait { await storageMetadata.calls == 1 }
        let oldDisk = diskTopology.currentRevision
        let oldNetwork = networkTopology.currentRevision
        center.post(name: NSWorkspace.didMountNotification, object: nil)
        center.post(name: NSWorkspace.willUnmountNotification, object: nil)
        ResourceTopologyObserver.routeNetworkChange(networkTopology, lifecycle: pipelines.lifecycle)
        ResourceTopologyObserver.routeNetworkChange(networkTopology, lifecycle: pipelines.lifecycle)
        #expect(diskTopology.currentRevision == oldDisk + 2)
        #expect(networkTopology.currentRevision == oldNetwork + 2)
        await pipelineWait { await storageMetadata.calls >= 2 }
        await pipelineWait { await networkMetadata.calls >= 2 }
        #expect(await storageMetadata.calls >= 2)
        #expect(await networkMetadata.calls >= 2)
    }

    @Test func injectedLowPowerLifecycleUsesProductionSixAxisFactory() async {
        let clock = ManualMonotonicClock()
        let admission = CollectionAdmission()
        let networkTopology = NetworkTopologyTracker()
        let diskTopology = DiskTopologyTracker()
        let system = PipelineSource<SystemMetricsSample> { _ in pipelineSystem() }
        let process = PipelineSource<ProcessSurveySample> { _ in
            .init(result: .success(ProcessSurveyReport(samples: [], unreadableCount: 0)))
        }
        let network = PipelineSource<NetworkActivitySample> { _ in
            pipelineNetwork(await clock.now(), revision: networkTopology.currentRevision, failure: false)
        }
        let disk = PipelineSource<DiskActivitySample> { _ in
            pipelineDisk(await clock.now(), revision: diskTopology.currentRevision, failure: false)
        }
        let networkMetadata = PipelineSource<NetworkMetadataResult> { _ in
            .failure("metadata", revision: networkTopology.currentRevision)
        }
        let storageMetadata = PipelineSource<StorageMetadataResult> { _ in
            .failure("storage", revision: diskTopology.currentRevision)
        }
        let pipelines = CollectionPipelines.make(clock: clock, admission: admission,
            networkTopology: networkTopology, diskTopology: diskTopology,
            systemSource: system, processSource: process,
            networkSource: { _ in network }, diskSource: disk,
            networkMetadataSource: networkMetadata, storageMetadataSource: storageMetadata)

        await pipelines.lifecycle.update(.systemSnapshot(initial(lowPower: true)))
        await pipelineWait {
            let counts = (await networkMetadata.calls, await storageMetadata.calls)
            return counts.0 == 1 && counts.1 == 1
        }
        await pipelineWait {
            let stored = ((await pipelines.networkMetadataStore.status()).latest != nil,
                          (await pipelines.storageMetadataStore.status()).latest != nil)
            return stored.0 && stored.1
        }
        await clock.advance(by: .seconds(4))
        #expect(await system.calls == 0)
        #expect(await network.calls == 0)
        #expect(await disk.calls == 0)
        #expect(await process.calls == 0)
        await clock.advance(by: .seconds(1))
        await pipelineWait {
            let counts = (await system.calls, await network.calls, await disk.calls)
            return counts.0 >= 1 && counts.1 >= 1 && counts.2 >= 1
        }
        #expect(await process.calls == 0)
        let epoch = admission.currentBoundary.epoch
        await pipelines.lifecycle.update(.popoverPresented(true))
        #expect(admission.currentBoundary.epoch == epoch)
        let delivery = CollectionDeliveryStore()
        let networkConsumer = ApplicationCoordinator.consumeNetworkMetadata(
            pipelines.networkMetadataStore, into: delivery, admission: admission)
        let storageConsumer = ApplicationCoordinator.consumeStorageMetadata(
            pipelines.storageMetadataStore, into: delivery, admission: admission)
        defer { networkConsumer.cancel(); storageConsumer.cancel() }
        await pipelineWait { delivery.networkMetadata?.latest != nil && delivery.storageMetadata?.latest != nil }
        #expect(delivery.networkMetadata?.latest?.context?.epoch == epoch)
        #expect(delivery.storageMetadata?.latest?.context?.epoch == epoch)
        await clock.advance(by: .seconds(3))
        #expect(await process.calls == 0)
        await clock.advance(by: .seconds(1))
        await pipelineWait { await process.calls >= 1 }
        #expect(await process.calls >= 1)
        #expect(await networkMetadata.calls == 1)
        #expect(await storageMetadata.calls == 1)
    }

    @Test func cachedReplayCannotReverseNewNativeOrCrossTopologyAndEpoch() async throws {
        let admission = CollectionAdmission()
        admission.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
        _ = admission.advance(.networkMetadata)
        _ = admission.advance(.storageMetadata)
        let networkTopology = NetworkTopologyTracker()
        let diskTopology = DiskTopologyTracker()
        let networkStore = NetworkMetadataStore(admission: admission, topology: networkTopology)
        let storageStore = StorageMetadataStore(admission: admission, topology: diskTopology)
        let timestamp = ContinuousClock().now
        let oldNetwork = try #require(admission.issue(.networkMetadata))
        let newNetwork = try #require(admission.issue(.networkMetadata))
        let oldDisk = try #require(admission.issue(.storageMetadata))
        let newDisk = try #require(admission.issue(.storageMetadata))
        let networkHold = PipelineHold()
        let diskHold = PipelineHold()
        let oldNetworkSample = TimestampedSample(timestamp: timestamp,
            value: NetworkMetadataResult.failure("old", revision: networkTopology.currentRevision),
            collectionEpoch: 0, context: oldNetwork)
        let oldDiskSample = TimestampedSample(timestamp: timestamp,
            value: StorageMetadataResult.failure("old", revision: diskTopology.currentRevision),
            collectionEpoch: 0, context: oldDisk)
        let lateNetwork = Task {
            await networkHold.wait()
            return await networkStore.replayCached(oldNetworkSample, context: oldNetwork)
        }
        let lateDisk = Task {
            await diskHold.wait()
            return await storageStore.replayCached(oldDiskSample, context: oldDisk)
        }
        await pipelineWait {
            let entered = (await networkHold.entered, await diskHold.entered)
            return entered.0 && entered.1
        }
        let newNetworkSample = TimestampedSample(timestamp: timestamp.advanced(by: .seconds(1)),
            value: NetworkMetadataResult.failure("new", revision: networkTopology.currentRevision),
            collectionEpoch: 0, context: newNetwork)
        let newDiskSample = TimestampedSample(timestamp: timestamp.advanced(by: .seconds(1)),
            value: StorageMetadataResult.failure("new", revision: diskTopology.currentRevision),
            collectionEpoch: 0, context: newDisk)
        #expect(await networkStore.append(newNetworkSample, context: newNetwork))
        #expect(await storageStore.append(newDiskSample, context: newDisk))
        await networkHold.resume()
        await diskHold.resume()
        #expect(await lateNetwork.value == false)
        #expect(await lateDisk.value == false)

        networkTopology.noteChange()
        diskTopology.noteChange()
        let changedNetwork = try #require(admission.issue(.networkMetadata))
        let changedDisk = try #require(admission.issue(.storageMetadata))
        #expect(await networkStore.replayCached(oldNetworkSample, context: changedNetwork) == false)
        #expect(await storageStore.replayCached(oldDiskSample, context: changedDisk) == false)
        admission.transition(CollectionBoundary(revision: 1, sequence: 1, epoch: 1, stopped: true))
        #expect(await networkStore.replayCached(newNetworkSample, context: newNetwork) == false)
        #expect(await storageStore.replayCached(newDiskSample, context: newDisk) == false)
        if case .failure(let reason, _) = (await networkStore.status()).latest?.value {
            #expect(reason == "new")
        } else { Issue.record("new network metadata should remain") }
        if case .failure(let reason, _) = (await storageStore.status()).latest?.value {
            #expect(reason == "new")
        } else { Issue.record("new storage metadata should remain") }
    }
}
