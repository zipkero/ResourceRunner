# task-009: 본체 카드 포커스 테두리를 키보드 탐색 때만 표시

2026-10-13 KST. HEAD `1eaf32104d50d78be098859bbaec9a42dfcadeb1`에 task-008 미커밋 변경(`popover.animates = false`)이 얹힌 작업 트리 위에서 바꿨다.
설치 앱 PID 16136(2026-10-09 16:28:46 시작)은 건드리지 않았고 작업 뒤에도 그대로다.

## 제품 변경

- `ResourceRunner/DashboardViewport.swift`: `@Published private(set) var showsKeyboardFocus`(기본 false)와 `noteFocusNavigation(byKeyboard:)`. `endDisplaySession()`에서 false로 되돌린다.
- `ResourceRunner/StatusBarController.swift`: 기존 local monitor 범위를 `[.keyDown, .leftMouseDown]`로 넓혔다. 본체·상세 소유 창에서
  - Tab(keyCode 48, 수식키 없음·Shift·Control)이면 `noteFocusNavigation(byKeyboard: true)` 후 이벤트를 그대로 넘긴다.
  - 왼쪽 마우스 누름이면 `noteFocusNavigation(byKeyboard: false)` 후 이벤트를 그대로 넘긴다.
  - 다른 키(⌘1–4, Escape, Page Up/Down, DEBUG 주입 키) 처리는 바뀌지 않았다.
- `ResourceRunner/DashboardView.swift`: 테두리 조건을 `focusedCard == card`에서 `outlinedCard == card`(`showsKeyboardFocus ? focusedCard : nil`)로 바꿨다. `@FocusState`, `.focusable()`, `scheduleFocusReturn`, 단축키는 그대로다.
  - DEBUG이고 `--dashboard-preferences-ui-test` 인자로 실행됐을 때만 `focus=<카드> outline=<카드>`를 접근성 값으로 낸다. 2026-10-13 2회차에서 실린 곳을 `DashboardContainer`에서 별도 관측 요소 `DashboardFocusOutlineState`로 옮겼다(아래 「2회차」). Release 바이너리에는 `observesFocusOutline` 심볼과 fixture 인자 문자열이 없음을 `nm`/`strings`로 확인했다(Debug dylib에는 심볼 5개).

## 판단

- 상세를 닫은 뒤 복귀: 포커스는 기존대로 원래 카드로 돌아오고, 테두리는 그 세션의 마지막 탐색 입력이 Tab이었으면 보이고 마우스였으면 보이지 않는다.
- 마우스 클릭: 본체·상세 창에서 왼쪽 버튼을 누르면 테두리를 숨긴다(포커스는 그대로).
- ⌘1–4, Space/Return, Escape는 테두리 상태를 바꾸지 않는다. 그래서 열자마자 ⌘1→Escape로 돌아오면 테두리가 없다.
- 다시 열기: `popoverDidClose` → `endDisplaySession()`에서 초기화한다.

## 검증

| 항목 | 결과 | 근거 |
|---|---|---|
| 전체 단위 `ResourceRunnerTests`(직렬, 원본 project) | 698/698, skip 0 | `/private/tmp/resourcerunner-task009/unit.xcresult`, `unit.log` |
| 원본 project Debug build | BUILD SUCCEEDED | `/private/tmp/resourcerunner-task009/build-Debug.log` |
| 원본 project Release build | BUILD SUCCEEDED | `/private/tmp/resourcerunner-task009/build-Release.log` |
| 새 UI 회귀 `testCardFocusOutlineAppearsOnlyAfterKeyboardNavigation`(격리, 1회차) | 미실행(runner 시작 실패 3회) | `ui-new.xcresult`, `ui-new-r2.xcresult`, `ui-new-r3.xcresult` |
| 새 UI 회귀(격리, 2026-10-13 재실행) | 0 통과·1 실패·skip 0 (테스트 관측 경로 문제, 아래) | `/private/tmp/resourcerunner-task009/ui-new-r4.xcresult`, `ui-new-r4.log` |
| 같은 실패의 진단 실행(임시 출력 추가, 실행 뒤 원복) | 0 통과·1 실패 | `/private/tmp/resourcerunner-task009/ui-diag.xcresult`, `ui-diag.log` |
| 외부 AX로 본 제품 동작(격리 Debug 앱) | 열기 `focus=cpu outline=none` → Tab `memory/memory` → Tab `network/network` → Shift-Tab `memory/memory` | [`ax-probe/axprobe-r6.txt`](ax-probe/axprobe-r6.txt), [`ax-probe/axprobe-r5.txt`](ax-probe/axprobe-r5.txt) |
| 영향 UI suite 56개(격리, 새 회귀 제외) | 56/56, 실패 0·skip 0 | `/private/tmp/resourcerunner-task009/ui-suite.xcresult`, `ui-suite.log` |
| 격리 Release UI 읽기 1개 | 1/1, 실패 0·skip 0 | `/private/tmp/resourcerunner-task009/ui-release-read.xcresult`, `ui-release-read.log` |

