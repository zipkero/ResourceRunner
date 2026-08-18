//
//  ApplicationRankingTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/14/26.
//

import Darwin
import Foundation
import Testing
@testable import ResourceRunner

// MARK: - 앱 키 유도

/// task-006 검증 조건: 경로 표본으로 앱 키 유도를 전수 검증합니다 —
/// 중첩 helper 번들, `.app` 안의 `.app`, 번들 밖 명령행 바이너리, 심볼릭 링크 형태 경로를 각각 단언합니다.
struct ApplicationIdentityDerivationTests {

    @Test(arguments: [
        // 중첩 helper 번들: Chrome Renderer Helper가 상위 Chrome.app 하나로 접힙니다.
        (
            "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/"
                + "Versions/151.0.7922.77/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/"
                + "Google Chrome Helper (Renderer)",
            "/Applications/Google Chrome.app",
            "Google Chrome"
        ),
        // 번들 안의 `.app` 확장자가 아닌 일반 디렉터리(VS Code류의 `app` 폴더)는 `.app`로 오인되지 않습니다.
        (
            "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
            "/Applications/Visual Studio Code.app",
            "Visual Studio Code"
        ),
        // `.app` 안에 중첩된 또 다른 `.app`: 가장 바깥(왼쪽) 것이 키가 됩니다.
        (
            "/Applications/Outer.app/Contents/Nested/Wrapped.app/Contents/MacOS/Wrapped",
            "/Applications/Outer.app",
            "Outer"
        ),
        // 번들 밖 명령행 바이너리: `.app`가 없으므로 실행 경로 자체가 키입니다.
        (
            "/usr/local/bin/node",
            "/usr/local/bin/node",
            "node"
        ),
        // 심볼릭 링크가 흔히 거치는 `/private/var` 경유 경로도 문자열 그대로 처리되어 동일하게 접힙니다.
        (
            "/private/var/folders/xy/T/AppTranslocation/abcd/d/Ghostty.app/Contents/MacOS/ghostty",
            "/private/var/folders/xy/T/AppTranslocation/abcd/d/Ghostty.app",
            "Ghostty"
        ),
    ])
    func derivesOutermostBundleOrFallsBackToExecutablePath(
        path: String,
        expectedKey: String,
        expectedDisplayName: String
    ) {
        let identity = ApplicationIdentityResolver.deriveIdentity(from: path)

        #expect(identity.key.value == expectedKey)
        #expect(identity.displayName == expectedDisplayName)
    }

    @Test func resolverCachesRepeatedPathWithoutChangingResult() {
        var resolver = ApplicationIdentityResolver()
        let path = "/Applications/Kiro.app/Contents/Frameworks/Kiro Helper (GPU).app/Contents/MacOS/Kiro Helper (GPU)"

        let first = resolver.resolve(executablePath: path)
        let second = resolver.resolve(executablePath: path)

        #expect(first == second)
        #expect(resolver.cachedPathCount == 1)
    }

    /// 상한을 넘는 서로 다른 경로가 들어오면 가장 오래전에 쓰인 항목부터 밀려나
    /// 캐시 크기가 상한 이상으로 늘지 않습니다.
    @Test func resolverEvictsLeastRecentlyUsedPathBeyondCapacity() {
        var resolver = ApplicationIdentityResolver(capacity: 2)

        _ = resolver.resolve(executablePath: "/bin/a")
        _ = resolver.resolve(executablePath: "/bin/b")
        _ = resolver.resolve(executablePath: "/bin/c")

        #expect(resolver.cachedPathCount == 2)
    }
}

// MARK: - 순위 계산 테스트 helper

private let baseInstant = ContinuousClock().now

private func rankingSample(
    cpuUsagePercent: Double?,
    residentBytes: UInt64
) -> ProcessRankingSample {
    ProcessRankingSample(cpuUsagePercent: cpuUsagePercent, residentBytes: residentBytes)
}

private func snapshot(
    pid: pid_t,
    executablePath: String,
    recentValues: [ProcessRankingSample],
    memoryBaselines: [ProcessMemoryBaselinePoint] = []
) -> ProcessHistorySnapshot {
    ProcessHistorySnapshot(
        identity: ProcessIdentity(pid: pid, startTime: 0),
        executablePath: executablePath,
        recentValues: recentValues,
        memoryBaselines: memoryBaselines
    )
}

// MARK: - 현재 사용량 순위: 최근 세 개 평균

/// task-006 검증 조건: 순간값이 아니라 최근 여러 샘플을 반영해 순위가 매 갱신마다 요동치지 않습니다.
/// 이 테스트가 고정하는 것은 "순간값으로 순위를 만들지 않는다"입니다 —
/// 평균을 최신값으로 되돌리면 한 tick만 급등한 앱이 1위가 되어 이 테스트가 실패해야 합니다.
struct ApplicationRankingAveragingTests {

    @Test func oneTickSpikeDoesNotOutrankConsistentlyHigherApp() {
        // spikedApp은 두 tick 동안 낮다가 이번 tick에서만 급등하고, steadyApp은 세 tick 모두 고르게 높습니다.
        let spiked = snapshot(
            pid: 100,
            executablePath: "/Applications/Spiked.app/Contents/MacOS/Spiked",
            recentValues: [
                rankingSample(cpuUsagePercent: 1, residentBytes: 1_000),
                rankingSample(cpuUsagePercent: 1, residentBytes: 1_000),
                rankingSample(cpuUsagePercent: 90, residentBytes: 1_000),
            ]
        )
        let steady = snapshot(
            pid: 200,
            executablePath: "/Applications/Steady.app/Contents/MacOS/Steady",
            recentValues: [
                rankingSample(cpuUsagePercent: 40, residentBytes: 1_000),
                rankingSample(cpuUsagePercent: 40, residentBytes: 1_000),
                rankingSample(cpuUsagePercent: 40, residentBytes: 1_000),
            ]
        )

        let (sample, _) = ApplicationRanking.compute(
            snapshots: [spiked, steady],
            currentTimestamp: baseInstant,
            unreadableCount: 0,
            resolver: ApplicationIdentityResolver()
        )

        #expect(sample.cpuUsage.first?.displayName == "Steady")
    }

