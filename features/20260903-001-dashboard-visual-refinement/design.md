# 대시보드 시각 정리 설계

## 근거

spec.md는 §1부터 §5까지 전부 읽었습니다.
`승인 전 확인` 섹션은 spec.md에 없으므로 미답 질문은 없습니다.
범위는 spec.md §1이 제한하는 표시 계층 안이고, 요구사항을 더하거나 약하게 바꾸지 않았습니다.

읽은 입력 맥락 — `ROADMAP.md` M2, `docs/product.md` 「대시보드 > 공통 정보 구조·접근성」·「CPU > 기본 카드·상세 정보·TOP 5 정책」·「Memory > 기본 카드·상세 정보」, `docs/design.md` 「SwiftUI 레이아웃과 접근성 제약」 전체, core-resource-monitoring `SPEC §5.13`·`§5.15`, resource-visualization `§3`·`§5.3`·`§5.5`·`§5.8`, detail-popover-readability `§3`·`§5.1`·`§5.2`와 그 feature의 design.md 전문.

### 코드에서 확인한 사실

- 본체(`ResourceRunner/DashboardView.swift:26-70`)는 `VStack(spacing: 8)`에 제목 `Text("ResourceRunner").font(.headline)`(`:27-32`)와 두 `Button`을 담고 `.padding()` + `.frame(width: 280, height: 488)`로 닫습니다.
  제목에는 `accessibilityIdentifier("DashboardTitle")`이 붙어 있고, 그 이유는 상세 팝업의 앱 자신 프로세스 행 라벨이 같은 문자열이라는 것입니다(`:29-31` 주석).
- 카드는 `Button` + `.buttonStyle(.plain)` + `.keyboardShortcut(_:modifiers:)` + `.accessibilityElement(children: .ignore)` + `.accessibilityLabel(...)` + `.isButton` + 식별자 조합입니다(`:39-49`, `:54-63`).
  선택 상태는 카드에 앵커한 자식 `.popover`로만 표현되고 본체 레이아웃에 참여하지 않습니다.
- 카드 배경은 `RoundedRectangle(cornerRadius: 8).fill(.quaternary)`(`:178`, `:341`)이고 `.contentShape`는 없습니다 — 지금은 이 불투명 채움이 카드 전체의 클릭 대상을 만들어 주고 있습니다.
- 상시 단축키 줄은 `Text("\(…selectionShortcutDisplayText) 선택·복귀").font(.caption2)`(`:172-174`, `:335-337`)이고, 같은 `selectionShortcutDisplayText`가 카드 접근성 이름의 `"단축키 ⌘1"`(`DashboardPresentation.swift:337`, `:1002`)에도 쓰입니다.
  `selectionShortcutKey`(`DashboardPresentation.swift:158`, `:922`)가 `KeyEquivalent`(`DashboardView.swift:83`, `:86`)와 표시 문자열의 공통 출처입니다.
- 값을 오른쪽에 두는 자리는 넷이 아니라 **다섯**입니다 — `CardRankingSlotView.rowContent`(`:790-794`), `ApplicationProcessGroupRow` 라벨(`:1487-1495`), `TopApplicationsView`(`:836-844`), `MemoryCompositionDonutView` 범례(`:1333-1339`), 그리고 값이 칸 안에 놓이는 `CPUCoreUsageCellView`(`:1168-1170`).
  앞 넷은 모두 `HStack` + `Spacer()`이고 폭 고정 수단이 없습니다.
- 뷰 밖 순수 상수에 레이아웃을 두고 단위 테스트가 그 상수를 직접 단언하는 관례가 이미 확립돼 있습니다 — `CPUCoreGridLayout`(`DashboardPresentation.swift:376`), `ApplicationProcessRowLayout`(`:418`), `MemoryCompositionLegendFormatting`(`:779`), `ApplicationRowIconLayout`(`ApplicationRowIcon.swift:28`), `MemoryCompositionBarLayout`(`DashboardView.swift:488`), `CardRankingRowLayout`(`:810`).
  글꼴·간격·색은 이 관례 밖에 있고 뷰 본문에 리터럴로 흩어져 있습니다.
- `DashboardColorPalette`를 쓰는 production 파일은 `DashboardView.swift` 하나입니다.
  Memory 4색(`DashboardColorPalette.swift:53-56`)과 CPU 2색(`:18`, `:20`)은 라이트·다크 각각 확정된 값이고, `cpuGridline`·`cpuCoreTrack`·`cpuCoreFill`·`memoryCompositionTrack`은 「구분 대상이 아닌 배경 대비 요소」라는 이유로 시스템 색입니다(`:22-30`, `:49-51`).
- 바이트 서식은 `ByteCountFormatter(countStyle: .memory)`를 카드(`DashboardView.swift:309-317`)와 Memory 상세(`:1202-1210`)가 각자 만들어 쓰고, 상세 목록·증가량 순위·범례는 그 함수를 클로저로 받아 씁니다.
- CPU 밴드는 `fillOpacity` 0.5/0.28과 경계선 점선 `[3, 2]`/실선으로 색 외 구분을 만들고(`DashboardView.swift:546-568`), 격자를 맨 아래에 깔아 반투명 채움을 통해 비치게 합니다(`:538-544`).

### 실측한 값 (이 기기, macOS 26.6.2)

`NSHostingController.sizeThatFits`로 직접 쟀습니다(앞 feature들이 쓰는 것과 같은 수단). 아래 수치는 모두 이 측정의 결과입니다.

- 한 줄 높이 — `.caption` 13.0, `.caption2` 13.0, `.subheadline` 14.0, `.subheadline.bold()` 14.0, `.callout` 15.0, `.headline` 16.0, `.title3` 19.0, `.title2` 21.0, `.title2.weight(.semibold)` 21.0.
  `.caption`과 `.caption2`는 **줄 높이가 같고** 같은 문자열 폭 차이가 1pt 이내(`"100%"` 27.0 대 28.0)입니다.
- 현재 카드 높이는 이 줄 높이로 산술이 정확히 맞습니다 — CPU `14 + 28 + 60 + 88 + 13 + (6 × 4) + 16 = 243`, Memory `14 + 13 + 13 + 88 + 13 + (6 × 4) + 16 = 181`.
  기존 테스트 기준값(`DashboardCardLayoutTests.swift:657-658`)과 일치합니다.
- 현재 본체 콘텐츠 높이도 산술이 맞습니다 — `16(.headline 제목) + 243 + 181 + (8 × 2) + 32(padding) = 488` = `DashboardView.bodyHeight`.
- `.padding()` 기본값은 좌우·위아래 각 16pt입니다(`"X"` 7.0×13.0 → 39.0×45.0).
- `monospacedDigit()`이 없으면 자릿수에 따라 폭이 흔들립니다 — `.caption`에서 `"100%"` 27.0, `"111%"` 24.0. `monospacedDigit()`을 걸면 둘 다 29.0입니다.
- 글꼴 굵기는 한글에서도 실제 face가 갈립니다 — `NSFont.systemFont(ofSize: 11, weight:)`가 regular `.AppleSystemUIFont`, medium `…Medium`, semibold `…Demi`, bold `…Bold`를 돌려줍니다.
  한글 문자열 폭 변화는 0.2pt 이내(97.91 → 98.05)이므로 굵기를 위계 수단으로 써도 줄 폭이 흔들리지 않습니다.
- 초점 글꼴 후보별 조립 카드 높이(폭 248pt, 제목·단축키 줄 제거, 묶음 간격 8pt) — `.title2.weight(.semibold)`에서 CPU 231.0 / Memory 169.0, `.system(size: 22, weight: .semibold)`에서 CPU 236.0 / Memory 174.0.
  모든 후보가 243/181 상한 안에 들어옵니다.
- Memory 제목 줄의 폭이 초점 크기의 실제 상한입니다(카드 콘텐츠 폭 232pt) — `.title2.weight(.semibold)`에서 대표값 `Memory 12.4 GB / 16 GB` 145.0(바에 79.0 남음), 128GB 기기 최악 `Memory 112.4 GB / 128 GB` 162.0(바 62.0), 실패 줄 `Memory 수집 실패 · 마지막 112.4 GB` 194.0(바 30.0).
  `.system(size: 22)`에서는 최악 182.0(바 42.0), 실패 214.0(바 10.0)까지 좁아집니다.
- 값 열 폭(`.caption.monospacedDigit()` 숫자 / `.caption` 단위) — 숫자 `"9999"` 26.0, `"1023.9"` 36.0, `"+1023.9"` 42.0, `"-1023.9"` 40.0. 단위 `" %"` 13.0, `" GB"` 18.0, `" % (코어 합산)"` 61.0.
- 값 열을 고정한 뒤 이름에 남는 폭 — CPU 상세 앱 행 237.0(목록 안쪽 360pt), Memory 상세 앱 행 270.0, 카드 순위 CPU 173.0 / Memory 158.0(카드 232pt), 상세 범례 137.0, 증가량 순위 270.0.
- 코어 칸 — `.caption.monospacedDigit()`에서 `"100%"` 29.0. 8열 칸 폭은 콘텐츠 368pt에서 칸 간격 8pt일 때 39.00pt, 스크롤러로 좁아진 353pt에서 37.12pt.
- 14코어 격자 높이(칸 간격 8pt, 2행) 104.0 → 팝업 위끝부터 격자 아래끝까지 `16 + 13 + 16 + 13 + 4 + 104 = 166`.

### 색 검증 (검증기를 직접 돌린 결과)

sRGB↔CIELAB 변환, WCAG 명도대비, Machado 2009 severity 1.0 색맹 시뮬레이션(protan·deutan·tritan), CIEDE2000을 구현한 스크립트를 **실제로 실행했습니다**.
검증기가 spec.md §1에 기록된 수치를 그대로 재현했습니다 — 현재 라이트 대비 App 3.74 / Wired 2.71 / Compressed 2.38 / Cached 1.83, 인접쌍 ΔL\* 라이트 9.3/3.9/8.3, 다크 1.9/3.8/3.1.
따라서 spec.md가 「추정」으로 적어 둔 값은 확인된 값입니다.

새 램프의 측정값은 §5 DP8에 표로 둡니다.
배경은 spec.md §1의 근사(라이트 `#ECECEC`, 다크 `#2E2E2E`)를 그대로 썼습니다.

### 기존 테스트가 잠그고 있는 것