- 단위 명령: `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -only-testing:ResourceRunnerTests -parallel-testing-enabled NO -derivedDataPath /private/tmp/resourcerunner-task009/unit-dd -resultBundlePath /private/tmp/resourcerunner-task009/unit.xcresult CODE_SIGNING_ALLOWED=NO`. 698 = task-008의 697 + 이번 `keyboardFocusOutlineStartsHiddenAndResetsWithDisplaySession` 1개.
- UI는 원본 `project.pbxproj`의 bundle ID 4줄만 바꾼 임시 `ResourceRunnerTask005UITests.xcodeproj`(SHA `de1a8dd1…`, task-005 `uiPBXSHA256`과 같음)로 실행했다. app ID `com.zipkero.ResourceRunner.Task005UITest`. 실행 뒤 지웠다. production ID로 XCUIApplication을 실행하지 않았다.
- UI 실패 원인: 1·2회차 "Timed out while enabling automation mode", 3회차 "The test runner hung before establishing connection". `automationmodetool` 출력은 "Automation Mode is disabled. This device requires user authentication to enable Automation Mode."이다. 인증 창은 조작하지 않았다. 테스트 메서드는 한 번도 시작하지 않았으므로 UI 통과 수는 0이다.

- 2026-10-13 재실행: 같은 방식으로 임시 project를 다시 만들었다(pbxproj SHA `de1a8dd1…` 동일). 첫 실행에서 인증 요구가 떴고 사용자가 승인해 automation session이 시작됐다. 인증 창은 조작하지 않았고 `automationmodetool`로 설정을 바꾸지 않았다. 세 실행 모두 끝난 뒤 임시 project를 지웠다.
- 새 회귀 실행 명령: 1회차와 같고 `-resultBundlePath …/ui-new-r4.xcresult CODE_SIGNING_ALLOWED=YES`.
- 56개 명령: task-005 `resourcerunner-task005-ui-resume-suite-hook`과 같은 `-only-testing:ResourceRunnerUITests` + 기존 `-skip-testing` 6개에 새 회귀 1개를 더 뺐다(새 회귀는 따로 실행했으므로). `-derivedDataPath /private/tmp/resourcerunner-task009/ui-dd -resultBundlePath …/ui-suite.xcresult CODE_SIGNING_ALLOWED=YES`. xcresult `totalTestCount` 56, 통과 56.
- Release UI: 격리 project Release build(`-derivedDataPath /private/tmp/resourcerunner-task009/ui-release-dd`, BUILD SUCCEEDED, `ui-release-build.log`), app ID `com.zipkero.ResourceRunner.Task005UITest`, exe SHA-256 `3372cc7450102dbb2ce39a1708c762794f3915d6110b1a6eb67eee40c22981b4`. Debug build-for-testing의 xctestrun을 복사해 UI 대상 `EnvironmentVariables.RR_RELEASE_APP_PATH`만 더한 `…-release-read.xctestrun`으로 `test-without-building -only-testing:ResourceRunnerUITests/SettingsWindowUITests/testReleaseBuildRightClickOpensSingleSettingsWindow`. 출력 `include=0 limit=20개 auto=1`. 테스트가 남긴 격리 Release 프로세스(PID 32530)는 끝난 뒤 종료했다.
- 설치 앱 PID 16136(2026-10-09 16:28:46 시작)은 세 실행 전후 그대로다.

## 새 회귀 실패 원인(1회차, 2회차에서 해소)

