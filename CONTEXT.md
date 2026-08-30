# Context

저장: 2026-08-30 16:39 +09:00

## 현재 목표

feature `20260818-001-resource-visualization`의 Task 13개를 구현해 CPU·Memory 카드와 상세 팝업의 표시를 개선합니다.
사용자가 「디자인이 마음에 안 든다」며 요청한 작업이고, SPEC~IMPLEMENT까지 이미 작성돼 있습니다.

## 현재 상태

resource-visualization은 **13개 중 11개 완료**입니다 — task-001~011이 `[x]`이고
`SPEC §5.1`·`§5.2`·`§5.4`·`§5.5`·`§5.6`·`§5.7`·`§5.8`이 닫혔습니다.
막힌 자리 없이 다음 Task(task-012)를 바로 시작할 수 있습니다.
남은 둘 중 task-013은 자동 부분만 끝났고 사람 관찰(Activity Monitor 10분 비교)이 남았습니다.

core-resource-monitoring은 16개 중 10개 완료이고, 남은 006·007·012·013·014·015는 전부 실기기 조작·관찰이 필요합니다.

마지막 검증은 격리 DerivedData로 실행한 `ResourceRunnerTests` **실패 0**(`** TEST SUCCEEDED **`)입니다.
**UI 스위트는 실행할 수 없습니다** — 기기에서 XCUITest 초기화가
`LocalAuthentication Code=-4 "System authentication is running."`으로 막히며, 이 인증 창이 풀려야 해소됩니다.
branch `main`, HEAD `1512125`, `origin/main`과 같습니다.
task-011 구현분(코드 3개 파일)과 그 후처리(문서 2개 파일)가 uncommitted로 남아 있습니다.

## 현재 작업 문서

- [features/20260818-001-resource-visualization/implement.md](./features/20260818-001-resource-visualization/implement.md)
  — 다음 항목은 `task-012`(새 표시 요소의 접근성 도달)입니다.

## 확정된 결정

- **카드에 두는 구성 수치는 「구성 합계」 하나이고 Pressure·Swap 병합 줄 맨 뒤에 놓습니다.**
  항목별 네 수치는 폭 실측(232pt에 345pt 필요)으로 카드에 들어가지 않아 상세 범례(task-008)와 접근성 이름(task-012)이 맡습니다.
  [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md)
  2026-08-22 첫 항목에 실측표와 함께 있습니다.
- **`SPEC §5.3` 재판정의 방향은 「성립」이고, 판정 자체는 task-012 approve 시점에 확정합니다.**
  확정 조건은 task-012가 실제로 카드 접근성 이름에 항목별 네 수치를 넣는 것이며, 빠지면 이 방향은 성립하지 않습니다.
  같은 README 2026-08-29 항목과 implement.md task-012 `확인` 필드에 있습니다.
- **`ANALYSIS §5 DP4` 재작성은 task-012 approve 뒤에 `/analyze-init`으로 합니다.**
  순서를 「§5.3 판정 → DP4 재작성」으로 고정했습니다. 어긋난 자리 셋과 참조 행 번호가 같은 README 항목에 있습니다.
- **UI 테스트 중복 정리는 기기 인증 창이 풀리고 task-012가 UI 스위트를 요구하는 시점에 함께 합니다.**
  착수 시 병합형 후보 여섯은 목록이 없어 재감사가 필요합니다.
  [features/20260812-001-core-resource-monitoring/README.md](./features/20260812-001-core-resource-monitoring/README.md)
  2026-08-29 UI 감사 항목에 있습니다.
- **테스트 통과 건수는 baseline으로 쓰지 않습니다.** 기준은 「실패 0 + `** TEST SUCCEEDED **`」이고,
  건수는 필요할 때 `Test case … passed` 줄 수를 보조로만 덧붙입니다. 같은 README 2026-08-29 마지막 항목에 있습니다.
- 카드와 상세는 같은 구간 계산(`MemoryCompositionLayout.make`)을 공유하고 「사용 중」은 그 입력이 아닙니다.
  [features/20260818-001-resource-visualization/analyze.md](./features/20260818-001-resource-visualization/analyze.md)
  §5 DP5·DP6과 rv README 2026-08-29 task-008 항목에 있습니다.
