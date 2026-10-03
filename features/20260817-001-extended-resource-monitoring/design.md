# Network·Disk 확장 리소스 모니터링 설계

## 근거

이 문서는 승인된 [spec.md](./spec.md)의 현재 적용 중인 완료 조건을 구현 Task 작성에 필요한 계약으로 구체화합니다.
2026-10-03 최신 개정에서는 승인된 280×590pt 축소 샘플에 따라 네 요약 카드를 함께 표시합니다.
Network 요약에는 그래프를 표시하지 않고 Disk는 작은 수치 옆에 42pt 미니 그래프를 제공합니다.
CPU 그래프는 약 2/3 높이로 줄이고 Memory 구성 바와 두 카드의 TOP 5 정보를 유지합니다.
Network·Disk 하단의 측정·보조 정보·용량 확인 경과 안내는 제거하며 TOP 5 제목 아래에 3pt 여백을 추가합니다.
SPEC §5.17은 번호를 보존한 철회 항목이고 Disk 미니 그래프는 새 SPEC §5.19를 따릅니다.
CPU·Memory의 최근 그래프 10분, 물리 인터페이스 합계·VPN 터널 상세 전용, 프로세스별 Disk I/O 제외,
M3의 변화 방향 비교와 M5의 출시 수치 관문 분리를 유지합니다.

### 2026-10-01 최초 설계의 원본과 적용 기준

- 프로젝트 루트: `/Users/zipkero/XcodeProjects/ResourceRunner`.
- 조사 기준 HEAD: `002414b13524606096ef9f4f41057dcbf9005fe0`.
- feature `README.md`: `SPEC [x]`, `DESIGN [ ]`, `IMPLEMENT [ ]`.
- 이 호출에서 읽은 미커밋 `spec.md` SHA-256:
  `4af0754e1087cac25e8998f74cb38885e30619d622fc7e66594b717800f451e2`.
- 이 호출에서 읽은 미커밋 feature `README.md` SHA-256:
  `86e15b7353af188187e6d52022e4ad85b1f07801248ccd146576845390b6ac04`.
- 기존 `design.md`·`implement.md`는 없습니다.
- 프로젝트 `AGENTS.md` 파일은 없으며 호출에 전달된 프로젝트 지침을 적용했습니다.
- 작성·상태 계약은 `/Users/zipkero/.codex/skills/design-init/SKILL.md`와
  `/Users/zipkero/.codex/docs/phased-state.md`를 직접 읽었습니다.
- 상위 입력은 `README.md`, `ROADMAP.md`, `docs/product.md`, `docs/design.md`입니다.
- M2의 `README.md`·`spec.md`·`design.md`·`implement.md`에서 현재 승인과 DP11의
  중지 epoch·기준점·그래프 단절 계약을 확인했습니다.
- `dashboard-visual-language`와 `graph-plot-surface` 문서의 카드 면·타이포·그래프 판·기준선·
  자리표시·접근성 기준을 적용합니다.
- 미커밋 `CONTEXT.md`·`ROADMAP.md`·feature README·SPEC은 이 문서의 변경 대상이 아닙니다.

### 최초 설계 시점의 코드에서 확인한 사실

- `ApplicationCoordinator.swift`는 시스템 CPU·Memory와 프로세스 조사 두 수집 축을 구성합니다.
- `MonitoringScheduler.swift`는 정상 주기 교체의 `generation`과 실제 중지의 `collectionEpoch`를 구분합니다.
- `SystemMetricsSampleSource.swift`는 CPU·Memory의 실패를 각각 `Result`로 전달하고,
  오래된 epoch를 거부하며 CPU 기준점을 초기화합니다.
- `MonitoringSampleStore.swift`는 최신 스냅샷과 601개 고정 이력 링을 분리합니다.
- `SystemLifecycleObserver.swift`는 화면 잠금·디스플레이 슬립·세션 활성·저전력을 관찰합니다.
  시스템 전체의 `willSleep`·`didWake`는 아직 배선되지 않았습니다.
- 시스템 snapshot의 stream은 `.bufferingNewest(1)`이며 현재 중지 표시 이벤트는 `Void`입니다.
  Network·Disk 추가 시 짧은 중지 전이 보존과 늦은 결과의 표시 순서를 보강해야 합니다.
- `DashboardView.swift`는 폭 280pt·콘텐츠 높이 601pt의 스크롤 없는 본체와
  400×480pt의 카드 옆 상세를 사용합니다.
- CPU·Memory 카드 높이는 현재 회귀 기준에서 각각 329pt·224pt입니다.
- `HistoryGraphView`는 CPU의 누적 밴드와 0~100% 변환에 묶여 있습니다.
  Network·Disk의 두 독립 속도를 이 밴드 의미에 넣지 않습니다.
- `DashboardPresentationStore.swift`의 카드와 선택 대상은 CPU·Memory 두 개입니다.

### 2026-10-03 그래프 제거 개정의 원본과 적용 기준 — 역사적 기록

- 기준 HEAD: `e63e5151579c183267613c22e3b49bea7cc6c506`.
- 읽은 미커밋 SPEC SHA-256: `a209272ee62ac73c3ebbcd4298c26b96457e7fa64c9aba69883c738816a7f2ed`.
- 개정 대상 DESIGN 읽기 기준 SHA-256: `1d7ab4a45a01d48f8a63feb703aadb8f6a4ccbd90dfb363a2ebb8a9d7adee53f`.
- 최신 README·implement.md와 미커밋 DashboardViewport·DashboardView·NetworkDashboardView·
  DiskDashboardView·StatusBarController·ApplicationCoordinator를 읽었습니다.
- 현재 두 요약 코드의 118pt 그래프와 범례·범위, 부분 DashboardViewport의 294pt 카드·601pt 상한은 아래 개정의 완료 구현이 아닙니다.
- ApplicationCoordinator는 같은 viewport를 본체·상세·StatusBarController에 전달합니다.
  기존 여섯 수집 축·source·store·소비 경로는 이번 표시 개정의 변경 대상이 아닙니다.
- 프로젝트 AGENTS.md 파일은 없으며 전달된 지침·design-init·phased-state 계약을 적용했습니다.
- 아래 최초 API 조사는 역사적 근거이며 현재 구현·검증 완료를 대신하지 않습니다.

### 2026-10-03 승인된 축소 샘플 개정의 원본과 적용 기준

- 기준 HEAD: `e63e5151579c183267613c22e3b49bea7cc6c506`.
- 승인 샘플은 `/tmp/ResourceRunner-compact-preview-20261003/Preview.swift`이며 하단 안내 두 행 제거와 TOP 5 제목 bottom padding 3pt가 반영되었습니다.
  읽기 기준 SHA-256은 `c89ff607d935459037afc71512da0aa0b1c52e84e2b4a9edf0eb0c5ca3d578d2`입니다.
  샘플의 고정 수치·앱 이름·대체 아이콘은 배치 예시이며 실제 수집값·기존 앱 아이콘을 대체하지 않습니다.
- 현재 `DashboardView.swift`는 280×601pt ScrollView와 기존 CPU·Memory 요약을 사용합니다.
  `NetworkDashboardView.swift`는 미커밋 160pt 카드, `DiskDashboardView.swift`는 294pt 카드입니다.
  이 호출에서 `DashboardViewport.swift`는 존재하지 않고 coordinator·StatusBarController에도 이전 개정 기록의 viewport 전달 배선은 없습니다.
  위 역사적 기록을 현재 구현 사실로 사용하지 않습니다.
- `DashboardStyle.swift`, `DashboardView.swift`의 CPU·Memory·TOP 5·CPU graph,
  `ResourceRateGraph.swift`, `ResourceRateGraphView.swift`, `ResourceQuantityFormatter.swift`와 관련 선행 시각·판 계약을 조사 출발점으로 읽었습니다.
  현재 formatter는 1024 기반 선택 단위·로케일·그룹 구분·소수 한 자리와 작은 양수의 `<0.1` 원칙을 사용합니다.
- 프로젝트 AGENTS.md 파일은 없으며 전달된 프로젝트 지침과 design-init·phased-state 계약을 적용했습니다.
  기존 미커밋 제품·문서 변경은 새 표시의 완료 근거가 아니며 현재 계약에 맞는 부분만 재사용합니다.

### 최초 API 조사 근거와 한계

조사 환경은 macOS 26.6.2 Apple silicon, macOS SDK 26.5입니다.
아래 SDK 경로의 기준은
`/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk`입니다.

- `usr/include/net/if.h`, `net/if_var.h`, `sys/socket.h`:
  `NET_RT_IFLIST2`, `if_msghdr2`, `if_data64.ifi_ibytes`·`ifi_obytes`의 64비트 카운터.
- `SystemConfiguration.framework/.../Headers/SCNetworkConfiguration.h`:
  `SCNetworkInterfaceCopyAll`, BSD 이름·인터페이스 유형과 계층 인터페이스 조회.
