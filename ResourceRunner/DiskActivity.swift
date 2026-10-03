import Foundation

nonisolated struct DiskOperationRates: Sendable, Equatable {
    let readsPerSecond: Double
    let writesPerSecond: Double

    init?(readsPerSecond: Double, writesPerSecond: Double) {
        guard readsPerSecond.isFinite, writesPerSecond.isFinite,
              readsPerSecond >= 0, writesPerSecond >= 0 else { return nil }
        self.readsPerSecond = readsPerSecond
        self.writesPerSecond = writesPerSecond
    }
}

nonisolated enum DiskBaselineReason: Sendable, Equatable {
    case first, newEpoch, topologyChanged, afterFailure, newTarget
    case nonpositiveElapsed, excessiveGap, counterDecrease, invalidRate, requiredBytesMissing
}

nonisolated enum DiskActivityStatus: Sendable, Equatable {
    case rate, baselineOnly(DiskBaselineReason), partial(String), noPhysicalDevice, failure(String)
}

nonisolated struct DiskDeviceActivity: Sendable {
    let registryID: UInt64
    let bsdNames: Set<String>
    let kind: DiskDeviceKind
    let kindReason: String
    let readBytes: UInt64?
    let writtenBytes: UInt64?
    let readOperations: UInt64?
    let writeOperations: UInt64?
    let operationsReason: String
    let bytesReason: String
    let rate: RatePair?
    let operationsRate: DiskOperationRates?
}

nonisolated struct DiskActivitySample: Sendable {
    let readAt: ContinuousClock.Instant
    let topologyRevision: UInt64
    let devices: [DiskDeviceActivity]
    let knownPhysicalRates: RatePair?
    let representative: RatePair?
    let knownPhysicalOperations: DiskOperationRates?
    let representativeOperations: DiskOperationRates?
    let physicalTotalsComplete: Bool
    let status: DiskActivityStatus
    let rateSegment: UInt64
}

