import Foundation

nonisolated enum ResourceActivityPhase: Sendable, Equatable {
    case collecting, measured, partial(String), baseline(String)
    case disconnected, noPhysicalDevice, failure(String), stopped
}

nonisolated enum SupplementalDisplayPhase: Sendable, Equatable {
    case collecting, refreshing, available, partial(String)
    case failure(String), unsupported(String)
}

nonisolated enum ConditionalMetric: Sendable, Equatable {
    case collecting, available(String), unsupported(String), failure(String)
}

nonisolated struct LastKnownRate: Sendable, Equatable {
    let rate: RatePair
    let readAt: ContinuousClock.Instant
}

nonisolated struct NetworkInterfacePresentation: Sendable {
    let key: NetworkTargetKey
    let kind: NetworkInterfaceKind
    let classificationReason: String
    let linkActive: Bool?
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let rate: RatePair?
    let ipv4: [String]
    let ipv6: [String]
    let linkSpeed: ConditionalMetric
}

nonisolated struct NetworkSupplementalPresentation: Sendable {
    let phase: SupplementalDisplayPhase
    /// 원본 metadata가 실제로 읽힌 시각이며 활동 tick 시각으로 대체하지 않습니다.
    let readAt: ContinuousClock.Instant?
    let records: [NetworkMetadataRecord]
    let isLastKnown: Bool
}

