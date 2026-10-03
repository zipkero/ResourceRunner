# Network·Disk 확장 리소스 모니터링 구현

## 2026-10-03 남은 M3 검증 재개

사용자가 잠금·절전 복귀를 제외한 나머지 작업 진행을 요청했습니다. 현재 실행 대상은 task012·013·014·016·017·018이며 task015는 사용자 지시로 보류합니다. 보류는 완료/철회가 아니며 기존SPEC매핑을 보존합니다. Task013/018의 과거590pt·고정카드치수·본체스크롤 설명은 최신스크롤없는280pt본체·Memory자연높이 요구보다 우선하지 않습니다. 현재요약치수/정보/가독성을 유지해 검증하고, 잠금·절전·디스플레이수면·사용자전환을 유발하지 않습니다.


사용자는 추가 장비 문의에 “그럼 그건 패스해”라고 답해 실제 VPN·외장 디스크 연결/해제 관찰도 보류했습니다. task014는 완료/철회로 바꾸지 않습니다. 현재 Ethernet 링크 전환 장비도 미확보이며 해당 미확인 영향을 보존합니다. 사용자 지시로 보류한 실장치/잠금 관문을 완료 근거로 대체하지 않고 독립적으로 실행 가능한 task013→016→017→018 검증을 이어갑니다.

## 2026-10-03 Memory 하단 여백 수정 (Per-Request)

사용자가 Memory 카드 하단 공백 제거를 요청해 최소199pt 예약 높이를 제거했습니다. Memory는 실제 내용 높이를 사용하고 긴 정보가 줄바꿈될 때만 늘어납니다. 이전 Memory199pt/전체698pt 고정 높이와 모든 긴 정보 상태의 동일 높이 기준을 이 수정으로 대체합니다. 글씨·정보·앱5개행·TOP5여백은 유지합니다. 기본 렌더169pt, 긴 정보184pt이며 실제 현재화면 본체280×668pt·bodyScroll=false를 확인했습니다. 관련15개테스트와서명Debug빌드가통과했습니다.

## 2026-10-03 실제 화면 피드백 — 이전 샘플 치수보다 우선

사용자는 CPU·Memory가 그대로인 채 스크롤되는 중간 화면과 Network·Disk의 지나치게 작은 글씨를 반려했습니다. 네 카드 전체를 동시에 줄여 **현재 지원 화면에서 스크롤 없이 모두 표시하고 가독성을 확보하는 것**이 우선입니다. 이전 샘플의 590pt 높이와 6.67/7pt 글꼴은 강제하지 않습니다. 요약의 제목·보조 정보·단위·TOP 5는 10pt 이상을 기본으로 하고 대표 숫자는 약 17.33pt, CPU 그래프는 약 66.67pt를 유지합니다. 본체 폭280pt·padding8pt·카드 간격6pt는 유지하되 높이는 실제 전체 렌더와 가용 화면으로 확정합니다. 본체에는 ScrollView를 두지 않습니다. 정보 삭제·말줄임으로 맞추지 않으며 TOP 5 아래 3pt, Network·Disk 하단 안내 삭제와 Disk 옆 그래프 요구는 유지합니다. 실제 아이콘·Memory 정보·전체 값과 상세의 기존 글꼴/스크롤을 보존합니다. 전체 배치가 끝나기 전 중간 앱을 사용자 화면에 띄우지 않습니다. Network의 활성 종류가 많아 이름 나열이 길어질 때 요약 카드에는 종류 수와 활성·미확인 개수를 표시할 수 있으며, 전체 종류 이름은 상세와 AX에 그대로 제공합니다. 소수 종류의 이름 표시는 유지합니다.

현재 task-011은 Disk 단독 중간 화면 대신 **CPU·Memory·Network·Disk 전체 요약 통합 수정 하나**를 담당합니다. task-010의 수집·상세 승인은 유지하되 요약 글꼴은 재검증합니다. task-012의 CPU·Memory 축소/TOP 5/전체 표시 구현은 task-011로 이동하고 추가 화면/chrome·예외 화면 viewport 검증은 task-012에 남깁니다. task-011은 전체 가독성·정보 보존·TOP 5 여백·스크롤 없는 실제 화면, 관련 회귀 테스트·Debug/Release 빌드·상세 개폐를 독립 검증합니다. 미확보 실장치/OS 전환 관문은 이번 요청으로 자동 시작하지 않습니다.


## 기준

승인된 [spec.md](./spec.md)의 현재 적용 중인 완료 조건 §5.1~§5.19와
[design.md](./design.md)의 채택된 설계를 순서 있는 Task로 나눕니다.
의존 순서는 아래 항목 위치로 표현하며 승인 상태는 각 Task의 체크박스와 승인 근거를 따릅니다.
SPEC §5.17은 철회 이력이며 현재 완료 관문에 포함하지 않습니다.
task-009도 체크박스 없이 철회 이력으로 보존하고 적용 중인 완료 조건에 매핑하지 않습니다.

2026-10-03 최신 개정의 구현 대상은 승인된 280×590pt 축소 샘플의 네 요약 카드입니다.
최종 카드 폭 264pt·높이 CPU 211pt/Memory 143pt/Network 101pt/Disk 101pt,
본체 padding 8pt·카드 사이 6pt를 사용합니다.
Network에는 그래프를 표시하지 않고 Disk는 작은 수치 옆에 42pt 미니 그래프를 제공합니다.
요약 제목·대표 수치·CPU 판은 승인 비율로 축소하고 Memory 구성 바와 두 TOP 5 정보를 유지하며,
TOP 5 제목 아래 3pt를 추가합니다. Network·Disk 하단 측정/보조 정보/용량 확인 경과 안내는 제거합니다.
원문 수치·단위·정밀도·로케일·상태 의미를 유지하고 긴 값은 고정 슬롯 안에서 배치·글꼴을 적응합니다.
기존 수집·baseline·내부 이력·단위·표시 모델·상세 의미를 유지하며 상세에 새 그래프를 추가하지 않습니다.

이번 사용자 승인으로 진행하는 실행 범위는 task-010→task-011→task-012입니다.
task-013~018은 남은 기능 관문으로 보존하되 이번 축소 UI 요청만으로 자동 착수하지 않습니다.
이 세 Task의 UI 적용 완료를 feature 전체 IMPLEMENT 완료로 보고하지 않습니다.
task-009의 철회·ID·과거 근거를 유지하며 미니 그래프는 task-011과 관련 회귀에 매핑합니다.

기존 CPU·Memory 수집·계산·프로세스 집계·TOP 5·메뉴바 판정과
완료된 대시보드 시각 규칙을 회귀 기준으로 사용합니다.
Network 대표값은 물리 인터페이스 합계이며 VPN·터널은 상세 전용입니다.
프로세스별 Disk I/O, 사용자 설정, 캐릭터 애니메이션과 M5의 출시 수치 관문은 추가하지 않습니다.

코드 조사 출발점은 `ResourceRunner/ApplicationCoordinator.swift`,
`MonitoringLifecycle.swift`, `MonitoringScheduler.swift`, `SystemLifecycleObserver.swift`,
`DashboardPresentation.swift`, `DashboardPresentationStore.swift`, `DashboardView.swift`,
`StatusBarController.swift`와 관련 `ResourceRunnerTests`·`ResourceRunnerUITests`입니다.
개정 표시의 출발점은 `NetworkDashboardView.swift`, `DiskDashboardView.swift`,
`DashboardView.swift`, `DashboardStyle.swift`, `ResourceRateGraph.swift`,
`ResourceRateGraphView.swift`, `ResourceQuantityFormatter.swift`와 각 카드의 직접 테스트입니다.
현재 `DashboardViewport.swift`는 없는 후보 파일명이며 viewport 책임의 파일 분할은 구현 재량입니다.
기존 미커밋 결과는 현재 계약에 맞는 부분만 재사용하고 task-010·011에서 본체 padding을 먼저 변경하지 않습니다.
최종 실제 카드 폭 264pt는 task-012가 소유하며 그 전에는 현재 부모 폭 248pt에서도
카드 밖으로 넘치지 않도록 수치·상태를 적응합니다.
새 source·reader·store의 이름과 파일 분할은 DESIGN §3.1의 책임 계약 안에서 정합니다.

task-001·task-002는 production과 같은 native adapter를 빌드·서명된 Sandbox 앱 내부에서
실행하는 선행 관문입니다. 전체 Collector·일정·카드 구현을 선행 조건으로 요구하지 않습니다.
SDK 조사, 비Sandbox 도구와 과거 접근 표는 해당 관문의 승인 근거를 대신하지 않습니다.

검증 근거에는 확인한 원본·빌드, OS·장치·Sandbox 설정, 절차·원시 결과와 판정을 남깁니다.
필수 API나 실제 하드웨어·VPN·화면·사용자 전환 항목을 확인하지 못하면
항목·원인·영향을 반환하고 해당 Task를 완료로 처리하지 않습니다.
필수 API 문제는 승인된 접근 안에서 재조사하고, 설계 변경이 필요하면 `design-init`,
사용자 관찰 결과나 완료 기준 변경이 필요하면 `spec-init` 소유 문제로 반환합니다.

## 체크리스트