- `DashboardCardLayoutTests.swift` — 카드 높이 리터럴 243.0(`:657`, `:677`)·181.0(`:586`, `:658`, `:692`), 측정 폭 248(`:130`), 픽셀 영역 리터럴 `cpuPlaceholderSummary` y 42..<57·`cpuPlaceholderGraph` y 60..<124·`memoryPlaceholderTrack` x 210..<238 y 11..<19·`cpuFirstRankingIcon` x 8..<20 y 129..<141(`:150-153`), 카드 배경 알파 임계 `> 0.12`(`:157`), 스와치 채도 `> 0.35`와 색조 범위 User `0.52...0.68`·System `0.0...0.12`(`:163-165`, `:355-356`).
- `ApplicationProcessRowLayoutTests.swift` — 네 경계 2/10/18/26(`:288-291`)과 `within < between < top < bottom`(`:299-302`), `childIndent == 12 + 16 + 6`·`childValueIndent == childIndent + 16`(`:239-242`), 접힘 행 24.0(`:314`), 펼침 증가 `70 + (n-1) × 38`(`:309`), `"12% (코어 합산) · Rosetta"`(`:334`), 목록 안쪽 폭 360(`:6`).
- `DetailPopoverValuelessStateTests.swift` — 4상태 팝업 프레임 400×480(`:352-353`), 값 없음 세 상태의 픽셀 완전 일치(`:370-373`), `DetailPopoverNewDisplayElement` 9개 전수(`:395-396`).
- `CPUCoreGridVerticalBudgetTests.swift` — 14코어 격자 아래끝 `== 154`(`:149`), 64코어 `== 478`(`:167`), 65·80·128코어는 480 초과(`:174-177`), 좁힌 폭 353(`:23-24`, 주석에 추정이라고 명시).
- `CPUCoreUsageGridTests.swift` — 격자 높이 공식(`:187-191`)·마지막 행 열 정렬(`:219-222`)·칸 안 잉크 띠 3개와 순서(`:233-248`)·격자 보고 폭 == 368(`:418-421`)은 모두 상수에서 유도되므로 상수를 바꾸면 따라옵니다.
- `ApplicationRowIconTests.swift:100-102` — `cardPointSize`(12) ≤ `.caption` 실측 줄 높이. 리터럴이 아니라 측정값과 비교하는 관례의 예입니다.
- `DashboardDetailPopoverUITests.swift:23` — 상세 크기 `CGSize(400, 480)`를 테스트 쪽에 복제한 리터럴.
- `DashboardCardSelectionUITests.swift:137-139`, `:173` — `app.staticTexts["DashboardTitle"]`을 「자식 팝업 밖·부모 팝오버 안」 클릭 대상으로 씁니다. 이 요소가 사라지면 3·5단계가 클릭 대상을 잃습니다.
- `ResourceRunnerUITests.swift:28`, `:45` — `app.staticTexts["ResourceRunner"]`가 팝오버 열림·닫힘 판정의 유일한 근거입니다.
- `DashboardProcessListDisplayUITests.swift:96-98` — 앱 행 `triangle.label`이 앱 이름과 `"%"`를 함께 포함. `:126-133` — 같은 `AppRow-<키>` 식별자의 `StaticText`가 정확히 2개.
- `CPUCoreAccessibilityUITests.swift:35-46` — 코어 칸 라벨 `"코어 0"`, 값 `^[0-9]+%$`, 하위 요소 수 0.
- `DashboardMemoryCardUITests.swift:138` — 바이트 수치 패턴 `(?:Zero|[0-9][0-9.,]*) ?(?:bytes|[KMGT]?B)`. `:173-180` — 앞 3개 행 라벨에 `KB|MB|GB`가 있고 `"bytes"`는 없어야 함.
- 단축키 문자열이 카드 접근성 이름에 들어 있는지는 UI 테스트가 아니라 `DashboardPresentationTests.swift:566`·`:595`·`:991`·`:1020`·`:1500`·`:1504`가 단언합니다.

### 의존 탐색 흔적 (§4의 근거)

- `DashboardColorPalette` production 소비자는 `DashboardView.swift` 하나입니다.
- `ApplicationProcessGroupListView` 호출부는 `CPUDetailView`(`:1007`)와 `MemoryDetailView`(`:1258`) 둘뿐이므로 앱 행 변경은 두 상세에 동시에 반영됩니다.
- `TopApplicationsView` 호출부는 `MemoryDetailView`(`:1247`) 하나입니다.
- `CardRankingSlotView` 호출부는 `CPUCardView.rankingSlot`(`:184`)과 `MemoryCardView.rankingSlot`(`:345`) 둘입니다.
- `ApplicationProcessValueFormatting`(`ApplicationRanking.swift:259`) 호출부는 `CPUDetailView`(`:1011`, `:1013`)와 `MemoryDetailView`(`:1263`)입니다.
- `selectionShortcutDisplayText` 소비자는 화면 텍스트 2곳(`:172`, `:335`)과 접근성 이름 2곳(`DashboardPresentation.swift:337`, `:1002`)입니다.
- `bodyHeight`·`detailPopupWidth`·`detailPopupHeight` 소비자는 `DashboardView`(`:69`)와 두 상세 콘텐츠(`:880`, `:917`), 그리고 테스트입니다.

### 추정으로 남는 것

- 팝오버 표면은 반투명 재질이라 실제 합성 배경은 뒤에 있는 화면 내용에 따라 달라집니다.
  라이트 배경이 `#E0E0E0`만큼 어두워지면 새 램프의 밝은 단계가 2.94:1로 3:1을 밑돌고, 다크 배경이 `#454545`만큼 밝아지면 진한 단계가 2.64:1로 밑돕니다(검증기 실행 결과).
  spec.md §1이 정한 근사 안에서는 여덟 색 모두 통과합니다.
- 「초점 수치가 가장 먼저 읽힌다」·「섹션 경계가 보인다」·「두 카드가 구분된다」는 지각 판정이므로 실측이 아니라 화면 확인의 몫입니다.
- `NSPopover`가 콘텐츠 크기에 더하는 26pt는 앞 feature가 이 OS 버전에서 실측한 값입니다.
- 새 본체 높이 448pt는 위 줄 높이 실측에서 유도한 산술값이며, §5 DP11의 절차로 다시 실측해 확정해야 합니다.

## 1. 구조

새 모듈이나 레이어를 만들지 않습니다.
표시 계층의 경계를 셋 추가하고, 나머지는 지금의 뷰 트리 모양(본체 → 두 `Button` → 카드 뷰 → 자식 팝오버 → 상세 뷰)을 그대로 씁니다.

### 시각 규칙 경계 — `DashboardStyle`

지금 `DashboardView.swift` 한 파일에 리터럴로 흩어진 글꼴·간격·표면 값을 뷰 밖 한 자리로 모읍니다.
이 저장소가 이미 쓰는 관례(뷰 밖 순수 상수 + 그 상수를 직접 단언하는 단위 테스트, `CPUCoreGridLayout`·`ApplicationProcessRowLayout`·`ApplicationRowIconLayout`)를 그대로 따릅니다 — 시각 규칙이 뷰 본문에 남으면 회귀를 잡는 수단이 렌더 픽셀뿐이고, 지금 27번 쓰인 `.caption`·`.caption2` 같은 중복이 다시 자랄 자리가 생깁니다.

경계는 **숫자와 글꼴 서술자로 표현되는 결정**입니다.
- 타이포 역할 네 단계(`focus`·`value`·`label`·`heading`)와 각 역할의 글꼴·전경색(`SPEC §5.1`).
- 여백 단계 집합(2 / 4 / 8 / 16pt)과 각 단계의 담당 자리(`SPEC §5.4`).
- 카드 표면 상수 — 모서리 반경, 테두리 두께, 테두리 색 슬롯(`SPEC §5.3`).

경계 밖에 두는 것은 뷰 조립(무엇을 어떤 순서로 그리는지)과 이미 다른 자리가 소유한 값입니다.
`ApplicationProcessRowLayout`의 하위 프로세스 네 경계 간격, `CPUCoreGridLayout`의 행·열 분할, `ApplicationRowIconLayout`의 아이콘 자리 크기는 그 자리에 그대로 둡니다.
`DashboardStyle`은 그 자리들이 참조할 여백 단계를 제공하기만 합니다.

### 값 정렬 경계 — `DashboardValueColumn`

값 우측 정렬을 다섯 자리가 공유하는 규칙으로 만듭니다(`SPEC §5.2`, `SPEC §5.8`).
지금은 `CardRankingSlotView`·`ApplicationProcessGroupRow`·`TopApplicationsView`·`MemoryCompositionDonutView`가 각자 `HStack` + `Spacer()`로 값을 밀고, `CPUCoreUsageCellView`는 칸 안에 값을 중앙 배치합니다 — 어느 자리도 폭을 고정하지 않으므로 이름 길이와 자릿수가 값의 위치를 바꿉니다.

`Spacer()`만으로는 `SPEC §5.2`가 요구하는 「단위와 소수점 자리가 같은 세로선」이 성립하지 않습니다.
값의 오른쪽 끝만 맞으므로 `7.8 GB`와 `112.4 GB`는 소수점이 갈리고, `1.2 GB`와 `980 MB`는 단위조차 갈립니다.
그래서 세 수단을 함께 씁니다.
- **폭 고정 숫자** — 숫자를 나르는 모든 글꼴 역할에 `monospacedDigit()`을 겁니다. 실측에서 이것 없이는 `"100%"` 27.0 대 `"111%"` 24.0으로 3pt가 흔들립니다.
- **자릿수 고정 서식** — 값 종류마다 소수 자리 수를 고정합니다(`SPEC §5.2`가 요구하는 소수점 정렬이 이것 없이는 성립하지 않습니다).
- **고정 폭 두 열** — 값을 `(숫자, 단위)` 쌍으로 나누고, 숫자는 폭 고정 열에서 오른쪽 정렬, 단위는 그 옆 폭 고정 열에서 왼쪽 정렬합니다.

`Grid`의 자동 열 폭을 쓰지 않는 이유는 `ApplicationProcessGroupRow`의 값이 각 행의 `DisclosureGroup` **라벨** 안에 있어 여러 행이 한 `Grid`를 공유할 수 없다는 것입니다.
따라서 열 폭은 뷰 밖 상수여야 하고, 그 상수가 값 종류(percent / bytes / signedBytes)와 함께 이 경계에 모입니다.
열 폭이 실제로 넉넉한지는 단위 테스트가 그 종류의 가장 넓은 문자열의 이상적 폭과 견주어 지킵니다 — `ApplicationRowIconTests.swift:100-102`가 쓰는 것과 같은 방식(리터럴 대신 측정값 비교)입니다.

이 경계는 값 종류별로 소수 자리 수·단위 선택 규칙·두 열 폭을 함께 소유합니다.
셋을 갈라 두면 서식이 바꾼 문자열 길이가 열 폭에 반영되지 않습니다.

### 정렬된 값 꼬리를 그리는 뷰 하나

다섯 자리가 같은 조립을 공유하도록, `(숫자 열, 단위 열)`을 그리는 뷰를 하나 두고 그 뷰만 씁니다.
자리마다 `HStack`을 다시 조립하면 한 자리에서 열을 빼먹는 변경이 나머지 자리의 단언으로는 드러나지 않습니다.

이 뷰는 두 `Text`를 `.accessibilityElement(children: .combine)`으로 묶습니다.
`docs/design.md` 「접근성 역할과 값」이 `.combine`은 자식 문자열을 `AXValue`에 이어 붙이고 `AXLabel`은 비운다고 기록해 두었고, UI 테스트가 상세 내용을 `staticTexts.value CONTAINS`로 조회하므로(`DashboardDetailPopoverUITests.swift:16-17` 주석) 값을 두 열로 나눠도 접근성 계층에서는 한 노드·한 문자열로 남습니다(`SPEC §5.11`).

`CPUCoreUsageCellView`의 칸 안 수치는 열을 나누지 않고 칸 폭 안에서 오른쪽 정렬만 합니다(`SPEC §5.8`).
칸은 이미 균등 분할로 폭이 같고 값이 정수 퍼센트 한 종류뿐이라, `monospacedDigit()`과 오른쪽 정렬만으로 `%` 기호가 모든 칸에서 같은 x에 놓입니다.

