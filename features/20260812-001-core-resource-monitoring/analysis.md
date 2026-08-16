# CPU·Memory 핵심 리소스 모니터링 분석

## 근거

### 확인 사실

- [spec.md](./spec.md) 전문을 읽었습니다. 승인 전 확인 섹션은 없고 완료 조건 14개가 설계 기준입니다.
  범위는 CPU·Memory 두 카드로 한정되고, 캐릭터 자산·애니메이션, Network·Disk, 그래프 범위 선택,
  사용자 갱신 설정, 설정 영구 저장, 시스템 슬립 복귀 기준점 재설정은 제외 범위입니다.
  다섯 표시 상태의 판정 규칙만은 이 feature가 정합니다.
- spec.md의 `확정한 판단`은 App Sandbox 유지, 논리 코어 합산 CPU 관례, Memory Pressure 3단계,
  실제 시각 기준 그래프, 디스플레이 슬립·빠른 사용자 전환에서의 수집 중지를 이 feature의 전제로 고정합니다.
  또한 `docs/product.md`가 Physical Footprint를 주 지표로 적은 것을 뒤집어 Resident Memory를 주 지표로 삼습니다.
- [docs/design.md](../../docs/design.md)의 `권한과 배포`는 App Sandbox에서 `proc_listallpids`가 차단되고
  `sysctl(KERN_PROC_ALL)`로 대체 가능하며, 아는 PID의 실행 경로·CPU 시간·Resident Memory·uid·시작 시각·부모 PID는
  읽히고 Physical Footprint는 차단됨을 실측 결과로 기록합니다.
  root 소유 프로세스의 CPU 시간과 메모리는 Sandbox와 무관하게 읽을 수 없고 전체 프로세스의 약 40%가 여기 해당합니다.
- 같은 문서의 `수집 일정 > 기본 정책`은 전체 지표를 열림 1초·닫힘 2초, TOP 5를 열림 2초·닫힘 5초로 두고,
  `사용자 갱신 프로필`의 절전은 전체 2초·TOP 5 4초·닫힘 전체 5초입니다.
  `생명주기 반영`은 화면을 볼 수 없는 상태 셋(화면 잠금·디스플레이 슬립·빠른 사용자 전환)과 그 신호를 표로 고정합니다.
- 같은 문서의 `최근 데이터 순환 버퍼`는 버퍼가 개수로만 축출하므로 중지 구간이 있으면 시간 범위를 벗어난 샘플이
  남는다는 M1 관찰(1시간 잠금에서 146개 잔존)을 기록하고, 시간 기준 선별이 별도로 필요하며 그 방식은 이 feature에서
  확정하라고 남깁니다.
- 같은 문서의 `Collector 설계 기준`은 수집 대상 목록과 함께 "상태 경계의 반복 전환을 줄이는 평활화 또는 히스테리시스",
  "최근 2~3개 샘플 평균에 의한 순위 안정화", "프로세스 조사 주기는 시스템 전체 CPU 수집과 분리"를 요구합니다.
  Memory Pressure는 `DispatchSource.makeMemoryPressureSource`와 `kern.memorystatus_vm_pressure_level` 두 경로가
  2026-08-12 macOS 26.5.2 Apple silicon에서 모두 동작함이 확인됐습니다.
- 같은 문서의 `프로세스 식별과 앱 집계`는 식별 후보(PID·시작 시각·실행 경로·번들 식별자·부모 프로세스)를 나열하고
  구체적인 식별 키는 접근 가능성과 비용을 검증한 뒤 확정하라고 남깁니다.
  `미확정 기술 결정`은 앱 단위 식별 키와 집계 예외, 정확성 검증의 비교 도구·허용 오차·반복 횟수를 미확정으로 둡니다.
- [docs/product.md](../../docs/product.md)의 `대시보드 > 공통 정보 구조`는 기본 상태·선택·복귀·실패 격리·데이터 부족·
  레이아웃 안정성을 카드 공통 원칙으로 두고, 중요한 분석 정보를 Hover에만 의존하지 말라고 요구합니다.
  `CPU`·`Memory`는 기본 카드와 상세 정보의 지표 목록, TOP 5 정책, 현재 사용량과 최근 증가량의 구분을 정의합니다.
  `미확정 제품 결정`은 CPU·Memory 상태 임계치와 지속 시간, 시스템 전체 CPU와 프로세스 CPU의 표시 단위를 미확정으로 둡니다.
- [features/20260802-001-menu-bar-foundation/analysis.md](../20260802-001-menu-bar-foundation/analysis.md)의
  DP4·DP5·DP6·DP8·DP9·DP12와 spec.md `확인한 실행 환경 사실`을 읽었습니다.
  M1은 화면 잠금 어댑터 격리, 알림 이름 우선, `unknown`에서의 pause, 접근성 이름 단일 자리, arm64 전용 산출물을 확정했습니다.

M1 산출물 코드를 직접 읽고 확인한 현재 경계입니다.

- [ApplicationCoordinator.swift](../../ResourceRunner/ApplicationCoordinator.swift)가
  `StatusBarController`, `CharacterStateSource`, `SystemLifecycleObserver`,
  `MonitoringSampleStore<PlaceholderMonitoringSample>`, `MonitoringScheduler`, `MonitoringLifecycleStore`를
  각각 한 번씩 만들어 종료까지 보유하고, 표시 흐름과 수집 흐름을 이 타입에서만 만나게 합니다.
  `consume(_:into:)`와 `startMonitoring(_:into:)`가 소비 경로를 별도 정적 메서드로 노출합니다.
- [MonitoringScheduler.swift](../../ResourceRunner/MonitoringScheduler.swift)의
  `MonitoringScheduler<Clock, Source>`는 단일 `Task`와 `generation`만 소유하고,
  `apply(_:)`가 취소 → generation 전진 → `sampleStore.resize(samplingInterval:)` → 새 Task 시작 순서로 동작합니다.
  저장 대상이 `MonitoringSampleStore<Source.Value>` 구체 타입으로 고정돼 있습니다.
  `source.sample()`이 던지면 0 샘플로 바꾸지 않고 다음 실행으로 넘어갑니다.
  현재 production source는 빈 값을 반환하는 `PlaceholderScheduledSampleSource`입니다.
- [MonitoringLifecycle.swift](../../ResourceRunner/MonitoringLifecycle.swift)의
  `CollectionSchedulePolicy.schedule(for:definition:)`는 단일 `CollectionSchedule` 하나만 반환하고,
  `MonitoringLifecycleStore`는 scheduler 하나를 보유하며 결과가 바뀔 때만 `apply(_:)`를 호출합니다.
  `CollectionScheduleDefinition.m1`은 normal 열림 1초·닫힘 2초, lowPower 열림 2초·닫힘 5초입니다.
- [MonitoringSampleStore.swift](../../ResourceRunner/MonitoringSampleStore.swift)의
  `HistoryCapacity.capacity(timeRange:samplingInterval:)`는 `ceil(범위 / 유효 주기)`를 돌려주고,
  `MonitoringSampleStore.resize(samplingInterval:timeRange:)`가 그 용량으로 `CircularBuffer`를 재구성하며
  최신 항목만 보존합니다. 스토어는 `snapshot()` 외에 값을 밖으로 내보내는 경로가 없습니다.
- [SystemLifecycleObserver.swift](../../ResourceRunner/SystemLifecycleObserver.swift)의
  `SystemLifecycleSnapshot`은 `revision`·`lowPowerMode`·`screenLockState` 세 필드이고,
  `SystemLifecycleFieldChange`와 `CombinedSnapshotProducer`가 필드별 병합을 담당해 값이 바뀔 때만 revision을 올립니다.
  잠금 신호 문자열은 `ScreenLockObservationAdapter`와 `ScreenLockStateReader`에만 있습니다.
- [CharacterStateSource.swift](../../ResourceRunner/CharacterStateSource.swift)의
  `CharacterStateSource`는 `initialState`와 이후 변경만 담는 `updates` stream을 제공하고 `send(_:)`로 상태를 받습니다.
  `CharacterPresentation.presenting(_:)`이 다섯 상태를 접근성 이름 하나로 바꾸는 순수 매핑입니다.
  [StatusBarController.swift](../../ResourceRunner/StatusBarController.swift)는 `render(_:)`에서
  접근성 이름만 갱신하고 이미지·길이·팝오버 상태를 건드리지 않습니다.
  팝오버 콘텐츠는 `init`에서 `NSHostingController`로 한 번 만들어져 앱 수명 동안 살아 있습니다.
- [DashboardView.swift](../../ResourceRunner/DashboardView.swift)는 고정 크기 셸 하나이며 카드가 없습니다.

macOS 26.5 SDK 헤더에서 직접 확인한 사실입니다. 이 feature의 Collector가 의존하는 지점입니다.

- `mach/processor_info.h`의 `PROCESSOR_CPU_LOAD_INFO`와 `processor_cpu_load_info`가 코어별 tick을 제공하고,
  `mach/machine.h`가 `CPU_STATE_USER`·`SYSTEM`·`IDLE`·`NICE` 인덱스를 정의합니다.
- `mach/host_info.h`의 `HOST_VM_INFO64`와 `mach/mach_host.h`의 `host_statistics64`가 있으며,
  `vm_statistics64`에 `wire_count`·`compressor_page_count`·`external_page_count`·`internal_page_count`·
  `purgeable_count`가 있습니다. 페이지 크기는 `mach/mach_init.h`의 `host_page_size`로 얻습니다.
