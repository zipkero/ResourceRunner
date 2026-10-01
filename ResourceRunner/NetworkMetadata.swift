import Foundation

nonisolated struct NetworkMetadataRecord: Sendable {
    let key: NetworkTargetKey
    let kind: NetworkInterfaceKind
    let classificationReason: String
    let ipv4: [String]
    let ipv6: [String]
    let linkActive: Bool?
    let status: String
    let linkSpeed: String
}

nonisolated struct NetworkMetadataSnapshot: Sendable {
    let readAt: ContinuousClock.Instant
    let topologyRevision: UInt64
    let records: [NetworkMetadataRecord]
    let physicalTotalsComplete: Bool
    let nativeStatus: String
}

nonisolated enum NetworkMetadataResult: Sendable {
    case available(NetworkMetadataSnapshot)
    case failure(String)
}

nonisolated protocol NetworkMetadataReading: Sendable {
    func read() throws -> NetworkMetadataSnapshot
    func read(context: CollectionRunContext?, admission: CollectionAdmission?) throws -> NetworkMetadataSnapshot
}

nonisolated extension NetworkMetadataReading {
    func read(context: CollectionRunContext?, admission: CollectionAdmission?) throws -> NetworkMetadataSnapshot {
        try read()
    }
}

/// 느린 주소·서비스·provider 조회는 빠른 route 카운터 reader와 별도 실행 축에서 수행합니다.
nonisolated struct SystemNetworkMetadataReader: NetworkMetadataReading {
    private let nativeRead: @Sendable () throws -> NetworkNativeSnapshot
    let topology: NetworkTopologyTracker

    init(topology: NetworkTopologyTracker,
         nativeRead: @escaping @Sendable () throws -> NetworkNativeSnapshot = { try NetworkNativeAdapter().read() }) {
        self.nativeRead = nativeRead
        self.topology = topology
    }

    func read() throws -> NetworkMetadataSnapshot {
        try read(context: nil, admission: nil)
    }

    func read(context: CollectionRunContext?, admission: CollectionAdmission?) throws -> NetworkMetadataSnapshot {
        for _ in 0..<3 {
            let expectedRevision = topology.currentRevision
            let native = try nativeRead()
            let readAt = ContinuousClock().now
            let registryIDs = Dictionary(uniqueKeysWithValues: native.interfaces.compactMap { item in
                item.registryID.map { (item.raw.name, $0) }
            })
            let linkStates = Dictionary(uniqueKeysWithValues: native.interfaces.compactMap { item in
                item.linkActive.map { (item.raw.name, $0) }
            })
            let classifications = Dictionary(uniqueKeysWithValues: native.interfaces.map {
                ($0.raw.name, $0.kind)
            })
            let addressPresence = Dictionary(uniqueKeysWithValues: native.interfaces.map {
                ($0.raw.name, !$0.ipv4.isEmpty || !$0.ipv6.isEmpty)
            })
            let observed: (interfaces: [NetworkCounterInterface], revision: UInt64)?
            if let context, let admission {
                var changedRevision = false
                observed = admission.admitOptional(context, phase: .reader, timestamp: readAt) {
                    let value = topology.observeIfCurrent(native.interfaces.map(\.raw),
                        registryIDs: registryIDs, linkStates: linkStates,
                        classifications: classifications, addressPresence: addressPresence,
                        expectedRevision: expectedRevision)
                    if value == nil { changedRevision = true }
                    return value
                }
                if observed == nil && !changedRevision {
                    throw NetworkNativeError.stale("metadata reader context or request order")
                }
            } else {
                observed = topology.observeIfCurrent(native.interfaces.map(\.raw),
                    registryIDs: registryIDs, linkStates: linkStates,
                    classifications: classifications, addressPresence: addressPresence,
                    expectedRevision: expectedRevision)
            }
            guard let observed else { continue }
        let keys = Dictionary(uniqueKeysWithValues: observed.interfaces.map {
            ($0.raw.name, $0.key)
        })
        let records = native.interfaces.compactMap { item -> NetworkMetadataRecord? in
            guard let key = keys[item.raw.name] else { return nil }
            return NetworkMetadataRecord(key: key, kind: item.kind,
                classificationReason: item.classificationReason,
                ipv4: item.ipv4, ipv6: item.ipv6, linkActive: item.linkActive,
                status: item.status, linkSpeed: item.linkSpeed)
        }
        return NetworkMetadataSnapshot(readAt: readAt, topologyRevision: observed.revision,
            records: records, physicalTotalsComplete: native.physicalTotalsComplete,
            nativeStatus: "route=\(native.routeLookup); addresses=\(native.addressLookup); configuration=\(native.configurationLookup); registry=\(native.registryLookup); link=\(native.linkLookup)")
        }
        throw NetworkNativeError.malformed("topology changed during metadata read")
    }
}

