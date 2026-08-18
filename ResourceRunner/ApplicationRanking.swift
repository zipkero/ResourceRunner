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

        return ApplicationIdentity(key: ApplicationKey(value: executablePath), displayName: executableName(from: executablePath))
    }

    /// 실행 경로의 마지막 구성 요소(실행 파일 이름)를 뽑습니다. 번들 밖 실행 파일의 표시 이름(`deriveIdentity`)과
    /// 상세 목록의 프로세스별 실행 파일 이름(`ApplicationRanking.groupByApplication`)이 같은 규칙을 공유하도록
    /// 이 자리에 둡니다 — 두 곳이 각자 이름을 유도하면 같은 프로세스가 서로 다른 이름으로 보일 수 있습니다.
    static func executableName(from executablePath: String) -> String {
        let components = executablePath.split(separator: "/", omittingEmptySubsequences: true)
        return components.last.map(String.init) ?? executablePath
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

            let smoothed = smoothedRecentValues(for: snapshot)

            // CPU는 기준점이 없어 값을 만들지 못한 조사가 섞일 수 있으므로, 값이 있는 것만 평균합니다.
            if let averageCPU = smoothed.cpuUsagePercent {
                cpuUsageByKey[identity.key, default: 0] += averageCPU
            }

            // Resident Memory는 항상 값이 있으므로 최근 값 전체를 그대로 평균합니다.
            if !snapshot.recentValues.isEmpty {
                memoryUsageByKey[identity.key, default: 0] += smoothed.residentBytes
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
        // Dictionary 유래 입력이라 값이 정확히 같으면 순서가 임의이므로, 상세 목록(`sortedForDisplay`)과
        // 같은 tie-break(앱 키 사전순)를 둬 동률에서도 결정적인 순서를 만듭니다.
        let sorted = entries.sorted { lhs, rhs in
            lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key.value < rhs.key.value
        }
        return Array(sorted.prefix(ApplicationRankingSampling.topCount))
    }

    /// 정체성 하나의 순간값을 평활화한 값. `compute(_:)`의 TOP 5 집계와 `groupByApplication(_:)`의 상세 표시가
    /// 같은 평활화 규칙을 공유하도록 이 자리에 둡니다 — 카드와 상세가 다른 규칙을 쓰면 같은 앱이
    /// 서로 다른 순서로 보이게 됩니다.
    /// CPU는 기준점이 없어 값을 만들지 못한 조사가 섞일 수 있으므로 값이 있는 것만 평균하고,
    /// 하나도 없으면 `nil`입니다 — 읽지 못한 프로세스의 사용량을 추정값으로 채우지 않습니다.
    /// Resident Memory는 항상 값이 있으므로 최근 값 전체를 그대로 평균합니다.
    static func smoothedRecentValues(for snapshot: ProcessHistorySnapshot) -> (cpuUsagePercent: Double?, residentBytes: Double) {
        let cpuValues = snapshot.recentValues.compactMap(\.cpuUsagePercent)
        let cpuUsagePercent = cpuValues.isEmpty ? nil : cpuValues.reduce(0, +) / Double(cpuValues.count)

        guard !snapshot.recentValues.isEmpty else {
            return (cpuUsagePercent, 0)
        }
        let residentBytes = snapshot.recentValues.reduce(0.0) { $0 + Double($1.residentBytes) }
            / Double(snapshot.recentValues.count)

        return (cpuUsagePercent, residentBytes)
    }
}

/// 앱 키로 묶은 프로세스 하나. 상세 영역에서 앱 항목을 펼치면 나타나는 하위 프로세스 목록의 원소입니다(ANALYSIS §2 「팝오버 열림과 카드 선택」).
/// CPU 상세는 `cpuUsagePercent`와 `isTranslated`를, Memory 상세는 `residentBytes`를 씁니다 —
/// CPU와 Memory가 같은 앱 키 규칙을 공유하므로(DP5) 그룹 목록 자체는 카드마다 다시 계산하지 않고 하나를 공유합니다.
nonisolated struct ApplicationProcessDetail: Sendable, Equatable {
    let pid: pid_t
    /// 실행 파일 이름. `ApplicationIdentityResolver.executableName(from:)`이 유도하며, 번들 밖 실행 파일의
    /// 표시 이름과 같은 규칙을 공유합니다 — PID만으로는 상세 목록에서 어떤 프로세스인지 알 수 없습니다.
    let executableName: String
    /// `ApplicationRanking.smoothedRecentValues(for:)`가 계산한 최근 값 평균 — TOP 5 집계와 같은 평활화 규칙입니다.
    /// 최근 값 중 CPU 사용률이 하나도 없으면(기준점이 없거나 조사 간격이 허용 범위를 넘은 조사만 섞인 경우) `nil`입니다.
    let cpuUsagePercent: Double?
    /// `ApplicationRanking.smoothedRecentValues(for:)`가 계산한 최근 값 평균입니다.
    let residentBytes: UInt64
    let isTranslated: Bool
}

