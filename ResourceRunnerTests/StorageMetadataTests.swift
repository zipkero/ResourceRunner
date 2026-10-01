import Foundation
import Testing
@testable import ResourceRunner

private final class StorageNativeScript: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    let callback: @Sendable (Int) -> DiskNativeSnapshot
    init(_ callback: @escaping @Sendable (Int) -> DiskNativeSnapshot) { self.callback = callback }
    func read() -> DiskNativeSnapshot {
        let call = lock.withLock { calls += 1; return calls }
        return callback(call)
    }
}

private final class DiskFastScript: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    let callback: @Sendable (Int) -> [DiskCounterDevice]
    init(_ callback: @escaping @Sendable (Int) -> [DiskCounterDevice]) { self.callback = callback }
    func read() -> [DiskCounterDevice] {
        let call = lock.withLock { calls += 1; return calls }
        return callback(call)
    }
}

private final class BlockingStorageReader: StorageMetadataReading, @unchecked Sendable {
    private let lock = NSLock()
    private var didEnter = false
    private let releaseSemaphore = DispatchSemaphore(value: 0)
    var entered: Bool { lock.withLock { didEnter } }
    func release() { releaseSemaphore.signal() }
    func read() throws -> StorageMetadataSnapshot {
        lock.withLock { didEnter = true }
        releaseSemaphore.wait()
        throw DiskNativeError.invalid("scripted slow query failed")
    }
}

private func storageDriver(_ id: UInt64, external: DiskExternalKind = .internalDevice) -> DiskDriverReading {
    DiskDriverReading(registryID: id, bsdNames: ["disk\(id)"], kind: .physical,
        kindReason: "hardware", readBytes: 100, writtenBytes: 200,
        readOperations: 10, writeOperations: 20, operationsReason: "Statistics",
        external: external, externalReason: "DA DeviceInternal", removable: false,
        ejectable: false, connection: "PCI-Express")
}
private func storageVolume(_ id: String, paths: Set<String>, drivers: Set<UInt64>,
                           scope: DiskVolumeScope = .physical, total: UInt64 = 1000,
                           available: UInt64 = 400) -> DiskVolumeReading {
    DiskVolumeReading(identity: id, mountPaths: paths, bsdName: "disk3s1", fileSystem: "apfs",
        totalBytes: total, availableBytes: available, driverIDs: drivers, scope: scope,
        relationReason: scope == .unconfirmed ? "relation unavailable" : "ancestor drivers",
        sharedCapacity: true)
}
private func storageNative(drivers: [DiskDriverReading], volumes: [DiskVolumeReading]) -> DiskNativeSnapshot {
    DiskNativeSnapshot(drivers: drivers, volumes: volumes,
        systemVolume: volumes.first { $0.mountPaths.contains("/") } ?? volumes[0],
        driverLookup: "IOKit=0", volumeLookup: "DA=0", physicalTotalsComplete: true,
        relationshipsComplete: volumes.allSatisfy { $0.scope != .unconfirmed })
}
private func storageCounter(_ id: UInt64) -> DiskCounterDevice {
    DiskCounterDevice(registryID: id, bsdNames: ["disk\(id)"], kind: .physical,
        kindReason: "hardware", readBytes: 100, writtenBytes: 200,
        readOperations: 10, writeOperations: 20, operationsReason: "Statistics",
        bytesReason: "Statistics")
}
private func storageGate(_ axis: CollectionAxis) -> CollectionAdmission {
    let admission = CollectionAdmission()
    admission.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
    _ = admission.advance(axis)
    return admission
}

struct StorageMetadataTests {
    private let origin = ContinuousClock().now

