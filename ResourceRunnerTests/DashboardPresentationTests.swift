//
//  DashboardPresentationTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/15/26.
//

import Darwin
import Foundation
import Testing
@testable import ResourceRunner

private let baseInstant = ContinuousClock().now

private func cpuMetrics(overallUsage: Double = 42, userRatio: Double = 30, systemRatio: Double = 12) -> CPUSystemMetrics {
    CPUSystemMetrics(
        overallUsage: overallUsage,
        userRatio: userRatio,
        systemRatio: systemRatio,
        idleRatio: 100 - overallUsage,
        coreUsages: [overallUsage],
        loadAverage: LoadAverage(oneMinute: 0, fiveMinutes: 0, fifteenMinutes: 0)
    )
}

private func historyPoint(secondsFromBase: Double, overallCPUUsage: Double = 10) -> SystemMetricsHistoryPoint {
    SystemMetricsHistoryPoint(
        timestamp: baseInstant.advanced(by: .seconds(secondsFromBase)),
        overallCPUUsage: overallCPUUsage,
        swapUsedBytes: 0
    )
}

private func rankingEntry(name: String, value: Double) -> ApplicationRankingEntry {
    ApplicationRankingEntry(key: ApplicationKey(value: "/Applications/\(name).app"), displayName: name, value: value)
}

private func processHistorySnapshot(
    pid: pid_t,
    executablePath: String,
    cpuUsagePercent: Double?,
    residentBytes: UInt64,
    isTranslated: Bool = false
) -> ProcessHistorySnapshot {
    ProcessHistorySnapshot(
        identity: ProcessIdentity(pid: pid, startTime: 0),
        executablePath: executablePath,
        latestCPUUsagePercent: cpuUsagePercent,
        recentValues: [ProcessRankingSample(cpuUsagePercent: cpuUsagePercent, residentBytes: residentBytes)],
        memoryBaselines: [],
        isTranslated: isTranslated
    )
}

// MARK: - 그래프 점의 연속 구간 분리

/// task-008 검증 조건이 고정하는 것: "빈 구간을 직선으로 잇지 않는다".
/// 간격이 벌어진 점 쌍이 하나의 연결 구간에 포함되면 실패하도록 연결 구간 목록을 단언하며,
/// 간격 판정을 제거하면(모든 점을 구간 하나로 합치면) 이 테스트가 실패해야 합니다.
struct HistoryPointConnectedSegmentsTests {

    @Test func emptyPointsProduceNoSegments() {
        #expect(HistoryPoint.connectedSegments(from: []).isEmpty)
    }

    @Test func singlePointProducesOneSegmentWithThatPoint() {
        let point = HistoryPoint(timestamp: baseInstant, value: 10)

        let segments = HistoryPoint.connectedSegments(from: [point])

        #expect(segments == [[point]])
    }

    @Test func adjacentPointsWithinGapStayInOneSegment() {
        let points = (0..<5).map { HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(Double($0))), value: Double($0)) }

        let segments = HistoryPoint.connectedSegments(from: points)

        #expect(segments.count == 1)
        #expect(segments.first?.count == 5)
    }

    /// 중지 구간을 포함한 이력: 정상 구간 두 tick, 큰 간격, 정상 구간 두 tick 순서로 넣으면
    /// 두 개의 분리된 구간이 나와야 합니다. 이 판정을 지우면(항상 하나로 합치면) 이 단언이 실패합니다.
    @Test func gapLargerThanMaximumSplitsIntoSeparateSegments() {
        let gap = HistoryPoint.maximumConnectedGap + .seconds(1)
        let points = [
            HistoryPoint(timestamp: baseInstant, value: 10),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(1)), value: 20),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(1)) + gap, value: 30),
            HistoryPoint(timestamp: baseInstant.advanced(by: .seconds(1)) + gap + .seconds(1), value: 40),
        ]

        let segments = HistoryPoint.connectedSegments(from: points)

        #expect(segments.count == 2)
        #expect(segments[0].count == 2)
        #expect(segments[1].count == 2)
    }

    @Test func gapExactlyAtMaximumStaysConnected() {
        let points = [
            HistoryPoint(timestamp: baseInstant, value: 10),
            HistoryPoint(timestamp: baseInstant + HistoryPoint.maximumConnectedGap, value: 20),
        ]

        let segments = HistoryPoint.connectedSegments(from: points)

        #expect(segments.count == 1)
    }
}

// MARK: - 그래프 가로축: 오른쪽 끝은 그리는 시점의 시각(재작업 회귀 고정)

/// task-008 검증 조건이 고정하는 것: "가로축 오른쪽 끝이 그리는 시점의 시각이라 마지막 샘플이
/// 오래된 상황에서도 빈 구간이 제자리에 보입니다".
/// 창의 오른쪽 끝을 점 자신의 시각(`timestamp`)이 아니라 항상 별도로 주어지는 `currentTimestamp`로 고정해야 하며,
/// 이 판정을 지우고 오른쪽 끝을 마지막 점의 시각으로 되돌리면(예: `currentTimestamp` 대신 `timestamp` 자체를
/// 창 끝으로 쓰면) 아래 단언들이 실패해야 합니다.
struct HistoryPointNormalizedXPositionTests {

    /// 낡은 마지막 샘플의 정규화 좌표가 1(오른쪽 끝)에 들러붙지 않고, 실제 경과 시간만큼 왼쪽으로 밀려납니다.
    /// 오른쪽 끝을 `timestamp` 자체로 되돌리면 이 값이 항상 1이 되어 실패합니다.
    @Test func staleLastSampleDoesNotStickToRightEdge() {
        let staleSampleTimestamp = baseInstant
        // 그리는 시점(currentTimestamp)이 마지막 샘플보다 300초(5분) 뒤입니다 — 예를 들어 중지 구간에서
        // 카드 갱신 자체가 없었던 사이 시간이 그만큼 흘렀다는 뜻입니다.
        let currentTimestamp = baseInstant.advanced(by: .seconds(300))

        let position = HistoryPoint.normalizedXPosition(for: staleSampleTimestamp, currentTimestamp: currentTimestamp)

        // 10분 창에서 5분 전 점은 왼쪽에서 절반 지점(0.5)에 있어야 하며, 결코 오른쪽 끝(1.0)이 아닙니다.
        #expect(abs(position - 0.5) < 0.0001)
        #expect(position < 0.99)
    }