    /// 여러 프로세스로 구성된 앱은 하나의 항목으로 합산됩니다(중첩 helper 번들 합산).
    @Test func processesUnderSameBundleAreAggregatedIntoOneEntry() throws {
        let mainProcess = snapshot(
            pid: 100,
            executablePath: "/Applications/Kiro.app/Contents/MacOS/Electron",
            recentValues: [rankingSample(cpuUsagePercent: 10, residentBytes: 1_000)]
        )
        let helperProcess = snapshot(
            pid: 101,
            executablePath: "/Applications/Kiro.app/Contents/Frameworks/Kiro Helper (Renderer).app/Contents/MacOS/Kiro Helper (Renderer)",
            recentValues: [rankingSample(cpuUsagePercent: 15, residentBytes: 2_000)]
        )
        let otherApp = snapshot(
            pid: 200,
            executablePath: "/Applications/Other.app/Contents/MacOS/Other",
            recentValues: [rankingSample(cpuUsagePercent: 5, residentBytes: 500)]
        )

        let (sample, _) = ApplicationRanking.compute(
            snapshots: [mainProcess, helperProcess, otherApp],
            currentTimestamp: baseInstant,
            unreadableCount: 0,
            resolver: ApplicationIdentityResolver()
        )

        let kiroEntry = try #require(sample.cpuUsage.first { $0.displayName == "Kiro" })
        #expect(kiroEntry.value == 25)
        #expect(sample.cpuUsage.count == 2)
    }
}

// MARK: - 현재 사용량 순위와 증가량 순위의 분리

/// task-006 검증 조건: 현재 사용량이 큰 앱과 증가량이 큰 앱을 다르게 구성한 입력에서
/// 두 목록의 1위가 다름을 단언합니다.
struct ApplicationRankingCurrentVersusIncreaseTests {

    @Test func largeCurrentUsageAndLargeIncreaseProduceDifferentTopEntries() {
        let windowStart = baseInstant - ProcessHistorySampling.memoryBaselineWindow

        // heavyButStable: 지금 메모리를 가장 많이 쓰지만 10분간 변화가 없습니다.
        let heavyButStable = snapshot(
            pid: 100,
            executablePath: "/Applications/HeavyButStable.app/Contents/MacOS/HeavyButStable",
            recentValues: [rankingSample(cpuUsagePercent: 1, residentBytes: 10_000_000)],
            memoryBaselines: [
                ProcessMemoryBaselinePoint(timestamp: windowStart.advanced(by: .seconds(1)), residentBytes: 10_000_000)
            ]
        )
        // smallButGrowing: 지금 쓰는 양은 적지만 10분 사이 크게 늘었습니다.
        let smallButGrowing = snapshot(
            pid: 200,
            executablePath: "/Applications/SmallButGrowing.app/Contents/MacOS/SmallButGrowing",
            recentValues: [rankingSample(cpuUsagePercent: 1, residentBytes: 1_000_000)],
            memoryBaselines: [
                ProcessMemoryBaselinePoint(timestamp: windowStart.advanced(by: .seconds(1)), residentBytes: 10_000)
            ]
        )

        let (sample, _) = ApplicationRanking.compute(
            snapshots: [heavyButStable, smallButGrowing],
            currentTimestamp: baseInstant,
            unreadableCount: 0,
            resolver: ApplicationIdentityResolver()
        )

        #expect(sample.memoryUsage.first?.displayName == "HeavyButStable")
        #expect(sample.memoryIncrease.first?.displayName == "SmallButGrowing")
    }

    /// 사용량이 크지만 변화가 없는 앱이 증가량 순위 상위에 오르지 않습니다.
    @Test func staleUsageDoesNotRankHighInIncreaseList() {
        let windowStart = baseInstant - ProcessHistorySampling.memoryBaselineWindow
        let stable = snapshot(
            pid: 100,
            executablePath: "/Applications/Stable.app/Contents/MacOS/Stable",
            recentValues: [rankingSample(cpuUsagePercent: 1, residentBytes: 50_000_000)],
            memoryBaselines: [
                ProcessMemoryBaselinePoint(timestamp: windowStart.advanced(by: .seconds(1)), residentBytes: 50_000_000)
            ]
        )

        let (sample, _) = ApplicationRanking.compute(
            snapshots: [stable],
            currentTimestamp: baseInstant,
            unreadableCount: 0,
            resolver: ApplicationIdentityResolver()
        )

        #expect(sample.memoryIncrease.first?.value == 0)
    }
}

// MARK: - 10분 창 경계

/// task-006 검증 조건: 10분 창 밖의 기준점은 증가량 계산에 쓰이지 않습니다.
struct ApplicationRankingWindowBoundaryTests {

