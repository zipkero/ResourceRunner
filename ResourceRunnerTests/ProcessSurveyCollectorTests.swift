//
//  ProcessSurveyCollectorTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/14/26.
//

import Darwin
import Foundation
import Testing
@testable import ResourceRunner

// MARK: - 테스트용 프로세스 조사 원본 공급자

/// 미리 준비한 원본을 돌려주는 `ProcessSurveying`.
/// pid별 호출 횟수를 세어 UID별 조회 시도와 매 조사 경로 조회를 확인합니다.
private final class StubProcessSurveyReader: ProcessSurveying, @unchecked Sendable {
    static let missingTaskInfoFailure = CollectorFailure(metric: .process, cause: .systemCall(name: "stub.taskInfo", code: -1))
    static let missingPathFailure = CollectorFailure(metric: .process, cause: .systemCall(name: "stub.executablePath", code: -1))
    static let exhaustedListFailure = CollectorFailure(metric: .process, cause: .systemCall(name: "stub.listProcesses", code: -1))

    private let lock = NSLock()
    private var listOutcomes: [Result<[ProcessListEntry], CollectorFailure>]
    private var taskInfoOutcomes: [pid_t: Result<ProcessTaskInfo, CollectorFailure>]
    private var pathOutcomes: [pid_t: Result<String, CollectorFailure>]
    private var pathOutcomeSequences: [pid_t: [Result<String, CollectorFailure>]]
    private var observedTaskInfoCalls: [pid_t] = []
    private var observedPathCalls: [pid_t] = []

    init(
        listOutcomes: [Result<[ProcessListEntry], CollectorFailure>],
        taskInfoOutcomes: [pid_t: Result<ProcessTaskInfo, CollectorFailure>] = [:],
        pathOutcomes: [pid_t: Result<String, CollectorFailure>] = [:],
        pathOutcomeSequences: [pid_t: [Result<String, CollectorFailure>]] = [:]
    ) {
        self.listOutcomes = listOutcomes
        self.taskInfoOutcomes = taskInfoOutcomes
        self.pathOutcomes = pathOutcomes
        self.pathOutcomeSequences = pathOutcomeSequences
    }

    var taskInfoCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return observedTaskInfoCalls.count
    }

    func taskInfoCallCount(for pid: pid_t) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return observedTaskInfoCalls.filter { $0 == pid }.count
    }

    func pathCallCount(for pid: pid_t) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return observedPathCalls.filter { $0 == pid }.count
    }

    func listProcesses() throws(CollectorFailure) -> [ProcessListEntry] {
        lock.lock()
        let outcome = listOutcomes.isEmpty ? nil : listOutcomes.removeFirst()
        lock.unlock()

        switch outcome {
        case .success(let entries): return entries
        case .failure(let failure): throw failure
        case nil: throw Self.exhaustedListFailure
        }
    }

    func taskInfo(pid: pid_t) throws(CollectorFailure) -> ProcessTaskInfo {
        lock.lock()
        observedTaskInfoCalls.append(pid)
        let outcome = taskInfoOutcomes[pid]
        lock.unlock()

        switch outcome {
        case .success(let info): return info
        case .failure(let failure): throw failure
        case nil: throw Self.missingTaskInfoFailure
        }
    }

    func executablePath(pid: pid_t) throws(CollectorFailure) -> String {
        lock.lock()
        observedPathCalls.append(pid)
        let outcome: Result<String, CollectorFailure>?
        if var sequence = pathOutcomeSequences[pid] {
            outcome = sequence.isEmpty ? nil : sequence.removeFirst()
            pathOutcomeSequences[pid] = sequence
        } else {
            outcome = pathOutcomes[pid]
        }
        lock.unlock()

        switch outcome {
        case .success(let path): return path
        case .failure(let failure): throw failure
        case nil: throw Self.missingPathFailure
        }
    }
}

/// 프로세스 목록 항목 하나를 짧게 만들기 위한 helper.
private func entry(
    pid: pid_t,
    startTime: TimeInterval = 0,
    uid: uid_t?,
    parentPID: pid_t = 1,
    isTranslated: Bool = false
) -> ProcessListEntry {
    ProcessListEntry(
        identity: ProcessIdentity(pid: pid, startTime: startTime),
        uid: uid,
        parentPID: parentPID,
        isTranslated: isTranslated
    )
}

