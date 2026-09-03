# 상세 팝업 가독성 설계

## 근거

spec.md는 §1부터 §5까지 전부 읽었습니다.
범위는 §1이 제한하는 두 자리 — 하위 프로세스 행의 시각적 구분과 논리 코어별 사용률 표현 — 뿐이고, 여기에 요구사항을 더하지 않았습니다.

### 코드에서 확인한 사실

- `CPUDetailView`(`ResourceRunner/DashboardView.swift:910`)는 `VStack(alignment: .leading, spacing: 6)` 안에 요약 줄 · 코어 격자(머리글 + `CPUCoreUsageGridView`) · Load Average · 앱 목록 넷을 **이 순서대로** 둡니다.
  앱 목록(`:932`)이 격자보다 아래에 있으므로, 하위 행의 높이가 늘어나도 격자의 세로 위치는 바뀌지 않습니다.
- `ApplicationProcessGroupListView`(`:1222`)는 `VStack(alignment: .leading, spacing: 2)`에 머리글과 앱 행을 담고 목록 전체에 `.padding(.leading, 8)`을 겁니다.
  그 8pt는 `DisclosureGroup` 삼각형이 `ScrollView` 클립 경계에 닿아 팝오버가 통째로 닫히던 결함의 대응이라 그대로 둡니다.
- `ApplicationProcessGroupRow`(`:1284`)는 `DisclosureGroup`을 쓰고, 펼친 내용의 하위 행이 `HStack { 이름 · Spacer · 값 }` 한 줄입니다.
  라벨은 `HStack(spacing: 6)`에 `ApplicationRowIconLayout.detailPointSize` 아이콘 · 이름 · `Spacer` · 값을 담고, `.contentShape(Rectangle())`과 `.onTapGesture`로 라벨 전체가 토글 대상입니다.
  행 식별자는 `AppRow-<앱 키>`입니다.
- `ApplicationRowIconLayout.detailPointSize`(`ApplicationRowIcon.swift:36`)는 `ApplicationIconCache.displayPointSize` = **16pt**입니다.
- **하위 행 값 문자열의 실제 형태** — `ApplicationProcessDetail.cpuUsageUnitLabel`(`ResourceRunner/ApplicationRanking.swift:253`)이 `"% (코어 합산)"`이고, `cpuProcessValueText`(`:266-269`)가 정수 퍼센트에 그 라벨을 붙인 뒤 Rosetta 프로세스에만 `" · Rosetta"`를 덧붙입니다.
  즉 화면 문자열은 `"10% (코어 합산)"`이고 Rosetta면 `"10% (코어 합산) · Rosetta"`입니다.
  단위 라벨이 시스템 전체 사용률(`CPUCardPresentation.overallUsageUnitLabel`)과 다른 것은 프로세스 값이 논리 코어 합산 관례라 100%를 넘을 수 있기 때문이고, 그 사실이 주석에 근거로 적혀 있습니다.
  값이 없으면 `"-"`입니다.
- `DashboardView.detailPopupWidth`·`detailPopupHeight`(`:99-100`)는 400·480이고, 두 상세 팝업 모두 `.frame(width:height:)`를 상태 분기 **밖**에 무조건 걸고 있습니다(`:878`·`:902`).
- `CPUDetailPopoverContent`·`MemoryDetailPopoverContent`는 `.normal`일 때만 상세 뷰를 그리고, 나머지 세 상태에서는 안내 문구 `Text` 하나만 그립니다.
- `CPUCardDetail.coreUsages`는 `[Double]`이고, `CPUSystemMetricsCollector`는 코어 배열을 만들 수 없는 모든 경우(기준점 없음 · 간격 초과 · 코어 수 변화 · 카운터 되감김 · 전체 tick 0)에 `nil`을 돌려줍니다.
  따라서 `.normal` 상태에서 `coreUsages`가 비거나 코어가 누락되는 경우는 없고, 진행하지 않은 코어도 0으로 자리를 채웁니다(`CPUSystemMetricsCollector.swift:142`).
- `DashboardColorPalette`의 계열 색은 색맹 시뮬레이션·명도대비 검증기를 통과한 조합이라 바꾸면 재검증이 필요합니다.
  반면 `cpuGridline`·`memoryCompositionTrack`은 「다른 색과 구분할 필요가 없는 배경 대비 요소」라는 이유로 시스템 색을 그대로 씁니다.
  `cpuCoreTrack`·`cpuCoreFill`(`DashboardColorPalette.swift:29-30`)도 같은 이유로 시스템 색입니다.

### 실측한 값

`NSHostingController.sizeThatFits`와 `ImageRenderer` 픽셀 probe로 이 기기(macOS 26.6.2)에서 직접 쟀습니다(앞 feature `DashboardCardLayoutTests`가 쓰는 것과 같은 수단).

- `.padding()` 기본값은 좌우 각 **16pt**입니다(폭 증가 32.0). 따라서 상세 팝업의 콘텐츠 폭은 **368pt**, 앱 목록 안쪽은 `.padding(.leading, 8)`을 뺀 **360pt**입니다.
- `.caption`·`.caption2` 한 줄 높이는 둘 다 **13.0pt**이고, `.caption2` 숫자 한 글자(`"0"`)는 **7.0pt**입니다.
- `.caption2` 기준 코어 칸 수치 `"100%"` = **28.0pt**입니다.
- `.caption2` 기준 하위 행 **값** 문자열 — `"10% (코어 합산)"` = 70.0, `"100% (코어 합산)"` = 77.0, `"10% (코어 합산) · Rosetta"` = **117.0pt**, `"100% (코어 합산) · Rosetta"` = 124.0, `"1234% (코어 합산) · Rosetta"` = 130.0입니다.
- `.caption2` 기준 하위 행 **이름** — `"Google Chrome Helper (Renderer) (PID 12345)"` = **231.0pt**, PID가 여섯 자리면 237.0pt입니다.
- **한 줄 구조(`HStack { 이름 · Spacer · 값 }`)의 필요 폭** — `HStack` 기본 간격이 8.0pt라 들여쓰기 0pt에서 **356.0pt**, 12pt에서 368.0, 34pt에서 **390.0pt**, 46pt에서 402.0입니다.
  앱 목록 안쪽 폭 360pt에서 잰 행 높이는 들여쓰기 0pt만 13.0(한 줄)이고 12·34·46pt는 전부 **26.0pt**(이름이 두 줄로 접힘)입니다.
