# 상세 팝업 가독성 설계

## 근거

spec.md는 §1부터 §5까지 전부 읽었습니다.
범위는 §1이 제한하는 두 자리 — 하위 프로세스 행의 시각적 구분과 논리 코어별 사용률 표현 — 뿐이고, 여기에 요구사항을 더하지 않았습니다.

### 코드에서 확인한 사실

- `ResourceRunner/DashboardView.swift:917`이 논리 코어별 사용률을 `presentation.detail.coreUsages.map(pct).joined(separator: ", ")` 한 줄 `Text`로 그립니다.
  `pct`는 `Int(value.rounded())`라 정수 퍼센트입니다.
- `CPUDetailView`(같은 파일 `:908`)는 `VStack(alignment: .leading, spacing: 6)` 안에 요약 줄 · 코어 줄 · Load Average · 앱 목록 넷을 순서대로 둡니다.
- `ApplicationProcessGroupListView`(`:1110`)는 `VStack(alignment: .leading, spacing: 2)`에 머리글과 앱 행을 담고 목록 전체에 `.padding(.leading, 8)`을 겁니다.
  그 8pt는 `DisclosureGroup` 삼각형이 `ScrollView` 클립 경계에 닿아 팝오버가 통째로 닫히던 결함의 대응이라 그대로 둡니다.
- `ApplicationProcessGroupRow`(`:1170`)는 `DisclosureGroup`을 쓰고, 펼친 내용이 `ForEach`만으로 나열되어 간격 지정이 없습니다.
  라벨은 `HStack(spacing: 6)`에 `ApplicationRowIconLayout.detailPointSize` 아이콘 · 이름 · `Spacer` · 값을 담고, `.contentShape(Rectangle())`과 `.onTapGesture`로 라벨 전체가 토글 대상입니다.
  행 식별자는 `AppRow-<앱 키>`입니다.
- `ApplicationRowIconLayout.detailPointSize`는 `ApplicationIconCache.displayPointSize` = **16pt**입니다.
- `DashboardView.detailPopupWidth`·`detailPopupHeight`는 400·480이고, 두 상세 팝업 모두 `.frame(width:height:)`를 상태 분기 **밖**에 무조건 걸고 있습니다.
- `CPUDetailPopoverContent`·`MemoryDetailPopoverContent`는 `.normal`일 때만 상세 뷰를 그리고, 나머지 세 상태에서는 안내 문구 `Text` 하나만 그립니다.
- `CPUCardDetail.coreUsages`는 `[Double]`이고, `CPUSystemMetricsCollector`는 코어 배열을 만들 수 없는 모든 경우(기준점 없음 · 간격 초과 · 코어 수 변화 · 카운터 되감김 · 전체 tick 0)에 `nil`을 돌려줍니다.
  따라서 `.normal` 상태에서 `coreUsages`가 비거나 코어가 누락되는 경우는 없고, 진행하지 않은 코어도 0으로 자리를 채웁니다.
- `ApplicationProcessValueFormatting.cpuProcessValueText`는 값이 없으면 `"-"`, Rosetta 프로세스에는 `"10% · Rosetta"` 형태를 돌려줍니다.
- `DashboardColorPalette`의 계열 색은 색맹 시뮬레이션·명도대비 검증기를 통과한 조합이라 바꾸면 재검증이 필요합니다.
  반면 `cpuGridline`·`memoryCompositionTrack`은 「다른 색과 구분할 필요가 없는 배경 대비 요소」라는 이유로 시스템 색을 그대로 씁니다.

### 실측한 값

`NSHostingController.sizeThatFits`와 `ImageRenderer` 픽셀 probe로 이 기기에서 직접 쟀습니다(앞 feature `DashboardCardLayoutTests`가 쓰는 것과 같은 수단).

- `.padding()` 기본값은 좌우 각 **16pt**입니다(폭 증가 32.0). 따라서 상세 팝업의 콘텐츠 폭은 **368pt**, 앱 목록 안쪽은 `.padding(.leading, 8)`을 뺀 **360pt**입니다.
- `.caption`·`.caption2` 한 줄 높이는 둘 다 **13.0pt**입니다.
- `.caption2` 기준 `"100%"` = **28.0pt**, `"123.4%"` = 37.0pt, `"100% · Rosetta"` = **75.0pt**, `"12.3% · Rosetta"` = **78.0pt**입니다.
- `.caption2` 기준 하위 행의 긴 이름 `"Google Chrome Helper (Renderer) (PID 12345)"` = **231.0pt**입니다.
- macOS `DisclosureGroup`은 **펼친 내용에 들여쓰기를 전혀 주지 않습니다** — 픽셀 probe로 라벨 아이콘의 시작 x = **12.0pt**(삼각형이 차지하는 폭), 펼친 내용의 시작 x = **0.0pt**였습니다.
  즉 지금 하위 행은 부모 앱 이름(12 + 16 + 6 = 34pt)보다 34pt 왼쪽에서, 삼각형보다도 12pt 왼쪽에서 시작합니다.
- 현재 세 경계의 실제 간격은 **0 / 2 / 2pt**입니다.
  접힘 행 24.0pt에 하위 1개는 +13.0(부모–첫 하위 0), 2개는 +28.0, 3개는 +43.0(하위끼리 2), 그리고 목록 `VStack`의 `spacing: 2`가 마지막 하위–다음 앱을 2로 만듭니다.
- 현재 코어 줄은 368pt 폭에서 14코어일 때 **26.0pt**(두 줄로 접힘)입니다.

### 격자 후보의 실측

칸을 「막대(18pt) · 수치 · 코어 번호」 세 줄로 두고 칸 간격 6pt, 열 상한 8로 잡아 쟀습니다.

