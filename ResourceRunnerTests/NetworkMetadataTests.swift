import Darwin
import Foundation
import Testing
@testable import ResourceRunner

private final class NativeNetworkScript: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    let callback: @Sendable (Int) -> NetworkNativeSnapshot
    init(callback: @escaping @Sendable (Int) -> NetworkNativeSnapshot) { self.callback = callback }
    func read() -> NetworkNativeSnapshot {
        let index = lock.withLock { calls += 1; return calls }
        return callback(index)
    }
}

private final class RouteNetworkScript: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    let callback: @Sendable (Int) -> [NetworkRawInterface]
    init(callback: @escaping @Sendable (Int) -> [NetworkRawInterface]) { self.callback = callback }
    func read() -> [NetworkRawInterface] {
        let index = lock.withLock { calls += 1; return calls }
        return callback(index)
    }
}

private func nativeNetwork(_ name: String, index: UInt16, registry: UInt64) -> NetworkNativeSnapshot {
    let raw = NetworkRawInterface(name: name, index: index, flags: Int32(IFF_UP),
        linkType: 6, receivedBytes: 100, sentBytes: 100, baudrate: 0)
    let reading = NetworkInterfaceReading(raw: raw, kind: .physicalEthernet,
        classificationReason: "hardware provider", registryID: registry,
        providerPath: ["IOEthernetInterface", "IOPCIDevice"], functionalType: nil,
        ipv4: ["192.0.2.1"], ipv6: [], linkActive: true, status: "link active", linkSpeed: "unsupported")
    return NetworkNativeSnapshot(interfaces: [reading], physicalTotalsComplete: true,
        routeLookup: "route=0", addressLookup: "address=0", configurationLookup: "SC=0",
        registryLookup: "IORegistry=0", linkLookup: "link=0")
}

private func throughScheduledProtocol<S: ScheduledSampleSource>(_ source: S,
    context: CollectionRunContext) async throws -> S.Value? {
    try await source.sample(context: context)
}

