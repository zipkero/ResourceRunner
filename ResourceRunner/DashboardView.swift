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
                // 상세 팝업이 고정 크기 `ScrollView`로 바뀌면서(task-016) 화면 밖 process 행까지 접근성
                // 계층에 함께 올라오게 되었고, 그중 앱 자신(ResourceRunner)의 행 라벨이 이 제목과 같은
                // 문자열이라 라벨만으로는 XCUITest가 둘을 구분하지 못합니다. 그래서 이 제목만의 식별자를 둡니다.
                .accessibilityIdentifier("DashboardTitle")

            // `Button`은 macOS에서 표준 포커스 가능 컨트롤이라 키보드 탐색(Full Keyboard Access)을 켠 환경에서는
            // Tab 이동과 Space·Return 활성화가 그대로 동작합니다. 다만 이 설정은 기본값이 꺼짐이고,
            // 꺼진 상태에서는 Tab이 텍스트 필드·목록만 순회해 버튼에 닿지 않는 것을 실행 중인 앱에서 확인했습니다.
            // 그래서 `keyboardShortcut(_:modifiers:)`로 키보드 탐색 설정과 무관하게 항상 동작하는 단축키를
            // 함께 둡니다(ANALYSIS §5 DP15) — 이 단축키가 기본 설정 환경에서 SPEC §5.13을 성립시키는 수단입니다.
            Button(action: { store.selectCard(.cpu) }) {
                CPUCardView(state: store.cpuCard)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(DashboardView.cpuSelectionKey, modifiers: .command)
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
            .keyboardShortcut(DashboardView.memorySelectionKey, modifiers: .command)
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
        .frame(width: 280, height: DashboardView.bodyHeight, alignment: .topLeading)
    }

    /// 본체 팝오버의 고정 높이. 두 카드가 상태와 무관하게 같은 슬롯 집합을 그리게 된 뒤(ANALYSIS §5 DP17)
    /// XCUITest로 팝오버를 열어 실측해 정한 값입니다 — `.frame(height:)` 제약 없이 연 팝오버의 자연 크기는
    /// 항상 최종 팝오버 프레임 514pt였고(앱 시작 직후 수집 중 상태와 첫 수집이 도착한 정상 상태 모두 동일),
    /// `NSPopover`가 SwiftUI 콘텐츠 크기에 자체 여백(26pt)을 더해 최종 프레임을 만들므로
    /// 이 상수에는 그 여백을 뺀 488을 넣어야 팝오버가 다시 514pt로 나옵니다.
    /// task-010이 어림한 460은 슬롯 고정 뒤 실제 필요한 높이보다 작아 하단 여백을 눌렀던 전례가 있어
    /// 다시 어림하지 않고 실측했습니다.
    fileprivate static let bodyHeight: CGFloat = 488

    /// CPU 카드 선택·복귀 단축키의 실제 키. `CPUCardPresentation.selectionShortcutKey`에서 유도되어
    /// 본체 등록 한 곳뿐인 단축키 정의와 카드 표시 문자열이 같은 값을 공유합니다(ANALYSIS §5 DP15).
    fileprivate static let cpuSelectionKey = KeyEquivalent(CPUCardPresentation.selectionShortcutKey)

    /// Memory 카드 선택·복귀 단축키의 실제 키. CPU 쪽과 같은 이유로 같은 형태로 유도합니다.
    fileprivate static let memorySelectionKey = KeyEquivalent(MemoryCardPresentation.selectionShortcutKey)

    /// 상세 팝업 콘텐츠의 공통 고정 크기(ANALYSIS §5 DP18). CPU 상세와 Memory 상세가 이 크기를 공유해
    /// 카드를 오가거나 프로세스 수·값이 바뀌어도 팝업 프레임이 흔들리지 않고, 넘치는 내용은 내부
    /// `ScrollView`에서만 스크롤됩니다.
    ///
    /// 임시 계측(task-016 구현 중 XCUITest로 측정 후 제거)으로 실행 환경의 실제 프로세스 조사 결과(381개 앱 그룹)를
    /// 반영한 자연 크기를 쟀더니 CPU 상세 (406, 8849), Memory 상세 (371, 9056)이 나왔습니다 — 두 상세 모두
    /// 실행 중인 모든 프로세스를 앱 단위로 나열하므로(`ApplicationProcessGroupListView`) 자연 높이가 화면보다
    /// 훨씬 크고, 어떤 고정 높이를 골라도 대부분의 환경에서 스크롤이 필요합니다. 화면 `visibleFrame` 높이가
    /// 1084pt(이 환경 실측)인 것에 견줘 충분히 작게 잡아 위·아래 여백 없이 화면 안에 들어가면서도, 요약 지표와
    /// 순위 앞부분 몇 줄은 스크롤 없이 보이도록 400×480을 씁니다. 폭은 두 상세의 실측 폭(406, 371) 안에 들어
    /// 코어별 사용률처럼 긴 한 줄만 접히고 그 밖의 줄은 접히지 않습니다.
    fileprivate static let detailPopupWidth: CGFloat = 400
    fileprivate static let detailPopupHeight: CGFloat = 480

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
///
/// 수집 중·정상·실패·중지 네 상태 모두 제목 줄 · 요약 줄 · 그래프 자리 · 순위 자리 · 단축키 줄이라는 같은 슬롯
/// 집합을 그립니다(task-015, ANALYSIS §1 「표시 경계」, §5 DP17). 상태 분기는 어느 슬롯을 그릴지가 아니라
/// `cached`(캐시된 값)가 있는지에 따라 슬롯 안의 내용에만 남습니다 — 슬롯을 더하거나 빼는 분기는 없습니다.
// `private`가 아니라 기본 접근 수준입니다 — task-015 테스트가 항목 수·조사 실패를 달리한 카드 뷰를 직접
// 렌더링해 높이를 비교해야 하므로(`@testable import`) 파일 밖(같은 모듈의 테스트 타깃)에서 접근할 수 있어야 합니다.
struct CPUCardView: View {
    let state: ResourceCardState<CPUCardPresentation>

