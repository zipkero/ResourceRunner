//
//  CharacterStateSourceTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/10/26.
//

import Testing
@testable import ResourceRunner

/// task-012 검증 조건: 다섯 상태 → 접근성 이름 매핑을 AppKit 없이 전수 검증하고,
/// 테스트 전용 sink로 상태 주입마다 전달되는 `CharacterPresentation` 순서와 횟수를 확인합니다.
struct CharacterStateSourceTests {

    @Test(arguments: [
        (CharacterActivityState.low, "ResourceRunner, 낮음"),
        (CharacterActivityState.moderate, "ResourceRunner, 보통"),
        (CharacterActivityState.high, "ResourceRunner, 높음"),
        (CharacterActivityState.veryHigh, "ResourceRunner, 매우 높음"),
        (CharacterActivityState.sustainedHigh, "ResourceRunner, 장시간 고부하"),
    ])
    func mapsEachStateToItsAccessibilityLabel(state: CharacterActivityState, expectedLabel: String) {
        let presentation = CharacterPresentation.presenting(state)

        #expect(presentation.accessibilityLabel == expectedLabel)
    }

    @Test func defaultInitialStateIsLow() {
        let source = CharacterStateSource()

        #expect(source.initialState == .low)
    }

    @MainActor
    final class RecordingSink: CharacterPresentationSink {
        private(set) var received: [CharacterPresentation] = []

        func render(_ presentation: CharacterPresentation) {
            received.append(presentation)
        }
    }

    /// `ApplicationCoordinator.consume(_:into:)`가 실제로 쓰는 소비 경로(초기 상태 렌더 + stream 소비 Task)를
    /// 그대로 통과시켜 검증합니다. 소비를 시작하기 전에 모든 상태를 먼저 주입해 소비가 밀린 상황을 인위적으로
    /// 만들고, 그래도 손실 없이 순서대로 전달되는지 확인합니다.
    @Test @MainActor func deliversEachInjectedStateExactlyOnceInOrderEvenWhenConsumptionLagsBehindInjection() async {
        let source = CharacterStateSource()
        let sink = RecordingSink()

        let injected: [CharacterActivityState] = [.high, .low, .sustainedHigh, .moderate, .veryHigh, .low]

        // 소비 Task를 시작하기 전에 먼저 전부 주입합니다.
        // Task는 아직 스케줄되지 않았으므로 이 시점의 stream 버퍼에 다섯 값이 모두 쌓입니다.
        for state in injected {
            source.send(state)
        }

        let task = ApplicationCoordinator.consume(source, into: sink)

        let expectedCount = injected.count + 1 // 초기 상태 1건 + 주입 상태
        var iterations = 0
        while sink.received.count < expectedCount && iterations < 10_000 {
            await Task.yield()
            iterations += 1
        }
        task.cancel()

        guard sink.received.count == expectedCount else {
            Issue.record("sink가 \(expectedCount)건을 받아야 하는데 \(sink.received.count)건만 받았습니다: \(sink.received)")
            return
        }

        let expected = ([source.initialState] + injected).map(CharacterPresentation.presenting)
        #expect(sink.received == expected)
    }
}
