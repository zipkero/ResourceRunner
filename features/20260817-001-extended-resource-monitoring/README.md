# Network·Disk 확장 리소스 모니터링

현재 상태: Disk 기준 변경의 여섯 Task 재검증과 실제 Wi-Fi 끊김·복귀, 잠금·절전·디스플레이 복귀 및 최종 통합 검증을 독립 승인했습니다. 철회 task009/§5.17을 제외한 모든 적용 Task와 완료 조건이 성립하여 IMPLEMENT를 완료했습니다. 다른 계정·VPN·외장·유선 LAN 전환 실시험은 사용자 제외 범위입니다. 아래 날짜별 문단의 과거 보류·미승인 설명은 이력입니다.

- 2026-10-09: 사용자 요청으로 Disk 기준 변경 Task와 task015 검증을 재개했습니다. task002는 현재 소스SHA/개정 용량 단위48·UI1 근거와 새 Sandbox 원자료를 독립 verify해 승인 복구했습니다. 구현 재시도0·근거 재검증0, 제품 변경·suite 재실행 없음. 나머지006/008/011/013/018과015는 아직 미승인입니다. 사용자 선택으로 다른 계정 전환 실제 시험을 제외하며 잠금·절전·디스플레이 중지/복귀는 실행 범위에 포함했습니다. 기존 SPEC/DESIGN 및 영향 없는 승인은 유지합니다.
- 2026-10-09 현재: task-014의 실제 Wi-Fi 끊김·복귀 검증을 완료했습니다. Off 상세 AX 보완과 원본 계약 재검토 후 독립 verifier의 approved를 main이 확정했습니다. 마지막 매핑이 끝난 SPEC §5.5도 성립합니다. 구현 재시도0·근거 재검증1. 최초 evidence reject는 이력으로 보존하며 현재 해소됐습니다. 원문에 없던 전체 disconnected 출력·대표 유효점 존재 요구는 정정했고 승인 기준은 바꾸지 않았습니다. 제품 코드 변경·suite 재실행 없이 실제 카드·상세·baseline/lifetime/segment·복귀 속도와 현재 소스에 대응하는 M4 단위86 통과 근거를 대조했습니다. task-014 [x], IMPLEMENT [ ]; Disk 재검증6개·task-015 보류·M4 완료는 유지합니다. Wi-Fi는 원래 연결로 복구됐고 임시 진단 앱·watchdog은 종료했습니다. [최종 보완 근거](./evidence/task-014/wifi-offdetail-20261009/README.md).

- 2026-10-03 현재: 스크롤 없는 네 요약 카드와 Memory 여백 수정, 실제 화면·키보드·접근성, Network·Disk 시스템 도구 변화 방향 비교, 임시 관찰 코드 정리와 통합 검증(task-018)을 완료했습니다. 2026-10-09 사용자 지시로 task-014의 실제 VPN·외장 디스크 시험을 제외했습니다. 유선 LAN 시험도 제외했으며 Wi-Fi 끊김/복귀는 아래 실제 시험과 evidence reject 상태, task-015 잠금·절전 복귀 사용자 보류는 유지합니다. IMPLEMENT는 미완료입니다.

## 개요

Network·Disk의 현재 속도와 인터페이스·장치·볼륨 정보를 추가합니다.
Network 요약은 수치를 표시하고 Disk 요약은 수치 옆 최근 10분 미니 그래프를 표시합니다.
CPU·Memory와 함께 네 카드를 지원 화면에서 일관되게 사용할 수 있도록 본체 배치와 수집 경계를 확장합니다.

## 상태

- [x] SPEC
- [x] DESIGN
- [x] IMPLEMENT

## 문서

- [spec.md](./spec.md)
- [design.md](./design.md)
- [implement.md](./implement.md)

## 이력

- 2026-10-09: task018 독립 approved를 main이 확정해 Disk 영향 여섯 Task의 승인 복구를 완료했습니다. 현재127파일SHA·전체단위674/674·Debug/Release, 전체UI48/54·실패0·skip6과 Release접근 별도1/1·기존native로그인5/5 인수의 구분, 정상Release 한세션 네카드/네상세/실제CPU 메뉴바 상승·회복 및 production 구성을 확인했습니다. 구현 재시도0·근거 재검증0. 마지막 매핑 조건이 모두 성립하여 IMPLEMENT[x]로 전환했습니다. 기존 제외·철회 이력 유지, 이후 M4 확장 변경은 해당 Task에서 영향 검증합니다.