    /// 이 카드가 보여줄 수 있는 값. `normal`은 이번 tick 값, `failure`·`stopped`는 마지막 성공 값을 담고,
    /// 성공 이력이 없는 `collecting`과 실패·중지는 `nil`입니다(`ResourceCardState.lastKnownValue`).
    /// 캐시된 값이 있는 슬롯에는 자리표시가 들어가지 않고 그 값이 그대로 보입니다(SPEC §5.9, §5 DP17).
    private var cached: CPUCardPresentation? {
        state.lastKnownValue?.presentation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CPU")
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 2) {
                Text(primaryLineText)
                    .font(.caption)
                Text(secondaryLineText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let presentation = cached {
                HistoryGraphView(points: presentation.graphPoints)
                    .frame(height: 60)
            } else {
                GraphPlaceholderView()
            }

            CardRankingSlotView(
                entries: cached?.topApplications ?? [],
                failed: cached?.topApplicationsFailed ?? false,
                caption: CPUCardPresentation.topApplicationsCaption,
                valueText: { "\(Int($0.value.rounded()))%" }
            )

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

    /// 요약 줄의 첫 번째 줄. 캐시된 값이 있으면 그 사용률을, 없으면 상태 문구를 보여줍니다(§5 DP17).
    private var primaryLineText: String {
        switch state {
        case .collecting:
            return "수집 중"
        case .normal(let presentation, _):
            return "\(Int(presentation.overallUsage.rounded()))\(CPUCardPresentation.overallUsageUnitLabel)"
        case .failure(let lastKnown):
            guard let lastKnown else { return "수집 실패" }
            return "수집 실패 · 마지막 \(Int(lastKnown.presentation.overallUsage.rounded()))\(CPUCardPresentation.overallUsageUnitLabel)"
        case .stopped(let lastKnown):
            guard let lastKnown else { return "수집 중지" }
            return "수집 중지 · 마지막 \(Int(lastKnown.presentation.overallUsage.rounded()))\(CPUCardPresentation.overallUsageUnitLabel)"
        }
    }

    /// 요약 줄의 두 번째 줄. 캐시된 값이 있을 때만 User·System 비율을 보여주고, 없으면 자리표시로 채웁니다 —
    /// 값을 지어내지 않으므로 구체적인 비율 대신 중립 기호를 씁니다(§5 DP17, SPEC §5.11).
    private var secondaryLineText: String {
        guard let presentation = cached else { return "–" }
        return "User \(Int(presentation.userRatio.rounded()))% · System \(Int(presentation.systemRatio.rounded()))%"
    }
}

/// Memory 카드: 전체 물리 메모리, 사용 중 메모리, Memory Pressure 단계, Swap 사용량과 최근 변화량,
/// 앱 단위 Memory TOP 5. Pressure 단계는 라벨과 기호를 함께 표시해 색상이 아닌 수단으로도 구분됩니다(SPEC §5.5).
///
/// CPU 카드와 같은 이유로 네 상태 모두 제목 줄 · Pressure 줄 · Swap 줄 · 순위 자리 · 단축키 줄을 항상 그리며,
/// 값이 있을 때만 그리던 Pressure 줄·Swap 줄도 고정 슬롯으로 바꿨습니다(task-015, §5 DP17).
// CPU 카드와 같은 이유로 기본 접근 수준입니다(task-015 테스트).
struct MemoryCardView: View {
    let state: ResourceCardState<MemoryCardPresentation>

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()

    private func format(_ bytes: UInt64) -> String {
        Self.byteCountFormatter.string(fromByteCount: Int64(bytes))
    }

    /// CPU 카드의 `cached`와 같은 뜻입니다 — 캐시된 값이 있는 슬롯에는 자리표시가 들어가지 않습니다.
    private var cached: MemoryCardPresentation? {
        state.lastKnownValue?.presentation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleLineText)
                .font(.subheadline.bold())

            pressureLine

            swapLine

            CardRankingSlotView(
                entries: cached?.topApplications ?? [],
                failed: cached?.topApplicationsFailed ?? false,
                caption: MemoryCardPresentation.topApplicationsCaption,
                valueText: { format(UInt64($0.value.rounded())) }
            )

            // CPU 카드와 같은 이유로 단축키 표시를 수집 상태와 무관하게 항상 둡니다(ANALYSIS §5 DP15).
            Text("\(MemoryCardPresentation.selectionShortcutDisplayText) 선택·복귀")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }

    /// 제목 줄. 캐시된 값이 있으면 사용 중/전체 메모리를, 없으면 상태 문구를 보여줍니다(§5 DP17).
    private var titleLineText: String {
        switch state {
        case .collecting:
            return "Memory 수집 중"
        case .normal(let presentation, _):
            return "Memory \(format(presentation.usedBytes)) / \(format(presentation.totalPhysicalBytes))"
        case .failure(let lastKnown):
            guard let lastKnown else { return "Memory 수집 실패" }
            return "Memory 수집 실패 · 마지막 \(format(lastKnown.presentation.usedBytes))"
        case .stopped(let lastKnown):
            guard let lastKnown else { return "Memory 수집 중지" }
            return "Memory 수집 중지 · 마지막 \(format(lastKnown.presentation.usedBytes))"
        }
    }

    /// Pressure 줄(고정 슬롯). 캐시된 값이 없으면 세 실제 단계 기호(원·삼각형·팔각형) 중 어느 것도 아닌
    /// `circle.dashed`로 자리표시를 채워 값을 지어내지 않습니다(§5 DP17, SPEC §5.11).
    @ViewBuilder
    private var pressureLine: some View {
        if let presentation = cached {
            Label(presentation.pressureDisplay.label, systemImage: presentation.pressureDisplay.symbolName)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Label("–", systemImage: "circle.dashed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Swap 줄(고정 슬롯). 캐시된 값이 없으면 자리표시로 채웁니다(§5 DP17).
    @ViewBuilder
    private var swapLine: some View {
        if let presentation = cached {
            if let change = presentation.swapRecentChangeBytes {
                Text("Swap \(format(presentation.swapUsedBytes)) (\(change >= 0 ? "+" : "")\(format(UInt64(abs(change)))))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Swap \(format(presentation.swapUsedBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Swap –")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
///
/// 이력 링 용량(10분 창, 1초 해상도라 점이 최대 601개)을 실제 렌더 폭(팝오버 280pt에서 카드 padding을 뺀 약 248pt)에
/// 그대로 찍으면 점 간격이 원본 표본 간격까지 좁아져 사용률 흐름이 뭉개집니다. 그리기 직전
/// `HistoryPoint.downsampledConnectedSegments(from:bucketCount:)`로 렌더 폭 기준 버킷 수만큼 다운샘플링해
/// 평균 점 간격이 `lineWidth`보다 확실히 커지게 합니다(결함 수정, SPEC §5.1).
private struct HistoryGraphView: View {
    let points: [HistoryPoint]

    /// `context.stroke`의 선 두께. 다운샘플링 버킷 최소 간격(`HistoryPoint.minimumDownsampledBucketSpacing`)의
    /// 절반(버킷당 평균 점 수 2개 기준 평균 간격)보다 확실히 작아야 인접 버킷의 선분이 두께에 묻혀 뭉개지지 않습니다.
    private static let lineWidth: CGFloat = 1.0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            GeometryReader { proxy in
                let currentTimestamp = ContinuousClock().now
                Canvas { context, size in
                    let bucketCount = HistoryPoint.downsampledBucketCount(forRenderWidth: size.width)
                    for segment in HistoryPoint.downsampledConnectedSegments(from: points, bucketCount: bucketCount) {
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
                        context.stroke(path, with: .color(.accentColor), lineWidth: Self.lineWidth)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

/// 그래프 자리의 자리표시(task-015). `HistoryGraphView`와 같은 높이만 차지하고 점이나 선은 그리지 않습니다 —
/// 값이 하나도 없는 슬롯에 값을 지어내지 않기 위해서입니다(ANALYSIS §5 DP17, SPEC §5.11).
private struct GraphPlaceholderView: View {
    var body: some View {
        Color.clear
            .frame(height: 60)
    }
}

/// 카드 순위 자리(task-015). 항목 수(0개·3개·5개)나 프로세스 조사 실패 여부와 무관하게
/// TOP 5 정원만큼의 줄과 안내 문구 한 줄을 항상 차지합니다(ANALYSIS §5 DP17).
/// 자리가 남으면 이름·수치를 만들어 넣지 않는 자리표시로 채우고, 조사 실패도 이 정원 안에서
/// 한 줄로 나타내며 나머지 줄은 자리표시로 남습니다(SPEC §5.11).
/// 상세 팝업(`TopApplicationsView`)과 달리 카드 쪽 순위는 이 정원이 고정되어야 하므로 별도 뷰로 둡니다 —
/// 상세 팝업의 크기 정책은 task-016 몫입니다.
private struct CardRankingSlotView: View {
    let entries: [ApplicationRankingEntry]
    let failed: Bool
    let caption: String
    let valueText: (ApplicationRankingEntry) -> String

    private static let capacity = ApplicationRankingSampling.topCount

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(0..<Self.capacity, id: \.self) { index in
                row(at: index)
                    .font(.caption)
            }

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func row(at index: Int) -> some View {
        if failed {
            if index == 0 {
                Text("TOP 5 조사 실패")
                    .foregroundStyle(.secondary)
            } else {
                placeholderRow
            }
        } else if index < entries.count {
            let entry = entries[index]
            HStack {
                Text(entry.displayName)
                Spacer()
                Text(valueText(entry))
            }
        } else {
            placeholderRow
        }
    }

    /// 값이 없는 줄의 자리표시. 다른 줄과 같은 높이만 차지하고 이름·수치를 만들어 넣지 않습니다.
    private var placeholderRow: some View {
        Text(" ")
            .opacity(0)
    }
}

/// 앱 단위 TOP 5. 상세 팝업(`CPUDetailView`·`MemoryDetailView`)이 쓰며, 5개 미만이면 있는 만큼만 나열하고
/// 시스템 프로세스 제외 안내를 항상 함께 둡니다. 카드 쪽 순위 자리는 높이가 고정되어야 하므로
/// 이 뷰 대신 `CardRankingSlotView`를 씁니다(task-015).
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
/// 팝업 프레임은 `DashboardView.detailPopupWidth`·`detailPopupHeight`로 고정하고, 그 안을 `ScrollView`로 감싸
/// 카드를 오가거나 프로세스 수·값이 달라져도 팝업 크기가 흔들리지 않게 합니다(ANALYSIS §5 DP18).
/// 카드 선택·복귀 단축키는 본체(`DashboardView`) 한 곳에만 등록합니다 — 자식 팝오버가 key window를 가져가지
/// 않는 것이 실행 환경에서 확인되어 본체 등록만으로 팝업이 열린 뒤에도 계속 닿습니다(ANALYSIS §5 DP15).
private struct CPUDetailPopoverContent: View {
    let state: ResourceCardState<CPUCardPresentation>

    var body: some View {
        ScrollView {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: DashboardView.detailPopupWidth, height: DashboardView.detailPopupHeight)
        .accessibilityIdentifier("DashboardDetail")
    }
}

/// Memory 카드 옆에 앵커되는 상세 팝업 콘텐츠. CPU 쪽과 같은 이유로 같은 형태를 씁니다.
private struct MemoryDetailPopoverContent: View {
    let state: ResourceCardState<MemoryCardPresentation>

    var body: some View {
        ScrollView {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: DashboardView.detailPopupWidth, height: DashboardView.detailPopupHeight)
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

            ApplicationProcessGroupListView(
                groups: presentation.detail.applications,
                sortDescription: "전체 프로세스 (CPU 사용량 합계 내림차순)",
                // 값 서식은 `ApplicationProcessValueFormatting`(단위 테스트가 nil 안전성을 직접 확인합니다)을 그대로 씁니다.
                groupValueText: ApplicationProcessValueFormatting.cpuGroupValueText,
                valueText: ApplicationProcessValueFormatting.cpuProcessValueText
            )
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
            // 그대로 재사용하지 않고, 부호를 보존하는 별도 포맷을 씁니다.
            TopApplicationsView(
                entries: detail.recentIncreaseRanking,
                caption: MemoryCardPresentation.topApplicationsCaption,
                valueText: { entry in
                    let signedBytes = Int64(entry.value.rounded())
                    let magnitude = format(UInt64(abs(signedBytes)))
                    return signedBytes >= 0 ? "+\(magnitude)" : "-\(magnitude)"
                }
            )

            ApplicationProcessGroupListView(
                groups: detail.applications,
                sortDescription: "전체 프로세스 (Memory 사용량 합계 내림차순)",
                // Memory는 항상 값이 있지만(SPEC §5.6과 달리 기준점이 필요 없음), nil 안전 경로는
                // `ApplicationProcessValueFormatting`(단위 테스트 대상)을 CPU와 공유합니다.
                groupValueText: { value in ApplicationProcessValueFormatting.memoryGroupValueText(value, format: format) }
            ) { process in
                format(process.residentBytes)
            }
        }
    }
}

/// 앱별 하위 프로세스 목록. 앱 항목을 펼치면(`DisclosureGroup`) 그 앱으로 묶인 프로세스가 나타납니다
/// (ANALYSIS §2 「팝오버 열림과 카드 선택」, SPEC §5.2, SPEC §5.6). CPU·Memory 상세가 표시할 값만
/// `groupValueText`·`valueText`로 다르게 넘깁니다.
///
/// 앱 행의 값은 `group.sortValue` — `ApplicationRanking.sortedForDisplay(groups:by:)`가 정렬에 쓴 바로 그 합계값을
/// 그대로 표시합니다. 이 목록을 표시용으로 다시 계산하면 정렬 기준과 화면에 보이는 값이 어긋날 수 있습니다.
///
/// 왼쪽에 여백을 둬 `DisclosureGroup`의 삼각형이 `ScrollView` 클립 경계 바로 위로 렌더링되지 않게 합니다 —
/// 그 경계 바깥을 클릭하면 macOS가 팝오버 밖 클릭으로 처리해 부모·자식 팝오버가 통째로 닫히는 것이
/// 실행 환경에서 확인되었습니다(상세 팝업 결함 조사).
///
/// 펼침 상태는 각 행이 아니라 이 목록이 `expandedKeys`로 모아서 들고 있습니다 — 펼친 행이 하나라도 있으면
/// 순서를 그 순간에 고정하고(SPEC §5.6 "순위가 매 갱신마다 요동치지 않습니다"), 모두 접히면 다시 매 tick
/// 정렬을 따라갑니다. 목록이 매초 다시 정렬되는 동안 펼친 행이 화면에서 자리를 옮기면, 그 행을 다시 클릭하려는
/// 시도가 이동 전 좌표를 써서 엉뚱한 행을 클릭하는 결함이 있었습니다(상세 팝업 결함 조사 — 접힘 클릭이 8회 중
/// 1회꼴로 실패했고, 클릭 직전·직후 프레임 비교로 행이 한 칸 이동했음을 확인).
/// 값 자체는 고정하지 않습니다 — 순서만 멈추고 표시 값은 계속 최신 `groups`를 따라갑니다.
private struct ApplicationProcessGroupListView: View {
    let groups: [ApplicationProcessGroup]
    /// 목록이 어떤 값으로, 어떤 방향으로 정렬됐는지 알리는 머리글.
    let sortDescription: String
    /// 앱 행에 표시할 그룹 합계 값의 서식. `nil`(값을 만들지 못한 그룹)을 0으로 지어내지 않습니다(SPEC §5.6).
    let groupValueText: (Double?) -> String
    let valueText: (ApplicationProcessDetail) -> String

    @State private var expandedKeys: Set<ApplicationKey> = []
    @State private var stableOrder: [ApplicationKey] = []

    /// 순서 고정 규칙은 `ApplicationProcessGroupOrdering`(단위 테스트 대상)을 그대로 씁니다.
    private var displayedGroups: [ApplicationProcessGroup] {
        ApplicationProcessGroupOrdering.displayedGroups(
            groups: groups,
            stableOrder: stableOrder,
            hasExpandedRow: !expandedKeys.isEmpty
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(sortDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(displayedGroups, id: \.key) { group in
                ApplicationProcessGroupRow(
                    group: group,
                    groupValueText: groupValueText,
                    valueText: valueText,
                    isExpanded: Binding(
                        get: { expandedKeys.contains(group.key) },
                        set: { isExpanded in
                            if isExpanded {
                                expandedKeys.insert(group.key)
                            } else {
                                expandedKeys.remove(group.key)
                            }
                        }
                    )
                )
            }
        }
        .padding(.leading, 8)
        .onAppear { stableOrder = groups.map(\.key) }
        // 펼친 행이 없을 때만 최신 순서를 따라잡습니다 — 펼친 행이 있는 동안 들어오는 새 정렬 결과는
        // `stableOrder`에 반영하지 않고 미뤄 둡니다.
        .onChange(of: groups.map(\.key)) { _, newOrder in
            if expandedKeys.isEmpty {
                stableOrder = newOrder
            }
        }
    }
}

/// 앱 하나에 대응하는 행. 펼침 상태는 부모(`ApplicationProcessGroupListView`)가 앱 키로 모아서 들고 있습니다 —
/// `ForEach`의 `id`가 앱 키라 안정적이므로 목록이 매초 재조립되어도 같은 앱을 가리키는 행이 그대로 유지됩니다.
private struct ApplicationProcessGroupRow: View {
    let group: ApplicationProcessGroup
    let groupValueText: (Double?) -> String
    let valueText: (ApplicationProcessDetail) -> String
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(group.processes, id: \.pid) { process in
                HStack {
                    Text("\(process.executableName) (PID \(process.pid))")
                    Spacer()
                    Text(valueText(process))
                }
                .font(.caption2)
            }
        } label: {
            HStack {
                Text(group.displayName)
                Spacer()
                Text(groupValueText(group.sortValue))
            }
            // 라벨 전체를 탭 대상으로 만들어, 기본 동작(삼각형만 반응)과 달리 라벨 텍스트·값·빈 공간을
            // 눌러도 펼침·접힘이 토글되게 합니다. 삼각형 자체의 기본 탭 동작은 그대로 남아 있어 둘 다 동작합니다.
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
        }
        .font(.caption)
        // 목록이 매 tick 다시 정렬되므로, 화면 위치가 아니라 앱 키로 특정 행을 계속 가리킬 수 있도록
        // 안정적인 식별자를 붙입니다(XCUITest가 재정렬 사이에도 같은 행을 추적하는 데 씁니다).
        .accessibilityIdentifier("AppRow-\(group.key.value)")
    }
}

#Preview {
    DashboardView(store: DashboardPresentationStore())
}