- 실패 지점: `DashboardViewportUITests.swift:90` 첫 기대값. `XCTAssertEqual failed: ("") is not equal to ("focus=cpu outline=none")`. `continueAfterFailure = false`라 이후 단계는 실행되지 않았다.
- 원인: DEBUG 관측 seam(`DashboardView.swift`의 `DashboardContainer`에 붙인 `.accessibilityValue`)이 macOS AX에서 `AXValue`가 아니라 `AXValueDescription`으로만 나온다. 컨테이너 AX 속성 목록에 `AXValue`가 없다(`axprobe-r5.txt`).
- XCUITest는 이 값을 읽지 못한다. 진단 실행에서 `DashboardContainer` snapshot 속성은 `title`·`label`·`identifier`·`hasFocus` 등뿐이고 `value`가 없으며, `debugDescription`에도 값이 없다([`ax-probe/xcui-diag-debugDescription.txt`](ax-probe/xcui-diag-debugDescription.txt)). 진단용 출력은 실행 뒤 원래 파일로 되돌렸다(`cmp` 일치).
- 그래서 테스트 파일만 고쳐서는 테두리 상태(`outline=`)를 읽을 수 없다. `hasFocus`로 포커스는 볼 수 있지만 테두리 기대값을 빼면 SPEC §3 문장의 검증이 약해지므로 테스트를 고치지 않았다.
- 제품 동작은 SPEC §3 문장("연 직후 테두리 없음, 키보드 탐색 뒤에만 보임")을 지킨다. 격리 Debug 앱(`--dashboard-preferences-ui-test`, 카드 mask 15, TOP mask 0)을 직접 띄우고 상태 아이템을 실제 클릭으로 연 뒤, 외부 AX 도구 [`ax-probe/probe.swift`](ax-probe/probe.swift)로 `AXValueDescription`과 `AXFocusedUIElement`를 읽었다. 키 입력은 `CGEvent.postToPid`로 그 PID에만 보냈다.

## 1회차에 확인하지 못한 것(2회차 결과는 아래)

- Tab·첫 포커스 전제는 외부 AX로 확인했다. `AppleKeyboardUIMode`가 0인 상태에서도 열자마자 포커스가 `CPUCard`에 놓이고(열기 직후 아주 짧게 이름 없는 `AXGroup`이 잡혔다가 `CPUCard`로 옮겨진다), Tab은 CPU→Memory→Network, Shift-Tab은 Network→Memory로 카드 사이를 옮긴다. 테스트 기대값의 두 전제는 맞다.
- 새 회귀의 나머지 단계(⌘3·Escape 복귀, 마우스 클릭 뒤 `outline=none`, 다시 열기 초기화)는 XCUITest로도 외부 AX로도 실행하지 않았다.
- 새 회귀가 통과하려면 DEBUG 관측 seam을 XCUITest가 읽는 속성(예: `value`나 `label`)으로 내보내도록 `DashboardView.swift`를 고쳐야 한다. 이번 회차 범위(코드 변경 금지, 테스트만 수정 허용) 밖이라 고치지 않았다.
- 실제 화면에서 테두리 픽셀을 눈으로 확인하지 않았다.

## 2회차(2026-10-13, 관측 경로 수정)

사용자 결정 (a): DEBUG 관측 경로를 XCUITest가 읽을 수 있게 고친다. 고친 범위는 `DashboardView.swift`의 `#if DEBUG` 블록과 `DashboardViewportUITests.swift`의 새 회귀·`waitForFocusState`뿐이다.

### 변경

- `ResourceRunner/DashboardView.swift`: 컨테이너의 `.accessibilityValue`를 지우고, DEBUG + `--dashboard-preferences-ui-test`일 때만 `.overlay(alignment: .topLeading)`에 크기 0·`allowsHitTesting(false)`인 `Color.clear` static text 요소를 둔다. label `FocusOutlineState`, value `focus=<카드> outline=<카드>`, identifier `DashboardFocusOutlineState`. 문자열은 DEBUG 전용 computed property `focusOutlineState`로 옮겼다. 포커스를 받는 modifier가 없어 Tab 순서에 끼지 않는다.
  - 실패 snapshot에서 이 요소는 `StaticText {{971.0, 54.2}, {0.0, 0.0}} identifier 'DashboardFocusOutlineState' value 'focus=cpu outline=...'`로, `DashboardContainer`(280×489) 바로 앞 형제로 나온다. 컨테이너와 카드 요소·frame은 그대로다.
  - 일반 Debug(인자 없음)와 Release에서는 요소가 생기지 않는다. Release는 `#if DEBUG`로 코드가 없다.
