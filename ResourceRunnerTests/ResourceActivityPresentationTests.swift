import Foundation
import Testing
@testable import ResourceRunner

@MainActor
struct ResourceActivityPresentationTests {
    private let origin = ContinuousClock().now
    private let key = NetworkTargetKey(name: "en0", index: 1, registryID: 7, lifetime: 1)

    private func rate(_ rx: Double, _ tx: Double) -> RatePair {
        RatePair(receivedBytesPerSecond: rx, sentBytesPerSecond: tx)!
    }

    private func network(_ status: NetworkActivityStatus, _ speed: RatePair? = nil,
                         partial: RatePair? = nil, revision: UInt64 = 1,
                         at second: Int = 1) -> NetworkActivityDisplayValue {
        let item = NetworkInterfaceActivity(key: key, kind: .physicalEthernet,
            classificationReason: "physical", linkActive: true,
            receivedBytes: 1_000, sentBytes: 2_000, rate: speed)
        let sample = NetworkActivitySample(readAt: origin.advanced(by: .seconds(second)),
            topologyRevision: revision, interfaces: [item],
            knownPhysicalRates: partial ?? speed, representative: speed,
            physicalTotalsComplete: speed != nil, status: status, rateSegment: 1)
        let stamp = TimestampedSample(timestamp: sample.readAt, value: sample)
        return NetworkActivityDisplayValue(latest: stamp,
            lastSuccess: speed == nil ? nil : stamp, recentHistory: [])
    }

    private func metadata(_ revision: UInt64 = 1, key metadataKey: NetworkTargetKey? = nil,
                          failure: String? = nil) -> NetworkMetadataStatus {
        let record = NetworkMetadataRecord(key: metadataKey ?? key,
            kind: .physicalEthernet, classificationReason: "physical",
            ipv4: ["192.0.2.10"], ipv6: [], linkActive: true,
            status: "link active", linkSpeed: "unsupported: negotiated speed unverified")
        let snapshot = NetworkMetadataSnapshot(readAt: origin, topologyRevision: revision,
            records: [record], physicalTotalsComplete: true, nativeStatus: "test")
        let result: NetworkMetadataResult = failure.map { .failure($0, revision: revision) }
            ?? .available(snapshot)
        return NetworkMetadataStatus(latest: TimestampedSample(timestamp: origin, value: result),
            lastKnown: failure == nil ? snapshot : nil)
    }

    private func disk(_ status: DiskActivityStatus, _ speed: RatePair? = nil,
                      partial: RatePair? = nil, revision: UInt64 = 1,
                      at second: Int = 1) -> DiskActivityDisplayValue {
        let item = DiskDeviceActivity(registryID: 8, bsdNames: ["disk0"],
            kind: .physical, kindReason: "physical", readBytes: 4_096,
            writtenBytes: 8_192, readOperations: nil, writeOperations: nil,
            operationsReason: "unsupported: no Operations", bytesReason: "Statistics bytes",
            rate: speed, operationsRate: nil)
        let sample = DiskActivitySample(readAt: origin.advanced(by: .seconds(second)),
            topologyRevision: revision, devices: [item],
            knownPhysicalRates: partial ?? speed, representative: speed,
            knownPhysicalOperations: nil, representativeOperations: nil,
            physicalTotalsComplete: speed != nil, status: status, rateSegment: 1)
        let stamp = TimestampedSample(timestamp: sample.readAt, value: sample)
        return DiskActivityDisplayValue(latest: stamp,
            lastSuccess: speed == nil ? nil : stamp, recentHistory: [])
    }