    /// 그리는 시점 자신(`currentTimestamp`)에 찍힌 점만 오른쪽 끝(1.0)에 옵니다.
    @Test func pointAtCurrentTimestampIsAtRightEdge() {
        let position = HistoryPoint.normalizedXPosition(for: baseInstant, currentTimestamp: baseInstant)

        #expect(abs(position - 1.0) < 0.0001)
    }

    /// 창의 왼쪽 끝(`currentTimestamp - timeRange`)에 있는 점은 좌표 0입니다.
    @Test func pointAtWindowStartIsAtLeftEdge() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(600))

        let position = HistoryPoint.normalizedXPosition(for: baseInstant, currentTimestamp: currentTimestamp)

        #expect(abs(position) < 0.0001)
    }
}

// MARK: - CPU 카드 조립

/// task-008 검증 조건: 빈 이력, 중지 구간을 포함한 이력, 10분을 넘는 이력,
/// TOP 5가 5개 미만·초과인 입력을 각각 단언합니다.
struct CPUCardPresentationAssembleTests {

    @Test func emptyHistoryProducesEmptyGraphPoints() {
        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(),
            history: [],
            topApplications: [],
            currentTimestamp: baseInstant
        )

        #expect(presentation.graphPoints.isEmpty)
        #expect(presentation.overallUsage == 42)
        #expect(presentation.userRatio == 30)
        #expect(presentation.systemRatio == 12)
    }

    /// 중지 구간을 포함한 이력이 그래프 점으로는 그대로 옮겨지되(값 자체를 지어내지 않음),
    /// 연결 구간 분리는 `HistoryPoint.connectedSegments`가 별도로 담당합니다.
    @Test func historyWithGapCarriesAllPointsIntoGraphPoints() {
        let history = [
            historyPoint(secondsFromBase: 0, overallCPUUsage: 10),
            historyPoint(secondsFromBase: 1, overallCPUUsage: 20),
            historyPoint(secondsFromBase: 100, overallCPUUsage: 30),
        ]

        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(),
            history: history,
            topApplications: [],
            currentTimestamp: baseInstant.advanced(by: .seconds(100))
        )

        #expect(presentation.graphPoints.map(\.value) == [10, 20, 30])
        let segments = HistoryPoint.connectedSegments(from: presentation.graphPoints)
        #expect(segments.count == 2, "정상 간격 두 점과 큰 간격 뒤 점이 분리된 구간으로 나뉘어야 합니다.")
    }

    /// 10분을 넘는 이력: 창 밖의 오래된 점은 그래프에 포함되지 않습니다.
    @Test func pointsOlderThanTenMinuteWindowAreExcluded() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(700))
        let history = [
            historyPoint(secondsFromBase: 0, overallCPUUsage: 1),  // 700초 전: 창(600초) 밖
            historyPoint(secondsFromBase: 50, overallCPUUsage: 2), // 650초 전: 창 밖
            historyPoint(secondsFromBase: 200, overallCPUUsage: 3), // 500초 전: 창 안
            historyPoint(secondsFromBase: 700, overallCPUUsage: 4), // 0초 전: 창 안
        ]

        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(),
            history: history,
            topApplications: [],
            currentTimestamp: currentTimestamp
        )

        #expect(presentation.graphPoints.map(\.value) == [3, 4])
    }

    @Test func fewerThanFiveTopApplicationsArePassedThroughUnchanged() {
        let entries = [rankingEntry(name: "A", value: 10), rankingEntry(name: "B", value: 5)]

        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(),
            history: [],
            topApplications: entries,
            currentTimestamp: baseInstant
        )

        #expect(presentation.topApplications == entries)
    }

    @Test func moreThanFiveTopApplicationsAreTrimmedToFive() {
        let entries = (0..<8).map { rankingEntry(name: "App\($0)", value: Double(8 - $0)) }

        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(),
            history: [],
            topApplications: entries,
            currentTimestamp: baseInstant
        )

        #expect(presentation.topApplications.count == 5)
        #expect(presentation.topApplications == Array(entries.prefix(5)))
    }
}

// MARK: - 접근성 이름

/// task-008 검증 조건: 카드의 접근성 이름에 현재 사용률과 상태, TOP 5의 안내 문구가 포함됩니다.
struct CPUCardAccessibilityLabelTests {

    @Test func collectingStateDescribesCollectingWithoutAUsageValue() {
        let state = ResourceCardState<CPUCardPresentation>.collecting

        #expect(state.cpuAccessibilityLabel.contains("수집 중"))
    }

    /// task-010(재작업, DP15) 검증 조건: 단축키의 존재가 카드 접근성 이름에서 확인되어야 하며,
    /// 수집 중 상태에서도(값이 아직 없어도) 단축키 발견 가능성이 유지되어야 합니다.
    @Test func collectingStateIncludesSelectionShortcut() {
        let state = ResourceCardState<CPUCardPresentation>.collecting

        #expect(state.cpuAccessibilityLabel.contains(CPUCardPresentation.selectionShortcutDisplayText))
    }

    @Test func normalStateIncludesUsageAndTopApplicationsCaption() {
        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(overallUsage: 55, userRatio: 40, systemRatio: 15),
            history: [],
            topApplications: [],
            currentTimestamp: baseInstant
        )
        let state = ResourceCardState.normal(presentation, timestamp: baseInstant)

        let label = state.cpuAccessibilityLabel
        #expect(label.contains("55"))
        #expect(label.contains(CPUCardPresentation.topApplicationsCaption))
    }

    /// task-010(재작업, DP15) 검증 조건: 단축키 안내는 조립 함수(`assemble(_:)`)를 거친 정상 상태에서도
    /// 접근성 이름에 포함되어야 합니다.
    @Test func normalStateIncludesSelectionShortcut() {
        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(), history: [], topApplications: [], currentTimestamp: baseInstant
        )
        let state = ResourceCardState.normal(presentation, timestamp: baseInstant)

        #expect(state.cpuAccessibilityLabel.contains(CPUCardPresentation.selectionShortcutDisplayText))
    }
}

// MARK: - DashboardPresentationStore: 항상 최신 표시 상태를 보유(DP10)

@MainActor
struct DashboardPresentationStoreTests {

    @Test func startsInCollectingStateBeforeAnyUpdate() {
        let store = DashboardPresentationStore()

        #expect(store.cpuCard == .collecting)
    }

