# 사용자 설정과 로그인 시 실행 구현

## 기준과 경계

승인된 [SPEC](./spec.md) §5.1~§5.13과 [DESIGN](./design.md)을 구현합니다.
조사 기준은 `main`, HEAD `3f8f0758458fd78c846a10da805675dc2c6067ba`입니다.
analyzer의 읽기 전용 후보를 main이 선행 문서·현재 원본·기존 검증 파일에 대조해 적용했습니다.
Task는 문서 순서로 진행하며 각 항목의 선행 Task가 승인된 뒤 착수합니다.
경로는 프로젝트 루트 기준이며 새 파일명은 DESIGN의 책임 후보입니다.
같은 책임 경계를 유지하는 파일 분리는 구현 재량입니다.

각 Task는 원본·diff·검증 방법·관찰 결과·미확인 범위를 근거로 한 번의 verify에서 판정할 수 있는 결과 단위입니다.
현재 승인 근거나 최근 reject는 없습니다. 해당 필드는 구현·검증 단계에서 관리합니다.
검증은 각 Task의 결과를 판정하는 단위·렌더·UI 근거로 구성합니다.

구현 계획 작성 단계에서는 제품 구현·로그인 등록/해제·로그아웃·재부팅을 수행하지 않았습니다.
2026-10-03 사용자 `$implement-loop M4` 요청으로 아래 Task의 순차 구현·검증을 시작합니다.
마지막 실제 로그인 관문은 향후 main이 환경·운영 접근 권한·사용자 승인 범위를 확인해 조정합니다.
필수 관문을 실행할 권한·환경이 없으면 관련 Task를 승인하지 않습니다.
M3 task014/015 보류와 기존 승인은 유지하며 해당 관문을 재개하거나 완료 처리하지 않습니다.

## 체크리스트

- [x] task-001: 검증된 일반 설정 snapshot과 저장·복원
  - 목적: 지원 설정만 저장·게시하고 잘못된 값은 기본값으로 복구하는 단일 일반 설정 원본을 완성합니다.
  - 접근: 선행 없음. 새 `AppPreferences`·enum·`PreferencesStore`·저장 adapter를 구성합니다. 출발점은 `ResourceRunner/AppDelegate.swift`, `ResourceRunner/ApplicationCoordinator.swift`입니다. `UserDefaults.standard`의 `preferences.v1` dictionary에 schemaVersion 1·여섯 Bool·두 enum raw value만 저장합니다. dictionary/schema 오류는 전체 기본값, 지원 dictionary의 필드 오류는 해당 기본값으로 복구합니다. snapshot·revision을 함께 게시하고 복원은 한 snapshot으로 처리합니다. 초기 배선은 task-005, 로그인은 task-004가 소유합니다.
  - 검증 조건:
    - 결과: 네 카드·두 TOP 5 켜기, 최근10분, 기본 프로필이 기본값입니다. 검증된 전체 snapshot만 저장하며 로그인 의도·수집값은 저장하지 않습니다.
    - 확인: 독립 저장소에서 누락·손상 dictionary·미지원 schema/enum·숫자/문자열 Bool·필드 오류·정상 round-trip을 검증합니다. 실제 Boolean 외 강제 변환 없음, 명시적 변경 전 쓰기 없음, 개별 변경과 복원 각각 한 번의 저장·게시·revision 전진, payload에 설정 외 데이터 없음을 확인합니다.
  - 참조: SPEC §5.7, §5.8, §5.9, §5.13; DESIGN §1.1, §1.2, §2.1, §4.1, §4.2, §5 DP1.
  - 승인 근거: 2026-10-03 main이 독립 verifier의 approved를 확정했습니다. HEAD cf9bc683 기준 세 파일 패치·해시와 signed PreferencesStoreTests 5/5·실패/skip0의 현재 대응을 확인했습니다. [task-001 근거](./evidence/task-001/README.md). loop 구현 재시도0·근거 재검증0이며 이번 Task로 마지막 매핑이 완료되는 SPEC 조건은 없습니다.

