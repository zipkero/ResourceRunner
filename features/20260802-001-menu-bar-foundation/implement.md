# 메뉴바 앱과 모니터링 기반 구현

## 체크리스트

- [ ] task-001: Dock 없는 메뉴바 셸과 transient 팝오버
  - 목적: 앱을 실행하면 Dock 아이콘과 일반 창 없이 고정 폭 메뉴바 항목이 나타나고,
    메뉴바 항목 클릭과 팝오버 외부 클릭을 반복해도 대시보드 팝오버의 실제 표시 상태와 다음 토글 동작이 어긋나지 않습니다.
  - 접근: `ResourceRunnerApp`을 `@NSApplicationDelegateAdaptor`와 `Settings { EmptyView() }` 구성으로 바꾸고,
    `AppDelegate`가 강하게 보유하는 `ApplicationCoordinator`가 `NSStatusItem.squareLength`,
    `NSPopover(behavior: .transient)`와 SwiftUI `NSHostingController`를 소유하는 `StatusBarController`를 한 번 구성합니다.
    생성 Info.plist의 `LSUIElement = YES`를 사용하고,
    팝오버 delegate의 실제 표시·닫힘을 단일 소스로 삼아 클릭 토글과 `popoverPresented(Bool)` 출력을 연결합니다.
  - 검증 조건:
    - 결과: 프로세스 시작 시점부터 Dock 아이콘과 기본 창이 나타나지 않고 메뉴바 항목이 일정한 폭과 위치로 표시됩니다.
      메뉴바 클릭 → 열림, 외부 클릭 → 닫힘, 다시 클릭 → 열림을 5회 이상 반복해도
      `NSPopover.isShown`과 delegate가 보고한 표시 상태가 매번 일치하고 토글이 한 번도 반대로 동작하지 않습니다.
      팝오버 내용은 M1 대시보드 셸뿐이며 완성된 자원 카드는 없습니다.
    - 확인: `StatusBarController`의 고정 길이 설정, `.transient` behavior,
      delegate 기반 `popoverPresented(Bool)` 출력을 AppKit 통합 테스트로 확인합니다.
      메뉴바 클릭·반복 토글·외부 클릭은 XCTest UI 테스트로 검증하고,
      시스템 메뉴바 자동화가 안정적이지 않은 구간은 macOS 26.5 Apple silicon에서 실행 앱의 Dock·메뉴바·팝오버를 직접 관찰합니다.
      생성 Info.plist의 `LSUIElement` 값은 `xcodebuild -showBuildSettings`와 빌드된 번들의 `Info.plist`로 확인합니다.
  - 참조: SPEC §5.1, SPEC §5.2, ANALYSIS §1 「애플리케이션 구성」, ANALYSIS §1 「표시 계층」,
    ANALYSIS §2 「앱 시작과 메뉴바 상호작용」, ANALYSIS §3 「팝오버와 접근성 계약」, ANALYSIS §5 DP1