struct NetworkMetadataTests {
    @Test func newerReaderRequestPreventsOlderRouteAndMetadataFromRestoringTopology() throws {
        let oldRaw = NetworkRawInterface(name: "en0", index: 1, flags: Int32(IFF_UP),
            linkType: 6, receivedBytes: 1, sentBytes: 1, baudrate: 0)
        let newRaw = NetworkRawInterface(name: "en1", index: 2, flags: Int32(IFF_UP),
            linkType: 6, receivedBytes: 1, sentBytes: 1, baudrate: 0)
        for axis in [CollectionAxis.networkActivity, .networkMetadata] {
            let topology = NetworkTopologyTracker()
            _ = topology.observe([oldRaw])
            let admission = CollectionAdmission()
            admission.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
            _ = admission.advance(axis)
            let older = try #require(admission.issue(axis))
            let newer = try #require(admission.issue(axis))
            if axis == .networkActivity {
                let script = RouteNetworkScript { call in call == 1 ? [newRaw] : [oldRaw] }
                let reader = SystemNetworkCounterReader(topology: topology,
                    routeRead: { script.read() })
                #expect(try reader.read(context: newer, admission: admission).interfaces.map(\.key.name) == ["en1"])
                let revision = topology.currentRevision
                #expect(throws: NetworkNativeError.self) {
                    try reader.read(context: older, admission: admission)
                }
                #expect(topology.currentRevision == revision)
            } else {
                let script = NativeNetworkScript { call in
                    call == 1 ? nativeNetwork("en1", index: 2, registry: 8) :
                                nativeNetwork("en0", index: 1, registry: 7)
                }
                let reader = SystemNetworkMetadataReader(topology: topology,
                    nativeRead: { script.read() })
                #expect(try reader.read(context: newer, admission: admission).records.map(\.key.name) == ["en1"])
                let revision = topology.currentRevision
                #expect(throws: NetworkNativeError.self) {
                    try reader.read(context: older, admission: admission)
                }
                #expect(topology.currentRevision == revision)
            }
            #expect(topology.observe([newRaw]).interfaces.map(\.key.name) == ["en1"])
        }
    }

    @Test func fastReaderRejectsBoundaryDuringRouteReadWithoutChangingTopology() throws {
        let topology = NetworkTopologyTracker()
        let raw = NetworkRawInterface(name: "en0", index: 1, flags: Int32(IFF_UP),
            linkType: 6, receivedBytes: 1, sentBytes: 1, baudrate: 0)
        let initial = topology.observe([raw])
        let admission = CollectionAdmission()
        admission.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
        _ = admission.advance(.networkActivity)
        let context = try #require(admission.issue(.networkActivity))
        let script = RouteNetworkScript { _ in
            admission.transition(CollectionBoundary(revision: 1, sequence: 1,
                epoch: 1, stopped: true))
            return [raw]
        }
        let reader = SystemNetworkCounterReader(topology: topology, routeRead: { script.read() })
        #expect(throws: NetworkNativeError.self) {
            try reader.read(context: context, admission: admission)
        }
        #expect(topology.currentRevision == initial.revision)
    }

    @Test func fastReaderRetriesChangedTopologyInsteadOfRestoringOldSet() throws {
        let topology = NetworkTopologyTracker()
        let old = NetworkRawInterface(name: "en0", index: 1, flags: Int32(IFF_UP),
            linkType: 6, receivedBytes: 1, sentBytes: 1, baudrate: 0)
        let current = NetworkRawInterface(name: "en1", index: 2, flags: Int32(IFF_UP),
            linkType: 6, receivedBytes: 1, sentBytes: 1, baudrate: 0)
        _ = topology.observe([old])
        let script = RouteNetworkScript { call in
            if call == 1 {
                _ = topology.observe([current])
                return [old]
            }
            return [current]
        }
        let reader = SystemNetworkCounterReader(topology: topology, routeRead: { script.read() })
        let result = try reader.read()
        #expect(result.interfaces.map(\.key.name) == ["en1"])
        #expect(result.topologyRevision == topology.currentRevision)
    }

    @Test func nativeTopologyChangeDuringSlowReadRetriesWithoutRestoringOldSet() throws {
        let topology = NetworkTopologyTracker()
        let oldRaw = NetworkRawInterface(name: "en0", index: 1, flags: Int32(IFF_UP),
            linkType: 6, receivedBytes: 1, sentBytes: 1, baudrate: 0)
        let newRaw = NetworkRawInterface(name: "en1", index: 2, flags: Int32(IFF_UP),
            linkType: 6, receivedBytes: 1, sentBytes: 1, baudrate: 0)
        _ = topology.observe([oldRaw])
        let script = NativeNetworkScript { call in
            if call == 1 {
                _ = topology.observe([newRaw])
                return nativeNetwork("en0", index: 1, registry: 7)
            }
            return nativeNetwork("en1", index: 2, registry: 8)
        }
        let reader = SystemNetworkMetadataReader(topology: topology, nativeRead: { script.read() })
        let snapshot = try reader.read()
        #expect(snapshot.records.map(\.key.name) == ["en1"])
        #expect(snapshot.topologyRevision == topology.currentRevision)
        #expect(topology.observe([newRaw]).interfaces.map(\.key.name) == ["en1"])
    }

    @Test func gateBoundaryDuringNativeReadLeavesTrackerAndStoresUntouched() async throws {
        let topology = NetworkTopologyTracker()
        let raw = NetworkRawInterface(name: "en0", index: 1, flags: Int32(IFF_UP),
            linkType: 6, receivedBytes: 1, sentBytes: 1, baudrate: 0)
        let initial = topology.observe([raw])
        let admission = CollectionAdmission()
        admission.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
        _ = admission.advance(.networkMetadata)
        let old = try #require(admission.issue(.networkMetadata))
        let script = NativeNetworkScript { call in
            if call == 1 {
                admission.transition(CollectionBoundary(revision: 1, sequence: 1,
                    epoch: 1, stopped: true))
            }
            return nativeNetwork("en0", index: 1, registry: 7)
        }
        let reader = SystemNetworkMetadataReader(topology: topology, nativeRead: { script.read() })
        let source = NetworkMetadataSource(reader: reader, admission: admission)
        let store = NetworkMetadataStore(admission: admission)
        let discarded = try await throughScheduledProtocol(source, context: old)
        #expect(discarded == nil)
        #expect(topology.currentRevision == initial.revision)
        #expect((await store.status()).latest == nil)

        admission.transition(CollectionBoundary(revision: 2, sequence: 2,
            epoch: 2, stopped: false))
        _ = admission.advance(.networkMetadata)
        let current = try #require(admission.issue(.networkMetadata))
        let result = try #require(try await throughScheduledProtocol(source, context: current))
        if case .available(let snapshot) = result {
            #expect(snapshot.records[0].key.registryID == 7)
        } else { Issue.record("복귀 후 metadata 원본을 읽지 못했습니다") }
        let timestamp = ContinuousClock().now
        #expect(await store.append(TimestampedSample(timestamp: timestamp, value: result,
            collectionEpoch: current.epoch, context: current), context: current))
        #expect(await store.append(TimestampedSample(timestamp: timestamp, value: result,
            collectionEpoch: old.epoch, context: old), context: old) == false)
        #expect((await store.status()).lastKnown?.records.count == 1)
    }
}