// MARK: - UID별 실제 읽기와 읽지 못한 프로세스

/// UID에 관계없이 실제 읽기를 시도하고 소속과 실패를 구분합니다.
struct ProcessSurveyCollectorTests {

    @Test func currentOtherAndMissingUIDFailuresStayInTheirDisplayScopes() async throws {
        let currentUID = geteuid()
        let otherUID = currentUID + 1
        let entries = [
            entry(pid: 101, uid: currentUID),
            entry(pid: 102, uid: currentUID),
            entry(pid: 201, uid: otherUID),
            entry(pid: 202, uid: otherUID),
            entry(pid: 301, uid: nil),
        ]
        let reader = StubProcessSurveyReader(listOutcomes: [.success(entries)],
            taskInfoOutcomes: [
                101: .success(ProcessTaskInfo(cpuTimeNanoseconds: 0, residentBytes: 100)),
                201: .success(ProcessTaskInfo(cpuTimeNanoseconds: 0, residentBytes: 200)),
            ],
            pathOutcomes: [101: .success("/System/Library/CoreServices/Finder.app/bin/Finder"),
                           201: .success("/Applications/Other.app/bin/Other")])
        var collector = ProcessSurveyCollector(reader: reader, effectiveUID: { currentUID })
        let report = try collector.survey()
        #expect(report.samples.map(\.identity.pid) == [101, 201])
        #expect(report.unreadableCount == 3)
        // 현재 UID 실패와 UID 자체를 알 수 없는 실패는 기본에 남고, 알려진 다른 UID 실패만 빠집니다.
        #expect(report.currentUserUnreadableCount == 2)
        let history = ProcessHistoryStore()
        let now = ContinuousClock().now
        await history.append(TimestampedSample(timestamp: now,
            value: ProcessSurveySample(result: .success(report))))
        let input = await history.rankingInput()
        let variants = ApplicationRanking.materials(snapshots: input.snapshots,
            currentTimestamp: now, unreadableCount: input.unreadableCount,
            currentUserUnreadableCount: input.currentUserUnreadableCount,
            resolver: ApplicationIdentityResolver()).materials
        #expect(variants.currentUser.ranking.unreadableCount == 2)
        #expect(variants.allReadable.ranking.unreadableCount == 3)
        #expect(variants.currentUser.excludedCount == 1)
        #expect(variants.currentUser.ranking.memoryUsage.map(\.displayName) == ["Finder"])
        #expect(variants.allReadable.ranking.memoryUsage.map(\.displayName) == ["Other", "Finder"])
    }

    @Test func effectiveUIDLabelsReadableProcessesWhenRealUIDDiffers() throws {
        let realUID = getuid()
        let effectiveUID = realUID + 1
        let entries = [
            entry(pid: 100, uid: realUID),
            entry(pid: 200, uid: effectiveUID),
        ]
        let reader = StubProcessSurveyReader(
            listOutcomes: [.success(entries)],
            taskInfoOutcomes: [
                100: .success(ProcessTaskInfo(cpuTimeNanoseconds: 1, residentBytes: 2)),
                200: .success(ProcessTaskInfo(cpuTimeNanoseconds: 3, residentBytes: 4)),
            ],
            pathOutcomes: [100: .success("/bin/real"), 200: .success("/bin/effective")]
        )
        var collector = ProcessSurveyCollector(reader: reader, effectiveUID: { effectiveUID })

        let survey = try collector.survey()

        #expect(survey.samples.map(\.identity.pid) == [100, 200])
        #expect(survey.samples.map(\.ownership) == [.otherUser, .currentUser])
        #expect(survey.unreadableCount == 0)
        #expect(reader.taskInfoCallCount(for: 100) == 1)
        #expect(reader.taskInfoCallCount(for: 200) == 1)
        #expect(reader.pathCallCount(for: 100) == 1)
        #expect(reader.pathCallCount(for: 200) == 1)
    }