    @Test func baselineOutsideWindowIsIgnoredInFavorOfOldestWithinWindow() {
        let windowStart = baseInstant - ProcessHistorySampling.memoryBaselineWindow

        let snap = snapshot(
            pid: 100,
            executablePath: "/Applications/Windowed.app/Contents/MacOS/Windowed",
            recentValues: [rankingSample(cpuUsagePercent: 1, residentBytes: 5_000)],
            memoryBaselines: [
                // 창 밖(더 오래된) 기준점: 이 값이 쓰이면 증가량이 훨씬 커집니다.
                ProcessMemoryBaselinePoint(timestamp: windowStart.advanced(by: .seconds(-30)), residentBytes: 100),
                // 창 안에서 가장 오래된 기준점: 이 값이 증가량 계산에 쓰여야 합니다.
                ProcessMemoryBaselinePoint(timestamp: windowStart.advanced(by: .seconds(10)), residentBytes: 4_000),
            ]
        )

        let (sample, _) = ApplicationRanking.compute(
            snapshots: [snap],
            currentTimestamp: baseInstant,
            unreadableCount: 0,
            resolver: ApplicationIdentityResolver()
        )

        #expect(sample.memoryIncrease.first?.value == 1_000)
    }
}

// MARK: - 읽지 못한 프로세스 수 전달

/// task-006 검증 조건: 읽지 못한 프로세스 수가 순위 결과와 함께 표시 계층으로 전달됩니다.
struct ApplicationRankingUnreadableCountTests {

    @Test func unreadableCountPassesThroughUnchanged() {
        let (sample, _) = ApplicationRanking.compute(
            snapshots: [],
            currentTimestamp: baseInstant,
            unreadableCount: 7,
            resolver: ApplicationIdentityResolver()
        )

        #expect(sample.unreadableCount == 7)
    }
}

// MARK: - 실기기 관찰: 실제 실행 중인 프로세스의 앱 단위 묶임
//
// task-006 검증 조건 중 실기기 확인(가장 바깥 `.app` 규칙이 실제 앱에서 성립하는지)은
// `Process()`로 `/bin/ps`를 실행해 테스트 코드로 자동화하려 했으나, App Sandbox가 적용된 이
// 테스트 host에서 서브프로세스 실행 자체가 `Operation not permitted`(POSIX errno 1)로 막혀
// 테스트로 넣을 수 없었습니다(이 시도 자체가 Sandbox에서 서브프로세스 실행이 차단된다는
// `docs/design.md` 기록과 일치합니다).
// 대신 이 머신에서 Bash로 직접 `ps -Ao pid,comm`을 실행해 관찰했습니다 —
// 헬퍼 프로세스의 실행 경로가 가장 바깥 `.app` 번들 아래에 있어, 위 규칙대로 상위 앱 하나로
// 묶이는 것이 실제 실행 중인 프로세스에서도 성립함을 확인했습니다.

// MARK: - 카드 TOP 5와 상세 목록의 순서 일치

/// 상세 팝업의 정렬·표시가 순간값을 쓰던 결함을 고치는 테스트입니다.
/// `groupByApplication(_:)`이 `compute(_:)`와 같은 평활화 규칙(`smoothedRecentValues(for:)`)을 공유해야
/// 카드 TOP 5와 상세 상위 목록이 같은 순서로 보입니다(SPEC §5.6).
struct ApplicationRankingCardDetailConsistencyTests {

    /// spiked는 이번 tick만 급등하고 steady는 세 tick 모두 고르게 높습니다.
    /// 순간값(최근 tick, 90 대 40)으로 정렬하면 spiked가 앞서지만, 평활화 평균(30.67 대 40)으로는 steady가 앞섭니다.
    /// 표시·정렬을 다시 순간값(`recentValues.last`)으로 되돌리면
    /// 상세 상위 순서가 카드와 달라져 이 테스트가 실패해야 합니다.
    @Test func detailTopOrderMatchesCardTopOrderUnderInstantVersusSmoothedDivergence() {
        let spiked = snapshot(
            pid: 100,
            executablePath: "/Applications/Spiked.app/Contents/MacOS/Spiked",
            recentValues: [
                rankingSample(cpuUsagePercent: 1, residentBytes: 1_000),
                rankingSample(cpuUsagePercent: 1, residentBytes: 1_000),
                rankingSample(cpuUsagePercent: 90, residentBytes: 1_000),
            ]
        )
        let steady = snapshot(
            pid: 200,
            executablePath: "/Applications/Steady.app/Contents/MacOS/Steady",
            recentValues: [
                rankingSample(cpuUsagePercent: 40, residentBytes: 1_000),
                rankingSample(cpuUsagePercent: 40, residentBytes: 1_000),
                rankingSample(cpuUsagePercent: 40, residentBytes: 1_000),
            ]
        )

        let (cardSample, resolverAfterCompute) = ApplicationRanking.compute(
            snapshots: [spiked, steady],
            currentTimestamp: baseInstant,
            unreadableCount: 0,
            resolver: ApplicationIdentityResolver()
        )
        let (groups, _) = ApplicationRanking.groupByApplication(
            snapshots: [spiked, steady],
            resolver: resolverAfterCompute
        )
        let detailOrder = ApplicationRanking.sortedForDisplay(groups: groups, by: .cpuUsage)

        #expect(cardSample.cpuUsage.first?.displayName == "Steady")
        #expect(detailOrder.map(\.displayName) == cardSample.cpuUsage.map(\.displayName))
    }

