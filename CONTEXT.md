# Context

저장: 2026-09-03 01:05 +09:00

## 현재 목표

feature `20260831-001-detail-popover-readability`의 Task 7개를 구현해
CPU·Memory 상세 팝업에서 값을 읽어내기 어려운 두 자리를 고칩니다 —
펼친 하위 프로세스 행의 배치와 CPU 상세의 논리 코어별 사용률 표현입니다.
남은 것은 task-006 verify와 task-007입니다.

## 현재 상태

**task-001~005가 `[x]`이고 `SPEC §5.2`·`§5.4`가 닫혔습니다.**
task-006은 구현이 끝났으나 verify를 받지 못했고, task-007은 미착수입니다.

task-006의 verify Task(`task_3b0678961bfd`)는 Orca에 만들어 dispatch까지 했으나
사용자 요청으로 워커를 중단시켰습니다. 그 Task를 새 워커에 다시 dispatch하면 재개됩니다.

마지막 검증은 task-006 재작업 2회차의 실행으로 `DashboardDetailExpansionUITests` 4/4 ·
`DashboardProcessListDisplayUITests` 3/3 · `DashboardDetailPopoverUITests` 7/7 ·
`ResourceRunnerTests` 407/407이 전부 실패 0과 `** TEST SUCCEEDED **`였습니다.
다만 이 결과는 구현 워커의 자기 실행이고 독립 verify를 아직 받지 않았습니다.

branch `main`, HEAD `456cfa0`. 커밋되지 않은 변경 11개가 작업 트리에 있습니다.

## 현재 작업 문서

- [features/20260831-001-detail-popover-readability/implement.md](./features/20260831-001-detail-popover-readability/implement.md)
  — 다음 항목은 `task-006`(펼침 동작과 하위 행 조회의 회귀 보호)의 verify입니다.

## 확정된 결정

- **하위 프로세스 행은 이름 줄과 값 줄 두 줄입니다.** 시작선은 이름 34pt · 값 50pt이고
  네 간격은 행 안 2 / 하위끼리 10 / 부모–첫 하위 18 / 마지막 하위–다음 앱 26pt입니다(층마다 8pt 등차).
  정확도 우선으로 고른 것이며 단위 라벨 축약과 이름 말줄임은 각각 값의 뜻을 바꾸고 `SPEC §5.2`와 부딪혀 배제했습니다.
  [features/20260831-001-detail-popover-readability/design.md](./features/20260831-001-detail-popover-readability/design.md) §5 DP5·DP6에 있습니다.
- **코어 표현은 막대 격자를 유지합니다.** 원형 검토를 접은 근거는 공통 기준선 정렬이 각도·면적보다 비교 정확도가 높다는 것,
  Memory 도넛이 이미 「전체의 구성」을 뜻해 데이터 모양이 다르다는 것, 8열에서 칸 폭 40.8pt에 링과 수치가 함께 안 들어간다는 것입니다(2026-09-02 사용자 결정).
  같은 design.md §5 DP2·DP3의 채택안이 그대로입니다.
- **코어 칸은 `.accessibilityAddTraits(.isStaticText)`로 AXValue를 노출합니다.**
  `children: .ignore`로 합쳐진 요소는 macOS에서 AXGroup이 되어 AXValue를 싣지 않는 것이 실측으로 확인됐습니다.
  같은 design.md §5 DP10과 `ResourceRunner/DashboardView.swift:1044`에 있습니다.
- **격자의 폭 잔차는 `ProposedWidthLayout`이 막습니다.** 열 수가 콘텐츠 폭을 나눠떨어뜨리지 않으면
  부동소수점 잔차가 팝업 AX 프레임을 `400.0000000000001`로 만들어 기존 UI 회귀 테스트를 깨뜨렸습니다.
  같은 design.md §5 DP2에 있습니다.
- **세로 예산은 그대로입니다** — 격자 위끝 52pt, 14코어 아래끝 154pt, 64코어 478pt가 마지막, 65코어부터 480pt 초과.
  앱 목록이 격자보다 아래라 하위 행이 두 줄이 되어도 격자를 밀지 않습니다. 같은 design.md §5 DP8에 있습니다.
- **implement와 verify는 별도 Codex 세션으로 분리합니다.** Orca orchestration의 nested worker depth 1이
  워커의 자체 verifier 생성을 런타임에서 막습니다. 이 분리로 같은 세션 자체 verifier가 통과시킨 결함을 네 번 잡았습니다.
- **Codex 워커는 `terminal create --command "codex --yolo"`로 띄웁니다.**
  `worker-start --agent codex`와 `/codex:rescue` 플러그인 경로는 `workspace-write` 샌드박스를 먹어
  `com.apple.testmanagerd.control` 접근이 막혀 `xcodebuild test`가 실행되지 않습니다.
- **테스트 통과 건수는 baseline으로 쓰지 않습니다.** 기준은 「실패 0 + `** TEST SUCCEEDED **`」입니다.
  [features/20260812-001-core-resource-monitoring/README.md](./features/20260812-001-core-resource-monitoring/README.md) 2026-08-29 마지막 항목에 있습니다.
- **`ANALYSIS §5 DP4` 재작성은 아직 하지 않았습니다.**
  [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md) 2026-08-29 항목에 어긋난 자리 셋과 참조 행 번호가 있습니다.