- [x] task-001: Network native adapter와 실제 Sandbox 접근 관문
  - 목적: 물리 인터페이스의 64비트 RX·TX, 분류 근거, 주소·연결 상태를
    선택한 Sandbox 조건의 앱 내부에서 실제로 읽을 수 있는 Network 원본 경로를 확보합니다.
  - 접근: `NET_RT_IFLIST2`의 `RTM_IFINFO2`를 읽는 production reader와
    SystemConfiguration·IORegistry의 유형·계층·provider 관계를 결합하는 최소 adapter를 만듭니다.
    메시지 길이·버전·형식·버퍼 경계·주소 길이를 검사하고 목록 변화에 따른 크기 부족은
    제한된 재시도로 처리합니다. 동일 인터페이스의 주소 행은 카운터 대상으로 중복하지 않습니다.
    `en*`·`IFT_ETHER`·`IONetworkInterface` 존재만으로 물리라고 판정하지 않고
    최하위 하드웨어 경로, 논리·가상 대상, 확인된 VPN과 소속 미확인 터널을 구분합니다.
    loopback은 집계 대상에서 제외합니다. 전체 카드 구현에 의존하지 않는 앱 내부 관찰 경로로
    같은 adapter를 실행하며 native 호출은 MainActor 밖에서 수행합니다.
  - 검증 조건:
    - 결과: 현재 물리 대상의 필수 카운터·분류·IPv4/IPv6·연결 상태가
      Sandbox 앱에서 조회됩니다. 주소 없음과 접근 실패를 구분하고
      물리 판정이 불완전한 대상·합계를 정상으로 숨기지 않습니다.
      링크 상태를 인터넷 접속 보장으로 설명하지 않고 `IFF_RUNNING`만으로 연결을 확정하지 않습니다.
      링크 속도는 API 의미와 유효한 양수 bit/s를 확인한 경우만 지원 값으로 인정하며
      0·형식상 상한·미확인 값은 추정하지 않습니다.
    - 확인: 손상 메시지·목록 변경·주소 중복·물리/논리/가상/loopback 분류를
      결정적 reader·분류 테스트로 확인합니다. 빌드·서명된 앱 내부에서 실제 adapter를 호출해
      원시 카운터·식별 근거·주소·상태·반환 코드와 링크 속도의 지원 여부·사유,
      OS·하드웨어·빌드·entitlement를 기록합니다.
      필수 항목 미확보는 관문 실패로 반환합니다.
      실제 VPN·Wi-Fi↔Ethernet 전환 관찰은 task-014에서 이어 확인합니다.
  - 참조: SPEC §5.1, SPEC §5.3, SPEC §5.5, SPEC §5.7, SPEC §5.13, SPEC §5.18,
    DESIGN §1.1, DESIGN §1.2, DESIGN §3.1, DESIGN §3.2, DESIGN §4.1, DESIGN §4.3

  - 승인 근거: 2026-10-01 독립 verifier의 approved 후보를 main이 원본·실행 근거와 대조해 approved로 확정했습니다. 검증 기준 HEAD `002414b`의 NetworkNativeAdapter·AppDelegate DEBUG probe·직접 테스트 미커밋 상태이며, `evidence/task-001/environment.txt`의 세 소스 SHA-256이 현재 파일과 일치합니다. 결정적 테스트 6개 통과와 별도 build-only arm64 Sandbox 앱의 실제 RX·TX·IPv4/IPv6·provider·Link Active 조회를 확인했습니다. 새 temporary-exception 없이 실행했고 llw0의 unknown·합계 complete=false를 보존했습니다. 원자료는 같은 evidence 디렉터리의 sandbox-network-probe.log·network-native-adapter-tests.log입니다. 실제 VPN·연결 전환은 task-014에 남으며 이번 승인으로 마지막 매핑이 끝난 SPEC 완료 조건은 없습니다. Swift 6 격리 경고는 후속 source·격리 배선에서 확인할 품질 위험으로 남깁니다.

- [x] task-002: Disk·볼륨 native adapter와 실제 Sandbox 접근 관문
  - 목적: 물리 저장 장치의 Read·Write 바이트 통계, 시스템 볼륨 용량과
    장치·볼륨 관계를 Sandbox 앱 내부에서 실제로 읽는 원본 경로를 확보합니다.
  - 접근: 물리 whole media에 대응하는 `IOBlockStorageDriver`의 `Statistics`를 읽고
    통계 소유 드라이버 registry entry ID로 중복을 제거합니다.
    Disk Arbitration·IOMedia·IOService 부모 관계로 볼륨과 물리 장치를 다대다 집합으로 연결하며
    APFS의 논리 whole disk를 물리 장치로 가정하지 않습니다.
    마운트된 로컬 디스크 기반 볼륨과 `/`의 Foundation 용량 키를 읽고
    UUID·마운트 정체성으로 경로 중복을 제거합니다.
    실제 native adapter를 앱 내부에서 실행하는 최소 관찰 경로를 두며 전체 Collector·UI는 요구하지 않습니다.
  - 검증 조건:
    - 결과: 필수 물리 Read·Write 카운터와 `/`의 전체·사용 가능한 공간,
      확인된 장치·볼륨 관계가 Sandbox 앱에서 확보됩니다.
      APFS container·volume·snapshot·partition을 물리 합계에 다시 더하지 않고
      디스크 이미지·확인된 가상 장치·네트워크 파일 시스템의 범위를 구분합니다.
      공유 용량을 합산하지 않으며 사용 중은 `전체 − 사용 가능`으로 정의합니다.
      잘못된 용량 관계·필수 키 누락은 오류로 반환합니다.
      `DeviceInternal`·연결 특성의 외장 판정과 Removable·Ejectable을 구분하고
      Operations의 조건부 지원 여부·사유를 보존합니다.
    - 확인: 드라이버 중복·APFS 다대다 관계·미확인 관계·중복 마운트·공유 용량·잘못된 키와
      외장 판정 사례를 결정적 테스트로 확인합니다.
      빌드·서명된 앱 내부의 같은 adapter로 원시 바이트·Operations,
      registry ID·BSD 장치·볼륨 관계·용량·반환 코드,
      OS·장치·빌드·entitlement를 기록합니다.
      필수 값이나 식별 관계를 확보하지 못하면 정상 완료로 처리하지 않습니다.
      실제 외장 연결·해제 관찰은 task-014에서 이어 확인합니다.
  - 참조: SPEC §5.2, SPEC §5.4, SPEC §5.7, SPEC §5.9, SPEC §5.10, SPEC §5.13, SPEC §5.18,
    DESIGN §1.1, DESIGN §1.3, DESIGN §1.4, DESIGN §3.1, DESIGN §4.1, DESIGN §4.3

  - 승인 근거: 2026-10-01 독립 verify approved를 main이 확정했습니다. 기준 HEAD `eed1f53`의 DiskNativeAdapter·직접 테스트·AppDelegate Disk probe와 Network nonisolated 선언 diff를 검증했고 `evidence/task-002/environment.txt`의 소스 4개 SHA-256이 현재 파일과 일치합니다. Disk 테스트 7개와 Network 회귀 6개 통과, 별도 build-only arm64 Sandbox 앱 PID 20826에서 물리 disk0 드라이버 ID 4294969732의 Read·Write 바이트·Operations, `/` 용량과 APFS 볼륨 8개의 관계를 확인했습니다. physicalComplete·relationshipsComplete가 true이며 새 예외가 없습니다. verifier가 같은 빌드의 Network probe PID 24040을 직접 재실행해 task-001 동작·complete=false 보존을 확인하고 종료했습니다. 실제 외장 전환은 task-014에 남고 마지막 매핑이 끝난 SPEC 조건은 없습니다. NetworkRouteReader 생성의 Swift 6 격리 경고는 현재 Swift 5 빌드·실행 통과와 별도로 후속 배선의 품질 위험으로 남깁니다.

- [x] task-003: 공통 수집 경계와 source·store·표시의 원자적 admission
  - 목적: 짧은 중지·복귀와 취소를 무시하는 늦은 응답이
    기준점·현재값·이력·카드 상태를 되돌리지 못하는 공통 실행 계약을 완성합니다.
  - 접근: lifecycle snapshot에 누적 boundary sequence를 담고
    중지 표시의 `Void` 이벤트를 epoch·revision·중지 여부가 있는 값으로 바꿉니다.
    시스템 `willSleep`·`didWake`를 관찰하고 wake 경계에서 기준점을 끊으며
    다른 중지 사유가 남아 있으면 계속 중지합니다.
    collection epoch·축 generation·요청 sequence·허용 상태를 실행 결과에 전달합니다.
    경계는 비동기 취소·일정 적용 전에 admission token을 무효화하고
    source의 baseline 반영, sink의 실제 저장, 표시의 실제 반영에서
    현재 token·요청 순서·시각을 검사합니다.
    기존 CPU·Memory와 프로세스 source·store·소비 경로에도 필요한 token 배선을 적용합니다.
  - 검증 조건:
    - 결과: 최신 snapshot 하나에 중지→복귀가 합쳐져 running만 전달돼도 경계 증가가 남습니다.
      await 전에 검사한 결과를 await 뒤 무조건 반영하는 경로가 없습니다.
      이전 epoch·generation, 이미 반영한 요청보다 오래된 결과는 모든 반영 경계에서 폐기됩니다.
      새 성공 이후 늦은 이전 중지가 표시를 멈추거나,
      중지 이후 이전 성공이 표시를 정상으로 되돌리지 못합니다.
      정상 주기 변경은 collection epoch·유효 baseline을 끊지 않습니다.
    - 확인: 최신 snapshot 병합, 취소 무시 source, 역순 응답,
      sink await 중 경계 변경, 표시 소비 지연과 성공/중지 이벤트 역순을
      제어 가능한 시계·suspension으로 재현합니다.
      baseline·저장 수·이력·카드 상태 각각의 불변성을 단언하고
      기존 CPU 재개 첫 tick·Memory 순간값·프로세스 및 메뉴바 정책 회귀를 확인합니다.
      새 Network·Disk 경로의 동일 계약은 task-005~task-008에서 확인합니다.
  - 참조: SPEC §5.8, SPEC §5.9, SPEC §5.11, SPEC §5.15,
    DESIGN §2.1, DESIGN §2.4, DESIGN §3.1, DESIGN §4.1, DESIGN §4.2

  - 승인 근거: 2026-10-01 독립 verify approved를 main이 확정했습니다. 기준 HEAD `d03fe7a`의 공통 CollectionAdmission, observer/lifecycle/scheduler/source/store/coordinator/display 배선과 직접 테스트 diff를 확인했으며 변경 소스 12개 SHA-256이 `evidence/task-003/environment.raw.txt`와 일치합니다. 누적 boundarySequence의 병합 중지·복귀, sleep/wake 알림, 첫 await 전 실행권 무효화, 이전 scheduler의 새 token 발급 방지, 늦은 target 일정 적용, CPU 실제 baseline·store suspension·coordinator 순위 await 뒤 표시 역전 차단을 전용 테스트로 확인했습니다. 정상 주기 변경의 epoch·baseline 보존과 기존 CPU·Memory·프로세스·메뉴바 회귀를 포함해 전체 단위 테스트 528/528 통과, Release BUILD SUCCEEDED, diff-check clean입니다. 원자료와 최종 change.patch는 같은 evidence 디렉터리에 있습니다. task-001·002 native adapter 변경이 없어 해당 승인을 유지합니다. 실제 OS 전환·UI 통합은 task-015·018에 남으며 이번에 완료되는 마지막 매핑 SPEC 조건은 없습니다.