- [x] task-002: 네 프로필 일정과 실제 단일 조회 실행권
  - 목적: 프로필·생명주기 변경을 다음 유효 일정에 반영하고 취소를 무시하는 조회까지 축별 실행 하나로 제한합니다.
  - 접근: 선행 task-001. 출발점은 `ResourceRunner/MonitoringLifecycle.swift`, `ResourceRunner/CollectionPipelines.swift`, `ResourceRunner/MonitoringScheduler.swift`, `ResourceRunner/AuxiliaryCollectionScheduler.swift`, `ResourceRunner/CollectionAdmission.swift`입니다. 순수 프로필 정책을 주입하고 preference/system/plan revision을 분리합니다. 바뀐 축의 plan revision·interval을 첫 target await 전에 같은 admission 임계 구간에서 확정하고 context에 당시 interval `P`를 불변 값으로 넣습니다. 타이머와 실제 조회 실행권을 분리하며 최신 계획 하나·조회 ID·실제 완료까지 실행권을 유지합니다. 보조 pending refresh·캐시 재전달에도 같은 규칙을 적용합니다.
  - 검증 조건:
    - 결과: 일정 열은 `(열림 빠른 지표, 열림 순위, 닫힘 빠른 지표, 닫힘 순위, 열림 보조, 닫힘 보조)`, 단위는 초입니다. 일반은 빠름 `(0.5,1,1,5,30,60)`, 기본 `(1,2,2,5,30,60)`, 절전 `(2,4,5,8,30,60)`, 매우 절전 `(5,5,10,10,30,60)`입니다. 저전력은 빠름·기본·절전 `(2,4,5,10,60,120)`, 매우 절전 `(5,5,10,10,60,120)`입니다. 비가시 신호는 여섯 축 paused가 우선합니다. 같은 계획은 재시작하지 않고 지난 deadline을 보충하지 않습니다.
    - 확인: `ResourceRunnerTests/MonitoringLifecycleTests.swift`, `CollectionPipelinesTests.swift`, `CollectionAdmissionTests.swift`, `AuxiliaryCollectionSchedulerTests.swift`의 수동 시계·대기 source/sink 패턴으로 네 프로필×열림/닫힘×일반/저전력·모든 중지 신호를 확인합니다. 연속·역순 변경, 같은 계획 반복, 취소 무시 source, 대기 sink, 보조 refresh 병합에서 최대 실제 조회1·유효 타이머1·최신 계획·타 축 독립·stale 거부·보충 없음·revision/P 일치를 검증합니다.
  - 참조: SPEC §5.5, §5.6, §5.13; DESIGN §1.4, §2.1, §2.2, §2.3, §2.4, §4.2, §5 DP3~DP5.
  - 승인 근거: 2026-10-03 main이 독립 재검증 approved를 확정했습니다. HEAD1647242 기준 전체9파일 소스 해시·최종 수정4파일 diff/로그가 일치하고 관련7suite50case(동적56실행)·실패/skip0입니다. A→B→A 최신 revision 누락을 수정하고 두 Scheduler의 역순 조회/캐시/pending 회귀를 확인했습니다. [task-002 근거](./evidence/task-002/README.md). 구현 재시도1·근거 재검증0; 이번에 완료되는 SPEC 전체 조건은 없습니다.

