//
//  DashboardView.swift
//  ResourceRunner
//
//  Created by zipkero on 8/2/26.
//

import SwiftUI

/// 대시보드 팝오버 셸. CPU·Memory 카드(task-008, task-009)와 카드 옆 상세 팝업(task-010)을 담습니다.
///
/// 본체는 두 카드만 가지며 상세를 위한 자리를 예약하지 않습니다.
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
        VStack(alignment: .leading, spacing: DashboardView.cardSpacing) {
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
        .background(DashboardColorPalette.popoverBackground)
        // 화면 제목을 없앤 뒤에도 XCUITest가 본체 팝오버의 프레임과 카드 밖 영역을 안정적으로 특정할 수 있게 합니다.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("DashboardContainer")
    }

    /// 높이 제약을 걷고 수집 중·정상 상태를 각각 재었을 때 팝오버 프레임은 모두 627pt였습니다.
    /// `NSPopover` chrome 26pt를 뺀 콘텐츠 높이로 고정해 상태 전이에도 프레임이 흔들리지 않게 합니다.
    fileprivate static let bodyHeight: CGFloat = 601

    /// 두 카드가 각자의 면으로 서로 분리되어 읽히게 하는 카드 사이 간격입니다.
    static let cardSpacing = DashboardStyle.Spacing.betweenSections

    /// CPU 카드 선택·복귀 단축키의 실제 키. `CPUCardPresentation.selectionShortcutKey`에서 유도되어
    /// 본체 등록 한 곳뿐인 단축키 정의와 카드 표시 문자열이 같은 값을 공유합니다(ANALYSIS §5 DP15).
    fileprivate static let cpuSelectionKey = KeyEquivalent(CPUCardPresentation.selectionShortcutKey)

    /// Memory 카드 선택·복귀 단축키의 실제 키. CPU 쪽과 같은 이유로 같은 형태로 유도합니다.
    fileprivate static let memorySelectionKey = KeyEquivalent(MemoryCardPresentation.selectionShortcutKey)

    /// 상세 팝업 콘텐츠의 공통 고정 크기(ANALYSIS §5 DP18). CPU 상세와 Memory 상세가 이 크기를 공유해
    /// 카드를 오가거나 프로세스 수·값이 바뀌어도 팝업 프레임이 흔들리지 않고, 넘치는 내용은 내부
    /// `ScrollView`에서만 스크롤됩니다.
    /// 새 상세 조립에서 후보 400×480을 다시 확정했습니다. 단위 테스트로 콘텐츠 폭 368pt 안에 CPU 앱 행,
    /// Memory 도넛·범례 행과 코어 격자의 이상적 폭이 들고, 14코어 격자 아래끝 176pt가 높이 480pt 안에
    /// 드는지 먼저 확인한 뒤 XCUITest에서 네 상태와 앱 행 펼침·접힘, 스크롤 전후의 `DashboardDetail`
    /// 프레임이 400×480으로 고정되는지 재확인했습니다. 두 상세는 실행 중인 모든 프로세스를 나열하므로
    /// 넘치는 세로 내용은 기존처럼 이 고정 프레임 안의 단일 `ScrollView`가 맡습니다.
    static let detailPopupWidth: CGFloat = 400
    static let detailPopupHeight: CGFloat = 480

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
/// 수집 중·정상·실패·중지 네 상태 모두 제목 줄 · 초점 줄 · 계열 요약 줄 · 그래프 자리 · 순위 자리라는 같은 슬롯
/// 집합을 그립니다(task-015, ANALYSIS §1 「표시 경계」, §5 DP17). 상태 분기는 어느 슬롯을 그릴지가 아니라
/// `cached`(캐시된 값)가 있는지에 따라 슬롯 안의 내용에만 남습니다 — 슬롯을 더하거나 빼는 분기는 없습니다.
// `private`가 아니라 기본 접근 수준입니다 — task-015 테스트가 항목 수·조사 실패를 달리한 카드 뷰를 직접
// 렌더링해 높이를 비교해야 하므로(`@testable import`) 파일 밖(같은 모듈의 테스트 타깃)에서 접근할 수 있어야 합니다.
struct CPUCardView: View {
    let state: ResourceCardState<CPUCardPresentation>
    /// 순위 행이 아이콘을 묻는 자리. 이 뷰는 전달만 하고 캐시를 만들지 않습니다(ANALYSIS §5 DP11).
    let iconProvider: any ApplicationIconProviding

    /// 카드 안 구역(제목 묶음·그래프 묶음·순위 묶음) 사이 간격. 상세 화면의 구역 사이와 같은 단계를 씁니다.
    static let sectionSpacing = DashboardStyle.Section.betweenSections

