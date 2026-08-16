//
//  MonitoringScheduler.swift
//  ResourceRunner
//
//  Created by zipkero on 8/10/26.
//

import Foundation
import OSLog

/// production과 수동 테스트 시계를 바꿔 끼우는 시간 계약.
/// `MonitoringScheduler`는 이 계약만으로 deadline을 전진시키고 잠들며, 실제 시각 종류(`ContinuousClock.Instant`)는
/// `MonitoringSampleStore`의 `TimestampedSample.timestamp`와 그대로 맞춰 별도 변환이 필요 없게 합니다.
nonisolated protocol MonotonicClock: Sendable {
    func now() async -> ContinuousClock.Instant
    func sleep(until deadline: ContinuousClock.Instant) async throws
}

/// production에서 쓰는 실제 단조 증가 시계.
struct SystemMonotonicClock: MonotonicClock {
    private let clock = ContinuousClock()

    func now() async -> ContinuousClock.Instant {
        clock.now
    }

    func sleep(until deadline: ContinuousClock.Instant) async throws {
        try await clock.sleep(until: deadline)
    }
}

/// 한 tick의 샘플을 비동기로 반환하고 취소를 따르는 계약.
/// 공급자 실패(`throw`)는 `MonitoringScheduler`가 0 샘플로 바꾸지 않고 다음 실행으로 넘어갑니다.
nonisolated protocol ScheduledSampleSource: Sendable {
    associatedtype Value: Sendable
    func sample() async throws -> Value
}

/// 수집한 샘플을 받는 저장 대상 계약.
/// `MonitoringScheduler`가 저장 대상을 구체 타입 대신 이 계약으로 받으므로,
/// 수집 축마다 서로 다른 자료 구조를 가진 저장소를 붙일 수 있습니다.
nonisolated protocol MonitoringSampleSink: Sendable {
    associatedtype Value: Sendable
    func append(_ sample: TimestampedSample<Value>) async
}

#if DEBUG
/// `MonitoringScheduler`가 제네릭 actor라 정적 저장 속성을 직접 가질 수 없으므로,
/// 관찰 수단(적용된 일정 전이·generation·누적 샘플 수·버퍼 용량)을 여기 분리해 둡니다.
/// 실기기에서 실제 잠금·해제에 따른 수집 중지와 재개를 확인할 때도 그대로 씁니다.
/// `Logger` 문자열 보간은 기본이 `.private`이라 명시하지 않으면 값이 가려지고, `.debug` 수준은
/// Console.app 기본 수집 대상이 아니므로 `.notice`와 `privacy: .public`을 씁니다.
enum MonitoringSchedulerDebugLog {
    static let logger = Logger(subsystem: "com.zipkero.ResourceRunner", category: "MonitoringScheduler")
}
#endif

/// 적용 일정, 단일 Task와 generation별 실행을 직렬화하는 actor.
/// 일정, 취소와 generation만 소유하고 이력 보관은 `MonitoringSampleSink` 구현에만 맡깁니다.
/// `apply(_:)` 호출마다 기존 작업을 취소하고 새 generation 하나만 시작하며,
/// interval은 마지막 실행 완료 시점이 아니라 기준 deadline을 전진시켜 계산합니다.
actor MonitoringScheduler<
    Clock: MonotonicClock,
    Source: ScheduledSampleSource,
    Sink: MonitoringSampleSink
