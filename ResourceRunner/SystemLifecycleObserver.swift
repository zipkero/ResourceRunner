//
//  SystemLifecycleObserver.swift
//  ResourceRunner
//
//  Created by zipkero on 8/10/26.
//

import Foundation

/// 화면 잠금 상태 세 값의 닫힌 집합.
/// 실제 판정 규칙(세션 사전 해석)은 task-006이 담당하며, 이 타입은 결과 값만 정의합니다.
/// 값 타입이라 어느 격리에서도 비교·전달할 수 있어야 하므로 `nonisolated`로 선언합니다.
nonisolated enum ScreenLockState: Sendable, Equatable {
    case locked
    case unlocked
    case unknown
}

/// 저전력 모드와 화면 잠금을 하나로 묶은 combined snapshot.
/// `revision`은 initial에서 0으로 시작해 필드 값이 실제로 바뀔 때마다 증가합니다.
nonisolated struct SystemLifecycleSnapshot: Sendable, Equatable {
    let revision: Int
    let lowPowerMode: Bool
    let screenLockState: ScreenLockState
}

/// initial snapshot과 `.bufferingNewest(1)`인 이후 update stream을 묶는 값.
nonisolated struct SystemLifecycleSubscription: Sendable {
    let initial: SystemLifecycleSnapshot
    let updates: AsyncStream<SystemLifecycleSnapshot>
}

/// combined snapshot의 초기값과 stream을 제공하는 주입 가능 계약.
/// `start()`는 한 번만 호출하며 stream 생성 → 관찰자 등록 → 초기값 조회 순서를 지킵니다.
@MainActor
protocol SystemLifecycleSource: AnyObject {
    func start() -> SystemLifecycleSubscription
}

/// combined snapshot 중 한쪽 필드의 갱신 이벤트.
/// `SystemLifecycleObserver`의 실제 시스템 callback과 `MemorySystemLifecycleSource`의 주입이
/// 같은 이벤트 모양을 거쳐 같은 병합 규칙을 통과하도록 합니다.
nonisolated enum SystemLifecycleFieldChange: Sendable {
    case lowPowerMode(Bool)
    case screenLock(ScreenLockState)
}

/// 등록 뒤 도착한 이벤트를 도착 순서대로 병합해 combined snapshot을 만드는 내부 직렬 생산자.
/// `MainActor`에서 현재 snapshot을 소유하며, 다른 queue에서 도착한 시스템 callback은
/// 이 타입을 직접 호출하지 않고 `AsyncStream` continuation을 거쳐 여기로 들어옵니다.
/// 갱신마다 항상 현재 snapshot 전체를 기준으로 바뀐 필드만 교체하므로, 한 필드의 갱신이
/// 다른 필드의 최신값을 이전 값으로 되돌리지 않습니다. 값이 같은 연속 snapshot은 만들지 않습니다.
final class CombinedSnapshotProducer {
    private(set) var currentSnapshot: SystemLifecycleSnapshot
    private let continuation: AsyncStream<SystemLifecycleSnapshot>.Continuation

    init(initial: SystemLifecycleSnapshot, continuation: AsyncStream<SystemLifecycleSnapshot>.Continuation) {
        self.currentSnapshot = initial
        self.continuation = continuation
    }

    /// 이벤트 하나를 현재 snapshot에 병합합니다. 값이 바뀔 때만 revision을 올리고 stream에 내보냅니다.
    func apply(_ change: SystemLifecycleFieldChange) {
        let lowPowerMode: Bool
        let screenLockState: ScreenLockState
        switch change {
        case .lowPowerMode(let value):
            lowPowerMode = value
            screenLockState = currentSnapshot.screenLockState
        case .screenLock(let value):
            lowPowerMode = currentSnapshot.lowPowerMode
            screenLockState = value
        }

        guard lowPowerMode != currentSnapshot.lowPowerMode || screenLockState != currentSnapshot.screenLockState else {
            return
        }

        let updated = SystemLifecycleSnapshot(
            revision: currentSnapshot.revision + 1,
            lowPowerMode: lowPowerMode,
            screenLockState: screenLockState
        )
        currentSnapshot = updated
        continuation.yield(updated)
    }
}

/// `CGSessionCopyCurrentDictionary()`는 공개 헤더가 없는 문서화되지 않은 API라
/// 심볼을 직접 선언합니다. DP6 채택안(옵션 B)에 따라 이 파일에만 존재해야 합니다.
@_silgen_name("CGSessionCopyCurrentDictionary")
private func CGSessionCopyCurrentDictionary() -> CFDictionary?