    @Test func nonMatchingUIDReadFailuresAreCountedWithoutInventingValues() throws {
        let currentUID = geteuid()
        let otherUID = currentUID + 1
        let entries = [
            entry(pid: 100, uid: currentUID),
            entry(pid: 200, uid: otherUID),
            entry(pid: 300, uid: otherUID),
        ]
        let reader = StubProcessSurveyReader(
            listOutcomes: [.success(entries)],
            taskInfoOutcomes: [100: .success(ProcessTaskInfo(cpuTimeNanoseconds: 10, residentBytes: 20))],
            pathOutcomes: [100: .success("/bin/self")]
        )
        var collector = ProcessSurveyCollector(reader: reader)

        let survey = try collector.survey()

        #expect(survey.samples.map(\.identity.pid) == [100])
        #expect(survey.unreadableCount == 2)
        #expect(reader.taskInfoCallCount == 3)
        #expect(reader.taskInfoCallCount(for: 200) == 1)
        #expect(reader.taskInfoCallCount(for: 300) == 1)
    }

    /// 이 단언이 고정하는 것은 "읽지 못한 프로세스를 값으로 채우지 않는다"입니다.
    /// proc_pidinfo가 실패한 프로세스는 0이나 다른 값으로 채워지지 않고 목록에서 통째로 빠집니다.
    @Test func taskInfoFailureExcludesProcessWithoutFillingValues() throws {
        let currentUID = geteuid()
        let entries = [entry(pid: 100, uid: currentUID), entry(pid: 101, uid: currentUID)]
        let reader = StubProcessSurveyReader(
            listOutcomes: [.success(entries)],
            taskInfoOutcomes: [101: .success(ProcessTaskInfo(cpuTimeNanoseconds: 5, residentBytes: 6))],
            pathOutcomes: [101: .success("/bin/b")]
        )
        var collector = ProcessSurveyCollector(reader: reader)

        let survey = try collector.survey()

        #expect(survey.samples.map(\.identity.pid) == [101])
        #expect(survey.unreadableCount == 1)
    }

    @Test func executablePathFailureExcludesProcess() throws {
        let currentUID = geteuid()
        let entries = [entry(pid: 100, uid: currentUID)]
        let reader = StubProcessSurveyReader(
            listOutcomes: [.success(entries)],
            taskInfoOutcomes: [100: .success(ProcessTaskInfo(cpuTimeNanoseconds: 1, residentBytes: 1))],
            pathOutcomes: [:]
        )
        var collector = ProcessSurveyCollector(reader: reader)

        let survey = try collector.survey()

        #expect(survey.samples.isEmpty)
        #expect(survey.unreadableCount == 1)
    }

    @Test func sampleCountPlusUnreadableCountEqualsListedEntries() throws {
        let currentUID = geteuid()
        let entries = [
            entry(pid: 1, uid: currentUID),
            entry(pid: 2, uid: currentUID + 1),
            entry(pid: 3, uid: currentUID),
        ]
        let reader = StubProcessSurveyReader(
            listOutcomes: [.success(entries)],
            taskInfoOutcomes: [
                1: .success(ProcessTaskInfo(cpuTimeNanoseconds: 1, residentBytes: 1)),
                3: .success(ProcessTaskInfo(cpuTimeNanoseconds: 2, residentBytes: 2)),
            ],
            pathOutcomes: [1: .success("/a"), 3: .success("/c")]
        )
        var collector = ProcessSurveyCollector(reader: reader)

        let survey = try collector.survey()

        #expect(survey.samples.count + survey.unreadableCount == entries.count)
    }

    /// Rosetta 실행 여부는 열거 단계에서 이미 얻은 `P_TRANSLATED` 값을 그대로 옮길 뿐,
    /// 별도 시스템 호출을 거치지 않습니다.
    @Test func translatedFlagPassesThroughFromListing() throws {
        let currentUID = geteuid()
        let entries = [entry(pid: 1, uid: currentUID, isTranslated: true)]
        let reader = StubProcessSurveyReader(
            listOutcomes: [.success(entries)],
            taskInfoOutcomes: [1: .success(ProcessTaskInfo(cpuTimeNanoseconds: 1, residentBytes: 1))],
            pathOutcomes: [1: .success("/a")]
        )
        var collector = ProcessSurveyCollector(reader: reader)

        let survey = try collector.survey()

        #expect(survey.samples.first?.isTranslated == true)
    }

