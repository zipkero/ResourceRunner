import SwiftUI

/// 디스크 활동과 별도 저장 공간 조회의 상태를 서로 다른 시각으로 표시합니다.
nonisolated enum DiskDisplayText {
    static func activity(_ phase: ResourceActivityPhase) -> String {
        switch phase {
        case .collecting: "수집 중"
        case .measured: "현재 측정"
        case .partial: "물리 합계 일부 확인"
        case .baseline: "기준점 수집 중"
        case .disconnected: "연결 없음"
        case .noPhysicalDevice: "물리 장치 없음"
        case .failure: "활동 조회 실패"
        case .stopped: "수집 중지"
        }
    }

    static func cardStatus(_ presentation: DiskCardPresentation, now: ContinuousClock.Instant) -> String {
        let state: String = switch presentation.phase {
        case .collecting: "수집 중"
        case .measured: "현재"
        case .partial: "일부 실패"
        case .baseline: "기준점"
        case .disconnected: "연결 없음"
        case .noPhysicalDevice: "물리 장치 없음"
        case .failure: "조회 실패"
        case .stopped: "중지"
        }
        guard presentation.currentRate == nil, let previous = presentation.lastKnownRate else { return state }
        return "\(state) · 과거 \(max(0, previous.readAt.duration(to: now).components.seconds))초 전"
    }

    static func external(_ kind: DiskExternalKind?, reason: String?) -> String {
        guard let kind else { return "외장 여부 미확인 · 저장 공간 조회 대기" }
        switch kind {
        case .internalDevice: return "내장 장치"
        case .externalDevice: return "외장 장치"
        case .unknown: return "외장 여부 미확인 · \(reason ?? "근거 없음")"
        }
    }

    static func mount(_ state: StorageMountState?) -> String {
        guard let state else { return "마운트 상태 미확인" }
        switch state {
        case .mounted: return "마운트됨"
        case .unmounted: return "마운트되지 않음"
        case .relationUnconfirmed: return "장치·볼륨 관계 미확인"
        }
    }

    static func supplemental(_ presentation: StorageSupplementalPresentation) -> String {
        let prefix = presentation.isLastKnown ? "과거 용량 · " : ""
        switch presentation.phase {
        case .collecting: return "용량 수집 중"
        case .refreshing: return prefix + "용량 갱신 중"
        case .available: return prefix + "용량 확인"
        case .partial: return prefix + "용량 일부 확인"
        case .failure: return prefix + "용량 조회 실패"
        case .unsupported: return prefix + "용량 미지원"
        }
    }

    static func compactCapacity(_ presentation: StorageSupplementalPresentation,
                                now: ContinuousClock.Instant) -> String {
        let state: String = switch presentation.phase {
        case .collecting: "용량 수집 중"
        case .refreshing: "용량 갱신 중"
        case .available: "용량 확인"
        case .partial: "용량 일부"
        case .failure: "용량 실패"
        case .unsupported: "용량 미지원"
        }
        guard let readAt = presentation.readAt else { return state }
        let age = max(0, readAt.duration(to: now).components.seconds)
        return "\(state) · \(presentation.isLastKnown ? "과거 " : "")\(age)초 전"
    }

    static func volumeScope(_ scope: DiskVolumeScope) -> String {
        switch scope {
        case .physical: "물리 관계 확인"
        case .virtual: "가상 볼륨"
        case .unconfirmed: "장치 관계 미확인"
        }
    }

    static func age(_ timestamp: ContinuousClock.Instant?, now: ContinuousClock.Instant) -> String {
        NetworkDisplayText.age(timestamp, now: now)
    }

    static func capacitySummary(_ capacity: DiskCapacityPresentation?, locale: Locale) -> String {
        guard let capacity else { return "시스템 / 용량 확인 중" }
        return "전체 \(ResourceQuantityFormatter.bytes(capacity.totalBytes, locale: locale)) · 사용 가능 \(ResourceQuantityFormatter.bytes(capacity.availableBytes, locale: locale))"
    }

    /// 두 값의 단위가 같을 때만 단위를 공유해 고정 보조행에 두 숫자를 온전히 둡니다.
    static func compactCapacitySummary(_ capacity: DiskCapacityPresentation?, locale: Locale) -> String {
        guard let capacity else { return "시스템 / 용량 확인 중" }
        let total = ResourceQuantityFormatter.bytes(capacity.totalBytes, locale: locale)
        let available = ResourceQuantityFormatter.bytes(capacity.availableBytes, locale: locale)
        guard let totalSeparator = total.lastIndex(of: " "),
              let availableSeparator = available.lastIndex(of: " ") else {
            return "전체 \(total)·가용 \(available)"
        }
        let totalUnit = total[total.index(after: totalSeparator)...]
        let availableUnit = available[available.index(after: availableSeparator)...]
        if totalUnit == availableUnit {
            return "전체 \(total[..<totalSeparator])·가용 \(available[..<availableSeparator]) \(totalUnit)"
        }
        return "전체 \(total)·가용 \(available)"
    }

    static let usedDefinition = "사용 중 = 전체 − 사용 가능. APFS 공유 공간에서는 볼륨별 독점 사용량이 아닙니다."
}