- `IOKit.framework/.../Headers/IOKitLib.h`:
  registry entry ID와 부모·자식 탐색. ID는 재부팅 전까지 registry 객체 식별에 사용할 수 있습니다.
- `IOKit.framework/.../Headers/storage/IOBlockStorageDriver.h`:
  `Statistics`의 `Bytes (Read)`·`Bytes (Write)`와 `Operations (Read)`·`Operations (Write)`.
  바이트 카운터는 해당 드라이버가 생성된 이후의 누적값입니다.
- `IOKit.framework/.../Headers/storage/IOMedia.h`, `IOStorageProtocolCharacteristics.h`:
  whole media·removable·ejectable 및 물리 연결·가상 연결 구분.
- `DiskArbitration.framework/.../Headers/DADisk.h`:
  볼륨 경로에서 디스크 조회, description·IOMedia·whole disk 조회.
- `usr/include/sys/mount.h`, Foundation의 볼륨 resource keys:
  마운트 목록과 전체·사용 가능한 용량 조회.
- `AppKit.framework/.../Headers/NSWorkspace.h`:
  시스템 sleep/wake, 디스플레이 sleep/wake, 마운트·해제 알림.
- 설치된 `netstat(1)`·`iostat(8)` 매뉴얼:
  인터페이스 바이트와 장치 전송 속도의 비교 범위·옵션.

읽기 전용 native 조사에서 다음을 확인했습니다.

- `SCNetworkInterfaceCopyAll`은 이 기기의 `en0`을 IEEE80211, 다른 `en*`를 Ethernet으로 반환합니다.
- `IONetworkInterface`에는 실제 물리 인터페이스 외에 `vmenet*`도 있습니다.
  `vmenet*`는 `IOResources/IOUserEthernetController` 경로여서 이름·Ethernet 유형만으로
  물리 인터페이스라고 판정할 수 없습니다.
- 실제 시스템 볼륨은 `disk3s1s1`이며 `DADiskCopyWholeDisk` 결과는 APFS 논리 장치 `disk3`입니다.
  IOService 부모 경로를 따라가면 `disk0s2`·물리 `disk0`·`IOBlockStorageDriver`에 도달합니다.
- `/`와 `/System/Volumes/Data`에서 전체·사용 가능한 용량이 같은 값으로 조회됐습니다.
  APFS의 공유 용량을 볼륨별로 더하면 중복됩니다.
- 물리 저장 장치 드라이버의 누적 Bytes·Operations가 조회됐습니다.

이 조사는 비Sandbox 명령행 프로세스의 원본·API 조사입니다.
새 Collector의 Sandbox 실행이나 기능 검증 완료를 뜻하지 않습니다.
과거 상위 문서의 Sandbox 접근 표도 이번 IMPLEMENT 승인 근거를 대체하지 않습니다.

## 1. 구조

### 1.1 수집 책임과 실행 축

기존 CPU·Memory 시스템 축과 프로세스 조사 축을 보존하고 네 축을 추가합니다.

| 축 | 책임 | 저장 대상 |
| --- | --- | --- |
| systemMetrics | 기존 CPU·Memory 순간값·CPU 차분 | 기존 MonitoringSampleStore |
| processSurvey | 기존 프로세스·앱 순위 | 기존 ProcessHistoryStore |
| networkActivity | 인터페이스 누적 바이트·현재 RX/TX | NetworkActivityStore |
| diskActivity | 물리 장치 누적 바이트·현재 Read/Write | DiskActivityStore |
| networkMetadata | 유형·주소·연결 상태·조건부 링크 속도 | NetworkMetadataStore |
| storageMetadata | 볼륨 용량·장치 관계·외장 상태 | StorageMetadataStore |

Network·Disk 속도는 별도의 source·scheduler·store를 가집니다.
한 native 조회의 실패·지연이 다른 세 카드의 호출이나 표시 전달을 기다리게 하지 않습니다.
보조 정보 축도 빠른 속도 축과 actor·실행 작업을 공유하지 않습니다.
동기 native 호출은 MainActor 밖에서 실행합니다. (`SPEC §5.10`, `SPEC §5.11`)

빠른 축은 카운터와 식별·현재 집합을 확인하는 최소 조회만 수행합니다.
주소 전체 조립·볼륨 용량 조회·장치와 볼륨 관계 탐색은 보조 축이 담당합니다.
캐시는 대상 정체성과 topology revision으로 연결하며 이름만으로 결합하지 않습니다.

### 1.2 Network 원본과 집계

`NetworkCounterReading`의 production 구현은
`sysctl([CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0])` 결과에서 `RTM_IFINFO2`를 읽습니다.

- 메시지 길이·버전·형식·버퍼 경계·주소 길이를 확인하고 손상된 결과를 값으로 해석하지 않습니다.
- 카운터는 `if_data64`의 64비트 RX·TX 바이트를 사용합니다.
- 길이 조회와 실제 읽기 사이에 목록이 변하면 크기 부족을 제한된 재시도로 처리합니다.
  재시도 후에도 실패하면 해당 tick의 Network 실패로 반환합니다.
- 같은 인터페이스의 IPv4·IPv6 주소 행을 별도 카운터 대상으로 더하지 않습니다.
- loopback은 대표값과 상세 목록의 집계에서 제외합니다.

물리 여부는 SystemConfiguration의 유형·계층과 IORegistry의 provider 관계를 결합해 판정합니다.
`en*` 이름, `IFT_ETHER`, `IONetworkInterface` 존재만으로 물리라고 결정하지 않습니다.
Wi-Fi·Ethernet·Thunderbolt 등 실제 하드웨어 경로를 확인한 최하위 인터페이스만 합산합니다.
Bridge·Bond·VLAN 같은 상위 논리 인터페이스와 가상 머신 인터페이스를 함께 더하지 않습니다.

VPN 서비스·프로토콜과 연결 관계가 확인된 대상은 VPN으로 표시합니다.
`utun*` 등 터널만 확인된 경우는 터널로 표시하고 VPN 소속 여부를 추정하지 않습니다.
VPN·터널의 RX/TX·주소·누적량은 상세에 제공하고 대표값에는 포함하지 않습니다.
판정할 수 없는 대상은 근거와 함께 상세에서 구분하며 물리 대상으로 조용히 합산하지 않습니다.
필수 물리 대상의 식별이 불완전하면 합계도 불완전 상태로 처리합니다.
(`SPEC §5.1`, `SPEC §5.3`, `SPEC §5.5`, `SPEC §5.7`, `SPEC §5.13`)

활성 상태는 링크·인터페이스 상태와 주소·서비스의 관측 결과를 사용합니다.
`IFF_RUNNING`은 자원 할당 상태이므로 단독으로 연결 성공을 뜻하지 않습니다.
인터넷에 요청을 보내 연결 여부를 확인하지 않으며 링크 연결을 인터넷 접속 보장으로 표시하지 않습니다.
동시 활성 물리 대상이 둘 이상이면 목록과 개수를 표시하고 기본 경로 하나로 축약하지 않습니다.

### 1.3 Disk 원본과 집계

`DiskCounterReading`의 production 구현은 IOKit의 저장 장치 드라이버 통계를 읽습니다.

- 물리 whole media와 대응하는 `IOBlockStorageDriver`의 `Statistics`를 사용합니다.
- 장치 키는 통계를 소유한 드라이버의 registry entry ID입니다.
- 대표 Read·Write는 읽을 수 있는 현재 물리 장치 각각의 속도를 한 번씩 합산합니다.
- APFS container·volume·snapshot·partition의 통계를 물리 장치에 다시 더하지 않습니다.
- 디스크 이미지와 확인된 가상 저장 장치는 물리 장치 합계에서 제외하고 상세에서 종류를 구분합니다.
- 실제 물리 대상의 필수 바이트 카운터 누락은 완전한 합계로 숨기지 않습니다.
- 장치 연결이 유지된 상태의 누적량은 드라이버 원본값이며 앱 실행 이후 누적량으로 바꾸지 않습니다.

볼륨은 `DADiskCreateFromVolumePath`·`DADiskCopyIOMedia`와 IOService 부모 관계로 장치에 연결합니다.
`DADiskCopyWholeDisk` 결과만 물리 장치라고 가정하지 않습니다.
부모 관계를 다대다 집합으로 표현해 복수 물리 저장소·복수 볼륨도 중복 집계하지 않습니다.
관계를 확인하지 못하면 미확인 상태를 남기며 이름을 잘라 물리 장치를 추정하지 않습니다.
(`SPEC §5.2`, `SPEC §5.4`, `SPEC §5.7`, `SPEC §5.9`, `SPEC §5.13`)

### 1.4 볼륨과 저장 공간

보조 축은 현재 마운트된 로컬 디스크 기반 볼륨과 시스템 볼륨 `/`를 조사합니다.
네트워크 파일 시스템은 로컬 물리 Disk I/O와 같은 범위로 합산하지 않습니다.
동일 볼륨의 여러 경로는 UUID·마운트 정체성으로 중복 제거합니다.

