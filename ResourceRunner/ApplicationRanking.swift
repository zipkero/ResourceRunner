//
//  ApplicationRanking.swift
//  ResourceRunner
//
//  Created by zipkero on 8/14/26.
//

import Darwin
import Foundation

/// 여러 프로세스로 구성된 앱을 하나로 묶는 집계 키.
/// 가장 바깥 `.app` 번들 경로이거나, 번들에 속하지 않으면 실행 파일 경로 그 자체입니다.
/// CPU와 Memory가 이 키를 공유하므로 두 카드의 집계 기준이 일치합니다.
nonisolated struct ApplicationKey: Sendable, Equatable, Hashable {
    let value: String
}

/// 실행 경로에서 유도한 앱 키와 표시 이름의 묶음.
nonisolated struct ApplicationIdentity: Sendable, Equatable {
    let key: ApplicationKey
    let displayName: String
}

/// 실행 경로에서 앱 키와 표시 이름을 유도하고 결과를 캐시하는 계약.
/// 경로 유도는 프로세스 생명주기와 무관한 순수 계산이므로, 정체성 이력(`ProcessHistoryStore`)과
/// 분리된 별도의 경계에 둡니다.
nonisolated protocol ApplicationIdentityResolving: Sendable {
    mutating func resolve(executablePath: String) -> ApplicationIdentity
}

/// 실행 경로 유도 결과를 재사용하는 고정 상한 LRU 캐시.
/// 조사마다 관찰되는 프로세스 수가 늘어도 캐시 크기가 고정되도록 상한을 둡니다.
nonisolated struct ApplicationIdentityResolver: ApplicationIdentityResolving {
    /// 한 조사에서 관찰되는 서로 다른 실행 경로 수가 이 상한을 넘는 경우는 드물다고 보고,
    /// 여유를 둔 고정값으로 상한을 정합니다.
    static let defaultCapacity = 512

    private var cache: [String: ApplicationIdentity] = [:]
    /// 가장 오래전에 쓰인 것부터 순서대로 담는 경로 목록. 캐시 적중 때마다 맨 뒤로 옮깁니다.
    private var recencyOrder: [String] = []
    private let capacity: Int

    init(capacity: Int = ApplicationIdentityResolver.defaultCapacity) {
        precondition(capacity > 0, "용량은 1 이상이어야 합니다.")
        self.capacity = capacity
    }

    mutating func resolve(executablePath: String) -> ApplicationIdentity {
        if let cached = cache[executablePath] {
            touch(executablePath)
            return cached
        }

        let resolved = Self.deriveIdentity(from: executablePath)
        cache[executablePath] = resolved
        recencyOrder.append(executablePath)
        if recencyOrder.count > capacity {
            let evicted = recencyOrder.removeFirst()
            cache.removeValue(forKey: evicted)
        }
        return resolved
    }

    /// 캐시에 담긴 서로 다른 경로 수. 상한 검증에 씁니다.
    var cachedPathCount: Int { cache.count }

    private mutating func touch(_ path: String) {
        guard let index = recencyOrder.firstIndex(of: path) else { return }
        recencyOrder.remove(at: index)
        recencyOrder.append(path)
    }

    /// 경로 구성 요소 중 가장 왼쪽(가장 바깥) `.app`까지를 앱 번들 경로로 삼습니다.
    /// 왼쪽 구성 요소가 경로 트리에서 더 상위이므로, 중첩된 helper 번들은 항상 자신을 감싸는
    /// 상위 번들 하나로 접힙니다. `.app`를 찾지 못하면 실행 파일 경로 자체가 키가 됩니다.
    static func deriveIdentity(from executablePath: String) -> ApplicationIdentity {
        let components = executablePath.split(separator: "/", omittingEmptySubsequences: true)

        if let bundleIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) {
            let bundlePath = "/" + components[...bundleIndex].joined(separator: "/")
            let bundleName = String(components[bundleIndex].dropLast(".app".count))
            return ApplicationIdentity(key: ApplicationKey(value: bundlePath), displayName: bundleName)
        }

        let executableName = components.last.map(String.init) ?? executablePath
        return ApplicationIdentity(key: ApplicationKey(value: executablePath), displayName: executableName)
    }
}

/// TOP 5 순위 계산의 고정 상한.
nonisolated enum ApplicationRankingSampling {
    static let topCount = 5
}

/// 앱 단위 순위 항목 하나.
nonisolated struct ApplicationRankingEntry: Sendable, Equatable {
    let key: ApplicationKey
    let displayName: String
    let value: Double
}