- **값 없음 자리표시의 회귀 그물은 「요소 전수 목록 + 상태 × 요소 순회」로 세웁니다.**
  목록을 production 조립 배열에서 파생시키고, 색 있는 요소는 픽셀·텍스트는 줄 이상적 폭 등식·순위 자리는 **줄별** 폭 등식으로 재며,
  폭 등식에는 감도 자기점검을 붙입니다. task-011이 다섯 번 reject된 끝에 이 방식으로 닫혔습니다.
  rv README 2026-08-30 항목에 원인 진단과 함께 있습니다.
- 색 팔레트를 확정했습니다. CPU User `#2a78d6`/`#3987e5`, System `#eb6834`/`#d95926`,
  Memory App·Wired·Compressed·Cached는 앞의 둘에 `#1baf7a`/`#199e70`·`#eda100`/`#c98500`를 더한 순서입니다(라이트/다크).
  [ResourceRunner/DashboardColorPalette.swift](./ResourceRunner/DashboardColorPalette.swift)에 있고 근거는 rv README task-004 항목에 있습니다.
- 테스트 실행 정책은 「단위 전체 + 변경에 걸리는 UI만, UI 스위트 전체는 Task나 `SPEC §5.N`이 닫힐 때만」입니다.
  core README 2026-08-21 항목에 있습니다.
- core-resource-monitoring `SPEC §5.2`의 「상세 상위 5개가 같은 시점 카드 순위와 일치」는 정상 갱신 상태 기준입니다.
  같은 README task-003 항목에 있습니다.

## 미확정 판단

없음.

## 다음 작업

- 작업: `task-012`(새 표시 요소의 접근성 도달)를 구현합니다.
  `cpuAccessibilityLabel`에 두 계열 수치와 기준선 값을, `memoryAccessibilityLabel`에 구성 네 항목의 수치와 구성 합계를 더하고
  「사용 중」과 라벨을 갈라 씁니다. 상세 도넛에도 자체 접근성 이름을 줍니다.
- 완료 기준: implement.md task-012의 검증 조건이 요구하는 mutation이 모두 잡히고,
  단위 스위트가 실패 0으로 끝난 뒤 verify가 `approved`를 돌려주어 체크박스가 `[x]`로 넘어갑니다.
  approve 시점에 `SPEC §5.3` 재판정(위 확정된 결정)과 task-011에서 이월된 UI 실행 확인 셋을 함께 처리합니다.

## 먼저 읽을 파일

- [features/20260818-001-resource-visualization/implement.md](./features/20260818-001-resource-visualization/implement.md) (변경함)
  — task-012의 목적·접근·검증 조건. `확인` 필드에 `SPEC §5.3` 재판정과 이월된 UI 실행 확인 셋이 함께 있습니다.
- [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md) (변경함)
  — 2026-08-30 항목에 task-011 결과와 남은 한계 다섯
- [features/20260818-001-resource-visualization/spec.md](./features/20260818-001-resource-visualization/spec.md) — `§5.10`(접근성)과 `§5.3`
- [features/20260818-001-resource-visualization/analyze.md](./features/20260818-001-resource-visualization/analyze.md)
  — `§1 「접근성 노출 자리」`, `§3 「접근성 이름」`, `§5 DP13`
- [ResourceRunner/DashboardPresentation.swift](./ResourceRunner/DashboardPresentation.swift)
  — `cpuAccessibilityLabel`·`memoryAccessibilityLabel`이 있는 자리(이름 조립은 순수 함수)
- [ResourceRunner/DashboardView.swift](./ResourceRunner/DashboardView.swift) (변경함)
  — task-011이 완화한 접근 수준 여섯과 `CPUSeriesPlaceholderLayout.spacing`
- [ResourceRunnerTests/DashboardCardLayoutTests.swift](./ResourceRunnerTests/DashboardCardLayoutTests.swift) (변경함)
  — 요소 전수 순회 테스트와 폭 등식·감도 자기점검
- [ResourceRunner/ApplicationRowIcon.swift](./ResourceRunner/ApplicationRowIcon.swift) (변경함) — 주석을 사실에 맞게 고친 자리
- [features/20260812-001-core-resource-monitoring/README.md](./features/20260812-001-core-resource-monitoring/README.md)
  — 테스트 실행 정책, UI 중복 감사와 정리 시점, 통과 건수 기준

## 문서 반영 필요

없음.