전체·사용 가능한 공간은 Foundation의
`volumeTotalCapacityKey`·`volumeAvailableCapacityKey`로 읽습니다.
여기서 사용 중 표시는 `전체 − 사용 가능`의 용량 점유 값입니다.
파일들의 논리 크기 합이나 특정 APFS 볼륨만의 독점 할당량이라고 설명하지 않습니다.
정의는 상세의 상시 설명과 접근성 문자열에도 포함합니다.

APFS에서 공유되는 전체·여유 용량은 각 볼륨 행에서 공유 공간임을 알립니다.
볼륨별 용량을 더해 장치·시스템 용량을 만들지 않습니다.
시스템 카드의 저장 공간은 `/`의 조회 결과 하나를 사용합니다.
원본의 용량 관계가 유효하지 않거나 필수 키가 없으면 오류로 처리하고 임의 보정값을 표시하지 않습니다.

외장 여부는 Disk Arbitration의 `DeviceInternal`과 확인된 연결 특성으로 판정합니다.
`Removable`·`Ejectable`은 별도 속성이며 외장 여부와 같은 뜻으로 사용하지 않습니다.
연결된 장치·마운트된 볼륨·마운트되지 않은 장치·외장 장치 없음·조회 실패를 구분합니다.
(`SPEC §5.2`, `SPEC §5.4`, `SPEC §5.7`, `SPEC §5.10`, `SPEC §5.12`)

## 2. 데이터 흐름

### 2.1 일정

| 축 | 일반 열림 | 일반 닫힘 | 저전력 열림 | 저전력 닫힘 |
| --- | ---: | ---: | ---: | ---: |
| CPU·Memory | 1초 | 2초 | 2초 | 5초 |
| 프로세스 조사 | 2초 | 5초 | 4초 | 10초 |
| Network 속도 | 1초 | 2초 | 2초 | 5초 |
| Disk 속도 | 1초 | 2초 | 2초 | 5초 |
| Network 보조 정보 | 30초 | 60초 | 60초 | 120초 |
| 저장 공간·장치 관계 | 30초 | 60초 | 60초 | 120초 |

기존 `.m2`를 대체할 M3 일정 정의에 축별 값을 함께 둡니다.
화면 잠금·잠금 상태 unknown·디스플레이 슬립·세션 비활성·시스템 sleep에서는 모든 축을 중지합니다.
정상 팝오버·전력 전환은 실행 generation만 바꾸며 수집 epoch나 유효한 차분 기준점을 끊지 않습니다.

보조 정보는 최초 수집 가능 상태에서 한 번 즉시 요청하고 이후 표의 주기를 적용합니다.
팝오버를 열 때 캐시를 먼저 표시하고 캐시가 새 주기보다 오래됐으면 한 번 갱신합니다.
토폴로지 변경·마운트·해제는 보조 정보 갱신을 요청하며 동일 요청을 하나로 합칩니다.
주소·상태의 변경 알림을 사용할 수 없을 때는 정해진 polling으로 갱신합니다.

중지 중 들어온 보조 갱신 요청은 실행하지 않고 재개 시 한 번 처리합니다.
보조 조회는 축마다 동시에 하나만 실행합니다. 오래 걸린 조회를 겹쳐 쌓거나 보충 tick을 몰아 실행하지 않습니다.
정상 주기 변경에서 유지되는 타이머·baseline·이력 계약은 기존 M2와 같습니다.
(`SPEC §5.8`, `SPEC §5.10`, `SPEC §5.11`)

### 2.2 실제 시각과 차분

카운터 snapshot은 실제 native 읽기 시각과 대상 집합을 함께 반환합니다.
Scheduler의 호출 예정 시각을 카운터 측정 시각으로 대신 쓰지 않습니다.
단조 증가 시계는 기존 `ContinuousClock`·`MonotonicClock` 계약을 사용합니다.

각 대상의 속도는 다음과 같습니다.

`bytesPerSecond = Double(currentCounter − previousCounter) / actualElapsedSeconds`

- 최초 수집, 새 collection epoch, 새 대상, 재연결, 활성 topology 변경은 기준점만 갱신합니다.
- `elapsed <= 0`, 10초 초과 지연, 감소한 카운터, 달라진 정체성·카운터 기준은 속도를 만들지 않습니다.
- 차분 전에 감소 여부를 확인하며 unsigned underflow·overflow·NaN·infinity를 허용하지 않습니다.
- 허용 간격 10초는 현재 가장 느린 속도 주기 5초의 두 배이며 M2의 기준을 재사용합니다.
- 정상적인 5초→1초·1초→2초 전환만으로 기준점을 버리지 않습니다.
- 실패 뒤 첫 성공 snapshot도 기준점부터 다시 잡아 실패 구간을 속도로 평균내지 않습니다.
- baseline-only 결과에는 현재 원시 누적량·대상 상태를 담을 수 있지만 현재 속도는 없습니다.

대표값은 대상별로 계산한 유효 속도의 합입니다.
필수 대상 일부의 속도가 없으면 이를 완전한 대표값으로 표시하지 않습니다.
실제 연결된 대상의 변화량이 0이면 정상적인 0 B/s이며 연결 없음·미수집과 구분됩니다.
(`SPEC §5.5`, `SPEC §5.7`, `SPEC §5.8`, `SPEC §5.9`, `SPEC §5.12`)

### 2.3 토폴로지와 대상 수명

Network 키는 BSD 이름·interface index·확인된 registry 정체성 또는 관측 수명으로 구성합니다.
제거 후 같은 이름·index가 재사용돼도 이전 baseline을 물려주지 않습니다.
Disk 키는 물리 통계 소유 드라이버의 registry entry ID로 유지합니다.

원본에서 확인한 집합·활성 상태·식별 기준과 변경 알림의 topology revision을 함께 사용합니다.
짧은 제거·복귀 알림이 병합되더라도 변경 revision은 누적해 보존합니다.
새 대상으로 판정된 결과를 오래된 보조 캐시와 이름만으로 연결하지 않습니다.

대상 제거는 다음 현재 snapshot에서 즉시 반영합니다.
제거된 대상의 속도·누적값은 현재 목록에서 빠지고 이미 측정된 과거 합계만 10분 이력에 남습니다.
집합 변경 이후 합계 이력은 새 연속 구간에서 시작합니다.
Network 내부 이력은 요약·상세의 새 그래프로 표시하지 않습니다.
Disk는 이 합계 이력을 §3.4의 요약 미니 그래프에 사용하며 상세·대상별 새 그래프를 추가하지 않습니다.
보조 캐시가 아직 갱신되지 않았으면 새 대상의 보조 정보는 갱신 중으로 표시합니다.

활성 baseline과 현재 캐시만 유지하며 제거된 대상별 이력을 계속 쌓지 않습니다.
상세는 현재 대상의 속도·누적량을 제공하고 대상별 장기 그래프를 추가하지 않습니다.
(`SPEC §5.3`, `SPEC §5.4`, `SPEC §5.7`, `SPEC §5.9`)

### 2.4 중지·시스템 sleep과 늦은 결과

기존 화면 중지 epoch를 확장해 모든 축이 공통 collection boundary를 관측하게 합니다.
`willSleepNotification`에서 수집을 중지하고 `didWakeNotification`에서 복귀 경계를 기록합니다.
복귀 시 다른 중지 사유가 남아 있으면 계속 중지합니다.
`didWake`는 긴 경과 시간의 휴리스틱과 별개로 기준점을 끊습니다.

최신 snapshot 하나만 보존하는 stream에서도 경계를 잃지 않도록
snapshot에 단조 증가하는 boundary sequence를 포함합니다.
중지→재개가 소비 전에 모두 일어나 최종 상태가 running이어도 boundary 증가가 남아야 합니다.
중지 표시 이벤트도 `Void` 대신 epoch·revision·중지 여부를 가진 값으로 전달합니다.

각 실행 결과에는 collection epoch·축 generation·요청 sequence를 전달합니다.
생명주기 경계는 비동기 취소·일정 적용보다 먼저 현재 admission token을 무효화합니다.
다음 조건을 source의 baseline 반영, store 저장, 표시 반영 각각에서 확인합니다.

- 현재 수집 허용 상태인가.
- 결과의 collection epoch와 축 generation이 현재 허용 token과 같은가.
- 동일 축에서 더 최신 요청·시각의 결과가 이미 반영되지 않았는가.

await 이전의 검사 하나만으로 반영을 허용하지 않습니다.
늦은 결과는 baseline·현재값·이력·카드 상태를 모두 변경하지 않습니다.
취소되지 않는 동기 native 조회가 끝나더라도 중지 이후 결과는 폐기합니다.

