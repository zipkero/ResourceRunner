# 메뉴바 앱과 모니터링 기반 분석

## 근거

### 확인 사실

- [spec.md](./spec.md)는 Dock 아이콘 없는 메뉴바 앱, transient 팝오버, 주입 상태 기반 캐릭터 표현,
  수집 일정과 순환 버퍼를 M1 범위로 고정하고, 저전력·화면 잠금에 따른 애니메이션 감속·정지를 M1에 포함시킵니다.
- [ROADMAP.md](../../ROADMAP.md)의 `M1. 메뉴바 앱과 모니터링 기반`은 실제 Collector 없이 UI와 상태 전환을
  검증하고 공통 모니터링 기반과 지원 정책을 완성하도록 요구합니다.
- [ROADMAP.md](../../ROADMAP.md)의 `프로젝트 완료 기준` 5번은 팝오버 상태, 저전력 모드와 화면 잠금에 따라
  수집과 애니메이션 비용이 조절되는 것을 1.0 필수 결과로 둡니다.
- [docs/product.md](../../docs/product.md)는 낮음·보통·높음·매우 높음에 걷기·달리기·전력 질주를 대응시키고,
  동작 줄이기와 애니메이션 비활성화에서는 같은 상태를 구분하는 정적 표현을 요구합니다.
- [docs/product.md](../../docs/product.md)의 `최근 그래프와 데이터 보관`은 1.0 기본 그래프 시간 범위를
  최근 10분으로, 기본 전체 지표 주기를 대시보드 열림 1초로 고정합니다.
- [docs/design.md](../../docs/design.md)의 `기술 방향`은 공개 macOS API를 우선하고 비공개 API, 별도 Helper,
  관리자 권한과 시스템 확장이 필요한 기능을 1.0 필수 기능으로 가정하지 않는다고 못 박습니다.
- [docs/design.md](../../docs/design.md)의 `상태 통합과 애니메이션`은 저전력 모드, 화면 잠금과 동작 줄이기에서
  애니메이션을 감속하거나 정지하라고 요구하고, `주요 기술 위험과 대응 > 애니메이션 전력 소비`도 같은 대응을 둡니다.
- [docs/design.md](../../docs/design.md)는 AppKit이 메뉴바 항목과 팝오버 생명주기를, SwiftUI가 대시보드를 담당하는
  목표 경계와 수집 일정·순환 버퍼·생명주기 정책을 정의합니다. 순환 버퍼 예시는 10분 범위에서 1초 600개,
  2초 300개, 5초 120개입니다.
- [ResourceRunnerApp.swift](../../ResourceRunner/ResourceRunnerApp.swift)는 현재 `WindowGroup`에서
  [ContentView.swift](../../ResourceRunner/ContentView.swift)를 여는 일반 SwiftUI 창 앱입니다.
- [project.pbxproj](../../ResourceRunner.xcodeproj/project.pbxproj)는 macOS 앱, 단위 테스트와 UI 테스트 대상을 가지며
  파일 시스템 동기화 그룹을 사용합니다. 현재 deployment target은 26.5이고 `LSUIElement`과 arm64 전용 설정은 없습니다.
- 애플리케이션 대상은 Swift 5 언어 모드, `SWIFT_APPROACHABLE_CONCURRENCY`와 `MainActor` 기본 격리를 사용하고
  App Sandbox가 활성화돼 있습니다.
- [ResourceRunnerTests.swift](../../ResourceRunnerTests/ResourceRunnerTests.swift)는 Swift Testing,
  [ResourceRunnerUITests.swift](../../ResourceRunnerUITests/ResourceRunnerUITests.swift)는 XCTest 템플릿 상태입니다.
- [StatusCatStatic.imageset](../../ResourceRunner/Assets.xcassets/StatusCatStatic.imageset/Contents.json)은 현재 기본 고양이 얼굴을
  22×22px와 44×44px template image로 제공합니다. 상태별 정적 변형은 아직 없습니다.
- 조사 환경과 M1 지원 기준은 Apple silicon, macOS 26.5.2, Xcode 26.6이며 macOS 26.5 미만과 Intel Mac은 제외됩니다.
- 설치된 macOS 26.5 SDK의 공개 `NSWorkspace` API에는 사용자 세션 전환과 화면 sleep·wake 알림만 있고,
  화면 잠금·해제를 직접 나타내는 공개 알림은 확인되지 않았습니다.
- 공개 `CGSession.h`는 `CGSessionCopyCurrentDictionary()`가 Quartz GUI 세션 밖에서 `NULL`을 반환할 수 있다고
  명시하고, 세션 사용자 ID를 32-bit unsigned integer `CFNumber`로 규정합니다.
- 같은 헤더의 키 매크로는 `#define kCGSessionUserIDKey CFSTR("kCGSSessionUserIDKey")`입니다. `CFSTR` 매크로는
  Swift로 import되지 않고, 실제 키 문자열 `"kCGSSessionUserIDKey"`는 매크로 이름과 `S` 개수가 다릅니다.
  Swift에서는 문자열 리터럴을 직접 써야 합니다.
- 현재 OS의 `loginwindow` 실행 파일에서는 `com.apple.screenIsLocked`, `com.apple.screenIsUnlocked` 알림 이름과
  `CGSSessionScreenIsLocked` 세션 사전 키가 확인됩니다. 이 이름과 키는 공개 SDK 계약이 아닙니다.

2026-08-06에 macOS 26.5.2 Apple silicon에서 App Sandbox를 적용한 GUI 앱과 적용하지 않은 GUI 앱을 각각 빌드해
직접 관찰한 결과는 다음과 같습니다. 상세는 spec.md의 `확인한 실행 환경 사실`에 있습니다.

- App Sandbox 앱에서도 `CGSessionCopyCurrentDictionary()`가 세션 사전을 반환하고 사용자 ID 키를 읽을 수 있습니다.
  비Sandbox 앱과 결과가 같습니다.
- `CGSSessionScreenIsLocked` 키는 잠금 상태에서만 나타나고 해제 상태에서는 사전에 존재하지 않습니다.
  키 부재는 정보 없음이 아니라 잠기지 않은 상태입니다.
- 잠금·해제 distributed notification은 App Sandbox 앱에도 배달되고 object에 현재 GUI 세션 사용자 ID가
  문자열로 실려 옵니다. 같은 값이 세션 사전에서는 숫자 타입입니다.
- 잠금 5.5초 뒤 해제한 짧은 순환에서 해제 알림이 도착한 시점에도 세션 사전이 여전히 잠김을 보고했습니다.
  4분간 지속된 잠금에서는 사전이 제때 갱신돼 있었습니다. 사전 갱신이 알림보다 늦는 경쟁이 간헐적으로 발생합니다.
- `com.apple.screensaver.didstart`와 `com.apple.screensaver.didstop`은 화면 잠금에서 발화하지 않아
  잠금 신호의 대체재가 되지 못합니다.
- M1 범위 밖 참고로 M2 대비 확인도 함께 했습니다. App Sandbox에서 `proc_listallpids`는 EPERM으로 막히지만
  `sysctl(KERN_PROC_ALL)`은 동작하고, 아는 PID의 `PROC_PIDTASKINFO`·`PROC_PIDTBSDINFO`·`proc_pidpath`는 읽히며
  `proc_pid_rusage`는 막힙니다.

