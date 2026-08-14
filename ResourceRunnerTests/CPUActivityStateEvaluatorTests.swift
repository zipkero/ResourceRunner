//
//  CPUActivityStateEvaluatorTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/14/26.
//

import Testing
@testable import ResourceRunner

/// task-007 검증 조건: 사용률과 시각을 직접 준 시퀀스로 순수 판정 함수를 검증합니다.
/// 데드밴드, 최소 유지 시간, 시각 기준 지속 판정 세 장치를 각각 mutation 관점에서 고정합니다.
struct CPUActivityStateEvaluatorTests {
    private let base = ContinuousClock().now

    /// 순서대로 `(경과 초, 사용률)` 시퀀스를 흘려보내 최종 상태를 얻습니다.
    private func run(_ ticks: [(Double, Double)], from state: CPUActivityStateEvaluator.State = .initial) -> CPUActivityStateEvaluator.State {
        var current = state
        for (offset, usage) in ticks {
            current = CPUActivityStateEvaluator.evaluate(usage: usage, timestamp: base.advanced(by: .seconds(offset)), state: current)
        }
        return current
    }

    // MARK: - 경계 진입·이탈 (상승은 원 경계값, 하강은 데드밴드)

    @Test func risesToModerateExactlyAtLowerBoundary() {
        // 25%가 3초 이상 유지되면 보통으로 올라갑니다.
        let state = run([(0, 25), (1, 25), (2, 25), (3, 25)])
        #expect(state.displayedState == .moderate)
    }

    @Test func risesToHighExactlyAtMidBoundary() {
        let state = run([(0, 50), (1, 50), (2, 50), (3, 50)])
        #expect(state.displayedState == .high)
    }

    @Test func risesToVeryHighExactlyAtUpperBoundary() {
        let state = run([(0, 75), (1, 75), (2, 75), (3, 75)])
        #expect(state.displayedState == .veryHigh)
    }

    @Test func staysInDeadbandJustBelowBoundaryDoesNotDescend() {
        // moderate로 올라선 뒤 20%(25-5)는 데드밴드 경계라 아직 낮음으로 내려가지 않습니다.
        let state = run([
            (0, 30), (1, 30), (2, 30), (3, 30),
            (4, 20), (5, 20), (6, 20), (7, 20),
        ])
        #expect(state.displayedState == .moderate)
    }

    @Test func descendsBelowDeadbandFloor() {
        // moderate로 올라선 뒤 19.9%는 데드밴드(20%) 아래이므로 3초 유지되면 낮음으로 내려갑니다.
        let state = run([
            (0, 30), (1, 30), (2, 30), (3, 30),
            (4, 19.9), (5, 19.9), (6, 19.9), (7, 19.9),
        ])
        #expect(state.displayedState == .low)
    }

    // MARK: - 데드밴드 mutation 민감성

    /// 이 테스트가 고정하는 것: 하강 판정에서 데드밴드(경계 - 5%p)를 없애고 원 경계값 그대로 쓰면
    /// 24%·26% 교대 시퀀스에서 표시 상태 변경 횟수가 0이 아니게 됩니다.
    /// base가 `.low`에 머무른 채로 교대하면 24%·26% 모두 `candidateBand`의 "위 또는 동일" 분기만 타서
    /// 데드밴드가 있든 없든 결과가 같아지므로(하강 분기가 실행되지 않으므로), 먼저 26%를 3초 이상 유지해
    /// base를 `.moderate`로 올린 뒤에 교대시켜야 하강 분기가 실제로 실행됩니다.
    /// 각 다리를 4초씩 유지하는 이유는, 데드밴드가 없다면 최소 유지 시간(3초)을 넘겨 실제로 승격될
    /// 시간을 주기 위해서입니다 — 매초 교대하면 최소 유지 시간 하나만으로도 승격이 걸러져 데드밴드
    /// 유무와 무관하게 변경 횟수가 0이 됩니다.
    @Test func alternatingAroundLowerBoundaryNeverChangesDisplayedStateOnceInModerate() {
        var usages: [Double] = Array(repeating: 26.0, count: 4) // base를 moderate로 승격
        for _ in 0..<3 {
            usages += Array(repeating: 24.0, count: 4) // 데드밴드 하한(20%) 위이므로 moderate를 유지해야 함
            usages += Array(repeating: 26.0, count: 4)
        }

        var state = CPUActivityStateEvaluator.State.initial
        var changeCount = 0
        for (index, usage) in usages.enumerated() {
            let previous = state.displayedState
            state = CPUActivityStateEvaluator.evaluate(usage: usage, timestamp: base.advanced(by: .seconds(index)), state: state)
            if state.displayedState != previous {
                changeCount += 1
            }
        }

        // 처음 4초의 low -> moderate 승격 1건만 있어야 하고, 이후 24%·26% 교대에서는 변경이 없어야 합니다.
        #expect(changeCount == 1)
        #expect(state.displayedState == .moderate)
    }

    // MARK: - 최소 유지 시간 mutation 민감성