    private func storage(_ revision: UInt64 = 1, failure: String? = nil) -> StorageMetadataStatus {
        let volume = DiskVolumeReading(identity: "system", mountPaths: ["/"],
            bsdName: "disk3s1", fileSystem: "apfs", totalBytes: 1 << 40,
            availableBytes: 1 << 39, driverIDs: [8], scope: .physical,
            relationReason: "APFS shared", sharedCapacity: true)
        let device = StorageDeviceRecord(registryID: 8, bsdNames: ["disk0"],
            external: .internalDevice, externalReason: "built-in", removable: false,
            ejectable: false, connection: "PCI", mountState: .mounted)
        let snapshot = StorageMetadataSnapshot(readAt: origin, topologyRevision: revision,
            volumes: [volume], systemVolume: volume, devices: [device],
            relationshipsComplete: true, externalDevicesAbsent: true, nativeStatus: "test")
        let result: StorageMetadataResult = failure.map { .failure($0, revision: revision) }
            ?? .available(snapshot)
        return StorageMetadataStatus(latest: TimestampedSample(timestamp: origin, value: result),
            lastKnown: failure == nil ? snapshot : nil)
    }

    @Test func macOSStorageUnitsDoNotChangeBinaryRatesOrCounters() {
        let english = Locale(identifier: "en_US")
        #expect(ResourceQuantityFormatter.storageBytes(994_662_584_320, locale: english) == "994.7 GB")
        #expect(ResourceQuantityFormatter.storageBytes(821_368_794_995, locale: english) == "821.4 GB")
        #expect(ResourceQuantityFormatter.storageBytes(999, locale: english) == "999.0 B")
        #expect(ResourceQuantityFormatter.storageBytes(1_000, locale: english) == "1.0 KB")
        #expect(ResourceQuantityFormatter.storageBytes(1_000_000, locale: english) == "1.0 MB")
        #expect(ResourceQuantityFormatter.storageBytes(1_000_000_000, locale: english) == "1.0 GB")
        #expect(ResourceQuantityFormatter.storageBytes(1_000_000_000_000, locale: english) == "1.0 TB")
        #expect(ResourceQuantityFormatter.bytes(1 << 30, locale: english) == "1.0 GB")
        #expect(ResourceQuantityFormatter.byteRate(Double(1 << 20), locale: english) == "1.0 MB/s")
        #expect(ResourceQuantityFormatter.storageBytes(821_368_794_995, locale: Locale(identifier: "de_DE")) == "821,4 GB")
    }

    @Test func measuredZeroIsDistinctFromNoConnectionBaselineAndFailure() {
        let zero = NetworkCardPresentation.assemble(activity: network(.rate, rate(0, 0)),
            metadata: metadata(), epoch: 0, wasStopped: false)
        #expect(zero.phase == .measured)
        #expect(zero.currentRate == rate(0, 0))
        #expect(zero.accessibilityLabel.contains("0.0 B/s"))
        #expect(zero.interfaces[0].receivedBytes == 1_000)
        #expect(zero.interfaces[0].ipv4 == ["192.0.2.10"])
        #expect(zero.interfaces[0].linkSpeed == .unsupported("unsupported: negotiated speed unverified"))
        let disconnected = NetworkCardPresentation.assemble(activity: network(.disconnected),
            metadata: metadata(), epoch: 0, wasStopped: false)
        #expect(disconnected.phase == .disconnected)
        #expect(disconnected.currentRate == nil)
        let baseline = NetworkCardPresentation.assemble(activity: network(.baselineOnly(.first)),
            metadata: metadata(), epoch: 0, wasStopped: false)
        #expect(baseline.currentRate == nil)
        #expect(baseline.interfaces[0].receivedBytes == 1_000)
        #expect(baseline.accessibilityLabel.contains("기준점 갱신"))
        let failure = NetworkCardPresentation.assemble(activity: network(.failure("route")),
            metadata: metadata(failure: "SC failed"), epoch: 0, wasStopped: false)
        #expect(failure.currentRate == nil)
        #expect(failure.lastKnownRate == nil)
        #expect(failure.accessibilityLabel.contains("측정된 속도 없음"))
        #expect(failure.interfaces[0].linkSpeed == .failure("SC failed"))
    }