### 색 경계 — `DashboardColorPalette`의 모양 변경

자리는 그대로 두고 내부 모양을 바꿉니다.
지금은 여섯 개의 독립 색 상수인데, **두 색조 × 두 단계** 램프와 그 램프의 슬롯 지정으로 재구성합니다(`SPEC §5.6`).
색조 A는 CPU 두 계열과 Memory App·Wired가, 색조 B는 Memory Compressed·Cached가 씁니다.
라이트·다크는 각각 확정된 값이며 한쪽에서 반전으로 유도하지 않습니다(현재 주석 `DashboardColorPalette.swift:14-15`의 근거를 그대로 유지).
`cpuGridline`·`cpuCoreTrack`·`cpuCoreFill`·`memoryCompositionTrack`은 구분 대상이 아닌 배경 대비 요소라는 기존 이유가 그대로여서 시스템 색으로 남습니다.

### 본체·카드 조립의 변경

- 본체에서 제목 줄을 지웁니다. 본체 컨테이너에 안정적인 접근성 식별자를 새로 붙여, 제목을 팝오버 앵커·클릭 대상으로 쓰던 UI 테스트가 옮겨갈 자리를 남깁니다(`SPEC §5.5`, `SPEC §5.11`).
- 두 카드에서 상시 단축키 줄을 지웁니다. `keyboardShortcut` 등록과 접근성 이름의 단축키 문구는 그대로 둡니다(`SPEC §5.5`).
- 카드 배경을 불투명 채움에서 테두리로 바꾸고, 사라진 불투명 영역이 만들던 클릭 대상을 `contentShape`로 되살립니다(`SPEC §5.3`).
- 카드 안 슬롯을 「묶음」으로 다시 묶습니다. 표시 항목의 순서와 개수는 바꾸지 않고, 어느 줄들이 한 묶음인지만 정합니다(`SPEC §5.4`).
  CPU 카드는 `[제목·초점·계열 요약]` / `[그래프]` / `[순위]` 세 묶음, Memory 카드는 `[제목·구성 바]` / `[Pressure·Swap 줄, 구성 범례 줄]` / `[순위]` 세 묶음입니다.
- 상세는 루트 `VStack`의 묶음 경계만 조정합니다. CPU 상세는 `[요약]` / `[코어 격자]` / `[Load Average]` / `[앱 목록]` 네 섹션, Memory 상세는 `[도넛·범례]` / `[사용 중 줄, Swap 줄]` / `[증가량 순위]` / `[앱 목록]` 네 섹션입니다(`SPEC §5.7`).

## 2. 데이터 흐름

이 feature는 상태를 더하지 않고, 새 입력·새 통합 지점·새 실패 경로도 만들지 않습니다.
수집 → 조립 → 표시 경로는 그대로입니다.

`MonitoringScheduler` tick → `ApplicationCoordinator` → `DashboardPresentationStore.updateCPUCard`·`updateMemoryCard` → `ResourceCardState<Presentation>` → `CPUCardView`·`MemoryCardView`(그리고 선택된 카드의 자식 팝오버 → `CPUDetailView`·`MemoryDetailView`).

바뀌는 지점은 마지막 한 칸, **표시 값이 화면 문자열이 되는 자리**뿐입니다.

1. 조립된 표시 값(`overallUsage`, `usedBytes`, `ApplicationRankingEntry.value`, `compositionBytes`, `coreUsages`, `ApplicationProcessGroup.sortValue`)은 지금과 같습니다.
2. 그 값이 문자열이 될 때 `DashboardValueColumn`이 값 종류에 맞는 `(숫자, 단위)` 쌍을 만듭니다. 지금은 각 자리가 `ByteCountFormatter`나 문자열 보간으로 이어 붙인 한 덩어리를 만듭니다.
3. 정렬된 값 꼬리 뷰가 그 쌍을 두 고정 폭 열에 놓습니다.
4. 글꼴·전경색·간격은 뷰 본문 리터럴이 아니라 `DashboardStyle`의 역할·단계에서 옵니다.
5. 색은 `DashboardColorPalette`의 램프 슬롯에서 옵니다. 램프의 라이트·다크 선택은 지금처럼 `NSColor(name:)` 클로저 안에서 AppKit이 appearance를 판정해 결정하므로, 갱신 주기와 무관합니다(`SPEC §5.13`).

상태 전이는 그대로입니다 — `collecting` / `normal` / `failure(lastKnown)` / `stopped(lastKnown)` 넷과 `DashboardSelection`의 `none` / `cpu` / `memory` 셋.
네 상태가 같은 슬롯 집합을 그린다는 계약도 그대로이며, 단축키 줄 슬롯 하나가 모든 상태에서 함께 없어질 뿐입니다(`SPEC §5.9`).
초점 줄은 상태에 따라 문자열이 달라지지만 슬롯이 갈리지 않습니다 — 상태 접두(`수집 실패 · 마지막 `)는 `label` 역할, 값은 `focus` 역할로 **한 줄 안에서** 이어 붙습니다.
그래서 줄 수와 줄 높이가 상태와 무관하고, 자리표시(`CPUSeriesPlaceholderLayout`, `MemoryPressureSwapLineFormatting.placeholder`, `MemoryCompositionBarLayout.placeholderSegments`, 순위 자리표시 줄)의 규칙도 그대로 성립합니다.

## 3. 인터페이스

경계를 가로지르는 계약만 둡니다.

- **`DashboardStyle`** — `DashboardView.swift`의 모든 뷰와 단위 테스트가 소비합니다.
  타이포 역할 네 개를 글꼴 값으로, 여백 단계 네 개를 `CGFloat`로, 카드 표면 상수를 값으로 내놓습니다.
  기존 레이아웃 상수 자리(`ApplicationProcessRowLayout`, `CPUCoreGridLayout`, `ApplicationRowIconLayout`)는 여백 단계를 이 자리에서 가져다 자기 값을 유도합니다.
- **`DashboardValueColumn`** — 값 종류(percent / bytes / signedBytes)를 받아 `(숫자 문자열, 단위 문자열)`과 두 열 폭을 내놓습니다.
  바이트 표시 규칙(1024 기반, 단위 하한 KB, 소수 한 자리 고정, 로케일 소수 구분자)이 이 자리 하나에 있습니다.
  지금 카드와 Memory 상세가 각자 만들던 `ByteCountFormatter` 인스턴스와 `format(_:)` 클로저가 이 자리로 합쳐집니다.
- **정렬된 값 꼬리 뷰** — 다섯 자리가 공유합니다. `(숫자, 단위)` 쌍과 값 종류를 받습니다.
- **값 서식 클로저의 형태 변경** — `CardRankingSlotView.valueText`, `TopApplicationsView.valueText`, `ApplicationProcessGroupListView.groupValueText`·`valueText`가 지금은 `-> String`입니다.
  앞 셋은 `(숫자, 단위)` 쌍을 돌려주도록 바뀝니다.
  `ApplicationProcessGroupListView.valueText`(하위 프로세스 값 줄)는 우측 정렬 대상이 아니므로 `-> String`을 유지합니다 — 하위 행은 detail-popover-readability가 확정한 두 줄 들여쓰기 구조를 그대로 씁니다.
- **`ApplicationProcessValueFormatting`** — `cpuGroupValueText`·`memoryGroupValueText`가 쌍을 돌려줍니다. `cpuProcessValueText`는 `-> String`을 유지합니다(하위 행 값 줄).
- **`DashboardColorPalette`** — 슬롯 이름이 램프 구조를 드러내는 형태로 바뀝니다. `memoryComposition(_:)`처럼 카테고리를 받는 진입점은 유지해 `MemoryCompositionCategory`와의 계약이 그대로입니다.
- **`HistoryGraphView.fillOpacity(for:)`·`boundaryStyle(for:)`** — signature는 그대로, 돌려주는 값이 바뀝니다(§5 DP9).
- **접근성 계약** — 아래는 변경 전과 같은 범위로 유지합니다(`SPEC §5.11`).
  카드의 `.accessibilityElement(children: .ignore)` + `.accessibilityLabel(cpuAccessibilityLabel / memoryAccessibilityLabel)` + `.isButton` + `CPUCard`·`MemoryCard` 식별자,
  코어 칸의 `.ignore` + `.isStaticText` + `"코어 N"` 라벨 + `"N%"` 값 + `CPUCore-N` 식별자,
  하위 프로세스 행의 `AppRow-<앱 키>` 식별자와 그 아래 정확히 두 개의 `StaticText`, 이름 줄의 `childAccessibilityLabel`,
  상세 콘텐츠의 `DashboardDetail` 식별자, 도넛의 `MemoryCompositionDonut` 식별자.
  없어지는 것은 `DashboardTitle` 식별자 하나이고, 대신 본체 컨테이너 식별자가 생깁니다.
- **키보드 계약** — ⌘1·⌘2 등록 자리(본체 한 곳)와 동작(선택·재선택 해제·다른 카드로 이동)이 그대로입니다(`SPEC §5.5`, core-resource-monitoring `SPEC §5.13`).

## 4. 영향 범위

### 고치는 production 파일

- `ResourceRunner/DashboardStyle.swift` — 새 파일. 타이포 역할·여백 단계·카드 표면 상수.
- `ResourceRunner/DashboardView.swift` — 제목 줄·단축키 줄 제거, 카드 표면과 `contentShape`, 초점 줄, 묶음 간격, 다섯 자리의 값 열, 코어 칸 정렬, 상세 섹션 간격과 머리글 역할, `CPUCoreUsageGridView`·`MemoryCompositionDonutView`·`TopApplicationsView`·`CardRankingSlotView`의 간격.
- `ResourceRunner/DashboardColorPalette.swift` — 램프 구조와 여덟 개 hex.
- `ResourceRunner/DashboardPresentation.swift` — `DashboardValueColumn`(값 종류·서식·열 폭), `CPUCoreUsageFormatting`의 칸 수치 경로, `ApplicationProcessRowLayout.labelIconSpacing`을 여백 단계에서 유도, `CPUCoreGridLayout.cellSpacing`을 여백 단계에서 유도.
- `ResourceRunner/ApplicationRanking.swift` — `ApplicationProcessValueFormatting`의 두 함수가 쌍을 돌려주도록.
- `ResourceRunner/ApplicationRowIcon.swift` — `cardPointSize`가 `.caption` 줄 높이 상한이라는 근거를 새 `value` 역할 기준으로 다시 적음(값 자체는 12pt 유지, 줄 높이가 13.0으로 그대로여서 상한이 바뀌지 않습니다).

`ResourceRunner/` 아래 나머지 파일(수집·일정·집계·생명주기·메뉴바)은 건드리지 않습니다.
표시 값의 정의·계산·수집 주기가 그대로이므로 `SystemMetrics`·`CPUSystemMetricsCollector`·`MemorySystemMetricsCollector`·`ProcessSurveyCollector`·`MonitoringSampleStore`·`ProcessHistoryStore`·`ApplicationCoordinator`·`StatusBarController`에는 변경이 없습니다.

### 기준을 갱신할 테스트

`§근거 > 기존 테스트가 잠그고 있는 것`에서 확인한 자리입니다.

