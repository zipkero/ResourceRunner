//
//  MonitoringScheduler.swift
//  ResourceRunner
//
//  Created by zipkero on 8/10/26.
//

import Foundation

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

/// M1 주입 샘플을 비동기로 반환하고 취소를 따르는 계약.
/// 공급자 실패(`throw`)는 `MonitoringScheduler`가 0 샘플로 바꾸지 않고 다음 실행으로 넘어갑니다.
nonisolated protocol ScheduledSampleSource: Sendable {
    associatedtype Value: Sendable
    func sample() async throws -> Value
}

/// 적용 일정, 단일 Task와 generation별 실행을 직렬화하는 actor.
/// 일정, 취소와 generation만 소유하고 버퍼는 `MonitoringSampleStore`에만 맡깁니다.
/// `apply(_:)` 호출마다 기존 작업을 취소하고 새 generation 하나만 시작하며,
/// interval은 마지막 실행 완료 시점이 아니라 기준 deadline을 전진시켜 계산합니다.
actor MonitoringScheduler<Clock: MonotonicClock, Source: ScheduledSampleSource> {
    private let clock: Clock
    private let source: Source
    private let sampleStore: MonitoringSampleStore<Source.Value>

    private var task: Task<Void, Never>?

    /// `apply(_:)`가 새 작업을 시작할 때만 전진하는 세대 번호.
    /// `appendIfCurrentGeneration`이 이전 세대의 실행 결과를 걸러내는 근거이며,
    /// `Task.isCancelled` 검사와 별개로 남겨 두는 방어선이라 테스트에서 직접 관찰할 수 있게 노출합니다.
    private(set) var generation = 0

    /// `MonitoringLifecycleStore`가 계산 결과가 바뀔 때만 호출하는지, 즉 같은 일정 반복에도
    /// `apply(_:)`가 다시 불리지 않는지를 테스트에서 직접 세기 위한 진단용 카운터입니다.
    private(set) var applyCallCount = 0

    init(clock: Clock, source: Source, sampleStore: MonitoringSampleStore<Source.Value>) {
        self.clock = clock
        self.source = source
        self.sampleStore = sampleStore
    }

    /// 계산된 일정을 적용합니다.
    /// `paused`는 실행 중인 작업만 취소하고 버퍼와 용량을 그대로 둡니다(resize 없음).
    /// `running(interval)`은 새 유효 주기로 버퍼를 resize한 뒤 새 generation 하나로 시작하며,
    /// 이전 generation의 실행 결과나 취소·공급자 실패는 저장하지 않습니다.
    func apply(_ schedule: CollectionSchedule) async {
        applyCallCount += 1

        task?.cancel()
        task = nil
        // generation은 취소와 같은 동기 구간에서 즉시 전진시킵니다. 뒤에 오는 `await sampleStore.resize`
        // 같은 suspension 지점 이후로 미루면, 그 구간에서 이전 세대 작업이 이미 취소 확인을 통과해 두고
        // actor 차례를 기다리던 `appendIfCurrentGeneration` 호출이 끼어들었을 때 아직 갱신 전인
        // generation과 우연히 일치해 이전 세대 결과가 저장될 수 있습니다.
        generation += 1

        switch schedule {
        case .paused:
            break

        case .running(let interval):
            await sampleStore.resize(samplingInterval: interval)

            let currentGeneration = generation
            let clock = clock
            let source = source
            let sampleStore = sampleStore
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
                        into: sampleStore
                    )
                }
            }
        }
    }

    /// 이전 generation인 실행 결과는 저장하지 않습니다.
    private func appendIfCurrentGeneration(
        _ resultGeneration: Int,
        sample: TimestampedSample<Source.Value>,
        into sampleStore: MonitoringSampleStore<Source.Value>
    ) async {
        guard resultGeneration == generation else { return }
        await sampleStore.append(sample)
    }
}
