# 메뉴바 앱과 모니터링 기반 구현

## 체크리스트

- [x] task-001: Dock 없는 메뉴바 셸과 transient 팝오버
  - 목적: 앱을 실행하면 Dock 아이콘과 일반 창 없이 고정 폭 메뉴바 항목이 나타나고,
    메뉴바 항목 클릭과 팝오버 외부 클릭을 반복해도 대시보드 팝오버의 실제 표시 상태와 다음 토글 동작이 어긋나지 않습니다.
  - 접근: `ResourceRunnerApp`을 `@NSApplicationDelegateAdaptor`와 `Settings { EmptyView() }` 구성으로 두고,
    `AppDelegate`가 강하게 보유하는 `ApplicationCoordinator`가 `NSStatusItem.squareLength`,
    `NSPopover(behavior: .transient)`와 `DashboardView`를 담은 `NSHostingController`를 소유하는
    `StatusBarController`를 한 번 구성합니다.
    생성 Info.plist의 `INFOPLIST_KEY_LSUIElement = YES`를 사용하고,
    자산 카탈로그 공유 인스턴스가 아닌 복사본에 18pt 크기를 적용해 22pt 자산을 메뉴바 글리프 크기로 표시합니다.
    여는 경로에서는 `NSApp.activate()`와 팝오버 창 `makeKey()`를 함께 호출해
    `LSUIElement` 앱에서도 `.transient`가 외부 클릭에서 닫을 계기를 얻게 하고,
    팝오버 delegate의 실제 표시·닫힘을 단일 소스로 삼아 클릭 토글과 `popoverPresented(Bool)` 출력을 연결합니다.
  - 검증 조건:
    - 결과: 프로세스 시작 시점부터 Dock 아이콘과 기본 창이 나타나지 않고 메뉴바 항목이 일정한 폭과 위치로 표시되며,
      메뉴바 아이콘이 인접한 시스템 메뉴바 항목과 같은 여백을 가진 18pt 글리프로 보입니다.
      메뉴바 클릭 → 열림, 외부 클릭 → 닫힘, 다시 클릭 → 열림을 5회 이상 반복해도
      `NSPopover.isShown`과 delegate가 보고한 표시 상태가 매번 일치하고 토글이 한 번도 반대로 동작하지 않습니다.
      팝오버 내용은 `DashboardView`의 M1 셸뿐이며 완성된 자원 카드는 없습니다.
    - 확인: `StatusBarController`의 고정 길이 설정, `.transient` behavior,
      delegate 기반 `popoverPresented(Bool)` 출력을 AppKit 통합 테스트로 확인하고,
      메뉴바 클릭과 반복 토글은 XCTest UI 테스트로 검증합니다.
      팝오버 외부 클릭 → 닫힘은 이 환경에서 자동화가 불가능한 것으로 두 차례 독립 확인됐습니다
      (UI 테스트의 시스템 메뉴바 밖 클릭이 팝오버에 도달하지 않고, in-process 합성 클릭은 SIGSEGV로 종료).
      따라서 이 항목은 macOS 26.5 Apple silicon에서 실행 앱을 띄운 채
      다른 앱 창 클릭과 바탕화면 클릭 각각에서 팝오버가 닫히는 것을 직접 관찰해 확인하며,
      이 관찰이 자동화 대체 근거입니다.
      생성 Info.plist의 `LSUIElement` 값은 `xcodebuild -showBuildSettings`와 빌드된 번들의 `Info.plist`로 확인합니다.
  - 참조: SPEC §5.1, SPEC §5.2, ANALYSIS §1 「애플리케이션 구성」, ANALYSIS §1 「표시 계층」,
    ANALYSIS §2 「앱 시작과 메뉴바 상호작용」, ANALYSIS §3 「팝오버와 접근성 계약」, ANALYSIS §5 DP1

