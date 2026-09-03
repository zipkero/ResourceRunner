# Context

저장: 2026-09-03 21:40 +09:00

## 현재 목표

`20260818-001-resource-visualization`의 `analyze.md` `§5 DP4`를 현재 구현과 일치하게 재작성합니다.
DP4의 채택안(옵션 D)이 「네 항목의 이름과 수치가 카드에 남습니다」인데
실제 구현은 카드에 수치를 두지 않아 문서와 코드가 어긋난 상태입니다.

## 현재 상태

`20260831-001-detail-popover-readability`가 **완료**됐습니다 —
Task 7개 전부 `[x]`, `SPEC §5.1`~`§5.7` 닫힘, README 상태판 `[x] IMPLEMENT`.
이 feature로 낡아진 루트 문서(`docs/product.md`·`docs/design.md`)도 갱신했고
`design.md` DP10 근거와 `implement.md` mutation 서술의 사실 오류도 정정했습니다.

`20260818-001-resource-visualization`은 IMPLEMENT 완료(Task 13개 전부 `[x]`)이지만
`analyze.md §5 DP4` 재작성이 남아 문서와 구현이 어긋나 있습니다.
「`§5.3` 판정 → DP4 재작성」 순서 중 앞 절반만 끝났습니다.

`20260812-001-core-resource-monitoring`은 IMPLEMENT `[ ]`이고 Task 6개가 남았습니다.
`20260817-001-extended-resource-monitoring`은 IMPLEMENT `[ ]`이며 이번 세션에서 다루지 않아 현재 지점을 확인하지 않았습니다.

마지막 검증은 `detail-popover-readability` task-007 재검증의 단위 스위트 412 passed / 0 failed / 0 skipped와
`** TEST SUCCEEDED **`입니다. UI 스위트는 task-006 재검증에서 전부 통과했습니다.

이 기기의 XCUITest 자동화는 간헐적으로 `Timed out while enabling automation mode`로 막힙니다.
원인은 특정하지 못했고 잔존 러너 프로세스 정리와 재시도로 풀릴 때도, 안 풀릴 때도 있었습니다.

branch `main`, HEAD `a1deba0`, `origin/main`과 같고 작업 트리는 깨끗합니다.

## 현재 작업 문서

- [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md)
  — 2026-08-29 항목 (2)에 어긋난 자리 셋과 DP4 참조 행 번호가 있습니다.
  이 feature는 `design.md` 대신 `analyze.md`를 쓰는 이전 산출물 구조입니다.

## 확정된 결정

- **DP4 재작성은 `analyze.md` 전체 재작성이어야 합니다.**
  `analyze.md`는 부분 수정하지 않는 문서이고, DP4를 참조하는 자리가 그 파일 안에만 여덟 곳 이상입니다
  (20·114·157·194·309·398·629·692·711행). 문장 하나만 고칠 수 있는 구조가 아닙니다.
  같은 README 2026-08-29 항목 (2)에 있습니다.
- **어긋난 자리는 셋입니다** — 옵션 D 채택안의 「네 항목의 이름과 **수치**가 카드에 남습니다」,
  「카드 범례의 값은 축약 서식을 씁니다」(157행에도 같은 말이 있고 지금은 대상이 없음),
  옵션 C를 접은 이유(「`SPEC §5.3`이 카드에서 수치를 요구」)가 현재 구현과 충돌하는 것.
  같은 자리에 있습니다.
- **실측 세 값이 재작성의 근거입니다** — 스와치+이름+수치 네 쌍은 347pt(최장 375pt)가 필요하고
  카드 콘텐츠 폭은 232pt이며, 스와치+이름만이면 219pt로 축소 없이 들어갑니다(여유 13pt).
  정상 상태 제목 줄에 약 96pt가 남아 짧은 합계 하나를 놓을 여지는 있습니다(바가 짧아지는 대가).
  같은 README 2026-08-21 항목에 있습니다.
