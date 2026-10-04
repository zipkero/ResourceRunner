import Foundation
import DiskArbitration
import IOKit
import Darwin

nonisolated enum DiskNativeError: Error, CustomStringConvertible {
    case native(String, Int32)
    case invalid(String)
    case stale(String)

    var description: String {
        switch self {
        case .native(let call, let code): "\(call) code=\(code)"
        case .invalid(let reason): "invalid disk data: \(reason)"
        case .stale(let reason): "stale disk read: \(reason)"
        }
    }
}

nonisolated enum DiskDeviceKind: String, Sendable {
    case physical, virtual, unknown
}

nonisolated enum DiskExternalKind: String, Sendable {
    case internalDevice, externalDevice, unknown
}

nonisolated enum DiskVolumeScope: String, Sendable, Hashable {
    case physical, virtual, unconfirmed
}

nonisolated struct DiskDriverReading: Sendable {
    let registryID: UInt64
    let bsdNames: Set<String>
    let kind: DiskDeviceKind
    let kindReason: String
    let readBytes: UInt64
    let writtenBytes: UInt64
    let readOperations: UInt64?
    let writeOperations: UInt64?
    let operationsReason: String
    let external: DiskExternalKind
    let externalReason: String
    let removable: Bool?
    let ejectable: Bool?
    let connection: String?
}

nonisolated struct DiskVolumeReading: Sendable {
    let identity: String
    let mountPaths: Set<String>
    let bsdName: String?
    let fileSystem: String?
    let totalBytes: UInt64
    let availableBytes: UInt64
    let driverIDs: Set<UInt64>
    let scope: DiskVolumeScope
    let relationReason: String
    let sharedCapacity: Bool

    var usedBytes: UInt64 { totalBytes - availableBytes }
}

nonisolated struct DiskNativeSnapshot: Sendable {
    let drivers: [DiskDriverReading]
    let volumes: [DiskVolumeReading]
    let systemVolume: DiskVolumeReading
    let driverLookup: String
    let volumeLookup: String
    let physicalTotalsComplete: Bool
    let relationshipsComplete: Bool
}