- [ ] task-002: 상태별 캐릭터 자산 제작과 카탈로그 등록
  - 목적: 다섯 표시 상태 각각의 정적 얼굴과 최소 두 애니메이션 프레임이
    현재 기본 고양이와 같은 캐릭터로 읽히면서 1x와 2x 모두에서 색상이 아닌 형태로 서로 구분되는 자산으로 존재하고,
    앱이 단일 이름 규칙으로 이 자산을 꺼내 쓸 수 있습니다.
  - 접근: 현재 `StatusCatStatic`의 얼굴 외곽과 귀를 기준 형태로 삼아
    `low`·`moderate`·`high`·`veryHigh`·`sustainedHigh`의 정적 얼굴 5종과 상태별 전신 애니메이션 프레임 2종씩을 그립니다.
    모든 자산은 같은 22pt 캔버스, 같은 기준선과 시각적 중심 위에 배치하고
    1x 22×22px, 2x 44×44px template image imageset으로 `Assets.xcassets`에 등록하며,
    상태와 프레임 인덱스를 담는 단일 이름 규칙을 정해 `CharacterAssetCatalog` 안에서만 참조되게 합니다.
  - 검증 조건:
    - 결과: 정적 얼굴 5종과 애니메이션 프레임 10종, 합계 15종의 imageset이 각각 1x 22×22px와 2x 44×44px 슬롯을 모두 채우고
      `template-rendering-intent`로 등록되어 있습니다.
      template image이므로 상태 구분에 색상을 쓸 수 없고, 다섯 정적 얼굴은 단일 색으로 렌더해도 형태만으로 구분됩니다 —
      `low`는 편안한 눈, `moderate`는 열린 눈과 기본 입, `high`는 집중한 눈,
      `veryHigh`는 크게 뜬 눈과 열린 입, `sustainedHigh`는 처진 눈과 피로 표시를 가집니다.
      15종 전부에서 알파 bounding box의 하단 기준선과 좌우 중심이 1x 기준 1px 이내로 일치해
      프레임을 교체해도 캐릭터가 위아래·좌우로 밀리지 않습니다.
      다섯 정적 얼굴은 바깥 얼굴선의 폭 대 높이 비율과 두 귀 꼭짓점 위치가 현재 `StatusCatStatic`과 1x 기준 1px 이내로 같아
      같은 캐릭터로 읽힙니다.
      자산 이름 문자열은 `CharacterAssetCatalog` 밖 어디에도 나타나지 않습니다.
    - 확인: 자산 로딩 단위 테스트로 15종이 모두 `nil`이 아니고 1x·2x 표현과 template rendering intent를 갖는지 확인합니다.
      각 이미지의 알파 bounding box를 계산하는 테스트로 기준선·중심 편차와
      `StatusCatStatic` 대비 얼굴 비율·귀 위치 편차를 수치로 확인합니다.
      형태 구분은 다섯 정적 얼굴을 1x 실제 크기와 2x 크기로 각각 무작위 순서로 나란히 렌더한 뒤
      상태 이름 다섯 개와 짝지어 두 크기 모두에서 5개 중 5개를 맞히는 블라인드 매칭으로 판정합니다.
      이름 규칙 격리는 자산 이름 문자열에 대한 소스 전체 검색으로 확인합니다.
  - 참조: SPEC §5.3, SPEC §5.4, ANALYSIS §1 「표시 계층」, ANALYSIS §2 「주입 상태와 캐릭터 전환」,
    ANALYSIS §3 「캐릭터 표시 계약」, ANALYSIS §4 「기존 애플리케이션」, ANALYSIS §5 DP2

- [ ] task-003: 주입 상태에 따른 캐릭터 프레임 전환
  - 목적: 낮음·보통·높음·매우 높음·장시간 고부하 상태를 주입하면 메뉴바 캐릭터가 상태별 FPS로 애니메이션하고,
    상태가 바뀌어도 메뉴바 항목의 폭과 기준 위치, 팝오버 열림 상태가 흔들리거나 깜빡이지 않습니다.
  - 접근: `CharacterStateSource → ApplicationCoordinator → CharacterPresentationStore → CharacterPresentationSink` 흐름을
    `MainActor`에 구현하고 `StatusBarController`가 sink로서 버튼 이미지만 교체하게 합니다.
    상태별 기본·저전력 FPS와 선로딩 프레임을 담는 `CharacterPresentationProfileSet`을 표시 계층 바깥에서 주입받고,
    순수 `CharacterFrameRateLimit`가 FPS를 1...12로 클램프하며 구성 검증이 초과 항목을 보고합니다.
    프레임 일정은 주입 가능한 `CharacterFrameClock` 위에서 하나만 유지하고,
    자산 Task 이전에는 임시 프로필로 로직을 선행 구현할 수 있으나 완료 판정은 production 카탈로그로 합니다.
  - 검증 조건:
    - 결과: 기본 실행은 `low`에서 시작하고 다섯 상태가 각각 2·4·8·10·6 FPS로 실행되며,
      `sustainedHigh`는 `veryHigh`보다 낮은 6 FPS를 씁니다.
      상태가 바뀌면 기존 프레임 일정이 취소되고 현재 프레임이 새 상태의 첫 프레임으로 치환된 단일 일정 하나만 남습니다.
      테스트가 13 이상의 FPS를 담은 프로필 집합을 구성하면 실제 프레임 간격이 12 FPS를 넘지 않도록 클램프되고
      구성 검증이 해당 항목을 초과로 보고합니다. 기본 프로필의 최대값은 10이므로 기본 구성에서는 클램프가 발생하지 않습니다.
      production 카탈로그가 다섯 상태의 정적 얼굴과 상태별 최소 두 프레임을 메뉴바 표시 전에 모두 선로딩합니다.
      필수 자산이 누락되면 초기 구성 실패로 기록하고 기본 `StatusCatStatic`과 실패 접근성 값으로 후퇴하지만,
      이 fallback이 활성인 상태는 완료로 처리하지 않습니다.
      프레임이 교체되는 동안 메뉴바 항목의 폭과 기준 위치가 변하지 않고 열려 있던 팝오버가 닫히지 않습니다.
    - 확인: Swift Testing과 수동 `CharacterFrameClock`으로 다섯 상태의 초기 프레임, 프레임 간격,
      상태 변경 시 기존 일정 취소와 단일 일정 유지, sink 약한 참조와 `MainActor` 렌더링을 검증합니다.
      12 FPS 상한은 13·20·100 FPS를 포함한 초과 프로필 집합을 테스트가 구성해
      클램프된 간격과 초과 보고 목록을 관찰하는 방식으로 검증합니다.
      카탈로그 선로딩과 누락 시 실패 기록·fallback은 자산 주입 테스트로 확인합니다.
      메뉴바 폭·기준 위치·팝오버 유지는 AppKit 통합 테스트와 상태를 순환시키며 실행 앱을 관찰하는 방식으로 확인합니다.
  - 참조: SPEC §5.3, ANALYSIS §1 「표시 계층」, ANALYSIS §1 「상태와 동시성 경계」,
    ANALYSIS §2 「주입 상태와 캐릭터 전환」, ANALYSIS §3 「캐릭터 표시 계약」, ANALYSIS §5 DP3, ANALYSIS §5 DP11

