# Context

## 현재 목표

M2 core-resource-monitoring의 IMPLEMENT를 진행 중입니다.
시스템 지표 수집 축(task-001~003)까지 마쳤고, 그 과정에서 드러난 tick 간격 판정 기준을 확정한 뒤 프로세스 조사 축으로 넘어갑니다.

## 현재 상태

task-001·task-002·task-003을 구현하고 각각 verifier agent가 `approved`로 판정해 체크박스가 `[x]`입니다.
task-004 이후는 시작하지 않았습니다.

이후 main이 직접 검토해 확인한 것입니다.

- 격리 DerivedData로 전체 빌드·테스트를 실행해 `** TEST SUCCEEDED **`, error 0건, 139건 통과입니다.
  IDE SourceKit 진단 오류는 인덱스 문제이고 실제 빌드에서 재현되지 않습니다.
  남은 warning 8건은 발생 지점이 모두 M1 기존 코드이고 이번 세 Task가 새로 만든 것은 없습니다.
- task-001의 CPU tick 간격 판정이 ANALYSIS §5 DP11 채택안에서 벗어났습니다.
  두 verifier는 이를 "남은 위험"으로만 처리했고 승인을 막지 않았습니다.

작업 트리는 커밋되지 않은 상태입니다.

## 현재 작업 문서

[features/20260812-001-core-resource-monitoring/implement.md](./features/20260812-001-core-resource-monitoring/implement.md) — task-001~003이 `[x]`, 다음 미완료는 task-004입니다.

## 확정된 결정

- M2 SPEC 작성 전에 확정한 판단 다섯(Sandbox 유지, 코어 합산 CPU 단위, Memory Pressure 3단계,
  시각 기준 그래프와 빈 구간, 디스플레이 슬립·빠른 사용자 전환 중지)은
  [spec.md](./features/20260812-001-core-resource-monitoring/spec.md) §제약과 §완료 조건에 반영돼 있습니다.
- task-002의 접근 이탈(저장소가 `SystemMetricsSample` 전용이 되면서 코디네이터 배선을 실제 source로 교체,
  `MonitoringSampleSink` 제네릭 전파)은 implement.md task-002 접근 필드에 반영했습니다.

## 미확정 판단

- CPU tick 간격 판정 기준.
  구현은 예상 주기와 무관한 절대 상수 10초(`ResourceRunner/CPUSystemMetricsCollector.swift:116`)인데,
  [analysis.md](./features/20260812-001-core-resource-monitoring/analysis.md) §5 DP11 채택안과
  implement.md task-001 접근 필드는 "예상 주기의 배수"를 요구합니다.
  1초 주기에서 5초 중지가 일어나면 재개 첫 tick의 경과 시간이 약 6초라 상한 안에 들어와
  중지 구간이 하나의 변화량에 섞이며, 이는 implement.md task-012 검증 조건과 SPEC §5.11에 걸립니다.
  선택지는 셋입니다 — 유효 주기를 Collector까지 전달(ANALYSIS §3·DP11 재작성 필요),
  관측된 직전 간격에서 주기 추론(계약 유지, 주기 변경 직후 한 tick 어긋남),
  절대 상수 유지하고 task-012 검증 조건 완화(spec.md까지 영향).
  main은 첫째를 권했고 사용자 결정은 아직 없습니다.
- 위 판정에 따른 task-001 체크박스 유지 여부.
  정식 verify가 아닌 검토에서 나온 지적이라 `[x]`를 그대로 두었습니다.
- 경미 지적 세 건의 처리 여부.
  이력 링 용량이 1초 주기에서 599초만 담는 것(`ResourceRunner/MonitoringSampleStore.swift:41`),
  `mach_host_self()` 참조 미해제(`ResourceRunner/CPUSystemMetricsCollector.swift:39`,
  `ResourceRunner/MemorySystemMetricsCollector.swift:52`),
  주석의 계획 식별자와 M1 시절 Task 번호가 M2에서 다른 Task를 가리키는 것(`ResourceRunner/MonitoringScheduler.swift:60`).

## 다음 작업

- 작업: CPU tick 간격 판정 기준을 위 세 선택지 중 하나로 확정합니다.
- 완료 기준: 선택한 방향이 analysis.md §5 DP11에 반영되고,
  implement.md task-001 접근 필드가 실제 판정 방식과 일치하며,
  task-001 체크박스를 `[x]`로 둘지 `[ ]`로 되돌릴지가 정해집니다.
  이 결정이 끝나면 task-004로 넘어갑니다.

## 먼저 읽을 문서

- [features/20260812-001-core-resource-monitoring/analysis.md](./features/20260812-001-core-resource-monitoring/analysis.md) — §5 DP11, §2 「시스템 지표 tick」
- [features/20260812-001-core-resource-monitoring/implement.md](./features/20260812-001-core-resource-monitoring/implement.md) — task-001 접근 필드, task-012 검증 조건, task-004
- [features/20260812-001-core-resource-monitoring/spec.md](./features/20260812-001-core-resource-monitoring/spec.md) — §5.11, §5.12

## 문서 반영 필요

- task-001의 실제 판정 방식(절대 상수 10초)이 implement.md task-001 접근 필드와 다릅니다.
  방향이 정해지기 전이라 문서를 고치지 않았습니다.
- task-003이 프로세스 축 자리표시로 `PlaceholderMonitoringSampleSink`를 새로 뒀는데,
  implement.md task-014 접근 필드의 자리표시 제거 대상 목록에 이 심볼이 없습니다.