- **두 줄 구조에서의 각 줄** — 이름 줄은 들여쓰기 34pt에서 필요 폭 265.0pt, 46pt에서 277.0pt로 360pt 안에 한 줄로 들어갑니다.
  값 줄은 들여쓰기 50pt에서 필요 폭 167.0pt입니다.
- macOS `DisclosureGroup`은 **펼친 내용에 들여쓰기도 위아래 여백도 전혀 주지 않습니다** — 픽셀 probe에서 라벨 삼각형의 잉크가 x 8–11, 아이콘 시작 x = **20.0pt**(목록 여백 8 + 삼각형 폭 **12.0pt**), 펼친 내용의 시작 x = 목록 여백 그대로였습니다.
- 현재 세 경계의 실제 간격은 **0 / 2 / 2pt**입니다.
  접힘 행 24.0pt에 하위 1개는 +13.0(부모–첫 하위 0), 2개는 +28.0, 3개는 +43.0(하위끼리 2), 그리고 목록 `VStack`의 `spacing: 2`가 마지막 하위–다음 앱을 2로 만듭니다.

### 두 줄 구조의 실측 (§5 DP5·DP6의 근거)

들여쓰기 34pt(이름 줄) / 50pt(값 줄), 간격 2 / 10 / 18 / 26pt로 조립해 368pt 폭에서 쟀습니다.

| 하위 수 | 앱 행 높이 | 직전 대비 |
| ---: | ---: | ---: |
| 0(접힘) | 24.0 | — |
| 1 | 94.0 | +70.0 |
| 2 | 132.0 | +38.0 |
| 3 | 170.0 | +38.0 |

하위 1개의 +70.0은 `18(부모–첫 하위) + 28(두 줄 행 = 13 + 2 + 13) + 24(펼친 내용 아래 여백)`이고, 하위가 하나 늘 때마다의 +38.0은 `10(하위끼리) + 28(행)`입니다.
펼친 행(하위 2개) 아래에 접힌 앱 행을 붙이면 합계 158.0pt로, `132 + 2(목록 spacing) + 24(접힘 행)`과 맞습니다 — 마지막 경계 26pt가 `펼친 내용 아래 여백 24 + 목록 spacing 2`로 쪼개진다는 뜻입니다.

같은 조립의 픽셀 probe로 잰 잉크 간격은 **5 / 13 / 24 / 31px**이고, 각 줄의 잉크 시작 x는 부모 아이콘 20, 하위 이름 줄 43(≈ 8 + 34), 하위 값 줄 58(≈ 8 + 34 + 16)이었습니다.
잉크 간격이 배치 상수(2 / 10 / 18 / 26)보다 넓은 것은 `DisclosureGroup` 라벨 행이 24.0pt인데 그 안의 아이콘이 16pt라 위아래로 4pt씩 자체 여백을 갖기 때문입니다.

값 줄의 추가 들여쓰기(0 · 6 · 12 · 16pt)를 바꿔도 펼친 행 높이는 132.0pt로 같았습니다 — 값 줄은 어느 후보에서도 접히지 않습니다.

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
| 65 | 8 | 9 | 40.8 | 480.0 |

팝업 위끝에서 격자 아래끝까지는 `16(상단 padding) + 13(요약 줄) + 6 + 13(격자 머리글) + 4 + 격자 높이`입니다 — 14코어 **154pt**, 24코어 208pt, 64코어 478pt입니다.

`LazyVGrid`도 열 수를 `CPUCoreGridLayout`에서 그대로 가져오면 `NSHostingController.sizeThatFits`의 결과가 `VStack`+`HStack`과 **소수점까지 같습니다** — 코어 8 · 10 · 14 · 16 · 24 · 32 · 64 · 65 · 80 · 128 모두 368pt 제안에서 폭·높이가 동일했습니다.
Lazy 컨테이너가 화면 밖 행을 실체화하지 않는다는 통념은 이 측정 경로에서는 성립하지 않습니다(§5 DP4).

칸에 `maxWidth: .infinity`를 걸어 균등 분할하면 열 수가 콘텐츠 폭을 나눠떨어뜨리지 않는 코어 수에서 부동소수점 잔차가 남습니다 — 5열(코어 10)에서 367.99999999999989, 7열(코어 14)에서 368.00000000000006이었고, 8열은 정확히 368이었습니다.

### 기존 테스트가 잠그고 있는 것

- `DashboardDetailExpansionUITests`와 `DashboardProcessListDisplayUITests`는 앱 행을 `app.popovers.descendants(matching: .disclosureTriangle)`로 찾고, 펼침을 `(triangle.value as? NSNumber)?.intValue == 1`로 판정합니다.
  즉 두 스위트가 `DisclosureGroup`이 만드는 `AXDisclosureTriangle` 요소와 그 AX value에 직접 매여 있습니다.
- 같은 두 스위트가 하위 행을 `app.popovers.staticTexts`의 `value CONTAINS "PID"`로 찾습니다.
- task-006의 XCUITest mutation에서 하위 행에 `.accessibilityElement(children: .combine)`을 걸면 AX 요소가 1개가 되고 label은 빈 문자열, value는 모든 문자열을 이어 붙인 값이 되어 `value CONTAINS "PID"` 조회가 통과했습니다.
  `.ignore`를 걸면 AX 요소가 0개가 되어 조회 자체가 실패했습니다.
  `.combine`을 가르는 것은 같은 `AppRow-<앱 키>` 식별자의 `StaticText`가 정확히 2개인지와 이름 줄 접근성 이름에 소속 앱이 포함되는지를 보는 단언입니다(`DashboardProcessListDisplayUITests`, task-006).
- `DashboardDetailPopoverUITests`는 두 상세의 `DashboardDetail` 프레임 크기가 같은지, 스크롤 전후에 그 프레임이 그대로인지, `"Load Average"` `staticText`가 `popovers` 아래에 있는지를 단언합니다.
- 팝업 AX 프레임이 정확히 400.0인지도 이 스위트가 잡습니다 — 격자 폭 잔차가 그대로 새어 나가 `400.0000000000001`이 되면서 실제로 깨졌고, `ProposedWidthLayout`(`DashboardView.swift:993`)이 격자의 **보고 폭**을 제안 폭으로 고정해 막았습니다.
- `DashboardCardLayoutTests`는 **카드**만 렌더링합니다(CPU 243.0pt, Memory 181.0pt). 상세 팝업 높이를 단언하는 단위 테스트는 없습니다.

### 의존 탐색 흔적 (§4의 근거)

