//
//  DashboardCardSelectionUITests.swift
//  ResourceRunnerUITests
//
//  Created by zipkero on 8/15/26.
//

import XCTest

/// task-010 검증 조건: 카드를 선택하면 그 카드 옆에 자식 팝오버가 열려 `app.popovers` 수가 1에서 2로 늘고,
/// 같은 카드를 다시 선택하면 2로 줄지 않고 1로 돌아오는지, 다른 카드로 옮기면 2에 머무는지,
/// 상세 개폐가 두 카드와 본체 팝오버의 프레임을 흔들지 않는지를 확인합니다.
///
/// 이전 버전은 하단 상세 영역의 안내 문구 등장·소멸로 선택·복귀를 판정했지만, task-010이 그 영역을 걷어내고
/// 상세를 카드 옆 자식 팝업으로 옮기면서(ANALYSIS §5 DP14) 그 판정 기준 자체가 성립하지 않게 되어
/// 판정 기준을 팝업의 등장·소멸(`app.popovers` 수)로 바꿉니다.
///
/// macOS 키보드 탐색(Full Keyboard Access)은 기본값이 꺼짐이고, 꺼진 상태에서는 Tab이 표준 `Button`에 닿지
/// 않는다는 것을 실행 중인 앱에서 확인했습니다(ANALYSIS §5 DP15). 그래서 카드 선택·복귀는 Tab이 아니라
/// `⌘1`(CPU)·`⌘2`(Memory) 단축키로 수행합니다.
///
/// 상세 영역의 SwiftUI `Text`는 접근성 계층에서 `AXValue`로만 문자열을 내보내고 `AXLabel`은 비어 있습니다.
/// 그래서 부분 일치 조회는 `label`이 아니라 `value`를 기준으로 만들어야 하며,
/// `label`로 조회하면 화면에 문구가 있어도 항상 0개가 잡힙니다(실행 중인 앱의 계층 덤프로 확인).
///
/// 팝오버는 `NSStatusItem` 아래 `Popover` 원소로 나타나고 `app.windows`에는 잡히지 않으므로,
/// 팝오버 조회와 프레임 비교 대상은 모두 `app.popovers`로 찾습니다.
/// 자식 팝오버가 부모 팝오버의 하위 노드로 들어간다는 것(별도 창으로 떨어져 나가지 않는다는 것)은
/// 실행 환경에서 이미 확인된 사실이므로, 부모 팝오버는 카드 식별자(`CPUCard`)를 담고 있는 팝오버로 특정합니다.
///
/// VoiceOver의 실제 낭독은 spec.md 제외 범위이므로 여기서 확인하지 않습니다.
final class DashboardCardSelectionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 상세 팝업 문구를 부분 일치로 찾는 조회. 위 주석의 이유로 `value`를 기준으로 삼습니다.
    private func detailValue(_ app: XCUIApplication, containing substring: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", substring)).firstMatch
    }

    /// 두 카드 버튼을 모두 담고 있는 본체(부모) 팝오버. 자식 팝오버가 하위 노드로 들어가므로
    /// `CPUCard`·`MemoryCard` 둘 다를 포함하는 팝오버로 부모를 특정합니다.
    private func parentPopover(_ app: XCUIApplication) -> XCUIElement {
        app.popovers
            .containing(.any, identifier: "CPUCard")
            .containing(.any, identifier: "MemoryCard")
            .firstMatch
    }

    private func openDashboard(_ app: XCUIApplication) -> XCUIElement {
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "메뉴바 항목이 나타나지 않았습니다.")
        statusItem.click()

        let cpuCard = app.descendants(matching: .any).matching(identifier: "CPUCard").firstMatch
        XCTAssertTrue(cpuCard.waitForExistence(timeout: 5), "팝오버를 연 뒤 CPU 카드가 나타나지 않았습니다.")

        // CPU Collector는 두 번째 tick부터 값을 만들므로, 앱 시작 직후에는 CPU 카드가 아직 `.collecting`일 수
        // 있습니다. 그 상태에서 상세를 열면 "Load Average" 대신 "아직 CPU 값이 수집되지 않았습니다."가 나와
        // 아래 단언이 어긋나므로, task-008 UI 테스트와 같은 방식으로 값이 채워질 때까지 먼저 기다립니다.
        XCTAssertTrue(
            waitUntilLabelNoLongerContainsCollecting(cpuCard, timeout: 5),
            "CPU 카드가 5초 안에 수집 중 상태를 벗어나지 못했습니다. 실제 값: \(cpuCard.label)"
        )
        return cpuCard
    }

    /// 원래 다섯 개 테스트(선택·해제로 팝오버 수가 늘고 주는지, 그 과정에서 두 카드·본체 팝오버 프레임이
    /// 흔들리지 않는지(SPEC §5.15, ANALYSIS §5 DP14), CPU·Memory 각각의 팝업 자기 해제 회귀(task-010이 두 번
    /// 반려된 끝에 확보한 그물), CPU에서 Memory로 전환 시 팝오버 수가 2에 머무는지)를 하나로 모았습니다.
    /// 앱 실행 → 팝오버 열기 → 카드 대기라는 같은 준비를 다섯 번 반복해서 지불하던 고정비를 한 번으로
    /// 줄이는 것이 목적이며, 원래 있던 단언은 하나도 지우지 않고 각 단언의 실패 메시지도 그대로 남깁니다.
    /// 첫째·둘째 단계가 문자 그대로 같은 조작(⌘1 선택→해제)이라 팝오버 수 단언과 프레임 불변 단언을
    /// 자연스럽게 같은 지점에서 함께 확인할 수 있고, 이어지는 자기 해제·전환 단계도 앞 단계가 남긴 선택
    /// 상태 위에서 그대로 이어집니다(각 원본 테스트의 조작 순서·전제와 동일).
    @MainActor
    func testCardSelectionLifecycleKeepsFramesFixedAndSurvivesSelfDismissal() throws {
        let app = XCUIApplication()
        let cpuCard = openDashboard(app)
        let memoryCard = app.descendants(matching: .any).matching(identifier: "MemoryCard").firstMatch
        XCTAssertTrue(memoryCard.waitForExistence(timeout: 5), "Memory 카드가 나타나지 않았습니다.")

        let parent = parentPopover(app)
        XCTAssertTrue(parent.waitForExistence(timeout: 2), "본체 팝오버를 찾지 못했습니다.")

        XCTAssertEqual(app.popovers.count, 1, "선택 전에는 본체 팝오버 하나만 있어야 합니다.")

        // 카드 슬롯이 상태와 무관하게 고정되어 높이는 이제 흔들리지 않지만, 이 테스트가 확인하려는 것은
        // "선택이 카드를 흔들지 않는다"뿐입니다. 기준 프레임이 안정된 뒤에 잡히도록 두어
        // 슬롯 고정이 회귀해도 이 테스트가 선택과 무관한 이유로 실패하지 않게 합니다.
        let cpuCardFrameBefore = waitUntilFrameStable(cpuCard, timeout: 10)
        let memoryCardFrameBefore = waitUntilFrameStable(memoryCard, timeout: 10)
        let parentFrameBefore = parent.frame

        // 1) CPU 선택 → 팝오버 수 1에서 2로, 두 카드·본체 프레임은 그대로
        //    (원 testSelectingCardOpensChildPopoverAndDeselectingClosesIt·testCardAndParentPopoverFramesStayFixedAcrossSelection)
        let loadAverageText = detailValue(app, containing: "Load Average")
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(loadAverageText.waitForExistence(timeout: 2), "⌘1로 CPU 상세(Load Average)가 나타나지 않았습니다.")
        XCTAssertEqual(app.popovers.count, 2, "CPU 카드를 선택하면 자식 팝오버가 열려 팝오버 수가 2가 되어야 합니다.")
        XCTAssertEqual(parent.frame, parentFrameBefore, "카드를 선택한 뒤 본체 팝오버 프레임이 바뀌었습니다.")
        XCTAssertEqual(cpuCard.frame, cpuCardFrameBefore, "카드를 선택한 뒤 CPU 카드 프레임이 바뀌었습니다.")
        XCTAssertEqual(memoryCard.frame, memoryCardFrameBefore, "카드를 선택한 뒤 Memory 카드 프레임이 바뀌었습니다.")

        // 2) 같은 단축키로 해제 → 팝오버 수 1로 복귀, 프레임은 여전히 그대로
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(waitUntilGone(loadAverageText, timeout: 2), "같은 ⌘1을 다시 눌렀는데도 CPU 상세가 사라지지 않았습니다.")
        XCTAssertTrue(
            waitUntil({ app.popovers.count == 1 }, timeout: 2),
            "선택을 해제했는데도 팝오버 수가 1로 돌아오지 않았습니다. 현재: \(app.popovers.count)"
        )
        XCTAssertEqual(parent.frame, parentFrameBefore, "선택 해제 후 본체 팝오버 프레임이 최초 크기와 달라졌습니다.")
        XCTAssertEqual(cpuCard.frame, cpuCardFrameBefore, "선택 해제 후 CPU 카드 프레임이 최초 크기와 달라졌습니다.")
        XCTAssertEqual(memoryCard.frame, memoryCardFrameBefore, "선택 해제 후 Memory 카드 프레임이 최초 크기와 달라졌습니다.")

        // 3) CPU 팝업 자기 해제 회귀(원 testSelfDismissingChildPopoverStaysClosedAndReselectionReopensIt).
        //    `DashboardView`의 `cpuDetailIsPresented` 바인딩 `set`이 `store.dismissDetail(for:)`를 부르지
        //    않고 비어 있어도(예: `set: { _ in }`) SwiftUI 팝오버 자신은 그대로 닫히므로, 팝오버 수가
        //    2 -> 1로 줄어드는 것까지는 이 mutation을 잡아내지 못합니다. 그 mutation이 만드는 실제 결함은
        //    store의 `selection`이 CPU로 남아 있어 다음 SwiftUI 갱신에서 팝업이 곧바로 되살아나는
        //    것이므로, (1) 1로 줄어든 뒤 그 값이 잠시 유지되는지와 (2) 그 상태에서 같은 단축키를 한 번 더
        //    누르면 선택이 없음 -> CPU로 다시 전이해 팝오버 수가 2로 늘어나는지를 함께 단언합니다.
        //    `set`이 비어 있으면 store의 `selection`이 이미 CPU라 재선택이 해제로 처리돼 팝오버가 오히려
        //    닫히므로 이 두 번째 단언에서 실패합니다.
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(loadAverageText.waitForExistence(timeout: 2), "⌘1로 CPU 상세가 나타나지 않았습니다.")
        XCTAssertEqual(app.popovers.count, 2, "CPU 카드를 선택하면 팝오버 수가 2가 되어야 합니다.")

        // 부모 팝오버 안이면서 자식 팝업 밖인 자리(제목 텍스트)를 클릭해 자식 팝업을 스스로 닫습니다.
        // 라벨("ResourceRunner")이 아니라 식별자로 찾습니다 — 상세 목록에 앱 자신(ResourceRunner)의 프로세스
        // 행이 같은 라벨로 나타나 라벨 조회가 둘 이상과 일치할 수 있기 때문입니다(`DashboardView.swift`
        // `accessibilityIdentifier("DashboardTitle")` 주석 참고).
        let title = app.staticTexts["DashboardTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 2), "본체 제목을 찾지 못했습니다.")
        title.click()

        XCTAssertTrue(
            waitUntil({ app.popovers.count == 1 }, timeout: 2),
            "팝업 밖을 클릭했는데도 팝오버 수가 1로 줄지 않았습니다. 현재: \(app.popovers.count)"
        )

        // 곧바로 되살아나지 않는지 잠깐 동안 반복 표본해 확인합니다. 한 번만 보고 끝내면 되살아나는 빌드를
        // 놓칠 수 있어(위 주석 참고), 짧은 구간에 걸쳐 값이 계속 1인지를 확인합니다.
        let cpuStayedClosed = waitUntil({ app.popovers.count != 1 }, timeout: 1) == false
        XCTAssertTrue(cpuStayedClosed, "팝업 밖을 클릭해 닫힌 뒤 팝오버가 스스로 되살아났습니다. 현재: \(app.popovers.count)")
        XCTAssertEqual(app.popovers.count, 1, "잠깐 뒤에도 팝오버 수는 1이어야 합니다.")

        // 선택이 실제로 해제됐다면 같은 단축키를 다시 눌렀을 때 없음 -> CPU 전이가 일어나 팝오버가 다시 열립니다.
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(
            waitUntil({ app.popovers.count == 2 }, timeout: 2),
            "자기 닫힘 뒤 같은 단축키를 눌렀는데도 팝오버가 다시 열리지 않았습니다 - 선택이 실제로 해제되지 않았을 수 있습니다. 현재: \(app.popovers.count)"
        )

        // 4) CPU에서 Memory로 전환 → 이전 팝업이 닫히고 Memory 옆에 새 팝업이 열리며 팝오버 수는 계속 2
        //    (원 testSwitchingFromCPUToMemoryKeepsOneChildPopoverOpen). 위 3단계가 CPU 상세를 다시 열어
        //    둔 상태라 이 전환이 자연스럽게 이어집니다.
        let currentUsageHeading = detailValue(app, containing: "현재 사용량 순위")
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(currentUsageHeading.waitForExistence(timeout: 2), "⌘2로 Memory 상세(현재 사용량 순위)가 나타나지 않았습니다.")
        XCTAssertTrue(waitUntilGone(loadAverageText, timeout: 2), "Memory로 전환한 뒤에도 CPU 상세가 남아 있습니다.")
        XCTAssertEqual(app.popovers.count, 2, "카드를 오가는 동안 팝오버 수가 2에 머물러야 합니다.")

        // 5) Memory 팝업 자기 해제 회귀(원 testSelfDismissingMemoryChildPopoverStaysClosedAndReselectionReopensIt).
        //    `DashboardView`의 `memoryDetailIsPresented` 바인딩 `set`은 `cpuDetailIsPresented`와 별도
        //    클로저이므로, CPU 쪽만 확인하면 Memory 쪽에서 `store.dismissDetail(for: .memory)` 호출이
        //    빠지는 회귀를 잡지 못합니다. 근거·판정 방식은 위 3단계 CPU 쪽과 같습니다.
        XCTAssertTrue(title.waitForExistence(timeout: 2), "본체 제목을 찾지 못했습니다.")
        title.click()

        XCTAssertTrue(
            waitUntil({ app.popovers.count == 1 }, timeout: 2),
            "팝업 밖을 클릭했는데도 팝오버 수가 1로 줄지 않았습니다. 현재: \(app.popovers.count)"
        )

        let memoryStayedClosed = waitUntil({ app.popovers.count != 1 }, timeout: 1) == false
        XCTAssertTrue(memoryStayedClosed, "팝업 밖을 클릭해 닫힌 뒤 팝오버가 스스로 되살아났습니다. 현재: \(app.popovers.count)")
        XCTAssertEqual(app.popovers.count, 1, "잠깐 뒤에도 팝오버 수는 1이어야 합니다.")

        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(
            waitUntil({ app.popovers.count == 2 }, timeout: 2),
            "자기 닫힘 뒤 같은 단축키를 눌렀는데도 팝오버가 다시 열리지 않았습니다 - 선택이 실제로 해제되지 않았을 수 있습니다. 현재: \(app.popovers.count)"
        )
    }

    /// CPU Collector는 두 번째 tick부터 값을 만들므로, 앱 시작 직후 첫 조회에서는 카드가 "수집 중"일 수
    /// 있습니다. 값이 채워질 때까지 정상 수집 주기(최대 2초) 안에서 기다립니다(`DashboardCPUCardUITests`와 같은 관례).
    private func waitUntilLabelNoLongerContainsCollecting(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        waitUntil({ !element.label.contains("수집 중") }, timeout: timeout)
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        waitUntil({ !element.exists }, timeout: timeout)
    }

    /// `element.frame`이 조용한 구간 동안 더 바뀌지 않을 때까지 기다린 뒤 그 값을 돌려줍니다.
    /// TOP 5 목록이 뒤늦게 채워지며 카드 높이가 자연히 안정되는 시점을 잡는 데 씁니다.
    /// 팝오버가 열린 정상 전력 상태의 프로세스 조사 주기(2초, ANALYSIS §2 「수집 중지와 재개」표)보다
    /// 긴 조용한 구간을 요구해야, 조사가 아직 끝나지 않은 순간을 "안정"으로 오판하지 않습니다.
    private func waitUntilFrameStable(_ element: XCUIElement, timeout: TimeInterval) -> CGRect {
        let quietPeriod: TimeInterval = 3
        var lastFrame = element.frame
        var stableSince = Date()
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.2))
            let currentFrame = element.frame
            if currentFrame != lastFrame {
                lastFrame = currentFrame
                stableSince = Date()
            } else if Date().timeIntervalSince(stableSince) > quietPeriod {
                return currentFrame
            }
        }
        return lastFrame
    }

    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