- [ ] task-003: 당시 주기의 차분·단절과 제한된10분 이력
  - 목적: 긴 정상 주기도 실제 경과 시간으로 계산하고 빠름의10분 이력을 제한된 메모리에 보존합니다.
  - 접근: 선행 task-002. 출발점은 `ResourceRunner/CPUSystemMetricsCollector.swift`, `ResourceRunner/SystemMetricsSampleSource.swift`, `ResourceRunner/NetworkActivity.swift`, `ResourceRunner/DiskActivity.swift`, `ResourceRunner/MonitoringSampleStore.swift`, `ResourceRunner/ProcessHistoryStore.swift`입니다. CPU 측정별 허용 간격과 Network·Disk 차분에 `G(P)=max(10초,2×P)`를 전달하고 candidate 상태는 현재 admission에서만 commit합니다. 시스템·Network·Disk 링은 각각1203개로 고정하며 실제600초 선별을 유지합니다. CPU·Disk 점에 당시 G·기존 연속성을 보존합니다. 표시 범위는 task-006이 소유합니다.
  - 검증 조건:
    - 결과: P≤5초는 G=10초, P=10초는 G=20초이며 분모는 실제 시각 차이입니다. 0 이하·G 초과는 기준점 전용입니다. epoch·실패·topology/identity·카운터 감소의 단절·Collector별 실패 격리를 유지합니다. 프로필 변경만으로 정상 기준점을 지우거나 과거 P를 재해석하지 않습니다. 링은 주기·표시 범위에 따라 축소하지 않습니다. 프로세스 최대20초·Memory600초 창/30초 최소 간격/21개 링은 유지합니다.
    - 확인: `ResourceRunnerTests/SystemMetricsCollectorTests.swift`, `SystemMetricsSampleSourceTests.swift`, `NetworkActivityTests.swift`, `DiskActivityTests.swift`, `MonitoringSampleStoreTests.swift`, `ProcessHistoryStoreTests.swift`에서 정상 지연·정확한 G 경계·초과·강제 단절·늦은 candidate 거부를 확인합니다. 0.5초의600초 양 끝점,1203개 상한·overflow·주기 변경·native 지연·긴 중지·실패, 보간/가짜0/과거 채움 없음과 기존 Memory·프로세스 계산 결과를 검증합니다.
  - 참조: SPEC §5.5, §5.6, §5.7, §5.13; DESIGN §2.4, §2.5, §3.4, §4.1, §4.2, §5 DP5, DP6.

- [ ] task-004: 실제 로그인 상태와 직렬 요청·복원 결과
  - 목적: 일반 설정과 독립된 macOS 로그인 상태를 관리하고 명시적 요청·복원 결과를 구분합니다.
  - 접근: 선행 task-001. 새 `LoginItemService` adapter·`LoginItemController`를 구성합니다. 출발점은 `ResourceRunner/AppDelegate.swift`, `ResourceRunner/ApplicationCoordinator.swift`이며 일반 복원은 task-001 store를 사용합니다. native 경계는 `SMAppService.mainApp.status`, 명시적 register/unregister, 사용자 버튼의 `openSystemSettingsLoginItems()`입니다. mutation 하나·operation ID·새 의도 직렬화를 유지합니다. 완료/실패 뒤 재조회 상태와 요청 결과를 분리합니다. 시작·활성화는 task-005, UI는 task-009, 실제 OS는 task-011이 소유합니다.
  - 검증 조건:
    - 결과: enabled만 켜기 성공이며 승인 대기·notFound·알 수 없는 상태·throw는 성공으로 추정하지 않습니다. 조회는 mutation·시스템 설정 열기를 실행하지 않습니다. 일반 복원과 로그인 해제 결과를 분리하며 notRegistered는 불필요한 unregister가 없습니다. 로그인 실패로 일반 복원을 취소하지 않습니다.
    - 확인: 주입 adapter로 모든 상태·등록/해제 실패·승인 대기·OS 변경·중복 요청·복원 경합·늦은 결과를 확인합니다. 초기 mutation0회·재조회 순서·최대 mutation1회·stale 결과 거부·일반 복원 한 번과 결과 분리를 검증합니다. mainApp 외 서비스·자동 시스템 설정 열기·저장된 로그인 의도가 없는지 원본을 대조합니다. mock은 실제 다음 로그인 근거를 대체하지 않습니다.
  - 참조: SPEC §5.9, §5.10, §5.11, §5.13; DESIGN §1.1, §1.2, §2.6, §3.5, §4.1, §4.3, §5 DP1, DP8.

