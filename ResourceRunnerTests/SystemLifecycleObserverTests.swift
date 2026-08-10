//
//  SystemLifecycleObserverTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/10/26.
//

import Foundation
import Testing
@testable import ResourceRunner

/// 여러 테스트가 "소비 Task가 실제로 값을 받을 때까지" 기다리는 데 공유하는 폴링 helper.
/// `CharacterStateSourceTests`가 쓰는 것과 같은 패턴입니다 — 소비 Task는 `MainActor`에서
/// 협력적으로 스케줄되므로 `Task.yield()`를 반복해 실행 기회를 줘야 합니다.
@MainActor
private func waitUntil(maxIterations: Int = 10_000, _ condition: () -> Bool) async {
    var iterations = 0
    while !condition() && iterations < maxIterations {
        await Task.yield()
        iterations += 1
    }
}

/// 매번 다른 값을 순서대로 돌려주는 저전력 값 소스.
/// 등록 창에서 도착한 알림이 읽은 값과 이후 초기 조회가 읽은 값을 서로 다르게 만들어야
/// 두 시점의 값이 실제로 구분돼 반영되는지(우연히 같아서 통과하는 상황이 아닌지) 확인할 수 있습니다.
private final class SequencedValueSource<Value>: @unchecked Sendable {
    private var values: [Value]

    init(_ values: [Value]) {
        self.values = values
    }

    func next() -> Value {
        values.removeFirst()
    }
}

/// `addObserver(forName:object:queue:using:)` 호출 시점을 기록하는 테스트용 `NotificationCenter`.
/// `SystemLifecycleObserver.start()`가 저전력 notification 등록을 초기 조회보다 먼저 하는지(DP8)
/// 직접 관찰하는 데 씁니다.
private final class OrderTrackingNotificationCenter: NotificationCenter {
    var onAddObserver: (() -> Void)?

    override func addObserver(
        forName name: NSNotification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping (Notification) -> Void
    ) -> NSObjectProtocol {
        onAddObserver?()
        return super.addObserver(forName: name, object: obj, queue: queue, using: block)
    }
}

/// task-005 검증 조건: 「initial snapshot의 revision은 0이고 이후 변경마다 증가하며,
/// 값이 같은 연속 snapshot은 제거됩니다」, 「소비가 밀리면 저전력과 화면 잠금을 함께 담은 최신
/// combined snapshot 하나만 남고, 한 필드의 갱신이 다른 필드의 최신값을 이전 값으로 되돌리지 않습니다」를
/// 내부 직렬 생산자 자체에 직접 검증합니다. `SystemLifecycleObserver`와 `MemorySystemLifecycleSource`가
/// 모두 이 생산자를 거치므로, 여기서 검증한 병합 규칙은 두 구현 모두에 적용됩니다.
@MainActor
struct CombinedSnapshotProducerTests {

    private func makeProducer(
        initial: SystemLifecycleSnapshot
    ) -> (producer: CombinedSnapshotProducer, stream: AsyncStream<SystemLifecycleSnapshot>) {
        var continuationSlot: AsyncStream<SystemLifecycleSnapshot>.Continuation!
        let stream = AsyncStream<SystemLifecycleSnapshot>(bufferingPolicy: .bufferingNewest(1)) {
            continuationSlot = $0
        }
        let producer = CombinedSnapshotProducer(initial: initial, continuation: continuationSlot!)
        return (producer, stream)
    }

    @Test func revisionIncrementsOnlyWhenFieldActuallyChanges() {
        let initial = SystemLifecycleSnapshot(revision: 0, lowPowerMode: false, screenLockState: .unlocked)
        let (producer, _) = makeProducer(initial: initial)

        producer.apply(.screenLock(.locked))
        #expect(producer.currentSnapshot.revision == 1)
        #expect(producer.currentSnapshot.screenLockState == .locked)

        producer.apply(.screenLock(.locked)) // 같은 값 -> 연속 snapshot 제거
        #expect(producer.currentSnapshot.revision == 1)
    }