    @Test func firstSuccessfulTickMovesCardToNormal() {
        let store = DashboardPresentationStore()
        let displayValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics()), memory: .success(memoryMetricsForTests()))
            ),
            recentHistory: []
        )

        store.updateCPUCard(with: displayValue, topApplications: [], currentTimestamp: baseInstant)

        guard case .normal(let presentation, let timestamp) = store.cpuCard else {
            Issue.record("정상 상태로 바뀌지 않았습니다.")
            return
        }
        #expect(presentation.overallUsage == 42)
        #expect(timestamp == baseInstant)
    }

    /// DP10이 고정하는 것: 한 번 정상 표시로 바뀐 카드는, 값을 만들지 못한 tick이나 실패 tick이 와도
    /// 다시 수집 중으로 되돌아가지 않고 마지막으로 성립한 표시 상태를 그대로 유지합니다.
    @Test func cardNeverRegressesToCollectingAfterShowingARealValue() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics()), memory: .success(memoryMetricsForTests()))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)

        let valuelessTick = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(1)),
                value: SystemMetricsSample(cpu: .success(nil), memory: .success(memoryMetricsForTests()))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: valuelessTick, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))

        guard case .normal = store.cpuCard else {
            Issue.record("값 없는 tick 뒤 카드가 수집 중으로 되돌아갔습니다.")
            return
        }
    }

    @Test func noLatestSampleKeepsCardCollecting() {
        let store = DashboardPresentationStore()
        let displayValue = SystemMetricsDisplayValue(latest: nil, recentHistory: [])

        store.updateCPUCard(with: displayValue, topApplications: [], currentTimestamp: baseInstant)

        #expect(store.cpuCard == .collecting)
    }
}

private func memoryMetricsForTests(
    swapUsedBytes: UInt64 = 0,
    pressureLevel: MemoryPressureLevel = .normal,
    usedBytes: UInt64 = 8 * 1024 * 1024 * 1024
) -> MemorySystemMetrics {
    MemorySystemMetrics(
        totalPhysicalBytes: 16 * 1024 * 1024 * 1024,
        usedBytes: usedBytes,
        appBytes: 4 * 1024 * 1024 * 1024,
        wiredBytes: 2 * 1024 * 1024 * 1024,
        compressedBytes: 2 * 1024 * 1024 * 1024,
        cachedBytes: 1024 * 1024 * 1024,
        swapUsedBytes: swapUsedBytes,
        pressureLevel: pressureLevel
    )
}

private func swapHistoryPoint(secondsFromBase: Double, swapUsedBytes: UInt64) -> SystemMetricsHistoryPoint {
    SystemMetricsHistoryPoint(
        timestamp: baseInstant.advanced(by: .seconds(secondsFromBase)),
        overallCPUUsage: 0,
        swapUsedBytes: swapUsedBytes
    )
}

// MARK: - Memory Pressure 단계 표시: 색상 없이 라벨·기호로 구분(SPEC §5.5)

/// task-009 검증 조건이 고정하는 것: "색상만으로 단계를 구분하지 않는다".
/// 색상 속성은 애초에 이 타입에 없으므로, 라벨과 기호 식별자만으로 세 단계가 모두 다른지 단언합니다.
/// 기호나 라벨을 한 값으로 통일하면(예: 세 단계 모두 같은 symbolName을 쓰면) 이 테스트가 실패해야 합니다.
struct MemoryPressureLevelDisplayTests {

    @Test func allThreeLevelsHaveDistinctLabelsAndSymbols() {
        let displays: [MemoryPressureDisplay] = [
            MemoryPressureLevel.normal.display,
            MemoryPressureLevel.warning.display,
            MemoryPressureLevel.critical.display,
        ]

        let labels = Set(displays.map(\.label))
        let symbols = Set(displays.map(\.symbolName))

        #expect(labels.count == 3, "세 단계의 라벨이 모두 달라야 합니다.")
        #expect(symbols.count == 3, "세 단계의 기호가 모두 달라야 합니다.")
    }

    /// 경고·위험에서 정상으로 돌아오면 표시가 최초 정상 표시와 완전히 같아져야 합니다(위험 → 정상 순서).
    @Test func returningToNormalFromCriticalMatchesInitialNormalDisplay() {
        let initialNormal = MemoryPressureLevel.normal.display
        let afterCriticalThenNormal = MemoryPressureLevel.critical.display
        let backToNormal = MemoryPressureLevel.normal.display

        #expect(backToNormal == initialNormal)
        #expect(backToNormal != afterCriticalThenNormal)
    }
}

// MARK: - Memory 카드 조립

/// task-009 검증 조건: Swap 최근 변화량의 10분 창 경계 직전·직후 기준점과 값이 하나뿐인 입력을 검증합니다.
struct MemoryCardPresentationAssembleTests {

    @Test func emptyHistoryProducesNoSwapChange() {
        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(swapUsedBytes: 100),
            history: [],
            topApplications: [],
            currentTimestamp: baseInstant
        )

