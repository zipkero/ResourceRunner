import SwiftUI

/// 활동 원본과 별도 보조 원본의 상태를 카드 한 슬롯에 배치할 문자열만 만듭니다.
nonisolated enum NetworkDisplayText {
    static func kind(_ kind: NetworkInterfaceKind) -> String {
        switch kind {
        case .physicalWiFi: "물리 Wi-Fi"
        case .physicalEthernet: "물리 Ethernet"
        case .physicalOther: "기타 물리"
        case .logical: "논리"
        case .virtual: "가상"
        case .tunnel: "터널"
        case .vpn: "VPN"
        case .loopback: "Loopback"
        case .unknown: "종류 미확인"
        }
    }

    static func activity(_ phase: ResourceActivityPhase) -> String {
        switch phase {
        case .collecting: "수집 중"
        case .measured: "현재 측정"
        case .partial: "물리 합계 일부 확인"
        case .baseline: "기준점 수집 중"
        case .disconnected: "연결 없음"
        case .noPhysicalDevice: "물리 대상 없음"
        case .failure: "활동 조회 실패"
        case .stopped: "수집 중지"
        }
    }

    static func supplemental(_ phase: SupplementalDisplayPhase, lastKnown: Bool) -> String {
        let prefix = lastKnown ? "과거 보조 정보 · " : ""
        switch phase {
        case .collecting: return "보조 수집 중"
        case .refreshing: return prefix + "보조 갱신 중"
        case .available: return prefix + "보조 확인"
        case .partial: return prefix + "보조 일부 확인"
        case .failure: return prefix + "보조 조회 실패"
        case .unsupported: return prefix + "보조 미지원"
        }
    }

    static func activeSummary(_ interfaces: [NetworkInterfacePresentation]) -> String {
        let active = interfaces.filter { $0.linkActive == true && $0.kind != .loopback }
        let unknown = interfaces.filter { $0.linkActive == nil && $0.kind != .loopback }
        guard !active.isEmpty else {
            return unknown.isEmpty ? "활성 대상 0개" : "활성 미확인 \(unknown.count)개"
        }
        let kinds = Set(active.map(\.kind))
        let names = kinds.sorted { $0.rawValue < $1.rawValue }.map { kind in
            switch kind {
            case .physicalWiFi: "Wi-Fi"
            case .physicalEthernet: "Ethernet"
            case .physicalOther: "물리"
            case .logical: "논리"
            case .virtual: "가상"
            case .tunnel: "터널"
            case .vpn: "VPN"
            case .loopback: "Loopback"
            case .unknown: "미확인"
            }
        }.joined(separator: "·")
        let uncertain = unknown.isEmpty ? "" : " · 상태 미확인 \(unknown.count)개"
        return "활성 확인 \(active.count)개 · \(names)\(uncertain)"
    }

    static func cardStatus(_ presentation: NetworkCardPresentation,
                           now: ContinuousClock.Instant) -> String {
        let state: String = switch presentation.phase {
        case .collecting: "수집 중"
        case .measured: "현재"
        case .partial: "일부 실패"
        case .baseline: "기준점"
        case .disconnected: "연결 없음"
        case .noPhysicalDevice: "물리 대상 없음"
        case .failure: "조회 실패"
        case .stopped: "중지"
        }
        guard presentation.currentRate == nil, let previous = presentation.lastKnownRate else { return state }
        return "\(state) · 과거 \(max(0, previous.readAt.duration(to: now).components.seconds))초 전"
    }

    static func link(_ metric: ConditionalMetric) -> String {
        switch metric {
        case .collecting: "링크 속도 조회 중"
        case .available(let value): "링크 속도 \(value)"
        case .unsupported(let reason): "링크 속도 미지원 · \(reason)"
        case .failure(let reason): "링크 속도 조회 실패 · \(reason)"
        }
    }

    static func age(_ timestamp: ContinuousClock.Instant?, now: ContinuousClock.Instant) -> String {
        guard let timestamp else { return "원본 조회 시각 없음" }
        let seconds = max(0, Int(timestamp.duration(to: now).components.seconds))
        return "원본 조회 \(seconds)초 전"
    }
}

/// 설계의 다섯 고정 높이와 세 구역 간격을 한곳에서 검증합니다.
nonisolated enum NetworkCardLayout {
    static let title: CGFloat = 12
    static let rates: CGFloat = 68
    static let auxiliary: CGFloat = 32
    static let graph: CGFloat = 118
    static let spacing: CGFloat = 16
    static let padding: CGFloat = 8
    static let total: CGFloat = title + rates + auxiliary + graph + spacing * 3 + padding * 2
}

