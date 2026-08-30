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
    /// 순위·목록 행이 앱 아이콘을 묻는 자리. 소유자는 `ApplicationCoordinator` 한 곳이고
    /// 뷰 계층은 생성자로 전달받기만 합니다 — 캐시 수명이 뷰 수명에 묶이면 팝오버를 열 때마다
    /// 같은 앱의 아이콘을 다시 얻게 됩니다(ANALYSIS §1 「아이콘 경계」, §5 DP11).
    let iconProvider: any ApplicationIconProviding

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
                CPUCardView(state: store.cpuCard, iconProvider: iconProvider)
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
                CPUDetailPopoverContent(state: store.cpuCard, iconProvider: iconProvider)
            }

            Button(action: { store.selectCard(.memory) }) {
                MemoryCardView(state: store.memoryCard, iconProvider: iconProvider)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(DashboardView.memorySelectionKey, modifiers: .command)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(store.memoryCard.memoryAccessibilityLabel)
            .accessibilityAddTraits(.isButton)
            // CPU 카드와 같은 이유로 텍스트 대신 이 식별자를 씁니다.
            .accessibilityIdentifier("MemoryCard")
            .popover(isPresented: memoryDetailIsPresented, arrowEdge: .trailing) {
                MemoryDetailPopoverContent(state: store.memoryCard, iconProvider: iconProvider)
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
    /// 순위 행이 아이콘을 묻는 자리. 이 뷰는 전달만 하고 캐시를 만들지 않습니다(ANALYSIS §5 DP11).
    let iconProvider: any ApplicationIconProviding

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
                secondaryLine
            }

            if let presentation = cached {
                HistoryGraphView(points: presentation.graphPoints)
                    .frame(height: 60)
            } else {
                GraphPlaceholderView()
            }

            rankingSlot

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

    /// 카드 순위 자리. 값이 없으면 빈 항목 목록을 넘겨 정원만큼의 자리표시 줄이 남습니다.
    // `private`가 아닌 것은 task-011 테스트가 이 카드가 실제로 넘기는 항목·정원 그대로 줄별 아이콘 자리를
    // 재기 때문입니다 — 테스트가 슬롯을 따로 조립하면 카드가 다른 인자를 넘기는 변경을 놓칩니다.
    var rankingSlot: CardRankingSlotView {
        CardRankingSlotView(
            entries: cached?.topApplications ?? [],
            failed: cached?.topApplicationsFailed ?? false,
            caption: CPUCardPresentation.topApplicationsCaption,
            valueText: { "\(Int($0.value.rounded()))%" },
            iconProvider: iconProvider
        )
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

    /// 요약 줄의 두 번째 줄. 캐시된 값이 있을 때만 User·System 비율을 그래프 밴드와 같은 모양의 스와치와 함께
    /// 보여주고, 없으면 자리표시로 채웁니다 — 값을 지어내지 않으므로 구체적인 비율 대신 중립 기호를 씁니다
    /// (§5 DP17, SPEC §5.11). 스와치는 색이 아니라 밴드의 채움 밀도·경계선 모양을 그대로 옮겨,
    /// 색을 지운 화면에서도 어느 스와치가 어느 계열인지 그래프와 같은 방식으로 구분됩니다(SPEC §5.5, ANALYSIS §5 DP9).
    // `private`가 아닌 것은 task-011 테스트가 값 없음 줄의 이상적 폭을 재기 때문입니다 — 이 줄의 스와치·이름·
    // 중립 기호·구분자는 무채색이거나 좁아 카드 렌더 높이·픽셀로는 사라져도 드러나지 않습니다.
    @ViewBuilder
    var secondaryLine: some View {
        Group {
            if let presentation = cached {
                HStack(spacing: CPUSeriesPlaceholderLayout.spacing) {
                    CPUSeriesSwatchView(band: .lower)
                    Text("User \(Int(presentation.userRatio.rounded()))%")
                    Text("·")
                    CPUSeriesSwatchView(band: .upper)
                    Text("System \(Int(presentation.systemRatio.rounded()))%")
                }
            } else {
                HStack(spacing: CPUSeriesPlaceholderLayout.spacing) {
                    ForEach(Array(CPUSeriesPlaceholderLayout.entries.enumerated()), id: \.offset) { index, entry in
                        if index > 0 {
                            Text("·")
                        }
                        CPUSeriesSwatchView(band: entry.band)
                        Text("\(entry.label) \(entry.valueText)")
                    }
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// CPU 계열 값이 없을 때도 요약 줄에 남는 범례 항목입니다.
///
/// 이 배열이 고정하는 것은 항목의 순서·개수와 각 항목의 이름·중립 기호 문자열뿐입니다.
/// 뷰가 어느 항목의 스와치나 텍스트를 실제로 그리는지는 고정하지 못합니다 —
/// 배열을 그대로 두고 순회 안에서 조각을 빼면 이 값에 대한 단언은 그대로 통과합니다.
/// 그 자리는 `DashboardCardPlaceholderRenderingTests`가 값 없음 요약 줄의 이상적 폭을
/// 조각별 기준 조립과 견주어 지킵니다.
@MainActor
enum CPUSeriesPlaceholderLayout {
    struct Entry: Equatable {
        let band: HistoryGraphView.BandRole
        let label: String
        let valueText: String
    }

    /// 요약 줄 조각 사이 간격. 값이 있는 줄과 값 없음 줄이 같은 간격을 써야 상태 전이에서 줄 폭이 흔들리지 않습니다.
    static let spacing: CGFloat = 4

    static let entries: [Entry] = [
        Entry(band: .lower, label: "User", valueText: "–"),
        Entry(band: .upper, label: "System", valueText: "–")
    ]
}

/// CPU 요약 줄의 계열 스와치. 그래프 밴드와 같은 채움 밀도·경계선 모양을 옮겨 색을 지운 화면에서도
/// User·System을 구분할 수 있게 합니다(SPEC §5.5, ANALYSIS §5 DP9).
/// 크기는 그 줄의 텍스트 높이를 넘지 않도록 `.caption` 줄 높이보다 작은 고정 값으로 둡니다.
// `private`가 아닌 것은 task-011 테스트가 값 없음 요약 줄의 기준 폭을 조립할 때 이 뷰를 그대로 쓰기 때문입니다 —
// 테스트가 같은 크기의 대역 뷰를 따로 만들면 스와치 크기 변경이 기준 폭에 반영되지 않습니다.
struct CPUSeriesSwatchView: View {
    let band: HistoryGraphView.BandRole

    private static let size: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color.opacity(HistoryGraphView.fillOpacity(for: band)))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(color, style: HistoryGraphView.boundaryStyle(for: band))
            )
            .frame(width: Self.size, height: Self.size)
    }

    private var color: Color {
        switch band {
        case .lower: return DashboardColorPalette.cpuUser
        case .upper: return DashboardColorPalette.cpuSystem
        }
    }
}

/// Memory 카드: 전체 물리 메모리, 사용 중 메모리, Memory Pressure 단계, Swap 사용량과 최근 변화량,
/// 앱 단위 Memory TOP 5. Pressure 단계는 기호와 라벨을 함께 표시해 색상이 아닌 수단으로도 구분됩니다(SPEC §5.5).
///
/// CPU 카드와 같은 이유로 네 상태 모두 제목 줄(구성 누적 바 포함) · Pressure·Swap 병합 줄 · 구성 범례 줄 ·
/// 순위 자리 · 단축키 줄을 항상 그립니다.
/// Pressure 줄과 Swap 줄은 한 줄로 합쳐 비운 자리를 구성 범례 줄이 씁니다 — 슬롯 수와 카드 높이는 그대로입니다(ANALYSIS §5 DP4).
/// 값이 있을 때만 그리던 Pressure 줄·Swap 줄도 고정 슬롯으로 바꿨습니다(task-015, §5 DP17).
// CPU 카드와 같은 이유로 기본 접근 수준입니다(task-015 테스트).
struct MemoryCardView: View {
    let state: ResourceCardState<MemoryCardPresentation>
    /// CPU 카드와 같은 이유로 전달만 받습니다.
    let iconProvider: any ApplicationIconProviding

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
            titleLine

            pressureSwapLine

            compositionLegendLine

            rankingSlot

            // CPU 카드와 같은 이유로 단축키 표시를 수집 상태와 무관하게 항상 둡니다(ANALYSIS §5 DP15).
            Text("\(MemoryCardPresentation.selectionShortcutDisplayText) 선택·복귀")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }

    /// 카드 순위 자리. CPU 카드의 같은 속성과 같은 이유로 기본 접근 수준입니다.
    var rankingSlot: CardRankingSlotView {
        CardRankingSlotView(
            entries: cached?.topApplications ?? [],
            failed: cached?.topApplicationsFailed ?? false,
            caption: MemoryCardPresentation.topApplicationsCaption,
            valueText: { format(UInt64($0.value.rounded())) },
            iconProvider: iconProvider
        )
    }

    /// 제목 줄. 「사용 중 / 전체」 수치가 왼쪽에 남고, 그 줄의 남는 폭을 구성 누적 바가 씁니다(SPEC §5.3).
    /// 바 높이는 제목 텍스트 높이 이하이고 제목은 한 줄로 묶여 있어, 이 바 때문에 카드가 커지지 않습니다(SPEC §5.8).
    private var titleLine: some View {
        HStack(spacing: 6) {
            Text(titleLineText)
                .font(.subheadline.bold())
                .lineLimit(MemoryCompositionLegendFormatting.maximumLineCount)
                .layoutPriority(1)

            MemoryCompositionBarView(segments: cached?.compositionLayout.segments ?? MemoryCompositionBarLayout.placeholderSegments)
        }
    }

    /// 제목 줄에 보이는 문자열. 캐시된 값이 있으면 사용 중/전체 메모리를, 없으면 상태 문구를 보여줍니다(§5 DP17).
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

    /// Pressure·Swap·구성 합계 줄(고정 슬롯). `MemoryPressureSwapLineFormatting.assemble`이 고정한 순서를
    /// 그대로 이어붙여 그리고 `MemoryPressureSwapLineFormatting.maximumLineCount`로 묶어
    /// 폭이 부족할 때 줄바꿈 대신 끝에서 잘리게 합니다 — 뷰는 순서도 줄 수 상한도 정하지 않고 조립 결과를 그리기만 합니다(ANALYSIS §5 DP4).
    /// 줄 끝의 구성 합계는 제목 줄의 「사용 중」과 다른 지표라 「구성」 라벨을 달아 그립니다(SPEC §5.3).
    // `private`가 아닌 것은 task-011 테스트가 값 없음 자리표시(`…placeholder`)의 조각이 이 줄에 실제로 남는지
    // 이 줄의 이상적 폭으로 재기 때문입니다 — 조립 배열만 단언하면 뷰가 조각을 건너뛰어도 통과합니다.
    var pressureSwapLine: some View {
        let segments = cached.map {
            MemoryPressureSwapLineFormatting.assemble(
                pressureDisplay: $0.pressureDisplay,
                swapUsedBytes: $0.swapUsedBytes,
                swapRecentChangeBytes: $0.swapRecentChangeBytes,
                compositionTotalBytes: $0.compositionTotalBytes,
                format: format
            )
        } ?? MemoryPressureSwapLineFormatting.placeholder

        return segments.reduce(Text("")) { line, segment in
            switch segment {
            case .symbol(let name):
                return line + Text(Image(systemName: name))
            case .label(let text):
                return line + Text(" \(text)")
            case .separator:
                return line + Text(" · ")
            case .swapUsage(let text):
                return line + Text("Swap \(text)")
            case .swapChange(let text):
                return line + Text(" (\(text))")
            case .compositionTotal(let text):
                return line + Text("구성 \(text)")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(MemoryPressureSwapLineFormatting.maximumLineCount)
    }

    /// 구성 범례 줄(고정 슬롯). task-006의 병합이 비워 둔 자리를 씁니다.
    /// `MemoryCompositionLegendFormatting.segments`가 고정한 순서 — 바 구간과 같은 App → Wired → Compressed → Cached —
    /// 를 그대로 이어붙여 그리므로 뷰는 순서도 문구도 고르지 않습니다(ANALYSIS §5 DP15).
    /// 각 색 스와치 바로 뒤에 이름이 붙어, 색을 지운 화면에서도 어느 구간인지 읽힙니다(SPEC §5.3).
    ///
    /// 수집 상태와 무관하게 같은 네 이름을 그립니다 — 범례에 수치가 없어 값 없음을 나타낼 것이 없고,
    /// 그래서 이 줄은 어느 상태에서도 같은 자리를 같은 크기로 차지합니다(SPEC §5.8, ANALYSIS §5 DP14).
    // `private`가 아닌 것은 task-011 테스트가 네 스와치와 네 이름이 상태마다 이 줄에 실제로 남는지
    // 이 줄의 이상적 폭으로 재기 때문입니다 — `segments` 배열만 단언하면 뷰가 조각을 건너뛰어도 통과합니다.
    var compositionLegendLine: some View {
        MemoryCompositionLegendFormatting.segments.reduce(Text("")) { line, segment in
            switch segment {
            case .swatch(let category):
                return line + Text(Image(systemName: "square.fill"))
                    .foregroundStyle(DashboardColorPalette.memoryComposition(category))
            case .label(let text):
                return line + Text(" \(text)")
            case .separator:
                return line + Text("  ")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(MemoryCompositionLegendFormatting.maximumLineCount)
    }
}

/// Memory 구성 누적 바. 제목 줄의 남는 폭을 채우고, 트랙 전체가 전체 물리 메모리이며
/// 각 구간 길이는 실제 바이트에 비례합니다(SPEC §5.3). 구간 순서·비율·누적 시작 위치는
/// `MemoryCompositionLayout`이 정하고, 이 뷰는 그 결과를 좌표로 옮겨 칠하는 일만 합니다(ANALYSIS §5 DP15).
///
/// 값이 없으면 구간 배열이 비어 트랙만 남습니다 — 없는 값을 길이 0 구간으로도 그리지 않습니다(ANALYSIS §5 DP14).
/// 트랙의 남는 부분에는 이름을 붙이지 않습니다. 여유 메모리와 같은 값이 아니기 때문입니다(ANALYSIS §5 DP5).
// `private`가 아닌 것은 task-011 테스트가 값 없음 트랙을 이 뷰만 따로 그려 같은 크기의 투명한 자리와
// 픽셀로 견주기 때문입니다 — 카드 전체 렌더로는 트랙이 제목 줄 안에 묻혀 그리기 여부가 드러나지 않습니다.
struct MemoryCompositionBarView: View {
    let segments: [MemoryCompositionSegment]

    /// 바 높이. 제목 줄 글꼴(`.subheadline`)의 텍스트 높이보다 작아야 카드 높이가 이 바 때문에 늘지 않습니다.
    private static let height: CGFloat = 8
    private static let cornerRadius: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            for layer in MemoryCompositionBarLayout.layers(for: segments) {
                switch layer {
                case .track:
                    let track = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: Self.cornerRadius)
                    context.fill(track, with: .color(DashboardColorPalette.memoryCompositionTrack))
                    context.clip(to: track)
                case .segments:
                    for segment in segments {
                        let width = size.width * CGFloat(segment.ratio)
                        guard width > 0 else { continue }
                        let rect = CGRect(x: size.width * CGFloat(segment.startRatio), y: 0, width: width, height: size.height)
                        context.fill(Path(rect), with: .color(DashboardColorPalette.memoryComposition(segment.category)))
                    }
                }
            }
        }
        .frame(height: Self.height)
    }
}

/// Memory 구성 바가 값 유무에 따라 그리는 레이어입니다.
/// 값 없음은 트랙만 남기고 구간 배열 자체를 비워, 길이 0 구간이나 지어낸 비율이 값처럼 들어올 수 없게 합니다.
nonisolated enum MemoryCompositionBarLayout {
    enum Layer: Equatable {
        case track
        case segments
    }

    static let placeholderSegments: [MemoryCompositionSegment] = []

    static func layers(for segments: [MemoryCompositionSegment]) -> [Layer] {
        segments.isEmpty ? [.track] : [.track, .segments]
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
// CPU 카드와 같은 이유로 기본 접근 수준입니다 — task-005 테스트가 `drawOrder`·`fillOpacity`·`boundaryStyle`을
// `@testable import`로 직접 단언해야 격자·밴드 그리기 순서와 불투명도의 회귀를 단위 테스트로 잡을 수 있습니다.
struct HistoryGraphView: View {
    let points: [HistoryPoint]

    /// 두 밴드 중 어느 쪽인지. 아래(User)와 위(System)가 색이 아니라 채움 밀도·경계선 모양으로도
    /// 구분되도록 이 값에서 스타일을 유도합니다(SPEC §5.5, ANALYSIS §5 DP9).
    /// 요약 줄 스와치(`CPUSeriesSwatchView`)가 같은 유도 함수를 써서 그래프와 스와치의 모양이 어긋나지 않습니다.
    enum BandRole {
        case lower
        case upper
    }

    /// `Canvas`가 그리는 것과 순서. 격자가 항상 맨 먼저(가장 뒤)이고, 그 뒤로 두 밴드 채움, 마지막에 두 밴드
    /// 경계선이 옵니다(SPEC §5.6, ANALYSIS §5 DP10) — 밴드 채움이 격자보다 먼저 오면 부하가 높은 구간에서
    /// 밴드가 격자를 덮어 SPEC §5.6이 그 구간에서 성립하지 않습니다.
    /// `body`가 이 배열을 그대로 순회해 그리므로, 이 배열 자체가 실제 그리기 순서입니다 —
    /// 순서를 검증하는 단위 테스트는 `Canvas` 내부가 아니라 이 배열을 단언합니다.
    enum DrawLayer: Equatable {
        case gridlines
        case bandFill(BandRole)
        case bandBoundary(BandRole)
    }

    static let drawOrder: [DrawLayer] = [
        .gridlines,
        .bandFill(.lower),
        .bandFill(.upper),
        .bandBoundary(.lower),
        .bandBoundary(.upper)
    ]

    /// `context.stroke`의 선 두께. 다운샘플링 버킷 최소 간격(`HistoryPoint.minimumDownsampledBucketSpacing`)의
    /// 절반(버킷당 평균 점 수 2개 기준 평균 간격)보다 확실히 작아야 인접 버킷의 선분이 두께에 묻혀 뭉개지지 않습니다.
    private static let lineWidth: CGFloat = 1.0

    /// 아래 밴드(User) 경계선의 점선 패턴. 위 밴드(System) 경계선(전체 사용률 선)과 모양이 달라야
    /// 색을 지운 화면에서도 두 경계가 구분됩니다.
    private static let lowerBandDashPattern: [CGFloat] = [3, 2]

    static func boundaryStyle(for band: BandRole) -> StrokeStyle {
        switch band {
        case .lower: return StrokeStyle(lineWidth: lineWidth, dash: lowerBandDashPattern)
        case .upper: return StrokeStyle(lineWidth: lineWidth)
        }
    }

    /// 밴드 채움 불투명도. 두 밴드가 서로 다른 밀도로 채워지고, 격자(task-005)가 부하가 높은 구간에서도
    /// 비치도록 둘 다 반투명입니다(ANALYSIS §5 DP9, DP10).
    static func fillOpacity(for band: BandRole) -> Double {
        switch band {
        case .lower: return 0.5
        case .upper: return 0.28
        }
    }

    private static func color(for band: BandRole) -> Color {
        switch band {
        case .lower: return DashboardColorPalette.cpuUser
        case .upper: return DashboardColorPalette.cpuSystem
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            GeometryReader { proxy in
                let currentTimestamp = ContinuousClock().now
                Canvas { context, size in
                    func xPosition(_ point: HistoryPoint) -> CGFloat {
                        size.width * CGFloat(HistoryPoint.normalizedXPosition(for: point.timestamp, currentTimestamp: currentTimestamp))
                    }
                    func yPosition(_ value: Double) -> CGFloat {
                        CGFloat(HistoryGraphGridline.yPosition(forValue: value, height: Double(size.height)))
                    }

                    let segments = HistoryPoint.downsampledConnectedSegments(from: points, bucketCount: HistoryPoint.downsampledBucketCount(forRenderWidth: size.width))

                    func lowerFillPath(for segment: [HistoryPoint]) -> Path? {
                        guard let first = segment.first, let last = segment.last else { return nil }
                        // 아래 밴드(User) 채움: 0~User.
                        var path = Path()
                        path.move(to: CGPoint(x: xPosition(first), y: yPosition(0)))
                        for point in segment {
                            path.addLine(to: CGPoint(x: xPosition(point), y: yPosition(point.lowerBandValue)))
                        }
                        path.addLine(to: CGPoint(x: xPosition(last), y: yPosition(0)))
                        path.closeSubpath()
                        return path
                    }

                    func upperFillPath(for segment: [HistoryPoint]) -> Path? {
                        guard let first = segment.first else { return nil }
                        // 위 밴드(System) 채움: User~전체.
                        var path = Path()
                        path.move(to: CGPoint(x: xPosition(first), y: yPosition(first.lowerBandValue)))
                        for point in segment {
                            path.addLine(to: CGPoint(x: xPosition(point), y: yPosition(point.lowerBandValue + point.upperBandValue)))
                        }
                        for point in segment.reversed() {
                            path.addLine(to: CGPoint(x: xPosition(point), y: yPosition(point.lowerBandValue)))
                        }
                        path.closeSubpath()
                        return path
                    }

                    // 두 밴드 경계선. 아래 경계(User)는 점선, 위 경계(전체 사용률)는 실선으로 그려
                    // 색을 지운 화면에서도 어느 쪽 경계인지 구분됩니다.
                    func boundaryPath(for segment: [HistoryPoint], band: BandRole) -> Path? {
                        guard !segment.isEmpty else { return nil }
                        var path = Path()
                        for (index, point) in segment.enumerated() {
                            let value = band == .lower ? point.lowerBandValue : point.lowerBandValue + point.upperBandValue
                            let position = CGPoint(x: xPosition(point), y: yPosition(value))
                            if index == 0 {
                                path.move(to: position)
                            } else {
                                path.addLine(to: position)
                            }
                        }
                        return path
                    }

                    for layer in Self.drawOrder {
                        switch layer {
                        case .gridlines:
                            drawCPUGraphGridlines(in: &context, size: size)
                        case .bandFill(let band):
                            for segment in segments {
                                let path = band == .lower ? lowerFillPath(for: segment) : upperFillPath(for: segment)
                                guard let path else { continue }
                                context.fill(path, with: .color(Self.color(for: band).opacity(Self.fillOpacity(for: band))))
                            }
                        case .bandBoundary(let band):
                            for segment in segments {
                                guard let path = boundaryPath(for: segment, band: band) else { continue }
                                context.stroke(path, with: .color(Self.color(for: band)), style: Self.boundaryStyle(for: band))
                            }
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

/// `HistoryGraphView`와 값 없음 자리표시(`GraphPlaceholderView`)가 같은 격자를 그리도록 공유하는 그리기 함수입니다
/// (SPEC §5.8, ANALYSIS §5 DP14). 기준선 값과 좌표 변환은 `HistoryGraphGridline`(뷰 밖 순수 함수)에서 가져오고,
/// 여기서는 그 결과를 좌표로 옮겨 선을 긋는 일만 합니다.
private func drawCPUGraphGridlines(in context: inout GraphicsContext, size: CGSize) {
    for value in HistoryGraphGridline.baselineValues {
        let y = CGFloat(HistoryGraphGridline.yPosition(forValue: value, height: Double(size.height)))
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(path, with: .color(DashboardColorPalette.cpuGridline))
    }
}

/// 그래프 자리의 자리표시(task-015). `HistoryGraphView`와 같은 높이만 차지하고, 값이 없는 상태에도
/// 같은 격자를 같은 높이로 그립니다 — 격자는 값이 아니라 눈금이라 그려도 되지만, 점이나 선은 값을 지어내는
/// 것이라 그리지 않습니다(ANALYSIS §5 DP14, SPEC §5.6, §5.8).
private struct GraphPlaceholderView: View {
    var body: some View {
        Canvas { context, size in
            for layer in HistoryGraphGridline.placeholderDrawOrder {
                switch layer {
                case .gridlines:
                    drawCPUGraphGridlines(in: &context, size: size)
                }
            }
        }
        .frame(height: 60)
    }
}

/// 순위·목록 행 앞의 아이콘 자리. 아이콘이 있는 줄이든 없는 줄이든 같은 크기를 차지해
/// 행 높이와 텍스트 시작 위치가 흔들리지 않습니다(SPEC §5.7, ANALYSIS §5 DP12).
///
/// 무엇을 그릴지는 `ApplicationRowIconLayout`이 정하고 이 뷰는 그 결정을 그리기만 합니다 —
/// 크기·중립 기호·접근성 감춤이 모두 뷰 밖 상수라 단위 테스트가 직접 잡습니다(ANALYSIS §5 DP15).
///
/// 아이콘은 같은 행의 앱 이름과 정보가 겹쳐 접근성 계층에서 감춥니다(ANALYSIS §5 DP13).
// `private`가 아닌 것은 task-010 테스트가 세 내용(`icon`·`missing`·`reserved`)의 자리 크기가 같은지
// 이 뷰를 직접 재서 확인하기 때문입니다.
struct ApplicationRowIconView: View {
    let content: ApplicationRowIconContent
    let pointSize: CGFloat

    var body: some View {
        iconImage
            .frame(width: pointSize, height: pointSize)
            .accessibilityHidden(ApplicationRowIconLayout.isHiddenFromAccessibility)
    }

    @ViewBuilder
    private var iconImage: some View {
        switch content {
        case .icon(let image):
            Image(nsImage: image)
                .resizable()
        case .missing:
            Image(systemName: ApplicationRowIconLayout.missingSymbolName)
                .resizable()
                .foregroundStyle(.secondary)
        case .reserved:
            // 앱이 없는 줄입니다. 자리만 차지하고 기호를 드러내지 않습니다.
            Color.clear
        }
    }
}

/// 카드 순위 자리(task-015). 항목 수(0개·3개·5개)나 프로세스 조사 실패 여부와 무관하게
/// TOP 5 정원만큼의 줄과 안내 문구 한 줄을 항상 차지합니다(ANALYSIS §5 DP17).
/// 자리가 남으면 이름·수치를 만들어 넣지 않는 자리표시로 채우고, 조사 실패도 이 정원 안에서
/// 한 줄로 나타내며 나머지 줄은 자리표시로 남습니다(SPEC §5.11).
/// 상세 팝업(`TopApplicationsView`)과 달리 카드 쪽 순위는 이 정원이 고정되어야 하므로 별도 뷰로 둡니다 —
/// 상세 팝업의 크기 정책은 task-016 몫입니다.
// `private`가 아닌 것은 task-011 테스트가 카드가 넘긴 인자 그대로 이 슬롯의 줄을 하나씩 꺼내 재고,
// 정원·아이콘 간격 상수를 기준 폭 조립에 쓰기 때문입니다.
struct CardRankingSlotView: View {
    let entries: [ApplicationRankingEntry]
    let failed: Bool
    let caption: String
    let valueText: (ApplicationRankingEntry) -> String
    let iconProvider: any ApplicationIconProviding

    private static let capacity = ApplicationRankingSampling.cardDisplayCount
    /// 아이콘 자리와 이름 사이 간격.
    static let iconSpacing: CGFloat = 4

    var body: some View {
        // 그릴 줄 수와 줄별 아이콘 대상이 같은 목록에서 나옵니다 — 아이콘이 있는 줄에만 자리를 두면
        // 줄마다 텍스트 시작 위치가 달라지므로, 값이 없는 줄과 조사 실패 줄도 이 목록에 자리를 갖습니다(SPEC §5.7).
        let iconKeys = ApplicationRowIconLayout.cardRowIconKeys(entries: entries, failed: failed, capacity: Self.capacity)
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(iconKeys.enumerated()), id: \.offset) { index, iconKey in
                row(at: index, iconKey: iconKey)
                    .font(.caption)
            }

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // `private`가 아닌 것은 task-011 테스트가 정원의 **줄마다** 아이콘 자리가 남아 있는지 한 줄씩 재기
    // 때문입니다 — 슬롯 전체의 이상적 폭은 가장 넓은 한 줄만 드러내 일부 줄의 자리 손실을 가립니다.
    func row(at index: Int, iconKey: ApplicationKey?) -> some View {
        HStack(spacing: Self.iconSpacing) {
            ForEach(CardRankingRowLayout.elements, id: \.self) { element in
                switch element {
                case .icon:
                    ApplicationRowIconView(
                        content: ApplicationRowIconLayout.content(for: iconKey, from: iconProvider),
                        pointSize: ApplicationRowIconLayout.cardPointSize
                    )
                case .content:
                    rowContent(at: index)
                }
            }
        }
    }

    @ViewBuilder
    private func rowContent(at index: Int) -> some View {
        if failed {
            if index == 0 {
                // 카드 정원(`Self.capacity`)에 맞춘 문구입니다 — 정원 숫자를 문자열에 직접 박아 두면
                // 카드 정원이 바뀌어도 이 문구가 따라오지 못합니다.
                Text("TOP \(Self.capacity) 조사 실패")
                    .foregroundStyle(.secondary)
            } else {
                placeholderRow
            }
        } else if index < entries.count {
            let entry = entries[index]
            Text(entry.displayName)
            Spacer()
            Text(valueText(entry))
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

/// 카드 순위 한 줄의 고정 요소 순서입니다.
/// 이 배열은 순서만 정하고 줄마다 요소가 실제로 그려지는지까지는 정하지 못합니다 —
/// 특정 줄에서만 아이콘 자리를 건너뛰는 변경은 `row(at:iconKey:)`를 줄마다 재는 단위 테스트가 잡습니다.
nonisolated enum CardRankingRowLayout {
    enum Element: Equatable, Hashable {
        case icon
        case content
    }

    static let elements: [Element] = [.icon, .content]
}

/// 앱 단위 순위 목록. 상세 팝업(`MemoryDetailView`)의 최근 증가량 순위 한 자리에서만 쓰이며, 정원보다 적으면
/// 있는 만큼만 나열하고 시스템 프로세스 제외 안내(호출부가 넘기는 정원에 맞춘 문구)를 항상 함께 둡니다.
/// 현재 사용량 순위는 `ApplicationProcessGroupListView`(펼침이 있는 앱 목록)가 겸하므로 이 뷰를 쓰지 않습니다(ANALYSIS §5 DP1).
/// 카드 쪽 순위 자리는 높이가 고정되어야 하므로 이 뷰 대신 `CardRankingSlotView`를 씁니다(task-015).
/// 값 단위가 카드마다 다르므로(CPU는 `%`, Memory는 바이트) 값 표시 문자열은 호출부가 `valueText`로 넘깁니다.
private struct TopApplicationsView: View {
    let entries: [ApplicationRankingEntry]
    let caption: String
    let valueText: (ApplicationRankingEntry) -> String
    let iconProvider: any ApplicationIconProviding

    /// 아이콘 자리와 이름 사이 간격.
    private static let iconSpacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entries, id: \.key) { entry in
                HStack(spacing: Self.iconSpacing) {
                    ApplicationRowIconView(
                        content: ApplicationRowIconLayout.content(for: entry.key, from: iconProvider),
                        pointSize: ApplicationRowIconLayout.detailPointSize
                    )
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
    let iconProvider: any ApplicationIconProviding

    var body: some View {
        ScrollView {
            Group {
                if case .normal(let presentation, _) = state {
                    CPUDetailView(presentation: presentation, iconProvider: iconProvider)
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
    let iconProvider: any ApplicationIconProviding

    var body: some View {
        ScrollView {
            Group {
                if case .normal(let presentation, _) = state {
                    MemoryDetailView(presentation: presentation, iconProvider: iconProvider)
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
    let iconProvider: any ApplicationIconProviding

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
                sortDescription: presentation.detail.applicationsHeading,
                // 값 서식은 `ApplicationProcessValueFormatting`(단위 테스트가 nil 안전성을 직접 확인합니다)을 그대로 씁니다.
                groupValueText: ApplicationProcessValueFormatting.cpuGroupValueText,
                iconProvider: iconProvider,
                valueText: ApplicationProcessValueFormatting.cpuProcessValueText
            )
        }
    }

    private func pct(_ value: Double) -> String { "\(Int(value.rounded()))%" }
    private func fmt(_ value: Double) -> String { String(format: "%.2f", value) }
}

/// Memory 상세: 구성 도넛·수치 범례, Swap 사용량과 증가량, 앱 목록(현재 사용량 순위와
/// 하위 프로세스를 겸함), 최근 증가량 순위(SPEC §5.2, SPEC §5.4, SPEC §5.8, ANALYSIS §5 DP1, DP6).
private struct MemoryDetailView: View {
    let presentation: MemoryCardPresentation
    let iconProvider: any ApplicationIconProviding

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
        let summary = presentation.compositionDetailSummary
        VStack(alignment: .leading, spacing: 6) {
            MemoryCompositionDonutView(
                layout: presentation.compositionDonutLayout,
                legendRows: MemoryCompositionDetailLegendFormatting.rows(
                    bytes: detail.compositionBytes,
                    format: format
                ),
                centerLabel: summary.donutCenter.label,
                centerValue: format(summary.donutCenter.bytes),
                accessibilityLabel: presentation.compositionDonutAccessibilityLabel
            )

            Text("\(summary.usedLine.label) \(format(summary.usedLine.bytes))")
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

            Text("최근 10분 증가량 순위").font(.caption.bold())
            // 증가량은 음수일 수 있으므로 `TopApplicationsView`가 기본 카드에 쓰는 `UInt64` 변환 경로를
            // 그대로 재사용하지 않고, 부호를 보존하는 별도 포맷을 씁니다.
            // 이 목록만 상세 정원(20)까지 받으므로 카드 정원 문구와 다른 문구가 필요합니다 — 정원을
            // 뷰가 고르지 않도록, 조립 시점에 이미 만들어진 문구(`detail.recentIncreaseRankingCaption`)를 그대로 씁니다.
            TopApplicationsView(
                entries: detail.recentIncreaseRanking,
                caption: detail.recentIncreaseRankingCaption,
                valueText: { entry in
                    let signedBytes = Int64(entry.value.rounded())
                    let magnitude = format(UInt64(abs(signedBytes)))
                    return signedBytes >= 0 ? "+\(magnitude)" : "-\(magnitude)"
                },
                iconProvider: iconProvider
            )

            ApplicationProcessGroupListView(
                groups: detail.applications,
                sortDescription: detail.applicationsHeading,
                // Memory는 항상 값이 있지만(SPEC §5.6과 달리 기준점이 필요 없음), nil 안전 경로는
                // `ApplicationProcessValueFormatting`(단위 테스트 대상)을 CPU와 공유합니다.
                groupValueText: { value in ApplicationProcessValueFormatting.memoryGroupValueText(value, format: format) },
                iconProvider: iconProvider
            ) { process in
                format(process.residentBytes)
            }
        }
    }
}

/// 카드와 공유한 구성 구간을 12시 방향부터 시계 방향으로 그리는 상세 도넛과 수치 범례.
private struct MemoryCompositionDonutView: View {
    let layout: MemoryCompositionDonutLayout
    let legendRows: [MemoryCompositionDetailLegendRow]
    let centerLabel: String
    let centerValue: String
    let accessibilityLabel: String

    private static let diameter: CGFloat = 140
    private static let lineWidth: CGFloat = 18

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = (min(size.width, size.height) - Self.lineWidth) / 2
                    let track = Path(ellipseIn: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))
                    context.stroke(
                        track,
                        with: .color(DashboardColorPalette.memoryCompositionTrack),
                        lineWidth: Self.lineWidth
                    )

                    for segment in layout.segments where segment.ratio > 0 {
                        var path = Path()
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(segment.startAngleDegrees),
                            endAngle: .degrees(segment.endAngleDegrees),
                            clockwise: false
                        )
                        context.stroke(
                            path,
                            with: .color(DashboardColorPalette.memoryComposition(segment.category)),
                            style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .butt)
                        )
                    }
                }

                VStack(spacing: 2) {
                    Text(centerLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(centerValue)
                        .font(.caption.bold())
                }
            }
            .frame(width: Self.diameter, height: Self.diameter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityIdentifier("MemoryCompositionDonut")

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(legendRows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 6) {
                        Image(systemName: "square.fill")
                            .foregroundStyle(DashboardColorPalette.memoryComposition(row.category))
                        Text(row.label)
                        Spacer(minLength: 8)
                        Text(row.valueText)
                    }
                    .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
    let iconProvider: any ApplicationIconProviding
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
                    iconProvider: iconProvider,
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
    let iconProvider: any ApplicationIconProviding
    @Binding var isExpanded: Bool

    /// 아이콘 자리와 앱 이름 사이 간격.
    private static let iconSpacing: CGFloat = 6

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
            HStack(spacing: Self.iconSpacing) {
                ApplicationRowIconView(
                    content: ApplicationRowIconLayout.content(for: group.key, from: iconProvider),
                    pointSize: ApplicationRowIconLayout.detailPointSize
                )
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
    DashboardView(store: DashboardPresentationStore(), iconProvider: ApplicationIconCache())
}