    @Test func listProcessesFailureIsThrown() throws {
        let failure = CollectorFailure(metric: .process, cause: .systemCall(name: "sysctl", code: 5))
        let reader = StubProcessSurveyReader(listOutcomes: [.failure(failure)])
        var collector = ProcessSurveyCollector(reader: reader)

        #expect(throws: failure) {
            _ = try collector.survey()
        }
    }
}

// MARK: - 매 조사 실행 경로

/// task-004 검증 조건: 같은 정체성이 exec해도 현재 경로를 읽고 조회 실패 시 이전 값을 재사용하지 않습니다.
struct ProcessSurveyPathRefreshTests {

    @Test func sameIdentityReadsChangedPathOnNextSurvey() throws {
        let currentUID = geteuid()
        let listedEntry = entry(pid: 100, uid: currentUID)
        let reader = StubProcessSurveyReader(
            listOutcomes: [.success([listedEntry]), .success([listedEntry])],
            taskInfoOutcomes: [100: .success(ProcessTaskInfo(cpuTimeNanoseconds: 1, residentBytes: 2))],
            pathOutcomeSequences: [100: [.success("/bin/a"), .success("/bin/b")]]
        )
        var collector = ProcessSurveyCollector(reader: reader)

        _ = try collector.survey()
        let second = try collector.survey()

        #expect(reader.pathCallCount(for: 100) == 2)
        #expect(second.samples.first?.executablePath == "/bin/b")
        #expect(second.unreadableCount == 0)
    }

    @Test func secondPathFailureDoesNotReusePreviousPath() throws {
        let listedEntry = entry(pid: 100, uid: geteuid())
        let reader = StubProcessSurveyReader(
            listOutcomes: [.success([listedEntry]), .success([listedEntry])],
            taskInfoOutcomes: [100: .success(ProcessTaskInfo(cpuTimeNanoseconds: 1, residentBytes: 2))],
            pathOutcomeSequences: [100: [.success("/bin/a"), .failure(StubProcessSurveyReader.missingPathFailure)]]
        )
        var collector = ProcessSurveyCollector(reader: reader)

        let first = try collector.survey()
        let second = try collector.survey()

        #expect(first.samples.first?.executablePath == "/bin/a")
        #expect(second.samples.isEmpty)
        #expect(second.unreadableCount == 1)
        #expect(reader.pathCallCount(for: 100) == 2)
    }

    /// 정체성이 재조사에서 사라지고 같은 PID가 다른 시작 시각으로 다시 나타나면
    /// 새 정체성도 현재 실행 경로를 읽습니다.
    @Test func differentStartTimeForSamePIDIsTreatedAsNewIdentityAndReReadsPath() throws {
        let currentUID = geteuid()
        let first = entry(pid: 100, startTime: 1_000, uid: currentUID)
        let reused = entry(pid: 100, startTime: 2_000, uid: currentUID)
        let reader = StubProcessSurveyReader(
            listOutcomes: [.success([first]), .success([reused])],
            taskInfoOutcomes: [100: .success(ProcessTaskInfo(cpuTimeNanoseconds: 1, residentBytes: 2))],
            pathOutcomes: [100: .success("/bin/a")]
        )
        var collector = ProcessSurveyCollector(reader: reader)

        _ = try collector.survey()
        _ = try collector.survey()

        #expect(reader.pathCallCount(for: 100) == 2)
    }
}

// MARK: - 조사 실패의 값 전달

/// 열거 자체가 실패한 tick을 던지지 않고 샘플 값으로 전달합니다.
///
/// 이 경계가 중요한 이유는 `MonitoringScheduler`가 source 예외에서 tick을 통째로 건너뛰기 때문입니다.
/// 던지면 sink에 아무것도 도착하지 않아 실패가 저장소와 표시 계층에 닿을 통로가 없습니다.
struct ProcessSurveySampleSourceTests {