중지 이벤트와 수집 stream 사이에는 단일 정렬 계약을 둡니다.
새 경계의 성공 이후 늦게 도착한 이전 중지 이벤트가 카드를 다시 중지시키지 못하고,
중지 이후 이전 성공이 카드를 정상으로 되돌리지 못해야 합니다.
구체적인 동기화 수단은 구현 재량이지만 위 원자적 무효화·반영 조건은 필수입니다.
(`SPEC §5.8`, `SPEC §5.9`, `SPEC §5.11`, `SPEC §5.15`)

### 2.5 내부 이력과 유지되는 그래프의 연속성

Network·Disk는 각각 601개 고정 링에 실제 유효 속도 두 개와 시각·연속성 키를 보관합니다.
빠른 축의 주기가 느려져도 링 용량을 줄이지 않습니다.
메모리에만 보관하며 재시작 복원·외부 전송·파일 기록 경로를 추가하지 않습니다.
Network 요약 그래프 제거와 Disk 그래프 축소는 승인된 수집·store·표시 모델의 이력 보존 계약을 철회하지 않습니다.

연속성 키는 collection epoch와 해당 리소스의 rate segment를 포함합니다.
중지·실패·baseline-only·topology 변경·카운터 재설정에서 segment를 끊습니다.
인접한 유효 점 사이가 10초를 넘는 경우도 같은 연속 구간으로 이어 붙이지 않습니다.
2초 이하의 실패 한 번도 과거와 미래의 연속성으로 덮지 않습니다.

유효 값 없는 tick은 링에 0·빈 점을 추가하지 않습니다.
유지하는 CPU·Memory 그래프의 시간 창·실제 시각·미수집 공백·중지 전후 단절과
CPU의 기존 downsampling은 선행 feature 계약대로 유지합니다.
Disk 미니 그래프는 §3.4의 축·downsampling·렌더 계약으로 같은 이력을 표시합니다.
Network 그래프 보조 코드는 보존할 수 있으나 제품 요약·상세에 표시하지 않습니다.
(`SPEC §5.8`, `SPEC §5.9`, `SPEC §5.11`, `SPEC §5.15`, `SPEC §5.19`)

## 3. 인터페이스

### 3.1 수집·저장 계약

아래 이름은 책임을 나타내는 후보 식별자입니다. 파일 분할과 제네릭 형태는 구현에서 정할 수 있습니다.

| 계약 | 필수 정보와 책임 |
| --- | --- |
| CollectionRunContext | 공통 epoch, 축 generation, 요청 sequence, 현재 허용 상태 |
| CollectionBoundary | lifecycle revision, 누적 boundary sequence, 중지 여부 |
| NetworkCounterSnapshot | 읽기 시각, 대상 키·원시 RX/TX·flags, topology revision |
| NetworkInterfaceMetadata | 종류·물리 판정 근거·활성 상태·주소·조건부 링크 속도 |
| DiskCounterSnapshot | 읽기 시각, 물리 드라이버 키·Read/Write·조건부 Operations |
| StorageMetadataSnapshot | 볼륨 키·용량·장치 키 집합·외장·마운트 상태 |
| RatePair | 두 독립 방향의 유한한 비음수 B/s |
| RateHistoryPoint | 실제 시각·RatePair·collection epoch·rate segment |
| SupplementalValue | collecting·available(value, timestamp)·failure(lastKnown, reason)·unsupported(reason) |

source는 성공·기준점 전용·조회 실패를 값으로 구분합니다.
raw reader 전체 실패 외에 대상·보조 필드·조건부 필드의 실패 원인을 보존합니다.
필수 값의 미지원은 구현 필수 관문의 실패이며 성공한 0으로 바꾸지 않습니다.

`NetworkActivityStore`·`DiskActivityStore`는 최신 결과와 독립 이력 링을 소유합니다.
보조 store는 최신 snapshot과 조회 상태·시각을 소유합니다.
표시 stream은 최신 값 하나를 유지하되 boundary·sequence 판정 정보도 함께 전달합니다.

### 3.2 상태와 조건부 지표

네 카드는 수집 중·정상·실패·중지의 공통 문구·상징·마지막 성공 시각 원칙을 사용합니다.
Network·Disk에서는 활동 결과와 보조 결과를 별도 상태로 조립합니다.

- 연결 없음: 원본 조회는 성공했으나 활성 연결이 없는 상태. 현재 속도를 지어내지 않습니다.
- 정상 유휴: 연결된 대상에서 실제 변화량 0을 측정한 상태.
- 기준점 갱신 중: 대상 정보·누적량은 있을 수 있으나 현재 속도는 아직 없습니다.
- 보조 정보 갱신 중: 빠른 속도는 계속 제공하고 보조 영역의 상태를 따로 표시합니다.
- 보조 조회 실패: 현재 속도는 계속 갱신하고 해당 영역에 실패·마지막 성공 시각을 표시합니다.
- 활동 조회 실패: 해당 카드에 실패를 표시하고 마지막 속도를 과거 값으로 구분합니다.
- 수집 중지: 네 카드가 마지막 성공 정보를 보존하며 중지 사실을 표시합니다.

필수 보조 정보 실패는 카드 상태·접근성 이름에서 일부 수집 실패로 식별됩니다.
그 상태에서도 성공한 실시간 속도를 이전 값에 묶어 두지 않습니다.
기존 `ResourceCardState`의 CPU·Memory 의미를 바꾸지 않고 공통 상태 표현을 공유합니다.
(`SPEC §5.7`, `SPEC §5.10`, `SPEC §5.11`, `SPEC §5.12`, `SPEC §5.14`)

링크 속도는 API가 보고한 유효한 양수 bit/s가 있고 의미를 확인했을 때만 상세에 제공합니다.
`ifi_baudrate`와 공개 media 정보의 의미·지원 여부를 확인하며 현재 전송 속도와 구분합니다.
0·형식상 상한·알 수 없는 값에서 실제 협상 속도를 추정하지 않습니다.
지원 불가와 조회 실패는 이유를 구분합니다.

IOPS는 드라이버가 제공하는 Read·Write Operations의 차분/실제 경과 시간입니다.
해당 드라이버의 작업 수이며 앱 요청 수·파일 호출 수·NVMe 명령 수로 바꾸어 설명하지 않습니다.
바이트 속도와 같은 기준점·연속성 규칙을 사용하고 미지원은 필수 속도를 막지 않습니다.
(`SPEC §5.18`)

### 3.3 카드와 단위

카드 순서는 CPU→Memory→Network→Disk입니다.
본체 폭 280pt·본체 padding 8pt·카드 사이 6pt·카드 padding 6pt를 사용합니다.
카드 폭은 264pt, 내용 폭은 252pt, 카드 모서리는 기존 8pt입니다.
네 카드의 고정 높이는 CPU 211pt·Memory 143pt·Network 101pt·Disk 101pt입니다.
값 없음·정상·실패·중지와 상세 개폐에서도 카드·내부 슬롯의 크기와 위치를 유지합니다.
샘플의 빈 여유는 긴 값·상태를 수용하는 고정 슬롯 안에서 사용할 수 있으며
하단 안내 제거를 이유로 카드 높이를 값이나 상태마다 바꾸지 않습니다.

요약의 타이포·배치는 승인 샘플의 다음 기준을 따릅니다.
이 축소 규칙은 요약 전용이며 상세의 기존 글꼴·코어 격자·행 간격을 함께 축소하지 않습니다.

| 요소 | 축소 표시 기준 |
| --- | --- |
| 네 카드 제목·단축키 | 기존 10pt의 2/3인 약 6.67pt, 제목 슬롯 8pt |
| CPU·Memory 대표 수치와 Network 속도 수치 | 기존 26pt의 2/3인 약 17.33pt |
| CPU 보조 비율·Memory Pressure·Swap | 9pt |
| Memory 구성 범례 | 8pt, 구성 바 높이 8pt |
| TOP 5 제목·앱 행 | 제목 7pt·높이 8pt, 이름·값 9pt·행 높이 10pt |
| TOP 5 아이콘·행 간격 | 실제 앱 아이콘 자리 10×10pt, 행 사이 1pt, 이름 앞 간격 4pt |
| TOP 5 제목 아래 | 제목 bottom padding 3pt를 추가하고 첫 행까지 기존 1pt stack 간격을 유지 |
| CPU 그래프 시간 라벨 | 7pt, 높이 9pt, 판과 간격 2pt |
| Network 방향 이름·단위·활성 정보 | 방향 이름 10pt, 단위·활성 정보 9pt |
| Disk 방향 이름·수치·단위·용량 | 이름 9pt, 수치 12pt, 단위 7pt, 용량 9pt |

CPU는 전체 사용률·User/System 비율·최근 10분 누적 밴드·TOP 5를 유지합니다.
Memory는 사용 중/전체 물리 메모리·구성 바·Pressure 기호와 단계·Swap 사용량/최근 변화·
기존 구성 합계·App/Wired/Compressed/Cached 범례·TOP 5를 유지합니다.
샘플에서 생략된 구성 합계나 실제 상태 접두를 제품에서 제거하는 근거로 사용하지 않습니다.
TOP 5는 기존 정원·정렬·값·단위·앱 귀속·조사 실패·자리표시·실제 아이콘 계약을 유지합니다.
상태 접두와 긴 Memory 보조 문자열도 고정 슬롯 안에서 줄 배치나 축소로 온전히 제공합니다.
(`SPEC §5.12`, `SPEC §5.14`~`SPEC §5.16`)