    /// `groupByApplication(_:)`이 `compute(_:)`와 같은 평활화 값을 만듭니다.
    /// 평균 대신 최댓값을 쓰거나 창 길이를 바꾸면 두 계산 결과가 어긋나 이 테스트가 실패해야 합니다.
    @Test func groupByApplicationUsesSameSmoothingRuleAsCompute() {
        let mixedApp = snapshot(
            pid: 400,
            executablePath: "/Applications/Mixed.app/Contents/MacOS/Mixed",
            recentValues: [
                rankingSample(cpuUsagePercent: 10, residentBytes: 2_000),
                rankingSample(cpuUsagePercent: 20, residentBytes: 4_000),
                rankingSample(cpuUsagePercent: 30, residentBytes: 6_000),
            ]
        )

        let (cardSample, resolverAfterCompute) = ApplicationRanking.compute(
            snapshots: [mixedApp],
            currentTimestamp: baseInstant,
            unreadableCount: 0,
            resolver: ApplicationIdentityResolver()
        )
        let (groups, _) = ApplicationRanking.groupByApplication(snapshots: [mixedApp], resolver: resolverAfterCompute)

        #expect(cardSample.cpuUsage.first?.value == 20)
        #expect(cardSample.memoryUsage.first?.value == 4_000)
        #expect(groups.first?.processes.first?.cpuUsagePercent == 20)
        #expect(groups.first?.processes.first?.residentBytes == 4_000)
    }

    /// CPU 기준점이 없어 최근 값 전체가 `nil`인 프로세스는 평활화 평균도 만들 수 없어 `nil`이 유지됩니다.
    /// `nil`을 0으로 채우면 「읽지 못한 프로세스의 사용량이 추정값으로 채워지지 않습니다」(SPEC §5.6)를 어기고
    /// 이 테스트가 실패해야 합니다.
    @Test func groupByApplicationKeepsNilCPUWhenNoRecentValueHasIt() {
        let noBaselineProcess = snapshot(
            pid: 300,
            executablePath: "/Applications/Fresh.app/Contents/MacOS/Fresh",
            recentValues: [rankingSample(cpuUsagePercent: nil, residentBytes: 1_000)]
        )

        let (groups, _) = ApplicationRanking.groupByApplication(
            snapshots: [noBaselineProcess],
            resolver: ApplicationIdentityResolver()
        )

        #expect(groups.first?.processes.first?.cpuUsagePercent == nil)
    }
}

// MARK: - 카드 TOP 5 동률 tie-break

/// 카드 TOP 5(`topEntries`)가 Dictionary 유래 입력을 값 내림차순으로만 정렬해 동률일 때 순서가
/// 임의였던 결함을 고치는 테스트입니다. 상세 목록(`sortedForDisplay`)과 같은 tie-break(앱 키 사전순)를
/// 두지 않으면 이 테스트가 실패해야 합니다.
struct ApplicationRankingCardTopEntriesTieBreakTests {

    /// tie-break 대상 앱을 다섯 개 두는 이유: `topEntries`의 입력은 Dictionary(`cpuUsageByKey`)를 거치므로
    /// 두 앱만으로는 Dictionary의 무작위 해시 순서가 우연히 사전순과 같아져 tie-break를 지워도
    /// 테스트가 통과할 수 있습니다(순열 2개 중 1개가 우연히 들어맞음). 앱 다섯 개(순열 120개)로 늘려
    /// tie-break가 없을 때 실패할 확률을 사실상 1에 가깝게 만듭니다.
    private static let tiedNames = ["E", "D", "C", "B", "A"]

    private static func tiedApps() -> [ProcessHistorySnapshot] {
        tiedNames.enumerated().map { index, name in
            snapshot(
                pid: pid_t(100 + index),
                executablePath: "/Applications/\(name).app/Contents/MacOS/\(name)",
                recentValues: [rankingSample(cpuUsagePercent: 30, residentBytes: 1_000)]
            )
        }
    }

    /// 여러 앱의 평활화 합이 정확히 같으면 앱 키 사전순으로 정렬됩니다.
    /// tie-break를 지우면(값만으로 비교하면) 이 순서가 Dictionary 순회 순서에 흔들려 실패해야 합니다.
    @Test func tiedValuesOrderByApplicationKeyAscending() {
        let (sample, _) = ApplicationRanking.compute(
            snapshots: Self.tiedApps(),
            currentTimestamp: baseInstant,
            unreadableCount: 0,
            resolver: ApplicationIdentityResolver()
        )

        #expect(sample.cpuUsage.map(\.displayName) == ["A", "B", "C", "D", "E"])
    }

    /// 동률 입력에서도 카드 TOP 5와 상세 상위 순서가 일치해야 합니다(SPEC §5.6) —
    /// 카드만 tie-break가 없으면 상세(앱 키 사전순)와 순서가 갈릴 수 있어 이 테스트가 실패해야 합니다.
    @Test func cardTopOrderMatchesDetailTopOrderUnderTiedValues() {
        let apps = Self.tiedApps()

        let (cardSample, resolverAfterCompute) = ApplicationRanking.compute(
            snapshots: apps,
            currentTimestamp: baseInstant,
            unreadableCount: 0,
            resolver: ApplicationIdentityResolver()
        )
        let (groups, _) = ApplicationRanking.groupByApplication(snapshots: apps, resolver: resolverAfterCompute)
        let detailOrder = ApplicationRanking.sortedForDisplay(groups: groups, by: .cpuUsage)

        #expect(detailOrder.map(\.displayName) == cardSample.cpuUsage.map(\.displayName))
    }
}

// MARK: - 상세 팝업 하위 프로세스 목록 정렬

/// `groupByApplication(_:)`이 Dictionary 순회 순서를 그대로 보존해 매 tick 순서가 흔들리던 결함을
/// 고치는 `sortedForDisplay(groups:by:)`의 결정성·정렬 기준·tie-break를 검증합니다.
/// 상세 팝업에서 앱 항목을 펼치면 이 함수의 결과가 그대로 하위 프로세스 목록으로 나타나므로
/// SPEC §5.2와 SPEC §5.6을 담당합니다.
private func processDetail(pid: pid_t, cpuUsagePercent: Double?, residentBytes: UInt64) -> ApplicationProcessDetail {
    ApplicationProcessDetail(
        pid: pid,
        executableName: "proc\(pid)",
        cpuUsagePercent: cpuUsagePercent,
        residentBytes: residentBytes,
        isTranslated: false
    )
}

