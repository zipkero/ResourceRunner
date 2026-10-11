# 개인 사용 성능 개선

## 개요

개인 Mac에서 상시 실행하는 ResourceRunner의 CPU·메모리 비용을 줄이는 ROADMAP M5의 첫 Phased 범위입니다.
원인 조사·동일 조건 전후 측정·기능 보존·실제 설치 앱 반영을 수행하며 M5 전체 완료와 구분합니다.

## 상태

- [x] SPEC
- [x] DESIGN
- [ ] IMPLEMENT

## 문서

- [spec.md](./spec.md)
- [design.md](./design.md)
- [implement.md](./implement.md)

## 다음 Task

[task-005](./implement.md): 현재 기능과 반복 수명·반응 시간 인수.
Task 7개 중4개 승인. 제품의 닫힘 hosting 보유 감소와 관련 화면 경계를 확인했으며 전체 성능 목표는 아직 미충족입니다.
현재 task-005는 macOS `Enable UI Automation` 사용자 인증이 필요해 `blocked`입니다. 전체 단위696/696·skip0와 Debug/Release는 통과했으나 UI·반복·공식 반응 시간은 미검증입니다.

## 이력

- 2026-10-10: 사용자 Phased 착수 요청과 기존 ROADMAP 성능 목표·기능 보존 정책으로 SPEC 작성·main 확정.
  메모리는 현재 문제 관찰에 사용한 앱 외부 Physical Footprint로 측정하고 RSS를 별도 보고합니다.
  M5의 성능 개선 첫 범위이며 기존 M1~M4 승인·과거 증거는 변경하지 않았습니다.
  실제 후속 코드 변경의 영향은 새 Task의 회귀 검증에서 판정합니다.
- 2026-10-10: analyzer 설계 후보를 main이 검토·적용하여 DESIGN 확정. 7개 창 상태의 동일 조건 비교,
  요소별 원인 조사, 최신 캐시 보존과 화면 작업 분리, 실제 설치 경로 검증을 채택했습니다.
  SPEC과 기존 기능 승인을 유지하며 성능 목표 달성·제품 최적화는 아직 미검증입니다.
- 2026-10-10: implement-init analyzer 후보를 main이 검토·적용했습니다. 조사/제품 개선/회귀·반복/
  사전 성능/실제 설치의7개 Task로 완료 조건8개를 모두 매핑했습니다. SPEC/DESIGN 승인은 유지하고
  Task와 IMPLEMENT는 미완료로 둡니다. 기존 기능 승인 무효화는 없으며 코드 변경 후 영향 검증을 수행합니다.
- 2026-10-10: task-001 worker 결과를 인수하고 독립 verifier approved를 main이 확정했습니다.
  원본170파일 해시·Release 출처·외부 도구 및 실제 CPU 단위를 검증했습니다. 설치 앱 세션을 유지했습니다.
  SPEC/DESIGN과 기존 승인 유지, IMPLEMENT 미완료. 재시도/근거 재검증0회. 다음 task-002.
- 2026-10-10: task-002 worker 결과와 독립 verifier approved를 main이 인수했습니다. 원본7상태21개
  유효 실행·6,321표본·출처·기본값·별도 동작/프로파일·설치 앱 보존을 확인했습니다.
  Network AX 판별 보완의 v1/v2 해시 적용 설명을 원시 출처와 일치하게 정정했습니다.
  요구사항·설계·Task 의미와 선행 승인은 유지합니다. 원본 목표 미달을 개선 완료로 해석하지 않으며
  IMPLEMENT는 미완료, 구현 재시도/근거 재검증0회, 다음 task-003입니다.
- 2026-10-10: task-003 worker 결과와 독립 verifier approved를 main이 확정했습니다. 같은 조건의
  원본/후보3쌍에서 닫힘 Footprint 최대가 약424MB→63MB로 줄고 graphics 보유 감소에 대응했습니다.
  hosting 수명 후보를 채택하며 CPU 감소폭과 열린 상태 비용은 미확정으로 남깁니다. 후보 닫힘 CPU도
  1% 목표 미달이며 전체 성능 승인이 아닙니다. 제품·선행 기준/승인은 유지하고 진단 실행을 정리했습니다.
  IMPLEMENT 미완료, 구현 재시도/근거 재검증0회, 다음 task-004입니다.
- 2026-10-10: task-004 제품 변경의 54개 영향 테스트와 신규 닫힘3쌍에서 Footprint 최대 약420MB→61MB를 확인했습니다.
  독립 verifier는 이전 AnchorView 해제 경로의 session 검사 누락으로 rejected를 반환했고 main이 확정했습니다.
  task-004/IMPLEMENT는 미완료이며 구현 재시도1·근거 재검증0으로 경계 수정과 새 빌드/측정을 진행합니다.
  기존 측정은 수정 전 artifact 근거로 보존합니다. SPEC/DESIGN·task-001~003 승인과 설치 앱은 유지합니다.

- 2026-10-10: task-004 재시도1의 최종 소스·56개 영향 테스트·신규 닫힘3쌍과 독립 verifier approved를 main이 인수했습니다.
  이전 앵커 session 및 새 열림의 보정 Task 경계를 보완하고 Footprint 최대419.27~421.64MB→60.92~61.02MB 감소를 확인했습니다.
  CPU2.52~2.53%는 목표 미달이며 전체 기능/반복/반응·실제 설치는 미완료입니다. SPEC/DESIGN·task-001~003 승인과 설치 앱을 유지합니다.
  이전 reject는 해결됐고 이력 근거를 보존합니다. 구현 재시도1·근거 재검증0, IMPLEMENT 미완료, 다음 task-005입니다.
- 2026-10-10: task-005 전체 단위696/696·skip0, Debug/Release 성공과 외부 계측 사전시험을 인수했습니다.
  격리 UI 러너는 testmanagerd의 `Enable UI Automation` 인증 요구로 실제 테스트 시작 전 대기했습니다.
  사용자에게 인증 진행 여부를 요청하고 임시 프로젝트·실행 프로세스를 정리했습니다. 기존 설치 앱과 승인Task001~004는 유지합니다.
  task-005는 blocked·미승인, 구현 재시도0·근거 재검증0이며 task-006/007은 미진입입니다.
  인증 완료 후 같은 소스의 격리 UI와 반복·외부100/200ms 검증을 재개합니다.
