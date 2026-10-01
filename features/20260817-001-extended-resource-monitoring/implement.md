# Network·Disk 확장 리소스 모니터링 구현

## 기준

승인된 [spec.md](./spec.md)의 완료 조건 §5.1~§5.18과
[design.md](./design.md)의 채택된 설계를 순서 있는 Task로 나눕니다.
의존 순서는 아래 항목 위치로 표현하며 승인 상태는 각 Task의 체크박스와 승인 근거를 따릅니다.

기존 CPU·Memory 수집·계산·프로세스 집계·TOP 5·메뉴바 판정과
완료된 대시보드 시각 규칙을 회귀 기준으로 사용합니다.
Network 대표값은 물리 인터페이스 합계이며 VPN·터널은 상세 전용입니다.
프로세스별 Disk I/O, 사용자 설정, 캐릭터 애니메이션과 M5의 출시 수치 관문은 추가하지 않습니다.

코드 조사 출발점은 `ResourceRunner/ApplicationCoordinator.swift`,
`MonitoringLifecycle.swift`, `MonitoringScheduler.swift`, `SystemLifecycleObserver.swift`,
`DashboardPresentation.swift`, `DashboardPresentationStore.swift`, `DashboardView.swift`,
`StatusBarController.swift`와 관련 `ResourceRunnerTests`·`ResourceRunnerUITests`입니다.
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

- [ ] task-004: 여섯 축 일정과 보조 조회의 독립 실행
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

- [ ] task-005: Network 속도·identity·보조 캐시와 최근 이력
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
      실패·baseline-only·중지·topology 변경·카운터 재설정에서 선분을 끊습니다.
      제거 대상별 장기 이력을 별도로 축적하지 않습니다.
    - 확인: 실제 경과 시간과 주기 전환, 모든 baseline-only 원인,
      동일 이름·index 재사용·revision 병합·캐시 불일치,
      물리/VPN 동시 트래픽·부분 실패·제거를 결정적 source·store 테스트로 확인합니다.
      601개 용량·축출·600초 시각 선별·짧은 실패의 segment 단절과
      늦은 결과의 baseline·최신값·이력 불변성을 확인합니다.
      미수집 tick이 0·빈 점으로 저장되지 않고 정상 5초→1초 변경에서 기준점·이력이 유지되는지 확인합니다.
  - 참조: SPEC §5.1, SPEC §5.3, SPEC §5.5, SPEC §5.7, SPEC §5.8,
    SPEC §5.9, SPEC §5.11, SPEC §5.17,
    DESIGN §1.1, DESIGN §1.2, DESIGN §2.2, DESIGN §2.3, DESIGN §2.4, DESIGN §2.5, DESIGN §3.1

- [ ] task-006: Disk 속도·장치 수명·용량 캐시와 최근 이력
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
    SPEC §5.10, SPEC §5.11, SPEC §5.17, SPEC §5.18,
    DESIGN §1.1, DESIGN §1.3, DESIGN §1.4, DESIGN §2.2, DESIGN §2.3,
    DESIGN §2.4, DESIGN §2.5, DESIGN §3.1, DESIGN §3.2

- [ ] task-007: production 여섯 축 배선과 실패 격리
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

- [ ] task-008: 활동·보조 상태 조립과 지표별 단위
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

- [ ] task-009: 두 독립 속도 계열과 공통 그래프 판
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

