import Foundation
import Testing
@testable import ResourceRunner

final class DiskScriptedReader: DiskCounterReading, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<DiskCounterSnapshot, DiskNativeError>]
    let topology: DiskTopologyTracker?
    init(_ results: [Result<DiskCounterSnapshot, DiskNativeError>], topology: DiskTopologyTracker? = nil) {
        self.results = results
        self.topology = topology
    }
    func read() throws -> DiskCounterSnapshot {
        try lock.withLock {
            guard !results.isEmpty else { throw DiskNativeError.invalid("script exhausted") }
            return try results.removeFirst().get()
        }
    }
    func withCurrentTopologyRevision<T>(_ revision: UInt64, _ apply: () -> T) -> T? {
        if let topology { return topology.withCurrentRevision(revision, apply) }
        return apply()
    }
}

private actor DiskReadHold {
    private var continuation: CheckedContinuation<Void, Never>?
    private var calls = 0
    private(set) var entered = false
    func pause() async {
        calls += 1
        guard calls == 1 else { return }
        entered = true
        await withCheckedContinuation { continuation = $0 }
    }
    func resume() { continuation?.resume(); continuation = nil }
}

private func diskWait(_ condition: () async -> Bool) async {
    for _ in 0..<10_000 {
        if await condition() { return }
        await Task.yield()
    }
}

struct DiskActivityTests {
    private let origin = ContinuousClock().now

    private func device(_ id: UInt64 = 1, kind: DiskDeviceKind = .physical,
                        read: UInt64? = 100, write: UInt64? = 200,
                        readOps: UInt64? = 10, writeOps: UInt64? = 20) -> DiskCounterDevice {
        DiskCounterDevice(registryID: id, bsdNames: ["disk\(id)"], kind: kind,
            kindReason: "test provider", readBytes: read, writtenBytes: write,
            readOperations: readOps, writeOperations: writeOps,
            operationsReason: readOps == nil ? "unsupported" : "Statistics operations",
            bytesReason: read == nil || write == nil ? "required bytes missing" : "Statistics bytes")
    }
    private func snapshot(_ second: Int, revision: UInt64 = 1,
                          _ devices: [DiskCounterDevice]) -> DiskCounterSnapshot {
        DiskCounterSnapshot(readAt: origin.advanced(by: .seconds(second)),
            devices: devices, topologyRevision: revision)
    }
    private func gate(_ axis: CollectionAxis = .diskActivity) -> CollectionAdmission {
        let admission = CollectionAdmission()
        admission.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
        _ = admission.advance(axis)
        return admission
    }

    @Test func realReadTimeAndFiveToOneSecondChangeKeepBytesAndOperationsBaseline() async throws {
        let admission = gate()
        let source = DiskActivitySource(reader: DiskScriptedReader([
            .success(snapshot(0, [device()])),
            .success(snapshot(5, [device(read: 150, write: 225, readOps: 20, writeOps: 30)])),
            .success(snapshot(6, [device(read: 160, write: 230, readOps: 23, writeOps: 32)]))
        ]), admission: admission)
        let firstContext = try #require(admission.issue(.diskActivity))
        let first = try #require(await source.sample(context: firstContext))
        #expect(first.status == .baselineOnly(.first))
        #expect(first.devices[0].readBytes == 100)
        let secondContext = try #require(admission.issue(.diskActivity))
        let second = try #require(await source.sample(context: secondContext))
        #expect(second.status == .rate)
        #expect(second.representative == RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 5))
        #expect(second.representativeOperations == DiskOperationRates(readsPerSecond: 2, writesPerSecond: 2))
        _ = admission.advance(.diskActivity)
        let thirdContext = try #require(admission.issue(.diskActivity))
        let third = try #require(await source.sample(context: thirdContext))
        #expect(third.representative == RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 5))
        #expect(third.representativeOperations == DiskOperationRates(readsPerSecond: 3, writesPerSecond: 2))
        #expect(third.rateSegment == second.rateSegment)
    }

    @Test func multiplePhysicalDriversCountOnceWhileVirtualAndAPFSDoNotAddTraffic() async throws {
        let source = DiskActivitySource(reader: DiskScriptedReader([
            .success(snapshot(0, [device(1), device(2, read: 200, write: 300),
                device(3, kind: .virtual, read: 1000, write: 1000)])),
            .success(snapshot(1, [device(1, read: 110, write: 220),
                device(2, read: 230, write: 340),
                device(3, kind: .virtual, read: 5000, write: 6000)])),
            .success(snapshot(2, [device(1, read: 120, write: 230),
                device(2, read: 240, write: 350),
                device(3, kind: .virtual, read: 0, write: 0)]))
        ]))
        _ = await source.sample(collectionEpoch: 0)
        let second = try #require(await source.sample(collectionEpoch: 0))
        #expect(second.representative == RatePair(receivedBytesPerSecond: 40, sentBytesPerSecond: 60))
        #expect(second.devices.count == 3)
        let third = try #require(await source.sample(collectionEpoch: 0))
        #expect(third.representative == RatePair(receivedBytesPerSecond: 20, sentBytesPerSecond: 20))
        #expect(third.devices.first { $0.registryID == 3 }?.rate == nil)
    }