    @Test func fieldUpdateDoesNotRevertOtherFieldsLatestValue() {
        // 초기값을 두 필드 모두 default가 아닌 값으로 둬야, 한쪽 case가 다른 쪽 필드를
        // default로 덮어써도 우연히 값이 같아 통과하는 상황을 막을 수 있습니다.
        let initial = SystemLifecycleSnapshot(revision: 0, lowPowerMode: true, screenLockState: .unknown)
        let (producer, _) = makeProducer(initial: initial)

        producer.apply(.screenLock(.locked))
        #expect(producer.currentSnapshot.lowPowerMode == true) // screenLock 갱신이 lowPower를 되돌리지 않음
        #expect(producer.currentSnapshot.screenLockState == .locked)

        producer.apply(.lowPowerMode(false))
        #expect(producer.currentSnapshot.screenLockState == .locked) // lowPower 갱신이 screenLock을 되돌리지 않음
        #expect(producer.currentSnapshot.lowPowerMode == false)
        #expect(producer.currentSnapshot.revision == 2)
    }

    @Test func emitsChangesInArrivalOrderWithDuplicatesRemoved() async {
        let initial = SystemLifecycleSnapshot(revision: 0, lowPowerMode: false, screenLockState: .unlocked)
        let (producer, stream) = makeProducer(initial: initial)

        var received: [SystemLifecycleSnapshot] = []
        let collector = Task { @MainActor in
            for await snapshot in stream {
                received.append(snapshot)
            }
        }

        producer.apply(.screenLock(.locked))
        await waitUntil { received.count >= 1 }
        producer.apply(.screenLock(.locked)) // 중복 -> 새 이벤트 없음
        producer.apply(.screenLock(.unlocked))
        await waitUntil { received.count >= 2 }

        collector.cancel()

        #expect(received.map(\.revision) == [1, 2])
        #expect(received.map(\.screenLockState) == [.locked, .unlocked])
    }

    @Test func lagInConsumptionKeepsOnlyLatestCombinedSnapshot() async {
        let initial = SystemLifecycleSnapshot(revision: 0, lowPowerMode: false, screenLockState: .unlocked)
        let (producer, stream) = makeProducer(initial: initial)

        // 소비를 시작하기 전에 연달아 갱신합니다. `.bufferingNewest(1)`이라 가장 최신 조합만 남아야 합니다.
        producer.apply(.screenLock(.locked))
        producer.apply(.lowPowerMode(true))
        producer.apply(.screenLock(.unknown))

        var iterator = stream.makeAsyncIterator()
        let first = await iterator.next()

        #expect(first == SystemLifecycleSnapshot(revision: 3, lowPowerMode: true, screenLockState: .unknown))
    }
}

/// task-005 검증 조건: 「`start()`는 stream 생성 → 관찰자 등록 → 초기값 조회 순서로 진행」,
/// 「등록 뒤 초기 조회가 끝나기 전에 도착한 callback은 버려지지 않고 initial 값 위에 도착 순서대로
/// 반영됩니다」를 주입 잠금 신호로 검증합니다.
@MainActor
struct SystemLifecycleObserverTests {

    @Test func startRegistersScreenLockObserverBeforeReadingInitialState() {
        var callOrder: [String] = []
        let observer = SystemLifecycleObserver(
            notificationCenter: NotificationCenter(),
            readInitialScreenLockState: {
                callOrder.append("readInitial")
                return .unlocked
            },
            registerScreenLockObserver: { _ in
                callOrder.append("register")
            }
        )

        _ = observer.start()

        #expect(callOrder == ["register", "readInitial"])
    }

    /// `registerScreenLockObserver`가 호출되는 시점(등록)이 초기 조회보다 앞서는 것과 마찬가지로,
    /// 저전력 notification 등록(`addObserver`)도 `readLowPowerMode()` 호출(초기 조회)보다 앞서야 합니다.
    @Test func startRegistersLowPowerObserverBeforeReadingInitialLowPowerMode() {
        var callOrder: [String] = []
        let notificationCenter = OrderTrackingNotificationCenter()
        notificationCenter.onAddObserver = { callOrder.append("register") }

        let observer = SystemLifecycleObserver(
            notificationCenter: notificationCenter,
            readLowPowerMode: {
                callOrder.append("readLowPowerMode")
                return false
            },
            readInitialScreenLockState: { .unlocked },
            registerScreenLockObserver: { _ in }
        )

        _ = observer.start()

        #expect(callOrder == ["register", "readLowPowerMode"])
    }