struct NetworkCardView: View {
    let presentation: NetworkCardPresentation
    var fixedNow: ContinuousClock.Instant? = nil
    @Environment(\.locale) private var locale

    var body: some View {
        let now = fixedNow ?? ContinuousClock().now
        let graph = ResourceRateGraph.make(history: presentation.recentHistory,
            firstHistoryPointAt: presentation.firstHistoryPointAt, currentTimestamp: now)
        return VStack(alignment: .leading, spacing: NetworkCardLayout.spacing) {
            HStack {
                Text("Network · 물리 합계")
                Spacer(minLength: 0)
                Text(NetworkDisplayText.cardStatus(presentation, now: now))
                    .lineLimit(1)
                Text("⌘3")
            }
            .dashboardTypography(DashboardStyle.TypographyRole.heading)
            .frame(height: NetworkCardLayout.title)

            VStack(spacing: 4) {
                rateRow(.received, rate: selectedRate?.receivedBytesPerSecond)
                rateRow(.sent, rate: selectedRate?.sentBytesPerSecond)
            }
            .frame(height: NetworkCardLayout.rates)

            VStack(alignment: .leading, spacing: 4) {
                Text(NetworkDisplayText.activeSummary(presentation.interfaces))
                    .lineLimit(1)
                    .accessibilityLabel(NetworkDisplayText.activeSummary(presentation.interfaces))
                    .frame(height: 14)
                HStack(spacing: 4) {
                    Text(NetworkDisplayText.supplemental(presentation.supplemental.phase,
                         lastKnown: presentation.supplemental.isLastKnown))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(graph.upperBound.map { "0–\(ResourceQuantityFormatter.byteRate($0, locale: locale))" }
                         ?? "속도 범위 대기 · B/s")
                        .lineLimit(1)
                }
                .frame(height: 14)
            }
            .dashboardTypography(DashboardStyle.TypographyRole.label)
            .frame(height: NetworkCardLayout.auxiliary)

            ResourceRateGraphSlotView(kind: .network, history: presentation.recentHistory,
                firstHistoryPointAt: presentation.firstHistoryPointAt, fixedNow: fixedNow)
                .frame(height: NetworkCardLayout.graph)
        }
        .padding(NetworkCardLayout.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: NetworkCardLayout.total)
        .background(RoundedRectangle(cornerRadius: DashboardStyle.CardSurface.cornerRadius)
            .fill(DashboardStyle.CardSurface.fillColor))
        .contentShape(RoundedRectangle(cornerRadius: DashboardStyle.CardSurface.cornerRadius))
    }

    private var selectedRate: RatePair? {
        presentation.currentRate ?? presentation.lastKnownRate?.rate
    }

    private var isPast: Bool {
        presentation.currentRate == nil && presentation.lastKnownRate != nil
    }

    private func rateRow(_ series: ResourceRateGraphSlotView.Series, rate: Double?) -> some View {
        HStack(spacing: 3) {
            ResourceRateLegendMarkerView(kind: .network, series: series)
            Text(series == .received ? "다운로드" : "업로드")
                .dashboardTypography(DashboardStyle.TypographyRole.label)
            Spacer(minLength: 2)
            if let rate {
                let parts = ResourceQuantityFormatter.byteRate(rate, locale: locale)
                    .split(separator: " ", maxSplits: 1)
                Text(String(parts.first ?? ""))
                    .dashboardTypography(DashboardStyle.TypographyRole.focus)
                    .lineLimit(1)
                Text(parts.count > 1 ? String(parts[1]) : "B/s")
                    .dashboardTypography(DashboardStyle.TypographyRole.label)
                    .lineLimit(1)
            } else {
                Text(NetworkDisplayText.activity(presentation.phase))
                    .dashboardTypography(DashboardStyle.TypographyRole.label)
                    .lineLimit(1)
            }
        }
        .frame(height: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rateAccessibility(series: series, rate: rate))
    }

    private func rateAccessibility(series: ResourceRateGraphSlotView.Series, rate: Double?) -> String {
        let label = series == .received ? "다운로드 RX" : "업로드 TX"
        guard let rate else { return "\(label), \(NetworkDisplayText.activity(presentation.phase)), 현재 속도 없음" }
        let scope = presentation.currentRateIsPartial ? "확인된 물리 대상 일부 합계" : "물리 대상 합계"
        let age = NetworkDisplayText.age(isPast ? presentation.lastKnownRate?.readAt : presentation.latestReadAt,
            now: fixedNow ?? ContinuousClock().now)
        return "\(label), \(isPast ? "과거" : "현재") \(scope), \(ResourceQuantityFormatter.byteRate(rate, locale: locale)), \(age), \(NetworkDisplayText.activity(presentation.phase))"
    }
}

