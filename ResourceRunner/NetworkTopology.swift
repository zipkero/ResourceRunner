import Foundation
import Darwin

/// 이름·index만 재사용돼도 이전 카운터와 보조 정보를 잇지 않는 현재 관측 대상의 키.
nonisolated struct NetworkTargetKey: Hashable, Sendable {
    let name: String
    let index: UInt16
    let registryID: UInt64?
    let lifetime: UInt64
}

nonisolated struct NetworkCounterInterface: Sendable {
    let key: NetworkTargetKey
    let raw: NetworkRawInterface
}

nonisolated struct NetworkCounterSnapshot: Sendable {
    let readAt: ContinuousClock.Instant
    let interfaces: [NetworkCounterInterface]
    let topologyRevision: UInt64
}

/// route 집합과 변경 알림을 함께 누적합니다. 알림 두 건이 다음 tick 전에 합쳐져도 revision은 두 번 전진합니다.
nonisolated final class NetworkTopologyTracker: @unchecked Sendable {
    private struct Base: Hashable {
        let name: String
        let index: UInt16
    }
    private struct Entry {
        var registryID: UInt64?
        var lifetime: UInt64
        var activeFlags: Int32
        var linkActive: Bool?
        var kind: NetworkInterfaceKind?
        var hasAddress: Bool?
    }

    private let lock = NSLock()
    private var entries: [Base: Entry] = [:]
    private var nextLifetime: UInt64 = 0
    private var revision: UInt64 = 0

    var currentRevision: UInt64 { lock.withLock { revision } }

    @discardableResult
    func withCurrentRevision<T>(_ expected: UInt64, _ apply: () -> T) -> T? {
        lock.withLock {
            guard revision == expected else { return nil }
            return apply()
        }
    }

    func noteChange() {
        lock.withLock {
            revision &+= 1
            // 알림 뒤 같은 이름·index가 다시 보이더라도 새 관측 수명으로 취급합니다.
            entries.removeAll()
        }
    }

    func observe(_ raw: [NetworkRawInterface], registryIDs: [String: UInt64]? = nil,
                 linkStates: [String: Bool]? = nil,
                 classifications: [String: NetworkInterfaceKind]? = nil,
                 addressPresence: [String: Bool]? = nil)
        -> (interfaces: [NetworkCounterInterface], revision: UInt64) {
        lock.withLock { observeLocked(raw, registryIDs: registryIDs, linkStates: linkStates,
                                     classifications: classifications, addressPresence: addressPresence) }
    }

    /// 느린 metadata 조회가 시작한 뒤 빠른 route 관측이 전진했으면 과거 집합을 반영하지 않습니다.
    func observeIfCurrent(_ raw: [NetworkRawInterface], registryIDs: [String: UInt64]? = nil,
                          linkStates: [String: Bool]? = nil,
                          classifications: [String: NetworkInterfaceKind]? = nil,
                          addressPresence: [String: Bool]? = nil,
                          expectedRevision: UInt64)
        -> (interfaces: [NetworkCounterInterface], revision: UInt64)? {
        lock.withLock {
            guard revision == expectedRevision else { return nil }
            return observeLocked(raw, registryIDs: registryIDs, linkStates: linkStates,
                                 classifications: classifications, addressPresence: addressPresence)
        }
    }

    private func observeLocked(_ raw: [NetworkRawInterface], registryIDs: [String: UInt64]?,
                               linkStates: [String: Bool]?,
                               classifications: [String: NetworkInterfaceKind]?,
                               addressPresence: [String: Bool]?)
        -> (interfaces: [NetworkCounterInterface], revision: UInt64) {
            let current = raw.filter { $0.flags & Int32(IFF_LOOPBACK) == 0 }
            let bases = Set(current.map { Base(name: $0.name, index: $0.index) })
            let removed = entries.keys.filter { !bases.contains($0) }
            if !removed.isEmpty {
                revision &+= 1
                for base in removed { entries.removeValue(forKey: base) }
            }
            var result: [NetworkCounterInterface] = []
            for item in current {
                let base = Base(name: item.name, index: item.index)
                let activeFlags = item.flags & Int32(IFF_UP)
                let observedRegistry = registryIDs?[item.name]
                if var existing = entries[base] {
                    if registryIDs != nil && existing.registryID != observedRegistry {
                        revision &+= 1
                        nextLifetime &+= 1
                        existing.lifetime = nextLifetime
                        existing.registryID = observedRegistry
                    }
                    if existing.activeFlags != activeFlags {
                        revision &+= 1
                        existing.activeFlags = activeFlags
                    }
                    if linkStates != nil && existing.linkActive != linkStates?[item.name] {
                        revision &+= 1
                        existing.linkActive = linkStates?[item.name]
                    }
                    if classifications != nil && existing.kind != classifications?[item.name] {
                        revision &+= 1
                        existing.kind = classifications?[item.name]
                    }
                    if addressPresence != nil && existing.hasAddress != addressPresence?[item.name] {
                        revision &+= 1
                        existing.hasAddress = addressPresence?[item.name]
                    }
                    entries[base] = existing
                } else {
                    revision &+= 1
                    nextLifetime &+= 1
                    entries[base] = Entry(registryID: observedRegistry,
                                          lifetime: nextLifetime, activeFlags: activeFlags,
                                          linkActive: linkStates?[item.name],
                                          kind: classifications?[item.name],
                                          hasAddress: addressPresence?[item.name])
                }
                let entry = entries[base]!
                result.append(NetworkCounterInterface(key: NetworkTargetKey(name: item.name,
                    index: item.index, registryID: entry.registryID, lifetime: entry.lifetime), raw: item))
            }
            return (result, revision)
    }
}