### 추정

- 다섯 상태의 전신 애니메이션 프레임과 상태별 정적 얼굴은 아직 존재하지 않습니다. 제품 문서의 움직임 의미와
  SPEC §5.4를 함께 유지하려면 현재 기본 얼굴과 같은 캐릭터 정체성을 공유하는 두 자산 계열이 필요합니다.
- M1 대상 환경에서 세션 사전이 `nil`인 경우는 관찰되지 않았습니다. 다만 공개 헤더가 `NULL` 반환을 명시하므로
  사전을 얻지 못하는 경로에 대한 명시적 fallback은 유지해야 합니다.
- 현재 OS의 문서화되지 않은 잠금 신호는 변경될 수 있습니다. macOS 26.5 전용 어댑터에 이름과 키를 격리하고,
  나머지 생명주기와 일정 정책은 주입 가능한 공개 계약만 의존해야 영향 범위를 제한할 수 있습니다.

## 1. 구조

### 애플리케이션 구성

`ResourceRunnerApp`은 SwiftUI `App`을 유지하고 `@NSApplicationDelegateAdaptor`로 `AppDelegate`를 연결합니다.
`body`에는 일반 창을 만들지 않는 `Settings { EmptyView() }`만 둡니다. `AppDelegate`는 앱 시작 때 하나의
`@MainActor ApplicationCoordinator`를 만들고 강하게 보유하며 별도 Helper나 추가 실행 대상은 만들지 않습니다.

`ApplicationCoordinator`는 다음 객체와 관찰 작업을 한 번만 구성하고 앱 종료 때까지 수명을 소유합니다.

- `StatusBarController`: `NSStatusItem`, `NSPopover`, 팝오버 delegate와 실제 메뉴바 렌더링을 소유하는 `MainActor` 경계
- `CharacterPresentationStore`: 주입 상태, 표시 정책, 프레임 일정과 현재 프레임을 소유하는 `MainActor` 표시 저장소
- `CharacterStateSource`: 실제 Collector와 분리된 M1 캐릭터 상태 입력
- `SystemLifecycleObserver`: 저전력·화면 잠금의 초기 combined snapshot과 이후 최신 snapshot stream을 제공하는
  `MainActor` 시스템 어댑터
- `MonitoringLifecycleStore`: 팝오버·저전력·잠금 snapshot과 마지막 적용 일정을 소유하는 actor
- `MonitoringScheduler`: 적용받은 일정에 따라 단일 수집 작업을 유지하는 actor
- `ScheduledSampleSource`: 실제 Collector 대신 일정 동작을 검증하는 M1 샘플 입력
- `MonitoringSampleStore`: `CircularBuffer`와 시간 범위·용량 변경을 소유하는 actor

`SystemLifecycleObserver`의 snapshot은 coordinator에서 두 갈래로 갈라져 `CharacterPresentationStore`와
`MonitoringLifecycleStore`에 각각 전달됩니다. 시스템 관찰은 한 곳에만 두고 프레임 일정과 수집 일정은
각자의 순수 정책으로 따로 계산합니다.

`LSUIElement = YES`를 생성 Info.plist의 제품 설정으로 사용해 프로세스 시작부터 Dock과 앱 전환기에 나타나지 않게 합니다.
런타임 activation policy만으로 Dock을 숨기는 방식은 시작 시점의 노출을 막는 기준으로 사용하지 않습니다. 이 구조가
SPEC §5.1과 SPEC §5.10을 담당합니다.

### 표시 계층

`StatusBarController`는 `NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)`로 고정 폭 항목을 만들고
`NSStatusBarButton`의 이미지만 교체합니다. `CharacterAssetCatalog`는 메뉴바 항목을 표시하기 전에 다섯 상태의 정적 얼굴과
상태별 최소 두 애니메이션 프레임을 선로딩합니다. 모든 자산은 같은 22pt 캔버스, 기준선과 시각적 중심을 사용합니다.
누락 자산은 초기 구성 실패로 기록하고 기본 `StatusCatStatic`과 실패 VoiceOver 값을 표시하되, 이 fallback을 M1 완료로
간주하지 않습니다. 이 경계가 SPEC §5.3의 프레임 전환과 폭·기준 위치 안정성을 담당합니다.

팝오버는 `NSPopover`와 SwiftUI `NSHostingController` 조합을 사용합니다. `behavior = .transient`로 외부 상호작용에서
닫히게 하고 delegate의 표시 상태를 단일 소스로 사용해 클릭 토글과 실제 닫힘 상태가 어긋나지 않게 합니다.
SwiftUI 콘텐츠는 M1 대시보드 셸만 제공하고 완성된 자원 카드는 포함하지 않습니다. 이 구조가 SPEC §5.2를 담당합니다.

캐릭터 표현은 다음 두 자산 계열을 사용합니다.

- 애니메이션 활성화: 상태별 최소 두 프레임의 전신 걷기·달리기·전력 질주·장시간 고부하 표현
- 정지 조건: 현재 기본 얼굴 외곽과 귀 비율을 유지한 상태별 정적 얼굴 5종

두 계열은 같은 캐릭터의 귀, 얼굴 비율과 표정 언어를 공유합니다. 각 상태는 고유한 정적 형태와 VoiceOver value를 가지며,
표시 모드가 바뀌어도 상태와 접근성 설명은 유지하고 이미지만 전환합니다. 정지 조건은 동작 줄이기와 애니메이션
비활성화(SPEC §5.4)뿐 아니라 화면 잠금(SPEC §5.5)도 포함하므로, 정적 얼굴은 두 조건이 공유하는 단일 표현입니다.

### 상태와 동시성 경계

표시 흐름은 `CharacterStateSource/SystemLifecycleObserver → ApplicationCoordinator → CharacterPresentationStore →
CharacterPresentationSink`로 한정합니다. `ApplicationCoordinator`가 store와 sink 구현체인 `StatusBarController`를
강하게 소유하고 store는 sink를 약하게 참조합니다. 상태, 표시 정책이나 프레임이 바뀌면 store가
`CharacterPresentation`을 만들어 `render(_:)`를 호출합니다. 상태 수신, 프레임 전환과 메뉴바 갱신은
`MainActor`에서만 수행합니다. 표시 계층은 수집 actor를 호출하지 않고 수집 actor도 표시 계층을 호출하지 않습니다.

생명주기 흐름은 `StatusBarController/SystemLifecycleObserver → ApplicationCoordinator → MonitoringLifecycleStore →
MonitoringScheduler`로 한정합니다. 모든 입력은 `MonitoringLifecycleStore.update(_:)`를 통과하며 actor가 snapshot 변경,
순수 일정 계산과 마지막 적용 일정 비교를 직렬화합니다. 계산 결과가 달라질 때만 Scheduler를 호출합니다.