    @Test func supplementalFailureDoesNotFreezeFastRateAndIdentityMustMatch() {
        let initial = NetworkCardPresentation.assemble(activity: network(.rate, rate(10, 20)),
            metadata: metadata(failure: "SC failed"), epoch: 0, wasStopped: false)
        let next = NetworkCardPresentation.assemble(activity: network(.rate, rate(30, 40), at: 2),
            metadata: metadata(failure: "SC failed"), epoch: 0, wasStopped: false)
        #expect(initial.currentRate == rate(10, 20))
        #expect(next.currentRate == rate(30, 40))
        #expect(next.supplemental.phase == .failure("SC failed"))
        #expect(next.accessibilityLabel.contains("일부 수집 실패"))
        let replacedKey = NetworkTargetKey(name: "en0", index: 1, registryID: 9, lifetime: 2)
        let mismatch = NetworkCardPresentation.assemble(activity: network(.rate, rate(10, 20)),
            metadata: metadata(key: replacedKey), epoch: 0, wasStopped: false)
        #expect(mismatch.interfaces[0].ipv4.isEmpty)
        #expect(mismatch.supplemental.phase == .partial("대상 identity 또는 물리 정보 일부 미확인"))
        let changed = NetworkCardPresentation.assemble(activity: network(.rate, rate(10, 20), revision: 2),
            metadata: metadata(), epoch: 0, wasStopped: false)
        #expect(changed.supplemental.phase == .refreshing)
        #expect(changed.interfaces[0].ipv4.isEmpty)
    }

    @Test func partialRateNeverBecomesFullLastKnownOnStop() {
        let partial = NetworkCardPresentation.assemble(activity: network(.partial("unknown physical"),
            partial: rate(10, 20)), metadata: nil, epoch: 0, wasStopped: false)
        #expect(partial.currentRateIsPartial)
        #expect(partial.currentRate == rate(10, 20))
        let stopped = partial.stopping()
        #expect(stopped.phase == .stopped)
        #expect(stopped.currentRate == nil)
        #expect(stopped.lastKnownRate == nil)
        #expect(stopped.interfaces[0].rate == nil)
        let full = NetworkCardPresentation.assemble(activity: network(.rate, rate(10, 20)),
            metadata: nil, epoch: 0, wasStopped: false).stopping()
        #expect(full.lastKnownRate?.rate == rate(10, 20))
        #expect(full.lastKnownRate?.readAt == origin.advanced(by: .seconds(1)))
        let pastMetadata = NetworkCardPresentation.assemble(activity: network(.rate, rate(10, 20)),
            metadata: metadata(), epoch: 0, wasStopped: false).stopping()
        #expect(pastMetadata.supplemental.isLastKnown)
        #expect(pastMetadata.supplemental.readAt == origin)
        #expect(pastMetadata.accessibilityLabel.contains("과거 값"))
    }

    @Test func diskCapacityAndUnsupportedOperationsRemainSeparateFromByteRate() {
        let measured = DiskCardPresentation.assemble(activity: disk(.rate, rate(0, 0)),
            metadata: storage(), epoch: 0, wasStopped: false)
        #expect(measured.phase == .measured)
        #expect(measured.currentRate == rate(0, 0))
        #expect(measured.devices[0].operations == .unsupported("unsupported: no Operations"))
        #expect(measured.supplemental.capacity?.totalBytes == 1 << 40)
        #expect(measured.supplemental.capacity?.sharedCapacity == true)
        #expect(measured.accessibilityLabel.contains("APFS 공유 공간"))
        let partial = DiskCardPresentation.assemble(activity: disk(.partial("missing bytes"),
            partial: rate(5, 6)), metadata: storage(failure: "volume lookup"),
            epoch: 0, wasStopped: false)
        #expect(partial.currentRateIsPartial)
        #expect(partial.supplemental.phase == .failure("volume lookup"))
        #expect(partial.accessibilityLabel.contains("일부 수집 실패"))
        #expect(partial.stopping().lastKnownRate == nil)
        let pastCapacity = measured.stopping()
        #expect(pastCapacity.supplemental.isLastKnown)
        #expect(pastCapacity.supplemental.capacity?.readAt == origin)
        #expect(pastCapacity.accessibilityLabel.contains("과거 값"))
        let absent = DiskCardPresentation.assemble(activity: disk(.noPhysicalDevice),
            metadata: nil, epoch: 0, wasStopped: false)
        #expect(absent.phase == .noPhysicalDevice)
        #expect(absent.currentRate == nil)
    }

