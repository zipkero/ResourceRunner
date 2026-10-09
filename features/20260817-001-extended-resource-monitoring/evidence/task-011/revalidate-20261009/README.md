# task-011 네 카드 화면 재검증 (2026-10-09)

기준 HEAD는 [`head.txt`](./head.txt)의 `5435c7dfdaf91d86c41827a6a521aa31b18dbbf9`이고 모든 원본 명령의 cwd는 `/Users/zipkero/XcodeProjects/ResourceRunner`입니다. 현재 M3 SPEC/DESIGN/task-011 첫머리의 가독성 override와 M4 DESIGN §3.6의 저장 공간 important-usage·1000 기반 정의를 적용했습니다. 제품 코드는 수정하지 않고 기존 `DiskCardUITests.swift`에 실제 네 카드의 화면 내 배치를 확인하는 테스트 하나만 추가했습니다([patch](./ui-test-change.patch)). 다른 Task의 미커밋 변경은 보존했습니다([상태](./status.txt), [diff 검사](./diff-check.txt)).

## 현재 원본 대응

[`source-sha256.txt`](./source-sha256.txt)에 화면·그래프·서식·native·관련 테스트 18파일의 현재 해시를 기록했습니다. 과거 task-011 `readable-integrated/source-sha256.txt`와 비교하면 `DashboardStyle.swift`와 `IntegratedDashboardSummaryTests.swift`만 그대로이고 나머지 화면 관련 소스는 이후 M4 등으로 달라졌습니다. 따라서 과거 610개 unit과 698pt 화면을 현재 결과로 주장하지 않습니다. 새 렌더는 현재의 668pt 자연 높이입니다.

Disk 용량의 `ResourceQuantityFormatter.swift`, `DiskNativeAdapter.swift`, `DiskDashboardView.swift`, `ResourceActivityPresentation.swift`, `PrivacyInfo.xcprivacy`, 두 관련 unit test는 [M4 승인된 Disk 용량 SHA](../../../../20261003-001-app-preferences/evidence/disk-capacity-20261004/source-sha256.txt)와 일치합니다. 그 승인 당시 관련 단위 48/48, signed Sandbox UI 1/1과 Release 빌드는 동일 소스의 용량 정의에 대한 근거입니다. 현재 [task-002](../../task-002/revalidate-20261009/README.md)의 raw important-usage 일치와 [task-006](../../task-006/revalidate-20261009/README.md)의 갱신·실패·볼륨 교체 캐시 31/31도 함께 인수합니다. [task-008 현재 집중 36/36·회귀 24/24](../../task-008/revalidate-20261009/README.md)는 변경된 표시 소비 경계에 한정해 인수합니다. 기존 전체 unit 610/610을 현재 HEAD의 전체 통과로 바꾸어 말하지 않습니다.

## 이번 실행

### 선택자 누락 보완 — main 실행

첫26개 실행의 `DashboardCardLayoutTests`·`DashboardValueColumnTests`는 파일명이어서 해당 suite는 실행되지 않았습니다. 독립 검토의 evidence reject를 보완해 실제8개 suite를 추가 실행했습니다. 원문 CPU/Memory 자리표시·구성·그래프·긴 값·랭킹 값 열의 현재 대응은 [추가 로그](./layout-supplement.log)·[summary](./layout-supplement-summary.json)의 **42/42, 실패/skip0**으로 확인합니다. 최초26개 통과와 별도 결과로 구별합니다. HeightTests는 같은 DashboardView/테스트 SHA의 M4task008 승인 근거를 인수합니다. [기존18파일 SHA 재대조](./layout-source-check.txt)는 모두 일치합니다. 보완 실행 시 M4task012의 additive 세 설정 모델/store 변경만 있었고 [추가3파일 SHA](./layout-additive-preferences-sha256.txt)를 기록했습니다. 이 변경은 기존 기본값·화면 배선에 영향을 주지 않습니다.

cwd 프로젝트 루트, 결과 `/tmp/rr-task011-layout-supplement-20261009.xcresult`:

```sh
xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -derivedDataPath /tmp/ResourceRunner-M3-task011-revalidate-20261009 -resultBundlePath /tmp/rr-task011-layout-supplement-20261009.xcresult -only-testing:ResourceRunnerTests/DashboardStyleTests -only-testing:ResourceRunnerTests/DashboardCardPlaceholderRenderingTests -only-testing:ResourceRunnerTests/CPUGraphPlotSurfaceRenderingTests -only-testing:ResourceRunnerTests/MemoryCardCompositionTotalRenderingTests -only-testing:ResourceRunnerTests/MemoryCardCompositionBarRenderingTests -only-testing:ResourceRunnerTests/DashboardValueColumnFormattingTests -only-testing:ResourceRunnerTests/DashboardValueColumnWidthTests -only-testing:ResourceRunnerTests/DashboardValueColumnAlignmentTests CODE_SIGNING_ALLOWED=NO
```

