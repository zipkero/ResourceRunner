# task-014 시스템 포함·상세 정원 즉시 표시

## 기준과 변경

- 기준 HEAD: `5435c7dfdaf91d86c41827a6a521aa31b18dbbf9`. task-012/013과 다른 승인 작업의 미커밋 변경을 보존했습니다. 현재 소스 12파일 SHA-256은 `source-sha256.txt`입니다. `shared-head-diff.patch`는 공유 작업트리의 해당 파일 전체 HEAD 대비 diff라 앞선 task-013의 공동 파일 hunk도 포함합니다. patch SHA-256은 `7497a9ea96d3da092fc8a0586c0ccaf19b6f73628c9666d27d7833d4fe4263a2`입니다.
- 두 순위 자료 중 현재 설정의 포함 범위를 표시 경계에서 선택하고 CPU·Memory TOP5/상세 그룹·Memory 10분 증가량의 공통 10/20/50 정원과 안내·AX를 유도합니다. 정렬·기존 펼침 안정화 뒤에 상세 정원을 적용하며 하위 프로세스는 절단하지 않습니다. 읽기 실패와 소속 기준 제외는 별도 수치로 설명합니다.
- 저장 snapshot 변경 시 이미 승인된 최신 조사 캐시와 마지막 성공 시스템 표본으로 즉시 다시 표시합니다. 조사·벽시계 Memory 계산·source·timer를 재시작하지 않습니다. 정상/실패/중지 상태 및 시스템 표본 원본 시각과 그래프를 보존합니다. 더 새로운 epoch의 승인된 순위가 먼저 도착해도 lastKnown 상태·시각을 정상 성공으로 승격하지 않습니다. 반대로 캐시가 비었거나 시스템 표본보다 오래됐으면 오래된 순위를 새 자료로 쓰지 않고 빈 순위·현재 설정의 안내/정원만 즉시 반영합니다. 캐시의 조사 원본 시각과 시스템 카드 원본 시각은 서로 다른 값으로 유지됩니다.
- 설정 창에는 시스템 포함 Toggle과 상세 10/20/50 Picker/순환 버튼을 추가했습니다. 기존 창 한 개와 내부 Form 스크롤을 사용합니다. 펼친 앱은 설정의 포함 범위/정원 때문에 표시에서 빠질 때만 정리합니다. 일반 조사에서 일시 사라졌다 같은 앱 키로 돌아오는 기존 펼침은 유지합니다. 자동 닫기 설정 UI·behavior는 task-015 범위입니다.

## 검증

- 원본 cwd `/Users/zipkero/XcodeProjects/ResourceRunner`, Debug arm64 signed `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -derivedDataPath /tmp/rr-m4-014-test -resultBundlePath /tmp/rr-m4-014-current-final-unit.xcresult`와 관련 `-only-testing:` 18개 실제 suite: **94/94, 실패·skip 0**. 선택 전체 명령은 `focused-unit.log`, 원시 요약은 `focused-unit-summary.json`입니다. 현재 선택 10→50→20, 빈/오래된 캐시, 새 epoch와 기준점 nil, stopped 원본시각, 펼침 정원/필터 정리, schedule apply 0, 기존 CPU·Memory·설정 회귀를 포함합니다.
- UI 격리 cwd `/tmp/rr-m4-014-isolated`: 원본 소스의 복사본에서 pbxproj bundle ID만 `com.zipkero.ResourceRunner.Task014`, UI runner `com.zipkero.ResourceRunnerUITests.Task014.xctrunner`로 변경했습니다. `xcodebuild build-for-testing` 후 `test-without-building`으로 SettingsWindow 1개 + DashboardDetailExpansion 4개 + DashboardProcessListDisplay 3개를 **8/8, 실패·skip 0** 실행했습니다. 고유 앱·runner는 `codesign --verify --strict` 통과, 둘 다 ad hoc 서명입니다. 원시 `/tmp/rr-m4-014-unique-ui.xcresult`, `unique-ui-eight.log`/summary를 보존했습니다. 이때 설정 UI는 DEBUG 메모리 preferences와 mock login, 상세/프로세스 UI는 native 조사값을 사용했습니다. 50그룹·혼합 UID의 실제 native 성공을 주장하지 않으며 해당 자료는 주입 단위 검증 대상입니다.
- 이후 빈/오래된 캐시 즉시 안내 보완을 반영한 동일 고유 앱에서 SettingsWindow 신규 UI를 **1/1, 실패·skip 0** 재실행했습니다. Toggle 단축키, Picker 10/50, Tab으로 순환 버튼 도달, Space/Return 조작을 확인했습니다. 원시 `/tmp/rr-m4-014-unique-final-ui.xcresult`, `unique-final-settings-ui.log`/summary입니다. 기존 상세/펼침 7개는 이 보완이 무캐시 설정 변경 경로에만 영향을 주므로 앞선 7/7 근거를 재사용합니다.
- 원본 cwd Release arm64 `xcodebuild build ... -derivedDataPath /tmp/rr-m4-014-release CODE_SIGNING_ALLOWED=YES` 성공, `codesign --verify --strict` 성공. Release 실행 파일 SHA-256은 `c75fcd66d2f5ecf9abee4f404c4c87f955f3046953e964688df92b88dc74bddd`입니다. `release-build.log`에 원시 빌드를 보존했습니다. Release UI 읽기 전용 접근은 task-016 최종 관문입니다.
- `git diff --check` 통과. 설치된 `/Users/zipkero/Applications/ResourceRunner.app` PID 64258은 계속 실행 중이며 수정/종료하지 않았습니다. 실제 로그인 등록·OS 잠금/절전/네트워크 상태 변경은 수행하지 않았습니다.