    /// 이 테스트가 고정하는 것: 최소 유지 시간을 없애면(승격 조건을 시간차 없이 즉시 통과시키면)
    /// 한 tick만 급등한 시퀀스 중간에 표시 상태가 실제로 바뀝니다.
    /// 최종 상태만 보면 급등 후 다시 낮은 값으로 돌아와 우연히 결과가 같아질 수 있으므로
    /// (최소 유지 시간이 없으면 낮은음↔높은음 왕복 승격이 각각 즉시 일어나 최종값은 결국 낮음으로 돌아옵니다)
    /// 시퀀스 전체에서 표시 상태가 몇 번 바뀌었는지를 셉니다.
    @Test func singleTickSpikeDoesNotChangeDisplayedState() {
        let usages: [Double] = [10, 95, 10, 10] // 한 tick만 급등

        var state = CPUActivityStateEvaluator.State.initial
        var changeCount = 0
        for (index, usage) in usages.enumerated() {
            let previous = state.displayedState
            state = CPUActivityStateEvaluator.evaluate(usage: usage, timestamp: base.advanced(by: .seconds(index)), state: state)
            if state.displayedState != previous {
                changeCount += 1
            }
        }

        #expect(changeCount == 0)
        #expect(state.displayedState == .low)
    }

    @Test func candidateMustHoldForAtLeastThreeSecondsToPromote() {
        // 2.9초만 유지되면 아직 승격되지 않습니다.
        let notYet = run([(0, 50), (1, 50), (2.9, 50)])
        #expect(notYet.displayedState == .low)

        let promoted = run([(0, 50), (1, 50), (3, 50)])
        #expect(promoted.displayedState == .high)
    }

    // MARK: - 장시간 고부하 진입·이탈

    @Test func entersSustainedHighAfterSixtySecondsOfContinuousVeryHigh() {
        // 1초 주기로 75% 이상을 이어가면 59초 시점에는 아직 매우 높음이고 60초에 장시간 고부하가 됩니다.
        var state = CPUActivityStateEvaluator.State.initial
        for second in 0...59 {
            state = CPUActivityStateEvaluator.evaluate(usage: 80, timestamp: base.advanced(by: .seconds(second)), state: state)
        }
        #expect(state.displayedState == .veryHigh)

        state = CPUActivityStateEvaluator.evaluate(usage: 80, timestamp: base.advanced(by: .seconds(60)), state: state)
        #expect(state.displayedState == .sustainedHigh)
    }

    @Test func sustainedHighExitsOnlyAfterThreeSecondsBelowVeryHighDeadband() {
        var state = CPUActivityStateEvaluator.State.initial
        for second in 0...60 {
            state = CPUActivityStateEvaluator.evaluate(usage: 80, timestamp: base.advanced(by: .seconds(second)), state: state)
        }
        #expect(state.displayedState == .sustainedHigh)

        // 71%는 veryHigh 데드밴드(70%) 안이라 벗어나지 않습니다.
        state = CPUActivityStateEvaluator.evaluate(usage: 71, timestamp: base.advanced(by: .seconds(61)), state: state)
        #expect(state.displayedState == .sustainedHigh)

        // 68%가 3초 이상 이어져야 벗어납니다.
        state = CPUActivityStateEvaluator.evaluate(usage: 68, timestamp: base.advanced(by: .seconds(62)), state: state)
        #expect(state.displayedState == .sustainedHigh)
        state = CPUActivityStateEvaluator.evaluate(usage: 68, timestamp: base.advanced(by: .seconds(63)), state: state)
        #expect(state.displayedState == .sustainedHigh)
        state = CPUActivityStateEvaluator.evaluate(usage: 68, timestamp: base.advanced(by: .seconds(65)), state: state)
        #expect(state.displayedState == .high)
    }

    // MARK: - 지속을 샘플 시각으로 세는 것에 대한 mutation 민감성

