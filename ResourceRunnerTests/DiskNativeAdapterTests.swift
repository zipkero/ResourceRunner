import Foundation
import Testing
@testable import ResourceRunner

struct DiskNativeAdapterTests {
    private func driver(id: UInt64) -> DiskDriverReading {
        DiskDriverReading(registryID: id, bsdNames: ["disk\(id)"], kind: .physical,
            kindReason: "hardware", readBytes: 10, writtenBytes: 20,
            readOperations: nil, writeOperations: nil, operationsReason: "unsupported",
            external: .unknown, externalReason: "unknown", removable: nil, ejectable: nil, connection: nil)
    }

    private func volume(identity: String, mount: String, drivers: Set<UInt64>, total: UInt64 = 100,
                        available: UInt64 = 40) -> DiskVolumeReading {
        DiskVolumeReading(identity: identity, mountPaths: [mount], bsdName: "disk3s1",
            fileSystem: "apfs", totalBytes: total, availableBytes: available,
            driverIDs: drivers, scope: drivers.isEmpty ? .unconfirmed : .physical,
            relationReason: "ancestors", sharedCapacity: true)
    }

    @Test func driverRegistryIdentityDeduplicatesAndRejectsConflicts() throws {
        #expect(try DiskNativeRules.uniqueDrivers([driver(id: 1), driver(id: 2)]).count == 2)
        #expect(try DiskNativeRules.uniqueDrivers([driver(id: 1), driver(id: 1)]).count == 1)
        let conflict = DiskDriverReading(registryID: 1, bsdNames: ["disk1"], kind: .physical,
            kindReason: "hardware", readBytes: 11, writtenBytes: 20,
            readOperations: nil, writeOperations: nil, operationsReason: "unsupported",
            external: .unknown, externalReason: "unknown", removable: nil, ejectable: nil, connection: nil)
        #expect(throws: DiskNativeError.self) { try DiskNativeRules.uniqueDrivers([driver(id: 1), conflict]) }
    }

    @Test func apfsRelationSupportsManyToManyAndUnconfirmedRelation() {
        let physical: Set<UInt64> = [1, 2]
        #expect(DiskNativeRules.relatedDrivers(ancestorIDs: [1, 2, 99], physicalIDs: physical) == physical)
        #expect(DiskNativeRules.relatedDrivers(ancestorIDs: [2], physicalIDs: physical) == [2])
        #expect(DiskNativeRules.relatedDrivers(ancestorIDs: [99], physicalIDs: physical).isEmpty)
        #expect(DiskNativeRules.relatedDrivers(ancestorIDs: [], physicalIDs: physical).isEmpty)
    }

    @Test func duplicateMountsMergeWithoutAddingSharedCapacity() throws {
        let merged = try DiskNativeRules.mergeVolumes([
            volume(identity: "uuid:a", mount: "/", drivers: [1, 2]),
            volume(identity: "uuid:a", mount: "/System/Volumes/Data", drivers: [1]),
            volume(identity: "uuid:b", mount: "/Volumes/B", drivers: [2])
        ])
        #expect(merged.count == 2)
        #expect(merged[0].mountPaths.count == 2)
        #expect(merged[0].driverIDs == [1, 2])
        #expect(merged[0].usedBytes == 60)
        #expect(merged[0].totalBytes == 100)
        #expect(merged[0].sharedCapacity)
    }

    @Test func conflictingSharedCapacityIsAnError() {
        #expect(throws: DiskNativeError.self) {
            try DiskNativeRules.mergeVolumes([
                volume(identity: "uuid:a", mount: "/", drivers: [1]),
                volume(identity: "uuid:a", mount: "/other", drivers: [1], total: 200)
            ])
        }
    }

    @Test func capacityRejectsMissingWrongTypeAndInvalidRelation() throws {
        #expect(try DiskNativeRules.capacity(total: NSNumber(value: 100), available: NSNumber(value: 40)).0 == 100)
        #expect(throws: DiskNativeError.self) { try DiskNativeRules.capacity(total: nil, available: 40) }
        #expect(throws: DiskNativeError.self) { try DiskNativeRules.capacity(total: "100", available: 40) }
        #expect(throws: DiskNativeError.self) { try DiskNativeRules.capacity(total: 100, available: 101) }
        #expect(throws: DiskNativeError.self) { try DiskNativeRules.capacity(total: 0, available: 0) }
        #expect(throws: DiskNativeError.self) { try DiskNativeRules.unsigned(NSNumber(value: -1), key: "Bytes (Read)") }
        #expect(throws: DiskNativeError.self) { try DiskNativeRules.unsigned(NSNumber(value: 1.5), key: "Bytes (Read)") }
        #expect(throws: DiskNativeError.self) { try DiskNativeRules.unsigned(NSNumber(value: true), key: "Bytes (Read)") }
    }

    @Test func requiredBytesAndOptionalOperationsAreDistinct() throws {
        #expect(try DiskNativeRules.unsigned(NSNumber(value: 5_000_000_000), key: "Bytes (Read)") == 5_000_000_000)
        #expect(try DiskNativeRules.unsigned(NSNumber(value: UInt64.max), key: "Bytes (Read)") == UInt64.max)
        #expect(throws: DiskNativeError.self) { try DiskNativeRules.unsigned(nil, key: "Bytes (Read)") }
        let unsupported = DiskNativeRules.operations(["Operations (Read)": NSNumber(value: 2)])
        #expect(unsupported.0 == nil && unsupported.1 == nil)
        let supported = DiskNativeRules.operations(["Operations (Read)": NSNumber(value: 2),
                                                    "Operations (Write)": NSNumber(value: 3)])
        #expect(supported.0 == 2 && supported.1 == 3)
    }

    @Test func externalUsesDeviceInternalBeforeConnectionAndNeverRemovable() {
        #expect(DiskNativeRules.external(deviceInternal: true, connection: "USB").0 == .internalDevice)
        #expect(DiskNativeRules.external(deviceInternal: false, connection: "PCI").0 == .externalDevice)
        #expect(DiskNativeRules.external(deviceInternal: nil, connection: "USB").0 == .externalDevice)
        #expect(DiskNativeRules.external(deviceInternal: nil, connection: "PCI").0 == .unknown)
    }
}
