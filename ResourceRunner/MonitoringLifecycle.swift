//
//  MonitoringLifecycle.swift
//  ResourceRunner
//
//  Created by zipkero on 8/10/26.
//

import Foundation

/// 팝오버 열림·저전력 모드와 화면을 볼 수 없는 신호를 묶은 수집 일정 결정용 최종 snapshot.
/// `MonitoringLifecycleStore`가 단독 소유하며, 값 타입이라 어느 격리에서도 전달할 수 있어야 하므로
/// `nonisolated`로 선언합니다.
nonisolated struct MonitoringLifecycle: Sendable, Equatable {
    let popoverPresented: Bool
    let lowPowerMode: Bool
    let screenLockState: ScreenLockState
    let displayAsleep: Bool
    let sessionActive: Bool
    let systemAsleep: Bool

    init(popoverPresented: Bool, lowPowerMode: Bool, screenLockState: ScreenLockState,
         displayAsleep: Bool, sessionActive: Bool, systemAsleep: Bool = false) {
        self.popoverPresented = popoverPresented
        self.lowPowerMode = lowPowerMode
        self.screenLockState = screenLockState
        self.displayAsleep = displayAsleep
        self.sessionActive = sessionActive
        self.systemAsleep = systemAsleep
    }

    /// 화면을 볼 수 없는 상태. 잠금·화면·세션·시스템 sleep 중 하나라도 성립하면 모든 축이 중지됩니다.
    /// 잠금 상태가 `unknown`일 때도 중지하는 M1 규칙을 그대로 둡니다.
    var screenUnobservable: Bool {
        screenLockState != .unlocked || displayAsleep || !sessionActive || systemAsleep
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

/// 여섯 수집 축의 일정을 묶는 계산 결과.
/// 축마다 값이 따로이므로 한 축만 바뀌는 변경을 다른 축에 옮기지 않고 구분할 수 있습니다.
nonisolated struct CollectionSchedulePlan: Sendable, Equatable {
    let systemMetrics: CollectionSchedule
    let processSurvey: CollectionSchedule
    let networkActivity: CollectionSchedule
    let diskActivity: CollectionSchedule
    let networkMetadata: CollectionSchedule
    let storageMetadata: CollectionSchedule

    init(systemMetrics: CollectionSchedule, processSurvey: CollectionSchedule,
         networkActivity: CollectionSchedule = .paused, diskActivity: CollectionSchedule = .paused,
         networkMetadata: CollectionSchedule = .paused, storageMetadata: CollectionSchedule = .paused) {
        self.systemMetrics = systemMetrics
        self.processSurvey = processSurvey
        self.networkActivity = networkActivity
        self.diskActivity = diskActivity
        self.networkMetadata = networkMetadata
        self.storageMetadata = storageMetadata
    }

    subscript(axis: CollectionAxis) -> CollectionSchedule {
        switch axis {
        case .systemMetrics: systemMetrics
        case .processSurvey: processSurvey
        case .networkActivity: networkActivity
        case .diskActivity: diskActivity
        case .networkMetadata: networkMetadata
        case .storageMetadata: storageMetadata
        }
    }

    static let paused = CollectionSchedulePlan(systemMetrics: .paused, processSurvey: .paused)
}

/// 각 수집 축의 전력·팝오버 조합별 interval을 담는 일정 정의.
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
    let networkActivity: AxisIntervals?
    let diskActivity: AxisIntervals?
    let networkMetadata: AxisIntervals?
    let storageMetadata: AxisIntervals?

    init(systemMetrics: AxisIntervals, processSurvey: AxisIntervals,
         networkActivity: AxisIntervals? = nil, diskActivity: AxisIntervals? = nil,
         networkMetadata: AxisIntervals? = nil, storageMetadata: AxisIntervals? = nil) {
        self.systemMetrics = systemMetrics
        self.processSurvey = processSurvey
        self.networkActivity = networkActivity
        self.diskActivity = diskActivity
        self.networkMetadata = networkMetadata
        self.storageMetadata = storageMetadata
    }

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

    /// DESIGN §2.1의 여섯 축 주기. 아직 배선되지 않은 축도 같은 순수 정책에서 계산합니다.
    static let m3 = CollectionScheduleDefinition(
        systemMetrics: m2.systemMetrics,
        processSurvey: m2.processSurvey,
        networkActivity: AxisIntervals(normalPresented: .seconds(1), normalDismissed: .seconds(2),
                                       lowPowerPresented: .seconds(2), lowPowerDismissed: .seconds(5)),
        diskActivity: AxisIntervals(normalPresented: .seconds(1), normalDismissed: .seconds(2),
                                    lowPowerPresented: .seconds(2), lowPowerDismissed: .seconds(5)),
        networkMetadata: AxisIntervals(normalPresented: .seconds(30), normalDismissed: .seconds(60),
                                       lowPowerPresented: .seconds(60), lowPowerDismissed: .seconds(120)),
        storageMetadata: AxisIntervals(normalPresented: .seconds(30), normalDismissed: .seconds(60),
                                       lowPowerPresented: .seconds(60), lowPowerDismissed: .seconds(120))
    )
}

/// 일정 정의와 최종 snapshot에서 여섯 축의 일정을 함께 계산하는 순수 정책.
/// 화면을 볼 수 없는 신호(잠금·`unknown`, 디스플레이·시스템 sleep, 세션 비활성) 중 하나라도 성립하면
/// 팝오버·전력과 무관하게 모든 축이 `paused`입니다.
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
            ),
            networkActivity: schedule(definition.networkActivity, lifecycle),
            diskActivity: schedule(definition.diskActivity, lifecycle),
            networkMetadata: schedule(definition.networkMetadata, lifecycle),
            storageMetadata: schedule(definition.storageMetadata, lifecycle)
        )
    }

    private static func schedule(_ intervals: CollectionScheduleDefinition.AxisIntervals?,
                                 _ lifecycle: MonitoringLifecycle) -> CollectionSchedule {
        guard let intervals else { return .paused }
        return .running(intervals.interval(lowPowerMode: lifecycle.lowPowerMode,
                                           popoverPresented: lifecycle.popoverPresented))
    }
}

