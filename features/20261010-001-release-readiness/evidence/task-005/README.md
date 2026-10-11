# task-005 검증 기록

기준 작업 트리는 `HEAD 69842e14e920e95da179f525055b22dd75c56b74`와 task-004 제품 변경 및 선행 미커밋 변경을 포함한다. 이 Task의 제품 코드는 변경하지 않았다. 실제 설치 앱 `PID 16136`은 종료하거나 교체하지 않았다.

## 현재 단위 테스트와 빌드

작업 디렉터리: `/Users/zipkero/XcodeProjects/ResourceRunner`. 아래 명령은 순서대로 실행했으며 빌드·테스트를 성능 측정과 겹치지 않았다.

1. `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -only-testing:ResourceRunnerTests -derivedDataPath /private/tmp/resourcerunner-task005-unit -resultBundlePath /private/tmp/resourcerunner-task005-unit.xcresult CODE_SIGNING_ALLOWED=NO`: xcresult 696개 중 693 통과·3 실패·skip 0. `StatusBarControllerTests`의 실제 AppKit 팝오버 열림 검사 3개가 실패했다. 실패 내용은 첫 열림에서 `isShown == false` 두 건과 `첫 팝오버가 열리지 않았습니다` 한 건이다. 병렬 옵션을 지정하지 않은 실행이었다. 셸 출력 포장에 사용한 `status` 변수는 zsh 읽기 전용이어서 래퍼는 exit 1을 반환했지만, xcresult 자체가 `Failed`이므로 결과 판정에는 영향이 없다.
2. 같은 대상 중 `StatusBarControllerTests`만 `-parallel-testing-enabled NO`로 재실행: `/private/tmp/resourcerunner-task005-status-serial.xcresult`의 13/13 통과·skip 0.
3. 전체 `ResourceRunnerTests`를 `-parallel-testing-enabled NO`로 재실행: `/private/tmp/resourcerunner-task005-unit-serial.xcresult`의 696/696 통과·skip 0. 이것을 현재 전체 단위 검증의 유효한 실행으로 사용한다. 첫 실패는 테스트 간 메뉴바 상태 간섭 가능성이 있지만 원인은 확정하지 않는다. 테스트의 assertion이나 skip 조건은 수정하지 않았다.
4. `xcodebuild build -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/resourcerunner-task005-debug CODE_SIGNING_ALLOWED=NO`: `BUILD SUCCEEDED`.
5. 같은 명령의 `Release`, `/private/tmp/resourcerunner-task005-release`: `BUILD SUCCEEDED`. Release 실행 파일 SHA-256은 `0b6ae93b24a6174aca192a22e754289de68dfcc14329b45ddfe6c907d4872c89`다.

각 xcresult와 로그는 위 경로에 보존한다. 초기 로그 SHA-256은 `edc894ebb0346feb8c15cb59e0e73c0f0768fee77b9fb34a48500899ff88f749`, 대상 직렬 로그 `e81cc3c583480971144020bb9f0e3b41bbbadaaf25c70c18432ba104183a798a`, 전체 직렬 로그 `227c2f9c4da9474f2dd276c3dc75a38d222f1158119a368d3bfd30463637db4d`, Debug 로그 `0013bec21600f286ab4a7ce596fc839b8d5179557a65c9397e8a6574c2e4f6b1`, Release 로그 `844c33b80504d112fb9e5af40eb6ad14e27eb9816686d8c2d06e0a45773a3fdf`다.

## GUI 관측 사전 조건

`CGPreflightScreenCaptureAccess`, `CGPreflightListenEventAccess`, `CGPreflightPostEventAccess`, `AXIsProcessTrusted`는 모두 `true`였다. 이 조회는 권한을 요청하지 않았다. 기존 `gui_state.swift`는 CGEvent를 게시하고 200ms 뒤 AX를 읽으므로 100/200ms 반응 검증 도구로 사용할 수 없다. `window_observer.swift`는 1초 창 집합만 확인한다. SDK의 대상 PID event tap과 `SCStreamFrameInfoDisplayTime`는 실제 전달/표시 관측 후보이나, `SCFrameStatusComplete`만으로 최신 네 카드·그래프의 완전 표시를 증명할 수 없다. 실제 화면 내용과 AX 값을 연결하는 짧은 사전검사가 필요하다.

## 2026-10-10 짧은 외부 관측 사전검사

`external_frame_probe.swift`와 `target_event_probe.swift`를 `swiftc -O`로 `/private/tmp/resourcerunner-task005-*` 바이너리로 만들었다. 전자는 ScreenCaptureKit 표시 프레임 시각, 프레임 callback 관측 시각, 대상 PID 화면 위 창을 기록하고 대상 팝오버 ROI 최대12장/20MB만 저장한다. 후자는 대상 PID의 `CGEvent.tapCreateForPid` 읽기 전용 tap에서 mouse-up 이벤트 timestamp와 callback 시각을 기록한다. 두 도구 모두 기존 앱 설정이나 수집값을 변경하지 않는다.