    @Test func formatterKeepsFourUnitsAndSmallRateAndLocale() {
        let english = Locale(identifier: "en_US")
        let german = Locale(identifier: "de_DE")
        #expect(ResourceQuantityFormatter.byteRate(1_023, locale: english) == "1,023.0 B/s")
        #expect(ResourceQuantityFormatter.byteRate(1_024, locale: english) == "1.0 KB/s")
        #expect(ResourceQuantityFormatter.byteRate(Double(1 << 30), locale: english) == "1.0 GB/s")
        #expect(ResourceQuantityFormatter.byteRate(0.01, locale: english) == "<0.1 B/s")
        #expect(ResourceQuantityFormatter.byteRate(1_024, locale: german) == "1,0 KB/s")
        #expect(ResourceQuantityFormatter.bytes(1 << 40, locale: english) == "1.0 TB")
        #expect(ResourceQuantityFormatter.linkBitsPerSecond(1_000_000, locale: english) == "1.0 Mbit/s")
        #expect(ResourceQuantityFormatter.driverOperationsPerSecond(2.5, locale: english) == "2.5 회/s")
    }

    @Test func auxiliaryCanArriveBeforeFastSampleAndDiskIdentityMismatchHidesDeviceRelation() {
        let earlyNetwork = NetworkCardPresentation.assemble(activity: nil,
            metadata: metadata(), epoch: 0, wasStopped: false)
        #expect(earlyNetwork.phase == .collecting)
        #expect(earlyNetwork.supplemental.phase == .available)
        #expect(earlyNetwork.supplemental.readAt == origin)
        #expect(earlyNetwork.currentRate == nil)
        let earlyDisk = DiskCardPresentation.assemble(activity: nil,
            metadata: storage(), epoch: 0, wasStopped: false)
        #expect(earlyDisk.phase == .collecting)
        #expect(earlyDisk.supplemental.capacity?.totalBytes == 1 << 40)
        let mismatch = DiskCardPresentation.assemble(activity: disk(.rate, rate(1, 2), revision: 2),
            metadata: storage(), epoch: 0, wasStopped: false)
        #expect(mismatch.supplemental.phase == .refreshing)
        #expect(mismatch.supplemental.capacity == nil)
        #expect(mismatch.devices[0].external == nil)
        #expect(mismatch.devices[0].mountState == nil)
        let newNetworkRevision = NetworkCardPresentation.assemble(
            activity: network(.rate, rate(9, 9)), metadata: metadata(2), epoch: 0,
            wasStopped: false, currentTopologyRevision: 2)
        #expect(newNetworkRevision.phase == .baseline("topologyChanged"))
        #expect(newNetworkRevision.currentRate == nil)
        #expect(newNetworkRevision.lastKnownRate?.rate == rate(9, 9))
        #expect(newNetworkRevision.supplemental.phase == .available)
        let newDiskRevision = DiskCardPresentation.assemble(
            activity: disk(.rate, rate(9, 9)), metadata: storage(2), epoch: 0,
            wasStopped: false, currentTopologyRevision: 2)
        #expect(newDiskRevision.phase == .baseline("topologyChanged"))
        #expect(newDiskRevision.currentRate == nil)
        #expect(newDiskRevision.supplemental.capacity?.totalBytes == 1 << 40)
    }