- [ ] task-005: 첫 화면·최초 일정과 즉시 변경의 단일 배선
  - 목적: 처음부터 같은 저장 설정을 사용하고 늦은 수집·설정 전달이 현재 선택을 되돌리지 않게 합니다.
  - 접근: 선행 task-001~task-004. 출발점은 `ResourceRunner/AppDelegate.swift`, `ResourceRunner/ApplicationCoordinator.swift`, `ResourceRunner/CollectionPipelines.swift`, `ResourceRunner/DashboardPresentationStore.swift`, `ResourceRunner/CollectionDeliveryStore.swift`, `ResourceRunner/DashboardPresentation.swift`, `ResourceRunner/ResourceActivityPresentation.swift`입니다. 일반 검증→로그인 실제 조회→같은 snapshot의 Dashboard/pipeline→admission/source/store/소비 연결→최초 lifecycle 일정 순서입니다. 표시 경계에 현재 snapshot/revision을 전달하고 변경은 현재 delivery·최대 이력으로 재조립합니다. profile만 lifecycle에 전달하며 샘플 반영은 현재 설정을 사용합니다.
  - 검증 조건:
    - 결과: 기본값으로 잠깐 시작했다가 바꾸지 않으며 저장 프로필이 최초 일정부터 적용됩니다. 설정·표시·수집의 원본이 같습니다. 화면 설정은 수집·메뉴바·순위/상세 계산을 바꾸지 않고 그래프 선택은 Memory 계산 창을 바꾸지 않습니다. 초기 읽기·재실행·활성화 재확인으로 로그인 상태를 바꾸지 않습니다.
    - 확인: `ResourceRunnerTests/ApplicationCoordinatorTests.swift`, `CollectionPipelinesTests.swift`, `CollectionAdmissionTests.swift`, `DashboardPresentationTests.swift`, `ResourceActivityPresentationTests.swift`에서 저장 snapshot을 주입해 첫 구성·첫 apply·초기 source를 관찰합니다. 연속/역순 전달·대기 sample/display·실패/중지 last-known에서 현재 revision·최종 프로필·표시 선택을 확인합니다. 재실행 시 설정은 복원되고 수집 이력·프로세스/장치 목록은 빈 메모리로 시작하는지 확인합니다.
  - 참조: SPEC §5.2, §5.4, §5.5, §5.6, §5.7, §5.8, §5.11, §5.13; DESIGN §1.1, §1.4, §2.1, §2.3, §2.5, §2.6, §4.1, §4.2.

- [ ] task-006: CPU·Disk의 공통1/5/10분 표시 범위
  - 목적: 최대 이력을 유지하고 CPU·Disk 구간·축·진행·AX를 선택 범위에 즉시 일치시킵니다.
  - 접근: 선행 task-003, task-005. 출발점은 `ResourceRunner/DashboardPresentation.swift`, `ResourceRunner/DashboardView.swift`, `ResourceRunner/ResourceRateGraph.swift`, `ResourceRunner/ResourceRateGraphView.swift`, `ResourceRunner/ResourceActivityPresentation.swift`, `ResourceRunner/DiskDashboardView.swift`입니다. 같은 `GraphTimeRange`를 CPU HistoryGraphView/HistoryGraphTimeAxis/normalizedXPosition과 Disk 모델·렌더·안내에 전달합니다. 현재 시각의 선택 범위만 선별하고 뒤쪽 점의 당시 G·epoch·연속성으로 연결합니다.
  - 검증 조건:
    - 결과: 60/300/600초 창·왼쪽1/5/10분 전·오른쪽 지금·분모01:00/05:00/10:00·표시 안내·상세·AX가 일치합니다. 재수집 없이 변경하며 없는 과거·중지 공백을 채우지 않습니다. CPU 밴드·기준선·극값, Disk Read 점선/Write 실선·42pt 미니 그래프·가시 peak/nice upper bound를 유지합니다. Network/Memory 그래프나 제거된 Disk 큰 안내는 추가하지 않습니다.
    - 확인: `ResourceRunnerTests/DashboardPresentationTests.swift`, `ResourceRateGraphTests.swift`, `ResourceRateGraphRenderingTests.swift`, `DiskDashboardViewTests.swift`에서 빈/부분/충분/실패/중지,1→5→10·10→1→10, 서로 다른 당시 G·강제 단절·창 밖 극값·downsampling을 확인합니다. 같은 원본의 Memory Swap·증가 순위 결과와600초 이름이 범위에 따라 바뀌지 않는지 검증합니다.
  - 참조: SPEC §5.4, §5.7, §5.13; DESIGN §1.4, §2.4, §2.5, §3.4, §4.2, §5 DP5, DP6.

