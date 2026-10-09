# 사용자 설정과 로그인 시 실행 구현

## 기준과 경계

승인된 [SPEC](./spec.md) §5.1~§5.13과 [DESIGN](./design.md)을 구현합니다.
조사 기준은 `main`, HEAD `3f8f0758458fd78c846a10da805675dc2c6067ba`입니다.
analyzer의 읽기 전용 후보를 main이 선행 문서·현재 원본·기존 검증 파일에 대조해 적용했습니다.
Task는 문서 순서로 진행하며 각 항목의 선행 Task가 승인된 뒤 착수합니다.
경로는 프로젝트 루트 기준이며 새 파일명은 DESIGN의 책임 후보입니다.
같은 책임 경계를 유지하는 파일 분리는 구현 재량입니다.

각 Task는 원본·diff·검증 방법·관찰 결과·미확인 범위를 근거로 한 번의 verify에서 판정할 수 있는 결과 단위입니다.
각 Task의 승인 근거와 최근 reject는 구현·검증 단계에서 관리합니다.
검증은 각 Task의 결과를 판정하는 단위·렌더·UI 근거로 구성합니다.

구현 계획 작성 단계에서는 제품 구현·로그인 등록/해제·로그아웃·재부팅을 수행하지 않았습니다.
2026-10-03 사용자 `$implement-loop M4` 요청으로 아래 Task의 순차 구현·검증을 시작합니다.
마지막 실제 로그인 관문은 향후 main이 환경·운영 접근 권한·사용자 승인 범위를 확인해 조정합니다.
필수 관문을 실행할 권한·환경이 없으면 관련 Task를 승인하지 않습니다.
M3 task014/015 보류와 기존 승인은 유지하며 해당 관문을 재개하거나 완료 처리하지 않습니다.

## 체크리스트

2026-10-09 확장: 승인 SPEC §5.14~16·DESIGN DP10~13을 task012~016으로 구현합니다. main이 analyzer의5개 후보를 채택했습니다. 기존001~011 승인·기본값·과거 근거는 유지하며 새 선택의 완료 근거로 확대하지 않습니다. 순서대로 선행 승인을 확인합니다. worker는 공유 파일의 해당 책임 구역만 수정하고 다른 미커밋을 되돌리지 않습니다. 문서 승인·상태는 main 소유, 추가 사용자 결정은 없습니다.

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

- [x] task-003: 당시 주기의 차분·단절과 제한된10분 이력
  - 목적: 긴 정상 주기도 실제 경과 시간으로 계산하고 빠름의10분 이력을 제한된 메모리에 보존합니다.
  - 접근: 선행 task-002. 출발점은 `ResourceRunner/CPUSystemMetricsCollector.swift`, `ResourceRunner/SystemMetricsSampleSource.swift`, `ResourceRunner/NetworkActivity.swift`, `ResourceRunner/DiskActivity.swift`, `ResourceRunner/MonitoringSampleStore.swift`, `ResourceRunner/ProcessHistoryStore.swift`입니다. CPU 측정별 허용 간격과 Network·Disk 차분에 `G(P)=max(10초,2×P)`를 전달하고 candidate 상태는 현재 admission에서만 commit합니다. 시스템·Network·Disk 링은 각각1203개로 고정하며 실제600초 선별을 유지합니다. CPU·Disk 점에 당시 G·기존 연속성을 보존합니다. 표시 범위는 task-006이 소유합니다.
  - 검증 조건:
    - 결과: P≤5초는 G=10초, P=10초는 G=20초이며 분모는 실제 시각 차이입니다. 0 이하·G 초과는 기준점 전용입니다. epoch·실패·topology/identity·카운터 감소의 단절·Collector별 실패 격리를 유지합니다. 프로필 변경만으로 정상 기준점을 지우거나 과거 P를 재해석하지 않습니다. 링은 주기·표시 범위에 따라 축소하지 않습니다. 프로세스 최대20초·Memory600초 창/30초 최소 간격/21개 링은 유지합니다.
    - 확인: `ResourceRunnerTests/SystemMetricsCollectorTests.swift`, `SystemMetricsSampleSourceTests.swift`, `NetworkActivityTests.swift`, `DiskActivityTests.swift`, `MonitoringSampleStoreTests.swift`, `ProcessHistoryStoreTests.swift`에서 정상 지연·정확한 G 경계·초과·강제 단절·늦은 candidate 거부를 확인합니다. 0.5초의600초 양 끝점,1203개 상한·overflow·주기 변경·native 지연·긴 중지·실패, 보간/가짜0/과거 채움 없음과 기존 Memory·프로세스 계산 결과를 검증합니다.
  - 참조: SPEC §5.5, §5.6, §5.7, §5.13; DESIGN §2.4, §2.5, §3.4, §4.1, §4.2, §5 DP5, DP6.
  - 승인 근거: 2026-10-03 독립 verifier approved를 main이 확정했습니다. HEAD429906e 기준11파일 diff·소스/로그 해시 대응과 관련86case(동적94실행)·Memory6case(동적17실행), 실패/skip0을 확인했습니다. [task-003 근거](./evidence/task-003/README.md). 구현 재시도0·근거 재검증0; 이번에 완료되는 SPEC 전체 조건은 없습니다.