- `ApplicationProcessGroupListView` 호출부는 `CPUDetailView`(`:932`)와 `MemoryDetailView`(`:1113`) 둘뿐입니다. 따라서 하위 행 변경은 CPU·Memory 상세 양쪽에 동시에 반영됩니다.
- `ApplicationProcessGroupRow`를 조립하는 곳은 `ApplicationProcessGroupListView` 하나뿐입니다.
- `CPUDetailView`를 그리는 곳은 `CPUDetailPopoverContent` 하나뿐입니다.
- `coreUsages`를 화면으로 옮기는 곳은 `DashboardView.swift:920`·`:924` 둘(머리글의 코어 수와 격자)뿐이고, 나머지 참조는 수집·조립 경로(`SystemMetrics:20`·`CPUSystemMetricsCollector`·`DashboardPresentation:131`·`:196`)와 테스트 픽스처입니다.
  표시 계층 밖은 건드리지 않습니다.
- `ApplicationProcessValueFormatting.cpuProcessValueText`를 넘기는 곳도 `CPUDetailView` 하나이고, 이 feature는 그 함수를 바꾸지 않습니다.
- `DashboardColorPalette`를 쓰는 production 파일은 `DashboardView.swift` 하나입니다.

### 추정으로 남는 것

- 픽셀 probe로 얻은 `DisclosureGroup` 삼각형 폭 12.0pt와 라벨 행의 자체 여백 4pt는 이 macOS 버전에서 잰 값입니다. OS가 이 값을 바꾸면 하위 이름 줄과 부모 이름의 정렬, 그리고 잉크 기준 세로 간격이 그만큼 어긋납니다.
- macOS 스크롤 막대를 「항상 표시」로 둔 환경에서는 레거시 스크롤러가 콘텐츠 폭을 15pt 안팎 줄일 수 있습니다. 그 경우까지 칸 폭과 하위 행 폭에 여유를 남겨 뒀지만 그 설정으로 재보지는 않았습니다.
- 네 간격이 「서로 확실히 갈려 보이는가」는 배치 값과 잉크 간격까지만 실측했고, 지각 판정은 화면 확인의 몫입니다.

## 1. 구조

새 모듈이나 레이어를 만들지 않습니다.
변경은 전부 Presentation 계층 안에서 끝나고, Application·Collectors 경계는 그대로입니다.

이 프로젝트는 「계산은 순수 함수로 빼고 뷰는 소비만 한다」를 이미 `MemoryCompositionLayout.make`·`MemoryCompositionDonutLayout.make`·`ApplicationProcessGroupOrdering.displayedGroups`·`ApplicationRowIconLayout`에서 지키고 있습니다.
코어 격자의 행·열 분할과 하위 행의 들여쓰기·간격도 그 자리에 넣습니다 — 둘 다 뷰 본문에 두면 코어 수나 행 수를 바꿔 가며 확인할 방법이 렌더링밖에 남지 않기 때문입니다.

경계는 넷입니다.

- **배치 계산** — `CPUCoreGridLayout`이 코어 수 하나만 받아 행별 코어 인덱스 묶음과 열 수를 돌려줍니다.
  가용 폭은 인자로 받지 않고, 폭에서 유도한 열 상한 하나만 상수로 들고 있습니다(§5 DP1).
  `ApplicationProcessRowLayout`이 하위 행의 두 시작선(이름 줄·값 줄)과 네 간격을 상수로 들고 있고, 시작선은 `ApplicationRowIconLayout.detailPointSize`와 라벨 `HStack`의 간격에서 유도합니다(§5 DP5, DP6).
- **문자열 서식** — `CPUCoreUsageFormatting`이 칸의 화면 수치, 격자 머리글, 코어 칸의 접근성 이름과 값을 만듭니다.
  `ApplicationProcessRowFormatting`이 하위 행의 접근성 이름(소속 앱을 포함한)을 만듭니다.
  접근성 이름을 순수 함수로 빼는 이유는 앞 feature가 확인한 사실 때문입니다 — SwiftUI 접근성 트리는 `NSHostingController` 안에서 실체화되지 않아, 문자열 자체는 단위 테스트로만 잡을 수 있습니다(`SPEC §5.7`).
  하위 행의 **값** 문자열은 기존 `ApplicationProcessValueFormatting`이 그대로 만듭니다. 이 feature는 그 함수도 단위 라벨도 바꾸지 않습니다.
- **표시** — `CPUCoreUsageGridView`가 `[Double]`을 받아 위 두 순수 자리가 정한 행·열과 문자열을 좌표와 그리기로 옮깁니다(`SPEC §5.3`, `SPEC §5.4`).
  이 뷰는 자식이 되돌린 폭 대신 제안 폭을 그대로 보고하는 `ProposedWidthLayout`으로 감쌉니다 — 칸을 균등 분할하면 열 수가 콘텐츠 폭을 나눠떨어뜨리지 않는 코어 수(5·6·7열)에서 부동소수점 잔차가 상위 레이아웃 폭으로 새어 나가, 실제로 팝업 AX 프레임이 400.0에서 벗어난 적이 있습니다(§근거 실측, §5 DP2).
  `ApplicationProcessGroupRow`는 `DisclosureGroup`을 그대로 유지한 채(§5 DP7) 펼친 내용을 `VStack`으로 감싸고, **하위 행 하나를 이름 줄과 값 줄 두 줄로** 조립한 뒤 `ApplicationProcessRowLayout`이 정한 시작선과 간격을 겁니다(`SPEC §5.1`, `SPEC §5.2`).
  `ApplicationProcessGroupListView`는 바뀌지 않습니다 — 펼침 상태와 순서 고정을 들고 있는 자리라 손대면 `SPEC §5.6`이 잠근 동작이 흔들립니다.
- **색** — 코어 막대의 트랙·채움 색을 `DashboardColorPalette`에 둡니다(§5 DP11).

## 2. 데이터 흐름

새 상태를 만들지 않습니다. 이 feature가 더하는 것은 기존 값이 화면으로 가는 마지막 구간뿐입니다.

코어 격자의 경로는 이렇습니다.

`MonitoringScheduler` tick → `CPUSystemMetricsCollector`가 `coreUsages: [Double]`을 만듦 → `ApplicationCoordinator` → `CPUCardPresentation.assemble`이 `CPUCardDetail.coreUsages`로 그대로 옮김 → `DashboardPresentationStore.cpuCard` → `DashboardView` → `CPUDetailPopoverContent`가 상태를 가름 → (`.normal`일 때만) `CPUDetailView` → `CPUCoreUsageGridView` → `CPUCoreGridLayout.rows(coreCount:)`가 행·열을 정하고 `CPUCoreUsageFormatting`이 문자열을 만듦 → 칸 렌더.

