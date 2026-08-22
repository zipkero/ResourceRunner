# Context

저장: 2026-08-21 15:38

## 현재 목표

feature `20260818-001-resource-visualization`의 Task 13개를 구현해 CPU·Memory 카드와 상세 팝업의 표시를 개선합니다.
사용자가 「디자인이 마음에 안 든다」며 요청한 작업이고, 이 feature가 그 목적으로 이미 SPEC~IMPLEMENT까지 작성돼 있습니다.

## 현재 상태

resource-visualization은 **13개 중 8개 완료**입니다 — task-001~006·009·010이 `[x]`이고
`SPEC §5.1`·`§5.2`·`§5.5`·`§5.6`·`§5.7`이 닫혔습니다.
task-007이 사용자 결정 대기로 **보류**됐고, 그 결정에 008·011·012가 걸려 있습니다.
task-013은 자동 부분만 끝냈고 사람 관찰이 남아 `[ ]`입니다.

core-resource-monitoring은 16개 중 10개 완료입니다. 남은 006·007·012·013·014·015는 전부 실기기 조작·관찰이 필요합니다.
task-014는 verify가 「나머지가 닫힌 뒤에 잡아야 한다」고 판정해 마지막입니다.

작업 트리에 커밋되지 않은 변경이 **수정 17개 + untracked 6개**입니다.
untracked는 git으로 복구할 수 없습니다 —
`ApplicationIconCache.swift`, `ApplicationRowIcon.swift`, `DashboardColorPalette.swift`,
`ApplicationIconCacheTests.swift`, `ApplicationRowIconTests.swift`, `MemoryCompositionTests.swift`.

마지막 검증은 격리 DerivedData로 실행한 `ResourceRunnerTests` **340개 전부 통과**(실패 0)와 `BUILD SUCCEEDED`입니다.
**UI 스위트는 실행할 수 없습니다** — 기기에서 XCUITest 초기화가
`LocalAuthentication Code=-4 "System authentication is running."`으로 막힙니다(`coreauthd`·`coreautha` 상주, 4회 확인).

## 현재 작업 문서

- [features/20260818-001-resource-visualization/implement.md](./features/20260818-001-resource-visualization/implement.md)
  — 활성 Task는 `task-007`(Memory 카드의 구성 누적 바와 범례)이고 **설계 결정 대기로 멈춰 있습니다.**

## 확정된 결정

- 색 팔레트를 확정했습니다. CPU User `#2a78d6`/`#3987e5`, System `#eb6834`/`#d95926`,
  Memory App·Wired·Compressed·Cached는 앞의 둘에 `#1baf7a`/`#199e70`·`#eda100`/`#c98500`를 더한 순서입니다(라이트/다크).
  dataviz 검증기로 색맹 시뮬레이션·명도대비 전 항목 통과를 확인했고, 다크는 자동 반전이 아니라 별도 값입니다.
  [ResourceRunner/DashboardColorPalette.swift](./ResourceRunner/DashboardColorPalette.swift)에 있고
  근거는 [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md)
  task-004 항목에 있습니다.
- 테스트 실행 정책은 「단위 전체 + 변경에 걸리는 UI만, UI 스위트 전체는 Task나 `SPEC §5.N`이 닫힐 때만」입니다.
  전체 338개 중 UI 22개가 시간의 98%를 씁니다.
  [features/20260812-001-core-resource-monitoring/README.md](./features/20260812-001-core-resource-monitoring/README.md)
  2026-08-21 항목에 있습니다.
- `MemorySystemMetricsCollector.readPressureLevel()`의 그물 공백은 열어 두고 기록만 합니다.
  닫으려면 production에 테스트 전용 seam이 필요한데 앞뒤 링크가 이미 덮여 있어 얻는 것이 작습니다.
  같은 README에 있습니다.
- `ANALYSIS §5 DP12`(아이콘을 얻지 못한 행의 중립 기호)를 살리려고
  `ApplicationIconCache.loadSystemIcon(for:)`에 `FileManager.fileExists` 확인을 넣었습니다.
  `NSWorkspace.icon(forFile:)`가 없는 경로에도 일반 문서 아이콘을 줘 「아이콘 없음」이 있는 것처럼 보이던 것을 막습니다.
  `DP11`은 바뀌지 않습니다.
  [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md)
  task-010 항목에 있습니다.