Network는 다운로드 RX·업로드 TX와 활성 종류·대상 수를 표시합니다.
두 속도 행은 각각 22pt, 행 사이 2pt이며 요약에 그래프·그래프 자리표시·전용 범례·범위·진행 문구를 표시하지 않습니다.
활성 정보는 샘플처럼 간결하게 조립하되 동시 활성 종류·개수와 미확인 상태를 손실시키지 않습니다.
Disk는 왼쪽 작은 Read·Write 수치 두 행과 오른쪽 미니 그래프를 45pt 고정 구역에 나란히 놓습니다.
일반 표기의 왼쪽 수치 영역은 112pt, 두 영역 사이 간격은 8pt, 오른쪽 판 높이는 42pt입니다.
요약에 별도 그래프 축 라벨·범위·진행 문구나 큰 범례 구역을 추가하지 않습니다.
Network·Disk에 순위·프로세스 목록을 추가하지 않습니다.

Network·Disk 하단의 `현재 측정 · 보조 정보 …초 전`,
`현재 측정 · 용량 확인 …초 전` 안내 행과 같은 역할의 갱신 경과 문구를 제거합니다.
이는 상단·수치 슬롯의 실패·중지·기준점·연결 없음·부분값 표시를 제거하는 결정이 아닙니다.
정상 상태는 샘플처럼 간결하게 표시하고 비정상 상태와 과거/부분값은
상단의 짧은 상태 라벨이나 해당 값 옆의 접두로 식별합니다.
보조 실패·갱신 중·과거 정보 여부는 활성/용량 슬롯의 해당 정보에 결합할 수 있으며
삭제한 하단 안내 행을 다시 만들지 않습니다.
활동·보조 정보 각각의 원본 시각·갱신 주기·실패 사유와 전체 상태는 상세·접근성에서 보존합니다.
(`SPEC §5.1`, `SPEC §5.2`, `SPEC §5.7`, `SPEC §5.10`~`SPEC §5.12`,
`SPEC §5.14`~`SPEC §5.16`, `SPEC §5.19`)

Disk 용량 슬롯에는 시스템 볼륨의 전체·사용 가능한 공간 두 값을 온전히 표시합니다.
요약에서 `가용`은 `사용 가능`의 간결한 라벨이며 같은 원본 값을 뜻합니다.
숫자는 기존 용량 formatter의 1024 기반 단위 선택·로케일·소수 한 자리·반올림·그룹 구분을 그대로 사용합니다.
두 값의 선택 단위가 같으면 `전체 <숫자>·가용 <숫자> <공통 단위>`로 조립하며,
끝의 공통 단위는 두 값 모두에 적용됩니다.
단위가 다르면 `전체 <숫자> <단위>·가용 <숫자> <단위>`로 각 단위를 제공합니다.
예를 들어 같은 TB 값은 `전체 16,777,216.0·가용 16,777,216.0 TB`,
서로 다른 단위는 `전체 1.0 TB·가용 512.0 GB`로 표시합니다.
일반적으로는 9pt 한 행으로 표시하고 긴 표기는 용량 고정 슬롯 안에서 두 행으로 나눌 수 있습니다.
삭제한 갱신 경과 안내가 차지하던 여유를 값의 온전한 표시에 사용하되 카드 높이 101pt를 유지합니다.
상세와 카드·상세의 접근성 이름에는 `전체`·`사용 가능`의 전체 라벨과 각 값의 단위를 제공합니다.
요약·상세·접근성의 용량 숫자는 같은 로케일로 서식화하며,
사용 중의 `전체 − 사용 가능` 정의와 APFS 공유 공간 설명을 유지합니다.
이 조립은 Disk 요약의 표현에 한정하며 공통 formatter의 다른 표시 결과를 바꾸지 않습니다.
(`SPEC §5.2`, `SPEC §5.4`, `SPEC §5.10`, `SPEC §5.12`, `SPEC §5.14`, `SPEC §5.15`)

속도는 B/s·KB/s·MB/s·GB/s, 누적량·용량은 B·KB·MB·GB·TB로 구분합니다.
기존 대시보드의 1024 기반 바이트 단위와 로케일 소수 한 자리 원칙을 유지합니다.
B보다 작은 단위를 만들지 않고 낮은 속도는 B/s로 표시해 유효한 작은 값을 0.0 KB/s에 묻지 않습니다.
링크 속도는 bit/s 계열, IOPS는 회/s이며 바이트 값과 같은 열 서식을 사용하지 않습니다.

Network·Disk는 같은 외곽 264×101pt를 사용하고 내부 구역은 승인 샘플의 서로 다른 구성을 따릅니다.
제목 8pt·구역 간격 4pt 두 곳·카드 상하 padding 합계 12pt를 고정합니다.
Network의 속도 구역은 46pt이며 남은 활성/상태 영역은 최대 27pt,
Disk의 속도·그래프 구역은 45pt이며 남은 용량/상태 영역은 최대 28pt입니다.
하단 정보가 짧아도 슬롯을 줄여 카드나 다음 카드를 움직이지 않습니다.

최장값은 먼저 샘플 기본 글꼴·배치로 표시하고 폭을 넘으면 요약 안의 내부 표현만 조정합니다.
숫자와 단위를 분리하더라도 formatter가 만든 숫자·단위·그룹 구분·소수 한 자리·작은 양수 표현을 모두 보존합니다.
과학 표기·정밀도 축약·임의 단위 변경·말줄임·clipping으로 숫자를 줄이거나 숨기지 않습니다.
Network는 값 영역에 우선 폭을 배정하고 필요한 경우 숫자와 단위를 같은 22pt 슬롯 안에서 재배치하거나 적합한 크기로 축소합니다.
Disk는 긴 수치에 대해 왼쪽 영역을 넓히고 미니 그래프의 가로 폭을 줄일 수 있습니다.
미니 그래프를 없애거나 42pt 판 높이를 바꾸지 않으며, 필요하면 각 방향의 이름/값/단위를
45pt 고정 구역 안에서 두 줄로 배치하거나 원문 수치의 글꼴을 적합한 크기로 축소합니다.
Disk 112pt 왼쪽 폭은 일반 표기의 기준이며 모든 극값에 강제하는 상한이 아닙니다.
Memory·TOP 5의 값에도 같은 수치 보존 원칙을 적용하고 긴 앱 이름의 전체 표기는 기존 상세에서 유지합니다.
같은 원본 값과 로케일이 요약·상세·접근성에서 대응해야 합니다.

이 적응 표현은 값에 따라 글꼴이나 내부 줄 배치를 바꿀 수 있으나 카드·슬롯의 외곽을 바꾸지 않습니다.
실제 글꼴·최장값·단위 경계·로케일·실패 접두를 구현 단계에 측정하며,
읽을 수 있는 전체 값과 그래프를 승인된 고정 예산 안에 함께 유지하지 못하면
근거·영향을 DESIGN으로 반환합니다. 정보 삭제나 카드 높이 변경으로 통과시키지 않습니다.
(`SPEC §5.1`, `SPEC §5.2`, `SPEC §5.12`, `SPEC §5.14`~`SPEC §5.16`, `SPEC §5.19`)

### 3.4 그래프 표시 경계

Network 요약의 속도 그래프·정상/빈 판·전용 범례·축 범위·수집 진행 문구를 제거합니다.
Disk는 기존 큰 그래프 구역을 작은 수치 옆의 42pt 미니 그래프로 대체합니다.
두 상세에 새 그래프를 추가하지 않습니다.
두 방향의 현재 수치·이름·단위와 수집 상태를 통해 송수신·읽기·쓰기를 구분합니다.
색상만으로 방향·정상·일부 실패·조회 실패·중지를 설명하지 않습니다.

CPU 판 높이는 기존 100pt의 2/3인 약 66.67pt이며 시간 라벨 구역은 §3.3을 따릅니다.
CPU의 최근 10분·0~100%·User/System 누적 밴드·코어 단계·기존 축·진행 상태와 접근성을 유지합니다.
Memory 구성 바는 높이 8pt와 기존 전체 물리 메모리 기준 비율·순서·자리표시 의미를 유지합니다.
적용되는 공통 판 면·기준선·clipping·정상/자리표시 크기·위치·미수집 공백 규칙은
선행 dashboard-visual-language·graph-plot-surface 계약을 그대로 따릅니다.
판 높이를 지정하는 공통 렌더 경계가 필요하면 요약 CPU와 Disk의 높이를 명시적으로 전달합니다.
기존 공통 100pt 상수를 무조건 변경해 상세·다른 그래프에 축소가 전파되게 하지 않습니다.