- [ ] task-007: 카드·TOP 5 숨김과 자연 높이·선택 정리
  - 목적: 숨긴 구역을 layout·AX에서 제거하고 대표값·상세·기본 배치·전체 숨김 복구를 유지합니다.
  - 접근: 선행 task-005, task-006. 출발점은 `ResourceRunner/DashboardView.swift`, `ResourceRunner/DashboardPresentationStore.swift`, `ResourceRunner/DashboardPresentation.swift`, `ResourceRunner/ResourceActivityPresentation.swift`입니다. 고정 순서의 켜진 카드만 eager 한 열에 구성합니다. TOP 5 제목·행·자리표시·실패 안내 전체를 제거합니다. 선택 카드 제거 전에 none·generation 전진을 적용하고 숨긴 상세 진입을 막습니다. 전체 숨김은 설명·공통 설정 callback만 표시합니다. 창은 task-009, 포커스·viewport는 task-008이 소유합니다.
  - 검증 조건:
    - 결과: 네 카드·두 TOP 5가 독립 즉시 반영되며 다른 저장 선택을 바꾸지 않습니다. 예약 frame·최소 높이·빈 순위 공간·본체 ScrollView·기본 footer가 없습니다. CPU 대표값/User/System/그래프·Memory 구성/Pressure/Swap·상세 목록을 유지합니다. 숨긴 AX·선택을 제거하고 늦은 닫힘은 새 선택을 지우지 않습니다. 기본 글꼴·Memory 자연 높이·TOP 5 여백·네 카드 배치를 유지합니다.
    - 확인: `ResourceRunnerTests/IntegratedDashboardSummaryTests.swift`, `DashboardPresentationTests.swift`와 `ResourceRunnerUITests/DashboardCPUCardUITests.swift`, `DashboardMemoryCardUITests.swift`, `DashboardCardSelectionUITests.swift`로16개 카드 조합·두 TOP 5 각각의 on/off 조합을 확인합니다. 열린 상세 숨김·빠른 재표시·늦은 닫힘·전체 숨김의 frame/AX/selection을 관찰하고 기존 기본 수치·글꼴·무스크롤 근거와 대조합니다.
  - 참조: SPEC §5.1, §5.2, §5.3, §5.12, §5.13; DESIGN §1.2, §1.4, §2.1, §3.2, §4.2, §5 DP7.

- [ ] task-008: 표시 조합의 포커스·단축키·현재 앵커
  - 목적: 제거 뒤 키보드 복귀와 마지막 표시 카드의 상세 공간을 안정적으로 유지합니다.
  - 접근: 선행 task-007. 출발점은 `ResourceRunner/DashboardView.swift`, `ResourceRunner/DashboardViewport.swift`, `ResourceRunner/StatusBarController.swift`, `ResourceRunner/DashboardPresentationStore.swift`입니다. ⌘1~⌘4 대응을 고정하고 숨긴 카드는 무동작으로 둡니다. 원래 카드→남은 첫 카드→전체 숨김 설정 버튼 순서로 유효 포커스에 복귀합니다. 지연 동작은 generation·표시 revision·현재 대상·key 설정창을 확인합니다. 앵커는 마지막 카드 identity/revision과 Memory 실제 위치·TOP 5 변경 높이를 반영합니다.
  - 검증 조건:
    - 결과: stale 포커스·측정·제거가 새 화면을 덮지 않고 숨긴 Memory·이전 Disk weak view를 쓰지 않습니다. 기본 Disk 앵커·Memory 보정을 보존합니다. 조합 변경 후 본체·앵커·chrome를 재측정하고8pt 여유·최대400×480pt·frame 보정을 유지합니다. 앵커 없음은 상세를 닫고 기존 화면 기본 크기를 유지합니다. 본체 축소로 상세 공간을 만들지 않으며 상세 스크롤·Escape·Page Up/Down을 유지합니다.
    - 확인: `ResourceRunnerTests/DashboardViewportTests.swift`와 `ResourceRunnerUITests/DashboardDetailPopoverUITests.swift`, `DashboardDetailExpansionUITests.swift`, `DashboardCardSelectionUITests.swift`로 마지막 카드·Memory의 마지막/위쪽/숨김·TOP 5 변경·stale 등록/제거를 확인합니다. 실제 화면 하단 상세·긴 Memory·chrome·단축키·포커스 복귀를 관찰합니다. key 설정창 보호의 최종 실행 근거는 task-009의 창과 함께 확인합니다.
  - 참조: SPEC §5.2, §5.12, §5.13; DESIGN §1.3, §3.2, §3.3, §4.2, §5 DP2, DP7.

