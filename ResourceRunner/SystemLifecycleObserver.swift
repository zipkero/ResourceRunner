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