Disk 미니 그래프는 최근 600초 원본 합계 이력의 Read·Write 두 독립 계열입니다.
실제 그리는 시각을 오른쪽 끝으로 두고 실제 샘플 시각을 사용합니다.
epoch·rate segment·10초 초과 간격을 기준으로 연속 구간을 먼저 나누며
실패·중지·baseline-only·카운터 reset·대상 변경 공백을 0·가상 과거 표본·연결선으로 채우지 않습니다.
두 계열은 같은 0부터 시작하는 B/s 축을 사용하며
10분 원본의 두 계열 peak를 포함하는 기존 1–2–5 상한과 최소 1024 B/s를 재사용합니다.
원본 peak로 축을 정한 뒤 렌더 가로 폭에 맞춰 두 계열 최소·최대 실제 표본 index의 합집합을
시간순으로 downsampling하며 수집/store·원본 이력을 바꾸지 않습니다.
Read는 점선, Write는 실선이며 기존 Disk Read/Written 팔레트 역할을 사용합니다.
축소 선 두께는 샘플의 약 1pt를 기준으로 하되 0·상한·겹침에서도 두 계열을 읽을 수 있게 합니다.
전체 시간 창의 무채색 판과 상한 절반의 약한 가로 기준선 하나를 유지하고
윤곽선·세로 눈금·미수집 별도 구획을 만들지 않습니다.
표본이 없으면 같은 위치·크기의 빈 판과 기준선을 표시하고 데이터 점·선을 만들지 않습니다.
판 밖으로 번지는 경계선은 clipping으로 제한합니다.

Disk 미니 그래프에는 독립 축 라벨·범위·진행 문구 구역을 두지 않습니다.
최근 10분·Read 점선/Write 실선·원본 축 범위와 값 없음/중지/부분값 의미를 접근성에 제공합니다.
현재·과거·부분값 여부는 옆 수치와 카드 상태에서 확인되고 원본 시각·실패 사유는 상세·AX에서 유지됩니다.
기존 ResourceRateGraph 모델·downsampling·팔레트·그리기 코드는 위 계약에 맞는 범위에서 재사용합니다.
기존 보조 코드 삭제는 완료 조건이 아니며 CPU가 쓰는 공통 판·색상·그리기 코드를 함께 제거하지 않습니다.
(`SPEC §5.1`, `SPEC §5.2`, `SPEC §5.8`, `SPEC §5.9`, `SPEC §5.12`,
`SPEC §5.14`~`SPEC §5.16`, `SPEC §5.19`;
철회된 `SPEC §5.17`은 새 구현 의무로 매핑하지 않음)

### 3.5 본체·상세·키보드

본체는 승인된 폭 280pt·콘텐츠 높이 590pt의 한 열과 고정 카드 높이를 사용합니다.
CPU 211pt·Memory 143pt·Network 101pt·Disk 101pt, 카드 사이 6pt·본체 padding 8pt로
콘텐츠 높이는 `16 + 211 + 143 + 101 + 101 + 18 = 590pt`입니다.
TOP 5 제목 아래 추가 3pt는 CPU·Memory의 승인된 카드 높이 안에 포함합니다.
상태 항목이 놓인 화면의 `visibleFrame`에서 위·아래 8pt와 실제 본체 chrome를 뺀
사용 가능한 콘텐츠 높이와 590pt 중 작은 값을 본체 viewport 높이로 사용합니다.

가용 콘텐츠 높이가 590pt 이상이면 네 카드 전체를 스크롤 없이 함께 보이게 합니다.
축소 본문보다 가용 높이가 작은 예외 화면에서는 승인된 카드·글꼴·그래프를 추가 축소하지 않고
viewport만 줄여 세로 스크롤로 도달합니다.
한 열 eager 컨테이너는 유지하며 충분한 높이에서는 스크롤이 필요하지 않아야 합니다.
예를 들어 visibleFrame 높이 1084pt·chrome 26pt이면 가용 콘텐츠 높이는
`1084 − 16 − 26 = 1042pt`이므로 본체 viewport는 590pt입니다.
이는 배치 산술이며 실제 창과 네 카드 동시 표시의 실행 검증을 대신하지 않습니다.
한 열 구조와 기존 폭을 유지하고 아코디언·2열·카드 숨김·새 설정을 추가하지 않습니다.

chrome 26pt는 최초 표시의 임시 추정치입니다.
실제 본체 SwiftUI viewport와 본체 NSWindow 외곽 frame 차이를 측정해 갱신합니다.
화면·배율·메뉴바 위치·chrome가 같으면 값·수집 상태·선택·상세 개폐로 본체 크기를 바꾸지 않습니다.

상세의 최대 콘텐츠 크기는 기존 400×480pt입니다.
현재 화면의 가용 영역과 chrome를 넘으면 상세 viewport를 줄이고 내용은 내부에서 스크롤합니다.
카드 옆 앵커와 macOS의 가장자리 배치를 사용하며 화면 밖으로 내보내거나 독립 창으로 바꾸지 않습니다.
화면 환경이 같을 때 값·상태·개폐로 본체나 상세 viewport 크기를 바꾸지 않습니다.

본체와 현재 카드의 상세는 같은 화면·가장자리 여유 정책을 사용합니다.
상세의 폭·높이도 visibleFrame의 해당 길이에서 양쪽 8pt와 실제 상세 chrome를 뺀 값으로 제한합니다.
ApplicationCoordinator가 소유하는 같은 viewport를 본체·네 상세·StatusBarController에 전달합니다.
StatusBarController는 본체 NSPopover와 현재 선택 카드의 상세에 대응하는 창을 식별해
실제 외곽 frame이 visibleFrame의 좌우·상하 8pt 안에 드는지 확인하고 필요한 크기·위치를 보정합니다.
임의의 다른 앱 창을 상세로 간주하지 않으며 카드 앵커와 자식 팝오버 관계를 유지합니다.
열기 전 화면 기준 계산과 실제 창 생성·레이아웃 이후 frame 확인을 연결합니다.
크기 보정 이후 위치를 다시 확인하고 화면 변경·상세 개폐에서도 같은 계약을 적용합니다.

오프스크린 단축키가 유지되도록 카드 Button은 eager 컨테이너에서 등록합니다.
⌘1·⌘2를 보존하고 Network는 ⌘3, Disk는 ⌘4를 사용합니다.
오프스크린 카드를 선택하면 먼저 해당 카드 앵커가 보이는 위치로 이동한 뒤 상세를 엽니다.
앵커 배치가 완료되기 전에 팝오버를 열지 않습니다.

다시 같은 단축키·카드를 선택하면 닫고, 다른 카드를 선택하면 해당 카드로 전환합니다.
닫힘 callback은 현재 선택과 일치하는 경우에만 selection을 지웁니다.
명시적인 닫기·Escape 복귀와 카드로의 포커스 복귀를 제공합니다.
Page Up·Page Down으로 본체를 스크롤하고 상세가 선택됐으면 그 상세의 스크롤에 전달합니다.
상세에서 부모 단축키로 복귀할 수 있는 기존 key-window 계약도 함께 확인합니다.

카드 이름에는 리소스·수집 상태·주요 수치·단축키를 포함합니다.
상세 행은 대상 이름·종류·현재/누적 구분·값·상태를 접근성 계층에 제공합니다.
키보드 탐색 기본 설정에서도 네 카드와 상세의 넘치는 내용에 도달해야 합니다.
VoiceOver 실제 낭독은 SPEC 제외 범위대로 M5에 남깁니다.
(`SPEC §5.3`, `SPEC §5.4`, `SPEC §5.14`, `SPEC §5.15`, `SPEC §5.16`)

## 4. 영향 범위

### 4.1 변경 소유 경계

- `ApplicationCoordinator.swift`: 새 축·store·표시 소비 구성과 공통 boundary 배선.
- `MonitoringLifecycle.swift`, `MonitoringScheduler.swift`, `SystemLifecycleObserver.swift`:
  여섯 축 일정·시스템 sleep/wake·경계 보존·늦은 결과 폐기.
- 기존 샘플/source 계약: token 전달과 admission 판정.
  CPU·Memory의 계산식·프로세스 집계·메뉴바 판정 정책은 보존합니다.
- Network·Disk native reader·collector·activity store·metadata store: 신규 책임.
- `DashboardPresentation.swift`, `DashboardPresentationStore.swift`:
  두 카드·세부 상태·단위·선택·boundary 순서와 기존 내부 이력 보존.
- `DashboardView.swift`, `DashboardStyle.swift`, `DashboardColorPalette.swift`:
  네 카드 요약 전용 축소 타이포·슬롯·TOP 5 여백·한 열 배치·가용 영역·접근성.
  CPU·Memory 정보 의미와 기존 상세·색상·판 면 규칙을 보존합니다.