- [x] task-012: 주입 상태에서 메뉴바 접근성 이름까지의 표시 경로
  - 목적: 낮음·보통·높음·매우 높음·장시간 고부하 상태를 주입하면 메뉴바 항목의 접근성 이름이 현재 상태를 포함하도록 바뀌고,
    그 이름이 실행 중인 앱의 접근성 트리에서 실제로 읽히며,
    상태가 바뀌어도 메뉴바 항목의 폭과 기준 위치, 열려 있던 팝오버는 흔들리지 않습니다.
  - 접근: `CharacterActivityState`의 다섯 상태와, 앱 이름에 상태 설명을 쉼표로 이어 하나의 접근성 이름을 만드는 순수 매핑을 담은
    `CharacterPresentation`, `AsyncStream`으로 상태를 제공하고 `send(_:)`로 주입하는 `CharacterStateSource`,
    `@MainActor render(_:)`만 가진 `CharacterPresentationSink`를 정의합니다.
    `ApplicationCoordinator`가 초기 상태를 읽어 첫 표현을 sink에 전달한 뒤 상태 stream 소비 Task를 `MainActor`에서 유지하고,
    sink 구현체인 `StatusBarController`는 메뉴바 버튼의 접근성 이름만 갱신하며 접근성 값은 설정하지 않습니다.
    실행 앱에서 상태를 바꿀 수 있도록 `#if DEBUG`로 격리한 우클릭 상태 메뉴를 `StatusBarController`에 두고
    고른 상태를 `CharacterStateSource.send(_:)`로만 넘깁니다.
    중간 표시 저장소는 두지 않고 버튼 이미지와 항목 길이는 구성 시점 값을 그대로 유지합니다.
  - 검증 조건:
    - 결과: 기본 실행은 `low`에서 시작하고, 메뉴바 항목의 접근성 이름은
      `low`→`ResourceRunner, 낮음`, `moderate`→`ResourceRunner, 보통`, `high`→`ResourceRunner, 높음`,
      `veryHigh`→`ResourceRunner, 매우 높음`, `sustainedHigh`→`ResourceRunner, 장시간 고부하`입니다.
      표시 경로는 메뉴바 항목의 접근성 값을 설정하지 않으며 상태 문자열은 접근성 이름 한 자리에만 존재합니다.
      다섯 상태를 임의 순서로 주입할 때마다 sink가 해당 상태의 표현을 한 번씩 받고,
      상태 변경 경로가 버튼 이미지·`NSStatusItem` 길이·팝오버 표시 상태를 건드리지 않아
      팝오버가 열린 채 상태가 바뀌어도 표시 상태가 그대로 유지됩니다.
      표시 경로는 팝오버 상태와 `SystemLifecycleSnapshot`을 입력으로 받지 않아
      잠금 신호를 해석하지 못하거나 저전력으로 바뀌어도 접근성 이름이 그대로 갱신됩니다.
      실행 중인 앱에서 이 접근성 이름이 접근성 클라이언트에 노출되고, Debug 주입으로 상태를 바꾸면 이름이 따라 바뀝니다.
      Debug 우클릭 주입 메뉴를 여는 동작은 메뉴바 항목 클릭이라 `NSPopover`가 외부 클릭으로 판정해 열려 있던 팝오버를 닫습니다.
      이는 주입 수단의 성질이며 표시 경로가 만든 변화가 아닙니다.
      Release 산출물에는 이 주입 진입점이 존재하지 않습니다.
      M1에서 다섯 상태를 구분하는 수단은 접근성 이름 하나뿐이며 이미지나 색상 차이는 사용하지 않습니다.
    - 확인: Swift Testing으로 다섯 상태 → 접근성 이름 매핑을 AppKit 없이 전수 검증하고,
      테스트 전용 sink로 상태 주입마다 전달되는 `CharacterPresentation` 순서와 횟수를 확인합니다.
      `StatusBarController`가 받은 값을 버튼 접근성 이름에 반영하고 접근성 값을 설정하지 않으며,
      상태를 다섯 번 순환시켜도 `NSStatusItem.length`와 버튼 이미지 참조가 변하지 않는 것은 AppKit 통합 테스트로 확인합니다.
      팝오버 열림 상태 보존은 같은 AppKit 통합 테스트에서 팝오버를 연 뒤 표시 경로만 실행해
      `NSPopover.isShown`이 유지되는 것으로 확인합니다 — 이 관찰은 주입 수단을 거치지 않으므로 우클릭 메뉴의 닫힘과 무관합니다.
      표시 계약에 팝오버 상태와 생명주기 snapshot이 없는 것은 타입 시그니처로 확인합니다.
      실행 앱의 노출은 XCUITest로 확인합니다 — `app.statusItems.firstMatch`의 접근성 이름이
      기동 직후 `ResourceRunner, 낮음`이고, Debug 우클릭 메뉴로 다른 상태를 주입하면 그 상태의 이름으로 바뀌는 것을
      다섯 상태 전부에 대해 단언합니다. 이 UI 테스트는 팝오버 열림 유지를 관찰 대상으로 두지 않습니다.
      주입 진입점의 Release 부재는 `#if DEBUG` 격리를 소스 검색으로 확인합니다.
      VoiceOver의 실제 낭독은 spec.md 제외 범위이므로 이 Task에서 확인하지 않습니다.
  - 참조: SPEC §5.3, ANALYSIS §1 「표시 계층」, ANALYSIS §1 「상태와 동시성 경계」,
    ANALYSIS §2 「주입 상태와 접근성 표현」, ANALYSIS §3 「캐릭터 표시 계약」,
    ANALYSIS §3 「팝오버와 접근성 계약」, ANALYSIS §5 DP12