nonisolated enum DiskCardLayout {
    static let title = NetworkCardLayout.title
    static let rates = NetworkCardLayout.rates
    static let auxiliary = NetworkCardLayout.auxiliary
    static let graph = NetworkCardLayout.graph
    static let spacing = NetworkCardLayout.spacing
    static let padding = NetworkCardLayout.padding
    static let total = NetworkCardLayout.total
}

struct DiskCardView: View {
    let presentation: DiskCardPresentation
    var fixedNow: ContinuousClock.Instant? = nil
    @Environment(\.locale) private var locale

    var body: some View {
        let now = fixedNow ?? ContinuousClock().now
        let graph = ResourceRateGraph.make(history: presentation.recentHistory,
            firstHistoryPointAt: presentation.firstHistoryPointAt, currentTimestamp: now)
        return VStack(alignment: .leading, spacing: DiskCardLayout.spacing) {
            HStack {
                Text("Disk · 물리 합계")
                Spacer(minLength: 0)
                Text(DiskDisplayText.cardStatus(presentation, now: now)).lineLimit(1)
                Text("⌘4")
            }
            .dashboardTypography(DashboardStyle.TypographyRole.heading)
            .frame(height: DiskCardLayout.title)

            VStack(spacing: 4) {
                rateRow(.received, rate: selectedRate?.receivedBytesPerSecond)
                rateRow(.sent, rate: selectedRate?.sentBytesPerSecond)
            }
            .frame(height: DiskCardLayout.rates)

            VStack(alignment: .leading, spacing: 4) {
                Text(DiskDisplayText.compactCapacitySummary(presentation.supplemental.capacity, locale: locale))
                    .lineLimit(1)
                    .accessibilityLabel("시스템 / " + DiskDisplayText.capacitySummary(presentation.supplemental.capacity, locale: locale) + ". " + DiskDisplayText.usedDefinition)
                    .frame(height: 14)
                HStack(spacing: 4) {
                    Text(DiskDisplayText.compactCapacity(presentation.supplemental, now: now))
                        .lineLimit(1)
                        .accessibilityLabel("저장 공간 별도 느린 주기, " + DiskDisplayText.supplemental(presentation.supplemental) + ", " + DiskDisplayText.age(presentation.supplemental.readAt, now: now))
                    Spacer(minLength: 0)
                    Text(graph.upperBound.map { "0–\(ResourceQuantityFormatter.byteRate($0, locale: locale))" }
                         ?? "범위 대기 · B/s")
                        .lineLimit(1)
                }
                .frame(height: 14)
            }
            .dashboardTypography(DashboardStyle.TypographyRole.label)
            .frame(height: DiskCardLayout.auxiliary)

            ResourceRateGraphSlotView(kind: .disk, history: presentation.recentHistory,
                firstHistoryPointAt: presentation.firstHistoryPointAt, fixedNow: fixedNow)
                .frame(height: DiskCardLayout.graph)
        }
        .padding(DiskCardLayout.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: DiskCardLayout.total)
        .background(RoundedRectangle(cornerRadius: DashboardStyle.CardSurface.cornerRadius)
            .fill(DashboardStyle.CardSurface.fillColor))
        .contentShape(RoundedRectangle(cornerRadius: DashboardStyle.CardSurface.cornerRadius))
    }

    private var selectedRate: RatePair? { presentation.currentRate ?? presentation.lastKnownRate?.rate }
    private var isPast: Bool { presentation.currentRate == nil && presentation.lastKnownRate != nil }