| 코어 수 | 열 | 행 | 칸 폭 | 격자 높이 |
| ---: | ---: | ---: | ---: | ---: |
| 8 | 8 | 1 | 40.8 | 48.0 |
| 10 | 5 | 2 | 68.8 | 102.0 |
| 14 | 7 | 2 | 47.4 | 102.0 |
| 16 | 8 | 2 | 40.8 | 102.0 |
| 24 | 8 | 3 | 40.8 | 156.0 |
| 32 | 8 | 4 | 40.8 | 210.0 |
| 64 | 8 | 8 | 40.8 | 426.0 |

팝업 위끝에서 격자 아래끝까지는 `16(상단 padding) + 13(요약 줄) + 6 + 13(격자 머리글) + 4 + 격자 높이`입니다 — 14코어 **154pt**, 24코어 208pt, 64코어 478pt입니다.

### 기존 테스트가 잠그고 있는 것

- `DashboardDetailExpansionUITests`와 `DashboardProcessListDisplayUITests`는 앱 행을 `app.popovers.descendants(matching: .disclosureTriangle)`로 찾고, 펼침을 `(triangle.value as? NSNumber)?.intValue == 1`로 판정합니다.
  즉 두 스위트가 `DisclosureGroup`이 만드는 `AXDisclosureTriangle` 요소와 그 AX value에 직접 매여 있습니다.
- 같은 두 스위트가 하위 행을 `app.popovers.staticTexts`의 `value CONTAINS "PID"`로 찾습니다 — 하위 행 이름 `Text`의 **AX value**가 화면 문자열 그대로여야 성립합니다.
- `DashboardDetailPopoverUITests`는 두 상세의 `DashboardDetail` 프레임 크기가 같은지, 스크롤 전후에 그 프레임이 그대로인지, `"Load Average"` `staticText`가 `popovers` 아래에 있는지를 단언합니다.
- `DashboardCardLayoutTests`는 **카드**만 렌더링합니다(CPU 243.0pt, Memory 181.0pt). 상세 팝업 높이를 단언하는 단위 테스트는 없습니다.
  코어별 사용률 문자열이나 하위 행 문자열을 직접 단언하는 단위 테스트도 없습니다.

### 의존 탐색 흔적 (§4의 근거)

- `ApplicationProcessGroupListView` 호출부는 `CPUDetailView`(`:926`)와 `MemoryDetailView`(`:1003`) 둘뿐입니다. 따라서 하위 행 변경은 CPU·Memory 상세 양쪽에 동시에 반영됩니다.
- `ApplicationProcessGroupRow`를 조립하는 곳은 `ApplicationProcessGroupListView`(`:1138`) 하나뿐입니다.
- `CPUDetailView`를 그리는 곳은 `CPUDetailPopoverContent`(`:868`) 하나뿐입니다.
- `coreUsages`를 화면으로 옮기는 곳은 `DashboardView.swift:917` 하나뿐이고, 나머지 참조는 수집·조립 경로(`SystemMetrics`·`CPUSystemMetricsCollector`·`DashboardPresentation:196`)와 테스트 픽스처입니다.
  표시 계층 밖은 건드리지 않습니다.
- `DashboardColorPalette`를 쓰는 production 파일은 `DashboardView.swift` 하나입니다.

### 추정으로 남는 것

- 픽셀 probe로 얻은 `DisclosureGroup` 삼각형 폭 12.0pt는 이 macOS 버전에서 잰 값입니다. OS가 이 값을 바꾸면 하위 행과 부모 이름의 정렬이 그만큼 어긋납니다.
- 하위 행을 하나의 접근성 요소로 합치면 AX value가 사라져 위 두 UI 스위트의 `value CONTAINS "PID"` 조회가 깨질 것으로 봅니다. 이 환경에서 XCUITest를 돌려 확인하지는 못했습니다.
- macOS 스크롤 막대를 「항상 표시」로 둔 환경에서는 레거시 스크롤러가 콘텐츠 폭을 15pt 안팎 줄일 수 있습니다. 그 경우까지 칸 폭 여유를 남겨 뒀지만 그 설정으로 재보지는 않았습니다.

## 1. 구조

새 모듈이나 레이어를 만들지 않습니다.
변경은 전부 Presentation 계층 안에서 끝나고, Application·Collectors 경계는 그대로입니다.

이 프로젝트는 「계산은 순수 함수로 빼고 뷰는 소비만 한다」를 이미 `MemoryCompositionLayout.make`·`MemoryCompositionDonutLayout.make`·`ApplicationProcessGroupOrdering.displayedGroups`·`ApplicationRowIconLayout`에서 지키고 있습니다.
코어 격자의 행·열 분할과 하위 행의 들여쓰기·간격도 그 자리에 넣습니다 — 둘 다 뷰 본문에 두면 코어 수나 행 수를 바꿔 가며 확인할 방법이 렌더링밖에 남지 않기 때문입니다.

경계는 넷입니다.

- **배치 계산** — `CPUCoreGridLayout`이 코어 수 하나만 받아 행별 코어 인덱스 묶음과 열 수를 돌려줍니다.
  가용 폭은 인자로 받지 않고, 폭에서 유도한 열 상한 하나만 상수로 들고 있습니다(§5 DP1).
  `ApplicationProcessRowLayout`이 하위 행의 들여쓰기와 세 경계의 간격을 상수로 들고 있고, 들여쓰기는 `ApplicationRowIconLayout.detailPointSize`와 라벨 `HStack`의 간격에서 유도합니다(§5 DP5).
