# 사용자 설정과 로그인 시 실행 설계

## 근거

- 승인된 [SPEC](./spec.md)의 §5.1~§5.13과 [기능 상태](./README.md)의 SPEC `[x]`를 기준으로 합니다.
  이번 요청은 DESIGN까지이며 제품 구현과 IMPLEMENT 계획 작성은 다음 단계입니다.
- [ROADMAP](../../ROADMAP.md)의 M4 범위와 M3 보류 관문 예외,
  [제품 정의](../../docs/product.md)의 설정·로그인·데이터 보관 정책,
  [기술 설계](../../docs/design.md)의 현재 구현·갱신 프로필·생명주기·이력을 입력으로 사용합니다.
- [M3 DESIGN](../20260817-001-extended-resource-monitoring/design.md)의
  수집 축·실행권·실제 시각·실패 격리·물리 합계·보조 정보·상세 접근성 계약을 이어받습니다.
  해당 문서 상단의 최신 개정과 현재 원본을 따르며, 과거 590pt 본체·작은 글꼴·본체 스크롤 대안을 재사용하지 않습니다.
  읽을 수 있는 한 열과 Memory 자연 높이, 스크롤 없는 기본 표시를 유지합니다.
- 조사 기준은 `main`, HEAD `e78af7f188cbf729924d46834103b297e36f2b4c`입니다.
  analyzer의 읽기 전용 후보를 main이 승인된 SPEC·현재 원본·로컬 SDK에 대조해 적용했습니다.
  적용 전 SPEC SHA256은 `5b9aa6354412b4f9cd57db73f674e905bf76c316242265e6b358db357c4f5a34`입니다.
- `ResourceRunnerApp.swift`의 Settings는 현재 `EmptyView`이고 `AppDelegate.swift`가 단일 coordinator를 구성합니다.
  사용자 설정 저장과 로그인 항목 제어는 아직 없습니다.
- `CollectionPipelines.swift`는 여섯 축의 source·store·scheduler와 공통 admission을 구성합니다.
  `MonitoringLifecycleStore`는 `.m3` 일정 정의를 고정 소유하며 축별 plan revision을 target의 첫 await 전에 갱신합니다.
- `MonitoringScheduler`는 취소 직후 새 Task를 시작합니다.
  generation과 admission은 늦은 결과를 거르지만, 취소를 무시하는 source의 실제 종료까지 새 조회를 막지는 않습니다.
  `AuxiliaryCollectionScheduler`는 실제 완료까지 `inFlight`를 유지하고 갱신 요청을 병합합니다.
- 시스템·Network·Disk 이력은 현재 1초 기준 601개 링입니다.
  빠름의 0.5초에서도 실제 10분을 지원하려면 용량 변경이 필요합니다.
  CPU·Disk의 그래프 조립·정규화·시간축·진행·AX에는 10분 기본값 또는 고정값이 남아 있습니다.
  Memory Swap 변화량과 증가 순위의 600초 계산은 그래프 표시 범위와 별개입니다.
- `DashboardView`의 본체는 폭 280pt의 한 열이며 본체 ScrollView가 없습니다.
  Memory는 최소 높이를 예약하지 않습니다. viewport는 현재 Disk 앵커와 Memory 실제 높이를 사용합니다.
  상세 선택·닫힘은 selection generation으로 늦은 callback과 포커스 복귀를 방어합니다.
- macOS 26.5·arm64·App Sandbox·LSUIElement·단일 메인 앱을 유지합니다.
  Helper·package·관리자 권한·새 entitlement를 추가하지 않습니다.

### 공개 API 조사

로컬 SDK의 `ServiceManagement.framework/Headers/SMAppService.h`와
`SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface`를 확인했습니다.
SDK 경로는 `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk`입니다.

`SMAppService.mainApp`, 등록·해제, `status`, `openSystemSettingsLoginItems()`는 공개 API입니다.
API 사용 앱은 코드 서명이 필요합니다. 메인 앱 등록은 다음 로그인 실행을 설정하며,
해제는 현재 메인 앱을 종료하지 않습니다. 상태는 `enabled`, `requiresApproval`, `notRegistered`, `notFound`를 구분합니다.
SwiftUI Settings·SettingsLink·openSettings도 공개 API입니다.
현재 대시보드가 AppKit의 NSHostingController이므로 설정에는 단일 AppKit 창과 SwiftUI 콘텐츠를 선택합니다.
이 조사는 API 선언과 설계 가능성의 근거이며 실제 등록·로그인·UI 검증 완료 근거는 아닙니다.

## 1. 구조

### 1.1 책임과 초기 구성

| 책임 | 소유 경계 |
| --- | --- |
| 지원 설정·기본값·검증 | `AppPreferences`와 관련 enum |
| 일반 설정 읽기·저장·snapshot·revision | `PreferencesStore` |
| 설정 UI | `PreferencesView` |
| 단일 설정창 생성·재사용·활성화 | `SettingsWindowController` |
| 실제 로그인 조회·등록·해제 | `LoginItemService` native adapter |
| 로그인 진행·실패·실제 상태·복원 결과 | `LoginItemController` |
| 설정의 표시·수집 배선 | `ApplicationCoordinator` |
| 프로필·생명주기 병합 | `MonitoringLifecycleStore`와 순수 일정 정책 |
| 축별 타이머·조회 실행권 | 기존 두 Scheduler |
| 표시 필터·선택·포커스·앵커 | Dashboard 표시 경계 |