- [ ] task-004: 정적 표현과 VoiceOver 접근성
  - 목적: 동작 줄이기가 켜져 있거나 애니메이션이 비활성화되면 캐릭터 애니메이션이 멈추고,
    사용자가 같은 다섯 상태를 정적 모양과 VoiceOver 설명으로 구분할 수 있습니다.
  - 접근: `NSWorkspace.accessibilityDisplayShouldReduceMotion`의 현재값과 접근성 표시 옵션 변경 알림을
    `CharacterMotionMode`의 `reduceMotion`으로 반영하고, `disabled`는 M1에서 주입 가능한 정책으로 제공합니다.
    정지 모드에서는 프레임 일정을 만들지 않고 현재 상태의 정적 얼굴만 표시하며,
    접근성 label과 value를 표시 모드와 무관하게 현재 상태에서 파생시킵니다.
  - 검증 조건:
    - 결과: `reduceMotion` 또는 `disabled`에서는 프레임 일정이 생성되지 않고 현재 상태의 정적 얼굴이 표시됩니다.
      정지 상태에서 상태가 바뀌면 일정을 만들지 않고 정적 얼굴과 접근성 값만 갱신됩니다.
      접근성 label은 `ResourceRunner`이고 value는 `낮음`·`보통`·`높음`·`매우 높음`·`장시간 고부하` 중 현재 상태와 일치하며,
      `animated`와 정지 모드 사이를 오가도 상태와 value는 유지되고 이미지만 바뀝니다.
      다섯 정적 얼굴은 1x와 2x 모두에서 색상이 아닌 형태로 서로 구분됩니다.
    - 확인: Swift Testing으로 `animated`·`reduceMotion`·`disabled` 각각의 프레임 일정 유무,
      정지 중 상태 변경 시 일정 미생성과 정적 얼굴·value 갱신,
      모드 전환 전후 상태·value 보존을 검증합니다.
      동작 줄이기 알림 반영은 주입한 접근성 정책 값으로 검증합니다.
      실제 VoiceOver label·value는 macOS 26.5에서 시스템 설정의 동작 줄이기를 켠 채
      다섯 상태를 순환시키며 접근성 검사 도구와 VoiceOver로 직접 확인합니다.
      1x·2x 형태 구분은 task-002의 블라인드 매칭 결과를 실행 앱의 메뉴바 렌더링에서 재확인합니다.
  - 참조: SPEC §5.4, ANALYSIS §1 「표시 계층」, ANALYSIS §2 「주입 상태와 캐릭터 전환」,
    ANALYSIS §3 「캐릭터 표시 계약」, ANALYSIS §3 「팝오버와 접근성 계약」, ANALYSIS §5 DP2

