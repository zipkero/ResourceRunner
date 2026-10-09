# task-008 활동·보조 표시 재검증 (2026-10-09)

기준 HEAD는 [`head.txt`](./head.txt)의 `5435c7dfdaf91d86c41827a6a521aa31b18dbbf9`이며, 검증 cwd는 `/Users/zipkero/XcodeProjects/ResourceRunner`입니다. 현재 승인된 M3 SPEC/DESIGN·task-008과 [M4 DESIGN §3.6](../../../../20261003-001-app-preferences/design.md)의 Disk 저장 공간 정의를 적용했습니다. 제품 코드는 수정하지 않았습니다. 다른 Task의 미커밋 변경은 [`status.txt`](./status.txt)대로 보존했습니다.

## 현재 소스와 기존 근거의 대응

현재 [`source-sha256.txt`](./source-sha256.txt)를 [과거 task-008](../source-sha256.txt), [승인된 Disk 용량 수정](../../../../20261003-001-app-preferences/evidence/disk-capacity-20261004/source-sha256.txt), [task-002 native 재검증](../../task-002/revalidate-20261009/source-sha256.txt), [task-006 cache 재검증](../../task-006/revalidate-20261009/source-sha256.txt)과 대조했습니다. 파일별 일치·변경 및 두 SHA의 원문은 [`hash-comparison.txt`](./hash-comparison.txt)에 있습니다.

| 경계 | 현재 대응과 인수 범위 |
| --- | --- |
| 조립·서식·테스트 | `ResourceActivityPresentation.swift`, `ResourceQuantityFormatter.swift`, `ResourceActivityPresentationTests.swift`는 승인된 Disk 용량 수정의 SHA와 각각 일치합니다. 과거 task-008의 원본 의미는 새 important-usage·1000 기준으로 바뀐 부분만 현재 M4 근거와 아래 집중 실행으로 대체합니다. |
| native 값·캐시 | `DiskNativeAdapter.swift`, `PrivacyInfo.xcprivacy`, `DiskNativeAdapterTests.swift`는 M4 승인·task-002 재검증 SHA와 일치합니다. `DiskNativeAdapter.swift`는 task-006의 signed Sandbox 복사본과도 일치합니다. task-002의 같은 시각 raw total/important-usage 값과 adapter 값 일치, task-006의 용량 갱신·실패·identity 교체 캐시 및 집중31/31을 인수합니다. 이전 raw available 근거는 사용하지 않습니다. |
| 카드·상세·AX | `DiskDashboardView.swift`, `DiskDashboardViewTests.swift`, `DiskCardUITests.swift`는 승인된 Disk 용량 수정 SHA와 각각 일치합니다. 당시 signed Sandbox UI1/1에서 현재 기준의 카드·상세·AX 및 112pt 동작을 확인했습니다. 현재 집중 실행은 같은 카드 테스트를 다시 실행했습니다. |
| 표시 전달·기존 상태 | `CollectionDeliveryStore.swift`는 과거 task-008 SHA와 일치합니다. `ApplicationCoordinator.swift`, `CollectionAdmission.swift`, `DashboardPresentationStore.swift`는 이후 M4 설정·프로필·표시 변경으로 과거 SHA와 다릅니다. 이 셋의 과거 실행 결과를 현재 코드의 단독 근거로 쓰지 않고 아래 production 소비자·admission·pipeline·CPU/Memory 표시 테스트를 재실행했습니다. |
| 이력 | 현재 M4 승인 정의는 600초·1203개 링입니다. [task-006 현재 검증](../../task-006/revalidate-20261009/README.md)의 이력·segment 결과와 [M4 task-003](../../../../20261003-001-app-preferences/evidence/task-003/README.md), [M4 task-005](../../../../20261003-001-app-preferences/evidence/task-005/README.md)의 범위를 인수합니다. 과거 task-008의 이력 정원을 현재 정의의 근거로 사용하지 않습니다. |

