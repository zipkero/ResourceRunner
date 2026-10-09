# task-010 구현·검증 근거

기준: `HEAD 5435c7dfdaf91d86c41827a6a521aa31b18dbbf9`, cwd `/Users/zipkero/XcodeProjects/ResourceRunner`, 2026-10-09. 이 폴더의 [patch](./changes.patch)는 task-010 제품·테스트 3파일과 main 소유 상위 문서 2파일의 미커밋 변경을, [소스 SHA-256](./source-sha256.txt)과 [실행 산출물 SHA-256](./artifact-sha256.txt)은 현재 연결 소스·빌드 설정·로그를 고정합니다. task-010 상태/승인 판정은 main 소유입니다.

## 새 통합 경계

Debug 앱에 `--preferences-persistence-ui-test`와 `ResourceRunnerUITest.` 접두사의 고유 `UserDefaults` suite를 함께 준 경우에만 격리 저장을 사용합니다. `--settings-ui-test`는 로그인 adapter만 격리합니다. 일반 Debug/Release 실행은 기존 사용자 설정과 native adapter를 사용합니다. 테스트 teardown은 앱 프로세스에서 이 suite를 지우고 앱을 종료합니다. 초기 시행 중 생성한 같은 접두사의 plist 3개도 소유 경로를 확인해 제거했습니다.

[UI 로그](./ui.log)·[요약](./ui-summary.json)의 새 사례 1/1, 실패/skip 0은 실제 Debug 앱에서 네 카드와 두 TOP 5·그래프 1분·매우 절전을 변경한 뒤 종료/재실행해 설정창 자동 열림 없음, 전체 숨김 첫 대시보드와 네 카드 부재, 모든 설정값 유지, 전체 숨김에서 설정창 진입을 확인합니다. 이어 일반 기본값 복원이 네 카드·두 TOP 5·10분·기본 프로필을 즉시 되돌리는 동안 mock 로그인 해제 실패 결과가 별도로 보이며, 두 번째 재실행 후 기본값이 유지됩니다. 실제 `SMAppService` 등록·해제·시스템 설정 열기는 호출하지 않았습니다.

[단위 로그](./unit.log)·[요약](./unit-summary.json)의 관련 3 suite 24/24, 실패/skip 0은 격리 `UserDefaults` payload 9키/schema와 재로드 revision 0, 수집·프로세스·전달 이력의 재실행 초기 공백, 저장 snapshot의 최초 Dashboard 배선, 최초 일정과 연속 변경 최종 일정, 그래프 재확대 시 이전 이력 보존을 확인합니다. `savedSnapshotSeedsFirstDisplayAndScheduleBeforePendingChanges`에 process 축의 10초→8초와 표시만 바꾼 뒤 두 축 apply 횟수 불변을 보강했습니다. 첫 system 축은 저장된 매우 절전 10초, 초기 적용 전 fast→energySaving 연속 변경의 최종 적용은 5초이며 중간 2초가 적용되지 않습니다. 실제 앱에서는 저장 프로필의 첫 화면을 UI로 보고, 동일 `PreferencesStore`→`ApplicationCoordinator`→`PreferencesPipelineBinding`→`MonitoringLifecycleStore` 초기 경로의 첫 일정은 주입 target 단위로 확인했습니다. 실제 앱 scheduler 간격을 시간 계측으로 직접 재지는 않았습니다. 아래 main 보완에서 동일 UI 세션의 실제 scheduler 첫 apply를 별도로 확보했습니다.

단위 test명 직접 선택 시 Swift Testing discovery가 0개를 반환해 이를 통과 근거로 사용하지 않았습니다. suite 단위로 재선택한 최종 24개 결과만 집계합니다. 최종 UI 이전의 두 실행도 1/1 통과했으나 cleanup 보강 전 근거라 합산하지 않았습니다. 원본 번들은 `/tmp/rr-task010-ui-final.xcresult`, `/tmp/rr-task010-unit-final.xcresult`에 보존합니다.

## 선행 근거와 현재 계약 대응