`SystemLifecycleObserver`는 notification token, 시작 시 읽은 세션 사용자 ID, 현재 revision,
`SystemLifecycleSnapshot`과 stream continuation을 `MainActor`에서 소유합니다. 시스템 callback이 다른 queue에서
도착하면 값을 직접 바꾸지 않고 내부 직렬 생산자에 전달합니다. stream은 증가하는 revision과 저전력·화면 잠금을 함께 담은
snapshot을 `.bufferingNewest(1)`로 제공하므로 소비가 늦어져도 두 필드의 최신 조합 하나만 남습니다.
`MonitoringLifecycleStore`는 마지막 system revision보다 큰 snapshot만 적용하고, `CharacterPresentationStore`도
같은 revision 규칙으로 오래된 snapshot을 거부합니다.

샘플 흐름은 `ScheduledSampleSource → MonitoringScheduler → MonitoringSampleStore → CircularBuffer`로 분리합니다.
Scheduler는 일정, 취소와 generation만 소유하고 버퍼를 직접 변경하지 않습니다. 저장소는 샘플과 버퍼 용량만 소유하며
표시 저장소를 호출하지 않습니다. 이 분리가 SPEC §5.6과 SPEC §5.8의 독립성과 단일 쓰기 경계를 담당합니다.

### 최근 데이터 경계

`CircularBuffer<Element>`는 고정 용량 값 타입으로 두고 저장소나 UI에 의존하지 않게 합니다. 내부에는 다음 쓰기 위치,
현재 개수와 고정 저장 공간만 소유하며 추가와 가장 오래된 샘플 교체는 O(1)로 처리합니다. 읽기는 오래된 항목부터
시간순으로 제공합니다.

M1의 그래프 시간 범위는 `docs/product.md`가 정한 1.0 기본값인 최근 10분을 상수로 사용합니다. 사용자가 범위를 고르는
설정은 M1 제외 범위이므로 범위 변경은 저장소 API로만 노출하고 UI로는 노출하지 않습니다.

용량은 `ceil(시간 범위 / 유효 수집 주기)`로 계산합니다. 기본 10분에서 1초 주기는 600개, 2초는 300개, 5초는 120개입니다.
실행 주기가 바뀌거나 pause에서 resume할 때만 새 주기로 resize하고 최신 샘플만 보존합니다. pause 중에는 유효 주기가
없으므로 버퍼와 용량을 그대로 유지합니다. 늘어난 공간이나 앱 시작 직후의 과거 구간은 채우지 않으며 샘플과 버퍼는
메모리에만 존재합니다. 이 경계가 SPEC §5.8을 담당합니다.

## 2. 데이터 흐름

### 앱 시작과 메뉴바 상호작용

1. SwiftUI `App`이 `AppDelegate`를 연결하고 `Settings { EmptyView() }`만 선언합니다.
2. `AppDelegate`가 하나의 `ApplicationCoordinator`를 만들고 coordinator가 필수 캐릭터 자산과
   `CharacterPresentationProfileSet`을 구성합니다.
3. coordinator가 `StatusBarController`를 표시 sink로 연결하고 생명주기 store와 Scheduler를 구성합니다.
4. coordinator가 `SystemLifecycleObserver.start()`를 한 번 호출합니다. observer는 combined snapshot stream과 continuation을
   먼저 만들고 화면 잠금·저전력 관찰자를 모두 등록한 뒤 현재 두 값을 읽어 `SystemLifecycleSubscription`을 반환합니다.
5. coordinator가 subscription의 initial snapshot을 `CharacterPresentationStore`와 `MonitoringLifecycleStore`에
   각각 적용하고, 초기 `popoverPresented = false`도 생명주기 store에 적용합니다.
6. coordinator가 이미 만들어진 snapshot stream 소비 Task를 시작합니다. 소비한 snapshot은 매번 두 store에 함께
   전달됩니다. 시작 중 도착한 callback은 초기값 위에 도착 순서로 반영되고 더 큰 revision의 combined snapshot으로
   버퍼링됩니다.
7. 메뉴바 버튼 클릭 시 팝오버가 닫혀 있으면 버튼에 고정해 열고, 열려 있으면 닫습니다.
8. delegate의 표시·닫힘 이벤트를 coordinator가 `popoverPresented` 입력으로 생명주기 store에만 전달합니다.
9. 팝오버 상태는 수집 일정에만 반영되고 캐릭터 프레임 일정의 입력이 아닙니다.

초기 팝오버 값은 `false`이며 system initial snapshot을 적용하기 전에는 Scheduler를 시작하지 않습니다. observer의 직렬 생산자는
관찰자 등록 뒤 초기 조회 중 도착한 callback을 보관하고, 조회한 initial 값 위에 도착 순서로 반영한 snapshot마다 revision을
증가시킵니다. 여러 update가 소비 전에 도착하면 `.bufferingNewest(1)`이 가장 큰 revision의 조합만 남깁니다. 두 소비자는
낮거나 같은 revision을 거부하고, 생명주기 store는 일정 결과가 같으면 Scheduler를 다시 호출하지 않습니다. 이 흐름이
SPEC §5.1, §5.2와 §5.6을 지원합니다.

### 주입 상태와 캐릭터 전환

M1의 `CharacterStateSource`는 실제 CPU 값을 읽지 않고 다음 표시 상태 중 하나를 주입합니다. 기본 실행은 `low`에서 시작하고
테스트와 M1 검증 구성은 동일한 source의 `send(_:)`로 상태를 순서와 시점에 관계없이 바꿀 수 있습니다.
FPS는 기본값과 저전력 감속값을 함께 가집니다.

| 상태 | 동작 | 기본 FPS | 저전력 FPS |
| --- | --- | ---: | ---: |
| `low` | 걷기 | 2 | 1 |
| `moderate` | 달리기 | 4 | 2 |
| `high` | 빠른 달리기 | 8 | 4 |
| `veryHigh` | 전력 질주 | 10 | 5 |
| `sustainedHigh` | 장시간 고부하 전용 표현 | 6 | 3 |

`sustainedHigh`는 `veryHigh`보다 심각한 상태지만 지친 움직임을 표현하기 위해 평상시 대역인 6 FPS를 의도적으로
사용합니다. 부하 크기와 FPS를 비례시키지 않는 유일한 상태이며 오타가 아닙니다.

정적 얼굴은 바깥 얼굴선과 귀를 바꾸지 않고 내부 형태로 구분합니다. `low`는 편안한 눈, `moderate`는 열린 눈과 기본 입,
`high`는 집중한 눈, `veryHigh`는 크게 뜬 눈과 열린 입, `sustainedHigh`는 처진 눈과 피로 표시를 사용합니다. 색상만으로
상태를 나누지 않으며 1x와 2x 크기에서 서로 다른 형태로 읽혀야 합니다.

표시 상태가 바뀌면 `CharacterPresentationStore`가 현재 프레임을 새 상태의 첫 프레임으로 치환하고 하나의 프레임 일정만
다시 구성합니다. 프레임 변경은 수집 작업과 독립적입니다. 런타임 이미지 설정 실패는 해당 상태의 정적 얼굴과 접근성 값으로
후퇴합니다. 이 흐름이 SPEC §5.3을 담당합니다.