extension ApplicationProcessDetail {
    /// 프로세스 CPU 사용률의 단위 라벨. 논리 코어 합산 관례라 100%를 넘을 수 있어
    /// 시스템 전체 사용률의 단위(`CPUCardPresentation.overallUsageUnitLabel`)와 다른 문자열을 씁니다.
    static let cpuUsageUnitLabel = "% (코어 합산)"
}

/// 상세 목록의 값 표시 서식. CPU·Memory 상세 뷰(`DashboardView`)가 공유합니다.
/// 값을 만들지 못한 경우 0을 지어내지 않고 `"-"`로 남깁니다(SPEC §5.6) — 이 규칙을 뷰 본문 안에 인라인
/// 클로저로만 두면 단위 테스트로 직접 확인할 수 없어 이 자리로 분리했습니다.
nonisolated enum ApplicationProcessValueFormatting {
    /// CPU 그룹 합계(`ApplicationProcessGroup.sortValue`)의 표시 문자열.
    static func cpuGroupValueText(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded()))\(ApplicationProcessDetail.cpuUsageUnitLabel)" } ?? "-"
    }

    /// CPU 프로세스 개별 값의 표시 문자열. Rosetta로 변환 실행 중이면 그 사실을 덧붙입니다.
    static func cpuProcessValueText(_ process: ApplicationProcessDetail) -> String {
        let usageText = process.cpuUsagePercent.map { "\(Int($0.rounded()))\(ApplicationProcessDetail.cpuUsageUnitLabel)" } ?? "-"
        return process.isTranslated ? "\(usageText) · Rosetta" : usageText
    }

    /// Memory 그룹 합계의 표시 문자열. 바이트 서식은 호출부(`MemoryDetailView`)가 공유하는
    /// `ByteCountFormatter` 기반 함수를 그대로 받아써, 서식 규칙을 이 자리에 중복 두지 않습니다.
    static func memoryGroupValueText(_ value: Double?, format: (UInt64) -> String) -> String {
        value.map { format(UInt64($0.rounded())) } ?? "-"
    }
}

/// 상세 목록(`ApplicationProcessGroupListView`)이 화면에 보여줄 그룹 순서를 정합니다.
/// 펼친 앱 행이 하나라도 있으면 최신 정렬을 곧장 반영하지 않고 `stableOrder`를 유지합니다 —
/// 목록이 매 tick 다시 정렬되는 동안 펼친 행이 화면에서 자리를 옮기면, 그 행을 다시 클릭하는 시도가
/// 이동 전 좌표를 써서 엉뚱한 행을 클릭하는 결함이 있었습니다(상세 팝업 결함 조사).
/// 값 자체는 고정하지 않고, 순서만 멈춥니다.
nonisolated enum ApplicationProcessGroupOrdering {
    /// - Parameters:
    ///   - groups: 이번 tick의 최신 정렬 결과.
    ///   - stableOrder: 펼친 행이 없었던 마지막 순간에 담아 둔 앱 키 순서.
    ///   - hasExpandedRow: 펼친 행이 하나라도 있으면 `true`.
    /// - Returns: `hasExpandedRow`가 `false`면 `groups`를 그대로, `true`면 `stableOrder` 순서를 따르되
    ///   그 사이 사라진 앱은 빠지고 새로 나타난 앱은 뒤에 붙은 목록.
    static func displayedGroups(
        groups: [ApplicationProcessGroup],
        stableOrder: [ApplicationKey],
        hasExpandedRow: Bool
    ) -> [ApplicationProcessGroup] {
        guard hasExpandedRow else { return groups }

        let groupsByKey = Dictionary(uniqueKeysWithValues: groups.map { ($0.key, $0) })
        var ordered = stableOrder.compactMap { groupsByKey[$0] }
        let orderedKeys = Set(stableOrder)
        ordered.append(contentsOf: groups.filter { !orderedKeys.contains($0.key) })
        return ordered
    }
}