        #expect(presentation.swapRecentChangeBytes == nil)
        #expect(presentation.swapUsedBytes == 100)
    }

    /// 창 안에 값이 하나뿐인 입력: 이력에 현재 tick 하나만 있으면(그보다 앞선 기준점이 없으면) 변화량을 만들지 않습니다.
    ///
    /// `currentTimestamp`는 이력 점과 같은 시각이 아니라 그보다 늦은 시각으로 줍니다 — production에서
    /// `ApplicationCoordinator`는 이력에 값을 넣은 뒤 별도로 관찰한 `ContinuousClock().now`를 넘기므로 항상 이력의
    /// 어떤 시각보다도 늦습니다. 이 관계를 재현하지 않고 같은 시각을 주면, 방금 이 tick이 만든 점 자신을 기준점으로
    /// 삼아 `swapRecentChangeBytes == 0`을 돌려주는 회귀(이력의 어떤 값도 현재 시각보다 이른지 여부만으로 기준점을
    /// 찾던 예전 구현)를 이 테스트가 잡아내지 못합니다.
    @Test func singleValueWithinWindowProducesNoSwapChange() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(15))
        let history = [swapHistoryPoint(secondsFromBase: 10, swapUsedBytes: 500)]

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(swapUsedBytes: 500),
            history: history,
            topApplications: [],
            currentTimestamp: currentTimestamp
        )

        #expect(presentation.swapRecentChangeBytes == nil)
    }

    /// 10분 창 경계 바로 안(포함)의 기준점은 변화량 계산에 쓰입니다.
    @Test func baselineExactlyAtWindowStartIsIncluded() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(600))
        let history = [
            swapHistoryPoint(secondsFromBase: 0, swapUsedBytes: 100), // 정확히 600초 전 = 창의 왼쪽 끝
            swapHistoryPoint(secondsFromBase: 600, swapUsedBytes: 300),
        ]

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(swapUsedBytes: 300),
            history: history,
            topApplications: [],
            currentTimestamp: currentTimestamp
        )

        #expect(presentation.swapRecentChangeBytes == 200)
    }

    /// 10분 창 밖(경계 직전, 601초 전)의 기준점은 변화량 계산에 쓰이지 않습니다.
    @Test func baselineJustBeforeWindowStartIsExcluded() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(601))
        let history = [
            swapHistoryPoint(secondsFromBase: 0, swapUsedBytes: 100), // 601초 전 = 창 밖
            swapHistoryPoint(secondsFromBase: 601, swapUsedBytes: 300),
        ]

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(swapUsedBytes: 300),
            history: history,
            topApplications: [],
            currentTimestamp: currentTimestamp
        )

        #expect(presentation.swapRecentChangeBytes == nil, "창 밖의 기준점을 써서 변화량을 만들면 안 됩니다.")
    }

    @Test func swapChangeCanBeNegativeWhenSwapDecreases() {
        let currentTimestamp = baseInstant.advanced(by: .seconds(60))
        let history = [
            swapHistoryPoint(secondsFromBase: 0, swapUsedBytes: 500),
            swapHistoryPoint(secondsFromBase: 60, swapUsedBytes: 200),
        ]

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(swapUsedBytes: 200),
            history: history,
            topApplications: [],
            currentTimestamp: currentTimestamp
        )

        #expect(presentation.swapRecentChangeBytes == -300)
    }

    @Test func moreThanFiveTopApplicationsAreTrimmedToFive() {
        let entries = (0..<8).map { rankingEntry(name: "App\($0)", value: Double(8 - $0)) }

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(),
            history: [],
            topApplications: entries,
            currentTimestamp: baseInstant
        )

        #expect(presentation.topApplications.count == 5)
        #expect(presentation.topApplications == Array(entries.prefix(5)))
    }

    @Test func fewerThanFiveTopApplicationsArePassedThroughUnchanged() {
        let entries = [rankingEntry(name: "A", value: 10), rankingEntry(name: "B", value: 5)]

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(),
            history: [],
            topApplications: entries,
            currentTimestamp: baseInstant
        )

        #expect(presentation.topApplications == entries)
    }
}

// MARK: - Memory 카드 접근성 이름

/// task-009 검증 조건: 카드 접근성 이름에 현재 단계와 사용 중 메모리가 포함됩니다.
struct MemoryCardAccessibilityLabelTests {

    @Test func collectingStateDescribesCollectingWithoutAValue() {
        let state = ResourceCardState<MemoryCardPresentation>.collecting

        #expect(state.memoryAccessibilityLabel.contains("수집 중"))
    }

    /// task-010(재작업, DP15) 검증 조건: 단축키의 존재가 카드 접근성 이름에서 확인되어야 합니다.
    @Test func collectingStateIncludesSelectionShortcut() {
        let state = ResourceCardState<MemoryCardPresentation>.collecting

        #expect(state.memoryAccessibilityLabel.contains(MemoryCardPresentation.selectionShortcutDisplayText))
    }

    @Test func normalStateIncludesPressureLevelAndUsedMemory() {
        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(pressureLevel: .warning),
            history: [],
            topApplications: [],
            currentTimestamp: baseInstant
        )
        let state = ResourceCardState.normal(presentation, timestamp: baseInstant)

        let label = state.memoryAccessibilityLabel
        #expect(label.contains("경고"))
        #expect(label.contains("사용 중 메모리"))
        #expect(label.contains(MemoryCardPresentation.topApplicationsCaption))
        #expect(label.contains(MemoryCardPresentation.selectionShortcutDisplayText))
    }
}

// MARK: - DashboardPresentationStore: Memory 카드도 항상 최신 표시 상태를 보유(DP10)

@MainActor
struct DashboardMemoryPresentationStoreTests {

    @Test func startsInCollectingStateBeforeAnyUpdate() {
        let store = DashboardPresentationStore()

        #expect(store.memoryCard == .collecting)
    }

    @Test func firstSuccessfulTickMovesCardToNormal() {
        let store = DashboardPresentationStore()
        let displayValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics()), memory: .success(memoryMetricsForTests()))
            ),
            recentHistory: []
        )

        store.updateMemoryCard(with: displayValue, topApplications: [], currentTimestamp: baseInstant)

        guard case .normal(let presentation, let timestamp) = store.memoryCard else {
            Issue.record("정상 상태로 바뀌지 않았습니다.")
            return
        }
        #expect(presentation.usedBytes == 8 * 1024 * 1024 * 1024)
        #expect(timestamp == baseInstant)
    }

    /// 해석할 수 없는 Memory Pressure 원시값은 Collector 단계에서 이미 `CollectorFailure`로 바뀌어
    /// `SystemMetricsSample.memory`가 `.failure`가 됩니다. 이 tick에서는 카드가 임의 단계로 바뀌지 않고
    /// `.failure` 상태로 바뀌어 그 사실을 나타내되, 마지막 성공 값과 그 시각을 그대로 물려받습니다(task-011).
    @Test func memoryFailureTickBecomesFailureStateKeepingLastKnownValue() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics()), memory: .success(memoryMetricsForTests(pressureLevel: .normal)))
            ),
            recentHistory: []
        )
        store.updateMemoryCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)

        let unsupportedPressureValueFailure = CollectorFailure(
            metric: .memory,
            cause: .unsupportedValue(name: "kern.memorystatus_vm_pressure_level", rawValue: 0x03)
        )
        let failureValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(1)),
                value: SystemMetricsSample(cpu: .success(cpuMetrics()), memory: .failure(unsupportedPressureValueFailure))
            ),
            recentHistory: []
        )
        store.updateMemoryCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))

        guard case .failure(let lastKnown) = store.memoryCard, let lastKnown else {
            Issue.record("실패 tick 뒤 카드가 실패 상태로 바뀌지 않았거나 마지막 성공 값을 잃었습니다.")
            return
        }
        #expect(lastKnown.presentation.pressureDisplay == MemoryPressureLevel.normal.display, "임의 단계로 바뀌면 안 됩니다.")
        #expect(lastKnown.timestamp == baseInstant, "마지막 성공 시각이 유지되어야 합니다.")
    }

    @Test func noLatestSampleKeepsCardCollecting() {
        let store = DashboardPresentationStore()
        let displayValue = SystemMetricsDisplayValue(latest: nil, recentHistory: [])

        store.updateMemoryCard(with: displayValue, topApplications: [], currentTimestamp: baseInstant)

        #expect(store.memoryCard == .collecting)
    }
}

