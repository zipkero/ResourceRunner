# task-013 키보드·AX 재검증 (2026-10-09)

기준 cwd는 `/Users/zipkero/XcodeProjects/ResourceRunner`, HEAD는 `5435c7dfdaf91d86c41827a6a521aa31b18dbbf9`입니다. 현재 M3 SPEC/DESIGN/task-013과 M4 DESIGN §3.6의 Disk important-usage·1000 기반 기준을 대조했습니다. 제품 코드와 기존 테스트는 바꾸지 않았습니다. 현재 관련 원본 20개의 SHA-256은 [source-sha256.txt](./source-sha256.txt)입니다. 다른 Task의 공유 작업 트리 변경을 보존했습니다. `git diff --check`는 통과했습니다.

## 현재 원본과 이미 실행된 근거

| 경계 | 현재 원본 대응·실행 근거 | 판정 범위 |
| --- | --- | --- |
| ⌘1~4, 선택·반복·전환, 늦은 닫힘과 포커스, 실제 마지막 앵커 | 현재 `DashboardView.swift`, `DashboardPresentationStore.swift`, `DashboardViewport.swift`, 직접 unit 2파일과 `DashboardViewportUITests.swift`의 SHA가 [M4 task-008](../../../../20261003-001-app-preferences/evidence/task-008/source-sha256.txt) 6파일과 정확히 일치합니다. 그 승인 [unit 46/46](../../../../20261003-001-app-preferences/evidence/task-008/unit-summary.json)·[UI 17/17](../../../../20261003-001-app-preferences/evidence/task-008/ui-summary.json)에는 ⌘2/⌘3/⌘4 실제 앵커·화면 여유, 숨긴 카드·포커스 복귀, 상세 부모 key 창에서 ⌘1/⌘2 반복·전환과 닫힘이 있습니다. `StatusBarController.swift`는 이후 설정 메뉴 때문에 바뀌었고 현재 SHA는 [M4 task-009](../../../../20261003-001-app-preferences/evidence/task-009/source-sha256.txt)와 정확히 일치합니다. [그 patch](../../../../20261003-001-app-preferences/evidence/task-009/changes.patch)에서 기존 Escape/Page Up/Down·소유 창 guard는 수정되지 않았고, 설정창 포커스 보호·키보드/AX를 [UI 18/18](../../../../20261003-001-app-preferences/evidence/task-009/ui-summary.json)로 승인했습니다. | 현재 키보드 선택 핵심 소스의 실행 재사용. 이 UI들이 새 Disk 용량의 AX 문자열까지 검사한 것으로 주장하지 않습니다. |
| 기본 키보드 설정·작은 화면·Page Up/Down·네 상세 AX | [기존 task-013 실제 앱 관찰](../README.md)의 두 PID에서 `AppleKeyboardUIMode=0`, ⌘1~4 한 경로, 반복·전환·명시적 닫기·Escape·카드 포커스, 네 상세의 Page Down 끝·Page Up 역이동, Network/Disk 대상별 AX와 1168×729 visibleFrame을 확인했습니다. 이후 제품·표시 원본은 바뀌었으므로 이전 실행의 전체 바이너리 일치를 주장하지 않습니다. 현재 `StatusBarController.swift`의 로컬 Escape/Page Up/Down과 `DashboardView.swift`의 단축키 경로를 원본으로 다시 확인했습니다. | 바뀌지 않은 키 처리 의미의 이력 근거와 현재 소스 대조. 현재 바이너리에서 작은 화면 네 상세 스크롤을 다시 실행한 근거는 없습니다. |
| 새 Disk 저장 공간 정의·실제 AX 부착 | 현재 `ResourceQuantityFormatter.swift`, `DiskNativeAdapter.swift`, `DiskDashboardView.swift`, `ResourceActivityPresentation.swift`, `PrivacyInfo.xcprivacy` 및 Disk 직접 unit 1파일의 SHA가 [M4 Disk 용량 승인](../../../../20261003-001-app-preferences/evidence/disk-capacity-20261004/source-sha256.txt)과 일치합니다. 당시 관련 unit 48/48·signed Sandbox UI 1/1이 새 정의를 확인했습니다. 이후 현재 소스의 [M3 task-011 UI 3/3](../../task-011/revalidate-20261009/ui-summary.json)은 실제 `/`의 `importantAvailable=838019173033`과 카드 838.0 GB를 대조했고, 카드 AX의 회수 가능 포함·실제 파일 점유량 아님·Disk 최근 10분 그래프/Read 점선/Write 실선/원본 범위/⌘4, 상세 `DiskSummary`의 갱신 시각·별도 느린 주기·정의, `DiskVolume-*`의 사용 중·APFS 공유·정의와 실제 개폐를 기록했습니다([원본 로그](../../task-011/revalidate-20261009/ui-test.log)). | 개정된 Disk 카드/상세/볼륨 AX의 현재 signed UI 실행. task-011의 실제 UI는 마우스 상세 개폐이고 새 키보드 전 경로를 재시험한 것은 아닙니다. |
| 설정 모델의 병행 변경 | 현재 `AppPreferences.swift`, `PreferencesStore.swift`, `PreferencesStoreTests.swift`에는 M4 task-012의 additive 3필드 작업이 있습니다. 기존 기본값과 schema1 로드는 해당 Task에서 검토 중이며, 이 작업은 그 결과를 승인으로 선취하지 않습니다. | Task 013 근거의 제품 UI·키 처리·Disk 정의 SHA에는 변경이 없습니다. |

## 이번 실행과 한계

새 Disk 정의가 붙은 현재 앱에서 ⌘1~4 반복·Escape를 함께 재시험하려고 격리된 UI 테스트를 임시로 컴파일했습니다. 명령은 프로젝트 루트에서 다음과 같았습니다.

```sh
xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -derivedDataPath /tmp/rr-m3-task013-revalidate-20261009 -resultBundlePath /tmp/rr-m3-task013-keyboard-20261009.xcresult '-only-testing:ResourceRunnerUITests/DashboardKeyboardDiskDefinitionUITests' CODE_SIGNING_ALLOWED=NO
```

새 테스트 소스는 컴파일됐으나 `ResourceRunnerUITests-Runner` PID82730이 약 2분 동안 테스트 시작과 제품 앱 launch 전에 대기했습니다. 중단 결과는 `TEST INTERRUPTED`/`BUILD INTERRUPTED`, **실행된 테스트 0건**입니다. 유효한 xcresult summary가 만들어지지 않았으며 성공/제품 실패 어느 쪽으로도 계산하지 않습니다. 원본 시도 로그는 `/tmp/rr-m3-task013-keyboard-20261009.log`입니다. 임시 테스트 파일은 제거했고 기존 테스트·제품 코드 변경은 없습니다. XCUITest runner 시작 불가의 이력은 [기존 task-013](../README.md)의 제한과 같습니다. 이 환경에서 같은 runner를 무한 재시도하지 않았습니다.

원문 대비 새 Disk 단위·정의와 AX는 현재 실제 UI로 확인됐습니다. ⌘1~4·복귀의 직접 실행은 동일 SHA의 M4 UI17 및 기존 task-013 실제 앱 근거를 구분해 인수합니다. 현재 통합 바이너리에서 **새 정의와 네 단축키를 한 세션으로 조합한 UI 테스트**, 실제 작은 화면의 네 상세 Page Up/Down 재실행, VoiceOver 음성 낭독은 이번 근거가 아닙니다. VoiceOver 실제 낭독은 SPEC상 M5 범위입니다.