- [ ] task-010: Network 요약 카드와 인터페이스 상세
  - 목적: Network 카드에서 현재 송수신·활성 종류·대상 수·최근 그래프를 확인하고
    카드 옆 상세에서 현재 인터페이스별 정보를 읽을 수 있게 합니다.
  - 접근: 제목 12pt, 두 수치 68pt, 보조 정보 32pt, 그래프 118pt와
    구역 간격·padding 64pt의 294pt 고정 슬롯으로 카드를 구성합니다.
    상세에 현재 대상별 RX·TX·IPv4/IPv6·원시 누적량·연결 상태·복수 활성 상태,
    확인된 물리/논리/VPN/터널 구분과 조건부 링크 속도·지원 사유를 제공합니다.
    긴 이름은 상세에서 온전히 표시하고 프로세스 목록을 추가하지 않습니다.
    공통 선택·닫힘 경로에 Network를 추가합니다.
  - 검증 조건:
    - 결과: 요약의 물리 대표값과 VPN·터널 상세 범위가 구분됩니다.
      현재 속도·누적량·링크 속도가 이름·단위·설명으로 구별되고
      연결 없음·필수 일부 실패·보조 상태·중지에서도 슬롯이 같습니다.
      최초 값·정상·실패·중지·보조 실패·최장 표기·로케일에서 카드 크기가 변하지 않습니다.
      상세는 카드 옆 팝업으로 열리고 같은 카드 선택·명시적 닫기로 요약에 복귀합니다.
    - 확인: 카드 렌더 크기·슬롯·최장 문구·로케일과
      표시 원본/화면/접근성 문자열의 대응을 확인합니다.
      실제 UI에서 상세 항목·누적/현재 구분·VPN/터널 표기와 개폐 전후 카드 frame을 확인합니다.
      294pt 슬롯에 맞지 않으면 글꼴·그래프 높이를 임의 축소하지 않고 DESIGN 문제로 반환합니다.
      전체 키보드·AX 도달은 task-013에서 확인합니다.
  - 참조: SPEC §5.1, SPEC §5.3, SPEC §5.5, SPEC §5.12,
    SPEC §5.14, SPEC §5.15, SPEC §5.18,
    DESIGN §1.2, DESIGN §2.3, DESIGN §3.2, DESIGN §3.3, DESIGN §3.5, DESIGN §4.2

- [ ] task-011: Disk 요약 카드와 장치·볼륨 상세
  - 목적: Disk 카드에서 현재 입출력·시스템 용량·최근 그래프를 확인하고
    카드 옆 상세에서 현재 장치·볼륨·외장 상태를 구분해 읽을 수 있게 합니다.
  - 접근: Network와 같은 294pt 고정 슬롯에 Read·Write,
    `/`의 전체·사용 가능한 공간과 최근 그래프를 배치합니다.
    저장 공간이 별도 느린 주기로 갱신됨과 마지막 갱신 시각을 제공합니다.
    상세에 볼륨별 전체·사용 중·사용 가능, 공유 공간 설명,
    물리 장치별 속도·드라이버 누적 바이트·조건부 IOPS·외장/마운트 상태와
    미확인 관계·지원 사유를 표시합니다.
    사용 중의 `전체 − 사용 가능` 정의를 상시 설명과 AX에 포함하며
    공통 선택·닫힘 경로에 Disk를 추가합니다.
  - 검증 조건:
    - 결과: 실시간 속도와 느린 용량의 시각·상태가 구별되고
      보조 실패 중에도 현재 속도가 계속 갱신됩니다.
      APFS 공유 공간을 볼륨 독점 사용량이나 합산 장치 용량으로 표시하지 않습니다.
      IOPS는 드라이버 작업 수의 회/s이며 앱 요청 수로 설명하지 않습니다.
      연결 장치·마운트 볼륨·미마운트 장치·외장 없음·조회 실패가 구별됩니다.
      모든 상태·최장 표기·로케일에서 같은 슬롯을 유지하고 상세 개폐가 카드를 움직이지 않습니다.
    - 확인: 원본/표시 모델/화면에서 용량·누적량·현재 속도·IOPS 정의와 시각을 대조합니다.
      렌더 측정으로 294pt 슬롯·자리표시·상태 전이 불변성을 확인하고
      실제 UI에서 상세 항목·공유 공간 설명·외장 상태와 선택·복귀를 확인합니다.
      슬롯에 맞지 않으면 DESIGN 문제로 반환합니다.
      전체 키보드·AX 도달은 task-013에서 확인합니다.
  - 참조: SPEC §5.2, SPEC §5.4, SPEC §5.10, SPEC §5.12,
    SPEC §5.14, SPEC §5.15, SPEC §5.18,
    DESIGN §1.3, DESIGN §1.4, DESIGN §2.3, DESIGN §3.2, DESIGN §3.3, DESIGN §3.5, DESIGN §4.2

