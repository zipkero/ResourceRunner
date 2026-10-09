# task-011 실제 로그인 항목 검증

기준은 `main` HEAD `5435c7dfdaf91d86c41827a6a521aa31b18dbbf9`와 현재 미커밋 task-010 변경, 이번 `SettingsWindowUITests.swift`의 native 테스트 추가분입니다. 검증 환경은 macOS 26.6.2(25G83), arm64입니다. 제품 코드는 task-011에서 변경하지 않았습니다. task-010의 단위24/24·UI1/1·Release build 근거는 재실행하지 않았습니다.

## 고정된 실제 앱

- 원본: `/tmp/rr-task010-release/Build/Products/Release/ResourceRunner.app`
- 등록·검증 경로: `/Users/zipkero/Applications/ResourceRunner.app` (`ditto` 복사, 기존 대상 없음 확인). 등록 이후 이 경로의 앱이나 서명을 바꾸지 않았습니다.
- bundle identifier `com.zipkero.ResourceRunner`, 실행 파일 `ResourceRunner`, arm64, `LSUIElement=true`, App Sandbox와 `com.apple.security.files.user-selected.read-only`, `com.apple.security.get-task-allow=true`. Ad hoc 서명, TeamIdentifier 없음, CDHash `9f70122313fe0370ee2061cfc0247639dcde7a1a`; `codesign --verify --deep --strict` 통과. 두 위치 실행 파일 SHA256은 모두 `4b1bbb1da9e36cc5f7f217eb93b8e7c5a06b2bf9b20e101581b849fa41acc0de`입니다. `ResourceRunner.app` 안에 Helper/package가 없으며 `project.pbxproj`의 기존 구성도 유지했습니다.
- 기존 `SettingsWindowUITests.swift`의 task-010 본문은 그대로 두고, 안정 Release 경로를 `XCUIApplication(url:)`로 지정하는 다섯 단계 검증을 추가했습니다. Debug runner의 `RR_NATIVE_RELEASE_APP_PATH`만 안정 Release 경로로 지정했습니다. 테스트 앱 인자 `--settings-ui-test`는 전달하지 않아 실제 `MainAppLoginItemService`를 사용했습니다. [소스 해시](./source-sha256.txt).

## 실행과 결과

`xcodebuild build-for-testing`으로 `/tmp/rr-task011-debug` runner를 빌드하고, `/tmp/rr-task011-debug/Build/Products/ResourceRunner_native_macosx26.5-arm64.xctestrun`에 `RR_NATIVE_RELEASE_APP_PATH=/Users/zipkero/Applications/ResourceRunner.app`을 설정했습니다. 각 단계는 `xcodebuild test-without-building -xctestrun ... -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:ResourceRunnerUITests/SettingsWindowUITests/<method> -resultBundlePath <path>`로 단독 실행했습니다. 최종 5개 단계 모두 1/1 통과, 실패·skip 0입니다. [xcresult 요약](./test-results.json)과 [UI 로그 발췌](./native-ui-results.txt)를 참조합니다.

| 단계 | 실제 관찰 |
| --- | --- |
| `testNativeLoginInitialReadOnly` | 최초 창·대시보드 자동 열림 없음. OS에 항목이 없는 초기 `SMAppService.mainApp.status`는 `notFound`(raw 3)였고 UI는 확인 불가·재시도 설명/토글 꺼짐을 표시했습니다. `다시 확인` 후 동일했고 초기 조회 중 register/unregister 로그가 없습니다. |
| `testNativeLoginRegister` | 명시적 토글 후 `registerLaunchItem` pid 38818/uid 501, `Register error: 0`, native status raw 1(enabled). UI/AX는 “등록되어 있으며 macOS에서 허용되었습니다.”·“켜기가 확인되었습니다.”, 재조회 후 유지. System Settings 「로그인 항목 및 확장 프로그램」의 「로그인 시 열기」에 `ResourceRunner.app`이 나타났습니다. |
| `testNativeLoginUnregisterAndRestore` | `unregisterLaunchItem` pid 39792 후 상태·토글이 해제로 바뀌어도 앱은 계속 실행됐습니다. 다시 등록 후 `기본값 복원`은 일반 설정 복원 문장과 별도 로그인 해제 결과를 표시하고 OS 항목을 제거했습니다. System Settings 목록에서도 사라졌습니다. |
| `testNativeSystemSettingsRemovalRefreshesAppStatus` | 다시 등록한 뒤 System Settings AX의 정확한 `open-at-login-item-ResourceRunner.app-icon` 행만 선택하고 「제거」했습니다. 행 소멸을 대기한 뒤 같은 실행 중인 앱에서 「다시 확인」을 눌렀고 UI/AX는 `notFound`, 토글 꺼짐, 이전 성공 결과 없음으로 바뀌었습니다. |
| `testNativeLoginPrepareNextLogin` | 외부 제거 후 다시 명시 등록해 native enabled/허용 UI를 확인했습니다. 설정창과 대시보드를 닫은 상태를 단언했습니다. 마지막 앱 PID 46871을 종료한 뒤 System Settings 목록에 `ResourceRunner.app`이 남은 것을 확인했습니다. |