// MARK: - task-011: 지표별 실패의 카드 격리

/// task-011 검증 조건이 고정하는 두 가지 —
/// "실패를 0으로 바꾸지 않는다"(실패 tick 뒤 카드 값이 마지막 성공 값과 같고 0이 아님),
/// "한 지표의 실패가 다른 카드를 실패로 만들지 않는다"(실패 tick에서 반대편 카드가 정상이고 값이 그 tick의 값과 같음).
/// 아래 두 단언을 한 테스트 안에서 함께 확인하므로, CPU·Memory 카드 갱신을 하나의 분기로 합치면
/// 어느 한쪽이 실패해야 합니다.
@MainActor
struct DashboardCardFailureIsolationTests {

    private let cpuFailure = CollectorFailure(metric: .cpu, cause: .systemCall(name: "host_processor_info", code: 5))
    private let memoryFailure = CollectorFailure(
        metric: .memory,
        cause: .unsupportedValue(name: "kern.memorystatus_vm_pressure_level", rawValue: 0x03)
    )

    @Test func cpuFailureLeavesMemoryCardNormalWithThatTickValueAndKeepsCPULastKnownValueNonZero() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 42)), memory: .success(memoryMetricsForTests()))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        store.updateMemoryCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)

        let failureValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(1)),
                value: SystemMetricsSample(cpu: .failure(cpuFailure), memory: .success(memoryMetricsForTests(usedBytes: 999)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))
        store.updateMemoryCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))

        guard case .failure(let lastKnown) = store.cpuCard, let lastKnown else {
            Issue.record("CPU 카드가 실패 상태로 바뀌지 않았거나 마지막 값을 잃었습니다.")
            return
        }
        #expect(lastKnown.presentation.overallUsage == 42, "실패가 값을 0으로 바꾸면 안 됩니다.")

        guard case .normal(let memoryPresentation, _) = store.memoryCard else {
            Issue.record("CPU 실패가 Memory 카드까지 실패로 만들었습니다.")
            return
        }
        #expect(memoryPresentation.usedBytes == 999, "Memory 카드는 그 tick의 값으로 계속 갱신되어야 합니다.")
    }

    @Test func memoryFailureLeavesCPUCardNormalWithThatTickValueAndKeepsMemoryLastKnownValueNonZero() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics()), memory: .success(memoryMetricsForTests(usedBytes: 500)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        store.updateMemoryCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)

        let failureValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(1)),
                value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 77)), memory: .failure(memoryFailure))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))
        store.updateMemoryCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))

        guard case .failure(let lastKnown) = store.memoryCard, let lastKnown else {
            Issue.record("Memory 카드가 실패 상태로 바뀌지 않았거나 마지막 값을 잃었습니다.")
            return
        }
        #expect(lastKnown.presentation.usedBytes == 500, "실패가 값을 0으로 바꾸면 안 됩니다.")

        guard case .normal(let cpuPresentation, _) = store.cpuCard else {
            Issue.record("Memory 실패가 CPU 카드까지 실패로 만들었습니다.")
            return
        }
        #expect(cpuPresentation.overallUsage == 77, "CPU 카드는 그 tick의 값으로 계속 갱신되어야 합니다.")
    }

    @Test func bothMetricsFailingInTheSameTickMakesBothCardsFailWithTheirOwnLastKnownValue() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 33)), memory: .success(memoryMetricsForTests(usedBytes: 700)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        store.updateMemoryCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)

        let failureValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(1)),
                value: SystemMetricsSample(cpu: .failure(cpuFailure), memory: .failure(memoryFailure))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))
        store.updateMemoryCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))

        guard case .failure(let cpuLastKnown) = store.cpuCard, let cpuLastKnown else {
            Issue.record("CPU 카드가 실패 상태로 바뀌지 않았습니다.")
            return
        }
        #expect(cpuLastKnown.presentation.overallUsage == 33)

        guard case .failure(let memoryLastKnown) = store.memoryCard, let memoryLastKnown else {
            Issue.record("Memory 카드가 실패 상태로 바뀌지 않았습니다.")
            return
        }
        #expect(memoryLastKnown.presentation.usedBytes == 700)
    }

    /// 성공 이력이 없는 상태에서의 실패는 `collecting`과 구분되어야 합니다.
    @Test func failureWithoutAnySuccessHistoryIsDistinctFromCollecting() {
        let store = DashboardPresentationStore()
        let failureValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .failure(cpuFailure), memory: .success(memoryMetricsForTests()))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant)

        guard case .failure(let lastKnown) = store.cpuCard else {
            Issue.record("성공 이력이 없는 실패가 실패 상태로 나타나지 않았습니다.")
            return
        }
        #expect(lastKnown == nil, "성공 이력이 없으면 마지막 값도 없어야 합니다.")
        #expect(store.cpuCard != .collecting, "성공 이력 없는 실패는 수집 중과 구분되어야 합니다.")
        #expect(
            store.cpuCard.cpuAccessibilityLabel != ResourceCardState<CPUCardPresentation>.collecting.cpuAccessibilityLabel,
            "접근성 이름에서도 수집 중과 구분되어야 합니다."
        )
    }

    /// 프로세스 조사 실패는 두 카드의 TOP 5만 실패로 바꾸고 시스템 지표 수치는 그대로 둡니다.
    @Test func processSurveyFailureMarksOnlyTopApplicationsFailedKeepingSystemMetrics() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 61)), memory: .success(memoryMetricsForTests(usedBytes: 321)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], topApplicationsFailed: true, currentTimestamp: baseInstant)
        store.updateMemoryCard(with: successValue, topApplications: [], topApplicationsFailed: true, currentTimestamp: baseInstant)

        guard case .normal(let cpuPresentation, _) = store.cpuCard else {
            Issue.record("프로세스 조사 실패가 CPU 카드 전체를 실패로 만들면 안 됩니다.")
            return
        }
        #expect(cpuPresentation.overallUsage == 61, "시스템 지표 수치는 그대로 표시되어야 합니다.")
        #expect(cpuPresentation.topApplicationsFailed)

        guard case .normal(let memoryPresentation, _) = store.memoryCard else {
            Issue.record("프로세스 조사 실패가 Memory 카드 전체를 실패로 만들면 안 됩니다.")
            return
        }
        #expect(memoryPresentation.usedBytes == 321, "시스템 지표 수치는 그대로 표시되어야 합니다.")
        #expect(memoryPresentation.topApplicationsFailed)
    }

    /// 실패가 카드 선택 상태를 바꾸지 않습니다(task-010이 세운 동작, 새 실패 상태에서도 유지되어야 함).
    @Test func failureDoesNotChangeCardSelection() {
        let store = DashboardPresentationStore()
        store.selectCard(.cpu)

        let failureValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .failure(cpuFailure), memory: .failure(memoryFailure))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant)
        store.updateMemoryCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant)

        #expect(store.selection == .cpu)
    }
}

