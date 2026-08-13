//
//  SystemMetrics.swift
//  ResourceRunner
//
//  Created by zipkero on 8/13/26.
//

import Foundation

/// 시스템 지표 한 tick의 CPU 값.
/// 비율은 모두 0~100 백분율이고, 코어별 tick 합에서 계산하므로 코어 수와 무관하게 100%를 넘지 않습니다.
/// 코어를 합산해 100%를 넘을 수 있는 프로세스 CPU 사용률과는 단위가 다릅니다.
nonisolated struct CPUSystemMetrics: Sendable, Equatable {
    /// 전체 사용률. `userRatio + systemRatio`와 같고 `100 - idleRatio`입니다.
    let overallUsage: Double
    let userRatio: Double
    let systemRatio: Double
    let idleRatio: Double
    /// 논리 코어별 사용률. 개수는 `host_processor_info`가 보고한 논리 코어 수입니다.
    let coreUsages: [Double]
    let loadAverage: LoadAverage
}

/// `getloadavg`가 돌려주는 1·5·15분 Load Average.
nonisolated struct LoadAverage: Sendable, Equatable {
    let oneMinute: Double
    let fiveMinutes: Double
    let fifteenMinutes: Double
}

/// 시스템 지표 한 tick의 Memory 값. 누적 차이가 필요 없는 순간값입니다.
/// `appBytes`·`wiredBytes`·`compressedBytes`·`cachedBytes`를 `vm_statistics64` 카운터에서 유도하는 식은
/// Apple이 공식 문서로 규정한 관계가 아니므로 Activity Monitor와 절대값이 정확히 같다고 보장하지 않습니다.
nonisolated struct MemorySystemMetrics: Sendable, Equatable {
    let totalPhysicalBytes: UInt64
    /// 현재 사용 중 메모리. App·Wired·Compressed의 합입니다.
    let usedBytes: UInt64
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let cachedBytes: UInt64
    let swapUsedBytes: UInt64
    let pressureLevel: MemoryPressureLevel
}

/// Memory Pressure 3단계의 닫힌 집합.
/// 연속적인 압력 수치를 만들지 않고 문서화된 단계 신호만 그대로 씁니다.
nonisolated enum MemoryPressureLevel: Sendable, Equatable {
    case normal
    case warning
    case critical

    /// `kern.memorystatus_vm_pressure_level`의 원시값 대응.
    /// 값 집합은 `dispatch/source.h`의 `DISPATCH_MEMORYPRESSURE_NORMAL`·`WARN`·`CRITICAL`과 같습니다.
    /// 세 값 밖의 원시값은 해석하지 않고 `nil`을 돌려주어 호출자가 실패로 다루게 합니다.
    init?(rawValue: Int32) {
        switch rawValue {
        case 0x01: self = .normal
        case 0x02: self = .warning
        case 0x04: self = .critical
        default: return nil
        }
    }
}

/// 지표 조회 실패를 값으로 옮길 수 있게 하는 오류 타입.
/// 어느 지표가 어떤 이유로 실패했는지를 구분하며, 실패를 0이나 빈 값으로 바꾸지 않기 위한 표현입니다.
nonisolated struct CollectorFailure: Error, Sendable, Equatable {
    /// 실패한 지표 종류. 카드 단위 실패 격리의 기준입니다.
    nonisolated enum Metric: Sendable, Equatable {
        case cpu
        case memory
    }

    nonisolated enum Cause: Sendable, Equatable {
        /// 시스템 호출이 실패했습니다. `code`는 `kern_return_t` 또는 `errno`입니다.
        case systemCall(name: String, code: Int32)
        /// 시스템 호출은 성공했지만 돌려준 값을 해석할 수 없습니다.
        case unsupportedValue(name: String, rawValue: Int64)
    }

    let metric: Metric
    let cause: Cause
}

/// 한 tick의 시스템 지표 결과. CPU와 Memory를 각각 `Result`로 담아 지표별 실패를 계약 수준에서 격리합니다.
/// 두 지표가 한 값에 묶이므로 카드 사이에 시점 차이가 생기지 않습니다.
nonisolated struct SystemMetricsSample: Sendable, Equatable {
    /// `.success(nil)`은 값을 만들지 않고 기준점만 갱신한 tick입니다.
    /// 첫 tick이거나 직전 tick과의 간격이 `SystemMetricsSampling.maximumTickGap`을 넘은 경우이며,
    /// 조회 실패(`.failure`)와 구분됩니다.
    let cpu: Result<CPUSystemMetrics?, CollectorFailure>
    let memory: Result<MemorySystemMetrics, CollectorFailure>
}

/// 시스템 지표 tick 사이 간격에 대한 판정 기준.
nonisolated enum SystemMetricsSampling {
    /// 직전 tick과의 간격이 이 값을 넘으면 누적 tick을 차분하지 않고 기준점만 갱신합니다.
    /// 이 feature가 시스템 지표에 쓰는 가장 느린 주기(lowPower·팝오버 닫힘 5초)의 두 배이므로,
    /// 정상 주기의 지연은 값을 버리지 않고 중지·재개나 장시간 지연만 걸러집니다.
    static let maximumTickGap: Duration = .seconds(10)
}
