import Foundation
import Darwin

nonisolated struct RatePair: Sendable, Equatable {
    let receivedBytesPerSecond: Double
    let sentBytesPerSecond: Double

    init?(receivedBytesPerSecond: Double, sentBytesPerSecond: Double) {
        guard receivedBytesPerSecond.isFinite, sentBytesPerSecond.isFinite,
              receivedBytesPerSecond >= 0, sentBytesPerSecond >= 0 else { return nil }
        self.receivedBytesPerSecond = receivedBytesPerSecond
        self.sentBytesPerSecond = sentBytesPerSecond
    }
}

nonisolated enum NetworkBaselineReason: Sendable, Equatable {
    case first, newEpoch, topologyChanged, classificationChanged, afterFailure
    case newTarget, nonpositiveElapsed, excessiveGap, counterDecrease, invalidRate
}

nonisolated enum NetworkActivityStatus: Sendable, Equatable {
    case rate, baselineOnly(NetworkBaselineReason), partial(String), disconnected, failure(String)
}

nonisolated struct NetworkInterfaceActivity: Sendable {
    let key: NetworkTargetKey
    let kind: NetworkInterfaceKind
    let classificationReason: String
    let linkActive: Bool?
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let rate: RatePair?
}

nonisolated struct NetworkActivitySample: Sendable {
    let readAt: ContinuousClock.Instant
    let topologyRevision: UInt64
    let interfaces: [NetworkInterfaceActivity]
    /// 확인된 물리 대상만의 부분 합계. 대표값으로 표시할 때는 completeness를 함께 확인해야 합니다.
    let knownPhysicalRates: RatePair?
    let representative: RatePair?
    let physicalTotalsComplete: Bool
    let status: NetworkActivityStatus
    let rateSegment: UInt64
}