- 2026-10-09: task015 실제잠금·디스플레이·systemsleep/wake를독립approved/main확정했습니다. 같은세션6축중지반영0·첫기준점/둘째실초속도·epoch/segment·CPU/Disk공백·현재674단위결정적회귀와sourceSHA충족, SPEC §5.9 성립. 다른계정실시험제외·Network대표nil/부분속도경계유지·Memory구성/Swap실측을정확히구별합니다. user직접unlock완료·임시진단cleanup·설정/안정앱보존. task018최종통합만남아 IMPLEMENT[ ].

- 2026-10-09: task013 독립 approved를main이확정해승인복구했습니다.20파일SHA·현재M4키보드/viewport/UI17·18과새DiskUI3 근거인수범위를대조했습니다. 추가runnerstartup정체의0case는성공으로계산하지않았습니다. Disk재검증5/6완료·018잔여,015실제잠금중지확보/사용자unlock대기. 기존승인유지·IMPLEMENT[ ].

- 2026-10-09: task011 독립 재판정 approved를 main이 확정해 승인복구했습니다. 최초 evidence reject의 잘못된 suite선택자는 실제8suite42/42로 보완, 기존26/26·signedUI3/3·현재18SHA·Debug/Release·정상light/dark/실제PNG와 함께충족됐습니다. 구현재시도0·근거재검증1. Disk002/006/008/011 완료,013/018과실제015가남습니다.

- 2026-10-09: task008 독립 approved를 main이 확정해 승인을 복구했습니다. 현재 집중36/36·CPU/Memory24/24·소스별SHA와 native/cache/AX 인수 경계가 충족됐고 마지막 매핑 SPEC §5.7이 성립합니다. task002/006/008 완료, Disk011/013/018과 실제015가 남습니다. 제품코드 무변경, 재시도0·근거재검증0.

- 2026-10-09: task006 독립 approved를 main이 확정해 승인을 복구했습니다. 집중31/31·동일 핵심 소스·signed Sandbox 용량 캐시/실제 차분 근거를 대조했습니다. task002/006 완료, Disk 재검증008/011/013/018이 남았습니다. 사용자 최신 지시로 task015 실제 잠금·절전·디스플레이 복귀를 재개하고 다른 계정 전환 실시험만 SPEC/DESIGN/Task에서 제외했습니다. 기존 승인과 세션 비활성 결정적 계약 유지, SPEC/DESIGN [x], IMPLEMENT [ ].

- 2026-10-03: task018 독립 FINAL approved를 main이 확정했습니다. 임시 DEBUG probe 제거 후 unit614/614·Debug/Release 통과, 서명 UI 전체29/30 뒤 실제 AXValue를 검사하도록 단언만 보완한 해당1/1 통과를 인수했습니다. 정상 Sandbox 앱 한 세션의 네 카드·상세·끝 페이지·실제 CPU 부하 메뉴바 반응과 최종 해시·production 구성을 확인했습니다. SPEC §5.1·§5.2·§5.10·§5.12·§5.14·§5.16을 충족하지만 보류014/015와 IMPLEMENT는 미완료입니다. 사용자 승인대로 main에 스테이징·커밋·푸시합니다.

- 2026-10-03: task017 독립 FINAL approved를 main이 확정했습니다. 같은 Sandbox 앱에서 내장 disk0의 Read·Write 부하 상승/회복이 원시 드라이버와 iostat 합계에서 일치했습니다. 최종 해시·서명 Debug·Release를 확인했습니다. task016과 함께 SPEC §5.6을 충족하며 task018 통합 검증을 이어갑니다. 보류한 task014/015와 IMPLEMENT는 미완료입니다.

- 2026-10-03: task016 독립 FINAL approved를 main이 확정했습니다. 같은 Sandbox 앱에서 다운로드·업로드 각각 유휴→부하→회복 방향이 확인된 물리 부분 합계와 netstat에서 일치했습니다. 서명 Debug·Release와 최종 해시를 확인했습니다. task017 디스크 비교를 이어가며 task014/015와 IMPLEMENT는 미완료로 유지합니다.

- 2026-10-03: task013 독립 FINAL approved를 main이 확정했습니다. 기본 키보드 설정의 현재/작은 실제 화면에서 네 단축키·닫기·Escape·AX 포커스·상세 페이지 끝·전체 접근성 정보를 검증했습니다. 전체614/614·Release·서명Debug 통과, 최종 소스/바이너리 해시 일치. 013완료 후016측정비교를 진행하며014실장치/015잠금·절전은보류합니다.