동작 줄이기는 `NSWorkspace.accessibilityDisplayShouldReduceMotion`의 현재값과 접근성 표시 옵션 변경 알림으로 반영합니다.
사용자가 애니메이션을 비활성화한 상태는 M1에서 주입 가능한 정책으로 제공합니다. 접근성 label은 `ResourceRunner`,
value는 `낮음`, `보통`, `높음`, `매우 높음`, `장시간 고부하` 중 현재 상태를 설명하며 표시 모드와 무관하게 유지됩니다.
이 흐름이 SPEC §5.4를 담당합니다.

### 캐릭터 프레임 일정과 생명주기

`CharacterPresentationStore`는 현재 상태, 동작 정책(`CharacterMotionMode`)과 최신 `SystemLifecycleSnapshot`을
순수 `CharacterFramePolicy`에 전달해 프레임 일정 하나를 계산합니다. 입력 중 하나라도 바뀌면 기존 프레임 일정을
취소하고 새 결과를 적용합니다. 결과가 이전과 같으면 일정을 다시 만들지 않아 상태 변경이 프레임을 흔들지 않습니다.

| 조건 | 우선순위 | 결과 |
| --- | ---: | --- |
| 동작 줄이기 또는 애니메이션 비활성화 | 1 | 정지, 현재 상태의 정적 얼굴 |
| `screenLockState == locked` | 2 | 정지, 현재 상태의 정적 얼굴 |
| 저전력 모드 | 3 | 현재 상태의 저전력 FPS로 실행 |
| 그 외 | 4 | 현재 상태의 기본 FPS로 실행 |

`unknown`은 프레임 정책에서 정지 사유가 아닙니다. 잠금 신호를 해석하지 못하는 동안에도 메뉴바와 캐릭터 표현이 계속
동작해야 한다는 spec.md 제약 때문이며, 이 지점에서 수집 정책과 의도적으로 다릅니다. 수집은 잠긴 화면에서 비용을 쓰지
않는 것이 목적이라 신호 불명에서 보수적으로 pause하지만, 표시는 신호 불명에서 멈추면 앱이 죽은 것처럼 보입니다.

정지 상태에서 상태가 바뀌면 프레임 일정을 만들지 않고 새 상태의 정적 얼굴과 접근성 값만 갱신합니다. 정지 사유가
풀리면 현재 상태의 해당 FPS로 첫 프레임부터 다시 시작합니다. 저전력 진입·해제는 정지가 아니라 일정 재구성이므로
현재 프레임을 유지한 채 간격만 바뀝니다. 프레임 일정은 수집 일정과 어떤 타이머도 공유하지 않습니다.
이 흐름이 SPEC §5.5를 담당합니다.

모든 FPS 값은 `CharacterPresentationProfileSet`으로 표시 계층 바깥에서 주입되고, `CharacterFrameRateLimit`가
1...12 범위로 클램프합니다. 상한을 넘는 프로필은 구성 검증이 초과 항목으로 보고하고 실제 일정은 12를 넘지 않습니다.
기본 프로필의 최대값은 10이므로 상한 검증은 테스트가 구성한 초과 프로필로만 관찰할 수 있습니다.

### 수집 일정과 생명주기

`SystemLifecycleObserver.start()`는 `MainActor`에서 한 번만 호출하며 `SystemLifecycleSubscription`을 반환합니다.
subscription은 initial `SystemLifecycleSnapshot`과 이후 combined snapshot을 제공하는
`AsyncStream<SystemLifecycleSnapshot>`을 묶습니다. observer는 stream을 먼저 생성하고 다음 시스템 관찰자를 모두 등록한 뒤
초기값을 읽습니다.

- 저전력: `NSNotification.Name.NSProcessInfoPowerStateDidChange`를 등록하고 `ProcessInfo.isLowPowerModeEnabled`를 읽습니다.
  `ProcessInfo.powerStateDidChangeNotification`이라는 심볼은 존재하지 않으므로 이 이름을 사용합니다.
- 화면 잠금: current-OS lock/unlock distributed notification을 등록하고 `ScreenLockStateReader`를 한 번 호출합니다.

화면 잠금 관찰의 시작 순서는 다음과 같습니다.

1. `DistributedNotificationCenter`에 `com.apple.screenIsLocked`와 `com.apple.screenIsUnlocked`를 먼저 등록합니다.
2. `CGSessionCopyCurrentDictionary()`를 한 번 호출해 `"kCGSSessionUserIDKey"` 값을 정수로 읽어 캐시하고,
   `CGSSessionScreenIsLocked` 값으로 초기 잠금 상태를 판정합니다.
3. 등록 뒤 초기 조회가 끝나기 전에 도착한 callback은 내부 직렬 생산자가 도착 순서와 함께 보관합니다.
4. 생산자는 조회한 initial 값에 보관한 callback을 순서대로 반영하고 snapshot 변경마다 revision을 증가시킵니다.
5. 같은 combined snapshot은 제거하고 소비가 밀리면 가장 큰 revision의 snapshot 하나만 유지합니다.

`ScreenLockStateReader`는 이 초기 조회에서만 사용하며 다음 세 값 중 하나를 반환합니다.

- `locked`: `CGSSessionScreenIsLocked` 값이 Boolean으로 해석돼 `true`
- `unlocked`: 값이 Boolean으로 해석돼 `false`이거나, 세션 사전에 잠금 키가 없음
- `unknown`: 세션 사전이 `nil`이거나, 잠금 키가 있으나 Boolean으로 해석할 수 없음

키 부재를 `unlocked`로 읽는 것이 실측과 맞는 유일한 매핑입니다. 이 키는 잠금 중에만 나타나므로 키 부재를 `unknown`으로
읽으면 정상 해제 상태에서 앱이 시작부터 영구히 pause합니다. 이 매핑의 대가는 DP6에 기록합니다.

시스템 callback은 값 자체를 stream에 바로 넣지 않고 내부 직렬 생산자에서 combined snapshot을 갱신합니다. 저전력 callback은
`isLowPowerModeEnabled`를 다시 읽습니다. 잠금 callback은 다음 순서로 처리합니다.

1. notification 이름이 `com.apple.screenIsLocked`이면 `locked`, `com.apple.screenIsUnlocked`이면 `unlocked`를
   후보 값으로 삼습니다.
2. notification object 문자열과 시작 시 캐시한 세션 사용자 ID를 각각 정수로 정규화해 비교합니다. object는 문자열,
   세션 사전 값은 32-bit unsigned integer이므로 정규화 없이는 항상 불일치합니다.
3. 양쪽 모두 정수로 해석됐고 값이 다르면 다른 GUI 세션의 이벤트이므로 무시하고 snapshot을 바꾸지 않습니다.
4. 값이 같거나, 어느 한쪽을 정수로 해석하지 못해 비교할 수 없으면 후보 값을 그대로 적용합니다.

알림 처리 경로에서는 세션 사전을 다시 읽지 않고 notification 이름을 그대로 신뢰합니다. 해제 알림이 도착한 시점에도
사전이 잠김을 보고하는 경쟁이 실측으로 확인됐기 때문이며, 사전을 우선하면 짧은 잠금·해제 순환에서 해제 알림이 폐기돼
다음 잠금까지 pause에 갇힙니다. 세션 사용자 ID를 읽지 못한 경우에도 이름을 버리지 않는 이유는 같습니다. 다른 세션의
이벤트를 잘못 반영하면 잠깐 pause했다가 그 세션의 해제 알림으로 복귀하지만, 유효한 해제 알림을 버리면 복귀할 신호가
없습니다. 이 흐름이 SPEC §5.7의 짧은 순환 재개를 담당합니다.