[native 시스템 로그 발췌](./native-system-log.txt)는 상태 3→등록→상태 1과 실제 해제·복원·재등록, 동일 앱 경로를 기록합니다. System Settings 최종 목록은 2026-10-09 10:13 KST 화면에서도 확인했습니다. 화면 전체 캡처는 다른 앱 내용이 보여 저장소에는 넣지 않았고 `/tmp/rr-task011-settings-final-prepared.png`에만 둡니다. OS 항목의 존재·제거는 대상 행을 직접 조작한 XCTest 결과에도 남았습니다.

## 현재 OS 상태와 재개 조건

- **로그인 항목 enabled/허용, 대상 경로 위 안정 Release 앱 고정, ResourceRunner 프로세스 없음.** 마지막 UI 등록 2026-10-09 10:12:52 KST, System Settings 행 재확인 10:13 KST. 앱 설정창·대시보드는 닫고 앱을 종료했습니다. System Settings도 종료했습니다. 현재 `preferences.v1`은 작업 전처럼 부재합니다. 기본값 복원으로 한때 생성된 기본 snapshot은 앱 종료 후 삭제해 원래 일반 설정 저장 상태로 되돌렸습니다.
- 다음 로그인 자동 실행 자체는 **아직 관찰하지 않았으므로 task-011 완료 근거가 아닙니다.** 로그아웃·재부팅·세션 전환은 이번 실행에서 하지 않았습니다. 세션 전환을 별도 승인받기 전에는 등록된 앱을 수동 실행하거나 재빌드·재서명·다른 경로로 옮기지 않아야 합니다.
- 별도 세션 전환 승인 후, 로그인 전 PID 없음·등록 경로/해시/OS enabled 시각을 다시 읽기 전용으로 기록합니다. 실제 로그아웃→로그인 뒤 사용자 수동 실행 전 앱 프로세스의 최초 시작 시각, executable/bundle 경로, launch origin과 macOS unified log를 대조하고 설정창·대시보드가 자동으로 열리지 않았는지 AX/창 목록으로 확인합니다. 이전 창 복원·테스트 runner·수동 `open`/`XCUIApplication.launch()`와 구분해야 합니다. 이 증거 전에는 `SPEC §5.10`의 다음 로그인 실행 및 task-011 전체를 승인하지 않습니다.

## 실패 이력·남은 범위

첫 초기 테스트는 OS 항목 부재를 `notRegistered`로 단정해 실패했으나 실제 raw 3 `notFound`를 확인해 테스트 전제만 수정했습니다. 한 번의 `sfltool dumpbtm` 진단이 `SecurityAgent` 인증 창을 열어 UI 클릭을 가린 적이 있어 그 자체 진단을 중단하고 이후 OS 목록은 System Settings/AX와 unified log로 대조했습니다. 인증·TCC·daemon은 조작하지 않았습니다. OS 제거 첫 테스트는 목록 반영 직전 즉시 `exists`를 읽어 실패했고, 대상 행 소멸을 기다리도록 고쳐 최종 통과했습니다. 해제 뒤 다음 프로세스에서 `notFound`가 될 수 있어 최종 준비 테스트도 그 native 상태를 허용했습니다. 이 실패 xcresult는 `/tmp/rr-task011-initial.xcresult`, `/tmp/rr-task011-initial-final.xcresult`, `/tmp/rr-task011-prepare.xcresult`, `/tmp/rr-task011-external-removal.xcresult`에 남겼습니다.

실제 환경에서는 등록이 즉시 허용되어 `requiresApproval`이나 native 호출 실패를 강제로 유발하지 않았습니다. 이 상태의 UI/AX/필요 동작은 선행 task-004·task-009의 주입 adapter 근거를 인수하며, 실제 OS에서 이미 확인한 `notFound` 및 외부 철회 상태를 성공으로 오표시하지 않았습니다. 실제 다음 로그인 실행만 별도 세션 관문으로 남습니다.