- **문자열 서식** — `CPUCoreUsageFormatting`이 칸의 화면 수치, 격자 머리글, 코어 칸의 접근성 이름과 값을 만듭니다.
  `ApplicationProcessRowFormatting`이 하위 행의 접근성 이름(소속 앱을 포함한)을 만듭니다.
  접근성 이름을 순수 함수로 빼는 이유는 앞 feature가 확인한 사실 때문입니다 — SwiftUI 접근성 트리는 `NSHostingController` 안에서 실체화되지 않아, 문자열 자체는 단위 테스트로만 잡을 수 있습니다(`SPEC §5.7`).
- **표시** — `CPUCoreUsageGridView`를 새로 두고 `CPUDetailView`의 코어 줄 `Text` 한 줄을 이 뷰로 바꿉니다.
  이 뷰는 `[Double]`을 받아 위 두 순수 자리가 정한 행·열과 문자열을 좌표와 그리기로 옮기기만 합니다(`SPEC §5.3`, `SPEC §5.4`).
  `ApplicationProcessGroupRow`는 `DisclosureGroup`을 그대로 유지한 채(§5 DP7) 펼친 내용을 `VStack`으로 감싸고 `ApplicationProcessRowLayout`이 정한 들여쓰기·간격을 겁니다(`SPEC §5.1`, `SPEC §5.2`).
  `ApplicationProcessGroupListView`는 바뀌지 않습니다 — 펼침 상태와 순서 고정을 들고 있는 자리라 손대면 `SPEC §5.6`이 잠근 동작이 흔들립니다.
- **색** — 코어 막대의 트랙·채움 색을 `DashboardColorPalette`에 더합니다(§5 DP11).

## 2. 데이터 흐름

새 상태를 만들지 않습니다. 이 feature가 더하는 것은 기존 값이 화면으로 가는 마지막 구간뿐입니다.

코어 격자의 경로는 이렇습니다.

`MonitoringScheduler` tick → `CPUSystemMetricsCollector`가 `coreUsages: [Double]`을 만듦 → `ApplicationCoordinator` → `CPUCardPresentation.assemble`이 `CPUCardDetail.coreUsages`로 그대로 옮김 → `DashboardPresentationStore.cpuCard` → `DashboardView` → `CPUDetailPopoverContent`가 상태를 가름 → (`.normal`일 때만) `CPUDetailView` → `CPUCoreUsageGridView` → `CPUCoreGridLayout.rows(coreCount:)`가 행·열을 정하고 `CPUCoreUsageFormatting`이 문자열을 만듦 → 칸 렌더.

하위 프로세스 행의 경로는 이렇습니다.

`ProcessSurveyCollector` → `ProcessHistoryStore` → `ApplicationRanking.groupByApplication` → `ApplicationRanking.sortedForDisplay` → `CPUCardDetail.applications`(Memory는 `MemoryCardDetail.applications`) → `ApplicationProcessGroupListView` → `ApplicationProcessGroupOrdering.displayedGroups`가 순서를 정함 → `ApplicationProcessGroupRow` → `DisclosureGroup` 라벨(부모)과 내용(하위) → `ApplicationProcessRowLayout`의 들여쓰기·간격 적용.

도달 가능한 상태는 이미 있는 둘뿐이고 둘 다 이 feature가 새로 만들지 않습니다.

- `ResourceCardState`의 네 경우 — `collecting` · `normal` · `failure(lastKnown:)` · `stopped(lastKnown:)`.
  전이는 수집 결과(정상·실패)와 생명주기 경계(중지·재개)가 일으키며 팝업 표시가 일으키지 않습니다.
  `CPUDetailPopoverContent`는 이 넷 중 `.normal`에서만 상세 본문을 그리고 나머지 셋에서는 안내 문구 하나를 그립니다.
  코어 격자와 하위 행은 `.normal` 안쪽에만 있으므로 상태가 오갈 때 팝업의 크기를 바꾸는 요소가 되지 않습니다 — 크기는 `.frame(width:height:)`가 상태 분기 밖에서 고정합니다(`SPEC §5.5`, §5 DP9).
- `ApplicationProcessGroupListView.expandedKeys`의 펼침 여부 — 전이는 행 라벨 탭과 삼각형 탭 둘뿐입니다.
  펼친 행이 하나라도 있으면 `stableOrder`가 그 순간의 순서를 붙잡아 목록이 매 tick 재정렬돼도 행이 자리를 옮기지 않고, 모두 접히면 다시 최신 순서를 따릅니다.
  이 경로를 그대로 두므로 펼친 상태가 목록 갱신 사이에 유지되고, 펼침으로 늘어난 높이는 팝업 프레임이 아니라 그 안의 `ScrollView` 콘텐츠 높이만 바꿉니다(`SPEC §5.6`).

실패 경로는 새로 생기지 않습니다.
코어 배열을 만들 수 없는 tick은 수집 단계에서 이미 `nil`이 되어 카드 상태가 `.normal`에 들어오지 못하므로, 격자가 빈 배열을 받는 분기는 도달할 수 없습니다.
프로세스 값이 없는 하위 행은 지금처럼 `ApplicationProcessValueFormatting`이 `"-"`로 그리고, 이 feature는 그 규칙을 건드리지 않습니다.

## 3. 인터페이스

경계를 가로지르는 것만 둡니다.