- [x] task-004: 실제 로그인 상태와 직렬 요청·복원 결과
  - 목적: 일반 설정과 독립된 macOS 로그인 상태를 관리하고 명시적 요청·복원 결과를 구분합니다.
  - 접근: 선행 task-001. 새 `LoginItemService` adapter·`LoginItemController`를 구성합니다. 출발점은 `ResourceRunner/AppDelegate.swift`, `ResourceRunner/ApplicationCoordinator.swift`이며 일반 복원은 task-001 store를 사용합니다. native 경계는 `SMAppService.mainApp.status`, 명시적 register/unregister, 사용자 버튼의 `openSystemSettingsLoginItems()`입니다. mutation 하나·operation ID·새 의도 직렬화를 유지합니다. 완료/실패 뒤 재조회 상태와 요청 결과를 분리합니다. 시작·활성화는 task-005, UI는 task-009, 실제 OS는 task-011이 소유합니다.
  - 검증 조건:
    - 결과: enabled만 켜기 성공이며 승인 대기·notFound·알 수 없는 상태·throw는 성공으로 추정하지 않습니다. 조회는 mutation·시스템 설정 열기를 실행하지 않습니다. 일반 복원과 로그인 해제 결과를 분리하며 notRegistered는 불필요한 unregister가 없습니다. 로그인 실패로 일반 복원을 취소하지 않습니다.
    - 확인: 주입 adapter로 모든 상태·등록/해제 실패·승인 대기·OS 변경·중복 요청·복원 경합·늦은 결과를 확인합니다. 초기 mutation0회·재조회 순서·최대 mutation1회·stale 결과 거부·일반 복원 한 번과 결과 분리를 검증합니다. mainApp 외 서비스·자동 시스템 설정 열기·저장된 로그인 의도가 없는지 원본을 대조합니다. mock은 실제 다음 로그인 근거를 대체하지 않습니다.
  - 참조: SPEC §5.9, §5.10, §5.11, §5.13; DESIGN §1.1, §1.2, §2.6, §3.5, §4.1, §4.3, §5 DP1, DP8.
  - 승인 근거: 2026-10-03 독립 verifier approved를 main이 확정했습니다. HEADccb1bf8 기준 새3파일 patch/blob·소스 해시와 signed 주입7/7·실패/skip0을 확인했습니다. [task-004 근거](./evidence/task-004/README.md). 구현 재시도0·근거 재검증0; 실제 OS mutation은 수행하지 않았고 이번에 완료되는 SPEC 전체 조건은 없습니다.

- [x] task-005: 첫 화면·최초 일정과 즉시 변경의 단일 배선
  - 목적: 처음부터 같은 저장 설정을 사용하고 늦은 수집·설정 전달이 현재 선택을 되돌리지 않게 합니다.
  - 접근: 선행 task-001~task-004. 출발점은 `ResourceRunner/AppDelegate.swift`, `ResourceRunner/ApplicationCoordinator.swift`, `ResourceRunner/CollectionPipelines.swift`, `ResourceRunner/DashboardPresentationStore.swift`, `ResourceRunner/CollectionDeliveryStore.swift`, `ResourceRunner/DashboardPresentation.swift`, `ResourceRunner/ResourceActivityPresentation.swift`입니다. 일반 검증→로그인 실제 조회→같은 snapshot의 Dashboard/pipeline→admission/source/store/소비 연결→최초 lifecycle 일정 순서입니다. 표시 경계에 현재 snapshot/revision을 전달합니다. 기존 카드 모델이 전체600초 이력·상세를 보유하므로 모델은 유지하고 guarded 현재 snapshot을 게시하며 후속 view006/007이 현재 선택으로 선별합니다. profile만 lifecycle에 전달하며 샘플 반영은 현재 설정을 사용합니다.
  - 검증 조건:
    - 결과: 기본값으로 잠깐 시작했다가 바꾸지 않으며 저장 프로필이 최초 일정부터 적용됩니다. 설정·표시·수집의 원본이 같습니다. 화면 설정은 수집·메뉴바·순위/상세 계산을 바꾸지 않고 그래프 선택은 Memory 계산 창을 바꾸지 않습니다. 초기 읽기·재실행·활성화 재확인으로 로그인 상태를 바꾸지 않습니다.
    - 확인: `ResourceRunnerTests/ApplicationCoordinatorTests.swift`, `CollectionPipelinesTests.swift`, `CollectionAdmissionTests.swift`, `DashboardPresentationTests.swift`, `ResourceActivityPresentationTests.swift`에서 저장 snapshot을 주입해 첫 구성·첫 apply·초기 source를 관찰합니다. 연속/역순 전달·대기 sample/display·실패/중지 last-known에서 현재 revision·최종 프로필·표시 선택을 확인합니다. 재실행 시 설정은 복원되고 수집 이력·프로세스/장치 목록은 빈 메모리로 시작하는지 확인합니다.
  - 참조: SPEC §5.2, §5.4, §5.5, §5.6, §5.7, §5.8, §5.11, §5.13; DESIGN §1.1, §1.4, §2.1, §2.3, §2.5, §2.6, §4.1, §4.2.
  - 승인 근거: 2026-10-03 독립 verifier approved를 main이 확정했습니다. HEADd119c73 기준8파일 diff·소스 해시와 signed 관련42case·실패/skip0을 확인했습니다. [task-005 근거](./evidence/task-005/README.md). 기존 전체 모델을 유지하고 현재 snapshot으로 표시를 선별하는 내부 접근 차이를 반영했습니다. 구현 재시도0·근거 재검증0; 이번에 완료되는 SPEC 전체 조건은 없습니다.

- [x] task-006: CPU·Disk의 공통1/5/10분 표시 범위
  - 목적: 최대 이력을 유지하고 CPU·Disk 구간·축·진행·AX를 선택 범위에 즉시 일치시킵니다.
  - 접근: 선행 task-003, task-005. 출발점은 `ResourceRunner/DashboardPresentation.swift`, `ResourceRunner/DashboardView.swift`, `ResourceRunner/ResourceRateGraph.swift`, `ResourceRunner/ResourceRateGraphView.swift`, `ResourceRunner/ResourceActivityPresentation.swift`, `ResourceRunner/DiskDashboardView.swift`입니다. 같은 `GraphTimeRange`를 CPU HistoryGraphView/HistoryGraphTimeAxis/normalizedXPosition과 Disk 모델·렌더·안내에 전달합니다. 현재 시각의 선택 범위만 선별하고 뒤쪽 점의 당시 G·epoch·연속성으로 연결합니다.
  - 검증 조건:
    - 결과: 60/300/600초 창·왼쪽1/5/10분 전·오른쪽 지금·분모01:00/05:00/10:00·표시 안내·상세·AX가 일치합니다. 재수집 없이 변경하며 없는 과거·중지 공백을 채우지 않습니다. CPU 밴드·기준선·극값, Disk Read 점선/Write 실선·42pt 미니 그래프·가시 peak/nice upper bound를 유지합니다. Network/Memory 그래프나 제거된 Disk 큰 안내는 추가하지 않습니다.
    - 확인: `ResourceRunnerTests/DashboardPresentationTests.swift`, `ResourceRateGraphTests.swift`, `ResourceRateGraphRenderingTests.swift`, `DiskDashboardViewTests.swift`에서 빈/부분/충분/실패/중지,1→5→10·10→1→10, 서로 다른 당시 G·강제 단절·창 밖 극값·downsampling을 확인합니다. 같은 원본의 Memory Swap·증가 순위 결과와600초 이름이 범위에 따라 바뀌지 않는지 검증합니다.
  - 참조: SPEC §5.4, §5.7, §5.13; DESIGN §1.4, §2.4, §2.5, §3.4, §4.2, §5 DP5, DP6.
  - 승인 근거: 2026-10-03 독립 읽기 전용 verifier approved를 main이 확정했습니다. HEAD8345f58 기준9파일 diff·소스 해시와 최종 signed serial86case(동적90실행)·실패/skip0을 확인했습니다. [task-006 근거](./evidence/task-006/README.md). agent thread 제한으로 동일 verifier 역할을 로컬 CLI에 적용했습니다. 구현 재시도0·근거 재검증0; 이번에 완료되는 SPEC 전체 조건은 없습니다.