파일명은 책임을 드러내는 후보이며 같은 경계를 유지하는 파일 분리는 구현 재량입니다.
`AppDelegate`는 MainActor의 설정 store·로그인 controller를 한 번 소유합니다.
일반 설정을 동기적으로 읽어 유효 snapshot을 확정한 뒤 coordinator에 주입합니다.
같은 snapshot으로 대시보드와 pipeline의 초기 프로필을 구성하고 소비 경로를 연결한 뒤 lifecycle 관찰을 시작합니다.
기본값으로 첫 화면·첫 수집을 시작했다가 저장값으로 바꾸지 않습니다.
뷰와 수집 actor는 UserDefaults를 별도로 읽지 않습니다.
(`SPEC §5.7`, `SPEC §5.8`, `SPEC §5.13`)

### 1.2 일반 설정과 저장

| 필드 | 지원 값 | 기본값 |
| --- | --- | --- |
| `showsCPUCard` | Bool | true |
| `showsMemoryCard` | Bool | true |
| `showsNetworkCard` | Bool | true |
| `showsDiskCard` | Bool | true |
| `showsCPUTopApplications` | Bool | true |
| `showsMemoryTopApplications` | Bool | true |
| `graphTimeRange` | `oneMinute`, `fiveMinutes`, `tenMinutes` | `tenMinutes` |
| `refreshProfile` | `fast`, `standard`, `energySaving`, `maximumEnergySaving` | `standard` |

시간 범위에서 60·300·600초를, 프로필에서 §2.2의 지원 일정만 유도합니다.
임의 Duration이나 축별 interval은 저장하지 않습니다.
앱의 `UserDefaults.standard`에서 소유 키 `preferences.v1`의 property-list dictionary 하나를 사용합니다.
내용은 `schemaVersion = 1`, 여섯 Bool과 두 enum의 안정된 문자열 raw value뿐입니다.

- dictionary 누락·형식 오류·미지원 schemaVersion이면 전체 기본값을 사용합니다.
- 지원 dictionary 안의 누락·잘못된 필드는 해당 필드만 기본값으로 복구합니다.
- Bool은 실제 Boolean 저장 타입만 허용하며 숫자·문자열을 강제 변환하지 않습니다.
- enum은 허용 목록과 정확히 일치하는 문자열만 허용합니다.
- 검증한 동일 값을 화면·대시보드·초기 수집에 사용합니다.
- 최초 읽기는 로그인 등록·해제를 호출하지 않습니다. 첫 명시적 변경부터 정규화한 전체 snapshot을 저장합니다.

개별 변경도 해당 필드만 바꾼 값 타입 전체를 저장·게시합니다.
기본값 복원은 snapshot 하나로 처리해 여러 중간 상태나 profile update를 만들지 않습니다.
로그인 켜기/끄기는 이 dictionary에 넣지 않습니다.
수집값·프로세스·앱 목록·그래프·인터페이스·장치 정보의 직렬화 경로도 만들지 않습니다.
(`SPEC §5.7`, `SPEC §5.8`, `SPEC §5.9`, `SPEC §5.13`)

### 1.3 설정창과 접근

단일 `NSWindowController`가 `NSHostingController<PreferencesView>`를 호스팅합니다.
닫은 뒤 다시 열 때 같은 창을 재사용하고, 명시적으로 열 때 앱을 활성화해 창을 key로 만듭니다.
앱 시작·로그인 실행만으로 설정창이나 대시보드를 열지 않습니다.
제품 설정 접근은 모두 `ApplicationCoordinator.openSettings()`로 연결합니다.

- Release 상태막대 우클릭 메뉴의 「설정…」.
- 앱의 설정 메뉴 명령과 `⌘,`.
- 모든 카드가 숨겨진 본체의 「설정 열기」 버튼.

Debug 상태 주입 메뉴는 구분된 Debug 구역으로 유지할 수 있습니다.
좌클릭 대시보드 토글·transient 동작은 보존합니다.
현재 `EmptyView` Settings·기본 설정 명령은 별도 빈 설정창을 여는 중복 경로가 되지 않도록 정리합니다.
Scene 요구를 충족하는 껍질이 필요해도 두 번째 제품 설정창을 호스팅하지 않습니다.
기본 대시보드에 footer·추가 높이를 넣지 않습니다.
카드 조합·대시보드 닫힘과 무관하게 상태막대 메뉴에서 설정을 열 수 있습니다.
`⌘,`는 앱이 명령을 받는 범위에서만 동작하며 전역 입력을 가로채지 않습니다.
(`SPEC §5.1`, `SPEC §5.2`, `SPEC §5.12`)

### 1.4 표시와 수집의 분리

카드·TOP 5는 화면 구성만 바꾸며 숨김을 이유로 수집·메뉴바 판정·현재값·상세 계산을 바꾸지 않습니다.
그래프 범위는 CPU·Disk 시간축 표시만 바꾸며 보관 이력·Memory 계산 창은 유지합니다.
프로필만 lifecycle 일정 입력에 전달하고 로그인 설정은 ServiceManagement 경계에 전달합니다.
설정창이 열렸다는 이유로 `popoverPresented`를 true로 만들지 않습니다.
일정의 열림/닫힘은 기존 대시보드 실제 delegate 이벤트가 계속 소유합니다.
(`SPEC §5.3`, `SPEC §5.4`, `SPEC §5.5`, `SPEC §5.13`)

