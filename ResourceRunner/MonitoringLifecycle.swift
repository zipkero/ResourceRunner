//
//  MonitoringLifecycle.swift
//  ResourceRunner
//
//  Created by zipkero on 8/10/26.
//

import Foundation

/// 팝오버 열림·저전력 모드와 화면을 볼 수 없는 세 신호를 하나로 묶은 수집 일정 결정용 최종 snapshot.
/// `MonitoringLifecycleStore`가 단독 소유하며, 값 타입이라 어느 격리에서도 전달할 수 있어야 하므로
/// `nonisolated`로 선언합니다.
nonisolated struct MonitoringLifecycle: Sendable, Equatable {
    let popoverPresented: Bool
    let lowPowerMode: Bool
    let screenLockState: ScreenLockState
    let displayAsleep: Bool
    let sessionActive: Bool

    /// 화면을 볼 수 없는 상태. 셋 중 하나라도 성립하면 두 수집 축이 모두 중지됩니다.
    /// 잠금 상태가 `unknown`일 때도 중지하는 M1 규칙을 그대로 둡니다.
    var screenUnobservable: Bool {
        screenLockState != .unlocked || displayAsleep || !sessionActive
    }
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

/// 시스템 지표와 프로세스 조사 두 축의 일정을 묶는 계산 결과.
/// 축마다 값이 따로이므로 한 축만 바뀌는 변경을 다른 축에 옮기지 않고 구분할 수 있습니다.
nonisolated struct CollectionSchedulePlan: Sendable, Equatable {
    let systemMetrics: CollectionSchedule
    let processSurvey: CollectionSchedule

    static let paused = CollectionSchedulePlan(systemMetrics: .paused, processSurvey: .paused)
}

/// 두 수집 축 각각의 전력·팝오버 조합별 interval 여덟 값을 담는 일정 정의.
nonisolated struct CollectionScheduleDefinition: Sendable, Equatable {
    /// 한 수집 축의 전력·팝오버 조합 넷.
    nonisolated struct AxisIntervals: Sendable, Equatable {
        let normalPresented: Duration
        let normalDismissed: Duration
        let lowPowerPresented: Duration
        let lowPowerDismissed: Duration

        func interval(lowPowerMode: Bool, popoverPresented: Bool) -> Duration {
            switch (lowPowerMode, popoverPresented) {
            case (false, true): normalPresented
            case (false, false): normalDismissed
            case (true, true): lowPowerPresented
            case (true, false): lowPowerDismissed
            }
        }
    }

    let systemMetrics: AxisIntervals
    let processSurvey: AxisIntervals

    /// ANALYSIS §2 「수집 중지와 재개」의 표: 시스템 지표는 normal 열림 1초·닫힘 2초, lowPower 열림 2초·닫힘 5초,
    /// 프로세스 조사는 normal 열림 2초·닫힘 5초, lowPower 열림 4초·닫힘 10초.
    static let m2 = CollectionScheduleDefinition(
        systemMetrics: AxisIntervals(
            normalPresented: .seconds(1),
            normalDismissed: .seconds(2),
            lowPowerPresented: .seconds(2),
            lowPowerDismissed: .seconds(5)
        ),
        processSurvey: AxisIntervals(
            normalPresented: .seconds(2),
            normalDismissed: .seconds(5),
            lowPowerPresented: .seconds(4),
            lowPowerDismissed: .seconds(10)
        )
    )
}

/// 일정 정의와 최종 snapshot에서 두 축의 일정을 함께 계산하는 순수 정책.
/// 화면을 볼 수 없는 세 신호(잠금·`unknown` 포함, 디스플레이 슬립, 세션 비활성) 중 하나라도 성립하면
/// 팝오버·전력과 무관하게 두 축이 모두 `paused`입니다.
nonisolated enum CollectionSchedulePolicy {
    static func plan(
        for lifecycle: MonitoringLifecycle,
        definition: CollectionScheduleDefinition
    ) -> CollectionSchedulePlan {
        guard !lifecycle.screenUnobservable else {
            return .paused
        }

        return CollectionSchedulePlan(
            systemMetrics: .running(
                definition.systemMetrics.interval(
                    lowPowerMode: lifecycle.lowPowerMode,
                    popoverPresented: lifecycle.popoverPresented
                )
            ),
            processSurvey: .running(
                definition.processSurvey.interval(
                    lowPowerMode: lifecycle.lowPowerMode,
                    popoverPresented: lifecycle.popoverPresented
                )
            )
        )
    }
}

/// 계산된 일정 하나를 적용받는 수집 축의 계약.
/// `MonitoringLifecycleStore`가 두 Scheduler를 구체 타입 대신 이 계약으로 보유하므로,
/// 축마다 서로 다른 source·sink 타입을 가져도 생명주기 계층에 제네릭이 전파되지 않습니다.
nonisolated protocol CollectionScheduleTarget: Sendable {
    func apply(_ schedule: CollectionSchedule) async
}

/// 팝오버·저전력과 화면을 볼 수 없는 세 신호를 `update(_:)` 하나로 직렬화해 최종 snapshot과
/// 마지막 system revision, 마지막 적용 일정을 단독 소유하는 actor.
/// 두 수집 축을 `CollectionScheduleTarget`으로 보유하고, 계산 결과가 마지막 적용 결과와 다른 축에만
/// `apply(_:)`를 호출해 중복 수집과 불필요한 재시작을 막습니다.
actor MonitoringLifecycleStore {
    private let definition: CollectionScheduleDefinition
    private let systemMetricsTarget: any CollectionScheduleTarget
    private let processSurveyTarget: any CollectionScheduleTarget

    /// system snapshot이 한 번도 도착하지 않은 시작 상태는 화면 상태를 알 수 없으므로
    /// 가장 안전한 `paused` 쪽(`unknown`)을 기본값으로 둡니다.
    /// 디스플레이 슬립과 세션 활성은 값 조회 경로가 없어 snapshot이 늘 초기값을 실어 오므로,
    /// 여기서도 그 초기값(화면이 켜져 있고 세션이 활성)을 그대로 둡니다.
    private var lifecycle = MonitoringLifecycle(
        popoverPresented: false,
        lowPowerMode: false,
        screenLockState: .unknown,
        displayAsleep: SystemLifecycleObserver.initialDisplayAsleep,
        sessionActive: SystemLifecycleObserver.initialSessionActive
    )
    private var lastSystemRevision: Int?
    private var lastAppliedPlan: CollectionSchedulePlan?

    /// 시스템 지표 일정이 새로 멈춘 순간만 알리는 stream. 일정이 멈춘 사실은 수집 결과가 아니라
    /// 이 store의 일정 결정이 산물이라 여기서만 알 수 있고, 표시 계층은 이 store를 호출하지 않으므로
    /// 이 stream이 생명주기 → coordinator → 표시로 가는 유일한 방향입니다(ANALYSIS §1 「생명주기 경계」, §5 DP16).
    /// 재개는 표시 저장소가 다음 tick의 조립 결과로 스스로 대체하므로(`DashboardPresentationStore.markCollectionStopped()`)
    /// 이 stream에 재개 전이를 따로 담지 않습니다. 최신 전이 하나만 보존해도 충분합니다.
    nonisolated let collectionStoppedEvents: AsyncStream<Void>
    private let collectionStoppedContinuation: AsyncStream<Void>.Continuation

    init(
        definition: CollectionScheduleDefinition,
        systemMetricsTarget: any CollectionScheduleTarget,
        processSurveyTarget: any CollectionScheduleTarget
    ) {
        self.definition = definition
        self.systemMetricsTarget = systemMetricsTarget
        self.processSurveyTarget = processSurveyTarget

        var collectionStoppedContinuation: AsyncStream<Void>.Continuation!
        self.collectionStoppedEvents = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { collectionStoppedContinuation = $0 }
        self.collectionStoppedContinuation = collectionStoppedContinuation
    }

    /// 입력 이벤트 하나를 반영합니다. `systemSnapshot`은 최초 revision은 항상 적용하고
    /// 이후에는 마지막 system revision보다 작거나 같은 snapshot을 거부합니다.
    /// 계산된 일정이 마지막 적용 결과와 같은 축에는 `apply(_:)`를 호출하지 않으므로,
    /// 한 축의 일정만 바뀌면 다른 축의 실행 중 작업은 취소되지 않습니다.
    func update(_ event: MonitoringLifecycleEvent) async {
        switch event {
        case .popoverPresented(let presented):
            lifecycle = MonitoringLifecycle(
                popoverPresented: presented,
                lowPowerMode: lifecycle.lowPowerMode,
                screenLockState: lifecycle.screenLockState,
                displayAsleep: lifecycle.displayAsleep,
                sessionActive: lifecycle.sessionActive
            )
        case .systemSnapshot(let snapshot):
            if let lastSystemRevision, snapshot.revision <= lastSystemRevision {
                return
            }
            lastSystemRevision = snapshot.revision
            lifecycle = MonitoringLifecycle(
                popoverPresented: lifecycle.popoverPresented,
                lowPowerMode: snapshot.lowPowerMode,
                screenLockState: snapshot.screenLockState,
                displayAsleep: snapshot.displayAsleep,
                sessionActive: snapshot.sessionActive
            )
        }

        let plan = CollectionSchedulePolicy.plan(for: lifecycle, definition: definition)
        guard plan != lastAppliedPlan else { return }

        let previousPlan = lastAppliedPlan
        lastAppliedPlan = plan
        if plan.systemMetrics != previousPlan?.systemMetrics {
            await systemMetricsTarget.apply(plan.systemMetrics)
        }
        if plan.processSurvey != previousPlan?.processSurvey {
            await processSurveyTarget.apply(plan.processSurvey)
        }

        // 시스템 지표 일정이 이번에 새로 멈췄을 때만 알립니다 — 이미 멈춰 있던 채로 다른 필드가 바뀐 경우나
        // 재개는 표시 계층에 별도로 알릴 필요가 없습니다(§5 DP16).
        if plan.systemMetrics == .paused, previousPlan?.systemMetrics != .paused {
            collectionStoppedContinuation.yield(())
        }
    }
}
