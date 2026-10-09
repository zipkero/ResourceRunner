#if DEBUG
import Darwin
import Foundation

/// 고유 UI 앱에서만 사용하는 결정적 조사 입력입니다. 일반 실행은 native reader로 위임합니다.
nonisolated final class UITestProcessSurveyReader: ProcessSurveying, @unchecked Sendable {
    private let native = HostProcessSurveyReader()
    private let usesFixture: Bool
    private let lock = NSLock()
    private var tick: UInt64 = 0

    init(usesFixture: Bool) { self.usesFixture = usesFixture }

    func listProcesses() throws(CollectorFailure) -> [ProcessListEntry] {
        guard usesFixture else { return try native.listProcesses() }
        lock.lock()
        tick += 1
        lock.unlock()
        let uid = geteuid()
        var entries = (0..<55).map { index in
            ProcessListEntry(identity: ProcessIdentity(pid: pid_t(50_000 + index), startTime: 1),
                             uid: uid, parentPID: 1, isTranslated: false)
        }
        // 같은 앱 그룹의 다른 UID 자식과 다른 UID 전용 그룹을 모두 제공합니다.
        entries.append(ProcessListEntry(identity: ProcessIdentity(pid: 60_000, startTime: 1),
                                        uid: uid + 1, parentPID: 50_000, isTranslated: false))
        entries.append(ProcessListEntry(identity: ProcessIdentity(pid: 60_001, startTime: 1),
                                        uid: uid + 1, parentPID: 1, isTranslated: false))
        return entries
    }

    func taskInfo(pid: pid_t) throws(CollectorFailure) -> ProcessTaskInfo {
        guard usesFixture else { return try native.taskInfo(pid: pid) }
        lock.lock()
        let currentTick = tick
        lock.unlock()
        let weight: UInt64 = pid == 60_001 ? 80 : pid == 60_000 ? 60 : UInt64(55 - Int(pid - 50_000))
        return ProcessTaskInfo(cpuTimeNanoseconds: currentTick * weight * 10_000_000,
                               residentBytes: (weight * 10 + currentTick) * 1_048_576)
    }

    func executablePath(pid: pid_t) throws(CollectorFailure) -> String {
        guard usesFixture else { return try native.executablePath(pid: pid) }
        if pid == 60_001 { return "/tmp/RRFixtureOtherOnly.app/Contents/MacOS/other" }
        let index = pid == 60_000 ? 0 : Int(pid - 50_000)
        let child = pid == 60_000 ? "other" : "current"
        return String(format: "/tmp/RRFixtureGroup%02d.app/Contents/MacOS/%@", index, child)
    }
}
#endif
