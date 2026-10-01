//
//  ApplicationCoordinator.swift
//  ResourceRunner
//
//  Created by zipkero on 8/2/26.
//

import AppKit
import OSLog

/// 앱 수명 동안 필요한 객체를 한 번만 구성하고 소유하는 경계.
/// 표시 흐름(`StatusBarController`, `CharacterStateSource`)과 생명주기·수집 흐름
/// (`SystemLifecycleObserver`, 여섯 축 `CollectionPipelines`)을
/// 각각 한 번만 만들어 앱 종료까지 강하게 보유합니다. 두 흐름은 이 타입에서만 만나며,
/// 표시 계층은 수집 actor를 호출하지 않고 수집 actor도 표시 계층을 호출하지 않습니다.
@MainActor
final class ApplicationCoordinator {
    let statusBarController: StatusBarController
    let characterStateSource: CharacterStateSource
    let systemLifecycleObserver: SystemLifecycleObserver
    let collectionPipelines: CollectionPipelines
    let topologyObserver: ResourceTopologyObserver
    let dashboardPresentationStore: DashboardPresentationStore
    let collectionDeliveryStore: CollectionDeliveryStore
    let processRankingCache: ProcessRankingDeliveryCache

    var monitoringSampleStore: MonitoringSampleStore { collectionPipelines.systemStore }
    var processHistoryStore: ProcessHistoryStore { collectionPipelines.processStore }
    var monitoringLifecycleStore: MonitoringLifecycleStore { collectionPipelines.lifecycle }
    var collectionAdmission: CollectionAdmission { collectionPipelines.admission }

    private var characterStateTask: Task<Void, Never>?
    private var monitoringTask: Task<Void, Never>?
    private var cpuActivityTask: Task<Void, Never>?
    private var processRankingTask: Task<Void, Never>?
    private var networkActivityTask: Task<Void, Never>?
    private var diskActivityTask: Task<Void, Never>?
    private var networkMetadataTask: Task<Void, Never>?
    private var storageMetadataTask: Task<Void, Never>?
    private var collectionBoundaryTask: Task<Void, Never>?

#if DEBUG
    // 생명주기 관찰용 observer는 여기 하나만 둡니다.
    // 둘 만들면 실기기에서 DistributedNotificationCenter 등록이 두 번 일어납니다.
    private static let debugLifecycleLogger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "SystemLifecycle")
    // task-007 실기기 확인: 사용률과 판정 전이를 Console.app에서 관찰하기 위한 로그 경계입니다.
    private static let debugCPUActivityLogger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "CPUActivityState")
    private static let debugPipelineLogger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "CollectionPipeline")