/// 세션 사전에서 화면 잠금 상태를 읽는 순수 판정 규칙.
/// 문서화되지 않은 세션 키 문자열(`CGSSessionScreenIsLocked`)은 이 타입에만 존재합니다.
/// 값 타입이 아니지만 저장 상태가 없는 순수 계산이라 `nonisolated`로 선언해 어느 격리에서도 호출할 수 있습니다.
nonisolated enum ScreenLockStateReader {
    static let lockedKey = "CGSSessionScreenIsLocked"

    /// 잠금 키가 Boolean `true`면 `locked`, `false`거나 키가 없으면 `unlocked`,
    /// 사전이 `nil`이거나 잠금 키를 Boolean으로 해석할 수 없으면 `unknown`.
    static func read(from sessionDictionary: [String: Any]?) -> ScreenLockState {
        guard let sessionDictionary else {
            return .unknown
        }
        guard let lockedValue = sessionDictionary[lockedKey] else {
            return .unlocked
        }
        guard let locked = lockedValue as? Bool else {
            return .unknown
        }
        return locked ? .locked : .unlocked
    }

    /// 세션 사전 값과 notification object를 같은 방식으로 비교하려면 둘 다 정수로 정규화해야 합니다.
    /// object는 문자열, 세션 사전 값은 32-bit unsigned integer라 정규화 없이는 항상 불일치합니다.
    static func normalizeSessionUserID(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }
}

/// macOS 26.5 전용 화면 잠금 관찰 어댑터.
/// 문서화되지 않은 알림 이름(`com.apple.screenIsLocked`·`com.apple.screenIsUnlocked`)과
/// 세션 사용자 ID 키(`kCGSSessionUserIDKey`)는 이 타입에만 존재합니다.
/// `SystemLifecycleObserver`의 `readInitialScreenLockState`·`registerScreenLockObserver` 주입점에
/// 이 어댑터가 만든 클로저를 연결하면 실제 macOS 화면 잠금·해제를 관찰합니다.
/// DP9 채택안에 따라 세션 사전은 초기 조회에서 세션 사용자 ID를 캐시하는 데만 쓰고,
/// 알림 처리 경로에서는 사전을 다시 읽지 않고 notification 이름을 그대로 신뢰합니다.
final class ScreenLockObservationAdapter {
    private static let lockedNotificationName = Notification.Name("com.apple.screenIsLocked")
    private static let unlockedNotificationName = Notification.Name("com.apple.screenIsUnlocked")
    private static let sessionUserIDKey = "kCGSSessionUserIDKey"

    // 자동 테스트가 실제 distributed notification(시스템 전역에 배달됨)을 발생시키지 않도록,
    // 타입은 production 기본값(`DistributedNotificationCenter.default()`)이 만족하는 `NotificationCenter`로
    // 두고 테스트에서는 이 프로세스 안에서만 도는 일반 `NotificationCenter`를 주입합니다.
    private let distributedNotificationCenter: NotificationCenter
    private let readSessionDictionary: () -> [String: Any]?

    /// 알림 callback이 도착하는 스레드에서도 안전하게 읽고 쓸 수 있어야 하므로
    /// actor 격리 대신 lock으로 보호합니다.
    private let cachedSessionUserIDLock = NSLock()
    private var cachedSessionUserID: Int?

    private var tokens: [NSObjectProtocol] = []

    init(
        distributedNotificationCenter: NotificationCenter = DistributedNotificationCenter.default(),
        readSessionDictionary: @escaping () -> [String: Any]? = {
            CGSessionCopyCurrentDictionary() as? [String: Any]
        }
    ) {
        self.distributedNotificationCenter = distributedNotificationCenter
        self.readSessionDictionary = readSessionDictionary
    }

    deinit {
        for token in tokens {
            distributedNotificationCenter.removeObserver(token)
        }
    }

    /// 초기 잠금 상태를 조회하면서 이후 알림 처리에서 쓸 세션 사용자 ID를 함께 캐시합니다.
    func readInitialScreenLockState() -> ScreenLockState {
        let sessionDictionary = readSessionDictionary()
        let sessionUserID = ScreenLockStateReader.normalizeSessionUserID(sessionDictionary?[Self.sessionUserIDKey])
        cachedSessionUserIDLock.withLock { cachedSessionUserID = sessionUserID }
        return ScreenLockStateReader.read(from: sessionDictionary)
    }