- `CPUCoreGridLayout.maximumColumnCount: Int` — 콘텐츠 폭 368pt에서 유도한 열 상한. 폭이 아니라 이 상수 하나만 뷰 밖에 노출합니다.
- `CPUCoreGridLayout.rows(coreCount: Int) -> [[Int]]` — 코어 인덱스를 행별로 묶어 돌려줍니다. 모든 행의 길이가 같거나, 마지막 행만 짧습니다. `coreCount == 0`이면 빈 배열입니다.
- `CPUCoreGridLayout.barHeight: CGFloat` · `cellSpacing: CGFloat` — 칸 막대의 트랙 높이와 칸 사이 간격.
- `CPUCoreUsageFormatting.valueText(_ usage: Double) -> String` — 칸에 보이는 정수 퍼센트. 지금 `pct`가 쓰는 반올림 규칙을 그대로 씁니다.
- `CPUCoreUsageFormatting.headingText(coreCount: Int) -> String` — 격자 머리글. 코어 수를 문자열 안에 직접 박지 않고 인자에서 만듭니다.
- `CPUCoreUsageFormatting.accessibilityLabel(coreIndex: Int) -> String` · `accessibilityValue(_ usage: Double) -> String` — 코어 칸의 접근성 이름과 값(`SPEC §5.7`).
- `CPUCoreUsageFormatting.cellAccessibilityIdentifier(coreIndex: Int) -> String` — 칸별 안정 식별자. `AppRow-<앱 키>`와 같은 관례를 따라 UI 테스트가 특정 칸을 가리킬 수 있게 합니다.
- `ApplicationProcessRowLayout.childIndent: CGFloat` — 하위 행의 왼쪽 들여쓰기. `DisclosureGroup` 삼각형 폭 + `ApplicationRowIconLayout.detailPointSize` + 라벨 `HStack` 간격에서 유도합니다.
- `ApplicationProcessRowLayout.betweenChildren: CGFloat` · `parentToFirstChild: CGFloat` · `afterLastChild: CGFloat` — `SPEC §5.1`이 말하는 세 경계의 간격. 마지막 값은 목록 `VStack`의 `spacing: 2` 위에 더해지는 몫입니다.
- `ApplicationProcessRowFormatting.childAccessibilityLabel(applicationDisplayName: String, process: ApplicationProcessDetail) -> String` — 하위 행 이름 요소의 접근성 이름. 소속 앱을 포함합니다(`SPEC §5.7`).
- `DashboardColorPalette.cpuCoreTrack: Color` · `cpuCoreFill: Color` — 코어 막대의 트랙과 채움.
- `CPUCoreUsageGridView(usages: [Double])` — `CPUDetailView`가 코어 줄 자리에 두는 뷰.

## 4. 영향 범위

- `ResourceRunner/DashboardView.swift`
  - `CPUDetailView` — 코어 줄 `Text` 한 줄을 격자 머리글 + `CPUCoreUsageGridView`로 바꿉니다. `VStack`의 나머지 세 자리는 그대로입니다.
  - `ApplicationProcessGroupRow` — `DisclosureGroup` 내용의 `ForEach`를 `VStack`으로 감싸고 들여쓰기·위아래 여백을 겁니다. 라벨·`contentShape`·`onTapGesture`·`AppRow-<앱 키>` 식별자는 손대지 않습니다.
  - `CPUCoreUsageGridView` 신설.
  - `ApplicationProcessGroupListView`는 바뀌지 않지만, 이 목록을 통해 변경이 `MemoryDetailView`에도 그대로 반영됩니다(호출부 탐색에서 두 곳 확인).
- `ResourceRunner/DashboardPresentation.swift` — `CPUCoreGridLayout`·`CPUCoreUsageFormatting`·`ApplicationProcessRowLayout`을 더합니다. `MemoryCompositionLayout` 계열이 이미 이 파일에 있어 새 파일을 만들지 않습니다.
- `ResourceRunner/ApplicationRanking.swift` — `ApplicationProcessRowFormatting`을 더합니다. 값 서식 `ApplicationProcessValueFormatting`이 이 파일에 있어 하위 행 문자열 서식이 한자리에 모입니다. 기존 타입과 계산은 바꾸지 않습니다.
- `ResourceRunner/DashboardColorPalette.swift` — `cpuCoreTrack`·`cpuCoreFill` 둘을 더합니다. 기존 계열 색은 그대로라 색맹·대비 재검증 대상이 아닙니다.

호환성·마이그레이션 항목은 없습니다.
저장 형식도 외부 계약도 바뀌지 않고, 표시 계층 밖의 호출자가 없습니다.

## 5. Decision Points

### DP1. 코어 격자의 열 수를 어떻게 정하는가

고려한 옵션 셋입니다.

- **고정 열 수** — 늘 같은 열 수를 씁니다. 대가: 코어 8개면 한 행이 남고, 코어 10개·14개에서 마지막 행이 크게 비어 격자가 기울어 보입니다.
- **가용 폭에서 유도** — `GeometryReader`나 `LazyVGrid(.adaptive(minimum:))`로 폭이 허용하는 만큼 채웁니다. 대가: 열 수가 렌더 시점에만 정해져 순수 함수로 확인할 수 없고, 앞 feature가 「계산을 순수 함수로 뺀다」로 세운 관례를 이 자리에서만 깹니다.
- **코어 수에서 유도하고 폭이 정한 상한으로 자름** (채택) — 먼저 `행 수 = ⌈코어 수 ÷ 열 상한⌉`을 정하고, 다시 `열 수 = ⌈코어 수 ÷ 행 수⌉`로 되돌려 행을 고르게 나눕니다.

채택 근거는 두 단계 유도가 폭을 인자로 받지 않으면서도 행을 고르게 나눈다는 점입니다.
코어 14개는 8+6의 들쭉날쭉한 두 행이 아니라 7+7이 되고, 10개는 5+5, 24개는 8+8+8이 됩니다(실측 표).
열 상한만이 폭에서 유도된 값이고, 그 값은 상수 하나라 단위 테스트가 코어 수를 바꿔 가며 행·열을 직접 확인할 수 있습니다.