- `NetworkDashboardView.swift`, `DiskDashboardView.swift`:
  264×101pt 슬롯·하단 안내 제거·필수 수치·상태·상세·AX 보존.
  Network 그래프 제거와 Disk 수치 옆 42pt 미니 그래프·극값의 온전한 내부 표현.
- `ResourceRateGraph.swift`, `ResourceRateGraphView.swift`와 CPU graph 렌더 경계:
  기존 원본 축·연속성·downsampling을 재사용하고 요약 CPU 약 66.67pt·Disk 42pt 판 높이를 지원합니다.
- `DashboardViewport.swift`:
  현재 없는 후보 파일명이며 같은 책임을 다른 파일에서 구성할 수 있습니다.
  590pt 콘텐츠 예산과 화면·실제 chrome에 따른 본체/상세 크기 정책을 소유합니다.
- `StatusBarController.swift`: 실제 화면에 따른 viewport 전달·popover frame 보정.
- 관련 단위·UI 테스트: 새 불변식과 기존 CPU·Memory 회귀.
- 상위 문서: 구현 결과로 두 카드 전용·스크롤 없음의 현재 구현 설명이 오래되면 갱신합니다.

프로젝트는 macOS 26.5·arm64·App Sandbox·단일 앱 실행 파일을 유지합니다.
공개 시스템 framework를 사용하고 Helper·권한 프롬프트·새 예외 entitlement·외부 package를 전제하지 않습니다.
native 도구 subprocess 실행은 비교 관찰용이며 production Collector에 넣지 않습니다.
(`SPEC §5.11`, `SPEC §5.13`)

### 4.2 IMPLEMENT에서 필요한 확인

최신 표시 개정의 직접 영향은 task-010의 Network 요약, task-011의 Disk 요약·미니 그래프,
task-012의 CPU·Memory 축소·TOP 5 여백·네 카드 본체·viewport입니다.
task-013의 키보드/AX, task-015의 표시 공백, task-018의 통합 회귀는 새 표시를 관찰하도록 갱신합니다.
task-009는 철회 이력이며 ID를 재사용하지 않습니다.
Disk 미니 그래프의 SPEC §5.19는 task-011과 관련 통합·접근성·공백 회귀에 매핑할 수 있어 별도 신규 Task를 전제하지 않습니다.
Task 경계·순서·매핑 확정은 implement-init이 소유합니다.

task-001~008의 수집·baseline·이력·단위·모델 승인에는 의미 변경이 없어 기존 근거를 유지할 수 있습니다.
기존 CPU·Memory의 계산·프로세스 집계·정보 의미·선택·상세·접근성 계약도 유지합니다.
기존 높이 329pt/224pt·요약 글꼴·CPU 판 100pt 및 선행 시각 feature의 수치 위계·고정 크기와 직접 충돌하는 요약 치수는 최신 승인 SPEC §5.16의 축소 계약으로 대체합니다.
이 항목들의 과거 렌더 승인은 역사적 근거이며 새 요약 표시의 완료 주장에 사용하지 않습니다.
상세와 정보 의미·기준선/밴드·팔레트처럼 영향 없는 선행 승인은 회귀 근거로 유지할 수 있습니다.
상위 문서의 현재 요약 치수·세로 예산 설명이 오래되면 현재 feature 계약을 참조하도록 정리합니다.

단위 확인은 차분·identity·순서·이력의 의미를 고정합니다.

- 실제 경과 시간, 0 변화량, 최초·재개·10초 초과·카운터 감소·대상 교체.
- 물리·논리·VPN·loopback 구분과 APFS 다대다 관계의 중복 집계 방지.
- 일부 필수 카운터 실패와 조건부 지표 미지원의 분리.
- 짧은 중지→복귀가 최신 snapshot 하나에 합쳐져도 boundary가 보존됨.
- 취소를 무시하는 source·역순 응답·sink await·표시 지연에서도 이전 결과가 반영되지 않음.
- 보조 조회가 suspend된 동안 빠른 Network·Disk와 CPU·Memory가 계속 진행됨.
- Network·Disk 내부 이력의 601개 고정 용량·10분 선별·짧은 실패와 중지의 연속성 단절.
- 유지되는 CPU·Memory 그래프의 시간 창·공백·기존 downsampling 보존.

렌더·UI 확인은 실제 표시 계약을 다룹니다.

- 수집 중·정상·실패·중지·연결 없음·보조 실패에서 네 카드의 크기·위치가 일정함.
- CPU 264×211pt·Memory 264×143pt·Network/Disk 264×101pt와 252pt 내용 폭에서 필수 정보가 읽힘.
- 승인 샘플의 제목·대표 수치·CPU 판 약 2/3, Memory 구성 바·TOP 5, 제목 아래 추가 3pt 대응.
- Network 요약·상세에 그래프·전용 범례·범위·진행 문구가 없고 Disk 상세에 새 그래프가 없음.
- Disk 수치 옆 42pt 정상/빈 판·기준선·Read/Write 두 계열과 극값 보존·미수집 공백 대응.
- Network·Disk 하단 측정/보조/용량 경과 안내가 없고 비정상 상태·과거/부분값이 요약에서 구분됨.
- 최장 속도와 용량·Memory 보조 문자열·로케일·상태 접두에서 원문 수치·단위가 말줄임 없이 읽힘.
- 최장 용량·단위 경계·로케일에서 compact 용량과 전체 라벨·각 단위의 상세/AX가 대응함.
- 라이트·다크에서 축소 CPU 판의 정상/자리표시·기준선·축·밴드와 Memory 구성 정보가 보존됨.
- 가용 콘텐츠 높이 590pt 이상에서 실제 chrome를 포함해 네 카드가 스크롤 없이 함께 보임.
- 590pt보다 작은 예외 가용 높이에서는 승인 카드 크기를 유지하고 세로 스크롤로 모두 도달함.
- 기본 키보드 설정의 ⌘1~⌘4·복귀·Page Up/Down과 상세 AX 도달.
- 첫 카드·중간 카드·마지막 카드의 마우스·키보드 접근.
- 화면 가장자리의 카드 옆 상세와 본체·상세 스크롤 전후 실제 frame.
- CPU·Memory 정보·선택·TOP 5·실제 앱 아이콘·최근 흐름과 메뉴바 동작 유지.

### 4.3 실제 Sandbox와 연결 관문

선택한 설정으로 빌드·서명된 앱 안에서 native adapter까지 실행한 근거가 필요합니다.

- 물리 인터페이스 카운터·분류·IPv4/IPv6·연결 상태.
- 시스템 볼륨 용량, 물리 드라이버 바이트 통계, 장치·볼륨 관계.
- VPN 연결·해제와 물리 대표값·터널 상세의 분리.
- Wi-Fi↔Ethernet, 연결 없음, 외장 장치 연결·해제에서 baseline·목록·상태 갱신.
- 시스템 sleep/wake 및 화면 중지 뒤 첫 카운터 snapshot이 기준점 전용임.
- 실제 API의 반환 코드·필수/조건부 지원 여부·장치/OS·빌드·entitlement 근거.

현재 조사에서 없었던 장비·VPN·화면·둘째 사용자 환경은 실제 가용 여부를 기록합니다.
M2에서 인정된 빠른 사용자 전환 미확인을 M3의 새 관문 승인으로 자동 승계하지 않습니다.
필수 실기기 항목을 확인하지 못하면 미확인과 영향을 반환하고 완료로 처리하지 않습니다.
필수 API를 확보하지 못하면 구현 방법을 재조사하거나 DESIGN/SPEC 소유 문제로 반환합니다.
(`SPEC §5.7`, `SPEC §5.8`, `SPEC §5.9`, `SPEC §5.13`, `SPEC §5.18`)

최소 지원 화면의 숫자는 상위 문서에 확정돼 있지 않습니다.
이 DESIGN은 새 최소 해상도 정책을 만들지 않고 실제 `visibleFrame`에 맞추는 구조를 정합니다.
구현 관문은 사용 가능한 가장 작은 가용 영역·배율·메뉴바 위치와 실제 frame을 기록해야 합니다.
실제 본체·상세 외곽 frame의 좌우·상하 8pt 여유와 카드 앵커 관계를 확인합니다.
590pt 축소 본문의 네 카드 동시 표시와 이보다 작은 예외 가용 높이의 스크롤 대안을 모두 확인합니다.
가상 viewport 확인만으로 가장 작은 지원 화면의 실기기 관찰을 완료했다고 보고하지 않습니다.
(`SPEC §5.16`)

### 4.4 변화 방향 비교

비교는 한 Sandbox 앱 세션에서 일반 모드·팝오버 열림으로 수행합니다.
각 시나리오는 유휴 15초→부하 30초→회복 15초를 기본 관측 구간으로 사용합니다.
실제 부하가 유지되지 않으면 그 사실과 유효 구간을 기록하고 성립한 구간으로 다시 관찰합니다.
기준점 전용·실패·전환 tick은 수치 비교 표본에서 제외하되 원시 기록에는 남깁니다.