    /// 이 카드가 보여줄 수 있는 값. `normal`은 이번 tick 값, `failure`·`stopped`는 마지막 성공 값을 담고,
    /// 성공 이력이 없는 `collecting`과 실패·중지는 `nil`입니다(`ResourceCardState.lastKnownValue`).
    /// 캐시된 값이 있는 슬롯에는 자리표시가 들어가지 않고 그 값이 그대로 보입니다(SPEC §5.9, §5 DP17).
    private var cached: CPUCardPresentation? {
        state.lastKnownValue?.presentation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            VStack(alignment: .leading, spacing: DashboardStyle.Spacing.withinGroup) {
                Text("CPU")
                    .dashboardTypography(DashboardStyle.TypographyRole.heading)

                focusLine
                secondaryLine
            }

            HistoryGraphSlotView(points: cached?.graphPoints)

            rankingSlot
        }
        .padding(DashboardStyle.CardSurface.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DashboardStyle.CardSurface.cornerRadius)
                .fill(DashboardStyle.CardSurface.fillColor)
        )
        .contentShape(RoundedRectangle(cornerRadius: DashboardStyle.CardSurface.cornerRadius))
    }

    /// 카드 순위 자리. 값이 없으면 빈 항목 목록을 넘겨 정원만큼의 자리표시 줄이 남습니다.
    // `private`가 아닌 것은 task-011 테스트가 이 카드가 실제로 넘기는 항목·정원 그대로 줄별 아이콘 자리를
    // 재기 때문입니다 — 테스트가 슬롯을 따로 조립하면 카드가 다른 인자를 넘기는 변경을 놓칩니다.
    var rankingSlot: CardRankingSlotView {
        CardRankingSlotView(
            entries: cached?.topApplications ?? [],
            failed: cached?.topApplicationsFailed ?? false,
            heading: CPUCardPresentation.topApplicationsHeading,
            value: { DashboardValueColumn.percent($0.value, unit: CPUCardPresentation.overallUsageUnitLabel) },
            iconProvider: iconProvider
        )
    }

    /// 상태 접두는 라벨 역할, 전체 사용률은 초점 역할로 한 줄 안에 이어 붙입니다.
    /// 값이 없는 상태에서도 숨긴 초점 역할 한 글자가 줄 높이를 맡아 상태 전환 때 카드 높이가 갈리지 않습니다.
    var focusLine: some View {
        ZStack(alignment: .leading) {
            Text("0")
                .dashboardTypography(DashboardStyle.TypographyRole.focus)
                .hidden()
            focusLineText
                .lineLimit(1)
        }
    }

    private var focusLineText: Text {
        switch state {
        case .collecting:
            return Text("수집 중").dashboardTypography(DashboardStyle.TypographyRole.label)
        case .normal(let presentation, _):
            return Text("\(Int(presentation.overallUsage.rounded()))\(CPUCardPresentation.overallUsageUnitLabel)")
                .dashboardTypography(DashboardStyle.TypographyRole.focus)
        case .failure(let lastKnown):
            guard let lastKnown else {
                return Text("수집 실패").dashboardTypography(DashboardStyle.TypographyRole.label)
            }
            return Text("수집 실패 · 마지막 ").dashboardTypography(DashboardStyle.TypographyRole.label)
                + Text("\(Int(lastKnown.presentation.overallUsage.rounded()))\(CPUCardPresentation.overallUsageUnitLabel)")
                    .dashboardTypography(DashboardStyle.TypographyRole.focus)
        case .stopped(let lastKnown):
            guard let lastKnown else {
                return Text("수집 중지").dashboardTypography(DashboardStyle.TypographyRole.label)
            }
            return Text("수집 중지 · 마지막 ").dashboardTypography(DashboardStyle.TypographyRole.label)
                + Text("\(Int(lastKnown.presentation.overallUsage.rounded()))\(CPUCardPresentation.overallUsageUnitLabel)")
                    .dashboardTypography(DashboardStyle.TypographyRole.focus)
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
                    CPUSeriesRatioView(label: "User", ratio: presentation.userRatio)
                    Text("·").dashboardTypography(DashboardStyle.TypographyRole.label)
                    CPUSeriesSwatchView(band: .upper)
                    CPUSeriesRatioView(label: "System", ratio: presentation.systemRatio)
                }
            } else {
                HStack(spacing: CPUSeriesPlaceholderLayout.spacing) {
                    ForEach(Array(CPUSeriesPlaceholderLayout.entries.enumerated()), id: \.offset) { index, entry in
                        if index > 0 {
                            Text("·").dashboardTypography(DashboardStyle.TypographyRole.label)
                        }
                        CPUSeriesSwatchView(band: entry.band)
                        Text("\(entry.label) ").dashboardTypography(DashboardStyle.TypographyRole.label)
                            + Text(entry.valueText).dashboardTypography(DashboardStyle.TypographyRole.value)
                    }
                }
            }
        }
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
    static let spacing = DashboardStyle.Spacing.labelToContent

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
/// 요약 줄의 「이름 + 비율」 조각. 비율 숫자에 두 자리 기준 고정 폭을 주어,
/// 값이 한 자리와 두 자리를 오갈 때 뒤따르는 구분자와 System 조각이 밀리지 않게 합니다.
/// 자릿수가 고정되지 않으면 `monospacedDigit()`만으로는 줄이 흔들립니다.
struct CPUSeriesRatioView: View {
    let label: String
    let ratio: Double

    /// 두 자리 정수 + `%`가 들어가는 폭. 사용률은 0…100이라 세 자리는 100 하나뿐이고,
    /// 그 값은 자리를 넘겨 그려도 줄 전체가 밀리지 않습니다.
    static let numberWidth: CGFloat = 26

    var body: some View {
        HStack(spacing: 0) {
            Text("\(label) ").dashboardTypography(DashboardStyle.TypographyRole.label)
            Text("\(Int(ratio.rounded()))%")
                .dashboardTypography(DashboardStyle.TypographyRole.value)
                .frame(width: Self.numberWidth, alignment: .leading)
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}

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
/// CPU 카드와 같은 이유로 네 상태 모두 제목·초점 줄(구성 누적 바 포함) · Pressure·Swap 병합 줄 · 구성 범례 줄 ·
/// 순위 자리를 항상 그립니다.
/// Pressure 줄과 Swap 줄은 한 줄로 합쳐 비운 자리를 구성 범례 줄이 씁니다 — 슬롯 수와 카드 높이는 그대로입니다(ANALYSIS §5 DP4).
/// 값이 있을 때만 그리던 Pressure 줄·Swap 줄도 고정 슬롯으로 바꿨습니다(task-015, §5 DP17).
// CPU 카드와 같은 이유로 기본 접근 수준입니다(task-015 테스트).
struct MemoryCardView: View {
    let state: ResourceCardState<MemoryCardPresentation>
    /// CPU 카드와 같은 이유로 전달만 받습니다.
    let iconProvider: any ApplicationIconProviding

    /// CPU 카드의 같은 상수와 같은 뜻입니다.
    static let sectionSpacing = DashboardStyle.Section.betweenSections

    /// CPU 카드의 `cached`와 같은 뜻입니다 — 캐시된 값이 있는 슬롯에는 자리표시가 들어가지 않습니다.
    private var cached: MemoryCardPresentation? {
        state.lastKnownValue?.presentation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            VStack(alignment: .leading, spacing: DashboardStyle.Spacing.withinGroup) {
                Text("Memory")
                    .dashboardTypography(DashboardStyle.TypographyRole.heading)

                titleLine
            }

            VStack(alignment: .leading, spacing: DashboardStyle.Spacing.withinGroup) {
                pressureSwapLine
                compositionLegendLine
            }

            rankingSlot
        }
        .padding(DashboardStyle.CardSurface.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DashboardStyle.CardSurface.cornerRadius)
                .fill(DashboardStyle.CardSurface.fillColor)
        )
        .contentShape(RoundedRectangle(cornerRadius: DashboardStyle.CardSurface.cornerRadius))
    }

    /// 카드 순위 자리. CPU 카드의 같은 속성과 같은 이유로 기본 접근 수준입니다.
    var rankingSlot: CardRankingSlotView {
        CardRankingSlotView(
            entries: cached?.topApplications ?? [],
            failed: cached?.topApplicationsFailed ?? false,
            heading: MemoryCardPresentation.topApplicationsHeading,
            value: { DashboardValueColumn.bytes(UInt64($0.value.rounded())) },
            iconProvider: iconProvider
        )
    }

    /// 제목 줄. 「사용 중 / 전체」 수치가 왼쪽에 남고, 그 줄의 남는 폭을 구성 누적 바가 씁니다(SPEC §5.3).
    /// 바 높이는 제목 텍스트 높이 이하이고 제목은 한 줄로 묶여 있어, 이 바 때문에 카드가 커지지 않습니다(SPEC §5.8).
    var titleLine: some View {
        HStack(spacing: DashboardStyle.Spacing.labelToContent) {
            focusLine
                .lineLimit(MemoryCompositionLegendFormatting.maximumLineCount)
                .layoutPriority(1)

            MemoryCompositionBarView(segments: cached?.compositionLayout.segments ?? MemoryCompositionBarLayout.placeholderSegments)
        }
    }