- 2026-10-03: task012 독립 FINAL approved를 main이 확정했습니다. 실제 현재/추가 지원 해상도에서 스크롤 없는 본체·외곽8pt·공유 상세 크기·앵커·끝 스크롤과 긴 Memory 원문/자연높이를 검증했습니다. 관련38/38·Release·서명Debug 통과, 구현/바이너리 해시 일치. 012만 완료하며013을 이어갑니다. 014실장치와015잠금·절전은 사용자 보류, IMPLEMENT는 미완료입니다.

- 2026-10-03: 사용자 장비 문의 답변 “그럼 그건 패스해”에 따라 실제 VPN·외장 디스크 전환 검증을 보류합니다. task014는 미완료로 유지하며 독립적인 화면·키보드·시스템 도구 비교·통합 검증을 진행합니다.

- 2026-10-03: 사용자 지시로 잠금·절전 복귀(task015)를 제외한 M3 잔여012·013·014·016·017·018 진행을 재개합니다. task015는미완료보류로남기며M3전체완료로처리하지않습니다. 최신스크롤없는UI·Memory자연높이를보존합니다.


- 2026-10-03: Per-Request로Memory하단최소199pt예약공간을제거했습니다. 내용에따라기본169pt/긴정보184pt, 실제본체280×668pt/스크롤없음으로확인했으며 관련15테스트·서명Debug빌드가통과했습니다. 사용자지시에따라main에커밋·푸시합니다.


- 2026-10-03: 사용자 반려를 반영한 task-011 전체 요약의 독립 FINAL approved를 main이 확정했습니다. CPU·Memory도 함께 줄이고 글씨를 회복해280×698pt 네카드/스크롤없음/TOP5여백/하단삭제를 적용했습니다. 전체610/610·Release/서명Debug·실제PID94070 네카드AX/상세개폐·해시를 확인했습니다. task-011 `[x]`, SPEC·DESIGN `[x]`, IMPLEMENT `[ ]`이며 추가화면/chrome/task012~018은 후속관문입니다.


- 2026-10-03: task-010 갱신주기 설명 보완 후 최종 독립 재verify approved를 main이 확정했습니다. 실제 상세/AX의 빠른 활동·별도 느린 보조 갱신 설명과 조회 시각·집중4/4·Release·서명Debug/최종해시를 확인했습니다. 기존606/606·최대속도·101pt/개폐 근거를 결합해010만 `[x]`로 전환하고 최근reject를 제거했습니다. 과거reject이력은 보존합니다. SPEC·DESIGN·선행승인은 유지하며 IMPLEMENT는 `[ ]`입니다. 저장·커밋 후011을 진행합니다.

- 2026-10-03: task-010 독립 verifier의 초기 approved 메시지가 최종 correctness rejected로 정정됐습니다. main이010을 `[ ]`로 유지하고 최근 reject를 기록했습니다. 상세·AX에서 속도와 보조 정보 갱신 주기 구분을 보완해 재검증합니다. 초기 메시지를 근거로 생성한 미공개 커밋43bde16은 soft reset으로 취소해 변경을 그대로 보존했습니다. SPEC·DESIGN과 수집001~008 승인은 유지하며 IMPLEMENT는 `[ ]`입니다.


- 2026-10-03: implement-init analyzer의 나머지 후보를 최신 DESIGN·SPEC과 대조해 적용했습니다. task-010→011→012에 이번 축소 UI 범위를 고정하고 신규 ID 없이 §5.19를 Disk·본체·관련 후속 회귀에 매핑했습니다. 수집001~008과 철회009/과거 근거는 유지하며 적용 Task17개·현재 완료 조건18개가 매핑됩니다. SPEC·DESIGN `[x]`, IMPLEMENT `[ ]`입니다. 이번 요청은 UI010~012까지이며 실장치 전환 등을 포함한013~018은 자동 착수하지 않습니다.

- 2026-10-03: implement-init analyzer의 task-010 부분 후보를 최신 SPEC·DESIGN과 대조해 적용했습니다. 264×101pt 직접렌더와 현재 부모248pt 과도기, 하단 안내 삭제·원문 수치 적응·상세/AX 보존을 확정했습니다. 나머지 Task 개정과 전체 매핑은 아직 진행 중이며 task-011·012는 갱신 후 순차 착수합니다. 부분 문서 적용은 전체 IMPLEMENT 완료나 Task 승인을 뜻하지 않습니다.