- `sys/sysctl.h`의 `VM_SWAPUSAGE`와 `struct xsw_usage`가 Swap 사용량을 제공하고,
  `_stdlib.h`의 `getloadavg`가 Load Average를 제공합니다.
- `sys/sysctl.h`의 `KERN_PROC_ALL`·`KERN_PROC_PID`와 `struct kinfo_proc`이 있고,
  `kinfo_proc`은 `kp_eproc.e_ppid`·`e_ucred.cr_uid`를, `kp_proc`은 `sys/proc.h`의 `extern_proc`으로
  `p_starttime`(`struct timeval`)·`p_flag`·`p_pid`·`p_comm`을 담습니다.
- `sys/proc.h`에 `#define P_TRANSLATED 0x00020000`이 있습니다. Rosetta 실행 여부를 프로세스 열거 결과에서
  추가 호출 없이 읽을 수 있다는 뜻입니다.
- `sys/proc_info.h`의 `proc_taskinfo`가 `pti_resident_size`·`pti_total_user`·`pti_total_system`을,
  `libproc.h`가 `proc_pidpath`를 제공합니다.
- `dispatch/source.h`가 `DISPATCH_MEMORYPRESSURE_NORMAL 0x01`·`WARN 0x02`·`CRITICAL 0x04`를 정의합니다.
  이 저장소의 macOS 26.5.2 Apple silicon에서 `sysctl kern.memorystatus_vm_pressure_level`이 `1`을 반환하는 것을
  직접 확인했으며, 값 집합이 위 dispatch 상수와 같습니다.
- `AppKit/NSWorkspace.h`에 `NSWorkspaceScreensDidSleepNotification`·`ScreensDidWakeNotification`과
  `NSWorkspaceSessionDidResignActiveNotification`·`SessionDidBecomeActiveNotification`이 공개 심볼로 있습니다.
  둘 다 가용 버전 제한이 macOS 26.5보다 낮습니다.

이 저장소의 Debug 빌드를 실행해 직접 확인한 사실입니다.

- macOS의 키보드 탐색(Full Keyboard Access)은 기본이 꺼짐이고,
  이 머신에서 `defaults read NSGlobalDomain AppleKeyboardUIMode`가 `0`을 반환합니다.
  꺼진 상태의 Tab은 텍스트 필드와 목록만 순회하고 일반 버튼에는 닿지 않습니다.
- 그 상태에서 팝오버를 열고 Tab을 눌러 카드에 포커스가 가지 않는 것을 실행 중인 앱에서 확인했습니다.

이 feature의 구현(task-001~010)이 코드로 확인한 사실입니다.

- 일정이 `.paused`가 되면 `MonitoringScheduler`는 실행 중인 Task만 취소하고 새 Task를 만들지 않으므로
  그 구간에는 `source.sample()` 호출이 한 번도 없습니다.
  따라서 `MonitoringSampleStore`의 append도 불리지 않고 표시용 stream에 tick이 하나도 나오지 않으며,
  이를 소비하는 `ApplicationCoordinator`의 `for await` 루프가 그 자리에서 멈춰 있습니다.
  정지 구간 동안 카드 표시 상태 조립이 한 번도 실행되지 않는다는 뜻입니다.

### 추정

- `vm_statistics64`의 카운터를 Activity Monitor의 App·Wired·Compressed·Cached Files 항목에 대응시키는 식은
  Apple이 공식 문서로 규정한 것이 아닙니다. 필드가 존재한다는 것까지가 확인 사실이고,
  대응 관계는 널리 쓰이는 유도식이며 절대값이 Activity Monitor와 정확히 같다고 보장할 수 없습니다.
  그래서 SPEC §5.3의 판정을 절대값 일치가 아니라 변화 방향과 허용 오차로 정의합니다(§5 DP13).
- 디스플레이 슬립 여부와 세션 활성 여부를 시작 시점에 직접 읽는 공개 API는 26.5 SDK에서 확인되지 않았습니다.
  두 신호는 변경 알림만 공개돼 있으므로 초기값은 가정해야 합니다(§5 DP12).
- root 소유가 아닌 프로세스라도 `proc_pidinfo`가 실패할 수 있습니다. 실측한 것은 root 소유 프로세스의 차단이며,
  그 밖의 실패는 호출 결과로만 판별할 수 있다고 봅니다.
- 앱 번들 경로에서 가장 바깥 `.app`를 앱 키로 삼는 규칙이 Chrome·Electron·IDE의 하위 프로세스를 실제로 묶는지는
  대표 앱으로 확인해야 합니다. 번들 배치 관례에 근거한 판단이며 실측으로 검증한 사실이 아닙니다.

## 1. 구조

### 수집 경계

시스템 API 호출은 Collector 경계 안에만 둡니다. Application과 Presentation은 시스템 심볼을 직접 부르지 않습니다.

- CPU 시스템 Collector: `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` 한 번으로 논리 코어별 tick을 읽고,
  전체 값은 코어별 합으로 만듭니다. Load Average는 `getloadavg`로 읽습니다.
  직전 tick 원본과 그 시각을 소유하며, 사용률은 두 시점의 차이로 계산합니다.
- Memory 시스템 Collector: `host_statistics64(HOST_VM_INFO64)`, `host_page_size`,
  `ProcessInfo.physicalMemory`, `sysctl(VM_SWAPUSAGE)`,
  `sysctlbyname("kern.memorystatus_vm_pressure_level")`을 한 tick에 함께 읽습니다.
  누적 차이가 필요 없는 순간값 조회라 직전 상태를 소유하지 않습니다.
- 프로세스 Collector: `sysctl(KERN_PROC_ALL)`로 `kinfo_proc` 배열을 얻고,
  현재 유효 uid와 같은 프로세스에 대해서만 `proc_pidinfo(PROC_PIDTASKINFO)`를 호출합니다.
  실행 경로는 `proc_pidpath`로 읽되 새로 관찰된 정체성에 대해서만 한 번 호출합니다.

두 수집 축은 각각 하나의 `ScheduledSampleSource` 구현이 대표합니다.
`SystemMetricsSampleSource`는 CPU·Memory Collector를 소유하고 한 tick의 결과를 지표별 성공·실패로 묶은 값 하나로 반환합니다.
`ProcessSurveySampleSource`는 프로세스 Collector를 소유하고 한 번의 조사 결과를 반환합니다.
둘 다 직전 상태를 가지므로 actor로 두고, `MonitoringScheduler`가 `await`로 호출합니다.

### 이력 경계

시스템 지표 이력은 `MonitoringSampleStore`가 계속 소유합니다.
다만 M1이 하나의 `CircularBuffer`에 샘플 전체를 담던 구조를 둘로 나눕니다.

- 최신 스냅샷: 코어별 사용률, Load Average, Memory 세부 구성처럼 현재값만 필요한 지표를 담는 마지막 샘플 하나
- 이력 링: 시각, 전체 CPU 사용률, Swap 사용 바이트만 담는 고정 크기 `CircularBuffer`

CPU 최근 10분 그래프(SPEC §5.1)와 Swap 최근 변화량(SPEC §5.1, SPEC §5.2)이 이력 링을 소비합니다.
메모리 세부 구성의 시계열은 spec.md 완료 조건이 요구하지 않으므로 링에 담지 않습니다.
링 용량은 유효 수집 주기가 아니라 이 feature가 쓸 수 있는 가장 짧은 주기를 기준으로 고정합니다(§5 DP3).

프로세스 이력은 별도 경계인 `ProcessHistoryStore`가 소유합니다.
단일 값 시계열이 아니라 정체성별 상태 묶음이라 `MonitoringSampleStore`와 자료 구조가 다릅니다.
정체성마다 직전 CPU 누적 시간과 그 시각, 순위 안정화용 최근 세 개의 계산값, 10분 증가량 산정용 메모리 기준점 링을 둡니다.
매 조사에서 관찰되지 않은 정체성은 그 자리에서 제거합니다. 이 경계가 SPEC §5.7을 담당합니다.

경로에서 앱 키와 표시 이름을 유도하는 정적 정보 캐시는 프로세스 생명주기와 분리해 이 경계 안에 별도로 둡니다.
키는 실행 경로이고 고정 상한의 LRU로 유지합니다.

### 계산 경계

Application 계산은 상태를 갖지 않는 순수 함수로 두고, 필요한 직전 상태는 입력으로 받아 새 상태를 함께 반환합니다.

- 앱 집계와 TOP 5: 조사 결과와 정체성별 이력에서 앱 단위 CPU·메모리 현재값 순위와 10분 증가량 순위를 계산합니다.
  CPU와 Memory가 같은 앱 정체성 규칙을 공유합니다. SPEC §5.6과 SPEC §5.8을 담당합니다.
- CPU 표시 상태 판정: 전체 CPU 사용률과 샘플 시각, 직전 판정 상태를 받아 다섯 상태 중 하나를 돌려줍니다.
  경계 데드밴드와 최소 유지 시간을 함께 적용합니다. SPEC §5.4를 담당합니다.
- 카드 표시 상태 조립: 최신 스냅샷·이력 링·순위 계산 결과를 카드별 표시 상태로 바꿉니다.
  지표별 성공·실패가 카드별로 갈리므로 이 자리에서 실패가 격리됩니다. SPEC §5.10을 담당합니다.

### 표시 경계

`DashboardPresentationStore`를 `@MainActor` 관찰 가능 객체로 두고 최신 카드 표시 상태와 선택 상태를 소유합니다.
이 저장소는 팝오버가 닫혀 있어도 갱신을 계속 받습니다.
팝오버 콘텐츠 뷰는 M1과 마찬가지로 앱 시작 때 한 번 만들어져 계속 살아 있으므로,
저장소가 항상 최신 표시 상태를 들고 있으면 여는 순간 빈 화면이 나올 경로가 없습니다. 이 구조가 SPEC §5.9를 담당합니다.