## 2. 데이터 흐름

### 2.1 시작과 변경 순서

시작은 일반 설정 검증 → 로그인 실제 상태 조회 → 같은 설정으로 Dashboard/pipeline 구성 →
admission·source·store·소비 연결 → 최초 lifecycle 일정 시작 순서입니다.
최초 로그인 조회는 등록·해제하지 않습니다.

일반 변경은 MainActor에서 revision을 전진시키고 동일 snapshot을 저장·게시합니다.
표시는 다음 view update에, 프로필은 revision과 함께 lifecycle actor에 전달합니다.
lifecycle은 오래된 preference revision을 거부합니다.
전달 Task의 역순 실행·연속 변경이 최종 선택을 되돌리지 않아야 합니다.
샘플 반영은 시작 때 캡처한 표시 설정을 게시하지 않고 반영 순간의 현재 설정을 사용합니다.
(`SPEC §5.2`, `SPEC §5.4`, `SPEC §5.6`, `SPEC §5.7`, `SPEC §5.8`)

### 2.2 프로필과 생명주기의 정확한 병합

일반 모드의 최종 주기입니다. 단위는 초입니다.

| 프로필 | 열림 빠른 지표 | 열림 순위 | 닫힘 빠른 지표 | 닫힘 순위 | 열림 보조 | 닫힘 보조 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 빠름 | 0.5 | 1 | 1 | 5 | 30 | 60 |
| 기본 | 1 | 2 | 2 | 5 | 30 | 60 |
| 절전 | 2 | 4 | 5 | 8 | 30 | 60 |
| 매우 절전 | 5 | 5 | 10 | 10 | 30 | 60 |

빠른 지표는 `systemMetrics`, `networkActivity`, `diskActivity`입니다.
CPU·Memory 순위는 `processSurvey`를 사용합니다.
닫힘 순위는 `max(5초, 2 × 열림 순위)`입니다.
`networkMetadata`, `storageMetadata`는 별도 느린 주기를 유지합니다.

저전력은 축별 하한과 사용자 interval의 max로 병합합니다.

| 축 | 저전력 열림 하한 | 저전력 닫힘 하한 |
| --- | ---: | ---: |
| 빠른 지표 | 2 | 5 |
| 순위 | 4 | 10 |
| 보조 정보 | 60 | 120 |

저전력 최종 주기는 다음과 같습니다.

| 프로필 | 열림 빠른 지표 | 열림 순위 | 닫힘 빠른 지표 | 닫힘 순위 | 열림 보조 | 닫힘 보조 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 빠름 | 2 | 4 | 5 | 10 | 60 | 120 |
| 기본 | 2 | 4 | 5 | 10 | 60 | 120 |
| 절전 | 2 | 4 | 5 | 10 | 60 | 120 |
| 매우 절전 | 5 | 5 | 10 | 10 | 60 | 120 |

저전력 진입은 사용자 절전 선택을 빠르게 만들지 않습니다. 기본 프로필은 기존 `.m3` 일정과 같습니다.
화면 잠금·unknown·디스플레이 슬립·세션 비활성·시스템 sleep 중 하나라도 성립하면
프로필·저전력·팝오버와 무관하게 여섯 축을 paused로 둡니다.
보조 topology·마운트 refresh는 기존 병합·단일 조회 정책을 유지합니다.
(`SPEC §5.5`, `SPEC §5.6`, `SPEC §5.13`)

### 2.3 즉시 적용과 단일 실행

lifecycle은 현재 프로필·lifecycle snapshot으로 계획을 계산합니다.
시스템 revision·preference revision·plan revision은 별도 순서이며 프로필 변경은 잠금·재개 boundary가 아닙니다.
계획 변경은 다음 순서를 따릅니다.

1. 바뀌는 축과 새 interval을 확정합니다.
2. 첫 target await 전에 그 축의 새 plan revision·interval을 admission에 게시합니다.
3. 이전 context의 source·store·display 반영 권한을 끊습니다.
4. Scheduler에 최신 계획을 전달합니다. 바뀌지 않은 축은 재시작하지 않습니다.

유효 계획이 같은 반복 이벤트는 타이머를 만들지 않습니다.
서로 다른 프로필의 저전력 병합 결과가 같은 축도 계속 실행할 수 있습니다.
빠른 Scheduler는 타이머와 실제 조회 실행권을 분리합니다.

- 축별 유효 타이머 하나, native source부터 sink 반영·폐기까지 조회 실행권 하나를 둡니다.
- 교체·중지는 즉시 generation을 전진시키고 취소를 요청합니다.
- 취소를 무시한 source가 실제 종료할 때까지 실행권을 해제하지 않습니다.
- 실행 중 도착한 계획은 최신 하나만 유지합니다.
- 이전 완료는 자신의 조회 ID로 해제하며 새 조회의 실행권을 지우지 못합니다.
- 중지 중에는 새 조회를 시작하지 않습니다. 재개·새 주기는 최신 계획의 다음 유효 deadline부터 실행합니다.