- [ ] task-009: 단일 설정창과 접근·키보드·AX
  - 목적: Release 메뉴바에서 모든 설정·실제 로그인 상태·복원 결과를 조작하는 제품 화면을 완성합니다.
  - 접근: 선행 task-004~task-008. 출발점은 `ResourceRunner/ResourceRunnerApp.swift`, `ResourceRunner/AppDelegate.swift`, `ResourceRunner/ApplicationCoordinator.swift`, `ResourceRunner/StatusBarController.swift`, `ResourceRunner/DashboardView.swift`입니다. `PreferencesView`·단일 `SettingsWindowController`를 구성해 모든 접근을 coordinator.openSettings()로 연결합니다. Release 우클릭·앱 명령/⌘,·전체 숨김 버튼·EmptyView 중복 경로 정리, 시작·창 열기/재활성화·앱 재활성화 후 설정 확인·다시 확인·요청 완료/실패 재조회를 연결합니다.
  - 검증 조건:
    - 결과: 창을 재사용하고 명시적 열기만 활성화합니다. 앱/로그인 시작으로 창·대시보드를 열지 않으며 설정창이 popoverPresented를 바꾸지 않습니다. 표시·그래프·갱신·로그인·복원의 현재값·진행·오류·필요 동작을 native 컨트롤·문장으로 제공합니다. 승인 대기의 시스템 설정·등록 해제 경로가 있고 개발 저장 키·generation·축 식별자는 노출하지 않습니다.
    - 확인: 주입 로그인 adapter의 창/UI 검증으로 Release 우클릭·⌘,·닫힘/전체 숨김·단일창 재사용·복구를 확인합니다. 모든 컨트롤·현재값·오류 뒤 동작·다시 확인·복원을 키보드·AX로 조작합니다. `ResourceRunnerTests/StatusBarControllerTests.swift`, `ResourceRunnerUITests/StatusItemAccessibilityUITests.swift`의 좌클릭/transient/설명을 대조하고 key 설정창 포커스 보호를 확인합니다. 실제 native mutation은 task-011로 분리합니다.
  - 참조: SPEC §5.1, §5.2, §5.3, §5.4, §5.5, §5.9, §5.11, §5.12, §5.13; DESIGN §1.3, §1.4, §2.6, §3.1, §3.2, §3.3, §3.5, §4.2, §5 DP1, DP2, DP7, DP8.

- [ ] task-010: 설정 통합 동작과 기본 구성 회귀
  - 목적: 실제 앱에서 같은 설정 계약을 사용하고 기본 수집·표시 의미·배포 제약을 유지하는지 판정합니다.
  - 접근: 선행 task-001~task-009. 출발점은 `ResourceRunner/ApplicationCoordinator.swift`, `ResourceRunner/CollectionPipelines.swift`, `ResourceRunner/DashboardView.swift`, `ResourceRunner/CollectionDeliveryStore.swift`, `ResourceRunnerTests/IntegratedDashboardSummaryTests.swift`, `ResourceRunnerUITests/OneSessionMonitoringIntegrationUITests.swift`입니다. 선행 근거를 연결하고 새 통합 검증은 시작·재실행·연속 변경·복원·창/포커스 등 경계 간 동작에 한정합니다. mock·격리 adapter로 실제 로그인 등록·로그아웃 없이 판정합니다.
  - 검증 조건:
    - 결과: 저장 설정의 첫 화면/일정·즉시 변경·전체 숨김 복구·그래프 재확대·복원 결과 분리가 일치합니다. 기본 CPU/Memory 계산·메뉴바·TOP 5/상세·Network 물리/부분 합계/보조·Disk 물리/볼륨 관계/현재값/상세를 유지합니다. 수집 영속화·외부 전송·추가 Helper/package/entitlement가 없고 arm64/macOS26.5/Sandbox/LSUIElement를 유지합니다.
    - 확인: 관련 단위·렌더·UI와 Debug/Release 빌드를 확인하고 실제 앱의 변경→재실행 첫 화면/일정→복원을 관찰합니다. 저장 payload·이력 초기화·profile apply 횟수·Release 접근·16개 카드/두 TOP 5 조합 근거, 기존 수집·summary/detail·AX를 대조합니다. 필수 미확인 항목은 이유를 적고 승인하지 않습니다. 다음 로그인·M3 보류를 완료 처리하지 않습니다.
  - 참조: SPEC §5.1~§5.9, §5.11, §5.12, §5.13; DESIGN §1.1~§1.4, §2.1~§2.6, §3.1~§3.5, §4.1, §4.2, §5 DP1~DP8.