열 상한은 **8**로 확정합니다.
칸 하나는 화면 수치 `"100%"`(`.caption2` 실측 28.0pt)를 담아야 합니다.
콘텐츠 폭 368pt에 칸 간격 6pt를 두면 8열의 칸 폭은 **40.8pt**로 여유가 12.8pt이고, 스크롤 막대를 「항상 표시」로 둔 환경(폭 −15pt 가정)에서도 38.9pt로 여유가 남습니다.
10열이면 칸 폭이 31.4pt로 여유가 3.4pt뿐이라 배제했습니다.

코어 수가 열 상한보다 적으면 칸이 그만큼 넓어지고 칸 폭에 상한을 두지 않습니다.
대가는 코어가 아주 적은 기기(테스트 픽스처의 1코어 등)에서 칸 하나가 콘텐츠 폭을 다 차지하는 것인데, 상한 상수를 하나 더 두는 것보다 남는 폭을 균등하게 나누는 편이 「격자」로 읽히고 정렬 규칙도 하나로 유지됩니다.

### DP2. 코어 칸 하나를 무엇으로 그리는가

- **링** — 칸이 40pt 안팎이라 선 두께를 확보하면 안쪽에 수치를 넣을 자리가 없고, 여러 개를 늘어놓으면 어느 것이 높은지 각도로 비교해야 합니다.
- **채움 사각형(전체를 값 비율로 칠함)** — 채움 넓이가 값이라 면적 비교가 되지만, 부분 채움과 색 농도가 섞여 보여 「형태」로 읽히지 않습니다.
- **세로 막대(고정 트랙 안에서 아래부터 차오름)** (채택).

채택 근거는 여러 칸이 한 행에 놓일 때 채움 높이가 그대로 능선처럼 보여, 값을 하나씩 읽지 않고 분포를 알 수 있다는 점입니다(`SPEC §5.3`).
트랙 높이가 고정이라 값이 0이든 100이든 칸 높이가 같아, 값이 바뀌어도 격자와 그 아래 내용이 밀리지 않습니다(`SPEC §5.5`).

색 외 구분 수단은 **채움 높이**와 **같은 칸의 화면 수치** 둘입니다.
막대의 색은 값에 따라 바뀌지 않으므로 색이 정보를 나르는 자리가 아예 없습니다(§5 DP11).

트랙 높이는 **18pt**로 둡니다.
같은 칸의 수치 한 줄(13pt)보다 커야 형태가 수치보다 먼저 눈에 들어오고, 칸 전체 높이(18 + 2 + 13 + 2 + 13 = 48pt)가 §5 DP8이 계산한 세로 예산 안에 넉넉히 들어갑니다.

값이 0인 코어는 채움을 그리지 않고, 값이 있어도 채움이 1pt에 못 미치면 그만큼만 그립니다 — 최소 채움 높이를 두지 않습니다.
대가는 1~3% 코어와 0% 코어가 형태만으로는 구분되지 않는 것인데, 최소 채움을 두면 사실상 쉬고 있는 코어가 활동하는 것처럼 보여 이 프로젝트가 자리표시에서 지켜 온 「없는 값을 지어내지 않는다」와 부딪힙니다.
그 구간의 구분은 같은 칸의 수치가 담당합니다.

마지막 행이 짧으면 빈 칸 자리를 같은 폭의 투명 자리로 채워 열이 어긋나지 않게 합니다.
채우지 않으면 마지막 행의 칸들이 늘어나 위 행과 열이 맞지 않습니다.

### DP3. 코어 수치를 화면에 두는가, 접근성 이름에만 두는가

spec.md가 확정한 최소선은 「Hover 단독 금지, 화면의 형태와 접근성 이름으로 도달」입니다.
화면에 수치를 함께 둘지는 이 자리에서 정합니다.

- **접근성 이름에만 둔다** — 칸이 막대 + 코어 번호 두 줄로 줄어(35pt) 격자가 조용해집니다. 대가: 마우스 사용자가 정확한 값을 알려면 VoiceOver를 켜야 하고, 「대략 높다」에서 더 나아갈 수 없습니다.
- **화면에도 둔다** (채택).

채택 근거는 실측입니다.
`"100%"`는 `.caption2`에서 28.0pt이고 열 상한 8에서의 칸 폭은 40.8pt라 어느 코어 수에서도 잘리지 않습니다 — 앞 feature가 카드 폭 232pt에 345pt가 필요해 수치를 카드 밖으로 뺐던 상황과 정반대로, 여기서는 자리가 남습니다.
세로 예산도 문제가 되지 않습니다(§5 DP8).
따라서 수치를 감출 이유가 없고, `docs/product.md`의 「중요한 분석 정보는 Hover에만 의존하지 않습니다」를 화면 자체로 만족시킵니다(`SPEC §5.3`).

코어 번호도 화면에 둡니다.
번호가 없으면 「어느 코어가 높은지」를 자리로만 세어야 하고, 화면에서 본 것을 접근성 이름과 맞춰 볼 수단이 사라집니다.
칸 안의 순서는 막대 → 수치 → 번호입니다 — 번호를 맨 아래에 두면 격자 전체가 가로축 눈금이 달린 막대 그래프로 읽힙니다.

### DP4. 격자를 Lazy 컨테이너로 그리는가

- **`LazyVGrid`** — 열 정의만 주면 배치를 SwiftUI가 합니다. 대가: 화면 밖 행이 실체화되지 않아 접근성 요소가 스크롤 전에는 없고, 행·열 분할이 뷰 안에만 있어 코어 수를 바꿔 가며 확인하려면 렌더링해야 합니다.
- **`CPUCoreGridLayout`이 나눈 행을 `VStack` + `HStack`으로 그림** (채택).

