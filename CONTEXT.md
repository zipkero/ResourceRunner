# Context

저장: 2026-08-29 11:53 +09:00

## 현재 목표

feature `20260818-001-resource-visualization`의 Task 13개를 구현해 CPU·Memory 카드와 상세 팝업의 표시를 개선합니다.
사용자가 「디자인이 마음에 안 든다」며 요청한 작업이고, SPEC~IMPLEMENT까지 이미 작성돼 있습니다.

## 현재 상태

resource-visualization은 **13개 중 10개 완료**입니다 — task-001~010이 `[x]`이고
`SPEC §5.1`·`§5.2`·`§5.4`·`§5.5`·`§5.6`·`§5.7`이 닫혔습니다.
막힌 자리 없이 다음 Task(task-011)를 바로 시작할 수 있습니다 —
011·012의 전제였던 「새 표시 요소가 모두 있는 상태」가 task-008로 갖춰졌습니다.
남은 셋 중 task-013은 자동 부분만 끝났고 사람 관찰(Activity Monitor 10분 비교)이 남았습니다.

core-resource-monitoring은 16개 중 10개 완료이고, 남은 006·007·012·013·014·015는 전부 실기기 조작·관찰이 필요합니다.

마지막 검증은 격리 DerivedData로 실행한 `ResourceRunnerTests` **실패 0**(`TEST SUCCEEDED`)입니다.
통과 건수는 세는 방식에 따라 갈립니다 — `Test case … passed` 줄 수 388, 서로 다른 테스트 이름 351개입니다.
**UI 스위트는 실행할 수 없습니다** — 기기에서 XCUITest 초기화가
`LocalAuthentication Code=-4 "System authentication is running."`으로 막히며, 이 인증 창이 풀려야 해소됩니다.
branch `main`이고, 이번 세션 변경은 이 파일과 함께 하나의 커밋으로 `origin/main`에 push했습니다(직전 HEAD `8c2b0ab`).

## 현재 작업 문서

- [features/20260818-001-resource-visualization/implement.md](./features/20260818-001-resource-visualization/implement.md)
  — 다음 항목은 `task-011`(새 표시 요소가 모두 있는 상태에서의 크기 불변)입니다.

## 확정된 결정

- **카드에 두는 구성 수치는 「구성 합계」 하나이고 Pressure·Swap 병합 줄 맨 뒤에 놓습니다.**
  항목별 네 수치는 폭 실측(232pt에 345pt 필요)으로 카드에 들어가지 않아 상세 범례(task-008)와 접근성 이름(task-012)이 맡습니다.
  `ANALYSIS §5 DP4`의 채택안을 대체하는 사용자 결정입니다.
  [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md)
  2026-08-22 첫 항목에 실측표와 함께 있습니다.
- 카드와 상세는 같은 구간 계산(`MemoryCompositionLayout.make`)을 공유하고 「사용 중」은 그 입력이 아닙니다.
  task-008의 도넛도 새 분모를 두지 않고 카드 결과를 각도로만 옮깁니다.
  [features/20260818-001-resource-visualization/analyze.md](./features/20260818-001-resource-visualization/analyze.md)
  §5 DP5·DP6과 같은 README 2026-08-29 항목에 있습니다.
- 색 팔레트를 확정했습니다. CPU User `#2a78d6`/`#3987e5`, System `#eb6834`/`#d95926`,
  Memory App·Wired·Compressed·Cached는 앞의 둘에 `#1baf7a`/`#199e70`·`#eda100`/`#c98500`를 더한 순서입니다(라이트/다크).
  [ResourceRunner/DashboardColorPalette.swift](./ResourceRunner/DashboardColorPalette.swift)에 있고
  근거는 같은 README task-004 항목에 있습니다.
- 테스트 실행 정책은 「단위 전체 + 변경에 걸리는 UI만, UI 스위트 전체는 Task나 `SPEC §5.N`이 닫힐 때만」입니다.
  [features/20260812-001-core-resource-monitoring/README.md](./features/20260812-001-core-resource-monitoring/README.md)
  2026-08-21 항목에 있습니다.
- core-resource-monitoring `SPEC §5.2`의 「상세 상위 5개가 같은 시점 카드 순위와 일치」는 정상 갱신 상태 기준입니다.
  같은 feature README task-003 항목에 있습니다.

## 미확정 판단