    /// 이 테스트가 고정하는 것: 지속을 샘플 개수로 세면 5초 주기 12틱(=60초)에서 아직 장시간 고부하가 되지 않아야 하는데
    /// 개수 기반 구현은 여기서 이미(또는 아직) 잘못된 시점에 전환해 이 단언이 어긋납니다.
    @Test func sustainedDurationCountsElapsedTimeNotSampleCount() {
        // 5초 주기 12틱 = 60초 경과. 시각 기준이면 정확히 이 시점에 장시간 고부하가 됩니다.
        var fiveSecondState = CPUActivityStateEvaluator.State.initial
        for tick in 0...12 {
            fiveSecondState = CPUActivityStateEvaluator.evaluate(
                usage: 80,
                timestamp: base.advanced(by: .seconds(tick * 5)),
                state: fiveSecondState
            )
        }
        #expect(fiveSecondState.displayedState == .sustainedHigh)

        // 같은 60초를 1초 주기 61틱으로 나타내도 같은 시점에 장시간 고부하가 되어야 합니다.
        var oneSecondState = CPUActivityStateEvaluator.State.initial
        for tick in 0...60 {
            oneSecondState = CPUActivityStateEvaluator.evaluate(
                usage: 80,
                timestamp: base.advanced(by: .seconds(tick)),
                state: oneSecondState
            )
        }
        #expect(oneSecondState.displayedState == .sustainedHigh)

        // 5초 주기로 60초에 못 미치는 11틱(=55초)까지는 아직 장시간 고부하가 아닙니다.
        var shortState = CPUActivityStateEvaluator.State.initial
        for tick in 0...11 {
            shortState = CPUActivityStateEvaluator.evaluate(
                usage: 80,
                timestamp: base.advanced(by: .seconds(tick * 5)),
                state: shortState
            )
        }
        #expect(shortState.displayedState == .veryHigh)

        // 2초 주기는 앞의 두 확인만으로는 걸러지지 않는 고정 개수 임계값(예: 13)을 추가로 걸러냅니다 —
        // 5초 주기 13틱과 1초 주기 61틱은 우연히도 개수 임계값 13과 60초 경과가 같은 지점에서 일치하지만,
        // 2초 주기에서 임계값 13은 26초(58초에 한참 못 미침) 만에 잘못 전환되므로 58초 시점의 단언이 이를 잡습니다.
        var twoSecondState = CPUActivityStateEvaluator.State.initial
        for tick in 0..<30 {
            twoSecondState = CPUActivityStateEvaluator.evaluate(
                usage: 80,
                timestamp: base.advanced(by: .seconds(tick * 2)),
                state: twoSecondState
            )
        }
        #expect(twoSecondState.displayedState == .veryHigh) // 58초 시점

        twoSecondState = CPUActivityStateEvaluator.evaluate(usage: 80, timestamp: base.advanced(by: .seconds(60)), state: twoSecondState)
        #expect(twoSecondState.displayedState == .sustainedHigh)
    }

    // MARK: - 중지 구간을 낀 지속 단절

    @Test func gapLongerThanAllowedBreaksSustainedStreak() {
        // 55초 동안 75% 이상을 이어가다가(아직 60초 미만) 긴 중지 뒤 재개된 것처럼 큰 간격을 두면
        // 이어서 5초를 더해도(총 경과 60초) 지속이 끊겨 장시간 고부하가 되지 않습니다.
        var state = CPUActivityStateEvaluator.State.initial
        for second in stride(from: 0, through: 55, by: 5) {
            state = CPUActivityStateEvaluator.evaluate(usage: 80, timestamp: base.advanced(by: .seconds(second)), state: state)
        }
        #expect(state.displayedState == .veryHigh)

        // 허용 범위(10초)를 넘는 중지 구간.
        let resumeTimestamp = base.advanced(by: .seconds(55 + 30))
        state = CPUActivityStateEvaluator.evaluate(usage: 80, timestamp: resumeTimestamp, state: state)
        #expect(state.displayedState == .veryHigh)

        // 재개 이후 다시 60초를 채워야 장시간 고부하가 됩니다. 재개 직후 몇 초만으로는 아직입니다.
        state = CPUActivityStateEvaluator.evaluate(usage: 80, timestamp: resumeTimestamp.advanced(by: .seconds(5)), state: state)
        #expect(state.displayedState == .veryHigh)
    }

    @Test func gapLongerThanAllowedBreaksMinimumHoldPending() {
        // 후보 상태가 확정되기 전(3초 미만 유지) 큰 간격이 끼면 그 유지 시간이 이어지지 않습니다.
        var state = CPUActivityStateEvaluator.State.initial
        state = CPUActivityStateEvaluator.evaluate(usage: 50, timestamp: base, state: state)
        state = CPUActivityStateEvaluator.evaluate(usage: 50, timestamp: base.advanced(by: .seconds(1)), state: state)
        #expect(state.displayedState == .low)

        // 허용 범위를 넘는 간격 뒤 같은 사용률이 다시 온 시점부터 새로 3초를 채워야 합니다.
        let resumeTimestamp = base.advanced(by: .seconds(1 + 30))
        state = CPUActivityStateEvaluator.evaluate(usage: 50, timestamp: resumeTimestamp, state: state)
        state = CPUActivityStateEvaluator.evaluate(usage: 50, timestamp: resumeTimestamp.advanced(by: .seconds(1)), state: state)
        #expect(state.displayedState == .low)

        state = CPUActivityStateEvaluator.evaluate(usage: 50, timestamp: resumeTimestamp.advanced(by: .seconds(3)), state: state)
        #expect(state.displayedState == .high)
    }

    // 실패 tick·값 없는 tick에서의 상태 유지와 `CharacterStateSource.send(_:)` 배선은
    // 순수 함수 하나로 시뮬레이션할 수 없는 `ApplicationCoordinator.consumeSystemMetrics(_:into:)`의 책임이라
    // ApplicationCoordinatorTests.swift에서 실제 배선(스토어 -> 평가 -> source)으로 검증합니다.
}