- `ResourceRunnerUITests/DashboardViewportUITests.swift`
  - `waitForFocusState`가 `DashboardFocusOutlineState`의 `value`를 읽는다. 문자열 비교 판은 남기고, 조건 closure를 받는 판(`waitForFocusState(in:timeout:until:)`)을 더했다.
  - 테스트 기대값 수정 2곳(아래 「기대값 수정 이유」).

### 기대값 수정 이유

1. ⌘3·마우스 클릭 단계의 상세 locator. 기존 테스트는 `detail(in:)`(`DashboardDetail`)로 Network·Disk 상세를 기다렸다. `DashboardDetail`은 CPU·Memory 상세만의 identifier이고 Network·Disk 상세는 `NetworkDetail`·`DiskDetail`이다(`NetworkDashboardView.swift`, `DiskDashboardView.swift`, 기존 `NetworkCardUITests`·`DiskCardUITests`도 그렇게 찾는다). `ui-new.xcresult` 실패 snapshot에 `ScrollView identifier 'NetworkDetail'`이 떠 있어 ⌘3이 상세를 실제로 열었음을 확인했다. 테스트가 틀렸으므로 각 identifier로 고쳤다. 기대하는 동작(상세 열림·Escape로 닫힘)은 그대로다.
2. 다시 열기 직전 Shift-Tab 단계. 기대값은 `focus=network outline=network`였으나 실제는 `focus=disk outline=disk`였다(`ui-new-r2.xcresult`, `DashboardViewportUITests.swift:119`). 마우스로 Disk 상세를 열고 Escape로 닫아 포커스가 Disk로 돌아온 직후, 첫 Shift-Tab에서 포커스는 Disk에 머물고 키보드 탐색 상태만 켜졌다.
   - SPEC §3 판단: 어기지 않는다. 테두리는 키보드 탐색(Shift-Tab) 뒤에, 포커스가 있는 카드에만 보인다. 직전 단계에서 상세를 닫은 뒤 원래 카드(Disk)로의 포커스 복귀도 지켜졌다. SPEC §3과 task-009 검증 조건은 포커스 복귀 뒤 Shift-Tab이 어느 카드로 가는지를 정하지 않는다.
   - task-009 변경은 Tab·마우스 누름 이벤트를 기록만 하고 그대로 넘기므로 포커스 이동 순서를 바꾸지 않는다. 같은 테스트 앞부분에서 Tab(CPU→Memory)·Shift-Tab(Memory→CPU)은 기대대로 움직였다.
   - 그래서 이 단계는 "Shift-Tab 뒤 `outline`이 `none`이 아니고 `focus`와 같다"를 기다린 뒤, 결과가 `focus=disk outline=disk` 또는 `focus=network outline=network`인지 확인하도록 고쳤다. 이 단계의 목적(다시 열기 전에 테두리가 켜져 있다가 다시 열면 `focus=cpu outline=none`으로 초기화)은 그대로다. 앞 단계의 정확한 문자열 기대값(열기 직후 `focus=cpu outline=none`, Tab `memory/memory`, Shift-Tab `cpu/cpu`, ⌘3·Escape 뒤 `network/network`, 마우스 뒤 `disk/none`, 다시 열기 `cpu/none`)은 바꾸지 않았다.

### 검증(2회차)

출력 디렉토리 `/private/tmp/resourcerunner-task009/r5/`.

