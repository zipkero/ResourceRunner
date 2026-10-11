# task-005 검증 인수 결과

2026-10-11 main이 /root/perf_task005_resume_verifier의 독립 판정과 추가 읽기 전용 적용 가능성 판정을 인수했다.

- Status: rejected
- Category: evidence
- 중단: evidence_exhausted
- 구현 재시도: 0 / 근거 재검증: 0. 최초 reject 후 새 측정 없이 SDK/문서만 대조했다.

## 충족한 범위

현재 source127개와 도구·실행 artifact 대응, 단위696/696·영향 UI56/56·Release UI1/1·skip0 및 원본/격리 Debug·Release 빌드. DEBUG 전용 key-window/콜백 관측 hook은 Release에서 제외된다. 상세 출처와 원시 해시는 README.md 및 resume-runtime-manifest-r2.json을 따른다.

## 미충족 근거와 Resolution

1. 실제 mouse-up 전달 경계 또는 PID tap callback과 실제 전달 사이의 개별 오차 상한이 필요하다. 현재 callback에서 읽은 Mach는 대상 앱 수신 시각을 증명하지 못한다. tap 기준 +103.32/+111.65ms 픽셀 부재, +144.98ms 윤곽 및 +186.65/+194.98ms 완전 표시 후보로 실제 전달 기준100/200ms 합격·제품 실패를 확정하지 않는다. 프레임의 displayTime을 사용하며 후행 창 metadata로 대체하지 않는다.
2. 경계가 확보된 후 나머지 첫 열림2회·재열림20회와600초 warm/5회 준비/20회 측정/닫힘60초 중 마지막30초/5회씩4묶음의 반복 자원 근거가 필요하다. 현재 미실행이다.

## 추가 적용 가능성 검토

worker의 로컬 SDK CGEvent.h:251–256,302–318 및 [Apple CGEventTapLocation](https://developer.apple.com/documentation/coregraphics/cgeventtaplocation) 대조는 per-app tap의 delivery-point 위치를 뒷받침한다. 그러나 별도 observer CFRunLoop callback 실행과 대상 앱 queue 수신의 순서/최대 지연은 보증하지 않는다. verifier는 기존 evidence 판정을 유지했다. 이벤트 생성 timestamp·비동기 global monitor·tap 집계 latency는 개별 실제 전달 시각을 대체하지 않는다.

현재 도구/근거로 Resolution을 충족할 수 없어 중단한다. 모든 외부 관측 대안이 불가능하다는 결론은 아니다. 승인 기준을 바꾸지 않고 경계/상한을 증명할 수단이 확보되면 implement-loop를 재개한다. 관측 경계 의미나 허용 오차 계약 변경이 필요하면 design-init 소유 단계에서 먼저 검토·승인하고 영향받는 Task를 implement-init에서 정리한다. 기준을 자동으로 완화하거나 Task를 재분해하지 않았다.

선행001~004의 실제 correctness 회귀는 확인되지 않았으며 승인을 유지한다. task-005와 IMPLEMENT는 미완료,006/007은 미진입이다. 진단 프로세스를 종료했고 기존 설치PID16136/실행 SHA는 유지했다.