Network는 `netstat -ibn`의 대상별 바이트 카운터를 실제 시각과 함께 관측합니다.
동일 인터페이스의 Link 행 한 개만 사용하고 주소별 중복 행은 더하지 않습니다.
앱과 같은 물리 대상 집합을 합산하고 원시 바이트 차분/실제 초로 B/s를 유도합니다.
다운로드·업로드 각각에서 해당 방향이 유휴보다 증가하고 종료 뒤 낮아지는지 비교합니다.
VPN 터널의 누적량은 대표 합계와 별도 표에 두며 같은 트래픽을 합산하지 않습니다.

Disk는 `iostat -d -w 1 <물리 BSD 장치 목록>`의 장치별 MB/s 변화를 관측합니다.
앱의 같은 물리 범위 Read+Write 흐름과 비교하고 iostat 합계를 Read 전용·Write 전용 값으로 오인하지 않습니다.
Read·Write 방향은 드라이버의 해당 원시 바이트 변화와 부하 종류로 추가 확인합니다.
캐시된 읽기는 물리 I/O를 만들지 않을 수 있으므로 실제 카운터가 증가한 부하 구간을 사용합니다.
시스템 도구의 표기 단위·초기 누적 구간·측정 범위 차이는 원문과 함께 기록합니다.

원시 앱값·도구 출력·대상 identity·단위·시각·부하 시작/종료·화면·판정을 남깁니다.
수치 일치율이나 새 허용 오차를 이번 필수 기준으로 추가하지 않습니다.
관찰 도구·증거 기록의 I/O는 제품 수집 활동과 분리해 기록합니다.
앱 Collector 자체는 파일 읽기/쓰기 부하·네트워크 요청·매 tick 외부 명령을 수행하지 않습니다.
출시 오차·반복 측정·성능·장기 안정성 기준은 M5 소관입니다.
(`SPEC §5.6`)

### 4.5 SPEC 추적

| 완료 조건 | 주 설계 |
| --- | --- |
| SPEC §5.1 | §1.2, §3.3~§3.5 |
| SPEC §5.2 | §1.3~§1.4, §3.3~§3.5 |
| SPEC §5.3 | §1.2, §2.3, §3.5 |
| SPEC §5.4 | §1.3~§1.4, §2.3, §3.5 |
| SPEC §5.5 | §1.2, §2.2, §4.4 |
| SPEC §5.6 | §4.4 |
| SPEC §5.7 | §1.2~§1.4, §2.2~§2.3, §3.2, §4.3 |
| SPEC §5.8 | §2.1, §2.2, §2.4~§2.5, §4.3 |
| SPEC §5.9 | §1.3, §2.2~§2.5, §4.3 |
| SPEC §5.10 | §1.1, §1.4, §2.1, §3.2~§3.3 |
| SPEC §5.11 | §1.1, §2.1, §2.4, §3.2, §4.1~§4.2 |
| SPEC §5.12 | §1.4, §2.2, §3.2~§3.4 |
| SPEC §5.13 | §1.2~§1.3, §4.1, §4.3 |
| SPEC §5.14 | §3.2, §3.5, §4.2 |
| SPEC §5.15 | §2.4, §3.3~§3.5, §4.2 |
| SPEC §5.16 | §3.3, §3.5, §4.2~§4.3 |
| SPEC §5.17 | 철회 이력만 보존; 현재 구현 의무 없음 |
| SPEC §5.18 | §3.2, §4.3 |
| SPEC §5.19 | §2.3, §2.5, §3.3~§3.4, §4.1~§4.2 |

## 5. Decision Points

### DP1. 수집 축과 실패 격리

채택: Network·Disk 속도와 두 보조 정보 축을 각각 분리합니다.
기존 시스템 tick에 모든 조회를 직렬 추가하면 느린 보조 조회와 실패가 다른 카드에 전파됩니다.
주기는 공통 lifecycle이 소유하고 실행·baseline·이력은 축별로 소유합니다.
영향: 공통 일정과 coordinator의 배선 확장. 관련 `SPEC §5.10`, `SPEC §5.11`.

### DP2. 물리 Network 식별과 VPN

채택: 64비트 route-interface 카운터에 SystemConfiguration·하드웨어 provider 근거를 결합합니다.
물리 최하위 대상만 합산하고 상위 논리·VPN·터널은 상세에서 분리합니다.
이름·Ethernet 유형만으로 가상 인터페이스를 물리라고 판정하지 않습니다.
영향: topology identity·필수 Sandbox 분류 관문. 관련 `SPEC §5.3`, `SPEC §5.5`, `SPEC §5.13`.

### DP3. 물리 Disk 통계와 APFS

채택: 통계 소유 드라이버 ID로 바이트·조건부 Operations를 한 번 집계합니다.
볼륨은 별도 용량 snapshot이며 APFS 공유 용량·논리 whole disk를 물리 I/O에 다시 더하지 않습니다.
영향: 장치·볼륨 다대다 관계와 실제 외장/APFS 관문. 관련 `SPEC §5.2`, `SPEC §5.4`, `SPEC §5.9`.

### DP4. 연속성·순서·허용 지연

채택: 공통 boundary sequence·epoch, 축 generation·요청 순서, 리소스 rate segment를 구분합니다.
중지·wake·실패·topology reset은 기준점을 끊고 정상 주기 변경은 유지합니다.
속도 차분의 최대 간격은 M2와 같은 10초입니다.
영향: source·sink·표시 admission과 기존 CPU·Memory 회귀. 관련 `SPEC §5.8`, `SPEC §5.9`, `SPEC §5.11`.

### DP5. Network 그래프 제거와 Disk 미니 그래프

최신 개정 채택: Network에는 그래프를 표시하지 않고 Disk 수치 옆에 42pt 미니 그래프를 제공합니다.
Disk는 기존 내부 이력·원본 peak 축·극값 downsampling·연속성 모델을 재사용하며
공통 판 면·기준선·Read 점선/Write 실선과 현재/과거/부분값 의미를 유지합니다.
큰 그래프·범례·축/범위·진행 구역과 두 요약 하단의 측정/보조/용량 경과 안내를 제거합니다.
상세에 새 그래프를 추가하지 않으며 상태·시각·갱신 주기·실패 사유는 상세/AX에서 보존합니다.
영향: task-010·011 표시 재검증과 task-011의 새 SPEC §5.19 매핑.
task-009와 SPEC §5.17은 철회 이력으로 유지하고 ID·완료 조건 번호를 재사용하지 않습니다.
관련 `SPEC §5.1`, `SPEC §5.2`, `SPEC §5.10`, `SPEC §5.15`, `SPEC §5.19`.

### DP6. 본체와 상세의 가용 영역

최신 개정 채택: 승인된 280×590pt 샘플의 한 열 배치입니다.
카드 폭 264pt·높이 211/143/101/101pt·본체 padding 8pt·카드 사이 6pt를 사용합니다.
590pt 콘텐츠 높이와 실제 화면 가용 콘텐츠 높이 중 작은 값을 본체 viewport로 사용합니다.
지원 화면에서 네 카드가 스크롤 없이 함께 보이며 590pt보다 작은 예외 가용 영역은 스크롤로 도달합니다.
제목·대표 수치·CPU 그래프는 샘플 비율로 축소하고 Memory 구성·TOP 5·기존 정보 의미를 유지합니다.
TOP 5 제목 아래 추가 3pt도 승인 카드 높이 안에 포함합니다.
아코디언은 기존 그래프의 상시 정보 구조를 바꾸고 2열은 본체 폭과 상세 배치 예산을 넓힙니다.
새 최소 화면 정책을 정하지 않고 현재 화면의 실제 가용 영역 안에 맞춥니다.
영향: task-012의 CPU·Memory 요약 치수·타이포·TOP 5 여백·590pt 본체,
실제 창 frame 보정·상세 크기 제한·예외 화면의 오프스크린 키보드 선택.
관련 `SPEC §5.14`~`SPEC §5.16`.

### DP7. 필수·조건부 API와 비교 관문

채택: native 조사와 실제 Sandbox 관문을 분리하고 필수 항목 미확보는 완료로 처리하지 않습니다.
링크 속도·IOPS는 지원 결과에 따라 제공하며 미지원 사유를 남깁니다.
M3 비교는 원시 근거가 있는 변화 방향 판정이며 출시 수치 기준은 M5에 남깁니다.
영향: 구현 Task의 실기기 확인·환경 부족 반환 계약. 관련 `SPEC §5.6`, `SPEC §5.13`, `SPEC §5.18`.

미채택 결정은 없습니다.
API 접근·하드웨어·작은 화면의 실제 확인은 §4의 IMPLEMENT 관문이며 현재 완료 주장에 포함하지 않습니다.
승인된 사용자 관찰 결과를 바꾸어야 하는 문제가 생기면 근거·영향과 함께 SPEC 소유 단계로 반환합니다.