- [x] task-007: 카드·TOP 5 숨김과 자연 높이·선택 정리
  - 목적: 숨긴 구역을 layout·AX에서 제거하고 대표값·상세·기본 배치·전체 숨김 복구를 유지합니다.
  - 접근: 선행 task-005, task-006. 출발점은 `ResourceRunner/DashboardView.swift`, `ResourceRunner/DashboardPresentationStore.swift`, `ResourceRunner/DashboardPresentation.swift`, `ResourceRunner/ResourceActivityPresentation.swift`입니다. 고정 순서의 켜진 카드만 eager 한 열에 구성합니다. TOP 5 제목·행·자리표시·실패 안내 전체를 제거합니다. 선택 카드 제거 전에 none·generation 전진을 적용하고 숨긴 상세 진입을 막습니다. 전체 숨김은 설명·공통 설정 callback만 표시합니다. 창은 task-009, 포커스·viewport는 task-008이 소유합니다.
  - 검증 조건:
    - 결과: 네 카드·두 TOP 5가 독립 즉시 반영되며 다른 저장 선택을 바꾸지 않습니다. 예약 frame·최소 높이·빈 순위 공간·본체 ScrollView·기본 footer가 없습니다. CPU 대표값/User/System/그래프·Memory 구성/Pressure/Swap·상세 목록을 유지합니다. 숨긴 AX·선택을 제거하고 늦은 닫힘은 새 선택을 지우지 않습니다. 기본 글꼴·Memory 자연 높이·TOP 5 여백·네 카드 배치를 유지합니다.
    - 확인: `ResourceRunnerTests/IntegratedDashboardSummaryTests.swift`, `DashboardPresentationTests.swift`와 `ResourceRunnerUITests/DashboardCPUCardUITests.swift`, `DashboardMemoryCardUITests.swift`, `DashboardCardSelectionUITests.swift`로16개 카드 조합·두 TOP 5 각각의 on/off 조합을 확인합니다. 열린 상세 숨김·빠른 재표시·늦은 닫힘·전체 숨김의 frame/AX/selection을 관찰하고 기존 기본 수치·글꼴·무스크롤 근거와 대조합니다.
  - 참조: SPEC §5.1, §5.2, §5.3, §5.12, §5.13; DESIGN §1.2, §1.4, §2.1, §3.2, §4.2, §5 DP7.
  - 승인 근거: 2026-10-04 독립 verifier approved를 main이 확정했습니다. HEADcac4ca9 기준10파일 해시/patch 대응, 최종 signed UI2/2·단위40/40/6suite·64렌더 조합·실패/skip0. 전체 숨김 부모 AX 식별자 전파를 수정하고 실제 버튼/높이/카드 AX 부재·상세 숨김/재표시를 확인했습니다. [재개/승인 근거](./evidence/task-007/resume-20261004/README.md). UI correctness 보완1회·근거 재검증0; 이전 환경 차단/실패 이력은 보존합니다. task-008~011 미착수, 이번에 완료되는 SPEC 전체 조건은 없습니다.

- [x] task-008: 표시 조합의 포커스·단축키·현재 앵커
  - 목적: 제거 뒤 키보드 복귀와 마지막 표시 카드의 상세 공간을 안정적으로 유지합니다.
  - 접근: 선행 task-007. 출발점은 `ResourceRunner/DashboardView.swift`, `ResourceRunner/DashboardViewport.swift`, `ResourceRunner/StatusBarController.swift`, `ResourceRunner/DashboardPresentationStore.swift`입니다. ⌘1~⌘4 대응을 고정하고 숨긴 카드는 무동작으로 둡니다. 원래 카드→남은 첫 카드→전체 숨김 설정 버튼 순서로 유효 포커스에 복귀합니다. 지연 동작은 generation·표시 revision·현재 대상·key 설정창을 확인합니다. 앵커는 마지막 카드 identity/revision과 Memory 실제 위치·TOP 5 변경 높이를 반영합니다.
  - 검증 조건:
    - 결과: stale 포커스·측정·제거가 새 화면을 덮지 않고 숨긴 Memory·이전 Disk weak view를 쓰지 않습니다. 기본 Disk 앵커·Memory 보정을 보존합니다. 조합 변경 후 본체·앵커·chrome를 재측정하고8pt 여유·최대400×480pt·frame 보정을 유지합니다. 앵커 없음은 상세를 닫고 기존 화면 기본 크기를 유지합니다. 본체 축소로 상세 공간을 만들지 않으며 상세 스크롤·Escape·Page Up/Down을 유지합니다.
    - 확인: `ResourceRunnerTests/DashboardViewportTests.swift`와 `ResourceRunnerUITests/DashboardDetailPopoverUITests.swift`, `DashboardDetailExpansionUITests.swift`, `DashboardCardSelectionUITests.swift`로 마지막 카드·Memory의 마지막/위쪽/숨김·TOP 5 변경·stale 등록/제거를 확인합니다. 실제 화면 하단 상세·긴 Memory·chrome·단축키·포커스 복귀를 관찰합니다. key 설정창 보호의 최종 실행 근거는 task-009의 창과 함께 확인합니다.
  - 참조: SPEC §5.2, §5.12, §5.13; DESIGN §1.3, §3.2, §3.3, §4.2, §5 DP2, DP7.
  - 승인 근거: 2026-10-04 독립 verifier approved를 main이 확정했습니다. HEADb8a8397 기준7파일 SHA/patch 대응, signed 단위46/46·6suite·UI17/17·실패/skip0과4조합 실제frame를 확인했습니다. 현재 마지막 앵커·Memory 보정·stale 복귀 거부·Return/Space와 기본 본체/상세 회귀를 통과했습니다. [task-008 근거](./evidence/task-008/README.md). 구현 재시도0·근거 재검증0; key 설정창 최종UI는009이며 신규 SPEC 전체 완료 없음.