/// 앱 하나로 묶인 프로세스 그룹. 표시 이름과 앱 키는 `ApplicationRankingEntry`와 같은 유도 규칙을 씁니다.
nonisolated struct ApplicationProcessGroup: Sendable, Equatable {
    let key: ApplicationKey
    let displayName: String
    let processes: [ApplicationProcessDetail]
    /// `sortedForDisplay(groups:by:)`가 정렬에 쓴 그룹 합계 값을 그대로 담습니다. 화면이 표시용으로
    /// 값을 다시 계산하면 정렬 키와 어긋날 수 있으므로(SPEC §5.6), 정렬이 계산한 바로 그 값을 재사용합니다.
    /// `groupByApplication(_:)`이 만드는 미정렬 그룹에는 정렬 기준(metric)이 없으므로 `nil`입니다.
    /// CPU처럼 그룹 안 모든 프로세스의 값이 `nil`이면 정렬 후에도 `nil`로 남습니다.
    let sortValue: Double?

    init(key: ApplicationKey, displayName: String, processes: [ApplicationProcessDetail], sortValue: Double? = nil) {
        self.key = key
        self.displayName = displayName
        self.processes = processes
        self.sortValue = sortValue
    }
}

extension ApplicationRanking {
    /// `ProcessHistoryStore.snapshot()`이 돌려준 정체성별 이력을 앱 키로 묶어 하위 프로세스 그룹 목록을 만듭니다.
    ///
    /// `ApplicationRankingSample`은 앱 키별 합산값만 담고 그 키에 속한 개별 프로세스 목록은 담지 않으므로,
    /// "앱 항목을 펼치면 하위 프로세스가 나타난다"(SPEC §5.2, SPEC §5.6)를 만족하려면 `snapshot()` 결과를
    /// `compute(_:)`와 별도로 한 번 더 순회해야 합니다. 두 계산이 같은 `resolver`를 이어받아 앱 키 유도가
    /// 두 번 다른 결과를 내지 않게 합니다.
    /// 프로세스별 값도 `smoothedRecentValues(for:)`로 `compute(_:)`와 같은 평활화 규칙을 공유합니다 —
    /// 카드 TOP 5와 상세 목록이 순간값·평활화 값을 섞어 쓰면 같은 앱이 서로 다른 순서로 보입니다.
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
            let smoothed = smoothedRecentValues(for: snapshot)
            processesByKey[identity.key, default: []].append(
                ApplicationProcessDetail(
                    pid: snapshot.identity.pid,
                    executableName: ApplicationIdentityResolver.executableName(from: snapshot.executablePath),
                    cpuUsagePercent: smoothed.cpuUsagePercent,
                    residentBytes: UInt64(smoothed.residentBytes.rounded()),
                    isTranslated: snapshot.isTranslated
                )
            )
        }

        let groups = order.map { key in
            ApplicationProcessGroup(key: key, displayName: displayNames[key] ?? key.value, processes: processesByKey[key] ?? [])
        }
        return (groups, resolver)
    }

    /// 상세 팝업의 하위 프로세스 목록을 정렬하는 기준. CPU 카드는 `cpuUsage`, Memory 카드는
    /// `residentMemory`를 써서 두 카드가 같은 `groupByApplication(_:)` 결과를 공유하면서도
    /// 각자의 값 기준으로 독립적으로 정렬됩니다.
    nonisolated enum ProcessGroupSortMetric: Sendable {
        case cpuUsage
        case residentMemory
    }

    /// `groupByApplication(_:)`이 관찰 순서 그대로 돌려준 그룹·프로세스 목록을 표시용으로 정렬합니다.
    /// Dictionary 기반 집계를 거쳐 오므로 입력 순서가 비결정적일 수 있고, 이 함수가 그 비결정성을 없애
    /// 매 tick 같은 논리적 입력이면 같은 순서를 돌려줍니다. 앱 항목을 펼치면 하위 프로세스가 나타나는
    /// 상세 목록이 이 함수의 결과를 그대로 쓰므로 SPEC §5.2와 SPEC §5.6을 담당합니다.
    ///
    /// 그룹 값은 그룹에 속한 프로세스 값의 합입니다 — `compute(_:)`가 앱 단위 집계에 쓰는 `+=` 합산 관례를
    /// 상세 목록 정렬에도 그대로 맞춥니다. 그룹·프로세스 모두 값이 같으면 흔들리지 않도록 tie-break를
    /// 둡니다 — 그룹은 앱 키 사전순, 프로세스는 pid 오름차순.
    /// CPU 값은 기준점이 없어 `nil`일 수 있으며(SPEC §5.6 — 읽지 못한 프로세스의 사용량이 추정값으로
    /// 채워지지 않습니다), `nil`을 0으로 취급하지 않고 값이 있는 항목보다 뒤로 보냅니다.
    ///
    /// 정렬 비교자 안에서 `groupSortValue(_:by:)`를 매번 다시 계산하면 `sorted`가 그룹 수의 로그배만큼
    /// 반복 호출해 같은 합산을 중복 수행하므로, 그룹마다 정렬 키를 한 번만 계산해 `ApplicationProcessGroup.sortValue`에
    /// 담아 둡니다(decorate-sort). 이 값을 버리지 않고 그대로 돌려주므로, 상세 화면은 이 값을 그대로 표시하면
    /// 정렬 키와 표시 값이 항상 같습니다.
    static func sortedForDisplay(
        groups: [ApplicationProcessGroup],
        by metric: ProcessGroupSortMetric
    ) -> [ApplicationProcessGroup] {
        groups
            .map { group -> ApplicationProcessGroup in
                let sortedProcesses = sortedProcesses(group.processes, by: metric)
                let sortValue = groupSortValue(
                    ApplicationProcessGroup(key: group.key, displayName: group.displayName, processes: sortedProcesses),
                    by: metric
                )
                return ApplicationProcessGroup(
                    key: group.key,
                    displayName: group.displayName,
                    processes: sortedProcesses,
                    sortValue: sortValue
                )
            }
            .sorted { lhs, rhs in
                isOrderedBefore(
                    lhsValue: lhs.sortValue,
                    rhsValue: rhs.sortValue,
                    lhsTiebreak: lhs.key.value,
                    rhsTiebreak: rhs.key.value,
                    tiebreakIsOrderedBefore: <
                )
            }
    }

    private static func sortedProcesses(
        _ processes: [ApplicationProcessDetail],
        by metric: ProcessGroupSortMetric
    ) -> [ApplicationProcessDetail] {
        processes.sorted { lhs, rhs in
            isOrderedBefore(
                lhsValue: processSortValue(lhs, by: metric),
                rhsValue: processSortValue(rhs, by: metric),
                lhsTiebreak: lhs.pid,
                rhsTiebreak: rhs.pid,
                tiebreakIsOrderedBefore: <
            )
        }
    }

    /// 그룹 하나의 정렬 값. CPU는 그룹 안에 값 있는 프로세스가 하나도 없으면 `nil`(기준점이 없는 조사가 섞인 앱),
    /// 그 외에는 값 있는 프로세스의 합입니다. Memory는 항상 값이 있으므로 그대로 합입니다.
    private static func groupSortValue(_ group: ApplicationProcessGroup, by metric: ProcessGroupSortMetric) -> Double? {
        switch metric {
        case .cpuUsage:
            let values = group.processes.compactMap(\.cpuUsagePercent)
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +)
        case .residentMemory:
            return Double(group.processes.reduce(UInt64(0)) { $0 + $1.residentBytes })
        }
    }

    private static func processSortValue(_ process: ApplicationProcessDetail, by metric: ProcessGroupSortMetric) -> Double? {
        switch metric {
        case .cpuUsage:
            return process.cpuUsagePercent
        case .residentMemory:
            return Double(process.residentBytes)
        }
    }

    /// 값 내림차순으로 정렬하되(`nil`은 값 있는 것보다 뒤), 값이 같으면(둘 다 `nil`인 경우 포함)
    /// tiebreak 기준 오름차순으로 결정적인 순서를 만듭니다.
    private static func isOrderedBefore<Tiebreak>(
        lhsValue: Double?,
        rhsValue: Double?,
        lhsTiebreak: Tiebreak,
        rhsTiebreak: Tiebreak,
        tiebreakIsOrderedBefore: (Tiebreak, Tiebreak) -> Bool
    ) -> Bool {
        switch (lhsValue, rhsValue) {
        case let (lhs?, rhs?) where lhs != rhs:
            return lhs > rhs
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            return tiebreakIsOrderedBefore(lhsTiebreak, rhsTiebreak)
        }
    }
}