nonisolated enum DiskNativeRules {
    static func unsigned(_ value: Any?, key: String) throws -> UInt64 {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFNumberGetTypeID(),
              "cCsSiIlLqQ".contains(String(cString: number.objCType)),
              let digits = number.stringValue.utf8.first, digits >= 48, digits <= 57,
              number.stringValue.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              let parsed = UInt64(number.stringValue) else {
            throw DiskNativeError.invalid("\(key) missing or invalid")
        }
        return parsed
    }

    static func capacity(total: Any?, available: Any?) throws -> (UInt64, UInt64) {
        let total = try unsigned(total, key: "volumeTotalCapacityKey")
        let available = try unsigned(available, key: "volumeAvailableCapacityForImportantUsageKey")
        guard total > 0, available <= total else {
            throw DiskNativeError.invalid("capacity relation total=\(total) available=\(available)")
        }
        return (total, available)
    }

    static func operations(_ stats: [String: Any]) -> (UInt64?, UInt64?, String) {
        guard let read = try? unsigned(stats["Operations (Read)"], key: "Operations (Read)"),
              let write = try? unsigned(stats["Operations (Write)"], key: "Operations (Write)") else {
            return (nil, nil, "unsupported: driver Operations missing or invalid")
        }
        return (read, write, "IOBlockStorageDriver Statistics operations")
    }

    static func external(deviceInternal: Bool?, connection: String?) -> (DiskExternalKind, String) {
        if let deviceInternal {
            return deviceInternal ? (.internalDevice, "DA DeviceInternal=true") : (.externalDevice, "DA DeviceInternal=false")
        }
        if let connection {
            let normalized = connection.lowercased()
            if normalized.contains("usb") || normalized.contains("thunderbolt") || normalized.contains("firewire") {
                return (.externalDevice, "DA connection=\(connection)")
            }
        }
        return (.unknown, "DeviceInternal and conclusive external connection unavailable")
    }

    static func uniqueDrivers(_ drivers: [DiskDriverReading]) throws -> [DiskDriverReading] {
        var values: [UInt64: DiskDriverReading] = [:]
        for driver in drivers {
            if let prior = values[driver.registryID] {
                guard prior.readBytes == driver.readBytes, prior.writtenBytes == driver.writtenBytes,
                      prior.kind == driver.kind else {
                    throw DiskNativeError.invalid("conflicting driver registry ID \(driver.registryID)")
                }
            } else { values[driver.registryID] = driver }
        }
        return values.values.sorted { $0.registryID < $1.registryID }
    }

    static func mergeVolumes(_ volumes: [DiskVolumeReading]) throws -> [DiskVolumeReading] {
        var result: [String: DiskVolumeReading] = [:]
        for volume in volumes {
            if let prior = result[volume.identity] {
                guard prior.totalBytes == volume.totalBytes, prior.availableBytes == volume.availableBytes else {
                    throw DiskNativeError.invalid("conflicting capacity for \(volume.identity)")
                }
                result[volume.identity] = DiskVolumeReading(
                    identity: volume.identity, mountPaths: prior.mountPaths.union(volume.mountPaths),
                    bsdName: prior.bsdName ?? volume.bsdName, fileSystem: prior.fileSystem ?? volume.fileSystem,
                    totalBytes: volume.totalBytes, availableBytes: volume.availableBytes,
            driverIDs: prior.driverIDs.union(volume.driverIDs), scope: prior.scope == volume.scope ? prior.scope : .unconfirmed,
                    relationReason: prior.relationReason == volume.relationReason ? prior.relationReason : "multiple observed paths",
                    sharedCapacity: prior.sharedCapacity || volume.sharedCapacity
                )
            } else { result[volume.identity] = volume }
        }
        return result.values.sorted { $0.identity < $1.identity }
    }

    static func relatedDrivers(ancestorIDs: Set<UInt64>, physicalIDs: Set<UInt64>) -> Set<UInt64> {
        ancestorIDs.intersection(physicalIDs)
    }
}

