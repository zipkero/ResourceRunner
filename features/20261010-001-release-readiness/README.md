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

[task-008](./implement.md): 팝오버 열림 지연의 원인 확정과 제품 최적화.
Task 8개 중4개 승인. task-008은 `blocked`(정지 반환)이며 제품 코드는 바꾸지 않았습니다. 사용자 결정이 필요합니다: (a) 닫힘 시 hosting 회수를 바꾸는 design 변경, (b) 팝오버 애니메이션 끄기를 spec에 넣는 사용자 가시 변경, (c) 효과 미확정인 작은 경로를 별도 Task로 시험. 근거는 [evidence/task-008](./evidence/task-008/README.md)입니다.
task-005는 task-008 이후 코드로 다시 판정합니다.

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

- 2026-10-11: 사용자 진행 요청으로 task-005 재개와 UI Automation 인증 절차 진행을 승인했습니다.
  격리 signed UI smoke가 인증 대기 없이 실제 automation session에서1/1·skip0로 통과했습니다.
  기존 설치 앱을 유지하고 영향 UI 직렬 suite를 시작했습니다. task-005 미승인·재시도0·근거 재검증0, 선행 기준·승인은 유지합니다.
- 2026-10-11: 첫 영향 UI54/55·skip0의 포커스 실패와 단독 재현을 보존했습니다. assertion 시각의 독립 AX에서 설정 창·요소 포커스 유지가 확인됐으나 runner 문자열/hasFocus 관측은 불일치했습니다.
  main이 DEBUG·`--settings-ui-test` 전용 read-only `isKeyWindow` 접근성 관측과 정·부 조건 검증을 task-005 관측 보완 범위로 확정했습니다.
  제품의 일반 실행·Release 동작과 승인 기준은 유지합니다. 보완 단독2/2·skip0 이후 현재 입력 전체 검증을 진행하며 task-005 승인·formal 완료로 확대하지 않습니다.

- 2026-10-11: task-005 현재 단위696/696·영향 UI56/56·Release UI1/1·skip0와 Debug/Release 빌드 근거를 인수했습니다. 시험 관측/fixture를 보완했고 일반 Release 동작의 추가 최적화는 하지 않았습니다.
  첫 공식 시도의 도구 종료 뒤 클릭은 무효 이력으로 보존하고 단일 driver로 보완했습니다. 새 PID29449의630.438초 warm 후 첫 열림 원시·픽셀 crop·해시를 확보했습니다.
  독립 verifier는 실제 전달과 tap callback 오차 상한 및 나머지 cohort 부족으로 evidence rejected를 반환했습니다. SDK/Apple delivery-point 설명 추가 대조 후에도 판정이 유지됐습니다.
  구현 재시도0·근거 재검증0이며 현재 관측 수단으로 Resolution을 충족하지 못해 evidence_exhausted로 중단합니다. 기준 의미와 SPEC/DESIGN·001~004 승인을 유지하고 task-005/IMPLEMENT는 미완료로 둡니다. 진단 프로세스를 정리하고 기존 설치PID16136을 유지했습니다.
- 2026-10-11: Claude Code로 이어받아 task-005 경계 진단을 수행했습니다(evidence/task-005/resume-20261011/boundary-diagnostic/). tap과 앱 mouse-up 수신 차이는 최대8.45ms이며 첫 픽셀 지연(재열림 중앙102ms·첫 열림135ms)은 실제 앱 지연입니다. 주된 구간은 `popover.show` 동기 호출(35~80ms)입니다.
  사용자 결정으로 DESIGN §2.4에 완전 표시를 "네 카드 값·TOP5 행·그래프가 프레임에서 처음 모두 식별되는 시점"으로 명시했습니다(기존 문언의 해석 확정, 기준 완화 없음). 영향 Task005~007은 모두 미승인이라 되돌린 승인은 없습니다.
  IMPLEMENT 체크리스트에 task-008(열림 지연 원인 확정·최적화)을 task-005 앞에 추가하고, 사용자 결정으로 §5.7 완성 자리를 task-005로 옮겼습니다(task-007 참조에서 §5.7 제거). task-001~004 승인 유지, IMPLEMENT 미완료.

- 2026-10-11: task-008 원인 비교(진단 사본, 변형별 첫 열림1회·재열림18회)를 인수했습니다. 재열림 `show` 동기 비용의 주원인은 열 때마다 새로 만드는 hosting의 SwiftUI graph 생성이고, 완전 표시까지 가장 긴 구간은 NSPopover 열림 애니메이션입니다.
  hosting 유지는 재열림 첫 픽셀 103.5→67.6ms, `animates=false`는 재열림 완전 표시 174.9→91.2ms였으나 각각 DESIGN 결정 변경·사용자 가시 변경이라 Task 정지 조건에 따라 구현하지 않았습니다. 첫 열림 첫 픽셀은 모든 변형에서 117~125ms(각1회)였습니다.
  제품 변경·verify 없음. task-008 `blocked`, 선행 승인 유지, IMPLEMENT 미완료.