| task-010 확인 대상 | 현재 원본·근거 |
| --- | --- |
| 설정 payload, 손상 복구, 재실행 이력 초기화 | `PreferencesStore.swift`, `ApplicationCoordinator.swift`; [task-001](../task-001/README.md), [task-005](../task-005/README.md), 이번 격리 UI·단위 |
| 네 프로필·저전력 병합·최신 의도/단일 조회·최초 apply | `MonitoringLifecycle.swift`, `CollectionPipelines.swift`; [task-002](../task-002/README.md), [task-003](../task-003/README.md), 이번 단위 |
| 600초/1203개 이력, 1/5/10분 재확대·당시 G/연속성 | `ResourceRateGraph.swift`, `DashboardView.swift`; [task-003](../task-003/README.md), [task-006](../task-006/README.md), 이번 그래프 단위 |
| 네 카드·두 TOP 5의 16×4=64 렌더, 전체 숨김/포커스·상세 | `DashboardView.swift`; [task-007 최종 UI](../task-007/resume-20261004/README.md), [task-008](../task-008/README.md), 이번 UI |
| 단일 설정창·Release 접근·키보드/AX·복원 일반/로그인 분리 | [task-004](../task-004/README.md), [task-009](../task-009/README.md), 이번 UI mock 실패 경계 |
| 기본 CPU/Memory, TOP 5/상세, Network 물리/부분 합계/보조, Disk 물리/볼륨/현재값/상세 | `IntegratedDashboardSummaryTests.swift`, `OneSessionMonitoringIntegrationUITests.swift`; 기존 [task-009](../task-009/README.md) 및 [Disk 승인](../disk-capacity-20261004/README.md)의 관련 단위·실제 UI 근거 |
| Disk 현재 정의·단위·Sandbox·privacy | `DiskNativeAdapter.swift`, `DiskDashboardView.swift`, `ResourceQuantityFormatter.swift`, `PrivacyInfo.xcprivacy`; [Disk 승인](../disk-capacity-20261004/README.md)의 48/48·Sandbox UI1/1·Release build. raw available/1024 옛 근거는 사용하지 않음 |

선행 폴더의 SHA는 각 승인 당시 소스에 대한 것이며 후속 task/별도 Disk 변경 뒤 현재 전체 파일 SHA와 일괄 일치할 것을 요구하지 않습니다. 현재 HEAD에 001~009와 Disk가 누적돼 있고 이 작업의 런타임 변경은 DEBUG 테스트 fixture 분기뿐입니다. 이번 [SHA-256](./source-sha256.txt)·[patch](./changes.patch)·최종 실행은 현재 통합 코드에 대응합니다. task-007의 과거 인증 차단과 수정 전 실패는 최종 성공 횟수에 포함하지 않습니다.

## 빌드·배포 경계

최종 [Release 로그](./release.log)는 arm64 build 성공입니다. 결과 앱의 `LSMinimumSystemVersion=26.5`, `LSUIElement=true`, bundle ID `com.zipkero.ResourceRunner`, arm64 서명, Sandbox entitlement, 번들 `PrivacyInfo.xcprivacy` 포함을 직접 확인했습니다. 프로젝트의 `packageProductDependencies`는 세 target 모두 비어 있고 Release 앱의 실행 파일은 mainApp 하나이며 Helper/PlugIns가 없습니다. 제품 소스에서 설정 저장은 `UserDefaults` payload 하나이고 수집 store는 프로세스 메모리입니다. 전송 API·수집 데이터 파일 쓰기 경로는 확인되지 않았습니다. 실행 환경은 macOS 26.6.2이며 최소 대상 26.5 설정을 확인한 것입니다.

명령은 로그 첫머리에 기록했습니다. 최종 앱/runner 프로세스와 `ResourceRunnerUITest.` 격리 plist 잔존 확인 후 정리했습니다. 실제 다음 로그인·native 상태 변경과 M3 보류 Task는 task-011/별도 관문입니다.

## main 근거 보완 — 실제 앱 최초 일정

2026-10-09 독립 verifier는 첫 판정에서 실제 앱의 재실행 최초 일정 관찰이 부족하다는 `evidence` 사유를 반환했습니다. main은 소스·테스트를 바꾸거나 통과한 suite를 재실행하지 않고 기존 DEBUG `MonitoringScheduler`의 macOS unified log를 추출했습니다. [원본 일정 로그](./runtime-schedules.json)의 앱 PID는 최종 ui.log의 launch/terminate와 일치합니다.

