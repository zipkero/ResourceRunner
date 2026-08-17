//
//  DashboardPresentationStore.swift
//  ResourceRunner
//
//  Created by zipkero on 8/15/26.
//

import Combine
import Foundation

/// 팝오버가 닫혀 있어도 갱신을 계속 받아 최신 카드 표시 상태를 보유하는 표시 계층 저장소.
/// 팝오버 콘텐츠 뷰는 앱 시작 때 한 번 만들어져 계속 살아 있으므로, 이 저장소가 항상 최신 값을
/// 들고 있으면 팝오버를 여는 순간 빈 화면이나 로딩 상태를 거칠 경로가 없습니다(ANALYSIS §5 DP10, SPEC §5.9).
@MainActor
final class DashboardPresentationStore: ObservableObject {
    @Published private(set) var cpuCard: ResourceCardState<CPUCardPresentation> = .collecting
    @Published private(set) var memoryCard: ResourceCardState<MemoryCardPresentation> = .collecting
    /// 어느 카드 옆에 상세 팝업이 열려 있는지. `selectCard(_:)`를 거쳐서만 바뀌므로 `updateCPUCard`·`updateMemoryCard`가
    /// 매 tick 호출되어도 선택 상태는 그대로 유지됩니다(task-010 검증 조건, ANALYSIS §2 「팝오버 열림과 카드 선택」).
    /// 이 값이 바로 카드 옆 상세 팝업의 표시 여부를 유도하는 바인딩 원본입니다 —
    /// 팝업이 스스로 닫히면 `dismissDetail(for:)`가 그 사실을 이 값으로 되돌립니다(ANALYSIS §5 DP14).
    @Published private(set) var selection: DashboardSelection = .none

    /// 카드 활성화 하나로만 선택 상태를 전이시킵니다.
    /// 이미 선택된 카드를 다시 활성화하면 선택이 해제되어 요약 상태로 돌아가고,
    /// 다른 카드를 활성화하면 선택이 그 카드로 바뀝니다(SPEC §5.2).
    func selectCard(_ card: DashboardSelection) {
        selection = (selection == card) ? .none : card
    }

    /// 카드 옆 상세 팝업이 스스로 닫힐 때(예: 팝업 밖 클릭) 선택을 해제하는 진입점입니다.
    /// `card`가 그 시점에도 여전히 선택 상태일 때만 선택을 지웁니다 — 이미 다른 카드로 선택이 옮겨간 뒤라면
    /// (예: CPU 팝업이 열린 채 ⌘2로 Memory를 선택해 CPU 팝업이 닫히는 경우) 그 자기 닫힘 신호는 무시합니다
    /// (task-010, ANALYSIS §2 「팝오버 열림과 카드 선택」, §5 DP14).
    func dismissDetail(for card: DashboardSelection) {
        guard selection == card else { return }
        selection = .none
    }

    /// 시스템 지표 tick 하나를 CPU 카드 표시 상태로 반영합니다.
    ///
    /// CPU 값을 아직 만들지 못한 tick(`.success(nil)`)에서는 카드를 다시 수집 중으로 되돌리거나 실패로 바꾸지
    /// 않고 마지막으로 성립한 표시 상태를 그대로 둡니다 — 앱 시작 직후 아직 기준점이 없는 경우와,
    /// 중지 뒤 재개 첫 tick으로 기준점만 갱신된 경우가 모두 여기 해당합니다. 후자는 일정이 멈췄던 동안
    /// 이미 `.stopped`로 바뀐 카드를 그대로 두므로, 값이 실제로 성립하는 다음 tick까지 중지 표시가 이어집니다
    /// (task-011, ANALYSIS §2 「실패 경로」, §5 DP16).
    /// 이 지표가 실패한 tick(`.failure`)에서는 카드를 `.failure`로 바꾸되 마지막 성공 값을 그대로 물려받아,
    /// 값이 0이나 빈 값으로 바뀌지 않습니다.
    ///
    /// - Parameters:
    ///   - topApplications: 앱 단위 CPU 사용량 TOP 5. 아직 조사 이력이 없어 순위를 만들지 못한 동안은
    ///     빈 배열이 그대로 전달되며, 그 자체가 "5개 미만이면 있는 만큼만 표시"의 한 경우입니다.
    ///   - topApplicationsFailed: 이 tick의 프로세스 조사가 실패했는지. 실패해도 시스템 지표 수치는 그대로
    ///     표시되고 TOP 5만 실패를 나타냅니다.
    ///   - currentTimestamp: 그래프를 그리는 시점의 시각(ANALYSIS §5 DP3).
    func updateCPUCard(
        with displayValue: SystemMetricsDisplayValue,
        topApplications: [ApplicationRankingEntry],
        topApplicationsFailed: Bool = false,
        processGroups: [ApplicationProcessGroup] = [],
        currentTimestamp: ContinuousClock.Instant
    ) {
        guard let latest = displayValue.latest else { return }

        switch latest.value.cpu {
        case .success(let cpu?):
            cpuCard = .normal(
                CPUCardPresentation.assemble(
                    cpu: cpu,
                    history: displayValue.recentHistory,
                    topApplications: topApplications,
                    topApplicationsFailed: topApplicationsFailed,
                    processGroups: processGroups,
                    currentTimestamp: currentTimestamp
                ),
                timestamp: latest.timestamp
            )
        case .success(nil):
            break
        case .failure:
            cpuCard = .failure(lastKnown: cpuCard.lastKnownValue)
        }
    }

