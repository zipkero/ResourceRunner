//
//  SystemMetricsSampleSource.swift
//  ResourceRunner
//
//  Created by zipkero on 8/13/26.
//

import Foundation

/// CPU·Memory Collector를 함께 소유하고 한 tick의 결과를 샘플 하나로 묶는 `ScheduledSampleSource`.
/// 직전 tick 원본을 가진 CPU Collector를 소유하므로 actor로 두고 `MonitoringScheduler`가 `await`로 호출합니다.
///
/// 지표 하나의 조회 실패는 던지지 않고 샘플 안의 `.failure`로 전달합니다.
/// 던지면 `MonitoringScheduler`가 그 tick 전체를 버려 다른 지표의 성공값까지 함께 사라지기 때문입니다.
actor SystemMetricsSampleSource<
    CPUCollector: CPUSystemMetricsCollecting,
    MemoryCollector: MemorySystemMetricsCollecting,
    Clock: MonotonicClock
>: ScheduledSampleSource {
    private var cpuCollector: CPUCollector
    private let memoryCollector: MemoryCollector
    private let clock: Clock

    init(cpuCollector: CPUCollector, memoryCollector: MemoryCollector, clock: Clock) {
        self.cpuCollector = cpuCollector
        self.memoryCollector = memoryCollector
        self.clock = clock
    }

    /// 두 Collector를 한 번의 시각 읽기 아래에서 차례로 호출해 지표별 성공·실패를 담은 샘플 하나를 만듭니다.
    /// 시각을 지표마다 따로 읽지 않으므로 두 지표가 같은 시각을 공유합니다.
    func sample() async -> SystemMetricsSample {
        let timestamp = await clock.now()

        let cpu: Result<CPUSystemMetrics?, CollectorFailure>
        do {
            cpu = .success(try cpuCollector.collect(at: timestamp))
        } catch {
            cpu = .failure(error)
        }

        let memory: Result<MemorySystemMetrics, CollectorFailure>
        do {
            memory = .success(try memoryCollector.collect())
        } catch {
            memory = .failure(error)
        }

        return SystemMetricsSample(cpu: cpu, memory: memory)
    }
}
