# task-018 네 리소스 통합 재검증 (2026-10-09)

기준 프로젝트는 `/Users/zipkero/XcodeProjects/ResourceRunner`, HEAD는 `5435c7dfdaf91d86c41827a6a521aa31b18dbbf9`입니다. 이 문서는 현재 원본 감사와 선행 근거 인수, 격리 단위·빌드·UI·정상 앱 관찰을 기록합니다. Task 승인·완료 판정은 포함하지 않습니다. task-015 진단 앱과 AX 감시가 정리된 뒤에만 UI suite와 정상 앱/CPU 부하를 실행했습니다. 설치된 Release PID64258과 로그인 등록은 변경·종료하지 않았습니다.

## 현재 원본과 선행 근거

| 경계 | 현재 확인 | 인수 범위와 남은 일 |
| --- | --- | --- |
| Disk 저장 공간 정의 | `DiskNativeAdapter.swift`는 `volumeAvailableCapacityForImportantUsageKey`와 전체−사용 가능을 사용하고, `ResourceQuantityFormatter.swift`는 저장 공간만 1000 기반으로 표시합니다. `PrivacyInfo.xcprivacy`에는 DiskSpace `85F4.1`과 UserDefaults `CA92.1`이 있습니다. M4 Disk 용량 승인 manifest의 제품·단위 소스 8개가 현재와 일치합니다. `DiskCardUITests.swift`는 이후 실제 네 카드 UI 단언이 더해져 과거 manifest와 달라졌습니다. | M4 관련 unit48/48·signed UI1/1, M3 task-002 실제 Sandbox raw와 task-011 현재 signed UI3/3·현재18파일 SHA를 구분해 인수합니다. 새 native 조회나 `sfltool`은 필요하지 않습니다. |
| 네 카드·CPU/Memory·그래프 | M3 task-011 재검증의 화면/테스트 18파일과 task-013의 키보드/AX 20파일이 현재 SHA와 일치합니다. task-011 관련 unit26/26, 누락 selector 보완42/42, signed UI3/3은 실제 280×668pt·네 카드·Disk 용량을 확인했습니다. | 과거 task-018의 정상 앱 한 세션 CPU 부하·네 상세·메뉴바 반응은 이력 근거입니다. 당시 `AppDelegate.swift`, `DashboardPresentationStore.swift`, `DashboardView.swift`, `DiskCardUITests.swift`는 현재와 달라 현재 바이너리의 통합 실행 근거로 바꾸지 않습니다. |
| 수집·경계 | 현재 `ApplicationCoordinator.swift`는 CPU, Memory, Process, Network, Disk, Network 보조 정보, 저장 공간을 `CollectionPipelines.make`에 연결합니다. M3 task-002의11파일, task-006의18파일, task-014 실제 Wi-Fi 전이의7파일은 현재 SHA와 모두 일치합니다. task-008은16개 중15개가 같고 `DiskCardUITests.swift`에 후속 단언이 추가됐습니다. 기존 승인 근거는 Disk cache31/31, 표시 집중36/36·CPU/Memory 회귀24/24입니다. M4 task-011 로그인 소스9파일도 현재 manifest와 일치합니다. | task-015 실제 baseline·중지 공백·여섯 축 재개와 task-013의 격리 키보드 후속 결과를 받아 현재 source와 대조해야 합니다. task-015 완료 전에 통합 성공을 선언하지 않습니다. |
| production 구성·개인정보 | `project.pbxproj`에는 앱·unit·UI 세 target, 빈 `packageProductDependencies`, arm64, macOS26.5, Swift5.0, App Sandbox가 있습니다. 제품 소스 검색에서 `Process(`, `URLSession`, `FileHandle`, 파일 쓰기·생성 경로는 발견되지 않았습니다. `ApplicationIconCache.swift`의 `fileExists`는 아이콘 조회용입니다. `PreferencesStore.swift`만 일반 설정 snapshot을 UserDefaults `preferences.v1`에 저장합니다. | 현재 M4 DEBUG UI fixture는 `RR_*` 환경변수를 사용하므로 과거 task-018의 “제품에서 `RR_*`/`UserDefaults` 없음” 단언은 재사용하지 않습니다. 일반 앱 실행에는 해당 test argument가 없고, 측정 샘플·이력·보조 정보의 설정 저장/전송 경로는 원본 검색에서 발견되지 않았습니다. 최종 빌드의 서명 entitlement·아키텍처·번들 manifest를 별도로 확인해야 합니다. |

상위 현재 구현 설명의 오래된 M4 task-011 미완료·M3 task-015 보류 문구를 `docs/product.md`와 `docs/design.md`에서 현재 승인/진행 상태로 고쳤습니다. 새 M4 옵션 세 가지의 저장 모델과 미구현 UI·동작을 구별했습니다. feature 계약 문서는 수정하지 않았습니다.

