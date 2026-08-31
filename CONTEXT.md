# Context

저장: 2026-08-31 20:19 +09:00

## 현재 목표

feature `20260831-001-detail-popover-readability`의 Task 7개를 구현해
CPU·Memory 상세 팝업에서 값을 읽어내기 어려운 두 자리를 고칩니다 —
펼친 하위 프로세스 행의 간격·들여쓰기와 CPU 상세의 논리 코어별 사용률 표현입니다.
사용자가 실행 중인 앱을 보고 지적한 사안이고, SPEC~IMPLEMENT까지 이미 작성돼 있습니다.

## 현재 상태

`20260831-001-detail-popover-readability`는 **SPEC·DESIGN이 `[x]`이고 IMPLEMENT는 시작 전**입니다 —
Task 7개가 전부 `[ ]`이고 `task-001`부터 시작하면 됩니다.
막힌 자리는 없습니다.

`20260818-001-resource-visualization`은 **IMPLEMENT 완료**입니다 — Task 13개 전부 `[x]`, `SPEC §5.1`~`§5.10` 전부 닫힘.
`20260812-001-core-resource-monitoring`은 16개 중 10개 완료이고, 남은 006·007·012·013·014·015는 전부 실기기 조작·관찰이 필요합니다.

마지막 검증은 `ResourceRunnerTests` **401 passed / 0 failed**(`** TEST SUCCEEDED **`)와
UI 스위트 다섯 **17건 전부 통과**입니다.
**앞 세션을 막던 기기 인증 문제는 해소됐습니다** — macOS 자동화 권한이 승인되어 XCUITest가 실행됩니다.
다만 이 승인이 풀리면 `task-006`이 닫히지 않습니다(UI 스위트 셋 실행이 유일한 판정 수단).

branch `main`, HEAD `4d1c5cf`, `origin/main`과 같습니다.

## 현재 작업 문서

- [features/20260831-001-detail-popover-readability/implement.md](./features/20260831-001-detail-popover-readability/implement.md)
  — 다음 항목은 `task-001`(코어 수를 따라가는 격자 행·열 분할)입니다.

## 확정된 결정

- **코어 표현은 격자입니다.** 코어 전체가 스크롤 없이 한 화면에 들어오는 배치를 씁니다.
  세로 목록을 접은 근거는 이 기기가 논리 코어 14개(Apple M3 Max)라는 실측입니다.
  [features/20260831-001-detail-popover-readability/spec.md](./features/20260831-001-detail-popover-readability/spec.md) §3과 §5.4에 있습니다.
- **열 수는 코어 수에서 두 단계로 유도합니다** — `행 수 = ⌈n ÷ 8⌉` → `열 수 = ⌈n ÷ 행 수⌉`.
  가용 폭은 인자로 받지 않고, 폭에서 온 값은 열 상한 8 하나뿐입니다.
  열 상한 8의 근거는 `"100%"` 28.0pt에 8열 칸 폭 40.8pt라는 실측이고 10열은 31.4pt로 배제했습니다.
  [features/20260831-001-detail-popover-readability/design.md](./features/20260831-001-detail-popover-readability/design.md) §5 DP1에 있습니다.
- **코어 칸은 고정 트랙(18pt) 세로 막대 + 수치 + 코어 번호 세 줄(48pt)이고, 수치를 화면에도 둡니다.**
  앞 feature가 카드 폭 232pt에 345pt가 필요해 수치를 뺐던 것과 반대로 여기선 자리가 남습니다.
  코어 번호를 화면에 두는 것은 2026-08-31 사용자 결정입니다. 같은 design.md §5 DP2·DP3에 있습니다.
- **하위 행 들여쓰기는 34pt(부모 앱 이름 시작선), 세 경계 간격은 4 / 10 / 16pt입니다.**
  34pt는 2026-08-31 사용자 결정이고, 46pt 안은 가장 긴 하위 행이 363pt로 목록 폭 360pt를 넘겨 접었습니다.
  현재 실측은 들여쓰기 0pt·간격 `0 / 2 / 2pt`입니다 — macOS `DisclosureGroup`이 펼친 내용에 들여쓰기를 0pt 줍니다.
  같은 design.md §5 DP5·DP6에 있습니다.
- **하위 행 구분은 들여쓰기와 간격만 씁니다.** 구분선·배경·테두리는 제외 범위입니다(2026-08-31 사용자 결정).
  같은 spec.md §4에 있습니다.