- [x] task-008: 메모리 전용 최근 샘플 순환 버퍼
  - 목적: 실제로 수집된 최근 샘플만 시간 범위와 수집 주기에 맞는 고정 용량으로 메모리에 유지하고,
    용량을 넘으면 가장 오래된 샘플만 사라지며 존재하지 않는 과거 데이터를 만들어내지 않습니다.
  - 접근: 단조 증가 시각과 값을 묶는 `TimestampedSample`,
    `ceil(시간 범위 / 유효 수집 주기)`로 양의 고정 용량을 계산하는 순수 `HistoryCapacity`,
    고정 저장 공간·다음 쓰기 위치·현재 개수만 가지고 O(1) 추가와 교체를 하는 값 타입 `CircularBuffer<Element>`를 구현합니다.
    actor `MonitoringSampleStore`만 append·시간순 snapshot·resize를 수행하고 가변 버퍼 참조를 밖으로 내보내지 않으며,
    M1 기본 시간 범위 10분은 상수로 두고 범위 변경은 저장소 API로만 노출합니다.
  - 검증 조건:
    - 결과: 기본 시간 범위 10분에서 용량은 1초 주기 600개, 2초 300개, 5초 120개이고,
      나누어떨어지지 않는 주기에서는 올림 결과를 사용하며 결과는 항상 1 이상입니다.
      append가 용량을 넘으면 가장 오래된 항목 하나만 교체되고 읽기는 wrap-around 전후 모두 오래된 것부터 시간순입니다.
      용량이 줄어드는 resize는 최신 항목만 보존하고, 늘어나는 resize는 새 공간을 채우지 않습니다.
      빈 버퍼는 빈 결과를 반환하고 첫 샘플은 그대로 현재 데이터가 되며 이전 구간이나 변화량을 만들지 않습니다.
      샘플과 버퍼는 프로세스 메모리에만 존재하고 파일·`UserDefaults`·네트워크 경로와 재시작 복원 경로가 없습니다.
    - 확인: Swift Testing으로 10분 × 1·2·5초의 600·300·120 용량,
      나누어떨어지지 않는 주기의 올림, 용량 경계 직전·직후·연속 초과 append,
      wrap-around 전후 순서, 축소·확대 resize의 최신 항목 보존과 빈 공간 미충전,
      빈 버퍼와 첫 샘플을 검증합니다.
      actor 외부로 가변 버퍼 참조가 노출되지 않는지는 API 시그니처로 확인하고,
      영구 저장·외부 전송 경로 부재는 `UserDefaults`·`FileManager`·`URLSession` 소스 검색과 diff로 확인합니다.
  - 참조: SPEC §5.6, ANALYSIS §1 「최근 데이터 경계」, ANALYSIS §2 「샘플과 순환 버퍼」,
    ANALYSIS §3 「최근 데이터 계약」, ANALYSIS §5 DP5

