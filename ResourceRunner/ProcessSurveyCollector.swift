//
//  ProcessSurveyCollector.swift
//  ResourceRunner
//
//  Created by zipkero on 8/14/26.
//

import Darwin
import Foundation

/// `sysctl(KERN_PROC_ALL)` 열거에서 얻는, 조사 대상 판별에 필요한 프로세스 한 항목.
nonisolated struct ProcessListEntry: Sendable, Equatable {
    let identity: ProcessIdentity
    let uid: uid_t
    let parentPID: pid_t
    let isTranslated: Bool
}

/// `proc_pidinfo(PROC_PIDTASKINFO)`가 돌려주는 값 중 이 feature가 쓰는 부분만 추린 값.
nonisolated struct ProcessTaskInfo: Sendable, Equatable {
    let cpuTimeNanoseconds: UInt64
    let residentBytes: UInt64
}

/// 프로세스 조사에 쓰는 시스템 호출 경계.
/// 이 경계를 분리해 두어야 uid 사전 판별·경로 캐시 규칙을 원본 주입으로 검증할 수 있습니다.
nonisolated protocol ProcessSurveying: Sendable {
    /// `sysctl(KERN_PROC_ALL)` 한 번으로 전체 프로세스를 열거합니다.
    func listProcesses() throws(CollectorFailure) -> [ProcessListEntry]
    /// 현재 유효 uid와 같은 프로세스에 대해서만 호출됩니다.
    func taskInfo(pid: pid_t) throws(CollectorFailure) -> ProcessTaskInfo
    /// 새로 관찰된 정체성에 대해서만 호출됩니다.
    func executablePath(pid: pid_t) throws(CollectorFailure) -> String
}

/// production에서 쓰는 `sysctl`·`proc_pidinfo`·`proc_pidpath` 기반 구현.
nonisolated struct HostProcessSurveyReader: ProcessSurveying {
    /// `4 * MAXPATHLEN`은 `proc_pidpath`가 요구하는 버퍼 크기입니다.
    /// `PROC_PIDPATHINFO_MAXSIZE` 매크로는 현재 SDK에서 Swift로 그대로 옮겨지지 않아 값을 직접 계산합니다.
    private static let pathBufferSize = 4 * Int(MAXPATHLEN)

    func listProcesses() throws(CollectorFailure) -> [ProcessListEntry] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]

        var size: size_t = 0
        var result = sysctl(&mib, u_int(mib.count), nil, &size, nil, 0)
        guard result == 0 else {
            throw CollectorFailure(metric: .process, cause: .systemCall(name: "sysctl(KERN_PROC_ALL).size", code: errno))
        }

        // 크기를 얻은 뒤 실제로 읽는 사이에 프로세스가 늘어날 수 있으므로 여유를 두고,
        // 그래도 모자라면(ENOMEM) 여유를 키워 다시 읽습니다.
        var count = size / MemoryLayout<kinfo_proc>.stride
        var buffer: [kinfo_proc] = []
        repeat {
            count += 16
            size = count * MemoryLayout<kinfo_proc>.stride
            buffer = [kinfo_proc](repeating: kinfo_proc(), count: count)
            result = sysctl(&mib, u_int(mib.count), &buffer, &size, nil, 0)
        } while result != 0 && errno == ENOMEM

        guard result == 0 else {
            throw CollectorFailure(metric: .process, cause: .systemCall(name: "sysctl(KERN_PROC_ALL)", code: errno))
        }

        let actualCount = size / MemoryLayout<kinfo_proc>.stride
        return (0..<actualCount).map { index in
            let entry = buffer[index]
            let startTime = entry.kp_proc.p_un.__p_starttime
            return ProcessListEntry(
                identity: ProcessIdentity(
                    pid: entry.kp_proc.p_pid,
                    startTime: TimeInterval(startTime.tv_sec) + TimeInterval(startTime.tv_usec) / 1_000_000
                ),
                uid: entry.kp_eproc.e_ucred.cr_uid,
                parentPID: entry.kp_eproc.e_ppid,
                isTranslated: (entry.kp_proc.p_flag & P_TRANSLATED) != 0
            )
        }
    }

    func taskInfo(pid: pid_t) throws(CollectorFailure) -> ProcessTaskInfo {
        var info = proc_taskinfo()
        let size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(MemoryLayout<proc_taskinfo>.size))
        guard size == Int32(MemoryLayout<proc_taskinfo>.size) else {
            throw CollectorFailure(metric: .process, cause: .systemCall(name: "proc_pidinfo(PROC_PIDTASKINFO)", code: errno))
        }
        return ProcessTaskInfo(
            cpuTimeNanoseconds: info.pti_total_user &+ info.pti_total_system,
            residentBytes: info.pti_resident_size
        )
    }

    func executablePath(pid: pid_t) throws(CollectorFailure) -> String {
        var buffer = [CChar](repeating: 0, count: Self.pathBufferSize)
        let length = proc_pidpath(pid, &buffer, UInt32(Self.pathBufferSize))
        guard length > 0 else {
            throw CollectorFailure(metric: .process, cause: .systemCall(name: "proc_pidpath", code: errno))
        }
        return String(cString: buffer)
    }
}

