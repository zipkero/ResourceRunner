//
//  DashboardView.swift
//  ResourceRunner
//
//  Created by zipkero on 8/2/26.
//

import SwiftUI

/// 대시보드 팝오버 셸. CPU·Memory 카드(task-008, task-009)와 카드 옆 상세 팝업(task-010)을 담습니다.
///
/// 본체는 제목과 두 카드만 가지며 상세를 위한 자리를 예약하지 않습니다.
/// 팝오버 프레임 크기는 `selection`과 무관한 상수(`frame(width:height:)`)이므로 카드를 선택하거나 해제해도
/// 본체 창 크기가 흔들리지 않습니다 — 상세는 그 카드에 앵커한 별도 자식 팝업으로 열려 본체 레이아웃에 참여하지
/// 않습니다(ANALYSIS §1 「표시 경계」, §5 DP14). 자식 팝오버를 카드에 붙여도 부모 팝오버가 닫히지 않고
/// 두 팝오버가 공존한다는 것과, 자식 콘텐츠가 접근성 계층에서 부모의 하위 노드로 도달된다는 것은 실행 환경에서
/// 확인된 사실입니다(ANALYSIS §근거 확인 사실).
struct DashboardView: View {
    @ObservedObject var store: DashboardPresentationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ResourceRunner")
                .font(.headline)

            // `Button`은 macOS에서 표준 포커스 가능 컨트롤이라 키보드 탐색(Full Keyboard Access)을 켠 환경에서는
            // Tab 이동과 Space·Return 활성화가 그대로 동작합니다. 다만 이 설정은 기본값이 꺼짐이고,
            // 꺼진 상태에서는 Tab이 텍스트 필드·목록만 순회해 버튼에 닿지 않는 것을 실행 중인 앱에서 확인했습니다.
            // 그래서 `keyboardShortcut(_:modifiers:)`로 키보드 탐색 설정과 무관하게 항상 동작하는 단축키를
            // 함께 둡니다(ANALYSIS §5 DP15) — 이 단축키가 기본 설정 환경에서 SPEC §5.13을 성립시키는 수단입니다.
            Button(action: { store.selectCard(.cpu) }) {
                CPUCardView(state: store.cpuCard)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("1", modifiers: .command)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(store.cpuCard.cpuAccessibilityLabel)
            .accessibilityAddTraits(.isButton)
            // XCUITest가 카드를 찾는 안정적인 식별자입니다. 접근성 이름 자체는 사용률에 따라 계속 바뀌므로
            // 텍스트가 아니라 이 식별자로 요소를 특정합니다.
            .accessibilityIdentifier("CPUCard")
            .popover(isPresented: cpuDetailIsPresented, arrowEdge: .trailing) {
                CPUDetailPopoverContent(state: store.cpuCard)
            }

            Button(action: { store.selectCard(.memory) }) {
                MemoryCardView(state: store.memoryCard)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("2", modifiers: .command)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(store.memoryCard.memoryAccessibilityLabel)
            .accessibilityAddTraits(.isButton)
            // CPU 카드와 같은 이유로 텍스트 대신 이 식별자를 씁니다.
            .accessibilityIdentifier("MemoryCard")
            .popover(isPresented: memoryDetailIsPresented, arrowEdge: .trailing) {
                MemoryDetailPopoverContent(state: store.memoryCard)
            }
        }
        .padding()
        .frame(width: 280, height: 460, alignment: .topLeading)
    }

    /// CPU 상세 팝업의 표시 여부. `get`은 `store.selection`을 그대로 반영하고,
    /// `set`은 팝업이 스스로 닫힐 때만(예: 팝업 밖 클릭) 호출되며 `store.dismissDetail(for:)`에 그 사실을 넘깁니다.
    /// 선택 해제 여부 자체는 그 진입점이 판단하므로(선택이 이미 다른 카드로 옮겨간 뒤라면 무시), 이 바인딩은
    /// 판단 없이 신호만 전달합니다.
    private var cpuDetailIsPresented: Binding<Bool> {
        Binding(
            get: { store.selection == .cpu },
            set: { isPresented in
                if !isPresented {
                    store.dismissDetail(for: .cpu)
                }
            }
        )
    }