- [ ] task-005: 시스템 생명주기 관찰과 combined snapshot 병합
  - 목적: 저전력 모드와 화면 잠금 상태를 하나의 관찰 지점에서 읽어,
    앱 시작 도중에 상태가 바뀌어도 두 값의 최신 조합이 유실되거나 오래된 값으로 되돌아가지 않고 소비자에게 전달됩니다.
  - 접근: `SystemLifecycleSnapshot`, `SystemLifecycleSubscription`, `SystemLifecycleSource` 계약과
    메모리 구현을 먼저 두고, `SystemLifecycleObserver`가 stream과 내부 직렬 생산자를 만든 뒤
    저전력 관찰자와 주입받은 잠금 신호 관찰자를 모두 등록하고 마지막에 초기값을 읽도록 구현합니다.
    저전력은 `NSNotification.Name.NSProcessInfoPowerStateDidChange`와 `ProcessInfo.isLowPowerModeEnabled`를 사용하고,
    snapshot 변경마다 revision을 증가시켜 `.bufferingNewest(1)` stream으로 제공합니다.
  - 검증 조건:
    - 결과: `start()`는 stream 생성 → 관찰자 등록 → 초기값 조회 순서로 진행하고 `SystemLifecycleSubscription` 하나를 반환합니다.
      등록 뒤 초기 조회가 끝나기 전에 도착한 callback은 버려지지 않고 initial 값 위에 도착 순서대로 반영됩니다.
      initial snapshot의 revision은 0이고 이후 변경마다 증가하며, 값이 같은 연속 snapshot은 제거됩니다.
      소비가 밀리면 저전력과 화면 잠금을 함께 담은 최신 combined snapshot 하나만 남고,
      한 필드의 갱신이 다른 필드의 최신값을 이전 값으로 되돌리지 않습니다.
      소비자는 마지막으로 적용한 revision보다 작거나 같은 snapshot을 거부합니다.
    - 확인: 메모리 `SystemLifecycleSource`와 주입 잠금 신호로 Swift Testing 검증을 작성합니다 —
      등록과 초기 조회 사이에 도착한 저전력·잠금 callback의 병합 순서,
      revision 증가와 동일 snapshot 제거, 소비 지연 시 `.bufferingNewest(1)`의 최신 조합 보존,
      낮거나 같은 revision 거부를 각각 확인합니다.
      `NSNotification.Name.NSProcessInfoPowerStateDidChange` 심볼 사용은 빌드로 확인하고,
      존재하지 않는 `ProcessInfo.powerStateDidChangeNotification`을 쓰지 않았는지 소스 검색으로 확인합니다.
  - 참조: SPEC §5.6, ANALYSIS §1 「상태와 동시성 경계」, ANALYSIS §2 「앱 시작과 메뉴바 상호작용」,
    ANALYSIS §2 「수집 일정과 생명주기」, ANALYSIS §3 「수집 일정 계약」, ANALYSIS §5 DP8

- [ ] task-006: macOS 26.5 화면 잠금 어댑터
  - 목적: 실제 화면 잠금과 해제가 일어나면 앱이 잠금 상태 변화를 곧바로 알아차리고,
    5초 내외의 짧은 잠금·해제 순환에서도 해제를 놓치지 않으며,
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
      실제 macOS 26.5 Apple silicon에서 화면을 잠그면 snapshot이 `locked`로,
      해제하면 `unlocked`로 바뀌고, 잠금 후 5초 내외에 해제하는 짧은 순환을 5회 반복해도 매번 `unlocked`로 복귀합니다.
      문서화되지 않은 이름과 키 문자열은 이 어댑터 밖에 존재하지 않습니다.
    - 확인: 세션 사전 입력을 주입한 Swift Testing으로 `ScreenLockStateReader`의 네 경우
      (`true`, `false`, 잠금 키 부재, 사전 `nil`)와 비Boolean 값의 `unknown` 매핑을 검증합니다.
      알림 처리는 UID 일치·불일치·object 해석 실패·캐시 UID 부재 조합을 주입해
      이름 적용과 무시 판정을 검증하고, 해제 알림이 사전 값 때문에 폐기되지 않는지 확인합니다.
      실제 잠금·해제와 5초 내외 짧은 순환 5회는 macOS 26.5 Apple silicon에서 앱을 실행한 채 수행하고
      snapshot 전이 로그로 `locked`·`unlocked` 복귀를 확인합니다.
      이름과 키 문자열의 격리는 소스 전체 검색으로 확인합니다.
  - 참조: SPEC §5.7, ANALYSIS §2 「수집 일정과 생명주기」, ANALYSIS §3 「수집 일정 계약」,
    ANALYSIS §5 DP6, ANALYSIS §5 DP9