## 검증 이력 구분

처음 UI 실행은 격리 복사본을 만들었지만 `xcodebuild` cwd가 원본이어서 bundle ID가 원본인 테스트 앱을 실행했습니다. 이 결과는 격리 성공 근거에서 제외했습니다. 기존 Expansion 테스트의 “일시 종료 후 같은 키 복귀 시 펼침 유지”가 새 구현에서 1회 실패한 뒤, 필터/정원 변경에서만 정리하도록 수정하여 **기존 기대값 그대로** 고유 bundle UI에서 통과했습니다. Release test target을 Release 구성으로 직접 빌드하려는 별도 시도는 `@testable import`/Release 전용 테스트 컴파일 문제로 실패했으며 제품 Release 빌드의 실패가 아닙니다. 두 실패 로그는 `/tmp/rr-m4-014-ui-regression.log`, `/tmp/rr-m4-014-unique-release-ui*.log`에 남겼습니다.

## 2026-10-09 카드 AX 포함 범위 보완

후속 실제 AX 관찰에서 상세가 포함/50으로 바뀌어도 CPU·Memory 카드의 정상 상태 접근성 이름이 정적 기본 문구인 `시스템 프로세스 제외`를 계속 사용한 결함을 확인했습니다. `DashboardPresentation.swift`의 정상·마지막 성공 실패·중지 카드 AX가 각 presentation의 현재 `includesSystemProcesses`와 제외/읽기 실패 수로 `앱 TOP 5` 안내를 유도하도록 수정했습니다. 상세 정원 50일 때도 카드 안내는 TOP 5이며 TOP 50으로 바뀌지 않습니다. 카드 수집 상태·시각·지표·상세/표시 배선은 이 보완에서 변경하지 않았습니다.

- 원본 cwd `/Users/zipkero/XcodeProjects/ResourceRunner`, HEAD `5435c7dfdaf91d86c41827a6a521aa31b18dbbf9`, 미커밋 작업트리: signed Debug `xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -derivedDataPath /tmp/rr-m4-014-ax-test -resultBundlePath /tmp/rr-m4-014-ax-final.xcresult -only-testing:ResourceRunnerTests/CPUCardAccessibilityLabelTests -only-testing:ResourceRunnerTests/MemoryCardAccessibilityLabelTests -only-testing:ResourceRunnerTests/DashboardRankingSelectionTests CODE_SIGNING_ALLOWED=YES` → **17/17, 실패·skip 0**. 포함/제외 정확 문구, 실패·제외 수, 기본값, 상세50에서도 TOP5 고정, 숨긴 TOP5, 실패·중지 마지막 성공 AX를 단언합니다. `ax-correction-unit.log`와 summary, 원시 xcresult를 보존했습니다.
- 수정 소유 2파일의 현재 SHA는 `ax-correction-source-sha256.txt`, HEAD 대비 두 파일 patch는 `ax-correction-head-diff.patch`(SHA-256 `60f1060dd382c6dd0c57921bfa75cbed931275d076be11f6a696e1eedfe76e42`)입니다. patch에는 같은 파일의 선행 task-014 구현도 포함합니다. 앞쪽 `source-sha256.txt`/`shared-head-diff.patch`는 최초 task-014 검증 시점 이력이며 이 AX 보완 이후 최종 두 파일에는 적용하지 않습니다.
- 설치 앱 PID 64258은 그대로 실행 중이고 실제 로그인/OS 상태를 바꾸지 않았습니다. 실제 UI 재확인은 task-016 작업자가 소유합니다.