- [x] task-004: 여섯 축 일정과 보조 조회의 독립 실행
  - 목적: 빠른 속도와 느린 보조 조회가 설계의 주기로 독립 실행되고
    조회 지연·중지·갱신 요청이 작업 중복이나 다른 축의 대기를 만들지 않게 합니다.
  - 접근: M3 일정 정의에 CPU·Memory, 프로세스, Network 활동, Disk 활동,
    Network 보조, 저장 공간·장치 관계의 여섯 축을 둡니다.
    빠른 활동은 일반 열림/닫힘 1/2초·저전력 2/5초,
    프로세스는 일반 2/5초·저전력 4/10초,
    두 보조 축은 일반 30/60초·저전력 60/120초로 적용합니다.
    보조 축은 최초 수집 가능 상태에서 즉시 요청하고
    팝오버 열림에서는 캐시를 먼저 제공한 뒤 새 주기보다 오래된 경우 갱신합니다.
    topology·마운트·해제 요청은 병합하며 알림을 사용할 수 없는 주소·상태는 polling합니다.
    보조 축별 단일 실행과 독립 actor·작업을 유지합니다.
  - 검증 조건:
    - 결과: 잠금·잠금 unknown·디스플레이 슬립·세션 비활성·시스템 sleep에서 모든 축이 중지합니다.
      동일 일정 재적용이나 정상 전력·팝오버 변경으로 불필요한 경계·baseline 초기화가 생기지 않습니다.
      중지 중 보조 갱신은 실행하지 않고 재개 때 한 번 처리합니다.
      느린 조회를 겹쳐 쌓거나 누락 deadline의 보충 tick을 몰아 실행하지 않습니다.
    - 확인: lifecycle 조합과 여섯 축 예상 주기를 순수 정책 테스트로 대조하고
      수동 시계로 최초 즉시 요청·캐시 신선도·요청 병합·중지 중 요청·재개를 확인합니다.
      보조 source를 suspend한 동안 빠른 두 활동과 CPU·Memory·프로세스 호출이 진행되는지
      독립 target·source로 확인합니다.
  - 참조: SPEC §5.8, SPEC §5.10, SPEC §5.11,
    DESIGN §1.1, DESIGN §2.1, DESIGN §2.4, DESIGN §4.2

  - 승인 근거: 2026-10-01 독립 verify approved를 main이 확정했습니다. 기준 HEAD `855c5e8`의 CollectionAdmission 축 확장, MonitoringLifecycle 여섯 축 .m3 정책·배선 및 AuxiliaryCollectionScheduler·직접 테스트 diff와 변경 소스 4개 SHA-256이 `evidence/task-004/environment.raw.txt`와 일치합니다. lifecycle 96개 조합에서 정확한 주기·중지를 대조했고 실제 보조 scheduler의 최초 즉시 조회·cache-first/stale-open·요청 병합·중지중 요청 재개1회·단일 inFlight·누락deadline 중복 방지, 느린 보조 source 동안 빠른4축의 실행을 확인했습니다. 집중6개×5회 30/30, 전체 단위534/534, Release BUILD SUCCEEDED와 diff-check clean입니다. 최종patch·원시로그·xcresult요약은 같은 evidence에 보존했습니다. task-003 admission·정상주기 epoch 보존과 기존 승인을 유지하며 마지막 매핑이 끝난 SPEC 조건은 없습니다. native source/store와 production 여섯 축 구성은 task-005~007에서 이어 확인합니다.

- [x] task-005: Network 속도·identity·보조 캐시와 최근 이력
  - 목적: 물리 대표 RX·TX와 현재 인터페이스별 속도·누적량을 정확한 연속 구간으로 계산하고
    대상 변경·실패에서 다른 대상의 baseline이나 캐시를 이어 쓰지 않게 합니다.
  - 접근: task-001의 reader를 Network 활동 source와 보조 source에 연결합니다.
    BSD 이름·interface index·registry 정체성 또는 관측 수명과 topology revision으로 키를 구성하고
    짧은 제거·복귀의 변경 revision도 누적합니다.
    native 읽기 시각의 실제 경과 시간으로 대상별 차분을 계산한 뒤
    확인된 최하위 물리 대상의 유효 속도만 대표로 합산합니다.
    활동 store는 최신 결과와 601개 고정 링을,
    보조 store는 identity·revision으로 연결한 최신 상태·시각을 소유합니다.
  - 검증 조건:
    - 결과: 최초·새 epoch·새 대상·재연결·활성 topology 변경,
      elapsed 0 이하·10초 초과·카운터 감소·기준 변경·실패 뒤 첫 성공은 baseline-only입니다.
      unsigned underflow·overflow·NaN·infinity가 발생하지 않습니다.
      실제 0 변화량은 정상 0 B/s이며 연결 없음·미수집과 구분됩니다.
      필수 대상 일부의 속도·식별 누락은 완전한 합계로 표시하지 않습니다.
      VPN·터널·loopback·상위 논리·가상 대상은 물리 대표에 중복되지 않습니다.
      제거된 대상은 다음 현재 snapshot에서 빠지고 이름·index 재사용으로 baseline·캐시를 상속하지 않습니다.
      이력은 실제 유효 두 속도·시각·epoch·rate segment만 담고
      실패·baseline-only·중지·topology 변경·카운터 재설정에서 rate segment를 끊습니다.
      제거 대상별 장기 이력을 별도로 축적하지 않습니다.
    - 확인: 실제 경과 시간과 주기 전환, 모든 baseline-only 원인,
      동일 이름·index 재사용·revision 병합·캐시 불일치,
      물리/VPN 동시 트래픽·부분 실패·제거를 결정적 source·store 테스트로 확인합니다.
      601개 용량·축출·600초 시각 선별·짧은 실패의 segment 단절과
      늦은 결과의 baseline·최신값·이력 불변성을 확인합니다.
      미수집 tick이 0·빈 점으로 저장되지 않고 정상 5초→1초 변경에서 기준점·이력이 유지되는지 확인합니다.
  - 참조: SPEC §5.1, SPEC §5.3, SPEC §5.5, SPEC §5.7, SPEC §5.8,
    SPEC §5.9, SPEC §5.11,
    DESIGN §1.1, DESIGN §1.2, DESIGN §2.2, DESIGN §2.3, DESIGN §2.4, DESIGN §2.5, DESIGN §3.1

  - 승인 근거: 2026-10-01 독립 verify approved를 main이 확정했습니다. 기준 HEAD `90204a1`의 Network activity/metadata/topology·native 격리·reader phase/admission·DEBUG probe와 직접 테스트 diff를 검증했고 관련 소스 8개 SHA-256이 `evidence/task-005/source-sha256.txt`와 일치합니다. 실제 읽기 시각 차분·모든 기준점 단절·5→1초 정상 변경·0 B/s·물리/VPN 집계·부분 실패·대상 제거/재사용/누적revision·캐시불일치·늦은 native/source/store·601링/600초/segment 조건을 집중24/24로 확인했고 전체unit552/552·Release·별도서명Debug빌드가 통과했습니다. Sandbox PID36178에서 첫baseline→약1초뒤 en0 knownPhysical 18485/17512 B/s, llw0 unknown에 따른 partial/representative nil을 확인하고 종료했습니다. 기존 native 격리 경고를 해소했으며 task-001·003·004의 의미와 승인을 유지합니다. 전체scheme UIrunner가 기동후 무진행으로 중단됐고 unit은 별도552/552 완료했습니다. production 배선·실제NIC/VPN·최종UI는 후속 관문이며 마지막 매핑이 끝난 SPEC 조건은 없습니다.