    @Test func enumerationFailureIsReturnedAsAFailedSampleInsteadOfThrowing() async {
        let currentUID = geteuid()
        let reader = StubProcessSurveyReader(
            listOutcomes: [.failure(StubProcessSurveyReader.exhaustedListFailure), .success([entry(pid: 100, uid: currentUID)])],
            taskInfoOutcomes: [100: .success(ProcessTaskInfo(cpuTimeNanoseconds: 1, residentBytes: 2))],
            pathOutcomes: [100: .success("/bin/a")]
        )
        let source = ProcessSurveySampleSource(collector: ProcessSurveyCollector(reader: reader))

        let failed = await source.sample(collectionEpoch: 7)
        #expect(failed?.result == .failure(StubProcessSurveyReader.exhaustedListFailure))

        // 실패한 조사가 source의 상태를 망가뜨리지 않고 다음 조사가 정상 결과를 돌려줍니다.
        let recovered = await source.sample(collectionEpoch: 8)
        guard case .success(let report) = recovered?.result else {
            Issue.record("복구된 조사가 성공 샘플을 돌려주지 않았습니다.")
            return
        }
        #expect(report.samples.map(\.identity.pid) == [100])
    }
}

// MARK: - 실제 시스템 호출 경로

/// 실제 `ProcessSurveying` 구현을 감싸 pid별 호출 횟수를 세는 decorator.
/// stub으로 대체하지 않고 실제 시스템 호출 경로를 그대로 태우면서 호출 횟수만 관찰합니다.
private final class CallCountingProcessSurveyReader: ProcessSurveying, @unchecked Sendable {
    private let underlying: ProcessSurveying
    private let lock = NSLock()
    private var taskInfoCallsByPID: [pid_t: Int] = [:]
    private var pathCallsByPID: [pid_t: Int] = [:]
    private var pathFailures = 0
    private(set) var lastListedEntries: [ProcessListEntry] = []

    init(underlying: ProcessSurveying) {
        self.underlying = underlying
    }

    var taskInfoCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return taskInfoCallsByPID.values.reduce(0, +)
    }

    func pathCallCount(for pid: pid_t) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return pathCallsByPID[pid, default: 0]
    }

    var pathCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pathCallsByPID.values.reduce(0, +)
    }

    var pathFailureCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pathFailures
    }

    func listProcesses() throws(CollectorFailure) -> [ProcessListEntry] {
        let entries = try underlying.listProcesses()
        lock.lock()
        lastListedEntries = entries
        lock.unlock()
        return entries
    }

    func taskInfo(pid: pid_t) throws(CollectorFailure) -> ProcessTaskInfo {
        lock.lock()
        taskInfoCallsByPID[pid, default: 0] += 1
        lock.unlock()
        return try underlying.taskInfo(pid: pid)
    }

    func executablePath(pid: pid_t) throws(CollectorFailure) -> String {
        lock.lock()
        pathCallsByPID[pid, default: 0] += 1
        lock.unlock()
        do {
            return try underlying.executablePath(pid: pid)
        } catch {
            lock.lock()
            pathFailures += 1
            lock.unlock()
            throw error
        }
    }
}

/// task-004 검증 조건 중 실기기 확인: 실제 조사 두 번으로
/// uid 사전 판별·매 조사 경로 조회·읽지 못한 수를 단언합니다.
/// 이 테스트가 고정하는 것은 "uid 사전 판별을 건너뛰지 않는다"입니다 —
/// uid 판별 없이 모든 프로세스에 `proc_pidinfo`를 호출하도록 되돌리면
/// `taskInfoCallCount`가 uid가 같은 프로세스 수를 넘어서 이 테스트가 실패해야 합니다.
struct ProcessSurveyRealDevicePathTests {