- 2026-10-03: design-init analyzer의 축소 샘플 후보를 최신 SPEC·원본과 대조해 적용했습니다. 카드 폭264pt·높이211/143/101/101pt·본체590pt, 요약 전용 타이포와 TOP 5 아래3pt, 하단 안내 삭제·상세/AX 정보 보존, Disk42pt 미니 그래프를 확정했습니다. 긴 값은 원문 숫자·정밀도·단위 보존한 내부 재배치/축소로 표시하며 과학 표기를 도입하지 않습니다. task-001~008과 정보 의미는 유지하고 UI010~012와 후속 표시 검증을 갱신합니다. DESIGN `[x]`, IMPLEMENT `[ ]`이며 implement-init에서 Task 계약을 맞춥니다.

- 2026-10-03: 사용자가 280×590pt 축소 샘플을 승인하고 Network·Disk 하단의 측정/보조 정보 안내 제거와 TOP 5 아래 여백을 추가 지시했습니다. SPEC에 축소 비율·Disk 옆 미니 그래프·네 카드 한눈 표시를 반영했습니다. 철회된 §5.17은 이력으로 보존하고 Disk 미니 그래프 기준을 새 §5.19에 추가합니다. 수집·표시 모델 task-001~008 승인은 유지하며 UI task-010 이후는 재검증 대상입니다. DESIGN·IMPLEMENT는 갱신 전 `[ ]`입니다.

- 2026-10-03: implement-init analyzer 후보를 새 SPEC·DESIGN과 대조해 적용했습니다. ID18개와 과거승인근거를 보존하고 task-009는 비적용 철회 이력으로 전환했습니다. 적용Task17개 중001~008승인을 유지하고010/011은160pt 요약·상세 재검증,012는953pt 네카드동시표시/가용영역·실제창 관문으로 갱신했습니다. 후속013~018은 현재값·보조정보·내부이력과유지되는CPU·Memory그래프로 관찰대상을 맞췄습니다. 적용완료조건17개에 모두Task가 매핑되고철회§5.17은 현재관문에서 제외됩니다. SPEC·DESIGN `[x]`, IMPLEMENT `[ ]`이며 task-010부터 순서대로 재개합니다.

- 2026-10-03: design-init analyzer의 개정 후보를 새 SPEC·원본과 대조해 적용하고 DESIGN `[x]`로 전환했습니다. Network·Disk는 그래프 전용 표시 없는160pt 카드, CPU329pt·Memory224pt는 기존그래프/정보를 유지하며 전체953pt를 가용높이에 맞춰 표시합니다. 충분한 높이는 네카드동시표시, 부족하면 스크롤로 도달하고 실제chrome·외곽8pt·카드앵커/상세를 검증합니다. task-009의 그래프UI목적과§5.17매핑은 철회 대상이고 task-010~012·후속UI관문은 새 계약 재검증 대상입니다. 수집·내부이력·단위·표시모델 task-001~008 승인은 유지합니다. IMPLEMENT는 `[ ]`이며 implement-init에서 Task 적용 상태·매핑을 확정합니다.

- 2026-10-03: 사용자가 Network·Disk 그래프만 제거하고 CPU·Memory 그래프를 유지하는 방향을 선택했습니다. spec-init에서 SPEC §5.1·5.2의 요약 그래프 요구를 제거하고 §5.17을 번호 보존한 채 철회했습니다. §5.15·5.16은 유지되는 CPU·Memory 그래프와 그래프 없는 두 요약의 안정성·한눈에 보기를 반영했습니다. 수집·필수 현재값·보조 정보·상세·단위·Sandbox 요구는 유지합니다. 기존 그래프 배치와 연결되는 DESIGN을 `[ ]`로 전환하고 task-009~011의 승인을 취소해 기존 근거를 이력으로 보존합니다. 영향 없는 수집·표시 모델 task-001~008 승인은 유지하고 task-012 부분 구현은 보존하되 승인하지 않습니다. SPEC `[x]`, DESIGN·IMPLEMENT `[ ]`이며 design-init에서 배치와 의존 영향의 상세 범위를 확정합니다.