nonisolated struct NetworkCardPresentation: Sendable {
    let phase: ResourceActivityPhase
    /// 불완전 합계에서는 확인된 물리 대상의 부분 속도만 담습니다.
    let currentRate: RatePair?
    let currentRateIsPartial: Bool
    let latestReadAt: ContinuousClock.Instant?
    let lastKnownRate: LastKnownRate?
    let topologyRevision: UInt64?
    let interfaces: [NetworkInterfacePresentation]
    let supplemental: NetworkSupplementalPresentation

    static let collecting = NetworkCardPresentation(phase: .collecting, currentRate: nil,
        currentRateIsPartial: false, latestReadAt: nil, lastKnownRate: nil,
        topologyRevision: nil, interfaces: [],
        supplemental: NetworkSupplementalPresentation(phase: .collecting, readAt: nil,
            records: [], isLastKnown: false))

    static func assemble(activity: NetworkActivityDisplayValue?, metadata: NetworkMetadataStatus?,
                         epoch: Int, wasStopped: Bool,
                         currentTopologyRevision: UInt64? = nil) -> NetworkCardPresentation {
        let current = activity?.latest.flatMap {
            $0.collectionEpoch == epoch &&
                (currentTopologyRevision == nil || $0.value.topologyRevision == currentTopologyRevision)
                ? $0.value : nil
        }
        let lastKnown = activity?.lastSuccess.flatMap { sample in
            sample.value.representative.map { LastKnownRate(rate: $0, readAt: sample.value.readAt) }
        }
        let phase: ResourceActivityPhase
        if let current {
            switch current.status {
            case .rate: phase = .measured
            case .partial(let reason): phase = .partial(reason)
            case .baselineOnly(let reason): phase = .baseline(String(describing: reason))
            case .disconnected: phase = .disconnected
            case .failure(let reason): phase = .failure(reason)
            }
        } else if wasStopped { phase = .stopped }
        else if activity?.latest?.collectionEpoch == epoch && currentTopologyRevision != nil {
            phase = .baseline("topologyChanged")
        } else { phase = .collecting }

        let supplemental = supplemental(for: current, metadata: metadata, epoch: epoch)
        let records = Dictionary(uniqueKeysWithValues: supplemental.records.map { ($0.key, $0) })
        let interfaces: [NetworkInterfacePresentation] = current?.interfaces.map { item in
            let record = records[item.key]
            let linkSpeed: ConditionalMetric
            if let record {
                linkSpeed = record.linkSpeed.hasPrefix("unsupported:")
                    ? .unsupported(record.linkSpeed) : .failure("링크 속도 원본을 해석할 수 없음: \(record.linkSpeed)")
            } else if case .failure(let reason) = supplemental.phase {
                linkSpeed = .failure(reason)
            } else { linkSpeed = .collecting }
            return NetworkInterfacePresentation(key: item.key, kind: item.kind,
                classificationReason: item.classificationReason, linkActive: item.linkActive,
                receivedBytes: item.receivedBytes, sentBytes: item.sentBytes, rate: item.rate,
                ipv4: record?.ipv4 ?? [], ipv6: record?.ipv6 ?? [],
                linkSpeed: linkSpeed)
        } ?? []
        let partial = current?.representative == nil && current?.knownPhysicalRates != nil
        return NetworkCardPresentation(phase: phase,
            currentRate: current?.representative ?? current?.knownPhysicalRates,
            currentRateIsPartial: partial,
            latestReadAt: current?.readAt, lastKnownRate: lastKnown,
            topologyRevision: current?.topologyRevision, interfaces: interfaces,
            supplemental: supplemental)
    }

    private static func supplemental(for activity: NetworkActivitySample?,
                                     metadata: NetworkMetadataStatus?, epoch: Int) -> NetworkSupplementalPresentation {
        guard let activity else {
            guard let latest = metadata?.latest else {
                return NetworkSupplementalPresentation(phase: .collecting, readAt: nil,
                    records: [], isLastKnown: false)
            }
            guard latest.collectionEpoch == epoch else {
                return NetworkSupplementalPresentation(phase: .refreshing, readAt: nil,
                    records: [], isLastKnown: false)
            }
            switch latest.value {
            case .available(let snapshot):
                return NetworkSupplementalPresentation(
                    phase: snapshot.physicalTotalsComplete ? .available : .partial("물리 대상 정보 일부 미확인"),
                    readAt: snapshot.readAt, records: snapshot.records, isLastKnown: false)
            case .failure(let reason, let revision):
                let lastKnown = metadata?.lastKnown.flatMap { $0.topologyRevision == revision ? $0 : nil }
                return NetworkSupplementalPresentation(phase: .failure(reason),
                    readAt: lastKnown?.readAt, records: lastKnown?.records ?? [],
                    isLastKnown: lastKnown != nil)
            }
        }
        let revision = activity.topologyRevision
        let keys = Set(activity.interfaces.map(\.key))
        func records(_ snapshot: NetworkMetadataSnapshot) -> [NetworkMetadataRecord] {
            snapshot.records.filter { keys.contains($0.key) }
        }
        guard let latest = metadata?.latest else {
            return NetworkSupplementalPresentation(phase: .refreshing, readAt: nil,
                records: [], isLastKnown: false)
        }
        let lastKnown = metadata?.lastKnown.flatMap { $0.topologyRevision == revision ? $0 : nil }
        guard latest.collectionEpoch == epoch else {
            return NetworkSupplementalPresentation(phase: .refreshing,
                readAt: lastKnown?.readAt, records: lastKnown.map(records) ?? [],
                isLastKnown: lastKnown != nil)
        }
        switch latest.value {
        case .available(let snapshot) where snapshot.topologyRevision == revision:
            let matchingRecords = records(snapshot)
            return NetworkSupplementalPresentation(
                phase: snapshot.physicalTotalsComplete && matchingRecords.count == keys.count
                    ? .available : .partial("대상 identity 또는 물리 정보 일부 미확인"),
                readAt: snapshot.readAt, records: matchingRecords, isLastKnown: false)
        case .failure(let reason, let failureRevision) where failureRevision == revision:
            return NetworkSupplementalPresentation(phase: .failure(reason),
                readAt: lastKnown?.readAt, records: lastKnown.map(records) ?? [],
                isLastKnown: lastKnown != nil)
        default:
            return NetworkSupplementalPresentation(phase: .refreshing, readAt: nil,
                records: [], isLastKnown: false)
        }
    }

    var accessibilityLabel: String {
        var parts = ["Network 카드", phase.accessibilityText]
        if let currentRate {
            let qualifier = currentRateIsPartial ? "확인된 일부 합계" : "현재"
            parts.append("\(qualifier) 다운로드 \(ResourceQuantityFormatter.byteRate(currentRate.receivedBytesPerSecond)), 업로드 \(ResourceQuantityFormatter.byteRate(currentRate.sentBytesPerSecond))")
        } else if let lastKnownRate {
            parts.append("마지막 측정값(과거) 다운로드 \(ResourceQuantityFormatter.byteRate(lastKnownRate.rate.receivedBytesPerSecond)), 업로드 \(ResourceQuantityFormatter.byteRate(lastKnownRate.rate.sentBytesPerSecond))")
        } else { parts.append("측정된 속도 없음") }
        parts.append(supplemental.phase.accessibilityText)
        if supplemental.isLastKnown { parts.append("보조 정보는 마지막 성공 시각의 과거 값") }
        return parts.joined(separator: ", ")
    }

    func stopping() -> NetworkCardPresentation {
        return NetworkCardPresentation(phase: .stopped, currentRate: nil,
            currentRateIsPartial: false, latestReadAt: latestReadAt,
            lastKnownRate: lastKnownRate,
            topologyRevision: topologyRevision,
            interfaces: interfaces.map { item in
                NetworkInterfacePresentation(key: item.key, kind: item.kind,
                    classificationReason: item.classificationReason, linkActive: item.linkActive,
                    receivedBytes: item.receivedBytes, sentBytes: item.sentBytes, rate: nil,
                    ipv4: item.ipv4, ipv6: item.ipv6, linkSpeed: item.linkSpeed)
            }, supplemental: NetworkSupplementalPresentation(phase: supplemental.phase,
                readAt: supplemental.readAt, records: supplemental.records,
                isLastKnown: supplemental.readAt != nil))
    }
}