기존 정상 기준 deadline 전진은 유지합니다.
교체 뒤 지난 deadline·이전 조회 때문에 놓친 deadline은 건너뛰며 과거 tick을 연속 보충하지 않습니다.
취소 불가능한 조회가 남으면 실제 완료 뒤 가능한 다음 일정에 새 조회를 시작합니다.
보조 Scheduler의 `inFlight`·pending refresh·캐시 재전달도 같은 revision·단일 실행 규칙을 따릅니다.
한 축의 대기·실패는 다른 축을 기다리게 하지 않습니다.
reader/source 공유 상태, store·캐시, MainActor 표시의 반영 순간마다 context를 확인합니다.
Task 취소 검사만으로 대체하지 않습니다.
(`SPEC §5.6`, `SPEC §5.13`)

### 2.4 실제 시각과 긴 주기의 기준점

속도는 원시 카운터 차분을 실제 샘플 시각의 차이로 나눕니다. interval을 분모로 쓰지 않습니다.
`CollectionRunContext`에 발급 당시 유효 interval `P`를 불변 값으로 넣습니다.
interval·plan revision은 admission의 같은 임계 구간에서 확정·발급합니다.
조회 완료 때 현재 프로필을 다시 읽어 과거 샘플을 재해석하지 않습니다.

빠른 차분 축의 허용 간격은 `G(P) = max(기존 10초, 2 × P)`로 확정합니다.
`P ≤ 5초`는 기존 10초, `P = 10초`는 20초입니다.
실제 경과 시간이 0 이하 또는 G 초과면 기준점 전용으로 처리합니다.
CPU Collector의 측정별 허용 간격 계약과 Network·Disk 차분에 같은 정책을 전달합니다.
프로세스 조사의 기존 20초 최대 간격·Memory 기준점 정책은 유지합니다.

이는 정상 10초 일정의 작은 timer/native 지연을 지원하기 위한 내부 결정입니다.
다음 강제 단절은 G와 무관하게 유지합니다.

- 화면 중지·복귀와 새 collection epoch.
- Network·Disk topology·대상 identity 변경.
- 카운터 감소·재설정·유효하지 않은 값.
- 기존 source 실패·baseline-only·rate segment 전환과 CPU 기준점 재설정 조건.

프로필 변경 자체는 정상 기준점을 지우지 않지만 새 측정 간격이 G를 넘으면 기준점 전용입니다.
오래된 context의 candidate baseline을 새 실행권으로 commit하지 않습니다.
이력에도 당시 G를 전달하고, CPU·Disk 인접점은 뒤쪽 점의 당시 G와 기존 epoch·연속성 키로 판단합니다.
현재 프로필로 과거 연결을 다시 계산하거나 긴 G로 중지·실패·topology를 이어 붙이지 않습니다.
(`SPEC §5.5`, `SPEC §5.6`, `SPEC §5.13`)

### 2.5 최대 이력과 표시 범위

보관은 600초, 최단 지원 주기는 0.5초입니다.
양 끝점 포함 이상적 최소 용량은 `ceil(600 / 0.5) + 1 = 1201`개입니다.
창 경계·native 시각 여유를 포함해 시스템·Network·Disk 활동 링은 각각 1203개로 고정합니다.
주기·표시 범위를 줄여도 링을 축소하거나 유효 10분 이력을 버리지 않습니다.
항목 수와 별도로 실제 시각의 600초 선별을 유지합니다. §2.3의 보충 금지로 지연 뒤 폭주를 방지합니다.

실제 수집값만 추가합니다. 실패 시각·중지·확대된 과거를 현재값이나 보간으로 채우지 않습니다.
재시작은 빈 이력으로 시작합니다.
CPU·Disk presentation은 최대 보관 이력을 유지하고 렌더가 현재 시각·선택 범위로
`now − range ≤ timestamp ≤ now`를 선별합니다.
실패·중지의 last-known presentation도 같은 선별을 사용합니다.
범위 변경은 다음 수집·source 재조회 없이 반영하며 1분 표시로 최대 이력을 먼저 잘라 버리지 않습니다.
(`SPEC §5.4`, `SPEC §5.7`, `SPEC §5.13`)

### 2.6 로그인과 기본값 복원

로그인 원본은 `SMAppService.mainApp.status`이며 실제 상태와 명시적 요청의 진행·결과를 구분합니다.
앱 시작, 설정창 열기·재활성화, 앱 재활성화 후 설정 확인,
요청 완료·실패 직후, 「다시 확인」에서 조회합니다.
조회는 등록·해제하지 않으며 macOS 해제·승인 철회를 저장된 의도로 되돌리지 않습니다.

명시적 켜기/끄기만 register/unregister로 전달합니다.
mutation은 한 번에 하나이며 진행 중 중복 요청을 막고 복원 등 새 의도는 직렬화합니다.
결과는 operation ID와 실제 재조회 후 게시해 늦은 메시지가 현재 결과를 덮지 못하게 합니다.

기본값 복원은 일반 snapshot 저장·즉시 반영과 로그인 해제 의도·실제 결과의 두 부분입니다.
`notRegistered`면 불필요한 unregister 없이 상태를 확인합니다.
`enabled`·`requiresApproval`이면 해제를 요청합니다.
해제 실패·확인 불가가 일반 설정 복원을 취소하지 않습니다.
일반 설정 복원 성공과 로그인 실제 결과·실패를 구분해 설명합니다.
(`SPEC §5.9`, `SPEC §5.10`, `SPEC §5.11`)

## 3. 인터페이스

### 3.1 설정 화면

