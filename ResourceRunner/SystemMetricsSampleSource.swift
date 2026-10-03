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
nonisolated enum SystemMetricsSampleSourceDebugLog {
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
    private let admission: CollectionAdmission?
    private var lastProcessedCollectionEpoch: Int?

#if DEBUG
    /// 직전 tick의 시각. 기준점만 갱신한 tick에서 경과 시간을 함께 남기기 위한 관찰용 상태이며,
    /// 사용률 계산은 Collector가 가진 기준점으로만 하므로 이 값은 어떤 계산에도 쓰이지 않습니다.
    private var debugPreviousTimestamp: ContinuousClock.Instant?
#endif

    init(cpuCollector: CPUCollector, memoryCollector: MemoryCollector, clock: Clock,
         admission: CollectionAdmission? = nil) {
        self.cpuCollector = cpuCollector
        self.memoryCollector = memoryCollector
        self.clock = clock
        self.admission = admission
    }

    /// 두 Collector를 한 번의 시각 읽기 아래에서 차례로 호출해 지표별 성공·실패를 담은 샘플 하나를 만듭니다.
    /// 시각을 지표마다 따로 읽지 않으므로 두 지표가 같은 시각을 공유합니다.
    func sample() async -> SystemMetricsSample {
        // Scheduler의 epoch 전달이 배선되기 전 기존 호출 경로를 유지합니다.
        // 시각 조회 중 epoch가 전진하면 지난 호출은 폐기되므로 현재 epoch로 다시 시도합니다.
        while true {
            if let sample = await sample(collectionEpoch: lastProcessedCollectionEpoch ?? 0) { return sample }
        }
    }

    /// 새 수집 구간의 첫 tick은 CPU 기준점만 잡습니다. native 조회는 복사한 Collector에서
    /// 실행하고 현재 token을 확인한 뒤에만 그 기준점을 소유 상태로 반영합니다.
    func sample(collectionEpoch: Int) async -> SystemMetricsSample? {
        await sample(collectionEpoch: collectionEpoch, context: nil)
    }

    func sample(context: CollectionRunContext) async -> SystemMetricsSample? {
        await sample(collectionEpoch: context.epoch, context: context)
    }

    private func sample(collectionEpoch: Int, context: CollectionRunContext?) async -> SystemMetricsSample? {
        guard collectionEpoch >= (lastProcessedCollectionEpoch ?? collectionEpoch) else { return nil }
        if let context, admission?.isCurrent(context) != true { return nil }
        let timestamp = await clock.now()
#if DEBUG
        let debugPreviousCollectionEpoch = lastProcessedCollectionEpoch
#endif
        guard collectionEpoch >= (lastProcessedCollectionEpoch ?? collectionEpoch) else { return nil }
        if let context, admission?.isCurrent(context) != true { return nil }
        var candidate = cpuCollector
        if let lastProcessedCollectionEpoch, collectionEpoch > lastProcessedCollectionEpoch {
            candidate.resetBaseline()
        }

        let cpu: Result<CPUSystemMetrics?, CollectorFailure>
        do {
            cpu = .success(try candidate.collect(at: timestamp,
                maximumTickGap: SystemMetricsSampling.maximumTickGap(for: context?.interval ?? .seconds(1))))
        } catch {
            cpu = .failure(error)
        }

        let memory: Result<MemorySystemMetrics, CollectorFailure>
        do {
            memory = .success(try memoryCollector.collect())
        } catch {
            memory = .failure(error)
        }

        if let context, let admission {
            guard admission.admit(context, phase: .source, timestamp: timestamp, {
                cpuCollector = candidate
                lastProcessedCollectionEpoch = collectionEpoch
                return true
            }) == true else { return nil }
        } else {
            cpuCollector = candidate
            lastProcessedCollectionEpoch = collectionEpoch
        }

#if DEBUG
        let previousTimestamp = debugPreviousTimestamp
        debugPreviousTimestamp = timestamp
        // 기준점 전용 tick의 원인이 새 epoch인지 시각 간격인지 구분해 남깁니다.
        if case .success(.none) = cpu {
            let elapsed = previousTimestamp.map { String(describing: $0.duration(to: timestamp)) } ?? "none"
            let maximumTickGap = String(describing: SystemMetricsSampling.maximumTickGap(for: context?.interval ?? .seconds(1)))
            let epochReset = debugPreviousCollectionEpoch.map { collectionEpoch > $0 } ?? false
            // 로그 호출 지연이 이 actor의 임계 구간을 늦추지 않도록 별도 Task로 분리합니다.
            Task.detached(priority: .utility) {
                SystemMetricsSampleSourceDebugLog.logger.notice("baseline-only tick: no cpu usage produced collectionEpoch=\(collectionEpoch, privacy: .public) epochReset=\(epochReset, privacy: .public) elapsed=\(elapsed, privacy: .public) maximumTickGap=\(maximumTickGap, privacy: .public)")
            }
        }
#endif

        return SystemMetricsSample(cpu: cpu, memory: memory)
    }
}