// MARK: - task-011: 일정 중지·재개 전이

/// task-011 검증 조건: 중지는 표시 저장소에 중지 전이를 넣어 두 카드가 마지막 성공 값을 유지한 채 중지가
/// 되는지, 재개만으로는 상태가 바뀌지 않고 값이 성립한 첫 tick에서 풀리는지를 확인합니다.
/// CPU는 재개 첫 tick이 기준점만 갱신하므로(§5 DP11) Memory보다 한 tick 늦게 풀립니다.
@MainActor
struct DashboardCollectionStoppedTests {

    @Test func markCollectionStoppedFreezesBothCardsWithLastKnownValues() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 42)), memory: .success(memoryMetricsForTests(usedBytes: 555)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        store.updateMemoryCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)

        store.markCollectionStopped()

        guard case .stopped(let cpuLastKnown) = store.cpuCard, let cpuLastKnown else {
            Issue.record("CPU 카드가 중지 상태로 바뀌지 않았거나 마지막 값을 잃었습니다.")
            return
        }
        #expect(cpuLastKnown.presentation.overallUsage == 42)

        guard case .stopped(let memoryLastKnown) = store.memoryCard, let memoryLastKnown else {
            Issue.record("Memory 카드가 중지 상태로 바뀌지 않았거나 마지막 값을 잃었습니다.")
            return
        }
        #expect(memoryLastKnown.presentation.usedBytes == 555)
    }

    /// 성공 이력이 없는 상태에서 곧바로 중지되면 마지막 값 없이 `.stopped(lastKnown: nil)`이 되어야 합니다.
    @Test func stoppingBeforeAnySuccessProducesStoppedWithoutLastKnownValue() {
        let store = DashboardPresentationStore()

        store.markCollectionStopped()

        guard case .stopped(let lastKnown) = store.cpuCard else {
            Issue.record("중지 상태로 바뀌지 않았습니다.")
            return
        }
        #expect(lastKnown == nil)
    }

    @Test func resumeAloneDoesNotChangeStateOnlyANextValueBearingTickDoes() {
        let store = DashboardPresentationStore()
        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 42)), memory: .success(memoryMetricsForTests(usedBytes: 555)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        store.updateMemoryCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        store.markCollectionStopped()

        // 재개 첫 tick: CPU는 기준점만 갱신하므로(`.success(nil)`) 중지가 유지되고,
        // Memory는 순간값 조회라 곧바로 중지가 풀립니다.
        let resumeFirstTick = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(100)),
                value: SystemMetricsSample(cpu: .success(nil), memory: .success(memoryMetricsForTests(usedBytes: 111)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: resumeFirstTick, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(100)))
        store.updateMemoryCard(with: resumeFirstTick, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(100)))

        guard case .stopped = store.cpuCard else {
            Issue.record("CPU는 재개 첫 tick(기준점 갱신)에서 중지 상태를 유지해야 합니다.")
            return
        }
        guard case .normal(let memoryPresentation, _) = store.memoryCard else {
            Issue.record("Memory는 재개 첫 tick에서 곧바로 중지가 풀려야 합니다.")
            return
        }
        #expect(memoryPresentation.usedBytes == 111)

        // 값이 성립하는 다음 tick에서 CPU도 중지가 풀립니다.
        let resumeSecondTick = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(101)),
                value: SystemMetricsSample(cpu: .success(cpuMetrics(overallUsage: 55)), memory: .success(memoryMetricsForTests(usedBytes: 111)))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: resumeSecondTick, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(101)))

        guard case .normal(let cpuPresentation, _) = store.cpuCard else {
            Issue.record("값이 성립한 tick에서 CPU 중지가 풀려야 합니다.")
            return
        }
        #expect(cpuPresentation.overallUsage == 55)
    }
}

// MARK: - task-010: 앱별 하위 프로세스 그룹

/// `ApplicationRankingSample`은 앱 키별 합산값만 담고 그 키에 속한 개별 프로세스 목록을 담지 않으므로,
/// "앱 항목을 펼치면 하위 프로세스가 나타난다"(SPEC §5.2, SPEC §5.6)를 만족하려면 `groupByApplication(_:)`가
/// `ProcessHistoryStore.snapshot()` 결과를 별도로 순회해야 합니다. 이 테스트가 그 계산을 검증합니다.
struct ApplicationProcessGroupingTests {

    @Test func processesUnderSameBundleAreGroupedTogether() throws {
        let mainProcess = processHistorySnapshot(
            pid: 100, executablePath: "/Applications/Kiro.app/Contents/MacOS/Electron",
            cpuUsagePercent: 10, residentBytes: 1_000
        )
        let helperProcess = processHistorySnapshot(
            pid: 101,
            executablePath: "/Applications/Kiro.app/Contents/Frameworks/Kiro Helper (Renderer).app/Contents/MacOS/Kiro Helper (Renderer)",
            cpuUsagePercent: 15, residentBytes: 2_000, isTranslated: true
        )
        let otherApp = processHistorySnapshot(
            pid: 200, executablePath: "/Applications/Other.app/Contents/MacOS/Other",
            cpuUsagePercent: 5, residentBytes: 500
        )

        let (groups, _) = ApplicationRanking.groupByApplication(
            snapshots: [mainProcess, helperProcess, otherApp],
            resolver: ApplicationIdentityResolver()
        )

        #expect(groups.count == 2)
        let kiroGroup = try #require(groups.first { $0.displayName == "Kiro" })
        #expect(kiroGroup.processes.count == 2)
        #expect(Set(kiroGroup.processes.map(\.pid)) == [100, 101])

        let helperDetail = try #require(kiroGroup.processes.first { $0.pid == 101 })
        #expect(helperDetail.cpuUsagePercent == 15)
        #expect(helperDetail.residentBytes == 2_000)
        #expect(helperDetail.isTranslated, "Rosetta 여부가 그대로 전달되어야 합니다.")

        let mainDetail = try #require(kiroGroup.processes.first { $0.pid == 100 })
        #expect(!mainDetail.isTranslated)

        let otherGroup = try #require(groups.first { $0.displayName == "Other" })
        #expect(otherGroup.processes.count == 1)
    }