#endif

    init() {
        // 팝오버 콘텐츠 뷰가 이 저장소를 관찰하므로, 뷰를 만들기 전에 먼저 만들어야 합니다.
        let dashboard = DashboardPresentationStore()
        dashboardPresentationStore = dashboard

        // 아이콘 캐시 수명은 앱 수명입니다. 여기서 한 번 만들어 뷰에 넘기면 팝오버를 여닫아도
        // 같은 앱의 아이콘을 다시 얻지 않습니다(ANALYSIS §5 DP11).
        statusBarController = StatusBarController(
            popoverContent: DashboardView(store: dashboard, iconProvider: ApplicationIconCache())
        )
        characterStateSource = CharacterStateSource()

        // 여섯 축 모두 같은 구성 함수를 지나며, 빠른 counter와 느린 metadata는 각각 별도 actor·scheduler입니다.
        let clock = SystemMonotonicClock()
        let admission = CollectionAdmission()
        let networkTopology = NetworkTopologyTracker()
        let diskTopology = DiskTopologyTracker()
        let pipelines = CollectionPipelines.make(clock: clock, admission: admission,
            networkTopology: networkTopology, diskTopology: diskTopology,
            systemSource: SystemMetricsSampleSource(
                cpuCollector: CPUSystemMetricsCollector(reader: HostCPUTickReader()),
                memoryCollector: MemorySystemMetricsCollector(),
                clock: clock, admission: admission),
            processSource: ProcessSurveySampleSource(
                collector: ProcessSurveyCollector(reader: HostProcessSurveyReader()),
                admission: admission),
            networkSource: { metadata in NetworkActivitySource(
                reader: SystemNetworkCounterReader(topology: networkTopology),
                metadata: metadata, admission: admission) },
            diskSource: DiskActivitySource(
                reader: SystemDiskCounterReader(topology: diskTopology), admission: admission),
            networkMetadataSource: NetworkMetadataSource(
                reader: SystemNetworkMetadataReader(topology: networkTopology), admission: admission),
            storageMetadataSource: StorageMetadataSource(
                reader: SystemStorageMetadataReader(topology: diskTopology), admission: admission))
        collectionPipelines = pipelines
        collectionDeliveryStore = CollectionDeliveryStore()
        processRankingCache = ProcessRankingDeliveryCache()
        topologyObserver = ResourceTopologyObserver(networkTopology: networkTopology,
            diskTopology: diskTopology, lifecycle: pipelines.lifecycle)
        systemLifecycleObserver = SystemLifecycleObserver.makeMacOSAdapter()

        // 모든 저장 속성이 준비된 뒤에야 `self`를 다른 객체에 넘길 수 있으므로,
        // delegate 연결과 이후 소비 Task 시작은 여기부터 진행합니다.
        statusBarController.output = self

#if DEBUG
        // 상태 전환을 사람이 직접 확인할 수 있도록 우클릭 디버그 메뉴를 상태 입력에 연결합니다.
        // Release 빌드에는 이 진입점이 없습니다.
        statusBarController.debugStateInjector = { [characterStateSource] state in
            characterStateSource.send(state)
        }
#endif

        let sink: CharacterPresentationSink = statusBarController
        characterStateTask = Self.consume(characterStateSource, into: sink)

        processRankingTask = Self.consumeProcessRanking(pipelines.processStore,
            into: processRankingCache, admission: admission)
        cpuActivityTask = Self.consumeSystemMetrics(
            pipelines.systemStore,
            into: characterStateSource,
            dashboard: dashboard,
            rankingCache: processRankingCache,
            admission: admission
        )
        networkActivityTask = Self.consumeNetworkActivity(pipelines.networkStore,
            into: collectionDeliveryStore, dashboard: dashboard,
            topology: networkTopology, admission: admission)
        diskActivityTask = Self.consumeDiskActivity(pipelines.diskStore,
            into: collectionDeliveryStore, dashboard: dashboard,
            topology: diskTopology, admission: admission)
        networkMetadataTask = Self.consumeNetworkMetadata(pipelines.networkMetadataStore,
            into: collectionDeliveryStore, dashboard: dashboard,
            topology: networkTopology, admission: admission)
        storageMetadataTask = Self.consumeStorageMetadata(pipelines.storageMetadataStore,
            into: collectionDeliveryStore, dashboard: dashboard,
            topology: diskTopology, admission: admission)
        collectionBoundaryTask = Self.consumeCollectionBoundaryEvents(pipelines.lifecycle, dashboard: dashboard, admission: admission)
        // 모든 소비 경로가 준비된 뒤 초기 lifecycle을 적용해야 최초 수집을 잃지 않습니다.
        monitoringTask = Self.startMonitoring(systemLifecycleObserver, into: pipelines.lifecycle)
    }

    /// 초기 상태를 sink에 전달한 뒤 이후 상태 변경을 소비하는 Task를 시작합니다.
    /// `init`과 테스트가 같은 소비 경로를 실제로 통과하도록 이 로직을 별도로 노출합니다.
    static func consume(_ source: CharacterStateSource, into sink: CharacterPresentationSink) -> Task<Void, Never> {
        // 초기 상태는 stream이 아니라 여기서 직접 sink에 전달합니다.
        // stream(`updates`)은 이후 변경만 담으므로 초기 표현이 두 번 전달되지 않습니다.
        sink.render(.presenting(source.initialState))

        let updates = source.updates
        return Task { @MainActor in
            for await state in updates {
                sink.render(.presenting(state))
            }
        }
    }

    /// 시스템 지표 소비 지점에서 전체 CPU 사용률로 메뉴바 표시 상태를 판정하고,
    /// 상태가 바뀌었을 때만 `CharacterStateSource.send(_:)`를 호출합니다.
    /// CPU 지표가 실패했거나(`.failure`) 값을 만들지 못한 tick(`.success(nil)`)에서는 판정 자체를 건너뛰어
    /// 마지막 표시 상태를 그대로 유지합니다(ANALYSIS §2 「메뉴바 표시 상태 판정」).
    /// 같은 소비 지점에서 `dashboard`의 CPU·Memory 카드도 매 tick 갱신합니다(ANALYSIS §5 DP10).
    /// production에서는 독립 프로세스 소비 경로가 계산한 순위 캐시를 읽습니다.
    /// 새 collection epoch의 시스템 tick은 이전 epoch 순위를 사용하지 않습니다.
    /// 기존 테스트의 `processHistory` 직접 조회 경로는 별도 주입점으로 유지합니다.
    /// `processHistory`가 없으면 순위는 빈 목록이 되고, 그 자체가 "5개 미만이면 있는 만큼만 표시"의 한 경우입니다.
    /// `init`과 테스트가 같은 경로를 통과하도록 이 로직을 별도로 노출합니다.
    static func consumeSystemMetrics(
        _ store: MonitoringSampleStore,
        into characterStateSource: CharacterStateSource,
        dashboard: DashboardPresentationStore,
        processHistory: ProcessHistoryStore? = nil,
        rankingCache: ProcessRankingDeliveryCache? = nil,
        admission: CollectionAdmission? = nil
    ) -> Task<Void, Never> {
        let displayValues = store.displayValues
        return Task { @MainActor in
            var state = CPUActivityStateEvaluator.State.initial
            var resolver = ApplicationIdentityResolver()
            for await displayValue in displayValues {
                let now = ContinuousClock().now

                var ranking: ApplicationRankingSample?
                var processGroups: [ApplicationProcessGroup] = []
                var nextResolver: ApplicationIdentityResolver?
                var surveyFailed = false
                if let rankingCache {
                    let current = rankingCache.snapshot(for: displayValue.latest?.collectionEpoch)
                    ranking = current.ranking
                    processGroups = current.groups
                    surveyFailed = current.surveyFailed
                } else if let processHistory {
                    let input = await processHistory.rankingInput()
                    surveyFailed = input.surveyFailed
                    let computed = ApplicationRanking.compute(
                        snapshots: input.snapshots,
                        currentTimestamp: now,
                        unreadableCount: input.unreadableCount,
                        resolver: resolver
                    )
                    // 두 계산이 같은 resolver를 이어받아야 앱 키 유도가 서로 다른 결과를 내지 않습니다.
                    let grouped = ApplicationRanking.groupByApplication(
                        snapshots: input.snapshots,
                        resolver: computed.resolver
                    )
                    nextResolver = grouped.resolver
                    ranking = computed.sample
                    processGroups = grouped.groups
                }

                @MainActor func updateDisplay() {
                    if let nextResolver { resolver = nextResolver }
                    dashboard.updateCPUCard(
                        with: displayValue,
                        topApplications: ranking?.cpuUsage ?? [],
                        topApplicationsFailed: surveyFailed,
                        processGroups: processGroups,
                        currentTimestamp: now
                    )
                    dashboard.updateMemoryCard(
                        with: displayValue,
                        topApplications: ranking?.memoryUsage ?? [],
                        topApplicationsFailed: surveyFailed,
                        memoryIncrease: ranking?.memoryIncrease ?? [],
                        processGroups: processGroups,
                        currentTimestamp: now
                    )
                    guard let latest = displayValue.latest,
                          case .success(let cpu?) = latest.value.cpu else { return }

                    let next = CPUActivityStateEvaluator.evaluate(
                        usage: cpu.overallUsage,
                        timestamp: latest.timestamp,
                        state: state,
                        collectionEpoch: latest.collectionEpoch
                    )
                    if next.displayedState != state.displayedState {
                        characterStateSource.send(next.displayedState)
                    }

#if DEBUG
                    if let previousEpoch = state.lastCollectionEpoch, previousEpoch != latest.collectionEpoch {
                        debugCPUActivityLogger.notice(
                            "continuity reset previousEpoch=\(previousEpoch, privacy: .public) collectionEpoch=\(latest.collectionEpoch, privacy: .public) pendingRestarted=\(next.pendingSince == nil || next.pendingSince == latest.timestamp, privacy: .public) highStreakRestarted=\(next.highStreakStart == nil || next.highStreakStart == latest.timestamp, privacy: .public) displayedState=\(String(describing: next.displayedState), privacy: .public)"
                        )
                    }
                    debugCPUActivityLogger.notice(
                        "usage=\(cpu.overallUsage, privacy: .public) collectionEpoch=\(latest.collectionEpoch, privacy: .public) displayedState=\(String(describing: next.displayedState), privacy: .public)"
                    )
#endif
                    state = next
                }

                if let context = displayValue.latest?.context, let admission {
                    guard admission.admitDisplay(context, timestamp: displayValue.latest!.timestamp, {
                        dashboard.recordSampleBoundary(context)
                        updateDisplay()
                        return true
                    }) == true else { continue }
                } else { updateDisplay() }
            }
        }
    }

    /// 프로세스 순위의 actor 조회·집계를 시스템 tick에서 분리해 CPU·Memory와 메뉴바 소비를 기다리게 하지 않습니다.
    static func consumeProcessRanking(_ store: ProcessHistoryStore,
                                      into cache: ProcessRankingDeliveryCache,
                                      admission: CollectionAdmission? = nil,
                                      beforeRankingCompute: (@Sendable () async -> Void)? = nil) -> Task<Void, Never> {
        let updates = store.rankingUpdates
        return Task.detached(priority: .utility) {
            var resolver = ApplicationIdentityResolver()
            for await input in updates {
                if let beforeRankingCompute { await beforeRankingCompute() }
                let computed = ApplicationRanking.compute(snapshots: input.snapshots,
                    currentTimestamp: input.timestamp, unreadableCount: input.unreadableCount,
                    resolver: resolver)
                let grouped = ApplicationRanking.groupByApplication(snapshots: input.snapshots,
                    resolver: computed.resolver)
                let accepted = await MainActor.run { () -> Bool in
                    if let context = input.context, let admission {
                        return admission.admitDisplay(context, timestamp: input.timestamp) {
                            cache.update(ranking: computed.sample, groups: grouped.groups,
                                surveyFailed: input.surveyFailed, timestamp: input.timestamp,
                                collectionEpoch: context.epoch)
#if DEBUG
                            debugPipelineLogger.notice("delivered axis=processSurvey epoch=\(context.epoch) failed=\(input.surveyFailed)")
#endif
                            return true
                        } ?? false
                    } else {
                        cache.update(ranking: computed.sample, groups: grouped.groups,
                            surveyFailed: input.surveyFailed, timestamp: input.timestamp,
                            collectionEpoch: input.context?.epoch)
                        return true
                    }
                }
                if accepted { resolver = grouped.resolver }
            }
        }
    }

    static func consumeNetworkActivity(_ store: NetworkActivityStore,
                                       into delivery: CollectionDeliveryStore,
                                       dashboard: DashboardPresentationStore? = nil,
                                       topology: NetworkTopologyTracker? = nil,
                                       admission: CollectionAdmission) -> Task<Void, Never> {
        let updates = store.updates
        return Task { @MainActor in
            for await value in updates {
                guard let latest = value.latest, let context = latest.context else { continue }
                _ = admission.admitDisplayOptional(context, timestamp: latest.value.readAt) {
                    let commit: @MainActor () -> Bool = {
                        delivery.updateNetwork(value)
                        if let dashboard {
                            dashboard.recordSampleBoundary(context)
                            dashboard.updateNetworkCard(activity: value,
                                metadata: delivery.networkMetadata, epoch: context.epoch,
                                currentTopologyRevision: latest.value.topologyRevision)
                        }
#if DEBUG
                        debugPipelineLogger.notice("delivered axis=networkActivity epoch=\(context.epoch) status=\(String(describing: latest.value.status), privacy: .public)")
#endif
                        return true
                    }
                    if let topology {
                        return topology.withCurrentRevision(latest.value.topologyRevision, commit)
                    }
                    return commit()
                }
            }
        }
    }

    static func consumeDiskActivity(_ store: DiskActivityStore,
                                    into delivery: CollectionDeliveryStore,
                                    dashboard: DashboardPresentationStore? = nil,
                                    topology: DiskTopologyTracker? = nil,
                                    admission: CollectionAdmission) -> Task<Void, Never> {
        let updates = store.updates
        return Task { @MainActor in
            for await value in updates {
                guard let latest = value.latest, let context = latest.context else { continue }
                _ = admission.admitDisplayOptional(context, timestamp: latest.value.readAt) {
                    let commit: @MainActor () -> Bool = {
                        delivery.updateDisk(value)
                        if let dashboard {
                            dashboard.recordSampleBoundary(context)
                            dashboard.updateDiskCard(activity: value,
                                metadata: delivery.storageMetadata, epoch: context.epoch,
                                currentTopologyRevision: latest.value.topologyRevision)
                        }
#if DEBUG
                        debugPipelineLogger.notice("delivered axis=diskActivity epoch=\(context.epoch) status=\(String(describing: latest.value.status), privacy: .public)")
#endif
                        return true
                    }
                    if let topology {
                        return topology.withCurrentRevision(latest.value.topologyRevision, commit)
                    }
                    return commit()
                }
            }
        }
    }

    static func consumeNetworkMetadata(_ store: NetworkMetadataStore,
                                       into delivery: CollectionDeliveryStore,
                                       dashboard: DashboardPresentationStore? = nil,
                                       topology: NetworkTopologyTracker? = nil,
                                       admission: CollectionAdmission) -> Task<Void, Never> {
        let updates = store.updates
        return Task { @MainActor in
            for await value in updates {
                guard let latest = value.latest, let context = latest.context else { continue }
                let revision: UInt64?
                switch latest.value {
                case .available(let snapshot): revision = snapshot.topologyRevision
                case .failure(_, let failedRevision): revision = failedRevision
                }
                _ = admission.admitDisplayOptional(context, timestamp: latest.timestamp) { () -> Bool? in
                    let commit: @MainActor () -> Bool = {
                        delivery.updateNetworkMetadata(value)
                        if let dashboard {
                            dashboard.recordSampleBoundary(context)
                            dashboard.updateNetworkCard(activity: delivery.networkActivity,
                                metadata: value, epoch: context.epoch,
                                currentTopologyRevision: revision)
                        }
#if DEBUG
                        let result: String
                        switch latest.value {
                        case .available(let snapshot): result = "available revision=\(snapshot.topologyRevision) records=\(snapshot.records.count)"
                        case .failure(let reason, let revision): result = "failure revision=\(revision.map(String.init) ?? "unknown") reason=\(reason)"
                        }
                        debugPipelineLogger.notice("delivered axis=networkMetadata epoch=\(context.epoch) result=\(result, privacy: .public)")
#endif
                        return true
                    }
                    if let topology {
                        guard let revision else { return nil }
                        return topology.withCurrentRevision(revision, commit)
                    }
                    return commit()
                }
            }
        }
    }

    static func consumeStorageMetadata(_ store: StorageMetadataStore,
                                       into delivery: CollectionDeliveryStore,
                                       dashboard: DashboardPresentationStore? = nil,
                                       topology: DiskTopologyTracker? = nil,
                                       admission: CollectionAdmission) -> Task<Void, Never> {
        let updates = store.updates
        return Task { @MainActor in
            for await value in updates {
                guard let latest = value.latest, let context = latest.context else { continue }
                let revision: UInt64?
                switch latest.value {
                case .available(let snapshot): revision = snapshot.topologyRevision
                case .failure(_, let failedRevision): revision = failedRevision
                }
                _ = admission.admitDisplayOptional(context, timestamp: latest.timestamp) { () -> Bool? in
                    let commit: @MainActor () -> Bool = {
                        delivery.updateStorageMetadata(value)
                        if let dashboard {
                            dashboard.recordSampleBoundary(context)
                            dashboard.updateDiskCard(activity: delivery.diskActivity,
                                metadata: value, epoch: context.epoch,
                                currentTopologyRevision: revision)
                        }
#if DEBUG
                        let result: String
                        switch latest.value {
                        case .available(let snapshot): result = "available revision=\(snapshot.topologyRevision) devices=\(snapshot.devices.count)"
                        case .failure(let reason, let revision): result = "failure revision=\(revision.map(String.init) ?? "unknown") reason=\(reason)"
                        }
                        debugPipelineLogger.notice("delivered axis=storageMetadata epoch=\(context.epoch) result=\(result, privacy: .public)")
#endif
                        return true
                    }
                    if let topology {
                        guard let revision else { return nil }
                        return topology.withCurrentRevision(revision, commit)
                    }
                    return commit()
                }
            }
        }
    }

    /// 생명주기 store의 중지·재개 경계를 표시 저장소에 전달합니다.
    /// 표시 저장소는 최신 경계와 sequence를 확인해 늦은 중지를 버립니다.
    /// `init`과 테스트가 같은 경로를 통과하도록 이 로직을 별도로 노출합니다.
    static func consumeCollectionBoundaryEvents(
        _ store: MonitoringLifecycleStore,
        dashboard: DashboardPresentationStore,
        admission: CollectionAdmission? = nil
    ) -> Task<Void, Never> {
        let events = store.collectionBoundaryEvents
        return Task { @MainActor in
            for await boundary in events {
                if let admission { dashboard.observe(boundary, admission: admission) }
                else if boundary.stopped { dashboard.markCollectionStopped() }
            }
        }
    }

    /// `source.start()`로 얻은 system initial snapshot과 초기 `popoverPresented = false`를
    /// store에 적용한 뒤에만 이후 update stream 소비를 시작합니다(DP8, ANALYSIS §2 「앱 시작과 메뉴바 상호작용」).
    /// 이 순서를 지켜야 store가 낮은 revision을 거부하는 방어와 무관하게, Scheduler가 초기 적용 전에
    /// 먼저 시작되는 경우가 생기지 않습니다.
    /// `init`과 테스트가 같은 경로를 통과하도록 이 로직을 별도로 노출합니다.
    static func startMonitoring(
        _ source: SystemLifecycleSource,
        into store: MonitoringLifecycleStore
    ) -> Task<Void, Never> {
        let subscription = source.start()

#if DEBUG
        // 실제 잠금·해제 반영을 사람이 콘솔 로그로 확인할 수 있어야 합니다.
        // `Logger`의 문자열 보간은 기본이 `.private`이라 명시하지 않으면 값이 가려지고, `.debug` 수준은
        // Console.app 기본 수집 대상이 아니므로 `.notice`와 `privacy: .public`을 씁니다.
        debugLifecycleLogger.notice("initial snapshot: \(String(describing: subscription.initial), privacy: .public)")
#endif

        return Task { @MainActor in
            await store.update(.systemSnapshot(subscription.initial))
            await store.update(.popoverPresented(false))

            for await snapshot in subscription.updates {
#if DEBUG
                debugLifecycleLogger.notice("snapshot changed: \(String(describing: snapshot), privacy: .public)")
#endif
                await store.update(.systemSnapshot(snapshot))
            }
        }
    }
}

extension ApplicationCoordinator: StatusBarControllerOutput {
    func popoverPresented(_ isPresented: Bool) {
        Task { await Self.forwardPopoverPresented(isPresented, to: monitoringLifecycleStore) }
    }

    /// `MonitoringLifecycleStore.update(_:)`는 actor 진입점이라 delegate 콜백에서 직접 await할 수 없으므로,
    /// 전달 로직을 별도로 노출해 `init`과 테스트가 같은 경로를 통과하게 합니다.
    static func forwardPopoverPresented(
        _ isPresented: Bool,
        to store: MonitoringLifecycleStore
    ) async {
        await store.update(.popoverPresented(isPresented))
    }
}