    @Test func manyToManyRelationsSharedCapacityAndUnmountedExternalStayDistinct() async throws {
        let topology = DiskTopologyTracker()
        let system = storageVolume("system", paths: ["/"], drivers: [1, 2])
        let data = storageVolume("data", paths: ["/System/Volumes/Data"], drivers: [1, 2])
        let unknown = storageVolume("unknown", paths: ["/Volumes/Unknown"], drivers: [], scope: .unconfirmed)
        let native = storageNative(drivers: [storageDriver(1), storageDriver(2),
            storageDriver(3, external: .externalDevice)], volumes: [system, data, unknown])
        let reader = SystemStorageMetadataReader(topology: topology, nativeRead: { native })
        let result = try reader.read()
        #expect(result.volumes.count == 3)
        #expect(result.volumes[0].driverIDs == [1, 2] || result.volumes[1].driverIDs == [1, 2])
        #expect(result.systemVolume.identity == "system")
        #expect(result.systemVolume.usedBytes == 600)
        #expect(result.systemVolume.sharedCapacity)
        #expect(result.relationshipsComplete == false)
        #expect(result.externalDevicesAbsent == false)
        #expect(result.devices.first { $0.registryID == 3 }?.mountState == .relationUnconfirmed)
        let store = StorageMetadataStore(topology: topology)
        await store.append(TimestampedSample(timestamp: result.readAt, value: .available(result)))
        let counter = DiskCounterSnapshot(readAt: origin,
            devices: [storageCounter(1), storageCounter(2), storageCounter(3)],
            topologyRevision: result.topologyRevision)
        let view = await store.relationship(for: counter)
        #expect(view.systemVolume?.identity == "system")
        #expect(view.volumes.count == 3)
        #expect(view.devices[3]?.mountState == .relationUnconfirmed)
        #expect(view.complete == false)
        #expect(await store.relationship(for: DiskCounterSnapshot(readAt: origin,
            devices: counter.devices, topologyRevision: result.topologyRevision + 1)).devices.isEmpty)
        #expect(await store.relationship(for: DiskCounterSnapshot(readAt: origin,
            devices: [storageCounter(9)], topologyRevision: result.topologyRevision)).devices.isEmpty)
    }

    @Test func noExternalAndFailureAreDifferentFromUnmountedOrUnknownRelation() async throws {
        let system = storageVolume("system", paths: ["/"], drivers: [1])
        let topology = DiskTopologyTracker()
        let result = try SystemStorageMetadataReader(topology: topology,
            nativeRead: { storageNative(drivers: [storageDriver(1), storageDriver(2)], volumes: [system]) }).read()
        #expect(result.externalDevicesAbsent)
        #expect(result.devices[0].mountState == .mounted)
        #expect(result.devices[1].mountState == .unmounted)
        let incompleteNative = DiskNativeSnapshot(drivers: [storageDriver(1), storageDriver(2)],
            volumes: [system], systemVolume: system, driverLookup: "IOKit=0",
            volumeLookup: "DA relation incomplete", physicalTotalsComplete: true,
            relationshipsComplete: false)
        let incomplete = try SystemStorageMetadataReader(topology: DiskTopologyTracker(),
            nativeRead: { incompleteNative }).read()
        #expect(incomplete.devices[1].mountState == .relationUnconfirmed)
        let store = StorageMetadataStore()
        await store.append(TimestampedSample(timestamp: origin, value: .available(result)))
        await store.append(TimestampedSample(timestamp: origin + .seconds(1),
            value: .failure("DA query failed", revision: result.topologyRevision)))
        let status = await store.status()
        if case .failure(let reason, _) = status.latest?.value { #expect(reason == "DA query failed") }
        else { Issue.record("failure state expected") }
        #expect(status.lastKnown?.systemVolume.identity == "system")
    }

    @Test func fastAndSlowReadersRejectBoundaryAndOlderRequestBeforeTrackerMutation() throws {
        let native = storageNative(drivers: [storageDriver(1)],
            volumes: [storageVolume("system", paths: ["/"], drivers: [1])])
        for axis in [CollectionAxis.diskActivity, .storageMetadata] {
            let topology = DiskTopologyTracker()
            let admission = storageGate(axis)
            let old = try #require(admission.issue(axis))
            let new = try #require(admission.issue(axis))
            if axis == .diskActivity {
                let reader = SystemDiskCounterReader(topology: topology,
                    nativeRead: { [storageCounter(1)] })
                _ = try reader.read(context: new, admission: admission)
                let revision = topology.currentRevision
                #expect(throws: DiskNativeError.self) {
                    try reader.read(context: old, admission: admission)
                }
                #expect(topology.currentRevision == revision)
            } else {
                let reader = SystemStorageMetadataReader(topology: topology,
                    nativeRead: { native })
                _ = try reader.read(context: new, admission: admission)
                let revision = topology.currentRevision
                #expect(throws: DiskNativeError.self) {
                    try reader.read(context: old, admission: admission)
                }
                #expect(topology.currentRevision == revision)
            }
        }
        let topology = DiskTopologyTracker()
        let admission = storageGate(.diskActivity)
        let context = try #require(admission.issue(.diskActivity))
        let reader = SystemDiskCounterReader(topology: topology, nativeRead: {
            admission.transition(CollectionBoundary(revision: 1, sequence: 1, epoch: 1, stopped: true))
            return [storageCounter(1)]
        })
        #expect(throws: DiskNativeError.self) { try reader.read(context: context, admission: admission) }
        #expect(topology.currentRevision == 0)
        let slowTopology = DiskTopologyTracker()
        let slowGate = storageGate(.storageMetadata)
        let slowContext = try #require(slowGate.issue(.storageMetadata))
        let slowReader = SystemStorageMetadataReader(topology: slowTopology, nativeRead: {
            slowGate.transition(CollectionBoundary(revision: 1, sequence: 1, epoch: 1, stopped: true))
            return native
        })
        #expect(throws: DiskNativeError.self) {
            try slowReader.read(context: slowContext, admission: slowGate)
        }
        #expect(slowTopology.currentRevision == 0)
    }

    @Test func fastReadRetriesConcurrentTopologyChangeWithoutRestoringOldDevice() throws {
        let topology = DiskTopologyTracker()
        _ = topology.observeIfCurrent([storageCounter(1)], expectedRevision: 0)
        let script = DiskFastScript { call in
            if call == 1 {
                _ = topology.observeIfCurrent([storageCounter(2)], expectedRevision: 1)
                return [storageCounter(1)]
            }
            return [storageCounter(2)]
        }
        let result = try SystemDiskCounterReader(topology: topology,
            nativeRead: { script.read() }).read()
        #expect(result.devices.map(\.registryID) == [2])
        #expect(result.topologyRevision == topology.currentRevision)
    }

    @Test func slowNativeReadRetriesTopologyRaceAndCannotRestoreOldSet() throws {
        let topology = DiskTopologyTracker()
        _ = topology.observeIfCurrent([storageCounter(1)], expectedRevision: 0)
        let old = storageNative(drivers: [storageDriver(1)],
            volumes: [storageVolume("system", paths: ["/"], drivers: [1])])
        let new = storageNative(drivers: [storageDriver(2)],
            volumes: [storageVolume("system", paths: ["/"], drivers: [2])])
        let script = StorageNativeScript { call in
            if call == 1 {
                _ = topology.observeIfCurrent([storageCounter(2)], expectedRevision: 1)
                return old
            }
            return new
        }
        let reader = SystemStorageMetadataReader(topology: topology, nativeRead: { script.read() })
        let result = try reader.read()
        #expect(result.devices.map(\.registryID) == [2])
        #expect(result.topologyRevision == topology.currentRevision)
    }

    @Test func mountChangeAdvancesTopologyRevisionAndInvalidatesOldCapacityCache() async throws {
        let topology = DiskTopologyTracker()
        let system = storageVolume("system", paths: ["/"], drivers: [1])
        let external = storageVolume("external", paths: ["/Volumes/External"], drivers: [2])
        let firstNative = storageNative(drivers: [storageDriver(1), storageDriver(2)],
            volumes: [system])
        let secondNative = storageNative(drivers: [storageDriver(1), storageDriver(2)],
            volumes: [system, external])
        let script = StorageNativeScript { call in call == 1 ? firstNative : secondNative }
        let reader = SystemStorageMetadataReader(topology: topology, nativeRead: { script.read() })
        let first = try reader.read()
        let store = StorageMetadataStore()
        await store.append(TimestampedSample(timestamp: first.readAt, value: .available(first)))
        let second = try reader.read()
        #expect(second.topologyRevision == first.topologyRevision + 1)
        let current = DiskCounterSnapshot(readAt: origin, devices: [storageCounter(1), storageCounter(2)],
            topologyRevision: second.topologyRevision)
        #expect(await store.relationship(for: current).devices.isEmpty)
        await store.append(TimestampedSample(timestamp: second.readAt, value: .available(second)))
        #expect(await store.relationship(for: current).volumes.count == 2)
    }

    @Test func slowStorageSuspensionDoesNotBlockFastDiskSamples() async throws {
        let hold = BlockingStorageReader()
        let slow = StorageMetadataSource(reader: hold)
        let slowTask = Task { await slow.sample(collectionEpoch: 0) }
        for _ in 0..<10_000 where !hold.entered { await Task.yield() }
        #expect(hold.entered)
        let fast = DiskActivitySource(reader: DiskScriptedReader([
            .success(DiskCounterSnapshot(readAt: origin, devices: [storageCounter(1)], topologyRevision: 1)),
            .success(DiskCounterSnapshot(readAt: origin + .seconds(1), devices: [
                DiskCounterDevice(registryID: 1, bsdNames: ["disk1"], kind: .physical,
                    kindReason: "hardware", readBytes: 110, writtenBytes: 220,
                    readOperations: 11, writeOperations: 22,
                    operationsReason: "Statistics", bytesReason: "Statistics")], topologyRevision: 1))
        ]))
        _ = await fast.sample(collectionEpoch: 0)
        #expect((await fast.sample(collectionEpoch: 0))?.representative ==
            RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 20))
        hold.release()
        _ = await slowTask.value
    }

    @Test func failureFromOlderTopologyCannotOverwriteStorageLatestAfterSourceOrSinkDelay() async throws {
        let topology = DiskTopologyTracker()
        _ = topology.observeIfCurrent([storageCounter(1)], expectedRevision: 0)
        let admission = storageGate(.storageMetadata)
        let context = try #require(admission.issue(.storageMetadata))
        let reader = TopologyChangingFailureReader(topology: topology)
        let source = StorageMetadataSource(reader: reader, admission: admission)
        #expect(await source.sample(context: context) == nil)
        #expect(topology.currentRevision == 2)
        let store = StorageMetadataStore(admission: admission, topology: topology)
        #expect(await store.append(TimestampedSample(timestamp: origin,
            value: .failure("old query failed", revision: 1),
            collectionEpoch: context.epoch), context: context) == false)
        let system = storageVolume("system", paths: ["/"], drivers: [1])
        let oldSnapshot = StorageMetadataSnapshot(readAt: origin, topologyRevision: 1,
            volumes: [system], systemVolume: system, devices: [],
            relationshipsComplete: true, externalDevicesAbsent: true, nativeStatus: "old")
        #expect(await store.append(TimestampedSample(timestamp: origin,
            value: .available(oldSnapshot), collectionEpoch: context.epoch), context: context) == false)
        #expect(await store.status().latest == nil)
    }
}

private struct TopologyChangingFailureReader: StorageMetadataReading {
    let topology: DiskTopologyTracker
    var currentTopologyRevision: UInt64? { topology.currentRevision }
    func read() throws -> StorageMetadataSnapshot {
        _ = topology.observeIfCurrent([storageCounter(2)], expectedRevision: 1)
        throw DiskNativeError.invalid("old query failed")
    }
}