## 미확정 판단

- **새 Xcode 타겟 `ResourceRunnerExpansionProbe`를 받아들일지.**
  task-006 재작업이 격리된 probe를 만들려고 타겟을 하나 더했고(`main.swift` 752바이트, `project.pbxproj` +90줄)
  구현 워커가 보고에서 밝히지 않았습니다. design.md가 다루지 않는 구조 변경이라
  `design/scope` 이탈인지 테스트 하네스 상세인지 판정이 필요합니다.
  중단된 verify Task의 최우선 항목으로 들어가 있습니다. 관련 본문: design.md §4 영향 범위.
- **`LazyVGrid` 치환을 가르는 회귀 그물을 이 기기에서 세울 수 없습니다.**
  `sizeThatFits` 안에서는 `LazyVGrid`도 화면 밖 행을 전부 실체화해 `VStack`+`HStack`과 측정값이 소수점까지 같고,
  접근성 계층으로 가르려면 화면 밖 칸이 있어야 하는데 14코어에서는 격자 전체가 첫 화면 안입니다.
  task-003에서 task-005로 이월돼 「남은 위험」으로 기록됐습니다. 관련 본문: design.md §5 DP4.

## 다음 작업

- 작업: task-006의 verify를 독립 세션에서 받습니다.
  Orca Run `run_b1cf7a61b08f`의 Task `task_3b0678961bfd`에 spec이 저장돼 있으므로,
  새 워커 터미널(`codex --yolo`)을 만들어 그 Task를 다시 dispatch하면 됩니다.
- 완료 기준: verify가 `approved`를 돌려주고 `SPEC §5.6`·`§5.7`의 성립이 함께 확인되어
  implement.md task-006 체크박스가 `[x]`로 넘어갑니다.
  `rejected`이면 재시도 한도(한 Task당 최대 3번 구현)를 이미 쓴 상태이므로 루프를 멈추고 사용자 판단을 받습니다.

## 먼저 읽을 파일

- [features/20260831-001-detail-popover-readability/implement.md](./features/20260831-001-detail-popover-readability/implement.md)
  — task-006의 목적·접근·검증 조건과 요구 mutation 다섯
- [features/20260831-001-detail-popover-readability/design.md](./features/20260831-001-detail-popover-readability/design.md)
  — §2 데이터 흐름, §4 영향 범위, §5 DP7·DP10
- [features/20260831-001-detail-popover-readability/spec.md](./features/20260831-001-detail-popover-readability/spec.md) — `§5.6`·`§5.7`·`§5.1`
- [ResourceRunnerUITests/DashboardDetailExpansionUITests.swift](./ResourceRunnerUITests/DashboardDetailExpansionUITests.swift) — 변경한 파일
- [ResourceRunnerUITests/DashboardDetailPopoverUITests.swift](./ResourceRunnerUITests/DashboardDetailPopoverUITests.swift) — 변경한 파일
- [ResourceRunnerUITests/DashboardProcessListDisplayUITests.swift](./ResourceRunnerUITests/DashboardProcessListDisplayUITests.swift) — 변경한 파일
- [ResourceRunner.xcodeproj/project.pbxproj](./ResourceRunner.xcodeproj/project.pbxproj) — 변경한 파일, 새 타겟 +90줄
- [ResourceRunnerExpansionProbe/main.swift](./ResourceRunnerExpansionProbe/main.swift) — 새로 만든 파일
- [ResourceRunner/ApplicationRanking.swift](./ResourceRunner/ApplicationRanking.swift) — 변경한 파일 (task-005 approved)
- [ResourceRunner/DashboardPresentation.swift](./ResourceRunner/DashboardPresentation.swift) — 변경한 파일 (task-004·005 approved)
- [ResourceRunner/DashboardView.swift](./ResourceRunner/DashboardView.swift) — 변경한 파일 (task-004·005 approved)
- [ResourceRunnerTests/ApplicationProcessRowLayoutTests.swift](./ResourceRunnerTests/ApplicationProcessRowLayoutTests.swift) — 변경한 파일 (task-004 approved)
- [ResourceRunnerTests/DetailAccessibilityFormattingTests.swift](./ResourceRunnerTests/DetailAccessibilityFormattingTests.swift) — 새로 만든 파일 (task-005 approved)
- [ResourceRunnerUITests/CPUCoreAccessibilityUITests.swift](./ResourceRunnerUITests/CPUCoreAccessibilityUITests.swift) — 새로 만든 파일 (task-005 approved)

## 문서 반영 필요

- **`DESIGN §5 DP10`의 근거가 사실과 다릅니다.** 「하위 행 요소를 합치면 AX value가 사라진다」고 적혀 있으나,
  실측 결과 `.combine`은 하위 행을 AX 요소 1개로 만들고 **value에 PID가 그대로 남습니다**(label만 빈 문자열).
  실제로 조회를 깨는 것은 `.ignore`(AX 요소 0개)입니다.
  채택안(요소를 합치지 않음)은 유효하므로 근거 서술만 고치면 됩니다.
- **implement.md의 mutation 서술 여럿이 「어느 단언이 잡는다」를 사실과 다르게 적고 있습니다** —
  task-001의 둘, task-002의 셋, task-004의 셋입니다.
  mutation이 잡히는 것 자체는 전부 성립해 reject 사유는 아니었습니다.
