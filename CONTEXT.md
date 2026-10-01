# Context

저장: 2026-10-01 22:02 +0900

## 현재 목표

사용자 요청 `$implement-loop M3`로 Task를 위에서부터 구현·검증한다.
각 Task가 독립 verify에서 승인되면 main이 상태·인수인계를 갱신하고 커밋한 뒤 다음 Task로 진행한다(2026-10-01 추가 지시).
첫 커밋에는 미커밋 M3 선행 문서도 포함한다.

## 현재 상태

branch `main`, task-006 검증 기준 HEAD `854c97d`. task-001~006 독립 verify approved를 main이 확정했다.
SPEC·DESIGN `[x]`, IMPLEMENT `[ ]`, task-001~006 `[x]`, task-007~018 `[ ]`다.
각 승인 Task를 커밋한 뒤 다음 Task를 진행한다. 다음은 task-007이다.

실행 원자료는 feature `evidence/task-001/`~`task-006/`에 있다.
Network·Disk native adapter는 별도 build-only arm64 Sandbox 앱에서 필수 원본 접근·새 예외 없음을 확인했다.
Disk는 물리 disk0 바이트·Operations, `/` 용량과 APFS 볼륨 8개 관계를 확인했다.
Network llw0 unknown·합계 complete=false를 보존하며 실제 VPN·인터페이스·외장 전환은 task-014에서 확인한다.

task-003은 공통 CollectionAdmission의 동기 무효화/반영 검사, 누적 경계·sleep/wake,
axis planRevision·epoch·generation·request 순서를 기존 두 축과 표시까지 배선했다.
async witness 우회·늦은 tick token 발급·역순 일정 적용을 보완했고 전용 통합 테스트와
전체 단위 528/528, Release 빌드가 통과했다. 소스 12개 해시·최종diff는 evidence/task-003와 대응한다.
실제 OS 전환·UI 통합은 task-015·018의 후속 관문이다.
Network native reader의 기존 Swift 6 격리 경고는 task-005에서 명시 nonisolated 선언으로 해소했다.
Network·Disk activity/metadata source·store는 구현됐고 새 네 축 production 배선·카드는 아직 없다. M2 기존 계약과 회귀 기준을 유지한다.

task-004은 .m3 여섯 축 일정·보조 조회 scheduler를 구현했다. 실제 보조 scheduler의
즉시/신선도/병합/중지중 보류/단일 실행과 느린 보조 조회 중 빠른4축 진행을 확인했다.
전용6개×5회·전체534/534·Release빌드 통과, 변경소스4개 해시와 원자료는 evidence/task-004에 있다.

task-005는 Network fast/slow native reader·activity/metadata source/store와 topology 수명을 구현했다.
확인된 물리 속도는 knownPhysicalRates에 보존하고 llw0 unknown 때문에 완전 representative는 nil/partial이다.
유효 완전 합계만 601링에 들어가며, 불완전 속도는 완전한 그래프 점으로 보관하지 않는다.
두 reader의 late/역순 tracker 부수효과와 metadata await 중 topology 변경도 현재 gate·revision으로 차단한다.
집중24/24·전체unit552/552·Release/별도서명Debug·Sandbox baseline/부분속도 probe 통과, PID 종료 확인.
전체scheme UIrunner는 기동후 진행이 없어 중단했으며 UI 성공 근거는 아직 없다.


task-006 독립 verify approved를 main이 확정했다. 기준 HEAD `854c97d`의
DiskNativeAdapter·AppDelegate·DiskActivity·DiskTopology·StorageMetadata·직접 테스트 2개를 검증했다.
최종 집중27/27·전체unit572/572·Release/서명Debug·Sandbox PID43148 두 tick이 통과했고
소스7개 해시 일치와 원자료는 `evidence/task-006/`에 보존했다.
필수 Bytes 누락의 partial/부분속도, Ops 감소의 IOPS만 기준점 처리,
전체 관계 미확인과 미마운트 구분, 같은 ID의 마운트 관계 변화 revision을 보완했다.
task-006 `[x]`이며 상태·CONTEXT를 커밋한 뒤 task-007로 진행한다.

## 현재 작업 문서

- [features/20260817-001-extended-resource-monitoring/spec.md](./features/20260817-001-extended-resource-monitoring/spec.md) — 승인된 요구사항과 완료 조건 18개
- [features/20260817-001-extended-resource-monitoring/design.md](./features/20260817-001-extended-resource-monitoring/design.md) — 구조·데이터 흐름·인터페이스·영향 범위와 채택한 DP1~DP7
- [features/20260817-001-extended-resource-monitoring/implement.md](./features/20260817-001-extended-resource-monitoring/implement.md) — Task 18개와 검증 조건, 완료 조건 매핑
- [features/20260817-001-extended-resource-monitoring/README.md](./features/20260817-001-extended-resource-monitoring/README.md) — SPEC·DESIGN `[x]`, IMPLEMENT `[ ]`, 승인 이력
- [ROADMAP.md](./ROADMAP.md) — M3 설계 완료와 M2 잔여 범위

## 확정된 결정