- [x] task-005: 시스템 생명주기 관찰과 combined snapshot 병합
  - 목적: 저전력 모드와 화면 잠금 상태를 하나의 관찰 지점에서 읽어,
    앱 시작 도중에 상태가 바뀌어도 두 값의 최신 조합이 유실되거나 오래된 값으로 되돌아가지 않고 소비자에게 전달됩니다.
  - 접근: `ScreenLockState`, `SystemLifecycleSnapshot`, `SystemLifecycleSubscription`, `SystemLifecycleSource` 계약과
    자동 테스트용 메모리 구현을 먼저 두고,
    `SystemLifecycleObserver`가 stream과 내부 직렬 생산자를 만든 뒤 저전력 관찰자와
    주입받은 잠금 신호 관찰자를 모두 등록하고 마지막에 초기값을 읽도록 구현합니다.
    저전력은 `NSNotification.Name.NSProcessInfoPowerStateDidChange`와 `ProcessInfo.isLowPowerModeEnabled`를 사용하고,
    snapshot 변경마다 revision을 증가시켜 `.bufferingNewest(1)` stream으로 제공합니다.
  - 검증 조건:
    - 결과: `start()`는 stream 생성 → 관찰자 등록 → 초기값 조회 순서로 진행하고
      `SystemLifecycleSubscription` 하나를 반환합니다.
      등록 뒤 초기 조회가 끝나기 전에 도착한 callback은 버려지지 않고 initial 값 위에 도착 순서대로 반영됩니다.
      initial snapshot의 revision은 0이고 이후 변경마다 증가하며, 값이 같은 연속 snapshot은 제거됩니다.
      소비가 밀리면 저전력과 화면 잠금을 함께 담은 최신 combined snapshot 하나만 남고,
      한 필드의 갱신이 다른 필드의 최신값을 이전 값으로 되돌리지 않습니다.
      observer는 `MainActor`에서 token·캐시·현재 snapshot을 소유하며 다른 queue의 callback은 직렬 생산자를 거칩니다.
    - 확인: 메모리 `SystemLifecycleSource`와 주입 잠금 신호로 Swift Testing 검증을 작성합니다 —
      등록과 초기 조회 사이에 도착한 저전력·잠금 callback의 병합 순서,
      revision 증가와 동일 snapshot 제거,
      소비 지연 시 `.bufferingNewest(1)`의 최신 조합 보존을 각각 확인합니다.
      `NSNotification.Name.NSProcessInfoPowerStateDidChange` 심볼 사용은 빌드로 확인하고,
      존재하지 않는 `ProcessInfo.powerStateDidChangeNotification`을 쓰지 않았는지 소스 검색으로 확인합니다.
  - 참조: SPEC §5.4, ANALYSIS §1 「상태와 동시성 경계」, ANALYSIS §2 「수집 일정과 생명주기」,
    ANALYSIS §3 「수집 일정 계약」, ANALYSIS §5 DP8

