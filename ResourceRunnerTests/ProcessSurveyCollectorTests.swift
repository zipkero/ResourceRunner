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
/// pid별 호출 횟수를 세어 uid 사전 판별과 경로 캐시가 실제로 시스템 호출을 건너뛰는지 확인합니다.
private final class StubProcessSurveyReader: ProcessSurveying, @unchecked Sendable {
    static let missingTaskInfoFailure = CollectorFailure(metric: .process, cause: .systemCall(name: "stub.taskInfo", code: -1))
    static let missingPathFailure = CollectorFailure(metric: .process, cause: .systemCall(name: "stub.executablePath", code: -1))
    static let exhaustedListFailure = CollectorFailure(metric: .process, cause: .systemCall(name: "stub.listProcesses", code: -1))

    private let lock = NSLock()
    private var listOutcomes: [Result<[ProcessListEntry], CollectorFailure>]
    private var taskInfoOutcomes: [pid_t: Result<ProcessTaskInfo, CollectorFailure>]
    private var pathOutcomes: [pid_t: Result<String, CollectorFailure>]
    private var observedTaskInfoCalls: [pid_t] = []
    private var observedPathCalls: [pid_t] = []

    init(
        listOutcomes: [Result<[ProcessListEntry], CollectorFailure>],
        taskInfoOutcomes: [pid_t: Result<ProcessTaskInfo, CollectorFailure>] = [:],
        pathOutcomes: [pid_t: Result<String, CollectorFailure>] = [:]
    ) {
        self.listOutcomes = listOutcomes
        self.taskInfoOutcomes = taskInfoOutcomes
        self.pathOutcomes = pathOutcomes
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
        let outcome = pathOutcomes[pid]
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
    uid: uid_t,
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

// MARK: - uid 사전 판별과 읽지 못한 프로세스

/// task-004 검증 조건: uid가 다른 프로세스는 목록에서 빠지고 `proc_pidinfo`가 호출되지 않으며,
/// 실패한 프로세스의 값이 추정값으로 채워지지 않고, 결과 목록과 읽지 못한 수의 합이 전체 열거 수와 같습니다.
struct ProcessSurveyCollectorTests {

    @Test func nonMatchingUIDProcessesAreExcludedWithoutTaskInfoCall() throws {
        let currentUID = getuid()
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
        // uid가 다른 200·300에는 proc_pidinfo가 한 번도 호출되지 않습니다.
        #expect(reader.taskInfoCallCount == 1)
        #expect(reader.taskInfoCallCount(for: 200) == 0)
        #expect(reader.taskInfoCallCount(for: 300) == 0)
    }

    /// 이 단언이 고정하는 것은 "읽지 못한 프로세스를 값으로 채우지 않는다"입니다.
    /// proc_pidinfo가 실패한 프로세스는 0이나 다른 값으로 채워지지 않고 목록에서 통째로 빠집니다.
    @Test func taskInfoFailureExcludesProcessWithoutFillingValues() throws {
        let currentUID = getuid()
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
        let currentUID = getuid()
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
        let currentUID = getuid()
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
        let currentUID = getuid()
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

// MARK: - 정체성별 경로 캐시

/// task-004 검증 조건: 이미 경로를 읽은 정체성에는 `proc_pidpath`가 다시 호출되지 않습니다.
struct ProcessSurveyPathCacheTests {

    @Test func pathIsReadOnlyOnceForSameIdentityAcrossSurveys() throws {
        let currentUID = getuid()
        let listedEntry = entry(pid: 100, uid: currentUID)
        let reader = StubProcessSurveyReader(
            listOutcomes: [.success([listedEntry]), .success([listedEntry])],
            taskInfoOutcomes: [100: .success(ProcessTaskInfo(cpuTimeNanoseconds: 1, residentBytes: 2))],
            pathOutcomes: [100: .success("/bin/a")]
        )
        var collector = ProcessSurveyCollector(reader: reader)

        _ = try collector.survey()
        let second = try collector.survey()

        #expect(reader.pathCallCount(for: 100) == 1)
        #expect(second.samples.first?.executablePath == "/bin/a")
    }

    /// 정체성이 재조사에서 사라지고 같은 PID가 다른 시작 시각으로 다시 나타나면
    /// 새 정체성이므로 캐시를 재사용하지 않고 경로를 다시 읽습니다.
    @Test func differentStartTimeForSamePIDIsTreatedAsNewIdentityAndReReadsPath() throws {
        let currentUID = getuid()
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

// MARK: - 실제 시스템 호출 경로

/// 실제 `ProcessSurveying` 구현을 감싸 pid별 호출 횟수를 세는 decorator.
/// stub으로 대체하지 않고 실제 시스템 호출 경로를 그대로 태우면서 호출 횟수만 관찰합니다.
private final class CallCountingProcessSurveyReader: ProcessSurveying, @unchecked Sendable {
    private let underlying: ProcessSurveying
    private let lock = NSLock()
    private var taskInfoCallsByPID: [pid_t: Int] = [:]
    private var pathCallsByPID: [pid_t: Int] = [:]
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
        return try underlying.executablePath(pid: pid)
    }
}

/// task-004 검증 조건 중 실기기 확인: macOS 26.5 Apple silicon에서 실제 조사 1회를 수행해
/// uid 사전 판별·경로 캐시·읽지 못한 수를 단언합니다.
/// 이 테스트가 고정하는 것은 "uid 사전 판별을 건너뛰지 않는다"입니다 —
/// uid 판별 없이 모든 프로세스에 `proc_pidinfo`를 호출하도록 되돌리면
/// `taskInfoCallCount`가 uid가 같은 프로세스 수를 넘어서 이 테스트가 실패해야 합니다.
struct ProcessSurveyRealDevicePathTests {

    @Test func realSurveyExcludesOtherUIDsAndCachesOwnPath() throws {
        let decorator = CallCountingProcessSurveyReader(underlying: HostProcessSurveyReader())
        var collector = ProcessSurveyCollector(reader: decorator)

        let survey = try collector.survey()
        let entries = decorator.lastListedEntries
        let currentUID = getuid()
        let matchingUIDCount = entries.filter { $0.uid == currentUID }.count

        // 결과 목록 크기와 읽지 못한 수의 합이 열거된 전체 프로세스 수와 같습니다.
        #expect(survey.samples.count + survey.unreadableCount == entries.count)
        // root를 비롯한 다른 uid 소유 프로세스가 실기기에는 상당수 있어 읽지 못한 수가 0보다 큽니다.
        #expect(survey.unreadableCount > 0)
        // uid가 다른 프로세스에는 proc_pidinfo가 호출되지 않으므로 총 호출 수가 uid가 같은 프로세스 수와 같습니다.
        #expect(decorator.taskInfoCallCount == matchingUIDCount)

        let selfPID = getpid()
        let selfSample = try #require(survey.samples.first { $0.identity.pid == selfPID })
        #expect(selfSample.residentBytes > 0)
        #expect(selfSample.cpuTimeNanoseconds > 0)
        #expect(selfSample.isTranslated == false)
        #expect(decorator.pathCallCount(for: selfPID) == 1)

        // 같은 정체성(자기 프로세스)을 두 번째로 조사해도 proc_pidpath가 다시 호출되지 않습니다.
        _ = try collector.survey()
        #expect(decorator.pathCallCount(for: selfPID) == 1)
    }
}