    @Test func requiredBytesMissingIsPartialAndOperationsUnsupportedDoesNotBlockBytes() async throws {
        let source = DiskActivitySource(reader: DiskScriptedReader([
            .success(snapshot(0, [device(), device(2, read: nil, write: 10)])),
            .success(snapshot(1, [device(read: 110, write: 220, readOps: nil, writeOps: nil),
                                  device(2, read: nil, write: 20)]))
        ]))
        _ = await source.sample(collectionEpoch: 0)
        let result = try #require(await source.sample(collectionEpoch: 0))
        #expect(result.knownPhysicalRates == RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 20))
        #expect(result.representative == nil)
        #expect(result.status == .partial("물리 드라이버의 필수 바이트 또는 분류 일부를 확인하지 못했습니다"))
        #expect(result.devices.first?.operationsRate == nil)
        let only = DiskActivitySource(reader: DiskScriptedReader([
            .success(snapshot(0, [device(readOps: nil, writeOps: nil)])),
            .success(snapshot(1, [device(read: 110, write: 220, readOps: nil, writeOps: nil)]))
        ]))
        _ = await only.sample(collectionEpoch: 0)
        let supportedBytes = try #require(await only.sample(collectionEpoch: 0))
        #expect(supportedBytes.status == .rate)
        #expect(supportedBytes.representativeOperations == nil)
    }