하위 프로세스 행의 경로는 이렇습니다.

`ProcessSurveyCollector` → `ProcessHistoryStore` → `ApplicationRanking.groupByApplication` → `ApplicationRanking.sortedForDisplay` → `CPUCardDetail.applications`(Memory는 `MemoryCardDetail.applications`) → `ApplicationProcessGroupListView` → `ApplicationProcessGroupOrdering.displayedGroups`가 순서를 정함 → `ApplicationProcessGroupRow` → `DisclosureGroup` 라벨(부모)과 내용(하위) → 하위 행마다 이름 줄과 값 줄 → `ApplicationProcessRowLayout`의 두 시작선과 네 간격 적용.

값 문자열은 이 경로에서 갈라지지 않습니다 — 이름 줄은 지금과 같은 `"<실행 파일 이름> (PID <pid>)"`, 값 줄은 지금과 같은 `ApplicationProcessValueFormatting.cpuProcessValueText`(Memory는 바이트 서식)의 결과이고, 두 줄로 나뉜 것은 배치뿐입니다.

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
프로세스 값이 없는 하위 행은 지금처럼 `ApplicationProcessValueFormatting`이 `"-"`로 그리고, 두 줄 구조에서도 그 `"-"`가 값 줄에 그대로 놓입니다.

## 3. 인터페이스

경계를 가로지르는 것만 둡니다.

- `CPUCoreGridLayout.maximumColumnCount: Int` — 콘텐츠 폭 368pt에서 유도한 열 상한. 폭이 아니라 이 상수 하나만 뷰 밖에 노출합니다.
- `CPUCoreGridLayout.rows(coreCount: Int) -> [[Int]]` — 코어 인덱스를 행별로 묶어 돌려줍니다. 모든 행의 길이가 같거나, 마지막 행만 짧습니다. `coreCount == 0`이면 빈 배열입니다.
- `CPUCoreGridLayout.barHeight: CGFloat` · `cellSpacing: CGFloat` — 칸 막대의 트랙 높이와 칸 사이 간격.
- `CPUCoreUsageFormatting.valueText(_ usage: Double) -> String` — 칸에 보이는 정수 퍼센트. 코어 사용률이 문자열 한 줄이던 때의 반올림 규칙을 그대로 씁니다.
- `CPUCoreUsageFormatting.headingText(coreCount: Int) -> String` — 격자 머리글. 코어 수를 문자열 안에 직접 박지 않고 인자에서 만듭니다.
- `CPUCoreUsageFormatting.accessibilityLabel(coreIndex: Int) -> String` · `accessibilityValue(_ usage: Double) -> String` — 코어 칸의 접근성 이름과 값(`SPEC §5.7`).
- `CPUCoreUsageFormatting.cellAccessibilityIdentifier(coreIndex: Int) -> String` — 칸별 안정 식별자. `AppRow-<앱 키>`와 같은 관례를 따라 UI 테스트가 특정 칸을 가리킬 수 있게 합니다.
- `ApplicationProcessRowLayout.childIndent: CGFloat` — 하위 행 **이름 줄**의 시작선(34pt). `disclosureTriangleWidth`(12) + `ApplicationRowIconLayout.detailPointSize`(16) + `labelIconSpacing`(6)에서 유도합니다.
- `ApplicationProcessRowLayout.childValueIndent: CGFloat` — 하위 행 **값 줄**의 시작선(50pt). `childIndent + ApplicationRowIconLayout.detailPointSize`로 유도합니다(§5 DP5).
- `ApplicationProcessRowLayout.withinChildRow: CGFloat` — 한 하위 행 안에서 이름 줄과 값 줄 사이(2pt).
- `ApplicationProcessRowLayout.betweenChildren: CGFloat` — 하위 행끼리(10pt).
- `ApplicationProcessRowLayout.parentToFirstChild: CGFloat` — 부모 앱 행과 첫 하위 행 사이(18pt).
- `ApplicationProcessRowLayout.lastChildToNextApplication: CGFloat` — 마지막 하위 행과 다음 앱 행 사이(26pt). 목록 `VStack`의 `spacing: 2`를 포함한 값입니다.
- `ApplicationProcessRowLayout.listRowSpacing: CGFloat` · `afterLastChild: CGFloat` — 목록 `VStack`이 이미 두는 간격(2pt)과, 그만큼을 뺀 뒤 펼친 내용 아래에 거는 몫(24pt).
- `ApplicationProcessRowFormatting.childAccessibilityLabel(applicationDisplayName: String, process: ApplicationProcessDetail) -> String` — 하위 행 이름 줄의 접근성 이름. 소속 앱을 포함합니다(`SPEC §5.7`).
- `DashboardColorPalette.cpuCoreTrack: Color` · `cpuCoreFill: Color` — 코어 막대의 트랙과 채움.
- `CPUCoreUsageGridView(usages: [Double])` — `CPUDetailView`가 코어 줄 자리에 두는 뷰.

## 4. 영향 범위

- `ResourceRunner/DashboardView.swift`
  - `CPUDetailView` — 코어 줄 자리가 격자 머리글 + `CPUCoreUsageGridView`입니다. `VStack`의 나머지 세 자리와 순서는 그대로입니다.
  - `ApplicationProcessGroupRow` — 펼친 내용의 하위 행을 `HStack { 이름 · Spacer · 값 }` 한 줄에서 `VStack { 이름 줄 · 값 줄 }` 두 줄로 바꾸고, 값 줄에 추가 들여쓰기를 겁니다. 펼친 내용 전체에 거는 왼쪽 들여쓰기·위아래 여백과 행 사이 간격은 `ApplicationProcessRowLayout`에서 옵니다.
    라벨·`contentShape`·`onTapGesture`·`AppRow-<앱 키>` 식별자는 손대지 않습니다.
  - `CPUCoreUsageGridView`·`ProposedWidthLayout`·`CPUCoreUsageCellView`.
  - `ApplicationProcessGroupListView`는 바뀌지 않지만, 이 목록을 통해 하위 행 변경이 `MemoryDetailView`에도 그대로 반영됩니다(호출부 탐색에서 두 곳 확인).