/// 드라이버의 원시 누적값과 실제 native 읽기 시각을 기준점으로 유지합니다.
actor DiskActivitySource<Reader: DiskCounterReading>: ScheduledSampleSource {
    private struct Baseline {
        let read: UInt64
        let write: UInt64
        let readOps: UInt64?
        let writeOps: UInt64?
        let readAt: ContinuousClock.Instant
    }
    private struct State {
        var epoch: Int?
        var revision: UInt64?
        var observedIDs: Set<UInt64> = []
        var baselines: [UInt64: Baseline] = [:]
        var afterFailure = false
        var segment: UInt64 = 0
    }

    private let reader: Reader
    private let admission: CollectionAdmission?
    private let beforeCommit: (@Sendable () async -> Void)?
    private let now: @Sendable () -> ContinuousClock.Instant
    private var state = State()

    init(reader: Reader, admission: CollectionAdmission? = nil,
         beforeCommit: (@Sendable () async -> Void)? = nil,
         now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock().now }) {
        self.reader = reader
        self.admission = admission
        self.beforeCommit = beforeCommit
        self.now = now
    }

    func sample(collectionEpoch: Int) async -> DiskActivitySample? {
        await read(epoch: collectionEpoch, context: nil)
    }

    func sample(context: CollectionRunContext) async -> DiskActivitySample? {
        await read(epoch: context.epoch, context: context)
    }

    private func read(epoch: Int, context: CollectionRunContext?) async -> DiskActivitySample? {
        if let context, admission?.isCurrent(context) != true { return nil }
        let startRevision = reader.currentTopologyRevision
        let snapshot: DiskCounterSnapshot
        do { snapshot = try reader.read(context: context, admission: admission) }
        catch DiskNativeError.stale(_) { return nil }
        catch {
            guard reader.currentTopologyRevision == startRevision else { return nil }
            var next = state
            next.baselines.removeAll()
            next.afterFailure = true
            next.segment &+= 1
            let sample = DiskActivitySample(readAt: now(),
                topologyRevision: startRevision ?? next.revision ?? 0, devices: [], knownPhysicalRates: nil,
                representative: nil, knownPhysicalOperations: nil, representativeOperations: nil,
                physicalTotalsComplete: false, status: .failure(String(describing: error)),
                rateSegment: next.segment)
            if let beforeCommit { await beforeCommit() }
            return commit(sample, next: next, context: context, expectedTopologyRevision: startRevision)
        }
        let (sample, next) = calculate(snapshot, epoch: epoch,
            maximumGap: SystemMetricsSampling.maximumTickGap(for: context?.interval ?? .seconds(1)))
        if let beforeCommit { await beforeCommit() }
        return commit(sample, next: next, context: context,
                      expectedTopologyRevision: snapshot.topologyRevision)
    }

    private func commit(_ sample: DiskActivitySample, next: State,
                        context: CollectionRunContext?, expectedTopologyRevision: UInt64?) -> DiskActivitySample? {
        if let context, let admission {
            return admission.admitOptional(context, phase: .source, timestamp: sample.readAt) {
                if let expectedTopologyRevision {
                    return reader.withCurrentTopologyRevision(expectedTopologyRevision) {
                        state = next
                        return sample
                    }
                }
                state = next
                return sample
            }
        }
        if let expectedTopologyRevision {
            return reader.withCurrentTopologyRevision(expectedTopologyRevision) {
                state = next
                return sample
            }
        }
        state = next
        return sample
    }

    private func calculate(_ snapshot: DiskCounterSnapshot, epoch: Int,
                           maximumGap: Duration) -> (DiskActivitySample, State) {
        var next = state
        let globalReason: DiskBaselineReason? = if next.epoch == nil { .first }
            else if next.epoch != epoch { .newEpoch }
            else if next.afterFailure { .afterFailure }
            else if next.revision != snapshot.topologyRevision { .topologyChanged }
            else if next.observedIDs != Set(snapshot.devices.map(\.registryID)) { .newTarget }
            else { nil }
        if globalReason != nil { next.baselines.removeAll() }
        next.epoch = epoch
        next.revision = snapshot.topologyRevision
        next.observedIDs = Set(snapshot.devices.map(\.registryID))
        next.afterFailure = false

        var baselines: [UInt64: Baseline] = [:]
        var details: [DiskDeviceActivity] = []
        var physicalRates: [RatePair] = []
        var operationsRates: [DiskOperationRates] = []
        var physicalCount = 0
        var incomplete = false
        var requiredPhysicalBytesMissing = false
        var operationsComplete = true
        var firstGap = globalReason
        var ids = Set<UInt64>()
        for device in snapshot.devices {
            guard ids.insert(device.registryID).inserted else {
                incomplete = true
                continue
            }
            let physical = device.kind == .physical
            if physical { physicalCount += 1 }
            if device.kind == .unknown { incomplete = true }
            var rate: RatePair?
            var operationsRate: DiskOperationRates?
            var gap: DiskBaselineReason?
            if let read = device.readBytes, let write = device.writtenBytes {
                let previous = next.baselines[device.registryID]
                if globalReason == nil {
                    if let previous {
                        let elapsed = previous.readAt.duration(to: snapshot.readAt)
                        let (seconds, attoseconds) = elapsed.components
                        let duration = Double(seconds) + Double(attoseconds) / 1e18
                        if duration <= 0 { gap = .nonpositiveElapsed }
                        else if elapsed > maximumGap { gap = .excessiveGap }
                        else if read < previous.read || write < previous.write { gap = .counterDecrease }
                        else {
                            rate = RatePair(receivedBytesPerSecond: Double(read - previous.read) / duration,
                                            sentBytesPerSecond: Double(write - previous.write) / duration)
                            if rate == nil { gap = .invalidRate }
                            if let currentReadOps = device.readOperations,
                               let currentWriteOps = device.writeOperations,
                               let oldReadOps = previous.readOps, let oldWriteOps = previous.writeOps,
                               currentReadOps >= oldReadOps, currentWriteOps >= oldWriteOps {
                                operationsRate = DiskOperationRates(
                                    readsPerSecond: Double(currentReadOps - oldReadOps) / duration,
                                    writesPerSecond: Double(currentWriteOps - oldWriteOps) / duration)
                            }
                        }
                    } else { gap = .newTarget }
                }
                baselines[device.registryID] = Baseline(read: read, write: write,
                    readOps: device.readOperations, writeOps: device.writeOperations,
                    readAt: snapshot.readAt)
            } else {
                gap = .requiredBytesMissing
                if physical { requiredPhysicalBytesMissing = true }
            }
            if physical {
                if let rate { physicalRates.append(rate) } else { incomplete = true }
                if let operationsRate { operationsRates.append(operationsRate) }
                else { operationsComplete = false }
                if let gap, firstGap == nil { firstGap = gap }
            }
            details.append(DiskDeviceActivity(registryID: device.registryID,
                bsdNames: device.bsdNames, kind: device.kind, kindReason: device.kindReason,
                readBytes: device.readBytes, writtenBytes: device.writtenBytes,
                readOperations: device.readOperations, writeOperations: device.writeOperations,
                operationsReason: device.operationsReason, bytesReason: device.bytesReason,
                rate: rate, operationsRate: operationsRate))
        }
        next.baselines = baselines
        let knownRates = physicalRates.isEmpty ? nil : RatePair(
            receivedBytesPerSecond: physicalRates.reduce(0) { $0 + $1.receivedBytesPerSecond },
            sentBytesPerSecond: physicalRates.reduce(0) { $0 + $1.sentBytesPerSecond })
        let knownOps = operationsRates.isEmpty ? nil : DiskOperationRates(
            readsPerSecond: operationsRates.reduce(0) { $0 + $1.readsPerSecond },
            writesPerSecond: operationsRates.reduce(0) { $0 + $1.writesPerSecond })
        let representative: RatePair?
        let status: DiskActivityStatus
        if snapshot.devices.isEmpty || (physicalCount == 0 && !incomplete) {
            representative = nil
            status = .noPhysicalDevice
        } else if requiredPhysicalBytesMissing {
            representative = nil
            status = .partial("물리 드라이버의 필수 바이트 또는 분류 일부를 확인하지 못했습니다")
        } else if let firstGap, firstGap != .requiredBytesMissing {
            representative = nil
            status = .baselineOnly(firstGap)
        } else if incomplete || physicalRates.count != physicalCount {
            representative = nil
            status = .partial("물리 드라이버의 필수 바이트 또는 분류 일부를 확인하지 못했습니다")
        } else {
            representative = knownRates
            status = representative == nil ? .partial("물리 속도 합계가 유한 범위를 벗어났습니다") : .rate
        }
        if representative == nil { next.segment &+= 1 }
        return (DiskActivitySample(readAt: snapshot.readAt, topologyRevision: snapshot.topologyRevision,
            devices: details, knownPhysicalRates: knownRates, representative: representative,
            knownPhysicalOperations: knownOps,
            representativeOperations: representative != nil && operationsComplete ? knownOps : nil,
            physicalTotalsComplete: representative != nil, status: status, rateSegment: next.segment), next)
    }
}