계약의 상세와 확인 근거는 SPEC·DESIGN·IMPLEMENT 원본을 따른다.
Task의 의존 순서는 implement.md 항목 위치를 따른다. task-001·002는 앱 내부 native adapter 관문이며 이후 공통 경계·일정·수집·표시·실기기 검증으로 진행한다.

- 기존 두 축에 Network·Disk 활동과 메타데이터 네 축을 추가하고, 일정·실패·느린 조회를 격리한다.
- Network 대표값은 물리 인터페이스 합계이며 VPN 터널은 상세 전용이다. Disk는 물리 드라이버별 중복을 제거하고 APFS 볼륨 용량을 합산하지 않는다.
- 중지·sleep 복귀·대상 변경·카운터 초기화에서 첫 샘플은 기준점 전용이다. epoch·수집 축 generation·요청 순서와 커밋 경계로 늦은 결과를 차단한다.
- 최근 10분의 두 계열 속도 그래프는 같은 축에 겹쳐 표시한다. 공통 그래프 판과 미수집 구간의 공백을 유지한다.
- 본체는 단일 열 세로 스크롤로 네 카드를 제공하고 본체·상세 크기를 실제 화면 가용 영역에 맞춘다. 카드별 그래프 높이를 다르게 줄이지 않는다.
- 연결 속도·IOPS는 조건부 지표다. 필수 속도·저장 공간 접근 실패는 요구사항 변경 없이 완료로 처리하지 않는다.
- M3 비교는 시스템 도구와 변화 방향을 확인한다. 최종 수치 정확성·성능·장기 안정성은 M5 소관이다.

## 미확정 판단

현재 SPEC·DESIGN에 미확정 요구사항이나 미채택 결정은 없다.
실제 배포 Sandbox에서 필수 API 접근이 불가능하면 근거와 영향을 정리해 SPEC 소유 단계로 반환한다.
구현 중 카드 프레임·실제 화면 관문을 만족하지 못해 설계 변경이 필요하면 DESIGN으로 반환한다.

## 다음 작업

- 작업: M3 task-007 production 여섯 축 배선과 실패 격리를 worker로 구현하고 독립 verify한다.
- 완료 기준: production과 같은 구성에서 지표별 실패·보조 suspension·취소 무시·중지/복귀·초기 lifecycle 이후 시작·single-flight·메뉴바 진행을 확인하고 실제 앱 최초 요청·팝오버/전력 일정 배선을 관찰한다. approved 뒤 상태·CONTEXT 갱신·커밋 후 task-008로 진행한다.

## 먼저 읽을 파일

- [ResourceRunner/DiskNativeAdapter.swift](./ResourceRunner/DiskNativeAdapter.swift)
- [ResourceRunner/NetworkActivity.swift](./ResourceRunner/NetworkActivity.swift)
- [ResourceRunner/NetworkMetadata.swift](./ResourceRunner/NetworkMetadata.swift)
- [ResourceRunner/NetworkTopology.swift](./ResourceRunner/NetworkTopology.swift)

- [ResourceRunner/CollectionAdmission.swift](./ResourceRunner/CollectionAdmission.swift)
- [ResourceRunner/AuxiliaryCollectionScheduler.swift](./ResourceRunner/AuxiliaryCollectionScheduler.swift)

- [ResourceRunner/NetworkNativeAdapter.swift](./ResourceRunner/NetworkNativeAdapter.swift)
- [ResourceRunner/AppDelegate.swift](./ResourceRunner/AppDelegate.swift)
- [ResourceRunnerTests/NetworkNativeAdapterTests.swift](./ResourceRunnerTests/NetworkNativeAdapterTests.swift)
- [features/20260817-001-extended-resource-monitoring/evidence/task-001/environment.txt](./features/20260817-001-extended-resource-monitoring/evidence/task-001/environment.txt)
- [features/20260817-001-extended-resource-monitoring/implement.md](./features/20260817-001-extended-resource-monitoring/implement.md)
- [features/20260817-001-extended-resource-monitoring/README.md](./features/20260817-001-extended-resource-monitoring/README.md)
- [features/20260817-001-extended-resource-monitoring/spec.md](./features/20260817-001-extended-resource-monitoring/spec.md)
- [features/20260817-001-extended-resource-monitoring/design.md](./features/20260817-001-extended-resource-monitoring/design.md)
- [ROADMAP.md](./ROADMAP.md)
- [ResourceRunner/ApplicationCoordinator.swift](./ResourceRunner/ApplicationCoordinator.swift)
- [ResourceRunner/MonitoringLifecycle.swift](./ResourceRunner/MonitoringLifecycle.swift)
- [ResourceRunner/MonitoringScheduler.swift](./ResourceRunner/MonitoringScheduler.swift)
- [ResourceRunner/DashboardView.swift](./ResourceRunner/DashboardView.swift)
- [ResourceRunner/DashboardPresentation.swift](./ResourceRunner/DashboardPresentation.swift)

## 문서 반영 필요

`docs/product.md`·`docs/design.md`의 미확정 목록에는 기존 M3 SPEC에서 확정된 VPN 합산과 프로세스별 Disk I/O 항목이 남아 있다.
통합 문서 정리 시 feature 결정을 반영해야 한다. 현재 선행 계약은 SPEC §1.2에 복원돼 있고 이번 DESIGN도 그 확정 결정을 사용했다.
