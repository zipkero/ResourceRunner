//
//  DashboardCardLayoutTests.swift
//  ResourceRunnerTests
//
//  task-015 검증 조건: 카드 뷰의 렌더 높이가 수집 상태·TOP 5 항목 수·조사 실패 여부와 무관하게 같은지 확인합니다.
//

import SwiftUI
import Testing
@testable import ResourceRunner

private let baseInstant = ContinuousClock().now

private func cpuMetrics() -> CPUSystemMetrics {
    CPUSystemMetrics(
        overallUsage: 42,
        userRatio: 30,
        systemRatio: 12,
        idleRatio: 58,
        coreUsages: [42],
        loadAverage: LoadAverage(oneMinute: 0, fiveMinutes: 0, fifteenMinutes: 0)
    )
}

private func memoryMetrics() -> MemorySystemMetrics {
    MemorySystemMetrics(
        totalPhysicalBytes: 16 * 1024 * 1024 * 1024,
        usedBytes: 8 * 1024 * 1024 * 1024,
        appBytes: 4 * 1024 * 1024 * 1024,
        wiredBytes: 2 * 1024 * 1024 * 1024,
        compressedBytes: 2 * 1024 * 1024 * 1024,
        cachedBytes: 1024 * 1024 * 1024,
        swapUsedBytes: 0,
        pressureLevel: .normal
    )
}

private func rankingEntries(count: Int) -> [ApplicationRankingEntry] {
    (0..<count).map { index in
        ApplicationRankingEntry(key: ApplicationKey(value: "/Applications/App\(index).app"), displayName: "App\(index)", value: Double(index))
    }
}

private func cpuPresentation(topApplicationsCount: Int, topApplicationsFailed: Bool = false) -> CPUCardPresentation {
    CPUCardPresentation.assemble(
        cpu: cpuMetrics(),
        history: [],
        topApplications: rankingEntries(count: topApplicationsCount),
        topApplicationsFailed: topApplicationsFailed,
        currentTimestamp: baseInstant
    )
}

private func memoryPresentation(topApplicationsCount: Int, topApplicationsFailed: Bool = false) -> MemoryCardPresentation {
    MemoryCardPresentation.assemble(
        memory: memoryMetrics(),
        history: [],
        topApplications: rankingEntries(count: topApplicationsCount),
        topApplicationsFailed: topApplicationsFailed,
        currentTimestamp: baseInstant
    )
}

/// 카드 뷰의 렌더 높이를 잽니다. `NSHostingController.sizeThatFits(in:)`가 주어진 너비에서
/// SwiftUI 뷰가 실제로 필요로 하는 높이를 돌려주므로, `DashboardView`가 카드에 실제로 주는
/// 너비(280pt에서 좌우 padding을 뺀 값)로 재야 슬롯 줄바꿈까지 production과 같은 조건이 됩니다.
@MainActor
private func measuredHeight(_ view: some View, width: CGFloat = 280 - 32) -> CGFloat {
    let controller = NSHostingController(rootView: view)
    return controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
}

/// task-015 검증 조건이 고정하는 것: "첫 수집이 카드를 부풀리지 않는다"와
/// "TOP 5 항목 수·조사 실패가 순위 자리 높이를 바꾸지 않는다".
/// 상태별로 슬롯을 접는 분기(예: `collecting`일 때 그래프·순위 자리 자체를 그리지 않는 코드)를 되살리면
/// 아래 단언들이 실패해야 합니다.
@MainActor
struct DashboardCardHeightTests {

    // MARK: - CPU 카드

    @Test func cpuCardHeightIsSameRegardlessOfTopApplicationsCount() {
        let heights = [0, 3, 5].map { count in
            measuredHeight(CPUCardView(state: .normal(cpuPresentation(topApplicationsCount: count), timestamp: baseInstant)))
        }

        #expect(Set(heights).count == 1, "TOP 5 항목 수에 따라 CPU 카드 높이가 달라졌습니다: \(heights)")
    }

    @Test func cpuCardHeightIsSameWhenProcessSurveyFails() {
        let normalHeight = measuredHeight(CPUCardView(state: .normal(cpuPresentation(topApplicationsCount: 5), timestamp: baseInstant)))
        let failedHeight = measuredHeight(
            CPUCardView(state: .normal(cpuPresentation(topApplicationsCount: 0, topApplicationsFailed: true), timestamp: baseInstant))
        )

        #expect(normalHeight == failedHeight, "프로세스 조사 실패 tick에서 CPU 카드 높이가 달라졌습니다: 정상 \(normalHeight), 실패 \(failedHeight)")
    }

    /// 이 테스트가 고정하는 것은 "네 상태(수집 중·정상·실패·중지) 모두 같은 슬롯 구성을 그린다"입니다 —
    /// 성공 이력이 없는 실패·중지(`lastKnown: nil`)까지 포함해 비교합니다.
    @Test func cpuCardHeightIsSameAcrossAllFourStates() {
        let presentation = cpuPresentation(topApplicationsCount: 3)
        let lastKnown = LastKnownCardValue(presentation: presentation, timestamp: baseInstant)

        let states: [ResourceCardState<CPUCardPresentation>] = [
            .collecting,
            .normal(presentation, timestamp: baseInstant),
            .failure(lastKnown: nil),
            .failure(lastKnown: lastKnown),
            .stopped(lastKnown: nil),
            .stopped(lastKnown: lastKnown)
        ]

        let heights = states.map { measuredHeight(CPUCardView(state: $0)) }

        #expect(Set(heights).count == 1, "상태에 따라 CPU 카드 높이가 달라졌습니다: \(heights)")
    }

    // MARK: - Memory 카드

    @Test func memoryCardHeightIsSameRegardlessOfTopApplicationsCount() {
        let heights = [0, 3, 5].map { count in
            measuredHeight(MemoryCardView(state: .normal(memoryPresentation(topApplicationsCount: count), timestamp: baseInstant)))
        }

        #expect(Set(heights).count == 1, "TOP 5 항목 수에 따라 Memory 카드 높이가 달라졌습니다: \(heights)")
    }

    @Test func memoryCardHeightIsSameWhenProcessSurveyFails() {
        let normalHeight = measuredHeight(MemoryCardView(state: .normal(memoryPresentation(topApplicationsCount: 5), timestamp: baseInstant)))
        let failedHeight = measuredHeight(
            MemoryCardView(state: .normal(memoryPresentation(topApplicationsCount: 0, topApplicationsFailed: true), timestamp: baseInstant))
        )

        #expect(normalHeight == failedHeight, "프로세스 조사 실패 tick에서 Memory 카드 높이가 달라졌습니다: 정상 \(normalHeight), 실패 \(failedHeight)")
    }

    @Test func memoryCardHeightIsSameAcrossAllFourStates() {
        let presentation = memoryPresentation(topApplicationsCount: 3)
        let lastKnown = LastKnownCardValue(presentation: presentation, timestamp: baseInstant)

        let states: [ResourceCardState<MemoryCardPresentation>] = [
            .collecting,
            .normal(presentation, timestamp: baseInstant),
            .failure(lastKnown: nil),
            .failure(lastKnown: lastKnown),
            .stopped(lastKnown: nil),
            .stopped(lastKnown: lastKnown)
        ]

        let heights = states.map { measuredHeight(MemoryCardView(state: $0)) }

        #expect(Set(heights).count == 1, "상태에 따라 Memory 카드 높이가 달라졌습니다: \(heights)")
    }
}