| 앱 실행 | 시각(+0900)·PID | 최초 system/Network/Disk | 최초 process |
| --- | --- | --- | --- |
| 변경 전 | 09:22:41.831 · 2447 | 2초 | 5초 |
| 저장된 매우 절전으로 재실행 | 09:22:54.459 · 2728 | 10초 | 10초 |
| 기본값 복원 후 재실행 | 09:23:03.209 · 2967 | 2초 | 5초 |

각 행의 네 실제 source 첫 apply는 `generation=1 collectionEpoch=0 appendedTotal=0`입니다. PID2728에서 기본2초로 시작했다 바뀐 기록이 없으며 이후 대시보드 열림5초→닫힘10초→복원2초/process5초도 보존했습니다. 첫 실제 적용 계획을 관찰한 근거이며 tick 간격의 시간 계측을 주장하지 않습니다. logger는 DEBUG의 별도 Task에서 이미 확정된 apply값을 기록하므로 로그 시각은 scheduler deadline이나 최초 샘플 시각이 아닙니다.

로그의 `senderImagePath`는 `/private/tmp/rr-task010-derived/Build/Products/Debug/ResourceRunner.app/Contents/MacOS/ResourceRunner.debug.dylib`이며 `senderImageUUID=9218417F-BEB2-3FA9-B2D7-FAB6C67B57E7`이 현재 arm64 dylib의 dwarfdump UUID와 일치합니다. processImagePath는 Xcode launch stub의 기본 DerivedData 경로로 기록되므로 실제 Swift 구현 대응에는 senderImagePath/UUID를 사용합니다. dylib SHA-256은 `9e8f96d8d7bdb0c720530312189068d7b320f1f527f2e6b3bb0c1acea0f1b535`입니다.

추출 명령(cwd 프로젝트 루트): `/usr/bin/log show --start '2026-10-09 09:22:36' --end '2026-10-09 09:23:20' --style json --predicate 'subsystem == "com.zipkero.ResourceRunner" AND category == "MonitoringScheduler" AND eventMessage BEGINSWITH "apply" AND (processIdentifier == 2447 OR processIdentifier == 2728 OR processIdentifier == 2967 OR processIdentifier == 3273)'`. 이후 JSON의 processID2447/2728/2967만 보존했습니다(별도 정리 앱3273 제외). `xcrun dwarfdump --uuid`와 `shasum -a 256`으로 위 dylib를 대조했습니다. main 구현 재시도0·근거 재검증1이며 최초 근거 부족 판정은 이력으로 보존합니다.

[초기 lifecycle 로그](./runtime-lifecycle.json)는 위 세 PID의 첫 apply 약54ms 전에 revision0·lowPowerMode=false·unlocked·displayAsleep=false·sessionActive=true·systemAsleep=false·boundarySequence0을 확인합니다. 추출은 동일 시각 범위의 `SystemLifecycle`/`initial snapshot` 로그와 PID2447/2728/2967 조건을 사용했습니다. 이를 `startMonitoring`의 최초 popoverPresented=false 적용 순서와 대조해 닫힘·일반전력의 최초 일정임을 확인했습니다.

## 최종 승인

2026-10-09 독립 verifier 재판정 **approved**를 main이 최종 확정했습니다. 첫 `evidence` reject는 위 보완 이력으로 남기고 현재 판정에서는 해소합니다. SPEC §5.1~§5.8은 선행 매핑 Task와 이번 통합 근거를 합쳐 모두 성립합니다. 실제 앱 최초 일정은 PID2728의 네 실제 scheduler 첫 apply10초·초기 unlocked/normal·실행 dylib UUID/SHA로 확인했으며 복원 후 PID2967은 기본2초/process5초입니다. 최종 관련 단위24/24·UI1/1·Release build와 현재24소스 SHA/patch 대응을 확인했습니다. 구현 재시도0·근거 재검증1입니다.

task001~010 승인,011 미완료이며 IMPLEMENT는 [ ]입니다. SPEC §5.9~§5.13의 마지막 매핑, 실제 mainApp 등록·해제·다음 로그인은 task-011에 남습니다. M3 취소6개 승인 복구·014/015 보류와 전체 미완료 상태는 유지합니다. 커밋·푸시는 이번 요청 범위에 없어 수행하지 않았습니다.