## 잠금 중 허용된 격리 단위·빌드 실행

2026-10-09 현재 원본 127파일을 `/tmp/rr-task018-revalidate-20261009`에 복사했고 양쪽 SHA-256이 모두 일치했습니다([스냅샷 manifest](./source-snapshot-sha256.txt)). 복사본의 앱 `PRODUCT_BUNDLE_IDENTIFIER` 두 빌드 구성만 `com.zipkero.ResourceRunner.Task018Revalidate`로 바꿨습니다. 원본 `project.pbxproj`는 수정하지 않았습니다. 실행 후 원본 127파일은 모두 같은 SHA로 다시 대조했습니다. 당시 [작업 트리 상태](./workspace-status.txt)와 [관련 원본·상위 문서 patch](./workspace-source-and-docs.patch)에는 다른 Task의 미커밋 변경도 포함되며, 이 worker의 제품 코드 변경을 뜻하지 않습니다. 아래 명령은 모두 복사본 디렉터리에서 실행했습니다.

```sh
xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -derivedDataPath /tmp/rr-task018-revalidate-20261009/DerivedData -resultBundlePath /tmp/rr-task018-revalidate-20261009/unit.xcresult '-only-testing:ResourceRunnerTests' CODE_SIGNING_ALLOWED=YES
xcodebuild build -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/rr-task018-revalidate-20261009/DerivedData CODE_SIGNING_ALLOWED=YES
xcodebuild build -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/rr-task018-revalidate-20261009/DerivedData CODE_SIGNING_ALLOWED=YES
```

전체 단위는 [원시 로그](./unit.log)와 [xcresult summary](./unit-summary.json)에 **674/674, 실패0·skip0**입니다. summary는 32개 동적 parameter 테스트의 476실행을 별도 통계로 표시하며 XCTest 총 case 674와 혼동하지 않습니다. Debug·Release는 각각 [빌드 로그](./debug-build.log)·[빌드 로그](./release-build.log)의 `BUILD SUCCEEDED`입니다. 이는 M4 task-013의 아직 미적용 변경 전 원본에 대한 결과이며, 최종 source가 바뀌면 영향 범위를 다시 평가해야 합니다.

Task 015의 실제 전이에서 바로 관찰하기 어려운 짧은 병합·지연 결과·세션 비활성은 이 674개에 포함된 현재 결정적 테스트로 대조합니다. `SystemLifecycleObserverTests`의 `displaySleepAndSessionChangesMergeWithoutRevertingOtherFields`·`workspaceNotificationsUpdateDisplaySleepAndSessionFields`, `MonitoringLifecycleTests`의 `allCombinationsOfPopoverPowerLockDisplaySleepAndSessionProduceExpectedPlan`·`fiveShortPausesResetCPUAndSeparateHistoryAcrossBothSchedules`·`resumedSourceAndStoredSampleShareEpochAndOldGenerationIsDiscarded`·`cancelledOrStaleGenerationResultsAreNotStored`, `CollectionAdmissionTests`의 `workspaceSleepNotificationsReachTheCombinedSnapshot`·`newestSnapshotStillCarriesStopResumeBoundary`·`coalescedRunningSnapshotRestartsBothAxesAtNewEpoch`·`boundaryDuringSinkSuspensionLeavesLatestAndHistoryUntouched`, `NetworkActivityTests`의 `staleSourceAndStoreResultsCannotChangeBaselineLatestOrHistory`, `DiskActivityTests`의 `lateBoundaryRejectsSourceBaselineAndStoreHistory`가 해당 경계입니다. 이 테스트가 실제 다른 계정 전환의 대체 근거라는 뜻은 아닙니다.

[산출물 감사](./artifact-audit.txt)의 Release 앱은 `codesign --verify --deep --strict` 통과, App Sandbox=true, arm64 단일 아키텍처, 최소 macOS26.5, `LSUIElement=true`, 번들 PrivacyInfo의 현재 SHA 일치, 중첩 appex/xpc/helper 없음입니다. target은 앱·unit·UI 세 개이며 project의 package 의존 배열은 비어 있습니다. [빌드 설정 원문](./release-build-settings.log)도 보존했습니다. Debug 단위 host에는 XCTest 주입 framework와 testmanager entitlement가 추가돼 있으므로 그 Debug 앱을 production entitlement 근거로 사용하지 않고, 정상 앱 관찰에는 XCTest 주입 없는 서명 Release 산출물을 사용했습니다.

## 전체 signed UI와 Release 읽기 사례