- [x] task-009: 수집 일정 정책과 단일 Scheduler
  - 목적: 팝오버 열림·닫힘, 저전력 모드와 화면 잠금 상태가 바뀌면 최신 조합에 맞는 수집 일정 하나만 적용되고,
    같은 상태가 반복해서 들어와도 중복 수집이 일어나지 않습니다.
  - 접근: actor `MonitoringLifecycleStore`가 `MonitoringLifecycleEvent`를 단일 `update(_:)`로 직렬화하며
    최종 snapshot·마지막 system revision·마지막 적용 일정을 소유하고,
    순수 `CollectionSchedulePolicy`가 `CollectionScheduleDefinition`과 snapshot에서
    `running(interval)` 또는 `paused`를 계산합니다.
    계산 결과가 마지막 적용 결과와 다를 때만 actor `MonitoringScheduler.apply(_:)`를 호출하고,
    Scheduler는 단일 Task와 generation, 주입 가능한 `MonotonicClock` 기준 deadline만 소유하며
    `ScheduledSampleSource`가 준 유효 샘플을 `MonitoringSampleStore`에 한 번 전달합니다.
    잠금 입력은 메모리 `SystemLifecycleSource`로 주입받아 실제 OS 어댑터 없이 이 Task를 완료·검증합니다.
  - 검증 조건:
    - 결과: `unlocked`에서 normal은 팝오버 열림 1초·닫힘 2초, lowPower는 열림 2초·닫힘 5초를 적용합니다.
      `locked` 또는 `unknown`은 팝오버·전력과 무관하게 `paused`입니다.
      store는 최초 revision은 적용하고 이후에는 마지막 system revision보다 작거나 같은 snapshot을 거부합니다.
      같은 결과를 만드는 이벤트가 반복 도착해도 `apply(_:)`가 다시 호출되지 않고 실행 중인 작업이 재시작되지 않아
      중복 수집이 발생하지 않습니다.
      일정이 바뀌면 기존 작업을 취소하고 새 generation 하나만 시작하며,
      간격은 마지막 실행 완료 시점이 아니라 기준 deadline을 전진시켜 계산합니다.
      pause는 작업만 취소하고 버퍼와 용량을 그대로 두며 resize하지 않습니다.
      resume은 새 유효 주기로 버퍼를 resize한 뒤 새 generation을 시작하고 중지 동안 놓친 실행을 따라잡지 않습니다.
      취소되었거나 이전 generation인 결과, 공급자 실패는 저장되지 않고 0 샘플로 바뀌지 않습니다.
    - 확인: 메모리 `SystemLifecycleSource`, 수동 `MonotonicClock`, 주입 `ScheduledSampleSource` 기반 Swift Testing으로
      팝오버 열림·닫힘 × normal·lowPower × `locked`·`unlocked`·`unknown` 조합의 일정 선택을 전수 검증합니다.
      같은 일정 반복 이벤트에서 `apply(_:)` 호출 횟수와 누적 샘플 수를 세어 중복 수집 부재를 확인하고,
      낮거나 같은 revision의 거부, 일정 교체 시 이전 generation 결과 폐기, 기준 deadline 전진,
      pause 중 버퍼·용량 유지, resume 시 10분 기준 새 주기 용량(1초 600·2초 300·5초 120)으로의 resize와 미따라잡기,
      공급자 실패·취소가 0 샘플을 만들지 않는 것을 각각 검증합니다.
      pause 중 버퍼 유지는 시계를 전진시켜 실제 샘플을 쌓은 뒤 pause하고 값 배열이 그대로인지 확인해
      용량뿐 아니라 내용 보존까지 관찰합니다.
      반복 이벤트의 중복 수집 부재는 `apply(_:)` 호출 횟수와 함께 시계를 전진시키며
      누적 샘플이 정확히 tick 수만큼만 늘어나는지 세어 확인합니다.
      다만 이전 generation 결과를 폐기하는 가드는 결정론적 회귀 방어가 없습니다.
      취소 검사가 모든 결정론적 경로를 선점해 가드를 제거해도 실패하는 테스트가 없으며,
      실측 stress 400회에서 가드 발동이 0회였습니다.
      actor hop 사이에 실제 창이 존재하므로 죽은 코드가 아닌 방어 심층으로 남기되,
      이 공백은 task-011의 실행 앱 통합 관찰에서 함께 확인합니다.
  - 참조: SPEC §5.4, SPEC §5.6, ANALYSIS §1 「상태와 동시성 경계」, ANALYSIS §2 「수집 일정과 생명주기」,
    ANALYSIS §3 「수집 일정 계약」, ANALYSIS §5 DP4

- [ ] task-006: macOS 26.5 화면 잠금 어댑터
  - 목적: 실제 화면 잠금과 해제가 일어나면 앱이 잠금 상태 변화를 곧바로 알아차리고,
    잠금 직후 곧바로 해제하는 짧은 순환에서도 해제를 놓치지 않으며,
    잠금 신호를 해석하지 못하는 상황에서도 앱이 계속 동작합니다.
  - 접근: 문서화되지 않은 알림 이름 `com.apple.screenIsLocked`·`com.apple.screenIsUnlocked`와
    세션 사전 키 문자열 `"kCGSSessionUserIDKey"`·`"CGSSessionScreenIsLocked"`를
    `ScreenLockStateReader`와 `SystemLifecycleObserver` 하나의 어댑터 경계에만 둡니다.
    세션 사전은 시작 시 초기 잠금 상태와 세션 사용자 ID 조회에만 쓰고,
    알림 처리 경로에서는 사전을 다시 읽지 않고 notification 이름을 그대로 신뢰합니다.
    알림 object 문자열과 캐시한 세션 사용자 ID는 각각 정수로 정규화한 뒤 비교합니다.
  - 검증 조건:
    - 결과: `ScreenLockStateReader`는 세션 사전을 주입받아 세 값을 반환합니다 —
      잠금 키가 Boolean `true`면 `locked`,
      Boolean `false`이거나 **잠금 키가 사전에 없으면** `unlocked`,
      사전이 `nil`이거나 잠금 키를 Boolean으로 해석할 수 없으면 `unknown`.
      알림 처리는 이름만으로 후보 값을 정하고, object와 캐시 UID가 둘 다 정수로 해석되며 값이 다를 때만 무시합니다.
      어느 한쪽이라도 정수로 해석되지 않으면 알림 이름을 그대로 적용합니다.
      알림을 받은 뒤 세션 사전을 다시 읽는 경로는 존재하지 않습니다.
      실제 macOS 26.5 Apple silicon에서 화면을 잠그면 snapshot이 `locked`로, 해제하면 `unlocked`로 바뀝니다.
      문서화되지 않은 이름과 키 문자열은 이 어댑터 밖에 존재하지 않고,
      나머지 계층과 자동 테스트는 `SystemLifecycleSource` 계약만 사용합니다.
    - 확인: 세션 사전 입력을 주입한 Swift Testing으로 `ScreenLockStateReader`의 네 경우
      (`true`, `false`, 잠금 키 부재, 사전 `nil`)와 비Boolean 값의 `unknown` 매핑을 검증합니다.
      알림 처리는 UID 일치·불일치·object 해석 실패·캐시 UID 부재 조합을 주입해
      이름 적용과 무시 판정을 검증하고, 해제 알림이 사전 값 때문에 폐기되지 않는지 확인합니다.
      실제 잠금·해제 반영은 macOS 26.5 Apple silicon에서 앱을 실행한 채 화면을 잠그고 해제해
      snapshot 전이 로그로 `locked`·`unlocked`를 확인합니다.
      이름과 키 문자열의 격리는 소스 전체 검색으로 확인합니다.
  - 참조: SPEC §5.5, ANALYSIS §2 「수집 일정과 생명주기」, ANALYSIS §3 「수집 일정 계약」,
    ANALYSIS §5 DP6, ANALYSIS §5 DP9

