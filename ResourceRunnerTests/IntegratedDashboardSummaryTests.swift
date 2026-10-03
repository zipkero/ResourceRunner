import AppKit
import SwiftUI
import Testing
@testable import ResourceRunner

@MainActor
struct IntegratedDashboardSummaryTests {
    private let now = ContinuousClock().now
    private let appPaths = ["Calculator", "Calendar", "Mail", "Music", "Notes"]
        .map { "/System/Applications/\($0).app" }

    private func entries() -> [ApplicationRankingEntry] {
        appPaths.enumerated().map { index, path in
            ApplicationRankingEntry(key: ApplicationKey(value: path),
                displayName: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent,
                value: Double(75 - index * 9))
        }
    }

    private func icons() -> StubApplicationIconProvider {
        let images = Dictionary(uniqueKeysWithValues: appPaths.map { path in
            (ApplicationKey(value: path), NSWorkspace.shared.icon(forFile: path))
        })
        return StubApplicationIconProvider(images: images)
    }

    private func cpu() -> ResourceCardState<CPUCardPresentation> {
        let metrics = CPUSystemMetrics(overallUsage: 42, userRatio: 30, systemRatio: 12,
            idleRatio: 58, coreUsages: [42],
            loadAverage: LoadAverage(oneMinute: 0, fiveMinutes: 0, fifteenMinutes: 0))
        let history: [SystemMetricsHistoryPoint] = (0...40).map { index in
            let usage = Double(25 + index % 20)
            let user = Double(17 + index % 20)
            return SystemMetricsHistoryPoint(timestamp: now.advanced(by: .seconds(-200 + index * 5)),
                overallCPUUsage: usage, userRatio: user,
                swapUsedBytes: 0)
        }
        return .normal(CPUCardPresentation.assemble(cpu: metrics, history: history,
            topApplications: entries(), currentTimestamp: now), timestamp: now)
    }

    private func memory() -> ResourceCardState<MemoryCardPresentation> {
        let metrics = MemorySystemMetrics(totalPhysicalBytes: 36 << 30, usedBytes: 23 << 30,
            appBytes: 12 << 30, wiredBytes: 5 << 30, compressedBytes: 2 << 30,
            cachedBytes: 3 << 30, swapUsedBytes: 0, pressureLevel: .normal)
        return .normal(MemoryCardPresentation.assemble(memory: metrics, history: [],
            topApplications: entries(), currentTimestamp: now), timestamp: now)
    }

    private func network() -> NetworkCardPresentation {
        let key = NetworkTargetKey(name: "en0", index: 1, registryID: 42, lifetime: 1)
        let item = NetworkInterfacePresentation(key: key, kind: .physicalWiFi,
            classificationReason: "하드웨어 provider 확인", linkActive: true,
            receivedBytes: 1_000_000, sentBytes: 500_000,
            rate: RatePair(receivedBytesPerSecond: 379.5 * 1_024,
                sentBytesPerSecond: 11.1 * 1_024), ipv4: ["198.51.100.10"],
            ipv6: ["2001:db8::1"], linkSpeed: .unsupported("조회 미지원"))
        return NetworkCardPresentation(phase: .measured,
            currentRate: RatePair(receivedBytesPerSecond: 379.5 * 1_024,
                sentBytesPerSecond: 11.1 * 1_024), currentRateIsPartial: false,
            latestReadAt: now, lastKnownRate: nil, topologyRevision: 1,
            recentHistory: [], firstHistoryPointAt: nil, interfaces: [item],
            supplemental: NetworkSupplementalPresentation(phase: .available,
                readAt: now, records: [], isLastKnown: false))
    }

    private func disk() -> DiskCardPresentation {
        let capacity = DiskCapacityPresentation(identity: "/", totalBytes: 994_662_584_320,
            availableBytes: 826_940_878_848, usedBytes: 167_721_705_472,
            sharedCapacity: true, relationReason: "APFS 공유", readAt: now)
        let history: [RateHistoryPoint] = (0...40).map { index in
            let read = Double(10_000 + index * 1_000)
            let write: Double = index == 20 ? 3_000_000 : 900_000
            let rate = RatePair(receivedBytesPerSecond: read, sentBytesPerSecond: write)!
            return RateHistoryPoint(timestamp: now.advanced(by: .seconds(-200 + index * 5)),
                rate: rate,
                collectionEpoch: 1, rateSegment: 1)
        }
        return DiskCardPresentation(phase: .measured,
            currentRate: RatePair(receivedBytesPerSecond: 39 * 1_024,
                sentBytesPerSecond: 1.7 * 1_048_576), currentRateIsPartial: false,
            latestReadAt: now, lastKnownRate: nil, topologyRevision: 1,
            recentHistory: history, firstHistoryPointAt: history.first?.timestamp, devices: [],
            supplemental: StorageSupplementalPresentation(phase: .available,
                readAt: now, capacity: capacity, volumes: [], externalDevicesAbsent: true,
                isLastKnown: false))
    }

    private func render(_ view: some View, named name: String,
                        appearance appearanceName: NSAppearance.Name) throws -> CGSize {
        let appearance = try #require(NSAppearance(named: appearanceName))
        let styled = view.environment(\.colorScheme, appearanceName == .darkAqua ? .dark : .light)
        var image: NSImage?
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: styled)
            renderer.scale = 1
            image = renderer.nsImage
        }
        let bitmap = try #require(image?.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        Attachment.record(png, named: "integrated-\(name)-\(appearanceName == .darkAqua ? "dark" : "light").png")
        return CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
    }

    @Test func allFourReadableCardsFitOneUnscrolledSummaryInLightAndDark() throws {
        let provider = icons()
        let content = VStack(alignment: .leading, spacing: DashboardView.cardSpacing) {
            CPUCardView(state: cpu(), iconProvider: provider)
            MemoryCardView(state: memory(), iconProvider: provider)
            NetworkCardView(presentation: network(), fixedNow: now)
            DiskCardView(presentation: disk(), fixedNow: now)
        }
        .padding(DashboardStyle.Summary.bodyPadding)
        .frame(width: 280)
        .background(DashboardColorPalette.popoverBackground)
        for appearance: NSAppearance.Name in [.aqua, .darkAqua] {
            let size = try render(content, named: "normal-four-cards", appearance: appearance)
            #expect(size.width == 280)
            #expect(size.height < 1_000)
        }
        #expect(DashboardStyle.Summary.focus.pointSize == 17.33)
        #expect(DashboardStyle.Summary.cpuPlotHeight == 66.67)
        #expect(DashboardView.cardSpacing == 6)
        #expect(NetworkCardLayout.total == 112)
        #expect(DiskCardLayout.total == 112)
    }

    @Test func productionDashboardContainerHasNoScrollAndKeepsAllFourPlaceholders() throws {
        let store = DashboardPresentationStore()
        let view = DashboardView(store: store, iconProvider: icons())
        let size = try render(view, named: "collecting-dashboard", appearance: .aqua)
        #expect(size.width == 280)
        #expect(size.height < 1_000)
    }
}
