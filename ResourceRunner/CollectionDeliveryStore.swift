import Foundation

/// 네 독립 소비 축의 최신 전달값을 카드 재조립에도 재사용합니다.
/// 늦은 stream 항목은 ApplicationCoordinator의 display admission과 topology 검사를 통과해야만 들어옵니다.
@MainActor
final class CollectionDeliveryStore {
    private(set) var networkActivity: NetworkActivityDisplayValue?
    private(set) var diskActivity: DiskActivityDisplayValue?
    private(set) var networkMetadata: NetworkMetadataStatus?
    private(set) var storageMetadata: StorageMetadataStatus?

    func updateNetwork(_ value: NetworkActivityDisplayValue) { networkActivity = value }
    func updateDisk(_ value: DiskActivityDisplayValue) { diskActivity = value }
    func updateNetworkMetadata(_ value: NetworkMetadataStatus) { networkMetadata = value }
    func updateStorageMetadata(_ value: StorageMetadataStatus) { storageMetadata = value }
}

/// 프로세스 순위 계산은 시스템 tick 소비와 독립적으로 진행합니다. 메뉴바 판정은 이 캐시를 기다리지 않습니다.
@MainActor
final class ProcessRankingDeliveryCache {
    private(set) var materials: ProcessRankingMaterials?
    var ranking: ApplicationRankingSample? { materials?.currentUser.ranking }
    var groups: [ApplicationProcessGroup] { materials?.currentUser.groups ?? [] }
    private(set) var surveyFailed = false
    private(set) var timestamp: ContinuousClock.Instant?
    private(set) var collectionEpoch: Int?
    private(set) var deliverySequence: UInt64 = 0

    @discardableResult
    func update(materials: ProcessRankingMaterials,
                surveyFailed: Bool, timestamp: ContinuousClock.Instant,
                collectionEpoch: Int?, deliverySequence: UInt64) -> Bool {
        if let collectionEpoch, let previousEpoch = self.collectionEpoch,
           collectionEpoch < previousEpoch { return false }
        if collectionEpoch == self.collectionEpoch, self.timestamp != nil {
            guard timestamp >= self.timestamp!, deliverySequence > self.deliverySequence else { return false }
        }
        self.materials = materials
        self.surveyFailed = surveyFailed
        self.timestamp = timestamp
        self.collectionEpoch = collectionEpoch
        self.deliverySequence = deliverySequence
        return true
    }

    func snapshot(for epoch: Int?, includesSystemProcesses: Bool = false) -> (ranking: ApplicationRankingSample?,
                                       groups: [ApplicationProcessGroup], surveyFailed: Bool, excludedCount: Int) {
        guard let epoch, epoch == collectionEpoch else { return (nil, [], false, 0) }
        let selected = includesSystemProcesses ? materials?.allReadable : materials?.currentUser
        return (selected?.ranking, selected?.groups ?? [], surveyFailed, selected?.excludedCount ?? 0)
    }
}
