//
//  ProcessSurvey.swift
//  ResourceRunner
//
//  Created by zipkero on 8/14/26.
//

import Darwin
import Foundation

/// 프로세스 하나를 고유하게 식별하는 키.
/// PID만 쓰면 재사용된 PID가 이전 이력을 이어받으므로, 시작 시각을 함께 묶어 이력·경로 캐시의 유일한 키로 삼습니다.
nonisolated struct ProcessIdentity: Sendable, Equatable, Hashable {
    let pid: pid_t
    /// `kinfo_proc.kp_proc.p_un.__p_starttime`에서 얻은 프로세스 시작 시각.
    let startTime: TimeInterval
}

/// 사용자 소유 프로세스 한 개의 조사 결과.
nonisolated struct ProcessSample: Sendable, Equatable {
    let identity: ProcessIdentity
    let executablePath: String
    let uid: uid_t
    let parentPID: pid_t
    /// 누적 User+System CPU 시간(나노초).
    /// `proc_pidinfo(PROC_PIDTASKINFO)`의 원값은 mach absolute time이라 조사 경계에서 나노초로 변환된 값입니다.
    let cpuTimeNanoseconds: UInt64
    /// Physical Footprint를 쓸 수 없어 대신 쓰는 Resident Memory(바이트).
    let residentBytes: UInt64
    /// `P_TRANSLATED` 플래그로 판정한 Rosetta 실행 여부.
    /// 프로세스 열거 단계에서 이미 얻은 값이라 추가 시스템 호출 없이 채워집니다.
    let isTranslated: Bool
}

/// 한 번의 조사 결과 전체.
/// 읽지 못한 프로세스는 목록에 담기지 않고 개수로만 남아, 사용량이 추정값으로 채워지는 일이 없습니다.
nonisolated struct ProcessSurveySample: Sendable, Equatable {
    let samples: [ProcessSample]
    let unreadableCount: Int
}