| 구역 | 컨트롤 |
| --- | --- |
| 표시 | 네 카드 Toggle, CPU·Memory TOP 5 Toggle |
| 그래프 | 최근 1분·5분·10분 Picker |
| 갱신 | 빠름·기본·절전·매우 절전 Picker |
| 로그인 시 실행 | 실제 상태·명시적 변경·시스템 설정 버튼·실패 설명 |
| 기본값 복원 | 복원 Button·일반 설정/로그인 결과 |

카드를 숨겨도 대응 TOP 5 설정을 변경하지 않으며 다시 켤 때 저장 선택을 사용합니다.
그래프는 CPU·Disk에 적용됨을, 갱신은 닫힘·저전력·화면 중지 시 자동 조절됨을 설명합니다.
native 컨트롤과 label·현재값·help를 사용하고 모든 조작·오류 뒤 동작에 키보드로 도달할 수 있게 합니다.
색상만으로 상태·실패를 설명하지 않으며 개발용 축 이름·generation·저장 키는 제품 화면에 넣지 않습니다.
(`SPEC §5.3`, `SPEC §5.4`, `SPEC §5.5`, `SPEC §5.12`)

### 3.2 카드·TOP 5·전체 숨김

CPU → Memory → Network → Disk 순서를 유지하고 켜진 카드만 eager 한 열에 넣습니다.
숨긴 카드는 AX·포커스·앵커·상세 진입에서 제외합니다.
선택한 카드 숨김은 제거 전에 selection을 none으로 바꾸고 generation을 전진시킵니다.
이전 닫힘 callback은 이후 선택을 지우지 못하며 포커스도 숨긴 카드에 남기지 않습니다.

TOP 5 숨김은 제목·행·자리표시·실패 안내를 포함한 요약 구역 전체를 제거합니다.
자연 높이를 줄이고 최소 높이·빈 frame을 남기지 않습니다.
CPU 대표 수치·User/System·그래프, Memory 대표 수치·구성·Pressure·Swap은 유지합니다.
상세 앱 목록·Memory 증가 순위·프로세스 정보도 유지하며 AX는 숨긴 순위를 보이는 것처럼 설명하지 않습니다.

전체 숨김은 상태 설명·「설정 열기」만 자연 높이로 표시합니다.
메뉴바 CPU 판정·설정 접근은 유지하고 네 카드 공간을 예약하지 않습니다.
재표시는 실제 내용 높이로 늘립니다. 수집값·성공/실패·상세 개폐만으로 높이가 바뀌지 않는 기존 원칙은 유지합니다.
기본 글꼴·대표 수치·간격·Memory 자연 높이·TOP 5 여백·네 카드 배치를 보존합니다.
본체 ScrollView·기본 footer·새 작은 화면 정책을 추가하지 않습니다.
(`SPEC §5.1`, `SPEC §5.2`, `SPEC §5.3`, `SPEC §5.13`)

### 3.3 단축키·포커스·viewport

`⌘1` CPU, `⌘2` Memory, `⌘3` Network, `⌘4` Disk, `⌘,` 설정을 고정합니다.
숨긴 카드 단축키는 상세를 열지 않고 다른 카드에 재배정하지 않습니다.
Escape·닫기·복귀, Page Up/Down의 상세 스크롤은 보존합니다.
일반 닫힘은 원래 카드, 카드 제거 시 남은 첫 카드, 전체 숨김 시 설정 버튼으로 복귀합니다.
지연 포커스는 selection generation·표시 revision·현재 보이는 대상을 확인합니다.
설정창이 key이면 대시보드가 포커스를 가져오지 않습니다.

최하단 앵커는 Disk 고정이 아니라 마지막으로 보이는 카드입니다.
등록은 카드 identity·표시 revision을 확인하고 늦은 측정·제거가 새 앵커를 덮지 못하게 합니다.
숨긴 Memory·이전 Disk의 weak view를 계산에 남기지 않습니다.
기본 네 카드에서는 현재 Disk 앵커·Memory 높이 보정 결과를 보존합니다.
다른 조합은 실제 마지막 카드의 화면 좌표로 계산하며 Memory가 앵커 위인지 자신인지에 따라 실제 변위를 반영합니다.
TOP 5를 숨긴 Memory에 이전 높이를 예약하지 않고 Memory 숨김 시 보정을 제거합니다.
앵커가 없으면 상세를 닫고 화면 기반 기본 크기만 유지합니다.
조합 변경 후 본체·앵커·chrome를 재측정하고 기존 화면 여유 8pt·최대 상세 400×480pt·frame 보정 경계를 사용합니다.
상세의 내부 스크롤은 유지하며 본체 geometry를 줄여 상세 공간을 만들지 않습니다.
(`SPEC §5.2`, `SPEC §5.12`, `SPEC §5.13`)

### 3.4 CPU·Disk 공통 범위

하나의 `GraphTimeRange`에서 실제 창·축 문자열·진행 분모·AX를 유도합니다.
CPU presentation은 최대 600초 이력을 유지하고 `HistoryGraphView`, `HistoryGraphTimeAxis`,
`HistoryPoint.normalizedXPosition`에 동일 선택 범위를 전달합니다.
밴드·기준선·단위·원본 peak를 보존하는 downsampling을 유지합니다.
왼쪽 축은 1/5/10분 전, 오른쪽은 지금입니다.