    /// 잠금·해제 distributed notification을 등록합니다.
    /// object와 캐시한 세션 사용자 ID가 둘 다 정수로 해석되고 값이 다를 때만 다른 GUI 세션의 이벤트로 보고 무시합니다.
    /// 그 밖의 모든 경우(값이 같거나 어느 한쪽이라도 정수로 해석되지 않으면) notification 이름을 그대로 적용합니다.
    func registerScreenLockObserver(_ onChange: @escaping @Sendable (ScreenLockState) -> Void) {
        let cachedSessionUserIDLock = cachedSessionUserIDLock
        let readCachedSessionUserID: () -> Int? = { [weak self] in
            guard let self else { return nil }
            return cachedSessionUserIDLock.withLock { self.cachedSessionUserID }
        }

        let lockedToken = distributedNotificationCenter.addObserver(
            forName: Self.lockedNotificationName,
            object: nil,
            queue: nil
        ) { notification in
            Self.handle(notification, candidate: .locked, readCachedSessionUserID: readCachedSessionUserID, onChange: onChange)
        }
        let unlockedToken = distributedNotificationCenter.addObserver(
            forName: Self.unlockedNotificationName,
            object: nil,
            queue: nil
        ) { notification in
            Self.handle(notification, candidate: .unlocked, readCachedSessionUserID: readCachedSessionUserID, onChange: onChange)
        }
        tokens = [lockedToken, unlockedToken]
    }

    // 자동 테스트가 실제 알림 등록·배달 없이 판정 규칙만 직접 검증할 수 있도록 module 내부에 노출합니다.
    static func handle(
        _ notification: Notification,
        candidate: ScreenLockState,
        readCachedSessionUserID: () -> Int?,
        onChange: @Sendable (ScreenLockState) -> Void
    ) {
        let objectUserID = ScreenLockStateReader.normalizeSessionUserID(notification.object)
        let cachedSessionUserID = readCachedSessionUserID()
        if let objectUserID, let cachedSessionUserID, objectUserID != cachedSessionUserID {
            return // 다른 GUI 세션의 이벤트이므로 무시합니다.
        }
        onChange(candidate)
    }
}

/// 저전력 모드와 화면 잠금을 하나의 관찰 지점에서 읽는 production 어댑터.
/// 저전력은 `NSNotification.Name.NSProcessInfoPowerStateDidChange`로 변경을 관찰하고,
/// 실제 값 조회는 `readLowPowerMode` 클로저로 주입받습니다(기본값은 `ProcessInfo.isLowPowerModeEnabled`).
/// 화면 잠금과 마찬가지로 자동 테스트가 실제 시스템 상태를 바꿀 수 없으므로,
/// 이 주입점이 있어야 저전력 쪽 병합·순서 규칙도 검증할 수 있습니다.
/// 화면 잠금은 이 Task의 범위가 아니므로(task-006 소관) 초기 조회와 이후 변경 등록을
/// 생성자로 주입받습니다. task-006은 이 두 클로저를 실제 macOS 어댑터로 채웁니다.
final class SystemLifecycleObserver: SystemLifecycleSource {
    private let notificationCenter: NotificationCenter
    private let readLowPowerMode: @Sendable () -> Bool
    private let readInitialScreenLockState: () -> ScreenLockState
    private let registerScreenLockObserver: (@escaping @Sendable (ScreenLockState) -> Void) -> Void

    private var powerStateToken: NSObjectProtocol?
    private var producer: CombinedSnapshotProducer?
    private var consumerTask: Task<Void, Never>?

    init(
        notificationCenter: NotificationCenter = .default,
        readLowPowerMode: @escaping @Sendable () -> Bool = { ProcessInfo.processInfo.isLowPowerModeEnabled },
        readInitialScreenLockState: @escaping () -> ScreenLockState,
        registerScreenLockObserver: @escaping (@escaping @Sendable (ScreenLockState) -> Void) -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.readLowPowerMode = readLowPowerMode
        self.readInitialScreenLockState = readInitialScreenLockState
        self.registerScreenLockObserver = registerScreenLockObserver
    }

    deinit {
        if let powerStateToken {
            notificationCenter.removeObserver(powerStateToken)
        }
    }