- [ ] task-011: 실제 mainApp 등록·해제와 다음 로그인 실행
  - 목적: 실제 macOS에서 로그인 상태·다음 로그인 자동 실행을 관찰해 native 계약을 최종 판정합니다.
  - 접근: 선행 task-010. 출발점은 구현된 `LoginItemService`·`LoginItemController`, `ResourceRunner/AppDelegate.swift`, `ResourceRunner/ApplicationCoordinator.swift`, 빌드 설정·entitlement 원본입니다. main이 당시 운영 접근·사용자 승인 범위를 확인하고 같은 bundle identifier·서명·entitlement의 앱을 안정된 경로에서 실제 adapter로 관찰합니다. 등록 bundle을 다른 빌드/경로로 바꾸지 않습니다. 로그아웃·재부팅 등 세션 영향은 그 시점의 별도 승인 범위 안에서만 진행합니다.
  - 검증 조건:
    - 결과: 초기 읽기는 OS 상태를 바꾸지 않고 등록·해제·복원이 status/macOS 항목과 일치합니다. 등록·허용 후 다음 로그인에서 메인 앱이 자동 실행되고 창·대시보드를 자동으로 열지 않습니다. OS 철회/변경·승인 대기·확인 불가·실패는 성공 표시하지 않습니다. 해제/복원 뒤 실제 해제와 현재 앱의 계속 실행을 확인합니다.
    - 확인: 대상 macOS·arm64·Sandbox·LSUIElement·번들/실행 파일·서명·Helper/package 없음, 초기 status/mutation 없음, native 결과·macOS 항목, 승인/철회 후 재확인·UI/AX·필요 동작을 기록합니다. 다음 로그인의 실행 시각·bundle 경로로 수동 실행·이전 창 복원과 구분합니다. 해제·복원과 일반/로그인 결과 분리도 확인합니다. mock·status·수동 실행만으로 승인하지 않습니다. 필수 환경·권한·증거가 없으면 이유·SPEC 영향을 반환하고 미승인으로 남깁니다.
  - 참조: SPEC §5.9, §5.10, §5.11, §5.12, §5.13; DESIGN §1.3, §2.6, §3.5, §4.1, §4.3, §5 DP1, DP2, DP8.

## 완료 조건 매핑

| SPEC | Task |
| --- | --- |
| §5.1 설정 접근·전체 숨김 복구 | task-007, task-009, task-010 |
| §5.2 카드·상세 정리·기본 배치 | task-005, task-007, task-008, task-009, task-010 |
| §5.3 TOP 5·대표값/상세 보존 | task-007, task-009, task-010 |
| §5.4 CPU·Disk1/5/10분 | task-005, task-006, task-009, task-010 |
| §5.5 프로필·생명주기 | task-002, task-003, task-005, task-009, task-010 |
| §5.6 일정·단일 실행·차분/단절 | task-002, task-003, task-005, task-010 |
| §5.7 저장·최초 적용·제한 이력 | task-001, task-003, task-005, task-006, task-010 |
| §5.8 잘못된 저장값 | task-001, task-005, task-010 |
| §5.9 기본값 복원·로그인 결과 | task-001, task-004, task-009, task-010, task-011 |
| §5.10 실제 mainApp 로그인 실행 | task-004, task-011 |
| §5.11 실제 상태·실패/승인 | task-004, task-005, task-009, task-010, task-011 |
| §5.12 키보드·AX·단축키/복귀 | task-007, task-008, task-009, task-010, task-011 |
| §5.13 기존 의미·개인정보·배포 | task-001~task-011 |

DP1은 task-001/004/005/009/011, DP2는 task-008/009/011,
DP3·DP4는 task-002, DP5는 task-002/003/006, DP6는 task-003/006,
DP7은 task-007/008/009, DP8은 task-004/009/011과 통합 task-010에서 확인합니다.

모든 매핑 Task가 현재 기준으로 승인되기 전에는 IMPLEMENT를 완료로 표시하지 않습니다.
문서 적용·최종 승인·상태·이력 갱신은 main이 수행합니다.
