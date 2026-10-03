import Foundation

nonisolated extension GraphTimeRange {
    var leadingLabel: String { "\(Int(duration) / 60)분 전" }
    var windowLabel: String { "최근 \(Int(duration) / 60)분" }
}

/// Network·Disk의 두 방향을 같은 양의 B/s 축에 놓는 순수 그래프 모델입니다.
nonisolated struct ResourceRateGraph: Sendable {
    let visibleSegments: [[RateHistoryPoint]]
    let upperBound: Double?
    let firstHistoryPointAt: ContinuousClock.Instant?
    let currentTimestamp: ContinuousClock.Instant
    let timeRange: GraphTimeRange

    static let minimumUpperBound = 1_024.0

    static func make(history: [RateHistoryPoint], firstHistoryPointAt: ContinuousClock.Instant?,
                     currentTimestamp: ContinuousClock.Instant,
                     timeRange: GraphTimeRange = .tenMinutes) -> ResourceRateGraph {
        let start = currentTimestamp - .seconds(timeRange.duration)
        let visible = history.filter { $0.timestamp >= start && $0.timestamp <= currentTimestamp }
            .sorted { $0.timestamp < $1.timestamp }
        var segments: [[RateHistoryPoint]] = []
        for point in visible {
            if let previous = segments.last?.last,
               previous.collectionEpoch == point.collectionEpoch,
               previous.rateSegment == point.rateSegment,
               previous.timestamp < point.timestamp,
               previous.timestamp.duration(to: point.timestamp) <= point.maximumConnectedGap {
                segments[segments.count - 1].append(point)
            } else { segments.append([point]) }
        }
        let maximum = visible.reduce(0.0) { partial, point in
            max(partial, point.rate.receivedBytesPerSecond, point.rate.sentBytesPerSecond)
        }
        return ResourceRateGraph(visibleSegments: segments,
            upperBound: visible.isEmpty ? nil : niceUpperBound(for: maximum),
            firstHistoryPointAt: firstHistoryPointAt, currentTimestamp: currentTimestamp,
            timeRange: timeRange)
    }

    /// 표시 구간의 두 peak를 본 뒤에만 축을 정합니다. 빈 판에는 측정된 peak가 없습니다.
    static func niceUpperBound(for maximum: Double) -> Double {
        guard maximum.isFinite, maximum > minimumUpperBound else { return minimumUpperBound }
        let power = pow(10, floor(log10(maximum)))
        for multiplier in [1.0, 2.0, 5.0, 10.0] {
            let candidate = power * multiplier
            if candidate.isFinite && candidate >= maximum { return candidate }
        }
        return maximum
    }

    var rangeLabel: String {
        guard let upperBound else { return "속도 범위 대기 · B/s" }
        return "0–\(ResourceQuantityFormatter.byteRate(upperBound))"
    }

    var progressLabel: String {
        let total = Int(timeRange.duration)
        let denominator = String(format: "%02d:%02d", total / 60, total % 60)
        guard let firstHistoryPointAt else { return "데이터 수집 중 · 00:00 / \(denominator)" }
        let duration = firstHistoryPointAt.duration(to: currentTimestamp)
        let (seconds, attoseconds) = duration.components
        let elapsed = max(0, Double(seconds) + Double(attoseconds) / 1e18)
        guard elapsed < timeRange.duration else { return "" }
        let whole = Int(elapsed)
        return String(format: "데이터 수집 중 · %02d:%02d / %@", whole / 60, whole % 60, denominator)
    }

    /// 먼저 분리한 연속 구간마다 버킷의 RX/Read·TX/Write 최소·최대 실제 index 합집합을 보존합니다.
    func downsampledSegments(bucketCount: Int) -> [[RateHistoryPoint]] {
        visibleSegments.map { segment in
            guard segment.count > 2 else { return segment }
            let buckets = min(segment.count, max(1, bucketCount))
            var selected: Set<Int> = [0, segment.count - 1]
            for bucket in 0..<buckets {
                let lower = bucket * segment.count / buckets
                let upper = (bucket + 1) * segment.count / buckets
                guard lower < upper else { continue }
                let indices = lower..<upper
                for value: (RateHistoryPoint) -> Double in [
                    { $0.rate.receivedBytesPerSecond }, { $0.rate.sentBytesPerSecond }
                ] {
                    if let low = indices.min(by: { value(segment[$0]) < value(segment[$1]) }),
                       let high = indices.max(by: { value(segment[$0]) < value(segment[$1]) }) {
                        selected.insert(low)
                        selected.insert(high)
                    }
                }
            }
            return selected.sorted().map { segment[$0] }
        }
    }

    func normalizedX(_ timestamp: ContinuousClock.Instant) -> Double {
        let start = currentTimestamp - .seconds(timeRange.duration)
        let (seconds, attoseconds) = start.duration(to: timestamp).components
        return (Double(seconds) + Double(attoseconds) / 1e18) / timeRange.duration
    }

    func normalizedY(_ value: Double) -> Double {
        guard let upperBound else { return 1 }
        return 1 - min(1, max(0, value / upperBound))
    }
}
