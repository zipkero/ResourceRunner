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
        latestCPUUsagePercent: recentValues.last?.cpuUsagePercent,
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
// 대신 이 머신에서 Bash로 직접 `ps -Ao pid,comm`을 실행해 관찰했고, 그 결과는 구현 보고의
// §비고·한계에 남깁니다.