- `ResourceRunner/DashboardPresentation.swift` — `CPUCoreGridLayout`·`CPUCoreUsageFormatting`·`ApplicationProcessRowLayout`. `ApplicationProcessRowLayout`에는 `childValueIndent`·`withinChildRow`가 더해지고 `betweenChildren`·`parentToFirstChild`·`lastChildToNextApplication`의 값이 바뀝니다. `MemoryCompositionLayout` 계열이 이미 이 파일에 있어 새 파일을 만들지 않습니다.
- `ResourceRunner/ApplicationRanking.swift` — `ApplicationProcessRowFormatting`을 더합니다. 값 서식 `ApplicationProcessValueFormatting`이 이 파일에 있어 하위 행 문자열 서식이 한자리에 모입니다. 기존 타입과 계산, 단위 라벨 `cpuUsageUnitLabel`은 바꾸지 않습니다.
- `ResourceRunner/DashboardColorPalette.swift` — `cpuCoreTrack`·`cpuCoreFill` 둘. 기존 계열 색은 그대로라 색맹·대비 재검증 대상이 아닙니다.

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
그 빈 자리는 높이를 0으로 묶습니다 — 묶지 않으면 `Color`가 세로로도 무한히 늘어나 짧은 마지막 행이 있는 코어 수에서 격자의 필요 높이가 무한대가 됩니다.

균등 분할에는 실측으로 확인된 제약이 하나 붙습니다.
칸에 `maxWidth: .infinity`를 걸면 열 수가 콘텐츠 폭을 나눠떨어뜨리지 않는 코어 수(5·6·7열)에서 부동소수점 잔차가 남아 — 5열 367.99999999999989, 7열 368.00000000000006 — 그 오차가 상위 레이아웃 폭으로 새어 나갑니다.
실제로 팝업 AX 프레임이 `400.0000000000001`이 되어 기존 UI 회귀 테스트를 깨뜨렸고, 격자의 **보고 폭**을 제안 폭으로 고정하는 래퍼(`ProposedWidthLayout`)로 막았습니다.
그 래퍼는 폭 제안이 없거나 무한대인 측정에서는 자식이 되돌린 필요 폭을 그대로 보고합니다 — 무한대를 보고하면 필요 폭 측정 자체가 무너지기 때문입니다.

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

- **`LazyVGrid`** — 열 정의만 주면 배치를 SwiftUI가 합니다. 대가: 열 정의가 뷰 안에만 있어 코어 수를 바꿔 가며 행·열 분할을 확인하려면 렌더링해야 하고, 화면 밖 행의 실체화 시점이 SwiftUI 구현에 달려 접근성 요소가 언제 존재하는지를 이 코드가 보증하지 못합니다.
- **`CPUCoreGridLayout`이 나눈 행을 `VStack` + `HStack`으로 그림** (채택).

채택 근거는 §1의 경계와 같습니다 — 행·열 분할이 순수 함수의 반환값이 되어 코어 수 8·10·14·16·24를 인자로 넣어 직접 확인할 수 있고, 코어 수가 최대 수십 개라 전부 그려도 비용이 문제 되지 않습니다.
칸 폭은 각 칸에 `maxWidth: .infinity`를 걸어 행 안에서 균등하게 나눕니다(그 잔차 처리는 §5 DP2).

이 결정에는 실측으로 확인된 한계가 하나 붙습니다.
열 수를 `CPUCoreGridLayout.rows`에서 그대로 가져오는 한, `LazyVGrid`도 `NSHostingController.sizeThatFits` 안에서는 `VStack`+`HStack`과 **소수점까지 같은 크기**를 돌려줍니다(코어 8 · 10 · 14 · 16 · 24 · 32 · 64 · 65 · 80 · 128 × 측정 4종에서 확인).
따라서 이 결정을 지키는 회귀 그물은 크기 측정 계층이 아니라 **접근성 계층**에 있어야 합니다 — 칸이 실제로 요소로 존재하는지를 보는 쪽이라야 컨테이너 교체가 드러납니다.
반대로 자체 열 유도를 쓰는 변형(`LazyVGrid(.adaptive(minimum:))`)은 열 수가 달라지므로 크기 측정만으로도 잡힙니다.

### DP5. 하위 행을 한 줄로 두는가 두 줄로 나누는가, 각 줄을 얼마나 들여쓰는가

**폭 예산이 한 줄 구조를 성립시키지 않는다는 것이 실측으로 확인됐습니다.**
값 문자열은 단위 라벨 `"% (코어 합산)"`을 포함하므로 `"10% (코어 합산) · Rosetta"` = **117.0pt**입니다.
이름 231.0pt와 `HStack` 기본 간격 8.0pt를 더하면, 부모 앱 이름 시작선인 들여쓰기 34pt에서 필요 폭이 **390.0pt**로 앱 목록 안쪽 폭 **360pt**를 넘습니다.
360pt에서 재면 행 높이가 26.0pt — 이름이 두 줄로 접히고 값은 그 옆에 남아, 어느 이름 조각에 어느 값이 붙는지 눈으로 짚을 수 없습니다(`SPEC §5.2` 위반).
들여쓰기를 12pt(삼각형 폭)로 낮춰도 368.0pt라 마찬가지이고, 0pt로 되돌려야 356.0pt로 겨우 들어가는데 0pt는 spec.md §1이 지목한 결함(하위가 부모보다 왼쪽에서 시작)그 자체입니다.
게다가 0pt의 여유는 4pt뿐이라 PID가 여섯 자리만 돼도(이름 237.0) 362pt로 다시 넘칩니다.
즉 **들여쓰기 값 조정으로는 풀리지 않습니다.**

고려한 옵션 셋입니다.

- **단위 라벨을 하위 행에서만 `"%"`로 줄인다** — 값이 28pt 안팎이 되어 한 줄이 유지됩니다. 대가: 하위 행의 숫자가 카드·요약 줄의 시스템 전체 사용률과 같은 단위처럼 보이게 되어 뜻이 바뀝니다. 프로세스 값은 논리 코어 합산이라 100%를 넘을 수 있고 그래서 다른 라벨을 쓰는 것이 `ApplicationRanking.swift`에 근거로 적혀 있습니다. spec.md §1의 「표시되는 값 자체는 그대로」와도 부딪혀 spec.md 수정을 요구합니다.
- **이름을 말줄임한다** — 폭이 확실히 맞습니다. 대가: `SPEC §5.2`의 「잘리지 않은 채」와 정면으로 부딪히고, 하위 프로세스는 이름 뒷부분(`(Renderer)`·`(GPU)`)이 구분의 핵심이라 잘리면 행을 구분할 수 없습니다. 이 안도 spec.md 수정을 요구합니다.
- **값을 이름 아래 줄로 내린다** (채택, 2026-09-01 사용자 결정 — 정확도 우선).