/// 앱 집계와 TOP 5 순위 계산 결과.
/// 현재 사용량과 최근 증가량이 서로 다른 목록으로 담기고, 읽지 못한 프로세스 수가 함께 전달됩니다.
nonisolated struct ApplicationRankingSample: Sendable, Equatable {
    /// CPU 사용량 TOP 5. 정체성별 최근 세 개 값 평균을 앱 키로 합산한 값입니다.
    let cpuUsage: [ApplicationRankingEntry]
    /// 메모리 사용량 TOP 5. 정체성별 최근 세 개 값 평균을 앱 키로 합산한 값입니다.
    let memoryUsage: [ApplicationRankingEntry]
    /// 메모리 최근 10분 증가량 TOP 5.
    /// 정체성별 메모리 기준점 링에서 10분 창 안의 가장 오래된 기준점과 현재값의 차이를 앱 키로 합산합니다.
    let memoryIncrease: [ApplicationRankingEntry]
    /// 이번 조사에서 읽지 못한 프로세스 수.
    let unreadableCount: Int
}

/// 조사 결과와 정체성별 이력에서 앱 단위 순위를 계산하는 순수 함수.
/// 상태를 갖지 않으며, 앱 키 유도 캐시(`ApplicationIdentityResolver`)만 호출자가 이어서 넘겨받습니다.
nonisolated enum ApplicationRanking {
    /// - Parameters:
    ///   - snapshots: `ProcessHistoryStore.snapshot()`이 돌려준 정체성별 이력.
    ///   - currentTimestamp: 이번 조사 시각. 10분 창의 오른쪽 끝으로 씁니다.
    ///   - unreadableCount: 이번 조사에서 읽지 못한 프로세스 수.
    ///   - resolver: 앱 키 유도 캐시. 갱신된 캐시를 그대로 돌려받아 다음 호출에 이어서 씁니다.
    static func compute(
        snapshots: [ProcessHistorySnapshot],
        currentTimestamp: ContinuousClock.Instant,
        unreadableCount: Int,
        resolver: ApplicationIdentityResolver
    ) -> (sample: ApplicationRankingSample, resolver: ApplicationIdentityResolver) {
        var resolver = resolver
        var cpuUsageByKey: [ApplicationKey: Double] = [:]
        var memoryUsageByKey: [ApplicationKey: Double] = [:]
        var memoryIncreaseByKey: [ApplicationKey: Double] = [:]
        var displayNames: [ApplicationKey: String] = [:]

        let windowStart = currentTimestamp - ProcessHistorySampling.memoryBaselineWindow

        for snapshot in snapshots {
            let identity = resolver.resolve(executablePath: snapshot.executablePath)
            displayNames[identity.key] = identity.displayName

            // CPU는 기준점이 없어 값을 만들지 못한 조사가 섞일 수 있으므로, 값이 있는 것만 평균합니다.
            let cpuValues = snapshot.recentValues.compactMap(\.cpuUsagePercent)
            if !cpuValues.isEmpty {
                let averageCPU = cpuValues.reduce(0, +) / Double(cpuValues.count)
                cpuUsageByKey[identity.key, default: 0] += averageCPU
            }

            // Resident Memory는 항상 값이 있으므로 최근 값 전체를 그대로 평균합니다.
            if !snapshot.recentValues.isEmpty {
                let averageMemory = snapshot.recentValues.reduce(0.0) { $0 + Double($1.residentBytes) }
                    / Double(snapshot.recentValues.count)
                memoryUsageByKey[identity.key, default: 0] += averageMemory
            }

            // 10분 창 안에서 가장 오래된 기준점을 찾습니다. 링은 오래된 것부터 시간순이므로
            // 조건을 만족하는 첫 항목이 그 기준점이고, 창 밖의(더 오래된) 기준점은 자연히 걸러집니다.
            if let currentResidentBytes = snapshot.recentValues.last?.residentBytes,
               let oldestWithinWindow = snapshot.memoryBaselines.first(where: { $0.timestamp >= windowStart }) {
                let increase = Double(currentResidentBytes) - Double(oldestWithinWindow.residentBytes)
                memoryIncreaseByKey[identity.key, default: 0] += increase
            }
        }

        let sample = ApplicationRankingSample(
            cpuUsage: topEntries(from: cpuUsageByKey, displayNames: displayNames),
            memoryUsage: topEntries(from: memoryUsageByKey, displayNames: displayNames),
            memoryIncrease: topEntries(from: memoryIncreaseByKey, displayNames: displayNames),
            unreadableCount: unreadableCount
        )
        return (sample, resolver)
    }

    private static func topEntries(
        from valuesByKey: [ApplicationKey: Double],
        displayNames: [ApplicationKey: String]
    ) -> [ApplicationRankingEntry] {
        let entries = valuesByKey.map { key, value in
            ApplicationRankingEntry(key: key, displayName: displayNames[key] ?? key.value, value: value)
        }
        return Array(entries.sorted { $0.value > $1.value }.prefix(ApplicationRankingSampling.topCount))
    }
}