    @Test func emptySnapshotsProduceNoGroups() {
        let (groups, _) = ApplicationRanking.groupByApplication(snapshots: [], resolver: ApplicationIdentityResolver())

        #expect(groups.isEmpty)
    }
}

// MARK: - task-010: 단위 라벨 구분(SPEC §5.2, SPEC §5.3)

/// 시스템 전체 CPU와 프로세스 CPU가 서로 다른 단위 라벨을 가져야 합니다 —
/// 프로세스 CPU는 코어 합산이라 100%를 넘을 수 있고, 두 라벨을 같은 문자열로 되돌리면 이 테스트가 실패해야 합니다.
struct CPUUnitLabelTests {

    @Test func overallAndProcessUsageUnitLabelsDiffer() {
        #expect(CPUCardPresentation.overallUsageUnitLabel != ApplicationProcessDetail.cpuUsageUnitLabel)
    }
}

// MARK: - task-010(재작업, DP15): 카드 선택·복귀 단축키

/// 두 카드가 서로 다른 단축키를 써야 동시에 활성화되는 충돌이 없습니다.
struct DashboardSelectionShortcutTests {

    @Test func cpuAndMemoryShortcutsDiffer() {
        #expect(CPUCardPresentation.selectionShortcutDisplayText != MemoryCardPresentation.selectionShortcutDisplayText)
    }
}

// MARK: - task-010: CPU 상세 조립

/// task-010 검증 조건: 상세 지표 구성은 항목 존재와 코어별 값 개수를 단언합니다.
struct CPUCardDetailAssembleTests {

    @Test func detailCarriesIdleRatioLoadAverageAndCoreUsageCount() {
        let cpu = CPUSystemMetrics(
            overallUsage: 42, userRatio: 30, systemRatio: 12, idleRatio: 58,
            coreUsages: [10, 20, 30, 40, 50, 60, 70, 80],
            loadAverage: LoadAverage(oneMinute: 1.5, fiveMinutes: 2.5, fifteenMinutes: 3.5)
        )

        let presentation = CPUCardPresentation.assemble(
            cpu: cpu, history: [], topApplications: [], currentTimestamp: baseInstant
        )

        #expect(presentation.detail.idleRatio == 58)
        #expect(presentation.detail.coreUsages.count == 8, "코어별 사용률 개수는 입력 그대로 전달되어야 합니다.")
        #expect(presentation.detail.loadAverage == cpu.loadAverage)
    }

    @Test func detailCarriesProcessGroupsThrough() {
        let (groups, _) = ApplicationRanking.groupByApplication(
            snapshots: [processHistorySnapshot(pid: 100, executablePath: "/bin/a", cpuUsagePercent: 10, residentBytes: 1_000)],
            resolver: ApplicationIdentityResolver()
        )

        let presentation = CPUCardPresentation.assemble(
            cpu: cpuMetrics(), history: [], topApplications: [], processGroups: groups, currentTimestamp: baseInstant
        )

        #expect(presentation.detail.applications == groups)
    }
}

// MARK: - task-010: Memory 상세 조립 — 현재 사용량과 증가량은 다른 목록

/// task-010 검증 조건: Memory 상세에 현재 사용량 순위와 최근 증가량 순위가 서로 다른 목록으로 나타납니다.
struct MemoryCardDetailAssembleTests {

    @Test func detailCarriesRawMemoryComponents() {
        let memory = memoryMetricsForTests()

        let presentation = MemoryCardPresentation.assemble(
            memory: memory, history: [], topApplications: [], currentTimestamp: baseInstant
        )

        #expect(presentation.detail.appBytes == memory.appBytes)
        #expect(presentation.detail.wiredBytes == memory.wiredBytes)
        #expect(presentation.detail.compressedBytes == memory.compressedBytes)
        #expect(presentation.detail.cachedBytes == memory.cachedBytes)
    }

    /// task-010(재작업) 검증 조건: Memory 상세에 Swap 사용량과 증가량이 나타나야 합니다.
    /// `MemoryDetailView`가 렌더링하는 값은 `detail`이 아니라 `presentation` 최상위 필드
    /// (`swapUsedBytes`·`swapRecentChangeBytes`, task-009가 이미 승인한 계산)이므로 여기서 함께 단언합니다.
    @Test func presentationCarriesSwapUsageAndRecentChange() {
        let memory = memoryMetricsForTests(swapUsedBytes: 500)
        // `swapRecentChangeBytes`는 창 안 가장 최신 값을 자기 자신의 기준점으로 삼지 않으므로(task-009),
        // 기준점(0초)과 현재 tick 자신(60초, `currentTimestamp`와 같은 시각)을 함께 이력에 넣어야 변화량이 나옵니다.
        let currentTimestamp = baseInstant.advanced(by: .seconds(60))
        let history = [
            swapHistoryPoint(secondsFromBase: 0, swapUsedBytes: 100),
            swapHistoryPoint(secondsFromBase: 60, swapUsedBytes: 500),
        ]

        let presentation = MemoryCardPresentation.assemble(
            memory: memory, history: history, topApplications: [], currentTimestamp: currentTimestamp
        )

        #expect(presentation.swapUsedBytes == 500)
        #expect(presentation.swapRecentChangeBytes == 400)
    }

    /// 10분 창 안에 이전 기준점이 없으면(이력이 비어 있으면) 변화량을 만들지 않고 `nil`이어야 합니다 —
    /// 값이 없는데 0으로 표시하면 안 되므로, 상세 화면이 이 경우를 구분해서 표시해야 합니다.
    @Test func presentationSwapRecentChangeIsNilWithoutABaseline() {
        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(swapUsedBytes: 500), history: [], topApplications: [], currentTimestamp: baseInstant
        )