채택안은 이름도 값도 줄이거나 자르지 않습니다.
spec.md §1이 「표시되는 값 자체는 그대로이고 그 값을 **배치하고 그리는 방식만** 바뀝니다」로 열어 둔 자리가 정확히 이 변경이라, 배제한 두 안과 달리 spec.md를 건드리지 않습니다.
실측으로 이름 줄은 들여쓰기 34pt에서 필요 폭 265.0pt, 값 줄은 들여쓰기 50pt에서 167.0pt라 둘 다 360pt 안에 한 줄로 들어갑니다(`SPEC §5.2`).
이름이 360pt를 넘길 만큼 긴 예외(시작선을 뺀 326pt 초과)에서는 `lineLimit`을 걸지 않으므로 잘리지 않고 접히며, 값 줄은 그 아래에 그대로 남아 이름–값 대응이 유지됩니다.

**이름 줄의 시작선은 34pt**로 둡니다.
spec.md §1이 지목한 문제 자체가 「부모 행에는 앱 아이콘이 있고 하위 행에는 없어 두 층의 시작 위치가 어긋나 있다」이고, 34pt는 부모 앱 이름 시작선과 같아 그 어긋남을 정확히 0으로 만듭니다(`SPEC §5.1`).
상수로 박지 않고 `ApplicationRowIconLayout.detailPointSize`(16)와 라벨 `HStack` 간격(6), 삼각형 폭(12)에서 유도합니다 — 아이콘 크기가 바뀌면 들여쓰기가 따라가야 정렬이 유지되기 때문입니다.
삼각형 폭 12pt만은 OS가 정하는 값이라 실측한 상수로 남고, OS가 이 값을 바꾸면 정렬이 그만큼 어긋납니다.
어긋나도 하위 행이 부모보다 왼쪽으로 나가지는 않으므로 층의 순서는 뒤집히지 않습니다.

**값 줄의 시작선은 50pt**입니다 — 이름 줄보다 한 단(16pt) 더 들어갑니다.

- **이름 줄과 같은 34pt** — 하위 블록의 왼쪽 끝선이 하나로 유지됩니다. 대가: 세로로 늘어선 줄들이 전부 같은 x에서 시작해, 어느 줄이 이름이고 어느 줄이 값인지가 **내용을 읽어야만** 갈립니다. `SPEC §5.1`이 구분을 들여쓰기와 간격으로 하라고 못박은 자리에서 구분 근거가 내용으로 넘어갑니다.
- **값을 오른쪽 끝선에 맞춤(부모 앱 값과 같은 열)** — 값들이 세로 열을 이뤄 크기 비교가 쉽습니다. 대가: 이름과 그 값이 화면에서 가장 멀어져, 줄이 촘촘히 쌓이면 어느 이름의 값인지 다시 헷갈립니다. 값 문자열 길이에 따라 왼쪽 끝이 들쭉날쭉해져 형태로 층을 읽는 수단이 되지도 못합니다.
- **한 단 더 들여씀** (채택).

채택 근거는 왼쪽 끝선이 그대로 층을 뜻하게 된다는 점입니다 — 34pt에서 시작하면 프로세스 이름, 50pt에서 시작하면 바로 위 이름의 값입니다.
픽셀 probe로 이름 줄 잉크 x = 43, 값 줄 잉크 x = 58이 나와 실제로 15px 갈립니다.
한 단의 폭 16pt는 `ApplicationRowIconLayout.detailPointSize`에서 가져옵니다 — 부모 행에서 아이콘 자리가 만든 한 단과 같은 폭이고, `.caption2` 숫자 한 글자 7.0pt의 두 배를 넘어 눈으로 갈립니다.
대가는 하위 블록의 왼쪽 끝선이 둘로 늘어나는 것인데, 그 둘이 각각 다른 뜻을 가지므로 「어긋남」이 아니라 층입니다.

층 구분을 색·구분선·배경으로 보강하는 선택지는 spec.md §4가 제외했으므로 검토 대상이 아닙니다.

### DP6. 네 간격을 얼마로 하는가

두 줄 구조가 되면서 경계가 셋에서 넷으로 늘었습니다 — 한 행 **안**의 두 줄 사이가 새로 생깁니다.
이 간격이 하위 행끼리의 간격과 비슷하면 「행 안의 줄바꿈」과 「행과 행의 경계」가 눈으로 갈리지 않아, 세 경계를 아무리 벌려도 하위 목록이 그냥 줄의 나열로 읽힙니다.
현행 값(행 안 2pt 안팎 · 하위끼리 4pt)이 정확히 그 상태입니다.

`SPEC §5.1`은 세 경계가 서로 같은 간격으로 보이지 않을 것을, `SPEC §5.2`는 하위 행끼리 붙어 보이지 않고 한 행의 이름과 값을 짚을 수 있을 것을 요구합니다.
값을 임의로 고르는 대신 규칙 하나로 넷을 유도합니다 — **층을 하나 넘을 때마다 8pt씩 더한다.**

- 한 행 안(이름 줄–값 줄): **2pt** — 층을 넘지 않으므로 가장 좁습니다. 두 줄이 한 덩어리로 읽히는 값이고, 코어 칸이 안쪽 세 줄에 쓰는 간격과 같습니다.
- 하위 행끼리: **10pt** — 같은 앱 안의 경계입니다.
- 부모 앱 행–첫 하위 행: **18pt** — 앱 행에서 그 앱 안쪽으로 들어가는 경계입니다.
- 마지막 하위 행–다음 앱 행: **26pt** — 앱 하나를 벗어나는 경계라 가장 넓습니다.

한 단의 폭 8pt는 `.caption2` 줄 높이 실측 13.0pt의 절반(6.5)을 넘는 최소 짝수입니다 — 인접한 두 경계의 차이가 줄 높이의 절반을 넘어야 두 경계가 같은 화면에서 한눈에 갈립니다.
2 → 10은 5배, 그다음은 8pt씩이라 순서가 어디서도 뒤집히지 않습니다.

