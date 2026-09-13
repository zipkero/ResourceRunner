# Context

저장: 2026-09-13 13:08 +09:00

## 현재 목표

`20260912-001-dashboard-visual-language`가 바꾼 최종 상태에 맞춰 `docs/product.md`의 낡은 서술을 갱신한다.
IMPLEMENT가 닫히기를 기다리던 항목이고, 이 feature에서 남은 문서 작업은 이것뿐이다.

## 현재 상태

`20260912-001-dashboard-visual-language`의 IMPLEMENT를 닫았다.
Task 11개가 전부 `[x]`이고 `SPEC §5` 완료 조건 15개가 모두 성립 확인을 받았다.
재시도는 `task-002` 한 번뿐이었다 — 삭제한 helper의 doc 주석이 새 함수 위에 겹쳐 남은 `style/minor`였다.

이 feature가 확정한 수치 — 카드 CPU **329** · Memory **224**, 본체 콘텐츠 **601** / 팝오버 프레임 **627**(실측, 산술과 0pt 차),
상세 400×480 유지, 코어 격자 아래끝 14코어 **176** · 56코어 **476**, M3 카드 넷 프레임 **1083** ≤ 기준 기기 1084.

루프 도중 `docs/design.md`와 `ROADMAP.md`는 `task-010`이 이미 새 값으로 갱신했다.
`docs/product.md`만 손대지 않은 채 남았다.

마지막 검증: 단위 스위트 911건과 UI 스위트 열 개 28건이 실패 0으로 통과했다.
화면 육안 확인은 루프 전체에서 하지 않았다 — 「바쁜 코어가 한눈에 찾아지는가」, 「카드가 떠올라 보이는가」 같은 지각 판정이 남아 있다.

branch `main`, 기준 HEAD `f0af886`. 작업 트리는 `CONTEXT.md` 외에 깨끗하다.

## 현재 작업 문서

- [features/20260912-001-dashboard-visual-language/README.md](./features/20260912-001-dashboard-visual-language/README.md) — SPEC·DESIGN·IMPLEMENT 전부 `[x]`

## 확정된 결정

- 이 feature가 바꾼 표시를 `docs/product.md`에 쓰는 시점은 IMPLEMENT가 닫힌 뒤 최종 상태로 한 번에 쓰는 것이다 —
  직전 feature가 더한 표시를 이 feature가 다시 바꾸기 때문이며, 그 시점이 지금이다
- 코어 격자의 주황(`busy`)은 위험이 아니라 지금 일하는 자리를 가리키고, 색은 세 번째 중복 수단이다 —
  [spec.md §3](./features/20260912-001-dashboard-visual-language/spec.md)
- 라이트에서 `quiet`와 `busy`의 `L*`가 56으로 같아 회색조에서 갈리지 않는 것은 허용된 상태이고,
  그 자리는 칸 안 정수 퍼센트와 채움 높이가 맡는다 —
  [design.md §5 DP8](./features/20260912-001-dashboard-visual-language/design.md)

## 미확정 판단

- `docs/product.md:134`의 「색상만으로 정상, 경고와 위험을 구분하지 않아야 합니다」와 코어 격자 주황의 관계를 본문에 정리할지.
  verify는 그 조항이 Memory Pressure의 세 단계를 가리키고 코어 격자는 문턱 하나라 충돌하지 않는다고 판정했으나,
  product.md 본문에는 그 구분이 없다 — [spec.md §3](./features/20260912-001-dashboard-visual-language/spec.md)

## 다음 작업

- 작업: `docs/product.md`의 낡은 서술 세 덩어리를 이 feature의 최종 상태로 갱신한다 —
  `:107` 「대시보드 상단에는 전체 시스템 상태와 그래프 시간 범위를 표시합니다」(`20260903-001`이 최상단 제목 줄을 없앤 뒤로 어긋남),
  CPU·Memory 기본 카드 설명과 `:163` 「논리 코어별 사용률」(세로 눈금 제거·빗금 제거·순위 머리글 변경·코어 색 세 단계·막대 20pt),
  그리고 §미확정 판단의 접근성 조항.
- 완료 기준: 세 덩어리가 현재 구현과 어긋나지 않고, 접근성 조항은 사용자가 정한 방향대로 정리되거나 그대로 두기로 확정된 상태.

## 먼저 읽을 파일

- [docs/product.md](./docs/product.md) — 이번에 고칠 대상
- [features/20260912-001-dashboard-visual-language/spec.md](./features/20260912-001-dashboard-visual-language/spec.md) — 완료 조건 15개와 §3 제약
- [features/20260912-001-dashboard-visual-language/design.md](./features/20260912-001-dashboard-visual-language/design.md) — Decision Point 16개, 실측 수치 전부
- [docs/design.md](./docs/design.md) — 「대시보드 본체의 세로 예산」이 이미 새 값이다. product.md 서술의 기준으로 삼는다

## 문서 반영 필요

- 위 §다음 작업이 곧 `docs/product.md` 미반영분이다. 그 밖에 원본에 반영되지 않은 확정 사항은 없다.
- 코드에 남은 낡은 주석 넷은 이 feature의 범위 밖이라 손대지 않았다 —
  `ResourceRunner/DashboardView.swift:276` 부근(`CPUSeriesSwatchView`의 doc 주석이 `CPUSeriesRatioView`에 붙음),
  `ResourceRunner/ApplicationRowIcon.swift:29`(「`.caption` 한 줄 13.0pt를 실측」, 현재 순위 행은 15pt),
  `ResourceRunner/DashboardPresentation.swift`의 `coreNumberText` 겹친 `///` 블록,
  `ResourceRunner/DashboardView.swift`의 `CardRankingSlotView` 위 주석이 가리키는 `task-011`(직전 feature 번호).
  앞 셋은 Per-Request 구간과 spec.md §4 제외 범위에서 왔다.