- 2026-10-03: task-011의 DESIGN §3.3 보완·구현 후 독립 재verify approved를 main이 확정했습니다. 가용 라벨과 같은 단위 공유로 최장값 말줄임을 해소하고 숫자·단위·정밀도·로케일·294pt 슬롯을 유지했습니다. 직접5/5·전체unit606/606·Release/서명Debug 및 실제Sandbox PID73723의 APFS/드라이버IOPS/외장없음·화면/AX/개폐를 확인했습니다. task-011만 `[x]`로 전환하고 최근 reject를 제거하며 과거 거절 기록은 보존합니다. 의미 변경·승인 취소 없이 SPEC·DESIGN·선행 승인을 유지하며 IMPLEMENT와 task-012 이후는 `[ ]`입니다. 커밋 후 task-012를 진행합니다.

- 2026-10-02: 사용자 재개 지시 후 `design-init` analyzer의 task-011 한정 후보를 원본과 대조해 DESIGN §3.3에 적용했습니다. `가용` 라벨·같은 단위 공유·구분자 공백 축약으로 전체/사용 가능 두 값을 보존하며 수치·1024단위·정밀도·로케일·갱신 시각·294pt 슬롯·글꼴·그래프는 유지합니다. 이는 승인된 정보의 내부 표현 보완이며 새 요구사항이나 완료 기준 완화가 아닙니다. 직접 영향은 미승인 task-011의 요약·AX·렌더이고 수집·공통 formatter·Network와 task-001~010 승인을 유지합니다. SPEC·DESIGN `[x]`, IMPLEMENT·task-011 이후 `[ ]`를 유지하고 최근 reject를 해소하기 위한 구현·독립 재verify를 진행합니다.

- 2026-10-02: task-011 completed 후보의 독립 verify에서 최장 용량 두 값이 카드 보조행에 맞지 않아 `design/scope` rejected를 main이 확정했습니다. 실제 Disk 카드/상세·APFS/IOPS/외장없음·개폐·605/605 단위·Release/서명Debug 근거는 확보했지만 최대 UInt64 사용 가능 용량이 말줄임됩니다. DESIGN §3.3의 슬롯 부적합 반환 조건에 따라 용량 표시 방식 결정 전 루프를 중단합니다. 사용자의 “그것만 하고 멈쳐” 지시에 따라 거절 사유·재개 조건만 저장하고 추가 구현은 하지 않습니다. task-011과 IMPLEMENT는 `[ ]`, task-012 이후는 미진행이며 SPEC·DESIGN·task-001~010의 기존 승인을 유지합니다. 아직 계약을 변경하지 않았으므로 승인 취소는 없습니다. 부분 구현과 원자료를 보존하고 DESIGN 결정 후 task-011부터 재개합니다.

- 2026-10-02: task-010 독립 verify approved를 main이 확정했습니다. Network 294pt 카드와 인터페이스 상세를 연결하고 물리 대표 속도·VPN/터널 상세 범위·현재/누적/링크 사유를 구분했습니다. 집중16/16·전체unit601/601·Release/서명Debug와 실제Sandbox PID77408의 화면·AX·개폐 프레임을 확인했습니다. XCUITest 초기화 실패는 성공으로 주장하지 않았으며 실제 앱 probe로 이번 UI 근거를 확보했습니다. task-010만 `[x]`로 전환하고 SPEC·DESIGN·기존 승인을 유지합니다. 의미 변경·승인 취소는 없고 IMPLEMENT와 task-011 이후는 `[ ]`입니다. 커밋 후 Disk 카드 task-011을 진행합니다.

- 2026-10-01: task-009 독립 verify approved를 main이 확정했습니다. 두 속도 계열의 독립 선·원본 peak 축·공백·극값 축소와 CPU가 공유하는 그래프 판을 구현했습니다. 최초 유효 시각을 별도로 보존해 600초 이후 진행 문구가 다시 나타나지 않게 했습니다. 집중51/51·전체unit597/597·Release빌드와 라이트/다크PNG20개를 확인했습니다. task-009만 `[x]`로 전환하며 기존 승인을 유지합니다. 의미 변경·승인 취소는 없고 IMPLEMENT와 task-010 이후는 `[ ]`입니다. 커밋 후 Network 카드 task-010을 진행합니다.

- 2026-10-01: task-008 독립 verify approved를 main이 확정했습니다. 활동과 보조 상태를 표시 store에 연결하고 지표별 단위·과거값·부분값·조건부 이유를 구분했습니다. 최종 표시 commit에서 topology까지 확인해 늦은 결과를 차단했습니다. 집중23/23·전체unit588/588·Release빌드와 소스7개 해시를 확인했습니다. task-008만 `[x]`로 전환하고 선행 승인·SPEC·DESIGN을 유지합니다. 의미 변경·승인 취소는 없으며 IMPLEMENT와 task-009 이후는 `[ ]`입니다. 커밋 후 task-009를 진행합니다.

