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

    static func compactSupplemental(_ presentation: StorageSupplementalPresentation) -> String? {
        let prefix = presentation.isLastKnown ? "과거 " : ""
        switch presentation.phase {
        case .available: return presentation.isLastKnown ? "과거 용량" : nil
        case .collecting: return presentation.capacity == nil ? nil : "용량 갱신 중"
        case .refreshing: return prefix + "용량 갱신 중"
        case .partial: return prefix + "용량 일부 실패"
        case .failure: return prefix + "용량 조회 실패"
        case .unsupported: return prefix + "용량 미지원"
        }
    }

    static func compactCardStatus(_ presentation: DiskCardPresentation,
                                  now: ContinuousClock.Instant) -> String {
        let activity = cardStatus(presentation, now: now)
        guard let supplemental = compactSupplemental(presentation.supplemental) else { return activity }
        return activity == "현재" ? supplemental : activity + " · " + supplemental
    }

    static func miniGraphAccessibility(_ graph: ResourceRateGraph,
                                       phase: ResourceActivityPhase,
                                       locale: Locale = .current) -> String {
        let range = graph.upperBound.map { "0–\(ResourceQuantityFormatter.byteRate($0, locale: locale))" }
            ?? "속도 범위 대기 · B/s"
        let progress = graph.progressLabel.isEmpty ? "" : ", \(graph.progressLabel)"
        return "Disk \(graph.timeRange.windowLabel) 그래프, Read 점선, Write 실선, 원본 범위 \(range), " +
            "\(activity(phase)), 수집 공백은 이어 그리지 않음\(progress)"
    }

    static func miniGraphAccessibility(presentation: DiskCardPresentation,
                                       now: ContinuousClock.Instant,
                                       timeRange: GraphTimeRange = .tenMinutes,
                                       locale: Locale = .current) -> String {
        miniGraphAccessibility(ResourceRateGraph.make(history: presentation.recentHistory,
            firstHistoryPointAt: presentation.firstHistoryPointAt, currentTimestamp: now,
            timeRange: timeRange),
            phase: presentation.phase, locale: locale)
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
        return "전체 \(ResourceQuantityFormatter.storageBytes(capacity.totalBytes, locale: locale)) · 사용 가능 \(ResourceQuantityFormatter.storageBytes(capacity.availableBytes, locale: locale))"
    }

    /// 두 값의 단위가 같을 때만 단위를 공유해 고정 보조행에 두 숫자를 온전히 둡니다.
    static func compactCapacitySummary(_ capacity: DiskCapacityPresentation?, locale: Locale) -> String {
        guard let capacity else { return "시스템 / 용량 확인 중" }
        let total = ResourceQuantityFormatter.storageBytes(capacity.totalBytes, locale: locale)
        let available = ResourceQuantityFormatter.storageBytes(capacity.availableBytes, locale: locale)
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

    static let usedDefinition = "사용 가능에는 macOS가 회수할 수 있는 공간이 포함됩니다. 사용 중 = 전체 − 사용 가능이며 실제 파일 점유량이 아닙니다. APFS 공유 공간에서는 볼륨별 독점 사용량이 아닙니다."
}

nonisolated enum DiskCardLayout {
    static let title: CGFloat = 14
    static let ratesAndGraph: CGFloat = 54
    static let miniPlot: CGFloat = 42
    static let auxiliary: CGFloat = 28
    static let spacing: CGFloat = 2
    static let padding: CGFloat = 6
    static let total: CGFloat = title + ratesAndGraph + auxiliary + spacing * 2 + padding * 2
}

private enum DiskCompactTypography {
    static let heading = Font.system(size: 10, weight: .semibold)
    static let number = Font.system(size: 17.33, weight: .semibold).monospacedDigit()
    static let name = Font.system(size: 10)
    static let unit = Font.system(size: 10)
    static let capacity = Font.system(size: 10)
}

struct DiskCardView: View {
    let presentation: DiskCardPresentation
    var timeRange: GraphTimeRange = .tenMinutes
    var fixedNow: ContinuousClock.Instant? = nil
    @Environment(\.locale) private var locale