- `ResourceRunnerTests/DashboardCardLayoutTests.swift` — 카드 높이 기준값, 픽셀 영역 리터럴(슬롯 순서·y 좌표가 바뀜), 카드 배경 알파 임계(불투명 채움이 사라져 판정 대상이 테두리로 바뀜), 스와치 색조 범위(두 계열이 한 색조가 되어 `System`의 `0.0...0.12` 범위가 성립하지 않음), 값 열 정렬 단언 추가.
- `ResourceRunnerTests/ApplicationProcessRowLayoutTests.swift` — `childIndent`·`childValueIndent` 유도식은 그대로 통과하고(공식 기반), `labelIconSpacing`이 4가 되어 시작선 픽셀 기준이 따라 움직입니다. `"12% (코어 합산) · Rosetta"` 단언은 유지합니다(하위 행 값 줄은 서식이 그대로).
- `ResourceRunnerTests/DetailPopoverValuelessStateTests.swift` — 4상태 팝업 프레임 기준(§5 DP11의 재실측 결과), 값 없음 상태의 기준 조립(제목·단축키 줄이 없어져 조립이 달라짐).
- `ResourceRunnerTests/CPUCoreGridVerticalBudgetTests.swift` — 14코어 격자 아래끝 154 → 166, 64코어 478 → 첫 화면 상한이 56코어로 옮겨간 결과(§5 DP6).
- `ResourceRunnerTests/CPUCoreUsageGridTests.swift` — 상수 유도 단언은 그대로 통과하고, 칸 수치 글꼴이 `value` 역할로 바뀌어 칸 폭 여유 단언의 기준 문자열 폭이 28.0 → 29.0으로 움직입니다.
- `ResourceRunnerTests/ApplicationRowIconTests.swift` — `cardPointSize` ≤ 줄 높이 단언은 `.caption` 줄 높이가 13.0으로 그대로여서 통과합니다. `.caption`을 `value` 역할로 바꾸는 표기만 따라갑니다.
- `ResourceRunnerTests/MemoryCompositionDetailTests.swift` — 범례 행 `valueText` 단언이 주입된 `format` 클로저 결과이므로 쌍 반환으로 형태가 바뀝니다. 값 없음 `"-"` 규칙은 유지합니다.
- `ResourceRunnerTests/DashboardPresentationTests.swift` — 카드 접근성 이름의 바이트 문자열이 소수 한 자리 고정 서식으로 바뀝니다. 단축키 포함 단언(`:566`, `:595`, `:991`, `:1020`, `:1500`, `:1504`)은 그대로 유지돼야 합니다(`SPEC §5.5`).
- `ResourceRunnerUITests/ResourceRunnerUITests.swift` — 팝오버 열림·닫힘 앵커를 `app.staticTexts["ResourceRunner"]`에서 `CPUCard`로 옮깁니다.
- `ResourceRunnerUITests/DashboardCardSelectionUITests.swift` — 자기 해제 클릭 대상을 `DashboardTitle`에서 본체 컨테이너의 카드 밖 영역으로 옮깁니다.
- `ResourceRunnerUITests/DashboardDetailPopoverUITests.swift` — 복제된 상세 크기 리터럴(`:23`)을 재실측 결과로 갱신합니다.
- `ResourceRunnerUITests/DashboardMemoryCardUITests.swift` — 바이트 패턴은 `0.0 KB`도 통과하므로 유지되고, `"bytes"` 미포함 단언(`:173-180`)은 단위 하한이 KB가 되어 더 강하게 성립합니다.
- `ResourceRunnerUITests/DashboardProcessListDisplayUITests.swift`·`DashboardDetailExpansionUITests.swift`·`CPUCoreAccessibilityUITests.swift` — 접근성 계약을 그대로 유지하므로 단언 변경이 없어야 합니다. 값 열 분리 때문에 `AppRow-<키>` 아래 `StaticText`가 2개를 넘지 않는지, 코어 칸 하위 요소가 0인지가 이 스위트로 확인됩니다.
- `ResourceRunnerTests/DetailAccessibilityFormattingTests.swift`·`ResourceRunnerTests/MemoryCompositionTests.swift`·`CPUCoreGridLayoutTests.swift` — 접근성 문자열 형식과 구성 비율·범례 순서는 바뀌지 않으므로 변경이 없어야 합니다.

기준 갱신 원칙은 §5 DP12에 둡니다. 단언을 지워서 통과시키지 않습니다.

### 하위 호환·마이그레이션

해당 없음.
저장 형식·외부 계약·영속 데이터가 없고, 표시 값의 정의와 수집 경로를 건드리지 않습니다.
`docs/product.md` 「대시보드 상단에는 전체 시스템 상태와 그래프 시간 범위를 표시합니다」 문장의 정리는 spec.md §1이 이미 별도 작업으로 지정한 것이며 이 design.md의 산출물이 아닙니다.

## 5. Decision Points

### DP1. 시각 규칙을 어디에 두는가

- 옵션 A — 뷰 본문에 리터럴로 남긴다. 대가: 회귀를 잡는 수단이 렌더 픽셀뿐이고, 같은 값이 여러 자리에 복제된다. 지금 상태다.
- 옵션 B — 뷰에 `ViewModifier`·`EnvironmentValues`로 주입한다. 대가: 값이 뷰 계층을 타고 흐르므로 단위 테스트가 값을 직접 단언할 수 없고, 이 저장소의 기존 관례와 어긋난다.
- 옵션 C — 뷰 밖 순수 상수·순수 함수 한 자리(`DashboardStyle`). 대가: 뷰가 그 자리를 참조하는지까지는 상수 단언으로 잡히지 않아, 자리마다 「이 상수를 실제로 쓰는지」를 렌더 측정으로 확인하는 테스트가 따로 필요하다.

**채택: C.**
이 저장소는 이미 `CPUCoreGridLayout`·`ApplicationProcessRowLayout`·`ApplicationRowIconLayout`·`MemoryCompositionLegendFormatting`을 이 형태로 두고 단위 테스트가 그 상수를 직접 단언합니다.
C의 대가는 이미 감수하고 있는 대가이며, 그 대가를 메우는 방법(정원의 줄을 하나씩 재는 테스트, 요소를 뺀 기준 조립과 견주는 감도 자기점검)도 `DashboardCardLayoutTests`·`DetailPopoverValuelessStateTests`에 확립돼 있습니다.
새 시각 규칙을 같은 자리에 두지 않으면 `SPEC §5.10`의 「카드 높이가 커지지 않는다」를 지키는 수단이 픽셀 단언뿐이 됩니다.

경계는 §1에 적은 대로 「숫자와 글꼴 서술자로 표현되는 결정」입니다.
하위 프로세스 네 경계·격자 행열 분할·아이콘 자리 크기는 각자의 자리에 남기고 여백 단계만 공유합니다 — 그 값들은 앞 feature의 완료 조건이 닫아 둔 결정이라 소유자를 옮기면 그 조건의 근거가 흩어집니다.

### DP2. 타이포 계층을 몇 단계로 두고 각 단계가 어디를 맡는가

`SPEC §5.1`이 요구하는 것은 카드마다 초점 수치 하나가 같은 카드의 다른 텍스트보다 크게 읽히는 것이고, `SPEC §5.10`이 카드 높이 상한(CPU 243.0 / Memory 181.0)을 겁니다.
높이 예산은 실측에서 나왔습니다 — 카드에서 단축키 줄(`.caption2` 13.0)과 그 위 간격을 지우고 슬롯을 세 묶음으로 묶으면, 묶음 간격을 6pt에서 8pt로 올려도 CPU는 `14 + 60 + 88 + (8 × 2) + 2 + 2 + 16`이 남아 초점 줄에 32.0pt까지, Memory는 제목 줄에 33.0pt까지 쓸 수 있습니다.

- 옵션 A — 2단계(초점 / 나머지). 대가: 상세 섹션 머리글이 값과 같은 위계로 읽혀 `SPEC §5.7`의 「본문과 구분된다」가 성립하지 않는다.
- 옵션 B — 3단계(초점 / 값 / 라벨). 대가: A와 같은 이유로 머리글 자리가 없다.
- 옵션 C — 4단계(초점 / 값 / 라벨 / 머리글). 크기는 두 종류(17pt·11pt)만 쓰고 나머지 구분은 굵기와 전경색으로 만든다.
- 옵션 D — 5단계 이상으로 `.caption`·`.caption2`를 유지하며 세분한다. 대가: 실측에서 두 글꼴은 줄 높이가 똑같이 13.0이고 문자열 폭 차이가 1pt 이내라, 단계를 늘려도 읽는 사람에게는 같은 크기다. spec.md §1이 지적한 「초점이 없다」가 그대로 남는다.

**채택: C.**
- `focus` — `.title2.weight(.semibold).monospacedDigit()`(macOS에서 17pt), 줄 높이 21.0, 전경 `.primary`. 카드마다 하나 — CPU 전체 사용률, Memory 사용 중/전체.
- `value` — `.caption.monospacedDigit()`(11pt), 줄 높이 13.0, 전경 `.primary`. 훑어 읽는 모든 수치 — 카드 순위 값, 상세 앱 목록 값, 상세 범례 값, 코어 칸 수치, 계열 비율.
- `label` — `.caption`(11pt), 줄 높이 13.0, 전경 `.secondary`. 이름·단위·안내 문구·상태 접두.
- `heading` — `.caption.weight(.semibold)`(11pt), 줄 높이 13.0, 전경 `.secondary`. 카드 이름과 상세 섹션 머리글.

초점 크기의 상한을 정한 것은 카드 높이가 아니라 **Memory 제목 줄의 폭**입니다.
카드 콘텐츠 폭 232pt 안에 제목 줄과 구성 누적 바가 함께 놓여야 하고, 실측에서 `.title2.weight(.semibold)`는 128GB 기기 최악 입력에서도 바에 62.0pt를 남기지만 `.system(size: 22)`는 42.0pt, 수집 실패 상태에서는 10.0pt만 남깁니다.
그래서 카드 높이로는 더 큰 후보(236.0 ≤ 243.0)가 들어가더라도 17pt에서 멈춥니다.
조립 실측 결과 카드 높이는 CPU 231.0 ≤ 243.0, Memory 169.0 ≤ 181.0으로 각각 12pt 여유가 남습니다(`SPEC §5.10`).

`.caption2`·`.subheadline.bold()`·`.headline`·`.caption.bold()`는 쓰지 않습니다.
`heading`의 굵기가 한글에서도 실제 face(`.AppleSystemUIFontDemi`)로 갈리고 문자열 폭 변화가 0.2pt 이내라는 것을 실측으로 확인했으므로, 굵기를 위계 수단으로 써도 줄 폭이 흔들리지 않습니다.

초점 줄의 상태 접두는 `label`, 값은 `focus`로 한 줄 안에서 이어 붙입니다.
접두까지 `focus`로 두면 `수집 실패 · 마지막 100%`가 카드 폭을 넘어 줄바꿈으로 카드가 커지고 `SPEC §5.9`·`SPEC §5.10`이 함께 깨집니다.
실측에서 이 조립의 상태별 최대 폭은 CPU 125.0pt, Memory 194.0pt로 232pt 안입니다.

