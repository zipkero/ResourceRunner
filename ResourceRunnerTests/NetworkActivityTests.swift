import Darwin
import Foundation
import Testing
@testable import ResourceRunner

private final class ScriptedNetworkCounterReader: NetworkCounterReading, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<NetworkCounterSnapshot, NetworkNativeError>]
    init(_ results: [Result<NetworkCounterSnapshot, NetworkNativeError>]) { self.results = results }
    func read() throws -> NetworkCounterSnapshot {
        try lock.withLock {
            guard !results.isEmpty else { throw NetworkNativeError.malformed("script exhausted") }
            return try results.removeFirst().get()
        }
    }
}

private actor NetworkReadHold {
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

private func networkWait(_ condition: () async -> Bool) async {
    for _ in 0..<10_000 {
        if await condition() { return }
        await Task.yield()
    }
}

struct NetworkActivityTests {
    private let origin = ContinuousClock().now

    @Test func tenSecondContextUsesActualTwentySecondBoundary() async throws {
        let target = key()
        let metadata = await metadataStore(1, [record(target)])
        let admission = gate()
        admission.setPlan(.running(.seconds(10)), revision: 1, for: .networkActivity)
        let source = NetworkActivitySource(reader: ScriptedNetworkCounterReader([
            .success(snapshot(0, [(target, raw(rx: 100, tx: 100))])),
            .success(snapshot(20, [(target, raw(rx: 300, tx: 200))])),
            .success(snapshot(41, [(target, raw(rx: 510, tx: 305))])),
            .success(snapshot(42, [(target, raw(rx: 520, tx: 310))]))
        ]), metadata: metadata, admission: admission)
        let first = try #require(admission.issue(.networkActivity))
        #expect((await source.sample(context: first))?.status == .baselineOnly(.first))
        let boundaryContext = try #require(admission.issue(.networkActivity))
        let boundary = try #require(await source.sample(context: boundaryContext))
        #expect(boundary.representative == RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 5))
        let excessiveContext = try #require(admission.issue(.networkActivity))
        let excessive = await source.sample(context: excessiveContext)
        #expect(excessive?.status == .baselineOnly(.excessiveGap))
        admission.setPlan(.running(.seconds(1)), revision: 2, for: .networkActivity)
        let resumedContext = try #require(admission.issue(.networkActivity))
        let resumed = try #require(await source.sample(context: resumedContext))
        #expect(resumed.representative == RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 5))
    }

    private func key(_ name: String = "en0", _ index: UInt16 = 1,
                     registry: UInt64? = 7, lifetime: UInt64 = 1) -> NetworkTargetKey {
        NetworkTargetKey(name: name, index: index, registryID: registry, lifetime: lifetime)
    }

    private func raw(_ name: String = "en0", _ index: UInt16 = 1,
                     rx: UInt64, tx: UInt64, up: Bool = true) -> NetworkRawInterface {
        NetworkRawInterface(name: name, index: index, flags: up ? Int32(IFF_UP) : 0,
            linkType: 6, receivedBytes: rx, sentBytes: tx, baudrate: 0)
    }

    private func snapshot(_ seconds: Int, revision: UInt64 = 1,
                          _ entries: [(NetworkTargetKey, NetworkRawInterface)]) -> NetworkCounterSnapshot {
        NetworkCounterSnapshot(readAt: origin.advanced(by: .seconds(seconds)),
            interfaces: entries.map { NetworkCounterInterface(key: $0.0, raw: $0.1) },
            topologyRevision: revision)
    }

    private func record(_ key: NetworkTargetKey, kind: NetworkInterfaceKind = .physicalEthernet,
                        active: Bool? = true) -> NetworkMetadataRecord {
        NetworkMetadataRecord(key: key, kind: kind, classificationReason: "test provider",
            ipv4: ["192.0.2.1"], ipv6: [], linkActive: active,
            status: "test", linkSpeed: "unsupported")
    }

    private func metadata(_ revision: UInt64, _ records: [NetworkMetadataRecord]) -> NetworkMetadataSnapshot {
        NetworkMetadataSnapshot(readAt: origin, topologyRevision: revision,
            records: records, physicalTotalsComplete: true, nativeStatus: "test")
    }

    private func metadataStore(_ revision: UInt64, _ records: [NetworkMetadataRecord]) async -> NetworkMetadataStore {
        let store = NetworkMetadataStore()
        await store.append(TimestampedSample(timestamp: origin,
            value: .available(metadata(revision, records))))
        return store
    }

    private func gate(_ axis: CollectionAxis = .networkActivity) -> CollectionAdmission {
        let gate = CollectionAdmission()
        gate.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
        _ = gate.advance(axis)
        return gate
    }

    @Test func actualReadTimeAndNormalFiveToOneSecondChangeKeepTheBaseline() async throws {
        let target = key()
        let store = await metadataStore(1, [record(target)])
        let reader = ScriptedNetworkCounterReader([
            .success(snapshot(0, [(target, raw(rx: 100, tx: 200))])),
            .success(snapshot(5, [(target, raw(rx: 150, tx: 225))])),
            .success(snapshot(6, [(target, raw(rx: 160, tx: 230))]))
        ])
        let admission = gate()
        let source = NetworkActivitySource(reader: reader, metadata: store, admission: admission)
        let firstContext = try #require(admission.issue(.networkActivity))
        let first = try #require(await source.sample(context: firstContext))
        #expect(first.status == .baselineOnly(.first))
        #expect(first.interfaces[0].receivedBytes == 100)
        let secondContext = try #require(admission.issue(.networkActivity))
        let second = try #require(await source.sample(context: secondContext))
        #expect(second.status == .rate)
        #expect(second.representative == RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 5))
        _ = admission.advance(.networkActivity)
        let thirdContext = try #require(admission.issue(.networkActivity))
        let third = try #require(await source.sample(context: thirdContext))
        #expect(third.status == .rate)
        #expect(third.representative == RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 5))
        #expect(third.rateSegment == second.rateSegment)
    }

    @Test func negativeElapsedAndUnsignedExtremesNeverCreateInvalidRates() async throws {
        let target = key()
        let store = await metadataStore(1, [record(target)])
        let reader = ScriptedNetworkCounterReader([
            .success(snapshot(5, [(target, raw(rx: UInt64.max - 1, tx: 0))])),
            .success(snapshot(4, [(target, raw(rx: UInt64.max, tx: 1))])),
            .success(snapshot(5, [(target, raw(rx: UInt64.max, tx: 2))]))
        ])
        let source = NetworkActivitySource(reader: reader, metadata: store)
        _ = await source.sample(collectionEpoch: 0)
        let reversed = try #require(await source.sample(collectionEpoch: 0))
        #expect(reversed.status == .baselineOnly(.nonpositiveElapsed))
        let recovered = try #require(await source.sample(collectionEpoch: 0))
        #expect(recovered.representative == RatePair(receivedBytesPerSecond: 0,
                                                       sentBytesPerSecond: 1))
        #expect(RatePair(receivedBytesPerSecond: .nan, sentBytesPerSecond: 0) == nil)
        #expect(RatePair(receivedBytesPerSecond: .infinity, sentBytesPerSecond: 0) == nil)
        #expect(RatePair(receivedBytesPerSecond: -1, sentBytesPerSecond: 0) == nil)
    }

    @Test func realZeroIsAValidRateAndVPNIsDetailedButNotSummed() async throws {
        let physical = key()
        let vpn = key("utun0", 2, registry: nil, lifetime: 2)
        let virtual = key("vmenet0", 3, registry: 9, lifetime: 3)
        let store = await metadataStore(1, [record(physical), record(vpn, kind: .vpn),
            record(virtual, kind: .virtual)])
        let entries1 = [(physical, raw(rx: 100, tx: 100)),
                        (vpn, raw("utun0", 2, rx: 1000, tx: 1000)),
                        (virtual, raw("vmenet0", 3, rx: 1000, tx: 1000))]
        let entries2 = [(physical, raw(rx: 100, tx: 100)),
                        (vpn, raw("utun0", 2, rx: 2000, tx: 2000)),
                        (virtual, raw("vmenet0", 3, rx: 2000, tx: 2000))]
        let entries3 = [(physical, raw(rx: 110, tx: 120)),
                        (vpn, raw("utun0", 2, rx: 10, tx: 10)),
                        (virtual, raw("vmenet0", 3, rx: 10, tx: 10))]
        let source = NetworkActivitySource(reader: ScriptedNetworkCounterReader([
            .success(snapshot(0, entries1)), .success(snapshot(1, entries2)),
            .success(snapshot(2, entries3))]), metadata: store)
        _ = await source.sample(collectionEpoch: 0)
        let second = try #require(await source.sample(collectionEpoch: 0))
        #expect(second.status == .rate)
        #expect(second.representative == RatePair(receivedBytesPerSecond: 0, sentBytesPerSecond: 0))
        #expect(second.interfaces.first { $0.kind == .vpn }?.rate ==
                RatePair(receivedBytesPerSecond: 1000, sentBytesPerSecond: 1000))
        let third = try #require(await source.sample(collectionEpoch: 0))
        #expect(third.representative == RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 20))
        #expect(third.interfaces.first { $0.kind == .vpn }?.rate == nil)
    }

    @Test func twoPhysicalTargetsAreSummedOnceAndRemovalClearsCurrentList() async throws {
        let first = key()
        let second = key("en1", 2, registry: 8, lifetime: 2)
        let store = await metadataStore(1, [record(first), record(second)])
        let reader = ScriptedNetworkCounterReader([
            .success(snapshot(0, [(first, raw(rx: 100, tx: 100)),
                                  (second, raw("en1", 2, rx: 200, tx: 200))])),
            .success(snapshot(1, [(first, raw(rx: 110, tx: 120)),
                                  (second, raw("en1", 2, rx: 230, tx: 240))])),
            .success(snapshot(2, revision: 2, [(first, raw(rx: 120, tx: 130))]))
        ])
        let source = NetworkActivitySource(reader: reader, metadata: store)
        _ = await source.sample(collectionEpoch: 0)
        let both = try #require(await source.sample(collectionEpoch: 0))
        #expect(both.representative == RatePair(receivedBytesPerSecond: 40,
                                                sentBytesPerSecond: 60))
        let removed = try #require(await source.sample(collectionEpoch: 0))
        #expect(removed.interfaces.map(\.key.name) == ["en0"])
        #expect(removed.representative == nil)
        #expect(removed.status == .baselineOnly(.topologyChanged))
    }

    @Test func everyInvalidIntervalAndFailureRestartsAtARealBaseline() async throws {
        let target = key()
        let store = await metadataStore(1, [record(target)])
        let cases: [(NetworkCounterSnapshot, NetworkBaselineReason)] = [
            (snapshot(5, [(target, raw(rx: 120, tx: 120))]), .nonpositiveElapsed),
            (snapshot(16, [(target, raw(rx: 120, tx: 120))]), .excessiveGap),
            (snapshot(6, [(target, raw(rx: 90, tx: 120))]), .counterDecrease),
            (snapshot(6, revision: 2, [(target, raw(rx: 120, tx: 120))]), .topologyChanged),
            (snapshot(6, [(key("en1", 2), raw("en1", 2, rx: 120, tx: 120))]), .newTarget)
        ]
        for (invalid, reason) in cases {
            let reader = ScriptedNetworkCounterReader([
                .success(snapshot(0, [(target, raw(rx: 100, tx: 100))])),
                .success(snapshot(5, [(target, raw(rx: 110, tx: 110))])),
                .success(invalid)
            ])
            let source = NetworkActivitySource(reader: reader, metadata: store)
            _ = await source.sample(collectionEpoch: 0)
            _ = await source.sample(collectionEpoch: 0)
            let result = try #require(await source.sample(collectionEpoch: 0))
            #expect(result.status == .baselineOnly(reason) || result.status == .partial("물리 대상의 식별·연결·속도 일부를 확인하지 못했습니다"))
            #expect(result.representative == nil)
        }

        let failureReader = ScriptedNetworkCounterReader([
            .success(snapshot(0, [(target, raw(rx: 100, tx: 100))])),
            .success(snapshot(1, [(target, raw(rx: 110, tx: 110))])),
            .failure(.malformed("injected")),
            .success(snapshot(2, [(target, raw(rx: 120, tx: 120))])),
            .success(snapshot(3, [(target, raw(rx: 130, tx: 130))]))
        ])
        let source = NetworkActivitySource(reader: failureReader, metadata: store)
        let activityStore = NetworkActivityStore()
        let first = try #require(await source.sample(collectionEpoch: 0))
        let valid = try #require(await source.sample(collectionEpoch: 0))
        let failed = try #require(await source.sample(collectionEpoch: 0))
        let resumed = try #require(await source.sample(collectionEpoch: 0))
        let next = try #require(await source.sample(collectionEpoch: 0))
        for value in [first, valid, failed, resumed, next] {
            await activityStore.append(TimestampedSample(timestamp: value.readAt, value: value))
        }
        if case .failure = failed.status {} else { Issue.record("조회 실패 상태가 아닙니다") }
        #expect(resumed.status == .baselineOnly(.afterFailure))
        #expect(next.status == .rate)
        #expect(next.rateSegment != valid.rateSegment)
        let history = await activityStore.snapshot(at: origin + .seconds(3)).recentHistory
        #expect(history.count == 2)
        #expect(history[0].rateSegment != history[1].rateSegment)
    }

    @Test func newEpochAndPartialIdentityDoNotPublishACompleteSum() async throws {
        let target = key()
        let unknown = key("en9", 9, registry: nil, lifetime: 9)
        let store = await metadataStore(1, [record(target), record(unknown, kind: .unknown)])
        let firstEntries = [(target, raw(rx: 100, tx: 100)),
                            (unknown, raw("en9", 9, rx: 100, tx: 100))]
        let nextEntries = [(target, raw(rx: 110, tx: 110)),
                           (unknown, raw("en9", 9, rx: 110, tx: 110))]
        let reader = ScriptedNetworkCounterReader([
            .success(snapshot(0, firstEntries)), .success(snapshot(1, nextEntries)),
            .success(snapshot(2, nextEntries))
        ])
        let source = NetworkActivitySource(reader: reader, metadata: store)
        _ = await source.sample(collectionEpoch: 0)
        let partial = try #require(await source.sample(collectionEpoch: 0))
        if case .partial = partial.status {} else { Issue.record("미확인 물리 대상의 합계를 완전으로 표시했습니다") }
        #expect(partial.representative == nil)
        #expect(partial.knownPhysicalRates == RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 10))
        let newEpoch = try #require(await source.sample(collectionEpoch: 1))
        #expect(newEpoch.status == .baselineOnly(.newEpoch))
    }

    @Test func linkDisconnectAndReconnectDoNotAverageAcrossTheGap() async throws {
        let target = key()
        let store = await metadataStore(1, [record(target)])
        let reader = ScriptedNetworkCounterReader([
            .success(snapshot(0, [(target, raw(rx: 100, tx: 100))])),
            .success(snapshot(1, [(target, raw(rx: 110, tx: 110))])),
            .success(snapshot(2, [(target, raw(rx: 120, tx: 120))])),
            .success(snapshot(3, [(target, raw(rx: 130, tx: 130))])),
            .success(snapshot(4, [(target, raw(rx: 140, tx: 140))]))
        ])
        let source = NetworkActivitySource(reader: reader, metadata: store)
        _ = await source.sample(collectionEpoch: 0)
        let valid = try #require(await source.sample(collectionEpoch: 0))
        await store.append(TimestampedSample(timestamp: origin + .seconds(2),
            value: .available(metadata(1, [record(target, active: false)]))))
        let disconnected = try #require(await source.sample(collectionEpoch: 0))
        #expect(disconnected.status == .disconnected)
        await store.append(TimestampedSample(timestamp: origin + .seconds(3),
            value: .available(metadata(1, [record(target)]))))
        let reconnected = try #require(await source.sample(collectionEpoch: 0))
        #expect(reconnected.status == .baselineOnly(.classificationChanged))
        let next = try #require(await source.sample(collectionEpoch: 0))
        #expect(next.status == .rate)
        #expect(next.rateSegment != valid.rateSegment)
    }

    @Test func topologyLifetimeAndRevisionSurviveRemovalReuseAndMergedNotifications() {
        let topology = NetworkTopologyTracker()
        let original = topology.observe([raw(rx: 1, tx: 1)])
        let empty = topology.observe([])
        let reused = topology.observe([raw(rx: 2, tx: 2)])
        #expect(empty.revision > original.revision)
        #expect(reused.interfaces[0].key != original.interfaces[0].key)
        topology.noteChange()
        topology.noteChange()
        let returned = topology.observe([raw(rx: 3, tx: 3)])
        #expect(returned.revision >= reused.revision + 2)
        #expect(returned.interfaces[0].key != reused.interfaces[0].key)
        let down = topology.observe([raw(rx: 3, tx: 3, up: false)])
        #expect(down.revision > returned.revision)
        let newRegistry = topology.observe([raw(rx: 3, tx: 3, up: false)], registryIDs: ["en0": 88])
        #expect(newRegistry.interfaces[0].key.registryID == 88)
        #expect(newRegistry.interfaces[0].key != down.interfaces[0].key)
        let linkUp = topology.observe([raw(rx: 3, tx: 3, up: false)], linkStates: ["en0": true])
        let linkDown = topology.observe([raw(rx: 3, tx: 3, up: false)], linkStates: ["en0": false])
        #expect(linkDown.revision > linkUp.revision)
        let addressChange = topology.observe([raw(rx: 3, tx: 3, up: false)],
            classifications: ["en0": .physicalEthernet], addressPresence: ["en0": true])
        let noAddress = topology.observe([raw(rx: 3, tx: 3, up: false)],
            classifications: ["en0": .physicalEthernet], addressPresence: ["en0": false])
        #expect(noAddress.revision > addressChange.revision)
    }

    @Test func metadataCacheRequiresExactLifetimeAndRevision() async {
        let old = key()
        let store = await metadataStore(1, [record(old)])
        let reused = key(lifetime: 2)
        let sameName = snapshot(1, [(reused, raw(rx: 1, tx: 1))])
        #expect((await store.classifications(for: sameName)).records.isEmpty)
        let changedRevision = snapshot(1, revision: 2, [(old, raw(rx: 1, tx: 1))])
        #expect((await store.classifications(for: changedRevision)).records.isEmpty)
    }

    @Test func reusedNameAndIndexCannotInheritRateOrMetadata() async throws {
        let old = key()
        let reused = key(lifetime: 2)
        let store = await metadataStore(1, [record(old)])
        let reader = ScriptedNetworkCounterReader([
            .success(snapshot(0, [(old, raw(rx: 100, tx: 100))])),
            .success(snapshot(1, [(old, raw(rx: 110, tx: 110))])),
            .success(snapshot(2, revision: 2, [(reused, raw(rx: 500, tx: 500))])),
            .success(snapshot(3, revision: 2, [(reused, raw(rx: 510, tx: 510))])),
            .success(snapshot(4, revision: 2, [(reused, raw(rx: 520, tx: 520))]))
        ])
        let source = NetworkActivitySource(reader: reader, metadata: store)
        _ = await source.sample(collectionEpoch: 0)
        _ = await source.sample(collectionEpoch: 0)
        let replaced = try #require(await source.sample(collectionEpoch: 0))
        #expect(replaced.status == .baselineOnly(.topologyChanged))
        #expect(replaced.interfaces[0].kind == .unknown)
        #expect(replaced.representative == nil)
        await store.append(TimestampedSample(timestamp: origin + .seconds(3),
            value: .available(metadata(2, [record(reused)]))))
        let classified = try #require(await source.sample(collectionEpoch: 0))
        #expect(classified.status == .baselineOnly(.classificationChanged))
        let measured = try #require(await source.sample(collectionEpoch: 0))
        #expect(measured.representative == RatePair(receivedBytesPerSecond: 10,
                                                     sentBytesPerSecond: 10))
    }

    @Test func staleSourceAndStoreResultsCannotChangeBaselineLatestOrHistory() async throws {
        let target = key()
        let hold = NetworkReadHold()
        let metadata = NetworkMetadataStore(beforeClassification: { await hold.pauseFirst() })
        await metadata.append(TimestampedSample(timestamp: origin,
            value: .available(self.metadata(1, [record(target)]))))
        let reader = ScriptedNetworkCounterReader([
            .success(snapshot(0, [(target, raw(rx: 100, tx: 100))])),
            .success(snapshot(1, [(target, raw(rx: 110, tx: 110))])),
            .success(snapshot(2, [(target, raw(rx: 120, tx: 120))]))
        ])
        let admission = gate()
        let source = NetworkActivitySource(reader: reader, metadata: metadata, admission: admission)
        let store = NetworkActivityStore(admission: admission)
        let old = try #require(admission.issue(.networkActivity))
        let delayed = Task { await source.sample(context: old) }
        await networkWait { await hold.entered }
        admission.transition(CollectionBoundary(revision: 1, sequence: 1, epoch: 1, stopped: true))
        admission.transition(CollectionBoundary(revision: 2, sequence: 2, epoch: 2, stopped: false))
        _ = admission.advance(.networkActivity)
        await hold.resume()
        #expect(await delayed.value == nil)
        let fresh = try #require(admission.issue(.networkActivity))
        let baseline = try #require(await source.sample(context: fresh))
        #expect(baseline.status == .baselineOnly(.first))
        #expect(await store.append(TimestampedSample(timestamp: baseline.readAt,
            value: baseline, collectionEpoch: fresh.epoch, context: fresh), context: fresh))
        let latest = try #require(admission.issue(.networkActivity))
        let valid = try #require(await source.sample(context: latest))
        #expect(valid.representative == RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 10))
        #expect(await store.append(TimestampedSample(timestamp: valid.readAt,
            value: valid, collectionEpoch: latest.epoch, context: latest), context: latest))
        #expect(await store.storedHistoryCount == 1)
        let oldSample = TimestampedSample(timestamp: origin, value: baseline,
            collectionEpoch: old.epoch, context: old)
        #expect(await store.append(oldSample, context: old) == false)
        #expect(await store.storedHistoryCount == 1)
        #expect((await store.snapshot(at: origin + .seconds(2))).latest?.value.representative == valid.representative)
    }

    @Test func topologyChangeDuringMetadataAwaitRejectsOldActivitySnapshot() async throws {
        let topology = NetworkTopologyTracker()
        let nativeRaw = raw(rx: 100, tx: 100)
        let observed = topology.observe([nativeRaw])
        let initialKey = observed.interfaces[0].key
        let hold = NetworkReadHold()
        let metadata = NetworkMetadataStore(beforeClassification: { await hold.pauseFirst() })
        await metadata.append(TimestampedSample(timestamp: origin,
            value: .available(self.metadata(observed.revision, [record(initialKey)]))))
        let reader = SystemNetworkCounterReader(topology: topology, routeRead: { [nativeRaw] })
        let admission = gate()
        let source = NetworkActivitySource(reader: reader, metadata: metadata, admission: admission)
        let activityStore = NetworkActivityStore(admission: admission)
        let old = try #require(admission.issue(.networkActivity))
        let delayed = Task { await source.sample(context: old) }
        await networkWait { await hold.entered }
        topology.noteChange()
        let current = topology.observe([nativeRaw])
        let currentKey = current.interfaces[0].key
        await metadata.append(TimestampedSample(timestamp: origin + .seconds(1),
            value: .available(self.metadata(current.revision, [record(currentKey)]))))
        await hold.resume()
        #expect(await delayed.value == nil)
        #expect((await activityStore.snapshot(at: origin)).latest == nil)
        let fresh = try #require(admission.issue(.networkActivity))
        let baseline = try #require(await source.sample(context: fresh))
        #expect(baseline.status == .baselineOnly(.first))
        #expect(baseline.interfaces[0].key == currentKey)
    }

    @Test func historyKeeps601ValidPairsAndFiltersTheMoving600SecondWindow() async {
        let store = NetworkActivityStore()
        for index in 0..<605 {
            let value = NetworkActivitySample(readAt: origin + .seconds(index),
                topologyRevision: 1, interfaces: [],
                knownPhysicalRates: RatePair(receivedBytesPerSecond: Double(index), sentBytesPerSecond: Double(604 - index)),
                representative: RatePair(receivedBytesPerSecond: Double(index), sentBytesPerSecond: Double(604 - index)),
                physicalTotalsComplete: true, status: .rate, rateSegment: 1)
            await store.append(TimestampedSample(timestamp: value.readAt, value: value))
        }
        #expect(await store.storedHistoryCount == 605)
        let full = await store.snapshot(at: origin + .seconds(604))
        #expect(full.recentHistory.count == 601)
        #expect(full.recentHistory.first?.rate.receivedBytesPerSecond == 4)
        #expect(full.recentHistory.last?.rate.sentBytesPerSecond == 0)
        let moved = await store.snapshot(at: origin + .seconds(1000))
        #expect(moved.recentHistory.first?.rate.receivedBytesPerSecond == 400)
        #expect(moved.recentHistory.count == 205)
    }

    @Test func halfSecondHistoryRetainsBothWindowEndpointsWithBoundedRing() async {
        let store = NetworkActivityStore()
        for index in 0...1204 {
            let time = origin + .milliseconds(index * 500)
            let rate = RatePair(receivedBytesPerSecond: Double(index), sentBytesPerSecond: 1)!
            let value = NetworkActivitySample(readAt: time, topologyRevision: 1,
                interfaces: [], knownPhysicalRates: rate, representative: rate,
                physicalTotalsComplete: true, status: .rate, rateSegment: 1)
            await store.append(TimestampedSample(timestamp: time, value: value))
        }
        #expect(await store.storedHistoryCount == 1203)
        let history = await store.snapshot(at: origin + .seconds(602)).recentHistory
        #expect(history.count == 1201)
        #expect(history.first?.timestamp == origin + .seconds(2))
        #expect(history.last?.timestamp == origin + .seconds(602))
    }
}