    var body: some View {
        let now = fixedNow ?? ContinuousClock().now
        let graph = ResourceRateGraph.make(history: presentation.recentHistory,
            firstHistoryPointAt: presentation.firstHistoryPointAt, currentTimestamp: now,
            timeRange: timeRange)
        return VStack(alignment: .leading, spacing: DiskCardLayout.spacing) {
            HStack(spacing: 3) {
                Text("Disk · 물리 합계")
                Spacer(minLength: 0)
                Text(DiskDisplayText.compactCardStatus(presentation, now: now)).lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("⌘4")
            }
            .font(DiskCompactTypography.heading)
            .foregroundStyle(.secondary)
            .frame(height: DiskCardLayout.title)

            GeometryReader { geometry in
                let rateWidth = rateColumnWidth(total: geometry.size.width)
                HStack(spacing: 8) {
                    VStack(spacing: 1) {
                        rateRow(.received, rate: selectedRate?.receivedBytesPerSecond)
                        rateRow(.sent, rate: selectedRate?.sentBytesPerSecond)
                    }
                    .frame(width: rateWidth, height: DiskCardLayout.ratesAndGraph)
                    ResourceRateGraphSlotView(kind: .disk, history: presentation.recentHistory,
                        firstHistoryPointAt: presentation.firstHistoryPointAt,
                        timeRange: timeRange, fixedNow: fixedNow,
                        plotHeight: DiskCardLayout.miniPlot, showsAxis: false)
                        .frame(maxWidth: .infinity)
                        .frame(height: DiskCardLayout.miniPlot)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(DiskDisplayText.miniGraphAccessibility(graph,
                            phase: presentation.phase, locale: locale))
                        .accessibilityIdentifier("DiskMiniGraph")
                }
                .frame(height: DiskCardLayout.ratesAndGraph)
            }
            .frame(height: DiskCardLayout.ratesAndGraph)

            Text(DiskDisplayText.compactCapacitySummary(presentation.supplemental.capacity,
                locale: locale))
                .font(DiskCompactTypography.capacity)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("시스템 / " + DiskDisplayText.capacitySummary(
                    presentation.supplemental.capacity, locale: locale) + ". " +
                    DiskDisplayText.supplemental(presentation.supplemental) + ". " +
                    DiskDisplayText.usedDefinition)
            .frame(height: DiskCardLayout.auxiliary)
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

    private func rateColumnWidth(total: CGFloat) -> CGFloat {
        let largest = max(selectedRate?.receivedBytesPerSecond ?? 0,
            selectedRate?.sentBytesPerSecond ?? 0)
        let length = NetworkDisplayText.byteRateParts(largest, locale: locale).number.count
        return min(max(112, length > 8 ? 170 : 112), max(112, total - 8 - 48))
    }

    private func rateRow(_ series: ResourceRateGraphSlotView.Series, rate: Double?) -> some View {
        Group {
            if let rate, NetworkDisplayText.byteRateParts(rate, locale: locale).number.count > 8 {
                let parts = NetworkDisplayText.byteRateParts(rate, locale: locale)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 2) {
                        Text(series == .received ? "Read" : "Write")
                            .font(DiskCompactTypography.name)
                        Text(parts.unit).font(DiskCompactTypography.unit)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.secondary)
                    Text(parts.number)
                        .font(DiskCompactTypography.number)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 3) {
                    Text(series == .received ? "Read" : "Write")
                        .font(DiskCompactTypography.name)
                        .foregroundStyle(.secondary)
                        .frame(width: 27, alignment: .leading)
                    Spacer(minLength: 0)
                    if let rate {
                        let parts = NetworkDisplayText.byteRateParts(rate, locale: locale)
                        Text(parts.number)
                            .font(DiskCompactTypography.number)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .layoutPriority(1)
                        Text(parts.unit)
                            .font(DiskCompactTypography.unit)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 26, alignment: .leading)
                    } else {
                        Text(DiskDisplayText.activity(presentation.phase))
                            .font(DiskCompactTypography.unit)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .frame(height: 26)
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
    @ObservedObject var viewport: DashboardViewport = DashboardViewport()
    var timeRange: GraphTimeRange = .tenMinutes
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
                    Text(DiskDisplayText.miniGraphAccessibility(presentation: presentation,
                        now: now, timeRange: timeRange, locale: locale))
                    if case .partial(let reason) = presentation.phase { Text("물리 합계 일부 실패: \(reason)") }
                    if case .failure(let reason) = presentation.phase { Text("활동 조회 실패: \(reason)") }
                    Text("용량은 활동과 별도 느린 주기로 갱신 · \(DiskDisplayText.supplemental(presentation.supplemental)) · \(DiskDisplayText.age(presentation.supplemental.readAt, now: now))")
                    if case .partial(let reason) = presentation.supplemental.phase { Text("용량 일부 실패: \(reason)") }
                    if case .failure(let reason) = presentation.supplemental.phase { Text("용량 조회 실패: \(reason)") }
                    Text("시스템 / · \(DiskDisplayText.capacitySummary(presentation.supplemental.capacity, locale: locale))")
                    if let capacity = presentation.supplemental.capacity {
                        Text("사용 중 \(ResourceQuantityFormatter.storageBytes(capacity.usedBytes, locale: locale))")
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
        .frame(width: viewport.detailSize.width, height: viewport.detailSize.height)
        .background(DashboardDetailWindowCapture(viewport: viewport, selection: .disk))
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
        let graph = DiskDisplayText.miniGraphAccessibility(presentation: presentation,
            now: now, timeRange: timeRange, locale: locale)
        return [activity, graph, storage, capacity, DiskDisplayText.usedDefinition, externalSummary]
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
            "전체 \(ResourceQuantityFormatter.storageBytes(item.totalBytes, locale: locale)) · 사용 중 \(ResourceQuantityFormatter.storageBytes(item.usedBytes, locale: locale)) · 사용 가능 \(ResourceQuantityFormatter.storageBytes(item.availableBytes, locale: locale))",
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
