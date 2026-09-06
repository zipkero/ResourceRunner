# Context

저장: 2026-09-06 12:14 +09:00

## 현재 목표

대시보드 그래프를 눈으로 따라갈 수 있게 키우고(판 60 → 100pt, 영역 경계와 시간 축 추가), 리소스당 고유 색조로 색감을 되돌린다.
사용자가 완성된 화면을 직접 보고 지적한 다섯 건(그래프 가독성, 색감 없음, 코어 격자 무채색, 상세 하위 행 간격 과다, TOP 5 안내 문구)이 범위다.

## 현재 상태

`20260906-001-graph-legibility-and-color`의 SPEC·DESIGN이 닫히고 IMPLEMENT 체크리스트(Task 8개)까지 작성됐다.
Task는 하나도 시작하지 않았다.

앞 feature `20260903-001-dashboard-visual-refinement`는 task-001~007이 verify 승인까지 끝났고 task-008(동작 줄이기·자체 부하 확인)만 남아 있다.
그 task-008은 이번 feature가 색·크기 결정을 되열었으므로 이번 feature가 끝난 뒤에 하는 것이 맞다.

마지막 검증: 앞 feature task-007 재판정에서 단위 `ResourceRunnerTests` 434개와 UI 스위트 넷 15개가 실패 0으로 통과했다.
이번 feature의 코드 변경은 아직 없다.

branch `main`, 기준 HEAD `cccca76`. 앞 feature의 코드·문서 변경이 전부 미커밋 상태로 작업 트리에 남아 있다.

## 현재 작업 문서

- [features/20260906-001-graph-legibility-and-color/implement.md](./features/20260906-001-graph-legibility-and-color/implement.md) — 현재 항목은 `task-001: 그래프 판을 키우고 영역 경계와 시간 축을 둔다`
- [features/20260903-001-dashboard-visual-refinement/implement.md](./features/20260903-001-dashboard-visual-refinement/implement.md) — `task-008`만 미완, 이번 feature 이후로 미룸

## 확정된 결정

- 그래프 판을 60 → 100pt로 키우고 시간 축·눈금을 둔다. 카드와 팝오버가 커지는 것을 허용한다 — [spec.md §5.1](./features/20260906-001-graph-legibility-and-color/spec.md), [design.md DP2](./features/20260906-001-graph-legibility-and-color/design.md)
- 색은 리소스당 고유 색조 한 개 × 네 단계로 되돌린다. CPU 파랑 h278 · Memory 주황 h55, Network 청록 h165 · Disk 자주 h320은 M3 예약 — [design.md DP6](./features/20260906-001-graph-legibility-and-color/design.md)
- 코어 막대는 사용률에 따라 유한한 네 단계 색을 쓰고 경계는 25/50/75%를 그래프 기준선 배열에서 유도한다. 매 tick 색 보간은 금지 — [spec.md §3](./features/20260906-001-graph-legibility-and-color/spec.md), [design.md DP8](./features/20260906-001-graph-legibility-and-color/design.md)
- 색 검증 기준을 배경 대비 3:1과 「색만으로 구분하지 않는다」 원칙으로 줄이고, Machado 색맹 시뮬레이션과 인접쌍 ΔE ≥ 8은 제약에서 뺀다. 공개 배포를 확정하면 M5 접근성 관문에서 한 번 수행한다 — [spec.md §3](./features/20260906-001-graph-legibility-and-color/spec.md)
- 카드가 넷이 되는 M3에서 본체 배치 구조를 바꾼다(세로 스크롤·아코디언·2열 배치 중 하나). 카드마다 그래프 높이를 달리해 높이를 맞추는 방식은 「네 카드의 구조가 일관됩니다」와 충돌하므로 쓰지 않는다 — [ROADMAP.md M3](./ROADMAP.md), [docs/design.md 「대시보드 본체의 세로 예산」](./docs/design.md), [design.md DP1](./features/20260906-001-graph-legibility-and-color/design.md)
- 테스트는 Task마다 전체 스킴을 돌리지 않고 단위 전체 + 그 Task가 건드리는 UI 스위트만 돌린다. 전체 스킴은 feature 마지막 Task에서 한 번 — [implement.md 각 Task 확인 항목](./features/20260906-001-graph-legibility-and-color/implement.md)

## 미확정 판단

없음

## 다음 작업

- 작업: `20260906-001-graph-legibility-and-color`의 `task-001`(그래프 판을 키우고 영역 경계와 시간 축을 둔다)을 구현하고 verify를 받는다.
- 완료 기준: implement.md task-001의 `검증 조건`이 성립하고 독립 verify가 approved를 내며, main이 그 Task 체크박스를 `[x]`로 넘긴 상태.

## 먼저 읽을 파일

- [features/20260906-001-graph-legibility-and-color/spec.md](./features/20260906-001-graph-legibility-and-color/spec.md)
- [features/20260906-001-graph-legibility-and-color/design.md](./features/20260906-001-graph-legibility-and-color/design.md)
- [features/20260906-001-graph-legibility-and-color/implement.md](./features/20260906-001-graph-legibility-and-color/implement.md)
- [docs/design.md](./docs/design.md) — 변경한 파일(「대시보드 본체의 세로 예산」 절 신설)
- [ROADMAP.md](./ROADMAP.md) — 변경한 파일(M3 완성 결과·전환 기준에 배치 구조 항목 추가)
- 앞 feature가 남긴 미커밋 코드 변경(전부 변경한 파일):
  `ResourceRunner/DashboardStyle.swift`(신규), `ResourceRunner/DashboardView.swift`,
  `ResourceRunner/DashboardPresentation.swift`, `ResourceRunner/DashboardColorPalette.swift`,
  `ResourceRunner/ApplicationRanking.swift`,
  `ResourceRunnerTests/DashboardValueColumnTests.swift`(신규), `ResourceRunnerTests/DashboardCardLayoutTests.swift`,
  `ResourceRunnerTests/DashboardPresentationTests.swift`, `ResourceRunnerTests/DetailPopoverValuelessStateTests.swift`,
  `ResourceRunnerTests/ApplicationProcessRowLayoutTests.swift`, `ResourceRunnerTests/ApplicationRankingTests.swift`,
  `ResourceRunnerTests/ApplicationRowIconTests.swift`, `ResourceRunnerTests/CPUCoreGridVerticalBudgetTests.swift`,
  `ResourceRunnerTests/CPUCoreUsageGridTests.swift`, `ResourceRunnerTests/MemoryCompositionDetailTests.swift`,
  `ResourceRunnerUITests/ResourceRunnerUITests.swift`, `ResourceRunnerUITests/DashboardCardSelectionUITests.swift`,
  `ResourceRunnerUITests/DashboardDetailPopoverUITests.swift`

## 문서 반영 필요

- `docs/product.md` 「대시보드 > 공통 정보 구조」의 「대시보드 상단에는 전체 시스템 상태와 그래프 시간 범위를 표시합니다」가 현재 구현과 어긋난다.
  앞 feature `20260903-001-dashboard-visual-refinement`가 최상단 제목 줄을 없앴고 그 spec §1이 이 갱신을 예고했으나 아직 반영되지 않았다.
- `docs/product.md` 「CPU > 기본 카드」와 「Memory > 기본 카드」에 이번 feature가 더하는 표시(그래프 시간 축·눈금, 미수집 구간 표시, 코어 막대의 사용률 단계 색)가 아직 없다.
