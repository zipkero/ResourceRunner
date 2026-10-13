# Context

저장: 2026-10-13 21:00 +09:00

## 현재 목표
개인 사용 성능 개선 feature의 IMPLEMENT를 이어간다.
다음 초점은 task-005(현재 코드의 기능 보존·반복 수명·첫 열림/재열림 100/200ms 인수)다.

## 현재 상태
task-001~004, task-008(팝오버 애니메이션 끔), task-009(포커스 테두리는 키보드 탐색 때만)가 `[x]`다. task-005·006·007은 `[ ]`다.
- 마지막 검증: task-009 독립 verify approved. 단위 698/698, 새 UI 회귀 1/1, 영향 UI 56/56, Release UI 1/1, skip 0, Debug/Release 빌드 성공.
- 멈춤 원인: task-005의 첫 열림 100ms(첫 픽셀) 기준이 현재 약 119ms라 실패가 예상된다. 사용자가 기준 처리를 정해야 task-005를 시작할 수 있다.
- Git: `main`, 이번 세션 변경을 1eaf321 위에 커밋·푸시했다.
- 설치 앱 `/Users/zipkero/Applications/ResourceRunner.app` PID 16136은 유지 중이다. 성능 개선본은 설치하지 않았다.
- UI 테스트마다 Automation Mode 사용자 인증이 필요하다(인증 요구를 끄지 않기로 함).

## 현재 작업 문서
[feature README](./features/20261010-001-release-readiness/README.md), [implement.md task-005](./features/20261010-001-release-readiness/implement.md), [design.md §2.4](./features/20261010-001-release-readiness/design.md).

## 확정된 결정
- 100/200ms, Footprint 100,000,000bytes, CPU 1%/3% 기준은 사용자 결정 없이 완화하지 않는다. — [design.md §2.4](./features/20261010-001-release-readiness/design.md)
- "완전 표시"는 네 카드 값·TOP5 행·그래프가 프레임에서 처음 모두 식별되는 시점이다. — [design.md §2.4](./features/20261010-001-release-readiness/design.md)
- 본체 팝오버 애니메이션은 끄고(`animates = false`), 열 때마다 hosting을 만드는 구조와 닫힘 Footprint 약 9MB 증가를 수용한다. — [spec.md §3](./features/20261010-001-release-readiness/spec.md), [implement.md task-008](./features/20261010-001-release-readiness/implement.md)
- 카드 포커스 테두리는 키보드 탐색 뒤에만 보인다. — [spec.md §3](./features/20261010-001-release-readiness/spec.md)
- SPEC §5.7은 task-005에서 완성된다. — [implement.md 매핑](./features/20261010-001-release-readiness/implement.md)
- 진단·UI 실행은 격리 bundle ID(`com.zipkero.ResourceRunner.Task005UITest` 등)로만 하고, 실제 설치는 task-006 승인 뒤 task-007에서만 한다. — [implement.md 머리말](./features/20261010-001-release-readiness/implement.md)

## 미확정 판단
- 첫 열림 100ms 기준 처리: 다른 메뉴바 앱(Wi-Fi·제어 센터 등)과 비교 측정할지, 100ms 종료 시점을 "첫 픽셀"에서 "show 반환" 등으로 재정의할지(`/design-init`), 그대로 두고 task-005에서 판정할지. — [evidence/task-008/retry-3](./features/20261010-001-release-readiness/evidence/task-008/retry-3/)
- 상세를 닫은 직후 120ms 안의 Tab 입력을 지연된 포커스 복귀(`scheduleFocusReturn`)가 덮어쓰는 기존 동작을 후속으로 고칠지. — [evidence/task-009/README.md](./features/20261010-001-release-readiness/evidence/task-009/README.md)

## 다음 작업

- 작업: 사용자에게 첫 열림 100ms 기준 처리를 받아 필요하면 소유 단계(`/spec-init`·`/design-init`)로 반영한 뒤, implementer로 task-005를 재개한다.
- 완료 기준: task-005가 독립 verify에서 `approved`되는 것이다(implement.md task-005 검증 조건).

## 먼저 읽을 파일
- [implement.md](./features/20261010-001-release-readiness/implement.md) — task-008·009 승인 근거를 더함
- [evidence/task-008/retry-3](./features/20261010-001-release-readiness/evidence/task-008/retry-3/) — 첫 열림 교대 측정
- [evidence/task-009/README.md](./features/20261010-001-release-readiness/evidence/task-009/README.md) — 이번에 만든 파일
- [design.md](./features/20261010-001-release-readiness/design.md) — §2.1·§2.4를 고침
- [spec.md](./features/20261010-001-release-readiness/spec.md) — §3에 두 줄을 더함

## 문서 반영 필요
없음