Disk의 `ResourceRateGraph.make`·모델에 선택 범위를 전달합니다.
가시 점·최대값·nice upper bound·normalized X·진행 문구·AX를 같은 구간으로 계산합니다.
Read 점선·Write 실선·42pt 미니 그래프와 극값 보존은 유지합니다.
제거했던 큰 범례·축·진행 구역을 요약에 추가하지 않으며 표시 중인 안내·상세·AX만 선택 범위에 맞춥니다.
수집 중 안내는 실제 시작·끝·선택 구간에서 유도하고 분모는 01:00·05:00·10:00입니다.
확대 뒤 없는 과거는 비우고 중지 공백을 채워진 데이터로 설명하지 않습니다.

Network·Memory 시간축 그래프는 만들지 않습니다.
Memory Swap 변화량·최근 10분 증가 순위·프로세스 600초 기준점 창·30초 최소 간격·21개 링은 유지합니다.
그래프 선택이 이 계산 이름이나 결과를 바꾸지 않습니다.
(`SPEC §5.4`, `SPEC §5.7`, `SPEC §5.13`)

### 3.5 로그인 실제 상태

native adapter는 `SMAppService.mainApp`, `status`, 명시적 `register()`·`unregister()`,
사용자 버튼의 `openSystemSettingsLoginItems()`만 사용합니다. 다른 LoginItem bundle·agent/daemon plist는 만들지 않습니다.

| 실제 상태 | 표시·동작 |
| --- | --- |
| `enabled` | 등록·허용됨. 로그인 실행 가능, 해제 요청 |
| `notRegistered` | 해제됨. 등록 요청 |
| `requiresApproval` | 등록됐으나 macOS 승인 필요. 성공한 켜기로 표시하지 않음, 시스템 설정·등록 해제 |
| `notFound` | 서비스 확인 불가. 다시 확인·명시적 등록 시도의 실제 결과 |
| 알 수 없는 상태 | 확인 불가 설명. 성공 추정 금지 |

켜기 성공은 enabled일 때만 표시합니다. 승인 대기에는 별도 「등록 해제」로 해제가 가능하게 합니다.
호출 성공·throw 모두 실제 status를 다시 읽어 상태와 이번 요청 결과를 별도로 설명합니다.
이미 등록됨·서명 오류·사용자 거부를 임의의 성공값으로 바꾸지 않습니다.
승인 버튼의 명시적 동작만 시스템 설정을 열며 로드·재조회·실패 표시가 자동으로 열지 않습니다.
현재값·진행·사유·필요한 동작·복원 결과는 키보드와 AX로 확인할 수 있어야 합니다.
(`SPEC §5.9`, `SPEC §5.10`, `SPEC §5.11`, `SPEC §5.12`)

### 3.6 사용자 승인 예외 — Disk 저장 공간 기준

2026-10-04 사용자 선택 「macOS 기준으로 맞추기 — 회수 가능한 공간 포함」을 적용합니다.
이 절은 기존 Disk 보조 의미 유지에서 저장 공간 정의만 한정해 대체합니다.
전체는 같은 대상 볼륨의 `volumeTotalCapacityKey`, 사용 가능은
`volumeAvailableCapacityForImportantUsageKey`를 읽은 바이트입니다.
사용 중은 `전체 − 사용 가능`이며 회수 가능한 공간을 사용 가능에 포함한 나머지입니다.
실제 파일 점유량·APFS 볼륨별 독점 사용량으로 설명하지 않습니다.
APFS 공유 공간·대상 identity·관계·느린 수집·조회 시각·last-known 구분은 유지합니다.

Disk 저장 공간 전용1000 기반 B/KB/MB/GB/TB formatter를 사용합니다.
기존 로케일·소수 한 자리·반올림·그룹 구분과 compact 공통 단위 조립을 유지합니다.
요약·상세·볼륨 행·AX에 같은 formatter와 정의를 적용하고 회수 가능 포함을 상세/AX에 설명합니다.
공통 `bytes`·`byteRate`, Read/Write·드라이버 누적량과 다른 리소스 표시는 바꾸지 않습니다.

important-usage 누락·잘못된 타입·음수·전체 초과·조회 throw는 기존 storage 보조 실패로 반환합니다.
raw available fallback·0 대체·clamp·추정 성공을 사용하지 않습니다.
새 정의의 과거 성공 값만 기존 identity/revision 조건에서 last-known으로 설명합니다.
기존 snapshot 실패 단위를 유지하고 빠른 Disk I/O는 보조 실패와 독립적으로 갱신합니다.
앱 번들의 `PrivacyInfo.xcprivacy`에 사용자 표시 용도의
`NSPrivacyAccessedAPICategoryDiskSpace`/`85F4.1`을 선언하고 번들 포함을 확인합니다.
추적·외부 전송이나 entitlement를 추가하지 않습니다.

별도 `implement` Per-Request 수정 후 task-010이 현재 기준의 회귀 근거를 연결합니다.
같은 볼륨·가까운 조회 시각의 total/important-usage 원시값, 단위·표시·AX·실패 격리,
Sandbox 실제 접근과 기존 속도/누적량 formatter 불변을 확인합니다.
OS 추정·조회 시각 차이로 다른 시각의 스크린샷 숫자 완전 일치는 완료 조건으로 삼지 않습니다.
(`SPEC §5.13`; M3 `SPEC §5.2`, `§5.4`, `§5.10`~`§5.14`)