실측 방법은 이 문서의 근거에 쓴 것과 같은 `NSHostingController.sizeThatFits`이고, 구현 단계에서 어림하지 않도록 카드 높이 단언을 조립 실측값으로 다시 잡습니다(DP12).

### DP3. 카드 표면을 무엇으로 만드는가

`SPEC §5.3`은 셋을 함께 요구합니다 — 불투명 회색 채움이 없고, 카드 경계가 팝오버 표면과 구분되고, 두 카드가 서로 구분됩니다.

- 옵션 A — 카드 사이 구분선만 둔다. 대가: 카드끼리는 갈리지만 카드 경계가 팝오버 표면과 구분되지 않는다. `SPEC §5.3`의 두 번째 조건을 만족하지 않는다.
- 옵션 B — 반투명 재질을 얹는다. 대가: spec.md §1이 지적한 「팝오버 자체가 이미 재질인데 그 위에 층을 얹어 겹친다」를 재질로 바꿔 반복하는 것이다. M3에서 카드가 넷이면 재질 층이 넷 겹친다.
- 옵션 C — 채움 없는 1pt 테두리(`RoundedRectangle(cornerRadius: 8).strokeBorder(시스템 구분선 색)`). 대가: 채움이 사라져 카드가 「블록」의 인상을 잃는다. M3에서 테두리 상자가 넷이면 격자처럼 보일 수 있다.
- 옵션 D — 테두리 + 아주 낮은 불투명도의 채움. 대가: 「불투명 회색 채움이 없다」의 판정이 애매해지고, 카드 배경 알파를 재는 기존 테스트의 임계값을 어디에 둘지가 임의 선택이 된다.

**채택: C.**
`strokeBorder`는 도형 내부에 그려지고 `background` 수정자는 크기에 관여하지 않으므로 카드 높이가 전혀 늘지 않습니다(`SPEC §5.10`).
테두리 하나가 「팝오버 표면과의 경계」와 「두 카드의 구분」을 동시에 만들어 `SPEC §5.3`의 세 조건을 함께 만족합니다.
M3에서 카드가 넷으로 늘어도 층이 쌓이지 않고 테두리 수만 늘어나며, 카드 사이 여백 단계(16pt)가 격자 인상을 누릅니다.
선택 상태는 지금처럼 자식 팝오버로만 표현하므로 테두리에 선택 표시를 겹치지 않습니다 — 카드는 `Button(.plain)` 안에 있어 표준 포커스 링·눌림 표현이 없고, 그 사실이 `keyboardShortcut`으로 선택을 성립시킨 기존 결정의 전제입니다.

**함께 확정하는 것**: 지금 클릭 대상을 만들어 주던 불투명 채움이 사라지므로 카드에 `contentShape(RoundedRectangle(cornerRadius: 8))`을 겁니다.
이것 없이는 카드의 빈 부분 클릭이 통하지 않고 `DashboardMemoryCardUITests.swift:71`의 `memoryCard.click()`이 카드 중앙(순위 줄 사이 빈 공간)을 눌러도 선택이 일어나지 않을 수 있습니다.
같은 패턴이 `ApplicationProcessGroupRow`(`DashboardView.swift:1498`)에 이미 쓰여 있습니다.

### DP4. 값 우측 정렬을 어떤 수단으로 보장하는가

- 옵션 A — 지금처럼 `Spacer()`만 쓰고 `monospacedDigit()`을 더한다. 대가: 값의 오른쪽 끝만 맞는다. `7.8 GB`와 `112.4 GB`는 소수점이 갈리고 `1.2 GB`와 `980 MB`는 단위가 갈려 `SPEC §5.2`의 「단위와 소수점 자리가 같은 세로선」이 성립하지 않는다.
- 옵션 B — `Grid` + `gridColumnAlignment(.trailing)`으로 열 폭을 자동으로 맞춘다. 대가: `ApplicationProcessGroupRow`의 값은 각 행의 `DisclosureGroup` **라벨** 안에 있어 여러 행이 한 `Grid`를 공유할 수 없다. 다섯 자리 중 한 자리를 커버하지 못한다.
- 옵션 C — 커스텀 `HorizontalAlignment` + `alignmentGuide`. 대가: B와 같은 이유로 `DisclosureGroup` 라벨 경계를 넘지 못한다.
- 옵션 D — 값 종류별 고정 폭 두 열(숫자 오른쪽 정렬 + 단위 왼쪽 정렬)을 뷰 밖 상수로 둔다. 대가: 폭이 상수라 예상보다 긴 값에서 잘린다. 상수가 넉넉한지 확인할 테스트가 따로 필요하다.

**채택: D.**
다섯 자리를 하나의 규칙으로 덮는 유일한 수단입니다.
폭 상수의 대가는 「그 종류의 가장 넓은 문자열의 이상적 폭 ≤ 열 폭」을 단위 테스트가 재는 것으로 메웁니다 — `ApplicationRowIconTests.swift:100-102`가 리터럴 대신 측정값과 비교하는 것과 같은 방식입니다.

실측한 열 폭과 이름에 남는 폭:

| 자리 | 숫자 열 | 단위 열 | 이름에 남는 폭 |
| --- | ---: | ---: | ---: |
| 카드 순위(CPU, 232pt) | 26.0 (`9999`) | 13.0 (` %`) | 173.0 |
| 카드 순위(Memory, 232pt) | 36.0 (`1023.9`) | 18.0 (` GB`) | 158.0 |
| 상세 앱 행(CPU, 360pt) | 26.0 | 61.0 (` % (코어 합산)`) | 237.0 |
| 상세 앱 행(Memory, 360pt) | 36.0 | 18.0 | 270.0 |
| 상세 증가량 순위(360pt) | 42.0 (`+1023.9`) | 18.0 | 270.0 |
| 상세 범례(368pt, 도넛 140 제외) | 36.0 | 18.0 | 137.0 |

정수 퍼센트가 네 자리를 넘는 극단(논리 코어가 매우 많은 기기에서 한 앱이 모든 코어를 쓰는 경우)에서는 숫자가 잘립니다.
열을 그 경우까지 넓히면 이름 폭이 상시로 줄어드므로, 잘림을 받아들이고 그 경우에도 접근성 이름이 전체 값을 그대로 나른다는 것으로 갈음합니다(`SPEC §5.11`).

코어 칸은 열을 나누지 않고 칸 폭 안 오른쪽 정렬만 씁니다(`SPEC §5.8`) — 값이 정수 퍼센트 한 종류이고 칸 폭이 균등해, `monospacedDigit()`과 오른쪽 정렬로 `%`가 모든 칸에서 같은 x에 놓입니다.
칸 수치 폭은 29.0pt이고 8열 칸 폭은 39.00pt(스크롤러로 좁아진 353pt에서 37.12pt)여서 여유가 남습니다.

하위 프로세스 행은 이 규칙의 대상이 아닙니다 — `SPEC §5.2`가 세는 자리에 들어 있지 않고, detail-popover-readability가 두 줄 왼쪽 들여쓰기로 이미 닫아 둔 결정입니다.

그 들여쓰기가 닫아 둔 것은 **관계**이지 픽셀 값이 아닙니다.
`childIndent = disclosureTriangleWidth + detailPointSize + labelIconSpacing`, `childValueIndent = childIndent + detailPointSize`라는 유도식이 「이름 줄이 부모 앱 이름과 같은 자리에서 시작하고 값 줄이 한 단 더 들어간다」(`docs/product.md`)를 성립시키고, `ApplicationProcessRowLayoutTests.swift:239-242`도 리터럴이 아니라 이 유도식을 단언합니다.
그래서 DP6이 `labelIconSpacing`을 여백 단계 `4`로 옮기면 두 값이 34/50에서 **32/48로 함께 움직이고**, 부모 이름 시작선도 같은 식으로 움직이므로 관계는 그대로입니다.
detail-popover-readability가 픽셀로 못 박은 것은 세로 네 경계 2 / 10 / 18 / 26pt이며(DP6), 가로 들여쓰기 값은 그 결정의 대상이 아닙니다.

### DP5. 소수점을 같은 세로선에 두기 위해 서식을 어떻게 고정하는가

`SPEC §5.2`는 자릿수가 달라져도 소수점 자리가 같은 세로선에 남을 것을 요구합니다.
지금 `ByteCountFormatter(countStyle: .memory)`는 값에 따라 소수 자리 수를 바꾸므로(`16 GB`, `12.4 GB`) 오른쪽 정렬만으로는 소수점이 갈립니다.

- 옵션 A — `ByteCountFormatter`를 그대로 두고 오른쪽 정렬만 한다. 대가: `SPEC §5.2`가 성립하지 않는다.
- 옵션 B — 목록 안에서만 다른 서식을 쓴다. 대가: 같은 값이 카드 제목 줄과 카드 순위 줄에서 다른 문자열로 보인다.
- 옵션 C — 표시 계층 전체에 하나의 바이트 표시 규칙을 둔다 — 1024 기반, 단위 하한 KB, 소수 한 자리 고정, 로케일 소수 구분자, `(숫자, 단위)`로 나눌 수 있는 형태. 대가: 화면 문자열이 바뀐다(`16 GB` → `16.0 GB`, `Zero KB` → `0.0 KB`).

**채택: C.** (2026-09-05 사용자 확인)
`SPEC §5.2`를 만족하는 다른 길이 없습니다.
`ByteCountFormatter`는 소수 자리 수를 고정하는 설정을 제공하지 않으므로 단위 선택과 숫자 서식을 직접 갖는 규칙이 필요합니다.
1024 기반과 `.memory` 관례를 유지해 표시되는 **값** 자체는 바뀌지 않고 자릿수 표기만 고정됩니다 — spec.md §3의 「표시하는 값·항목·정원·계산·수집 주기를 바꾸지 않습니다」와 §4의 「값의 정의·계산 변경」 제외는 계산 규칙에 걸린 제약이고, 이 결정은 그 값을 화면에 적는 방식입니다.

단위 하한을 KB로 두는 것은 `ByteCountFormatter(.memory)`가 이미 그렇게 동작하기 때문이며(0을 `Zero KB`로 냅니다), 그 결과 `bytes` 단위가 화면에서 사라져 `DashboardMemoryCardUITests.swift:173-180`의 「`bytes`가 없어야 한다」 단언이 더 강하게 성립합니다.
`:138`의 바이트 패턴은 `0.0 KB`도 통과합니다.

퍼센트는 지금처럼 정수 0자리를 유지합니다 — `CPUCoreUsageFormatting.valueText`의 반올림 규칙과 접근성 값의 동일 서식 공유(`DetailAccessibilityFormattingTests.swift:23-27`)를 건드리지 않습니다.

### DP6. 여백 단계를 몇 개로 줄이고 어디에 쓰는가

지금 2·4·6·8·16pt가 자리마다 섞여 있습니다.

- 옵션 A — {2, 6, 12} 세 단계. 대가: 카드 묶음 간격을 12로 올리면 조립 실측에서 CPU 243.0 / Memory 181.0으로 상한에 정확히 닿아 여유가 0이 된다.
- 옵션 B — {4, 8, 16} 세 단계. 대가: 2pt를 4로 올리면 카드 순위 자리의 6개 간격에서만 12pt가 늘어 `SPEC §5.10`의 예산을 잡아먹는다.
- 옵션 C — {2, 4, 8, 16} 네 단계, 배수 관계. 각 단계에 담당 위계를 지정한다.