    private func rateRow(_ series: ResourceRateGraphSlotView.Series, rate: Double?) -> some View {
        HStack(spacing: 3) {
            ResourceRateLegendMarkerView(kind: .disk, series: series)
            Text(series == .received ? "Read" : "Write")
                .dashboardTypography(DashboardStyle.TypographyRole.label)
            Spacer(minLength: 2)
            if let rate {
                let parts = ResourceQuantityFormatter.byteRate(rate, locale: locale)
                    .split(separator: " ", maxSplits: 1)
                Text(String(parts.first ?? ""))
                    .dashboardTypography(DashboardStyle.TypographyRole.focus).lineLimit(1)
                Text(parts.count > 1 ? String(parts[1]) : "B/s")
                    .dashboardTypography(DashboardStyle.TypographyRole.label).lineLimit(1)
            } else {
                Text(DiskDisplayText.activity(presentation.phase))
                    .dashboardTypography(DashboardStyle.TypographyRole.label).lineLimit(1)
            }
        }
        .frame(height: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rateAccessibility(series: series, rate: rate))
    }

    private func rateAccessibility(series: ResourceRateGraphSlotView.Series, rate: Double?) -> String {
        let label = series == .received ? "Read 읽기" : "Write 쓰기"
        guard let rate else { return "\(label), \(DiskDisplayText.activity(presentation.phase)), 현재 속도 없음" }
        let scope = presentation.currentRateIsPartial ? "확인된 물리 장치 일부 합계" : "물리 장치 합계"
        let age = DiskDisplayText.age(isPast ? presentation.lastKnownRate?.readAt : presentation.latestReadAt,
            now: fixedNow ?? ContinuousClock().now)
        return "\(label), \(isPast ? "과거" : "현재") \(scope), \(ResourceQuantityFormatter.byteRate(rate, locale: locale)), \(age), \(DiskDisplayText.activity(presentation.phase))"
    }
}

/// 볼륨 용량은 각 볼륨 원본 그대로 보여주며 합산하거나 독점 사용량으로 해석하지 않습니다.
struct DiskDetailPopoverContent: View {
    let presentation: DiskCardPresentation
    let onClose: () -> Void
    var fixedNow: ContinuousClock.Instant? = nil
    @Environment(\.locale) private var locale