- **`detail-popover-readability`의 재사용 가능한 실측 셋은 루트 설계 문서에 남겼습니다** —
  합쳐진 접근성 요소가 `AXValue`를 싣지 않아 `.isStaticText`가 필요한 것,
  크기 측정 경로에서 접근성 트리가 실체화되지 않고 Lazy 컨테이너도 화면 밖 행을 전부 실체화하는 것,
  `maxWidth: .infinity` 균등 분할이 폭 잔차를 상위 레이아웃으로 흘리는 것.
  [docs/design.md](./docs/design.md) 「기술 방향 › SwiftUI 레이아웃과 접근성 제약」에 있습니다.
- **implement와 verify는 별도 Codex 세션으로 분리합니다.**
  Orca orchestration의 nested worker depth 1이 워커의 자체 verifier 생성을 런타임에서 막습니다.
  Codex 워커는 `orca terminal create --command "codex --yolo"`로 띄웁니다 —
  `worker-start --agent codex`와 `/codex:rescue` 플러그인 경로는 `workspace-write` 샌드박스를 먹어
  `com.apple.testmanagerd.control` 접근이 막혀 `xcodebuild test`가 실행되지 않습니다.
- **테스트 통과 건수는 baseline으로 쓰지 않습니다.** 기준은 「실패 0 + `** TEST SUCCEEDED **`」입니다.
  [features/20260812-001-core-resource-monitoring/README.md](./features/20260812-001-core-resource-monitoring/README.md) 2026-08-29 마지막 항목에 있습니다.

## 미확정 판단

- **DP4를 어느 방향으로 재작성할지.** 두 길이 있고 범위가 다릅니다.
  ① `SPEC §5.3`을 그대로 두고 카드에 **구성 합계 수치 하나**를 놓는 배치로 DP4를 실측과 함께 다시 씁니다 —
  `analyze.md` 재작성만으로 끝나고 사용자가 승인한 완료 조건을 건드리지 않습니다.
  ② 「카드에는 구성 수치를 두지 않는다」를 확정하려면 `SPEC §5.3`의 첫·셋째 문장을 먼저 고쳐야 합니다 —
  `spec.md` 재작성까지 올라갑니다.
  [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md) 2026-08-21 항목에 두 길이 적혀 있습니다.

## 다음 작업

- 작업: DP4 재작성 방향을 ①과 ② 중 하나로 확정한 뒤 `analyze.md` 전체를 다시 씁니다.
  방향이 정해지기 전에는 재작성을 시작하지 않습니다 — §5.3을 건드리는지에 따라 결과가 달라집니다.
- 완료 기준: `analyze.md`의 DP4 채택안과 그 근거가 현재 구현과 일치하고,
  위 「어긋난 자리 셋」이 모두 해소되며, DP4를 참조하는 나머지 자리(20·114·157·194·309·398·629·692·711행)가
  새 채택안과 모순되지 않습니다.
  방향 ②를 고르면 `spec.md` 재작성이 먼저이고, 그 경우 하위 승인 상태 초기화 범위를 함께 확인합니다.

## 먼저 읽을 파일

- [features/20260818-001-resource-visualization/README.md](./features/20260818-001-resource-visualization/README.md)
  — 2026-08-21 항목(두 길과 실측 세 값), 2026-08-29 항목 (2)(어긋난 자리 셋과 참조 행 번호)
- [features/20260818-001-resource-visualization/analyze.md](./features/20260818-001-resource-visualization/analyze.md)
  — `§5 DP4`와 그것을 참조하는 여덟 자리
- [features/20260818-001-resource-visualization/spec.md](./features/20260818-001-resource-visualization/spec.md)
  — `§5.3`·`§5.4`. 방향 ②는 `§5.3`의 첫·셋째 문장을 고쳐야 합니다
- [features/20260818-001-resource-visualization/implement.md](./features/20260818-001-resource-visualization/implement.md)
  — task-007과 task-012의 검증 조건. 한 번 원문으로 되돌려 `analyze.md` DP4와 다시 일치시킨 이력이 있습니다

## 문서 반영 필요

없음.
