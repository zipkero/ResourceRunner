# Context

저장: 2026-09-14 22:34 +09:00

## 현재 목표

M2(CPU·Memory 핵심 리소스 모니터링)의 잔여를 닫는다.
문서 갱신 두 건은 끝났고, 남은 것은 실기기 조작·관찰이 필요한 Task 묶음과 맨 마지막에 둘 캐릭터 자산·메뉴바 애니메이션이다.

## 현재 상태

`docs/product.md`와 `ROADMAP.md` 갱신을 마쳤다.
`docs/product.md`는 다섯 자리를 고쳤다 — 본체 상단 서술, 그래프 판의 보조 표시와 미수집 구간,
접근성 조항의 적용 범위, 코어 칸 색 세 값, 카드 순위 머리글과 제외 사실의 자리.
`ROADMAP.md`는 M2 현재 상태 칸의 근거를 지금 상태로 바꿨다.

M2가 닫히지 않은 근거는 셋이다.
`20260812-001-core-resource-monitoring`의 IMPLEMENT가 열려 있고 Task 16개 중 6개(`task-006`·`007`·`012`·`013`·`014`·`015`)가 `[ ]`다.
`20260903-001-dashboard-visual-refinement`는 8개 중 `task-008` 하나만 남았다.
캐릭터 자산·메뉴바 애니메이션은 feature 자체가 없고, 자산은 `StatusCatStatic` 정적 하나뿐이다.

`task-006`·`007`은 신규 구현이 아니라 2026-08-17 SPEC 재작성으로 승인이 풀린 재검증 건으로 보인다 —
`ApplicationRanking.swift`·`CPUActivityStateEvaluator.swift`와 각 테스트가 있고 `ApplicationCoordinator.swift:215`가 평가기를 호출한다.
각 Task의 검증 조건을 전부 만족하는지는 확인하지 않았다.

이번 작업에서 테스트는 실행하지 않았다 — 코드를 바꾸지 않았다.
`20260912-001-dashboard-visual-language` 루프 전체에서 화면 육안 확인을 하지 않아 지각 판정이 남아 있다.

branch `main`, 기준 HEAD `7b49a0f`.

## 현재 작업 문서

- [features/20260812-001-core-resource-monitoring/implement.md](./features/20260812-001-core-resource-monitoring/implement.md) — 남은 Task 6개
- [features/20260903-001-dashboard-visual-refinement/implement.md](./features/20260903-001-dashboard-visual-refinement/implement.md) — `task-008`

## 확정된 결정

- 캐릭터 자산과 메뉴바 애니메이션은 M2 잔여 중 마지막에 착수하고, 그 전에 M3를 먼저 시작한다.
  M3의 「의존 관계: M2」 선언 자체는 고치지 않고 M2 근거 칸에 예외만 기록했다 —
  [ROADMAP.md](./ROADMAP.md) §현재 상태 M2 행
- `docs/product.md`의 「색상만으로 정상, 경고와 위험을 구분하지 않아야 합니다」는 유지하고,
  그 대상이 Memory Pressure 같은 단계 표시이며 코어 격자의 색은 단계 구분이 아니라는 것을 조항 아래에 명시한다 —
  [docs/product.md](./docs/product.md) §접근성

## 미확정 판단

- `docs/product.md`의 「최근 1분·5분·10분 중 선택된 범위의 사용량 그래프」를 어떻게 할지.
  현재 구현은 `HistoryCapacity.defaultTimeRange` 10분 고정이고 범위 선택 UI가 없다.
  M4 설정 소관으로 보여 이번 범위 밖에 뒀고 사용자 판단을 받지 않았다 — [docs/product.md](./docs/product.md) §CPU 기본 카드

## 다음 작업

- 작업: M2 잔여 중 실기기 조작·관찰이 필요한 Task에 착수한다.
  어느 Task부터 시작할지는 사용자가 정한다 — `task-014`가 나머지가 닫힌 뒤라는 제약만 있다.
  실기기를 켜는 김에 `20260912-001-dashboard-visual-language`의 화면 육안 확인(바쁜 코어가 한눈에 찾아지는가, 카드가 떠올라 보이는가)도 함께 처리할 수 있다.
- 완료 기준: 착수한 Task가 verify 판정을 받아 해당 `implement.md`의 체크박스가 `[x]`가 된 상태.

## 먼저 읽을 파일

- [features/20260812-001-core-resource-monitoring/implement.md](./features/20260812-001-core-resource-monitoring/implement.md) — `task-006`·`007`은 실기기 확인 절차까지 본문에 있음
- [features/20260812-001-core-resource-monitoring/README.md](./features/20260812-001-core-resource-monitoring/README.md) — 2026-08-17 승인 초기화 경위와 테스트 실행 정책
- [ROADMAP.md](./ROADMAP.md) — 변경한 파일. §현재 상태 M2 행과 §M2 전환 기준
- [docs/product.md](./docs/product.md) — 변경한 파일. §공통 정보 구조·§접근성·§CPU·§TOP 5 정책

## 문서 반영 필요

- 없음.
- 코드에 남은 낡은 주석 넷은 여전히 그대로다 —
  `ResourceRunner/DashboardView.swift:273`(`CPUSeriesSwatchView`의 doc 주석이 아래 뷰에 붙음),
  `ResourceRunner/ApplicationRowIcon.swift:29`(「`.caption` 한 줄 13.0pt를 실측」, 현재 순위 행은 15pt),
  `ResourceRunner/DashboardPresentation.swift:686`의 `coreNumberText` 겹친 `///` 블록,
  `ResourceRunner/DashboardView.swift:820`의 `CardRankingSlotView` 위 주석이 가리키는 `task-011`·`task-016`.
  `20260912-001` 범위 밖이라 손대지 않았고 소유 단계가 정해지지 않았다.