- [ ] task-012: 네 카드 본체와 상세의 화면별 viewport
  - 목적: 화면 가용 영역 안에서 네 카드와 넘치는 상세 내용에 도달하고
    데이터·상태·상세 개폐로 본체와 카드 배치가 흔들리지 않게 합니다.
  - 접근: 폭 280pt의 한 열 `ScrollView`에
    CPU 329pt→Memory 224pt→Network 294pt→Disk 294pt를 eager 컨테이너로 배치합니다.
    카드 사이 16pt·본체 padding 16pt의 콘텐츠 높이 1221pt를 유지하고
    viewport는 최대 601pt로 제한합니다.
    `StatusBarController`가 상태 항목 화면의 `visibleFrame`과 실제 popover chrome를 전달해
    위·아래 8pt 여유 안에서 viewport만 줄입니다.
    상세도 최대 400×480pt에서 화면별 viewport를 제한하고 내용은 내부 스크롤로 제공합니다.
    카드 옆 앵커·macOS 가장자리 배치를 유지하고 실제 창 frame으로 chrome 차이를 보정합니다.
  - 검증 조건:
    - 결과: 같은 화면 환경에서 값·상태·상세 개폐로 viewport와 카드 크기가 바뀌지 않습니다.
      네 카드의 그래프 높이를 개별 축소하지 않으며 마지막 카드와 상세 끝까지 마우스로 도달합니다.
      첫·중간·마지막 카드의 상세가 화면 가용 영역 안에서 열립니다.
      본체는 상세용 공간을 예약하지 않고 별도 독립 창을 만들지 않습니다.
    - 확인: 화면별 계산·콘텐츠 높이·카드 높이와 상태별 렌더를 확인합니다.
      실제 사용 가능한 가장 작은 가용 영역·배율·메뉴바 위치를 기록하고
      본체/상세의 실제 frame, 화면 가장자리 배치와 스크롤 전후 도달을 관찰합니다.
      고정 스크롤 위치에서 최초·정상·실패·중지·연결 없음·보조 실패·상세 개폐의
      카드 크기·상대 위치를 대조합니다.
      가상 viewport만으로 실기기 관문을 승인하지 않고 화면 미확보와 영향을 반환합니다.
      새로운 최소 해상도 정책은 만들지 않습니다.
  - 참조: SPEC §5.15, SPEC §5.16,
    DESIGN §3.3, DESIGN §3.5, DESIGN §4.1, DESIGN §4.2, DESIGN §4.3

- [ ] task-013: 오프스크린 선택·키보드 복귀와 접근성 도달
  - 목적: 키보드 탐색 기본 설정에서도 네 카드와 각 상세의 넘치는 정보를 사용할 수 있고
    색상 없이 현재 상태·지표 의미를 식별할 수 있게 합니다.
  - 접근: eager 카드 Button에 ⌘1·⌘2를 유지하고 Network ⌘3·Disk ⌘4를 등록합니다.
    오프스크린 선택에서는 해당 앵커가 보이도록 스크롤한 뒤 배치 완료를 확인해 상세를 엽니다.
    같은 카드 선택은 닫기, 다른 카드 선택은 전환으로 처리하며
    이전 팝업 닫힘 callback은 현재 선택과 일치할 때만 해제합니다.
    명시적 닫기·Escape와 카드 포커스 복귀,
    본체 Page Up/Down·상세 선택 중 상세 Page Up/Down을 제공합니다.
    상세에서 부모 단축키가 작동하는 key-window 계약을 유지합니다.
  - 검증 조건:
    - 결과: 처음 화면 밖에 있는 Network·Disk도 단축키로 앵커 이동 후 상세가 열립니다.
      빠른 카드 전환이나 늦은 callback이 새 선택을 지우지 않습니다.
      키보드로 상세 끝까지 도달하고 선택·복귀 뒤 카드로 포커스가 돌아옵니다.
      카드 AX 이름에 리소스·상태·주요 수치·단축키가,
      상세 AX에 대상 이름·종류·현재/누적 구분·값·상태와 필수 일부 실패가 제공됩니다.
      상태 라벨·상징과 그래프 선 모양으로 색상 없이도 구분합니다.
    - 확인: 기본 키보드 설정의 실제 UI에서 첫·중간·마지막 카드,
      ⌘1~⌘4 반복·전환·명시적 닫기·Escape·포커스 복귀·Page Up/Down을 확인합니다.
      offscreen 앵커 배치 전 상세가 열리지 않는지와 부모/자식 key-window 전환을 확인합니다.
      AX 계층에서 Network·Disk 상세 행과 넘치는 내용을 조회하고
      task-012의 실제 작은 화면에서도 마우스·키보드로 전 항목에 도달하는지 확인합니다.
      접근성 문자열 단위 테스트와 실제 AX 부착을 구분하며 VoiceOver 실제 낭독은 M5 범위로 둡니다.
  - 참조: SPEC §5.3, SPEC §5.4, SPEC §5.12, SPEC §5.14, SPEC §5.15, SPEC §5.16,
    DESIGN §3.2, DESIGN §3.5, DESIGN §4.2, DESIGN §4.3

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
      카드·상세·그래프 화면을 대조합니다.
      VPN 서비스와 터널 분류 근거, 외장 장치의 연결 특성과 드라이버 ID를 기록합니다.
      장비·VPN 미확보는 해당 항목·이유·영향을 반환하며 mock 통과로 실제 관문을 대체하지 않습니다.
  - 참조: SPEC §5.3, SPEC §5.4, SPEC §5.5, SPEC §5.7, SPEC §5.9, SPEC §5.13, SPEC §5.18,
    DESIGN §1.2, DESIGN §1.3, DESIGN §1.4, DESIGN §2.2, DESIGN §2.3,
    DESIGN §3.2, DESIGN §4.3