- **`SPEC §5.3`의 「각 구간이 … 수치를 확인할 수 있습니다」가 카드에서 아직 미충족입니다.**
  항목별 수치를 상세와 접근성 이름에 넘겼으므로, §5.3이 실제로 닫히는 시점(task-012 approve)에
  「접근성 이름만으로 카드의 수치 확인이 성립하는가」를 다시 판정해야 합니다.
  `docs/product.md` 125행의 「중요한 분석 정보는 Hover에만 의존하지 않습니다」와 나란히 볼 자리입니다.
  implement.md task-012 `확인` 필드에 있습니다.
- analyze.md 재작성 여부. `ANALYSIS §5 DP4`의 채택안이 실제 구현과 다른 채로 남아 있습니다.
  대체 사실은 feature README 2026-08-22 첫 항목과 implement.md task-007 참조 필드에 있고,
  analyze.md는 부분 수정하지 않는 문서라 `/analyze-init` 재작성이 필요합니다.
  [features/20260818-001-resource-visualization/analyze.md](./features/20260818-001-resource-visualization/analyze.md) §5 DP4입니다.
- UI 테스트 중복 정리 실행 여부. 약 80초(200초 → 120초)를 단언 손실 없이 줄일 수 있다는 감사 결과가
  core-resource-monitoring README 2026-08-29 항목에 있습니다. 지금은 UI 스위트를 돌릴 수 없어 정리 전후 대조가 불가능합니다.
- 단위 테스트 통과 건수를 세는 방식을 하나로 고정할지. 지금 세 값(388 / 351 / 앞선 기록 346)이 섞여 있어
  「N개 통과」를 baseline으로 쓰기 어렵습니다. 실패 건수는 어느 방식으로도 0입니다.
  resource-visualization README 2026-08-29 항목에 있습니다.

## 다음 작업

- 작업: `task-011`(새 표시 요소가 모두 있는 상태에서의 크기 불변)을 구현합니다.
  `DashboardCardLayoutTests`에 네 상태 × 새 요소 조합의 렌더 높이 단언을 더하고,
  자리표시 규칙이 각 상태에서 실제로 적용되는지 확인해 빠진 자리를 채웁니다.
- 완료 기준: implement.md task-011의 검증 조건이 요구하는 mutation이 모두 잡히고,
  두 카드 렌더 높이가 네 상태에서 같으며 변경 전 기준값(CPU 243.0 / Memory 181.0)과도 같고,
  단위 스위트가 전부 통과한 뒤 verify가 `approved`를 돌려주어 체크박스가 `[x]`로 넘어갑니다.

## 먼저 읽을 파일

- [features/20260818-001-resource-visualization/implement.md](./features/20260818-001-resource-visualization/implement.md) (변경함)
  — task-011의 목적·접근·검증 조건. task-010의 행 식별자·탭 동작 실행 확인도 이 Task에 붙어 있습니다.
- [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md) (변경함)
  — 2026-08-29 항목에 task-008 결과와 `MemoryDetailView` 뷰 본문 그물 0 한계
- [features/20260818-001-resource-visualization/spec.md](./features/20260818-001-resource-visualization/spec.md) — `§5.8`(크기 불변)과 `§5.3`
- [features/20260818-001-resource-visualization/analyze.md](./features/20260818-001-resource-visualization/analyze.md)
  — `§2 「상태 전이에서의 새 요소」`, `§5 DP14`·`DP15`
- [ResourceRunnerTests/DashboardCardLayoutTests.swift](./ResourceRunnerTests/DashboardCardLayoutTests.swift)
  — 확장 대상이고 `renderedPixels`로 그림 요소를 견주는 수단이 여기 있습니다
- [ResourceRunner/DashboardView.swift](./ResourceRunner/DashboardView.swift) (변경함)
  — 자리표시 규칙이 적용될 카드·상세 뷰
- [ResourceRunner/DashboardPresentation.swift](./ResourceRunner/DashboardPresentation.swift) (변경함)
  — task-008이 더한 `MemoryCompositionDonutLayout`·`MemoryCompositionDetailLegendFormatting`·`MemoryCompositionDetailSummary`
- [ResourceRunnerTests/MemoryCompositionDetailTests.swift](./ResourceRunnerTests/MemoryCompositionDetailTests.swift) (새로 만듦)
  — task-008의 도넛·범례·요약 단언 6건
- [features/20260812-001-core-resource-monitoring/README.md](./features/20260812-001-core-resource-monitoring/README.md) (변경함)
  — 테스트 실행 정책과 2026-08-29 UI 중복 감사 결과

## 문서 반영 필요

없음.
