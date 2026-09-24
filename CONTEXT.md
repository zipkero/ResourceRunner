# Context

저장: 2026-09-15 22:45 +09:00

## 현재 목표

M2(CPU·Memory 핵심 리소스 모니터링)의 잔여를 닫는다.
책상에서 닫을 수 있는 Task는 이번 세션에서 모두 처리했고, 남은 것은 실기기 조작·관찰이 필요한 묶음과 맨 마지막에 둘 캐릭터 자산·메뉴바 애니메이션이다.

## 현재 상태

`20260812-001-core-resource-monitoring`의 `task-015`·`task-006`·`task-007`이 verify approved로 `[x]`가 됐다.
셋 다 2026-08-17 SPEC 재작성으로 승인만 풀렸던 건이라 구현이 이미 성립해 있었고, 코드 변경은 `ApplicationCoordinator.swift`·`CharacterStateSource.swift`의 낡은 `M1` 서술 주석 정정뿐이다.
`task-007`은 그 주석이 거짓이라는 이유로 한 번 `style/minor` reject를 받은 뒤 재작업해 approved됐다.
이 feature에 남은 것은 `task-012`·`013`·`014` 셋이며 전부 실기기 조작 전용이다.

`20260903-001-dashboard-visual-refinement`의 `task-008`은 **rejected 상태로 열려 있다**.
정적 확인 네 항목(애니메이션 추가 0건, 새 타이머·관찰자·이미지 생성 없음, `project.pbxproj` 무변경으로 App Sandbox 유지, 테스트 전수 통과)은 모두 성립했다.
해소 조건은 `SPEC §5.13`의 잔여 판단 하나다 — 팝오버를 연 채 앱 자신의 CPU 사용량을 변경 전과 같은 조건으로 관찰해 지속 상승이 없음을 확인해야 하며, 검증 조건이 이를 「정적 확인으로 대체되지 않는 잔여 판단」으로 규정해 정적 근거로 닫히지 않는다.

verify 과정에서 닫힌 feature의 완료 조건 둘이 후속 feature에 의해 거짓이 된 것을 확인하고, 사용자 결정에 따라 원문을 지우지 않고 대체 사실만 덧붙였다.

실기기 확인을 일부 진행했고 두 가지를 얻었다.
`task-007`의 「Debug 주입이 아니라 실제 판정이 이름을 정한다」가 확인됐다 —
Release 빌드로 띄운 앱의 메뉴바 항목 접근성 이름이 `ResourceRunner, 낮음`이었고 Release에는 주입 진입점이 없다.
`task-008`의 자체 CPU는 HEAD와 `cccca76`을 각각 Release로 빌드해 2초 간격 15표본씩 재어 HEAD 평균 0.81%(최대 2.30%), 변경 전 평균 0.92%(최대 3.00%)로 상승이 없었다.
다만 이 표본은 **팝오버가 닫힌 조건**이라 `SPEC §5.13`이 요구하는 「팝오버를 열어 둔 채」를 채우지 못한다 —
System Events의 클릭과 `AXPress` 모두 팝오버를 열지 못했고(`count of windows` = 0), 이는 이 feature README에 이미 기록된 환경 문제와 같은 증상이다.

마지막 검증 — `xcodebuild test -scheme ResourceRunner -destination 'platform=macOS'` 전체 통과(종료 코드 0, UI 테스트 28건 포함).

branch `main`, 기준 HEAD `fa618e4`. 위 변경은 전부 미커밋이다.

## 현재 작업 문서

- [features/20260903-001-dashboard-visual-refinement/implement.md](./features/20260903-001-dashboard-visual-refinement/implement.md) — `task-008`, rejected 상태로 열려 있음
- [features/20260812-001-core-resource-monitoring/implement.md](./features/20260812-001-core-resource-monitoring/implement.md) — 남은 `task-012`·`013`·`014`

## 확정된 결정

- 캐릭터 자산과 메뉴바 애니메이션은 M2 잔여 중 마지막에 착수하고, 그 전에 M3를 먼저 시작한다 —
  [ROADMAP.md](./ROADMAP.md) §현재 상태 M2 행
- `docs/product.md`의 「색상만으로 정상, 경고와 위험을 구분하지 않아야 합니다」는 유지하고, 그 대상이 단계 표시이며 코어 격자의 색은 단계 구분이 아니라는 것을 조항 아래에 명시한다 —
  [docs/product.md](./docs/product.md) §접근성
- 닫힌 feature의 완료 조건이 후속 feature에 의해 거짓이 되면, 원문을 지우지 않고 대체 사실과 참조를 덧붙인다 —
  [features/20260903-001-dashboard-visual-refinement/spec.md](./features/20260903-001-dashboard-visual-refinement/spec.md) 완료 조건 3·10,
  [features/20260903-001-dashboard-visual-refinement/design.md](./features/20260903-001-dashboard-visual-refinement/design.md) §5 DP3·DP13
- `SPEC §5.3`(카드 표면)은 `20260912-001-dashboard-visual-language`가, `SPEC §5.10`(카드 높이 상한)은 `20260906-001-graph-legibility-and-color`가 대체한 것으로 본다 — 위 두 문서의 대체 기록