    @Test func realSurveyAttemptsEveryUIDAndRefreshesOwnPath() throws {
        let decorator = CallCountingProcessSurveyReader(underlying: HostProcessSurveyReader())
        var collector = ProcessSurveyCollector(reader: decorator)

        let clock = ContinuousClock()
        let firstStart = clock.now
        let survey = try collector.survey()
        let firstElapsed = firstStart.duration(to: clock.now)
        let entries = decorator.lastListedEntries
        let currentUID = geteuid()
        let matchingUIDCount = entries.filter { $0.uid == currentUID }.count

        // 결과 목록 크기와 읽지 못한 수의 합이 열거된 전체 프로세스 수와 같습니다.
        #expect(survey.samples.count + survey.unreadableCount == entries.count)
        // 다른 UID에도 조회를 시도하지만 읽기에 실패할 수 있습니다.
        #expect(decorator.taskInfoCallCount == entries.count)
        #expect(survey.samples.filter { $0.ownership == .currentUser }.count <= matchingUIDCount)

        let selfPID = getpid()
        let selfSample = try #require(survey.samples.first { $0.identity.pid == selfPID })
        #expect(selfSample.residentBytes > 0)
        #expect(selfSample.cpuTimeNanoseconds > 0)
        #expect(selfSample.isTranslated == false)
        #expect(decorator.pathCallCount(for: selfPID) == 1)

        // 같은 정체성도 다음 조사에서 현재 경로를 다시 읽습니다.
        let secondStart = clock.now
        let secondSurvey = try collector.survey()
        let secondElapsed = secondStart.duration(to: clock.now)
        #expect(decorator.pathCallCount(for: selfPID) == 2)
        #expect(secondSurvey.samples.contains { $0.identity.pid == selfPID })
        print("ProcessSurvey DP20: first=\(firstElapsed), second=\(secondElapsed), pathCalls=\(decorator.pathCallCount), pathFailures=\(decorator.pathFailureCount), unreadable=\(survey.unreadableCount)/\(secondSurvey.unreadableCount)")
    }

    /// 이 테스트가 고정하는 것은 "`cpuTimeNanoseconds`가 실제 나노초 단위다"입니다 —
    /// 자기 프로세스에서 한 스레드를 계속 태우면 두 조사 사이 누적 CPU 시간 증가가 벽시계 경과와 같은 자릿수여야 합니다.
    /// `proc_pidinfo`의 mach absolute time을 변환 없이 그대로 쓰도록 되돌리면
    /// Apple silicon에서 증가량이 벽시계 경과의 1/41 수준으로 줄어 이 테스트가 실패해야 합니다.
    @Test func realSurveyReportsCPUTimeInNanoseconds() throws {
        var collector = ProcessSurveyCollector(reader: HostProcessSurveyReader())
        let selfPID = getpid()
        let clock = ContinuousClock()

        let before = try #require(try collector.survey().samples.first { $0.identity.pid == selfPID })
        let start = clock.now
        burnCPUOnCurrentThread(for: .milliseconds(500))
        let elapsed = start.duration(to: clock.now)
        let after = try #require(try collector.survey().samples.first { $0.identity.pid == selfPID })

        let elapsedNanoseconds = Double(elapsed.components.seconds) * 1e9 + Double(elapsed.components.attoseconds) / 1e9
        #expect(after.cpuTimeNanoseconds > before.cpuTimeNanoseconds)
        let cpuDeltaNanoseconds = Double(after.cpuTimeNanoseconds - before.cpuTimeNanoseconds)

        // 한 스레드를 온전히 태웠으므로 증가량은 벽시계 경과에 가깝습니다.
        // 다른 스레드의 활동과 스케줄링 지연을 감안해 범위를 넉넉히 두되,
        // 41배 어긋난 단위는 어느 쪽으로 틀리든 이 범위 밖으로 벗어납니다.
        #expect(cpuDeltaNanoseconds >= elapsedNanoseconds * 0.5)
        #expect(cpuDeltaNanoseconds <= elapsedNanoseconds * 8)
    }
}

/// 현재 스레드를 주어진 시간 동안 쉬지 않고 돌려 CPU 시간을 소비합니다.
/// 계산 결과를 밖으로 흘려보내 최적화로 반복이 통째로 사라지는 것을 막습니다.
private func burnCPUOnCurrentThread(for duration: Duration) {
    let clock = ContinuousClock()
    let deadline = clock.now + duration
    var accumulator: UInt64 = 1
    while clock.now < deadline {
        for _ in 0..<20_000 {
            accumulator = accumulator &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        }
    }
    cpuBurnSink = accumulator
}

/// `burnCPUOnCurrentThread(for:)`의 계산 결과를 받아 두는 자리. 값 자체는 쓰이지 않습니다.
private nonisolated(unsafe) var cpuBurnSink: UInt64 = 0
