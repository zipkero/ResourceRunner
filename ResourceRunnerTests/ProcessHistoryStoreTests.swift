//
//  ProcessHistoryStoreTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/14/26.
//

import Darwin
import Foundation
import Testing
@testable import ResourceRunner

// MARK: - 테스트용 조사 결과 helper

private func processSample(
    pid: pid_t = 100,
    startTime: TimeInterval = 0,
    cpuTimeNanoseconds: UInt64,
    residentBytes: UInt64 = 1_000,
    executablePath: String = "/bin/a",
    uid: uid_t = 501,
    parentPID: pid_t = 1,
    isTranslated: Bool = false
) -> ProcessSample {
    ProcessSample(
        identity: ProcessIdentity(pid: pid, startTime: startTime),
        executablePath: executablePath,
        uid: uid,
        parentPID: parentPID,
        cpuTimeNanoseconds: cpuTimeNanoseconds,
        residentBytes: residentBytes,
        isTranslated: isTranslated
    )
}

private func survey(_ samples: [ProcessSample], unreadableCount: Int = 0) -> ProcessSurveySample {
    ProcessSurveySample(result: .success(ProcessSurveyReport(samples: samples, unreadableCount: unreadableCount)))
}

private func failedSurvey(
    _ cause: CollectorFailure.Cause = .systemCall(name: "sysctl(KERN_PROC_ALL).size", code: EPERM)
) -> ProcessSurveySample {
    ProcessSurveySample(result: .failure(CollectorFailure(metric: .process, cause: cause)))
}

private let baseInstant = ContinuousClock().now

// MARK: - 정체성 경계와 사라진 프로세스 제거

/// task-005 검증 조건: 같은 PID가 다른 시작 시각으로 나타나면 새 정체성이 되어 이전 누적 CPU 시간과
/// 차분되지 않고 첫 조사에서 사용률이 만들어지지 않으며 메모리 기준점도 새로 시작합니다.
/// 이 테스트가 고정하는 것은 "정체성 키에서 시작 시각을 빼면 PID 재사용에서 이력이 섞인다"입니다 —
/// 키를 PID만으로 되돌리면 재사용된 PID가 이전 누적 CPU 시간과 차분되어 이 테스트가 실패해야 합니다.
struct ProcessHistoryIdentityBoundaryTests {

    @Test func firstSurveyOfIdentityProducesNoRateAndSingleMemoryBaseline() async throws {
        let store = ProcessHistoryStore()
        let sample = processSample(cpuTimeNanoseconds: 5_000_000_000, residentBytes: 10_000)

        await store.append(TimestampedSample(timestamp: baseInstant, value: survey([sample])))
        let snapshot = try #require(await store.snapshot().first)

        #expect(snapshot.latestCPUUsagePercent == nil)
        #expect(snapshot.memoryBaselines.count == 1)
        #expect(snapshot.memoryBaselines.first?.residentBytes == 10_000)
    }

    @Test func pidReuseWithDifferentStartTimeDoesNotInheritPreviousCPUBaseline() async throws {
        let store = ProcessHistoryStore()
        let original = processSample(pid: 100, startTime: 1_000, cpuTimeNanoseconds: 50_000_000_000)
        let reused = processSample(pid: 100, startTime: 2_000, cpuTimeNanoseconds: 1_000_000_000)

        await store.append(TimestampedSample(timestamp: baseInstant, value: survey([original])))
        await store.append(TimestampedSample(timestamp: baseInstant.advanced(by: .seconds(1)), value: survey([reused])))

        let snapshot = try #require(await store.snapshot().first)
        // 같은 PID이지만 새 정체성이라 직전(원래 프로세스) 누적 CPU 시간과 차분되지 않고 첫 조사로 취급됩니다.
        #expect(snapshot.identity.startTime == 2_000)
        #expect(snapshot.latestCPUUsagePercent == nil)
        #expect(snapshot.memoryBaselines.count == 1)
        #expect(await store.identityCount == 1)
    }

    @Test func terminatedProcessIsRemovedAfterNextSurveyWithoutAffectingSurvivingIdentity() async {
        let store = ProcessHistoryStore()
        let terminating = processSample(pid: 100, cpuTimeNanoseconds: 1_000_000_000)
        let surviving = processSample(pid: 200, cpuTimeNanoseconds: 1_000_000_000)

        await store.append(TimestampedSample(timestamp: baseInstant, value: survey([terminating, surviving])))
        #expect(await store.identityCount == 2)

        // 다음 조사 결과에 pid 100이 없으므로(프로세스 종료) 그 정체성만 이력에서 바로 제거됩니다.
        await store.append(TimestampedSample(timestamp: baseInstant.advanced(by: .seconds(1)), value: survey([surviving])))

        #expect(await store.identityCount == 1)
        let remainingIdentities = await Set(store.snapshot().map(\.identity))
        #expect(remainingIdentities == [surviving.identity])
    }