## 미확정 판단

- `docs/product.md`의 「최근 1분·5분·10분 중 선택된 범위의 사용량 그래프」를 어떻게 할지.
  현재 구현은 `HistoryCapacity.defaultTimeRange` 10분 고정이고 범위 선택 UI가 없다.
  M4 설정 소관으로 보여 범위 밖에 뒀고 사용자 판단을 받지 않았다 — [docs/product.md](./docs/product.md) §CPU 기본 카드

## 다음 작업

- 작업: 실기기에서 `task-008`의 수동 확인을 수행한다 — 동작 줄이기와 애니메이션 끄기를 켠 환경에서 카드와 두 상세가 같은 정보를 보이는지, 그리고 팝오버를 열어 둔 채 앱 자신의 CPU 사용량이 변경 전과 같은 조건에서 지속 상승하지 않는지.
  자체 CPU 쪽은 팝오버를 사람이 직접 열어 둔 뒤 재면 닫힌다 — 측정 절차와 팝오버 닫힘 조건의 결과는 §현재 상태에 있다.
  실기기를 켜는 김에 `task-012`·`013`, `task-007`의 실제 부하 상태 전환 관찰, `20260912-001-dashboard-visual-language`의 화면 육안 확인을 같은 세션에서 함께 처리할 수 있다.
  `task-007` 관찰은 Debug 주입 메뉴를 건드리지 않은 상태에서 해야 한다 — 코디네이터가 판정 상태가 바뀔 때만 `send`하므로 주입값이 다음 실제 전이까지 메뉴바에 남는다.
- 완료 기준: `task-008`이 verify approved를 받아 `implement.md` 체크박스가 `[x]`가 되고, `20260903-001-dashboard-visual-refinement`의 모든 Task가 `[x]`가 되어 feature README의 IMPLEMENT가 닫힌 상태.

## 먼저 읽을 파일

- [features/20260903-001-dashboard-visual-refinement/implement.md](./features/20260903-001-dashboard-visual-refinement/implement.md) — 변경한 파일. `task-008` 검증 조건의 수동 확인 줄과 `task-004`의 대체 기록
- [features/20260903-001-dashboard-visual-refinement/spec.md](./features/20260903-001-dashboard-visual-refinement/spec.md) — 변경한 파일. 완료 조건 3·10의 대체 기록
- [features/20260903-001-dashboard-visual-refinement/design.md](./features/20260903-001-dashboard-visual-refinement/design.md) — 변경한 파일. §5 DP3·DP13의 대체 기록
- [features/20260812-001-core-resource-monitoring/implement.md](./features/20260812-001-core-resource-monitoring/implement.md) — 변경한 파일. `task-012`·`013`은 실기기 확인 절차까지 본문에 있음
- `ResourceRunner/ApplicationCoordinator.swift`, `ResourceRunner/CharacterStateSource.swift` — 변경한 파일. 주석 정정만

## 문서 반영 필요

- 낡은 주석·서술의 소유 단계가 정해지지 않았다. 확인된 자리는 다음과 같다.
  - `ResourceRunner/DashboardView.swift:273`(`CPUSeriesSwatchView`의 doc 주석이 아래 뷰에 붙음),
    `ResourceRunner/ApplicationRowIcon.swift:29`(「`.caption` 한 줄 13.0pt를 실측」, 현재 순위 행은 15pt),
    `ResourceRunner/DashboardPresentation.swift:686`의 `coreNumberText` 겹친 `///` 블록,
    `ResourceRunner/DashboardView.swift:820`의 `CardRankingSlotView` 위 주석이 가리키는 `task-011`·`task-016`.
  - `ResourceRunner/MonitoringLifecycle.swift:21`, `ResourceRunnerTests/MonitoringLifecycleTests.swift:268`,
    `ResourceRunnerTests/MonitoringSampleStoreTests.swift:187`의 `M1` 서술.
  - [features/20260812-001-core-resource-monitoring/analyze.md](./features/20260812-001-core-resource-monitoring/analyze.md) 355행 문단.
    「단축키의 존재는 카드에 항상 보이는 표시에서 확인됩니다」는 `20260903-001`의 `task-003`이, 「본체와 상세 팝업 콘텐츠 양쪽에 등록」은 승인된 `task-016`이 되열었다.
  - `20260903-001-dashboard-visual-refinement`의 `spec.md` 확정된 방향 요약과 `design.md`의 카드 표면 상수·접근 요약·테스트 영향 서술에 테두리 표현이 남아 있다.
    대체 기록이 붙은 자리의 부차 서술이라 이번에 덧붙이지 않았다.
- 코드에 남은 관찰 두 건. 둘 다 verify가 reject 사유로 보지 않았다.
  - `ApplicationRankingSample.unreadableCount`는 production에서 읽는 곳이 없다.
    설계가 화면에 수 대신 고정 문구를 내보내도록 정했고 `task-006` 접근 필드가 이 필드 전달을 요구한다.
  - `DashboardView.bodyHeight = 601`은 카드 기준 높이에서 유도되지 않은 실측 상수이고, 카드 높이 합과 어긋나는 것을 잡는 테스트가 없다.