문서화되지 않은 알림 이름과 세션 키는 이 어댑터에만 존재합니다. 나머지 계층과 자동 테스트는
`SystemLifecycleSource` 계약과 메모리 구현을 사용합니다. 세션 사전을 얻지 못하고 유효한 알림도 받지 못하면
`unknown`을 유지하고 수집을 pause하며, 표시 계층은 계속 동작합니다.

`MonitoringLifecycleStore`는 마지막 system revision과 `popoverPresented`, `lowPowerMode`, `screenLockState`의 최종
snapshot을 단독 소유합니다. coordinator가 전달한 `MonitoringLifecycleEvent`를 actor의 `update(_:)` 하나로 직렬화하고, 순수
`CollectionSchedulePolicy`에 snapshot을 전달합니다. 우선순위와 결과는 다음과 같습니다.

| 화면 잠금 상태 | 전력 | 팝오버 열림 | 팝오버 닫힘 |
| --- | --- | ---: | ---: |
| `locked` 또는 `unknown` | 무관 | paused | paused |
| `unlocked` | lowPower | 2초 | 5초 |
| `unlocked` | normal | 1초 | 2초 |

store는 계산 결과가 마지막 적용 결과와 다를 때만 `MonitoringScheduler.apply(_:)`를 호출합니다. Scheduler는 production에서
단조 증가 시계를 사용하고 자동 테스트에서는 수동 시계를 주입받습니다. 일정 간격은 마지막 실행 완료 시점이 아니라 기준
deadline을 전진시켜 계산합니다. 실행 주기 변경은 기존 작업을 취소하고 새 generation을 만듭니다.

pause에서는 작업만 취소하고 버퍼를 유지하며 resize하지 않습니다. resume에서는 새 주기로 버퍼를 resize한 뒤 새 generation을
시작하고 중지 동안 놓친 실행은 따라잡지 않습니다. 공급자 실패나 취소는 0 샘플로 바꾸지 않습니다. `locked`, `unlocked`,
`unknown`과 시작 중 상태 변경은 주입 가능한 lifecycle source와 수동 시계로 자동 검증합니다. 이 흐름이 SPEC §5.6과
SPEC §5.8을 담당합니다.

### 샘플과 순환 버퍼

주입 공급자가 반환한 샘플에는 단조 증가 시각과 값이 함께 들어갑니다. 첫 샘플은 그대로 현재 데이터가 되고 변화량이나
이전 구간을 만들지 않습니다. Scheduler가 유효 샘플을 받으면 generation 유효성을 확인한 뒤
`MonitoringSampleStore`에 한 번 전달합니다. 저장소 actor만 순환 버퍼를 변경하며 용량을 넘으면 가장 오래된 항목 하나만
교체합니다.

시간 범위나 유효 수집 주기가 바뀌면 용량 정책이 새 크기를 계산하고 버퍼는 최신 항목만 보존해 재구성됩니다. 데이터는
다른 저장 경계로 전달되지 않으며 앱 재시작 시 초기화됩니다. 이 흐름이 SPEC §5.8을 담당합니다.

## 3. 인터페이스

### 캐릭터 표시 계약

- `CharacterActivityState`: `low`, `moderate`, `high`, `veryHigh`, `sustainedHigh`의 닫힌 상태 집합
- `CharacterStateSource`: 초기 상태와 이후 변경을 `AsyncStream<CharacterActivityState>`로 제공하고 M1 검증에서
  `send(_:)`로 상태를 주입하는 메모리 입력 계약
- `CharacterMotionMode`: `animated`, `reduceMotion`, `disabled`의 표시 정책
- `CharacterAssetCatalog`: 상태마다 정적 얼굴 하나와 최소 두 애니메이션 프레임을 선로딩하는 자산 계약
- `CharacterPresentationProfile`: 한 상태의 선로딩 프레임, 기본 FPS, 저전력 FPS와 정적 얼굴을 묶는 값
- `CharacterPresentationProfileSet`: 다섯 상태의 프로필을 묶어 표시 계층 바깥에서 주입하는 구성 값.
  production 기본값은 coordinator가 제공하고 테스트는 상한을 넘는 값을 포함한 임의 구성을 만들 수 있습니다.
- `CharacterFrameRateLimit`: 최대 12 FPS 상한을 소유하고 FPS를 1...12로 클램프하며 프로필 구성의 초과 항목을
  보고하는 순수 정책
- `CharacterFrameSchedule`: `stopped` 또는 `running(framesPerSecond:)`의 프레임 일정 결과
- `CharacterFramePolicy`: 상태, `CharacterMotionMode`와 `SystemLifecycleSnapshot`을 받아 `CharacterFrameSchedule`을
  반환하는 순수 계산
- `CharacterPresentation`: 렌더링할 이미지와 지역화 가능한 접근성 label·value를 묶는 값
- `CharacterPresentationSink: AnyObject`: `@MainActor render(_:)`만 제공하며 `StatusBarController`가 구현하는 출력 계약
- `CharacterPresentationStore`: 상태, 표시 정책, 최신 생명주기 snapshot과 프레임을 `MainActor`에서 소유하고 sink를
  약하게 참조하는 내부 계약
- `CharacterFrameClock`: production 프레임 일정과 수동 테스트 일정을 교체할 수 있는 시간 계약

애니메이션 자산 이름과 프레임 인덱스는 `CharacterAssetCatalog` 내부에만 존재합니다. UI나 Scheduler는 자산 이름을 알지 않고
상태와 표시 정책만 전달합니다. `CharacterFramePolicy`는 팝오버 상태를 입력으로 받지 않습니다.
이 경계가 SPEC §5.3~5.5를 지원합니다.

### 팝오버와 접근성 계약

- `StatusBarController.togglePopover()`: 현재 `NSPopover.isShown`에 맞춰 버튼 입력을 열기 또는 닫기로 변환
- 팝오버 delegate event: 실제 표시 완료와 닫힘을 coordinator에 전달하는 `popoverPresented(Bool)` 출력
- 접근성 label: `ResourceRunner`
- 접근성 value: 현재 캐릭터 상태의 지역화 가능한 설명

실제 팝오버 표시 상태는 `StatusBarController`가 소유하고 SwiftUI 셸은 이를 변경하지 않습니다. coordinator가 delegate
출력을 생명주기 store에 전달하므로 표시 계층이 Scheduler를 직접 호출하지 않습니다. 이 경계가 SPEC §5.2와 §5.6을 지원합니다.

### 수집 일정 계약

- `ScreenLockState`: `locked`, `unlocked`, `unknown`의 닫힌 상태 집합
- `ScreenLockStateReader`: 시작 시 GUI 세션 사전에서 `ScreenLockState`와 세션 사용자 ID를 한 번 읽는 current-OS
  어댑터 계약. 세션 사전 키는 Swift에서 문자열 리터럴 `"kCGSSessionUserIDKey"`와 `"CGSSessionScreenIsLocked"`로
  씁니다. 공개 헤더의 매크로 이름 `kCGSessionUserIDKey`는 `CFSTR` 매크로라 Swift로 import되지 않고 실제 키 문자열과
  철자도 다릅니다.