    /// 상태 접두는 라벨, 사용 중 값은 초점 역할로 한 줄 안에 이어 붙입니다.
    /// 전체 용량은 견주는 대상이라 본문 값 역할이고, 초점 역할로 두면 최악 입력에서 줄이 카드 콘텐츠 폭을 넘습니다.
    /// CPU 카드와 같이 숨긴 초점 역할 한 글자가 값 없는 상태의 줄 높이를 보존합니다.
    var focusLine: some View {
        ZStack(alignment: .leading) {
            Text("0")
                .dashboardTypography(DashboardStyle.TypographyRole.focus)
                .hidden()
            focusLineText
                .lineLimit(1)
        }
    }

    private var focusLineText: Text {
        switch state {
        case .collecting:
            return Text("수집 중").dashboardTypography(DashboardStyle.TypographyRole.label)
        case .normal(let presentation, _):
            return Text(DashboardValueColumn.byteText(presentation.usedBytes))
                .dashboardTypography(DashboardStyle.TypographyRole.focus)
                + Text(" / \(DashboardValueColumn.byteText(presentation.totalPhysicalBytes))")
                    .dashboardTypography(DashboardStyle.TypographyRole.value)
        case .failure(let lastKnown):
            guard let lastKnown else {
                return Text("수집 실패").dashboardTypography(DashboardStyle.TypographyRole.label)
            }
            return Text("수집 실패 · 마지막 ").dashboardTypography(DashboardStyle.TypographyRole.label)
                + Text(DashboardValueColumn.byteText(lastKnown.presentation.usedBytes))
                    .dashboardTypography(DashboardStyle.TypographyRole.focus)
        case .stopped(let lastKnown):
            guard let lastKnown else {
                return Text("수집 중지").dashboardTypography(DashboardStyle.TypographyRole.label)
            }
            return Text("수집 중지 · 마지막 ").dashboardTypography(DashboardStyle.TypographyRole.label)
                + Text(DashboardValueColumn.byteText(lastKnown.presentation.usedBytes))
                    .dashboardTypography(DashboardStyle.TypographyRole.focus)
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
                format: { DashboardValueColumn.byteText($0) }
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
        .dashboardTypography(DashboardStyle.TypographyRole.label)
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
        .dashboardTypography(DashboardStyle.TypographyRole.label)
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

    /// `Canvas`가 그리는 것과 순서. 기준선이 맨 먼저(가장 뒤)에 오고 두 밴드 채움·경계선이 그 위에 얹힙니다.
    /// 기준선을 먼저 그려야 반투명 밴드 사이로 비칩니다.
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

    let currentTimestamp: ContinuousClock.Instant

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

    /// 밴드 채움 불투명도. 두 밴드가 서로 다른 밀도로 채워지고, 격자가 부하가 높은 구간에서도
    /// 비치도록 둘 다 반투명입니다.
    static func fillOpacity(for band: BandRole) -> Double {
        switch band {
        case .lower: return 0.60
        case .upper: return 0.15
        }
    }

    private static func color(for band: BandRole) -> Color {
        switch band {
        case .lower: return DashboardColorPalette.cpuUser
        case .upper: return DashboardColorPalette.cpuSystem
        }
    }

    var body: some View {
        GeometryReader { proxy in
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

/// `HistoryGraphView`와 값 없음 자리표시(`GraphPlaceholderView`)가 같은 기준선을 그리도록 공유하는 그리기 함수입니다.
/// 그리는 기준선 값과 좌표 변환은 `HistoryGraphGridline`(뷰 밖 순수 함수)에서 가져오고,
/// 여기서는 그 결과를 좌표로 옮겨 선을 긋는 일만 합니다.
private func drawCPUGraphGridlines(in context: inout GraphicsContext, size: CGSize) {
    for value in HistoryGraphGridline.drawnBaselineValues {
        let y = CGFloat(HistoryGraphGridline.yPosition(forValue: value, height: Double(size.height)))
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(
            path,
            with: .color(DashboardColorPalette.cpuGridline),
            lineWidth: HistoryGraphGridline.lineWidth
        )
    }
}

/// 값 있음·없음 경로가 공유하는 그래프 판과 시간 축 줄입니다.
/// 판 면은 두 경로를 고르는 판 틀에 배경으로 한 번만 깔아, 어느 경로든 같은 크기·같은 자리의 면 위에 그립니다.
private struct HistoryGraphSlotView: View {
    let points: [HistoryPoint]?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let currentTimestamp = ContinuousClock().now
            let timeAxis = HistoryGraphTimeAxis.make(
                points: points ?? [],
                currentTimestamp: currentTimestamp
            )

            VStack(spacing: HistoryGraphLayout.axisSpacing) {
                Group {
                    if let points {
                        HistoryGraphView(points: points, currentTimestamp: currentTimestamp)
                    } else {
                        GraphPlaceholderView()
                    }
                }
                .frame(height: HistoryGraphLayout.plotHeight)
                // 판 틀의 네 변이 곧 100%·0%와 시간 창 양끝이라, 틀 전체를 각진 면으로 덮어 판의 범위를 면의 가장자리로 보입니다.
                // `points`를 읽지 않아 수집되지 않은 구간도 같은 면이고, 윤곽선을 긋지 않아 판 위의 선은 기준선 하나로 남습니다.
                .background(DashboardColorPalette.graphPlotSurface)

                ZStack {
                    HStack(spacing: 0) {
                        axisLabel(timeAxis.leadingLabel)
                        Spacer(minLength: 0)
                        axisLabel(timeAxis.trailingLabel)
                    }
                    axisLabel(timeAxis.collectionProgressLabel)
                }
                .frame(height: HistoryGraphLayout.axisLabelHeight)
            }
            .frame(height: HistoryGraphLayout.slotHeight)
        }
    }

    private func axisLabel(_ text: String) -> some View {
        Text(text)
            .dashboardTypography(DashboardStyle.TypographyRole.label)
    }
}

/// 그래프 자리의 자리표시. 값이 없는 상태에도 값 있음 경로와 같은 판 면 위에 같은 기준선 하나를 같은 좌표에 그립니다.
/// 기준선은 값이 아니라 눈금이라 그려도 되지만, 점이나 값 선은 그리지 않습니다.
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
/// 머리글과 TOP 5 정원만큼의 줄을 항상 차지합니다(ANALYSIS §5 DP17).
/// 자리가 남으면 이름·수치를 만들어 넣지 않는 자리표시로 채우고, 조사 실패도 이 정원 안에서
/// 한 줄로 나타내며 나머지 줄은 자리표시로 남습니다(SPEC §5.11).
/// 상세 팝업(`TopApplicationsView`)과 달리 카드 쪽 순위는 이 정원이 고정되어야 하므로 별도 뷰로 둡니다 —
/// 상세 팝업의 크기 정책은 task-016 몫입니다.
// `private`가 아닌 것은 task-011 테스트가 카드가 넘긴 인자 그대로 이 슬롯의 줄을 하나씩 꺼내 재고,
// 정원·아이콘 간격 상수를 기준 폭 조립에 쓰기 때문입니다.
struct CardRankingSlotView: View {
    let entries: [ApplicationRankingEntry]
    let failed: Bool
    let heading: String
    let value: (ApplicationRankingEntry) -> DashboardValueColumn.Value
    let iconProvider: any ApplicationIconProviding

    private static let capacity = ApplicationRankingSampling.cardDisplayCount
    /// 머리글과 순위 목록 사이 간격.
    static let headingSpacing = DashboardStyle.Section.headingToContent
    /// 아이콘 자리와 이름 사이 간격.
    static let iconSpacing = DashboardStyle.Spacing.labelToContent

    var body: some View {
        // 그릴 줄 수와 줄별 아이콘 대상이 같은 목록에서 나옵니다 — 아이콘이 있는 줄에만 자리를 두면
        // 줄마다 텍스트 시작 위치가 달라지므로, 값이 없는 줄과 조사 실패 줄도 이 목록에 자리를 갖습니다(SPEC §5.7).
        let iconKeys = ApplicationRowIconLayout.cardRowIconKeys(entries: entries, failed: failed, capacity: Self.capacity)
        VStack(alignment: .leading, spacing: Self.headingSpacing) {
            Text(heading)
                .dashboardTypography(DashboardStyle.Section.headingRole)

            VStack(alignment: .leading, spacing: DashboardStyle.Spacing.withinGroup) {
                ForEach(Array(iconKeys.enumerated()), id: \.offset) { index, iconKey in
                    row(at: index, iconKey: iconKey)
                }
            }
        }
    }

    // `private`가 아닌 것은 task-011 테스트가 정원의 **줄마다** 아이콘 자리가 남아 있는지 한 줄씩 재기
    // 때문입니다 — 슬롯 전체의 이상적 폭은 가장 넓은 한 줄만 드러내 일부 줄의 자리 손실을 가립니다.
    func row(at index: Int, iconKey: ApplicationKey?) -> some View {
        // 값 열이 없는 줄(자리표시·조사 실패 안내)은 라벨 역할 줄 높이만 차지해 값이 있는 줄보다 낮아집니다.
        // 숨긴 본문 값 한 글자가 모든 줄의 높이를 맡아, 줄마다 높이가 갈려 카드 높이가 상태에 따라 달라지는 것을 막습니다.
        ZStack(alignment: .leading) {
            Text(" ")
                .dashboardTypography(DashboardStyle.TypographyRole.value)
                .hidden()

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
    }

    @ViewBuilder
    private func rowContent(at index: Int) -> some View {
        if failed {
            if index == 0 {
                // 카드 정원(`Self.capacity`)에 맞춘 문구입니다 — 정원 숫자를 문자열에 직접 박아 두면
                // 카드 정원이 바뀌어도 이 문구가 따라오지 못합니다.
                Text("TOP \(Self.capacity) 조사 실패")
                    .dashboardTypography(DashboardStyle.TypographyRole.label)
            } else {
                placeholderRow
            }
        } else if index < entries.count {
            let entry = entries[index]
            Text(entry.displayName)
                .dashboardTypography(DashboardStyle.TypographyRole.label)
            Spacer()
            DashboardAlignedValueView(value: value(entry))
        } else {
            placeholderRow
        }
    }

    /// 값이 없는 줄의 자리표시. 다른 줄과 같은 높이만 차지하고 이름·수치를 만들어 넣지 않습니다.
    private var placeholderRow: some View {
        Text(" ")
            .dashboardTypography(DashboardStyle.TypographyRole.label)
            .opacity(0)
    }
}

/// 숫자와 단위를 값 종류별 고정 폭 열에 놓는 공용 값 꼬리입니다.
///
/// 두 `Text`는 화면에서는 별도 열이지만 접근성 계층에서는 한 문자열을 가진 노드 하나로 합쳐집니다.
struct DashboardAlignedValueView: View {
    let value: DashboardValueColumn.Value

    var body: some View {
        HStack(spacing: 0) {
            Text(value.number)
                .dashboardTypography(DashboardStyle.TypographyRole.value)
                .frame(width: value.kind.numberWidth, alignment: .trailing)
            Text(value.unit.isEmpty ? "" : " \(value.unit)")
                .dashboardTypography(DashboardStyle.TypographyRole.label)
                .frame(width: value.kind.unitWidth, alignment: .leading)
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
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
struct TopApplicationsView: View {
    let entries: [ApplicationRankingEntry]
    let caption: String
    let value: (ApplicationRankingEntry) -> DashboardValueColumn.Value
    let iconProvider: any ApplicationIconProviding

    /// 아이콘 자리와 이름 사이 간격.
    static let iconSpacing = DashboardStyle.Spacing.labelToContent

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardStyle.Spacing.withinGroup) {
            ForEach(entries, id: \.key) { entry in
                row(entry)
            }

            Text(caption)
                .dashboardTypography(DashboardStyle.TypographyRole.label)
        }
    }

    /// 실제 목록과 같은 한 행을 렌더 측정할 수 있게 조립을 한 곳에 둡니다.
    func row(_ entry: ApplicationRankingEntry) -> some View {
        HStack(spacing: Self.iconSpacing) {
            ApplicationRowIconView(
                content: ApplicationRowIconLayout.content(for: entry.key, from: iconProvider),
                pointSize: ApplicationRowIconLayout.detailPointSize
            )
            Text(entry.displayName)
            Spacer()
            DashboardAlignedValueView(value: value(entry))
        }
        .dashboardTypography(DashboardStyle.TypographyRole.label)
    }
}

/// CPU 카드 옆에 앵커되는 상세 팝업 콘텐츠. 아직 정상 값이 없으면(수집 중·실패·중지) 안내 문구만 보여줍니다.
/// 팝업 프레임은 `DashboardView.detailPopupWidth`·`detailPopupHeight`로 고정하고, 그 안을 `ScrollView`로 감싸
/// 카드를 오가거나 프로세스 수·값이 달라져도 팝업 크기가 흔들리지 않게 합니다(ANALYSIS §5 DP18).
/// 카드 선택·복귀 단축키는 본체(`DashboardView`) 한 곳에만 등록합니다 — 자식 팝오버가 key window를 가져가지
/// 않는 것이 실행 환경에서 확인되어 본체 등록만으로 팝업이 열린 뒤에도 계속 닿습니다(ANALYSIS §5 DP15).
// `private`가 아닌 것은 task-007 테스트가 네 상태의 콘텐츠를 직접 렌더해 고정 프레임과
// 값 없음 분기의 동일성을 재야 하기 때문입니다. `.popover` 안에 둔 채 재면 콘텐츠가 실체화되지 않습니다.
struct CPUDetailPopoverContent: View {
    let state: ResourceCardState<CPUCardPresentation>
    let iconProvider: any ApplicationIconProviding

    /// 이 상태에서 상세 본문이 조립하는 이 feature의 새 표시 요소.
    /// 정상 목록을 `CPUDetailView`의 production 조립에서 가져오므로 하위 조립에 요소가 더해지면
    /// task-007의 상태 × 요소 순회 목록도 같은 경로로 늘어납니다.
    var newDisplayElements: [DetailPopoverNewDisplayElement] {
        guard case .normal = state else { return [] }
        return CPUDetailView.newDisplayElements
    }

    var body: some View {
        ScrollView {
            detailContent
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: DashboardView.detailPopupWidth, height: DashboardView.detailPopupHeight)
        .background(DashboardColorPalette.cardSurface)
        .accessibilityIdentifier("DashboardDetail")
    }

    /// 상태 분기를 한 자리에 두고 `body`가 이를 production `ScrollView`와 고정 프레임 아래에 조립합니다.
    /// task-007은 `detailContent` 조각이 아니라 그 `body` 전체를 AppKit hosting view로 렌더합니다.
    @ViewBuilder var detailContent: some View {
        if case .normal(let presentation, _) = state {
            CPUDetailView(presentation: presentation, iconProvider: iconProvider)
        } else {
            Text("아직 CPU 값이 수집되지 않았습니다.")
                .dashboardTypography(DashboardStyle.TypographyRole.label)
        }
    }
}

/// Memory 카드 옆에 앵커되는 상세 팝업 콘텐츠. CPU 쪽과 같은 이유로 같은 형태를 씁니다.
// CPU 쪽과 같은 고정 프레임 계약을 단위 테스트에서 직접 재기 위해 기본 접근 수준으로 둡니다.
struct MemoryDetailPopoverContent: View {
    let state: ResourceCardState<MemoryCardPresentation>
    let iconProvider: any ApplicationIconProviding

    var body: some View {
        ScrollView {
            Group {
                if case .normal(let presentation, _) = state {
                    MemoryDetailView(presentation: presentation, iconProvider: iconProvider)
                } else {
                    Text("아직 Memory 값이 수집되지 않았습니다.")
                        .dashboardTypography(DashboardStyle.TypographyRole.label)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: DashboardView.detailPopupWidth, height: DashboardView.detailPopupHeight)
        .background(DashboardColorPalette.cardSurface)
        .accessibilityIdentifier("DashboardDetail")
    }
}

/// CPU 상세: User·System·Idle, 논리 코어별 사용률, Load Average, 앱별 하위 프로세스(SPEC §5.2).
// `private`가 아닌 것은 task-002 테스트가 이 뷰를 직접 렌더해 코어 격자가 실제로 조립되는지 보기 때문입니다 —
// `.popover` 콘텐츠는 크기 측정에서 평가되지 않아, 팝오버 쪽에서 재면 격자 호출을 통째로 지워도 드러나지 않습니다.
struct CPUDetailView: View {
    let presentation: CPUCardPresentation
    let iconProvider: any ApplicationIconProviding

    private enum AssemblyElement: CaseIterable {
        case summary
        case coreUsage
        case loadAverage
        case applicationGroups

        var newDisplayElements: [DetailPopoverNewDisplayElement] {
            switch self {
            case .summary, .loadAverage:
                []
            case .coreUsage:
                CPUCoreUsageSection.assembly.flatMap(\.newDisplayElements)
            case .applicationGroups:
                ApplicationProcessGroupRow.assembly.flatMap(\.newDisplayElements)
            }
        }
    }

    /// `body`가 실제로 순회하는 production 조립 항목에서 파생한 task-007 전수 목록입니다.
    /// 표시 요소를 더하려면 이 조립에 항목을 넣어야 하므로 별도 목록을 함께 고칠 자리가 없습니다.
    static var newDisplayElements: [DetailPopoverNewDisplayElement] {
        AssemblyElement.allCases.flatMap(\.newDisplayElements)
    }

    /// 코어 머리글과 격자를 한 조립으로 둡니다. task-007은 이 production 조립과 머리글만 뺀 기준의
    /// 높이를 견주어 머리글 존재 단언의 감도를 확인합니다.
    private struct CPUCoreUsageSection: View {
        let presentation: CPUCardPresentation

        fileprivate enum AssemblyElement: CaseIterable {
            case heading
            case grid

            var newDisplayElements: [DetailPopoverNewDisplayElement] {
                switch self {
                case .heading: [.coreGridHeading]
                case .grid: CPUCoreUsageGridView.assembly.flatMap(\.newDisplayElements)
                }
            }
        }

        fileprivate static let assembly = AssemblyElement.allCases

        var body: some View {
            VStack(alignment: .leading, spacing: CPUCoreUsageGridView.headingSpacing) {
                ForEach(Self.assembly, id: \.self) { element in
                    switch element {
                    case .heading:
                        Text(CPUCoreUsageFormatting.headingText(coreCount: presentation.detail.coreUsages.count))
                            .dashboardTypography(DashboardStyle.Section.headingRole)
                    case .grid:
                        CPUCoreUsageGridView(usages: presentation.detail.coreUsages)
                    }
                }
            }
        }
    }

    var coreUsageSection: some View {
        CPUCoreUsageSection(presentation: presentation)
    }

    /// 상세 구역 사이 간격. 카드와 같은 자리를 참조해 두 화면의 구역이 같은 간격으로 갈립니다.
    static let sectionSpacing = DashboardStyle.Section.betweenSections

    var body: some View {
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            ForEach(AssemblyElement.allCases, id: \.self) { element in
                switch element {
                case .summary:
                    Text("User \(pct(presentation.userRatio)) · System \(pct(presentation.systemRatio)) · Idle \(pct(presentation.detail.idleRatio))")
                        .dashboardTypography(DashboardStyle.TypographyRole.value)
                case .coreUsage:
                    coreUsageSection
                case .loadAverage:
                    let load = presentation.detail.loadAverage
                    Text("Load Average ").dashboardTypography(DashboardStyle.TypographyRole.heading)
                        + Text("\(fmt(load.oneMinute)) / \(fmt(load.fiveMinutes)) / \(fmt(load.fifteenMinutes))")
                            .dashboardTypography(DashboardStyle.TypographyRole.value)
                case .applicationGroups:
                    ApplicationProcessGroupListView(
                        groups: presentation.detail.applications,
                        sortDescription: presentation.detail.applicationsHeading,
                        exclusionNote: presentation.detail.applicationsExclusionNote,
                        // 값 서식은 `ApplicationProcessValueFormatting`(단위 테스트가 nil 안전성을 직접 확인합니다)을 그대로 씁니다.
                        groupValue: ApplicationProcessValueFormatting.cpuGroupValueText,
                        iconProvider: iconProvider,
                        valueText: ApplicationProcessValueFormatting.cpuProcessValueText
                    )
                }
            }
        }
    }

    private func pct(_ value: Double) -> String { "\(Int(value.rounded()))%" }
    private func fmt(_ value: Double) -> String { String(format: "%.2f", value) }
}

/// 논리 코어별 사용률 격자. `CPUCoreGridLayout`이 나눈 행을 좌표로 옮겨 그리기만 합니다.
///
/// 칸 하나는 위에서부터 막대 · 화면 수치 · 코어 번호 세 줄입니다. 번호를 맨 아래에 두면 격자 전체가
/// 가로축 눈금이 달린 막대 그래프로 읽힙니다(DESIGN §5 DP3).
///
/// `LazyVGrid`도 `sizeThatFits`에서는 화면 밖 행까지 모두 실체화해 이 조립과 렌더 높이가 소수점까지 같습니다.
/// 쓰지 않는 근거는 화면 밖 행의 접근성 요소가 언제 존재하는지를 이 코드가 보증할 수 없기 때문입니다(DESIGN §5 DP4).
// `private`가 아닌 것은 task-002 테스트가 이 뷰만 따로 렌더해 칸 폭·채움 픽셀을 재기 때문입니다.
struct CPUCoreUsageGridView: View {
    let usages: [Double]

    enum AssemblyElement: CaseIterable {
        case cells
        case lastRowEmptySlots

        var newDisplayElements: [DetailPopoverNewDisplayElement] {
            switch self {
            case .cells: CPUCoreUsageCellView.assembly.flatMap(\.newDisplayElements)
            case .lastRowEmptySlots: [.lastRowEmptySlot]
            }
        }
    }

    /// 각 격자 행의 `body`가 실제로 순회하는 조립 항목입니다.
    static let assembly = AssemblyElement.allCases

    /// 격자 머리글과 격자 사이 간격. 머리글이 격자에 딸린 이름으로 읽히도록 섹션 간격보다 좁습니다.
    static let headingSpacing = DashboardStyle.Section.headingToContent

    var body: some View {
        let rows = CPUCoreGridLayout.rows(coreCount: usages.count)
        let columnCount = rows.first?.count ?? 0

        // 균등 분할한 칸 폭이 나눠떨어지지 않는 코어 수에서 `HStack`이 되돌리는 폭에 부동소수점 잔차가 남습니다.
        // 그대로 두면 상세 팝업 콘텐츠 폭이 400pt에서 미세하게 벗어나 CPU·Memory 두 상세의 크기가 갈립니다.
        ProposedWidthLayout {
            VStack(spacing: CPUCoreGridLayout.cellSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: CPUCoreGridLayout.cellSpacing) {
                        ForEach(Self.assembly, id: \.self) { element in
                            switch element {
                            case .cells:
                                ForEach(row, id: \.self) { coreIndex in
                                    CPUCoreUsageCellView(coreIndex: coreIndex, usage: usages[coreIndex])
                                }
                            case .lastRowEmptySlots:
                                // 짧은 마지막 행에 같은 폭의 빈 자리를 채웁니다. 채우지 않으면 남은 칸들이 늘어나
                                // 마지막 행의 열이 위 행과 어긋납니다(DESIGN §5 DP2).
                                // 높이를 0으로 묶는 것은 `Color`가 세로로도 무한히 늘어나기 때문입니다 —
                                // 묶지 않으면 짧은 마지막 행이 있는 코어 수에서 격자의 필요 높이가 무한대가 됩니다.
                                ForEach(row.count..<columnCount, id: \.self) { _ in
                                    Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// 자식에게 제안 폭을 그대로 주되, 자식이 되돌린 폭 대신 제안 폭을 그대로 보고하는 레이아웃.
/// 자식 안에서 생긴 폭 오차가 상위 레이아웃의 폭 계산으로 새어 나가지 않습니다.
///
/// 폭 제안이 없거나 무한대인 측정(`fixedSize(horizontal: true, vertical: false)`)에서는
/// 자식이 되돌린 필요 폭을 그대로 보고합니다 — 무한대를 보고하면 필요 폭 측정이 무너집니다.
private struct ProposedWidthLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let subviewSize = subviews.first?.sizeThatFits(proposal) ?? .zero
        guard let width = proposal.width, width.isFinite else { return subviewSize }
        return CGSize(width: width, height: subviewSize.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        subviews.first?.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
        )
    }
}

/// 코어 격자의 칸 하나. 고정 높이 트랙 안에서 아래부터 차오르는 막대와 같은 값의 화면 수치, 코어 번호를 담습니다.
///
/// 값이 0이면 채움을 그리지 않고 최소 채움 높이도 두지 않습니다 — 쉬고 있는 코어가 활동하는 것처럼
/// 보이지 않게 하는 대신, 0%와 1%의 구분은 같은 칸의 수치가 맡습니다(DESIGN §5 DP2).
// task-007이 production 칸과 요소 하나를 뺀 기준을 직접 렌더해 견주므로 기본 접근 수준으로 둡니다.
struct CPUCoreUsageCellView: View {
    let coreIndex: Int
    let usage: Double

    enum AssemblyElement: CaseIterable {
        case bar
        case valueText
        case coreNumber

        var newDisplayElements: [DetailPopoverNewDisplayElement] {
            switch self {
            case .bar: BarAssemblyElement.allCases.map(\.newDisplayElement)
            case .valueText: [.coreValueText]
            case .coreNumber: [.coreNumber]
            }
        }
    }

    enum BarAssemblyElement: CaseIterable {
        case track
        case fill

        var newDisplayElement: DetailPopoverNewDisplayElement {
            switch self {
            case .track: .coreBarTrack
            case .fill: .coreBarFill
            }
        }
    }

    /// 칸의 `body`가 실제로 순회하는 조립 항목입니다.
    static let assembly = AssemblyElement.allCases

    /// 칸 안 세 줄 사이 간격. 칸 높이(막대 20 + 2 + 값 줄 15 + 2 + 코어 번호 13 = 52pt)가 이 값에서 나옵니다.
    static let rowSpacing = DashboardStyle.Spacing.withinGroup
    static let cornerRadius: CGFloat = 2

    var body: some View {
        VStack(spacing: Self.rowSpacing) {
            ForEach(Self.assembly, id: \.self) { element in
                switch element {
                case .bar:
                    ZStack(alignment: .bottom) {
                        ForEach(BarAssemblyElement.allCases, id: \.self) { barElement in
                            switch barElement {
                            case .track:
                                Rectangle().fill(DashboardColorPalette.cpuCoreTrack)
                            case .fill:
                                Rectangle()
                                    .fill(DashboardColorPalette.cpuCoreFill(CPUCoreUsageStep.step(for: usage)))
                                    .frame(height: fillHeight)
                            }
                        }
                    }
                    .frame(height: CPUCoreGridLayout.barHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
                case .valueText:
                    Text(CPUCoreUsageFormatting.valueText(usage))
                        .dashboardTypography(DashboardStyle.TypographyRole.value)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                case .coreNumber:
                    Text(CPUCoreUsageFormatting.coreNumberText(coreIndex: coreIndex))
                        .dashboardTypography(DashboardStyle.TypographyRole.heading)
                }
            }
        }
        .frame(maxWidth: .infinity)
        // macOS에서 합쳐진 컨테이너의 기본 AXGroup은 `accessibilityValue`를 내보내지 않으므로,
        // 칸을 static text로 노출해 이름과 값을 분리한 채 AXValue가 실리게 합니다.
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(CPUCoreUsageFormatting.accessibilityLabel(coreIndex: coreIndex))
        .accessibilityValue(CPUCoreUsageFormatting.accessibilityValue(usage))
        .accessibilityIdentifier(CPUCoreUsageFormatting.cellAccessibilityIdentifier(coreIndex: coreIndex))
    }

    /// 트랙 높이에 대한 값의 비율. 100%를 넘는 값은 트랙을 넘지 않게 자릅니다.
    private var fillHeight: CGFloat {
        CPUCoreGridLayout.barHeight * min(max(CGFloat(usage) / 100, 0), 1)
    }
}

/// Memory 상세: 구성 도넛·수치 범례, Swap 사용량과 증가량, 앱 목록(현재 사용량 순위와
/// 하위 프로세스를 겸함), 최근 증가량 순위(SPEC §5.2, SPEC §5.4, SPEC §5.8, ANALYSIS §5 DP1, DP6).
// `private`가 아닌 것은 task-004 테스트가 CPU 상세와 나란히 렌더해 두 상세가 같은 앱 목록을
// 그리는지 보기 때문입니다.
struct MemoryDetailView: View {
    let presentation: MemoryCardPresentation
    let iconProvider: any ApplicationIconProviding

    /// 상세 구역 사이 간격. CPU 상세·두 카드와 같은 자리를 참조합니다.
    static let sectionSpacing = DashboardStyle.Section.betweenSections
    /// 증가량 순위 구역의 머리글과 목록 사이 간격.
    static let recentIncreaseHeadingSpacing = DashboardStyle.Section.headingToContent

    var body: some View {
        let detail = presentation.detail
        let summary = presentation.compositionDetailSummary
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            MemoryCompositionDonutView(
                layout: presentation.compositionDonutLayout,
                legendRows: MemoryCompositionDetailLegendFormatting.rows(bytes: detail.compositionBytes),
                centerLabel: summary.donutCenter.label,
                centerValue: DashboardValueColumn.byteText(summary.donutCenter.bytes),
                accessibilityLabel: presentation.compositionDonutAccessibilityLabel
            )

            VStack(alignment: .leading, spacing: DashboardStyle.Spacing.withinGroup) {
                Text("\(summary.usedLine.label) \(DashboardValueColumn.byteText(summary.usedLine.bytes))")
                    .dashboardTypography(DashboardStyle.TypographyRole.value)

                // Swap 사용량과 증가량은 `detail`이 아니라 카드 요약과 공유하는 `presentation` 최상위 필드입니다
                // (task-009가 만든 계산을 그대로 재사용). 변화량이 없으면(10분 창 안에 기준점이 없으면) `nil`이고,
                // 그 경우를 0으로 표시하지 않습니다. 변화량은 음수일 수 있으므로 증가량 순위와 같은 부호 보존
                // 서식을 씁니다.
                if let change = presentation.swapRecentChangeBytes {
                    Text("Swap \(DashboardValueColumn.byteText(presentation.swapUsedBytes)) (\(DashboardValueColumn.signedBytes(change).text))")
                        .dashboardTypography(DashboardStyle.TypographyRole.value)
                } else {
                    Text("Swap \(DashboardValueColumn.byteText(presentation.swapUsedBytes))")
                        .dashboardTypography(DashboardStyle.TypographyRole.value)
                }
            }

            VStack(alignment: .leading, spacing: Self.recentIncreaseHeadingSpacing) {
                Text("최근 10분 증가량 순위")
                    .dashboardTypography(DashboardStyle.Section.headingRole)
                // 증가량은 음수일 수 있으므로 `TopApplicationsView`가 기본 카드에 쓰는 `UInt64` 변환 경로를
                // 그대로 재사용하지 않고, 부호를 보존하는 별도 포맷을 씁니다.
                // 이 목록만 상세 정원(20)까지 받으므로 카드 정원 문구와 다른 문구가 필요합니다 — 정원을
                // 뷰가 고르지 않도록, 조립 시점에 이미 만들어진 문구(`detail.recentIncreaseRankingCaption`)를 그대로 씁니다.
                TopApplicationsView(
                    entries: detail.recentIncreaseRanking,
                    caption: detail.recentIncreaseRankingCaption,
                    value: { DashboardValueColumn.signedBytes(Int64($0.value.rounded())) },
                    iconProvider: iconProvider
                )
            }

            ApplicationProcessGroupListView(
                groups: detail.applications,
                sortDescription: detail.applicationsHeading,
                exclusionNote: detail.applicationsExclusionNote,
                // Memory는 항상 값이 있지만(SPEC §5.6과 달리 기준점이 필요 없음), nil 안전 경로는
                // `ApplicationProcessValueFormatting`(단위 테스트 대상)을 CPU와 공유합니다.
                groupValue: ApplicationProcessValueFormatting.memoryGroupValueText,
                iconProvider: iconProvider
            ) { process in
                DashboardValueColumn.byteText(process.residentBytes)
            }
        }
    }
}

/// 카드와 공유한 구성 구간을 12시 방향부터 시계 방향으로 그리는 상세 도넛과 수치 범례.
struct MemoryCompositionDonutView: View {
    let layout: MemoryCompositionDonutLayout
    let legendRows: [MemoryCompositionDetailLegendRow]
    let centerLabel: String
    let centerValue: String
    let accessibilityLabel: String

    /// 범례에 남는 폭을 상세 후보 크기에서 유도해 재는 task-007 테스트와 공유합니다.
    static let diameter: CGFloat = 140
    private static let lineWidth: CGFloat = 18

    /// 범례 이름 열의 폭. 네 구간 이름(App / Wired / Compressed / Cached)을 `label` 역할로 실측한
    /// 이상적 폭의 최댓값이며, 이보다 좁히면 가장 긴 이름이 잘리거나 접혀 네 행의 값 열이 어긋납니다.
    /// 이름이 바뀌거나 늘면 다시 재야 하고, 단위 테스트가 네 이름을 다시 재서 이 폭 안에 드는지 확인합니다.
    static let legendNameWidth: CGFloat = 67

    var body: some View {
        HStack(alignment: .center, spacing: DashboardStyle.Spacing.betweenSections) {
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

                VStack(spacing: DashboardStyle.Spacing.withinGroup) {
                    Text(centerLabel)
                        .dashboardTypography(DashboardStyle.TypographyRole.label)
                    Text(centerValue)
                        .dashboardTypography(DashboardStyle.TypographyRole.value)
                }
            }
            .frame(width: Self.diameter, height: Self.diameter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityIdentifier("MemoryCompositionDonut")

            VStack(alignment: .leading, spacing: DashboardStyle.Spacing.labelToContent) {
                ForEach(Array(legendRows.enumerated()), id: \.offset) { _, row in
                    legendRow(row)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 실제 범례와 같은 한 행을 렌더 측정할 수 있게 조립을 한 곳에 둡니다.
    func legendRow(_ row: MemoryCompositionDetailLegendRow) -> some View {
        HStack(spacing: DashboardStyle.Spacing.labelToContent) {
            Image(systemName: "square.fill")
                .foregroundStyle(DashboardColorPalette.memoryComposition(row.category))
            Text(row.label)
                .frame(width: Self.legendNameWidth, alignment: .leading)
            DashboardAlignedValueView(value: row.value)
            Spacer(minLength: 0)
        }
        .dashboardTypography(DashboardStyle.TypographyRole.label)
    }
}

/// 앱별 하위 프로세스 목록. 앱 항목을 펼치면(`DisclosureGroup`) 그 앱으로 묶인 프로세스가 나타납니다
/// (ANALYSIS §2 「팝오버 열림과 카드 선택」, SPEC §5.2, SPEC §5.6). CPU·Memory 상세가 표시할 값만
/// `groupValue`·`valueText`로 다르게 넘깁니다.
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
// `private`가 아닌 것은 task-004 테스트가 이 목록을 직접 렌더해 접힌 앱 행 사이 간격을 재기 때문입니다 —
// 마지막 하위 행과 다음 앱 행 사이 간격에 이 목록의 행 간격이 더해집니다.
struct ApplicationProcessGroupListView: View {
    let groups: [ApplicationProcessGroup]
    /// 목록이 어떤 값으로, 어떤 방향으로 정렬됐는지 알리는 머리글.
    let sortDescription: String
    /// 머리글 바로 아래 줄에 붙는 안내. 시스템 프로세스가 순위에서 빠진다는 사실을 두 상세 모두에서 알립니다.
    let exclusionNote: String
    /// 앱 행에 표시할 그룹 합계 값의 서식. `nil`(값을 만들지 못한 그룹)을 0으로 지어내지 않습니다(SPEC §5.6).
    let groupValue: (Double?) -> DashboardValueColumn.Value
    let iconProvider: any ApplicationIconProviding
    let valueText: (ApplicationProcessDetail) -> String

    static let headingSpacing = DashboardStyle.Section.headingToContent
    /// 머리글과 안내 줄 사이 간격. 두 줄이 하나의 머리글 묶음으로 읽히도록 머리글과 내용 사이보다 좁습니다.
    static let noteSpacing = DashboardStyle.Spacing.withinGroup
    static let rowSpacing = DashboardStyle.Spacing.withinGroup
    static let contentLeadingPadding = DashboardStyle.Spacing.betweenGroups

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
        VStack(alignment: .leading, spacing: Self.headingSpacing) {
            VStack(alignment: .leading, spacing: Self.noteSpacing) {
                Text(sortDescription)
                    .dashboardTypography(DashboardStyle.Section.headingRole)
                Text(exclusionNote)
                    .dashboardTypography(DashboardStyle.TypographyRole.label)
            }

            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                ForEach(displayedGroups, id: \.key) { group in
                    ApplicationProcessGroupRow(
                        group: group,
                        groupValue: groupValue,
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
        }
        .padding(.leading, Self.contentLeadingPadding)
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
// `private`가 아닌 것은 task-004 테스트가 이 행을 펼친 채로 직접 렌더해 하위 행의 시작 x와
// 세 경계 간격을 재기 때문입니다 — 펼침 상태는 목록의 `@State`라 목록 쪽에서는 펼칠 수 없습니다.
struct ApplicationProcessGroupRow: View {
    let group: ApplicationProcessGroup
    let groupValue: (Double?) -> DashboardValueColumn.Value
    let valueText: (ApplicationProcessDetail) -> String
    let iconProvider: any ApplicationIconProviding
    @Binding var isExpanded: Bool

    enum AssemblyElement: CaseIterable {
        case childNameLine
        case childValueLine
        case boundarySpacings

        var newDisplayElements: [DetailPopoverNewDisplayElement] {
            switch self {
            case .childNameLine: [.childNameIndent]
            case .childValueLine: [.childValueIndent]
            case .boundarySpacings: [.childBoundarySpacings]
            }
        }
    }

    /// 펼친 내용의 `body`와 여백 적용이 함께 소비하는 production 조립 항목입니다.
    static let assembly = AssemblyElement.allCases

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            // macOS `DisclosureGroup`은 펼친 내용에 들여쓰기도 위아래 여백도 주지 않으므로, 하위 행이
            // 부모 앱 이름보다 왼쪽에서 시작하고 부모 행에 그대로 달라붙습니다. 네 경계와 두 시작선을
            // 이 `VStack`이 전부 만듭니다 — 상수만 두고 이 여백을 걸지 않으면 화면은 그대로 붙어 있습니다.
            VStack(alignment: .leading, spacing: ApplicationProcessRowLayout.betweenChildren) {
                ForEach(group.processes, id: \.pid) { process in
                    VStack(alignment: .leading, spacing: ApplicationProcessRowLayout.withinChildRow) {
                        ForEach(Self.assembly.filter { $0 != .boundarySpacings }, id: \.self) { element in
                            switch element {
                            case .childNameLine:
                                Text("\(process.executableName) (PID \(process.pid))")
                                    .padding(.leading, ApplicationProcessRowLayout.childIndent)
                                    .accessibilityLabel(
                                        ApplicationProcessRowFormatting.childAccessibilityLabel(
                                            applicationDisplayName: group.displayName,
                                            process: process
                                        )
                                    )
                            case .childValueLine:
                                Text(valueText(process))
                                    .padding(.leading, ApplicationProcessRowLayout.childValueIndent)
                            case .boundarySpacings:
                                EmptyView()
                            }
                        }
                    }
                    .dashboardTypography(DashboardStyle.TypographyRole.label)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Self.assembly.contains(.boundarySpacings) ? ApplicationProcessRowLayout.parentToFirstChild : 0)
            .padding(.bottom, Self.assembly.contains(.boundarySpacings) ? ApplicationProcessRowLayout.afterLastChild : 0)
        } label: {
            HStack(spacing: ApplicationProcessRowLayout.labelIconSpacing) {
                ApplicationRowIconView(
                    content: ApplicationRowIconLayout.content(for: group.key, from: iconProvider),
                    pointSize: ApplicationRowIconLayout.detailPointSize
                )
                Text(group.displayName)
                Spacer()
                DashboardAlignedValueView(value: groupValue(group.sortValue))
            }
            // 라벨 전체를 탭 대상으로 만들어, 기본 동작(삼각형만 반응)과 달리 라벨 텍스트·값·빈 공간을
            // 눌러도 펼침·접힘이 토글되게 합니다. 삼각형 자체의 기본 탭 동작은 그대로 남아 있어 둘 다 동작합니다.
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
        }
        .dashboardTypography(DashboardStyle.TypographyRole.label)
        // 목록이 매 tick 다시 정렬되므로, 화면 위치가 아니라 앱 키로 특정 행을 계속 가리킬 수 있도록
        // 안정적인 식별자를 붙입니다(XCUITest가 재정렬 사이에도 같은 행을 추적하는 데 씁니다).
        .accessibilityIdentifier("AppRow-\(group.key.value)")
    }
}

#Preview {
    DashboardView(store: DashboardPresentationStore(), iconProvider: ApplicationIconCache())
}