/// 차분 기준점과 topology 지문을 한 actor가 소유합니다. native 조회와 metadata actor 접근 뒤
/// 공통 admission이 허용할 때만 후보 기준점을 반영합니다.
actor NetworkActivitySource<Reader: NetworkCounterReading>: ScheduledSampleSource {
    private struct CounterBaseline {
        let received: UInt64
        let sent: UInt64
        let readAt: ContinuousClock.Instant
    }
    private struct Classification: Equatable {
        let kind: NetworkInterfaceKind
        let linkActive: Bool?
        let hasAddress: Bool
    }
    private struct State {
        var epoch: Int?
        var revision: UInt64?
        var baselines: [NetworkTargetKey: CounterBaseline] = [:]
        var classifications: [NetworkTargetKey: Classification] = [:]
        var afterFailure = false
        var segment: UInt64 = 0
    }

    private let reader: Reader
    private let metadata: NetworkMetadataStore?
    private let admission: CollectionAdmission?
    private var state = State()

    init(reader: Reader, metadata: NetworkMetadataStore? = nil,
         admission: CollectionAdmission? = nil) {
        self.reader = reader
        self.metadata = metadata
        self.admission = admission
    }

    func sample(collectionEpoch: Int) async -> NetworkActivitySample? {
        await read(collectionEpoch: collectionEpoch, context: nil)
    }

    func sample(context: CollectionRunContext) async -> NetworkActivitySample? {
        await read(collectionEpoch: context.epoch, context: context)
    }

    private func read(collectionEpoch: Int, context: CollectionRunContext?) async -> NetworkActivitySample? {
        if let context, admission?.isCurrent(context) != true { return nil }
        let snapshot: NetworkCounterSnapshot
        do { snapshot = try reader.read(context: context, admission: admission) }
        catch NetworkNativeError.stale(_) { return nil }
        catch {
            var next = state
            next.baselines.removeAll()
            next.afterFailure = true
            next.segment &+= 1
            let timestamp = ContinuousClock().now
            let sample = NetworkActivitySample(readAt: timestamp,
                topologyRevision: next.revision ?? 0, interfaces: [],
                knownPhysicalRates: nil, representative: nil,
                physicalTotalsComplete: false, status: .failure(String(describing: error)),
                rateSegment: next.segment)
            return commit(sample, next: next, context: context, topologyRevision: nil)
        }
        let view = if let metadata { await metadata.classifications(for: snapshot) }
            else { NetworkClassificationView(records: [:], complete: false) }
        if let context, admission?.isCurrent(context) != true { return nil }
        let (sample, next) = calculate(snapshot, view: view, epoch: collectionEpoch)
        return commit(sample, next: next, context: context,
                      topologyRevision: snapshot.topologyRevision)
    }

    private func commit(_ sample: NetworkActivitySample, next: State,
                        context: CollectionRunContext?, topologyRevision: UInt64?) -> NetworkActivitySample? {
        if let context, let admission {
            return admission.admitOptional(context, phase: .source, timestamp: sample.readAt) {
                if let topologyRevision {
                    return reader.withCurrentTopologyRevision(topologyRevision) {
                        state = next
                        return sample
                    }
                }
                state = next
                return sample
            }
        }
        if let topologyRevision {
            return reader.withCurrentTopologyRevision(topologyRevision) {
                state = next
                return sample
            }
        }
        state = next
        return sample
    }

    private func calculate(_ snapshot: NetworkCounterSnapshot, view: NetworkClassificationView,
                           epoch: Int) -> (NetworkActivitySample, State) {
        var next = state
        let classes = Dictionary(uniqueKeysWithValues: snapshot.interfaces.map { item in
            let record = view.records[item.key]
            return (item.key, Classification(kind: record?.kind ?? .unknown,
                                             linkActive: record?.linkActive,
                                             hasAddress: record.map { !$0.ipv4.isEmpty || !$0.ipv6.isEmpty } ?? false))
        })
        let globalReason: NetworkBaselineReason? = if next.epoch == nil { .first }
            else if next.epoch != epoch { .newEpoch }
            else if next.afterFailure { .afterFailure }
            else if next.revision != snapshot.topologyRevision { .topologyChanged }
            else if Set(next.baselines.keys) != Set(snapshot.interfaces.map(\.key)) { .newTarget }
            else if next.classifications != classes { .classificationChanged }
            else { nil }
        if globalReason != nil { next.baselines.removeAll() }
        next.epoch = epoch
        next.revision = snapshot.topologyRevision
        next.classifications = classes
        next.afterFailure = false

        var details: [NetworkInterfaceActivity] = []
        var newBaselines: [NetworkTargetKey: CounterBaseline] = [:]
        var physicalRates: [RatePair] = []
        var activePhysical = 0
        var incomplete = !view.complete
        var firstGap = globalReason
        for item in snapshot.interfaces {
            let record = view.records[item.key]
            let kind = record?.kind ?? .unknown
            let up = item.raw.flags & Int32(IFF_UP) != 0
            let activePhysicalCandidate = kind == .physicalWiFi || kind == .physicalEthernet || kind == .physicalOther
            let hasAddress = record.map { !$0.ipv4.isEmpty || !$0.ipv6.isEmpty } ?? false
            let activePhysicalTarget = activePhysicalCandidate && up &&
                record?.linkActive == true && hasAddress
            if activePhysicalTarget { activePhysical += 1 }
            if up && (kind == .unknown ||
                (activePhysicalCandidate && (record?.linkActive == nil ||
                                             (record?.linkActive == true && !hasAddress)))) {
                incomplete = true
            }
            let previous = next.baselines[item.key]
            let (rate, gap) = Self.rate(item.raw, at: snapshot.readAt, previous: previous,
                                        forcedBaseline: globalReason != nil)
            // 비합산 대상의 카운터 이상은 해당 상세 속도만 비웁니다.
            if let gap, firstGap == nil, activePhysicalTarget { firstGap = gap }
            if activePhysicalTarget {
                if let rate { physicalRates.append(rate) }
                else { incomplete = true }
            }
            details.append(NetworkInterfaceActivity(key: item.key, kind: kind,
                classificationReason: record?.classificationReason ?? "분류 캐시 없음 또는 identity/revision 불일치",
                linkActive: record?.linkActive, receivedBytes: item.raw.receivedBytes,
                sentBytes: item.raw.sentBytes, rate: rate))
            newBaselines[item.key] = CounterBaseline(received: item.raw.receivedBytes,
                sent: item.raw.sentBytes, readAt: snapshot.readAt)
        }
        next.baselines = newBaselines

        let knownPhysicalRates: RatePair? = physicalRates.isEmpty ? nil : RatePair(
            receivedBytesPerSecond: physicalRates.reduce(0) { $0 + $1.receivedBytesPerSecond },
            sentBytesPerSecond: physicalRates.reduce(0) { $0 + $1.sentBytesPerSecond })

        let representative: RatePair?
        let status: NetworkActivityStatus
        if snapshot.interfaces.isEmpty || (activePhysical == 0 && !incomplete) {
            representative = nil
            status = .disconnected
        } else if let firstGap {
            representative = nil
            status = .baselineOnly(firstGap)
        } else if incomplete || physicalRates.count != activePhysical {
            representative = nil
            status = .partial("물리 대상의 식별·연결·속도 일부를 확인하지 못했습니다")
        } else {
            representative = knownPhysicalRates
            status = representative == nil ? .partial("대표 속도 합계가 유한 범위를 벗어났습니다") : .rate
        }
        if representative == nil { next.segment &+= 1 }
        return (NetworkActivitySample(readAt: snapshot.readAt,
            topologyRevision: snapshot.topologyRevision, interfaces: details,
            knownPhysicalRates: knownPhysicalRates, representative: representative,
            physicalTotalsComplete: representative != nil,
            status: status, rateSegment: next.segment), next)
    }

    private static func rate(_ raw: NetworkRawInterface, at timestamp: ContinuousClock.Instant,
                             previous: CounterBaseline?, forcedBaseline: Bool)
        -> (RatePair?, NetworkBaselineReason?) {
        guard !forcedBaseline else { return (nil, nil) }
        guard let previous else { return (nil, .newTarget) }
        let elapsed = previous.readAt.duration(to: timestamp)
        let (seconds, attoseconds) = elapsed.components
        let duration = Double(seconds) + Double(attoseconds) / 1e18
        guard duration > 0 else { return (nil, .nonpositiveElapsed) }
        guard duration <= 10 else { return (nil, .excessiveGap) }
        guard raw.receivedBytes >= previous.received, raw.sentBytes >= previous.sent else {
            return (nil, .counterDecrease)
        }
        let received = Double(raw.receivedBytes - previous.received) / duration
        let sent = Double(raw.sentBytes - previous.sent) / duration
        guard let rate = RatePair(receivedBytesPerSecond: received, sentBytesPerSecond: sent) else {
            return (nil, .invalidRate)
        }
        return (rate, nil)
    }
}