/// 한 번의 조사로 사용자 소유 프로세스 조사 결과를 만드는 계약.
nonisolated protocol ProcessSurveyCollecting: Sendable {
    mutating func survey() throws(CollectorFailure) -> ProcessSurveySample
}

/// `ProcessSurveying` 경계를 소유하고 uid 사전 판별과 경로 캐시 규칙을 적용하는 Collector.
/// 정체성별 실행 경로 캐시를 상태로 가지므로 값 타입으로 두고 소유자의 격리 안에서만 변경됩니다.
nonisolated struct ProcessSurveyCollector<Reader: ProcessSurveying>: ProcessSurveyCollecting {
    private let reader: Reader
    /// 정체성마다 `proc_pidpath`를 한 번만 호출하기 위한 실행 경로 캐시.
    private var pathCache: [ProcessIdentity: String] = [:]

    init(reader: Reader) {
        self.reader = reader
    }

    mutating func survey() throws(CollectorFailure) -> ProcessSurveySample {
        let entries = try reader.listProcesses()
        let currentUID = getuid()

        var samples: [ProcessSample] = []
        samples.reserveCapacity(entries.count)
        var unreadableCount = 0
        var observedIdentities: Set<ProcessIdentity> = []

        for entry in entries {
            // uid가 다른 프로세스는 proc_pidinfo를 호출하지 않고 곧바로 읽지 못한 수에 더합니다.
            guard entry.uid == currentUID else {
                unreadableCount += 1
                continue
            }

            guard let taskInfo = try? reader.taskInfo(pid: entry.identity.pid) else {
                // 호출이 실패한 프로세스(조사 사이의 종료 등)는 값을 추정해 채우지 않고 읽지 못한 수에 더합니다.
                unreadableCount += 1
                continue
            }

            let path: String
            if let cached = pathCache[entry.identity] {
                path = cached
            } else if let resolved = try? reader.executablePath(pid: entry.identity.pid) {
                pathCache[entry.identity] = resolved
                path = resolved
            } else {
                unreadableCount += 1
                continue
            }

            observedIdentities.insert(entry.identity)
            samples.append(
                ProcessSample(
                    identity: entry.identity,
                    executablePath: path,
                    uid: entry.uid,
                    parentPID: entry.parentPID,
                    cpuTimeNanoseconds: taskInfo.cpuTimeNanoseconds,
                    residentBytes: taskInfo.residentBytes,
                    isTranslated: entry.isTranslated
                )
            )
        }

        // 이번 조사에서 관찰되지 않은 정체성은 이미 사라진 프로세스이므로 경로 캐시에서도 지웁니다.
        pathCache = pathCache.filter { observedIdentities.contains($0.key) }

        return ProcessSurveySample(samples: samples, unreadableCount: unreadableCount)
    }
}