task-004 최종 진단 Release `/private/tmp/resourcerunner-task004-perf-diagnostic-r4.app`(실행 파일 SHA-256 `281a1e6eba0d0b79e84fd3dc49210d56ee9ba732cef15ac03f2bc9093b891475`) 한 인스턴스를 PID95451로 실행했다. GUI 시작 전 설치 PID16136이 유지됨을 확인했다. 10초 동안 두 관측기를 실행하고 진단 메뉴바를 한 번 열고 닫았다. [`preflight`](preflight)의 `events.jsonl`, `capture/frames.jsonl`, 대상 팝오버 안쪽 JPEG12장, `open.json`, `close.json`과 stdout/stderr를 보존했다. JPEG는 대상 창 외의 배경이 포함되지 않도록 안쪽으로 다시 잘랐으므로 원래 창 전체 픽셀의 무수정 원본은 아니다. 진단 PID95451을 종료하고 설치 PID16136만 남은 것을 확인했다. 이것은 새 PID600초 워밍업/기본 설정의 공식 측정이 아닌 도구 실현 가능성 검사다.

사전검사에서 프레임 911개와 mouse-up 2개가 기록됐다. Mach timebase는 `numer=125`, `denom=3`이다. tap의 event timestamp는 macOS startup 이후 ns, `observedMach`는 Mach tick이며 환산한 두 차이는 각각 약0.352ms, 0.178ms다. event timestamp는 이벤트 생성/게시 시각과 실제 대상 앱 handler 시작을 같다고 증명하지 않는다. 대상 PID tap callback도 handler 직전 또는 주변의 외부 관측 경계일 뿐 handler 실행 시각은 알 수 없다. 첫 이벤트 후 창 목록에서 작은 새 팝오버가 처음 나온 프레임은 표시 시각 차 약169ms, 풀사이즈 창 내부 이미지가 처음 보존된 프레임은 약353ms였다. 프레임 시각과 해당 callback에서 읽은 창 목록은 원자적인 동일 시점 스냅샷이 아니며, 첫 JPEG는 300pt 초과 너비에만 저장하도록 제한한 도구의 첫 이미지다. 따라서 이 숫자를100/200ms 합격 또는 실패로 판정하지 않는다.

현재 관측의 미해결 경계는 (1) tap callback과 실제 AppKit mouse-up handler 사이 오차, (2) WindowServer 표시 프레임과 나중에 읽은 창 metadata의 원자성, (3) 프레임의 카드/그래프 픽셀이 최신 자료의 완전한 화면임을 AX 값과 같은 시점에서 입증하는 방법이다. `SCFrameStatusComplete`는 새 프레임 생성 상태이고 전체 콘텐츠의 최종 완성을 뜻하지 않는다. 이 경계를 해결하기 전 긴 반복/반응 측정을 통과 근거로 실행하지 않는다.

두 번째 짧은 사전검사는 같은 진단 실행 파일의 새 PID142에서 수행했다. [`preflight-2`](preflight-2)에 외부 프레임 908개(complete503개), PID mouse-up 2개, AX 스냅샷433개와 연속 대상 창 ROI 이미지48장(합계 약1.2MB)을 남겼다. 당시 `external_frame_probe.swift`는 부분 팝오버도 저장하고 창 목록 조회 시작·끝 Mach를 별도로 기록한다. 저장 이미지는 대상 창 범위로 잘렸지만 macOS 투명 팝오버 안에서 배경 화면이 비칠 수 있다. 전체 화면 이미지는 저장하지 않았다. 진단 PID142 종료와 설치 PID16136 유지를 확인했다.

두 번째 관측에서 event timestamp→PID tap callback 관측 차는 약0.165ms와0.139ms였다. 첫 카드4개의 AX 설명 응답은 첫 mouse-up 후 약111ms였으나, 최초 응답에108ms가 걸려 그 앞의 정확한 등장 시점을 뜻하지 않는다. 새 팝오버 ROI의 첫 저장 프레임은 약115ms로 너비26pt·높이58pt였다. 약198ms 프레임은216×490pt로 네 카드와 Disk 하단이 아직 애니메이션 중인 부분 표시였다. 약340ms에서311×706pt로 커졌지만 그 프레임을 최신 카드/그래프 완료의 최초 시각으로 판정하지 않았다. 이벤트 후90ms의 창 metadata에는12×27pt 창이 있었지만 해당 프레임의 대상 픽셀을 저장하지 않았으므로 실제100ms 안 화면 등장 통과 근거가 아니다. 고주기 AX의 값과 특정 표시 프레임의 최신 내용 세대를 동일하게 연결하는 외부 기준도 아직 없다. 이는600초 워밍업 없이 약10초 실행한 관측이다. 빠른 사전검사의 부분 화면을 정식 목표 실패로 확대하지 않는다.

