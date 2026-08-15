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
  잔여 항목 둘을 기록합니다 — Memory TOP 5에 앱 이름 대신 버전 문자열(`2.1.233`)이 나오는 경로가 있고(ANALYSIS §5 DP5 앱 키 유도),
  프로세스 조사 실패가 표시 계층에 도달할 통로가 설계에 없어 `topApplicationsFailed`가 production에서 항상 `false`입니다(수정 소유 단계 `analyze-init`).
- 2026-08-15: task-004 결함 수정 후 재검증(approved). 실기기에서 CPU TOP 5가 전부 `0%`로 나오는 것을 사용자가 발견했습니다.
  원인은 `proc_pidinfo(PROC_PIDTASKINFO)`의 `pti_total_user`·`pti_total_system`이 나노초가 아니라 mach absolute time tick인데
  `HostProcessSurveyReader`가 나노초로 오인한 것이었습니다. Apple silicon의 timebase가 125/3이라 사용률이 실제의 1/41.67로 축소됐습니다.
  변환을 어댑터 경계에서 한 번 적용하도록 고쳤고 상위 계층은 손대지 않았습니다.
  이 결함이 새어 나간 이유는 테스트 경계가 `ProcessSurveying` 프로토콜에 있어 실제 어댑터가 한 번도 검증되지 않았기 때문이며,
  실기기 회귀 테스트 `realSurveyReportsCPUTimeInNanoseconds()`로 그 구간을 덮었습니다.
  이 수정으로 task-005의 "두 코어를 완전히 쓰는 프로세스가 200%" 조건이 실기기에서 처음 성립했습니다(실측 199.91%).