/// 카드 옆 팝업의 인터페이스 목록은 긴 이름과 다수 대상을 내부 스크롤로 보존합니다.
struct NetworkDetailPopoverContent: View {
    let presentation: NetworkCardPresentation
    let onClose: () -> Void
    var fixedNow: ContinuousClock.Instant? = nil
    @Environment(\.locale) private var locale

    var body: some View {
        let now = fixedNow ?? ContinuousClock().now
        return ScrollView {
            VStack(alignment: .leading, spacing: DashboardStyle.Section.betweenSections) {
                HStack {
                    Text("Network 인터페이스")
                        .dashboardTypography(DashboardStyle.TypographyRole.heading)
                    Spacer()
                    Button("닫기", action: onClose).accessibilityIdentifier("NetworkDetailClose")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(NetworkDisplayText.activity(presentation.phase)) · \(NetworkDisplayText.activeSummary(presentation.interfaces))")
                    if case .partial(let reason) = presentation.phase { Text("물리 합계 일부 실패: \(reason)") }
                    if case .failure(let reason) = presentation.phase { Text("활동 조회 실패: \(reason)") }
                    if case .partial(let reason) = presentation.supplemental.phase { Text("보조 일부 실패: \(reason)") }
                    if case .failure(let reason) = presentation.supplemental.phase { Text("보조 조회 실패: \(reason)") }
                    Text("현재 속도는 확인된 물리 대상만 합산합니다. VPN·터널은 아래 상세 전용입니다.")
                    Text(NetworkDisplayText.age(presentation.latestReadAt, now: now))
                    Text("\(NetworkDisplayText.supplemental(presentation.supplemental.phase, lastKnown: presentation.supplemental.isLastKnown)) · \(NetworkDisplayText.age(presentation.supplemental.readAt, now: now))")
                }
                .dashboardTypography(DashboardStyle.TypographyRole.label)
                if presentation.interfaces.isEmpty {
                    Text("현재 인터페이스 정보 없음")
                        .dashboardTypography(DashboardStyle.TypographyRole.label)
                }
                ForEach(presentation.interfaces, id: \.key) { item in
                    interfaceRow(item, now: now)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: DashboardView.detailPopupWidth, height: DashboardView.detailPopupHeight)
        .accessibilityIdentifier("NetworkDetail")
    }

    func interfaceRow(_ item: NetworkInterfacePresentation, now: ContinuousClock.Instant) -> some View {
        let state = item.linkActive.map { $0 ? "연결 활성" : "연결 비활성" } ?? "연결 상태 미확인"
        let receive = item.rate.map { ResourceQuantityFormatter.byteRate($0.receivedBytesPerSecond, locale: locale) } ?? "현재 속도 없음"
        let send = item.rate.map { ResourceQuantityFormatter.byteRate($0.sentBytesPerSecond, locale: locale) } ?? "현재 속도 없음"
        let age = NetworkDisplayText.age(presentation.latestReadAt, now: now)
        let lines = [
            "\(item.key.name) · \(NetworkDisplayText.kind(item.kind)) · \(state)",
            "분류 근거: \(item.classificationReason)",
            "현재 RX \(receive) · 현재 TX \(send) · \(age)",
            "원시 누적 RX \(item.receivedBytes.formatted(.number.locale(locale))) B · 원시 누적 TX \(item.sentBytes.formatted(.number.locale(locale))) B",
            "IPv4 \(item.ipv4.isEmpty ? "없음 또는 미확인" : item.ipv4.joined(separator: ", "))",
            "IPv6 \(item.ipv6.isEmpty ? "없음 또는 미확인" : item.ipv6.joined(separator: ", "))",
            NetworkDisplayText.link(item.linkSpeed)
        ]
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(lines, id: \.self) { line in
                Text(line).fixedSize(horizontal: false, vertical: true)
            }
        }
        .dashboardTypography(DashboardStyle.TypographyRole.label)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: DashboardStyle.CardSurface.cornerRadius)
            .fill(DashboardStyle.CardSurface.fillColor))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lines.joined(separator: ", "))
        .accessibilityIdentifier("NetworkInterface-\(item.key.name)")
    }
}