/// 계산된 일정 하나를 적용받는 수집 축의 계약.
/// `MonitoringLifecycleStore`가 수집 Scheduler를 구체 타입 대신 이 계약으로 보유하므로,
/// 축마다 서로 다른 source·sink 타입을 가져도 생명주기 계층에 제네릭이 전파되지 않습니다.
nonisolated protocol CollectionScheduleTarget: Sendable {
    func apply(_ schedule: CollectionSchedule) async
    func apply(_ schedule: CollectionSchedule, revision: Int) async
}

nonisolated extension CollectionScheduleTarget {
    func apply(_ schedule: CollectionSchedule, revision: Int) async { await apply(schedule) }
}

/// 팝오버·저전력과 화면을 볼 수 없는 신호를 `update(_:)` 하나로 직렬화해 최종 snapshot과
/// 마지막 system revision, 마지막 적용 일정을 단독 소유하는 actor.
/// 활성 수집 축을 `CollectionScheduleTarget`으로 보유하고, 계산 결과가 마지막 적용 결과와 다른 축에만
/// `apply(_:)`를 호출해 중복 수집과 불필요한 재시작을 막습니다.
actor MonitoringLifecycleStore {
    private let definition: CollectionScheduleDefinition
    private let systemMetricsTarget: any CollectionScheduleTarget
    private let processSurveyTarget: any CollectionScheduleTarget
    private let networkActivityTarget: (any CollectionScheduleTarget)?
    private let diskActivityTarget: (any CollectionScheduleTarget)?
    private let networkMetadataTarget: (any AuxiliaryCollectionTarget)?
    private let storageMetadataTarget: (any AuxiliaryCollectionTarget)?

    /// system snapshot이 한 번도 도착하지 않은 시작 상태는 화면 상태를 알 수 없으므로
    /// 가장 안전한 `paused` 쪽(`unknown`)을 기본값으로 둡니다.
    /// 디스플레이 슬립과 세션 활성은 값 조회 경로가 없어 snapshot이 늘 초기값을 실어 오므로,
    /// 여기서도 그 초기값(화면이 켜져 있고 세션이 활성)을 그대로 둡니다.
    private var lifecycle = MonitoringLifecycle(
        popoverPresented: false,
        lowPowerMode: false,
        screenLockState: .unknown,
        displayAsleep: SystemLifecycleObserver.initialDisplayAsleep,
        sessionActive: SystemLifecycleObserver.initialSessionActive,
        systemAsleep: false
    )
    private var lastSystemRevision: Int?
    private var lastAppliedPlan: CollectionSchedulePlan?
    private var planRevision = 0
    private var lastBoundary = CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: true)
    let admission: CollectionAdmission

    /// 중지·재개와 누적 경계를 함께 전달합니다. 최신 값 하나만 남아도 sequence가
    /// 짧은 중지·재개를 보존하고 표시 계층이 늦은 이벤트를 거부할 수 있습니다.
    nonisolated let collectionBoundaryEvents: AsyncStream<CollectionBoundary>
    private let collectionBoundaryContinuation: AsyncStream<CollectionBoundary>.Continuation

    init(
        definition: CollectionScheduleDefinition,
        systemMetricsTarget: any CollectionScheduleTarget,
        processSurveyTarget: any CollectionScheduleTarget,
        networkActivityTarget: (any CollectionScheduleTarget)? = nil,
        diskActivityTarget: (any CollectionScheduleTarget)? = nil,
        networkMetadataTarget: (any AuxiliaryCollectionTarget)? = nil,
        storageMetadataTarget: (any AuxiliaryCollectionTarget)? = nil,
        admission: CollectionAdmission = CollectionAdmission()
    ) {
        self.definition = definition
        self.systemMetricsTarget = systemMetricsTarget
        self.processSurveyTarget = processSurveyTarget
        self.networkActivityTarget = networkActivityTarget
        self.diskActivityTarget = diskActivityTarget
        self.networkMetadataTarget = networkMetadataTarget
        self.storageMetadataTarget = storageMetadataTarget
        self.admission = admission

        var continuation: AsyncStream<CollectionBoundary>.Continuation!
        self.collectionBoundaryEvents = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation = $0 }
        self.collectionBoundaryContinuation = continuation
    }

    /// 변경 알림이 있는 topology·마운트·해제는 해당 축에 요청을 전달합니다.
    /// 알림이 없는 주소·상태는 보조 scheduler의 주기 조회가 맡습니다.
    func requestAuxiliaryRefresh(_ axis: CollectionAxis) async {
        switch axis {
        case .networkMetadata: await networkMetadataTarget?.requestRefresh()
        case .storageMetadata: await storageMetadataTarget?.requestRefresh()
        default: break
        }
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
                sessionActive: lifecycle.sessionActive,
                systemAsleep: lifecycle.systemAsleep
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
                sessionActive: snapshot.sessionActive,
                systemAsleep: snapshot.systemAsleep
            )
        }

        let plan = CollectionSchedulePolicy.plan(for: lifecycle, definition: definition)
        let previousPlan = lastAppliedPlan
        let stopped = plan.systemMetrics == .paused
        let changedStop = previousPlan != nil && stopped != lastBoundary.stopped
        let snapshotSequence: Int
        if case .systemSnapshot(let snapshot) = event { snapshotSequence = snapshot.boundarySequence }
        else { snapshotSequence = lastBoundary.sequence }
        let sequence = max(snapshotSequence, lastBoundary.sequence + (changedStop ? 1 : 0))
        let boundaryChanged = sequence != lastBoundary.sequence || changedStop
        let revision = lastSystemRevision ?? lastBoundary.revision
        if boundaryChanged {
            let boundary = CollectionBoundary(revision: revision, sequence: sequence,
                epoch: lastBoundary.epoch + max(1, sequence - lastBoundary.sequence), stopped: stopped)
            lastBoundary = boundary
            // 취소나 target의 await보다 먼저 모든 축의 실행권을 끊습니다.
            admission.transition(boundary)
            collectionBoundaryContinuation.yield(boundary)
        } else if previousPlan == nil {
            let boundary = CollectionBoundary(revision: revision, sequence: sequence,
                epoch: lastBoundary.epoch, stopped: stopped)
            lastBoundary = boundary
            admission.transition(boundary)
            if stopped { collectionBoundaryContinuation.yield(boundary) }
        }
        guard plan != previousPlan || boundaryChanged else { return }
        lastAppliedPlan = plan
        planRevision += 1
        let revisionForTargets = planRevision
        let applySystem = plan.systemMetrics != previousPlan?.systemMetrics || boundaryChanged
        let applyProcess = plan.processSurvey != previousPlan?.processSurvey || boundaryChanged
        let applyNetwork = networkActivityTarget != nil &&
            (plan.networkActivity != previousPlan?.networkActivity || boundaryChanged)
        let applyDisk = diskActivityTarget != nil &&
            (plan.diskActivity != previousPlan?.diskActivity || boundaryChanged)
        let applyNetworkMetadata = networkMetadataTarget != nil &&
            (plan.networkMetadata != previousPlan?.networkMetadata || boundaryChanged)
        let applyStorageMetadata = storageMetadataTarget != nil &&
            (plan.storageMetadata != previousPlan?.storageMetadata || boundaryChanged)
        // actor의 첫 await 전에 축별 계획을 확정해 이전 update의 늦은 apply와 tick을 거부합니다.
        if applySystem { admission.setPlanRevision(revisionForTargets, for: .systemMetrics) }
        if applyProcess { admission.setPlanRevision(revisionForTargets, for: .processSurvey) }
        if applyNetwork { admission.setPlanRevision(revisionForTargets, for: .networkActivity) }
        if applyDisk { admission.setPlanRevision(revisionForTargets, for: .diskActivity) }
        if applyNetworkMetadata { admission.setPlanRevision(revisionForTargets, for: .networkMetadata) }
        if applyStorageMetadata { admission.setPlanRevision(revisionForTargets, for: .storageMetadata) }
        if applySystem {
            await systemMetricsTarget.apply(plan.systemMetrics, revision: revisionForTargets)
        }
        guard revisionForTargets == planRevision else { return }
        if applyProcess {
            await processSurveyTarget.apply(plan.processSurvey, revision: revisionForTargets)
        }
        guard revisionForTargets == planRevision else { return }
        if applyNetwork {
            await networkActivityTarget?.apply(plan.networkActivity, revision: revisionForTargets)
        }
        guard revisionForTargets == planRevision else { return }
        if applyDisk {
            await diskActivityTarget?.apply(plan.diskActivity, revision: revisionForTargets)
        }
        guard revisionForTargets == planRevision else { return }
        if applyNetworkMetadata {
            await networkMetadataTarget?.apply(plan.networkMetadata, revision: revisionForTargets)
        }
        guard revisionForTargets == planRevision else { return }
        if applyStorageMetadata {
            await storageMetadataTarget?.apply(plan.storageMetadata, revision: revisionForTargets)
        }
    }
}