    /// 등록과 초기 조회 사이 창에서 저전력 알림과 잠금 callback이 섞여 도착하는 경우를 검증합니다.
    /// `registerScreenLockObserver`의 클로저는 초기 조회보다 먼저 실행되므로, 그 안에서
    /// 저전력 notification을 post해 "등록 창에서 도착한 저전력 callback"을 만들고,
    /// 뒤이어 잠금 callback을 흘려 두 필드가 도착 순서대로, 서로의 최신값을 되돌리지 않고
    /// 병합되는지 확인합니다.
    @Test func lowPowerAndScreenLockCallbacksDuringRegistrationMergeInArrivalOrder() async {
        let notificationCenter = NotificationCenter()
        // 첫 호출(등록 창에서 도착한 저전력 알림 처리)은 true, 두 번째 호출(초기 조회)은 false를 돌려줘
        // 두 시점의 값이 실제로 다른 상황을 만듭니다.
        let lowPowerValues = SequencedValueSource([true, false])

        let observer = SystemLifecycleObserver(
            notificationCenter: notificationCenter,
            readLowPowerMode: { lowPowerValues.next() },
            readInitialScreenLockState: { .unlocked },
            registerScreenLockObserver: { onChange in
                notificationCenter.post(name: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil)
                onChange(.locked)
            }
        )

        let subscription = observer.start()
        #expect(subscription.initial.lowPowerMode == false)
        #expect(subscription.initial.screenLockState == .unlocked)

        var received: [SystemLifecycleSnapshot] = []
        let collector = Task { @MainActor in
            for await snapshot in subscription.updates {
                received.append(snapshot)
            }
        }
        await waitUntil { received.count >= 2 }
        collector.cancel()

        #expect(received.map(\.revision) == [1, 2])
        #expect(received[0].lowPowerMode == true)
        #expect(received[0].screenLockState == .unlocked) // 저전력 갱신이 아직 오지 않은 잠금 값을 되돌리지 않음
        #expect(received[1].lowPowerMode == true) // 잠금 갱신이 저전력 최신값을 되돌리지 않음
        #expect(received[1].screenLockState == .locked)
    }

    @Test func initialSnapshotRevisionIsAlwaysZero() {
        let observer = SystemLifecycleObserver(
            notificationCenter: NotificationCenter(),
            readInitialScreenLockState: { .locked },
            registerScreenLockObserver: { _ in }
        )

        let subscription = observer.start()

        #expect(subscription.initial.revision == 0)
        #expect(subscription.initial.screenLockState == .locked)
    }

    /// `registerScreenLockObserver`가 호출되는 시점(등록)은 항상 `readInitialScreenLockState`
    /// 호출(초기 조회)보다 앞서므로, 등록 클로저 안에서 곧바로 콜백을 흘려보내면 "등록 뒤 초기 조회가
    /// 끝나기 전에 도착한 callback"과 같은 상황을 만들 수 있습니다.
    @Test func callbackArrivingDuringRegistrationIsNotDroppedAndAppliesOnTopOfInitial() async {
        let observer = SystemLifecycleObserver(
            notificationCenter: NotificationCenter(),
            readInitialScreenLockState: { .unlocked },
            registerScreenLockObserver: { onChange in
                onChange(.locked)
            }
        )

        let subscription = observer.start()
        #expect(subscription.initial.revision == 0)
        #expect(subscription.initial.screenLockState == .unlocked)

        var received: [SystemLifecycleSnapshot] = []
        let collector = Task { @MainActor in
            for await snapshot in subscription.updates {
                received.append(snapshot)
            }
        }
        await waitUntil { received.count >= 1 }
        collector.cancel()

        guard let first = received.first else {
            Issue.record("등록 중 도착한 callback이 반영된 update를 받지 못했습니다.")
            return
        }
        #expect(first.revision == 1)
        #expect(first.screenLockState == .locked)
        #expect(first.lowPowerMode == subscription.initial.lowPowerMode)
    }

    /// 등록 중 도착한 callback이 둘 이상이면 도착 순서를 그대로 지켜야 합니다.
    @Test func multipleCallbacksDuringRegistrationApplyInArrivalOrder() async {
        let observer = SystemLifecycleObserver(
            notificationCenter: NotificationCenter(),
            readInitialScreenLockState: { .unlocked },
            registerScreenLockObserver: { onChange in
                onChange(.locked)
                onChange(.unknown)
                onChange(.unlocked)
            }
        )

        let subscription = observer.start()

        var received: [SystemLifecycleSnapshot] = []
        let collector = Task { @MainActor in
            for await snapshot in subscription.updates {
                received.append(snapshot)
            }
        }
        await waitUntil { received.count >= 3 }
        collector.cancel()

        #expect(received.map(\.screenLockState) == [.locked, .unknown, .unlocked])
        #expect(received.map(\.revision) == [1, 2, 3])
    }