- `SystemLifecycleSnapshot`: initial에서 0으로 시작해 변경 때 증가하는 `revision`, `lowPowerMode`와 `screenLockState`를 담는 값
- `SystemLifecycleSubscription`: initial snapshot과 `.bufferingNewest(1)`인 snapshot update stream을 묶는 값
- `SystemLifecycleSource`: `@MainActor start()`를 한 번 호출해 `SystemLifecycleSubscription`을 제공하는 주입 가능 계약
- `SystemLifecycleObserver`: 시스템 notification token, 캐시한 세션 사용자 ID와 combined snapshot을 소유하는 production 구현
- `MonitoringLifecycle`: `popoverPresented`, `lowPowerMode`, `screenLockState`를 묶는 최종 snapshot
- `MonitoringLifecycleEvent`: `popoverPresented(Bool)` 또는 `systemSnapshot(SystemLifecycleSnapshot)` 입력 값
- `MonitoringLifecycleStore`: 최초 revision은 항상 적용하고 이후에는 마지막 system revision보다 큰 snapshot과 변경된 일정만
  Scheduler에 전달하는 actor
- `CollectionScheduleDefinition`: normal·lowPower 각각의 팝오버 열림·닫힘 interval을 묶는 값
- `CollectionSchedulePolicy`: 일정 정의와 snapshot을 받아 `running(interval)` 또는 `paused`를 반환하는 순수 계산
- `MonitoringScheduler`: 적용 일정, 단일 Task와 generation별 실행을 직렬화하는 actor
- `ScheduledSampleSource`: M1 주입 샘플을 비동기로 반환하고 취소를 따르는 `Sendable` 계약
- `MonitoringSampleStore`: 샘플 추가, 시간 범위·주기 변경과 snapshot을 직렬화하는 actor
- `MonotonicClock`: production과 수동 테스트 시계를 바꾸는 시간 계약

M1 일정 값은 normal 열림 1초·닫힘 2초, lowPower 열림 2초·닫힘 5초입니다. 화면 상태가 `locked` 또는 `unknown`이면
다른 입력과 무관하게 paused입니다. M1은 실제 자원별 Collector 인터페이스나 시스템 지표 타입을 확정하지 않습니다.
이 경계가 SPEC §5.6과 §5.7을 지원하면서 M2의 공개 수집 contract를 선결하지 않습니다.

### 최근 데이터 계약

- `TimestampedSample<Value>`: 단조 증가 시각과 `Sendable` 값을 묶는 M1 샘플
- `HistoryCapacity`: 시간 범위와 유효 수집 주기에서 양의 고정 용량을 계산하는 순수 정책. M1 기본 시간 범위는 10분입니다.
- `CircularBuffer<Element>`: `append`, 시간순 `elements`, 최신 항목을 보존하는 `resize`를 제공하는 값 타입

`CircularBuffer`는 `MonitoringSampleStore` 밖으로 가변 참조를 노출하지 않습니다. pause는 저장소의 resize를 호출하지 않고,
resume과 실행 주기 변경만 새 유효 주기로 resize를 요청합니다. 공급자 오류나 취소는 Scheduler에서 샘플 부재로 처리합니다.
이 계약이 SPEC §5.8을 지원합니다.

### 빌드와 산출물 계약

앱·단위 테스트·UI 테스트 대상의 deployment target은 26.5로 통일하고 앱 실행 파일의 지원 아키텍처는 arm64로 제한합니다.
생성 Info.plist에는 `LSUIElement = YES`를 포함합니다. 기존 단일 애플리케이션 대상과 두 테스트 대상은 유지하고 새 Helper,
로그인 항목 또는 실행 대상을 추가하지 않습니다. 이 계약이 SPEC §5.1, §5.9와 §5.10을 지원합니다.

## 4. 영향 범위

### 기존 애플리케이션

- [ResourceRunnerApp.swift](../../ResourceRunner/ResourceRunnerApp.swift): `WindowGroup`을 제거하고
  `NSApplicationDelegateAdaptor`와 `Settings { EmptyView() }` 구성으로 바꿉니다.
- [ContentView.swift](../../ResourceRunner/ContentView.swift): 템플릿 콘텐츠를 M1 팝오버의 SwiftUI 대시보드 셸 책임으로
  제한하거나 같은 책임의 새 뷰로 대체합니다.
- [Assets.xcassets](../../ResourceRunner/Assets.xcassets): 현재 기본 얼굴을 유지하고 같은 외곽의 상태별 정적 얼굴 5종과
  각 상태의 전신 애니메이션 프레임을 최소 2개씩 추가합니다.
- 애플리케이션 내부에는 `AppDelegate`, `ApplicationCoordinator`, StatusBar, Character, Dashboard, Lifecycle와 Monitoring
  책임 경계가 생깁니다. 파일 시스템 동기화 그룹이므로 새 소스의 PBX 파일 참조를 수동 생성할 필요는 없습니다.

### 프로젝트 설정과 대상

- [project.pbxproj](../../ResourceRunner.xcodeproj/project.pbxproj)의 Debug·Release와 테스트 대상 deployment target,
  지원 아키텍처와 생성 Info.plist 설정을 macOS 26.5·arm64·`LSUIElement` 계약에 맞춥니다.
- 현재 App Sandbox 설정은 M1 범위에서 유지합니다. 잠금 신호에 필요한 알림 배달과 세션 사전 접근은 Sandbox 상태에서
  실측으로 확인됐습니다. 실제 CPU·Memory 접근과 배포를 위한 최종 Sandbox 판단은 후속 feature에 남깁니다.
- 번들 식별자, 제품 버전, 서명 방식, 로그인 항목, Helper와 외부 package 의존성은 변경하지 않습니다.

### 테스트 대상

- [ResourceRunnerTests](../../ResourceRunnerTests)는 다섯 정적 표현과 VoiceOver 값, 상태별 최소 프레임 수와 선로딩,
  상태별 기본·저전력 FPS, `CharacterFrameRateLimit`의 12 FPS 클램프와 초과 프로필 보고,
  잠금·동작 줄이기·저전력 조합의 프레임 일정 우선순위와 정지 사유 해제 후 복귀를 검증합니다.
- observer 등록 뒤 초기 조회, 시작 중 update 병합, 수집 일정 우선순위와 1·2·5초 선택, 중복 일정 억제,
  generation 교체, pause/resume 및 버퍼 용량·순서·resize를 검증합니다.
- 메모리 `SystemLifecycleSource`와 수동 시계로 `locked`·`unlocked`·`unknown`, UID 정수 정규화 후 불일치 무시,
  UID 해석 실패 시 알림 이름 적용, 최신 combined snapshot 보존, 낮거나 같은 revision 거부, 중복 수집 부재를 자동 검증합니다.
- `ScreenLockStateReader`의 세 매핑은 잠금 키 부재를 `unlocked`로 읽는 경우를 포함해 세션 사전 입력을 주입한 단위
  테스트로 검증합니다.
