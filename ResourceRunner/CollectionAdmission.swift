import Foundation

nonisolated enum CollectionAxis: Hashable, Sendable {
    case systemMetrics, processSurvey, networkActivity, diskActivity, networkMetadata, storageMetadata
}

nonisolated enum CollectionAdmissionPhase: Hashable, Sendable {
    case source, store, display
}

nonisolated struct CollectionBoundary: Sendable, Equatable {
    let revision: Int
    let sequence: Int
    let epoch: Int
    let stopped: Bool
}

nonisolated struct CollectionRunContext: Sendable, Equatable {
    let axis: CollectionAxis
    let epoch: Int
    let generation: Int
    let planRevision: Int
    let requestSequence: Int
    let boundarySequence: Int
}

/// 생명주기와 세 반영 지점이 같은 lock 아래에서 현재 실행권을 확인합니다.
/// 오래 걸리는 native 조회는 lock 밖에서 실행하고, 상태 변경만 임계 구간에 둡니다.
nonisolated final class CollectionAdmission: @unchecked Sendable {
    private struct Watermark {
        let request: Int
        let timestamp: ContinuousClock.Instant
    }

    private let lock = NSLock()
    private var boundary = CollectionBoundary(revision: 0, sequence: 0, epoch: 0, stopped: true)
    private var generations: [CollectionAxis: Int] = [:]
    private var planRevisions: [CollectionAxis: Int] = [:]
    private var nextRequests: [CollectionAxis: Int] = [:]
    private var accepted: [CollectionAxis: [CollectionAdmissionPhase: Watermark]] = [:]

    var currentBoundary: CollectionBoundary { lock.withLock { boundary } }

    func planRevision(for axis: CollectionAxis) -> Int {
        lock.withLock { planRevisions[axis] ?? 0 }
    }

    /// target 호출이 대기 중이어도 새 일정의 실행권을 먼저 고정합니다.
    func setPlanRevision(_ revision: Int, for axis: CollectionAxis) {
        lock.withLock {
            if revision > (planRevisions[axis] ?? 0) { planRevisions[axis] = revision }
        }
    }

    func transition(_ next: CollectionBoundary) {
        lock.withLock {
            guard next.revision >= boundary.revision, next.sequence >= boundary.sequence else { return }
            guard next != boundary else { return }
            let resetOrder = next.sequence != boundary.sequence || next.epoch != boundary.epoch
            boundary = next
            if resetOrder { accepted.removeAll() }
        }
    }

    func advance(_ axis: CollectionAxis) -> Int {
        lock.withLock {
            let next = (generations[axis] ?? 0) + 1
            generations[axis] = next
            return next
        }
    }

    func issue(_ axis: CollectionAxis) -> CollectionRunContext? {
        lock.withLock {
            guard !boundary.stopped else { return nil }
            let request = (nextRequests[axis] ?? 0) + 1
            nextRequests[axis] = request
            return CollectionRunContext(axis: axis, epoch: boundary.epoch,
                generation: generations[axis] ?? 0, planRevision: planRevisions[axis] ?? 0,
                requestSequence: request,
                boundarySequence: boundary.sequence)
        }
    }

    func issue(_ axis: CollectionAxis, expectedEpoch: Int,
               expectedGeneration: Int, expectedPlanRevision: Int) -> CollectionRunContext? {
        lock.withLock {
            guard !boundary.stopped, boundary.epoch == expectedEpoch,
                  generations[axis] == expectedGeneration,
                  planRevisions[axis, default: 0] == expectedPlanRevision else { return nil }
            let request = (nextRequests[axis] ?? 0) + 1
            nextRequests[axis] = request
            return CollectionRunContext(axis: axis, epoch: expectedEpoch,
                generation: expectedGeneration, planRevision: expectedPlanRevision,
                requestSequence: request,
                boundarySequence: boundary.sequence)
        }
    }

    func isCurrent(_ context: CollectionRunContext) -> Bool {
        lock.withLock { valid(context) }
    }

    @discardableResult
    func withCurrentBoundary<T>(_ candidate: CollectionBoundary, _ apply: () -> T) -> T? {
        lock.withLock {
            guard candidate == boundary else { return nil }
            return apply()
        }
    }

    @discardableResult
    func admit<T>(_ context: CollectionRunContext, phase: CollectionAdmissionPhase,
                  timestamp: ContinuousClock.Instant, _ apply: () -> T) -> T? {
        lock.withLock {
            guard valid(context) else { return nil }
            if let last = accepted[context.axis]?[phase],
               context.requestSequence <= last.request || timestamp < last.timestamp { return nil }
            let result = apply()
            accepted[context.axis, default: [:]][phase] = Watermark(request: context.requestSequence, timestamp: timestamp)
            return result
        }
    }

    @MainActor
    func admitDisplay<T>(_ context: CollectionRunContext, timestamp: ContinuousClock.Instant,
                         _ apply: @MainActor () -> T) -> T? {
        lock.withLock {
            guard valid(context) else { return nil }
            if let last = accepted[context.axis]?[.display],
               context.requestSequence <= last.request || timestamp < last.timestamp { return nil }
            let result = apply()
            accepted[context.axis, default: [:]][.display] = Watermark(request: context.requestSequence, timestamp: timestamp)
            return result
        }
    }

    private func valid(_ context: CollectionRunContext) -> Bool {
        !boundary.stopped && context.epoch == boundary.epoch &&
            context.boundarySequence == boundary.sequence &&
            context.generation == generations[context.axis] &&
            context.planRevision == planRevisions[context.axis, default: 0]
    }
}
