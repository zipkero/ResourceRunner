import Foundation

nonisolated enum StorageMountState: Sendable, Equatable {
    case mounted, unmounted, relationUnconfirmed
}

nonisolated struct StorageDeviceRecord: Sendable {
    let registryID: UInt64
    let bsdNames: Set<String>
    let external: DiskExternalKind
    let externalReason: String
    let removable: Bool?
    let ejectable: Bool?
    let connection: String?
    let mountState: StorageMountState
}

nonisolated struct StorageMetadataSnapshot: Sendable {
    let readAt: ContinuousClock.Instant
    let topologyRevision: UInt64
    let volumes: [DiskVolumeReading]
    let systemVolume: DiskVolumeReading
    let devices: [StorageDeviceRecord]
    let relationshipsComplete: Bool
    let externalDevicesAbsent: Bool
    let nativeStatus: String
}

nonisolated enum StorageMetadataResult: Sendable {
    case available(StorageMetadataSnapshot)
    case failure(String, revision: UInt64?)
}

nonisolated protocol StorageMetadataReading: Sendable {
    var currentTopologyRevision: UInt64? { get }
    func read() throws -> StorageMetadataSnapshot
    func read(context: CollectionRunContext?, admission: CollectionAdmission?) throws -> StorageMetadataSnapshot
}

nonisolated extension StorageMetadataReading {
    var currentTopologyRevision: UInt64? { nil }
    func read(context: CollectionRunContext?, admission: CollectionAdmission?) throws -> StorageMetadataSnapshot {
        try read()
    }
}

/// 느린 보조 경로가 용량·마운트·DA 관계를 소유합니다. 빠른 드라이버 통계 조회에는 영향을 주지 않습니다.
nonisolated struct SystemStorageMetadataReader: StorageMetadataReading {
    private let nativeRead: @Sendable () throws -> DiskNativeSnapshot
    let topology: DiskTopologyTracker
    var currentTopologyRevision: UInt64? { topology.currentRevision }

    init(topology: DiskTopologyTracker,
         nativeRead: @escaping @Sendable () throws -> DiskNativeSnapshot = { try DiskNativeAdapter().read() }) {
        self.topology = topology
        self.nativeRead = nativeRead
    }

    func read() throws -> StorageMetadataSnapshot { try read(context: nil, admission: nil) }

    func read(context: CollectionRunContext?, admission: CollectionAdmission?) throws -> StorageMetadataSnapshot {
        for _ in 0..<3 {
            let expected = topology.currentRevision
            let native = try nativeRead()
            let readAt = ContinuousClock().now
            let counterDevices = native.drivers.map { driver in
                DiskCounterDevice(registryID: driver.registryID, bsdNames: driver.bsdNames,
                    kind: driver.kind, kindReason: driver.kindReason,
                    readBytes: driver.readBytes, writtenBytes: driver.writtenBytes,
                    readOperations: driver.readOperations, writeOperations: driver.writeOperations,
                    operationsReason: driver.operationsReason, bytesReason: "IOBlockStorageDriver Statistics bytes")
            }
            let observed: UInt64?
            if let context, let admission {
                var topologyRace = false
                observed = admission.admitOptional(context, phase: .reader, timestamp: readAt) {
                    let revision = topology.observeMetadataIfCurrent(counterDevices,
                        mountedVolumes: native.volumes, expectedRevision: expected)
                    if revision == nil { topologyRace = true }
                    return revision
                }
                if observed == nil && !topologyRace { throw DiskNativeError.stale("storage reader context or request order") }
            } else {
                observed = topology.observeMetadataIfCurrent(counterDevices,
                    mountedVolumes: native.volumes, expectedRevision: expected)
            }
            guard let observed else { continue }
            let mountedIDs = native.volumes.reduce(into: Set<UInt64>()) { $0.formUnion($1.driverIDs) }
            let unresolvedMountedVolume = !native.relationshipsComplete ||
                native.volumes.contains { $0.scope == .unconfirmed }
            let devices = native.drivers.map { driver in
                StorageDeviceRecord(registryID: driver.registryID, bsdNames: driver.bsdNames,
                    external: driver.external, externalReason: driver.externalReason,
                    removable: driver.removable, ejectable: driver.ejectable,
                    connection: driver.connection,
                    mountState: mountedIDs.contains(driver.registryID) ? .mounted :
                        (unresolvedMountedVolume ? .relationUnconfirmed : .unmounted))
            }
            return StorageMetadataSnapshot(readAt: readAt, topologyRevision: observed,
                volumes: native.volumes, systemVolume: native.systemVolume, devices: devices,
                relationshipsComplete: native.relationshipsComplete,
                externalDevicesAbsent: !native.drivers.contains { driver in
                    driver.kind != .virtual && driver.external != .internalDevice
                },
                nativeStatus: "\(native.driverLookup); \(native.volumeLookup)")
        }
        throw DiskNativeError.invalid("topology changed during storage read")
    }
}