채택 근거는 §1의 경계와 같습니다 — 행·열 분할이 순수 함수의 반환값이 되어 코어 수 8·10·14·16·24를 인자로 넣어 직접 확인할 수 있고, 코어 수가 최대 수십 개라 전부 그려도 비용이 문제 되지 않습니다.
칸 폭은 각 칸에 `maxWidth: .infinity`를 걸어 행 안에서 균등하게 나눕니다.

### DP5. 하위 행 들여쓰기를 얼마나 주는가

지금 문제는 실측이 드러냅니다 — macOS `DisclosureGroup`은 펼친 내용에 들여쓰기를 **0pt** 주고, 부모 앱 이름은 34pt(삼각형 12 + 아이콘 16 + 간격 6)에서 시작합니다.
하위 행이 부모 이름보다 34pt, 삼각형보다도 12pt 왼쪽에서 시작해 층이 뒤집혀 보입니다.

- **12pt(삼각형 폭만큼)** — 하위 행이 부모 아이콘과 같은 자리에서 시작합니다. 대가: 부모 이름과는 여전히 22pt 어긋나 어긋남을 절반만 없앱니다.
- **46pt(부모 이름 시작선 + 한 단)** — 층이 가장 뚜렷합니다. 대가: 실측으로 잘립니다 — 46 + 이름 231.0 + 간격 8 + 값 78.0(`"12.3% · Rosetta"`) = **363pt**로 앱 목록 안쪽 폭 **360pt**를 넘깁니다.
- **34pt(부모 앱 이름 시작선)** (채택).

채택 근거는 둘입니다.
첫째, spec.md §1이 지목한 문제 자체가 「부모 행에는 앱 아이콘이 있고 하위 행에는 없어 두 층의 시작 위치가 어긋나 있다」이고, 34pt는 그 어긋남을 정확히 0으로 만듭니다(`SPEC §5.1`).
둘째, 폭 예산이 남습니다 — 34 + 231.0 + 8 + 78.0 = **351pt**로 360pt 안에 들어가 가장 긴 하위 행도 잘리지 않습니다(`SPEC §5.2`).

34pt는 상수로 박지 않고 `ApplicationRowIconLayout.detailPointSize`(16)와 라벨 `HStack` 간격(6), 삼각형 폭(12)에서 유도합니다.
아이콘 크기가 바뀌면 들여쓰기가 따라가야 정렬이 유지되기 때문입니다.
삼각형 폭 12pt만은 OS가 정하는 값이라 실측한 상수로 남고, OS가 이 값을 바꾸면 정렬이 그만큼 어긋납니다 — 이것이 34pt 안이 지는 유일한 위험이며, 어긋나도 하위 행이 부모보다 왼쪽으로 나가지는 않으므로 층의 순서는 뒤집히지 않습니다.

층 구분을 색·구분선·배경으로 보강하는 선택지는 spec.md §4가 제외했으므로 검토 대상이 아닙니다.

### DP6. 세 경계의 간격을 얼마로 하는가

현재 실측은 **0 / 2 / 2pt**입니다 — 부모–첫 하위가 0이고 나머지 둘이 똑같아 세 경계가 층으로 읽히지 않습니다.

`SPEC §5.1`은 세 경계가 서로 같은 간격으로 보이지 않을 것을 요구합니다.
값을 임의로 고르는 대신 「경계가 넘는 층이 깊을수록 간격이 넓다」는 규칙 하나로 셋을 유도합니다.

- 하위끼리: **4pt** — 같은 앱 안이라 가장 좁습니다. 13pt 행이 17pt 간격으로 놓여 행마다 이름과 값을 눈으로 짚을 수 있습니다(`SPEC §5.2`).
- 부모–첫 하위: **10pt** — 앱 행에서 그 앱의 안쪽으로 들어가는 경계입니다.
- 마지막 하위–다음 앱: **16pt** — 앱 하나를 벗어나는 경계라 가장 넓습니다. 펼친 내용에 거는 여백 14pt와 목록 `VStack`의 기존 `spacing: 2`가 더해진 값입니다.

4 : 10 : 16은 두 배 이상씩 벌어져 눈으로도 구분됩니다.

목록 `VStack`의 `spacing: 2`는 그대로 둡니다.
그 값을 키우면 접힌 앱 행 사이까지 벌어져 상세 목록 전체가 길어지는데, spec.md가 지목한 문제는 펼친 뒤의 세 경계뿐입니다.
여백을 펼친 내용에만 걸면 접힌 목록의 밀도는 지금 그대로 유지되고, 세 번째 경계는 펼친 행에서만 넓어집니다.

### DP7. `DisclosureGroup`을 계속 쓰는가

- **자체 조립(삼각형 버튼 + 조건부 하위 목록)** — 내부 간격과 들여쓰기를 완전히 제어할 수 있습니다. 대가: 결정적입니다 — `DashboardDetailExpansionUITests`와 `DashboardProcessListDisplayUITests`가 앱 행을 `descendants(matching: .disclosureTriangle)`로 찾고 펼침을 `triangle.value`의 `NSNumber` 0/1로 판정합니다. 자체 조립은 `AXDisclosureTriangle` 요소를 만들지 않으므로 두 스위트의 조회가 통째로 성립하지 않고, 「행 라벨 클릭으로 펼침」·「재렌더링 뒤 펼침 유지」·「왼쪽 끝 클릭에도 팝오버가 닫히지 않음」이라는 세 회귀 그물을 스스로 걷어내게 됩니다.
- **`DisclosureGroup` 유지** (채택).