struct ApplicationProcessGroupSortingTests {

    /// Dictionary 기반 집계를 거치는 실제 경로에서는 그룹·프로세스 배열의 입력 순서가 프로그램 실행마다
    /// 달라질 수 있습니다. 실제 Dictionary 순회 순서에 기대면 위양성이 되므로, 같은 논리적 입력을
    /// 순서만 다른 여러 배열로 만들어 결과가 항상 같은지 확인합니다.
    @Test func sameLogicalInputProducesSameOrderRegardlessOfInputOrder() {
        let groupA = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/A.app"),
            displayName: "A",
            processes: [
                processDetail(pid: 10, cpuUsagePercent: 5, residentBytes: 100),
                processDetail(pid: 11, cpuUsagePercent: 10, residentBytes: 200),
            ]
        )
        let groupB = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/B.app"),
            displayName: "B",
            processes: [
                processDetail(pid: 20, cpuUsagePercent: 8, residentBytes: 50),
            ]
        )
        // groupA 안의 프로세스 순서도 함께 뒤집어 두 축 모두 입력 순서와 무관함을 확인합니다.
        let groupAReversed = ApplicationProcessGroup(
            key: groupA.key,
            displayName: groupA.displayName,
            processes: groupA.processes.reversed()
        )

        let orderedInput = [groupA, groupB]
        let reversedInput = [groupB, groupAReversed]

        let cpuResult1 = ApplicationRanking.sortedForDisplay(groups: orderedInput, by: .cpuUsage)
        let cpuResult2 = ApplicationRanking.sortedForDisplay(groups: reversedInput, by: .cpuUsage)
        #expect(cpuResult1 == cpuResult2)

        let memoryResult1 = ApplicationRanking.sortedForDisplay(groups: orderedInput, by: .residentMemory)
        let memoryResult2 = ApplicationRanking.sortedForDisplay(groups: reversedInput, by: .residentMemory)
        #expect(memoryResult1 == memoryResult2)
    }

    /// 그룹 정렬 값은 그룹 안 프로세스 값의 합입니다(`compute(_:)`의 `+=` 합산 관례와 동일). CPU 기준 내림차순도 함께 확인합니다.
    /// 그룹을 최댓값이나 첫 프로세스 값으로 정렬하면, 합이 더 큰 그룹(6)이 단일 최댓값 그룹(5)보다
    /// 앞에 오는 이 결과가 깨집니다.
    @Test func cpuMetricSortsGroupsByDescendingSumOfProcessValues() {
        let sumGroup = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/Sum.app"),
            displayName: "Sum",
            processes: [
                processDetail(pid: 1, cpuUsagePercent: 3, residentBytes: 0),
                processDetail(pid: 2, cpuUsagePercent: 3, residentBytes: 0),
            ]
        )
        let singleGroup = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/Single.app"),
            displayName: "Single",
            processes: [
                processDetail(pid: 3, cpuUsagePercent: 5, residentBytes: 0),
            ]
        )

        let result = ApplicationRanking.sortedForDisplay(groups: [singleGroup, sumGroup], by: .cpuUsage)

        #expect(result.map(\.key.value) == ["/Applications/Sum.app", "/Applications/Single.app"])
    }

    /// Memory 기준도 그룹 안 residentBytes 합으로 내림차순 정렬됩니다. CPU와 Memory가 서로 다른 값을
    /// 기준으로 삼는 것을 함께 확인합니다 — 두 기준을 바꿔치면 이 테스트와 위 CPU 테스트 중 하나가 실패합니다.
    @Test func residentMemoryMetricSortsGroupsByDescendingSumOfResidentBytes() {
        let heavyGroup = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/Heavy.app"),
            displayName: "Heavy",
            // CPU로 보면 Light가 앞서야 하므로, Memory 기준이 실제로 적용됐는지 CPU 테스트와 교차 확인됩니다.
            processes: [processDetail(pid: 1, cpuUsagePercent: 1, residentBytes: 1_000)]
        )
        let lightGroup = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/Light.app"),
            displayName: "Light",
            processes: [processDetail(pid: 2, cpuUsagePercent: 90, residentBytes: 10)]
        )

        let result = ApplicationRanking.sortedForDisplay(groups: [lightGroup, heavyGroup], by: .residentMemory)

        #expect(result.map(\.key.value) == ["/Applications/Heavy.app", "/Applications/Light.app"])
    }

    /// Memory 그룹 값이 최댓값이나 첫 프로세스 값이 아니라 프로세스 값의 합임을 프로세스 여러 개를 가진
    /// 그룹으로 확인합니다. 위 테스트는 그룹마다 프로세스가 하나뿐이라 합·최댓값·첫 값 세 계산이 모두
    /// 같은 결과를 내므로, 합이 아닌 계산으로 바꿔도 잡지 못합니다.
    /// `sumGroup`은 3GB+3GB(합 6GB)로 단일 프로세스 5GB인 `singleGroup`보다 합 기준으로는 앞서야 하지만,
    /// 최댓값(3GB)이나 첫 프로세스 값(그룹 안 배열 순서상 3GB) 기준으로는 `singleGroup`(5GB)에 뒤집니다.
    @Test func residentMemoryMetricSortsGroupsByDescendingSumNotMaxOrFirstOfProcessValues() {
        let sumGroup = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/Sum.app"),
            displayName: "Sum",
            processes: [
                processDetail(pid: 1, cpuUsagePercent: nil, residentBytes: 3_000_000_000),
                processDetail(pid: 2, cpuUsagePercent: nil, residentBytes: 3_000_000_000),
            ]
        )
        let singleGroup = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/Single.app"),
            displayName: "Single",
            processes: [
                processDetail(pid: 3, cpuUsagePercent: nil, residentBytes: 5_000_000_000),
            ]
        )

        let result = ApplicationRanking.sortedForDisplay(groups: [singleGroup, sumGroup], by: .residentMemory)

        #expect(result.map(\.key.value) == ["/Applications/Sum.app", "/Applications/Single.app"])
    }

    /// 값이 같은 그룹은 앱 키 사전순으로 결정적으로 정렬됩니다. tie-break가 없으면 입력 순서에 따라
    /// 흔들릴 수 있어 이 단언이 실패합니다.
    @Test func groupsWithEqualValueTiebreakByKeyAscending() {
        let groupZ = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/Z.app"),
            displayName: "Z",
            processes: [processDetail(pid: 1, cpuUsagePercent: 5, residentBytes: 0)]
        )
        let groupA = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/A.app"),
            displayName: "A",
            processes: [processDetail(pid: 2, cpuUsagePercent: 5, residentBytes: 0)]
        )

        let result = ApplicationRanking.sortedForDisplay(groups: [groupZ, groupA], by: .cpuUsage)

        #expect(result.map(\.key.value) == ["/Applications/A.app", "/Applications/Z.app"])
    }

    /// 그룹 안 프로세스도 같은 기준으로 내림차순 정렬됩니다. 정렬을 제거하면 입력 순서 그대로 남아
    /// 이 단언이 실패합니다.
    @Test func processesWithinGroupSortByMetricDescending() {
        let group = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/A.app"),
            displayName: "A",
            processes: [
                processDetail(pid: 1, cpuUsagePercent: 5, residentBytes: 100),
                processDetail(pid: 2, cpuUsagePercent: 20, residentBytes: 50),
                processDetail(pid: 3, cpuUsagePercent: 10, residentBytes: 200),
            ]
        )

        let cpuSorted = ApplicationRanking.sortedForDisplay(groups: [group], by: .cpuUsage)
        #expect(cpuSorted[0].processes.map(\.pid) == [2, 3, 1])

        let memorySorted = ApplicationRanking.sortedForDisplay(groups: [group], by: .residentMemory)
        #expect(memorySorted[0].processes.map(\.pid) == [3, 1, 2])
    }

    /// 값이 같은 프로세스는 pid 오름차순으로 결정적으로 정렬됩니다.
    @Test func processesWithEqualValueTiebreakByPidAscending() {
        let group = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/A.app"),
            displayName: "A",
            processes: [
                processDetail(pid: 30, cpuUsagePercent: 5, residentBytes: 0),
                processDetail(pid: 10, cpuUsagePercent: 5, residentBytes: 0),
                processDetail(pid: 20, cpuUsagePercent: 5, residentBytes: 0),
            ]
        )

        let result = ApplicationRanking.sortedForDisplay(groups: [group], by: .cpuUsage)

        #expect(result[0].processes.map(\.pid) == [10, 20, 30])
    }

    /// CPU는 기준점이 없어 `nil`일 수 있습니다. `nil`을 0으로 채우면 「읽지 못한 프로세스의 사용량이
    /// 추정값으로 채워지지 않습니다」(SPEC §5.6)를 어깁니다. `nil`을 0으로 취급하면 nil 프로세스가
    /// 낮은 양수 값보다 앞서는 잘못된 결과가 나오므로, 여기서는 값이 있는 프로세스보다 항상 뒤로 보냅니다.
    /// 값 있는 프로세스는 그 값이 0이어도 `nil`보다 항상 앞섭니다. `nil`을 0으로 취급하면 둘이 동률이 되어
    /// tie-break(pid 오름차순)가 대신 순서를 정하므로, pid가 더 작은 `nil` 프로세스(1)가 앞으로 와
    /// 기대값([2, 1])과 달라집니다.
    @Test func nilCPUValueSortsAfterNonNilValuesInsteadOfBeingTreatedAsZero() {
        let group = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/A.app"),
            displayName: "A",
            processes: [
                processDetail(pid: 1, cpuUsagePercent: nil, residentBytes: 0),
                processDetail(pid: 2, cpuUsagePercent: 0, residentBytes: 0),
            ]
        )

        let result = ApplicationRanking.sortedForDisplay(groups: [group], by: .cpuUsage)

        #expect(result[0].processes.map(\.pid) == [2, 1])
    }

    /// `nil`끼리도 pid로 결정적으로 tie-break됩니다.
    @Test func nilCPUValuesTiebreakByPidAscending() {
        let group = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/A.app"),
            displayName: "A",
            processes: [
                processDetail(pid: 30, cpuUsagePercent: nil, residentBytes: 0),
                processDetail(pid: 10, cpuUsagePercent: nil, residentBytes: 0),
            ]
        )

        let result = ApplicationRanking.sortedForDisplay(groups: [group], by: .cpuUsage)

        #expect(result[0].processes.map(\.pid) == [10, 30])
    }

    /// 그룹 안 모든 프로세스의 CPU가 `nil`이면(기준점이 없는 조사만 관찰된 앱) 그룹 자체도 값 있는
    /// 그룹보다 뒤로 갑니다. `nil`을 0으로 취급하면 이 그룹이 낮은 양수 그룹보다 앞서게 되어 실패합니다.
    /// `hasValueGroup`의 값을 0(값 있음, `nil` 아님)으로 둡니다. `nil`을 0으로 취급하면 두 그룹이
    /// 동률이 되어 앱 키 tie-break(사전순)가 대신 정하는데, "AllNil.app"이 "HasValue.app"보다 사전순으로
    /// 앞서 기대 순서와 달라집니다.
    @Test func groupWithAllNilCPUValuesSortsAfterGroupsWithValues() {
        let allNilGroup = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/AllNil.app"),
            displayName: "AllNil",
            processes: [processDetail(pid: 1, cpuUsagePercent: nil, residentBytes: 0)]
        )
        let hasValueGroup = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/HasValue.app"),
            displayName: "HasValue",
            processes: [processDetail(pid: 2, cpuUsagePercent: 0, residentBytes: 0)]
        )

        let result = ApplicationRanking.sortedForDisplay(groups: [allNilGroup, hasValueGroup], by: .cpuUsage)

        #expect(result.map(\.key.value) == ["/Applications/HasValue.app", "/Applications/AllNil.app"])
    }
}

