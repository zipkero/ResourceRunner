# Context

저장: 2026-10-04 (M4 task-008 승인·loop 계속)

## 현재 목표

M4 미완료 Task를 순서대로 구현·verify한다. 사용자 “진행해”로 남은 task-008~011의 순차 loop를 재개했다. main 스테이징·커밋·푸시 승인은 유지된다.

## 현재 상태

- branch main, 이번 검증 기준 HEAD b8a83973efd29905d3d9e2406b2fb63ad6f7bedd. SPEC/DESIGN [x], IMPLEMENT [ ]; task-001~008 [x], task-009~011 [ ]·미착수.
- task-001 설정 저장/복원,002 프로필/단일조회,003 차분/1203링/당시G,004 실제 로그인 상태 controller,005 동일snapshot 초기 배선,006 CPU/Disk 범위를 승인했다. 상세 이력·근거는 기능 README와 evidence/task-001~006에 있다.
- task-007 worker가10파일을 부분 구현했으나 2026-10-03 UI runner LocalAuthentication Code=-4로 blocked였다. 이번 첫 UI 재실행은 automation mode timeout, 재시도는 실제2개 중 전체 숨김 버튼AX 식별자 실패1개다. 진단 AX트리에서 부모 DashboardAllCardsHidden 식별자가 자식 버튼ID를 가린 것을 확인해 부모ID만 제거했다. 버튼label/hittable/frame/자연높이/click·4카드AX부재를 보강했고 실시간 상세 숨김/재표시 검증은 유지했다.
- 최종 signed arm64 UI2/2·단위40/40/6suite(64개 ImageRenderer 조합)·실패/skip0, 전체10파일SHA와 새파일 포함patch 대응. 독립 verifier approved를 main이 확정했다. 코드/근거/상태를 스테이징·커밋·푸시한다. 최신 근거는 evidence/task-007/resume-20261004.
- 내장 verifier 호출은 agent thread limit으로 실패해 /Users/zipkero/.codex/agents/verifier.toml의 동일 gpt-6-sol/high 읽기 전용 역할을 로컬Codex CLI로 적용했다. main은 최종 판정/문서/상태를 수행했다.
- 구현 보완 누적: task-002 correctness1(A→B→A 최신revision누락), task-007 correctness1(부모AXID전파); 다른Task0. 근거 재검증은 모든Task0. 이전 실패/차단과 원인은 이력으로 유지하며 현재 reject는 없다.
- native 로그인 mutation·TCC·시스템 인증 설정 변경 없음. M3 task014/015의 실제장비/잠금·절전 보류와 기존 승인은 유지한다. 이를 M4 검증으로 완료 처리하지 않는다.

- task-008 worker 결과를 인수하고 독립 verifier approved를 확정했다. signed 단위46/46·6suite·UI17/17·실패/skip0·7파일 SHA/patch 대응. 현재 마지막 앵커/Memory 보정·stale focus/등록/제거 거부·고정Cmd1~4·Return/Space·실제4조합frame/default280×668을 확인했다. loop 재시도0·근거 재검증0. 실제 key 설정창 최종UI는009에서 검증한다. 근거는 evidence/task-008, 다음009.

## 현재 작업 문서

- [M4 상태](./features/20261003-001-app-preferences/README.md)
- [SPEC](./features/20261003-001-app-preferences/spec.md), [DESIGN](./features/20261003-001-app-preferences/design.md), [구현 계획](./features/20261003-001-app-preferences/implement.md)
- [task-007 최신 근거](./features/20261003-001-app-preferences/evidence/task-007/resume-20261004/README.md)
- [ROADMAP](./ROADMAP.md), [제품 정의](./docs/product.md), [기술 설계](./docs/design.md)

## 확정된 결정