nonisolated struct RateHistoryPoint: Sendable, Equatable {
    let timestamp: ContinuousClock.Instant
    let rate: RatePair
    let collectionEpoch: Int
    let rateSegment: UInt64
}

nonisolated struct NetworkActivityDisplayValue: Sendable {
    let latest: TimestampedSample<NetworkActivitySample>?
    let lastSuccess: TimestampedSample<NetworkActivitySample>?
    let recentHistory: [RateHistoryPoint]
}

/// 유효한 대표 두 속도만 601개 링에 보관합니다. 실패·기준점은 최신 상태만 바꾸고 점을 추가하지 않습니다.
actor NetworkActivityStore: MonitoringSampleSink {
    private let admission: CollectionAdmission?
    private var latest: TimestampedSample<NetworkActivitySample>?
    private var lastSuccess: TimestampedSample<NetworkActivitySample>?
    private var history = CircularBuffer<RateHistoryPoint>(capacity: 601)
    nonisolated let updates: AsyncStream<NetworkActivityDisplayValue>
    private let continuation: AsyncStream<NetworkActivityDisplayValue>.Continuation

    init(admission: CollectionAdmission? = nil) {
        self.admission = admission
        var continuation: AsyncStream<NetworkActivityDisplayValue>.Continuation!
        self.updates = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation = $0 }
        self.continuation = continuation
    }

    func append(_ sample: TimestampedSample<NetworkActivitySample>) {
        latest = sample
        if let rate = sample.value.representative {
            lastSuccess = sample
            history.append(RateHistoryPoint(timestamp: sample.value.readAt, rate: rate,
                collectionEpoch: sample.collectionEpoch, rateSegment: sample.value.rateSegment))
        }
        continuation.yield(snapshot(at: sample.value.readAt))
    }

    func append(_ sample: TimestampedSample<NetworkActivitySample>,
                context: CollectionRunContext) async -> Bool {
        guard let admission else { append(sample); return true }
        return admission.admit(context, phase: .store, timestamp: sample.value.readAt) {
            append(sample)
            return true
        } ?? false
    }

    func snapshot(at now: ContinuousClock.Instant) -> NetworkActivityDisplayValue {
        let threshold = now.advanced(by: .seconds(-600))
        return NetworkActivityDisplayValue(latest: latest, lastSuccess: lastSuccess,
            recentHistory: history.elements.filter { $0.timestamp >= threshold && $0.timestamp <= now })
    }

    var storedHistoryCount: Int { history.count }
}