- [ ] task-010: 실제 잠금·해제에서의 수집 중지와 재개
  - 목적: 실제 macOS 화면 잠금에서 수집이 멈추고 해제하면 다시 시작하며,
    잠근 직후 곧바로 해제하는 짧은 순환에서도 수집이 멈춘 채 남지 않습니다.
  - 접근: 어댑터가 만든 실제 `SystemLifecycleSnapshot`을 생명주기 store와 Scheduler까지 연결한 구성으로 앱을 실행하고,
    잠금·해제 전이와 그때 적용된 일정, 누적 샘플 수와 버퍼 용량을 관찰 가능한 형태로 남겨 실제 OS 조작으로 확인합니다.
  - 검증 조건:
    - 결과: macOS 26.5 Apple silicon에서 화면을 잠그면 수집 일정이 `paused`로 바뀌어 새 샘플이 늘지 않고,
      해제하면 잠금 이전 팝오버·전력 조합에 해당하는 일정으로 재개되어 샘플이 다시 쌓입니다.
      잠금 후 5초 내외에 해제하는 짧은 순환을 5회 반복해도 매번 재개되며,
      해제 알림이 세션 사전의 지연 갱신 때문에 폐기되어 pause에 갇히는 경우가 한 번도 발생하지 않습니다.
      1분 이상 유지되는 긴 잠금에서도 해제 시 재개됩니다.
      resume 시 버퍼는 새 유효 주기 용량으로 resize되고 중지 동안 놓친 샘플을 만들어내지 않습니다.
      잠금·해제 중에도 메뉴바 항목과 팝오버는 계속 동작합니다.
    - 확인: macOS 26.5 Apple silicon에서 앱을 실행한 채 실제 화면 잠금·해제를 수행하고,
      적용 일정 전이와 샘플 수 변화를 로그로 기록해 pause·resume 시점과 간격을 확인합니다.
      5초 내외의 짧은 순환 5회와 1분 이상 유지되는 긴 잠금 1회를 각각 수행해 두 경우 모두 재개되는지 확인하고,
      순환 도중 메뉴바 항목 클릭과 팝오버 열림·닫힘을 직접 관찰합니다.
      resume 후 버퍼 용량과 샘플 연속성은 같은 실행에서 저장소 snapshot으로 확인합니다.
  - 참조: SPEC §5.5, ANALYSIS §2 「수집 일정과 생명주기」, ANALYSIS §4 「테스트 대상」,
    ANALYSIS §5 DP6, ANALYSIS §5 DP9