- [x] task-009: 단일 설정창과 접근·키보드·AX
  - 목적: Release 메뉴바에서 모든 설정·실제 로그인 상태·복원 결과를 조작하는 제품 화면을 완성합니다.
  - 접근: 선행 task-004~task-008. 출발점은 `ResourceRunner/ResourceRunnerApp.swift`, `ResourceRunner/AppDelegate.swift`, `ResourceRunner/ApplicationCoordinator.swift`, `ResourceRunner/StatusBarController.swift`, `ResourceRunner/DashboardView.swift`입니다. `PreferencesView`·단일 `SettingsWindowController`를 구성해 모든 접근을 coordinator.openSettings()로 연결합니다. Release 우클릭·앱 명령/⌘,·전체 숨김 버튼·EmptyView 중복 경로 정리, 시작·창 열기/재활성화·앱 재활성화 후 설정 확인·다시 확인·요청 완료/실패 재조회를 연결합니다.
  - 검증 조건:
    - 결과: 창을 재사용하고 명시적 열기만 활성화합니다. 앱/로그인 시작으로 창·대시보드를 열지 않으며 설정창이 popoverPresented를 바꾸지 않습니다. 표시·그래프·갱신·로그인·복원의 현재값·진행·오류·필요 동작을 native 컨트롤·문장으로 제공합니다. 승인 대기의 시스템 설정·등록 해제 경로가 있고 개발 저장 키·generation·축 식별자는 노출하지 않습니다.
    - 확인: 주입 로그인 adapter의 창/UI 검증으로 Release 우클릭·⌘,·닫힘/전체 숨김·단일창 재사용·복구를 확인합니다. 모든 컨트롤·현재값·오류 뒤 동작·다시 확인·복원을 키보드·AX로 조작합니다. `ResourceRunnerTests/StatusBarControllerTests.swift`, `ResourceRunnerUITests/StatusItemAccessibilityUITests.swift`의 좌클릭/transient/설명을 대조하고 key 설정창 포커스 보호를 확인합니다. 실제 native mutation은 task-011로 분리합니다.
  - 참조: SPEC §5.1, §5.2, §5.3, §5.4, §5.5, §5.9, §5.11, §5.12, §5.13; DESIGN §1.3, §1.4, §2.6, §3.1, §3.2, §3.3, §3.5, §4.2, §5 DP1, DP2, DP7, DP8.
  - 승인 근거: 2026-10-04 main이 독립 verifier approved 후보를 최종 확정했습니다. HEADdf90292 기준9파일 SHA/patch 현재 대응, 기존 signed 단위46/46·Debug UI18/18·격리 Release UI1/1·실패/skip0와 최종 Release build를 확인했습니다. 단일창·접근·설정·복원·키보드/AX·key 설정창 보호를 승인하며 실제 native mutation/다음로그인은011에 남깁니다. [task-009 근거](./evidence/task-009/README.md). 구현 재시도0·근거 재검증0; 테스트 재실행 없음·신규 SPEC 전체 완료 없음.

- [x] task-010: 설정 통합 동작과 기본 구성 회귀
  - 목적: 실제 앱에서 같은 설정 계약을 사용하고 기본 수집·표시 의미·배포 제약을 유지하는지 판정합니다.
  - 접근: 선행 task-001~task-009. 출발점은 `ResourceRunner/ApplicationCoordinator.swift`, `ResourceRunner/CollectionPipelines.swift`, `ResourceRunner/DashboardView.swift`, `ResourceRunner/CollectionDeliveryStore.swift`, `ResourceRunnerTests/IntegratedDashboardSummaryTests.swift`, `ResourceRunnerUITests/OneSessionMonitoringIntegrationUITests.swift`입니다. 선행 근거를 연결하고 새 통합 검증은 시작·재실행·연속 변경·복원·창/포커스 등 경계 간 동작에 한정합니다. mock·격리 adapter로 실제 로그인 등록·로그아웃 없이 판정합니다.
  - 검증 조건:
    - Disk 현재 기준: 별도 Per-Request의 DESIGN §3.6 [승인 근거](./evidence/disk-capacity-20261004/README.md)를 인수해1000 기반 저장 공간·important-usage available·상세/AX 정의·미확보 실패·privacy manifest 번들 포함·Sandbox 접근을 확인합니다. 원시값의 대상/시각·반올림과 Read/Write·누적량·Network·Memory 단위 불변을 대조합니다. 기존 raw available/1024 용량 근거는 새 정의의 성공으로 사용하지 않습니다.
    - 결과: 저장 설정의 첫 화면/일정·즉시 변경·전체 숨김 복구·그래프 재확대·복원 결과 분리가 일치합니다. 기본 CPU/Memory 계산·메뉴바·TOP 5/상세·Network 물리/부분 합계/보조·Disk 물리/볼륨 관계/현재값/상세를 유지합니다. 수집 영속화·외부 전송·추가 Helper/package/entitlement가 없고 arm64/macOS26.5/Sandbox/LSUIElement를 유지합니다.
    - 확인: 관련 단위·렌더·UI와 Debug/Release 빌드를 확인하고 실제 앱의 변경→재실행 첫 화면/일정→복원을 관찰합니다. 저장 payload·이력 초기화·profile apply 횟수·Release 접근·16개 카드/두 TOP 5 조합 근거, 기존 수집·summary/detail·AX를 대조합니다. 필수 미확인 항목은 이유를 적고 승인하지 않습니다. 다음 로그인·M3 보류를 완료 처리하지 않습니다.
  - 참조: SPEC §5.1~§5.9, §5.11, §5.12, §5.13; DESIGN §1.1~§1.4, §2.1~§2.6, §3.1~§3.6, §4.1, §4.2, §5 DP1~DP9.

  - 승인 근거: 2026-10-09 독립 verifier의 재판정 approved를 main이 최종 확정했습니다. HEAD5435c7d와 제품/테스트3파일·상위문서2파일 미커밋 patch·24소스 SHA 대응, signed 관련 단위24/24·실제 UI1/1·Release build를 확인했습니다. 실제 UI 재실행 PID2447→2728→2967의 첫 scheduler apply·초기 lifecycle·DEBUG dylib UUID/SHA를 대조해 저장 매우 절전10초와 복원 후 기본2초/process5초를 확인했습니다. 기존64렌더조합·포커스·Release접근·Disk 승인 근거를 인수했으며 SPEC §5.1~§5.8이 성립합니다. [task-010 근거](./evidence/task-010/README.md). 최초 evidence reject는 이력으로 보존하고 현재 reject에서 제거합니다. 구현 재시도0·근거 재검증1; 보완 중 suite 재실행·native 로그인 mutation 없음. task-011·M3 취소6개/보류 관문·IMPLEMENT 전체는 미완료입니다.

