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
    let uid: uid_t?
    let parentPID: pid_t
    let isTranslated: Bool
}

/// `proc_pidinfo(PROC_PIDTASKINFO)`가 돌려주는 값 중 이 feature가 쓰는 부분만 추린 값.
nonisolated struct ProcessTaskInfo: Sendable, Equatable {
    /// `pti_total_user + pti_total_system`(mach absolute time)을 나노초로 변환한 값.
    let cpuTimeNanoseconds: UInt64
    let residentBytes: UInt64
}

/// 프로세스 조사에 쓰는 시스템 호출 경계.
/// 이 경계를 분리해 두어야 UID별 실제 읽기·매 조사 경로 조회를 원본 주입으로 검증할 수 있습니다.
nonisolated protocol ProcessSurveying: Sendable {
    /// `sysctl(KERN_PROC_ALL)` 한 번으로 전체 프로세스를 열거합니다.
    func listProcesses() throws(CollectorFailure) -> [ProcessListEntry]
    /// 열거된 모든 프로세스에 대해 호출을 시도합니다.
    func taskInfo(pid: pid_t) throws(CollectorFailure) -> ProcessTaskInfo
    /// task-info를 읽은 프로세스마다 매 조사 호출됩니다.
    func executablePath(pid: pid_t) throws(CollectorFailure) -> String
}

/// production에서 쓰는 `sysctl`·`proc_pidinfo`·`proc_pidpath` 기반 구현.
nonisolated struct HostProcessSurveyReader: ProcessSurveying {
    /// `4 * MAXPATHLEN`은 `proc_pidpath`가 요구하는 버퍼 크기입니다.
    /// `PROC_PIDPATHINFO_MAXSIZE` 매크로는 현재 SDK에서 Swift로 그대로 옮겨지지 않아 값을 직접 계산합니다.
    private static let pathBufferSize = 4 * Int(MAXPATHLEN)

    /// `mach_timebase_info`는 부팅 중 바뀌지 않으므로 한 번만 읽어 둡니다.
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        // 실패하면 tick과 나노초가 1:1인 것으로 두어 변환 없이 원값을 쓰게 합니다.
        guard mach_timebase_info(&info) == KERN_SUCCESS, info.numer != 0, info.denom != 0 else {
            return mach_timebase_info_data_t(numer: 1, denom: 1)
        }
        return info
    }()

    /// `proc_taskinfo`의 CPU 시간은 나노초가 아니라 mach absolute time tick이므로 나노초로 변환합니다.
    /// Apple silicon에서는 `numer/denom`이 1이 아니어서(예: 125/3) 변환을 빠뜨리면 사용률이 그 배율만큼 축소됩니다.
    private static func nanoseconds(fromMachTicks ticks: UInt64) -> UInt64 {
        let numer = UInt64(timebase.numer)
        let denom = UInt64(timebase.denom)
        // Intel처럼 tick이 곧 나노초인 기기에서는 변환이 필요 없습니다.
        guard numer != denom else { return ticks }
        // 누적 CPU 시간은 큰 값이 될 수 있어 그대로 곱하면 넘칠 수 있으므로
        // 몫과 나머지로 나눠 곱한 뒤 다시 더합니다.
        let (quotient, remainder) = ticks.quotientAndRemainder(dividingBy: denom)
        return quotient &* numer &+ (remainder &* numer) / denom
    }

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
            cpuTimeNanoseconds: Self.nanoseconds(fromMachTicks: info.pti_total_user &+ info.pti_total_system),
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

/// 한 번의 조사로 읽을 수 있는 프로세스 조사 결과를 만드는 계약.
nonisolated protocol ProcessSurveyCollecting: Sendable {
    mutating func survey() throws(CollectorFailure) -> ProcessSurveyReport
}

/// `ProcessSurveying` 경계를 소유하고 UID별 실제 읽기와 현재 실행 경로 조회를 적용하는 Collector.
nonisolated struct ProcessSurveyCollector<Reader: ProcessSurveying>: ProcessSurveyCollecting {
    private let reader: Reader
    private let effectiveUID: @Sendable () -> uid_t

    init(reader: Reader, effectiveUID: @escaping @Sendable () -> uid_t = { geteuid() }) {
        self.reader = reader
        self.effectiveUID = effectiveUID
    }

    mutating func survey() throws(CollectorFailure) -> ProcessSurveyReport {
        let entries = try reader.listProcesses()
        let currentUID = effectiveUID()

        var samples: [ProcessSample] = []
        samples.reserveCapacity(entries.count)
        var unreadableCount = 0
        var currentUserUnreadableCount = 0

        for entry in entries {
            guard let taskInfo = try? reader.taskInfo(pid: entry.identity.pid) else {
                // 호출이 실패한 프로세스(조사 사이의 종료 등)는 값을 추정해 채우지 않고 읽지 못한 수에 더합니다.
                unreadableCount += 1
                if entry.uid == nil || entry.uid == currentUID { currentUserUnreadableCount += 1 }
                continue
            }

            // 같은 정체성이 exec할 수 있으므로 CPU·메모리를 읽은 tick마다 현재 경로를 확인합니다.
            guard let path = try? reader.executablePath(pid: entry.identity.pid) else {
                unreadableCount += 1
                if entry.uid == nil || entry.uid == currentUID { currentUserUnreadableCount += 1 }
                continue
            }

            samples.append(
                ProcessSample(
                    identity: entry.identity,
                    executablePath: path,
                    uid: entry.uid,
                    parentPID: entry.parentPID,
                    cpuTimeNanoseconds: taskInfo.cpuTimeNanoseconds,
                    residentBytes: taskInfo.residentBytes,
                    isTranslated: entry.isTranslated,
                    ownership: entry.uid.map { $0 == currentUID ? .currentUser : .otherUser } ?? .unknown
                )
            )
        }

        return ProcessSurveyReport(samples: samples, unreadableCount: unreadableCount,
                                   currentUserUnreadableCount: currentUserUnreadableCount)
    }
}