`DisclosureGroup`의 제어 한계는 실측해 보니 이 feature가 필요한 범위에서는 문제가 되지 않습니다.
펼친 내용에 들여쓰기도 위아래 여백도 **0pt**를 주므로, 내용을 `VStack`으로 감싸고 `.padding(.leading/.top/.bottom)`을 거는 것만으로 세 경계와 들여쓰기가 전부 원하는 값이 됩니다 — `DisclosureGroup`이 몰래 더하는 몫을 빼거나 상쇄할 필요가 없습니다.
라벨 쪽 삼각형 폭 12pt는 제어할 수 없지만, 그 값은 들여쓰기 유도에 쓰는 상수일 뿐 없애야 할 대상이 아닙니다.

따라서 기존 탭 동작과 펼침 유지가 그대로 남고(`SPEC §5.6`), 세 UI 스위트를 고치지 않아도 됩니다.

### DP8. 새 표시 요소가 400×480을 넘기는가, 넘기면 무엇이 스크롤로 가는가

상세 팝업은 이미 넘칩니다 — `DashboardView.swift:94`의 주석이 실행 환경에서 잰 자연 크기를 CPU 상세 (406, 8849), Memory 상세 (371, 9056)로 기록하고 있습니다.
앱 목록이 실행 중인 모든 앱을 나열하기 때문이고, 이 feature가 그 사실을 바꾸지 않습니다.
따라서 판단해야 할 것은 「넘치는가」가 아니라 「무엇이 첫 화면 안에 남는가」입니다.

세로 예산은 480 − 상단 padding 16 = **464pt**입니다.
격자 아래끝까지의 높이는 `52 + 격자 높이`이고(요약 줄 13 + 간격 6 + 격자 머리글 13 + 간격 4), 격자 높이는 `54 × 행 수 − 6`입니다.

- 논리 코어 **14개** — 7열 2행, 격자 102pt, 아래끝 **154pt**. 격자 전체가 스크롤 없이 한 화면에 들어옵니다(`SPEC §5.4`).
- 24개는 208pt, 32개는 262pt로 모두 첫 화면 안입니다.
- `52 + (54r − 6) ≤ 480`을 풀면 `r ≤ 8`이므로 **논리 코어 64개(8열 8행, 격자 426pt, 아래끝 478pt)까지** 격자가 스크롤 없이 들어옵니다.
- 65개 이상에서는 격자 아래끝이 첫 화면을 벗어나고, 기존 세로 스크롤이 그 몫을 받습니다. 팝업의 고정 크기는 그대로입니다.

스크롤로 가는 것은 **Load Average 아래의 앱 목록**이며, 이는 이 feature 이전과 같습니다.
코어 줄이 26pt(14코어 기준 두 줄로 접힌 `Text`)에서 119pt(머리글 13 + 간격 4 + 격자 102)로 늘어 앱 목록이 93pt만큼 아래로 밀립니다.
하위 행 간격이 더하는 몫은 펼친 그룹 하나당 `10 + 2 × (하위 수 − 1) + 14`pt이고, 앱 목록은 이미 스크롤 영역이라 팝업 크기에 영향을 주지 않습니다.

가로는 넘기지 않습니다 — 격자는 콘텐츠 폭을 열 수로 나눠 쓰고, 가장 긴 하위 행도 351pt로 360pt 안에 들어갑니다.
spec.md §4가 제외한 가로 스크롤을 새로 만들 이유가 생기지 않습니다.

### DP9. 값 없음(수집 중·실패·중지) 상태의 자리표시

앞 feature가 이 자리에서 다섯 번 연속 reject된 전례가 있고, 원인은 「값이 없을 때 새 표시 요소 중 하나라도 그리지 않으면 실패해야 한다」가 전칭 조건인데 그 전수 목록이 어디에도 없었다는 것이었습니다.
그래서 먼저 이 feature가 더하는 표시 요소를 전수 열거합니다 — ① 코어 격자 머리글 ② 코어 칸의 막대 트랙 ③ 막대 채움 ④ 칸의 화면 수치 ⑤ 칸의 코어 번호 ⑥ 마지막 행의 빈 칸 자리 ⑦ 하위 행의 들여쓰기 ⑧ 세 경계의 간격.

고려한 옵션은 둘입니다.

- **값 없음 상태에도 격자와 하위 행의 자리를 같은 높이로 남긴다** — 카드가 쓰는 자리표시 규칙을 상세에도 확장합니다. 대가: 팝업은 카드와 사정이 다릅니다. 상세 본문 전체가 `.normal` 밖에서는 안내 문구 하나로 대체되고, 팝업 크기는 `.frame(width:height:)`가 상태 분기 밖에서 이미 고정합니다. 자리를 남겨도 지켜지는 것이 없고, 코어가 몇 개인지 모르는 상태에서 격자의 행 수를 지어내야 합니다.
- **값 없음 상태의 표시 경로를 그대로 둔다** (채택).

채택 근거는 도달 가능성입니다.
위 여덟 요소는 전부 `.normal` 분기 **안쪽**에만 있고, 값 없음 세 상태에서는 어느 것도 그려지지 않습니다 — 「일부만 빠지는」 조합 자체가 도달 불가능합니다.
그리고 `SPEC §5.5`가 요구하는 것은 상태를 오갈 때 **팝업의 크기와 카드의 위치**가 변하지 않는 것인데, 팝업 크기는 상태와 무관한 `.frame`이 정하고 카드는 이 feature가 건드리지 않습니다.

`.normal` 안쪽에서 값이 비는 경우도 확인했고 도달하지 않습니다.
`CPUSystemMetricsCollector`는 코어 배열을 만들 수 없는 모든 경우에 `nil`을 돌려주므로 `coreUsages`가 빈 채로 `.normal`에 들어오지 못하고, 진행하지 않은 코어도 0으로 자리를 채웁니다.
하위 프로세스 값이 없는 행은 기존 `ApplicationProcessValueFormatting`이 `"-"`로 그리며 그 규칙은 그대로입니다.

