# Context

저장: 2026-08-16 11:03

## 현재 목표

M2 core-resource-monitoring feature가 완료됐습니다.
문서 동기화와 남아 있는 설계 쟁점의 처리 방향을 정한 뒤 다음 마일스톤으로 넘어갑니다.

## 현재 상태

feature `20260812-001-core-resource-monitoring`의 14개 Task가 모두 `[x]`이고 SPEC·ANALYSIS·IMPLEMENT 단계가 모두 완료입니다.
`main`에 푸시까지 마쳤고(`eb90d02`) 작업 트리는 clean입니다.

이 세션에서 task-013 실기기 비교가 단위 테스트를 모두 통과하던 결함 두 개를 잡아 고쳤습니다 —
프로세스 CPU 시간을 mach absolute time tick이 아닌 나노초로 오인해 값이 41.67배 축소되던 문제(`1fdaa6c`),
Memory 「사용 중」이 Activity Monitor와 다른 공식을 쓰던 문제(`ae9cf7b`).
두 결함 모두 회귀 테스트를 붙였고 고친 부분을 되돌리면 그 테스트만 실패하는 것까지 확인했습니다.
task-001·task-004는 수정 후 verifier가 재검증해 `approved`입니다.

마지막 검증은 격리 DerivedData로 실행한 전체 테스트(`ResourceRunnerTests` + `ResourceRunnerUITests`)이며
`** TEST SUCCEEDED **`, 256건 통과, 실패 0건입니다.
task-013 실기기 관측은 세 시나리오(유휴 / 논리 코어 14개 `yes` 부하 / 4 GB 메모리 할당)를 각 3회 수행했습니다.

## 현재 작업 문서

없음. feature가 완료돼 활성 Task가 없고 다음 feature 문서는 만들지 않았습니다.

## 확정된 결정

- Memory 「사용 중」을 Activity Monitor 공식(`total − (free − speculative) − external`)에 맞춥니다.
  [README.md](./features/20260812-001-core-resource-monitoring/README.md) 작업 히스토리와
  `ResourceRunner/MemorySystemMetricsCollector.swift`에 반영돼 있습니다.
- task-013 부하 시나리오에서 「프로세스 순위 상위 3개 집합이 `top`과 일치」의 2·3위 불일치는
  편차로 기록하고 통과 처리합니다. 도구별 표본 창 차이가 원인이고 앱의 평활화는 task-006이 요구한 동작입니다.
  [README.md](./features/20260812-001-core-resource-monitoring/README.md)에 사유와 함께 기록돼 있습니다.
- task-012의 빠른 사용자 전환은 둘째 사용자 계정이 없어 미확인으로 남기고 완료 처리합니다.
  [README.md](./features/20260812-001-core-resource-monitoring/README.md)에 기록돼 있습니다.
- task-014를 task-013보다 먼저 진행합니다. task-013이 비교할 프로세스 순위를 task-014가 배선하기 때문입니다.
  [README.md](./features/20260812-001-core-resource-monitoring/README.md)에 기록돼 있습니다.

## 미확정 판단

- 프로세스 조사 실패가 표시 계층에 도달할 통로가 없어 `topApplicationsFailed`가 production에서 항상 `false`입니다.
  현재 동작은 "조사가 실패해도 직전 순위가 정상인 것처럼 계속 표시된다"입니다.
  `SPEC §5.10` 문장 자체는 성립하고 깨지는 것은
  [analyze.md](./features/20260812-001-core-resource-monitoring/analyze.md) §2 「실패 경로」의
  "프로세스 조사 실패는 두 카드의 TOP 5만 실패로 바꾼다"입니다.
  Scheduler가 source 예외에서 tick을 건너뛰고 `ProcessSurveySample`에 실패 필드가 없어 계약을 새로 정해야 하므로
  `수정 소유 단계`는 `analyze-init`입니다.
  선택지는 셋 — 조사 실패를 값으로 바꾸기, Scheduler가 실패를 알리기, 스토어가 신선도를 판정하기.
- CPU tick 간격 판정 기준(ANALYSIS §5 DP11)이 코드와 문서에서 여전히 어긋납니다.
  구현은 예상 주기와 무관한 절대 상수(`SystemMetricsSampling.maximumTickGap`, 10초)인데
  [implement.md](./features/20260812-001-core-resource-monitoring/implement.md) task-001 접근 필드는
  "예상 주기의 허용 배수"를 요구합니다.
  task-013·task-012 관측에서는 문제가 드러나지 않았고 두 Task 모두 통과했습니다.
- 경미 지적 세 건의 처리 여부.
  이력 링 용량이 1초 주기에서 599초만 담는 것(`ResourceRunner/MonitoringSampleStore.swift:31`),
  `mach_host_self()` 참조 미해제(`ResourceRunner/CPUSystemMetricsCollector.swift:39`,
  `ResourceRunner/MemorySystemMetricsCollector.swift:87`·`:100`),
  주석의 계획 식별자와 M1 시절 Task 번호가 M2에서 다른 Task를 가리키는 것.
- 다음 마일스톤 M3(Network·Disk 확장 리소스 모니터링) 착수 여부와 시점.
  [ROADMAP.md](./ROADMAP.md) §M3에 전환 기준과 feature 문서 후보명 `extended-resource-monitoring`이 있습니다.

## 다음 작업

- 작업: [ROADMAP.md](./ROADMAP.md) 마일스톤 상태표의 M2 행을 갱신합니다.
- 완료 기준: M2 행의 상태가 `완료`이고 현재 근거가 이번 feature의 실제 결과로 교체됩니다.
  어느 방향으로 이어가든 필요한 문서 동기화라 먼저 둡니다.
  이후 진행 방향(§미확정 판단의 `topApplicationsFailed` 처리 / M3 착수)은 사용자가 정합니다.

## 먼저 읽을 문서

- [ROADMAP.md](./ROADMAP.md) — 마일스톤 상태표, §M3 전환 기준
- [features/20260812-001-core-resource-monitoring/README.md](./features/20260812-001-core-resource-monitoring/README.md) — 이번 feature의 결과와 기록된 편차
- [features/20260812-001-core-resource-monitoring/analyze.md](./features/20260812-001-core-resource-monitoring/analyze.md) — §2 「실패 경로」, §3 「프로세스와 앱 계약」

## 문서 반영 필요

- [ROADMAP.md](./ROADMAP.md) 마일스톤 상태표의 M2 행이 아직 `예정`이고 근거가
  "CPU·Memory Collector, 대시보드와 캐릭터 애니메이션 미구현"으로 남아 있습니다.
- [implement.md](./features/20260812-001-core-resource-monitoring/implement.md) task-001 접근 필드의
  "예상 주기의 허용 배수"가 실제 구현(절대 상수 10초)과 다릅니다. 방향이 정해지기 전이라 고치지 않았습니다.
