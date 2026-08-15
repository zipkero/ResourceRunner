//
//  SystemMetricsSampleSource.swift
//  ResourceRunner
//
//  Created by zipkero on 8/13/26.
//

import Foundation
import OSLog

#if DEBUG
/// 재개 첫 tick이 사용률을 만들지 않고 기준점만 갱신했는지를 실기기에서 읽기 위한 로그 경계.
/// `Logger` 문자열 보간은 기본이 `.private`이라 명시하지 않으면 값이 가려지고, `.debug` 수준은
/// Console.app 기본 수집 대상이 아니므로 `.notice`와 `privacy: .public`을 씁니다.
enum SystemMetricsSampleSourceDebugLog {
    static let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "SystemMetricsSampleSource")
}
#endif

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

#if DEBUG
    /// 직전 tick의 시각. 기준점만 갱신한 tick에서 경과 시간을 함께 남기기 위한 관찰용 상태이며,
    /// 사용률 계산은 Collector가 가진 기준점으로만 하므로 이 값은 어떤 계산에도 쓰이지 않습니다.
    private var debugPreviousTimestamp: ContinuousClock.Instant?
#endif

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

#if DEBUG
        let previousTimestamp = debugPreviousTimestamp
        debugPreviousTimestamp = timestamp
        // 사용률을 만들지 못한 tick만 남깁니다. 중지에서 돌아온 첫 tick이 여기 해당하고,
        // 그 경과 시간이 허용 간격을 넘었다는 사실까지 한 줄에서 확인할 수 있게 함께 적습니다.
        if case .success(.none) = cpu {
            let elapsed = previousTimestamp.map { String(describing: $0.duration(to: timestamp)) } ?? "none"
            let maximumTickGap = String(describing: SystemMetricsSampling.maximumTickGap)
            // 로그 호출 지연이 이 actor의 임계 구간을 늦추지 않도록 별도 Task로 분리합니다.
            Task.detached(priority: .utility) {
                SystemMetricsSampleSourceDebugLog.logger.notice("baseline-only tick: no cpu usage produced elapsed=\(elapsed, privacy: .public) maximumTickGap=\(maximumTickGap, privacy: .public)")
            }
        }
#endif

        return SystemMetricsSample(cpu: cpu, memory: memory)
    }
}