    /// 접근 실패로 조사 결과에서 빠진 프로세스도 제거되고, 다시 나타나면 새 기준점부터 시작합니다.
    @Test func processMissingFromASurveyIsRemovedAndRestartsFreshOnReappearance() async throws {
        let store = ProcessHistoryStore()
        let sample = processSample(cpuTimeNanoseconds: 1_000_000_000)

        await store.append(TimestampedSample(timestamp: baseInstant, value: survey([sample])))
        // proc_pidinfo 실패 등으로 이번 조사에는 이 정체성이 빠집니다.
        await store.append(TimestampedSample(timestamp: baseInstant.advanced(by: .seconds(1)), value: survey([], unreadableCount: 1)))
        #expect(await store.identityCount == 0)

        // 다시 나타난 같은 정체성은 이전 기준점을 이어받지 않고 첫 조사로 취급됩니다.
        let reappeared = processSample(cpuTimeNanoseconds: 90_000_000_000)
        await store.append(TimestampedSample(timestamp: baseInstant.advanced(by: .seconds(2)), value: survey([reappeared])))

        let snapshot = try #require(await store.snapshot().first)
        #expect(snapshot.latestCPUUsagePercent == nil)
    }

    /// 실패한 조사는 이력을 전혀 건드리지 않고 실패 사실만 기록합니다.
    ///
    /// 바로 위 테스트가 고정하듯 프로세스가 빠진 **성공** 조사는 이력을 지우는 것이 옳은 동작입니다.
    /// 실패한 조사를 같은 경로로 흘려보내면 관찰된 정체성이 하나도 없는 것으로 읽혀
    /// 조사 한 번 실패에 CPU 기준점과 메모리 기준점이 모두 사라지고, 복구된 뒤에도
    /// 사용률이 다시 나오기까지 조사 두 번을 기다려야 합니다.
    /// `append`의 실패 분기를 빼면 `identityCount`와 복구 직후 사용률 단언이 함께 실패합니다.
    @Test func failedSurveyKeepsHistoryIntactAndOnlyRecordsTheFailure() async throws {
        let store = ProcessHistoryStore()

        await store.append(TimestampedSample(
            timestamp: baseInstant,
            value: survey([processSample(cpuTimeNanoseconds: 0)])
        ))
        await store.append(TimestampedSample(timestamp: baseInstant.advanced(by: .seconds(1)), value: failedSurvey()))

        // 이력이 그대로 남고 실패만 기록됩니다.
        #expect(await store.identityCount == 1)
        #expect(await store.rankingInput().surveyFailed)

        // 기준점이 살아 있으므로 복구된 첫 조사에서 곧바로 사용률이 나옵니다.
        // 실패 시각이 아니라 마지막 성공 조사 시각과의 차이로 계산되어 2초 동안 1초를 쓴 50%입니다.
        await store.append(TimestampedSample(
            timestamp: baseInstant.advanced(by: .seconds(2)),
            value: survey([processSample(cpuTimeNanoseconds: 1_000_000_000)])
        ))

        let input = await store.rankingInput()
        #expect(!input.surveyFailed)
        let snapshot = try #require(input.snapshots.first)
        #expect(snapshot.latestCPUUsagePercent == 50)
    }
}

// MARK: - 코어 합산 CPU 사용률

/// task-005 검증 조건: 누적 CPU 시간 차이를 경과 시간으로 나눈 값이 코어 합산 비율이라
/// 두 코어를 완전히 쓰는 프로세스가 200%로 계산됩니다.
struct ProcessHistoryCPUUsageTests {

    @Test func twoFullyUsedCoresProduce200Percent() async throws {
        let store = ProcessHistoryStore()
        let first = processSample(cpuTimeNanoseconds: 0)
        // 1초 경과 동안 누적 CPU 시간이 2초(2_000_000_000ns)만큼 늘어나 두 코어를 꽉 채운 상황입니다.
        let second = processSample(cpuTimeNanoseconds: 2_000_000_000)

        await store.append(TimestampedSample(timestamp: baseInstant, value: survey([first])))
        await store.append(TimestampedSample(timestamp: baseInstant.advanced(by: .seconds(1)), value: survey([second])))

        let snapshot = try #require(await store.snapshot().first)
        #expect(snapshot.latestCPUUsagePercent == 200)
    }

