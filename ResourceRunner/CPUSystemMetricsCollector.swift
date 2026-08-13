//
//  CPUSystemMetricsCollector.swift
//  ResourceRunner
//
//  Created by zipkero on 8/13/26.
//

import Darwin
import Foundation

/// 논리 코어 하나의 누적 tick 원본.
/// 사용률이 아니라 단조 증가하는 원본이므로 두 tick의 차이로만 의미가 생깁니다.
nonisolated struct CPUCoreTicks: Sendable, Equatable {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64

    /// 낮은 우선순위로 실행된 사용자 시간도 사용자 시간으로 세는 Activity Monitor 관례를 따릅니다.
    /// nice를 따로 두면 User·System·Idle의 합이 100%에 미치지 못합니다.
    var userIncludingNice: UInt64 { user &+ nice }
}

/// 코어별 tick 원본과 Load Average를 읽는 시스템 호출 경계.
/// 이 경계를 분리해 두어야 차분 계산을 원본 주입으로 검증할 수 있습니다.
nonisolated protocol CPUTickReading: Sendable {
    /// 한 번의 호출로 논리 코어 전체의 누적 tick을 읽습니다.
    func readCoreTicks() throws(CollectorFailure) -> [CPUCoreTicks]
    func readLoadAverage() throws(CollectorFailure) -> LoadAverage
}

/// production에서 쓰는 `host_processor_info`·`getloadavg` 기반 구현.
nonisolated struct HostCPUTickReader: CPUTickReading {
    func readCoreTicks() throws(CollectorFailure) -> [CPUCoreTicks] {
        var processorCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else {
            throw CollectorFailure(metric: .cpu, cause: .systemCall(name: "host_processor_info", code: result))
        }
        // `host_processor_info`가 할당한 버퍼는 호출자가 해제해야 합니다.
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: UnsafeMutableRawPointer(info))),
                vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            )
        }

        let stateCount = Int(CPU_STATE_MAX)
        return (0..<Int(processorCount)).map { core in
            let base = core * stateCount
            // tick 카운터는 부호 없는 값이지만 `integer_t` 배열로 전달되므로, 상위 비트가 켜진 값이
            // 음수로 읽히지 않도록 비트 패턴을 그대로 옮깁니다.
            func tick(_ state: Int32) -> UInt64 {
                UInt64(UInt32(bitPattern: info[base + Int(state)]))
            }
            return CPUCoreTicks(
                user: tick(CPU_STATE_USER),
                system: tick(CPU_STATE_SYSTEM),
                idle: tick(CPU_STATE_IDLE),
                nice: tick(CPU_STATE_NICE)
            )
        }
    }

    func readLoadAverage() throws(CollectorFailure) -> LoadAverage {
        var loads = [Double](repeating: 0, count: 3)
        let count = getloadavg(&loads, 3)
        guard count == 3 else {
            throw CollectorFailure(metric: .cpu, cause: .systemCall(name: "getloadavg", code: Int32(count)))
        }
        return LoadAverage(oneMinute: loads[0], fiveMinutes: loads[1], fifteenMinutes: loads[2])
    }
}

/// 한 tick의 CPU 시스템 지표를 만드는 계약.
/// 실패는 던지고, 값을 만들 수 없는 tick은 실패가 아니라 `nil`로 구분합니다.
nonisolated protocol CPUSystemMetricsCollecting: Sendable {
    /// 직전 tick 원본과의 차이로 이번 tick의 CPU 지표를 만듭니다.
    /// 직전 원본이 없거나 간격이 허용 범위를 넘으면 값을 만들지 않고 기준점만 갱신한 뒤 `nil`을 돌려줍니다.
    mutating func collect(at timestamp: ContinuousClock.Instant) throws(CollectorFailure) -> CPUSystemMetrics?
}

/// 직전 tick 원본과 그 시각을 소유하고 차분으로 사용률을 만드는 Collector.
/// 상태를 가지므로 값 타입으로 두고 소유자(actor)의 격리 안에서만 변경됩니다.
nonisolated struct CPUSystemMetricsCollector<Reader: CPUTickReading>: CPUSystemMetricsCollecting {
    private let reader: Reader
    private let maximumTickGap: Duration
    private var baseline: (ticks: [CPUCoreTicks], timestamp: ContinuousClock.Instant)?

    init(reader: Reader, maximumTickGap: Duration = SystemMetricsSampling.maximumTickGap) {
        self.reader = reader
        self.maximumTickGap = maximumTickGap
    }

    mutating func collect(at timestamp: ContinuousClock.Instant) throws(CollectorFailure) -> CPUSystemMetrics? {
        let ticks = try reader.readCoreTicks()
        guard !ticks.isEmpty else {
            throw CollectorFailure(
                metric: .cpu,
                cause: .unsupportedValue(name: "host_processor_info.processorCount", rawValue: 0)
            )
        }

        // 값을 만들 수 있는지와 무관하게 이번 원본은 항상 새 기준점이 됩니다.
        let previous = baseline
        baseline = (ticks: ticks, timestamp: timestamp)

        guard let previous else { return nil }

        // 중지·재개나 장시간 지연 구간을 하나의 변화량으로 이어 붙이지 않습니다.
        let elapsed = previous.timestamp.duration(to: timestamp)
        guard elapsed > .zero, elapsed <= maximumTickGap else { return nil }

        // 코어 구성이 바뀌면 직전 원본과 대응시킬 수 없으므로 기준점만 새로 잡습니다.
        guard previous.ticks.count == ticks.count else { return nil }

        var coreUsages: [Double] = []
        coreUsages.reserveCapacity(ticks.count)
        var userDelta: Int64 = 0
        var systemDelta: Int64 = 0
        var idleDelta: Int64 = 0

        for (previousCore, currentCore) in zip(previous.ticks, ticks) {
            let coreUser = Int64(currentCore.userIncludingNice) - Int64(previousCore.userIncludingNice)
            let coreSystem = Int64(currentCore.system) - Int64(previousCore.system)
            let coreIdle = Int64(currentCore.idle) - Int64(previousCore.idle)

            // 카운터가 되감기면 차이가 의미를 잃으므로 이번 tick은 기준점 갱신으로만 끝냅니다.
            guard coreUser >= 0, coreSystem >= 0, coreIdle >= 0 else { return nil }

            let coreTotal = coreUser + coreSystem + coreIdle
            // 이 코어가 한 tick도 진행하지 않았다면 소비한 시간도 없으므로 0%로 봅니다.
            coreUsages.append(coreTotal > 0 ? percentage(of: coreUser + coreSystem, in: coreTotal) : 0)

            userDelta += coreUser
            systemDelta += coreSystem
            idleDelta += coreIdle
        }

        let totalDelta = userDelta + systemDelta + idleDelta
        // 전체 tick이 하나도 진행하지 않은 간격에서는 사용률을 만들 근거가 없습니다.
        guard totalDelta > 0 else { return nil }

        let loadAverage = try reader.readLoadAverage()

        return CPUSystemMetrics(
            overallUsage: percentage(of: userDelta + systemDelta, in: totalDelta),
            userRatio: percentage(of: userDelta, in: totalDelta),
            systemRatio: percentage(of: systemDelta, in: totalDelta),
            idleRatio: percentage(of: idleDelta, in: totalDelta),
            coreUsages: coreUsages,
            loadAverage: loadAverage
        )
    }

    /// 부동소수 오차로 0~100 범위를 벗어나지 않도록 잘라 낸 백분율.
    private func percentage(of part: Int64, in total: Int64) -> Double {
        min(100, max(0, Double(part) / Double(total) * 100))
    }
}
