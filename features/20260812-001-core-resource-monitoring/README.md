# CPU·Memory 핵심 리소스 모니터링

## 요약

실제 CPU와 Memory 데이터를 수집해 대시보드 팝오버의 두 카드로 설명하고, 앱 단위 TOP 5와 최근 10분 그래프를 제공합니다.
메뉴바 표시 상태도 주입값 대신 실제 CPU 부하를 따르게 합니다.

## 상태

- [x] SPEC
- [x] ANALYSIS
- [ ] IMPLEMENT

## 문서

- [spec.md](./spec.md)
- [analysis.md](./analysis.md) (ANALYSIS 단계에서 생성)
- [implement.md](./implement.md) (IMPLEMENT 단계에서 생성)

## 작업 히스토리

- 2026-08-12: SPEC 작성
- 2026-08-12: ANALYSIS 작성
- 2026-08-13: IMPLEMENT 체크리스트 작성
- 2026-08-15: task-012 실기기 관찰 완료.
  화면 잠금과 디스플레이 슬립 각각에서 두 축의 일정 중지·재개, 중지 구간의 누적 샘플 불변,
  재개 첫 tick의 기준점 전용 갱신, 짧은 중지 6회 반복 재개, 그래프 빈 구간을 확인했습니다.
  **빠른 사용자 전환은 둘째 사용자 계정이 없어 확인하지 못했습니다** — 사용자 판단으로 이 항목만 미확인으로 남기고 완료 처리했습니다.
- 2026-08-15: task-014 완료. 프로세스 조사 축을 production에 배선하고 자리표시 심볼을 제거했습니다.
  Task 순서는 사용자 승인을 받아 task-013보다 먼저 진행했습니다 — task-013이 비교할 프로세스 순위를 task-014가 배선하기 때문입니다.
  실기기 한 세션에서 두 카드 TOP 5 표시, 카드 선택과 복귀, 부하에 따른 메뉴바 이름 전환, 팝오버 개폐에 따른 주기 변경을 함께 관찰했습니다.
  잔여 항목을 기록합니다 — 프로세스 조사 실패가 표시 계층에 도달할 통로가 설계에 없어
  `topApplicationsFailed`가 production에서 항상 `false`입니다(수정 소유 단계 `analyze-init`).
  (Memory TOP 5의 `2.1.233` 표시를 앱 키 유도 결함으로 적었으나 오기였습니다 —
  실행 파일 경로가 `~/.local/share/claude/versions/2.1.233`이라 `.app` 밖 실행 파일 이름을 그대로 쓰는 규칙대로 동작한 것입니다.)
- 2026-08-15: task-004 결함 수정 후 재검증(approved). 실기기에서 CPU TOP 5가 전부 `0%`로 나오는 것을 사용자가 발견했습니다.
  원인은 `proc_pidinfo(PROC_PIDTASKINFO)`의 `pti_total_user`·`pti_total_system`이 나노초가 아니라 mach absolute time tick인데
  `HostProcessSurveyReader`가 나노초로 오인한 것이었습니다. Apple silicon의 timebase가 125/3이라 사용률이 실제의 1/41.67로 축소됐습니다.
  변환을 어댑터 경계에서 한 번 적용하도록 고쳤고 상위 계층은 손대지 않았습니다.
  이 결함이 새어 나간 이유는 테스트 경계가 `ProcessSurveying` 프로토콜에 있어 실제 어댑터가 한 번도 검증되지 않았기 때문이며,
  실기기 회귀 테스트 `realSurveyReportsCPUTimeInNanoseconds()`로 그 구간을 덮었습니다.
  이 수정으로 task-005의 "두 코어를 완전히 쓰는 프로세스가 200%" 조건이 실기기에서 처음 성립했습니다(실측 199.91%).
- 2026-08-15: task-001 결함 수정 후 재검증(approved). task-013 비교에서 Memory 「사용 중」이 Activity Monitor와 10.8% 어긋났습니다.
  Activity Monitor의 공식을 역어셈블로 확정한 결과 구성 항목 넷·스왑·물리 메모리는 앱과 공식이 동일했고,
  「사용 중」만 정의가 달랐습니다(앱은 `app + wired + compressed`, AM은 `total − (free − speculative) − external`).
  사용자 결정으로 AM 공식에 맞췄습니다. 동시 관측에서 일곱 항목 전부 편차 0으로 일치합니다.
  부수 효과로 "사용 중 메모리가 전체 물리 메모리를 넘지 않습니다"가 saturating 뺄셈으로 구조적 보장이 됐습니다 — 옛 합산식에는 상한이 없었습니다.
  관측됐던 와이어드 13.6% 차이는 결함이 아니라 `wire_count`가 초 단위로 0.45 GB 흔들리는 촬영 시점 차이였습니다.
  기록해 둘 위험 — 실기기 단언 `usedBytes > app + wired + compressed`는 불변식이 아니며,
  compressor가 약 4.33 GB를 넘으면 코드가 옳아도 실패할 수 있습니다(정확한 식은 원시값 주입 테스트가 고정).