    @Test func newlyMissingRequiredBytesRemainPartialEvenWhenBaselineSetChanges() async throws {
        let source = DiskActivitySource(reader: DiskScriptedReader([
            .success(snapshot(0, [device(1), device(2)])),
            .success(snapshot(1, [device(1, read: 110, write: 220),
                                  device(2, read: nil, write: 220)]))
        ]))
        _ = await source.sample(collectionEpoch: 0)
        let result = try #require(await source.sample(collectionEpoch: 0))
        if case .partial = result.status {} else { Issue.record("required Bytes must stay partial") }
        #expect(result.representative == nil)
        #expect(result.knownPhysicalRates == RatePair(receivedBytesPerSecond: 10,
                                                       sentBytesPerSecond: 20))
        #expect(result.devices.first { $0.registryID == 2 }?.bytesReason == "required bytes missing")
        #expect(result.devices.first { $0.registryID == 2 }?.readBytes == nil)
    }

    @Test func optionalOperationsResetDropsOnlyIOPSForThatInterval() async throws {
        let source = DiskActivitySource(reader: DiskScriptedReader([
            .success(snapshot(0, [device()])),
            .success(snapshot(1, [device(read: 110, write: 220, readOps: 1, writeOps: 2)])),
            .success(snapshot(2, [device(read: 120, write: 240, readOps: 4, writeOps: 6)]))
        ]))
        _ = await source.sample(collectionEpoch: 0)
        let reset = try #require(await source.sample(collectionEpoch: 0))
        #expect(reset.status == .rate)
        #expect(reset.representative == RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 20))
        #expect(reset.representativeOperations == nil)
        let resumed = try #require(await source.sample(collectionEpoch: 0))
        #expect(resumed.representativeOperations == DiskOperationRates(readsPerSecond: 3, writesPerSecond: 4))
    }

    @Test func zeroDeltaIsMeasuredZeroRatherThanNoDeviceOrMissingSample() async throws {
        let source = DiskActivitySource(reader: DiskScriptedReader([
            .success(snapshot(0, [device()])),
            .success(snapshot(1, [device()]))
        ]))
        _ = await source.sample(collectionEpoch: 0)
        let idle = try #require(await source.sample(collectionEpoch: 0))
        #expect(idle.status == .rate)
        #expect(idle.representative == RatePair(receivedBytesPerSecond: 0,
                                                 sentBytesPerSecond: 0))
        #expect(idle.representativeOperations == DiskOperationRates(readsPerSecond: 0,
                                                                    writesPerSecond: 0))
    }

    @Test func allContinuityGapsAndFailureRestartHaveNoRate() async throws {
        let source = DiskActivitySource(reader: DiskScriptedReader([
            .success(snapshot(0, [device()])),
            .success(snapshot(0, [device(read: 110, write: 210)])),
            .success(snapshot(11, [device(read: 120, write: 220)])),
            .success(snapshot(12, [device(read: 1, write: 1)])),
            .failure(.invalid("read failed")),
            .success(snapshot(13, [device(read: 2, write: 2)])),
            .success(snapshot(14, [device(read: 3, write: 3)]))
        ]))
        #expect((await source.sample(collectionEpoch: 0))?.status == .baselineOnly(.first))
        #expect((await source.sample(collectionEpoch: 0))?.status == .baselineOnly(.nonpositiveElapsed))
        #expect((await source.sample(collectionEpoch: 0))?.status == .baselineOnly(.excessiveGap))
        #expect((await source.sample(collectionEpoch: 0))?.status == .baselineOnly(.counterDecrease))
        let failed = try #require(await source.sample(collectionEpoch: 0))
        if case .failure = failed.status {} else { Issue.record("failure expected") }
        #expect((await source.sample(collectionEpoch: 0))?.status == .baselineOnly(.afterFailure))
        #expect((await source.sample(collectionEpoch: 0))?.representative ==
                RatePair(receivedBytesPerSecond: 1, sentBytesPerSecond: 1))
    }

    @Test func epochIdReplacementRemovalAndShortNotificationsBreakContinuity() async throws {
        let topology = DiskTopologyTracker()
        let a = device()
        let b = device(2)
        #expect(topology.observeIfCurrent([a], expectedRevision: 0) == 1)
        topology.noteChange()
        topology.noteChange()
        #expect(topology.currentRevision == 3)
        #expect(topology.observeIfCurrent([a], expectedRevision: 3) == 4)
        #expect(topology.observeIfCurrent([b], expectedRevision: 4) == 5)
        #expect(topology.observeIfCurrent([], expectedRevision: 5) == 6)
        let source = DiskActivitySource(reader: DiskScriptedReader([
            .success(snapshot(0, revision: 1, [a])),
            .success(snapshot(1, revision: 1, [device(read: 110, write: 210)])),
            .success(snapshot(2, revision: 2, [b])),
            .success(snapshot(3, revision: 2, [device(2, read: 110, write: 210)])),
            .success(snapshot(4, revision: 2, [])),
            .success(snapshot(5, revision: 3, [a]))
        ]))
        _ = await source.sample(collectionEpoch: 0)
        #expect((await source.sample(collectionEpoch: 0))?.status == .rate)
        let replaced = try #require(await source.sample(collectionEpoch: 0))
        #expect(replaced.status == .baselineOnly(.topologyChanged))
        #expect(replaced.devices.map(\.registryID) == [2])
        #expect((await source.sample(collectionEpoch: 1))?.status == .baselineOnly(.newEpoch))
        let removed = try #require(await source.sample(collectionEpoch: 1))
        #expect(removed.devices.isEmpty)
        #expect(removed.status == .noPhysicalDevice)
        #expect((await source.sample(collectionEpoch: 1))?.status == .baselineOnly(.topologyChanged))
    }

    @Test func historyHas601ValidPairsAnd600SecondMovingWindowWithShortGap() async throws {
        var scripts: [Result<DiskCounterSnapshot, DiskNativeError>] = []
        for index in 0...603 {
            scripts.append(.success(snapshot(index, [device(read: UInt64(100 + index),
                write: UInt64(200 + index))])))
        }
        let admission = gate()
        let source = DiskActivitySource(reader: DiskScriptedReader(scripts), admission: admission)
        let store = DiskActivityStore(admission: admission)
        for _ in 0...603 {
            let context = try #require(admission.issue(.diskActivity))
            let value = try #require(await source.sample(context: context))
            #expect(await store.append(TimestampedSample(timestamp: value.readAt, value: value,
                collectionEpoch: context.epoch), context: context))
        }
        #expect(await store.storedHistoryCount == 601)
        let current = await store.snapshot(at: origin.advanced(by: .seconds(603)))
        #expect(current.recentHistory.count == 601)
        #expect(current.recentHistory.first?.timestamp == origin.advanced(by: .seconds(3)))
        let future = await store.snapshot(at: origin.advanced(by: .seconds(610)))
        #expect(future.recentHistory.count == 594)
        let failContext = try #require(admission.issue(.diskActivity))
        let failed = DiskActivitySample(readAt: origin.advanced(by: .seconds(611)),
            topologyRevision: 1, devices: [], knownPhysicalRates: nil, representative: nil,
            knownPhysicalOperations: nil, representativeOperations: nil,
            physicalTotalsComplete: false, status: .failure("brief"), rateSegment: 1)
        #expect(await store.append(TimestampedSample(timestamp: failed.readAt, value: failed,
            collectionEpoch: 0), context: failContext))
        #expect(await store.storedHistoryCount == 601)
    }

    @Test func briefFailureAndRecoveryCreateDistinctStoredRateSegmentsWithoutZeroPoints() async throws {
        let admission = gate()
        let failureAt = origin.advanced(by: .milliseconds(1500))
        let source = DiskActivitySource(reader: DiskScriptedReader([
            .success(snapshot(0, [device()])),
            .success(snapshot(1, [device(read: 110, write: 220)])),
            .failure(.invalid("brief IOKit failure")),
            .success(snapshot(2, [device(read: 120, write: 240)])),
            .success(snapshot(3, [device(read: 130, write: 260)]))
        ]), admission: admission, now: { failureAt })
        let store = DiskActivityStore(admission: admission)
        for _ in 0..<5 {
            let context = try #require(admission.issue(.diskActivity))
            let sample = try #require(await source.sample(context: context))
            #expect(await store.append(TimestampedSample(timestamp: sample.readAt, value: sample,
                collectionEpoch: context.epoch), context: context))
        }
        let display = await store.snapshot(at: origin + .seconds(3))
        #expect(display.recentHistory.count == 2)
        #expect(display.recentHistory[0].rateSegment != display.recentHistory[1].rateSegment)
        #expect(display.recentHistory[0].rate == RatePair(receivedBytesPerSecond: 10,
                                                          sentBytesPerSecond: 20))
        #expect(display.recentHistory[1].rate == RatePair(receivedBytesPerSecond: 10,
                                                          sentBytesPerSecond: 20))
    }

    @Test func sourceAndStoreRejectBoundaryOrTopologyChangedDuringSuspension() async throws {
        let topology = DiskTopologyTracker()
        let a = device()
        _ = topology.observeIfCurrent([a], expectedRevision: 0)
        let admission = gate()
        let hold = DiskReadHold()
        let source = DiskActivitySource(reader: DiskScriptedReader([
            .success(snapshot(0, [a]))
        ], topology: topology), admission: admission, beforeCommit: { await hold.pause() })
        let context = try #require(admission.issue(.diskActivity))
        let pending = Task { await source.sample(context: context) }
        await diskWait { await hold.entered }
        _ = topology.observeIfCurrent([device(2)], expectedRevision: 1)
        await hold.resume()
        #expect(await pending.value == nil)
        let store = DiskActivityStore(admission: admission, topology: topology)
        let stale = DiskActivitySample(readAt: origin, topologyRevision: 1, devices: [],
            knownPhysicalRates: nil, representative: nil, knownPhysicalOperations: nil,
            representativeOperations: nil, physicalTotalsComplete: false,
            status: .baselineOnly(.first), rateSegment: 1)
        #expect(await store.append(TimestampedSample(timestamp: origin, value: stale,
            collectionEpoch: 0), context: context) == false)
        #expect(await store.statusLatestIsEmpty())
    }

    @Test func lateBoundaryRejectsSourceBaselineAndStoreHistory() async throws {
        let admission = gate()
        let hold = DiskReadHold()
        let source = DiskActivitySource(reader: DiskScriptedReader([
            .success(snapshot(0, [device()])),
            .success(snapshot(1, [device(read: 110, write: 220)]))
        ]), admission: admission, beforeCommit: { await hold.pause() })
        let oldContext = try #require(admission.issue(.diskActivity))
        let old = Task { await source.sample(context: oldContext) }
        await diskWait { await hold.entered }
        admission.transition(CollectionBoundary(revision: 1, sequence: 1, epoch: 1, stopped: true))
        await hold.resume()
        #expect(await old.value == nil)
        admission.transition(CollectionBoundary(revision: 2, sequence: 2, epoch: 2, stopped: false))
        let currentContext = try #require(admission.issue(.diskActivity))
        let current = try #require(await source.sample(context: currentContext))
        #expect(current.status == .baselineOnly(.first))
        let store = DiskActivityStore(admission: admission)
        #expect(await store.append(TimestampedSample(timestamp: origin, value: current,
            collectionEpoch: oldContext.epoch), context: oldContext) == false)
        #expect(await store.storedHistoryCount == 0)
        #expect(await store.append(TimestampedSample(timestamp: current.readAt, value: current,
            collectionEpoch: currentContext.epoch), context: currentContext))
        #expect(await store.storedHistoryCount == 0)
    }
}

private extension DiskActivityStore {
    func statusLatestIsEmpty() -> Bool { snapshot(at: ContinuousClock().now).latest == nil }
}