실측으로 확인한 결과입니다.
접힘 앱 행 24.0pt에 하위 1개는 +70.0(= 18 + 28 + 24), 하위가 하나 늘 때마다 +38.0(= 10 + 28)이고, 펼친 행(하위 2개) 아래 접힌 앱 행을 붙이면 132 + 2 + 24 = 158.0pt입니다.
같은 조립의 픽셀 잉크 간격은 **5 / 13 / 24 / 31px**로 네 경계가 순서대로 벌어집니다.
잉크 간격이 배치 상수보다 넓은 것은 `DisclosureGroup` 라벨 행(24.0pt)이 16pt 아이콘 위아래로 4pt씩 자체 여백을 갖기 때문이고, 그 몫이 부모가 걸린 두 경계(부모–첫 하위, 마지막 하위–다음 앱)에만 더해집니다.

마지막 경계 26pt는 그대로 걸지 않고 쪼갭니다.
목록 `VStack`이 이미 행 사이에 `spacing: 2`를 두므로, 펼친 내용 아래에는 그만큼을 뺀 **24pt**를 겁니다.
목록의 `spacing: 2`는 그대로 둡니다 — 그 값을 키우면 접힌 앱 행 사이까지 벌어져 상세 목록 전체가 길어지는데, spec.md가 지목한 문제는 펼친 뒤의 경계뿐입니다.
여백을 펼친 내용에만 걸면 접힌 목록의 밀도는 지금 그대로 유지되고, 마지막 경계는 펼친 행에서만 넓어집니다.

대가는 펼친 앱 하나가 차지하는 높이입니다 — 하위 2개 기준 80pt에서 108pt로 늘어납니다.
받아들이는 이유는 그 몫이 전부 앱 목록 안에서 생기고, 앱 목록은 이 feature 이전부터 스크롤 영역이라 팝업의 고정 크기에 닿지 않기 때문입니다(spec.md §3의 「기존 세로 스크롤 안에서 해결」).

### DP7. `DisclosureGroup`을 계속 쓰는가

- **자체 조립(삼각형 버튼 + 조건부 하위 목록)** — 내부 간격과 들여쓰기를 완전히 제어할 수 있습니다. 대가: 결정적입니다 — `DashboardDetailExpansionUITests`와 `DashboardProcessListDisplayUITests`가 앱 행을 `descendants(matching: .disclosureTriangle)`로 찾고 펼침을 `triangle.value`의 `NSNumber` 0/1로 판정합니다. 자체 조립은 `AXDisclosureTriangle` 요소를 만들지 않으므로 두 스위트의 조회가 통째로 성립하지 않고, 「행 라벨 클릭으로 펼침」·「재렌더링 뒤 펼침 유지」·「왼쪽 끝 클릭에도 팝오버가 닫히지 않음」이라는 세 회귀 그물을 스스로 걷어내게 됩니다.
- **`DisclosureGroup` 유지** (채택).

`DisclosureGroup`의 제어 한계는 실측해 보니 이 feature가 필요한 범위에서는 문제가 되지 않습니다.
펼친 내용에 들여쓰기도 위아래 여백도 **0pt**를 주므로, 내용을 `VStack`으로 감싸고 `.padding(.leading/.top/.bottom)`을 거는 것만으로 두 시작선과 네 간격이 전부 원하는 값이 됩니다 — `DisclosureGroup`이 몰래 더하는 몫을 빼거나 상쇄할 필요가 없습니다.
라벨 행이 갖는 위아래 4pt 자체 여백은 부모가 걸린 두 경계의 잉크 간격을 그만큼 넓히지만, 넷의 순서를 뒤집지 않으므로 상수에서 빼지 않습니다.
라벨 쪽 삼각형 폭 12pt는 제어할 수 없지만, 그 값은 시작선 유도에 쓰는 상수일 뿐 없애야 할 대상이 아닙니다.

따라서 기존 탭 동작과 펼침 유지가 그대로 남고(`SPEC §5.6`), 세 UI 스위트를 고치지 않아도 됩니다.

### DP8. 새 표시 요소가 400×480을 넘기는가, 넘기면 무엇이 스크롤로 가는가

상세 팝업은 이미 넘칩니다 — `DashboardView.swift:88-98`의 주석이 실행 환경에서 잰 자연 크기를 CPU 상세 (406, 8849), Memory 상세 (371, 9056)로 기록하고 있습니다.
앱 목록이 실행 중인 모든 앱을 나열하기 때문이고, 이 feature가 그 사실을 바꾸지 않습니다.
따라서 판단해야 할 것은 「넘치는가」가 아니라 「무엇이 첫 화면 안에 남는가」입니다.

세로 예산은 480 − 상단 padding 16 = **464pt**입니다.
격자 아래끝까지의 높이는 `52 + 격자 높이`이고(요약 줄 13 + 간격 6 + 격자 머리글 13 + 간격 4), 격자 높이는 `54 × 행 수 − 6`입니다.

- 논리 코어 **14개** — 7열 2행, 격자 102pt, 아래끝 **154pt**. 격자 전체가 스크롤 없이 한 화면에 들어옵니다(`SPEC §5.4`).
- 24개는 208pt, 32개는 262pt로 모두 첫 화면 안입니다.
- `52 + (54r − 6) ≤ 480`을 풀면 `r ≤ 8`이므로 **논리 코어 64개(8열 8행, 격자 426pt, 아래끝 478pt)까지** 격자가 스크롤 없이 들어옵니다.
- 65개 이상에서는 격자 아래끝이 첫 화면을 벗어나고(9행, 격자 480pt), 기존 세로 스크롤이 그 몫을 받습니다. 팝업의 고정 크기는 그대로입니다.

**하위 행이 두 줄이 되어도 이 예산은 그대로입니다.**
`CPUDetailView`의 `VStack` 순서가 요약 → 코어 격자 → Load Average → 앱 목록이라 앱 목록이 격자보다 아래에 있고, 아래 항목이 길어져도 위 항목의 세로 위치를 밀지 않습니다(§근거에서 배치 순서 확인).
따라서 두 줄 구조가 더하는 높이는 전부 격자 아래에서 생기고, `SPEC §5.4`가 요구하는 「14코어 격자가 스크롤 없이」는 영향을 받지 않습니다.

스크롤로 가는 것은 **Load Average 아래의 앱 목록**이며, 이는 이 feature 이전과 같습니다.
코어 줄이 26pt(14코어 기준 두 줄로 접힌 `Text`)에서 119pt(머리글 13 + 간격 4 + 격자 102)로 늘어 앱 목록이 93pt만큼 아래로 밀립니다.
하위 행이 더하는 몫은 펼친 그룹 하나당 `18 + 38 × 하위 수 − 10 + 24`pt이고, 앱 목록은 이미 스크롤 영역이라 팝업 크기에 영향을 주지 않습니다.