- [x] task-006: Disk 속도·장치 수명·용량 캐시와 최근 이력
  - 목적: 현재 물리 장치의 Read·Write와 조건부 IOPS를 계산하고
    느린 볼륨 용량·장치 관계와 빠른 활동을 서로 지연시키지 않게 합니다.
  - 접근: task-002의 reader를 독립 Disk 활동 source와 storage 보조 source에 연결합니다.
    통계 소유 드라이버 registry entry ID와 topology revision으로 수명을 구분하고
    대상별 실제 경과 시간 차분을 한 번 합산합니다.
    활동 store는 최신 결과와 601개 고정 링을,
    보조 store는 볼륨 용량·장치 관계·외장/마운트 상태·조회 시각을 소유합니다.
    공유 rate·연속성·admission 계약을 적용하고 Operations는 바이트와 같은 기준점 규칙으로 계산합니다.
  - 검증 조건:
    - 결과: 최초·재개·10초 초과·카운터 감소·교체·재연결·실패 뒤 첫 성공에서
      Read·Write·IOPS를 이전 기준점과 차분하지 않습니다.
      필수 바이트 일부 누락은 불완전 상태이고 Operations 미지원은 필수 속도를 막지 않습니다.
      물리 드라이버를 한 번 합산하며 APFS·볼륨·partition·가상 장치를 중복하지 않습니다.
      누적 바이트는 드라이버 원본 누적량으로 제공하고 앱 실행 이후 누적량으로 바꾸지 않습니다.
      제거된 장치의 현재값·누적값·캐시는 새 장치로 이어지지 않습니다.
      볼륨 관계 미확인·마운트되지 않은 장치·외장 없음·조회 실패가 구분됩니다.
      활동 이력은 실제 유효 값만 담고 모든 연속성 경계와 짧은 실패를 보존합니다.
    - 확인: 다중 장치·APFS 다대다·ID 교체·제거/재연결·관계 미확인·공유 용량,
      필수/조건부 카운터 실패를 source·store 테스트로 확인합니다.
      원시 Operations/실제 초가 드라이버의 회/s로 계산되는지 단언합니다.
      601개 링·600초 선별·0 미삽입·segment 단절과 늦은 결과 폐기를 확인하고
      storage 조회 suspension 중 Disk 활동이 계속 갱신되는지 확인합니다.
  - 참조: SPEC §5.2, SPEC §5.4, SPEC §5.7, SPEC §5.8, SPEC §5.9,
    SPEC §5.10, SPEC §5.11, SPEC §5.18,
    DESIGN §1.1, DESIGN §1.3, DESIGN §1.4, DESIGN §2.2, DESIGN §2.3,
    DESIGN §2.4, DESIGN §2.5, DESIGN §3.1, DESIGN §3.2

  - 승인 근거: 2026-10-01 독립 verify approved를 main이 확정했습니다. 기준 HEAD `854c97d`의 변경 소스 7개 SHA-256과 최종 patch가 `evidence/task-006/`의 실행 근거와 일치합니다. 물리 드라이버의 실제 시각 Bytes/Operations 차분, 필수 Bytes partial/부분속도, 조건부 IOPS 기준점, 장치·마운트 수명과 관계 캐시, 모든 연속성 경계, 601링/600초/짧은 실패 segment, 늦은 reader/source/store 폐기와 느린 storage 중 빠른 Disk 진행을 집중27/27로 확인했습니다. 전체unit572/572·Release·서명Debug빌드가 통과했고 Sandbox PID43148에서 disk0 ID4294969732·볼륨8개·시스템용량/관계·첫baseline 이후 Read/Write189012.39/13691584.82 B/s와 IOPS11.54/28.84회/s를 확인했습니다. 기존 승인과 SPEC·DESIGN 의미를 유지하며 완료된 SPEC 조건은 없습니다. production 배선과 실제 외장 전환은 task-007·014의 후속 관문입니다.

- [x] task-007: production 여섯 축 배선과 실패 격리
  - 목적: 앱 한 세션에서 네 카드의 수집 흐름과 두 보조 흐름이 독립적으로 작동하고
    한 source·소비 경로의 실패나 지연이 다른 리소스와 메뉴바를 막지 않게 합니다.
  - 접근: `ApplicationCoordinator`가 여섯 축의 source·scheduler·store와
    표시 소비 경로를 각각 한 번 구성해 앱 수명 동안 보유합니다.
    기존 CPU·Memory 시스템 축·프로세스 축을 유지하고
    새 활동·보조 흐름을 기존 시스템 tick의 직렬 조회에 넣지 않습니다.
    공통 boundary와 token을 모든 축에 배선하며
    빠른 조회에는 카운터·식별·현재 집합의 최소 작업만 둡니다.
    주소 조립·볼륨 용량·관계 탐색은 보조 축에서 수행합니다.
  - 검증 조건:
    - 결과: Network·Disk·CPU·Memory 중 한 지표가 실패해도 나머지 수집과 메뉴바 흐름은 계속됩니다.
      보조 실패·suspension은 빠른 속도와 다른 카드 소비를 기다리게 하지 않습니다.
      실패 원인은 보존되고 실패한 값이 성공 0으로 바뀌지 않습니다.
      초기 lifecycle 적용 전 수집을 시작하지 않고
      축별 single-flight·token·중지·재개 계약이 실제 구성에서 유지됩니다.
    - 확인: production과 같은 coordinator 구성 경계에 주입 가능한 source를 연결해
      각 지표 실패·보조 suspension·취소 무시·중지/복귀를 통합 확인합니다.
      축별 호출·저장·전달 시각과 메뉴바 전달을 대조하고
      실제 앱에서 여섯 축의 최초 요청·팝오버 개폐·전력별 일정 배선을 관찰합니다.
  - 참조: SPEC §5.10, SPEC §5.11, SPEC §5.13,
    DESIGN §1.1, DESIGN §2.1, DESIGN §2.4, DESIGN §3.1, DESIGN §4.1, DESIGN §4.2

  - 승인 근거: 2026-10-01 독립 verify 재검증 approved를 main이 확정했습니다. 기준 HEAD `c61f76e`의 production 여섯 축 factory·독립 소비·순위 경계·topology 알림·보조 cache replay와 직접 테스트 15개 소스 해시 및 최종 patch가 `evidence/task-007/`과 일치합니다. 초기 lifecycle 전 무호출, 지표별 실패 원인 보존, 느린 보조/순위 중 카드·메뉴바 진행, 취소 무시 결과·늦은 실패·역순 cache replay·epoch/topology 폐기를 확인했습니다. 집중23/23·전체unit579/579·Release/서명Debug빌드가 통과했습니다. 실제 Sandbox PID31677에서 최초 여섯 축 전달·팝오버 개폐·알림 등록, DEBUG observer의 저전력 snapshot revision1에 따른 닫힘5/10/120초·열림2/4/60초·닫힘 전환과 revision2 일반 복원을 관찰했습니다. 실제 OS lowPower는 false였고 OS 설정 변경·실제 OS 전환으로 주장하지 않습니다. 최초 evidence reject의 앱 저전력 로그 부족은 보완됐으며 기존 SPEC·DESIGN·task-001~006 승인을 유지합니다. 마지막 매핑이 끝난 SPEC 조건은 없습니다.

- [x] task-008: 활동·보조 상태 조립과 지표별 단위
  - 목적: Network·Disk의 현재 속도·누적량·저장 공간을 구분하고
    일부 실패나 조건부 미지원에서도 성공한 값과 상태를 정확히 표시하는 모델을 완성합니다.
  - 접근: `DashboardPresentation.swift`·`DashboardPresentationStore.swift`에서
    활동 결과와 보조 결과를 identity·revision·시각에 맞춰 별도로 조립합니다.
    수집 중·정상·실패·중지의 공통 표현에
    연결 없음·정상 유휴·baseline 갱신·보조 갱신·보조 실패·불완전 합계의 구분을 더합니다.
    필수 보조 실패는 카드와 접근성 이름에서 일부 수집 실패로 나타냅니다.
    기존 CPU·Memory `ResourceCardState` 의미를 유지하고 새 경로에도 반영 시 admission을 검사합니다.
    속도는 B/s~GB/s, 누적량·용량은 B~TB의 1024 기반과 로케일 소수 한 자리,
    링크는 bit/s 계열, IOPS는 드라이버의 회/s로 구분합니다.
  - 검증 조건:
    - 결과: 보조 조회가 실패해도 성공한 현재 속도가 계속 바뀝니다.
      활동 실패·중지는 마지막 성공 값과 시각을 과거 정보로 구분하며
      성공 이력이 없으면 측정값을 지어내지 않습니다.
      지원 불가와 조회 실패·사유가 구별되고 조건부 미지원은 필수 카드 값을 막지 않습니다.
      baseline-only의 원시 누적량·대상 상태를 현재 속도로 오인시키지 않습니다.
      낮은 유효 속도는 B/s로 제공하고 bit/s·회/s·B/s·용량을 같은 지표처럼 서식화하지 않습니다.
      늦은 성공·실패·중지·보조 캐시가 최신 상태를 덮지 않습니다.
    - 확인: 활동/보조 성공·수집 중·실패·중지·미지원 조합,
      일부 필수 대상 실패·연결 없음·정상 0·baseline-only와 lastKnown 시각을
      표시 모델·store 테스트로 대조합니다.
      단위 경계·작은 속도·로케일·조건부 값 의미와 접근성 문구를 확인하고
      소비 await·역순 이벤트·identity 불일치에서 이전 반영이 차단되는지 확인합니다.
      기존 CPU·Memory 실패·재개·선택 상태 테스트도 통과합니다.
  - 참조: SPEC §5.7, SPEC §5.10, SPEC §5.11, SPEC §5.12,
    SPEC §5.14, SPEC §5.15, SPEC §5.18,
    DESIGN §1.4, DESIGN §2.3, DESIGN §2.4, DESIGN §3.1, DESIGN §3.2, DESIGN §3.3, DESIGN §4.2

  - 승인 근거: 2026-10-01 독립 verify approved를 main이 확정했습니다. 기준 HEAD `c42a0cd5`의 표시 모델·formatter·production 네 소비자·최종 topology display commit 및 직접 테스트 7개 파일 해시/patch가 `evidence/task-008/`과 일치합니다. 활동/보조 identity·revision·원본시각 조립, 보조 실패 중 속도 갱신, 성공이력 없는 상태·정상0·연결/장치없음·baseline·partial·과거값/시각·중지상세 rate 제거·조건부 미지원/실패 사유·단위/작은속도/로케일·AX 및 대기중 구 topology/epoch 표시 거절을 확인했습니다. 집중23/23·전체unit588/588·Release빌드와 diff-check가 통과했습니다. 전체unit 이후 production 변경 없이 Operations 표시 테스트 단언만 추가했고 최종집중을 재실행했습니다. CPU·Memory 및 기존 경계 승인을 유지하며 마지막 매핑이 끝난 SPEC 조건은 없습니다. 실제 graph·카드 렌더는 task-009~011에서 확인합니다.