- [x] task-011: 실제 mainApp 등록·해제와 다음 로그인 실행
  - 승인 근거: 2026-10-09 독립 verifier의 재판정 approved를 main이 확정했습니다. native UI5/5·실패/skip0과 현재9파일 SHA/고정 Release 서명 대응, 사용자 별도 승인 후 실제 다음 로그인 근거를 대조했습니다. 새 console 로그인10:31과 loginwindow의10:31:02.665 performAutolaunch, 같은 경로의 PID64258/시작 시각이 일치합니다. 비활성 읽기 전용 AX창0·화면 표시창0과 사용자 메뉴바만 표시 관찰로 창·대시보드 비자동 열림을 확인했습니다. SPEC §5.9~§5.13 성립, 모든11개Task 승인으로 IMPLEMENT 완료입니다. [실제 검증 근거](./evidence/task-011/README.md). 구현 재시도0·근거 재검증1, 최초 evidence reject는 이력으로 보존하고 현재 reject에서 제거합니다. suite 재실행·제품 코드 변경 없음.
  - 목적: 실제 macOS에서 로그인 상태·다음 로그인 자동 실행을 관찰해 native 계약을 최종 판정합니다.
  - 접근: 선행 task-010. 출발점은 구현된 `LoginItemService`·`LoginItemController`, `ResourceRunner/AppDelegate.swift`, `ResourceRunner/ApplicationCoordinator.swift`, 빌드 설정·entitlement 원본입니다. main이 당시 운영 접근·사용자 승인 범위를 확인하고 같은 bundle identifier·서명·entitlement의 앱을 안정된 경로에서 실제 adapter로 관찰합니다. 등록 bundle을 다른 빌드/경로로 바꾸지 않습니다. 로그아웃·재부팅 등 세션 영향은 그 시점의 별도 승인 범위 안에서만 진행합니다.
  - 검증 조건:
    - 결과: 초기 읽기는 OS 상태를 바꾸지 않고 등록·해제·복원이 status/macOS 항목과 일치합니다. 등록·허용 후 다음 로그인에서 메인 앱이 자동 실행되고 창·대시보드를 자동으로 열지 않습니다. OS 철회/변경·승인 대기·확인 불가·실패는 성공 표시하지 않습니다. 해제/복원 뒤 실제 해제와 현재 앱의 계속 실행을 확인합니다.
    - 확인: 대상 macOS·arm64·Sandbox·LSUIElement·번들/실행 파일·서명·Helper/package 없음, 초기 status/mutation 없음, native 결과·macOS 항목, 승인/철회 후 재확인·UI/AX·필요 동작을 기록합니다. 다음 로그인의 실행 시각·bundle 경로로 수동 실행·이전 창 복원과 구분합니다. 해제·복원과 일반/로그인 결과 분리도 확인합니다. mock·status·수동 실행만으로 승인하지 않습니다. 필수 환경·권한·증거가 없으면 이유·SPEC 영향을 반환하고 미승인으로 남깁니다.
  - 참조: SPEC §5.9, §5.10, §5.11, §5.12, §5.13; DESIGN §1.3, §2.6, §3.5, §4.1, §4.3, §5 DP1, DP2, DP8.

- [x] task-012: 새 세 설정의 additive 저장·복원
  - 승인 근거(2026-10-09): 독립 verify approved를 main이 확정했습니다. HEAD5435c7d 작업트리의3파일SHA/patch와 signedPreferencesStoreTests10/10·실패/skip0 원본xcresult를대조했습니다. 기존schema1/9키 비기본보존·새3필드개별오류복구·strictBool/enum·10/20/50roundtrip·12키·초기write0·개별변경/복원snapshot/write/callback/revision1회·설정만영속화가충족됐습니다. `evidence/task-012/README.md`. 구현재시도0·근거재검증0, 완료SPEC조건없음. UI/수집/behavior는후속Task입니다.
  - 목적: 기존 설정을 보존하며 시스템 포함·상세 정원·자동 닫기를 유효 snapshot으로 저장·복원합니다.
  - 접근: 선행001/004/011. 소유 `AppPreferences.swift`, `PreferencesStore.swift`, `PreferencesStoreTests.swift`. `includesSystemProcesses=false`, `detailListLimit=twenty`, `automaticallyClosesPopover=true`; enum `ten`/`twenty`/`fifty`에서10/20/50을 유도합니다. preferences.v1/schema1·기존 키/raw value·snapshot/revision 계약을 유지합니다. 로그인·수집·UI 배선은 후속 Task입니다.
  - 검증 조건:
    - 결과: 이전 payload의 새 필드 누락은 새 기본값만 복구하고 기존 비기본 선택을 보존합니다. Bool은 실제 Boolean, 정원은 정확한 enum 문자열만 허용합니다. 필드 오류는 해당 기본값, container/schema 오류는 기존 전체 기본값입니다. 초기 쓰기0, 명시 변경/복원 저장·게시·revision 각1회, 설정만 영속화합니다.
    - 확인: 격리 PreferencesStoreTests에서 이전 비기본 카드/TOP5/그래프/프로필, 각 새 필드 누락·숫자/문자열 Bool·숫자 정원·미지원 문자열·세 정원 round-trip을 검증합니다. 각각 변경/전체 복원의 snapshot·callback·쓰기 횟수와12키/schema1·Bool/enum 타입을 대조합니다. 기존9키 단언을 확장하며 기존 값 보존·fresh store 수집 데이터 부재를 확인합니다.
  - 참조: SPEC §5.7, SPEC §5.8, SPEC §5.9, SPEC §5.13, SPEC §5.14, SPEC §5.15, SPEC §5.16, DESIGN §1.2, DESIGN §2.6, DESIGN §4.2, DESIGN §4.3