현재 원본에서 아래 집중 실행은 [`focused-test.log`](./focused-test.log), [`focused-summary.json`](./focused-summary.json)에 **26/26 통과, 실패·skip 0**으로 기록됐습니다. 결과 번들은 `/tmp/ResourceRunner-M3-task011-revalidate-20261009/Logs/Test/Test-ResourceRunner-2026.10.09_12-38-23-+0900.xcresult`입니다. 카드 슬롯·TOP 5 아래 3pt·아이콘/자리표시·긴 용량/로케일·정상/빈/실패/중지·CPU/Disk 그래프 판·segment/축·Network/Disk 상세 라벨을 관련 suite에서 확인했습니다.

```sh
xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ResourceRunner-M3-task011-revalidate-20261009 -only-testing:ResourceRunnerTests/DashboardCardLayoutTests -only-testing:ResourceRunnerTests/DiskDashboardViewTests -only-testing:ResourceRunnerTests/NetworkDashboardViewTests -only-testing:ResourceRunnerTests/ResourceRateGraphRenderingTests -only-testing:ResourceRunnerTests/IntegratedDashboardSummaryTests -only-testing:ResourceRunnerTests/ResourceRateGraphTests -only-testing:ResourceRunnerTests/DashboardValueColumnTests CODE_SIGNING_ALLOWED=NO
```

동일 원본의 결정적 전체 렌더는 [light](./render/light.png)·[dark](./render/dark.png) 각 **280×668px**, [수집 중](./render/collecting.png)입니다. 정상 fixture에는 실제 앱 아이콘과 CPU/Memory TOP 5 다섯 행, Memory 구성/Pressure/Swap, CPU 66.67pt 판, Disk 수치 옆 42pt 미니 판과 저장 공간 `994.7 GB / 826.9 GB`가 있습니다. main이 light/dark 두 PNG의 네 카드·모든 행·하단 잘림 없음과 새 용량 문구를 직접 확인했습니다. fixture 용량은 실제 장치 실측값이 아닙니다.

Release 빌드는 같은 cwd에서 다음 명령으로 [`release-build.log`](./release-build.log)의 **BUILD SUCCEEDED**를 확인했습니다. 위 단위 실행이 Debug 빌드도 수행했습니다.

```sh
xcodebuild build -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ResourceRunner-M3-task011-revalidate-20261009 CODE_SIGNING_ALLOWED=NO
```

실제 signed UI는 현재 `ResourceRunner`·Tests·UITests·project를 `/tmp/rr-task011-ui-isolated`로 복사하고 project의 앱 bundle ID만 `com.zipkero.ResourceRunner.Task011Revalidate`로 바꿔 실행했습니다. 앱 화면·Disk 용량·native 소스와 `AppDelegate.swift`는 현재 원본과 byte-for-byte 일치합니다. `codesign --verify --deep --strict` 통과, Sandbox true이며 UI test harness의 테스트 전용 entitlement는 제품 entitlement의 근거로 사용하지 않습니다. 설치 Release PID 64258은 수정·종료하지 않았습니다. 아래 명령의 [`ui-test.log`](./ui-test.log), [`ui-summary.json`](./ui-summary.json)은 **3/3 통과, 실패·skip 0**입니다. 결과 번들은 `/tmp/rr-task011-ui-isolated/ui.xcresult`입니다.

```sh
cd /tmp/rr-task011-ui-isolated
xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -derivedDataPath /tmp/rr-task011-ui-isolated/DerivedData -resultBundlePath /tmp/rr-task011-ui-isolated/ui.xcresult -only-testing:ResourceRunnerUITests/DiskCardUITests/testFourCardSummaryFitsVisibleScreenAndKeepsDiskCapacityAccessible -only-testing:ResourceRunnerUITests/DiskCardUITests/testRealDiskCardDetailAndReturnKeepFrames -only-testing:ResourceRunnerUITests/DiskCardUITests/testSandboxCapacityUsesDecimalUnitsAndReclaimableSpace CODE_SIGNING_ALLOWED=YES
```

실제 화면의 visibleFrame은 **1728×1084pt**, 배율 2입니다. 본체 **280×668pt**, CPU **264×241pt**, Memory **264×169pt**, Network/Disk 각각 **264×112pt**, 카드 간격 6pt로 네 카드가 모두 hittable이고 본체 스크롤이 없습니다. [실제 전체 캡처](./ui-attachments/actual-four-cards.png)에는 CPU/Memory TOP 5 다섯 행과 마지막 Disk 하단이 보입니다. 현재 `/` 카드 AX의 전체 **994.7 GB**, important-usage 사용 가능 **838.0–838.1 GB**와 회수 가능 포함 문구, [실제 상세 캡처](./ui-attachments/actual-disk-detail.png)의 전체−사용 가능·실제 점유량 아님·APFS 공유 설명을 확인했습니다. 다른 시각의 가용 공간을 정확히 같은 수치라고 비교하지 않았습니다. Disk 상세 열기/닫기·재선택·카드와 본체 frame 불변도 통과했습니다.

이 재검증은 task-011의 현재 요약/용량 영향 범위입니다. 추가 viewport와 전체 offscreen 키보드 탐색·네 상세 끝 페이지는 각각 task-012·013의 현재 소스 대응 근거와 구별합니다. 전체 UI suite·전체 unit을 다시 실행하지 않았고, 이번 집중 실행·실제 signed UI·현재 SHA 대응 범위만 주장합니다. Task 승인·상태 변경은 main과 독립 verifier가 담당합니다.