task-015 진단 앱·AX watcher 정리 뒤 같은 clone의 고유 `UIDerivedData`에서 아래 전체 UI를 실행했습니다. 앱의 bundle ID는 `com.zipkero.ResourceRunner.Task018Revalidate`이며 현재 제품·테스트 소스는 [127파일 snapshot](./source-snapshot-sha256.txt) 그대로입니다. `RR_NATIVE_RELEASE_APP_PATH`는 지정하지 않아 실제 로그인 등록 상태를 바꾸는 다섯 사례를 의도적으로 제외했습니다.

```sh
RR_RELEASE_APP_PATH=/tmp/rr-task018-revalidate-20261009/DerivedData/Build/Products/Release/ResourceRunner.app xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -derivedDataPath /tmp/rr-task018-revalidate-20261009/UIDerivedData -resultBundlePath /tmp/rr-task018-revalidate-20261009/ui-full.xcresult '-only-testing:ResourceRunnerUITests' CODE_SIGNING_ALLOWED=YES
```

[원시 로그](./ui-full.log)·[xcresult summary](./ui-full-summary.json)는 **54 XCTest cases: 통과48, 실패0, skip6**입니다. 원시 XCTest 출력의 **55 runs**는 `ResourceRunnerUITestsLaunchTests.testLaunch` 성능 사례를 두 번 실행한 수이며, case 수와 분리합니다. 세 Disk 실제 UI(네 카드·상세·important-usage/1000), Network 상세, 작은 화면/설정/접근성, 한 세션 CPU 부하·메뉴바 회복 테스트가 통과했습니다. skip 여섯 중 다섯은 `RR_NATIVE_RELEASE_APP_PATH` 미지정으로 의도한 실제 로그인 사례입니다. 현재 M4 task-011의 별도 native signed UI5/5·실제 다음 로그인 관찰·현재9파일 SHA를 인수하고 이 suite의 통과로 합산하지 않습니다.

나머지 skip 하나는 `testReleaseBuildRightClickOpensSingleSettingsWindow`입니다. `RR_RELEASE_APP_PATH`를 `xcodebuild` 환경에 넣었지만 UI test runner가 상속하지 않아 test 자체가 경로 미전달로 skip했습니다. 원본 source를 바꾸지 않고 clone의 `build-for-testing`으로 만든 `.xctestrun`의 `ResourceRunnerUITests` Target `EnvironmentVariables`에 그 Release 경로 한 키만 주입했습니다([주입 파일](./release-readonly.xctestrun), [빌드 로그](./build-for-testing.log)). 아래 별도 재실행은 [원시 로그](./release-readonly-ui.log)·[summary](./release-readonly-ui-summary.json)에 **1/1 통과, 실패·skip0**입니다. 전체 UI 단일 실행을 54/54 통과로 바꾸어 쓰지 않습니다.

```sh
xcodebuild test-without-building -xctestrun /tmp/rr-task018-revalidate-20261009/UIDerivedData/Build/Products/ResourceRunner-Task018ReleaseReadOnly.xctestrun -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -resultBundlePath /tmp/rr-task018-revalidate-20261009/release-readonly.xcresult '-only-testing:ResourceRunnerUITests/SettingsWindowUITests/testReleaseBuildRightClickOpensSingleSettingsWindow'
```

## 정상 Release 앱 한 세션

별도 test argument·`RR_*` 변수를 주지 않고 동일 clone의 서명 Release 앱을 `open -n -a /tmp/rr-task018-revalidate-20261009/DerivedData/Build/Products/Release/ResourceRunner.app`로 열었습니다. 관찰 PID **30218**은 2026-10-09 13:27:50 KST 시작, [실행 경로·OS·서명/바이너리 SHA](./normal-identity.txt)에 고정했습니다. 이 Mac은 macOS26.6.2(25G83)입니다. 별도 AX helper는 기존 [task-018 helper](../normal-ax.swift)를 clone의 `/tmp` 실행 파일로 컴파일해 앱 소유 status item·popover를 조회하고, 카드 명시적 클릭·상세 Page Down·닫기를 실행했습니다. 앞선 Release 읽기 UI가 남긴 같은 clone의 PID29409는 이 관찰 전에 종료해 clone 앱은 PID30218 하나로 유지했습니다.