- [ ] task-007: 저전력·잠금에 따른 프레임 일정 감속과 정지
  - 목적: 저전력 모드에서는 캐릭터가 느리게 움직이고 화면이 잠긴 동안에는 멈추며,
    두 상태가 풀리면 원래 상태의 속도로 되돌아옵니다.
  - 접근: `CharacterPresentationStore`가 현재 상태, `CharacterMotionMode`와 최신 `SystemLifecycleSnapshot`을
    순수 `CharacterFramePolicy`에 넘겨 `CharacterFrameSchedule` 하나를 계산하고,
    입력이 바뀔 때만 기존 일정을 취소해 새 결과를 적용합니다.
    coordinator는 같은 snapshot을 표시 저장소와 수집 저장소에 각각 전달하고,
    표시 저장소도 revision 규칙으로 오래된 snapshot을 거부합니다.
  - 검증 조건:
    - 결과: 프레임 정책은 정적 요구(동작 줄이기 또는 애니메이션 비활성화) > 잠금 정지 > 저전력 감속 > 기본 순서로 판정합니다.
      저전력에서 다섯 상태는 각각 1·2·4·5·3 FPS로 실행되고, 해제되면 2·4·8·10·6 FPS로 복귀합니다.
      `screenLockState == locked`면 상태와 무관하게 정지하고 현재 상태의 정적 얼굴을 표시하며,
      해제되면 현재 상태의 해당 FPS로 첫 프레임부터 다시 시작합니다.
      `screenLockState == unknown`은 정지 사유가 아니어서 프레임이 계속 실행됩니다 —
      같은 `unknown`에서 수집이 pause되는 것과 의도적으로 다릅니다.
      정적 요구와 잠금이 동시에 성립해도 결과는 하나의 정지이고,
      저전력 진입·해제는 정지가 아니라 일정 재구성이므로 현재 프레임을 유지한 채 간격만 바뀝니다.
      계산 결과가 이전과 같으면 일정을 다시 만들지 않습니다.
      프레임 일정과 수집 일정은 어떤 타이머도 공유하지 않고 팝오버 상태는 프레임 정책 입력이 아닙니다.
    - 확인: `CharacterFramePolicy`는 순수 계산이므로
      다섯 상태 × `animated`·`reduceMotion`·`disabled` × `locked`·`unlocked`·`unknown` × 저전력 on·off 조합을
      Swift Testing 표 기반 테스트로 전수 검증합니다.
      저전력 FPS 값, 해제 후 기본 FPS 복귀, 잠금 해제 후 첫 프레임 재시작,
      저전력 전환 시 현재 프레임 유지, 동일 결과에서 일정 미재생성은 수동 `CharacterFrameClock`으로 확인합니다.
      `unknown`에서 프레임이 계속 도는 것과 같은 입력에서 수집이 pause되는 것을 한 테스트에서 함께 관찰해
      두 정책이 다르다는 점을 고정합니다.
      팝오버 상태가 `CharacterFramePolicy` 입력에 없고 두 일정이 타이머를 공유하지 않는지는 타입 시그니처와 소스 검색으로 확인합니다.
  - 참조: SPEC §5.5, ANALYSIS §1 「상태와 동시성 경계」, ANALYSIS §2 「캐릭터 프레임 일정과 생명주기」,
    ANALYSIS §3 「캐릭터 표시 계약」, ANALYSIS §5 DP3, ANALYSIS §5 DP10

- [ ] task-008: 메모리 전용 최근 샘플 순환 버퍼
  - 목적: 실제로 수집된 최근 샘플만 시간 범위와 수집 주기에 맞는 고정 용량으로 메모리에 유지하고,
    용량을 넘으면 가장 오래된 샘플만 사라지며 존재하지 않는 과거 데이터를 만들어내지 않습니다.
  - 접근: 단조 증가 시각과 값을 묶는 `TimestampedSample`,
    `ceil(시간 범위 / 유효 수집 주기)`로 양의 고정 용량을 계산하는 순수 `HistoryCapacity`,
    고정 저장 공간·다음 쓰기 위치·현재 개수만 가지고 O(1) 추가와 교체를 하는 값 타입 `CircularBuffer<Element>`를 구현합니다.
    actor `MonitoringSampleStore`만 append·시간순 snapshot·resize를 수행하고 가변 버퍼 참조를 밖으로 내보내지 않습니다.
  - 검증 조건:
    - 결과: M1 기본 시간 범위 10분에서 용량은 1초 주기 600개, 2초 300개, 5초 120개이고,
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
  - 참조: SPEC §5.8, ANALYSIS §1 「최근 데이터 경계」, ANALYSIS §2 「샘플과 순환 버퍼」,
    ANALYSIS §3 「최근 데이터 계약」, ANALYSIS §5 DP5