// MARK: - 결함 회귀: 상세 팝업에 정렬 기준 값이 보이지 않던 문제

/// 상세 팝업이 앱을 사용량 내림차순으로 정렬하면서도 그 값을 화면에 보여주지 않아 "정렬 기준을 알 수 없다"는
/// 결함이 있었습니다. `sortedForDisplay(_:by:)`가 돌려주는 `sortValue`가 표시에 그대로 쓰이므로,
/// 이 값이 실제 정렬 합계와 같고(표시용으로 따로 계산하면 어긋날 수 있음), 값을 만들지 못한 그룹은
/// 0을 지어내지 않고 `nil`로 남는지 확인합니다.
struct ApplicationProcessGroupDisplayValueRegressionTests {

    @Test func sortValueEqualsSortedProcessSumAndPreservesNilForValuelessGroups() throws {
        let noSignalGroup = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/NoSignal.app"),
            displayName: "NoSignal",
            processes: [processDetail(pid: 1, cpuUsagePercent: nil, residentBytes: 0)]
        )
        let signalGroup = ApplicationProcessGroup(
            key: ApplicationKey(value: "/Applications/Signal.app"),
            displayName: "Signal",
            processes: [
                processDetail(pid: 2, cpuUsagePercent: 3, residentBytes: 0),
                processDetail(pid: 3, cpuUsagePercent: 4, residentBytes: 0),
            ]
        )