- task-009: [철회] 두 독립 속도 계열과 공통 그래프 판
  - 적용 상태: 2026-10-03 사용자 확정 SPEC과 DESIGN §3.4·DP5에 따라
    Network·Disk 그래프 UI 목적을 철회했습니다. 현재 구현·검증·완료 매핑의 적용 대상이 아닙니다.
    ID를 다른 목적으로 재사용하거나 재번호하지 않습니다.
    기존 모델·보조 렌더 코드·실행 근거는 보존할 수 있으며 삭제를 완료 조건으로 요구하지 않습니다.
    CPU 공통 판·수집·baseline·내부 이력은 유지합니다.
    아래 목적·접근·검증 조건·참조·승인 근거는 철회 전의 기록이며 현재 승인 근거가 아닙니다.
    최신 Network 그래프 제거·Disk 미니 그래프의 구현·재검증은 task-010·011, 본체 배치는 task-012가 소유합니다.
  - 목적: Network·Disk의 최근 10분 흐름과 미수집 공백을
    두 독립 선과 같은 크기의 공통 그래프 판으로 읽을 수 있게 합니다.
  - 접근: 기존 CPU 누적 밴드의 의미를 유지하면서 속도 전용 그래프 경로를 만듭니다.
    두 계열은 0부터 시작하는 같은 양의 B/s 축에 그리며 RX·Read는 점선,
    TX·Write는 실선과 같은 모양의 범례를 사용합니다.
    상한은 10분 창의 두 계열 원본 최댓값을 모두 포함하는 1–2–5 계열,
    최소 1024 B/s로 정하고 범위 숫자·단위를 제공합니다.
    연속 구간을 먼저 분리한 뒤 두 계열 극값의 실제 표본 index 합집합을
    시간순으로 downsampling합니다.
    팔레트의 별도 역할이 Network의 cpu step3/step1과
    Disk의 Memory Compressed/Cached 색을 참조합니다.
  - 검증 조건:
    - 결과: 100pt 판·118pt graph slot이 정상·자리표시 모두 같은 위치·크기입니다.
      판 면은 전체 시간 창을 덮고 clipping·윤곽선 없음·세로 눈금 없음,
      상한 절반의 `graphPlotGridline` 1pt 하나가 데이터 선 아래에 적용됩니다.
      미수집·실패·중지·baseline-only 구간에 점·선·음영 구획이 생기지 않고
      10초 초과 간격과 segment 경계를 잇지 않습니다.
      중지 중에도 현재 시각 기준 600초 창이 이동합니다.
      자리표시는 측정값·측정된 peak를 만들지 않고
      축 아래 고정 슬롯의 수집 진행 문구는 10분 창이 찬 뒤 비워집니다.
    - 확인: 원본 peak·0 데이터·빈 데이터·축 경계·서로 다른 두 계열 peak,
      짧은 실패·중지·장기 경과 사례를 단위 테스트로 확인합니다.
      라이트·다크 렌더에서 판/카드 구분·기준선 강도·선 모양·범례·clipping·단위·범위와
      정상/자리표시의 프레임·미수집 공백을 확인합니다.
      CPU의 0~100%·밴드·코어 단계와 기존 그래프 렌더 회귀를 확인합니다.
  - 참조: SPEC §5.1, SPEC §5.2, SPEC §5.8, SPEC §5.9,
    SPEC §5.12, SPEC §5.15, SPEC §5.17,
    DESIGN §2.5, DESIGN §3.3, DESIGN §3.4, DESIGN §4.2

  - 과거 승인 근거(2026-10-03 철회로 현재 적용하지 않음): 2026-10-01 독립 verify approved를 main이 확정했습니다. 기준 HEAD `2068184`의 속도 그래프 모델/view·store 첫 유효 시각·표시 history 전달·공통판/팔레트 및 직접 테스트 소스9개 해시와 최종 patch가 `evidence/task-009/`과 일치합니다. 원본 두 peak 기반 1–2–5축·최소1024·빈 값/실제0·epoch/segment/10초초과 공백·극값 index 합집합 축소·중지 중600초창 이동·축출후 진행문구 종료를 확인했습니다. 렌더PNG20개를 main/verifier가 직접 열어 라이트/다크 정상/빈판·확장 연속 구간·큰공백·별도범례/범위·점선/실선·100pt판/118pt슬롯·1pt절반기준선·clipping/윤곽선없음을 확인했고 해시가 일치합니다. 집중51/51·전체unit597/597·Release빌드·diff-check가 통과하고 CPU그래프/source/store 계약을 유지합니다. 마지막 매핑이 끝난 SPEC 조건은 없습니다. 카드 통합 배치는 task-010/011에서 확인합니다.

- [x] task-010: Network 요약 카드와 인터페이스 상세
  - 목적: 승인된 축소 샘플의 Network 요약에서 그래프 없이 현재 송수신·활성 종류·대상 수·수집 상태를 확인하고,
    카드 옆 상세에서 현재 인터페이스별 정보를 읽을 수 있게 합니다.
  - 접근: `ResourceRunner/NetworkDashboardView.swift`를 높이 101pt·카드 padding 6pt의 요약으로 개정합니다.
    최종 카드 폭 264pt·내용 폭 252pt는 task-012의 본체 padding 8pt에서 확보합니다.
    제목·단축키 약 6.67pt/슬롯 8pt, 대표 속도 약 17.33pt, 방향 이름 10pt·단위/활성 정보 9pt,
    속도 두 행 각각 22pt·행 사이 2pt·구역 사이 4pt를 적용합니다.
    요약 그래프·그래프 자리표시·전용 범례·범위·그래프 진행 문구와 하단 측정/보조 정보 경과 안내 행을 제거합니다.
    현재값·일부 합계·과거값·활성 종류·대상 수와 비정상 상태를 보존하며
    실패·중지·연결 없음·기준점·보조 실패는 상단 또는 해당 값의 짧은 접두로 식별합니다.
    활동·보조 정보 각각의 원본 시각·갱신 주기·실패 사유는 기존 상세·AX에서 제공합니다.
    긴 수치는 원문 숫자·단위·1024 기반 단위 선택·로케일·그룹 구분·소수 한 자리·작은 양수 표현을 보존하고,
    값 영역 우선 폭 배정·고정 슬롯 안 줄 배치·필요한 글꼴 축소로 온전히 표시합니다.
    과학 표기·정밀도 축약·말줄임·clipping으로 필수 수치나 상태를 숨기지 않습니다.
    상세의 현재 대상별 RX·TX·IPv4/IPv6·원시 누적량·연결/복수 활성 상태,
    물리/논리/VPN/터널 구분·조건부 링크 속도·지원 사유·긴 이름을 유지합니다.
    상세에 새 그래프나 프로세스 목록을 추가하지 않고 상세 글꼴·공통 선택/닫힘·수집·내부 이력을 유지합니다.
    요약 타이포는 Network 전용으로 적용해 CPU·Memory·Disk의 미개정 표시를 먼저 바꾸지 않습니다.
    task-012 전 부모의 현재 248pt 카드 폭에도 맞게 유연한 폭과 긴 값 적응을 제공하며
    Network 카드에 고정 264pt를 강제해 부모 밖으로 넘기거나 본체 padding을 먼저 변경하지 않습니다.
    Disk 요약·미니 그래프는 task-011, CPU·Memory 축소·본체 배치는 task-012가 소유합니다.
  - 검증 조건:
    - 결과: Network 요약·상세에 그래프 전용 표시가 없고 요약 하단 측정/보조 정보 경과 안내가 없습니다.
      물리 대표값과 VPN·터널 상세 범위, 현재 속도·누적량·링크 속도의 이름·단위·설명이 구분됩니다.
      최초·정상·일부 실패·조회 실패·중지·연결 없음·보조 실패에서 높이 101pt와 내부 슬롯이 같습니다.
      최장 수치·상태·로케일에서 원문 현재값·단위·활성 정보와 과거/부분값 의미가 읽힙니다.
      상세는 카드 옆 팝업으로 열리고 같은 카드 선택·명시적 닫기로 요약에 복귀합니다.
      CPU·Memory·Disk와 공통 formatter의 의미·상세 표시를 공유 변경으로 훼손하지 않습니다.
    - 확인: `ResourceRunnerTests/NetworkDashboardViewTests.swift`를 출발점으로
      최종 264×101pt 직접 렌더와 과도기 248×101pt 렌더를 라이트·다크·상태별로 대조합니다.
      UInt64.max에 대응하는 거대 속도·단위 경계·작은 양수·기존 로케일 입력에서
      formatter 원문 숫자/단위의 전체 표시와 상태 접두·활성 정보 적합성을 확인합니다.
      서명된 실제 Sandbox 앱의 현재 부모 폭에서는 높이 101pt·정보·AX·선택/복귀·개폐 전후 frame을 확인하고,
      최종 실제 264pt 카드와 네 카드 동시 표시는 task-012에서 확인합니다.
      원본·화면·AX의 현재/과거·일부 합계·단위·활동/보조 시각을 대조하고
      하단 안내·그래프 전용 표시 제거와 CPU·Memory·Disk 공유 경계 회귀를 확인합니다.
      승인된 내부 적응으로도 읽을 수 있는 전체 값이 맞지 않으면 정보 삭제·높이 변경 없이 DESIGN으로 반환합니다.
      네 카드 동시 표시·화면/chrome는 task-012, 전체 키보드·AX 도달은 보류된 task-013에서 확인합니다.
  - 참조: SPEC §5.1, SPEC §5.3, SPEC §5.5, SPEC §5.10, SPEC §5.12,
    SPEC §5.14, SPEC §5.15, SPEC §5.16, SPEC §5.18,
    DESIGN §1.2, DESIGN §2.3, DESIGN §3.2, DESIGN §3.3, DESIGN §3.4,
    DESIGN §3.5, DESIGN §4.1, DESIGN §4.2
  - 승인 근거: 2026-10-03 verify_compact_task010의 최종 독립 재검증 approved 후보를 main이 확정했습니다. 근거는 evidence/task-010/sample-compact/ 및 retry-cadence/입니다. 기준 HEAD e63e515와 초기/보완 patch·최종 소스/Debug/Release 실행파일/PNG 해시가 현재 상태에 대응합니다. Network101pt·248/264직접렌더·5로케일UInt64.max 전체숫자/단위·활성8종류/보조실패·graph/footer삭제와상세/AX/선택을 확인했습니다. 초기집중9/9·전체606/606·보완Network4/4·Release/서명Debug가 통과했습니다. 실제SandboxPID41825 카드248×101·상세400×480/자식426×506·en0/utun·NetworkUpdateCadence AX359×28의빠른/별도느린갱신설명·조회시각·AXPress닫기/재선택/frame불변과기존Disk294/CPU·Memory회귀를 확인했습니다. 이전correctness reject를 해소하고 최근reject를 제거합니다(README이력보존). 완료 SPEC 조건은 없으며최종264배선/네카드동시표시와전체키보드/실전VPN은012/013/014관문입니다.
  - 과거 승인 근거(2026-10-03 계약 변경으로 승인 취소, 현재 기준 재검증 필요): 2026-10-02 독립 verifier의 approved 후보를 main이 원본·실행 근거와 대조해 확정했습니다. 기준 HEAD `2926498`의 카드/상세·공통 선택·최소 본체 ScrollView·범례 마커·DEBUG UI probe 및 직접 테스트 소스7개와 PNG42개 해시/patch가 `evidence/task-010/`과 일치합니다. 상태별·최장값·로케일294pt 렌더, 물리 대표와VPN/터널상세 범위, 긴 이름·현재/누적/주소/조건부 링크 사유를 확인했습니다. 집중16/16·전체unit601/601·Release/서명Debug빌드가 통과했습니다. 실제Sandbox PID77408의 카드248×294·상세400×480·본문306×627·자식426×506과 en0/utun 항목, AXPress닫기·재선택·개폐전후frame 보존을 확인했습니다. XCUITest는 automation mode 활성timeout으로 본문전에 실패했고 성공 근거로 사용하지 않았습니다. 실제 카드 클릭·전체 키보드/AX·네 카드 viewport·VPN 전환은 후속012~014에 남습니다. SPEC·DESIGN과 선행 승인을 유지하며 마지막 매핑이 끝난 SPEC 조건은 없습니다.