nonisolated protocol NetworkCounterReading: Sendable {
    func read() throws -> NetworkCounterSnapshot
    func read(context: CollectionRunContext?, admission: CollectionAdmission?) throws -> NetworkCounterSnapshot
    func withCurrentTopologyRevision<T>(_ revision: UInt64, _ apply: () -> T) -> T?
}

nonisolated extension NetworkCounterReading {
    func read(context: CollectionRunContext?, admission: CollectionAdmission?) throws -> NetworkCounterSnapshot {
        try read()
    }

    func withCurrentTopologyRevision<T>(_ revision: UInt64, _ apply: () -> T) -> T? { apply() }
}

/// 빠른 경로는 route 카운터·대상 집합만 읽습니다. 주소·서비스·provider 탐색은 보조 reader가 맡습니다.
nonisolated struct SystemNetworkCounterReader: NetworkCounterReading {
    private let routeRead: @Sendable () throws -> [NetworkRawInterface]
    let topology: NetworkTopologyTracker

    init(topology: NetworkTopologyTracker,
         routeRead: @escaping @Sendable () throws -> [NetworkRawInterface] = { try NetworkRouteReader().read() }) {
        self.topology = topology
        self.routeRead = routeRead
    }

    func read() throws -> NetworkCounterSnapshot {
        try read(context: nil, admission: nil)
    }

    func read(context: CollectionRunContext?, admission: CollectionAdmission?) throws -> NetworkCounterSnapshot {
        for _ in 0..<3 {
            let expectedRevision = topology.currentRevision
            let raw = try routeRead()
            let readAt = ContinuousClock().now
            let observed: (interfaces: [NetworkCounterInterface], revision: UInt64)?
            if let context, let admission {
                var changedRevision = false
                observed = admission.admitOptional(context, phase: .reader, timestamp: readAt) {
                    let value = topology.observeIfCurrent(raw, expectedRevision: expectedRevision)
                    if value == nil { changedRevision = true }
                    return value
                }
                if observed == nil && !changedRevision {
                    throw NetworkNativeError.stale("counter reader context or request order")
                }
            } else {
                observed = topology.observeIfCurrent(raw, expectedRevision: expectedRevision)
            }
            guard let observed else { continue }
            return NetworkCounterSnapshot(readAt: readAt, interfaces: observed.interfaces,
                                          topologyRevision: observed.revision)
        }
        throw NetworkNativeError.malformed("topology changed during counter read")
    }

    func withCurrentTopologyRevision<T>(_ revision: UInt64, _ apply: () -> T) -> T? {
        topology.withCurrentRevision(revision, apply)
    }
}