- [ ] task-009: 수집 일정 정책과 단일 Scheduler
  - 목적: 팝오버 열림·닫힘, 저전력 모드와 화면 잠금 상태가 바뀌면 최신 조합에 맞는 수집 일정 하나만 적용되고,
    같은 상태가 반복해서 들어와도 중복 수집이 일어나지 않습니다.
  - 접근: actor `MonitoringLifecycleStore`가 `MonitoringLifecycleEvent`를 단일 `update(_:)`로 직렬화하며
    최종 snapshot과 마지막 적용 일정을 소유하고, 순수 `CollectionSchedulePolicy`가 `running(interval)` 또는 `paused`를 계산합니다.
    계산 결과가 마지막 적용 결과와 다를 때만 actor `MonitoringScheduler.apply(_:)`를 호출하고,
    Scheduler는 단일 Task와 generation, 주입 가능한 `MonotonicClock` 기준 deadline만 소유하며
    유효 샘플을 `MonitoringSampleStore`에 한 번 전달합니다.
  - 검증 조건:
    - 결과: `unlocked`에서 normal은 팝오버 열림 1초·닫힘 2초, lowPower는 열림 2초·닫힘 5초를 적용합니다.
      `locked` 또는 `unknown`은 팝오버·전력과 무관하게 `paused`입니다.
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
      일정 교체 시 이전 generation 결과 폐기, 기준 deadline 전진,
      pause 중 버퍼·용량 유지, resume 시 10분 기준 새 주기 용량으로의 resize와 미따라잡기,
      공급자 실패·취소가 0 샘플을 만들지 않는 것을 각각 검증합니다.
  - 참조: SPEC §5.6, SPEC §5.8, ANALYSIS §1 「상태와 동시성 경계」, ANALYSIS §2 「수집 일정과 생명주기」,
    ANALYSIS §3 「수집 일정 계약」, ANALYSIS §5 DP4

- [ ] task-010: 실제 잠금·해제에서의 수집 중지와 재개
  - 목적: 실제 macOS 화면 잠금에서 수집이 멈추고 해제하면 다시 시작하며,
    잠근 직후 곧바로 해제하는 짧은 순환에서도 수집이 멈춘 채 남지 않습니다.
  - 접근: 어댑터가 만든 실제 `SystemLifecycleSnapshot`을 생명주기 store와 Scheduler까지 연결한 구성으로 앱을 실행하고,
    잠금·해제 전이와 그때 적용된 일정을 관찰 가능한 형태로 남겨 실제 OS 조작으로 확인합니다.
  - 검증 조건:
    - 결과: macOS 26.5 Apple silicon에서 화면을 잠그면 수집 일정이 `paused`로 바뀌어 새 샘플이 늘지 않고,
      해제하면 잠금 이전 팝오버·전력 조합에 해당하는 일정으로 재개되어 샘플이 다시 쌓입니다.
      잠금 후 5초 내외에 해제하는 짧은 순환을 5회 반복해도 매번 재개되며,
      해제 알림이 세션 사전의 지연 갱신 때문에 폐기되어 pause에 갇히는 경우가 한 번도 발생하지 않습니다.
      resume 시 버퍼는 새 유효 주기 용량으로 resize되고 중지 동안 놓친 샘플을 만들어내지 않습니다.
      잠금·해제 중에도 메뉴바 항목과 팝오버는 계속 동작합니다.
    - 확인: macOS 26.5 Apple silicon에서 앱을 실행한 채 실제 화면 잠금·해제를 수행하고,
      적용 일정 전이와 샘플 수 변화를 로그로 기록해 pause·resume 시점과 간격을 확인합니다.
      5초 내외의 짧은 순환 5회와 1분 이상 유지되는 긴 잠금 1회를 각각 수행해 두 경우 모두 재개되는지 확인하고,
      순환 도중 메뉴바 항목·팝오버 동작을 직접 관찰합니다.
      resume 후 버퍼 용량과 샘플 연속성은 같은 실행에서 저장소 snapshot으로 확인합니다.
  - 참조: SPEC §5.7, ANALYSIS §2 「수집 일정과 생명주기」, ANALYSIS §4 「테스트 대상」,
    ANALYSIS §5 DP6, ANALYSIS §5 DP9

