# Context

저장: 2026-10-03 (M4 task-002 승인)

## 현재 목표

사용자 `$implement-loop M4`에 따라 미완료 Task를 순서대로 구현·verify한다. main 스테이징·커밋·푸시 승인은 유지된다.

## 현재 상태

- branch main, loop 시작 HEAD cf9bc683. task-001을 worker가 구현하고 독립 verifier approved를 main이 확정했다. task-001/002 [x], task-003~011 [ ], SPEC/DESIGN [x], IMPLEMENT [ ].
- 새 AppPreferences.swift·PreferencesStore.swift·PreferencesStoreTests.swift, 근거와 상태 문서를 인수했다. 전용 signed 테스트5/5·실패0/skip0, 소스 해시·패치·xcresult 대응을 확인했다. 실제 초기 앱 배선·로그인은 아직 후속 범위다.
- task-002의 제품5개·검증4개 파일과 근거를 인수했다. A→B→A target 역순의 최신 revision 미적용으로 최초 correctness reject였으나 worker 재시도1에서 두 Scheduler 검사와 회귀3개를 보완했다. 독립 verifier approved를 main이 확정했다. 관련7suite50case(동적56실행), 실패/skip0·전체9파일 최종 해시 대응을 확인했다.
- 재시도 누적: task-001 구현0/근거0, task-002 구현1/근거0. 초기 reject·근거는 evidence/task-002의 이력으로 보존했다. collaboration worker thread limit·not_found를 확인하고 같은 worker 모델 gpt-6-sol/medium의 로컬 CLI로 수정했으며 재검증은 custom verifier를 사용했다.
- M3 task014/015 보류와 기존 승인은 유지한다. M4 실제 로그인 관문은 별도다. 기존 M3 검증을 M4 통과로 사용하지 않는다.

## 현재 작업 문서

- [M4 상태](./features/20261003-001-app-preferences/README.md)
- [M4 SPEC](./features/20261003-001-app-preferences/spec.md)
- [M4 DESIGN](./features/20261003-001-app-preferences/design.md)
- [M4 구현 계획](./features/20261003-001-app-preferences/implement.md)
- [ROADMAP](./ROADMAP.md), [제품 정의](./docs/product.md), [기술 설계](./docs/design.md)
- [M3 상태](./features/20260817-001-extended-resource-monitoring/README.md), [M3 통합 근거](./features/20260817-001-extended-resource-monitoring/evidence/task-018/README.md)

## 확정된 결정

- M4 첫 범위·기본값·정책은 승인된 SPEC·DESIGN이 소유한다. 구현 계획은 저장→일정/실행권→차분/이력→로그인 관리→초기 배선→그래프→표시→포커스/앵커→설정창→통합→실제 로그인 순서다.
- 기본 네 카드의 무스크롤·가독성·Memory 자연 높이·Network 그래프 없음·Disk 미니 그래프·TOP 5 여백·상세/AX를 유지한다. 작은 화면 정책과 M3 보류 항목은 별도다.
- task-011은 실제 서명된 안정 경로 앱의 등록/해제와 다음 로그인 실행을 판정한다. mock·status·수동 실행으로 대체하지 않으며 미래 운영 접근·사용자 승인 범위와 환경이 없으면 미승인으로 남긴다.
- 기존 Task012 stash0ef806c85321a92c7a07226de4b0080a7cc1eb48은 구치수이므로 전체 적용하지 않는다.

## 미확정 판단

task-001/002는 승인됐다. 상위 결정의 부족은 없다. 후속 실제 UI·로그인 결과는 아직 없으며 task-011의 실제 세션 전환 권한·환경은 해당 착수 시 main이 확인한다.

## 다음 작업

- 작업: 첫 미완료 task-003을 worker에게 맡겨 당시 P의 차분/G·단절·1203개 제한 이력을 구현하고 verify한다.
- 완료 기준: Task별 현재 원본·diff·검증 근거로 승인하고 상태·이력을 갱신한다. SPEC §5.1~§5.13의 모든 매핑 Task가 승인되기 전에는 IMPLEMENT를 완료로 표시하지 않는다. 필수 실제 관문 미확인은 남긴다.

## 먼저 읽을 파일

- [M4 구현 계획](./features/20261003-001-app-preferences/implement.md), [SPEC](./features/20261003-001-app-preferences/spec.md), [DESIGN](./features/20261003-001-app-preferences/design.md), [상태](./features/20261003-001-app-preferences/README.md)
- [AppDelegate.swift](./ResourceRunner/AppDelegate.swift), [ApplicationCoordinator.swift](./ResourceRunner/ApplicationCoordinator.swift)
- [MonitoringLifecycle.swift](./ResourceRunner/MonitoringLifecycle.swift), [CollectionPipelines.swift](./ResourceRunner/CollectionPipelines.swift)
- 각 Task에 명시한 원본·기존 검증 파일
- ~/.codex/skills/implement-loop/SKILL.md, ~/.codex/skills/implement/SKILL.md, ~/.codex/skills/verify/SKILL.md, ~/.codex/docs/phased-state.md

## 문서 반영 필요

없음. 구현 계획과 상태를 M4 문서·ROADMAP·CONTEXT에 반영했다. 상위 기술 설계의 현재 구현 설명은 제품 구현 후 해당 단계에서 갱신한다.