- [x] task-011: 네 카드 통합 축소·가독성·TOP 5 여백과 Disk 미니 그래프
  - 목적: CPU·Memory도 함께 줄여 현재 지원 화면에서 네 카드를 스크롤 없이 읽을 수 있게 표시합니다.
  - 접근: DashboardView/Style·CPU 그래프·Memory 구성·순위·Network/Disk 요약·본체 크기 연결을 함께 수정합니다.
    본체폭280pt·padding8pt·카드간격6pt, 기본 제목/상태/단위/랭킹10pt이상, 대표17.33pt, CPU판66.67pt를 사용합니다.
    590pt/과거 카드높이를 강제하지 않고 정보와 가독성을 확보한 전체 슬롯 합계로 높이를 확정합니다.
    본체ScrollView를 제거하고 네 카드전체가 실제visibleFrame에 들어가게 합니다.
    TOP 5 아래3pt, 실제아이콘·5개행·자리표시·전체값·상태·Memory비율/Pressure/Swap/범례를 유지합니다.
    Disk의42pt 옆미니판·Read점선/Write실선·10분/원본peak/축/downsampling/epoch/segment/10초초과단절을 유지합니다.
    Network그래프 없음과 Network/Disk 하단안내삭제를 유지하고 상세/AX의정보·원문라벨·갱신주기·APFS·IOPS를 보존합니다.
    긴값은 원문숫자/1024단위/로케일/정밀도를 보존하며 내부두줄배치로 읽히게 합니다.
    상세의원래글꼴·스크롤·선택/복귀/단축키·수집/모델/메뉴바정책을 유지합니다.
    전체코드/결정적전체PNG를 먼저 main이 확인하고 전체배치완성뒤 실제앱을 실행합니다.
  - 검증 조건:
    - 결과: CPU/Memory도 기존보다줄고 Network/Disk의작은글씨가회복되며 실제본체에네카드가동시에보입니다.
      본체스크롤이없고 마지막Disk하단/전체5행/Memory정보가잘리지 않습니다. TOP5아래3pt가 유지됩니다.
      정상/빈/실패/중지/긴값에서 슬롯이안정적이며 전체숫자·단위·정보가읽힙니다.
      CPU밴드/기준선/미수집공백과Memory구성비율, Disk정상/빈미니판과정보의의미를유지합니다.
      실제상세개폐와원래글꼴/스크롤/선택/단축키/접근성이회귀하지않습니다.
    - 확인: 실제전체light/dark렌더와관련CPU/Memory/랭킹/Network/Disk/graph테스트, Debug/Release빌드를확인합니다.
      실제지원화면의visibleFrame/배율과전체본체/카드치수·마지막하단을기록하고스크롤없이전부보임을확인합니다.
      전체UI가완성되기전중간앱을띄우지않습니다. 기존극값/단위/그래프근거는현재소스대응범위만재사용합니다.
      추가화면/chrome/예외화면·전체offscreen키보드·OS/실장치전환은후속Task에남깁니다.
  - 참조: 최신 SPEC·DESIGN 첫머리, SPEC §5.1–5.5·5.8–5.10·5.12·5.15–5.16·5.19.
  - 최신 승인 근거: 2026-10-03 독립 verifier FINAL approved를 main이 확정했습니다. `evidence/task-011/readable-integrated/`의 최종소스11개/Debug·Release해시와patch가현재코드에대응합니다. 전체unit610/610·Release/서명Debug빌드·실제PID94070의280×698pt/본체스크롤없음/네카드AX/Memory·Disk상세개폐·본체불변을확인했습니다. 많은Network종류는종류수/활성·미확인수로읽기좋게요약하고전체종류명은상세/부모AX에보존합니다. TOP5아래3pt·실제아이콘·CPU66.67/Disk42판·하단삭제를확인했습니다. 추가화면/외곽chrome·전체M3검증은후속Task이며완료된SPEC조건은없습니다.
  - 과거 승인 근거(2026-10-03 계약 변경으로 승인 취소, 현재 기준 재검증 필요): 2026-10-03 독립 verifier의 재검증 approved 후보를 main이 확정했습니다. 기준 HEAD `331bdc5`의 변경 소스7개와 signed Debug dylib SHA-256/최종patch가 `evidence/task-011/retry/`와 일치합니다. DESIGN §3.3의 가용 라벨·같은 단위 공유로 최대 UInt64 두 값과 단위 경계·0·작은 양수·5로케일25개248×294 렌더의 말줄임을 해소했으며 상세/AX 전체 라벨·단위·로케일을 유지합니다. 직접5/5·전체unit606/606·Release/서명Debug빌드가 통과했습니다. 실제Sandbox PID73723의 `/` 용량·APFS 공유 정의·볼륨8개·disk0 현재/원시누적/드라이버IOPS·외장없음과 카드248×294·상세400×480·본문306×627·자식426×506·AXPress닫기/재선택/frame보존을 확인했습니다. main/verifier가 실제PNG3개와 최장값렌더를 직접 확인했습니다. 이전 design/scope reject는 해소됐고 최근 reject를 제거합니다. SPEC·DESIGN·선행 승인을 유지하며 마지막 매핑이 끝난 SPEC 조건은 없습니다. XCUITest 성공은 주장하지 않고 실제 앱 probe로 이번 UI 근거를 확인했으며 viewport/키보드AX/실제외장 전환은012~014에 남습니다.

- [x] task-012: 추가 화면별 viewport·chrome 검증
  - 목적: task-011의통합축소를인수해추가가용화면과상세창의화면경계/chrome를검증합니다.
  - 접근: 소유한본체/상세창의실측chrome·visibleFrame·8pt외곽여유·카드앵커·상세400×480최대크기를확인합니다.
    task-011이완료한CPU/Memory축소·TOP5여백·전체표시는다시구현하지않습니다.
    현재지원화면의스크롤없는본체를유지하고 추가미확보예외화면에서별도정책결정이필요하면main에반환합니다.
  - 검증 조건: 사용가능한추가화면/배율/메뉴바위치에서본체와첫/중간/마지막상세의외곽여유·앵커·개폐후프레임을확인합니다.
    가상viewport만으로실화면근거를대신하지않고미확보이유와영향을남깁니다. 상세끝정보는기존스크롤로도달합니다.
  - 참조: 최신 SPEC·DESIGN, SPEC §5.12·5.15·5.16·5.19.

  - 승인 근거: 2026-10-03 독립 verifier의 FINAL approved를 main이 확정했습니다. 기준 HEAD43de4d3의 소스9개·Debug 실행파일/실제 Swift dylib·Release 해시가 evidence/task-012 패킷과 일치하고 관련38/38·Release·서명Debug가 통과했습니다. 실제 PID4865 현재 visible1728×1084와 PID5951 추가 실제1168×755 모드(visible1168×729)에서 본체280×668/스크롤없음·외곽8pt·네 상세 카드앵커·개폐프레임불변·상세끝정보를 확인했습니다. 상세는 각 화면에서 공유400×480/400×136입니다. DEBUG 최장 원본fixture PID6563에서 Memory169→184/본체668→683pt·두줄 원문 보존에도 상세400×136불변/Disky8을 확인했고 main이 PNG를 직접 대조했습니다. 실제 모드는 복원했고 관찰앱은 종료했습니다. 외부 물리화면 미확보와 본체가 들어가지 않는 더 작은 모드의 새 정책 경계를 명시하며 해당 지원 성공은 주장하지 않습니다. 후속 매핑이 남아 이번 승인으로 완료되는 SPEC 조건은 없습니다.

