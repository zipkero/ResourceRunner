//
//  MemorySystemMetricsCollector.swift
//  ResourceRunner
//
//  Created by zipkero on 8/13/26.
//

import Darwin
import Foundation

/// 한 tick의 Memory 시스템 지표를 만드는 계약.
/// 순간값 조회라 직전 상태가 없고 첫 tick부터 값이 나옵니다.
nonisolated protocol MemorySystemMetricsCollecting: Sendable {
    func collect() throws(CollectorFailure) -> MemorySystemMetrics
}

/// `host_statistics64`·`host_page_size`·`ProcessInfo.physicalMemory`·`sysctl(VM_SWAPUSAGE)`·
/// `kern.memorystatus_vm_pressure_level`을 한 tick에 함께 읽는 Collector.
/// Memory Pressure를 폴링으로 읽는 이유는 다른 Memory 지표와 같은 샘플 시각·같은 수집 일정에 묶기 위해서입니다.
nonisolated struct MemorySystemMetricsCollector: MemorySystemMetricsCollecting {
    func collect() throws(CollectorFailure) -> MemorySystemMetrics {
        let pageSize = try readPageSize()
        let statistics = try readVMStatistics()
        let swapUsedBytes = try readSwapUsedBytes()
        let pressureLevel = try readPressureLevel()

        let wiredBytes = UInt64(statistics.wire_count) * pageSize
        let compressedBytes = UInt64(statistics.compressor_page_count) * pageSize
        let purgeableBytes = UInt64(statistics.purgeable_count) * pageSize
        let internalBytes = UInt64(statistics.internal_page_count) * pageSize
        let externalBytes = UInt64(statistics.external_page_count) * pageSize

        // 익명 페이지에서 언제든 회수 가능한 purgeable을 빼면 App 메모리가 되고,
        // 그 purgeable은 파일 기반 페이지와 함께 Cached Files 쪽에 들어갑니다.
        let appBytes = internalBytes >= purgeableBytes ? internalBytes - purgeableBytes : 0
        let cachedBytes = externalBytes + purgeableBytes

        return MemorySystemMetrics(
            totalPhysicalBytes: ProcessInfo.processInfo.physicalMemory,
            usedBytes: appBytes + wiredBytes + compressedBytes,
            appBytes: appBytes,
            wiredBytes: wiredBytes,
            compressedBytes: compressedBytes,
            cachedBytes: cachedBytes,
            swapUsedBytes: swapUsedBytes,
            pressureLevel: pressureLevel
        )
    }

    private func readPageSize() throws(CollectorFailure) -> UInt64 {
        var pageSize: vm_size_t = 0
        let result = host_page_size(mach_host_self(), &pageSize)
        guard result == KERN_SUCCESS else {
            throw CollectorFailure(metric: .memory, cause: .systemCall(name: "host_page_size", code: result))
        }
        return UInt64(pageSize)
    }

    private func readVMStatistics() throws(CollectorFailure) -> vm_statistics64_data_t {
        var statistics = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            throw CollectorFailure(metric: .memory, cause: .systemCall(name: "host_statistics64", code: result))
        }
        return statistics
    }

    private func readSwapUsedBytes() throws(CollectorFailure) -> UInt64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        var mib: [Int32] = [CTL_VM, VM_SWAPUSAGE]

        let result = sysctl(&mib, u_int(mib.count), &usage, &size, nil, 0)
        guard result == 0 else {
            throw CollectorFailure(metric: .memory, cause: .systemCall(name: "sysctl(VM_SWAPUSAGE)", code: errno))
        }
        return usage.xsu_used
    }

    private func readPressureLevel() throws(CollectorFailure) -> MemoryPressureLevel {
        let name = "kern.memorystatus_vm_pressure_level"
        var rawValue: Int32 = 0
        var size = MemoryLayout<Int32>.stride

        let result = sysctlbyname(name, &rawValue, &size, nil, 0)
        guard result == 0 else {
            throw CollectorFailure(metric: .memory, cause: .systemCall(name: name, code: errno))
        }
        // 해석할 수 없는 원시값을 임의 단계로 표시하지 않고 실패로 다룹니다.
        guard let level = MemoryPressureLevel(rawValue: rawValue) else {
            throw CollectorFailure(metric: .memory, cause: .unsupportedValue(name: name, rawValue: Int64(rawValue)))
        }
        return level
    }
}