- 2026-10-01: task-007의 실제 앱 저전력 일정 근거를 보완하고 독립 재verify approved를 main이 확정했습니다. 서명 앱 observer에 DEBUG snapshot을 주입해 여섯 축 닫힘5/10/120초·열림2/4/60초·일반 복원을 관찰했으며 실제 OS 전력 설정은 변경하지 않았습니다. 최종 집중23/23·전체unit579/579·Release/서명Debug와 소스15개 해시를 대조했습니다. task-007만 `[x]`로 전환하고 기존 승인을 유지합니다. 요구사항·설계·완료 기준 변경이나 승인 취소는 없으며 IMPLEMENT와 task-008 이후는 `[ ]`입니다. 커밋 후 task-008을 진행합니다.

- 2026-10-01: task-007 completed 후보의 독립 verify에서 실제 앱 저전력 일정 관찰 근거가 부족해 `evidence` rejected를 확정했습니다. 같은 production factory의 저전력 테스트와 일반 전력 실제 앱 로그는 확보했으며, 실제 앱 DEBUG lifecycle 입력에 저전력 snapshot을 주입해 로그를 보완합니다. 승인 계약·선행 승인 변경은 없고 task-007 및 IMPLEMENT는 `[ ]`입니다.

- 2026-10-01: task-006 독립 verify approved를 main이 확정했습니다. Disk 활동·저장소 metadata source/store와 수명·이력을 구현하고 필수 Bytes partial, 조건부 Operations 감소, 관계 미확인과 같은 ID의 마운트 캐시 수명을 보완했습니다. 집중27/27·전체unit572/572·Release/서명Debug·실제Sandbox 두 tick 관찰이 통과했습니다. task-006만 `[x]`로 전환하며 SPEC·DESIGN·기존 Task 승인을 유지합니다. 의미 변경·승인 취소는 없고 IMPLEMENT와 task-007 이후는 `[ ]`입니다. 커밋 후 task-007을 진행합니다.

- 2026-08-17: SPEC 작성. 물리 인터페이스 합계·VPN 터널 상세 전용, 프로세스별 Disk I/O 제외를 확정했습니다.
- 2026-10-01: M2 core-resource-monitoring 완료 후 기존 디렉터리에서 SPEC을 갱신했습니다. 완료 조건 §5.1~§5.15의 번호를 보존하고, 작은 화면의 네 카드 접근(§5.16), 최신 공통 그래프 판 규칙(§5.17), 조건부 연결 속도·IOPS(§5.18)를 추가했습니다. 수집 중지 경계·느린 보조 조회·실패·연결 상태의 의미도 현재 선행 계약에 맞췄습니다. 오래된 카드 넷의 세로 공간 설명을 현재 ROADMAP·원본 기준으로 대체하고 `ANALYSIS`를 `DESIGN` 상태로 옮겼습니다. 확정된 범위·제약과 VPN 합산·Disk 제외 결정을 유지하므로 SPEC `[x]`를 유지합니다. 기존 DESIGN·IMPLEMENT 승인과 Task 문서는 없어 취소할 하위 승인은 없으며, 두 상태는 `[ ]`입니다. 이번 요청 범위는 SPEC 갱신까지입니다.
- 2026-10-01: analyzer의 전체 설계 후보를 현재 SPEC·원본과 대조해 적용했습니다. 완료 조건 §5.1~§5.18을 모두 매핑하고 DP1~DP7을 채택해 DESIGN `[x]`로 전환했습니다. Network·Disk 활동과 메타데이터의 네 독립 수집 축, 물리 대상 집계와 중복 제거, 중지 경계·늦은 결과 차단, 두 계열 그래프와 단일 열 세로 스크롤을 확정했습니다. SPEC 변경과 미채택 결정은 없으며 기존 M3 Task·IMPLEMENT 승인이 없어 취소 대상도 없습니다. 제품 코드와 기존 M2·표시 개선 계약은 변경하지 않아 해당 승인을 유지합니다. 구현 단계에서는 CPU·Memory 회귀 검증과 실제 Sandbox·VPN·외장 장치·작은 화면 관문을 수행해야 합니다. SDK 조사와 Sandbox 밖 읽기 전용 probe는 실제 배포 조건 검증을 대신하지 않습니다. IMPLEMENT는 `[ ]`이며 이번 요청 범위는 DESIGN까지입니다.