- **`DisclosureGroup`을 유지하고, 하위 행 접근성 요소를 합치지 않습니다.**
  자체 조립이나 합침은 `DashboardDetailExpansionUITests`·`DashboardProcessListDisplayUITests`가 매여 있는
  `AXDisclosureTriangle` 요소·`triangle.value` 0/1 판정과 `value CONTAINS "PID"` 조회를 깨뜨립니다.
  같은 design.md §5 DP7·DP10에 있습니다.
- **값 없음 상태에 자리표시를 새로 만들지 않습니다.** 새 표시 요소 8종이 전부 `.normal` 분기 안쪽에만 있고
  팝업 크기는 상태 분기 밖 `.frame`이 고정합니다. 이 판단의 검증은 `task-007`이 성립 조건 셋으로 확인합니다.
  같은 design.md §5 DP9에 있습니다.
- **상세 팝업은 400×480 고정입니다.** 넘치면 팝업을 키우지 않고 기존 세로 스크롤로 해결하며 가로 스크롤은 쓰지 않습니다.
  같은 spec.md §3·§4에 있습니다.
- **테스트 통과 건수는 baseline으로 쓰지 않습니다.** 기준은 「실패 0 + `** TEST SUCCEEDED **`」입니다.
  [features/20260812-001-core-resource-monitoring/README.md](./features/20260812-001-core-resource-monitoring/README.md) 2026-08-29 마지막 항목에 있습니다.
- **테스트 실행 정책**은 「단위 전체 + 변경에 걸리는 UI만, UI 스위트 전체는 Task나 `SPEC §5.N`이 닫힐 때만」입니다.
  같은 README 2026-08-21 항목에 있습니다.
- **UI 테스트 중복 정리가 착수 가능해졌습니다.** 기기 인증이 풀리는 것이 조건이었고 해소됐습니다.
  병합형 후보 여섯은 목록이 없어 재감사가 필요합니다. 같은 README 2026-08-29 UI 감사 항목에 있습니다.
- **`ANALYSIS §5 DP4` 재작성은 아직 하지 않았습니다.** 「`§5.3` 판정 → DP4 재작성」 순서 중 앞 절반만 끝났습니다.
  [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md) 2026-08-29 항목에 어긋난 자리 셋과 참조 행 번호가 있습니다.
- **도구 선택에서 Codex 사용 한도는 판단 기준으로 쓰지 않습니다.** 사용자가 한도는 직접 관리한다고 밝혔습니다.

## 미확정 판단

없음.

## 다음 작업

- 작업: `task-001`(코어 수를 따라가는 격자 행·열 분할)을 구현합니다.
  코어 수 하나만 받아 행별 코어 인덱스 묶음을 돌려주는 순수 타입을 만들고, 가용 폭은 인자로 받지 않습니다.
- 완료 기준: 코어 8·10·14·16·24·64에서 행×열이 각각 1×8 · 2×5 · 2×7 · 2×8 · 3×8 · 8×8이 되고,
  implement.md task-001이 요구한 mutation 다섯이 모두 잡히며,
  단위 스위트가 실패 0으로 끝난 뒤 verify가 `approved`를 돌려주어 체크박스가 `[x]`로 넘어갑니다.

## 먼저 읽을 파일

- [features/20260831-001-detail-popover-readability/implement.md](./features/20260831-001-detail-popover-readability/implement.md)
  — task-001의 목적·접근·검증 조건과 mutation 다섯
- [features/20260831-001-detail-popover-readability/design.md](./features/20260831-001-detail-popover-readability/design.md)
  — `§1` 구조, `§3` 인터페이스, `§5 DP1`·`DP4`. `§근거`의 「실측한 값」·「격자 후보의 실측」과 「추정으로 남는 것」
- [features/20260831-001-detail-popover-readability/spec.md](./features/20260831-001-detail-popover-readability/spec.md) — `§5.3`·`§5.4`와 `§3` 제약
- [ResourceRunner/DashboardView.swift](./ResourceRunner/DashboardView.swift)
  — `CPUDetailView`(코어별 사용률 `Text`), `ApplicationProcessGroupRow`(`DisclosureGroup`), `ApplicationProcessGroupListView`(`spacing: 2`)
- [ResourceRunner/DashboardPresentation.swift](./ResourceRunner/DashboardPresentation.swift) — `MemoryCompositionLayout` 계열이 있는 자리(순수 계산 관례)
- [ResourceRunnerTests/DashboardCardLayoutTests.swift](./ResourceRunnerTests/DashboardCardLayoutTests.swift) — 렌더 실측·폭 등식·감도 자기점검 관례
- [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md)
  — 2026-08-30 항목의 값 없음 회귀 그물 해법(요소 전수 목록 + 상태 × 요소 순회)과 항진명제 전례

## 문서 반영 필요

없음.