- 정책·책임·순서는 승인된 SPEC/DESIGN/Task가 소유한다. 첫 미완료 task-009를 건너뛰지 않는다.
- 기본 네 카드의 무스크롤/가독성·Memory 자연높이·Network 그래프 없음·Disk 미니 그래프·TOP5 여백/상세/AX를 유지한다. 작은 화면 새 정책은 추가하지 않는다.
- task-005는 기존 전체600초 이력/상세 모델을 유지하고 guarded 현재snapshot을 게시하며 view006/007이 선별한다. 접근 차이는 Task에 반영됐다.
- task-007의 전체 숨김 설정 버튼은 주입callback이며 실제 단일 설정창은 task-009가 연결한다. 조합별포커스/현재마지막앵커는 task-008이다.
- task-011은 안정 경로/동일 bundleID/서명의 실제 mainApp 등록·해제·다음로그인 관문이다. mock/status/수동실행으로 대체하지 않고 세션 영향은 당시 운영권한/별도승인 범위에서만 수행한다.
- 기존 Task012 stash0ef806c85321a92c7a07226de4b0080a7cc1eb48은 구치수라 전체 적용하지 않는다.

- 사용자 2026-10-04 macOS Disk 용량 기준 선택을 확정했다: Disk 저장 공간만1000 기반+회수 가능한 공간 포함(important-usage), 다른 지표 단위 유지. spec/design 원본과010 현재회귀 참조에 반영했다. Disk 제품 수정은 아직 없음. main은009 승인 뒤 별도 implement Per-Request로 수정·verify하고010에 근거를 연결한다. M3 직접002/008·의존006/011/013/018 승인 취소·과거근거 보존, 새 용량 근거로 개별 재검증 필요. 014/015 보류·그외승인은 유지한다. 자세한 현재정의는 M4 DESIGN §3.6.

## 미확정 판단

task-007 UI 환경 차단은 해소됐다. 사용자 Disk 기준 개정은 확정·문서 반영됐고 제품수정/관련재검증은 남았다. 실제 설정창/통합/다음로그인은 task-009~011이며 아직 완료 근거가 없다.

## 다음 작업

- 작업: task-009의 단일 설정창·Release 메뉴 접근·모든 native 컨트롤·키보드/AX와 key 설정창 보호를 worker에게 맡겨 구현·verify한다.
- 완료 기준: task-009의 단일창 재사용·명시적 열기·우클릭/⌘,/전체숨김 복구·설정/실제상태/오류/복원·키보드/AX와 포커스 보호를 현재 원본·단위/UI근거로 확인한다. 실제OS mutation은011에 남긴다. 모든 적용중 SPEC 매핑과 필수 실제 로그인 관문이 완료되기 전에는 IMPLEMENT를 완료 표시하지 않는다.

## 먼저 읽을 파일

- [구현 계획](./features/20261003-001-app-preferences/implement.md), [SPEC](./features/20261003-001-app-preferences/spec.md), [DESIGN](./features/20261003-001-app-preferences/design.md), [현재 상태](./features/20261003-001-app-preferences/README.md)
- [DashboardView.swift](./ResourceRunner/DashboardView.swift), [DashboardViewport.swift](./ResourceRunner/DashboardViewport.swift), [StatusBarController.swift](./ResourceRunner/StatusBarController.swift), [DashboardPresentationStore.swift](./ResourceRunner/DashboardPresentationStore.swift)
- [task-007 worker 결과](./features/20261003-001-app-preferences/evidence/task-007/resume-20261004/worker-result.md), [현재 소스 해시](./features/20261003-001-app-preferences/evidence/task-007/resume-20261004/source-sha256.txt)
- ~/.codex/skills/implement-loop/SKILL.md, ~/.codex/skills/implement/SKILL.md, ~/.codex/skills/verify/SKILL.md, ~/.codex/docs/phased-state.md

## 문서 반영 필요

없음. 상태·Task 승인·근거를 M4 문서/ROADMAP에 반영했다. 상위 기술 설계의 현재 구현 설명은 제품 통합 완료 후 해당 단계에서 갱신한다.