actor NetworkMetadataSource<Reader: NetworkMetadataReading>: ScheduledSampleSource {
    private let reader: Reader
    private let admission: CollectionAdmission?

    init(reader: Reader, admission: CollectionAdmission? = nil) {
        self.reader = reader
        self.admission = admission
    }

    func sample(collectionEpoch: Int) -> NetworkMetadataResult? {
        do { return .available(try reader.read(context: nil, admission: admission)) }
        catch { return .failure(String(describing: error)) }
    }

    func sample(context: CollectionRunContext) async -> NetworkMetadataResult? {
        guard admission?.isCurrent(context) != false else { return nil }
        let result: NetworkMetadataResult
        do { result = .available(try reader.read(context: context, admission: admission)) }
        catch NetworkNativeError.stale(_) { return nil }
        catch { result = .failure(String(describing: error)) }
        guard admission?.isCurrent(context) != false else { return nil }
        return result
    }
}

nonisolated struct NetworkMetadataStatus: Sendable {
    let latest: TimestampedSample<NetworkMetadataResult>?
    let lastKnown: NetworkMetadataSnapshot?
}

nonisolated struct NetworkClassificationView: Sendable {
    let records: [NetworkTargetKey: NetworkMetadataRecord]
    let complete: Bool
}

/// 실패에서는 마지막 성공을 보존하되 현재 identity·revision과 다르면 분류 캐시로 돌려주지 않습니다.
actor NetworkMetadataStore: MonitoringSampleSink {
    private let admission: CollectionAdmission?
    private let beforeClassification: (@Sendable () async -> Void)?
    private var latest: TimestampedSample<NetworkMetadataResult>?
    private var lastKnown: NetworkMetadataSnapshot?
    nonisolated let updates: AsyncStream<NetworkMetadataStatus>
    private let continuation: AsyncStream<NetworkMetadataStatus>.Continuation

    init(admission: CollectionAdmission? = nil,
         beforeClassification: (@Sendable () async -> Void)? = nil) {
        self.admission = admission
        self.beforeClassification = beforeClassification
        var continuation: AsyncStream<NetworkMetadataStatus>.Continuation!
        self.updates = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation = $0 }
        self.continuation = continuation
    }

    func append(_ sample: TimestampedSample<NetworkMetadataResult>) {
        latest = sample
        if case .available(let value) = sample.value { lastKnown = value }
        continuation.yield(NetworkMetadataStatus(latest: latest, lastKnown: lastKnown))
    }

    func append(_ sample: TimestampedSample<NetworkMetadataResult>,
                context: CollectionRunContext) async -> Bool {
        guard let admission else { append(sample); return true }
        return admission.admit(context, phase: .store, timestamp: sample.timestamp) {
            append(sample)
            return true
        } ?? false
    }

    func status() -> NetworkMetadataStatus {
        NetworkMetadataStatus(latest: latest, lastKnown: lastKnown)
    }

    func classifications(for snapshot: NetworkCounterSnapshot) async -> NetworkClassificationView {
        if let beforeClassification { await beforeClassification() }
        guard let lastKnown, lastKnown.topologyRevision == snapshot.topologyRevision else {
            return NetworkClassificationView(records: [:], complete: false)
        }
        let currentKeys = Set(snapshot.interfaces.map(\.key))
        let records = Dictionary(uniqueKeysWithValues: lastKnown.records.compactMap { record in
            currentKeys.contains(record.key) ? (record.key, record) : nil
        })
        return NetworkClassificationView(records: records, complete: lastKnown.physicalTotalsComplete)
    }
}
