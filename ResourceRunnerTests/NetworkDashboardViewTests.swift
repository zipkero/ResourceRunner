import AppKit
import SwiftUI
import Testing
@testable import ResourceRunner

@MainActor
struct NetworkDashboardViewTests {
    private let now = ContinuousClock().now
    private let key = NetworkTargetKey(name: "utun1234567890123456789012345678901234567890",
        index: 8, registryID: nil, lifetime: 3)

    private func item(kind: NetworkInterfaceKind = .tunnel, name: String? = nil, index: UInt16 = 8,
                      link: ConditionalMetric = .unsupported("unsupported: negotiated speed unverified")) -> NetworkInterfacePresentation {
        let target = NetworkTargetKey(name: name ?? key.name, index: index, registryID: nil, lifetime: 3)
        let reason = switch kind {
        case .physicalWiFi: "confirmed hardware provider"
        case .vpn: "confirmed VPN service"
        case .tunnel: "tunnel name; VPN service unconfirmed"
        default: "classification unavailable"
        }
        let rates = switch kind {
        case .physicalWiFi: RatePair(receivedBytesPerSecond: 1_023, sentBytesPerSecond: 1_024)
        case .vpn: RatePair(receivedBytesPerSecond: 2_048, sentBytesPerSecond: 512)
        default: RatePair(receivedBytesPerSecond: 4_096, sentBytesPerSecond: 0)
        }
        return NetworkInterfacePresentation(key: target, kind: kind, classificationReason: reason,
            linkActive: true, receivedBytes: UInt64.max, sentBytes: 9_876_543_210,
            rate: rates,
            ipv4: ["198.51.100.10"], ipv6: ["2001:db8::1"], linkSpeed: link)
    }

    private func card(_ phase: ResourceActivityPhase = .measured,
                      auxiliary: SupplementalDisplayPhase = .available,
                      current: RatePair? = RatePair(receivedBytesPerSecond: 1_023,
                                                   sentBytesPerSecond: 1_024),
                      partial: Bool = false,
                      lastKnown: LastKnownRate? = nil,
                      interfaces: [NetworkInterfacePresentation]? = nil) -> NetworkCardPresentation {
        NetworkCardPresentation(phase: phase, currentRate: current,
            currentRateIsPartial: partial, latestReadAt: now.advanced(by: .seconds(-3)),
            lastKnownRate: lastKnown, topologyRevision: 1, recentHistory: [],
            firstHistoryPointAt: nil, interfaces: interfaces ?? [
                item(kind: .physicalWiFi, name: "en0", index: 1),
                item(kind: .vpn, name: "utun3", index: 3),
                item(kind: .tunnel, name: key.name, index: 8)
            ],
            supplemental: NetworkSupplementalPresentation(phase: auxiliary,
                readAt: now.advanced(by: .seconds(-30)), records: [], isLastKnown: false))
    }