`DashboardView`는 고정 크기 팝오버 안에 CPU 카드, Memory 카드와 하단 상세 영역을 둡니다.
상세 영역은 선택 여부와 관계없이 항상 자리를 차지하고 선택 전에는 안내를 표시합니다.
카드 선택으로 팝오버 크기가 변하지 않으므로 레이아웃이 흔들리지 않습니다. 이 구조가 SPEC §5.2를 담당합니다.

메뉴바 표시 경로는 M1 구조를 그대로 씁니다.
판정 결과를 `CharacterStateSource.send(_:)`로 넣으면 기존 매핑과 `StatusBarController.render(_:)`를 그대로 통과합니다.
표시 계층에는 변경이 없습니다.

### 생명주기 경계

`SystemLifecycleSnapshot`에 디스플레이 슬립과 세션 활성 두 필드를 더하고,
`SystemLifecycleFieldChange`에 대응하는 케이스를 더합니다.
`CombinedSnapshotProducer`는 필드별 병합과 revision 증가를 이미 담당하므로 구조가 그대로 유지됩니다.
두 신호는 `NSWorkspace.shared.notificationCenter`의 공개 알림이라 M1의 잠금 어댑터와 달리 별도 격리 어댑터가 필요 없습니다.

일정 결정은 `CollectionSchedulePolicy`가 시스템 지표와 프로세스 조사 두 일정을 함께 계산하는 형태로 확장하고,
`MonitoringLifecycleStore`가 두 Scheduler를 각각 결과가 바뀔 때만 호출합니다. 이 구조가 SPEC §5.12를 담당합니다.

일정이 멈췄다는 사실은 수집 결과가 아니라 일정 결정의 산물이므로 이 경계에서만 알 수 있습니다.
`MonitoringLifecycleStore`가 화면을 볼 수 없어 두 일정을 중지했는지와 다시 시작했는지의 전이를 밖으로 알리고,
`ApplicationCoordinator`가 그 신호를 받아 `DashboardPresentationStore`에 넣습니다.
방향은 생명주기 → coordinator → 표시 한 방향이고, 표시 계층은 생명주기 store를 호출하지 않습니다.
coordinator가 두 store를 이미 함께 보유하므로 새 소유 관계가 생기지 않고 경로 하나만 늘어납니다(§5 DP16).

## 2. 데이터 흐름

### 전체 경로

~~~text
시스템 API 조회
   ↓ SystemMetricsSampleSource / ProcessSurveySampleSource (actor)
MonitoringScheduler (일정·취소·generation)
   ↓ MonitoringSampleSink
MonitoringSampleStore (최신 스냅샷 + 이력 링) / ProcessHistoryStore (정체성별 이력)
   ↓ 최신 조합 하나만 보존하는 AsyncStream
ApplicationCoordinator (MainActor 소비)
   ├→ 카드 표시 상태 조립 → DashboardPresentationStore → DashboardView
   └→ CPU 표시 상태 판정 → CharacterStateSource → StatusBarController

SystemLifecycleObserver
   ↓ 최종 snapshot
MonitoringLifecycleStore (일정 결정: 중지·재개)
   ├→ 두 축의 MonitoringScheduler (일정 적용)
   └→ 중지·재개 전이 → ApplicationCoordinator (MainActor) → DashboardPresentationStore
~~~

### 시스템 지표 tick

1. Scheduler가 deadline에 도달하면 `SystemMetricsSampleSource.sample()`을 호출합니다.
2. source가 CPU Collector와 Memory Collector를 차례로 호출합니다.
   한쪽이 실패해도 던지지 않고 해당 지표만 실패로 표시한 샘플 하나를 만듭니다.
   두 지표가 같은 시각에 묶이므로 카드 사이의 시점 차이가 생기지 않습니다.
3. CPU Collector는 직전 tick 원본이 없으면 기준점만 잡고 사용률을 만들지 않습니다.
   직전 tick과의 경과 시간이 허용 범위를 넘으면 값을 만들지 않고 새 기준점으로만 삼습니다(§5 DP11).
   Memory Collector는 순간값 조회라 첫 tick부터 값을 만듭니다.
4. Scheduler가 generation을 확인한 뒤 샘플을 sink에 전달합니다.
5. `MonitoringSampleStore`가 최신 스냅샷을 교체하고, CPU 사용률과 Swap 값이 모두 있는 tick만 이력 링에 추가합니다.
   사용률을 만들지 못한 tick은 링에 들어가지 않으므로 그 시각이 그래프에서 비어 있게 됩니다. SPEC §5.11을 담당합니다.
6. 스토어가 최신 스냅샷과 시간 범위 안의 이력을 묶은 표시용 값을 stream으로 내보냅니다.
   stream은 최신 하나만 보존하므로 소비가 밀려도 오래된 조합이 쌓이지 않습니다.
7. coordinator가 `MainActor`에서 소비해 카드 표시 상태를 조립하고 `DashboardPresentationStore`에 반영합니다.
8. 같은 소비 지점에서 전체 CPU 사용률로 표시 상태를 판정하고 값이 바뀌었을 때만
   `CharacterStateSource.send(_:)`를 호출합니다.

이력 링에서 그래프로 넘길 구간은 최신 샘플 시각에서 10분을 뺀 시점 이후로 한정합니다.
용량으로만 축출하면 중지 구간이 있을 때 범위를 벗어난 샘플이 남기 때문이며, 이 선별이 `docs/design.md`가
이 feature에 남긴 시간 기준 선별입니다.
가로축의 오른쪽 끝은 표시 계층이 그리는 시점의 시각으로 잡습니다.
그래야 잠금이 막 풀린 직후처럼 마지막 샘플이 오래된 상황에서도 빈 구간이 제자리에 보입니다.

### 프로세스 조사 tick

1. Scheduler가 `ProcessSurveySampleSource.sample()`을 호출합니다.
2. source가 `sysctl(KERN_PROC_ALL)`로 전체 프로세스를 열거합니다.
   각 항목에서 PID, 시작 시각, uid, 부모 PID, `P_TRANSLATED` 플래그를 함께 얻습니다.
3. 현재 유효 uid와 같은 프로세스만 조사 대상으로 삼고, 나머지는 「읽을 수 없음」으로 세어 두고 값을 만들지 않습니다.
4. 대상마다 `proc_pidinfo(PROC_PIDTASKINFO)`로 누적 CPU 시간과 Resident Memory를 읽습니다.
   호출이 실패한 프로세스는 그 tick의 결과에서 빠지고 추정값으로 채우지 않습니다. SPEC §5.6을 담당합니다.
5. 새로 관찰된 정체성만 `proc_pidpath`로 경로를 읽고, 경로에서 앱 키와 표시 이름을 유도해 캐시에 넣습니다.
6. Scheduler가 조사 결과를 `ProcessHistoryStore`에 전달합니다.
7. 스토어가 정체성별 직전 누적 CPU 시간과 비교해 프로세스 CPU 사용률을 계산합니다.
   경과 시간이 허용 범위를 넘으면 값을 만들지 않고 기준점만 갱신합니다.
8. 스토어가 이번 조사에 없는 정체성을 제거하고, 최근 세 개 링과 메모리 기준점 링을 갱신합니다.
9. 스토어가 앱 집계와 순위 계산에 필요한 값을 stream으로 내보내고 coordinator가 표시 상태에 반영합니다.

프로세스 CPU 사용률은 논리 코어 합산 관례를 따르므로 여러 코어를 쓰는 프로세스에서 100%를 넘습니다.
시스템 전체 CPU는 코어별 tick 합에서 계산해 항상 0~100% 범위입니다.
두 값은 서로 다른 단위이므로 표시 계층이 라벨과 접근성 이름에서 구분합니다. SPEC §5.3을 담당합니다.

### 앱 집계와 순위

정체성 키는 PID와 프로세스 시작 시각의 쌍입니다.
PID가 재사용되면 시작 시각이 달라지므로 새 정체성이 되고 이전 이력을 이어받지 않습니다.
프로세스가 종료되면 다음 조사에서 정체성이 사라져 이력이 제거됩니다. SPEC §5.7을 담당합니다.

앱 키는 실행 경로에서 가장 바깥 `.app` 번들 경로입니다.
`.app`를 찾지 못하면 실행 파일 경로 자체를 키로 씁니다.
표시 이름은 번들의 이름이거나, 앱으로 묶이지 않으면 실행 파일 이름입니다.

순위는 정체성별 최근 세 개 값의 평균을 앱 키로 합산해 만듭니다.
순간값이 아니라 최근 여러 샘플을 반영하므로 갱신마다 순위가 뒤바뀌지 않습니다. SPEC §5.6을 담당합니다.
최근 증가량 순위는 정체성별 메모리 기준점 링에서 10분 창 안의 가장 오래된 기준점과 현재값의 차이를 앱 키로 합산합니다.
현재 사용량 순위와 증가량 순위는 서로 다른 목록으로 제공됩니다. SPEC §5.8을 담당합니다.

읽지 못한 프로세스가 있다는 사실은 TOP 5 목록에 붙는 상시 설명으로 표시합니다.
색상이나 Hover가 아니라 항상 보이는 문구이며 접근성 이름에도 포함됩니다. SPEC §5.6을 담당합니다.

### 메뉴바 표시 상태 판정

판정은 전체 CPU 사용률 하나를 입력으로 받고 다음 상태를 가집니다.