**채택: C.** (2026-09-05 사용자 확인)
- `2` 한 묶음 안의 줄 사이 — 카드 순위 줄, 초점 줄과 계열 요약 줄, Pressure 줄과 범례 줄, 코어 칸 안 세 줄, 상세 목록 행 사이, 하위 행의 이름 줄과 값 줄.
- `4` 라벨과 그 대상 사이 — 격자 머리글과 격자, 아이콘 자리와 이름, 스와치와 이름, 상세 범례 행 사이.
- `8` 카드 안 묶음 사이, 카드 안쪽 여백, 앱 목록 왼쪽 여백, 코어 칸 사이.
- `16` 카드 사이, 상세 섹션 사이, 상세 콘텐츠 여백(`.padding()` 기본값과 같은 값).

`SPEC §5.4`가 요구하는 「묶음 사이 간격 > 묶음 안 줄 간격」은 8 > 2로 성립하고, 「같은 위계는 같은 간격」은 단계에 위계를 못 박아 성립합니다.
묶음 간격을 6에서 8로 올리는 것이 예산을 쓰지 않는 이유는 단축키 줄이 사라져 카드의 묶음 경계가 넷에서 둘로 줄기 때문입니다 — CPU 카드는 `6 × 4 = 24`에서 `8 × 2 = 16`으로 오히려 8pt가 남습니다.

**이 단계 집합이 지배하지 않는 자리**를 함께 못 박습니다.
- `ApplicationProcessRowLayout.disclosureTriangleWidth` 12pt — macOS가 정하는 값입니다.
- 하위 프로세스 네 경계 2 / 10 / 18 / 26pt — detail-popover-readability가 픽셀 실측으로 확정하고 `SPEC §5.1`·`§5.2`로 닫은 결정입니다. 이 값들은 `2 + 8k`(k = 0…3) 꼴이라 같은 8pt 단위에서 나온 등차 램프이며, 재조정하면 「세 경계가 서로 같은 간격으로 보이지 않는다」의 근거를 다시 만들어야 합니다. spec.md §4가 그 결정을 유지하라고 지정한 것과도 맞습니다.
- `spec.md §5.4`의 범위 자체가 「카드 안」이라 하위 프로세스 행 경계는 대상이 아닙니다.

**대가와 그 대가를 받아들이는 근거**: 상세 섹션 간격을 6에서 16으로 올리면 CPU 상세 첫 화면의 코어 격자 아래끝이 14코어에서 154pt → 166pt가 되고, 「첫 화면에 코어 격자 전체가 들어오는」 코어 수 상한이 64개에서 56개로 내려갑니다(격자 높이 상한 `480 - (16 + 13 + 16 + 13 + 4) = 418pt`, 7행까지).
`SPEC §5.14`가 요구하는 것은 14코어 기기의 무스크롤과 「배치가 코어 수를 따라간다」이고 166pt ≤ 480pt로 만족합니다.
detail-popover-readability `SPEC §5.4`도 14코어 무스크롤과 「팝업의 고정 크기를 넘기지 않는다」만 요구하며, 그보다 많은 코어의 넘침은 내부 스크롤이 받도록 이미 설계돼 있습니다.
이 상한을 내리는 것은 섹션 간격만이 아닙니다 — 격자 예산은 `480 − (16 + 13 + S + 13 + 4)`이고 행 높이는 `48R + C(R − 1)`이므로(칸 높이 48pt, 섹션 간격 S, 칸 간격 C), 두 값을 각각 계산하면 이렇습니다.

| 칸 간격 C | 섹션 간격 S | 격자 예산 | 최대 행 | 8열 기준 코어 상한 |
| ---: | ---: | ---: | ---: | ---: |
| 6 | 6 | 428 | 8 | 64 (현재) |
| 8 | 16 | 418 | 7 | 56 (채택) |
| 8 | 8 | 426 | 7 | 56 |
| 6 | 16 | 418 | 7 | 56 |
| 6 | 8 | 426 | 8 | 64 |

칸 간격 6→8과 섹션 간격 6→16이 **각각 독립적으로** 상한을 56으로 내리므로, 한쪽만 되돌려서는 64가 돌아오지 않습니다.
64를 유지하는 조합은 칸 간격 6과 섹션 간격 8을 함께 쓰는 것 하나뿐이고(예산 426 = 필요 426, 여유 0),
그러면 섹션 간격 8이 카드 묶음 간격과 같은 값이어서 상세 섹션 경계가 카드 안 묶음 경계와 같은 위계로 읽히고
`SPEC §5.7`의 「어디까지가 한 섹션인지 알 수 있다」가 흔들리며, 칸 간격도 `4`·`8` 단계 어느 쪽에도 속하지 않는 예외로 남습니다.

코어 칸 간격을 6에서 8로 올려도 8열 칸 폭이 39.00pt(좁아진 폭에서 37.12pt)로 칸 수치 29.0pt를 담고 남습니다.

### DP7. 상시 chrome을 지운 뒤 남는 자리를 어떻게 정리하는가

`SPEC §5.5`는 단축키 줄과 「ResourceRunner」 제목이 화면에서 사라지고, 키보드 선택·복귀는 그대로 동작하며, 각 카드의 접근성 이름에서 단축키를 확인할 수 있을 것을 요구합니다.

- 옵션 A — 화면 텍스트만 지우고 나머지는 그대로 둔다. 대가: `DashboardTitle`을 쓰는 UI 테스트가 클릭 대상을 잃고, `app.staticTexts["ResourceRunner"]`로 팝오버 열림을 판정하는 테스트는 상세 팝업의 앱 자신 프로세스 행에 걸린다.
- 옵션 B — 제목을 감춘 접근성 전용 요소로 남긴다. 대가: 정보가 아닌 표시를 접근성 계층에만 남기는 것이라 `SPEC §5.11`의 「변경 전 도달했던 요소를 같은 범위로 유지」와는 무관한 새 노드를 만드는 셈이고, spec.md §2의 「정보가 아닌 표시가 사라진다」와 어긋난다.
- 옵션 C — 화면 텍스트를 지우고, 본체 컨테이너에 안정적인 접근성 식별자를 새로 붙여 앵커·클릭 대상을 옮긴다.

**채택: C.**
`keyboardShortcut(_:modifiers:)` 등록은 본체 한 곳에 그대로 남습니다 — 키보드 탐색 설정이 꺼진 기본 환경에서 `SPEC §5.5`와 core-resource-monitoring `SPEC §5.13`을 성립시키는 수단이 그 등록이고, 자식 팝오버가 key window를 가져가지 않아 팝업이 열린 뒤에도 닿는다는 것이 이미 확인된 사실입니다.

단축키 문자열의 소유 관계는 오히려 단순해집니다.
`selectionShortcutKey`(문자) → `selectionShortcutDisplayText`(표시 문자열) → 접근성 이름의 `"단축키 ⌘1"`, 그리고 같은 `selectionShortcutKey` → `KeyEquivalent` → `keyboardShortcut`.
화면 텍스트 소비자가 없어져 갈라질 경로가 둘에서 하나로 줄고, 등록된 키와 접근성 이름이 여전히 한 상수에서 나옵니다.
`selectionShortcutDisplayText`를 지우지 않는 이유가 이것입니다 — `SPEC §5.5`가 접근성 이름에서 단축키를 확인할 수 있어야 한다고 요구하고, 그 문구는 `DashboardPresentationTests`가 이미 단언하고 있습니다.

옮길 자리는 둘입니다.
- 팝오버 열림·닫힘 앵커(`ResourceRunnerUITests.swift:28`, `:45`) → 이미 식별자가 있는 `CPUCard`. 제목이 사라지면 `staticTexts["ResourceRunner"]`가 상세 팝업 안 앱 자신의 프로세스 행에 걸릴 수 있어(`DashboardView.swift:29-31`이 기록한 바로 그 충돌) 라벨 조회를 쓰지 않습니다.
- 자기 해제 클릭 대상(`DashboardCardSelectionUITests.swift:137-139`, `:173`) → 본체 컨테이너 식별자 아래의 카드 밖 영역. 제목이 없어진 뒤 본체에서 카드가 아닌 영역은 위·아래 여백 16pt와 카드 사이 16pt뿐이므로, 컨테이너 프레임에서 계산한 좌표를 클릭합니다. `DashboardDetailExpansionUITests.swift:255-257`이 이미 같은 방식(요소 프레임 기준 오프셋 클릭)을 씁니다.

### DP8. 새 색 램프를 무엇으로 확정하는가

spec.md §3이 정한 규칙 — CPU 한 색조 두 단계, Memory 두 색조 각 두 단계(App·Wired가 한 색조, Compressed·Cached가 다른 색조), 색조 셋 이하, 라이트·다크 각각 확정, 인접쌍 색맹 시뮬레이션 ΔE ≥ 8과 배경 대비 3:1, relief 의존 해소.

색조 수에서 선택이 갈립니다.

- 옵션 A — 색조 셋(CPU 전용 색조 하나 + Memory 두 색조). 대가: 한 팝오버 안에 색조가 셋 남아 spec.md §1이 지적한 「280pt 폭 안에서 서로 경쟁」이 덜 풀린다. M3에서 Network·Disk가 각자 색조를 요구하면 넷을 넘어 `SPEC §5.6`의 상한을 다시 손봐야 한다.
- 옵션 B — 색조 둘(CPU가 Memory App·Wired와 같은 색조를 공유). 대가: 같은 두 hex가 한 팝오버 안에서 「CPU User·System」과 「App·Wired」 두 뜻을 갖는다.

**채택: B.** (2026-09-05 사용자 확인)
근거 셋입니다.
- spec.md §1이 문제로 지목한 것이 카드 경계를 넘어선 색 경쟁이므로, 색조를 둘로 줄이는 것이 그 문제에 직접 닿습니다. 검증기 실행 결과 평균 채도도 라이트 64.2 → 43.9, 다크 60.5 → 39.0으로 함께 내려갑니다.
- 「색조는 카드가 아니라 표시 계열족(step 1 = 순서상 앞 항목, step 2 = 뒤 항목)을 가리킨다」는 규칙을 세우면 M3의 Network·Disk가 같은 두 색조를 다시 쓸 수 있어 `SPEC §5.6`의 상한을 넘지 않습니다.
- 두 뜻이 겹치는 대가는 표시 형태가 다르다는 것으로 갈립니다 — CPU는 반투명 밴드(채움 밀도 0.55/0.20, 경계선 점선·실선), Memory는 불투명 바·도넛 구간입니다. 그리고 spec.md §3이 요구하는 색 비의존 때문에 모든 계열·구간에는 이름이 스와치 바로 옆에 붙어 있습니다(`MemoryCompositionLegendSegment`의 `.swatch` 뒤에 `.label`이 반드시 따라오는 계약, `CPUSeriesPlaceholderLayout.entries`의 이름).

**확정한 값** (검증기 실행 결과, 배경은 spec.md §1의 근사)

라이트 (`#ECECEC`, L\* 93.4)