- [ ] task-013: 네 카드 키보드 선택·복귀와 접근성 도달
  - 목적: 키보드 탐색 기본 설정에서도 네 카드와 각 상세의 넘치는 정보를 사용할 수 있고
    색상 없이 현재 상태·지표 의미를 식별할 수 있게 합니다.
  - 접근: eager 카드 Button에 ⌘1·⌘2를 유지하고 Network ⌘3·Disk ⌘4를 등록합니다.
    지원 화면의 스크롤 없는 본체에서 해당 카드 앵커의 배치 완료를 확인해 상세를 엽니다.
    같은 카드 선택은 닫기, 다른 카드 선택은 전환으로 처리하며
    이전 팝업 닫힘 callback은 현재 선택과 일치할 때만 해제합니다.
    명시적 닫기·Escape와 카드 포커스 복귀,
    상세 선택 중 Page Up/Down으로 넘치는 상세 정보를 탐색합니다. 본체는 스크롤하지 않습니다.
    상세에서 부모 단축키가 작동하는 key-window 계약을 유지합니다.
  - 검증 조건:
    - 결과: 한눈에 표시된 Network·Disk도 단축키로 해당 카드에 앵커한 상세가 열립니다.
      빠른 카드 전환이나 늦은 callback이 새 선택을 지우지 않습니다.
      키보드로 상세 끝까지 도달하고 선택·복귀 뒤 카드로 포커스가 돌아옵니다.
      카드 AX 이름에 리소스·상태·주요 수치·단축키가,
      상세 AX에 대상 이름·종류·현재/누적 구분·값·상태와 필수 일부 실패가 제공됩니다.
      Network·Disk는 방향 이름·현재/과거·일부 실패·상태 라벨·상징으로 색상 없이도 구분합니다.
      Disk 미니 그래프의 최근 10분·Read 점선/Write 실선·원본 범위·상태 의미가 AX에서 확인됩니다.
      제거된 요약 하단 안내 대신 상세·AX에서 활동/보조 시각·갱신 주기·실패 사유에 도달합니다.
      CPU·Memory의 기존 그래프·정보와 접근성을 유지합니다.
    - 확인: 기본 키보드 설정의 실제 UI에서 첫·중간·마지막 카드,
      ⌘1~⌘4 반복·전환·명시적 닫기·Escape·포커스 복귀·Page Up/Down을 확인합니다.
      앵커 배치와 부모/자식 key-window 전환을 확인합니다.
      AX 계층에서 Network·Disk 상세 행과 넘치는 내용을 조회하고
      task-012의 실제 작은 화면에서도 마우스·키보드로 전 항목에 도달하는지 확인합니다.
      현재 자연 높이 본체가 들어가는 실제 지원 화면에서 네 카드 동시 표시를 확인합니다.
      부족한 예외 화면은 task-012의 정책 결정 경계를 보존하며 본체 스크롤이나 글꼴 축소를 추가하지 않습니다.
      접근성 문자열 단위 테스트와 실제 AX 부착을 구분하며 VoiceOver 실제 낭독은 M5 범위로 둡니다.
  - 참조: SPEC §5.3, SPEC §5.4, SPEC §5.12, SPEC §5.14, SPEC §5.15, SPEC §5.16, SPEC §5.19,
    DESIGN §3.2, DESIGN §3.3, DESIGN §3.4, DESIGN §3.5, DESIGN §4.2, DESIGN §4.3

- [ ] task-014: 실제 VPN·인터페이스·외장 장치 전환
  - 목적: 실제 연결 전환에서 대표 합계·상세 목록·대상 수명이 일관되게 바뀌고
    이전 대상 값이나 허위 순간값이 남지 않는지 확인합니다.
  - 접근: 선택한 Sandbox 앱에서 Wi-Fi↔Ethernet,
    VPN 연결·해제, 네트워크 연결 없음과 복귀,
    외장 디스크 연결·해제를 관찰합니다.
    원시 identity·topology revision·카운터·실제 시각·baseline-only·현재 합계·목록·보조 캐시와
    화면 상태를 함께 기록하고 필요한 경우 승인된 collector·표시 경계에서 수정합니다.
  - 검증 조건:
    - 결과: VPN·터널은 상세에서 확인되고 물리 대표 합계에 다시 더해지지 않습니다.
      실제 물리 대상·장치 집합 변경 첫 샘플은 새 기준점이며
      음수·비정상 급증·앱 종료가 없습니다.
      제거 대상의 속도·누적값이 현재 목록에서 빠지고 새 대상의 이력·캐시로 이어지지 않습니다.
      연결 없음·복수 활성·외장 없음·미마운트·조회 실패가 각각 구별됩니다.
      링크 속도·IOPS는 실제 대상의 지원 여부·의미·사유와 일치합니다.
    - 확인: 시나리오마다 전환 전후 원시값·반환 코드·대상/볼륨 관계와
      Network·Disk의 현재값·목록·보조 정보·카드·상세 상태를 대조합니다.
      baseline·rate segment·내부 이력의 수명은 원자료로 확인하며 제거된 Network 그래프 화면을 요구하지 않습니다.
      VPN 서비스와 터널 분류 근거, 외장 장치의 연결 특성과 드라이버 ID를 기록합니다.
      장비·VPN 미확보는 해당 항목·이유·영향을 반환하며 mock 통과로 실제 관문을 대체하지 않습니다.
  - 참조: SPEC §5.3, SPEC §5.4, SPEC §5.5, SPEC §5.7, SPEC §5.9, SPEC §5.13, SPEC §5.18,
    DESIGN §1.2, DESIGN §1.3, DESIGN §1.4, DESIGN §2.2, DESIGN §2.3,
    DESIGN §3.2, DESIGN §3.4, DESIGN §4.3

- [ ] task-015: 실제 시스템 sleep/wake와 화면 중지·재개
  - 목적: 실제 수면·화면 중지 뒤 첫 속도 샘플이 기준점 전용이고
    Network·Disk 내부 이력의 연속성과 유지되는 CPU·Memory·Disk 그래프의 중지 공백이 보존되는지 확인합니다.
  - 접근: 같은 Sandbox 앱에서 시스템 sleep/wake, 화면 잠금/해제,
    디스플레이 sleep/wake와 빠른 사용자 전환/복귀를 수행합니다.
    모든 축의 적용 일정·boundary sequence·epoch·허용 token·샘플 누적 수,
    첫 두 카운터 snapshot·실제 읽기 시각·rate segment·화면을 기록합니다.
    복귀 때 다른 중지 이유가 남는 경우도 확인합니다.
  - 검증 조건:
    - 결과: 중지 구간에 수집값·이력이 새로 반영되지 않고
      Network·Disk 재개 첫 snapshot은 수면 시간을 나눈 속도 없이 baseline만 갱신합니다.
      두 번째 유효 snapshot부터 실제 경과 시간의 속도를 제공합니다.
      Network·Disk 내부 이력의 rate segment가 중지 전후를 이어 붙이지 않으며
      유지되는 CPU·Memory·Disk 그래프의 중지 구간은 비고 전후 점이 선으로 이어지지 않습니다.
      짧은 중지와 wake 경계도 보존됩니다.
      중지 전 늦은 결과가 baseline·현재값·이력·표시를 바꾸지 않습니다.
      기존 CPU 재개 baseline·Memory 순간값·메뉴바와 화면 상태 계약도 유지됩니다.
    - 확인: 각 실제 전이의 시각·알림·여섯 축 샘플 수·원시 카운터·계산 결과와
      Network·Disk 내부 이력·현재/과거·카드/상세 상태와 CPU·Memory·Disk 그래프를 대조합니다.
      Disk42pt 미니 판의 중지 공백·전후 단절을 실제 화면으로 대조하며
      제거된 Network 그래프·두 카드의 그래프 진행/하단 안내를 다시 표시해 관찰하지 않습니다.
      다른 중지 사유가 남았을 때 실행이 재개되지 않는지 확인하고
      짧은 병합·늦은 결과는 결정적 통합 테스트 근거도 함께 확인합니다.
      둘째 사용자 환경 등 미확보 항목은 이유·영향을 반환합니다.
      M2에서 인정된 빠른 사용자 전환 미확인을 M3의 승인으로 자동 승계하지 않습니다.
  - 참조: SPEC §5.8, SPEC §5.9, SPEC §5.11, SPEC §5.15, SPEC §5.19,
    DESIGN §2.1, DESIGN §2.2, DESIGN §2.4, DESIGN §2.5, DESIGN §3.4, DESIGN §4.2, DESIGN §4.3

