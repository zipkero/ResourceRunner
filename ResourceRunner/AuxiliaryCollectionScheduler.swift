import Foundation

/// 보조 정보는 일정 외에 topology·마운트 변경의 명시적 갱신 요청을 받습니다.
nonisolated protocol AuxiliaryCollectionTarget: CollectionScheduleTarget {
    func requestRefresh() async
}

/// 느린 보조 조회 한 축의 타이머·요청 병합·단일 실행을 소유합니다.
/// 빠른 수집 축과 actor나 작업을 공유하지 않으며, 결과 반영은 공통 admission에 맡깁니다.
actor AuxiliaryCollectionScheduler<Clock: MonotonicClock, Source: ScheduledSampleSource,
                                   Sink: MonitoringSampleSink>: AuxiliaryCollectionTarget
where Sink.Value == Source.Value {
    private let clock: Clock
    private let source: Source
    private let sink: Sink
    private let admission: CollectionAdmission
    private let axis: CollectionAxis

    private var schedule: CollectionSchedule = .paused
    private var lastRevision = -1
    private var generation = 0
    private var admittedGeneration = 0
    private var admittedPlanRevision = 0
    private var collectionEpoch = 0
    private var timer: Task<Void, Never>?
    private var query: Task<Void, Never>?
    private var inFlight = false
    private var pendingRefresh = false
    private var lastQueryStartedAt: ContinuousClock.Instant?
    private(set) var cachedSample: TimestampedSample<Source.Value>?
    private(set) var startedQueryCount = 0

    init(clock: Clock, source: Source, sink: Sink, admission: CollectionAdmission,
         axis: CollectionAxis) {
        precondition(axis == .networkMetadata || axis == .storageMetadata)
        self.clock = clock
        self.source = source
        self.sink = sink
        self.admission = admission
        self.axis = axis
    }

    func apply(_ next: CollectionSchedule, revision: Int) async {
        guard revision >= lastRevision,
              admission.planRevision(for: axis) == revision else { return }
        lastRevision = revision
        await apply(next)
    }

    func apply(_ next: CollectionSchedule) async {
        generation += 1
        let localGeneration = generation
        schedule = next
        collectionEpoch = admission.currentBoundary.epoch
        admittedGeneration = admission.advance(axis)
        admittedPlanRevision = admission.planRevision(for: axis)
        timer?.cancel()
        timer = nil
        // 취소를 무시하는 source도 있으므로 inFlight는 실제 완료까지 유지합니다.
        query?.cancel()
        if inFlight { pendingRefresh = true }

        guard case .running(let interval) = next else {
            if inFlight { pendingRefresh = true }
            return
        }

        let queryCountBeforeClock = startedQueryCount
        let now = await clock.now()
        guard localGeneration == generation,
              admission.planRevision(for: axis) == admittedPlanRevision else { return }

        // 기존 캐시를 즉시 유지하고, 새 주기 기준으로 오래된 경우만 별도 조회합니다.
        if pendingRefresh || (startedQueryCount == queryCountBeforeClock &&
            (cachedSample == nil || cachedSample.map({ $0.timestamp.duration(to: now) >= interval }) == true)) {
            pendingRefresh = true
            startIfPossible(at: now)
        }
        timer = Task { [weak self] in
            guard let self else { return }
            var deadline = now.advanced(by: interval)
            while !Task.isCancelled {
                do { try await clock.sleep(until: deadline) }
                catch { return }
                if Task.isCancelled { return }
                let current = await clock.now()
                await self.periodicDue(generation: localGeneration, deadline: deadline, now: current)
                // 지나간 deadline 수만큼 보충 tick을 만들지 않습니다.
                deadline = current.advanced(by: interval)
            }
        }
    }

    func requestRefresh() async {
        pendingRefresh = true
        let now = await clock.now()
        startIfPossible(at: now)
    }

    private func periodicDue(generation expected: Int,
                             deadline: ContinuousClock.Instant, now: ContinuousClock.Instant) {
        guard expected == generation else { return }
        // 대기 중 병합 요청으로 이미 이 deadline 이후 조회가 시작됐으면 보충하지 않습니다.
        if let lastQueryStartedAt, lastQueryStartedAt >= deadline { return }
        pendingRefresh = true
        startIfPossible(at: now)
    }

    private func startIfPossible(at timestamp: ContinuousClock.Instant) {
        guard pendingRefresh, !inFlight, case .running = schedule else { return }
        guard let context = admission.issue(axis, expectedEpoch: collectionEpoch,
            expectedGeneration: admittedGeneration,
            expectedPlanRevision: admittedPlanRevision) else { return }
        pendingRefresh = false
        inFlight = true
        lastQueryStartedAt = timestamp
        startedQueryCount += 1
        query = Task { [weak self, source, clock] in
            let value: Source.Value?
            do { value = try await source.sample(context: context) }
            catch { value = nil }
            let timestamp = await clock.now()
            await self?.finish(value, context: context, timestamp: timestamp)
        }
    }

    private func finish(_ value: Source.Value?, context: CollectionRunContext,
                        timestamp: ContinuousClock.Instant) async {
        defer {
            inFlight = false
            query = nil
            startIfPossible(at: timestamp)
        }
        guard let value, admission.isCurrent(context) else { return }
        let sample = TimestampedSample(timestamp: timestamp, value: value,
                                       collectionEpoch: context.epoch, context: context)
        guard await sink.append(sample, context: context), admission.isCurrent(context) else { return }
        cachedSample = sample
    }
}