| 표시 상태 | 진입 조건 |
| --- | --- |
| `low` | 사용률이 25% 미만 |
| `moderate` | 25% 이상 50% 미만 |
| `high` | 50% 이상 75% 미만 |
| `veryHigh` | 75% 이상 |
| `sustainedHigh` | 75% 이상이 60초 이상 끊기지 않고 지속 |

경계마다 5%p 데드밴드를 둡니다.
상태가 올라갈 때는 경계값을 그대로 쓰고, 내려갈 때는 경계값에서 5%p를 뺀 값을 밑돌아야 합니다.
데드밴드를 통과한 새 후보 상태는 3초 이상 유지될 때만 실제 표시 상태를 바꿉니다.
두 장치가 함께 있어야 경계 위아래를 오가는 값과 한 tick짜리 스파이크가 모두 걸러집니다. SPEC §5.4를 담당합니다.

지속 시간은 샘플 개수가 아니라 샘플 시각으로 셉니다.
수집 주기가 1초에서 5초까지 달라져도 같은 시간 기준이 유지되어야 하기 때문입니다.
인접한 두 샘플의 간격이 허용 범위를 넘으면 지속 누적을 끊고 다시 셉니다.
그래야 화면 잠금으로 중지된 구간이 장시간 고부하로 판정되지 않습니다.

`sustainedHigh`에서는 사용률이 `veryHigh` 진입 경계의 데드밴드 아래로 3초 이상 내려가야 벗어납니다.
CPU 지표 수집이 실패한 tick에서는 판정을 진행하지 않고 마지막 표시 상태를 유지합니다.
실패가 상태를 임의로 뒤집지 않게 하기 위해서입니다.

Memory Pressure는 이 feature에서 메뉴바 상태의 입력이 아닙니다(§5 DP8).

### 팝오버 열림과 카드 선택

1. 사용자가 메뉴바 항목을 클릭하면 M1 경로가 팝오버를 열고 delegate가 `popoverPresented(true)`를 냅니다.
2. 팝오버 콘텐츠는 이미 살아 있고 `DashboardPresentationStore`가 마지막 표시 상태를 들고 있으므로
   첫 프레임부터 마지막 수집값이 보입니다. 로딩 상태를 거치지 않습니다. SPEC §5.9를 담당합니다.
3. `popoverPresented(true)`가 생명주기 store에 도달해 두 일정이 열림 주기로 바뀌고, 다음 tick부터 최신값이 반영됩니다.
4. 카드를 활성화하면 선택 상태가 그 카드로 바뀌고 하단 영역이 상세로 채워집니다.
   같은 카드를 다시 활성화하면 선택이 해제되고 요약 안내로 돌아갑니다.
5. 상세 안에서 앱 항목을 펼치면 그 앱의 하위 프로세스가 나타납니다. SPEC §5.2와 SPEC §5.6을 담당합니다.

도달 가능한 선택 상태는 선택 없음, CPU 선택, Memory 선택 셋입니다.
전이는 카드 활성화 하나로만 일어나고 수집 결과나 실패는 선택 상태를 바꾸지 않습니다.
카드는 표준 `Button`으로 두고, 선택과 복귀를 수행하는 키보드 단축키를 함께 제공합니다.
단축키는 macOS 키보드 탐색 설정과 무관하게 동작하므로 기본 설정 환경에서도 선택과 복귀가 키보드만으로 끝납니다.
단축키의 존재는 카드에 항상 보이는 표시와 카드 접근성 이름에서 확인됩니다(§5 DP15).
M1이 팝오버를 열 때 앱을 활성화하고 팝오버 창을 key로 만들어 두었으므로 키 이벤트가 도달합니다. SPEC §5.13을 담당합니다.

Memory Pressure 단계는 텍스트 라벨과 형태가 구분되는 기호를 함께 써서 색상 없이도 읽히게 하고,
카드 접근성 이름에 현재 단계를 포함합니다.
정상으로 돌아오면 같은 자리가 원래 표시로 복귀합니다. SPEC §5.5를 담당합니다.

### 수집 중지와 재개

`CollectionSchedulePolicy`는 화면 잠금·디스플레이 슬립·세션 비활성 중 하나라도 성립하면 두 일정을 모두 중지합니다.
잠금 상태가 `unknown`일 때 중지하는 M1 규칙은 그대로 둡니다.
그 밖에는 저전력 여부와 팝오버 열림 여부로 두 주기를 함께 정합니다.

| 전력 | 팝오버 | 시스템 지표 | 프로세스 조사 |
| --- | --- | ---: | ---: |
| normal | 열림 | 1초 | 2초 |
| normal | 닫힘 | 2초 | 5초 |
| lowPower | 열림 | 2초 | 4초 |
| lowPower | 닫힘 | 5초 | 10초 |

중지 구간에서는 새 샘플이 만들어지지 않고 이력도 변하지 않습니다. SPEC §5.12를 담당합니다.
재개하면 Collector의 직전 원본은 남아 있지만 경과 시간이 허용 범위를 넘으므로 첫 tick은 기준점만 갱신합니다.
그래서 중지 전 값과 재개 후 값이 하나의 변화량으로 이어 붙지 않고 그래프에 빈 구간이 그대로 남습니다. SPEC §5.11을 담당합니다.

### 실패 경로

카드 표시 상태는 다음 값을 가집니다.

- 수집 중: 앱 시작 직후 아직 유효한 값이 없는 상태
- 정상: 최신 값과 그 시각
- 실패: 마지막 성공 값과 그 시각을 함께 보여주면서 최근 수집이 실패했음을 표시
- 중지: 화면을 볼 수 없어 일정이 멈춘 상태

중지는 수집 결과에서 유도할 수 없습니다.
일정이 멈춘 구간에는 tick이 하나도 없어 조립이 실행되지 않기 때문입니다(§근거 확인 사실).
그래서 §1 「생명주기 경계」가 둔 경로로 중지 사실이 표시 저장소에 직접 도착하고, 그때 두 카드가 함께 중지로 바뀝니다.
중지도 실패와 마찬가지로 마지막 성공 값과 그 시각을 함께 들고 있어 복귀 직후 팝오버를 열어도 빈 화면이 되지 않습니다.
중지에서 벗어나는 것은 재개 신호가 아니라 그 카드의 값이 성립한 첫 tick입니다.
그 tick의 조립 결과가 중지를 덮어 정상이나 실패로 바뀝니다.
Memory는 순간값 조회라 재개 첫 tick에서 바로 벗어나고,
CPU는 재개 첫 tick이 값을 만들지 않고 기준점만 갱신하므로(§5 DP11) 값이 성립하는 그다음 tick에서 벗어납니다.
그 사이 CPU 카드는 실패가 아니라 중지로 남습니다. 그 구간에 멈춘 것이 수집 호출이 아니라 일정이기 때문입니다.

CPU 지표 실패는 CPU 카드만 실패로 바꾸고 Memory 카드와 메뉴바 표시는 그대로 둡니다. 반대 방향도 같습니다.
프로세스 조사 실패는 두 카드의 TOP 5만 실패로 바꾸고 시스템 지표 수치는 그대로 둡니다.
일시적 실패를 0으로 표시하지 않습니다. SPEC §5.10을 담당합니다.

Scheduler는 source가 던져도 0 샘플로 바꾸지 않고 다음 실행으로 넘어가는 M1 동작을 유지합니다.
다만 지표별 실패는 던지지 않고 샘플 안의 실패 값으로 전달하므로,
한 지표의 실패가 다른 지표의 그 tick 값을 함께 없애지 않습니다.

## 3. 인터페이스

### 수집 계약

- `CPUSystemMetrics`: 전체 사용률, User·System·Idle 비율, 논리 코어별 사용률, Load Average를 담는 값
- `MemorySystemMetrics`: 전체 물리 메모리, 현재 사용 중 메모리, App·Wired·Compressed·Cached,
  Swap 사용량, Memory Pressure 단계를 담는 값
- `MemoryPressureLevel`: `normal`·`warning`·`critical`의 닫힌 집합.
  `kern.memorystatus_vm_pressure_level`의 `0x01`·`0x02`·`0x04`에 대응하고 그 밖의 값은 실패로 다룹니다.
- `CollectorFailure`: 조회 실패를 값으로 표현하는 오류 타입. 지표 종류와 실패 원인을 구분합니다.
- `SystemMetricsSample`: CPU와 Memory 각각을 `Result`로 담는 한 tick의 결과.
  이 형태가 지표별 실패 격리를 계약 수준에서 보장합니다.
- `SystemMetricsSampleSource`: 위 샘플을 반환하는 `ScheduledSampleSource` 구현 actor.
  직전 CPU tick 원본과 그 시각을 소유합니다.

### 프로세스와 앱 계약

- `ProcessIdentity`: PID와 프로세스 시작 시각을 묶는 값. 이력과 캐시의 유일한 키입니다.
- `ProcessSample`: 정체성, 실행 경로, uid, 부모 PID, 누적 CPU 시간, Resident Memory,
  Rosetta 실행 여부를 담는 한 프로세스의 조사 결과
- `ProcessSurveyReport`: 이번 조사에서 값을 얻은 프로세스 목록과 읽지 못한 프로세스 수를 담는 값
- `ProcessSurveySample`: 위 결과 또는 조사 실패를 담는 `Result`.
  열거 자체가 실패해 이번 tick의 결과가 아예 없는 경우를 던지지 않고 값으로 전달합니다 —
  던지면 `MonitoringScheduler`가 tick을 건너뛰어 §2 「실패 경로」가 정한
  "프로세스 조사 실패는 두 카드의 TOP 5만 실패로 바꾼다"가 표시 계층에 도달할 통로가 없습니다.
  시스템 지표 축의 `SystemMetricsSample`과 같은 규칙입니다.