## 4. 영향 범위

### 4.1 변경 경계

| 원본·책임 | 직접 영향 |
| --- | --- |
| `AppDelegate.swift`, `ResourceRunnerApp.swift` | 초기 설정 소유·주입, 설정 명령·빈 Settings 중복 정리 |
| 새 설정 모델·store·저장 adapter | 지원 값·검증·snapshot·revision |
| 새 설정 view·window controller | 단일 창·키보드/AX·복원 결과 |
| 새 로그인 adapter·controller | 공개 mainApp·직렬 요청·실제 상태·실패 |
| `ApplicationCoordinator.swift`, `StatusBarController.swift` | 초기 설정·변경 배선·우클릭·활성화 재조회·단축키 |
| `MonitoringLifecycle.swift`, `CollectionPipelines.swift` | 초기 프로필·일정 병합·preference revision |
| 두 Scheduler | 단일 조회·최신 계획 인계·지난 deadline 보충 금지 |
| `CollectionAdmission.swift` | 불변 interval과 revision의 원자 발급·늦은 반영 거부 |
| `CPUSystemMetricsCollector.swift`, `SystemMetricsSampleSource.swift`, Network/Disk 활동 | 측정별 G·candidate 상태 admission commit |
| 시스템·활동 store·이력 모델 | 1203개 최대 이력·당시 G |
| Dashboard/ResourceActivity presentation·delivery 경계 | 현재 설정·최대 이력·선택 정리·실패/중지 값 보존 |
| Dashboard view·viewport, 그래프·Disk view | 자연 높이·현재 앵커·범위·시간축·AX |
| 관련 단위·렌더·UI 검증 | 새 불변식·기본 회귀 |

상위 기술 설계의 현재 구현 설명은 실제 구현 완료 후 갱신합니다.
기존 계산식·identity/집계·순위 정원·메뉴바 판정·Network 물리/부분 합계·Disk 물리/볼륨 관계·보조 의미는 유지합니다.
긴 주기 G만 §2.4의 내부 정책으로 확장합니다.
macOS 26.5·arm64·Sandbox·LSUIElement·단일 메인 앱·추가 Helper/package 없음·수집 영속화 없음은 유지합니다.
(`SPEC §5.6`, `SPEC §5.7`, `SPEC §5.10`, `SPEC §5.13`)

### 4.2 후속 검증 관문

다음은 IMPLEMENT에 배분할 관문이며 이번 DESIGN의 실행 결과가 아닙니다. Task ID·순서·경계는 implement-init이 소유합니다.

- **설정·시작:** 기본값·유효값·누락·Boolean 대신 숫자/문자열·미지원 enum/schema·손상 dictionary;
  UI/첫 수집의 동일 snapshot; 복원 한 번의 apply; 초기 읽기·재시작·재확인의 native mutation 0회;
  설정 유지·수집 이력 미복원; 소유 키에 설정만 저장.
- **일정·실행권:** 네 프로필×열림/닫힘×일반/저전력 표; 화면 비가시 우선 중지; 저전력 감속;
  연속·역순 변경·같은 계획 반복; 취소 무시 source·대기 sink/display의 stale 거부;
  축별 최대 동시 조회 1·타 축 독립; 보조 refresh 병합; 지난 deadline 보충 없음.
- **차분·공백:** 실제 경과 속도; P≤5의 기존 10초·P=10의 정상 지연/20초/초과;
  epoch·실패·topology·카운터 감소 단절; 이전 interval 결과 재해석 없음;
  현재 프로필로 과거 그래프 연결 재해석 없음.
- **이력·그래프:** 0.5초로 실제 600초 양 끝과 제한 용량; native 지연·일정 교체·overflow·긴 중지·실패;
  1→5→10, 10→1→10 즉시 실제 이력 표시; 빈/부분/충분/중지 이력의 축·분모·AX 일치;
  CPU 밴드·Disk 계열·선택 구간의 peak/downsampling; Memory 600초 계산 불변; Network/Memory 새 그래프 없음.
- **표시·창·AX:** 16개 카드 조합과 두 TOP 5 조합; 기본 글꼴·Memory 자연 높이·순위 여백·본체 무스크롤;
  숨긴 구역의 예약 공백·AX 제거; 열린 상세 숨김·빠른 재표시·늦은 닫힘;
  단축키 대응·포커스 복귀·key 설정창 보호; 마지막 카드/Memory/TOP 5 변경·stale 앵커 거부;
  실제 화면·chrome·8pt 여유·하단 상세·긴 Memory;
  Release 우클릭·⌘,·전체 숨김 복구·단일창 재사용; 컨트롤·현재값·오류·복원의 키보드/AX;
  기존 상태 설명·상세 정보·기본 수집 의미 회귀.

(`SPEC §5.1`~`SPEC §5.9`, `SPEC §5.12`, `SPEC §5.13`)

### 4.3 실제 로그인 실행

`SPEC §5.10`의 다음 로그인 실행은 mock·status 조회·수동 실행만으로 완료 처리하지 않습니다.
같은 bundle identifier·서명·entitlement의 메인 앱을 안정된 경로에 두고 실제 adapter로 확인합니다.
관찰 중 등록 bundle을 다른 빌드·경로로 계속 교체하지 않습니다.

