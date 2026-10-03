import AppKit
import SwiftUI
import Testing
@testable import ResourceRunner

@MainActor
struct DiskDashboardViewTests {
    private let now = ContinuousClock().now

    private func volume(path: String, shared: Bool = true) -> DiskVolumeReading {
        DiskVolumeReading(identity: "volume-\(path)", mountPaths: [path], bsdName: "disk3s5",
            fileSystem: "apfs", totalBytes: 1 << 40, availableBytes: 1 << 39,
            driverIDs: [42], scope: .physical, relationReason: "driver 42 confirmed",
            sharedCapacity: shared)
    }

    private func device(external: DiskExternalKind? = .internalDevice,
                        mount: StorageMountState? = .mounted,
                        operations: ConditionalMetric = .available("Read 2.5 회/s, Write 1.0 회/s")) -> DiskDevicePresentation {
        DiskDevicePresentation(registryID: 42,
            bsdNames: ["disk0123456789012345678901234567890123456789"],
            readBytes: UInt64.max, writtenBytes: 9_876_543_210,
            bytesReason: "IOBlockStorageDriver Statistics bytes",
            rate: RatePair(receivedBytesPerSecond: 1_024, sentBytesPerSecond: 0),
            readOperations: 100, writeOperations: 200,
            operationsRate: DiskOperationRates(readsPerSecond: 2.5, writesPerSecond: 1),
            operations: operations, external: external,
            externalReason: "IORegistry external property", mountState: mount)
    }

    private func card(_ phase: ResourceActivityPhase = .measured,
                      auxiliary: SupplementalDisplayPhase = .available,
                      current: RatePair? = RatePair(receivedBytesPerSecond: 1_024, sentBytesPerSecond: 0),
                      partial: Bool = false,
                      lastKnown: LastKnownRate? = nil,
                      capacity: DiskCapacityPresentation? = nil,
                      externalAbsent: Bool? = true,
                      capacityIsLastKnown: Bool = false,
                      devices: [DiskDevicePresentation]? = nil,
                      history: [RateHistoryPoint] = []) -> DiskCardPresentation {
        let storage = capacity ?? DiskCapacityPresentation(identity: "/", totalBytes: 1 << 40,
            availableBytes: 1 << 39, usedBytes: 1 << 39, sharedCapacity: true,
            relationReason: "APFS shared", readAt: now.advanced(by: .seconds(-30)))
        return DiskCardPresentation(phase: phase, currentRate: current,
            currentRateIsPartial: partial, latestReadAt: now.advanced(by: .seconds(-2)),
            lastKnownRate: lastKnown, topologyRevision: 1, recentHistory: history,
            firstHistoryPointAt: nil, devices: devices ?? [device()],
            supplemental: StorageSupplementalPresentation(phase: auxiliary,
                readAt: now.advanced(by: .seconds(-30)), capacity: storage,
                volumes: [volume(path: "/"), volume(path: "/System/Volumes/Data")],
                externalDevicesAbsent: externalAbsent, isLastKnown: capacityIsLastKnown))
    }

    private func capacity(total: UInt64, available: UInt64) -> DiskCapacityPresentation {
        DiskCapacityPresentation(identity: "/", totalBytes: total, availableBytes: available,
            usedBytes: total - available, sharedCapacity: true,
            relationReason: "APFS shared", readAt: now.advanced(by: .seconds(-30)))
    }

    private func measuredHistory() -> [RateHistoryPoint] {
        (0...60).map { index in
            let read: Double = index == 20 ? 4_000 : Double(500 + index * 10)
            let write: Double = index == 45 ? 3_000 : Double(900 - index * 5)
            let rate = RatePair(receivedBytesPerSecond: read, sentBytesPerSecond: write)!
            return RateHistoryPoint(timestamp: now.advanced(by: .seconds(-300 + index * 5)),
                rate: rate,
                collectionEpoch: 1, rateSegment: 1)
        }
    }

