# Context

저장: 2026-10-01 19:49 +0900

## 현재 목표

사용자 요청 `$implement-loop M3`로 Task를 위에서부터 구현·검증한다.
각 Task가 독립 verify에서 승인되면 main이 상태·인수인계를 갱신하고 커밋한 뒤 다음 Task로 진행한다(2026-10-01 추가 지시).
첫 커밋에는 미커밋 M3 선행 문서도 포함한다.

## 현재 상태

branch `main`, task-002 검증 기준 HEAD `eed1f53`. task-001·002 독립 verify approved를 main이 확정했다.
SPEC·DESIGN `[x]`, IMPLEMENT `[ ]`, task-001·002 `[x]`, task-003~018 `[ ]`다.
각 승인 Task를 커밋한 뒤 다음 Task를 진행한다. 다음은 task-003이다.

Network 원자료는 feature `evidence/task-001/`, Disk 원자료는 `evidence/task-002/`다.
Disk 7개·Network 6개 테스트 통과, 별도 build-only arm64 Sandbox 앱에서 물리 disk0 Read·Write·Operations,
`/` 용량과 APFS 볼륨 8개의 물리 드라이버 관계를 확인했다. source 해시 일치·새 예외 없음을 확인했다.
Network nonisolated 인접 변경의 영향은 verifier가 같은 빌드 Network probe를 재실행해 회귀 없음을 확인했다.
llw0 unknown·합계 complete=false를 보존하며 실제 VPN·인터페이스·외장 전환은 task-014에서 확인한다.
NetworkRouteReader 생성의 Swift 6 격리 경고는 후속 source·격리 배선에서 확인할 품질 위험이다.
Network·Disk Collector와 카드는 아직 없다. M2 기존 계약과 회귀 기준을 유지한다.

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

- 작업: M3 task-003 공통 수집 경계와 source·store·표시의 원자적 admission을 worker로 구현하고 독립 verify한다.
- 완료 기준: 승인된 task-003의 병합된 짧은 중지·취소 무시·역순 응답·sink suspension·표시 역순을 결정적으로 재현해 기준점·현재값·이력·카드 상태 불변성과 CPU·Memory·프로세스·메뉴바 회귀를 확인한다. approved 뒤 상태·CONTEXT를 갱신하고 커밋 후 task-004로 진행한다.

## 먼저 읽을 파일

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
