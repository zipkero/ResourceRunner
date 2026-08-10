//
//  MonitoringLifecycle.swift
//  ResourceRunner
//
//  Created by zipkero on 8/10/26.
//

import Foundation

/// 팝오버 열림·저전력 모드·화면 잠금을 하나로 묶은 수집 일정 결정용 최종 snapshot.
/// `MonitoringLifecycleStore`가 단독 소유하며, 값 타입이라 어느 격리에서도 전달할 수 있어야 하므로
/// `nonisolated`로 선언합니다.
nonisolated struct MonitoringLifecycle: Sendable, Equatable {
    let popoverPresented: Bool
    let lowPowerMode: Bool
    let screenLockState: ScreenLockState
}

/// `MonitoringLifecycleStore.update(_:)`가 받는 입력 이벤트.
/// 팝오버 이벤트에는 revision 개념이 없어 항상 반영되고, system snapshot은 store가 revision을 확인합니다.
nonisolated enum MonitoringLifecycleEvent: Sendable {
    case popoverPresented(Bool)
    case systemSnapshot(SystemLifecycleSnapshot)
}

/// `CollectionSchedulePolicy`가 계산하는 결과. `MonitoringScheduler.apply(_:)`의 입력이기도 합니다.
nonisolated enum CollectionSchedule: Sendable, Equatable {
    case running(Duration)
    case paused
}

/// normal·lowPower 각각의 팝오버 열림·닫힘 interval을 묶는 M1 일정 정의.
nonisolated struct CollectionScheduleDefinition: Sendable, Equatable {
    let normalPresented: Duration
    let normalDismissed: Duration
    let lowPowerPresented: Duration
    let lowPowerDismissed: Duration

    /// SPEC·ANALYSIS가 정한 M1 값: normal 열림 1초·닫힘 2초, lowPower 열림 2초·닫힘 5초.
    static let m1 = CollectionScheduleDefinition(
        normalPresented: .seconds(1),
        normalDismissed: .seconds(2),
        lowPowerPresented: .seconds(2),
        lowPowerDismissed: .seconds(5)
    )
}

/// 일정 정의와 최종 snapshot에서 `running(interval)` 또는 `paused`를 계산하는 순수 정책.
/// 화면이 `locked` 또는 `unknown`이면 팝오버·전력과 무관하게 `paused`입니다.
nonisolated enum CollectionSchedulePolicy {
    static func schedule(
        for lifecycle: MonitoringLifecycle,
        definition: CollectionScheduleDefinition
    ) -> CollectionSchedule {
        guard lifecycle.screenLockState == .unlocked else {
            return .paused
        }

        if lifecycle.lowPowerMode {
            return .running(lifecycle.popoverPresented ? definition.lowPowerPresented : definition.lowPowerDismissed)
        } else {
            return .running(lifecycle.popoverPresented ? definition.normalPresented : definition.normalDismissed)
        }
    }
}

/// 팝오버·저전력·화면 잠금 입력을 `update(_:)` 하나로 직렬화해 최종 snapshot과
/// 마지막 system revision, 마지막 적용 일정을 단독 소유하는 actor.
/// 계산 결과가 마지막 적용 결과와 다를 때만 `MonitoringScheduler.apply(_:)`를 호출해 중복 수집을 막습니다.
actor MonitoringLifecycleStore<Clock: MonotonicClock, Source: ScheduledSampleSource> {
    private let definition: CollectionScheduleDefinition
    private let scheduler: MonitoringScheduler<Clock, Source>

    /// system snapshot이 한 번도 도착하지 않은 시작 상태는 화면 상태를 알 수 없으므로
    /// 가장 안전한 `paused` 쪽(`unknown`)을 기본값으로 둡니다.
    private var lifecycle = MonitoringLifecycle(popoverPresented: false, lowPowerMode: false, screenLockState: .unknown)
    private var lastSystemRevision: Int?
    private var lastAppliedSchedule: CollectionSchedule?

    init(definition: CollectionScheduleDefinition, scheduler: MonitoringScheduler<Clock, Source>) {
        self.definition = definition
        self.scheduler = scheduler
    }

    /// 입력 이벤트 하나를 반영합니다. `systemSnapshot`은 최초 revision은 항상 적용하고
    /// 이후에는 마지막 system revision보다 작거나 같은 snapshot을 거부합니다.
    /// 계산된 일정이 마지막 적용 결과와 같으면 `scheduler.apply(_:)`를 호출하지 않습니다.
    func update(_ event: MonitoringLifecycleEvent) async {
        switch event {
        case .popoverPresented(let presented):
            lifecycle = MonitoringLifecycle(
                popoverPresented: presented,
                lowPowerMode: lifecycle.lowPowerMode,
                screenLockState: lifecycle.screenLockState
            )
        case .systemSnapshot(let snapshot):
            if let lastSystemRevision, snapshot.revision <= lastSystemRevision {
                return
            }
            lastSystemRevision = snapshot.revision
            lifecycle = MonitoringLifecycle(
                popoverPresented: lifecycle.popoverPresented,
                lowPowerMode: snapshot.lowPowerMode,
                screenLockState: snapshot.screenLockState
            )
        }

        let schedule = CollectionSchedulePolicy.schedule(for: lifecycle, definition: definition)
        guard schedule != lastAppliedSchedule else { return }
        lastAppliedSchedule = schedule
        await scheduler.apply(schedule)
    }
}