    private func render(_ presentation: NetworkCardPresentation,
                        appearance name: NSAppearance.Name, label: String,
                        locale: Locale = .current, width: CGFloat = 248) throws -> NSBitmapImageRep {
        let appearance = try #require(NSAppearance(named: name))
        let view = NetworkCardView(presentation: presentation, fixedNow: now)
            .frame(width: width)
            .environment(\.colorScheme, name == .darkAqua ? .dark : .light)
            .environment(\.locale, locale)
        var image: NSBitmapImageRep?
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            image = renderer.nsImage?.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))
        }
        let bitmap = try #require(image)
        #expect(bitmap.pixelsWide == Int(width))
        #expect(bitmap.pixelsHigh == 101)
        Attachment.record(try #require(bitmap.representation(using: .png, properties: [:])),
            named: "network-card-\(Int(width))-\(label)-\(name == .darkAqua ? "dark" : "light").png")
        return bitmap
    }

    @Test func fixedSlotsCoverInitialNormalPartialFailureStoppedAndAuxiliaryFailure() throws {
        #expect(NetworkCardLayout.total == 101)
        #expect(NetworkCardLayout.title == 8)
        #expect(NetworkCardLayout.rates == 46)
        #expect(NetworkCardLayout.auxiliary == 27)
        let past = LastKnownRate(rate: RatePair(receivedBytesPerSecond: 1_024,
                                               sentBytesPerSecond: 2_048)!, readAt: now.advanced(by: .seconds(-20)))
        let manyKinds: [NetworkInterfaceKind] = [.physicalWiFi, .physicalEthernet,
            .physicalOther, .logical, .virtual, .tunnel, .vpn, .unknown]
        let busyInterfaces = manyKinds.enumerated().map { index, kind in
            item(kind: kind, name: "target\(index)", index: UInt16(index + 1))
        }
        let fixtures: [(String, NetworkCardPresentation)] = [
            ("initial", .collecting),
            ("normal", card()),
            ("partial", card(.partial("llw0 classification unknown"), partial: true)),
            ("failure", card(.failure("route unavailable"), current: nil, lastKnown: past)),
            ("stopped", card(.stopped, current: nil, lastKnown: past)),
            ("aux-failure", card(auxiliary: .failure("addresses unavailable"))),
            ("disconnected", card(.disconnected, current: nil, interfaces: [])),
            ("baseline", card(.baseline("first native read"), current: nil)),
            ("no-physical", card(.noPhysicalDevice, current: nil, interfaces: [])),
            ("long-value", card(current: RatePair(receivedBytesPerSecond: 1_023,
                                                  sentBytesPerSecond: 1_073_741_823))),
            ("small-positive", card(current: RatePair(receivedBytesPerSecond: 0.01,
                                                      sentBytesPerSecond: 1_024))),
            ("many-kinds-aux-failure", card(auxiliary: .failure("addresses unavailable"),
                interfaces: busyInterfaces))
        ]
        for (label, fixture) in fixtures {
            for appearance: NSAppearance.Name in [.aqua, .darkAqua] {
                for width: CGFloat in [248, 264] {
                    _ = try render(fixture, appearance: appearance, label: label, width: width)
                }
            }
        }
        _ = try render(card(), appearance: .aqua, label: "german-locale",
            locale: Locale(identifier: "de_DE"))
        for identifier in ["en_US", "gez_ER", "my_MM", "ko_KR", "fr_FR"] {
            for width: CGFloat in [248, 264] {
                _ = try render(card(current: RatePair(receivedBytesPerSecond: Double(UInt64.max),
                                                      sentBytesPerSecond: Double(UInt64.max))),
                    appearance: .aqua, label: "long-\(identifier)",
                    locale: Locale(identifier: identifier), width: width)
            }
            let locale = Locale(identifier: identifier)
            let value = Double(UInt64.max)
            let parts = NetworkDisplayText.byteRateParts(value, locale: locale)
            #expect(parts.number + " " + parts.unit == ResourceQuantityFormatter.byteRate(value, locale: locale))
            #expect(parts.unit == "GB/s")
        }
        #expect(ResourceQuantityFormatter.byteRate(1_024,
            locale: Locale(identifier: "de_DE")) == "1,0 KB/s")
    }

    @Test func displayTextPreservesPhysicalScopeAndConditionalFailure() {
        let physical = item(kind: .physicalWiFi, name: "en0", index: 1)
        let vpn = item(kind: .vpn, name: "utun3", index: 3)
        let tunnel = item(kind: .tunnel)
        #expect(NetworkDisplayText.activeSummary([physical, vpn, tunnel]).contains("3개"))
        #expect(NetworkDisplayText.activeSummary([physical, vpn, tunnel]).contains("VPN"))
        #expect(NetworkDisplayText.compactActiveSummary([physical, vpn, tunnel])
            .contains("Wi-Fi·터널·VPN · 활성 3개"))
        let uncertain = NetworkInterfacePresentation(key: key, kind: .unknown,
            classificationReason: "classification unavailable", linkActive: nil,
            receivedBytes: 0, sentBytes: 0, rate: nil, ipv4: [], ipv6: [], linkSpeed: .collecting)
        #expect(NetworkDisplayText.activeSummary([uncertain]) == "활성 미확인 1개")
        #expect(NetworkDisplayText.compactActiveSummary([uncertain]) == "활성 미확인 1개")
        #expect(NetworkDisplayText.activeSummary([physical, uncertain]).contains("상태 미확인 1개"))
        #expect(NetworkDisplayText.compactSupplemental(.available, lastKnown: false) == nil)
        #expect(NetworkDisplayText.compactSupplemental(.failure("addresses unavailable"),
            lastKnown: true) == "과거 보조 조회 실패")
        #expect(NetworkDisplayText.updateCadence.contains("속도는 실시간 수집 주기"))
        #expect(NetworkDisplayText.updateCadence.contains("주소·연결 상태 보조 정보는 별도 느린 주기"))
        #expect(NetworkDisplayText.kind(.tunnel) == "터널")
        #expect(NetworkDisplayText.link(.unsupported("unsupported: unknown"))
            .contains("미지원"))
        #expect(NetworkDisplayText.link(.failure("sysctl failed")).contains("조회 실패"))
        #expect(NetworkDisplayText.link(.available("1.0 Gbit/s")).contains("bit/s"))
        let partial = card(.partial("physical classification unknown"), partial: true)
        #expect(partial.accessibilityLabel.contains("확인된 일부 합계"))
        #expect(NetworkDisplayText.activity(partial.phase) == "물리 합계 일부 확인")
        #expect(NetworkDisplayText.age(now.advanced(by: .seconds(-10)), now: now) == "원본 조회 10초 전")
        let past = LastKnownRate(rate: RatePair(receivedBytesPerSecond: 10, sentBytesPerSecond: 20)!,
                                 readAt: now.advanced(by: .seconds(-20)))
        #expect(NetworkDisplayText.cardStatus(card(.stopped, current: nil, lastKnown: past), now: now)
            == "중지 · 과거 20초 전")
        #expect(NetworkDisplayText.cardStatus(card(.failure("route"), current: nil, lastKnown: past), now: now)
            == "조회 실패 · 과거 20초 전")
    }

    @Test func selectionAndExplicitCloseReuseCommonPath() {
        let store = DashboardPresentationStore()
        store.selectCard(.network)
        #expect(store.selection == .network)
        store.selectCard(.network)
        #expect(store.selection == .none)
        store.selectCard(.network)
        store.selectCard(.cpu)
        store.dismissDetail(for: .network)
        #expect(store.selection == .cpu)
        store.selectCard(.network)
        store.dismissDetail(for: .network)
        #expect(store.selection == .none)
    }

    @Test func longNameAndLargeRawCountersRemainInDetailSource() throws {
        let fixture = card(interfaces: [
            item(kind: .physicalWiFi, name: "en0", index: 1),
            item(kind: .vpn, name: "utun3", index: 3),
            item(kind: .tunnel, name: key.name, index: 8)
        ])
        let detail = NetworkDetailPopoverContent(presentation: fixture, onClose: {}, fixedNow: now)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: detail)
        renderer.scale = 1
        let image = try #require(renderer.nsImage?.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        #expect(image.pixelsWide == 400)
        #expect(image.pixelsHigh == 480)
        // ImageRenderer는 ScrollView의 레이어를 빈 비트맵으로 내보내므로 실제 행을 별도로 렌더합니다.
        let rows = VStack(spacing: 16) {
            NetworkDetailPopoverContent(presentation: fixture, onClose: {}, fixedNow: now)
                .interfaceRow(fixture.interfaces[0], now: now)
            NetworkDetailPopoverContent(presentation: fixture, onClose: {}, fixedNow: now)
                .interfaceRow(fixture.interfaces[1], now: now)
            NetworkDetailPopoverContent(presentation: fixture, onClose: {}, fixedNow: now)
                .interfaceRow(fixture.interfaces[2], now: now)
        }
        .frame(width: 368)
        .environment(\.colorScheme, .light)
        let rowRenderer = ImageRenderer(content: rows)
        rowRenderer.scale = 1
        let rowImage = try #require(rowRenderer.nsImage?.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        #expect(rowImage.pixelsWide == 368)
        #expect(rowImage.pixelsHigh > 300)
        Attachment.record(try #require(rowImage.representation(using: .png, properties: [:])),
            named: "network-detail-three-kinds-long-name.png")
        #expect(key.name.count > 30)
        #expect(fixture.interfaces.count == 3)
        #expect(fixture.interfaces[2].receivedBytes == UInt64.max)
        #expect(fixture.interfaces[2].ipv4 == ["198.51.100.10"])
        #expect(fixture.interfaces[2].ipv6 == ["2001:db8::1"])
    }
}
