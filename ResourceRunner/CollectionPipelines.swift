import Foundation

/// 테스트와 실제 앱이 같은 여섯 축 구성 함수를 통과합니다. 각 scheduler는 별도 actor·Task를 소유합니다.
struct CollectionPipelines {
    let admission: CollectionAdmission
    let lifecycle: MonitoringLifecycleStore
    let systemStore: MonitoringSampleStore
    let processStore: ProcessHistoryStore
    let networkStore: NetworkActivityStore
    let diskStore: DiskActivityStore
    let networkMetadataStore: NetworkMetadataStore
    let storageMetadataStore: StorageMetadataStore
    let systemScheduler: any CollectionScheduleTarget
    let processScheduler: any CollectionScheduleTarget
    let networkScheduler: any CollectionScheduleTarget
    let diskScheduler: any CollectionScheduleTarget
    let networkMetadataScheduler: any AuxiliaryCollectionTarget
    let storageMetadataScheduler: any AuxiliaryCollectionTarget

    static func make<Clock: MonotonicClock,
                     SystemSource: ScheduledSampleSource, ProcessSource: ScheduledSampleSource,
                     NetworkSource: ScheduledSampleSource, DiskSource: ScheduledSampleSource,
                     NetworkMetadataSourceType: ScheduledSampleSource,
                     StorageMetadataSourceType: ScheduledSampleSource>(
        clock: Clock,
        admission: CollectionAdmission,
        networkTopology: NetworkTopologyTracker,
        diskTopology: DiskTopologyTracker,
        systemSource: SystemSource,
        processSource: ProcessSource,
        networkSource: (NetworkMetadataStore) -> NetworkSource,
        diskSource: DiskSource,
        networkMetadataSource: NetworkMetadataSourceType,
        storageMetadataSource: StorageMetadataSourceType
    ) -> CollectionPipelines
    where SystemSource.Value == SystemMetricsSample,
          ProcessSource.Value == ProcessSurveySample,
          NetworkSource.Value == NetworkActivitySample,
          DiskSource.Value == DiskActivitySample,
          NetworkMetadataSourceType.Value == NetworkMetadataResult,
          StorageMetadataSourceType.Value == StorageMetadataResult {
        let systemStore = MonitoringSampleStore(admission: admission)
        let processStore = ProcessHistoryStore(admission: admission)
        let networkMetadataStore = NetworkMetadataStore(admission: admission, topology: networkTopology)
        let storageMetadataStore = StorageMetadataStore(admission: admission, topology: diskTopology)
        let networkStore = NetworkActivityStore(admission: admission, topology: networkTopology)
        let diskStore = DiskActivityStore(admission: admission, topology: diskTopology)
        let systemScheduler = MonitoringScheduler(clock: clock, source: systemSource,
            sink: systemStore, admission: admission, axis: .systemMetrics)
        let processScheduler = MonitoringScheduler(clock: clock, source: processSource,
            sink: processStore, admission: admission, axis: .processSurvey)
        let networkScheduler = MonitoringScheduler(clock: clock,
            source: networkSource(networkMetadataStore), sink: networkStore,
            admission: admission, axis: .networkActivity)
        let diskScheduler = MonitoringScheduler(clock: clock, source: diskSource,
            sink: diskStore, admission: admission, axis: .diskActivity)
        let networkMetadataScheduler = AuxiliaryCollectionScheduler(clock: clock,
            source: networkMetadataSource, sink: networkMetadataStore,
            admission: admission, axis: .networkMetadata)
        let storageMetadataScheduler = AuxiliaryCollectionScheduler(clock: clock,
            source: storageMetadataSource, sink: storageMetadataStore,
            admission: admission, axis: .storageMetadata)
        let lifecycle = MonitoringLifecycleStore(definition: .m3,
            systemMetricsTarget: systemScheduler, processSurveyTarget: processScheduler,
            networkActivityTarget: networkScheduler, diskActivityTarget: diskScheduler,
            networkMetadataTarget: networkMetadataScheduler,
            storageMetadataTarget: storageMetadataScheduler, admission: admission)
        return CollectionPipelines(admission: admission, lifecycle: lifecycle,
            systemStore: systemStore, processStore: processStore, networkStore: networkStore,
            diskStore: diskStore, networkMetadataStore: networkMetadataStore,
            storageMetadataStore: storageMetadataStore, systemScheduler: systemScheduler,
            processScheduler: processScheduler, networkScheduler: networkScheduler,
            diskScheduler: diskScheduler, networkMetadataScheduler: networkMetadataScheduler,
            storageMetadataScheduler: storageMetadataScheduler)
    }
}