- [ ] task-011: M1 production 구성과 지원·산출물 정책
  - 목적: macOS 26.5 이상 Apple silicon에서 ResourceRunner 메인 앱 하나만 실행하면
    메뉴바·팝오버·캐릭터·생명주기 일정·최근 샘플 기반이 함께 동작하고,
    M1 디버그 빌드와 자동 테스트가 성공하며 추가 상주 실행 파일이 만들어지지 않습니다.
  - 접근: `ApplicationCoordinator`가 캐릭터 자산과 `CharacterPresentationProfileSet`을 구성한 뒤
    `StatusBarController`, 캐릭터 source·store·sink, `SystemLifecycleObserver`,
    생명주기 store, Scheduler, M1 샘플 source와 샘플 store를 각각 한 번 만들어
    분석이 정한 시작 순서와 단일 방향 흐름으로 연결하고 종료까지 강하게 보유합니다.
    앱·단위 테스트·UI 테스트 대상의 Debug·Release deployment target을 26.5로 통일하고
    앱 실행 파일 아키텍처를 arm64로 제한하며, 생성 Info.plist의 `LSUIElement = YES`와 기존 App Sandbox를 유지합니다.
  - 검증 조건:
    - 결과: production 앱은 system initial snapshot과 초기 `popoverPresented = false`를 적용하기 전에는 Scheduler를 시작하지 않고,
      이후 update stream을 소비하며 두 store에 같은 snapshot을 전달합니다.
      표시 계층은 수집 actor를 호출하지 않고 수집 actor도 표시 계층을 호출하지 않으며,
      프레임 일정과 수집 일정은 서로 다른 타이머를 씁니다.
      실제 Collector, 설정 영구 저장, 로그인 항목, 외부 package, Helper, 추가 실행 대상이 추가되지 않습니다.
      세 대상 모두 macOS 26.5를 최소 버전으로 사용하고,
      Debug·Release 앱 아키텍처 설정과 빌드된 실행 파일이 arm64 단일 슬라이스이며,
      생성 Info.plist에 `LSUIElement = YES`가 있고 App Sandbox가 유지됩니다.
      앱 번들 `Contents/MacOS`에는 ResourceRunner 실행 파일 하나만 있고 로그인 항목·Helper 위치는 비어 있습니다.
      M1 Debug 빌드와 Swift Testing·XCTest 전체가 성공합니다.
    - 확인: macOS 26.5 Apple silicon에서 격리된 DerivedData로 Debug 빌드와 전체 테스트를 실행해 성공을 확인합니다.
      `xcodebuild -showBuildSettings`로 세 대상의 deployment target, Debug·Release 앱 아키텍처와 생성 Info.plist 설정을 확인하고,
      빌드된 번들의 `Info.plist`, `lipo -archs` 또는 `file`의 실행 파일 아키텍처,
      `Contents/MacOS`와 `Contents/Library/LoginItems` 목록,
      `project.pbxproj`의 native target·package 목록과 최종 diff를 검사합니다.
      실행 앱에서는 Dock 없음, 안정적인 메뉴바 항목, 반복 팝오버 토글,
      다섯 캐릭터 상태 전환과 정적 접근성 표현이 한 세션 안에서 함께 동작하는지 통합 관찰합니다.
      구성 방향과 계층 간 호출 금지는 coordinator 초기화 순서 테스트와 소스 검색으로 확인합니다.
  - 참조: SPEC §5.1, SPEC §5.9, SPEC §5.10, ANALYSIS §1 「애플리케이션 구성」, ANALYSIS §1 「상태와 동시성 경계」,
    ANALYSIS §2 「앱 시작과 메뉴바 상호작용」, ANALYSIS §3 「빌드와 산출물 계약」,
    ANALYSIS §4 「프로젝트 설정과 대상」, ANALYSIS §4 「저장과 외부 경계」, ANALYSIS §5 DP7
