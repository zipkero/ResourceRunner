# Context

저장: 2026-09-07 06:49 +09:00

## 현재 목표

`20260906-001-graph-legibility-and-color`의 색 재결정을 코드까지 반영한다.
Memory 구성 네 구간을 이 feature 착수 전 상태(두 색조 각 두 단계, 파랑 둘·주황 둘)로 되돌리고,
그에 맞춰 초기화된 Task 여덟을 현재 spec·design 기준으로 다시 검증받는다.

## 현재 상태

Task 여덟이 구현·verify 승인까지 끝나 커밋 `060504b`에 들어 있다.
그 뒤 사용자가 완성된 화면을 보고 **Memory 구성 색만** 착수 전이 낫다고 지적해, 오늘 SPEC·DESIGN·IMPLEMENT를 차례로 재작성했다.
`/spec-init` §재작성 시 하위 승인 상태 초기화에 따라 README의 DESIGN·IMPLEMENT와 Task 여덟 체크박스가 전부 `[ ]`로 되돌아갔고,
그 뒤 DESIGN만 다시 `[x]`가 됐다. 코드는 아직 한 줄도 고치지 않았다.

실제로 코드가 바뀌어야 하는 자리는 `task-003`(Memory 팔레트) 하나이고, 나머지 일곱은 무변경 확인 Task다.
다만 `implement` skill은 위에서부터 첫 미완료 Task를 잡으므로 다음 차례는 `task-001`이다.

마지막 검증: `060504b` 시점 전체 스킴에서 단위 `ResourceRunnerTests` 455개와 UI 열 스위트가 실패 0으로 통과했다.
재작성 이후로는 테스트를 돌린 적이 없다.

branch `main`, 기준 HEAD `060504b`(아직 푸시하지 않음). 미커밋 변경은 오늘 재작성한 feature 문서 넷뿐이다.

## 현재 작업 문서

- [features/20260906-001-graph-legibility-and-color/implement.md](./features/20260906-001-graph-legibility-and-color/implement.md) — 현재 항목은 `task-001: 그래프 판을 키우고 영역 경계와 시간 축을 둔다`
- [features/20260903-001-dashboard-visual-refinement/implement.md](./features/20260903-001-dashboard-visual-refinement/implement.md) — `task-008`만 미완, 이번 feature 이후로 미룸

## 확정된 결정

- Memory 구성 네 구간을 커밋 `8f79d15`의 값으로 되돌린다 — 라이트 App `#165698` · Wired `#4b82d0` · Compressed `#83441d` · Cached `#ba6e41`,
  다크 App `#5287d5` · Wired `#a1bbf5` · Compressed `#c07345` · Cached `#ecae8c` — [spec.md §1 「2026-09-06 색 재결정」](./features/20260906-001-graph-legibility-and-color/spec.md), [design.md DP7](./features/20260906-001-graph-legibility-and-color/design.md)
- 「리소스마다 고유 색조」 규칙을 철회한다. 카드 구분은 제목·아이콘·배치가 맡고, 색은 한 카드 안에서만 계열·구간·단계를 가른다.
  집합 사이 색조 중복은 실격 사유가 아니다 — [spec.md §3](./features/20260906-001-graph-legibility-and-color/spec.md), [design.md DP6](./features/20260906-001-graph-legibility-and-color/design.md)
- M3의 Network·Disk 색조 예약(청록 h165 · 자주 h320)을 철회한다. 두 카드의 색은 카드 확정 시점에 갈래 수·대비 3:1·색 외 구분 수단 셋으로 정한다 — [design.md DP6](./features/20260906-001-graph-legibility-and-color/design.md)
- Memory 색 집합은 CPU 램프와 별개로 두고 공개 진입점은 `memoryComposition(_:)` 하나만 남긴다.
  두 집합의 「단계」가 서로 다른 뜻이므로 `RampStep`은 CPU 전용이다 — [design.md DP7](./features/20260906-001-graph-legibility-and-color/design.md)
- CPU 계열 색·코어 단계 색·그래프 표현·여백·문구는 재결정 대상이 아니며 `060504b` 그대로 둔다 — [spec.md §1 「2026-09-06 색 재결정」](./features/20260906-001-graph-legibility-and-color/spec.md)
- 회색조에서 Memory 네 구간이 두 쌍(App≈Compressed, Wired≈Cached)으로 붙는 것을 허용하고, 범례 이름이 색 비의존 구분 수단을 맡는다.
  표시 순서에서 이웃한 두 구간의 `L*`는 갈린다(라이트 17.9 / 18.0 / 17.9, 다크 19.9 / 19.9 / 20.1) — [spec.md §3·§5.4](./features/20260906-001-graph-legibility-and-color/spec.md), [design.md DP7](./features/20260906-001-graph-legibility-and-color/design.md)