- [ ] task-016: Network의 시스템 도구 변화 방향 비교
  - 목적: 실제 다운로드·업로드에서 앱의 물리 대표값과 macOS 도구가
    같은 집계 범위의 변화 방향을 보여 주는지 확인합니다.
  - 접근: 한 Sandbox 앱 세션의 일반 모드·팝오버 열림에서
    다운로드와 업로드 각각 유휴 15초→부하 30초→회복 15초를 관찰합니다.
    `netstat -ibn`의 인터페이스별 Link 행 하나에서 원시 바이트·시각을 얻고
    앱과 같은 물리 대상 집합의 차분/실제 초로 B/s를 유도합니다.
    IPv4/IPv6 주소별 행을 더하지 않고 VPN 터널은 별도 표로 기록합니다.
    baseline-only·실패·전환 tick은 수치 비교에서 제외하되 원시 기록에는 남깁니다.
  - 검증 조건:
    - 결과: 두 부하 각각 해당 방향이 유휴보다 증가하고 종료 뒤 낮아지는 흐름이
      앱과 비교 자료에서 일치합니다.
      VPN 물리/터널 중복이나 단위·범위 차이를 같은 측정값으로 비교하지 않습니다.
      실제 부하가 유지되지 않은 구간은 성공 근거로 사용하지 않고 유효 구간을 다시 관찰합니다.
    - 확인: 원시 앱값·도구 출력·identity·단위·실제 시각·부하 시작/종료·화면과
      유휴/부하/회복 판정을 보존합니다.
      Network 카드·상세의 현재값·집계 범위·시각을 원자료와 대조하며 속도 그래프 화면을 관문으로 요구하지 않습니다.
      관찰 도구·증거 기록의 I/O를 제품 수집 활동과 구분하고
      Collector가 네트워크 요청이나 매 tick 외부 명령을 수행하지 않는지 소스도 확인합니다.
      새 수치 허용 오차·반복 횟수·출시 성능 기준을 추가하지 않습니다.
  - 참조: SPEC §5.5, SPEC §5.6, SPEC §5.13,
    DESIGN §1.2, DESIGN §3.3, DESIGN §3.4, DESIGN §4.1, DESIGN §4.4

- [ ] task-017: Disk의 시스템 도구 변화 방향 비교
  - 목적: 실제 대형 파일 읽기·쓰기에서 앱의 물리 Disk I/O와 macOS 도구가
    같은 측정 범위의 변화 방향을 보여 주는지 확인합니다.
  - 접근: 한 Sandbox 앱 세션의 일반 모드·팝오버 열림에서
    읽기와 쓰기 각각 유휴 15초→부하 30초→회복 15초를 관찰합니다.
    `iostat -d -w 1 <물리 BSD 장치 목록>`의 장치별 MB/s를
    앱의 같은 물리 범위 Read+Write 흐름과 비교합니다.
    Read·Write 방향은 드라이버의 해당 원시 바이트 변화와 부하 종류로 추가 확인합니다.
    캐시된 읽기가 물리 I/O를 만들지 않으면 실제 카운터가 증가하는 유효 부하로 다시 관찰합니다.
  - 검증 조건:
    - 결과: 물리 I/O를 발생시킨 읽기·쓰기에서 해당 방향과 합계가 부하 중 증가하고
      회복 구간에 낮아지는 흐름이 앱·원시 드라이버·도구와 일관됩니다.
      iostat 합계를 Read 전용·Write 전용으로 비교하지 않습니다.
      도구의 단위·초기 누적 구간·장치 범위 차이는 원문과 함께 구분됩니다.
    - 확인: 원시 앱 Read/Write·드라이버 바이트·도구 출력·대상 identity·단위·시각,
      부하 시작/종료·유효 구간·화면과 판정을 보존합니다.
      Disk 카드·상세의 현재값·물리 범위·시각을 원자료와 대조하며 속도 그래프 화면을 관문으로 요구하지 않습니다.
      baseline-only·실패·전환 tick은 수치 비교에서 제외하고 원자료에는 남깁니다.
      부하·관찰 도구·증거 기록 I/O와 앱 수집 활동을 구분하고
      Collector가 파일 읽기/쓰기 부하나 매 tick 외부 명령을 수행하지 않는지 확인합니다.
      새 수치 허용 오차나 M5 출시 관문을 추가하지 않습니다.
  - 참조: SPEC §5.6, SPEC §5.13,
    DESIGN §1.3, DESIGN §3.3, DESIGN §3.4, DESIGN §4.1, DESIGN §4.4

- [ ] task-018: 네 리소스 통합·CPU·Memory 회귀와 production 구성
  - 목적: 네 리소스가 한 앱 세션에서 함께 동작하고
    공통 경계·요약 통합이 기존 CPU·Memory와 배포·개인정보 계약을 훼손하지 않은 결과를 완성합니다.
  - 접근: 최종 coordinator·수집·표시 구성과 관련 상위 현재 구현 설명을 정리합니다.
    Debug·Release 및 기존·추가 단위/UI 테스트로 변경 범위를 확인하고
    실제 한 세션에서 팝오버 개폐·네 카드·상세 전환·스크롤·실제 CPU 부하의 메뉴바 반응을 확인합니다.
    초기 Sandbox 관찰용 임시 진입점은 정리하며 production은 공개 native API 경로만 사용합니다.
  - 검증 조건:
    - 결과: CPU·Memory 현재값·TOP 5·프로세스 귀속·상세·기존 그래프·선택/복귀·접근성이 유지되고
      Network·Disk 및 두 보조 흐름과 동시에 갱신됩니다.
      네 카드는264pt폭의 읽을 수 있는 축소 요약이며 CPU 최소241pt·Memory 자연 높이·Network/Disk112pt를 사용합니다.
      요약 기본 글꼴10pt 이상·대표17.33pt를 유지하며 Network 그래프·두 하단 경과 안내가 없습니다.
      Disk 수치 옆42pt 미니 그래프와 CPU 축소 판·Memory 구성·TOP 5 아래3pt가 유지되고 상세에 새 그래프가 없습니다.
      자연 높이 콘텐츠가 지원 화면에서 스크롤 없이 함께 보입니다.
      부족한 예외 화면에서는 사용자 정책 결정 경계를 보존합니다.
      수집·baseline·내부 이력·단위와 실제 창의 가장자리 여유·카드 앵커가 유지됩니다.
      실패·중지·주기 변경·카드에 앵커한 상세가 기존 동작을 깨뜨리지 않습니다.
      앱은 macOS 26.5 이상 Apple silicon·arm64 단일 실행 파일·App Sandbox를 유지하며
      Helper·관리자 권한·시스템 확장·권한 프롬프트·새 예외 entitlement·외부 package를 추가하지 않습니다.
      샘플·이력·보조 정보는 메모리에만 있고 파일·설정 저장소·외부 전송·재시작 복원 경로가 없습니다.
      Collector 자체에 부하 생성·외부 명령 경로가 없습니다.
      관련 상위 문서의 현재 구현 설명이 최종 원본과 일치하고 승인된 feature 결정이 유지됩니다.
    - 확인: 격리 빌드와 전체 단위·서명 UI suite 결과, 최종 diff와
      기존 CPU·Memory의 계산·집계·메뉴바 정책 회귀를 확인합니다.
      실제 한 세션의 네 카드·상세·일정·CPU 부하 메뉴바 반응을 관찰하고
      충분한/부족한 가용 높이에서 새 요약 구조·필수 정보·CPU·Memory 그래프 보존을 대조하며
      build settings·`codesign` entitlement·`lipo` 아키텍처·번들 실행 파일·target/package 목록과
      영속화/외부 전송/외부 명령 소스 경로를 검사합니다.
      앞 Task의 실제 Sandbox·연결·중지·작은 화면·변화 방향 근거를 현재 원본과 대조하며
      미확인 필수 항목을 통합 성공으로 덮지 않습니다.
      상위 설명 갱신이 요구사항·설계 변경을 필요로 하면 해당 소유 단계로 반환합니다.
  - 참조: SPEC §5.1, SPEC §5.2, SPEC §5.3, SPEC §5.4, SPEC §5.8,
    SPEC §5.10, SPEC §5.11, SPEC §5.12, SPEC §5.13, SPEC §5.14,
    SPEC §5.15, SPEC §5.16, SPEC §5.18, SPEC §5.19,
    DESIGN §1.1, DESIGN §2.1, DESIGN §2.4, DESIGN §2.5,
    DESIGN §3.2, DESIGN §3.3, DESIGN §3.4, DESIGN §3.5, DESIGN §4.1, DESIGN §4.2, DESIGN §4.3

## 완료 조건 매핑

각 적용 중인 완료 조건은 아래 Task가 모두 현재 원본 기준으로 승인돼야 충족됩니다.
SPEC §5.17과 task-009는 철회 이력이며 현재 완료 관문에 포함하지 않습니다.

| 완료 조건 | Task |
| --- | --- |
| SPEC §5.1 | task-001, task-005, task-010, task-018 |
| SPEC §5.2 | task-002, task-006, task-011, task-018 |
| SPEC §5.3 | task-001, task-005, task-010, task-013, task-014, task-018 |
| SPEC §5.4 | task-002, task-006, task-011, task-013, task-014, task-018 |
| SPEC §5.5 | task-001, task-005, task-010, task-014, task-016 |
| SPEC §5.6 | task-016, task-017 |
| SPEC §5.7 | task-001, task-002, task-005, task-006, task-008, task-014 |
| SPEC §5.8 | task-003, task-004, task-005, task-006, task-011, task-015, task-018 |
| SPEC §5.9 | task-002, task-003, task-005, task-006, task-011, task-014, task-015 |
| SPEC §5.10 | task-002, task-004, task-006, task-007, task-008, task-010, task-011, task-018 |
| SPEC §5.11 | task-003, task-004, task-005, task-006, task-007, task-008, task-015, task-018 |
| SPEC §5.12 | task-008, task-010, task-011, task-012, task-013, task-018 |
| SPEC §5.13 | task-001, task-002, task-007, task-014, task-016, task-017, task-018 |
| SPEC §5.14 | task-008, task-010, task-011, task-012, task-013, task-018 |
| SPEC §5.15 | task-003, task-008, task-010, task-011, task-012, task-013, task-015, task-018 |
| SPEC §5.16 | task-010, task-011, task-012, task-013, task-018 |
| SPEC §5.17 | [철회] 이력만 보존; 현재 완료 관문 없음 |
| SPEC §5.18 | task-001, task-002, task-006, task-008, task-010, task-011, task-014, task-018 |
| SPEC §5.19 | task-011, task-012, task-013, task-015, task-018 |