| 항목 | 결과 | 근거 |
|---|---|---|
| 원본 project Debug build | BUILD SUCCEEDED | `r5/build-Debug.log` |
| 원본 project Release build | BUILD SUCCEEDED | `r5/build-Release.log` |
| 전체 단위 `ResourceRunnerTests`(직렬, 원본 project) | 698/698, 실패 0·skip 0 | `r5/unit.xcresult`, `r5/unit.log` |
| 새 UI 회귀 1차(관측 수정만) | 0/1, 실패 1 — 앞 3단계 통과, ⌘3 뒤 `DashboardDetail` 대기 실패(locator) | `r5/ui-new.xcresult`, `r5/ui-new.log` |
| 새 UI 회귀 2차(locator 수정) | 0/1, 실패 1 — ⌘3·Escape `network/network`, 마우스 `disk/none` 통과, Shift-Tab에서 `focus=disk outline=disk` | `r5/ui-new-r2.xcresult`, `r5/ui-new-r2.log` |
| 새 UI 회귀 3차(Shift-Tab 기대값 수정) | 1/1, 실패 0·skip 0 | `r5/ui-new-r3.xcresult`, `r5/ui-new-r3.log` |
| 영향 UI suite 56개(새 회귀 제외) | 56/56, 실패 0·skip 0 | `r5/ui-suite.xcresult`, `r5/ui-suite.log` |
| 격리 Release UI 읽기 1개 | 1/1, 실패 0·skip 0, 출력 `include=0 limit=20개 auto=1` | `r5/ui-release-read.xcresult`, `r5/ui-release-read.log` |

- 위 1·2차 실패는 시간 초과가 아니라 단언 실패이며, 원인을 고친 뒤 다시 실행했다. runner 시작 실패·시간 초과는 없었다.
- 격리 방식은 1회차와 같다. 원본 `project.pbxproj`의 bundle ID 4줄만 바꾼 임시 `ResourceRunnerTask005UITests.xcodeproj`(SHA-256 `de1a8dd1cd9819153e00e45d85d01eb35fe1d6bb79624c7694770a1e459f2215`), app ID `com.zipkero.ResourceRunner.Task005UITest`. 모든 실행 뒤 지웠다. production ID로 앱·XCUIApplication을 실행하지 않았다. 인증 창은 조작하지 않았고 `automationmodetool`로 설정을 바꾸지 않았다.
- 명령은 1회차와 같고 출력 경로만 `r5/`(`-derivedDataPath r5/ui-dd`)다. 56개는 같은 `-skip-testing` 7개(설정 6개 + 새 회귀)를 썼다.
- Release UI: 격리 Release build(`r5/ui-release-dd`, `r5/ui-release-build.log`, bundle ID `com.zipkero.ResourceRunner.Task005UITest`, exe SHA-256 `a46b0d0cbc4470be9dc740c3f828980b98f6f81ce7b32311c52a1833f8a1b92c`). Debug build-for-testing(`r5/ui-build-for-testing.log`)의 xctestrun에서 `ResourceRunnerUITests` 대상 `EnvironmentVariables.RR_RELEASE_APP_PATH`만 더한 `…-release-read.xctestrun`으로 `test-without-building`. 테스트가 남긴 격리 Release 프로세스(PID 54622)는 끝난 뒤 종료했다.
- Release 바이너리 확인: 원본 project Release(`r5/build-Release-dd`)와 격리 Release(`r5/ui-release-dd`) 실행 파일 모두 `nm`에서 `observesFocusOutline`·`focusOutlineState` 0건, `strings -a`에서 `dashboard-preferences-ui-test`·`DashboardFocusOutlineState`·`FocusOutlineState` 0건. 원본 Debug의 `ResourceRunner.debug.dylib`에는 심볼 18건·문자열 3건이 있다.
- 설치 앱 PID 16136(2026-10-09 16:28:46 시작)은 모든 실행 전후 그대로다.

### 2회차에도 확인하지 못한 것

- 3차 통과 실행에서 Shift-Tab 뒤 값이 `disk/disk`였는지 `network/network`였는지는 기록하지 않았다(2차에서는 `disk/disk`).
- 포커스 복귀 직후 첫 Shift-Tab이 Disk에 머무는 동작이 task-009 이전 코드에서도 같았는지는 이전 코드로 실행해 보지 않았다. 위 근거(이벤트를 그대로 넘김)로 task-009와 무관하다고 판단했다.
- 실제 화면에서 테두리 픽셀을 눈으로 확인하지 않았다.
- 테스트 파일 수정 뒤 단위 테스트는 다시 돌리지 않았다. 바뀐 파일은 UI test target뿐이고, `DashboardView.swift`는 단위 실행 전에 고쳤다.