    /// 직전 조사와의 간격이 허용 범위(`ProcessHistorySampling.maximumTickGap`)를 넘으면
    /// 사용률을 만들지 않고 기준점만 갱신합니다. 중지 구간을 사이에 둔 두 조사가 이 경로를 탑니다.
    @Test func gapExceedingMaximumTickGapProducesNoRateButUpdatesBaseline() async throws {
        let store = ProcessHistoryStore()
        let first = processSample(cpuTimeNanoseconds: 0)
        let afterGap = processSample(cpuTimeNanoseconds: 100_000_000_000)
        let gap = ProcessHistorySampling.maximumTickGap + .seconds(1)

        await store.append(TimestampedSample(timestamp: baseInstant, value: survey([first])))
        await store.append(TimestampedSample(timestamp: baseInstant.advanced(by: gap), value: survey([afterGap])))

        let afterGapSnapshot = try #require(await store.snapshot().first)
        #expect(afterGapSnapshot.latestCPUUsagePercent == nil)

        // 기준점은 그래도 이번 조사 값으로 갱신되었으므로, 그다음 정상 간격 조사에서는 값이 다시 나옵니다.
        let next = processSample(cpuTimeNanoseconds: 100_000_000_000 + 500_000_000)
        await store.append(
            TimestampedSample(timestamp: baseInstant.advanced(by: gap + .seconds(1)), value: survey([next]))
        )
        let finalSnapshot = try #require(await store.snapshot().first)
        #expect(finalSnapshot.latestCPUUsagePercent == 50)
    }
}

// MARK: - 메모리 기준점 링의 주기 독립성

/// task-005 검증 조건: 메모리 기준점 링의 크기는 조사 주기가 2초든 10초든 같고,
/// 최소 간격보다 촘촘한 조사에서는 기준점이 추가되지 않습니다.
struct ProcessHistoryMemoryBaselineRingTests {

    @Test func tightSurveysWithinMinimumIntervalDoNotAddBaseline() async throws {
        let store = ProcessHistoryStore()
        let first = processSample(cpuTimeNanoseconds: 0, residentBytes: 1_000)
        let second = processSample(cpuTimeNanoseconds: 0, residentBytes: 2_000)

        await store.append(TimestampedSample(timestamp: baseInstant, value: survey([first])))
        // 최소 간격(30초)보다 훨씬 촘촘한 2초 뒤 조사이므로 기준점이 추가되지 않습니다.
        await store.append(TimestampedSample(timestamp: baseInstant.advanced(by: .seconds(2)), value: survey([second])))

        let snapshot = try #require(await store.snapshot().first)
        #expect(snapshot.memoryBaselines.count == 1)
        #expect(snapshot.memoryBaselines.first?.residentBytes == 1_000)
    }

    @Test func ringCapacityIsIndependentOfSurveyPeriod() async throws {
        let fastStore = ProcessHistoryStore()
        let slowStore = ProcessHistoryStore()

        // 링을 확실히 가득 채우도록 용량 × 최소 간격의 두 배에 해당하는 시간 동안 조사를 반복합니다.
        let totalDuration = ProcessHistorySampling.minimumMemoryBaselineInterval
            * (2 * ProcessHistorySampling.memoryBaselineRingCapacity)
        let fastPeriod: Duration = .seconds(2)
        let slowPeriod: Duration = .seconds(10)
        let fastTickCount = Int(totalDuration / fastPeriod) + 1
        let slowTickCount = Int(totalDuration / slowPeriod) + 1

        for tick in 0..<fastTickCount {
            let fastTimestamp = baseInstant.advanced(by: fastPeriod * tick)
            await fastStore.append(
                TimestampedSample(timestamp: fastTimestamp, value: survey([processSample(cpuTimeNanoseconds: 0)]))
            )
        }

        for tick in 0..<slowTickCount {
            let slowTimestamp = baseInstant.advanced(by: slowPeriod * tick)
            await slowStore.append(
                TimestampedSample(timestamp: slowTimestamp, value: survey([processSample(cpuTimeNanoseconds: 0)]))
            )
        }

        let fastSnapshot = try #require(await fastStore.snapshot().first)
        let slowSnapshot = try #require(await slowStore.snapshot().first)

        // 두 주기 모두 링이 가득 차 있고, 크기가 조사 주기와 무관하게 같은 고정 용량입니다.
        #expect(fastSnapshot.memoryBaselines.count == ProcessHistorySampling.memoryBaselineRingCapacity)
        #expect(slowSnapshot.memoryBaselines.count == ProcessHistorySampling.memoryBaselineRingCapacity)
    }
}
