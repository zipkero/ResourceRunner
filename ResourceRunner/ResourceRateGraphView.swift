import SwiftUI

/// CPU와 속도 그래프가 동일한 100pt 판 면·클리핑을 사용합니다.
/// 지금 시각의 선 두께와 창 밖으로 막 밀려난 표본이 카드 면으로 번지지 않게 판에서 자릅니다.
struct DashboardGraphPlotSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(height: HistoryGraphLayout.plotHeight)
            .background(DashboardColorPalette.graphPlotSurface)
            .clipped()
    }
}

struct ResourceRateGraphSlotView: View {
    enum Kind: Sendable {
        case network, disk

        var labels: (String, String) {
            switch self {
            case .network: ("다운로드", "업로드")
            case .disk: ("읽기", "쓰기")
            }
        }

        func color(for series: Series) -> Color {
            switch (self, series) {
            case (.network, .received): DashboardColorPalette.networkReceived
            case (.network, .sent): DashboardColorPalette.networkSent
            case (.disk, .received): DashboardColorPalette.diskRead
            case (.disk, .sent): DashboardColorPalette.diskWritten
            }
        }
    }

    enum Series: CaseIterable, Sendable {
        case received, sent

        var style: StrokeStyle {
            switch self {
            case .received: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
            case .sent: StrokeStyle(lineWidth: 1.5)
            }
        }

        func value(_ point: RateHistoryPoint) -> Double {
            switch self {
            case .received: point.rate.receivedBytesPerSecond
            case .sent: point.rate.sentBytesPerSecond
            }
        }
    }

    let kind: Kind
    let history: [RateHistoryPoint]
    let firstHistoryPointAt: ContinuousClock.Instant?
    /// 결정적 렌더 테스트에서는 시간을 고정하고 실제 앱에서는 매초 새 창을 그립니다.
    var fixedNow: ContinuousClock.Instant? = nil

    var body: some View {
        Group {
            if let fixedNow {
                slot(at: fixedNow)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    slot(at: ContinuousClock().now)
                }
            }
        }
        .frame(height: HistoryGraphLayout.slotHeight)
    }

    private func slot(at now: ContinuousClock.Instant) -> some View {
        let graph = ResourceRateGraph.make(history: history,
            firstHistoryPointAt: firstHistoryPointAt, currentTimestamp: now)
        return VStack(spacing: HistoryGraphLayout.axisSpacing) {
            ZStack(alignment: .top) {
                Canvas { context, size in
                    drawGridline(in: &context, size: size)
                    let segments = graph.downsampledSegments(
                        bucketCount: HistoryPoint.downsampledBucketCount(forRenderWidth: size.width))
                    // 실제 0과 상한의 선 두께 절반이 판 밖으로 잘려 사라지지 않게 중심만 안쪽에 둡니다.
                    func yPosition(_ value: Double, series: Series) -> CGFloat {
                        let inset = series.style.lineWidth / 2
                        return min(size.height - inset,
                            max(inset, size.height * graph.normalizedY(value)))
                    }
                    // 겹치는 0선에서도 점선 조각이 보이도록 실선을 먼저 그립니다.
                    for series: Series in [.sent, .received] {
                        for segment in segments {
                            guard !segment.isEmpty else { continue }
                            var path = Path()
                            for (index, point) in segment.enumerated() {
                                let position = CGPoint(x: size.width * graph.normalizedX(point.timestamp),
                                    y: yPosition(series.value(point), series: series))
                                if index == 0 { path.move(to: position) }
                                else { path.addLine(to: position) }
                            }
                            let color = kind.color(for: series)
                            if segment.count == 1, let point = segment.first {
                                let center = CGPoint(x: size.width * graph.normalizedX(point.timestamp),
                                    y: yPosition(series.value(point), series: series))
                                context.fill(Path(ellipseIn: CGRect(x: center.x - 1, y: center.y - 1,
                                    width: 2, height: 2)), with: .color(color))
                            } else {
                                context.stroke(path, with: .color(color), style: series.style)
                            }
                        }
                    }
                }
            }
            .modifier(DashboardGraphPlotSurface())
            ZStack {
                HStack(spacing: 0) {
                    Text("10분 전")
                    Spacer(minLength: 0)
                    Text("지금")
                }
                Text(graph.progressLabel)
                    .lineLimit(1)
            }
            .dashboardTypography(DashboardStyle.TypographyRole.label)
            .frame(height: HistoryGraphLayout.axisLabelHeight)
        }
        .frame(height: HistoryGraphLayout.slotHeight)
    }

    private func drawGridline(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height / 2))
        path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(path, with: .color(DashboardColorPalette.graphPlotGridline),
            lineWidth: HistoryGraphGridline.lineWidth)
    }
}

/// 두 현재값 이름 옆에서 재사용할 범례입니다. 판의 미수집 면에는 범례 선을 그리지 않습니다.
struct ResourceRateLegendView: View {
    let kind: ResourceRateGraphSlotView.Kind

    var body: some View {
        HStack(spacing: 8) {
            legend(.received, label: kind.labels.0)
            legend(.sent, label: kind.labels.1)
        }
        .dashboardTypography(DashboardStyle.TypographyRole.label)
    }

    private func legend(_ series: ResourceRateGraphSlotView.Series, label: String) -> some View {
        HStack(spacing: 3) {
            ResourceRateLegendMarkerView(kind: kind, series: series)
            Text(label)
        }
    }

}

/// 현재값 이름과 그래프 범례가 같은 선 모양을 공유합니다.
struct ResourceRateLegendMarkerView: View {
    let kind: ResourceRateGraphSlotView.Kind
    let series: ResourceRateGraphSlotView.Series

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.stroke(path, with: .color(kind.color(for: series)), style: series.style)
        }
        .frame(width: 14, height: 8)
        .accessibilityHidden(true)
    }
}

/// 현재값 이름 옆 범례와 축 범위를 판 밖 요약 줄에 배치할 때 재사용합니다.
struct ResourceRateGraphHeaderView: View {
    let kind: ResourceRateGraphSlotView.Kind
    let rangeLabel: String

    var body: some View {
        HStack(spacing: 4) {
            ResourceRateLegendView(kind: kind)
            Spacer(minLength: 0)
            Text(rangeLabel).lineLimit(1)
        }
        .dashboardTypography(DashboardStyle.TypographyRole.label)
    }
}