- `ProcessSurveySampleSource`: 위 값을 반환하는 `ScheduledSampleSource` 구현 actor
- `ApplicationKey`: 가장 바깥 `.app` 번들 경로 또는 실행 파일 경로를 담는 앱 집계 키
- `ApplicationIdentityResolver`: 실행 경로에서 앱 키와 표시 이름을 유도하고 결과를 캐시하는 계약
- `ProcessHistoryStore`: 조사 결과를 받아 정체성별 이력을 갱신하고, 사라진 정체성을 제거하며,
  앱 단위 현재값 순위와 10분 증가량 순위 계산에 필요한 값을 제공하는 actor.
  실패한 조사는 이력을 전혀 건드리지 않고 실패 사실만 기록해 순위 계산 입력과 함께 내보냅니다 —
  관찰된 정체성이 없는 것으로 처리하면 제거 규칙이 이력 전체를 지웁니다.
  실패 표시는 다음 성공 조사까지 유지되므로, 더 빠른 시스템 지표 tick이 순위를 다시 읽어도 흔들리지 않습니다

### 일정 계약

- `CollectionSchedulePlan`: 시스템 지표와 프로세스 조사 각각의 `CollectionSchedule`을 묶는 값
- `CollectionScheduleDefinition`: 위 표의 여덟 값을 담도록 확장한 일정 정의
- `CollectionSchedulePolicy.plan(for:definition:)`: 최종 snapshot과 정의에서 `CollectionSchedulePlan`을 계산하는 순수 함수
- `CollectionScheduleTarget`: `apply(_ schedule: CollectionSchedule) async`만 제공하는 actor 계약.
  `MonitoringLifecycleStore`가 두 Scheduler를 이 계약으로 보유합니다.
- `MonitoringSampleSink`: `append(_ sample: TimestampedSample<Value>) async`만 제공하는 actor 계약.
  `MonitoringScheduler`가 저장 대상을 구체 타입 대신 이 계약으로 받습니다.
- `SystemLifecycleSnapshot`: `revision`·`lowPowerMode`·`screenLockState`에 디스플레이 슬립과 세션 활성을 더한 값
- `SystemLifecycleFieldChange`: 위 두 필드의 변경 케이스를 더한 열거

`MonitoringScheduler`의 단일 Task·generation·기준 deadline 전진 규칙과
`MonitoringLifecycleStore`의 revision 거부·중복 일정 억제 규칙은 M1 계약을 그대로 유지합니다.

### 표시 계약

- `ResourceCardState`: 수집 중·정상·실패·중지 네 경우를 담는 카드 표시 상태
- `CPUCardPresentation`: 전체 사용률, User·System 비율, 그래프 점 목록, 앱 단위 CPU TOP 5,
  상세용 코어별 사용률·Load Average·프로세스 목록을 담는 값
- `MemoryCardPresentation`: 전체 물리 메모리, 사용 중 메모리, Memory Pressure 단계,
  Swap 사용량과 10분 변화량, 앱 단위 메모리 TOP 5,
  상세용 App·Wired·Compressed·Cached와 현재 사용량 순위·최근 증가량 순위를 담는 값
- `HistoryPoint`: 시각과 값을 묶는 그래프 점. 인접 점의 시각 간격으로 빈 구간을 판별합니다.
- `DashboardSelection`: 선택 없음·CPU·Memory의 닫힌 집합
- `DashboardPresentationStore`: 위 값들과 선택 상태를 소유하는 `@MainActor` 관찰 가능 객체
  수집 tick을 받는 진입점과 별개로, 일정 중지·재개 전이를 받는 진입점을 함께 가집니다.
  중지를 받으면 두 카드를 마지막 성공 값을 유지한 채 중지로 바꾸고,
  재개는 그 자체로 카드 상태를 바꾸지 않으며 다음에 값이 성립한 tick의 조립 결과가 중지를 대체합니다.
- `CPUActivityStateEvaluator`: 사용률·샘플 시각·직전 판정 상태를 받아 다음 판정 상태를 돌려주는 순수 계산

메뉴바 쪽 계약은 M1의 `CharacterActivityState`, `CharacterPresentation`, `CharacterPresentationSink`를 그대로 씁니다.
이 feature는 그 입력을 주입에서 실제 판정으로 바꾸기만 합니다.

## 4. 영향 범위

### 기존 코드

- [MonitoringScheduler.swift](../../ResourceRunner/MonitoringScheduler.swift):
  저장 대상이 `MonitoringSampleStore<Source.Value>` 구체 타입에서 `MonitoringSampleSink` 계약으로 바뀝니다.
  `apply(_:)`에서 `sampleStore.resize(samplingInterval:)` 호출이 사라집니다.
  `PlaceholderMonitoringSample`과 `PlaceholderScheduledSampleSource`는 실제 source로 대체돼 제거됩니다.
- [MonitoringSampleStore.swift](../../ResourceRunner/MonitoringSampleStore.swift):
  최신 스냅샷과 이력 링을 분리하고 `MonitoringSampleSink`를 구현합니다.
  용량 기준이 유효 주기에서 최소 주기로 바뀌므로 `resize(samplingInterval:timeRange:)`는 호출자가 없어집니다.
  시간 범위 선택이 들어오는 M4까지 쓰이지 않는 API를 남기지 않고 제거하며,
  `HistoryCapacity`와 `CircularBuffer`는 그대로 씁니다.
- [MonitoringLifecycle.swift](../../ResourceRunner/MonitoringLifecycle.swift):
  `CollectionScheduleDefinition`이 여덟 값으로 확장되고 정책이 `CollectionSchedulePlan`을 돌려줍니다.
  `MonitoringLifecycleStore`가 두 target을 보유하며 `<Clock, Source>` 제네릭 파라미터가 사라집니다.
  화면을 볼 수 없는 상태 판정에 디스플레이 슬립과 세션 비활성이 더해집니다.
- [SystemLifecycleObserver.swift](../../ResourceRunner/SystemLifecycleObserver.swift):
  snapshot과 field change에 두 필드가 추가되고 `NSWorkspace` 알림 등록이 더해집니다.
  `CombinedSnapshotProducer`의 병합 규칙과 `ScreenLockObservationAdapter`는 그대로입니다.
- [ApplicationCoordinator.swift](../../ResourceRunner/ApplicationCoordinator.swift):
  두 source·두 Scheduler·두 스토어와 표시 저장소를 구성하고, 수집 결과 stream을 소비해
  카드 표시 상태와 CPU 판정 결과를 나누는 배선이 추가됩니다.
  제네릭이 정리되면서 저장 속성의 타입 표기가 짧아집니다.
- [DashboardView.swift](../../ResourceRunner/DashboardView.swift):
  셸이 두 카드와 상세 영역을 가진 대시보드로 교체됩니다.
- [StatusBarController.swift](../../ResourceRunner/StatusBarController.swift)와
  [CharacterStateSource.swift](../../ResourceRunner/CharacterStateSource.swift):
  변경하지 않습니다.
  Debug 우클릭 주입 메뉴는 남지만 다음 수집 tick의 실제 판정이 주입한 상태를 덮으므로 관찰 수단으로서의 의미가 줄어듭니다.
  제거는 이 feature의 완료 조건과 무관하므로 하지 않습니다.

### 테스트 대상

- [MonitoringSampleStoreTests.swift](../../ResourceRunnerTests/MonitoringSampleStoreTests.swift)에서
  `resize` 동작을 검증하는 단언이 용량 고정 검증으로 바뀝니다.
- [MonitoringLifecycleTests.swift](../../ResourceRunnerTests/MonitoringLifecycleTests.swift)의
  일정 계산 검증이 단일 일정에서 두 일정 조합으로 바뀌고, 화면을 볼 수 없는 상태 세 가지가 대상에 더해집니다.
- [ApplicationCoordinatorTests.swift](../../ResourceRunnerTests/ApplicationCoordinatorTests.swift)와
  [SystemLifecycleObserverTests.swift](../../ResourceRunnerTests/SystemLifecycleObserverTests.swift)는
  snapshot 필드 추가와 배선 변경만큼 갱신됩니다.
- [CharacterStateSourceTests.swift](../../ResourceRunnerTests/CharacterStateSourceTests.swift)와
  [StatusBarControllerTests.swift](../../ResourceRunnerTests/StatusBarControllerTests.swift),
  [ResourceRunnerUITests](../../ResourceRunnerUITests)는 표시 경로가 그대로라 영향을 받지 않습니다.

### M1 결정 중 이 feature가 대체하는 것

- M1 analysis.md DP5는 실행 주기 변경과 resume에서 버퍼를 새 주기로 resize하도록 정했습니다.
  이 feature가 §5 DP3으로 대체합니다. 실제 수집값이 들어오면 그 규칙이 최근 10분 그래프를 성립시키지 못하기 때문입니다.
- M1 analysis.md DP4가 정한 store·scheduler·sample store의 3분할 경계는 유지하고, 축을 둘로 늘리기만 합니다.

### 프로젝트 설정과 외부 경계

App Sandbox, deployment target 26.5, arm64 전용 산출물과 단일 애플리케이션 대상 구성을 그대로 유지합니다.
새 Helper, 로그인 항목, 실행 대상과 외부 package 의존성을 만들지 않습니다. SPEC §5.14를 담당합니다.
수집한 값과 프로세스 정보는 앱 메모리에만 존재하고 파일·`UserDefaults`·네트워크로 나가지 않습니다.
필요한 시스템 API는 모두 Sandbox에서 접근 가능한 것으로 확인된 범위 안에 있으므로 entitlement 변경이 없습니다.