>: CollectionScheduleTarget where Sink.Value == Source.Value {
    private let clock: Clock
    private let source: Source
    private let sink: Sink

    private var task: Task<Void, Never>?

    /// `apply(_:)`가 새 작업을 시작할 때만 전진하는 세대 번호.
    /// `appendIfCurrentGeneration`이 이전 세대의 실행 결과를 걸러내는 근거이며,
    /// `Task.isCancelled` 검사와 별개로 남겨 두는 방어선이라 테스트에서 직접 관찰할 수 있게 노출합니다.
    private(set) var generation = 0

    /// `MonitoringLifecycleStore`가 계산 결과가 바뀔 때만 호출하는지, 즉 같은 일정 반복에도
    /// `apply(_:)`가 다시 불리지 않는지를 테스트에서 직접 세기 위한 진단용 카운터입니다.
    private(set) var applyCallCount = 0

#if DEBUG
    /// 두 수집 축이 같은 category로 로그를 남기므로 어느 축의 전이·누적인지 구분하기 위한 이름.
    /// 축마다 `Source` 타입이 다르다는 사실만 이용하므로 production 초기화 경로에 인자가 늘지 않습니다.
    private nonisolated var debugAxisLabel: String {
        String(String(describing: Source.self).prefix { $0 != "<" })
    }

    /// 실기기 중지·재개 관찰용 누적 저장 샘플 수.
    /// 일정이 다시 적용돼도 되돌리지 않으므로 중지 구간에서 값이 늘지 않는지를 그대로 읽을 수 있습니다.
    private var debugAppendedSampleCount = 0
#endif

    init(clock: Clock, source: Source, sink: Sink) {
        self.clock = clock
        self.source = source
        self.sink = sink
    }

    /// 계산된 일정을 적용합니다.
    /// `paused`는 실행 중인 작업만 취소하고 쌓인 이력을 그대로 둡니다.
    /// `running(interval)`은 새 generation 하나로 시작하며,
    /// 이전 generation의 실행 결과나 취소·공급자 실패는 저장하지 않습니다.
    /// 일정이 바뀌어도 저장 대상의 용량은 건드리지 않습니다 — 주기로 용량을 다시 잡으면
    /// 주기가 느려지는 순간 이미 쌓인 최근 10분 이력의 일부가 사라지기 때문입니다.
    func apply(_ schedule: CollectionSchedule) async {
        applyCallCount += 1

        task?.cancel()
        task = nil
        // generation은 취소와 같은 동기 구간에서 즉시 전진시킵니다. 뒤에 오는 `await clock.now()`
        // 같은 suspension 지점 이후로 미루면, 그 구간에서 이전 세대 작업이 이미 취소 확인을 통과해 두고
        // actor 차례를 기다리던 `appendIfCurrentGeneration` 호출이 끼어들었을 때 아직 갱신 전인
        // generation과 우연히 일치해 이전 세대 결과가 저장될 수 있습니다.
        generation += 1

#if DEBUG
        // 로그 자체는 실기기 관찰에만 필요하고 이 actor의 임계 구간에 영향을 주면 안 되므로,
        // `notice` 호출을 별도 Task로 분리해 `apply(_:)`의 동기 구간을 그대로 유지합니다.
        // 여기서 직접(동기적으로) 호출하면 로깅 시스템 호출 지연이 그대로 이 actor 차례를 늦춰
        // `ManualMonotonicClock` 기반 타이밍 테스트의 협력 스케줄링 가정을 흔들 수 있습니다.
        let debugSchedule = schedule
        let debugGeneration = generation
        let debugAxis = debugAxisLabel
        let debugCount = debugAppendedSampleCount
        Task.detached(priority: .utility) {
            MonitoringSchedulerDebugLog.logger.notice("apply axis=\(debugAxis, privacy: .public) schedule=\(String(describing: debugSchedule), privacy: .public) generation=\(debugGeneration, privacy: .public) appendedTotal=\(debugCount, privacy: .public)")
        }
#endif

        switch schedule {
        case .paused:
            break

        case .running(let interval):
            let currentGeneration = generation
            let clock = clock
            let source = source
            let sink = sink
            // 기준 deadline은 apply(_:)가 실행되는 이 시점에 고정합니다. Task 본문 안에서 다시 now()를
            // 읽으면 비동기 스케줄링 시점에 따라 anchor가 달라질 수 있어(수동 시계 테스트에서는 호출자의
            // 이후 전진과 경쟁), 매 tick이 이 고정된 기준에서만 전진하도록 보장할 수 없습니다.
            let startInstant = await clock.now()

            task = Task { [weak self] in
                var deadline = startInstant
                while true {
                    if Task.isCancelled { return }

                    // 마지막 실행 완료 시점이 아니라 기준 deadline을 전진시켜 다음 실행 시각을 계산합니다.
                    deadline = deadline.advanced(by: interval)

                    do {
                        try await clock.sleep(until: deadline)
                    } catch {
                        return
                    }
                    if Task.isCancelled { return }

                    let timestamp = await clock.now()
                    let value: Source.Value
                    do {
                        value = try await source.sample()
                    } catch {
                        // 공급자 실패는 0 샘플로 바꾸지 않고 다음 실행으로 넘어갑니다.
                        continue
                    }
                    if Task.isCancelled { return }

                    guard let self else { return }
                    await self.appendIfCurrentGeneration(
                        currentGeneration,
                        sample: TimestampedSample(timestamp: timestamp, value: value),
                        into: sink
                    )
                }
            }
        }
    }

    /// 이전 generation인 실행 결과는 저장하지 않습니다.
    private func appendIfCurrentGeneration(
        _ resultGeneration: Int,
        sample: TimestampedSample<Source.Value>,
        into sink: Sink
    ) async {
        guard resultGeneration == generation else {
#if DEBUG
            let debugCurrentGeneration = generation
            let debugAxis = debugAxisLabel
            Task.detached(priority: .utility) {
                MonitoringSchedulerDebugLog.logger.notice("discarded stale axis=\(debugAxis, privacy: .public) generation result=\(resultGeneration, privacy: .public) current=\(debugCurrentGeneration, privacy: .public)")
            }
#endif
            return
        }
        await sink.append(sample)
#if DEBUG
        debugAppendedSampleCount += 1
        let debugAxis = debugAxisLabel
        let debugCount = debugAppendedSampleCount
        Task.detached(priority: .utility) {
            MonitoringSchedulerDebugLog.logger.notice("appended sample axis=\(debugAxis, privacy: .public) generation=\(resultGeneration, privacy: .public) appendedTotal=\(debugCount, privacy: .public)")
        }
#endif
    }
}