| 슬롯 | hex | L\* | C\* | h° | 배경 대비 |
| --- | --- | ---: | ---: | ---: | ---: |
| 색조 A step 1 = Memory App, CPU System | `#165698` | 36.2 | 42.0 | 277.9 | 6.31 |
| 색조 A step 2 = Memory Wired, CPU User | `#4b82d0` | 54.0 | 46.1 | 277.9 | 3.29 |
| 색조 B step 1 = Memory Compressed | `#83441d` | 36.1 | 42.0 | 55.3 | 6.33 |
| 색조 B step 2 = Memory Cached | `#ba6e41` | 54.0 | 45.7 | 55.2 | 3.30 |

다크 (`#2E2E2E`, L\* 18.9)

| 슬롯 | hex | L\* | C\* | h° | 배경 대비 |
| --- | --- | ---: | ---: | ---: | ---: |
| 색조 A step 1 | `#5287d5` | 56.0 | 45.8 | 277.9 | 3.74 |
| 색조 A step 2 | `#a1bbf5` | 75.9 | 31.9 | 278.4 | 7.08 |
| 색조 B step 1 | `#c07345` | 56.0 | 46.0 | 55.5 | 3.74 |
| 색조 B step 2 | `#ecae8c` | 76.1 | 32.2 | 55.0 | 7.11 |

인접쌍 분리 (Memory 바·도넛 순서 App → Wired → Compressed → Cached, CIEDE2000)

| 인접쌍 | 모드 | ΔL\* | 정상 | protan | deutan | tritan |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| App / Wired | 라이트 | 17.9 | 17.0 | 17.9 | 16.3 | 16.8 |
| Wired / Compressed | 라이트 | 18.0 | 45.3 | 50.3 | 50.1 | 62.1 |
| Compressed / Cached | 라이트 | 17.9 | 17.0 | 15.8 | 18.0 | 17.0 |
| App / Wired | 다크 | 19.9 | 17.0 | 15.4 | 17.7 | 16.2 |
| Wired / Compressed | 다크 | 19.9 | 42.2 | 46.3 | 46.3 | 51.7 |
| Compressed / Cached | 다크 | 20.1 | 17.1 | 18.7 | 16.0 | 16.9 |

여덟 색 모두 3:1을 통과하므로 relief 조건 의존이 없어집니다 — 현재 라이트에서 세 구간이 미달해 「스와치 옆 이름」을 통과 조건으로 걸고 있던 상태(`DashboardColorPalette.swift:36-39`)가 해소됩니다.
인접쌍 최소 ΔE는 15.4로 목표 8의 두 배 가까이 됩니다. 여섯 색 전체를 짝지은 최악 쌍도 라이트 15.8 / 다크 15.4입니다.
색조 B를 청록(h 165)·자주(h 320)로도 같은 절차로 검증했고, 색조 교차 쌍의 최소 ΔE가 각각 19.1(tritan)·14.9(deutan)로 주황(h 55)의 42.2보다 낮아 주황을 골랐습니다.

**단계 배치 규칙**: 색조 안 두 단계를 Memory는 네 구간 순서에 **번갈아** 걸어(진함 → 밝음 → 진함 → 밝음) 인접 경계마다 L\* 계단이 생기게 합니다.
그래서 색을 지운 화면에서도 구간 **경계**가 보입니다.
회색조에서 App과 Compressed는 L\*가 같아 서로 구분되지 않습니다 — 어느 구간인지의 식별은 고정된 순서와 범례 이름이 맡습니다(spec.md §3의 색 비의존 요구가 이미 그 수단을 상시로 두게 하고, §4가 그것을 지우는 것을 막습니다).
한 색조 네 단계로 네 구간을 모두 L\*로 갈랐던 대안은 2026-09-04 사용자 결정이 이미 접었고, 라이트에서 인접쌍 ΔL\*가 18에서 10 이하로 좁아집니다.

CPU의 단계 배치는 Memory와 다릅니다 — DP9에서 확정합니다.

### DP9. 새 램프에서 CPU 밴드의 색 외 구분 수단이 계속 성립하는가

CPU 두 계열이 한 색조가 되면서 채움 밀도와 경계선 모양이 지고 있던 짐이 커집니다.
반투명 밴드는 팝오버 표면에 각각 합성되므로, 합성 결과가 갈려야 두 밴드가 구분됩니다.

검증기로 합성 밝기를 쟀습니다(합성 후 L\*).

| 배치 | 라이트 밴드 ΔL\* | 다크 밴드 ΔL\* |
| --- | ---: | ---: |
| 현재 구현(청 0.50 / 주황 0.28) | 9.3 | 9.0 |
| 아래=step 1(진함) 0.50 / 위=step 2(밝음) 0.28 | 11.3 | **3.5** |
| 아래=step 2(밝음) 0.50 / 위=step 1(진함) 0.28 | 5.4 | 23.0 |
| 아래=step 2(밝음) **0.55** / 위=step 1(진함) **0.20** | **10.2** | **28.8** |

- 옵션 A — 채움 불투명도를 그대로 두고 아래 밴드에 진한 단계를 준다. 대가: 다크 모드에서 두 밴드의 합성 밝기 차가 3.5로 무너져 `SPEC §5.6`의 「색을 지운 화면에서도 어느 계열인지 구분된다」가 다크에서 성립하지 않는다.
- 옵션 B — 채움 불투명도를 그대로 두고 아래 밴드에 밝은 단계를 준다. 대가: 라이트에서 5.4로 무너진다.
- 옵션 C — 아래 밴드에 밝은 단계를 주고 불투명도를 0.55 / 0.20으로 조정한다. 대가: 앞 feature가 정한 0.5 / 0.28을 바꾸므로 격자가 반투명 채움을 통해 비치는 정도가 함께 움직인다.

**채택: C.**
아래 밴드(User) = 색조 A step 2, 위 밴드(System) = 색조 A step 1, 채움 0.55 / 0.20입니다.
합성 밴드 ΔL\*가 라이트 10.2 / 다크 28.8로 현재(9.3 / 9.0)보다 양쪽 모두 좋아지고, 채움 밀도 차 자체도 0.22에서 0.35로 벌어져 색 외 구분 수단이 약해지지 않고 강해집니다.
경계선은 그대로 아래 점선 `[3, 2]` · 위 실선이며, 두 경계선은 전체 불투명도로 그려져 라이트에서 3.29:1 / 6.31:1, 다크에서 7.08:1 / 3.74:1로 모두 3:1을 넘습니다 — 전체 사용률을 나르는 실선이 가장 중요한 선이고 그 선이 진한 단계를 갖습니다.

격자 비침에 대한 대가를 함께 잽니다.
격자선을 시스템 구분선 색(라이트 검정 9.8%, 다크 흰색 13% 근사)으로 두고 밴드 아래에 깔았을 때, 격자선이 밴드 안에서 남기는 L\* 차이는 라이트에서 아래 밴드 2.56 · 위 밴드 3.29, 현재 구현은 2.82 · 3.13입니다.
아래 밴드에서 0.26 줄고 위 밴드에서 0.16 늘어 사실상 같은 수준입니다.
격자 그리기 순서(`HistoryGraphView.drawOrder`)와 격자 색 선택은 바꾸지 않으므로 resource-visualization `SPEC §5.6`의 기준선 표시는 그대로 성립하고, 기준선 값은 카드 접근성 이름(`"기준선 25%·50%·75%"`)에도 그대로 남습니다.

Memory와 CPU가 단계를 다르게 배치하는 이유를 못 박습니다 — Memory의 제약은 **줄지어 붙은 불투명 구간의 인접 경계**이고, CPU의 제약은 **같은 표면에 각각 합성되는 반투명 밴드**입니다.
같은 배치를 쓰면 한쪽이 무너지는 것을 위 표가 보여줍니다.

요약 줄 스와치(`CPUSeriesSwatchView`)는 지금처럼 밴드와 같은 유도 함수(`fillOpacity`, `boundaryStyle`)를 써서 그래프와 모양이 어긋나지 않게 유지합니다.
`DashboardCardLayoutTests.swift:355-356`의 스와치 색조 범위 단언(User `0.52...0.68`, System `0.0...0.12`)은 두 계열이 한 색조가 되면서 성립하지 않으므로, 「두 스와치의 색조가 같고 밝기가 갈린다」는 형태로 다시 잡습니다(DP12).

### DP10. 상세 팝업 섹션 위계를 무엇으로 만드는가

spec.md §4가 구분선·배경·테두리를 뺐으므로 남은 수단은 여백과 머리글 위계뿐입니다(`SPEC §5.7`).
지금 CPU 상세 네 섹션과 Memory 상세 다섯 섹션이 모두 `VStack(spacing: 6)`으로 같은 간격입니다.

- 옵션 A — 머리글을 키운다. 대가: `SPEC §5.1`의 「초점 수치 하나가 다른 텍스트보다 크다」와 경쟁하고, `SPEC §5.7`이 요구하는 「머리글이 그 안의 값보다 낮은 위계로 읽힌다」와도 어긋난다.
- 옵션 B — 여백만 벌린다. 대가: 머리글이 본문과 구분되지 않아 `SPEC §5.7`의 뒷 문장이 성립하지 않는다.
- 옵션 C — 크기는 본문과 같게 두고 굵기·전경색·위쪽 여백을 조합한다.

**채택: C.**
- 머리글은 `heading` 역할(11pt semibold, `.secondary`) — 크기가 `value`·`label`과 같은 11pt여서 초점 규칙과 경쟁하지 않고, `.secondary` 전경이 위계를 값보다 낮추고, semibold가 `label`과 갈립니다. 실측에서 굵기는 실제 face를 바꾸면서 한글 문자열 폭을 0.2pt 이내로 유지하므로 레이아웃 안정성에 영향이 없습니다.
- 섹션 사이 16pt, 머리글과 내용 사이 4pt, 내용 안 줄 사이 2pt — 세 단계가 배수 관계라 어디까지가 한 섹션인지가 간격 비율로 읽힙니다.
- 붙어 있는 한 줄 섹션은 묶습니다. CPU 상세는 `[요약]` / `[코어 격자]` / `[Load Average]` / `[앱 목록]`, Memory 상세는 `[도넛·범례]` / `[사용 중 줄, Swap 줄]` / `[증가량 순위]` / `[앱 목록]`입니다. 표시 항목의 순서와 개수는 바꾸지 않고, 인접한 두 값 줄을 한 묶음(2pt)으로 두어 16pt 간격이 다섯 군데로 흩어지지 않게 합니다.

하위 프로세스 행의 소속 구분은 들여쓰기와 간격으로만 이뤄지는 지금 구조를 그대로 둡니다(`SPEC §5.7` 마지막 문장, spec.md §4).

### DP11. 고정 크기를 어떻게 다시 확정하는가

`SPEC §5.9`는 본체와 두 상세의 크기를 새 표현에 맞춰 다시 확정하고, 상태 전이·상세 열고 닫기·앱 행 펼치고 접기에서 그 크기와 카드 위치가 변하지 않을 것을 요구합니다.
현재 값 488과 400×480은 XCUITest 실측으로 정한 것이고, `NSPopover`가 콘텐츠 크기에 26pt를 더한다는 사실이 `DashboardView.swift:72-79`에 남아 있습니다.

- 옵션 A — 산술로 새 값을 계산해 박는다. 대가: task-010이 어림한 460이 실제 필요 높이보다 작아 하단 여백을 눌렀던 전례가 있다. spec.md가 요구하는 「다시 확정」의 근거가 되지 못한다.
- 옵션 B — `.frame(height:)` 제약을 임시로 걷어 자연 크기를 실측하고 그 값에서 26pt를 뺀다. 대가: 임시 계측 코드를 넣고 빼는 절차가 필요하다.