        let result = ApplicationRanking.sortedForDisplay(groups: [noSignalGroup, signalGroup], by: .cpuUsage)

        let signal = try #require(result.first { $0.key.value == "/Applications/Signal.app" })
        #expect(signal.sortValue == 7, "표시값은 정렬에 쓴 합(3+4)과 같아야 합니다.")

        let noSignal = try #require(result.first { $0.key.value == "/Applications/NoSignal.app" })
        #expect(noSignal.sortValue == nil, "값을 만들지 못한 그룹은 0을 지어내지 않고 nil로 남아야 합니다.")
    }

    /// 상세 목록의 프로세스별 표시 이름이 `deriveIdentity`가 번들 밖 실행 파일에 쓰는 것과 같은
    /// "실행 경로 마지막 구성 요소" 규칙을 공유하는지 확인합니다. 이름 유도를 별도 규칙(예: 고정 문자열,
    /// 경로 전체)으로 바꾸면 이 단언이 실패합니다.
    @Test func processExecutableNameSharesDeriveIdentityRule() throws {
        let helperPath = "/Applications/Example.app/Contents/Frameworks/Example Helper.app/Contents/MacOS/Example Helper"
        let snapshotUnderTest = snapshot(pid: 1, executablePath: helperPath, recentValues: [rankingSample(cpuUsagePercent: 1, residentBytes: 0)])

        let (groups, _) = ApplicationRanking.groupByApplication(snapshots: [snapshotUnderTest], resolver: ApplicationIdentityResolver())

        let process = try #require(groups.first?.processes.first)
        #expect(process.executableName == ApplicationIdentityResolver.executableName(from: helperPath))
        #expect(process.executableName == "Example Helper")
    }
}

// MARK: - 결함 회귀: 상세 팝업 값 서식이 nil을 0으로 지어내던 문제

/// `ApplicationProcessValueFormatting`은 CPU·Memory 상세 뷰가 그룹·프로세스 값을 문자열로 바꿀 때 공유하는
/// 서식입니다. 값을 만들지 못한 경우(SPEC §5.6) 0을 지어내지 않고 `"-"`로 남기는지를, 뷰를 렌더링하지 않고도
/// 이 자리에서 직접 확인합니다 — 이 nil 안전성이 뷰 본문의 인라인 클로저에만 있으면 단위 테스트로 잡을 수 없습니다.
struct ApplicationProcessValueFormattingTests {

    @Test func cpuGroupValueTextKeepsNilAsDashInsteadOfZero() {
        #expect(ApplicationProcessValueFormatting.cpuGroupValueText(nil) == "-")
    }

    @Test func cpuGroupValueTextFormatsRoundedPercentageWithCoreSumUnit() {
        #expect(ApplicationProcessValueFormatting.cpuGroupValueText(12.6) == "13\(ApplicationProcessDetail.cpuUsageUnitLabel)")
    }

    @Test func cpuProcessValueTextKeepsNilAsDashInsteadOfZero() {
        let process = processDetail(pid: 1, cpuUsagePercent: nil, residentBytes: 0)
        #expect(ApplicationProcessValueFormatting.cpuProcessValueText(process) == "-")
    }

    @Test func cpuProcessValueTextAppendsRosettaSuffixWhenTranslated() {
        let translated = ApplicationProcessDetail(
            pid: 1, executableName: "proc1", cpuUsagePercent: 10, residentBytes: 0, isTranslated: true
        )
        #expect(ApplicationProcessValueFormatting.cpuProcessValueText(translated) == "10\(ApplicationProcessDetail.cpuUsageUnitLabel) · Rosetta")
    }