가로는 넘기지 않습니다 — 격자는 콘텐츠 폭을 열 수로 나눠 쓰고, 두 줄 구조의 이름 줄(최장 265.0pt)과 값 줄(167.0pt)이 모두 360pt 안에 들어갑니다.
spec.md §4가 제외한 가로 스크롤을 새로 만들 이유가 생기지 않습니다.

### DP9. 값 없음(수집 중·실패·중지) 상태의 자리표시

앞 feature가 이 자리에서 다섯 번 연속 reject된 전례가 있고, 원인은 「값이 없을 때 새 표시 요소 중 하나라도 그리지 않으면 실패해야 한다」가 전칭 조건인데 그 전수 목록이 어디에도 없었다는 것이었습니다.
그래서 먼저 이 feature가 더하는 표시 요소를 전수 열거합니다 — ① 코어 격자 머리글 ② 코어 칸의 막대 트랙 ③ 막대 채움 ④ 칸의 화면 수치 ⑤ 칸의 코어 번호 ⑥ 마지막 행의 빈 칸 자리 ⑦ 하위 행 이름 줄의 시작선 ⑧ 하위 행 값 줄의 시작선 ⑨ 네 간격.

고려한 옵션은 둘입니다.

- **값 없음 상태에도 격자와 하위 행의 자리를 같은 높이로 남긴다** — 카드가 쓰는 자리표시 규칙을 상세에도 확장합니다. 대가: 팝업은 카드와 사정이 다릅니다. 상세 본문 전체가 `.normal` 밖에서는 안내 문구 하나로 대체되고, 팝업 크기는 `.frame(width:height:)`가 상태 분기 밖에서 이미 고정합니다. 자리를 남겨도 지켜지는 것이 없고, 코어가 몇 개인지 모르는 상태에서 격자의 행 수를 지어내야 합니다.
- **값 없음 상태의 표시 경로를 그대로 둔다** (채택).

채택 근거는 도달 가능성입니다.
위 아홉 요소는 전부 `.normal` 분기 **안쪽**에만 있고, 값 없음 세 상태에서는 어느 것도 그려지지 않습니다 — 「일부만 빠지는」 조합 자체가 도달 불가능합니다.
그리고 `SPEC §5.5`가 요구하는 것은 상태를 오갈 때 **팝업의 크기와 카드의 위치**가 변하지 않는 것인데, 팝업 크기는 상태와 무관한 `.frame`이 정하고 카드는 이 feature가 건드리지 않습니다.

`.normal` 안쪽에서 값이 비는 경우도 확인했고 도달하지 않습니다.
`CPUSystemMetricsCollector`는 코어 배열을 만들 수 없는 모든 경우에 `nil`을 돌려주므로 `coreUsages`가 빈 채로 `.normal`에 들어오지 못하고, 진행하지 않은 코어도 0으로 자리를 채웁니다.
하위 프로세스 값이 없는 행은 기존 `ApplicationProcessValueFormatting`이 `"-"`로 그리며, 두 줄 구조에서 그 `"-"`는 값 줄에 놓입니다 — 값 줄 자체를 없애지 않으므로 행 높이가 값 유무에 따라 달라지지 않습니다.

따라서 이 feature는 값 없음 자리표시를 새로 만들지 않습니다.
남는 검증 부담은 「아홉 요소가 `.normal`에서 실제로 그려지는가」이고, 이는 상태별 분기가 아니라 요소 전수 목록으로 확인할 문제입니다.

### DP10. 새 표시 요소를 접근성 계층에 어떻게 드러내는가

`SPEC §5.7`은 코어별 사용률에서 코어 번호와 값이, 하위 프로세스 행에서 소속 앱과 값이 읽히기를 요구합니다.

**코어 칸**은 칸 하나를 접근성 요소 하나로 합칩니다.
안쪽의 막대·수치·번호를 각각 읽히게 두면 `"13"` 같은 조각이 홀로 낭독되므로 자식을 무시하고, 이름은 `"코어 <번호>"`, 값은 `"<수치>%"`로 나눠 답니다 — `MemoryCompositionDonutView`가 도넛을 요소 하나로 합쳐 이름을 붙인 것과 같은 형태입니다.
칸마다 `CPUCore-<번호>` 식별자를 붙여 UI 테스트가 특정 칸을 가리킬 수 있게 합니다(`AppRow-<앱 키>`와 같은 관례).

**하위 프로세스 행**은 두 옵션이 갈립니다.

- **행 전체를 요소 하나로 합침(`children: .combine`이나 `.ignore`)** — 대가: `.ignore`는 AX 요소를 0개로 만들어 `value CONTAINS "PID"` 조회 자체를 깨뜨립니다.
  `.combine`은 AX 요소 하나의 label을 빈 문자열로 만들고 모든 문자열을 value에 이어 붙여 해당 조회는 통과하지만, 이름·값 두 요소 분리가 사라져 같은 `AppRow-<앱 키>` 식별자의 `StaticText` 2개 단언과 이름 줄 접근성 이름의 소속 앱 단언이 실패합니다.
- **두 `Text`를 그대로 두고 이름 줄에만 접근성 이름을 덧붙임** (채택).

채택안은 이름 줄 `Text`의 접근성 이름을 `ApplicationProcessRowFormatting.childAccessibilityLabel`이 만든 「소속 앱 + 실행 파일 이름 + PID」로 바꾸고, 값 줄 `Text`는 손대지 않습니다.
요소를 합치지 않으므로 이름 줄과 값 줄은 독립된 AX 요소로 남습니다.
macOS XCUITest에서는 이름 줄에 붙인 SwiftUI `accessibilityLabel`이 해당 `StaticText`의 value로 드러나 소속 앱·실행 파일 이름·PID를 담고, 손대지 않은 값 줄의 value는 화면 문자열 그대로 남습니다.
따라서 두 UI 스위트의 `value CONTAINS "PID"` 조회가 유지되고 접근성 계층에서의 낭독 순서(이름 → 값)도 화면 순서와 같아집니다.
대가는 소속 앱과 값이 한 요소로 묶여 낭독되지 않는 것인데, 두 요소가 인접해 있어 행 단위 탐색으로는 이어집니다.

값 줄 `Text`를 감추는 선택은 하지 않습니다 — 화면에 보이는 수치를 접근성 계층에서 지우는 셈이라 `SPEC §5.7`과 정면으로 부딪힙니다.

문자열은 전부 순수 함수(`CPUCoreUsageFormatting`·`ApplicationProcessRowFormatting`·기존 `ApplicationProcessValueFormatting`)가 만듭니다.
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