- core-resource-monitoring `SPEC §5.2`의 「상세 상위 5개가 같은 시점 카드 순위와 일치」는 **정상 갱신 상태 기준**입니다.
  펼친 행이 있는 동안 상세 순서가 고정돼 카드와 갈리는 것은 모순이 아니라 예외로 봅니다.
  [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md)
  task-003 항목에 있습니다.

## 미확정 판단

- **task-007 — 카드에 구성 수치를 둘 자리가 있는가.** 이 feature의 진행을 막고 있는 유일한 쟁점입니다.
  실측상 스와치+이름+수치 네 쌍은 347~375pt가 필요한데 카드 콘텐츠 폭은 232pt이고,
  이름까지만이면 219pt로 들어갑니다. 제목 줄에 약 96pt가 남아 짧은 합계 하나를 놓을 여지는 있습니다.
  `SPEC §5.3`의 셋째 문장이 카드에 구성 합계를 요구하고 `ANALYSIS §5 DP4`가 「수치를 카드에 두지 않음」을
  사용자 확인 아래 이미 접었으므로, 어느 쪽이든 analyze.md 재작성이 필요합니다.
  선택지 두 가지와 실측값이
  [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md)
  task-007 항목에 있습니다.
- 커밋 여부. 오늘 작업 전체가 커밋 없이 쌓여 있고 untracked 6개는 git으로 복구할 수 없습니다.
- UI 테스트 중복 정리 여부. 감사 결과 약 80초(200초 → 120초)를 단언 손실 없이 줄일 수 있습니다.
  완전 중복 3건(15.5초)은 판단 보류와 무관해 바로 처리 가능하고, 병합형은 production 확인이 필요한 보류 3건이 걸립니다.
  감사 결과는 이 대화에만 있고 문서에 없습니다(아래 §문서 반영 필요).

## 다음 작업

- 작업: task-007의 방향을 정합니다 —
  ① `SPEC §5.3`을 그대로 두고 카드에 구성 합계 수치 하나를 놓는 배치로 `/analyze-init`을 돌려 DP4를 다시 쓰거나,
  ② 「카드에 구성 수치를 두지 않는다」를 확정하려면 `/spec-init`으로 `§5.3`의 첫·셋째 문장을 먼저 고칩니다.
  verify는 ①을 권했습니다.
- 완료 기준: analyze.md DP4가 실측(232 / 219 / 347~375 / 여유 96pt)을 근거로 다시 쓰이고,
  그에 맞춰 implement.md task-007의 목적·접근·검증 조건이 갱신되어 구현을 재개할 수 있는 상태가 됩니다.

## 먼저 읽을 문서

- [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md)
  — task-007 항목에 실측값과 선택지, 그 위 항목들에 이번 세션의 결정 근거
- [features/20260818-001-resource-visualization/spec.md](./features/20260818-001-resource-visualization/spec.md)
  — `§5.3`(카드)과 `§5.4`(상세)의 문장 차이가 쟁점입니다
- [features/20260818-001-resource-visualization/analyze.md](./features/20260818-001-resource-visualization/analyze.md)
  — `§5 DP4`가 다시 쓸 대상, `DP15`가 UI 테스트를 늘리지 않는 근거
- [features/20260818-001-resource-visualization/implement.md](./features/20260818-001-resource-visualization/implement.md)
  — Task 13개 상태

## 문서 반영 필요

- UI 테스트 중복 감사 결과가 어느 문서에도 없습니다. 완전 중복 3건
  (`testOtherCardShortcutMovesSelectionWhileDetailIsOpen` 8.9초,
  `ResourceRunnerUITests.testMenuBarClickOpensPopover` 4.4초,
  단언이 하나도 없는 `ResourceRunnerUITestsLaunchTests.testLaunch` 2.2초)과
  병합형 후보 여섯, 그리고 production 확인이 필요한 보류 3건이 이 대화에만 있습니다.
- core-resource-monitoring task-010의 행 식별자·탭 동작이 실행으로 확인되지 않았다는 사실은
  resource-visualization README에 적혀 있으나, 기기 인증 창이 해소되면
  `DashboardProcessListDisplayUITests`·`DashboardDetailExpansionUITests`를 돌려 닫아야 한다는 후속 작업이
  어느 진행 추적자에도 등록돼 있지 않습니다.