- [ ] task-015: 실제 시스템 sleep/wake와 화면 중지·재개
  - 목적: 실제 수면·화면 중지 뒤 첫 속도 샘플이 기준점 전용이고
    중지 구간이 그래프의 공백으로 보존되는지 확인합니다.
  - 접근: 같은 Sandbox 앱에서 시스템 sleep/wake, 화면 잠금/해제,
    디스플레이 sleep/wake와 빠른 사용자 전환/복귀를 수행합니다.
    모든 축의 적용 일정·boundary sequence·epoch·허용 token·샘플 누적 수,
    첫 두 카운터 snapshot·실제 읽기 시각·rate segment·화면을 기록합니다.
    복귀 때 다른 중지 이유가 남는 경우도 확인합니다.
  - 검증 조건:
    - 결과: 중지 구간에 수집값·이력이 새로 반영되지 않고
      Network·Disk 재개 첫 snapshot은 수면 시간을 나눈 속도 없이 baseline만 갱신합니다.
      두 번째 유효 snapshot부터 실제 경과 시간의 속도를 제공합니다.
      중지 전후 점이 이어지지 않고 짧은 중지와 wake 경계도 보존됩니다.
      중지 전 늦은 결과가 baseline·현재값·이력·표시를 바꾸지 않습니다.
      기존 CPU 재개 baseline·Memory 순간값·메뉴바와 화면 상태 계약도 유지됩니다.
    - 확인: 각 실제 전이의 시각·알림·여섯 축 샘플 수·원시 카운터·계산 결과와
      그래프/카드 상태를 대조합니다.
      다른 중지 사유가 남았을 때 실행이 재개되지 않는지 확인하고
      짧은 병합·늦은 결과는 결정적 통합 테스트 근거도 함께 확인합니다.
      둘째 사용자 환경 등 미확보 항목은 이유·영향을 반환합니다.
      M2에서 인정된 빠른 사용자 전환 미확인을 M3의 승인으로 자동 승계하지 않습니다.
  - 참조: SPEC §5.8, SPEC §5.9, SPEC §5.11, SPEC §5.15,
    DESIGN §2.1, DESIGN §2.2, DESIGN §2.4, DESIGN §2.5, DESIGN §4.2, DESIGN §4.3

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
      관찰 도구·증거 기록의 I/O를 제품 수집 활동과 구분하고
      Collector가 네트워크 요청이나 매 tick 외부 명령을 수행하지 않는지 소스도 확인합니다.
      새 수치 허용 오차·반복 횟수·출시 성능 기준을 추가하지 않습니다.
  - 참조: SPEC §5.5, SPEC §5.6, SPEC §5.13,
    DESIGN §1.2, DESIGN §4.1, DESIGN §4.4

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
      baseline-only·실패·전환 tick은 수치 비교에서 제외하고 원자료에는 남깁니다.
      부하·관찰 도구·증거 기록 I/O와 앱 수집 활동을 구분하고
      Collector가 파일 읽기/쓰기 부하나 매 tick 외부 명령을 수행하지 않는지 확인합니다.
      새 수치 허용 오차나 M5 출시 관문을 추가하지 않습니다.
  - 참조: SPEC §5.6, SPEC §5.13,
    DESIGN §1.3, DESIGN §4.1, DESIGN §4.4