- 2026-10-01: `implement-init`에서 analyzer의 전체 후보를 현재 SPEC·DESIGN·원본과 대조해 신규 implement.md에 적용했습니다. task-001~task-018의 목적·접근·결과·확인·참조와 SPEC §5.1~§5.18의 전체 매핑을 작성했습니다. 실제 Sandbox native adapter 관문을 앞에 두고 수집 경계·일정·리소스 수집·배선·표시·그래프·카드·화면·접근성·실제 전환·시스템 도구 비교·회귀 순서를 고정했습니다. SPEC·DESIGN 의미 변경이나 기존 Task·승인 취소는 없습니다. 선행 SPEC·DESIGN과 기존 M2 승인을 유지하고 신규 Task 18개와 IMPLEMENT는 모두 `[ ]`로 둡니다. 제품 코드·실행 검증은 수행하지 않았으며 이번 요청 범위는 Task 문서 작성까지입니다.

- 2026-10-01: `implement-loop M3`의 task-001 구현 완료 후보와 테스트 6개 통과 근거를 인수했습니다. 초기 XCTest 호스트의 임시 Sandbox 예외를 발견해 테스트와 분리한 build-only 앱으로 관문을 재확인했습니다. 최종 앱에는 새 예외가 없고 물리 Wi-Fi 카운터·주소·provider·Link Active를 확인했으며 미확정 대상·불완전성은 보존합니다. 그러나 독립 verifier 호출이 `agent thread limit reached`로 반복 실패해 최종 판정 전 중단했습니다. SPEC·DESIGN 승인을 유지하고 task-001~018 및 IMPLEMENT는 `[ ]`이며 승인 취소나 최종 reject는 없습니다. 사용자의 Task별 승인 후 커밋 지시에 따라 아직 커밋하지 않았습니다. 재개 지점은 현재 코드·evidence/task-001의 독립 verify이며, 승인되면 커밋 후 task-002로 진행합니다.

- 2026-10-01: 새 세션에서 task-001 독립 verify 호출이 성공했고 main이 approved로 확정했습니다. 현재 소스 해시와 테스트 6개·임시 예외 없는 build-only Sandbox 실행 원자료를 대조했습니다. task-001만 `[x]`로 전환하며 SPEC·DESIGN 승인과 나머지 Task를 유지합니다. 완료 조건의 마지막 매핑 Task는 없어 IMPLEMENT는 `[ ]`입니다. 선행 문서와 task-001을 첫 커밋에 포함한 뒤 task-002를 진행합니다.

- 2026-10-01: task-002 독립 verify approved를 확정했습니다. 필수 물리 Disk 바이트·Operations·시스템 용량·APFS 관계의 실제 Sandbox 근거, 결정적 Disk 7개·Network 6개 테스트와 현재 소스 해시를 확인했습니다. Network 격리 선언 보완의 영향은 verifier의 같은 빌드 probe 재실행으로 회귀 없음을 확인해 task-001 승인을 유지합니다. task-002만 `[x]`, 나머지 Task와 IMPLEMENT는 `[ ]`로 유지하며 커밋 후 task-003으로 진행합니다. 요구사항·설계·완료 기준 변경과 승인 취소는 없습니다.

- 2026-10-01: task-003 독립 verify approved를 확정했습니다. 공통 실행권과 누적 경계·sleep/wake·축별 계획 순서 검사를 source 기준점/실제 저장/표시 반영에 배선했습니다. 구현 중 async protocol 기본 구현 우회, 오래된 tick의 새 token 발급, 늦은 target 일정 적용을 발견해 승인 계약 안에서 보완하고 결정적 통합 테스트로 확인했습니다. 전체 단위 테스트 528/528와 Release 빌드가 통과했습니다. task-003만 `[x]`로 전환하고 기존 SPEC·DESIGN·task-001·002 승인을 유지하며 IMPLEMENT와 task-004 이후는 `[ ]`입니다. 의미 변경·완료 기준 변경·승인 취소는 없습니다. 커밋 후 task-004를 진행합니다.