- [ResourceRunnerUITests](../../ResourceRunnerUITests)는 메뉴바 항목과 transient 팝오버의 자동화 가능한 실제 상호작용을
  담당합니다. 시스템 메뉴바 접근이 안정적이지 않은 동작은 AppKit 통합 상태와 현재 OS의 직접 관찰 근거를 함께 사용합니다.
- macOS 26.5 Apple silicon 환경에서 실제 잠금·해제와 5초 내외의 짧은 잠금·해제 순환에서 수집 중지·재개를 확인하고
  (SPEC §5.7), 앱·테스트 실행과 arm64 산출물을 확인합니다.

### 저장과 외부 경계

최근 샘플, 표시 상태와 캐시는 앱 메모리에만 존재합니다. 파일, `UserDefaults`, 네트워크, 텔레메트리와 외부 서버에는
기록하지 않습니다. M1은 사용자 설정 저장, 실제 Collector, 로그인 시 실행, 코드 서명·공증과 배포 형식을 변경하지 않습니다.

## 5. Decision Points

### DP1. 메뉴바와 팝오버 구성

- 옵션 A: SwiftUI `MenuBarExtra(.window)`를 사용합니다. 코드량은 적지만 상태 항목 폭, 이미지 프레임과 실제 닫힘
  생명주기를 세밀하게 소유하기 어렵습니다.
- 옵션 B: `NSStatusItem + NSPopover + NSHostingController`를 사용합니다. AppKit 코드는 늘지만 고정 폭, 프레임 교체,
  transient 닫힘과 SwiftUI 콘텐츠 경계가 명확합니다.
- 옵션 C: `NSStatusItem + NSPanel`을 사용합니다. 창 제어는 가장 크지만 외부 클릭, 위치, 포커스와 접근성을 직접 구현합니다.
- 채택안: 옵션 B. `ApplicationCoordinator`가 AppKit 객체를 소유하고 일반 창은 만들지 않습니다.

### DP2. 애니메이션과 정적 표현의 자산 구조

- 옵션 A: 현재 단일 얼굴을 모든 정적 상태에 재사용합니다. 자산은 적지만 SPEC §5.4의 정적 상태 구분을 충족하지 못합니다.
- 옵션 B: 전신 애니메이션의 정지 프레임을 재사용합니다. 연속성은 높지만 22pt에서 상태 구분이 약합니다.
- 옵션 C: 활성 상태는 전신 애니메이션, 정지 상태는 현재 기본 얼굴 외곽을 유지한 상태별 얼굴 5종으로 구성합니다.
- 채택안: 옵션 C. 제품 문서의 움직임 의미와 현재 기본 얼굴의 정체성을 유지하고 표정 형태와 VoiceOver로 상태를 구분합니다.
  같은 정적 얼굴을 동작 줄이기와 화면 잠금 정지에 함께 사용하므로 자산이 늘지 않습니다.

### DP3. 프레임 일정

- 옵션 A: 디스플레이 동기화 콜백에서 프레임을 건너뜁니다. 화면 주기와 맞지만 12 FPS 이하 표현을 위해 자주 깨어납니다.
- 옵션 B: `MainActor`의 저주기 타이머와 허용 오차를 사용하고 상태별 FPS로 재구성합니다.
- 채택안: 옵션 B. 최대 12 FPS 제약과 수집 일정 독립성을 직접 표현하고 수동 프레임 시계로 검증합니다.
  저전력 감속과 잠금 정지도 같은 재구성 경로로 처리합니다.

### DP4. 수집 일정 동시성

- 옵션 A: UI actor가 모든 생명주기 상태와 타이머를 소유합니다. 단순하지만 표시와 수집 책임이 섞입니다.
- 옵션 B: `MonitoringLifecycleStore` actor가 최종 snapshot과 일정 결정을, `MonitoringScheduler` actor가 Task와
  generation을, `MonitoringSampleStore` actor가 버퍼를 소유합니다.
- 옵션 C: Scheduler actor가 생명주기 snapshot과 버퍼까지 소유합니다. 타입은 적지만 입력·일정·이력 책임이 결합됩니다.
- 채택안: 옵션 B. 모든 입력을 `update(_:)`로 직렬화하고 결과 변경 때만 Scheduler를 호출해 중복 수집을 막습니다.

### DP5. 순환 버퍼 구현

- 옵션 A: 배열에 추가하고 초과 시 `removeFirst()`를 호출합니다. 구현은 단순하지만 제거 때마다 원소를 이동합니다.
- 옵션 B: 고정 저장 공간, 쓰기 위치와 개수를 가진 원형 배열을 사용합니다. 인덱스 계산은 필요하지만 추가 비용이 고정됩니다.
- 옵션 C: 외부 deque package를 추가합니다. 검증된 자료구조를 얻지만 M1 하나를 위해 새 의존성을 만듭니다.
- 채택안: 옵션 B. pause 중에는 유지하고 resume 때 새 유효 주기로 최신 샘플만 보존해 resize합니다.

### DP6. 화면 잠금 신호

- 옵션 A: 공개 `NSWorkspace` session·screen 알림을 잠금으로 해석합니다. 공개 API지만 실제 화면 잠금과 의미가 일치하지 않습니다.
  `com.apple.screensaver.didstart/didstop`도 화면 잠금에서 발화하지 않아 대체재가 되지 못합니다.
- 옵션 B: 현재 OS의 lock/unlock distributed notification과 `CGSessionCopyCurrentDictionary()` 세션 키를
  `ScreenLockStateReader`와 observer에 격리합니다. 잠금을 직접 다루지만 문서화되지 않은 OS 구현에 의존합니다.
- 옵션 C: 테스트용 주입만 제공하고 실행 앱의 잠금 입력은 생략합니다. 자동 정책 검증은 가능하지만 실제 생명주기를 충족하지 못합니다.
- 채택안: 옵션 B.

이 채택안은 `docs/design.md`의 `기술 방향`이 정한 "공개 macOS API를 우선하고 비공개 API를 1.0 필수 기능으로 가정하지
않는다"는 원칙과 충돌합니다. 화면 잠금 시 수집 중지는 ROADMAP 프로젝트 완료 기준 5번이 요구하는 1.0 필수 기능이므로
"필수 기능으로 가정하지 않는다"를 그대로 지키면 요구사항을 포기해야 합니다. 사용자 결정에 따라 원칙에 대한 검증된
예외로 채택하며, 근거와 경계는 다음과 같습니다.

- 예외 근거: 2026-08-06 실측에서 App Sandbox 앱에도 잠금·해제 알림이 배달되고 세션 사전을 읽을 수 있음을 확인했으며,
  같은 의미를 가진 공개 대체 신호는 SDK와 실측 어디에서도 확인되지 않았습니다.
- 격리 범위: 알림 이름과 세션 키 문자열은 `ScreenLockStateReader`와 `SystemLifecycleObserver` 하나의 어댑터에만 둡니다.
  나머지 계층과 자동 테스트는 `SystemLifecycleSource` 계약만 사용하므로 신호가 바뀌면 이 어댑터만 교체합니다.