`docs/product.md`의 `대시보드 > 공통 정보 구조`가 언급하는 앱 아이콘 표시와 Hover 설명,
`Memory` 상세의 최근 1분 증가량 순위는 spec.md 완료 조건에 없어 이 feature 범위 밖으로 둡니다.
product.md의 상태 우선순위 규칙 중 Memory Pressure가 메뉴바 상태를 앞지르는 부분도
spec.md가 메뉴바 판정을 CPU로 한정해 이 feature 범위 밖입니다(§5 DP8).

## 5. Decision Points

### DP1. 두 수집 주기를 수용하는 방식

- 옵션 A: Scheduler 하나를 유지하고 프로세스 조사를 N tick마다 실행합니다.
  타입은 늘지 않지만 두 주기가 항상 배수 관계여야 하고, 한쪽 주기가 바뀌면 다른 쪽 위상이 함께 흔들립니다.
- 옵션 B: Scheduler가 여러 Task를 소유하도록 확장합니다.
  일정 계산이 한곳에 모이지만 M1이 세운 단일 Task·단일 generation 불변식이 깨져 취소 규칙이 복잡해집니다.
- 옵션 C: Scheduler 인스턴스를 둘 두고 각각 자기 source와 sink를 갖게 합니다.
  단일 Task 불변식이 인스턴스마다 그대로 유지되지만, 저장 대상 타입 고정을 계약으로 풀어야 하고
  생명주기 store가 두 일정을 계산해 각각 적용해야 합니다.
- 채택안: 옵션 C.
  `MonitoringScheduler`의 취소·generation·deadline 전진 규칙은 M1에서 이미 검증된 자산이고,
  그 규칙이 성립하는 이유가 "한 인스턴스는 Task 하나만 소유한다"이므로 인스턴스를 늘리는 쪽이 규칙을 건드리지 않습니다.
  저장 대상은 `MonitoringSampleSink` 계약으로 받아 시스템 이력과 프로세스 이력이 서로 다른 자료 구조를 쓸 수 있게 합니다.
  SPEC §5.12가 요구하는 일정 변경은 `CollectionSchedulePlan` 한 값에서 두 target으로 갈라집니다.

### DP2. CPU와 Memory 시스템 지표의 묶음 단위

- 옵션 A: CPU와 Memory에 각각 Scheduler와 스토어를 둡니다.
  실패가 구조적으로 갈리지만 같은 주기의 축이 셋으로 늘고, 두 카드의 샘플 시각이 어긋나 그래프 비교가 어긋납니다.
- 옵션 B: 한 source가 두 Collector를 호출하고 실패 시 던집니다.
  간단하지만 한쪽 실패가 그 tick의 다른 지표까지 없애 SPEC §5.10을 충족하지 못합니다.
- 옵션 C: 한 source가 두 Collector를 호출하고 지표별 성공·실패를 담은 샘플 하나를 반환합니다.
  샘플 타입에 `Result`가 들어가지만 시각이 하나로 묶이고 실패가 지표 단위로 격리됩니다.
- 채택안: 옵션 C.
  SPEC §5.10이 요구하는 격리 단위는 축이 아니라 카드이고, 카드 단위 격리는 샘플 안의 값 형태로 충분히 표현됩니다.
  Scheduler가 오류를 다루는 방식(던지면 그 tick 전체를 버림)은 M1 그대로 두고,
  지표별 부분 실패는 오류가 아니라 값으로 전달해 두 계층의 책임을 섞지 않습니다.

### DP3. 최근 이력 버퍼의 용량 기준

- 옵션 A: M1처럼 유효 수집 주기로 용량을 재계산하고 주기가 바뀔 때 resize합니다.
  버퍼 크기가 항상 최소지만, 팝오버를 닫아 주기가 2초가 되는 순간 용량이 절반으로 줄어
  이미 수집한 최근 10분 중 절반이 사라집니다. SPEC §5.1의 10분 그래프가 성립하지 않습니다.
- 옵션 B: 용량을 이 feature가 쓸 수 있는 가장 짧은 주기 기준으로 고정하고 resize를 하지 않습니다.
  주기가 느려지면 버퍼가 덜 찰 뿐 이미 쌓인 이력이 사라지지 않습니다. 항상 최대 크기를 할당합니다.
- 옵션 C: 개수 대신 시각으로 축출하는 자료 구조로 바꿉니다.
  의미는 가장 정확하지만 고정 크기 원형 배열의 O(1) 성질을 잃고 M1이 검증한 구조를 버립니다.
- 채택안: 옵션 B.
  이력 링에 담는 것은 시각과 스칼라 몇 개뿐이라 최대 용량으로 고정해도 수십 KB 규모이고,
  성능 목표의 메모리 항목에 의미 있는 영향을 주지 않습니다.
  범위를 벗어난 오래된 샘플이 버퍼에 남는 문제는 `docs/design.md`가 이 feature에 남긴 시간 기준 선별로 처리하며,
  표시 직전에 최신 시각 기준 10분 창으로 거르므로 축출 기준과 표시 기준을 분리합니다.
  이 선택이 SPEC §5.1과 SPEC §5.11을 함께 성립시킵니다.

### DP4. 프로세스 정체성 키

- 옵션 A: PID만 씁니다. 비용이 없지만 PID 재사용에서 이력이 섞입니다.
- 옵션 B: PID와 프로세스 시작 시각의 쌍을 씁니다.
  `sysctl(KERN_PROC_ALL)` 결과의 `p_starttime`에 이미 들어 있어 추가 호출이 없습니다.
- 옵션 C: PID와 실행 경로를 씁니다. 의미는 명확하지만 프로세스마다 `proc_pidpath` 호출이 필요하고,
  같은 실행 파일을 여러 번 실행하면 구분되지 않습니다.
- 채택안: 옵션 B.
  PID 재사용은 같은 PID를 같은 시각에 다시 받는 경우에만 충돌하는데 시작 시각이 마이크로초 단위라 실질적으로 발생하지 않습니다.
  열거 결과에서 함께 오므로 조사 비용이 늘지 않는다는 점이 결정적입니다. 이 키가 SPEC §5.7을 성립시킵니다.

### DP5. 앱 집계 키

- 옵션 A: `NSWorkspace.shared.runningApplications`의 PID로 매핑합니다.
  공개 API만 쓰지만 GUI 앱 본체만 목록에 있어 Chrome Renderer나 Electron Helper가 묶이지 않습니다.
  spec.md가 요구하는 "여러 프로세스로 구성된 앱이 하나의 항목으로" 표시되지 않습니다.
- 옵션 B: 실행 경로에서 가장 바깥 `.app` 번들 경로를 앱 키로 삼습니다.
  중첩된 helper 번들이 자기 상위 앱으로 접히므로 복합 앱이 하나로 묶입니다.
  경로 한 번만 읽으면 되고 결과를 경로 기준으로 캐시할 수 있습니다.
- 옵션 C: 부모 PID 체인을 거슬러 최상위 앱을 찾습니다.
  번들 배치와 무관하게 동작하지만 부모가 종료돼 `launchd`로 재부모화된 프로세스에서 체인이 끊깁니다.
- 채택안: 옵션 B.
  `docs/design.md`의 집계 원칙이 "앱 번들에 속한 프로세스는 가능한 경우 같은 앱으로 집계"이고,
  Chrome·Electron·IDE의 helper가 모두 상위 앱 번들 안에 중첩 배치되는 관례를 따르므로 이 규칙이 그 관계를 그대로 표현합니다.
  `.app`를 찾지 못하는 명령행 프로세스는 실행 파일 경로를 키로 삼아 확인 가능한 실행 정보로 표시합니다.
  이 규칙이 대표 앱에서 실제로 성립하는지는 실측으로 확인해야 하며(§근거 추정),
  묶이지 않는 예외가 나오면 그 앱의 하위 프로세스가 별도 항목으로 보이는 것이 대가입니다.
  CPU와 Memory가 같은 키를 쓰므로 두 카드의 집계 기준이 일치합니다. 이 키가 SPEC §5.6을 성립시킵니다.

### DP6. 프로세스별 이력 보관 구조

- 옵션 A: 조사 스냅샷 전체를 10분치 순환 버퍼에 넣고 필요할 때 훑습니다.
  기존 `CircularBuffer`를 그대로 쓰지만 프로세스 수 × 샘플 수만큼 메모리를 쓰고,
  조사 주기가 빨라지면 이력이 함께 커지며, 종료된 프로세스를 지우려면 전체를 훑어야 합니다.
- 옵션 B: 정체성별로 최근 세 개 값만 보관합니다.
  순위 안정화에는 충분하지만 10분 증가량을 계산할 기준점이 없어 SPEC §5.8을 충족하지 못합니다.
- 옵션 C: 정체성별로 두 개의 고정 크기 링을 둡니다.
  순위 안정화용 최근 세 개 링과, 최소 간격을 둔 메모리 기준점 링을 분리합니다.
  기준점 링의 크기가 조사 주기와 무관해지지만 증가량 기준점이 그 최소 간격만큼 어긋날 수 있습니다.