    /// 위 테스트와 달리 `updates`를 소비하지 않은 채로 raw event 처리가 끝날 시간을 준 뒤 소비를 시작해,
    /// `SystemLifecycleObserver.start()`가 실제로 `.bufferingNewest(1)` stream을 반환하는지 직접 확인합니다.
    /// (내부 raw event queue는 무제한이라 세 콜백 모두 소비되지만, `updates`에는 최신 조합 하나만 남아야 합니다.)
    @Test func lagInConsumingUpdatesKeepsOnlyLatestCombinedSnapshot() async {
        let observer = SystemLifecycleObserver(
            notificationCenter: NotificationCenter(),
            readInitialScreenLockState: { .unlocked },
            registerScreenLockObserver: { onChange in
                onChange(.locked)
                onChange(.unknown)
                onChange(.unlocked)
            }
        )

        let subscription = observer.start()

        // `updates`를 아직 소비하지 않은 채로, 내부 소비 Task가 raw event 세 건을 모두 처리할
        // 협력 스케줄링 기회를 줍니다.
        for _ in 0..<200 {
            await Task.yield()
        }

        var iterator = subscription.updates.makeAsyncIterator()
        let first = await iterator.next()

        #expect(first?.revision == 3)
        #expect(first?.screenLockState == .unlocked)
    }
}

/// task-005 접근 조건: 자동 테스트용 메모리 `SystemLifecycleSource` 구현.
/// task-009·task-011 같은 이후 Task가 실제 화면 잠금 어댑터 없이 조합 snapshot을 주입하는 데 씁니다.
@MainActor
struct MemorySystemLifecycleSourceTests {

    @Test func initialSnapshotUsesGivenValuesWithRevisionZero() {
        let source = MemorySystemLifecycleSource(initialLowPowerMode: true, initialScreenLockState: .unknown)

        let subscription = source.start()

        #expect(subscription.initial == SystemLifecycleSnapshot(revision: 0, lowPowerMode: true, screenLockState: .unknown))
    }

    @Test func sendUpdatesPreserveOtherFieldAndIncrementRevisionInOrder() async {
        let source = MemorySystemLifecycleSource(initialLowPowerMode: false, initialScreenLockState: .unlocked)
        let subscription = source.start()

        var received: [SystemLifecycleSnapshot] = []
        let collector = Task { @MainActor in
            for await snapshot in subscription.updates {
                received.append(snapshot)
            }
        }

        source.sendScreenLockState(.locked)
        await waitUntil { received.count >= 1 }
        source.sendLowPowerMode(true)
        await waitUntil { received.count >= 2 }

        collector.cancel()

        #expect(received == [
            SystemLifecycleSnapshot(revision: 1, lowPowerMode: false, screenLockState: .locked),
            SystemLifecycleSnapshot(revision: 2, lowPowerMode: true, screenLockState: .locked),
        ])
    }

    @Test func sendBeforeStartHasNoEffect() {
        let source = MemorySystemLifecycleSource()

        source.sendLowPowerMode(true) // start() 전이므로 무시되어야 하며 크래시가 없어야 합니다.

        let subscription = source.start()
        #expect(subscription.initial.lowPowerMode == false)
    }

    /// `MemorySystemLifecycleSource.start()`가 실제로 `.bufferingNewest(1)` stream을 반환하는지
    /// 소비를 미룬 채 직접 확인합니다.
    @Test func lagInConsumingUpdatesKeepsOnlyLatestSnapshot() async {
        let source = MemorySystemLifecycleSource(initialLowPowerMode: false, initialScreenLockState: .unlocked)
        let subscription = source.start()

        source.sendScreenLockState(.locked)
        source.sendLowPowerMode(true)
        source.sendScreenLockState(.unknown)

        var iterator = subscription.updates.makeAsyncIterator()
        let first = await iterator.next()

        #expect(first == SystemLifecycleSnapshot(revision: 3, lowPowerMode: true, screenLockState: .unknown))
    }
}
