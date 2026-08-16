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

        return Self.metrics(
            from: statistics,
            pageSize: pageSize,
            totalPhysicalBytes: ProcessInfo.processInfo.physicalMemory,
            swapUsedBytes: swapUsedBytes,
            pressureLevel: pressureLevel
        )
    }

    /// 시스템 호출로 읽은 원본에서 Memory 지표를 만드는 순수 계산.
    /// 시스템 호출과 분리해 두어야 유도식을 원본 주입으로 검증할 수 있습니다.
    static func metrics(
        from statistics: vm_statistics64_data_t,
        pageSize: UInt64,
        totalPhysicalBytes: UInt64,
        swapUsedBytes: UInt64,
        pressureLevel: MemoryPressureLevel
    ) -> MemorySystemMetrics {
        let wiredBytes = UInt64(statistics.wire_count) * pageSize
        let compressedBytes = UInt64(statistics.compressor_page_count) * pageSize
        let purgeableBytes = UInt64(statistics.purgeable_count) * pageSize
        let internalBytes = UInt64(statistics.internal_page_count) * pageSize
        let externalBytes = UInt64(statistics.external_page_count) * pageSize
        let freeBytes = UInt64(statistics.free_count) * pageSize
        let speculativeBytes = UInt64(statistics.speculative_count) * pageSize

        // 익명 페이지에서 언제든 회수 가능한 purgeable을 빼면 App 메모리가 되고,
        // 그 purgeable은 파일 기반 페이지와 함께 Cached Files 쪽에 들어갑니다.
        let appBytes = internalBytes >= purgeableBytes ? internalBytes - purgeableBytes : 0
        let cachedBytes = externalBytes + purgeableBytes

        // `사용 중`은 구성 항목의 합이 아니라 "전체에서 당장 내줄 수 있는 메모리를 뺀 나머지"입니다.
        // 당장 내줄 수 있는 쪽은 순수 free(free에는 speculative가 포함되어 있어 먼저 빼냅니다)와
        // 파일 기반 external 페이지이고, 그 밖은 전부 사용 중으로 셉니다.
        //
        // 그래서 이 값은 `appBytes + wiredBytes + compressedBytes`와 일치하지 않으며 그보다 큽니다.
        // 차이는 어느 항목에도 잡히지 않는 커널 영역과 speculative·purgeable을 사용 중으로 세는 반면
        // compressor가 물고 있는 페이지는 이미 internal 쪽에 계상되어 중복되지 않기 때문에 생깁니다.
        // Activity Monitor의 `사용된 메모리`도 같은 식이라 구성 항목의 합과 어긋나는 성질을 그대로 가집니다.
        // 합이 맞지 않는다는 이유로 세 항목의 합으로 되돌리면 표시값이 Activity Monitor보다 작아집니다.
        //
        // `totalPhysicalBytes`만 페이지 카운터가 아닌 `ProcessInfo.physicalMemory`에서 오지만,
        // 물리 메모리 크기가 페이지 크기의 배수라 페이지 단위로 환산해도 같은 값입니다.
        let reclaimableBytes = (freeBytes >= speculativeBytes ? freeBytes - speculativeBytes : 0) + externalBytes
        let usedBytes = totalPhysicalBytes >= reclaimableBytes ? totalPhysicalBytes - reclaimableBytes : 0

        return MemorySystemMetrics(
            totalPhysicalBytes: totalPhysicalBytes,
            usedBytes: usedBytes,
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
