# Context

## 현재 목표

M1(메뉴바 앱과 모니터링 기반)을 마쳤고, M2 core-resource-monitoring의 SPEC 작성으로 넘어가려는 지점입니다.
M2는 실제 CPU·Memory 수집과 대시보드를 다룹니다.

## 현재 상태

M1은 SPEC·ANALYSIS·IMPLEMENT가 모두 완료됐습니다.
Task 8개와 spec.md 완료 조건 8개가 전부 승인·성립했고, `68ced41`까지 main에 푸시됐습니다.
작업 트리는 깨끗합니다.

M2는 아직 시작하지 않았습니다.
`/spec-init core-resource-monitoring`을 실행하기 전에 아래 미확정 판단을 정리해야 합니다.

## 현재 작업 문서

없음. M1 문서는 [features/20260802-001-menu-bar-foundation/](./features/20260802-001-menu-bar-foundation/)에 있고 모든 Task가 `[x]`입니다.

## 확정된 결정

- 최소 지원 macOS는 26.5, Apple silicon 전용입니다.
- 메뉴바 상태 구분은 접근성 값이 아니라 접근성 이름에 담습니다.
  메뉴바 항목의 role이 `Status Menu`라 VoiceOver가 접근성 값을 읽지 않습니다.
  VoiceOver 실제 낭독 확인은 M5 접근성 관문으로 미뤘습니다.
- 화면 잠금 감지는 문서화되지 않은 알림과 세션 키를 쓰되 어댑터 하나에 격리합니다.
  알림 이름이 단일 진실 소스이고, 알림 처리 경로에서 세션 사전을 다시 읽지 않습니다.
- 캐릭터 자산 제작과 애니메이션은 M2에서 실제 부하 값과 함께 다룹니다.
- App Sandbox 접근 범위는 실측을 마쳤습니다. 결과는 [docs/design.md](./docs/design.md) §권한과 배포에 있습니다.

M2 SPEC 작성 전에 2026-08-12에 확정한 항목입니다.

- App Sandbox를 유지합니다. 포기하는 것은 프로세스별 Physical Footprint 하나이고,
  Mac App Store 배포 가능성을 열어 둡니다.
  root 소유 프로세스를 읽지 못하는 제약은 Sandbox와 무관하므로 이 결정으로 달라지지 않습니다.
- 프로세스 CPU 사용률은 코어를 합산하는 Activity Monitor 관례를 따릅니다.
  M5 정확성 검증이 Activity Monitor와 비교하므로 같은 단위를 씁니다.
- Memory Pressure는 문서화된 3단계 신호를 그대로 사용합니다.
  `DispatchSource.makeMemoryPressureSource`와 `kern.memorystatus_vm_pressure_level`로
  정상·경고·위험을 얻을 수 있음을 2026-08-12 probe로 확인했습니다.
  Activity Monitor의 연속 압력 곡선은 계산식이 공개돼 있지 않으므로 따라 그리지 않습니다.
- 최근 그래프는 샘플의 실제 시각을 기준으로 그리고, 수집하지 않은 구간은 비워 둡니다.
  "존재하지 않는 과거를 현재값으로 채우지 않는다"는 기존 버퍼 원칙과 같은 방향입니다.
- 공백을 정직하게 표현하므로 디스플레이 슬립과 빠른 사용자 전환에서도 수집을 중지합니다.
  둘 다 공개 알림이 있어 화면 잠금 어댑터와 달리 문서화되지 않은 신호에 기대지 않습니다.
  시스템 슬립 복귀는 성격이 달라 복귀 첫 샘플을 변화량 기준점으로만 쓰는 문제로 남습니다.

## 미확정 판단

없음.

## 다음 작업

- 작업: `/spec-init core-resource-monitoring`을 실행합니다.
- 완료 기준: `features/<yyyyMMdd>-<nnn>-core-resource-monitoring/spec.md`와 `README.md`가 생성되고,
  위 확정된 결정이 spec.md의 범위·제약·제외 범위·완료 조건 본문에 자체 완결적으로 반영돼 있습니다.

## 먼저 읽을 문서

- [ROADMAP.md](./ROADMAP.md) — M2 완성 결과, 의존 관계와 전환 기준
- [docs/product.md](./docs/product.md) — CPU·Memory 카드, 메뉴바 캐릭터와 대시보드 사용자 흐름
- [docs/design.md](./docs/design.md) — Collector 설계 기준, 수집 일정, 순환 버퍼, 미확정 기술 결정
- [features/20260802-001-menu-bar-foundation/spec.md](./features/20260802-001-menu-bar-foundation/spec.md) — M1이 확정한 실행 환경 사실과 경계

## 문서 반영 필요

없음. 확정된 결정은 모두 [docs/design.md](./docs/design.md)에 반영했습니다.