## 현재 집중 실행

다음 명령은 위 cwd에서 실행했습니다. 원본 결과 번들은 `/tmp/ResourceRunner-M3-task008-revalidate-20261009/Logs/Test/Test-ResourceRunner-2026.10.09_12-32-17-+0900.xcresult`입니다. [`focused-test.log`](./focused-test.log)와 [`focused-summary.json`](./focused-summary.json)은 **36/36 통과, 실패·skip 0**입니다. 관련 소스의 [`diff-check.txt`](./diff-check.txt)는 빈 파일이며 `git diff --check` 성공을 뜻합니다.

```sh
xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -destination 'platform=macOS,arch=arm64' -only-testing:ResourceRunnerTests/ResourceActivityPresentationTests -only-testing:ResourceRunnerTests/CollectionAdmissionTests -only-testing:ResourceRunnerTests/CollectionPipelinesTests -only-testing:ResourceRunnerTests/DiskDashboardViewTests -only-testing:ResourceRunnerTests/DashboardPresentationStoreTests -derivedDataPath /tmp/ResourceRunner-M3-task008-revalidate-20261009 CODE_SIGNING_ALLOWED=NO
```

`ResourceActivityPresentationTests`는 Network/Disk의 정상0·미연결·기준점·부분 합계·보조 실패 중 빠른 속도 갱신·성공 이력 없는 실패·과거 성공값과 원본 시각·중지·identity/revision/epoch 불일치·역순 topology commit을 확인합니다. 저장 공간만1000 기반 B/KB/MB/GB/TB이고 속도·누적 바이트는1024 기반이며 bit/s·회/s도 별도라는 경계와 작은 속도·로케일을 확인합니다. `DiskDashboardViewTests`는 전체/사용 가능의 compact·상세·AX 용량, 서로 다른 단위, 회수 가능 포함 설명과 카드 슬롯을 확인합니다. `CollectionAdmissionTests`·`CollectionPipelinesTests`·`DashboardPresentationStoreTests`는 현재 소비 경계의 늦은 결과 거절, 여섯 축 독립 진행, CPU/Memory 기존 상태를 확인합니다.

변경된 `DashboardPresentationStore.swift`의 기존 CPU/Memory 실패·재개·선택 상태도 현재 소스에서 직접 확인했습니다. 같은 cwd·derivedDataPath로 아래 네 suite를 실행했고 [`regression-test.log`](./regression-test.log), [`regression-summary.json`](./regression-summary.json)은 **24/24 통과, 실패·skip 0**입니다. 결과 번들은 `/tmp/ResourceRunner-M3-task008-revalidate-20261009/Logs/Test/Test-ResourceRunner-2026.10.09_12-33-45-+0900.xcresult`입니다.

```sh
xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -destination 'platform=macOS,arch=arm64' -only-testing:ResourceRunnerTests/DashboardMemoryPresentationStoreTests -only-testing:ResourceRunnerTests/DashboardCardFailureIsolationTests -only-testing:ResourceRunnerTests/DashboardCollectionStoppedTests -only-testing:ResourceRunnerTests/DashboardSelectionTests -derivedDataPath /tmp/ResourceRunner-M3-task008-revalidate-20261009 CODE_SIGNING_ALLOWED=NO
```

이번에는 제품 앱·설치 앱 PID 64258을 변경하거나 실행하지 않았습니다. 실제 native 값은 현재 소스와 SHA가 일치하는 task-002/006의 별도 signed Sandbox 진단과 M4 signed UI를 정확한 범위에서 인수했습니다. 전체 unit·Release·실제 외장 장치 전환을 재실행하지 않았으며, task-008의 표시 모델과 저장 공간 정의에 영향을 주는 현재 집중36개와 CPU/Memory 회귀24개를 실행했습니다. Task 승인·상태 변경은 main과 독립 verifier가 담당합니다.