- [네 카드 실제 화면](./normal-four-cards.png)·[AX](./normal-four-cards-ax.txt): 본체280×668pt, CPU264×241, Memory264×169, Network/Disk264×112. CPU 실제값·축소 그래프·TOP5, Memory 구성·TOP5, Network 부분 합계, Disk 42pt 미니 그래프·저장 공간이 동시에 보입니다. Disk `/`의 전체994.7 GB, important-usage 사용 가능834.9 GB와 회수 가능 포함·실제 파일 점유량 아님·APFS 공유 정의를 카드 AX에서 확인했습니다. Network의 일부 물리 후보는 미확인이므로 완전 물리 대표값으로 주장하지 않습니다.
- 같은 PID에서 CPU [시작](./normal-cpu-detail-top.png)·[끝](./normal-cpu-detail-end.png), Memory [시작](./normal-memory-detail-top.png)·[끝](./normal-memory-detail-end.png), Network [시작](./normal-network-detail-top.png)·[끝](./normal-network-detail-end.png), Disk [시작](./normal-disk-detail-top.png)·[끝](./normal-disk-detail-end.png)을 각각 열고 Page Down 20회로 내부 목록 끝까지 이동한 뒤 닫았습니다. 각 상세 AX의 scroll area는400×480pt이며 본체 카드 frame은 유지됩니다. [Network 끝 AX](./normal-network-end-ax.txt)의 주소·인터페이스별 원시 누적과 `NetworkUpdateCadence` 실제 `AXValue`, [Disk 끝 AX](./normal-disk-end-ax.txt)의 `/` 전체/사용 중/사용 가능·APFS 설명, disk0 ID4294969732의 Read/Write·IOPS를 확인했습니다.
- 같은 PID에 앱 바깥 `/usr/bin/yes` 12개를 stdout `/dev/null`로 약18초 실행했습니다. [시각별 원시 AX](./normal-cpu-load.log)는 유휴 CPU **6–12%/메뉴바 낮음** → 부하 중 **88–89%/매우 높음** → 종료 뒤 **6–8%/낮음**을 기록합니다. 자식12개는 모두 종료됐고, 본체를 닫았다가 재개방한 [회복 후 AX](./normal-after-load-ax.txt)·[화면](./normal-after-load.png)은 같은 PID의 네 카드와 낮음 상태를 보입니다.

관찰 뒤 clone PID30218과 자체 부하를 종료했습니다. [정리 확인](./cleanup.txt)은 clone Release 프로세스0, `/usr/bin/yes` 0, 설치 Release PID64258 유지입니다. [최종 원본 검사](./final-source-check.txt)는 작업·관찰 전후 프로젝트의 127파일 SHA 변경0이고 `git diff --check`도 통과했습니다. 이 실행은 M4 task-013의 tmp 후보가 원본에 적용되기 전 원본에 대응합니다. 이후 원본 변경은 영향 범위와 승인 근거를 다시 대조해야 합니다.

## 최종 검증에 필요한 실행

공유 작업 트리의 source가 멈추고 task-015 실제 전이 결과가 도착하면, 같은 소스 snapshot을 기록한 후 다음을 수행합니다.

1. 선행 task-015의 실제 잠금·디스플레이·시스템 수면 전이 packet과 현재 source를 최종 대조합니다. 이 근거의 실제 세 전이·경계는 task-015 소유이며 여기서 새 전이를 수행하지 않습니다.
2. 위 전체 unit674/674와 Debug/Release 성공을 최종 source snapshot에 재대조합니다. M4 task-013 변경이 원본에 적용되면 관련 영향·전체 unit 재실행 필요성을 판정합니다. 과거 614/614 또는 M4의 여러 집중 suite를 현재 전체 통과로 합산하지 않습니다.
3. 위 전체 UI 48/54 통과·6skip과 Release 읽기 보완1/1, 현재 M4 로그인 native5/5 근거를 서로 구별해 인수합니다. 과거 task-018의 UI29/30+수정 단일1/1과 M4 signed UI17/18·M3 signed UI3/3은 현재 전체 suite 결과를 대신하지 않습니다.
4. 위 정상 Release PID30218 한 세션의 네 카드·네 상세 끝 페이지/복귀·CPU 부하 메뉴바 상승/회복을 현재 근거로 인수합니다.
5. 최종 빌드의 `xcodebuild -showBuildSettings`, `codesign -d --entitlements`, `codesign --verify --deep --strict`, `lipo -archs`, 실행 파일/target/package/PrivacyInfo 번들 확인과 source 경로 감사를 기록합니다. 현재 M4 설정값 저장과 지표의 메모리 전용 수명을 구분합니다.

task-015 실제 세 전이 packet과 task-018 모두 독립 승인 및 main의 상태 반영을 완료했습니다. 마지막 매핑 조건이 성립하여 M3 IMPLEMENT를 완료했습니다. 이후 원본에 적용한 M4 task-013 변경은 해당 Task의 현재 소스·집중92/92·동일 소스 전체679/679·Release 근거로 별도 검증하고 독립 승인했습니다. 이 packet의674/674·UI·정상 앱 실측을 후속 변경 후 실행 결과로 확대하지 않습니다.