nonisolated struct DiskCapacityPresentation: Sendable {
    let identity: String
    let totalBytes: UInt64
    let availableBytes: UInt64
    let usedBytes: UInt64
    let sharedCapacity: Bool
    let relationReason: String
    let readAt: ContinuousClock.Instant
}

nonisolated struct DiskDevicePresentation: Sendable {
    let registryID: UInt64
    let bsdNames: Set<String>
    let readBytes: UInt64?
    let writtenBytes: UInt64?
    let bytesReason: String
    let rate: RatePair?
    let readOperations: UInt64?
    let writeOperations: UInt64?
    let operationsRate: DiskOperationRates?
    let operations: ConditionalMetric
    let external: DiskExternalKind?
    let externalReason: String?
    let mountState: StorageMountState?
}

nonisolated struct StorageSupplementalPresentation: Sendable {
    let phase: SupplementalDisplayPhase
    let readAt: ContinuousClock.Instant?
    let capacity: DiskCapacityPresentation?
    let volumes: [DiskVolumeReading]
    let externalDevicesAbsent: Bool?
    let isLastKnown: Bool
}

nonisolated struct DiskCardPresentation: Sendable {
    let phase: ResourceActivityPhase
    let currentRate: RatePair?
    let currentRateIsPartial: Bool
    let latestReadAt: ContinuousClock.Instant?
    let lastKnownRate: LastKnownRate?
    let topologyRevision: UInt64?
    let devices: [DiskDevicePresentation]
    let supplemental: StorageSupplementalPresentation

    static let collecting = DiskCardPresentation(phase: .collecting, currentRate: nil,
        currentRateIsPartial: false, latestReadAt: nil, lastKnownRate: nil,
        topologyRevision: nil, devices: [],
        supplemental: StorageSupplementalPresentation(phase: .collecting, readAt: nil,
            capacity: nil, volumes: [], externalDevicesAbsent: nil, isLastKnown: false))

    static func assemble(activity: DiskActivityDisplayValue?, metadata: StorageMetadataStatus?,
                         epoch: Int, wasStopped: Bool,
                         currentTopologyRevision: UInt64? = nil) -> DiskCardPresentation {
        let current = activity?.latest.flatMap {
            $0.collectionEpoch == epoch &&
                (currentTopologyRevision == nil || $0.value.topologyRevision == currentTopologyRevision)
                ? $0.value : nil
        }
        let lastKnown = activity?.lastSuccess.flatMap { sample in
            sample.value.representative.map { LastKnownRate(rate: $0, readAt: sample.value.readAt) }
        }
        let phase: ResourceActivityPhase
        if let current {
            switch current.status {
            case .rate: phase = .measured
            case .partial(let reason): phase = .partial(reason)
            case .baselineOnly(let reason): phase = .baseline(String(describing: reason))
            case .noPhysicalDevice: phase = .noPhysicalDevice
            case .failure(let reason): phase = .failure(reason)
            }
        } else if wasStopped { phase = .stopped }
        else if activity?.latest?.collectionEpoch == epoch && currentTopologyRevision != nil {
            phase = .baseline("topologyChanged")
        } else { phase = .collecting }
        let supplemental = supplemental(for: current, metadata: metadata, epoch: epoch)
        let matchingDevices: [StorageDeviceRecord]
        if let current, let snapshot = metadata?.lastKnown,
           snapshot.topologyRevision == current.topologyRevision,
           supplemental.readAt != nil {
            matchingDevices = snapshot.devices
        } else { matchingDevices = [] }
        let metadataDevices = Dictionary(uniqueKeysWithValues: matchingDevices.map { ($0.registryID, $0) })
        let devices: [DiskDevicePresentation] = current?.devices.map { item in
            let record = metadataDevices[item.registryID]
            let operations: ConditionalMetric
            if let rate = item.operationsRate {
                operations = .available("Read \(ResourceQuantityFormatter.driverOperationsPerSecond(rate.readsPerSecond)), Write \(ResourceQuantityFormatter.driverOperationsPerSecond(rate.writesPerSecond))")
            } else if item.readOperations == nil || item.writeOperations == nil {
                operations = item.operationsReason.hasPrefix("unsupported")
                    ? .unsupported(item.operationsReason) : .failure(item.operationsReason)
            } else { operations = .collecting }
            return DiskDevicePresentation(registryID: item.registryID, bsdNames: item.bsdNames,
                readBytes: item.readBytes, writtenBytes: item.writtenBytes,
                bytesReason: item.bytesReason, rate: item.rate,
                readOperations: item.readOperations, writeOperations: item.writeOperations,
                operationsRate: item.operationsRate, operations: operations,
                external: record?.external, externalReason: record?.externalReason,
                mountState: record?.mountState)
        } ?? []
        let partial = current?.representative == nil && current?.knownPhysicalRates != nil
        return DiskCardPresentation(phase: phase,
            currentRate: current?.representative ?? current?.knownPhysicalRates,
            currentRateIsPartial: partial,
            latestReadAt: current?.readAt, lastKnownRate: lastKnown,
            topologyRevision: current?.topologyRevision, devices: devices,
            supplemental: supplemental)
    }

    private static func supplemental(for activity: DiskActivitySample?,
                                     metadata: StorageMetadataStatus?, epoch: Int) -> StorageSupplementalPresentation {
        guard let latest = metadata?.latest else {
            return StorageSupplementalPresentation(phase: activity == nil ? .collecting : .refreshing,
                readAt: nil, capacity: nil, volumes: [], externalDevicesAbsent: nil, isLastKnown: false)
        }
        let revision = activity?.topologyRevision
        let lastKnown = metadata?.lastKnown.flatMap { snapshot in
            revision == nil || snapshot.topologyRevision == revision ? snapshot : nil
        }
        func view(_ snapshot: StorageMetadataSnapshot, phase: SupplementalDisplayPhase,
                  stale: Bool) -> StorageSupplementalPresentation {
            let system = snapshot.systemVolume
            let capacity = DiskCapacityPresentation(identity: system.identity,
                totalBytes: system.totalBytes, availableBytes: system.availableBytes,
                usedBytes: system.usedBytes, sharedCapacity: system.sharedCapacity,
                relationReason: system.relationReason, readAt: snapshot.readAt)
            return StorageSupplementalPresentation(phase: phase, readAt: snapshot.readAt,
                capacity: capacity, volumes: snapshot.volumes,
                externalDevicesAbsent: snapshot.externalDevicesAbsent, isLastKnown: stale)
        }
        guard latest.collectionEpoch == epoch else {
            return lastKnown.map { view($0, phase: .refreshing, stale: true) } ??
                StorageSupplementalPresentation(phase: .refreshing, readAt: nil,
                    capacity: nil, volumes: [], externalDevicesAbsent: nil, isLastKnown: false)
        }
        switch latest.value {
        case .available(let snapshot) where revision == nil || snapshot.topologyRevision == revision:
            return view(snapshot, phase: snapshot.relationshipsComplete ? .available : .partial("장치·볼륨 관계 일부 미확인"), stale: false)
        case .failure(let reason, let failureRevision) where revision == nil || failureRevision == revision:
            return lastKnown.map { view($0, phase: .failure(reason), stale: true) } ??
                StorageSupplementalPresentation(phase: .failure(reason), readAt: nil,
                    capacity: nil, volumes: [], externalDevicesAbsent: nil, isLastKnown: false)
        default:
            return StorageSupplementalPresentation(phase: .refreshing, readAt: nil,
                capacity: nil, volumes: [], externalDevicesAbsent: nil, isLastKnown: false)
        }
    }

    var accessibilityLabel: String {
        var parts = ["Disk 카드", phase.accessibilityText]
        if let currentRate {
            let qualifier = currentRateIsPartial ? "확인된 일부 합계" : "현재"
            parts.append("\(qualifier) Read \(ResourceQuantityFormatter.byteRate(currentRate.receivedBytesPerSecond)), Write \(ResourceQuantityFormatter.byteRate(currentRate.sentBytesPerSecond))")
        } else if let lastKnownRate {
            parts.append("마지막 측정값(과거) Read \(ResourceQuantityFormatter.byteRate(lastKnownRate.rate.receivedBytesPerSecond)), Write \(ResourceQuantityFormatter.byteRate(lastKnownRate.rate.sentBytesPerSecond))")
        } else { parts.append("측정된 속도 없음") }
        parts.append(supplemental.phase.accessibilityText)
        if supplemental.isLastKnown { parts.append("보조 정보는 마지막 성공 시각의 과거 값") }
        if let capacity = supplemental.capacity {
            let qualifier = supplemental.isLastKnown ? "마지막 저장 공간(과거)" : "저장 공간"
            parts.append("\(qualifier) 전체 \(ResourceQuantityFormatter.bytes(capacity.totalBytes)), 사용 가능 \(ResourceQuantityFormatter.bytes(capacity.availableBytes)), 사용 중은 전체에서 사용 가능을 뺀 값")
            if capacity.sharedCapacity { parts.append("APFS 공유 공간이며 볼륨별 독점 사용량이 아님") }
        }
        return parts.joined(separator: ", ")
    }

    func stopping() -> DiskCardPresentation {
        return DiskCardPresentation(phase: .stopped, currentRate: nil,
            currentRateIsPartial: false, latestReadAt: latestReadAt,
            lastKnownRate: lastKnownRate,
            topologyRevision: topologyRevision,
            devices: devices.map { item in
                DiskDevicePresentation(registryID: item.registryID, bsdNames: item.bsdNames,
                    readBytes: item.readBytes, writtenBytes: item.writtenBytes,
                    bytesReason: item.bytesReason, rate: nil,
                    readOperations: item.readOperations, writeOperations: item.writeOperations,
                    operationsRate: nil, operations: .collecting,
                    external: item.external, externalReason: item.externalReason,
                    mountState: item.mountState)
            }, supplemental: StorageSupplementalPresentation(phase: supplemental.phase,
                readAt: supplemental.readAt, capacity: supplemental.capacity,
                volumes: supplemental.volumes,
                externalDevicesAbsent: supplemental.externalDevicesAbsent,
                isLastKnown: supplemental.readAt != nil))
    }
}

nonisolated private extension ResourceActivityPhase {
    var accessibilityText: String {
        switch self {
        case .collecting: "수집 중"
        case .measured: "정상 측정"
        case .partial(let reason): "일부 수집 실패: \(reason)"
        case .baseline: "기준점 갱신 중, 현재 속도 없음"
        case .disconnected: "연결 없음, 현재 속도 없음"
        case .noPhysicalDevice: "물리 장치 없음, 현재 속도 없음"
        case .failure(let reason): "활동 조회 실패: \(reason)"
        case .stopped: "수집 중지"
        }
    }
}

nonisolated private extension SupplementalDisplayPhase {
    var accessibilityText: String {
        switch self {
        case .collecting: "보조 정보 수집 중"
        case .refreshing: "보조 정보 갱신 중"
        case .available: "보조 정보 확인됨"
        case .partial(let reason): "일부 수집 실패: \(reason)"
        case .failure(let reason): "일부 수집 실패: 보조 조회 실패 \(reason)"
        case .unsupported(let reason): "보조 정보 미지원: \(reason)"
        }
    }
}