    var body: some View {
        let now = fixedNow ?? ContinuousClock().now
        return ScrollView {
            VStack(alignment: .leading, spacing: DashboardStyle.Section.betweenSections) {
                HStack {
                    Text("Disk 장치와 볼륨")
                        .dashboardTypography(DashboardStyle.TypographyRole.heading)
                    Spacer()
                    Button("닫기", action: onClose).accessibilityIdentifier("DiskDetailClose")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("활동 · \(DiskDisplayText.activity(presentation.phase)) · \(DiskDisplayText.age(presentation.latestReadAt, now: now))")
                    if case .partial(let reason) = presentation.phase { Text("물리 합계 일부 실패: \(reason)") }
                    if case .failure(let reason) = presentation.phase { Text("활동 조회 실패: \(reason)") }
                    Text("용량은 활동과 별도 느린 주기로 갱신 · \(DiskDisplayText.supplemental(presentation.supplemental)) · \(DiskDisplayText.age(presentation.supplemental.readAt, now: now))")
                    if case .partial(let reason) = presentation.supplemental.phase { Text("용량 일부 실패: \(reason)") }
                    if case .failure(let reason) = presentation.supplemental.phase { Text("용량 조회 실패: \(reason)") }
                    Text("시스템 / · \(DiskDisplayText.capacitySummary(presentation.supplemental.capacity, locale: locale))")
                    if let capacity = presentation.supplemental.capacity {
                        Text("사용 중 \(ResourceQuantityFormatter.bytes(capacity.usedBytes, locale: locale))")
                        Text("용량 관계: \(capacity.relationReason)")
                    }
                    Text(DiskDisplayText.usedDefinition)
                    Text(externalSummary)
                }
                .dashboardTypography(DashboardStyle.TypographyRole.label)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(summaryAccessibility(now: now))
                .accessibilityIdentifier("DiskSummary")

                Text("마운트 볼륨")
                    .dashboardTypography(DashboardStyle.TypographyRole.heading)
                if presentation.supplemental.volumes.isEmpty {
                    Text("확인된 마운트 볼륨 없음")
                        .dashboardTypography(DashboardStyle.TypographyRole.label)
                }
                ForEach(presentation.supplemental.volumes, id: \.identity) { item in
                    volumeRow(item)
                }

                Text("물리 장치 · 드라이버 통계")
                    .dashboardTypography(DashboardStyle.TypographyRole.heading)
                if presentation.devices.isEmpty {
                    Text("확인된 물리 장치 없음")
                        .dashboardTypography(DashboardStyle.TypographyRole.label)
                }
                ForEach(presentation.devices, id: \.registryID) { item in
                    deviceRow(item, now: now)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: DashboardView.detailPopupWidth, height: DashboardView.detailPopupHeight)
        .accessibilityIdentifier("DiskDetail")
    }

    private func summaryAccessibility(now: ContinuousClock.Instant) -> String {
        let activity = "활동 " + DiskDisplayText.activity(presentation.phase) + ", " +
            DiskDisplayText.age(presentation.latestReadAt, now: now)
        let storage = "저장 공간 별도 느린 주기, " +
            DiskDisplayText.supplemental(presentation.supplemental) + ", " +
            DiskDisplayText.age(presentation.supplemental.readAt, now: now)
        let capacity = "시스템 / " +
            DiskDisplayText.capacitySummary(presentation.supplemental.capacity, locale: locale)
        return [activity, storage, capacity, DiskDisplayText.usedDefinition, externalSummary]
            .joined(separator: ", ")
    }

    private var externalSummary: String {
        switch presentation.supplemental.externalDevicesAbsent {
        case .some(true): "외장 장치 없음"
        case .some(false): "외장 장치 확인 · 아래 장치 상태 참조"
        case .none: "외장 장치 여부 미확인 · 용량 조회 대기 또는 실패"
        }
    }

    func volumeRow(_ item: DiskVolumeReading) -> some View {
        let paths = item.mountPaths.sorted().joined(separator: ", ")
        let lines = [
            "\(paths.isEmpty ? item.identity : paths) · \(item.fileSystem ?? "파일 시스템 미확인") · \(DiskDisplayText.volumeScope(item.scope))",
            "전체 \(ResourceQuantityFormatter.bytes(item.totalBytes, locale: locale)) · 사용 중 \(ResourceQuantityFormatter.bytes(item.usedBytes, locale: locale)) · 사용 가능 \(ResourceQuantityFormatter.bytes(item.availableBytes, locale: locale))",
            "장치 관계: \(item.relationReason)",
            item.sharedCapacity ? "APFS 공유 공간 · 볼륨별 독점 사용량 아님" : "공유 공간 여부 미확인 또는 비공유",
            DiskDisplayText.usedDefinition
        ]
        return detailRow(lines, identifier: "DiskVolume-\(item.identity)")
    }

    func deviceRow(_ item: DiskDevicePresentation, now: ContinuousClock.Instant) -> some View {
        let read = item.rate.map { ResourceQuantityFormatter.byteRate($0.receivedBytesPerSecond, locale: locale) } ?? "현재 속도 없음"
        let write = item.rate.map { ResourceQuantityFormatter.byteRate($0.sentBytesPerSecond, locale: locale) } ?? "현재 속도 없음"
        let readBytes = item.readBytes.map { "\($0.formatted(.number.locale(locale))) B" } ?? "조회 실패 · \(item.bytesReason)"
        let writtenBytes = item.writtenBytes.map { "\($0.formatted(.number.locale(locale))) B" } ?? "조회 실패 · \(item.bytesReason)"
        let operations: String = switch item.operations {
        case .collecting: "드라이버 IOPS 기준점 수집 중"
        case .available: item.operationsRate.map {
            "드라이버 IOPS Read \(ResourceQuantityFormatter.driverOperationsPerSecond($0.readsPerSecond, locale: locale)) · Write \(ResourceQuantityFormatter.driverOperationsPerSecond($0.writesPerSecond, locale: locale))"
        } ?? "드라이버 IOPS 값 미확인"
        case .unsupported(let reason): "드라이버 IOPS 미지원 · \(reason)"
        case .failure(let reason): "드라이버 IOPS 조회 실패 · \(reason)"
        }
        let lines = [
            "\(item.bsdNames.sorted().joined(separator: ", ")) · 물리 드라이버 ID \(item.registryID)",
            "\(DiskDisplayText.external(item.external, reason: item.externalReason)) · \(DiskDisplayText.mount(item.mountState))",
            "현재 Read \(read) · Write \(write) · \(DiskDisplayText.age(presentation.latestReadAt, now: now))",
            "드라이버 원시 누적 Read \(readBytes) · Write \(writtenBytes)",
            operations + " · 앱 요청 수 아님"
        ]
        return detailRow(lines, identifier: "DiskDevice-\(item.registryID)")
    }

    private func detailRow(_ lines: [String], identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
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
        .accessibilityIdentifier(identifier)
    }
}