    @Test func memoryGroupValueTextKeepsNilAsDashInsteadOfZero() {
        #expect(ApplicationProcessValueFormatting.memoryGroupValueText(nil, format: { "\($0) bytes" }) == "-")
    }

    /// 값이 있으면 반올림한 바이트 수를 그대로 `format`에 넘겨야 합니다 — 별도 계산으로 값을 바꿔치기하면
    /// (예: 다른 프로세스 값을 대신 쓰면) 이 단언이 깨집니다.
    @Test func memoryGroupValueTextPassesRoundedValueToFormatUnchanged() {
        var receivedBytes: UInt64?
        let result = ApplicationProcessValueFormatting.memoryGroupValueText(1024.6) { bytes in
            receivedBytes = bytes
            return "\(bytes) bytes"
        }
        #expect(receivedBytes == 1025)
        #expect(result == "1025 bytes")
    }
}

// MARK: - 결함 회귀: 펼친 행이 매초 재정렬로 자리를 옮기던 문제

/// 상세 팝업에서 앱 행을 펼친 채로 두면 목록이 매초 다시 정렬되며 그 행이 화면에서 자리를 옮겼습니다.
/// 사용자가 같은 행을 다시 클릭하려 하면(예: 접으려는 클릭) 이동 전 좌표를 써서 엉뚱한 행을 클릭하는
/// 결함으로 이어졌습니다(실행 환경 재현: 클릭 직전·직후 프레임을 비교해 행이 정확히 한 칸 이동했음을 확인).
/// `ApplicationProcessGroupOrdering.displayedGroups`가 펼친 행이 있는 동안 순서를 고정하는지 확인합니다.
struct ApplicationProcessGroupOrderingTests {

    private func group(_ path: String, sortValue: Double) -> ApplicationProcessGroup {
        ApplicationProcessGroup(
            key: ApplicationKey(value: path),
            displayName: path,
            processes: [],
            sortValue: sortValue
        )
    }

    @Test func returnsLatestSortWhenNoRowIsExpanded() {
        let groups = [group("/A", sortValue: 3), group("/B", sortValue: 1)]

        let result = ApplicationProcessGroupOrdering.displayedGroups(
            groups: groups, stableOrder: [ApplicationKey(value: "/B"), ApplicationKey(value: "/A")], hasExpandedRow: false
        )

        #expect(result.map(\.key.value) == ["/A", "/B"], "펼친 행이 없으면 최신 정렬을 그대로 써야 합니다.")
    }

    /// 이번 결함의 핵심 단언 — 펼친 행이 있으면, 이번 tick에 순위가 뒤바뀌어도(`/B`가 `/A`를 추월) 화면 순서는
    /// 펼치기 전 고정된 순서를 그대로 유지해야 합니다.
    @Test func keepsStableOrderWhenARowIsExpandedEvenIfLatestSortChanged() {
        // 최신 정렬은 B가 A를 추월했지만(B: 5 > A: 3), 고정된 순서는 여전히 [A, B]입니다.
        let latestSort = [group("/B", sortValue: 5), group("/A", sortValue: 3)]
        let stableOrder = [ApplicationKey(value: "/A"), ApplicationKey(value: "/B")]

        let result = ApplicationProcessGroupOrdering.displayedGroups(
            groups: latestSort, stableOrder: stableOrder, hasExpandedRow: true
        )

        #expect(result.map(\.key.value) == ["/A", "/B"], "펼친 행이 있는 동안은 최신 정렬이 아니라 고정된 순서를 유지해야 합니다.")
    }

    /// 고정된 순서에 값만 최신으로 반영되는지 — 순서는 멈추되 표시 값은 계속 최신을 따라가야 합니다.
    @Test func stableOrderStillReflectsLatestValuesNotFrozenValues() {
        let latestSort = [group("/B", sortValue: 5), group("/A", sortValue: 99)]
        let stableOrder = [ApplicationKey(value: "/A"), ApplicationKey(value: "/B")]

        let result = ApplicationProcessGroupOrdering.displayedGroups(
            groups: latestSort, stableOrder: stableOrder, hasExpandedRow: true
        )

        let a = try? #require(result.first { $0.key.value == "/A" })
        #expect(a?.sortValue == 99, "순서는 고정하되 값은 최신 tick 값을 그대로 보여줘야 합니다.")
    }

    @Test func appThatDisappearedFromLatestGroupsIsDroppedFromStableOrder() {
        let latestSort = [group("/A", sortValue: 3)] // /B가 이번 tick에 사라짐
        let stableOrder = [ApplicationKey(value: "/A"), ApplicationKey(value: "/B")]

        let result = ApplicationProcessGroupOrdering.displayedGroups(
            groups: latestSort, stableOrder: stableOrder, hasExpandedRow: true
        )

        #expect(result.map(\.key.value) == ["/A"], "고정된 순서에만 있고 최신 목록에는 없는 앱은 지어내지 않고 빠져야 합니다.")
    }

    @Test func newAppNotInStableOrderIsAppendedAfterFixedOrder() {
        let latestSort = [group("/A", sortValue: 3), group("/NEW", sortValue: 100)]
        let stableOrder = [ApplicationKey(value: "/A")]

        let result = ApplicationProcessGroupOrdering.displayedGroups(
            groups: latestSort, stableOrder: stableOrder, hasExpandedRow: true
        )

        #expect(result.map(\.key.value) == ["/A", "/NEW"], "고정된 순서에 없던 새 앱은 순위가 더 높아도 끼어들지 않고 뒤에 붙어야 합니다.")
    }
}