- 2026-10-01: task-004 독립 verify approved를 확정했습니다. 여섯 축 일정과 보조 조회의 최초/신선도/병합/중지중 보류/단일 실행을 구현하고, 지연된 과거 deadline의 중복 보충을 수정했습니다. 전용6개×5회와 전체534/534·Release빌드가 통과했습니다. task-004만 `[x]`, task-005 이후와 IMPLEMENT는 `[ ]`입니다. SPEC·DESIGN·기존 Task 승인을 유지하며 의미 변경·승인 취소는 없습니다. 커밋 후 Network source/store인 task-005를 진행합니다.

- 2026-10-01: task-005 독립 verify approved를 확정했습니다. Network fast/slow reader·source·store, topology 수명/revision, 차분·이력과 불완전 물리 합계를 구현했습니다. reader/source의 늦은 tracker 반영과 metadata await 사이 topology 변경을 보완해 실제 반영 시점에서 차단합니다. 집중24/24·전체unit552/552·Release/서명Debug빌드와 실제Sandbox baseline/부분속도 관찰이 통과했습니다. task-005만 `[x]`로 전환하고 SPEC·DESIGN·기존 Task 승인을 유지합니다. 나머지 Task와 IMPLEMENT는 `[ ]`이며 의미 변경·승인 취소는 없습니다. 커밋 후 task-006을 진행합니다.

- 2026-10-04: 사용자 「macOS 기준으로 맞추기 — 회수 가능한 공간 포함」 선택을 spec-init/읽기 전용 analyzer 후보의 design-init으로 반영했습니다. Disk 저장 공간만1000 기반·important-usage available로 변경하며 다른 지표 단위는 유지합니다. 누락/실패는 기존 보조 실패, privacy reason85F4.1을 선택했습니다. SPEC/DESIGN [x], IMPLEMENT [ ]. 직접002/008·의존006/011/013/018 승인을 취소하고 이전 근거를 보존했습니다. 그 외 승인·014/015 보류는 유지합니다. 새 용량 렌더/geometry가 달라지면012 및 관련M4승인 영향을 추가 산정합니다. 제품 수정/새 용량 검증은 아직 수행하지 않았습니다.

- 2026-10-09: 사용자 지시로 실제 VPN 연결/해제·외장 디스크 연결/제거 시험을 SPEC §4·§5.5/7에서 제외했습니다. analyzer의 design-init/implement-init 후보를 main이 원본과 대조해 DESIGN §4.3·DP3 및 task014/후속 시험 지시를 적용했습니다. 제품 기능·수집·표시·결정적 검증은 유지합니다. SPEC/DESIGN [x], IMPLEMENT [ ]이며 task014는 남은 Wi-Fi↔Ethernet·끊김/복귀 근거 대기입니다. 새 승인 취소 없이 기존 승인과 Disk 용량 재검증6개·task015 보류·M4 완료를 유지합니다. 네트워크 조작·코드 변경·시험 실행은 수행하지 않았습니다.

- 2026-10-09: 사용자 「랜케이블은 제외 / 네트워크 끊김 복귀는 자동복구 준비하고 진행」 지시로 실제 Wi-Fi↔Ethernet 전환 시험도 제외했습니다. SPEC §4/5.7과 analyzer 후보의 DESIGN §4.3·task014를 main이 확정했습니다. 기존 분류·제품 동작·결정적 검증 및 승인 유지, SPEC/DESIGN [x]·IMPLEMENT [ ]입니다. task014는 Wi-Fi 끊김·복귀의 독립 자동복구 준비와 실기기 검증으로 좁혀 실행합니다.

- 2026-10-09: 독립 자동복구를 준비한 실제 Wi-Fi12초 끊김/복귀와 원래 연결 복원을 완료했습니다. 같은 전체 소스의 별도 서명 Sandbox 진단 앱과 등록 Release 앱 AX를 구분해 원시값·baseline·다음 부분 속도·앱 생존을 확인했습니다. worker 결과 인수 후 독립 verifier의 evidence reject를 main이 확정했습니다. 전체 연결 없음(가상/미확인 인터페이스 잔존), Off 상세, 대표 이력 유효점 분리는 미확인이라 task014/IMPLEMENT [ ] 유지, 새 SPEC 완료 없음. 구현 재시도0·근거 재검증0, 제품 수정·suite 재실행 없음. 독립 watchdog/진단 앱은 종료했고 Release64258 유지·Wi-FiOn/en0Reachable 복구. 기존 승인·Disk재검증6개/task015보류/M4완료 유지. [이번 근거](./evidence/task-014/wifi-20261009/README.md).