`external_frame_probe.swift`의 fixed ROI fingerprint는 두 번째 실행에서 `unavailable`이었다. ScreenCaptureKit의 현재 pixel buffer가 도구의 BGRA 가정과 맞지 않았기 때문이다. 창 metadata의 `metadataStartedMach`/`metadataEndedMach`는 displayTime과 별도로 읽은 구간이므로 같은 프레임의 원자적 창 상태로 쓰지 않는다. 향후 통과 상한을 입증하려면 미리 정한 대상 ROI의 각 complete 프레임 픽셀과 event/tap timestamp를 한 시간축으로 보존하고,200ms 안에 네 카드·실제 TOP5·그래프가 완전히 보이는 프레임과 그때까지 응답한 최신 AX 값이 같은 내용임을 확인해야 한다. 최신 자료 세대의 외부 대조 근거가 없으면 판정은 미검증이다.

## 영향 UI 시험과 환경 경계

원본 프로젝트를 복사한 `ResourceRunnerTask005UITests.xcodeproj`에서 app ID만 `com.zipkero.ResourceRunner.Task005UITest`, UI runner ID만 `com.zipkero.ResourceRunner.Task005UITests`로 바꿨다. 정확한 project 차이는 [`isolated-ui-project.patch`](isolated-ui-project.patch), 원본 앱·단위·UI 소스와 원본 project의127개 파일 SHA-256은 [`ui-source-manifest.json`](ui-source-manifest.json)에 보존했다. 임시 프로젝트는 실행 뒤 제거했으며 원본 프로젝트 파일은 수정하지 않았다. XCTest의 기본 `XCUIApplication()`가 설치 앱 bundle ID로 향하지 않게 하는 격리다.

첫 시도는 이 임시 프로젝트에서 `ResourceRunnerUITests` 전체를 `-parallel-testing-enabled NO`, `CODE_SIGNING_ALLOWED=NO`, `/private/tmp/resourcerunner-task005-ui.xcresult`로 실행했다. 실제 로그인/OS 변경 다섯 테스트와 별도 Release 경로가 필요한 한 테스트는 아래 이유로 실행 대상에서 뺐다. 빌드는 끝났지만 runner만 약3분 대기하고 앱 테스트 메서드는 시작하지 않아 이 실행을 중단했다. 로그는 `/private/tmp/resourcerunner-task005-ui.log`에 있다. 다음으로 `DashboardCPUCardUITests/testOpeningPopoverShowsCPUValueCollectionProgressAndTopApplicationsHeading` 한 개만 `CODE_SIGNING_ALLOWED=YES`, `/private/tmp/resourcerunner-task005-ui-signed-smoke.xcresult`로 실행해 서명 문제를 분리했다. 이때도 app launch 전 runner가 대기했다. `/private/tmp/resourcerunner-task005-ui-signed-smoke.log`와 [`ui-automation-mode.log`](ui-automation-mode.log)에 20:58:23 `testmanagerd`가 `Enable UI Automation`을 위해 인증을 요구한 사실이 있다. 승인 UI를 조작하지 않았고 해당 owned `xcodebuild`와 runner만 종료했다. 두 xcresult는 강제 중단으로 `Info.plist`가 없어 테스트 결과 bundle로 읽을 수 없으며 UI 통과 수는0이다. 설치 PID16136은 전 과정 유지됐다.

명시적 제외 목록은 `SettingsWindowUITests/testNativeLoginInitialReadOnly`, `testNativeLoginRegister`, `testNativeLoginUnregisterAndRestore`, `testNativeLoginPrepareNextLogin`, `testNativeSystemSettingsRemovalRefreshesAppStatus`와 `testReleaseBuildRightClickOpensSingleSettingsWindow`다. 앞의 다섯 개는 실제 네이티브 로그인 등록·해제나 System Settings 제거를 수행하거나 그 흐름에 종속되며 SPEC §3의 로그인 등록 변경 금지 범위 밖이다. 마지막 하나는 별도 Release 앱 경로를 제공한 실행에서 읽기 전용으로 수행할 계획이었고 당시 suite에는 Debug 격리 앱만 제공돼 분리했다. 나머지 설정의 시스템 포함·10/20/50·자동닫기·키보드/포커스·로그인 상태 표시 등은 suite 실행 대상에 남아 있었으나 인증 경계로 실제 시작되지 않았다. 정상 XCTest 재개에는 사용자가 Mac에서 UI Automation 인증을 직접 완료한 외부 상태가 필요하다. 현재 권한만으로 인증을 우회하거나 임의 승인하지 않는다.

현재 전체 단위696/696과 Debug/Release 빌드는 성공했다. 영향 UI, 별도 Release UI 진입,600초 워밍업 뒤5+20회 반복, 첫 열림3회/재열림20회 외부100/200ms는 미실행·미검증이다. 기존 task-004 닫힘 CPU2.52~2.53%는 전체 닫힘1% 목표에 미달한 별도 선행 결과이며 task-005 완료를 의미하지 않는다. task-006/007은 시작하지 않았다.