    /// 시스템 지표 tick 하나를 Memory 카드 표시 상태로 반영합니다.
    ///
    /// Memory는 CPU와 달리 순간값 조회라 "값을 만들지 못한 tick"이 없으므로, 성공하면 곧바로 `.normal`이
    /// 되어 중지 표시를 대체합니다(CPU보다 먼저 중지에서 벗어나는 이유, ANALYSIS §2 「실패 경로」).
    /// 이 tick의 Memory 조회가 실패한 경우(`.failure`)에는 카드를 `.failure`로 바꾸되 마지막 성공 값을
    /// 그대로 물려받습니다. 해석할 수 없는 Memory Pressure 원시값도 Collector 단계에서 이미 이
    /// `CollectorFailure` 경로로 합류하므로 임의 단계가 카드에 나타나는 경로가 없습니다.
    ///
    /// - Parameters:
    ///   - topApplications: 앱 단위 메모리 사용량 TOP 5. 아직 조사 이력이 없어 순위를 만들지 못한 동안은
    ///     빈 배열이 그대로 전달됩니다.
    ///   - topApplicationsFailed: CPU 카드의 같은 매개변수와 같은 뜻입니다.
    ///   - currentTimestamp: Swap 최근 변화량의 10분 창 오른쪽 끝으로 쓰는 시각(ANALYSIS §5 DP3).
    func updateMemoryCard(
        with displayValue: SystemMetricsDisplayValue,
        topApplications: [ApplicationRankingEntry],
        topApplicationsFailed: Bool = false,
        memoryIncrease: [ApplicationRankingEntry] = [],
        processGroups: [ApplicationProcessGroup] = [],
        currentTimestamp: ContinuousClock.Instant
    ) {
        guard let latest = displayValue.latest else { return }

        switch latest.value.memory {
        case .success(let memory):
            memoryCard = .normal(
                MemoryCardPresentation.assemble(
                    memory: memory,
                    history: displayValue.recentHistory,
                    topApplications: topApplications,
                    topApplicationsFailed: topApplicationsFailed,
                    memoryIncrease: memoryIncrease,
                    processGroups: processGroups,
                    currentTimestamp: currentTimestamp
                ),
                timestamp: latest.timestamp
            )
        case .failure:
            memoryCard = .failure(lastKnown: memoryCard.lastKnownValue)
        }
    }

    /// 일정 중지·재개 전이를 받는 진입점. 수집 tick과 별개의 경로로, 코디네이터가 생명주기 store가 알리는
    /// "새로 멈췄다" 전이를 그대로 이 메서드에 전달합니다(ANALYSIS §1 「생명주기 경계」, §5 DP16).
    /// 두 카드가 함께 마지막 성공 값을 유지한 채 중지로 바뀝니다.
    /// 재개는 이 저장소에 별도로 알리지 않습니다 — 다음에 값이 성립한 tick의 `updateCPUCard`·`updateMemoryCard`
    /// 호출이 조립 결과로 중지를 자연히 대체하기 때문입니다.
    func markCollectionStopped() {
        cpuCard = .stopped(lastKnown: cpuCard.lastKnownValue)
        memoryCard = .stopped(lastKnown: memoryCard.lastKnownValue)
    }
}