actor StorageMetadataSource<Reader: StorageMetadataReading>: ScheduledSampleSource {
    private let reader: Reader
    private let admission: CollectionAdmission?

    init(reader: Reader, admission: CollectionAdmission? = nil) {
        self.reader = reader
        self.admission = admission
    }

    func sample(collectionEpoch: Int) -> StorageMetadataResult? {
        do { return .available(try reader.read(context: nil, admission: admission)) }
        catch { return .failure(String(describing: error), revision: reader.currentTopologyRevision) }
    }

    func sample(context: CollectionRunContext) async -> StorageMetadataResult? {
        guard admission?.isCurrent(context) != false else { return nil }
        let startRevision = reader.currentTopologyRevision
        let result: StorageMetadataResult
        do { result = .available(try reader.read(context: context, admission: admission)) }
        catch DiskNativeError.stale(_) { return nil }
        catch {
            guard reader.currentTopologyRevision == startRevision else { return nil }
            result = .failure(String(describing: error), revision: startRevision)
        }
        guard admission?.isCurrent(context) != false else { return nil }
        return result
    }
}

nonisolated struct StorageMetadataStatus: Sendable {
    let latest: TimestampedSample<StorageMetadataResult>?
    let lastKnown: StorageMetadataSnapshot?
}

nonisolated struct StorageRelationshipView: Sendable {
    let devices: [UInt64: StorageDeviceRecord]
    let systemVolume: DiskVolumeReading?
    let volumes: [DiskVolumeReading]
    let complete: Bool
}

actor StorageMetadataStore: MonitoringSampleSink {
    private let admission: CollectionAdmission?
    private let topology: DiskTopologyTracker?
    private var latest: TimestampedSample<StorageMetadataResult>?
    private var lastKnown: StorageMetadataSnapshot?
    nonisolated let updates: AsyncStream<StorageMetadataStatus>
    private let continuation: AsyncStream<StorageMetadataStatus>.Continuation

    init(admission: CollectionAdmission? = nil, topology: DiskTopologyTracker? = nil) {
        self.admission = admission
        self.topology = topology
        var continuation: AsyncStream<StorageMetadataStatus>.Continuation!
        self.updates = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation = $0 }
        self.continuation = continuation
    }

    func append(_ sample: TimestampedSample<StorageMetadataResult>) {
        latest = sample
        if case .available(let snapshot) = sample.value { lastKnown = snapshot }
        continuation.yield(status())
    }

    func append(_ sample: TimestampedSample<StorageMetadataResult>,
                context: CollectionRunContext) async -> Bool {
        guard let admission else { append(sample); return true }
        return admission.admitOptional(context, phase: .store, timestamp: sample.timestamp) {
            if let topology {
                let revision: UInt64?
                switch sample.value {
                case .available(let snapshot): revision = snapshot.topologyRevision
                case .failure(_, let failureRevision): revision = failureRevision
                }
                if let revision { return topology.withCurrentRevision(revision) {
                    append(sample)
                    return true
                } }
            }
            append(sample)
            return true
        } ?? false
    }

    func status() -> StorageMetadataStatus { StorageMetadataStatus(latest: latest, lastKnown: lastKnown) }

    func relationship(for snapshot: DiskCounterSnapshot) -> StorageRelationshipView {
        guard let lastKnown, lastKnown.topologyRevision == snapshot.topologyRevision else {
            return StorageRelationshipView(devices: [:], systemVolume: nil, volumes: [], complete: false)
        }
        let ids = Set(snapshot.devices.map(\.registryID))
        let devices = Dictionary(uniqueKeysWithValues: lastKnown.devices.compactMap { item in
            ids.contains(item.registryID) ? (item.registryID, item) : nil
        })
        return StorageRelationshipView(devices: devices, systemVolume: lastKnown.systemVolume,
            volumes: lastKnown.volumes, complete: lastKnown.relationshipsComplete)
    }
}