- 채택안: 옵션 C.
  이력에 필요한 것은 순위용 짧은 평균과 증가량용 기준점 하나뿐이고 프로세스별 그래프는 요구되지 않으므로,
  전체 시계열을 보관할 이유가 없습니다.
  기준점 링을 최소 간격 기준으로 두면 조사 주기가 2초든 10초든 이력 크기가 같아
  장기 실행에서 프로세스 이력이 주기에 따라 커지지 않습니다.
  대가는 10분 증가량의 기준점 시각이 최소 간격만큼 어긋날 수 있다는 것이며,
  10분 창에서 그 오차는 증가량의 크기 순서를 바꿀 만한 수준이 아닙니다.
  종료된 정체성은 사전에서 바로 지워지므로 SPEC §5.7의 제거가 O(1)로 끝납니다.

### DP7. 읽을 수 없는 프로세스의 처리와 안내

- 옵션 A: 모든 프로세스에 `proc_pidinfo`를 호출하고 실패한 것만 제외합니다.
  판정이 정확하지만 전체의 약 40%에 대해 반드시 실패할 호출을 매 조사마다 반복합니다.
- 옵션 B: 현재 유효 uid와 다른 프로세스는 호출하지 않고 제외하며, 그 안에서 실패한 것도 제외합니다.
  불필요한 호출이 사라지지만 다른 사용자 소유이면서 읽을 수 있는 프로세스가 있다면 놓칩니다.
- 옵션 C: 읽지 못한 프로세스의 사용량을 다른 정보로 추정해 채웁니다.
  목록이 완전해 보이지만 spec.md가 명시적으로 금지합니다.
- 채택안: 옵션 B.
  spec.md 제약이 이미 "TOP 5는 사실상 사용자 소유 프로세스로 한정됩니다"로 결과를 규정하고 있어,
  uid 사전 판별은 그 결과를 바꾸지 않으면서 조사 비용만 줄입니다.
  `docs/design.md`가 프로세스 조사 비용을 주요 기술 위험으로 두고 있으므로 반복 실패 호출을 없애는 값어치가 있습니다.
  목록이 시스템 프로세스를 담지 않는다는 사실은 TOP 5 옆의 상시 문구로 표시하고 접근성 이름에도 넣습니다.
  Hover나 색상에 의존하지 않는 이유는 `docs/product.md`가 중요한 분석 정보를 Hover에만 두지 말라고 요구하기 때문입니다.
  이 처리가 SPEC §5.6을 성립시킵니다.

### DP8. 표시 상태 판정 규칙과 입력 범위

**흔들림 억제 수단**

- 옵션 A: 사용률을 평활화한 뒤 고정 임계치로 판정합니다.
  값이 부드러워지지만 평활화 창을 시간 기준으로 맞춰야 하고,
  그래프에 그리는 값과 판정에 쓰는 값이 달라져 사용자가 둘의 불일치를 보게 됩니다.
- 옵션 B: 경계에 데드밴드를 두고 새 후보 상태에 최소 유지 시간을 요구합니다.
  파라미터가 둘이고 둘 다 순수 함수로 검증할 수 있으며 표시값을 건드리지 않습니다.
- 옵션 C: 평활화와 히스테리시스를 함께 씁니다.
  가장 안정적이지만 파라미터가 셋으로 늘고 어느 장치가 어떤 흔들림을 막는지 분리 검증이 어려워집니다.
- 채택안: 옵션 B.
  SPEC §5.4가 요구하는 것은 "경계 근처에서 반복해서 뒤집히지 않는다"와 "장시간 고부하와 순간 부하의 구분" 둘이고,
  앞은 데드밴드가, 뒤는 최소 유지 시간과 지속 시간 조건이 각각 담당합니다.
  `docs/design.md`도 평활화와 히스테리시스를 택일로 두고 있습니다.
  그래프와 카드에는 평활화하지 않은 원값을 표시하므로 SPEC §5.3의 시스템 도구 비교와 판정 규칙이 서로 간섭하지 않습니다.

**수치**

경계는 25·50·75%, 데드밴드는 5%p, 최소 유지 시간은 3초, 장시간 고부하 판정은 75% 이상 60초 지속으로 둡니다.
경계 셋은 0~100% 구간을 네 등분해 "대략 구분"이라는 제품 목표에 맞춘 값이고,
데드밴드 5%p는 등분 폭 25%p의 5분의 1이라 구간 하나를 잠식하지 않으면서 경계 진동을 흡수합니다.
최소 유지 시간 3초는 가장 빠른 주기 1초에서 세 샘플, 닫힘 2초에서 두 샘플에 해당해 한 tick 스파이크를 항상 거릅니다.
장시간 고부하 60초는 빌드 시작이나 앱 실행 같은 수 초~수십 초 스파이크와 지속 부하를 가르는 자리입니다.
이 수치들은 사용자가 보는 결과를 직접 정하므로 2026-08-12에 사용자 확인을 받아 확정했습니다.
실제 값을 눈으로 본 뒤 조정할 여지가 있으며, 조정은 순수 판정 함수의 파라미터만 바꾸는 범위에서 끝납니다.

**입력 범위**

- 옵션 A: `docs/product.md`의 우선순위대로 Memory Pressure가 CPU 상태를 앞지르게 합니다.
  1.0 목표 규칙과 같아지지만 spec.md가 메뉴바에 요구한 것은 CPU 다섯 상태이고,
  Memory Pressure의 메뉴바 반영은 캐릭터 상태 표현이라 자산과 함께 정해야 합니다.
- 옵션 B: 이 feature의 메뉴바 판정 입력을 CPU 사용률 하나로 한정합니다.
  SPEC §5.4를 그대로 충족하고 우선순위 통합은 캐릭터 feature로 넘깁니다.
- 채택안: 옵션 B.
  SPEC §5.5는 Memory Pressure를 Memory 카드의 표현으로만 요구하고 메뉴바를 언급하지 않습니다.
  다섯 상태의 판정 규칙을 여기서 확정하는 이유가 후속 캐릭터 feature에 그릴 대상을 주기 위해서이므로,
  상태 사이의 우선순위는 그릴 대상이 정해질 때 함께 정하는 편이 맞습니다.

### DP9. Memory Pressure 획득 경로

- 옵션 A: `DispatchSource.makeMemoryPressureSource` 이벤트만 씁니다.
  전이를 즉시 알 수 있지만 수집이 중지된 상태에서도 값이 바뀌어
  "화면을 볼 수 없는 세 상태에서는 새 샘플이 쌓이지 않는다"는 SPEC §5.12와 어긋나는 경로가 생깁니다.
- 옵션 B: `kern.memorystatus_vm_pressure_level` 폴링만 씁니다.
  값이 다른 Memory 지표와 같은 샘플 시각에 묶이고 수집 일정 하나만 따르지만,
  전이 반영이 최대 한 주기 늦습니다.
- 옵션 C: 둘을 함께 씁니다.
  즉시성과 일관성을 모두 노리지만 두 경로의 값이 어긋날 수 있고 중지 상태 규칙이 경로마다 달라집니다.
- 채택안: 옵션 B.
  두 경로 모두 동작함이 확인됐으므로 선택 기준은 접근성이 아니라 일정 정책과의 정합성입니다.
  이 앱에서 압력 단계가 사용자에게 닿는 자리는 팝오버를 연 상태의 Memory 카드이고,
  그 시점에는 열림 주기가 1초라 최대 지연이 사용자 인지 범위 밖입니다.
  대신 수집 진입점이 하나로 유지되어 중지·재개 규칙과 실패 표현이 다른 지표와 같아집니다. SPEC §5.5를 성립시킵니다.

### DP10. 표시 상태를 보유하는 위치

- 옵션 A: 팝오버가 열릴 때 스토어에서 값을 가져옵니다.
  표시 계층이 상태를 갖지 않지만 actor 경계를 넘는 `await`가 필요해 첫 프레임이 비어 SPEC §5.9를 어깁니다.
- 옵션 B: 표시 계층이 항상 최신 표시 상태를 보유하고 수집 결과가 올 때마다 갱신합니다.
  팝오버가 닫혀 있어도 갱신 비용을 내지만 여는 순간 이미 값이 있습니다.
- 옵션 C: 팝오버가 닫히면 갱신을 멈추고 마지막 값만 남깁니다.
  닫힘 비용이 줄지만 다시 열었을 때 보이는 값이 닫은 시점의 값이라
  "마지막으로 수집된 값"이라는 SPEC §5.9의 문구와 어긋납니다.
- 채택안: 옵션 B.
  팝오버가 닫힌 상태에서도 수집은 감속해서 계속되므로(SPEC §5.12) 갱신을 멈출 이유가 없고,
  갱신 대상은 이미 계산된 값 몇 개와 그래프 점 배열 하나라 닫힘 주기에서 성능 목표에 영향을 주지 않습니다.
  표시 계층이 상태를 들고 있으면 SPEC §5.9가 구조로 보장되고 별도의 즉시 표시 경로를 만들 필요가 없습니다.

### DP11. 중지·재개 경계에서의 누적 차이 처리

- 옵션 A: Scheduler가 재개할 때 Collector에 기준점 재설정을 통지합니다.
  의도가 명시적이지만 `ScheduledSampleSource` 계약에 생명주기 개념이 들어가고 Scheduler가 상태를 하나 더 갖습니다.
- 옵션 B: Collector가 직전 원본의 시각과 새 샘플 시각의 간격을 보고,
  예상 주기의 배수를 넘으면 값을 만들지 않고 기준점만 갱신합니다.
  계약 변경 없이 Collector 안에서 닫히고, 중지·재개뿐 아니라 시스템 슬립 복귀와 긴 지연에도 같은 규칙이 적용됩니다.
- 옵션 C: 아무 처리도 하지 않습니다. 재개 첫 tick의 값이 중지 구간 전체의 평균이 되어
  "중지 전후 값이 이어 붙지 않는다"는 SPEC §5.11을 어깁니다.