## main 판정과 인수

2026-10-09 독립 verifier `rejected / evidence`를 main이 확정했습니다. 실제 초기 읽기·등록/해제/복원·외부 OS 변경 재조회·다음 로그인 준비와9파일 SHA/고정 Release 서명 대응은 모두 충족입니다. SPEC §5.9·§5.11~§5.13 성립, §5.10은 실제 다음 로그인 자동 실행 관찰이 없어 미확인입니다. 구현 재시도0·근거 재검증0이며 task-011/IMPLEMENT [ ] 유지합니다. 다음 로그인 후 수동 launch 없이 PID·시작 시각·실행 경로·로그인 실행 출처·설정창/대시보드 비자동 열림을 확인해야 재판정할 수 있습니다. 사용자에게 별도 세션 전환 승인 또는 직접 로그아웃/로그인 후 알림을 요청했고 아직 응답 전입니다. `sfltool`의 인증 요구 조회는 더 호출하지 않습니다.

## 세션 전환 승인

2026-10-09T10:22:07.771775+09:00 — User explicitly selected: “지금 자동 로그아웃 승인”. Authorized action: one normal System Events log out request, no reboot or forced termination. Pre-transition checks: pre-login-check.txt. Command/output: logout-request.log. User will sign back in and report before manually launching ResourceRunner.

## 실제 다음 로그인 관찰 — 근거 보완

사용자 별도 승인 후 10:23:48 KST 정상 로그아웃을 요청했고 osascript exit 0을 확인했습니다. 사용자가 재로그인 후 실행 중임을 알렸고, 추가 확인에 “메뉴바에만 나타남”이라고 답했습니다. 10:31 새 console 로그인과 새 앱 PID64258의 시작 10:31:02 KST를 [읽기 전용 점검](./next-login-check.json)에 기록했습니다. 고정 실행 경로와 SHA256은 준비 당시와 같고 strict 서명 검증도 통과합니다.

[로그인 출처 발췌](./next-login-origin-excerpt.json)의 loginwindow 10:31:02.665648 `performAutolaunch, launching: /Users/zipkero/Applications/ResourceRunner.app`와 CoreServicesUIAgent의 stopped process 시작, [PID 로그](./next-login-system-log.json)의 launch job/PID64258을 대조했습니다. 이전 로그인 전 PID 없음과 결합해 수동 실행이나 이전 창 복원이 아닌 등록된 로그인 항목 실행임을 확인합니다. 출처 로그는 10:31:00~10:31:05 구간에서 대상 앱과 LoginItemsLauncher 메시지만 보존했습니다.

[비활성 조회](./next-login-observation.json)에서 NSWorkspace 경로·launchDate가 일치하고 AXTrusted true/AXResult 0/AXWindowCount 0입니다. CG의 전체 창 목록에는 표시되지 않는 캐시 창이 있으므로 이것을 열린 창으로 판정하지 않았습니다. [화면 표시 창 조회](./next-login-onscreen.json)도 대상 창 0개입니다. 조회 중 앱 launch/open/activate, XCTest 또는 UI 클릭을 수행하지 않았습니다. 사용자 로그인 직후 메뉴바만 표시됐다는 진술과 함께 설정창·대시보드 비자동 열림을 확인합니다. 조회 [Swift 원본](./next-login-observe.swift)의 optionAll을 optionOnScreenOnly로 바꿔 두 번째 조회를 수행했습니다.

제품·테스트 코드는 기존 native 5/5 이후 변경하지 않았고 suite 재실행도 없습니다. 구현 재시도0·근거 재검증1로 독립 재판정을 요청합니다. 현재 실제 앱은 등록된 상태로 실행 중입니다.

## 최종 승인

2026-10-09 독립 verifier의 재판정 approved를 main이 확정했습니다. 이전 evidence reject의 실제 다음 로그인 부족분은 위 실행 출처·PID·시각·경로·서명 및 창 관찰로 해소됐습니다. SPEC §5.9~§5.13 모두 성립하며 task-011과 IMPLEMENT를 완료했습니다. 구현 재시도0·근거 재검증1입니다. 준비 당시 상태와 첫 reject는 위 이력으로 보존합니다. 현재 등록은 enabled이며 앱은 자동 실행된 PID64258로 실행 중입니다. 세션 근거 해시는 session-evidence-sha256.txt에 기록했습니다.