nonisolated struct DiskActivityDisplayValue: Sendable {
    let latest: TimestampedSample<DiskActivitySample>?
    let lastSuccess: TimestampedSample<DiskActivitySample>?
    let recentHistory: [RateHistoryPoint]
    let firstHistoryPointAt: ContinuousClock.Instant?

    init(latest: TimestampedSample<DiskActivitySample>?,
         lastSuccess: TimestampedSample<DiskActivitySample>?,
         recentHistory: [RateHistoryPoint],
         firstHistoryPointAt: ContinuousClock.Instant? = nil) {
        self.latest = latest
        self.lastSuccess = lastSuccess
        self.recentHistory = recentHistory
        self.firstHistoryPointAt = firstHistoryPointAt
    }
}

actor DiskActivityStore: MonitoringSampleSink {
    private let admission: CollectionAdmission?
    private let topology: DiskTopologyTracker?
    private var latest: TimestampedSample<DiskActivitySample>?
    private var lastSuccess: TimestampedSample<DiskActivitySample>?
    private var firstHistoryPointAt: ContinuousClock.Instant?
    private var history = CircularBuffer<RateHistoryPoint>(capacity: 1203)
    nonisolated let updates: AsyncStream<DiskActivityDisplayValue>
    private let continuation: AsyncStream<DiskActivityDisplayValue>.Continuation

    init(admission: CollectionAdmission? = nil, topology: DiskTopologyTracker? = nil) {
        self.admission = admission
        self.topology = topology
        var continuation: AsyncStream<DiskActivityDisplayValue>.Continuation!
        self.updates = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation = $0 }
        self.continuation = continuation
    }

    func append(_ sample: TimestampedSample<DiskActivitySample>) {
        latest = sample
        if let rate = sample.value.representative {
            if firstHistoryPointAt == nil { firstHistoryPointAt = sample.value.readAt }
            lastSuccess = sample
            history.append(RateHistoryPoint(timestamp: sample.value.readAt, rate: rate,
                collectionEpoch: sample.collectionEpoch, rateSegment: sample.value.rateSegment,
                maximumConnectedGap: SystemMetricsSampling.maximumTickGap(for: sample.context?.interval ?? .seconds(1))))
        }
        continuation.yield(snapshot(at: sample.value.readAt))
    }

    func append(_ sample: TimestampedSample<DiskActivitySample>,
                context: CollectionRunContext) async -> Bool {
        guard let admission else {
            append(TimestampedSample(timestamp: sample.timestamp, value: sample.value,
                collectionEpoch: sample.collectionEpoch, context: context))
            return true
        }
        return admission.admitOptional(context, phase: .store, timestamp: sample.value.readAt) {
            if let topology {
                return topology.withCurrentRevision(sample.value.topologyRevision) {
                    append(TimestampedSample(timestamp: sample.timestamp, value: sample.value,
                        collectionEpoch: sample.collectionEpoch, context: context))
                    return true
                }
            }
            append(TimestampedSample(timestamp: sample.timestamp, value: sample.value,
                collectionEpoch: sample.collectionEpoch, context: context))
            return true
        } ?? false
    }

    func snapshot(at now: ContinuousClock.Instant) -> DiskActivityDisplayValue {
        let threshold = now.advanced(by: .seconds(-600))
        return DiskActivityDisplayValue(latest: latest, lastSuccess: lastSuccess,
            recentHistory: history.elements.filter { $0.timestamp >= threshold && $0.timestamp <= now },
            firstHistoryPointAt: firstHistoryPointAt)
    }

    var storedHistoryCount: Int { history.count }
}