    /// Memory 상세 팝업의 표시 여부. CPU 쪽과 같은 이유로 같은 형태의 바인딩을 씁니다.
    private var memoryDetailIsPresented: Binding<Bool> {
        Binding(
            get: { store.selection == .memory },
            set: { isPresented in
                if !isPresented {
                    store.dismissDetail(for: .memory)
                }
            }
        )
    }
}

/// CPU 카드 콘텐츠: 전체 사용률, User·System 비율, 최근 10분 그래프, 앱 단위 CPU TOP 5.
/// 접근성 이름·식별자·탭 활성화는 이 뷰를 감싸는 `Button`(`DashboardView`)이 담당합니다.
private struct CPUCardView: View {
    let state: ResourceCardState<CPUCardPresentation>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch state {
            case .collecting:
                Text("CPU")
                    .font(.subheadline.bold())
                Text("수집 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .normal(let presentation, _):
                Text("CPU \(Int(presentation.overallUsage.rounded()))\(CPUCardPresentation.overallUsageUnitLabel)")
                    .font(.subheadline.bold())
                Text("User \(Int(presentation.userRatio.rounded()))% · System \(Int(presentation.systemRatio.rounded()))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HistoryGraphView(points: presentation.graphPoints)
                    .frame(height: 60)

                if presentation.topApplicationsFailed {
                    Text("TOP 5 조사 실패")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    TopApplicationsView(
                        entries: presentation.topApplications,
                        caption: CPUCardPresentation.topApplicationsCaption,
                        valueText: { "\(Int($0.value.rounded()))%" }
                    )
                }

            case .failure(let lastKnown):
                Text("CPU")
                    .font(.subheadline.bold())
                if let lastKnown {
                    Text("수집 실패 · 마지막 \(Int(lastKnown.presentation.overallUsage.rounded()))\(CPUCardPresentation.overallUsageUnitLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HistoryGraphView(points: lastKnown.presentation.graphPoints)
                        .frame(height: 60)
                    TopApplicationsView(
                        entries: lastKnown.presentation.topApplications,
                        caption: CPUCardPresentation.topApplicationsCaption,
                        valueText: { "\(Int($0.value.rounded()))%" }
                    )
                } else {
                    Text("수집 실패")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .stopped(let lastKnown):
                Text("CPU")
                    .font(.subheadline.bold())
                if let lastKnown {
                    Text("수집 중지 · 마지막 \(Int(lastKnown.presentation.overallUsage.rounded()))\(CPUCardPresentation.overallUsageUnitLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HistoryGraphView(points: lastKnown.presentation.graphPoints)
                        .frame(height: 60)
                    TopApplicationsView(
                        entries: lastKnown.presentation.topApplications,
                        caption: CPUCardPresentation.topApplicationsCaption,
                        valueText: { "\(Int($0.value.rounded()))%" }
                    )
                } else {
                    Text("수집 중지")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // 선택·복귀 단축키는 수집 상태와 무관하게 카드에 항상 보이는 표시입니다(ANALYSIS §5 DP15) —
            // Hover에 숨기지 않고 접근성 이름(`cpuAccessibilityLabel`)에도 같은 문자열을 함께 둡니다.
            Text("\(CPUCardPresentation.selectionShortcutDisplayText) 선택·복귀")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }
}

/// Memory 카드: 전체 물리 메모리, 사용 중 메모리, Memory Pressure 단계, Swap 사용량과 최근 변화량,
/// 앱 단위 Memory TOP 5. Pressure 단계는 라벨과 기호를 함께 표시해 색상이 아닌 수단으로도 구분됩니다(SPEC §5.5).
private struct MemoryCardView: View {
    let state: ResourceCardState<MemoryCardPresentation>

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()

    private func format(_ bytes: UInt64) -> String {
        Self.byteCountFormatter.string(fromByteCount: Int64(bytes))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch state {
            case .collecting:
                Text("Memory")
                    .font(.subheadline.bold())
                Text("수집 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .normal(let presentation, _):
                Text("Memory \(format(presentation.usedBytes)) / \(format(presentation.totalPhysicalBytes))")
                    .font(.subheadline.bold())

                Label(presentation.pressureDisplay.label, systemImage: presentation.pressureDisplay.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let change = presentation.swapRecentChangeBytes {
                    Text("Swap \(format(presentation.swapUsedBytes)) (\(change >= 0 ? "+" : "")\(format(UInt64(abs(change)))))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Swap \(format(presentation.swapUsedBytes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if presentation.topApplicationsFailed {
                    Text("TOP 5 조사 실패")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    TopApplicationsView(
                        entries: presentation.topApplications,
                        caption: MemoryCardPresentation.topApplicationsCaption,
                        valueText: { format(UInt64($0.value.rounded())) }
                    )
                }

            case .failure(let lastKnown):
                Text("Memory")
                    .font(.subheadline.bold())
                if let lastKnown {
                    Text("수집 실패 · 마지막 \(format(lastKnown.presentation.usedBytes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TopApplicationsView(
                        entries: lastKnown.presentation.topApplications,
                        caption: MemoryCardPresentation.topApplicationsCaption,
                        valueText: { format(UInt64($0.value.rounded())) }
                    )
                } else {
                    Text("수집 실패")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .stopped(let lastKnown):
                Text("Memory")
                    .font(.subheadline.bold())
                if let lastKnown {
                    Text("수집 중지 · 마지막 \(format(lastKnown.presentation.usedBytes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TopApplicationsView(
                        entries: lastKnown.presentation.topApplications,
                        caption: MemoryCardPresentation.topApplicationsCaption,
                        valueText: { format(UInt64($0.value.rounded())) }
                    )
                } else {
                    Text("수집 중지")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // CPU 카드와 같은 이유로 단축키 표시를 수집 상태와 무관하게 항상 둡니다(ANALYSIS §5 DP15).
            Text("\(MemoryCardPresentation.selectionShortcutDisplayText) 선택·복귀")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }
}

/// 최근 10분 CPU 사용률 그래프. 인접 간격이 벌어진 점끼리는 잇지 않고 연속 구간별로 선을 그립니다.
///
/// 가로축 오른쪽 끝은 마지막 점의 시각이 아니라 **그리는 시점의 시각**입니다(ANALYSIS §5 DP3).
/// 갱신이 멈춘 동안(팝오버가 닫혀 있거나 화면을 볼 수 없어 카드가 갱신되지 않는 동안)에는 `points` 자체가
/// 낡아갈 수 있으므로, 점 배열이 바뀌지 않아도 이 뷰가 스스로 다시 그려 시계를 따라가야 합니다.
/// `TimelineView`가 매초 다시 그리도록 강제하고, 그 순간의 `ContinuousClock().now`를 창의 오른쪽 끝으로 씁니다.
/// 그래야 중지 뒤 재개 첫 tick처럼 카드 갱신 자체가 없는 순간에도 마지막 샘플이 오른쪽 끝에 들러붙지 않고
/// 실제 경과 시간만큼 왼쪽으로 밀려나 빈 구간이 제자리에 보입니다.
private struct HistoryGraphView: View {
    let points: [HistoryPoint]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            GeometryReader { proxy in
                let currentTimestamp = ContinuousClock().now
                Canvas { context, size in
                    for segment in HistoryPoint.connectedSegments(from: points) {
                        var path = Path()
                        for (index, point) in segment.enumerated() {
                            let position = CGPoint(
                                x: size.width * CGFloat(HistoryPoint.normalizedXPosition(for: point.timestamp, currentTimestamp: currentTimestamp)),
                                y: size.height * (1 - CGFloat(point.value / 100))
                            )
                            if index == 0 {
                                path.move(to: position)
                            } else {
                                path.addLine(to: position)
                            }
                        }
                        context.stroke(path, with: .color(.accentColor), lineWidth: 1.5)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

/// 앱 단위 TOP 5. CPU 카드와 Memory 카드가 함께 쓰며, 5개 미만이면 있는 만큼만 나열하고
/// 시스템 프로세스 제외 안내를 항상 함께 둡니다.
/// 값 단위가 카드마다 다르므로(CPU는 `%`, Memory는 바이트) 값 표시 문자열은 호출부가 `valueText`로 넘깁니다.
private struct TopApplicationsView: View {
    let entries: [ApplicationRankingEntry]
    let caption: String
    let valueText: (ApplicationRankingEntry) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entries, id: \.key) { entry in
                HStack {
                    Text(entry.displayName)
                    Spacer()
                    Text(valueText(entry))
                }
                .font(.caption)
            }

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// CPU 카드 옆에 앵커되는 상세 팝업 콘텐츠. 아직 정상 값이 없으면(수집 중·실패·중지) 안내 문구만 보여줍니다.
/// 팝업 고정 크기와 내부 스크롤은 task-016이 더하므로, 지금은 내용 그대로 팝업 크기가 정해집니다.
private struct CPUDetailPopoverContent: View {
    let state: ResourceCardState<CPUCardPresentation>

    var body: some View {
        Group {
            if case .normal(let presentation, _) = state {
                CPUDetailView(presentation: presentation)
            } else {
                Text("아직 CPU 값이 수집되지 않았습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 220, alignment: .leading)
        .accessibilityIdentifier("DashboardDetail")
    }
}

/// Memory 카드 옆에 앵커되는 상세 팝업 콘텐츠. CPU 쪽과 같은 이유로 같은 형태를 씁니다.
private struct MemoryDetailPopoverContent: View {
    let state: ResourceCardState<MemoryCardPresentation>

    var body: some View {
        Group {
            if case .normal(let presentation, _) = state {
                MemoryDetailView(presentation: presentation)
            } else {
                Text("아직 Memory 값이 수집되지 않았습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 220, alignment: .leading)
        .accessibilityIdentifier("DashboardDetail")
    }
}

/// CPU 상세: User·System·Idle, 논리 코어별 사용률, Load Average, 앱별 하위 프로세스(SPEC §5.2).
private struct CPUDetailView: View {
    let presentation: CPUCardPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("User \(pct(presentation.userRatio)) · System \(pct(presentation.systemRatio)) · Idle \(pct(presentation.detail.idleRatio))")
                .font(.caption)

            Text("코어별 사용률: " + presentation.detail.coreUsages.map(pct).joined(separator: ", "))
                .font(.caption2)
                .foregroundStyle(.secondary)

            let load = presentation.detail.loadAverage
            Text("Load Average \(fmt(load.oneMinute)) / \(fmt(load.fiveMinutes)) / \(fmt(load.fifteenMinutes))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ApplicationProcessGroupListView(groups: presentation.detail.applications) { process in
                // 프로세스 CPU는 논리 코어 합산 단위라 100%를 넘을 수 있고 그 값을 그대로 표시합니다(SPEC §5.2, SPEC §5.3).
                // 전체 사용률의 단위(`CPUCardPresentation.overallUsageUnitLabel`)와 다른 라벨을 써서 화면에서 구분합니다.
                let usageText = process.cpuUsagePercent.map { "\(Int($0.rounded()))\(ApplicationProcessDetail.cpuUsageUnitLabel)" } ?? "-"
                return process.isTranslated ? "\(usageText) · Rosetta" : usageText
            }
        }
    }

    private func pct(_ value: Double) -> String { "\(Int(value.rounded()))%" }
    private func fmt(_ value: Double) -> String { String(format: "%.2f", value) }
}

/// Memory 상세: App·Wired·Compressed·Cached, Swap 사용량과 증가량, 현재 사용량 순위와 최근 증가량 순위,
/// 앱별 하위 프로세스(SPEC §5.2, SPEC §5.8).
private struct MemoryDetailView: View {
    let presentation: MemoryCardPresentation

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()

    private func format(_ bytes: UInt64) -> String {
        Self.byteCountFormatter.string(fromByteCount: Int64(bytes))
    }

    var body: some View {
        let detail = presentation.detail
        VStack(alignment: .leading, spacing: 6) {
            Text("App \(format(detail.appBytes)) · Wired \(format(detail.wiredBytes)) · "
                + "Compressed \(format(detail.compressedBytes)) · Cached \(format(detail.cachedBytes))")
                .font(.caption)

            // Swap 사용량과 증가량은 `detail`이 아니라 카드 요약과 공유하는 `presentation` 최상위 필드입니다
            // (task-009가 만든 계산을 그대로 재사용). 변화량이 없으면(10분 창 안에 기준점이 없으면) `nil`이고,
            // 그 경우를 0으로 표시하지 않습니다. 변화량은 음수일 수 있으므로 증가량 순위와 같은 부호 보존
            // 포맷을 씁니다 — `format(UInt64(...))`에 음수를 직접 넣으면 trap합니다.
            if let change = presentation.swapRecentChangeBytes {
                Text("Swap \(format(presentation.swapUsedBytes)) (\(change >= 0 ? "+" : "")\(format(UInt64(abs(change)))))")
                    .font(.caption)
            } else {
                Text("Swap \(format(presentation.swapUsedBytes))")
                    .font(.caption)
            }

            Text("현재 사용량 순위").font(.caption.bold())
            TopApplicationsView(
                entries: detail.currentUsageRanking,
                caption: MemoryCardPresentation.topApplicationsCaption,
                valueText: { format(UInt64($0.value.rounded())) }
            )

            Text("최근 10분 증가량 순위").font(.caption.bold())
            // 증가량은 음수일 수 있으므로 `TopApplicationsView`가 기본 카드에 쓰는 `UInt64` 변환 경로를
            // 그대로 재사용하지 않고, 부호를 보존하는 별도 포맷을 씁니다(구현 보고 §비고·한계 참고).
            TopApplicationsView(
                entries: detail.recentIncreaseRanking,
                caption: MemoryCardPresentation.topApplicationsCaption,
                valueText: { entry in
                    let signedBytes = Int64(entry.value.rounded())
                    let magnitude = format(UInt64(abs(signedBytes)))
                    return signedBytes >= 0 ? "+\(magnitude)" : "-\(magnitude)"
                }
            )

            ApplicationProcessGroupListView(groups: detail.applications) { process in
                format(process.residentBytes)
            }
        }
    }
}

/// 앱별 하위 프로세스 목록. 앱 항목을 펼치면(`DisclosureGroup`) 그 앱으로 묶인 프로세스가 나타납니다
/// (ANALYSIS §2 「팝오버 열림과 카드 선택」). CPU·Memory 상세가 표시할 값만 `valueText`로 다르게 넘깁니다.
private struct ApplicationProcessGroupListView: View {
    let groups: [ApplicationProcessGroup]
    let valueText: (ApplicationProcessDetail) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(groups, id: \.key) { group in
                DisclosureGroup(group.displayName) {
                    ForEach(group.processes, id: \.pid) { process in
                        HStack {
                            Text("PID \(process.pid)")
                            Spacer()
                            Text(valueText(process))
                        }
                        .font(.caption2)
                    }
                }
                .font(.caption)
            }
        }
    }
}

#Preview {
    DashboardView(store: DashboardPresentationStore())
}