    /// stream 생성 → 관찰자 등록 → 초기값 조회 순서로 진행합니다(DP8 채택안).
    /// 이 메서드는 중단 없이 동기로 끝나므로, 등록 중 도착한 callback은 내부 raw event stream에
    /// 쌓였다가 이 메서드가 반환한 뒤 시작되는 소비 Task가 initial 값 위에 도착 순서대로 반영합니다.
    func start() -> SystemLifecycleSubscription {
        var updatesContinuationSlot: AsyncStream<SystemLifecycleSnapshot>.Continuation!
        let updates = AsyncStream<SystemLifecycleSnapshot>(bufferingPolicy: .bufferingNewest(1)) {
            updatesContinuationSlot = $0
        }
        let updatesContinuation = updatesContinuationSlot!

        var rawContinuationSlot: AsyncStream<SystemLifecycleFieldChange>.Continuation!
        let rawEvents = AsyncStream<SystemLifecycleFieldChange>(bufferingPolicy: .unbounded) {
            rawContinuationSlot = $0
        }
        let rawContinuation = rawContinuationSlot!

        let readLowPowerMode = readLowPowerMode
        powerStateToken = notificationCenter.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: nil
        ) { _ in
            rawContinuation.yield(.lowPowerMode(readLowPowerMode()))
        }

        registerScreenLockObserver { state in
            rawContinuation.yield(.screenLock(state))
        }

        let initial = SystemLifecycleSnapshot(
            revision: 0,
            lowPowerMode: readLowPowerMode(),
            screenLockState: readInitialScreenLockState()
        )

        let producer = CombinedSnapshotProducer(initial: initial, continuation: updatesContinuation)
        self.producer = producer
        consumerTask = Task { @MainActor in
            for await change in rawEvents {
                producer.apply(change)
            }
        }

        return SystemLifecycleSubscription(initial: initial, updates: updates)
    }
}

extension SystemLifecycleObserver {
    /// `ScreenLockObservationAdapter`를 실제 macOS 화면 잠금 신호에 연결한 production 인스턴스를 만듭니다.
    /// 어댑터를 클로저 캡처로 계속 붙잡고 있어야 등록한 알림 관찰이 살아 있으므로,
    /// 이 인스턴스가 살아있는 동안에만 실제 잠금·해제를 관찰합니다.
    static func makeMacOSAdapter(notificationCenter: NotificationCenter = .default) -> SystemLifecycleObserver {
        let screenLockAdapter = ScreenLockObservationAdapter()
        return SystemLifecycleObserver(
            notificationCenter: notificationCenter,
            readInitialScreenLockState: { screenLockAdapter.readInitialScreenLockState() },
            registerScreenLockObserver: { onChange in screenLockAdapter.registerScreenLockObserver(onChange) }
        )
    }
}

/// 자동 테스트용 메모리 `SystemLifecycleSource` 구현.
/// 실제 저전력·화면 잠금 관찰 없이 `send(_:)`로 combined snapshot 변경을 직접 주입할 수 있어,
/// task-006 이전까지 생명주기 store·Scheduler 같은 이후 계층을 검증하는 데 사용합니다.
final class MemorySystemLifecycleSource: SystemLifecycleSource {
    private let initialLowPowerMode: Bool
    private let initialScreenLockState: ScreenLockState
    private var producer: CombinedSnapshotProducer?

    init(initialLowPowerMode: Bool = false, initialScreenLockState: ScreenLockState = .unlocked) {
        self.initialLowPowerMode = initialLowPowerMode
        self.initialScreenLockState = initialScreenLockState
    }

    func start() -> SystemLifecycleSubscription {
        var continuationSlot: AsyncStream<SystemLifecycleSnapshot>.Continuation!
        let updates = AsyncStream<SystemLifecycleSnapshot>(bufferingPolicy: .bufferingNewest(1)) {
            continuationSlot = $0
        }

        let initial = SystemLifecycleSnapshot(
            revision: 0,
            lowPowerMode: initialLowPowerMode,
            screenLockState: initialScreenLockState
        )
        producer = CombinedSnapshotProducer(initial: initial, continuation: continuationSlot!)
        return SystemLifecycleSubscription(initial: initial, updates: updates)
    }

    /// 저전력 모드 변경을 주입합니다. `start()` 호출 전에는 아무 효과가 없습니다.
    func sendLowPowerMode(_ value: Bool) {
        producer?.apply(.lowPowerMode(value))
    }

    /// 화면 잠금 상태 변경을 주입합니다. `start()` 호출 전에는 아무 효과가 없습니다.
    func sendScreenLockState(_ value: ScreenLockState) {
        producer?.apply(.screenLock(value))
    }
}