- [ ] task-018: 네 리소스 통합·CPU·Memory 회귀와 production 구성
  - 목적: 네 리소스가 한 앱 세션에서 함께 동작하고
    공통 경계·스크롤 확장이 기존 CPU·Memory와 배포·개인정보 계약을 훼손하지 않은 결과를 완성합니다.
  - 접근: 최종 coordinator·수집·표시 구성과 관련 상위 현재 구현 설명을 정리합니다.
    Debug·Release 및 기존·추가 단위/UI 테스트로 변경 범위를 확인하고
    실제 한 세션에서 팝오버 개폐·네 카드·상세 전환·스크롤·실제 CPU 부하의 메뉴바 반응을 확인합니다.
    초기 Sandbox 관찰용 임시 진입점은 정리하며 production은 공개 native API 경로만 사용합니다.
  - 검증 조건:
    - 결과: CPU·Memory 현재값·TOP 5·프로세스 귀속·상세·기존 그래프·선택/복귀·접근성이 유지되고
      Network·Disk 및 두 보조 흐름과 동시에 갱신됩니다.
      실패·중지·주기 변경·오프스크린 상세가 기존 동작을 깨뜨리지 않습니다.
      앱은 macOS 26.5 이상 Apple silicon·arm64 단일 실행 파일·App Sandbox를 유지하며
      Helper·관리자 권한·시스템 확장·권한 프롬프트·새 예외 entitlement·외부 package를 추가하지 않습니다.
      샘플·이력·보조 정보는 메모리에만 있고 파일·설정 저장소·외부 전송·재시작 복원 경로가 없습니다.
      Collector 자체에 부하 생성·외부 명령 경로가 없습니다.
      관련 상위 문서의 현재 구현 설명이 최종 원본과 일치하고 승인된 feature 결정이 유지됩니다.
    - 확인: 격리 빌드와 전체 단위·서명 UI suite 결과, 최종 diff와
      기존 CPU·Memory의 계산·집계·메뉴바 정책 회귀를 확인합니다.
      실제 한 세션의 네 카드·상세·일정·CPU 부하 메뉴바 반응을 관찰하고
      build settings·`codesign` entitlement·`lipo` 아키텍처·번들 실행 파일·target/package 목록과
      영속화/외부 전송/외부 명령 소스 경로를 검사합니다.
      앞 Task의 실제 Sandbox·연결·중지·작은 화면·변화 방향 근거를 현재 원본과 대조하며
      미확인 필수 항목을 통합 성공으로 덮지 않습니다.
      상위 설명 갱신이 요구사항·설계 변경을 필요로 하면 해당 소유 단계로 반환합니다.
  - 참조: SPEC §5.1, SPEC §5.2, SPEC §5.3, SPEC §5.4, SPEC §5.8,
    SPEC §5.10, SPEC §5.11, SPEC §5.12, SPEC §5.13, SPEC §5.14,
    SPEC §5.15, SPEC §5.16, SPEC §5.17, SPEC §5.18,
    DESIGN §1.1, DESIGN §2.1, DESIGN §2.4, DESIGN §2.5,
    DESIGN §3.2, DESIGN §3.3, DESIGN §3.4, DESIGN §3.5, DESIGN §4.1, DESIGN §4.2, DESIGN §4.3

## 완료 조건 매핑

각 완료 조건은 아래 Task가 모두 현재 원본 기준으로 승인돼야 충족됩니다.

| 완료 조건 | Task |
| --- | --- |
| SPEC §5.1 | task-001, task-005, task-009, task-010, task-018 |
| SPEC §5.2 | task-002, task-006, task-009, task-011, task-018 |
| SPEC §5.3 | task-001, task-005, task-010, task-013, task-014, task-018 |
| SPEC §5.4 | task-002, task-006, task-011, task-013, task-014, task-018 |
| SPEC §5.5 | task-001, task-005, task-010, task-014, task-016 |
| SPEC §5.6 | task-016, task-017 |
| SPEC §5.7 | task-001, task-002, task-005, task-006, task-008, task-014 |
| SPEC §5.8 | task-003, task-004, task-005, task-006, task-009, task-015, task-018 |
| SPEC §5.9 | task-002, task-003, task-005, task-006, task-009, task-014, task-015 |
| SPEC §5.10 | task-002, task-004, task-006, task-007, task-008, task-011, task-018 |
| SPEC §5.11 | task-003, task-004, task-005, task-006, task-007, task-008, task-015, task-018 |
| SPEC §5.12 | task-008, task-009, task-010, task-011, task-013, task-018 |
| SPEC §5.13 | task-001, task-002, task-007, task-014, task-016, task-017, task-018 |
| SPEC §5.14 | task-008, task-010, task-011, task-013, task-018 |
| SPEC §5.15 | task-003, task-008, task-009, task-010, task-011, task-012, task-013, task-015, task-018 |
| SPEC §5.16 | task-012, task-013, task-018 |
| SPEC §5.17 | task-005, task-006, task-009, task-018 |
| SPEC §5.18 | task-001, task-002, task-006, task-008, task-010, task-011, task-014, task-018 |
