import Foundation

nonisolated struct DiskCounterDevice: Sendable {
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
}

nonisolated struct DiskCounterSnapshot: Sendable {
    let readAt: ContinuousClock.Instant
    let devices: [DiskCounterDevice]
    let topologyRevision: UInt64
}

/// 드라이버 ID 집합과 물리 분류의 변화를 누적합니다. 별도 변경 알림은 다음 관측 전에 revision을 전진시킵니다.
nonisolated final class DiskTopologyTracker: @unchecked Sendable {
    private struct Identity: Equatable {
        let bsdNames: Set<String>
        let kind: DiskDeviceKind
    }
    private struct VolumeIdentity: Hashable {
        let identity: String
        let mountPaths: Set<String>
        let driverIDs: Set<UInt64>
        let scope: DiskVolumeScope
    }
    private let lock = NSLock()
    private var entries: [UInt64: Identity] = [:]
    private var volumes: Set<VolumeIdentity>?
    private var revision: UInt64 = 0

    var currentRevision: UInt64 { lock.withLock { revision } }

    func noteChange() {
        lock.withLock { revision &+= 1; entries.removeAll(); volumes = nil }
    }

    @discardableResult
    func withCurrentRevision<T>(_ expected: UInt64, _ apply: () -> T) -> T? {
        lock.withLock {
            guard expected == revision else { return nil }
            return apply()
        }
    }

    func observeIfCurrent(_ devices: [DiskCounterDevice], expectedRevision: UInt64) -> UInt64? {
        lock.withLock {
            guard expectedRevision == revision else { return nil }
            guard let current = identities(devices) else { return nil }
            if current != entries { revision &+= 1; entries = current }
            return revision
        }
    }

    /// 마운트·해제는 드라이버 ID가 같아도 관계 캐시의 수명을 바꿉니다.
    func observeMetadataIfCurrent(_ devices: [DiskCounterDevice],
                                  mountedVolumes: [DiskVolumeReading],
                                  expectedRevision: UInt64) -> UInt64? {
        lock.withLock {
            guard expectedRevision == revision, let current = identities(devices) else { return nil }
            let currentVolumes = Set(mountedVolumes.map {
                VolumeIdentity(identity: $0.identity, mountPaths: $0.mountPaths,
                    driverIDs: $0.driverIDs, scope: $0.scope)
            })
            if current != entries || (volumes != nil && currentVolumes != volumes) {
                revision &+= 1
            }
            entries = current
            volumes = currentVolumes
            return revision
        }
    }

    private func identities(_ devices: [DiskCounterDevice]) -> [UInt64: Identity]? {
        var current: [UInt64: Identity] = [:]
        for device in devices {
            let identity = Identity(bsdNames: device.bsdNames, kind: device.kind)
            if let prior = current[device.registryID], prior != identity { return nil }
            current[device.registryID] = identity
        }
        return current
    }
}

nonisolated protocol DiskCounterReading: Sendable {
    var currentTopologyRevision: UInt64? { get }
    func read() throws -> DiskCounterSnapshot
    func read(context: CollectionRunContext?, admission: CollectionAdmission?) throws -> DiskCounterSnapshot
    func withCurrentTopologyRevision<T>(_ revision: UInt64, _ apply: () -> T) -> T?
}

nonisolated extension DiskCounterReading {
    var currentTopologyRevision: UInt64? { nil }
    func read(context: CollectionRunContext?, admission: CollectionAdmission?) throws -> DiskCounterSnapshot {
        try read()
    }
    func withCurrentTopologyRevision<T>(_ revision: UInt64, _ apply: () -> T) -> T? { apply() }
}

/// 빠른 조회는 IOKit 드라이버 Statistics만 읽고 Disk Arbitration·Foundation 용량 조회를 하지 않습니다.
nonisolated struct SystemDiskCounterReader: DiskCounterReading {
    private let nativeRead: @Sendable () throws -> [DiskCounterDevice]
    let topology: DiskTopologyTracker
    var currentTopologyRevision: UInt64? { topology.currentRevision }

    init(topology: DiskTopologyTracker,
         nativeRead: @escaping @Sendable () throws -> [DiskCounterDevice] = { try DiskNativeAdapter().readCounters() }) {
        self.topology = topology
        self.nativeRead = nativeRead
    }

    func read() throws -> DiskCounterSnapshot { try read(context: nil, admission: nil) }

    func read(context: CollectionRunContext?, admission: CollectionAdmission?) throws -> DiskCounterSnapshot {
        for _ in 0..<3 {
            let expected = topology.currentRevision
            let devices = try nativeRead()
            let readAt = ContinuousClock().now
            let observed: UInt64?
            if let context, let admission {
                var topologyRace = false
                observed = admission.admitOptional(context, phase: .reader, timestamp: readAt) {
                    let revision = topology.observeIfCurrent(devices, expectedRevision: expected)
                    if revision == nil { topologyRace = true }
                    return revision
                }
                if observed == nil && !topologyRace { throw DiskNativeError.stale("counter reader context or request order") }
            } else {
                observed = topology.observeIfCurrent(devices, expectedRevision: expected)
            }
            guard let observed else { continue }
            return DiskCounterSnapshot(readAt: readAt, devices: devices, topologyRevision: observed)
        }
        throw DiskNativeError.invalid("topology changed during counter read")
    }

    func withCurrentTopologyRevision<T>(_ revision: UInt64, _ apply: () -> T) -> T? {
        topology.withCurrentRevision(revision, apply)
    }
}