nonisolated struct DiskNativeAdapter {
    nonisolated init() {}

    /// 빠른 경로에서는 드라이버 통계와 물리 분류만 읽습니다. DA·볼륨·용량 탐색은 보조 축의 read()가 담당합니다.
    nonisolated func readCounters() throws -> [DiskCounterDevice] {
        guard let matching = IOServiceMatching("IOBlockStorageDriver") else {
            throw DiskNativeError.invalid("IOServiceMatching IOBlockStorageDriver=nil")
        }
        var iterator: io_iterator_t = 0
        let code = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard code == KERN_SUCCESS else { throw DiskNativeError.native("IOServiceGetMatchingServices", code) }
        defer { IOObjectRelease(iterator) }
        var result: [DiskCounterDevice] = []
        while case let driver = IOIteratorNext(iterator), driver != 0 {
            defer { IOObjectRelease(driver) }
            var id: UInt64 = 0
            let idCode = IORegistryEntryGetRegistryEntryID(driver, &id)
            guard idCode == KERN_SUCCESS else { throw DiskNativeError.native("IORegistryEntryGetRegistryEntryID", idCode) }
            let media = try directWholeMedia(driver)
            guard !media.isEmpty else { continue }
            defer { media.forEach { IOObjectRelease($0) } }
            let names = Set(media.compactMap { property($0, "BSD Name") as? String })
            let ancestry = try parentClasses(driver)
            let path = ancestry.joined(separator: "/")
            let virtual = path.contains("IOHDIX") || path.contains("IODiskImage") || path.contains("IOVirtual") || path.contains("AppleRAID")
            let hardware = path.contains("IOPlatformDevice") || path.contains("IOPCIDevice") || path.contains("IOUSB") || path.contains("IOThunderbolt") || path.contains("AppleANS")
            let kind: DiskDeviceKind = virtual ? .virtual : (hardware ? .physical : .unknown)
            let stats = property(driver, "Statistics") as? [String: Any]
            let read = try? DiskNativeRules.unsigned(stats?["Bytes (Read)"], key: "driver \(id) Bytes (Read)")
            let write = try? DiskNativeRules.unsigned(stats?["Bytes (Write)"], key: "driver \(id) Bytes (Write)")
            let (readOps, writeOps, opsReason) = stats.map(DiskNativeRules.operations) ??
                (nil, nil, "unsupported: driver Statistics absent")
            result.append(DiskCounterDevice(registryID: id, bsdNames: names, kind: kind,
                kindReason: "provider=\(path)", readBytes: read, writtenBytes: write,
                readOperations: readOps, writeOperations: writeOps,
                operationsReason: opsReason,
                bytesReason: read == nil || write == nil ? "driver \(id) required Bytes missing or invalid" : "IOBlockStorageDriver Statistics bytes"))
        }
        var unique: [UInt64: DiskCounterDevice] = [:]
        for item in result {
            if let prior = unique[item.registryID] {
                guard prior.readBytes == item.readBytes, prior.writtenBytes == item.writtenBytes,
                      prior.kind == item.kind else {
                    throw DiskNativeError.invalid("conflicting driver registry ID \(item.registryID)")
                }
            } else { unique[item.registryID] = item }
        }
        return unique.values.sorted { $0.registryID < $1.registryID }
    }

    nonisolated func read() throws -> DiskNativeSnapshot {
        guard let session = DASessionCreate(kCFAllocatorDefault) else {
            throw DiskNativeError.invalid("DASessionCreate=nil")
        }
        let drivers = try readDrivers(session: session)
        let physicalIDs = Set(drivers.filter { $0.kind == .physical }.map(\.registryID))
        let virtualIDs = Set(drivers.filter { $0.kind == .virtual }.map(\.registryID))
        let volumes = try readVolumes(session: session, physicalIDs: physicalIDs, virtualIDs: virtualIDs)
        guard let system = volumes.first(where: { $0.mountPaths.contains("/") }) else {
            throw DiskNativeError.invalid("system volume / absent")
        }
        return DiskNativeSnapshot(
            drivers: drivers, volumes: volumes, systemVolume: system,
            driverLookup: "IOServiceGetMatchingServices=0 count=\(drivers.count)",
            volumeLookup: "getmntinfo=success diskVolumes=\(volumes.count); DASessionCreate=success",
            physicalTotalsComplete: drivers.contains { $0.kind == .physical } && !drivers.contains { $0.kind == .unknown },
            relationshipsComplete: volumes.allSatisfy { $0.scope != .unconfirmed }
        )
    }

    private func readDrivers(session: DASession) throws -> [DiskDriverReading] {
        guard let matching = IOServiceMatching("IOBlockStorageDriver") else {
            throw DiskNativeError.invalid("IOServiceMatching IOBlockStorageDriver=nil")
        }
        var iterator: io_iterator_t = 0
        let code = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard code == KERN_SUCCESS else { throw DiskNativeError.native("IOServiceGetMatchingServices", code) }
        defer { IOObjectRelease(iterator) }
        var result: [DiskDriverReading] = []
        while case let driver = IOIteratorNext(iterator), driver != 0 {
            defer { IOObjectRelease(driver) }
            var id: UInt64 = 0
            let idCode = IORegistryEntryGetRegistryEntryID(driver, &id)
            guard idCode == KERN_SUCCESS else { throw DiskNativeError.native("IORegistryEntryGetRegistryEntryID", idCode) }
            let media = try directWholeMedia(driver)
            guard !media.isEmpty else { continue }
            let names = Set(media.compactMap { property($0, "BSD Name") as? String })
            defer { media.forEach { IOObjectRelease($0) } }
            guard let stats = property(driver, "Statistics") as? [String: Any] else {
                throw DiskNativeError.invalid("driver \(id) Statistics missing")
            }
            let read = try DiskNativeRules.unsigned(stats["Bytes (Read)"], key: "driver \(id) Bytes (Read)")
            let write = try DiskNativeRules.unsigned(stats["Bytes (Write)"], key: "driver \(id) Bytes (Write)")
            let (readOps, writeOps, opsReason) = DiskNativeRules.operations(stats)
            let ancestry = try parentClasses(driver)
            let path = ancestry.joined(separator: "/")
            let virtual = path.contains("IOHDIX") || path.contains("IODiskImage") || path.contains("IOVirtual") || path.contains("AppleRAID")
            let hardware = path.contains("IOPlatformDevice") || path.contains("IOPCIDevice") || path.contains("IOUSB") || path.contains("IOThunderbolt") || path.contains("AppleANS")
            let kind: DiskDeviceKind = virtual ? .virtual : (hardware ? .physical : .unknown)
            let disk = media.first.flatMap { DADiskCreateFromIOMedia(kCFAllocatorDefault, session, $0) }
            let description = disk.flatMap { DADiskCopyDescription($0) as? [String: Any] } ?? [:]
            let internalValue = description[kDADiskDescriptionDeviceInternalKey as String] as? Bool
            let connection = description[kDADiskDescriptionDeviceProtocolKey as String] as? String
            let (external, externalReason) = DiskNativeRules.external(deviceInternal: internalValue, connection: connection)
            result.append(DiskDriverReading(
                registryID: id, bsdNames: names, kind: kind,
                kindReason: "provider=\(path)", readBytes: read, writtenBytes: write,
                readOperations: readOps, writeOperations: writeOps, operationsReason: opsReason,
                external: external, externalReason: externalReason,
                removable: description[kDADiskDescriptionMediaRemovableKey as String] as? Bool,
                ejectable: description[kDADiskDescriptionMediaEjectableKey as String] as? Bool,
                connection: connection
            ))
        }
        return try DiskNativeRules.uniqueDrivers(result).sorted { $0.registryID < $1.registryID }
    }

    private func readVolumes(session: DASession, physicalIDs: Set<UInt64>, virtualIDs: Set<UInt64>) throws -> [DiskVolumeReading] {
        let keys: Set<URLResourceKey> = [.volumeIsLocalKey, .volumeUUIDStringKey,
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        let urls = try mountedDiskURLs()
        var readings: [DiskVolumeReading] = []
        for url in urls {
            let values = try url.resourceValues(forKeys: keys)
            guard url.path == "/" || values.volumeIsLocal == true else { continue }
            // macOS의 회수 가능한 공간 포함 값을 사용하며 미확보를 순수 여유 공간으로 대체하지 않습니다.
            let (total, available) = try DiskNativeRules.capacity(total: values.volumeTotalCapacity, available: values.volumeAvailableCapacityForImportantUsage)
            let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL)
            let desc = disk.flatMap { DADiskCopyDescription($0) as? [String: Any] } ?? [:]
            let bsdName = disk.flatMap { DADiskGetBSDName($0) }.map { String(cString: $0) }
            let media = disk.map { DADiskCopyIOMedia($0) } ?? 0
            var ancestors = Set<UInt64>()
            if media != 0 {
                defer { IOObjectRelease(media) }
                ancestors = try ancestorDriverIDs(media)
            }
            let related = DiskNativeRules.relatedDrivers(ancestorIDs: ancestors, physicalIDs: physicalIDs)
            let virtualRelated = ancestors.intersection(virtualIDs)
            let scope: DiskVolumeScope = !related.isEmpty ? .physical : (!virtualRelated.isEmpty ? .virtual : .unconfirmed)
            let uuid = values.volumeUUIDString ?? (desc[kDADiskDescriptionVolumeUUIDKey as String] as? UUID)?.uuidString
            // APFS의 시스템 snapshot과 Data는 용량 UUID가 같아도 BSD 정체성이 다릅니다.
            let identity = bsdName.map { "uuid:\(uuid ?? "unknown")|bsd:\($0)" } ?? uuid.map { "uuid:\($0)" } ?? "mount:\(url.path)"
            let fs = desc[kDADiskDescriptionVolumeKindKey as String] as? String
            readings.append(DiskVolumeReading(
                identity: identity, mountPaths: [url.path], bsdName: bsdName, fileSystem: fs,
                totalBytes: total, availableBytes: available, driverIDs: related, scope: scope,
                relationReason: media == 0 ? "DADiskCopyIOMedia=0" : "DADiskCopyIOMedia nonzero; ancestor IOBlockStorageDriver IDs=\(ancestors.sorted()); virtual IDs=\(virtualRelated.sorted())",
                sharedCapacity: fs?.lowercased() == "apfs"
            ))
        }
        return try DiskNativeRules.mergeVolumes(readings)
    }

    private func mountedDiskURLs() throws -> [URL] {
        var entries: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&entries, MNT_NOWAIT)
        guard count > 0, let entries else { throw DiskNativeError.native("getmntinfo", errno) }
        var urls: [URL] = []
        var seen = Set<String>()
        for index in 0..<Int(count) {
            var record = entries[index]
            let source = withUnsafePointer(to: &record.f_mntfromname) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
            }
            let path = withUnsafePointer(to: &record.f_mntonname) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
            }
            // 마운트 테이블의 /dev/disk 소스만 볼륨 용량 대상으로 삼습니다.
            guard source.hasPrefix("/dev/disk"), seen.insert(path).inserted else { continue }
            urls.append(URL(fileURLWithPath: path, isDirectory: true))
        }
        guard urls.contains(where: { $0.path == "/" }) else { throw DiskNativeError.invalid("system / absent from getmntinfo") }
        return urls
    }

    private func directWholeMedia(_ driver: io_registry_entry_t) throws -> [io_registry_entry_t] {
        var iterator: io_iterator_t = 0
        let code = IORegistryEntryGetChildIterator(driver, kIOServicePlane, &iterator)
        guard code == KERN_SUCCESS else { throw DiskNativeError.native("IORegistryEntryGetChildIterator", code) }
        defer { IOObjectRelease(iterator) }
        var result: [io_registry_entry_t] = []
        while case let child = IOIteratorNext(iterator), child != 0 {
            if IOObjectConformsTo(child, "IOMedia") != 0 && (property(child, "Whole") as? Bool) == true {
                result.append(child)
            } else { IOObjectRelease(child) }
        }
        return result
    }

    private func parentClasses(_ entry: io_registry_entry_t) throws -> [String] {
        var classes: [String] = []
        var current = entry
        var owned: io_registry_entry_t = 0
        defer { if owned != 0 { IOObjectRelease(owned) } }
        for _ in 0..<32 {
            var name = [CChar](repeating: 0, count: 128)
            if IOObjectGetClass(current, &name) == KERN_SUCCESS { classes.append(String(cString: name)) }
            var parent: io_registry_entry_t = 0
            if IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) != KERN_SUCCESS { break }
            if owned != 0 { IOObjectRelease(owned) }
            owned = parent
            current = parent
        }
        return classes
    }

    private func ancestorDriverIDs(_ media: io_registry_entry_t) throws -> Set<UInt64> {
        var result = Set<UInt64>()
        var visited = Set<UInt64>()
        var pending = [media]
        var depth = 0
        while !pending.isEmpty && depth < 256 {
            let current = pending.removeLast()
            var id: UInt64 = 0
            if IORegistryEntryGetRegistryEntryID(current, &id) == KERN_SUCCESS && visited.insert(id).inserted {
                if IOObjectConformsTo(current, "IOBlockStorageDriver") != 0 { result.insert(id) }
                var iterator: io_iterator_t = 0
                if IORegistryEntryGetParentIterator(current, kIOServicePlane, &iterator) == KERN_SUCCESS {
                    while case let parent = IOIteratorNext(iterator), parent != 0 { pending.append(parent) }
                    IOObjectRelease(iterator)
                }
            }
            if current != media { IOObjectRelease(current) }
            depth += 1
        }
        pending.forEach { if $0 != media { IOObjectRelease($0) } }
        guard pending.isEmpty else { throw DiskNativeError.invalid("IOMedia parent graph exceeds 256 entries") }
        return result
    }

    private func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