- 매핑의 대가: 잠금 키 부재를 `unlocked`로 읽으므로, 이후 OS가 이 키 발행을 멈추면 잠긴 화면에서도 수집이 계속됩니다.
  반대 매핑은 현재 OS의 정상 해제 상태를 `unknown`으로 읽어 앱이 시작부터 영구히 pause하므로 채택할 수 없습니다.
  안전 방향은 한 단계 내려가지만 앱이 동작하지 않는 실패보다 낫습니다.
- 신호가 깨졌을 때의 대체 동작: 알림이 배달되지 않으면 초기 조회 결과가 유지되고, 세션 사전마저 얻지 못하면 `unknown`으로
  수집을 pause합니다. 어느 경우에도 메뉴바 항목, 팝오버와 캐릭터 표현은 계속 동작하며 프레임 정책은 `unknown`을
  정지 사유로 보지 않습니다. 잠금 대응만 비활성화되고 앱 기능은 유지됩니다.
- 배포 영향: 문서화되지 않은 신호 의존은 Mac App Store 심사에서 문제가 될 수 있어 M5의 배포 선택지를 좁힙니다.
  ROADMAP은 직접 배포를 우선 검토하고 Mac App Store는 별도 검증 후 결정하도록 두고 있으므로, 이 예외는 그 결정의
  입력으로 release-readiness에 넘깁니다. Helper나 관리자 권한은 추가하지 않습니다.

### DP7. 지원 범위와 Sandbox

- 옵션 A: deployment target 26.5를 유지하되 기본 아키텍처 설정을 사용합니다. 현재 빌드는 단순하지만 arm64 전용 산출물을
  설정에서 명시하지 못합니다.
- 옵션 B: 앱·테스트 대상의 deployment target을 26.5로 통일하고 앱 실행 파일을 arm64로 제한합니다.
- 채택안: 옵션 B. macOS 26.5 이상 Apple silicon이라는 SPEC §5.9를 프로젝트와 산출물에서 관찰 가능하게 만듭니다.
  App Sandbox는 유지하고 최종 정책은 실제 Collector 접근을 다루는 후속 feature에 남깁니다.

### DP8. 생명주기 초기화와 update 병합

- 옵션 A: 현재값을 먼저 읽고 관찰자를 등록합니다. 단순하지만 두 동작 사이의 상태 변경을 놓칠 수 있습니다.
- 옵션 B: combined snapshot stream을 먼저 만들고 모든 관찰자를 등록한 뒤 초기값을 읽습니다. 시작 중 callback은
  `MainActor`에서 직렬화하고 `.bufferingNewest(1)`로 최신 combined snapshot만 보존합니다.
- 옵션 C: 저전력과 화면 잠금을 별도 stream으로 전달합니다. source는 단순하지만 소비가 밀릴 때 한 필드 update가 다른 필드의
  최신값을 덮지 않도록 coordinator가 별도 병합 상태를 소유해야 합니다.
- 채택안: 옵션 B. source가 초기화 순서, revision과 두 시스템 필드의 병합을 단독 소유하고, coordinator는 initial snapshot을
  먼저 적용한 뒤 update를 소비합니다. 소비자는 낮거나 같은 revision을 거부해 시작 중 변경 유실과 오래된 snapshot 재적용을
  막으면서 일정 중복 제거 책임을 유지합니다.

### DP9. 잠금·해제 알림과 세션 사전의 우선순위

- 옵션 A: 알림을 받으면 세션 사전을 다시 읽어 사전 값을 우선합니다. 사전이 단일 진실 소스가 되지만, 해제 알림 시점에
  사전이 아직 잠김을 보고하는 경쟁이 실측으로 확인됐습니다. 이 경우 해제가 폐기돼 다음 잠금까지 pause에 갇힙니다.
- 옵션 B: 알림 처리에서는 notification 이름을 그대로 신뢰하고, 세션 사전은 시작 시 초기 상태와 세션 사용자 ID 조회에만
  씁니다. 사전의 지연 갱신에 영향을 받지 않지만 알림이 누락되면 상태가 그대로 유지됩니다.
- 옵션 C: 알림을 받은 뒤 짧게 지연하고 사전을 다시 읽어 확인합니다. 두 신호를 모두 쓰지만 필요한 지연 시간의 근거가 없고
  재개가 늦어집니다.
- 채택안: 옵션 B. 알림은 잠금·해제 시점에 맞춰 도착하고 사전은 늦게 따라오므로, 짧은 잠금·해제 순환에서 재개를 놓치지
  않는 것을 우선합니다. 알림 누락 위험은 잠금 상태가 오래 유지되는 경우에만 문제이고 그때는 사전도 갱신돼 있으므로
  다음 시작 시 초기 조회가 교정합니다. 이 선택이 SPEC §5.7의 짧은 순환 재개를 성립시킵니다.

### DP10. 저전력·잠금의 애니메이션 반영 경로

- 옵션 A: `MonitoringLifecycleStore`가 프레임 일정까지 계산해 표시 계층에 돌려줍니다. 정책이 한곳에 모이지만 수집 actor가
  표시 계층을 호출하게 되고 수집 일정과 프레임 일정이 같은 결정에 묶입니다.
- 옵션 B: coordinator가 같은 `SystemLifecycleSnapshot`을 두 store에 각각 전달하고, 표시 계층은 순수
  `CharacterFramePolicy`로 프레임 일정만 계산합니다. 시스템 관찰은 하나로 유지되고 두 일정은 독립합니다.
- 옵션 C: 표시 계층이 저전력·잠금을 직접 관찰합니다. 두 계층이 완전히 독립하지만 관찰자와 문서화되지 않은 잠금 신호
  해석이 두 곳으로 늘어나 DP6의 격리 범위가 무너집니다.
- 채택안: 옵션 B. 수집 일정과 프레임 일정이 독립이어야 한다는 제약을 유지하면서 같은 입력을 공유합니다.
  팝오버 상태는 프레임 정책 입력에서 제외해 팝오버 개폐가 캐릭터 표현을 끊지 않게 합니다.

### DP11. FPS 구성과 12 FPS 상한 검증

- 옵션 A: 상태별 FPS를 표시 계층 안의 상수로 둡니다. 코드는 짧지만 상태 집합이 닫혀 있고 FPS가 상태에 고정돼 있어
  상한을 넘는 입력을 만들 수 없고, 12 FPS 상한 정책을 코드에서 검증할 수 없습니다.
- 옵션 B: 상태별 기본·저전력 FPS를 `CharacterPresentationProfileSet`으로 표시 계층 바깥에서 주입하고,
  순수 `CharacterFrameRateLimit`가 1...12로 클램프하며 구성 검증이 초과 항목을 보고합니다. 타입이 하나 늘지만
  테스트가 상한 초과 프로필을 구성해 상한이 실제로 걸리는지 관찰할 수 있습니다.
- 옵션 C: 최대 FPS를 사용자 설정으로 노출합니다. `docs/product.md`의 최종 형태지만 설정 저장은 M4 범위이고
  M1 제외 범위입니다.
- 채택안: 옵션 B. 기본 프로필의 최대값은 10이라 production 경로만으로는 상한을 확인할 수 없으므로, 상한 정책을
  검증 가능한 위치로 끌어내는 최소 구성을 택합니다.