- [x] task-013: 읽기 가능한 시스템 항목과 제한 전 두 순위 자료
  - 승인 근거(2026-10-09): main이 독립 verifier의 approved를 확정했습니다. 현재 소유10파일 SHA와 최종patch71a82fe의 원본/격리 대응, 원본24suite92/92·실패/skip0, 동일 소스 격리 전체679/679 및 Release/서명을 확인했습니다. UID별 실제 조회·소속변경 단절·실패범위 구분, 필터 후 두 unbounded 순위·하위 목록, 50그룹·기존3/21링·resolver512, 최신cache/역순/epoch/admission와 메뉴바 독립 진행이 충족됐습니다. [task-013 근거](./evidence/task-013/README.md). 구현 재시도0·근거 재검증0, 이번에 완료되는 SPEC 전체 조건은 없습니다. 설정 UI·즉시 표시 선택은014에서 구현합니다.
  - 목적: 같은 조사에서 제외/포함 정확한 순위·하위 목록을 확보하고 최신 자료만 제한된 메모리에 보관합니다.
  - 접근: 선행012. 소유 `ProcessSurvey.swift`, `ProcessSurveyCollector.swift`, `ProcessHistoryStore.swift`, `ApplicationRanking.swift`, `CollectionDeliveryStore.swift`, coordinator의 consumeProcessRanking 구역 및 해당 테스트. UID 사전 제외를 제거하고 기존 task-info/현재 경로 조회를 적용합니다. 조사 당시 소속을 전달하며 소속 변경은 exec처럼 평활화/기준점을 단절합니다. 독립 소비에서 소속 선별 후 앱 집계/정렬한 두 자료를 만들고20개로 선절단하지 않습니다. 캐시는 최신 자료·시각·실패 상태·epoch·순서를 보관합니다. 후속 표시 전에도 기본 제외/20 의미를 유지합니다.
  - 검증 조건:
    - 결과: 현재 UID의 Apple 경로는 기본에도 유지, 다른 UID의 실제 읽기 성공만 포함합니다. 항목 실패/종료/경로 실패 격리·전체 열거 실패·혼합 소속 그룹의 제외 합계/하위 격리를 유지합니다. CPU/Memory 최대3 평균·조사시각600초/최고령 기준점·30초/21링·PID재사용/exec/종료 제거를 유지합니다. 실패 수와 제외 수를 구별하며 admission/동일epoch순서로 오래된 자료를 거릅니다.
    - 확인: 주입 reader의 UID별 조회·항목/전체 실패, PID재사용/exec/소속 변경·혼합 UID 같은 앱의 두 자료 원시 기대값을 대조합니다. 시스템 상위20+뒤 사용자 자료로 필터 전 절단 오류, 최소50개 그룹·동률/nil·실패 보존·최신한조사·resolver512·3/21링·종료 제거를 확인합니다. 대기계산/역순/새epoch/중지늦은결과와 시스템지표/메뉴바 독립 진행을 검증합니다. source/timer 추가가 없음을 원본으로 대조합니다.
  - 참조: SPEC §5.6, SPEC §5.13, SPEC §5.14, SPEC §5.15, DESIGN §2.3, DESIGN §2.7, DESIGN §3.7, DESIGN §4.3

- [x] task-014: 시스템 포함·상세 정원의 즉시 표시와 두 설정 UI
  - 재승인 근거(2026-10-09): main이 독립 verifier approved를 확정했습니다. 보완2파일 SHA/patch와 signed17/17·실패/skip0 원본xcresult 대응, 정상/실패/중지의 현재 포함 범위·제외/읽기실패 수·TOP5고정/숨김을 확인했습니다. 기존014 조건은 영향 구분해 인수하고 실제AX 최종관문은016에서 이어갑니다. 구현 보완1회·근거재검증0회, 완료SPEC조건 없음.
  - 재개 사유(2026-10-09): task016 실제 AX에서 상세 목록은 포함/TOP50인데 CPU·Memory 카드 AX 설명의 static 기본값이 제외로 고정된 결함을 발견했습니다. 기존 승인 이력을 보존하고 이 범위만 수정·단위 및 실제 AX 재검증합니다. 다른 task014 조건·012/013/015 승인은 유지하며 선행 영향은016에서 대조합니다. main 확정 원인 소유는 DashboardPresentation.swift 및 해당 테스트입니다.
  - 승인 근거(2026-10-09): main이 독립 verifier approved를 확정했습니다. 현재12파일SHA/patch와 원본signed18suite94/94·실패/skip0, 고유bundle UI8/8·최종설정UI1/1, Release/엄격서명 성공을 대조했습니다. 현재snapshot의 cached 즉시선택·공통10/20/50·TOP5/하위보존, 빈/older/newEpoch/중지 상태와 시각·그래프·일정불변, 키보드/AX가 충족됐습니다. 일반조사 동일앱복귀 펼침 기대값은 유지하고 필터/정원에서만 cleanup하도록 보완했습니다. 초기잘못된cwd UI와 Release테스트타깃 직접빌드실패는 승인근거에서 제외한 이력입니다. [task-014 근거](./evidence/task-014/README.md). 구현 재시도0·근거 재검증0, 완료SPEC조건 없음. 자동닫기015·최종실제관문016 진행.
  - 목적: 현재 선택을 사용량/증가량·상세·안내/AX에 즉시 적용하고 TOP5·하위 목록·포커스를 보존합니다.
  - 접근: 선행013. 소유 DashboardPresentation/Store/View, PreferencesView, SettingsWindowController, coordinator 초기/PreferencesPipelineBinding/표시 소비와 해당 단위·SettingsWindow/ProcessList/Expansion UI 테스트. 두 자료를 표시 경계에 보존하고 현재 snapshot으로 자료/정원/AX를 유도합니다. 캐시로 즉시 재표시하고 다음tick/조사/source를 기다리지 않습니다. Toggle·10/20/50 Picker를 단일창에 연결합니다.
  - 검증 조건:
    - 결과: 선별→집계→정렬→펼친순서안정화→정원 적용, CPU/Memory 그룹/증가량 공통10/20/50·TOP5고정5·하위무절단·실제부족수 유지. 안내/AX·10분 증가량 정의 일치, 대표값/원본시각/상태/그래프/창/일정 불변. 사라진 펼친 앱/포커스만 정리하고 남은 목록·상세/복귀 유지, last-known을 최신 성공으로 바꾸지 않습니다.
    - 확인: 두tick 대기 fixture의 포함on/off·10→50→20 즉시성과 source/일정apply 증가0,20밖 사용자/50그룹/혼합UID/동률/nil/부족/펼친안정화·제거를 원시합계/AX에 대조합니다. 늦은조사/역순설정/epoch/중지실패의 현재선택·시각/과거상태 확인. Tab/Space/Return/Picker로 컨트롤·현재값·설명·스크롤에 도달합니다. 단축키·400×480 상세/앵커·본체무스크롤 유지. persistence/전체회귀는016에서 연결합니다.
  - 참조: SPEC §5.3, SPEC §5.6, SPEC §5.7, SPEC §5.9, SPEC §5.12, SPEC §5.13, SPEC §5.14, SPEC §5.15, DESIGN §1.2, DESIGN §2.1, DESIGN §2.7, DESIGN §3.1, DESIGN §3.3, DESIGN §3.7, DESIGN §4.3