    private func render(_ presentation: DiskCardPresentation, appearance name: NSAppearance.Name,
                        label: String, locale: Locale = .current,
                        width: CGFloat = 248) throws {
        let appearance = try #require(NSAppearance(named: name))
        let view = DiskCardView(presentation: presentation, fixedNow: now)
            .frame(width: width)
            .environment(\.colorScheme, name == .darkAqua ? .dark : .light)
            .environment(\.locale, locale)
        var bitmap: NSBitmapImageRep?
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            bitmap = renderer.nsImage?.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))
        }
        let image = try #require(bitmap)
        #expect(image.pixelsWide == Int(width))
        #expect(image.pixelsHigh == Int(DiskCardLayout.total))
        Attachment.record(try #require(image.representation(using: .png, properties: [:])),
            named: "disk-card-\(Int(width))-\(label)-\(name == .darkAqua ? "dark" : "light").png")
    }

    @Test func fixedSlotsAndStatesKeepRateAndCapacityIndependent() throws {
        #expect(DiskCardLayout.total == 112)
        #expect(DiskCardLayout.title == 14)
        #expect(DiskCardLayout.ratesAndGraph == 54)
        #expect(DiskCardLayout.miniPlot == 42)
        #expect(DiskCardLayout.auxiliary == 28)
        let past = LastKnownRate(rate: RatePair(receivedBytesPerSecond: 4_096,
            sentBytesPerSecond: 2_048)!, readAt: now.advanced(by: .seconds(-20)))
        let fixtures: [(String, DiskCardPresentation)] = [
            ("initial", .collecting),
            ("normal", card(history: measuredHistory())),
            ("native-units", card(current: RatePair(receivedBytesPerSecond: 1.8 * 1_048_576,
                sentBytesPerSecond: 9.0 * 1_048_576), history: measuredHistory())),
            ("partial", card(.partial("driver bytes missing"), partial: true)),
            ("activity-failure", card(.failure("driver unavailable"), current: nil, lastKnown: past)),
            ("stopped", card(.stopped, current: nil, lastKnown: past)),
            ("capacity-failure", card(auxiliary: .failure("volume unavailable"), capacityIsLastKnown: true)),
            ("capacity-partial", card(auxiliary: .partial("relationship unconfirmed"))),
            ("no-device", card(.noPhysicalDevice, current: nil, devices: [])),
            ("long-value", card(current: RatePair(receivedBytesPerSecond: 1_073_741_823,
                sentBytesPerSecond: 1_073_741_824),
                capacity: DiskCapacityPresentation(identity: "/", totalBytes: UInt64.max,
                    availableBytes: UInt64.max - 1, usedBytes: 1, sharedCapacity: true,
                    relationReason: "APFS shared", readAt: now.advanced(by: .seconds(-30))))),
            ("max-rate", card(current: RatePair(receivedBytesPerSecond: Double(UInt64.max),
                sentBytesPerSecond: Double(UInt64.max))))
        ]
        for (label, fixture) in fixtures {
            for appearance: NSAppearance.Name in [.aqua, .darkAqua] {
                for width: CGFloat in [248, 264] {
                    try render(fixture, appearance: appearance, label: label, width: width)
                }
            }
        }
        try render(card(), appearance: .aqua, label: "german-locale", locale: Locale(identifier: "de_DE"))
        let graphAX = DiskDisplayText.miniGraphAccessibility(presentation: card(history: measuredHistory()),
            now: now, locale: Locale(identifier: "de_DE"))
        #expect(graphAX.contains("최근 10분"))
        #expect(graphAX.contains("Read 점선, Write 실선"))
        #expect(graphAX.contains("0–4,9 KB/s"))
        #expect(DiskDisplayText.miniGraphAccessibility(presentation: card(), now: now)
            .contains("속도 범위 대기"))
        #expect(DiskDisplayText.compactCapacity(card().supplemental, now: now) == "용량 확인 · 30초 전")
        let failedCapacity = card(auxiliary: .failure("volume unavailable"), capacityIsLastKnown: true)
        #expect(failedCapacity.currentRate != nil)
        #expect(failedCapacity.supplemental.isLastKnown)
        #expect(DiskDisplayText.compactCapacity(failedCapacity.supplemental, now: now)
            == "용량 실패 · 과거 30초 전")
        #expect(DiskDisplayText.cardStatus(card(.stopped, current: nil, lastKnown: past), now: now)
            == "중지 · 과거 20초 전")
    }

    @Test func detailPreservesSharedCapacityDriverCountersOperationsAndRelations() throws {
        let item = device()
        let fixture = card()
        let detail = DiskDetailPopoverContent(presentation: fixture, onClose: {}, fixedNow: now)
        let rows = VStack(spacing: 16) {
            detail.volumeRow(fixture.supplemental.volumes[0])
            detail.deviceRow(item, now: now)
        }
        .frame(width: 368)
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: rows)
        renderer.scale = 1
        let image = try #require(renderer.nsImage?.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        #expect(image.pixelsWide == 368)
        #expect(image.pixelsHigh > 200)
        Attachment.record(try #require(image.representation(using: .png, properties: [:])),
            named: "disk-detail-volume-device-long-name.png")
        #expect(fixture.supplemental.volumes[0].usedBytes == 1 << 39)
        #expect(fixture.supplemental.volumes[0].sharedCapacity)
        #expect(fixture.accessibilityLabel.contains("APFS 공유 공간"))
        #expect(DiskDisplayText.usedDefinition.contains("전체 − 사용 가능"))
        #expect(item.readBytes == UInt64.max)
        #expect(item.operationsRate?.readsPerSecond == 2.5)
        #expect(ResourceQuantityFormatter.driverOperationsPerSecond(2.5) == "2.5 회/s")
        #expect(DiskDisplayText.external(.externalDevice, reason: nil) == "외장 장치")
        #expect(DiskDisplayText.external(.unknown, reason: "IORegistry unknown").contains("미확인"))
        #expect(DiskDisplayText.mount(.mounted) == "마운트됨")
        #expect(DiskDisplayText.mount(.unmounted) == "마운트되지 않음")
        #expect(DiskDisplayText.mount(.relationUnconfirmed) == "장치·볼륨 관계 미확인")
        #expect(DiskDisplayText.volumeScope(.unconfirmed) == "장치 관계 미확인")
    }

    @Test func fullCapacityNumbersFitFirstAuxiliaryRowAcrossUnitsAndLocales() throws {
        let cases: [(String, DiskCapacityPresentation)] = [
            ("max-same-unit", capacity(total: UInt64.max, available: UInt64.max - 1)),
            ("different-tb-gb", capacity(total: 1 << 40, available: 1 << 39)),
            ("unit-boundary", capacity(total: 1 << 30, available: (1 << 30) - 1)),
            ("zero", capacity(total: 0, available: 0)),
            ("small-positive", capacity(total: 1_024, available: 1))
        ]
        let locales = ["en_US", "de_DE", "ko_KR", "gez_ER", "my_MM"]
        let font = NSFont.preferredFont(forTextStyle: .subheadline)
        #expect(font.pointSize == DashboardStyle.TypographyRole.label.pointSize)
        for localeID in locales {
            let locale = Locale(identifier: localeID)
            for (name, value) in cases {
                let compact = DiskDisplayText.compactCapacitySummary(value, locale: locale)
                let total = ResourceQuantityFormatter.bytes(value.totalBytes, locale: locale)
                let available = ResourceQuantityFormatter.bytes(value.availableBytes, locale: locale)
                let totalParts = total.split(separator: " ", omittingEmptySubsequences: false)
                let availableParts = available.split(separator: " ", omittingEmptySubsequences: false)
                #expect(compact.contains(String(totalParts.dropLast().joined(separator: " "))))
                #expect(compact.contains(String(availableParts.dropLast().joined(separator: " "))))
                #expect(!compact.contains("…"))
                let width = (compact as NSString).size(withAttributes: [.font: font]).width
                #expect(width < 232, "\(localeID) \(name): \(compact) width=\(width)")
                for width: CGFloat in [248, 264] {
                    try render(card(capacity: value), appearance: .aqua,
                        label: "capacity-\(localeID)-\(name)", locale: locale, width: width)
                }
            }
            for width: CGFloat in [248, 264] {
                try render(card(current: RatePair(receivedBytesPerSecond: Double(UInt64.max),
                    sentBytesPerSecond: Double(UInt64.max)), history: measuredHistory()),
                    appearance: .aqua, label: "max-rate-\(localeID)", locale: locale, width: width)
            }
        }
        let english = Locale(identifier: "en_US")
        #expect(DiskDisplayText.compactCapacitySummary(cases[0].1, locale: english)
            == "전체 16,777,216.0·가용 16,777,216.0 TB")
        #expect(DiskDisplayText.compactCapacitySummary(cases[1].1, locale: english)
            == "전체 1.0 TB·가용 512.0 GB")
        #expect(DiskDisplayText.capacitySummary(cases[1].1, locale: english)
            == "전체 1.0 TB · 사용 가능 512.0 GB")
        let german = Locale(identifier: "de_DE")
        let germanCard = card(capacity: cases[1].1)
        #expect(germanCard.accessibilityLabel(locale: german).contains("전체 1,0 TB"))
        #expect(germanCard.accessibilityLabel(locale: german).contains("사용 가능 512,0 GB"))
        #expect(DiskDisplayText.capacitySummary(cases[1].1, locale: german)
            .contains("사용 가능 512,0 GB"))
    }

    @Test func conditionalOperationsAndExternalMountStatesStayDistinct() throws {
        let fixture = card(externalAbsent: false, devices: [
            device(external: .externalDevice, mount: .unmounted,
                operations: .unsupported("unsupported: Operations key absent")),
            DiskDevicePresentation(registryID: 43, bsdNames: ["disk43"],
                readBytes: nil, writtenBytes: nil, bytesReason: "invalid: Statistics bytes missing",
                rate: nil, readOperations: nil, writeOperations: nil, operationsRate: nil,
                operations: .failure("invalid: Operations key"), external: .unknown,
                externalReason: "IORegistry relation unconfirmed", mountState: .relationUnconfirmed)
        ])
        let detail = DiskDetailPopoverContent(presentation: fixture, onClose: {}, fixedNow: now)
        let rows = VStack(spacing: 16) {
            detail.deviceRow(fixture.devices[0], now: now)
            detail.deviceRow(fixture.devices[1], now: now)
        }
        .frame(width: 368)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: rows)
        renderer.scale = 1
        let bitmap = try #require(renderer.nsImage?.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        #expect(bitmap.pixelsWide == 368)
        #expect(bitmap.pixelsHigh > 200)
        Attachment.record(try #require(bitmap.representation(using: .png, properties: [:])),
            named: "disk-detail-external-unmounted-unknown-failure.png")
        #expect(DiskDisplayText.external(fixture.devices[0].external,
            reason: fixture.devices[0].externalReason) == "외장 장치")
        #expect(DiskDisplayText.mount(fixture.devices[0].mountState) == "마운트되지 않음")
        #expect(DiskDisplayText.mount(fixture.devices[1].mountState) == "장치·볼륨 관계 미확인")
        #expect(DiskDisplayText.external(fixture.devices[1].external,
            reason: fixture.devices[1].externalReason).contains("미확인"))
    }

    @Test func diskSelectionAndExplicitCloseUseCommonStore() {
        let store = DashboardPresentationStore()
        store.selectCard(.disk)
        #expect(store.selection == .disk)
        store.selectCard(.disk)
        #expect(store.selection == .none)
        store.selectCard(.disk)
        store.selectCard(.network)
        store.dismissDetail(for: .disk)
        #expect(store.selection == .network)
        store.selectCard(.disk)
        store.dismissDetail(for: .disk)
        #expect(store.selection == .none)
    }
}
