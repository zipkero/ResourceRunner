# Context

저장: 2026-10-03 (M4 task-007 환경 차단)

## 현재 목표

사용자 `$implement-loop M4`에 따라 미완료 Task를 순서대로 구현·verify한다. main 스테이징·커밋·푸시 승인은 유지된다.

## 현재 상태

- branch main, loop 시작 HEAD cf9bc683. task-001을 worker가 구현하고 독립 verifier approved를 main이 확정했다. task-001~006 [x], task-007~011 [ ], SPEC/DESIGN [x], IMPLEMENT [ ].
- 새 AppPreferences.swift·PreferencesStore.swift·PreferencesStoreTests.swift, 근거와 상태 문서를 인수했다. 전용 signed 테스트5/5·실패0/skip0, 소스 해시·패치·xcresult 대응을 확인했다. 실제 초기 앱 배선·로그인은 아직 후속 범위다.
- task-002의 제품5개·검증4개 파일과 근거를 인수했다. A→B→A target 역순의 최신 revision 미적용으로 최초 correctness reject였으나 worker 재시도1에서 두 Scheduler 검사와 회귀3개를 보완했다. 독립 verifier approved를 main이 확정했다. 관련7suite50case(동적56실행), 실패/skip0·전체9파일 최종 해시 대응을 확인했다.
- 재시도 누적: task-001 구현0/근거0, task-002 구현1/근거0, task-003 구현0/근거0, task-004 구현0/근거0, task-005 구현0/근거0, task-006 구현0/근거0. 초기 reject·근거는 evidence/task-002의 이력으로 보존했다. collaboration worker thread limit·not_found를 확인하고 같은 worker 모델 gpt-6-sol/medium의 로컬 CLI로 수정했으며 재검증은 custom verifier를 사용했다.
- task-003의 제품6개·검증5개 파일을 인수했다. 기준 HEAD429906e, 제품 커밋e429527, 독립 verifier approved를 main이 확정했다. 관련86case(동적94실행)·Memory6case(동적17실행), 실패/skip0·소스/패치/로그 해시 대응을 확인했다. 그래프 적용은 task-006이다.
- task-004 새3파일을 인수했다. 기준 HEADccb1bf8, 독립 verifier approved를 main이 확정했다. signed 주입7/7·실패/skip0·patch/blob·소스 해시 대응 확인. 실제 native OS mutation은 수행하지 않았다.
- task-005 제품4개·검증4개를 인수했다. 기준 HEADd119c73, 독립 verifier approved 확정. signed42case·실패/skip0·전체8파일 해시 대응. 기존 전체 모델+현재 snapshot 선별의 내부 접근 차이를 Task에 반영했으며 그래프/카드 표시 자체는006/007이다. 실제 로그인 mutation 없음.
- task-006 제품5개·검증4개를 인수했다. 기준 HEAD8345f58, 독립 verifier approved 확정. signed serial86case(동적90실행)·실패/skip0·9파일 해시/패치 대응. 이전 불완전한 병렬 결과는 제외. 내장 verifier 호출 제한을 확인해 동일 gpt-6-sol/high 읽기 전용 역할을 로컬 CLI로 실행했다. 실제 설정창/앱 통합은 후속이다.
- task-007 worker blocked를 인수했다. 기준 HEADccee0f6(승인006 제품까지 main pushed), 미커밋10파일 부분 구현과 evidence/task-007 근거를 보존했다. signed 단위40/40·6suite/64렌더 조합 통과지만 UI 두 번 모두 본문 전 LocalAuthentication Code=-4로 차단됐다. main은 coreautha PID55055 실행·테스트 runner 잔존 없음 확인. 인증/TCC/시스템 프로세스 변경 없음. 인증 대기 창 처리 여부를 사용자에게 async 요청했으나 저장 시 답변 없음. task007 loop 구현0/근거0, verifier 판정 없음. task008~011 미착수, 첫 미완료007을 건너뛰지 않는다.
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

task-001~006은 승인됐다. task-007은 부분 구현 후 UI 인증 충돌로 blocked이며 상위 결정의 부족은 없다. 후속 실제 UI·로그인 결과는 아직 없으며 task-011의 실제 세션 전환 권한·환경은 해당 착수 시 main이 확인한다.

## 다음 작업

- 작업: macOS 인증이 끝난 뒤 task-007의 저장된 signed UI 명령을 재실행한다. 실제 UI근거를 확보하면 독립 verify와 main 승인 후 task-008로 진행한다.
- 완료 기준: task-007의 필수 UI 본문이 실행되어 AX/frame·전체 숨김·상세 숨김/재표시를 확인하고 현재10파일 해시/diff와 단위/UI 근거가 대응해야 한다. Task별 현재 원본·diff·검증 근거로 승인하고 상태·이력을 갱신한다. SPEC §5.1~§5.13의 모든 매핑 Task가 승인되기 전에는 IMPLEMENT를 완료로 표시하지 않는다. 필수 실제 관문 미확인은 남긴다.

## 먼저 읽을 파일

- [task-007 근거/재개 명령](./features/20261003-001-app-preferences/evidence/task-007/README.md), [worker 결과](./features/20261003-001-app-preferences/evidence/task-007/worker-result.md), [현재 코드 해시](./features/20261003-001-app-preferences/evidence/task-007/source-sha256.txt)

- [M4 구현 계획](./features/20261003-001-app-preferences/implement.md), [SPEC](./features/20261003-001-app-preferences/spec.md), [DESIGN](./features/20261003-001-app-preferences/design.md), [상태](./features/20261003-001-app-preferences/README.md)
- [AppDelegate.swift](./ResourceRunner/AppDelegate.swift), [ApplicationCoordinator.swift](./ResourceRunner/ApplicationCoordinator.swift)
- [MonitoringLifecycle.swift](./ResourceRunner/MonitoringLifecycle.swift), [CollectionPipelines.swift](./ResourceRunner/CollectionPipelines.swift)
- 각 Task에 명시한 원본·기존 검증 파일
- ~/.codex/skills/implement-loop/SKILL.md, ~/.codex/skills/implement/SKILL.md, ~/.codex/skills/verify/SKILL.md, ~/.codex/docs/phased-state.md

## 문서 반영 필요

없음. 구현 계획과 상태를 M4 문서·ROADMAP·CONTEXT에 반영했다. 상위 기술 설계의 현재 구현 설명은 제품 구현 후 해당 단계에서 갱신한다.