**채택: B**, 앞 feature가 쓴 절차를 그대로 씁니다.

본체 높이 —
1. 본체 `.frame(height:)`를 임시로 걷는다.
2. XCUITest로 팝오버를 열어 `app.popovers.element.frame.size.height`를 읽는다. 앱 시작 직후 수집 중 상태와 첫 수집이 도착한 정상 상태 **둘 다** 잰다(두 값이 갈리면 슬롯 고정이 깨진 것이다).
3. 읽은 값에서 26pt를 빼 `bodyHeight`로 넣고, 제약을 되건 뒤 팝오버 프레임이 다시 같은 값으로 나오는지 확인한다.
근거의 줄 높이 실측에서 유도한 예상값은 콘텐츠 448pt(= `32(padding) + 231(CPU) + 16(카드 사이) + 169(Memory)`), 팝오버 프레임 474pt입니다. 지금은 488 / 514입니다.
이 예상값은 실측 결과와 어긋나면 실측을 따릅니다.

상세 크기 — 두 단계로 확정합니다.
1. 단위 테스트로 `NSHostingController.sizeThatFits`를 써서, 후보 폭에서 가장 넓은 행(CPU 상세 앱 행, Memory 상세 범례 행, 코어 격자)의 이상적 폭이 콘텐츠 폭을 넘지 않는지, 그리고 14코어 격자 아래끝이 후보 높이 안에 드는지 잰다.
2. XCUITest로 `DashboardDetail`의 AX 프레임이 네 상태 전부에서, 그리고 앱 행 펼침 전후·스크롤 전후에 후보 크기와 같은지 단언한다.
현재 값 400×480은 이 절차로 **재확인**합니다 — 실측 계산에서 14코어 격자 아래끝이 166pt로 480pt 안에 들고(`SPEC §5.14`), DP4의 값 열 고정 뒤에도 가장 넓은 행이 콘텐츠 폭 368pt 안에 들며(이름에 237.0pt가 남습니다), 두 상세가 한 크기를 공유하는 조건도 그대로입니다.
따라서 폭·높이를 바꿀 근거가 없고, 절차를 다시 돌려 같은 값으로 확정합니다.
`ProposedWidthLayout`(`DashboardView.swift:1091`)은 그대로 둡니다 — 균등 분할 칸 폭 잔차가 상위 레이아웃으로 새지 않아야 하는 `docs/design.md` 「균등 분할 폭 잔차」 조건이 그대로이고, 칸 간격만 6에서 8로 바뀝니다.

### DP12. 픽셀·이상적 폭 단언 테스트의 기준을 어떤 원칙으로 갱신하는가

- 옵션 A — 깨지는 단언을 지우거나 완화한다. 대가: `SPEC §5.9`·`§5.10`·`§5.11`·`§5.14`를 지키는 수단이 없어진다. 채택하지 않습니다.
- 옵션 B — 리터럴을 새 숫자로 갈아 끼운다. 대가: 다음 변경에서 같은 일이 반복되고, 어떤 단언이 요구사항이고 어떤 단언이 우연한 스냅샷인지 구분이 남지 않는다.
- 옵션 C — 단언을 세 형태로 다시 쓴다. 유도형 / 불변형 / 기준값형.

**채택: C.**
- **유도형** — 순수 레이아웃 상수나 기준 조립의 측정값과 견준다. 리터럴을 쓰지 않는다. 이미 쓰이는 형태다(`ApplicationRowIconTests.swift:100-102`, `CPUCoreUsageGridTests.swift:187-191`, `ApplicationProcessRowLayoutTests.swift:239-242`). 값 열 폭, 아이콘 자리 크기, 격자 높이 공식, 하위 행 들여쓰기가 여기에 든다.
- **불변형** — 숫자와 무관하게 성립해야 하는 관계를 단언한다. 「여섯 상태에서 카드 높이가 하나」, 「카드 높이 ≤ 변경 전 기준값」(`SPEC §5.10`), 「묶음 사이 간격 > 묶음 안 간격」(`SPEC §5.4`), 「한 목록의 값 오른쪽 끝이 모두 같다」(`SPEC §5.2`), 「두 스와치의 색조가 같고 밝기가 갈린다」(`SPEC §5.6`), 「네 상태 팝업 프레임이 같다」(`SPEC §5.9`)가 여기에 든다.
- **기준값형** — 숫자 자체가 요구사항인 자리만 리터럴로 둔다. DP11의 절차로 다시 실측한 값을 넣고, 그 값이 어떤 절차에서 나왔는지를 함께 적는다. 본체 높이, 상세 크기, 카드 높이 기준값, 14코어 격자 아래끝이 여기에 든다.

`SPEC §5.10`은 특히 기존 기준값 243.0 / 181.0을 **상한으로 남겨** 새 기준값과 함께 단언합니다 — 새 값만 남기면 「변경 전보다 커지지 않는다」는 조건이 문서에서만 남고 테스트에서 사라집니다.

단언이 대상을 잃는 경우(`DashboardTitle`)는 지우지 않고, 같은 보장을 지금 지고 있는 요소로 옮깁니다(DP7).
카드 배경 알파를 재던 단언(`DashboardCardLayoutTests.swift:157`)은 채움이 없어졌으므로 「카드 안쪽에 불투명 채움 픽셀이 없고 테두리 자리에만 잉크가 있다」로 판정 대상을 바꿉니다(`SPEC §5.3`).
픽셀 영역 리터럴(`:150-153`)은 슬롯 순서와 y 좌표가 바뀌므로 새 조립에서 다시 계산합니다 — 이 리터럴이 조용히 다른 영역을 보게 되는 것이 이 자리의 알려진 취약점입니다.

### DP13. 접근성 도달 범위·동작 줄이기·자체 부하가 새 표현에서 성립하는 근거

**접근성 (`SPEC §5.11`)** — 도달 경로를 바꾸지 않습니다.
- 카드는 `.accessibilityElement(children: .ignore)` + `.accessibilityLabel` + `.isButton` 조합을 유지합니다. `docs/design.md`가 기록한 대로 `.ignore`는 `AXGroup`을 만들고 `.accessibilityValue`가 도달하지 않는데, 카드는 값을 쓰지 않고 이름 하나에 모두 담으므로 변경이 필요 없습니다. 그 이름에 초점 수치·상태·두 계열·기준선·TOP 5 안내·단축키가 그대로 들어 있어 `SPEC §5.5`도 함께 성립합니다.
- 코어 칸은 `.ignore` + `.isStaticText` + 이름/값 분리를 유지합니다. `docs/design.md`가 이 조합만이 `AXValue`를 싣는다고 기록했고, 칸 안 값 정렬을 오른쪽으로 바꾸는 것은 배치 변경이라 합쳐진 노드 하나와 하위 요소 0개가 그대로입니다(`CPUCoreAccessibilityUITests.swift:41-46`).
- 하위 프로세스 행은 `AppRow-<앱 키>` 식별자 아래 두 `StaticText`와 이름 줄의 소속 앱 접두를 유지합니다(`DashboardProcessListDisplayUITests.swift:126-139`).
- DP4의 값 열 분리가 만드는 위험은 한 행의 `StaticText`가 늘어나는 것입니다. 정렬된 값 꼬리 뷰가 두 `Text`를 `.accessibilityElement(children: .combine)`으로 묶어 한 노드·한 문자열로 남깁니다 — `docs/design.md`가 `.combine`이 자식 문자열을 `AXValue`에 이어 붙이고 `AXLabel`은 비운다고 기록했고, UI 테스트가 쓰는 `staticTexts.value CONTAINS` 조회가 그 형태를 그대로 받습니다. 이 조합이 실제로 노드 수를 늘리지 않는지는 위 두 UI 스위트가 판정합니다.
- 앱 행의 `DisclosureGroup` 라벨은 이름과 값을 합성한 문자열을 냅니다. 값이 두 열로 나뉘어도 그 합성 문자열에 이름과 `%`가 함께 남아 `DashboardProcessListDisplayUITests.swift:96-98`이 그대로 성립합니다.
- 없어지는 도달 요소는 「ResourceRunner」 제목뿐이고, 그것은 값도 상태도 나르지 않는 앱 이름 표시입니다. `SPEC §5.11`이 세는 「카드의 상태와 주요 수치, 상세 팝업의 내용, 코어 칸의 번호와 사용률, 하위 프로세스 행의 소속 앱과 값」에 들어 있지 않습니다.

**동작 줄이기 (`SPEC §5.12`)** — 새 표현이 애니메이션을 전제하지 않습니다.
더하는 것은 테두리 한 겹, 큰 글꼴 한 단계, 고정 폭 두 열, 새 색 여덟 개, 조정된 간격입니다. 모두 정적입니다.
`withAnimation`·`transition`·암시적 애니메이션을 새로 걸지 않고, 기존 `TimelineView(.periodic(from:by:))`(`DashboardView.swift:578`)는 그래프 가로축을 시계에 맞추는 재그리기이지 애니메이션이 아니며 이 feature가 건드리지 않습니다.
따라서 동작 줄이기·애니메이션 끄기에서 같은 정보가 그대로 전달됩니다.

**자체 CPU 부하 (`SPEC §5.13`)** — 갱신 주기마다 늘어나는 일이 없습니다.
- 늘어나는 일: 값 문자열을 `(숫자, 단위)`로 나누는 순수 문자열 연산(한 tick에 표시되는 행 수는 카드 10줄 + 상세 정원 20 안쪽), 고정 폭 프레임(`Spacer()`가 하던 것과 같은 한 번의 레이아웃 패스), 카드 테두리 한 경로.
- 줄어드는 일: 텍스트 슬롯 셋(제목 하나 + 단축키 둘)이 없어지고, 카드 배경이 채움에서 선으로 바뀝니다.
- 새 타이머·새 관찰자·새 이미지 생성이 없습니다. 색은 지금처럼 `NSColor(name:)` 클로저 안에서 appearance가 바뀔 때만 해석되므로 tick과 무관합니다. `monospacedDigit()` 글꼴은 서술자 하나이며 SwiftUI가 캐시합니다.
검증은 앞 feature와 같은 절차 — 팝오버를 열어 둔 채 앱 자신의 CPU 사용량을 관찰해 변경 전과 견주는 것입니다.

**코어 14개 한 화면 (`SPEC §5.14`)** — 격자 배치 규칙(`CPUCoreGridLayout.rows(coreCount:)`, 열 상한 8)을 바꾸지 않으므로 배치는 그대로 코어 수를 따라갑니다.
바뀌는 것은 칸 간격 6 → 8과 칸 수치 글꼴이며, 14코어 격자 높이 104.0pt에서 팝업 위끝부터 격자 아래끝까지 166pt로 480pt 안에 듭니다.
8열 칸 폭 39.00pt(좁아진 폭 353pt에서 37.12pt)가 칸 수치 29.0pt를 담고 남아, 코어 수가 늘어도 칸 안 수치가 잘리지 않습니다.
첫 화면에 전체가 들어오는 코어 수 상한이 64에서 56으로 내려가는 것은 DP6에서 받아들인 대가입니다.
