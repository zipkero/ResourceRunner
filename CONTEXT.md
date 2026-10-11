# Context

저장: 2026-10-11 22:02 +09:00

## 현재 목표
개인 사용 성능 개선 feature의 IMPLEMENT를 이어간다.
지금 초점은 팝오버 열림 지연(SPEC §5.6의 클릭 처리 100ms·팝오버 표시 200ms)을 기준 완화 없이 줄이는 task-008이다.

## 현재 상태
작업 주체가 Codex에서 Claude Code로 바뀌었다.
- task-005 경계 진단은 완료했다. 외부 tap과 앱 mouse-up 수신의 차이는 최대 8.45ms였고, 첫 픽셀 지연(재열림 중앙 102ms·첫 열림 135ms)은 측정 오차가 아닌 실제 앱 지연이다.
- task-008 원인 비교는 완료했고 결과는 `blocked`(정지 반환)다. 제품 코드는 바꾸지 않았다.
  - hosting을 유지하면 재열림 `show` 48.0→12.3ms, 첫 픽셀 103.5→67.6ms로 줄지만, task-004의 "닫힘 시 hosting 회수" 결정을 바꿔야 한다.
  - `animates=false`면 재열림 완전 표시 174.9→91.2ms로 줄지만, spec에 없는 사용자 가시 변경이다.
  - 설계를 바꾸지 않는 경로(카드 `.keyboardShortcut` 비용)는 −3.6ms로 실행 간 변동 안이다.
  - 첫 열림 첫 픽셀은 모든 변형에서 117~125ms였다(변형마다 1회). 시험한 어떤 경로도 첫 열림 100ms를 보여주지 못했다.
- task-001~004는 `[x]`이고, task-008·005·006·007은 `[ ]`다.
- 마지막 검증: task-008은 제품 변경이 없어 단위·UI 테스트와 verify를 하지 않았다. 진단 변형 Release 빌드는 성공했다. task-005 범위의 단위 696/696·영향 UI 56/56·Release UI 1/1은 이전에 통과했다.
- 멈춤 원인: 개선 경로가 설계 변경이나 사용자 가시 변경뿐이라 사용자 결정이 필요하다. 사용자가 (a)·(b)·(c) 중 하나를 고르면 풀린다.
- Git: `main`, 기준 HEAD `e02b3b2`. 이번 세션 끝에 커밋·푸시한다.
- 기존 설치 앱 `/Users/zipkero/Applications/ResourceRunner.app` PID 16136은 유지 중이다. 성능 개선본은 설치하지 않았다.

## 현재 작업 문서
[feature README](./features/20261010-001-release-readiness/README.md), [implement.md task-008](./features/20261010-001-release-readiness/implement.md), [design.md §2.4](./features/20261010-001-release-readiness/design.md), [spec.md](./features/20261010-001-release-readiness/spec.md).

## 확정된 결정
- 100/200ms, Footprint 100,000,000bytes, CPU 1%/3% 기준은 완화하지 않는다. — [design.md §2.4](./features/20261010-001-release-readiness/design.md)
- "완전 표시"는 애니메이션 종료가 아니라 네 카드 값·TOP5 행·그래프가 프레임에서 처음 모두 식별되는 시점이다. — [design.md §2.4](./features/20261010-001-release-readiness/design.md)
- 열림 지연 개선은 task-005 앞의 task-008이 맡고, task-005는 task-008 이후 코드로 다시 판정한다. — [implement.md](./features/20261010-001-release-readiness/implement.md)
- SPEC §5.7은 task-005에서 완성된다(task-007 참조에서 제외). — [implement.md 매핑](./features/20261010-001-release-readiness/implement.md)
- 진단 앱은 격리 bundle ID(`com.zipkero.ResourceRunner.Task005PerfDiagnostic` 등)로만 실행하고, 설치 앱 PID 16136은 건드리지 않는다. 실제 설치는 task-006 승인 뒤 task-007에서만 한다. — [implement.md 머리말](./features/20261010-001-release-readiness/implement.md)

## 미확정 판단
- task-008 진행 경로를 정해야 한다. — [evidence/task-008/README.md](./features/20261010-001-release-readiness/evidence/task-008/README.md)
  - (a) 닫힘 시 hosting 회수를 바꾸는 design 변경. 닫힘 Footprint 61MB가 회귀할 위험이 있다.
  - (b) 팝오버 애니메이션 끄기를 spec에 넣는 사용자 가시 변경.
  - (c) 효과가 확정되지 않은 작은 경로를 별도 Task로 시험한다. ⌘1–4를 key monitor로 다시 구현하거나 아이콘을 미리 읽는 방식이다.
  - (a)+(b)를 함께 고를 수도 있다.
  - hosting을 남기되 빈 화면으로 바꿔 두는 중간안은 측정하지 않았다.
- 첫 열림 100ms를 달성할 경로가 아직 없다. 모든 변형에서 첫 픽셀이 117~125ms였다. — [evidence/task-008/README.md](./features/20261010-001-release-readiness/evidence/task-008/README.md)

## 다음 작업

- 작업: 사용자에게 task-008 경로(a/b/c)를 받아 소유 단계로 반영한다. design 변경은 `/design-init`, spec 변경은 `/spec-init`, Task 조정은 `/implement-init`이다. 그 뒤 implementer로 task-008을 재개한다.
- 완료 기준: task-008이 독립 verify에서 `approved`되는 것이다. 개선 전후 같은 진단 방식에서 첫 픽셀과 완전 표시가 앞당겨지고, 단위·영향 UI·Release UI·Debug/Release 빌드가 skip 0으로 통과하며, 닫힘 Footprint/CPU가 task-004 대비 회귀하지 않아야 한다.

## 먼저 읽을 파일
- [evidence/task-008/README.md](./features/20261010-001-release-readiness/evidence/task-008/README.md) — 이번에 만든 파일
- [boundary-diagnostic/README.md](./features/20261010-001-release-readiness/evidence/task-005/resume-20261011/boundary-diagnostic/README.md) — 이번에 만든 파일
- [implement.md](./features/20261010-001-release-readiness/implement.md) — task-008을 추가하고 매핑을 변경함
- [design.md](./features/20261010-001-release-readiness/design.md) — §2.4에 완전 표시 정의를 추가함
- [evidence/task-004/README.md](./features/20261010-001-release-readiness/evidence/task-004/README.md) — 닫힘 Footprint/CPU baseline

## 문서 반영 필요
없음