- 채택안: 옵션 B.
  `docs/design.md`의 샘플 원칙이 이미 "허용 범위를 넘은 샘플은 새 기준점으로 처리한다"로 같은 방향을 정하고 있고,
  판정 근거가 샘플 시각 하나라 Collector가 자기 안에서 판단할 수 있습니다.
  spec.md 제외 범위의 "시스템 슬립 복귀 후 첫 샘플의 기준점 재설정"과 겹치지 않습니다.
  그 항목은 Network·Disk 속도 계산을 위한 별도 복귀 처리를 뒤로 미룬 것이고,
  여기서 다루는 것은 SPEC §5.11이 이 feature에 직접 요구한 중지 구간의 단절입니다.

### DP12. 디스플레이 슬립과 세션 활성의 초기값

- 옵션 A: 두 값을 "알 수 없음"으로 시작하고 알림이 올 때까지 수집을 중지합니다.
  안전 방향이지만 두 신호 모두 상태 변경 알림만 있어 이미 그 상태가 아니면 알림이 오지 않고,
  앱이 시작부터 영구히 중지됩니다. M1 DP6이 화면 잠금에서 같은 이유로 기각한 형태입니다.
- 옵션 B: 화면이 켜져 있고 세션이 활성인 상태로 시작하고 이후 알림으로 교정합니다.
  잘못된 가정으로 시작할 여지가 있지만 앱이 동작하지 않는 실패는 생기지 않습니다.
- 옵션 C: 문서화되지 않은 세션 사전 키로 초기 상태를 읽습니다.
  초기값이 정확해지지만 공개 알림만 쓰기로 한 spec.md의 확정 판단을 되돌리고 격리 대상이 늘어납니다.
- 채택안: 옵션 B.
  사용자가 앱을 실행하는 시점은 화면이 켜져 있고 그 세션이 활성인 시점이므로 가정이 실제와 어긋나기 어렵고,
  어긋나더라도 다음 알림이 교정합니다.
  M1이 잠금 키 부재를 `unlocked`로 읽으며 택한 것과 같은 판단 방향이며,
  두 신호가 공개 알림이라는 spec.md의 전제도 그대로 유지됩니다.

### DP13. 정확성 비교 절차와 허용 오차

- 옵션 A: Activity Monitor 하나와 비교합니다.
  사용자가 보는 기준과 같지만 프로세스 메모리 열이 Physical Footprint라
  Resident Memory를 쓰는 이 앱과 절대값이 구조적으로 다릅니다.
- 옵션 B: 지표에 따라 비교 대상을 나눕니다.
  시스템 전체 CPU·Memory 구성과 Swap은 Activity Monitor와, 프로세스 CPU와 Resident Memory는 `top`과 비교합니다.
  대상이 둘로 늘지만 각 지표가 같은 정의의 값과 비교됩니다.
- 옵션 C: 비교 절차를 M5로 미룹니다.
  이 feature의 부담이 줄지만 SPEC §5.3이 "정해진 비교 절차"를 완료 조건으로 두고 있어 충족 여부를 판정할 수 없습니다.
- 채택안: 옵션 B.
  `top`은 RSIZE 열로 Resident Memory를 그대로 보여주므로 이 앱이 쓰는 정의와 일치하고,
  Activity Monitor는 시스템 전체 지표에서 사용자가 실제로 참조하는 기준입니다.
  판정 기준은 다음으로 둡니다.
  변화 방향 일치는 모든 시나리오에서 필수이고,
  전체 CPU 사용률은 동시 관측에서 5%p 이내,
  Memory 구성 항목과 Swap은 10% 이내,
  프로세스 순위는 상위 3개 집합이 일치하는지로 봅니다.
  전체 물리 메모리는 정의가 하나뿐이므로 정확히 일치해야 합니다.
  각 시나리오를 3회 반복해 모두 만족해야 합니다.
  절대값 오차를 허용하는 이유는 §근거 추정에 적은 대로 `vm_statistics64` 카운터와 Activity Monitor 항목의 대응이
  공식 문서로 규정된 관계가 아니고, 두 도구의 샘플링 시점도 다르기 때문입니다.

### DP14. 상세 영역의 배치

- 옵션 A: 카드를 선택하면 팝오버가 커지며 상세가 나타납니다.
  요약 상태의 팝오버가 작지만 선택할 때마다 창 크기가 변해
  `docs/product.md`의 레이아웃 안정성 원칙과 어긋납니다.
- 옵션 B: 팝오버 크기를 고정하고 하단에 상세 영역을 항상 두며, 선택 전에는 안내를 표시합니다.
  요약 상태에서 공간을 쓰지만 선택·복귀에서 크기가 변하지 않고 상세가 항상 같은 자리에 나타납니다.
- 옵션 C: 상세를 별도 창으로 띄웁니다.
  공간 제약이 없어지지만 spec.md가 "고정된 영역"을 요구하고 별도 상세 창은 1.0 이후 후보입니다.
- 채택안: 옵션 B.
  SPEC §5.2가 "고정된 영역"과 "다시 선택하면 요약 상태로 복귀"를 함께 요구하므로,
  영역이 항상 존재하고 내용만 바뀌는 형태가 두 요구를 동시에 만족하는 가장 단순한 배치입니다.
  상세 내용이 영역보다 길면 그 영역만 스크롤해 팝오버 크기를 유지합니다.

### DP15. 카드 선택과 복귀의 키보드 수단

- 옵션 A: 카드를 표준 `Button` 그대로 두고, 선택과 복귀를 수행하는 키보드 단축키를 제공합니다.
  키보드 탐색 설정과 무관하게 항상 동작하므로 기본 설정 사용자도 SPEC §5.13을 만족하고,
  사용자가 키보드 탐색을 켜 둔 환경에서는 표준 `Button`이므로 Tab 이동도 자연히 동작합니다.
- 옵션 B: 카드 영역을 선택 가능한 목록으로 바꿔 키보드 탐색이 꺼져 있어도 Tab이 닿게 합니다.
  macOS다운 패턴이지만 DP14가 고정한 카드 배치를 목록 구조로 재설계해야 해서 비용이 큽니다.
- 옵션 C: 키보드 탐색이 켜진 환경을 전제합니다.
  비용은 없지만 기본 설정 사용자에게 SPEC §5.13이 성립하지 않아 `docs/product.md`의 접근성 요구에 어긋납니다.
- 채택안: 옵션 A.
  키보드 탐색이 기본 꺼짐이고 그 상태에서 Tab이 버튼에 닿지 않는다는 것을 실행 중인 앱에서 확인했으므로(§근거 확인 사실),
  Tab에 기대는 방식은 기본 설정 환경에서 SPEC §5.13을 성립시키지 못합니다.
  SPEC §5.13이 요구하는 것은 선택과 복귀를 키보드로 수행할 수 있다는 것이고 Tab이라는 수단을 지정하지 않으므로,
  단축키로 그 요구를 그대로 충족할 수 있습니다.
  DP14가 정한 카드 배치를 유지한 채 표준 컨트롤만 쓰므로 §1 구조에 미치는 영향이 없습니다.
  어떤 키 조합을 쓸지는 구현이 정하며, 단축키의 존재는 화면 표시와 카드 접근성 이름에서 확인할 수 있어야 합니다.
  Hover에만 두지 않는 이유는 `docs/product.md`가 중요한 정보를 Hover에만 의존하지 말라고 요구하기 때문입니다.

### DP16. 중지 상태가 표시 계층에 도달하는 경로

- 옵션 A: 일정이 멈추고 다시 시작하는 전이를 생명주기 경계에서 표시 저장소로 배선합니다.
  coordinator가 두 store를 이미 보유하므로 새 소유 관계 없이 경로 하나만 늘고,
  중지가 정지 구간 내내 유지됩니다.
- 옵션 B: 재개 첫 tick에서 CPU 값이 성립하지 않는다는 사실을 중지 신호로 씁니다.
  새 배선이 없지만 정지 "동안"이 아니라 재개 순간의 한 tick만 중지로 보이고,
  Memory Collector는 순간값 조회라 그 신호 자체가 없어 두 카드가 비대칭이 됩니다.
- 옵션 C: 카드 표시 상태에 중지 경우만 두고 트리거 배선은 뒤로 미룹니다.
  이 feature의 변경량이 줄지만 도달할 수 없는 상태가 남고,
  중지 상태의 조합을 검증하려 해도 그 상태를 만들 수단이 없어 무엇을 확인하는 검증인지 정해지지 않습니다.
- 채택안: 옵션 A.
  정지 구간에는 tick이 하나도 없어 카드 표시 상태 조립이 실행되지 않으므로(§근거 확인 사실),
  샘플 안의 값만으로는 중지를 만들 수 없습니다. 중지를 만들 수 있는 자리는 일정 결정 쪽뿐입니다.
  SPEC §5.10이 실패한 카드가 그 사실을 나타내라고 요구하고 SPEC §5.12가 화면을 볼 수 없는 세 상태에서
  새 샘플이 쌓이지 않는다고 정하므로, 둘이 함께 성립하려면 사용자가 보는 카드에서 중지와 실패가 갈라져야 합니다.
  §2 「실패 경로」가 정의한 중지의 뜻대로 동작하는 것은 옵션 A뿐입니다.
  대가는 생명주기에서 표시로 가는 경로가 하나 느는 것이며,
  방향이 한쪽뿐이고 표시 계층이 생명주기 store를 호출하지 않으므로 §1이 세운 경계 구분은 그대로입니다.