- [x] task-015: 본체 자동 닫기·명시적 Escape와 설정 배선
  - 승인 근거(2026-10-09): main이 독립 verifier approved를 확정했습니다. 현재7파일SHA/patch·고유clone 대응과 signed단위41/41(동적47)·실패/skip0, 최종고유UI5/5·기존상세scroll1/1·Release/엄격서명 성공을 대조했습니다. 최초/current behavior·동일값 idempotence·열린identity/선택/delegate0·stalecallback·일정불변, 소유Escape 상세우선/본체명시닫기·nil소비·타창/PageUpDown 비간섭, Toggle실키/AX가 충족됐습니다. 설정창 실제 key/main 보호는 별도 관찰계측과 최종Tab/AX로 확인했고 계측은 최종원본/clone에서 제거했습니다. [task-015 근거](./evidence/task-015/README.md). 구현 재시도0·근거 재검증0, 완료SPEC조건 없음. 실제외부/재실행·복원관문은016에서 진행합니다.
  - 목적: 최초/열린 본체에 자동 닫기를 반영하며 명시적 닫기·상세 복귀·설정창 포커스를 유지합니다.
  - 접근: 선행014. 소유 StatusBarController/PreferencesView, coordinator StatusBar초기/설정전달/keyboardDismiss, 관련 controller/coordinator/SettingsWindow·새팝오버 테스트. 최초/현재snapshot으로 `.transient`/`.applicationDefined`, 소유 로컬키 Escape 상세우선→본체performClose, 단일창 Toggle를 연결합니다.
  - 검증 조건:
    - 결과: 열린behavior만 바꾸고 재생성/강제재개폐/선택제거/syntheticdelegate 없음. 토글/명시닫기 유지, 타앱/설정키 비간섭·key설정/지연포커스 보호. 실제delegate만lifecycle 갱신, 끔에서도 모든화면중지 우선. 상세고정/시간닫기로 확대하지 않습니다.
    - 확인: 최초값/연속변경/복원의behavior·identity·선택·delegate횟수, Escape본체/상세·외부창키·토글·PageUpDown·key설정/늦은callback을 검증합니다. 기존lifecycle근거로 중지/새기준점 대조, 실제Toggle키보드/AX/current 확인. behavior 단위만으로§5.16완료하지않으며 실제외부관문은016입니다.
  - 참조: SPEC §5.5, SPEC §5.6, SPEC §5.7, SPEC §5.9, SPEC §5.12, SPEC §5.13, SPEC §5.16, DESIGN §1.2, DESIGN §1.3, DESIGN §2.1, DESIGN §2.2, DESIGN §3.1, DESIGN §3.3, DESIGN §3.7, DESIGN §4.3

- [x] task-016: 확장 설정의 실제 상호작용·재실행과 기본 회귀
  - 승인 근거(2026-10-09): main이 독립 verifier approved를 확정했습니다. 현재10파일SHA/patch·제품/격리UI 대응과 원본전체단위690/690·실제선택UI21/21·50그룹fixture1/1·고유Release읽기전용1/1, 모두실패/skip0을 확인했습니다. 실제 외부클릭/Finder활성의 켬/끔·열린양방향전환, CPU/Memory사용량·증가량10/20/50과혼합UID하위/합계/경계/50행접근, 실제9→12키payload·재실행/복원/로그인실패분리·기존기본회귀를 충족했습니다. §5.1~5.9·5.11~5.16 성립, §5.10 선행011 승인을 유지하여 적용16개조건/16개Task 모두 완료입니다. [최종 근거](./evidence/task-016/README.md). task016 구현/근거재검증0회, 별도014 AX결함 보완1/근거재검증0회 이력 유지. 실제설치경로 반영은 main이 별도 기록합니다.
  - 목적: 새 세 설정의 실제앱/AX·저장/즉시성/복원과 기존기본동작을 최종판정합니다.
  - 접근: 선행012~015. 소유 관련 SettingsWindow/ProcessList/Expansion/OneSession UI·새팝오버suite, 필요한 AppDelegate/coordinator DEBUG fixture 분기만. 결정적50그룹/혼합UID와 고유suite를 주입하고 mocklogin으로 복원성공/로그인실패를 분리해 실제등록을 변경하지않습니다. native수집과 fixture를 구별합니다. 제품수정은원인Task로반환, 완료후 docs/product.md/design.md 현행설명갱신, 승인/ROADMAP는main소유입니다.
  - 검증 조건:
    - 결과: 포함/제외·10/20/50 사용량/증가량/하위/AX 일치, 기본제외/20. 켬은실제외부클릭/타앱활성닫힘·끔은유지, 열린양방향변경강제닫기/포커스탈취없음. 최초저장값·복원제외/20/켬+기존기본snapshot1회, 일반복원/로그인실패분리. 로그인mutation/수집영속화/Helper/package/entitlement추가없음.
    - 확인: 고유 ResourceRunnerUITest. suite의 이전schema1→새기본·포함/50/끔변경→재실행첫화면/behavior→복원→재실행, 초기창비자동열림·payload/빈이력·AX·login초기mutation0/복원실패분리를 관찰합니다. 실제AppKit 켬/끔 각각외부클릭/타앱활성·열린양방향변경·토글/Escape본체상세/PageUpDown/key설정/늦은포커스와 delegate/lifecycle연결. native읽기가능프로세스/미확보안내확인, root성공추정금지. 50/혼합UID는실제렌더fixtureAX이며native성공주장금지. Debug영향단위/UI·Release빌드/읽기전용설정진입, 기존64표시조합·geometry·CPU/Memory계산/메뉴바/일정/600초·Network/Disk·decimalimportantUsage·로그인분리를현재소스대조. 동일독립근거재사용범위를설명하며 실제관문미확인은승인하지않습니다. M3실기기/M5장기성능을이번승인으로완료하지않습니다.
  - 참조: SPEC §5.1, SPEC §5.2, SPEC §5.3, SPEC §5.4, SPEC §5.5, SPEC §5.6, SPEC §5.7, SPEC §5.8, SPEC §5.9, SPEC §5.11, SPEC §5.12, SPEC §5.13, SPEC §5.14, SPEC §5.15, SPEC §5.16, DESIGN §1.2, DESIGN §2.1, DESIGN §2.6, DESIGN §2.7, DESIGN §3.1, DESIGN §3.3, DESIGN §3.6, DESIGN §3.7, DESIGN §4.2, DESIGN §4.3