- 시각 항목의 수동 확인은 Codex 워커가 아니라 coordinator가 스크린샷·실측으로 수행한다.
  이번 판본에서 수동 확인이 남은 Task는 `task-003` 하나다 — [implement.md task-003 확인 필드](./features/20260906-001-graph-legibility-and-color/implement.md)

## 미확정 판단

- `task-001`에서 「그래프가 띠가 아니라 면으로 읽히는지」 수동 확인을 뺀 것이 맞는지.
  앞 판본은 그것을 「비율·픽셀 단언으로 대체되지 않는 잔여 판단」으로 두었고, 실제로 앞 라운드 verify가 그 근거 부재로 reject한 적이 있다.
  이번 판본은 판 높이 > 60pt · 가로세로 비 < 3.9 : 1 단언으로 대체했다.
  main이 그대로 두기로 판단해 사용자에게 알렸으나 아직 답을 받지 못했다 — [implement.md task-001 확인 필드](./features/20260906-001-graph-legibility-and-color/implement.md)

## 다음 작업

- 작업: `20260906-001-graph-legibility-and-color`의 `task-001`(그래프 판을 키우고 영역 경계와 시간 축을 둔다)을 현재 기준으로 확인하고 verify를 받는다.
  코드가 이미 그 목적을 만족하면 고치지 않고 그 사실을 보고한다.
- 완료 기준: implement.md task-001의 `검증 조건`이 성립하고 독립 verify가 approved를 내며, main이 그 Task 체크박스를 `[x]`로 넘긴 상태.

## 먼저 읽을 파일

- [features/20260906-001-graph-legibility-and-color/spec.md](./features/20260906-001-graph-legibility-and-color/spec.md) — 변경한 파일(§1 재결정 절 신설, §2·§3·§4·§5.4 갱신)
- [features/20260906-001-graph-legibility-and-color/design.md](./features/20260906-001-graph-legibility-and-color/design.md) — 변경한 파일(전문 재작성, DP 14개)
- [features/20260906-001-graph-legibility-and-color/implement.md](./features/20260906-001-graph-legibility-and-color/implement.md) — 변경한 파일(전문 재작성, Task 8개 전부 `[ ]`)
- [features/20260906-001-graph-legibility-and-color/README.md](./features/20260906-001-graph-legibility-and-color/README.md) — 변경한 파일(요약·상태판·작업 히스토리)
- [ResourceRunner/DashboardColorPalette.swift](./ResourceRunner/DashboardColorPalette.swift) — `task-003`이 고칠 자리. 현재는 Memory가 주황 한 색조 네 단계다
- `~/.claude/skills/implement/SKILL.md` §컨텍스트 로딩 — 상위 문서 재작성으로 초기화된 Task를 어떻게 다루는지

## 문서 반영 필요

- `docs/product.md:107` 「대시보드 상단에는 전체 시스템 상태와 그래프 시간 범위를 표시합니다」가 현재 구현과 어긋난다.
  `20260903-001-dashboard-visual-refinement`가 최상단 제목 줄을 없앴고 그 spec §1이 갱신을 예고했으나 아직 반영되지 않았다.
- `docs/product.md` 「CPU > 기본 카드」(`:142-147`)에 이번 feature가 더한 표시가 없다 — 그래프 시간 축·눈금, 미수집 구간 빗금과 진행 문구,
  순위 머리글 「앱 TOP 5 · 시스템 프로세스 제외」.
- `docs/product.md:163` 「논리 코어별 사용률」에 사용률 단계 색 설명이 없다.
- `docs/product.md` 「Memory > 기본 카드」에 순위 머리글이 없다.
- 위 넷은 IMPLEMENT가 다시 닫힐 때 `skills/verify/SKILL.md` §verify 후처리의 낡은 문서 보고로 한 번 더 올라온다.
  `docs/design.md`와 `ROADMAP.md`는 갱신 대상이 아니다 — 전자의 세로 예산 수치는 실측과 일치하고, 후자는 M2 전환 기준에 캐릭터 애니메이션이 남아 미충족이다.
