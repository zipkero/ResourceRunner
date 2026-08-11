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

## 미확정 판단

- CPU 정규화 단위와 Memory Pressure의 공개 정보 사용 방식. [docs/design.md](./docs/design.md) §미확정 기술 결정
- App Sandbox 유지 여부와 직접 배포 기준. 접근 범위 실측은 끝났고 결정만 남았습니다. [docs/design.md](./docs/design.md) §미확정 기술 결정
- 수집이 중지됐다 재개된 구간을 최근 그래프에서 어떻게 보여줄 것인가.
  버퍼가 시간 기준으로 축출하지 않아 범위를 벗어난 샘플이 남습니다. [docs/design.md](./docs/design.md) §최근 데이터 순환 버퍼
- 디스플레이 슬립·빠른 사용자 전환·시스템 슬립 복귀를 생명주기 입력으로 다룰지와 그 시점.
  세 상태 모두 공개 알림이 있으며, 앞의 둘은 화면 잠금과 같은 처리가 자연스럽지만 위 그래프 공백 표현과 함께 정해야 합니다. [docs/design.md](./docs/design.md) §생명주기 반영

## 다음 작업

- 작업: 위 미확정 판단 넷을 사용자와 정리한 뒤 `/spec-init core-resource-monitoring`을 실행합니다.
- 완료 기준: `features/<yyyyMMdd>-<nnn>-core-resource-monitoring/spec.md`와 `README.md`가 생성되고,
  정리한 판단이 spec.md의 범위·제약·제외 범위·완료 조건 본문에 반영돼 있습니다.

## 먼저 읽을 문서

- [ROADMAP.md](./ROADMAP.md) — M2 완성 결과, 의존 관계와 전환 기준
- [docs/product.md](./docs/product.md) — CPU·Memory 카드, 메뉴바 캐릭터와 대시보드 사용자 흐름
- [docs/design.md](./docs/design.md) — Collector 설계 기준, 수집 일정, 순환 버퍼, 미확정 기술 결정
- [features/20260802-001-menu-bar-foundation/spec.md](./features/20260802-001-menu-bar-foundation/spec.md) — M1이 확정한 실행 환경 사실과 경계

## 문서 반영 필요

없음.