### 확장 검증 명령과 근거

cwd 프로젝트루트, 기존scheme/서명 유지, UI직렬. 아래형식의 실제suite명·새Task별경로를 사용하고 실행0/skip/본문전인증실패를통과로계산하지않습니다. 관련새사례/영향회귀를선택하며전체suite를무조건반복하지않습니다.

```sh
xcodebuild test -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -derivedDataPath <새경로> -resultBundlePath <새결과경로> -only-testing:<target/suite> CODE_SIGNING_ALLOWED=YES
xcodebuild build -project ResourceRunner.xcodeproj -scheme ResourceRunner -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath <새Release경로> CODE_SIGNING_ALLOWED=YES
```

012 PreferencesStoreTests;013 ProcessSurveyCollector/ProcessHistoryStore/ApplicationRanking/ApplicationCoordinatorTests;014 DashboardPresentation/PreferencesVisibility/ApplicationCoordinator/RankingTests+SettingsWindow/ProcessList/ExpansionUITests;015 StatusBarController/ApplicationCoordinator/MonitoringLifecycle/DashboardViewportTests+SettingsWindow/새팝오버UI;016 해당영향suite와 OneSessionMonitoringIntegrationUITests를 선택합니다. Release 접근은 SettingsWindowUITests/testReadOnlyStatusMenuSettingsAccess를 Release로선택합니다. 실제외부관문은자동UI 또는같은서명앱 AX/화면 관찰로실동작근거를남깁니다. 로그인변경/로그아웃은안합니다. Task별명령·case/실패/skip·xcresult·diff/SHA·앱/runner서명·DEBUG실제dylib·fixture/native·시각/화면AX·한계를남기며 고유suite/프로세스/창은정리합니다.

## 완료 조건 매핑

| SPEC | Task |
| --- | --- |
| §5.1 설정 접근·전체 숨김 복구 | task-007, task-009, task-010, task-016 |
| §5.2 카드·상세 정리·기본 배치 | task-005, task-007, task-008, task-009, task-010, task-016 |
| §5.3 TOP 5·대표값/상세 보존 | task-007, task-009, task-010, task-014, task-016 |
| §5.4 CPU·Disk1/5/10분 | task-005, task-006, task-009, task-010, task-016 |
| §5.5 프로필·생명주기 | task-002, task-003, task-005, task-009, task-010, task-015, task-016 |
| §5.6 일정·단일 실행·차분/단절 | task-002, task-003, task-005, task-010, task-013, task-014, task-015, task-016 |
| §5.7 저장·최초 적용·제한 이력 | task-001, task-003, task-005, task-006, task-010, task-012, task-014, task-015, task-016 |
| §5.8 잘못된 저장값 | task-001, task-005, task-010, task-012, task-016 |
| §5.9 기본값 복원·로그인 결과 | task-001, task-004, task-009, task-010, task-011, task-012, task-014, task-015, task-016 |
| §5.10 실제 mainApp 로그인 실행 | task-004, task-011 |
| §5.11 실제 상태·실패/승인 | task-004, task-005, task-009, task-010, task-011, task-016 |
| §5.12 키보드·AX·단축키/복귀 | task-007, task-008, task-009, task-010, task-011, task-014, task-015, task-016 |
| §5.13 기존 의미·개인정보·배포 | task-001~task-016 |
| §5.14 시스템 프로세스 포함·집계·의미 보존 | task-012, task-013, task-014, task-016 |
| §5.15 상세10/20/50·TOP5·저장/복원 | task-012, task-013, task-014, task-016 |
| §5.16 자동 닫기·명시적 닫기·포커스·저장/복원 | task-012, task-015, task-016 |

DP10은012/014/015/016, DP11·DP12는013/014/016, DP13은015/016에서 확인했습니다. 2026-10-09 task016 최종 승인으로 기존13조건과 추가3조건의 모든 적용 매핑이 완료되어 전체 IMPLEMENT [x]입니다.

DP1은 task-001/004/005/009/011, DP2는 task-008/009/011,
DP3·DP4는 task-002, DP5는 task-002/003/006, DP6는 task-003/006,
DP7은 task-007/008/009, DP8은 task-004/009/011과 통합 task-010에서 확인합니다.

모든 매핑 Task가 현재 기준으로 승인되기 전에는 IMPLEMENT를 완료로 표시하지 않습니다.
문서 적용·최종 승인·상태·이력 갱신은 main이 수행합니다.
