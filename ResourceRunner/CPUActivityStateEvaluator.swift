//
//  CPUActivityStateEvaluator.swift
//  ResourceRunner
//
//  Created by zipkero on 8/14/26.
//

import Foundation

/// 전체 CPU 사용률·샘플 시각·직전 판정 상태를 받아 다음 표시 상태를 돌려주는 순수 계산.
/// 상태를 갖지 않으므로 값 타입인 `State`에 필요한 모든 것을 담아 호출자가 다음 호출에 그대로 넘깁니다.
/// ANALYSIS §2 「메뉴바 표시 상태 판정」, ANALYSIS §5 DP8을 그대로 구현합니다.
nonisolated enum CPUActivityStateEvaluator {
    /// 경계 25·50·75%, 상승은 경계값 그대로, 하강은 경계값에서 5%p를 뺀 값을 밑돌아야 합니다.
    static let lowerBoundary = 25.0
    static let midBoundary = 50.0
    static let upperBoundary = 75.0
    static let deadband = 5.0

    /// 데드밴드를 통과한 새 후보 상태가 실제 표시 상태를 바꾸려면 이만큼 유지돼야 합니다.
    static let minimumHoldDuration: Duration = .seconds(3)

    /// 75% 이상이 끊기지 않고 이만큼 이어지면 장시간 고부하로 전환합니다.
    static let sustainedDuration: Duration = .seconds(60)

    /// 인접 샘플 간격이 이 값을 넘으면 지속 누적(후보 유지 시간·75% 연속 구간)을 끊고 이 샘플을 새 기준점으로 삼습니다.
    /// 화면 잠금 같은 실제 중지 구간과 정상 수집 주기(가장 느린 5초)를 가르는 값이 이미 `SystemMetricsSampling.maximumTickGap`으로
    /// 정해져 있으므로 같은 값을 재사용합니다.
    static var maximumSampleGap: Duration { SystemMetricsSampling.maximumTickGap }

    /// 지속 누적에 필요한 값만 담는 판정 상태. `displayedState`가 `CharacterStateSource`로 나가는 값입니다.
    nonisolated struct State: Sendable, Equatable {
        /// 실제로 표시되는 다섯 상태 중 하나.
        let displayedState: CharacterActivityState
        /// 데드밴드를 통과해 확정된 기본 밴드. `sustainedHigh`는 이 값이 `.veryHigh`인 위에 얹히는 부가 상태라 따로 둡니다.
        let baseBand: CharacterActivityState
        /// 기본 밴드와 다르게 감지된 후보와 그 후보가 처음 나타난 시각. `minimumHoldDuration` 이상 유지되면 `baseBand`로 승격합니다.
        let pendingBand: CharacterActivityState?
        let pendingSince: ContinuousClock.Instant?
        /// 사용률이 75% 이상으로 끊기지 않고 이어진 구간의 시작 시각.
        let highStreakStart: ContinuousClock.Instant?
        /// 가장 최근에 실제로 판정을 진행한 샘플 시각. 다음 샘플과의 간격이 `maximumSampleGap`을 넘으면 지속을 끊습니다.
        let lastSampleTimestamp: ContinuousClock.Instant?

        /// `CharacterStateSource`의 기본 초기 상태(`low`)와 같은 자리에서 출발합니다.
        static let initial = State(
            displayedState: .low,
            baseBand: .low,
            pendingBand: nil,
            pendingSince: nil,
            highStreakStart: nil,
            lastSampleTimestamp: nil
        )
    }

    /// 한 tick의 사용률과 시각으로 다음 판정 상태를 계산합니다.
    /// 호출자는 CPU 지표가 실패했거나 값을 만들지 못한 tick(`.success(nil)`)에서는 이 함수를 호출하지 않고
    /// 직전 상태를 그대로 유지해야 합니다 — 판정할 사용률 자체가 없기 때문입니다.
    static func evaluate(usage: Double, timestamp: ContinuousClock.Instant, state: State) -> State {
        // 직전에 실제로 판정한 샘플과의 간격이 허용 범위를 넘으면 지속 누적을 끊습니다.
        // 화면 잠금 같은 중지 구간을 사이에 둔 두 샘플이 하나의 지속으로 이어지지 않게 하기 위해서입니다.
        let continuous: Bool
        if let last = state.lastSampleTimestamp {
            continuous = timestamp - last <= maximumSampleGap
        } else {
            continuous = false
        }

        var pendingBand = continuous ? state.pendingBand : nil
        var pendingSince = continuous ? state.pendingSince : nil
        var highStreakStart = continuous ? state.highStreakStart : nil
        var baseBand = state.baseBand
        var displayedState = state.displayedState

        // 후보 밴드를 히스테리시스로 계산합니다. 기본 밴드와 같으면 후보 추적을 초기화합니다.
        let candidate = candidateBand(usage: usage, currentBase: baseBand)
        if candidate == baseBand {
            pendingBand = nil
            pendingSince = nil
        } else if pendingBand != candidate {
            pendingBand = candidate
            pendingSince = timestamp
        }

        // 새 후보가 최소 유지 시간 이상 이어지면 기본 밴드를 승격합니다.
        // 이 순간 `sustainedHigh`도 함께 벗어납니다 — veryHigh를 벗어나는 조건(70% 아래 3초)과
        // sustainedHigh 이탈 조건이 정확히 같은 기준이므로 별도 이탈 로직을 두지 않습니다.
        if let candidateSince = pendingSince, let promoted = pendingBand,
           timestamp - candidateSince >= minimumHoldDuration {
            baseBand = promoted
            displayedState = promoted
            pendingBand = nil
            pendingSince = nil
        }

        // 75% 이상이 끊기지 않고 이어진 구간을 추적합니다.
        if usage >= upperBoundary {
            if highStreakStart == nil {
                highStreakStart = timestamp
            }
        } else {
            highStreakStart = nil
        }

        // 기본 밴드가 veryHigh를 유지한 채 75% 이상 구간이 sustainedDuration 이상 이어지면 장시간 고부하로 전환합니다.
        if let highStreakStart, baseBand == .veryHigh, displayedState != .sustainedHigh,
           timestamp - highStreakStart >= sustainedDuration {
            displayedState = .sustainedHigh
        }

        return State(
            displayedState: displayedState,
            baseBand: baseBand,
            pendingBand: pendingBand,
            pendingSince: pendingSince,
            highStreakStart: highStreakStart,
            lastSampleTimestamp: timestamp
        )
    }

    /// 현재 기본 밴드를 기준으로 새 후보 밴드를 히스테리시스로 계산합니다.
    /// 상승(또는 유지)은 원 경계값을 그대로 쓰고, 하강은 현재 밴드의 진입 경계에서 데드밴드를 뺀 값을 밑돌아야 합니다.
    private static func candidateBand(usage: Double, currentBase: CharacterActivityState) -> CharacterActivityState {
        let raw = rawBand(for: usage)
        guard rank(of: raw) < rank(of: currentBase) else {
            // 원 경계값 기준으로 현재 밴드와 같거나 위입니다. 상승·유지는 데드밴드를 적용하지 않습니다.
            return raw
        }

        // 원 경계값 기준으로는 현재 밴드보다 아래이지만, 데드밴드 안이면 아직 밴드를 벗어나지 않습니다.
        guard usage < entryBoundary(of: currentBase) - deadband else {
            return currentBase
        }

        return raw
    }

    /// 데드밴드 없이 25·50·75% 경계만으로 판정한 원 밴드.
    private static func rawBand(for usage: Double) -> CharacterActivityState {
        if usage >= upperBoundary { return .veryHigh }
        if usage >= midBoundary { return .high }
        if usage >= lowerBoundary { return .moderate }
        return .low
    }

    /// 밴드 사이의 순서. `sustainedHigh`는 기본 밴드로 쓰이지 않으므로 `veryHigh`와 같은 순위를 둡니다.
    private static func rank(of band: CharacterActivityState) -> Int {
        switch band {
        case .low: return 0
        case .moderate: return 1
        case .high: return 2
        case .veryHigh, .sustainedHigh: return 3
        }
    }

    /// 그 밴드에 진입하는 원 경계값. `low`는 진입 경계가 없으므로 더 내려갈 곳이 없습니다.
    private static func entryBoundary(of band: CharacterActivityState) -> Double {
        switch band {
        case .low: return lowerBoundary
        case .moderate: return lowerBoundary
        case .high: return midBoundary
        case .veryHigh, .sustainedHigh: return upperBoundary
        }
    }
}