        #expect(presentation.swapUsedBytes == 500)
        #expect(presentation.swapRecentChangeBytes == nil)
    }

    @Test func currentUsageRankingAndIncreaseRankingAreDistinctLists() {
        let currentUsageTop = [rankingEntry(name: "HeavyButStable", value: 10_000_000)]
        let increaseTop = [rankingEntry(name: "SmallButGrowing", value: 9_000_000)]

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(),
            history: [],
            topApplications: currentUsageTop,
            memoryIncrease: increaseTop,
            currentTimestamp: baseInstant
        )

        #expect(presentation.detail.currentUsageRanking == currentUsageTop)
        #expect(presentation.detail.recentIncreaseRanking == increaseTop)
        #expect(presentation.detail.currentUsageRanking != presentation.detail.recentIncreaseRanking)
    }

    /// 증가량 순위는 음수를 담을 수 있습니다(메모리가 줄어든 경우) — 이 값이 카드 표시에서 trap하지 않고
    /// 그대로 보관되는지 확인합니다. `TopApplicationsView`의 `UInt64` 변환 경로를 재사용하면 trap하는
    /// 회귀를 막는 것이 이 단언의 목적입니다.
    @Test func recentIncreaseRankingCanContainNegativeValues() {
        let negativeIncrease = [rankingEntry(name: "Shrunk", value: -500)]

        let presentation = MemoryCardPresentation.assemble(
            memory: memoryMetricsForTests(),
            history: [],
            topApplications: [],
            memoryIncrease: negativeIncrease,
            currentTimestamp: baseInstant
        )

        #expect(presentation.detail.recentIncreaseRanking.first?.value == -500)
    }
}

// MARK: - task-010: 카드 선택 상태 전이

/// task-010 검증 조건: 선택 없음 → CPU → 선택 없음, 선택 없음 → Memory → 선택 없음, CPU → Memory 전이가
/// 카드 활성화만으로 일어납니다.
@MainActor
struct DashboardSelectionTests {

    @Test func startsWithNoSelection() {
        let store = DashboardPresentationStore()

        #expect(store.selection == .none)
    }

    @Test func selectingCPUThenSameCardAgainReturnsToNoSelection() {
        let store = DashboardPresentationStore()

        store.selectCard(.cpu)
        #expect(store.selection == .cpu)

        store.selectCard(.cpu)
        #expect(store.selection == .none)
    }

    @Test func selectingMemoryThenSameCardAgainReturnsToNoSelection() {
        let store = DashboardPresentationStore()

        store.selectCard(.memory)
        #expect(store.selection == .memory)

        store.selectCard(.memory)
        #expect(store.selection == .none)
    }

    @Test func selectingMemoryWhileCPUIsSelectedSwitchesSelection() {
        let store = DashboardPresentationStore()

        store.selectCard(.cpu)
        store.selectCard(.memory)

        #expect(store.selection == .memory)
    }

    /// task-010이 고정하는 것: "수집 갱신이 선택을 초기화하지 않는다".
    /// 선택 상태에서 수집 결과 갱신과 지표 실패를 연속으로 넣고 선택이 유지되는지 단언하며,
    /// 선택을 표시 값과 함께 재생성하도록 되돌리면(예: 카드 갱신 시 selection도 `.none`으로 되돌리면) 이 테스트가 실패해야 합니다.
    @Test func selectionSurvivesRepeatedCardUpdatesAndFailures() {
        let store = DashboardPresentationStore()
        store.selectCard(.cpu)

        let successValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant,
                value: SystemMetricsSample(cpu: .success(cpuMetrics()), memory: .success(memoryMetricsForTests()))
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        #expect(store.selection == .cpu)

        let failureValue = SystemMetricsDisplayValue(
            latest: TimestampedSample(
                timestamp: baseInstant.advanced(by: .seconds(1)),
                value: SystemMetricsSample(
                    cpu: .failure(CollectorFailure(metric: .cpu, cause: .systemCall(name: "host_processor_info", code: 5))),
                    memory: .success(memoryMetricsForTests())
                )
            ),
            recentHistory: []
        )
        store.updateCPUCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))
        store.updateMemoryCard(with: failureValue, topApplications: [], currentTimestamp: baseInstant.advanced(by: .seconds(1)))
        #expect(store.selection == .cpu, "수집 실패가 선택 상태를 바꾸면 안 됩니다.")

        store.updateMemoryCard(with: successValue, topApplications: [], currentTimestamp: baseInstant)
        #expect(store.selection == .cpu, "다른 카드의 수집 갱신도 선택 상태를 바꾸면 안 됩니다.")
    }

    /// task-010 재작업이 고정하는 것: "팝업 자신의 닫힘"이 선택 해제로 이어집니다(ANALYSIS §2 「팝오버 열림과 카드 선택」, §5 DP14).
    /// `dismissDetail(for:)`를 무력화하면(예: 본문을 비우면) 이 단언이 실패해야 합니다.
    @Test func dismissDetailForSelectedCardClearsSelection() {
        let store = DashboardPresentationStore()
        store.selectCard(.cpu)
        #expect(store.selection == .cpu)

        store.dismissDetail(for: .cpu)
        #expect(store.selection == .none)
    }

    @Test func dismissDetailForSelectedMemoryCardClearsSelection() {
        let store = DashboardPresentationStore()
        store.selectCard(.memory)
        #expect(store.selection == .memory)

        store.dismissDetail(for: .memory)
        #expect(store.selection == .none)
    }

    /// 선택이 이미 다른 카드로 옮겨간 뒤(예: CPU 팝업이 열린 채 ⌘2로 Memory를 선택해 CPU 자식 팝오버가 닫히는 경우)라면,
    /// CPU 쪽의 뒤늦은 자기 닫힘 신호가 방금 옮겨간 Memory 선택을 지우면 안 됩니다 —
    /// 이 가드를 없애면(무조건 `.none`으로 지우면) 이 단언이 실패해야 합니다.
    @Test func dismissDetailForCardThatIsNoLongerSelectedDoesNotClearNewSelection() {
        let store = DashboardPresentationStore()
        store.selectCard(.cpu)
        store.selectCard(.memory)
        #expect(store.selection == .memory)

        store.dismissDetail(for: .cpu)
        #expect(store.selection == .memory, "이미 다른 카드로 옮겨간 선택을 지우면 안 됩니다.")
    }

    /// 선택 없음 상태에서의 자기 닫힘 신호도 안전하게 무시되어야 합니다.
    @Test func dismissDetailWhileNoSelectionStaysNone() {
        let store = DashboardPresentationStore()

        store.dismissDetail(for: .cpu)
        #expect(store.selection == .none)
    }
}