1. 대상 macOS·arm64·Sandbox·LSUIElement·번들/실행 파일·코드 서명·Helper/package 없음.
2. 최초 읽기 전후 실제 상태와 mutation 없음.
3. 명시적 등록의 native 결과·status·macOS 로그인 항목.
4. 승인 대기·macOS 허용 철회/변경·앱 재확인·필요 동작.
5. 등록·허용 후 다음 로그인에서 메인 앱 자동 실행의 실제 관찰.
   수동 실행·macOS 이전 창 복원과 구분하는 실행 시각·bundle 경로 근거.
6. 해제·복원 뒤 실제 해제와 현재 메인 앱의 계속 실행.
7. 일반 복원 성공과 로그인 실패·승인·확인 불가의 분리.
8. native 실패를 성공값으로 바꾸지 않는 UI·AX.

이번 DESIGN에서 등록·로그아웃·재부팅을 실행하지 않습니다.
향후 실제 로그인 관찰은 main이 당시 운영 접근 권한·사용자 승인 범위를 확인해 조정합니다.
필수 관문의 환경·권한이 없으면 이유·영향을 반환하고 관련 Task를 승인하지 않습니다.
M4의 관문·단위 회귀는 M3 task014/015 보류를 재개하거나 완료하는 근거가 아닙니다.
(`SPEC §5.9`, `SPEC §5.10`, `SPEC §5.11`, `SPEC §5.13`)

### 4.4 SPEC 추적

| 조건 | 주 설계 |
| --- | --- |
| SPEC §5.1 | §1.3, §3.2, §4.2 |
| SPEC §5.2 | §2.1, §3.2~§3.3, §4.2 |
| SPEC §5.3 | §1.2, §1.4, §3.1~§3.2 |
| SPEC §5.4 | §1.4, §2.5, §3.4, §4.2 |
| SPEC §5.5 | §2.2~§2.4, §4.2 |
| SPEC §5.6 | §2.1, §2.3~§2.4, §4.2 |
| SPEC §5.7 | §1.1~§1.2, §2.1, §2.5, §4.2 |
| SPEC §5.8 | §1.2, §2.1, §4.2 |
| SPEC §5.9 | §1.2, §2.6, §3.5, §4.3 |
| SPEC §5.10 | §2.6, §3.5, §4.3 |
| SPEC §5.11 | §2.6, §3.5, §4.3 |
| SPEC §5.12 | §1.3, §3.1~§3.3, §3.5, §4.2 |
| SPEC §5.13 | §1.2~§1.4, §2.2~§2.5, §3.2~§3.4, §3.6, §4.1~§4.3 |

## 5. Decision Points

모든 내부 결정을 채택했습니다. 아래는 구현 완료나 실제 운영 관문 통과 주장이 아닙니다.

| 결정 | 채택과 이유 | 영향·조건 |
| --- | --- | --- |
| DP1 일반 설정과 로그인 분리 | 검증한 snapshot만 UserDefaults 저장, 로그인은 실제 macOS 상태. 초기 OS 부작용 방지·복원 결과 분리 | startup·store·login controller, SPEC §5.7~§5.11·§5.13 |
| DP2 단일 AppKit 설정창 | NSWindowController와 공통 open 경로. 기존 Dashboard 높이·AppKit 호스팅 보존 | Scene·메뉴·창·포커스, SPEC §5.1·§5.2·§5.12 |
| DP3 닫힘·저전력 병합 | 닫힘 순위 max(5,2×열림), 보조 일반30/60·저전력60/120, 축별 저전력 하한 max. 기본 유지·절전 선택 가속 방지 | 일정·lifecycle, SPEC §5.5·§5.6 |
| DP4 실제 단일 조회 | generation 외 실제 완료까지 실행권·최신 계획·보충 금지. 취소 무시 조회 겹침 방지 | Scheduler·admission·늦은 반영, SPEC §5.6·§5.13 |
| DP5 당시 interval과 G | context에 P, G=max(10,2P), 당시 G로 과거 연결. 10초 정상 지연 지원·강제 단절 유지 | Collector·차분·이력 모델, SPEC §5.5·§5.6·§5.13 |
| DP6 보관과 표시 분리 | 600초·0.5초 기준 1203개 고정 링, 렌더에서 범위 선택. 재확대 실제 과거·Memory 고정 계산 보존 | store·그래프·축/AX, SPEC §5.4·§5.7·§5.13 |
| DP7 자연 높이·현재 앵커 | 숨긴 구역 제거·단축키 고정·마지막 표시 카드 앵커. 예약 공간 없이 기본 geometry 보존 | view·selection·focus·viewport, SPEC §5.1~§5.3·§5.12·§5.13 |
| DP8 native 실제 로그인 | mainApp만, 승인/실패 분리·실제 다음 로그인 필수 관문. status·mock의 완료 대체 방지 | adapter·오류 UI·실제 관찰, SPEC §5.9~§5.13 |

미채택 내부 결정은 없습니다.
구현 중 승인된 사용자 관찰 결과·완료 조건의 의미 변경이 필요하면 근거·영향·수정 소유 단계를 main에 반환합니다.

DP9: Disk 저장 공간만1000 기반·important-usage available을 사용합니다. 값 미확보는 기존 보조 실패이며 raw fallback은 없습니다. native 조회·전용 formatter·상세/AX·privacy manifest·task-010 회귀에 영향을 줍니다(SPEC §5.13).