    @Test func activityFailureUsesOnlyPriorFullSuccessAndOptionalLookupFailureIsExplicit() {
        let networkSuccess = network(.rate, rate(12, 34)).latest!
        let networkFailure = network(.failure("route read"), at: 2).latest!
        let networkValue = NetworkActivityDisplayValue(latest: networkFailure,
            lastSuccess: networkSuccess, recentHistory: [])
        let networkCard = NetworkCardPresentation.assemble(activity: networkValue,
            metadata: metadata(), epoch: 0, wasStopped: false)
        #expect(networkCard.phase == .failure("route read"))
        #expect(networkCard.currentRate == nil)
        #expect(networkCard.lastKnownRate?.rate == rate(12, 34))
        #expect(networkCard.lastKnownRate?.readAt == origin.advanced(by: .seconds(1)))
        #expect(networkCard.accessibilityLabel.contains("마지막 측정값(과거)"))

        let diskSuccess = disk(.rate, rate(5, 6)).latest!
        let diskFailure = disk(.failure("driver read"), at: 2).latest!
        let diskValue = DiskActivityDisplayValue(latest: diskFailure,
            lastSuccess: diskSuccess, recentHistory: [])
        let diskCard = DiskCardPresentation.assemble(activity: diskValue,
            metadata: storage(), epoch: 0, wasStopped: false)
        #expect(diskCard.phase == .failure("driver read"))
        #expect(diskCard.currentRate == nil)
        #expect(diskCard.lastKnownRate?.rate == rate(5, 6))
        #expect(diskCard.lastKnownRate?.readAt == origin.advanced(by: .seconds(1)))

        let invalidOperations = DiskDeviceActivity(registryID: 8, bsdNames: ["disk0"],
            kind: .physical, kindReason: "physical", readBytes: 4_096, writtenBytes: 8_192,
            readOperations: nil, writeOperations: nil, operationsReason: "invalid: Operations key",
            bytesReason: "Statistics bytes", rate: rate(5, 6), operationsRate: nil)
        let sample = DiskActivitySample(readAt: origin, topologyRevision: 1,
            devices: [invalidOperations], knownPhysicalRates: rate(5, 6),
            representative: rate(5, 6), knownPhysicalOperations: nil,
            representativeOperations: nil, physicalTotalsComplete: true,
            status: .rate, rateSegment: 1)
        let invalid = DiskCardPresentation.assemble(activity: DiskActivityDisplayValue(
            latest: TimestampedSample(timestamp: origin, value: sample),
            lastSuccess: nil, recentHistory: []), metadata: storage(), epoch: 0, wasStopped: false)
        #expect(invalid.devices[0].operations == .failure("invalid: Operations key"))
        #expect(invalid.currentRate == rate(5, 6))
        let supportedOperations = DiskDeviceActivity(registryID: 8, bsdNames: ["disk0"],
            kind: .physical, kindReason: "physical", readBytes: 4_096, writtenBytes: 8_192,
            readOperations: 100, writeOperations: 200, operationsReason: "Statistics operations",
            bytesReason: "Statistics bytes", rate: rate(5, 6),
            operationsRate: DiskOperationRates(readsPerSecond: 2.5, writesPerSecond: 3)!)
        let supportedSample = DiskActivitySample(readAt: origin, topologyRevision: 1,
            devices: [supportedOperations], knownPhysicalRates: rate(5, 6),
            representative: rate(5, 6), knownPhysicalOperations: supportedOperations.operationsRate,
            representativeOperations: supportedOperations.operationsRate,
            physicalTotalsComplete: true, status: .rate, rateSegment: 1)
        let supported = DiskCardPresentation.assemble(activity: DiskActivityDisplayValue(
            latest: TimestampedSample(timestamp: origin, value: supportedSample),
            lastSuccess: nil, recentHistory: []), metadata: storage(), epoch: 0, wasStopped: false)
        #expect(supported.devices[0].operations == .available("Read 2.5 회/s, Write 3.0 회/s"))
        #expect(supported.currentRate == rate(5, 6))
    }
    @Test func productionConsumersAdvanceFastCardsDuringAuxFailureAndRejectOldEpoch() async throws {
        let gate = CollectionAdmission()
        gate.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
        for axis: CollectionAxis in [.networkActivity, .diskActivity, .networkMetadata, .storageMetadata] {
            _ = gate.advance(axis)
        }
        let networkStore = NetworkActivityStore(admission: gate)
        let diskStore = DiskActivityStore(admission: gate)
        let networkMetadataStore = NetworkMetadataStore(admission: gate)
        let storageStore = StorageMetadataStore(admission: gate)
        let delivery = CollectionDeliveryStore()
        let dashboard = DashboardPresentationStore()
        let consumers = [
            ApplicationCoordinator.consumeNetworkActivity(networkStore, into: delivery,
                dashboard: dashboard, admission: gate),
            ApplicationCoordinator.consumeDiskActivity(diskStore, into: delivery,
                dashboard: dashboard, admission: gate),
            ApplicationCoordinator.consumeNetworkMetadata(networkMetadataStore, into: delivery,
                dashboard: dashboard, admission: gate),
            ApplicationCoordinator.consumeStorageMetadata(storageStore, into: delivery,
                dashboard: dashboard, admission: gate)
        ]
        defer { consumers.forEach { $0.cancel() } }
        let networkContext = try #require(gate.issue(.networkActivity))
        let diskContext = try #require(gate.issue(.diskActivity))
        let networkSample = try #require(network(.rate, rate(10, 20)).latest)
        let diskSample = try #require(disk(.rate, rate(30, 40)).latest)
        #expect(await networkStore.append(TimestampedSample(timestamp: networkSample.timestamp,
            value: networkSample.value, context: networkContext), context: networkContext))
        #expect(await diskStore.append(TimestampedSample(timestamp: diskSample.timestamp,
            value: diskSample.value, context: diskContext), context: diskContext))
        for _ in 0..<10_000 where dashboard.networkCard.currentRate != rate(10, 20)
            || dashboard.diskCard.currentRate != rate(30, 40) { await Task.yield() }
        #expect(dashboard.networkCard.currentRate == rate(10, 20))
        #expect(dashboard.diskCard.currentRate == rate(30, 40))

        let networkAuxContext = try #require(gate.issue(.networkMetadata))
        let diskAuxContext = try #require(gate.issue(.storageMetadata))
        let networkFailure = TimestampedSample(timestamp: origin, value:
            NetworkMetadataResult.failure("SC failed", revision: 1), context: networkAuxContext)
        let storageFailure = TimestampedSample(timestamp: origin, value:
            StorageMetadataResult.failure("DA failed", revision: 1), context: diskAuxContext)
        #expect(await networkMetadataStore.append(networkFailure, context: networkAuxContext))
        #expect(await storageStore.append(storageFailure, context: diskAuxContext))
        for _ in 0..<10_000 where dashboard.networkCard.supplemental.phase != .failure("SC failed")
            || dashboard.diskCard.supplemental.phase != .failure("DA failed") { await Task.yield() }
        #expect(dashboard.networkCard.supplemental.phase == .failure("SC failed"))
        #expect(dashboard.diskCard.supplemental.phase == .failure("DA failed"))

        let nextNetwork = try #require(gate.issue(.networkActivity))
        let nextDisk = try #require(gate.issue(.diskActivity))
        let n = try #require(network(.rate, rate(50, 60), at: 2).latest)
        let d = try #require(disk(.rate, rate(70, 80), at: 2).latest)
        #expect(await networkStore.append(TimestampedSample(timestamp: n.timestamp, value: n.value,
            context: nextNetwork), context: nextNetwork))
        #expect(await diskStore.append(TimestampedSample(timestamp: d.timestamp, value: d.value,
            context: nextDisk), context: nextDisk))
        for _ in 0..<10_000 where dashboard.networkCard.currentRate != rate(50, 60)
            || dashboard.diskCard.currentRate != rate(70, 80) { await Task.yield() }
        #expect(dashboard.networkCard.currentRate == rate(50, 60))
        #expect(dashboard.diskCard.currentRate == rate(70, 80))
        #expect(dashboard.networkCard.supplemental.phase == .failure("SC failed"))
        #expect(dashboard.diskCard.supplemental.phase == .failure("DA failed"))

        let stop = CollectionBoundary(revision: 1, sequence: 1, epoch: 0, stopped: true)
        gate.transition(stop)
        dashboard.observe(stop, admission: gate)
        #expect(dashboard.networkCard.phase == .stopped)
        #expect(dashboard.diskCard.phase == .stopped)
        #expect(dashboard.networkCard.lastKnownRate?.rate == rate(50, 60))
        let resume = CollectionBoundary(revision: 2, sequence: 2, epoch: 1, stopped: false)
        gate.transition(resume)
        dashboard.observe(resume, admission: gate)
        #expect(await networkStore.append(TimestampedSample(timestamp: origin.advanced(by: .seconds(3)),
            value: network(.rate, rate(900, 900), at: 3).latest!.value,
            collectionEpoch: 0, context: nextNetwork), context: nextNetwork) == false)
        #expect(await networkMetadataStore.append(networkFailure, context: networkAuxContext) == false)
        #expect(dashboard.networkCard.phase == .stopped)
        #expect(dashboard.networkCard.lastKnownRate?.rate == rate(50, 60))
        #expect(dashboard.diskCard.phase == .stopped)
    }

    @Test func queuedOldTopologyEventsCannotReachProductionDisplayOrReassembleOldActivity() async throws {
        let gate = CollectionAdmission()
        gate.transition(CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: false))
        for axis: CollectionAxis in [.networkActivity, .diskActivity, .networkMetadata, .storageMetadata] {
            _ = gate.advance(axis)
        }
        let networkTopology = NetworkTopologyTracker()
        let diskTopology = DiskTopologyTracker()
        let networkStore = NetworkActivityStore(admission: gate)
        let diskStore = DiskActivityStore(admission: gate)
        let networkMetadataStore = NetworkMetadataStore(admission: gate)
        let storageStore = StorageMetadataStore(admission: gate)
        let delivery = CollectionDeliveryStore()
        let dashboard = DashboardPresentationStore()

        // 소비 Task를 만들기 전에 stream에 쌓인 구 topology 결과가 표시될 때에는 revision이 전진해 있습니다.
        let oldNetworkContext = try #require(gate.issue(.networkActivity))
        let oldDiskContext = try #require(gate.issue(.diskActivity))
        let oldNetworkAuxContext = try #require(gate.issue(.networkMetadata))
        let oldDiskAuxContext = try #require(gate.issue(.storageMetadata))
        let oldNetwork = try #require(network(.rate, rate(99, 99), revision: 0).latest)
        let oldDisk = try #require(disk(.rate, rate(99, 99), revision: 0).latest)
        #expect(await networkStore.append(TimestampedSample(timestamp: oldNetwork.timestamp,
            value: oldNetwork.value, context: oldNetworkContext), context: oldNetworkContext))
        #expect(await diskStore.append(TimestampedSample(timestamp: oldDisk.timestamp,
            value: oldDisk.value, context: oldDiskContext), context: oldDiskContext))
        let oldNetworkMetadata = NetworkMetadataSnapshot(readAt: origin, topologyRevision: 0,
            records: [], physicalTotalsComplete: true, nativeStatus: "old")
        let oldStorage = storage(0).lastKnown!
        #expect(await networkMetadataStore.append(TimestampedSample(timestamp: origin,
            value: NetworkMetadataResult.available(oldNetworkMetadata), context: oldNetworkAuxContext),
            context: oldNetworkAuxContext))
        #expect(await storageStore.append(TimestampedSample(timestamp: origin,
            value: StorageMetadataResult.available(oldStorage), context: oldDiskAuxContext),
            context: oldDiskAuxContext))
        networkTopology.noteChange()
        diskTopology.noteChange()
        let consumers = [
            ApplicationCoordinator.consumeNetworkActivity(networkStore, into: delivery,
                dashboard: dashboard, topology: networkTopology, admission: gate),
            ApplicationCoordinator.consumeDiskActivity(diskStore, into: delivery,
                dashboard: dashboard, topology: diskTopology, admission: gate),
            ApplicationCoordinator.consumeNetworkMetadata(networkMetadataStore, into: delivery,
                dashboard: dashboard, topology: networkTopology, admission: gate),
            ApplicationCoordinator.consumeStorageMetadata(storageStore, into: delivery,
                dashboard: dashboard, topology: diskTopology, admission: gate)
        ]
        defer { consumers.forEach { $0.cancel() } }
        for _ in 0..<200 { await Task.yield() }
        #expect(delivery.networkActivity == nil)
        #expect(delivery.diskActivity == nil)
        #expect(delivery.networkMetadata == nil)
        #expect(delivery.storageMetadata == nil)
        #expect(dashboard.networkCard.currentRate == nil)
        #expect(dashboard.diskCard.currentRate == nil)

        let newNetworkContext = try #require(gate.issue(.networkActivity))
        let newDiskContext = try #require(gate.issue(.diskActivity))
        let newNetwork = try #require(network(.rate, rate(10, 20), revision: 1, at: 2).latest)
        let newDisk = try #require(disk(.rate, rate(30, 40), revision: 1, at: 2).latest)
        #expect(await networkStore.append(TimestampedSample(timestamp: newNetwork.timestamp,
            value: newNetwork.value, context: newNetworkContext), context: newNetworkContext))
        #expect(await diskStore.append(TimestampedSample(timestamp: newDisk.timestamp,
            value: newDisk.value, context: newDiskContext), context: newDiskContext))
        for _ in 0..<10_000 where dashboard.networkCard.currentRate != rate(10, 20)
            || dashboard.diskCard.currentRate != rate(30, 40) { await Task.yield() }
        #expect(dashboard.networkCard.currentRate == rate(10, 20))
        #expect(dashboard.diskCard.currentRate == rate(30, 40))
        #expect(delivery.networkMetadata == nil)
        #expect(delivery.storageMetadata == nil)

        let newNetworkAuxContext = try #require(gate.issue(.networkMetadata))
        let newDiskAuxContext = try #require(gate.issue(.storageMetadata))
        #expect(await networkMetadataStore.append(TimestampedSample(timestamp: origin.advanced(by: .seconds(2)),
            value: NetworkMetadataResult.failure("new SC failure", revision: 1),
            context: newNetworkAuxContext), context: newNetworkAuxContext))
        #expect(await storageStore.append(TimestampedSample(timestamp: origin.advanced(by: .seconds(2)),
            value: StorageMetadataResult.failure("new DA failure", revision: 1),
            context: newDiskAuxContext), context: newDiskAuxContext))
        for _ in 0..<10_000 where dashboard.networkCard.supplemental.phase != .failure("new SC failure")
            || dashboard.diskCard.supplemental.phase != .failure("new DA failure") { await Task.yield() }
        #expect(dashboard.networkCard.currentRate == rate(10, 20))
        #expect(dashboard.diskCard.currentRate == rate(30, 40))
        #expect(dashboard.networkCard.supplemental.phase == .failure("new SC failure"))
        #expect(dashboard.diskCard.supplemental.phase == .failure("new DA failure"))
        #expect(dashboard.networkCard.interfaces[0].ipv4.isEmpty)
    }

}