/// 앱 키로 묶은 프로세스 하나. 상세 영역에서 앱 항목을 펼치면 나타나는 하위 프로세스 목록의 원소입니다(ANALYSIS §2 「팝오버 열림과 카드 선택」).
/// CPU 상세는 `cpuUsagePercent`와 `isTranslated`를, Memory 상세는 `residentBytes`를 씁니다 —
/// CPU와 Memory가 같은 앱 키 규칙을 공유하므로(DP5) 그룹 목록 자체는 카드마다 다시 계산하지 않고 하나를 공유합니다.
nonisolated struct ApplicationProcessDetail: Sendable, Equatable {
    let pid: pid_t
    /// 기준점이 없거나 조사 간격이 허용 범위를 넘으면 `nil`입니다(`ProcessHistoryStore`와 같은 규칙).
    let cpuUsagePercent: Double?
    let residentBytes: UInt64
    let isTranslated: Bool
}

extension ApplicationProcessDetail {
    /// 프로세스 CPU 사용률의 단위 라벨. 논리 코어 합산 관례라 100%를 넘을 수 있어
    /// 시스템 전체 사용률의 단위(`CPUCardPresentation.overallUsageUnitLabel`)와 다른 문자열을 씁니다.
    static let cpuUsageUnitLabel = "% (코어 합산)"
}

/// 앱 하나로 묶인 프로세스 그룹. 표시 이름과 앱 키는 `ApplicationRankingEntry`와 같은 유도 규칙을 씁니다.
nonisolated struct ApplicationProcessGroup: Sendable, Equatable {
    let key: ApplicationKey
    let displayName: String
    let processes: [ApplicationProcessDetail]
}

extension ApplicationRanking {
    /// `ProcessHistoryStore.snapshot()`이 돌려준 정체성별 이력을 앱 키로 묶어 하위 프로세스 그룹 목록을 만듭니다.
    ///
    /// `ApplicationRankingSample`은 앱 키별 합산값만 담고 그 키에 속한 개별 프로세스 목록은 담지 않으므로,
    /// "앱 항목을 펼치면 하위 프로세스가 나타난다"(SPEC §5.2, SPEC §5.6)를 만족하려면 `snapshot()` 결과를
    /// `compute(_:)`와 별도로 한 번 더 순회해야 합니다. 두 계산이 같은 `resolver`를 이어받아 앱 키 유도가
    /// 두 번 다른 결과를 내지 않게 합니다.
    /// - Returns: 관찰 순서를 보존한 그룹 목록(정렬하지 않음 — 정렬된 순위는 `compute(_:)`가 이미 담당)과 갱신된 resolver.
    static func groupByApplication(
        snapshots: [ProcessHistorySnapshot],
        resolver: ApplicationIdentityResolver
    ) -> (groups: [ApplicationProcessGroup], resolver: ApplicationIdentityResolver) {
        var resolver = resolver
        var order: [ApplicationKey] = []
        var displayNames: [ApplicationKey: String] = [:]
        var processesByKey: [ApplicationKey: [ApplicationProcessDetail]] = [:]

        for snapshot in snapshots {
            let identity = resolver.resolve(executablePath: snapshot.executablePath)
            if processesByKey[identity.key] == nil {
                order.append(identity.key)
            }
            displayNames[identity.key] = identity.displayName
            processesByKey[identity.key, default: []].append(
                ApplicationProcessDetail(
                    pid: snapshot.identity.pid,
                    cpuUsagePercent: snapshot.latestCPUUsagePercent,
                    residentBytes: snapshot.recentValues.last?.residentBytes ?? 0,
                    isTranslated: snapshot.isTranslated
                )
            )
        }

        let groups = order.map { key in
            ApplicationProcessGroup(key: key, displayName: displayNames[key] ?? key.value, processes: processesByKey[key] ?? [])
        }
        return (groups, resolver)
    }
}