따라서 이 feature는 값 없음 자리표시를 새로 만들지 않습니다.
남는 검증 부담은 「여덟 요소가 `.normal`에서 실제로 그려지는가」이고, 이는 상태별 분기가 아니라 요소 전수 목록으로 확인할 문제입니다.

### DP10. 새 표시 요소를 접근성 계층에 어떻게 드러내는가

`SPEC §5.7`은 코어별 사용률에서 코어 번호와 값이, 하위 프로세스 행에서 소속 앱과 값이 읽히기를 요구합니다.

**코어 칸**은 칸 하나를 접근성 요소 하나로 합칩니다.
안쪽의 막대·수치·번호를 각각 읽히게 두면 `"13"` 같은 조각이 홀로 낭독되므로 자식을 무시하고, 이름은 `"코어 <번호>"`, 값은 `"<수치>%"`로 나눠 답니다 — `MemoryCompositionDonutView`가 도넛을 요소 하나로 합쳐 이름을 붙인 것과 같은 형태입니다.
칸마다 `CPUCore-<번호>` 식별자를 붙여 UI 테스트가 특정 칸을 가리킬 수 있게 합니다(`AppRow-<앱 키>`와 같은 관례).

**하위 프로세스 행**은 두 옵션이 갈립니다.

- **행 전체를 요소 하나로 합침(`children: .combine`이나 `.ignore`)** — 소속 앱·이름·값이 한 번에 낭독됩니다. 대가: 합치면 하위 `Text`의 AX value가 사라질 것으로 보이는데, `DashboardProcessListDisplayUITests`와 `DashboardDetailExpansionUITests`가 하위 행을 `staticTexts`의 `value CONTAINS "PID"`로 찾습니다. 두 스위트의 조회가 함께 깨집니다.
- **두 `Text`를 그대로 두고 이름 쪽에만 접근성 이름을 덧붙임** (채택).

채택안은 이름 `Text`의 접근성 이름을 `ApplicationProcessRowFormatting.childAccessibilityLabel`이 만든 「소속 앱 + 실행 파일 이름 + PID」로 바꾸고, 값 `Text`는 손대지 않습니다.
접근성 **이름**만 바꾸고 요소를 합치지 않으므로 AX value는 화면 문자열 그대로 남아 두 UI 스위트의 조회가 유지되고, 소속 앱과 값이 같은 행에서 이어 읽힙니다.
대가는 소속 앱과 값이 한 요소로 묶여 낭독되지 않는 것인데, 두 요소가 인접해 있어 행 단위 탐색으로는 이어집니다.

값 `Text`를 감추는 선택은 하지 않습니다 — 화면에 보이는 수치를 접근성 계층에서 지우는 셈이라 `SPEC §5.7`과 정면으로 부딪힙니다.

문자열은 전부 순수 함수(`CPUCoreUsageFormatting`·`ApplicationProcessRowFormatting`)가 만듭니다.
앞 feature가 「SwiftUI 접근성 트리는 `NSHostingController` 안에서 실체화되지 않는다」를 실측으로 확인했으므로, 문자열 자체는 단위 테스트로 잡고 실제 부착 여부는 UI 테스트가 잡는 두 겹으로 나뉩니다.

### DP11. 코어 막대의 색을 무엇으로 하는가

- **`DashboardColorPalette.cpuUser` 재사용** — 이미 검증된 색이고 CPU 맥락에 맞습니다. 대가: 그 색은 카드 그래프와 요약 줄에서 **User 계열**을 뜻합니다. 코어별 사용률은 User + System 합계라 뜻이 다른데, 카드와 상세 팝업이 나란히 보이는 배치에서 같은 파랑이 두 가지를 가리키게 됩니다.
- **값 구간에 따라 색을 바꿈(높으면 붉게)** — 대가: 새 색 집합을 색맹 시뮬레이션·명도대비로 다시 검증해야 하고, 색이 정보를 나르기 시작하면 `docs/product.md` 「색상만으로 구분하지 않는다」에 걸려 색 외 수단을 하나 더 얹어야 합니다. 채움 높이와 수치가 이미 그 일을 하므로 얻는 것이 없습니다.
- **계열이 아닌 배경 대비 요소로 두고 시스템 색을 씀** (채택) — 트랙은 `NSColor.quaternaryLabelColor`, 채움은 `NSColor.secondaryLabelColor`를 `DashboardColorPalette.cpuCoreTrack`·`cpuCoreFill`로 둡니다.

채택 근거는 `DashboardColorPalette`가 `cpuGridline`과 `memoryCompositionTrack`에 이미 적어 둔 것과 같습니다 — 다른 색과 구분할 필요가 없는 배경 대비 요소는 색맹 시뮬레이션 대상이 아니고, 라이트·다크 대비는 시스템이 맞춥니다.
막대 하나가 나르는 정보는 오직 높이라 색이 구분에 쓰이는 자리가 없습니다.

대가는 앞 feature의 verifier가 남긴 한계 그대로입니다 — 무채색 요소는 색조·채도 픽셀 계수로 잡히지 않아, 이 요소들의 회귀 그물은 계열 색 요소보다 좁고 렌더 픽셀 비교나 이상적 폭·높이 등식에 기대야 합니다.
그 대가를 받아들이는 이유는, 채움 색에 계열 색을 쓰면 검증은 쉬워지지만 카드의 User 계열과 뜻이 겹쳐 화면 자체가 틀려지기 때문입니다.
색을 두 상수로 `DashboardColorPalette`에 모아 두어, 나중에 계열 색으로 옮기더라도 한 자리만 바꾸면 되게 합니다.