- [ ] task-011: M1 production 구성과 지원·산출물 정책
  - 목적: macOS 26.5 이상 Apple silicon에서 ResourceRunner 메인 앱 하나만 실행하면
    메뉴바·팝오버·접근성 표현·생명주기 일정·최근 샘플 기반이 함께 동작하고,
    M1 디버그 빌드와 자동 테스트가 성공하며 추가 상주 실행 파일이 만들어지지 않습니다.
  - 접근: `ApplicationCoordinator`가 `StatusBarController`, `CharacterStateSource`와 표시 sink 연결,
    `SystemLifecycleObserver`, 생명주기 store, Scheduler, M1 샘플 source와 샘플 store를 각각 한 번 만들어
    분석이 정한 시작 순서와 단일 방향 흐름으로 연결하고 종료까지 강하게 보유합니다.
    앱·단위 테스트·UI 테스트 대상의 Debug·Release deployment target을 26.5로 통일하고
    앱 실행 파일 아키텍처를 arm64로 제한하며,
    생성 Info.plist의 `LSUIElement = YES`와 기존 App Sandbox를 유지합니다.
  - 검증 조건:
    - 결과: production 앱은 system initial snapshot과 초기 `popoverPresented = false`를 적용하기 전에는
      Scheduler를 시작하지 않고, 이후 update stream을 소비해 생명주기 store에 전달합니다.
      표시 계층은 수집 actor를 호출하지 않고 수집 actor도 표시 계층을 호출하지 않으며,
      팝오버 상태는 수집 일정에만 반영되고 메뉴바 표현의 입력이 아닙니다.
      실제 Collector, 설정 영구 저장, 로그인 항목, 외부 package, Helper, 추가 실행 대상이 추가되지 않습니다.
      세 대상 모두 macOS 26.5를 최소 버전으로 사용하고,
      Debug·Release 앱 아키텍처 설정과 빌드된 실행 파일이 arm64 단일 슬라이스이며,
      생성 Info.plist에 `LSUIElement = YES`가 있고 App Sandbox가 유지됩니다.
      앱 번들 `Contents/MacOS`에는 ResourceRunner 실행 파일 하나만 있고 로그인 항목·Helper 위치는 비어 있습니다.
      M1 Debug 빌드와 Swift Testing·XCTest 전체가 성공합니다.
      production 배선은 실제 시스템 값을 읽습니다 — 저전력은 `ProcessInfo.isLowPowerModeEnabled`,
      알림은 기본 `NotificationCenter`를 사용하며 테스트용 대체 구현이 배선에 남지 않습니다.
    - 확인: macOS 26.5 Apple silicon에서 격리된 DerivedData로 Debug 빌드와 전체 테스트를 실행해 성공을 확인합니다.
      `xcodebuild -showBuildSettings`로 세 대상의 deployment target, Debug·Release 앱 아키텍처와
      생성 Info.plist 설정을 확인하고,
      빌드된 번들의 `Info.plist`, `lipo -archs` 또는 `file`의 실행 파일 아키텍처,
      `Contents/MacOS`와 `Contents/Library/LoginItems` 목록,
      `project.pbxproj`의 native target·package 목록과 최종 diff를 검사합니다.
      실행 앱에서는 Dock 없음, 안정적인 메뉴바 항목, 반복 팝오버 토글,
      다섯 상태의 접근성 이름 전환이 한 세션 안에서 함께 동작하는지 통합 관찰합니다.
      구성 방향과 계층 간 호출 금지는 coordinator 초기화 순서 테스트와 소스 검색으로 확인합니다.
      `SystemLifecycleObserver`의 production 기본 인자(`readLowPowerMode`, `notificationCenter`)는
      자동 테스트가 항상 값을 주입하므로 실행되지 않아 회귀 방어가 없습니다.
      task-005 검증 중 변이 테스트로 확인된 공백이며, 여기서 배선을 소스로 확인하고
      실기기에서 저전력 모드를 켜고 끄며 수집 일정이 실제로 바뀌는지 직접 관찰해 메웁니다.
      `MonitoringScheduler`의 이전 generation 결과 폐기 가드도 같은 성격의 공백입니다.
      취소 검사가 모든 결정론적 경로를 선점해 가드를 제거해도 실패하는 테스트가 없으므로,
      실행 앱에서 일정이 자주 바뀌는 상황을 만들어 오래된 샘플이 섞이지 않는지 함께 관찰합니다.
  - 참조: SPEC §5.1, SPEC §5.7, SPEC §5.8, ANALYSIS §1 「애플리케이션 구성」, ANALYSIS §1 「상태와 동시성 경계」,
    ANALYSIS §2 「앱 시작과 메뉴바 상호작용」, ANALYSIS §3 「빌드와 산출물 계약」,
    ANALYSIS §4 「프로젝트 설정과 대상」, ANALYSIS §4 「저장과 외부 경계」, ANALYSIS §5 DP7
