//
//  DashboardDetailPopoverUITests.swift
//  ResourceRunnerUITests
//
//  Created by zipkero on 8/17/26.
//

import XCTest

/// task-016 검증 조건: 두 상세 팝업이 같은 고정 크기로 열리고, 내용이 넘치면 팝업 안에서만 스크롤되며,
/// 팝업이 열린 뒤에도 단축키로 요약 상태로 돌아올 수 있는지 확인합니다(ANALYSIS §5 DP15, DP18).
///
/// `app.popovers` 수가 카드 선택으로 1에서 2로 늘고, 자식 팝오버가 부모 팝오버의 하위 노드로 들어가
/// 별도 최상위 창으로 떨어져 나가지 않는다는 것은 실행 환경에서 이미 확인된 사실이므로(ANALYSIS §근거 확인 사실,
/// `DashboardCardSelectionUITests`가 이미 그 관계로 판정합니다) 이 파일도 그 관계를 판정 수단으로 그대로 씁니다.
/// 상세 영역의 SwiftUI `Text`는 접근성 계층에서 `AXValue`로만 문자열을 내보내므로 부분 일치 조회는
/// `value` 기준으로 만듭니다(`DashboardCardSelectionUITests`와 같은 관례).
final class DashboardDetailPopoverUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func detailValue(_ app: XCUIApplication, containing substring: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", substring)).firstMatch
    }

    /// `DashboardDetail` 식별자는 두 상세 팝업 콘텐츠(`CPUDetailPopoverContent`·`MemoryDetailPopoverContent`)의
    /// 고정 크기 `ScrollView`에 붙어 있으므로, 이 식별자의 프레임이 곧 팝업 콘텐츠의 고정 크기입니다.
    private func detailContent(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "DashboardDetail").firstMatch
    }

    private func openDashboard(_ app: XCUIApplication) -> XCUIElement {
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "메뉴바 항목이 나타나지 않았습니다.")
        statusItem.click()

        let cpuCard = app.descendants(matching: .any).matching(identifier: "CPUCard").firstMatch
        XCTAssertTrue(cpuCard.waitForExistence(timeout: 5), "팝오버를 연 뒤 CPU 카드가 나타나지 않았습니다.")

        XCTAssertTrue(
            waitUntil({ !cpuCard.label.contains("수집 중") }, timeout: 5),
            "CPU 카드가 5초 안에 수집 중 상태를 벗어나지 못했습니다. 실제 값: \(cpuCard.label)"
        )
        return cpuCard
    }

    /// CPU 상세와 Memory 상세를 차례로 열어 팝업 콘텐츠 프레임 크기가 같은지 확인합니다(ANALYSIS §5 DP18).
    /// 코어 수·프로세스 수·값이 실행 환경마다 달라도 고정 크기이므로 크기가 같아야 합니다.
    @MainActor
    func testCPUAndMemoryDetailPopoverFramesAreTheSameFixedSize() throws {
        let app = XCUIApplication()
        _ = openDashboard(app)

        let loadAverageText = detailValue(app, containing: "Load Average")
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(loadAverageText.waitForExistence(timeout: 2), "⌘1로 CPU 상세가 나타나지 않았습니다.")
        XCTAssertEqual(app.popovers.count, 2, "CPU 카드를 선택하면 자식 팝오버가 열려 팝오버 수가 2가 되어야 합니다.")

        let cpuDetailFrame = detailContent(app).frame
        XCTAssertGreaterThan(cpuDetailFrame.width, 0, "CPU 상세 팝업 콘텐츠 프레임을 찾지 못했습니다.")

        // Memory로 전환합니다. 자식 팝오버는 key window를 가져가지 않으므로(ANALYSIS §5 DP15) 팝업이 열려
        // 있어도 본체 등록만으로 전환이 계속 닿습니다.
        let currentUsageHeading = detailValue(app, containing: "현재 사용량 순위")
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(currentUsageHeading.waitForExistence(timeout: 2), "⌘2로 Memory 상세가 나타나지 않았습니다.")
        XCTAssertTrue(waitUntil({ !loadAverageText.exists }, timeout: 2), "Memory로 전환한 뒤에도 CPU 상세가 남아 있습니다.")

        let memoryDetailFrame = detailContent(app).frame
        XCTAssertEqual(
            cpuDetailFrame.size, memoryDetailFrame.size,
            "CPU 상세와 Memory 상세의 팝업 콘텐츠 크기가 다릅니다. CPU: \(cpuDetailFrame.size), Memory: \(memoryDetailFrame.size)"
        )
    }

    /// 상세 지표 문자열이 접근성 계층에서 조회되며, 어느 팝오버로도 도달할 수 있어야 합니다 —
    /// `app.windows`가 아니라 `app.popovers` 아래에서 잡혀야 별도 최상위 창으로 떨어져 나가지 않은 것입니다.
    @MainActor
    func testDetailContentIsReachableUnderPopoversNotAsSeparateWindow() throws {
        let app = XCUIApplication()
        _ = openDashboard(app)

        app.typeKey("1", modifierFlags: .command)
        let loadAverageInPopovers = app.popovers.staticTexts
            .matching(NSPredicate(format: "value CONTAINS %@", "Load Average"))
            .firstMatch
        XCTAssertTrue(loadAverageInPopovers.waitForExistence(timeout: 2), "CPU 상세 지표가 팝오버 계층 아래에서 잡히지 않습니다.")

        let loadAverageInWindows = app.windows.staticTexts
            .matching(NSPredicate(format: "value CONTAINS %@", "Load Average"))
            .firstMatch
        XCTAssertFalse(loadAverageInWindows.exists, "CPU 상세 지표가 별도 최상위 창으로 떨어져 나갔습니다.")
    }

    /// 키 복귀는 팝업이 열린 상태에서 단축키를 눌러 팝오버 수가 2에서 1로 줄어드는지로 단언합니다.
    /// 팝업 콘텐츠 자체(정적 텍스트)를 클릭해 자식 팝오버 쪽에 상호작용 기회를 준 뒤 단축키로 복귀를 시도합니다.
    ///
    /// 이 테스트가 고정하는 것은 「팝업이 열리고 그 콘텐츠를 클릭한 뒤에도 본체(`DashboardView`) 등록 단축키가
    /// 계속 닿아 복귀가 성립한다」입니다(ANALYSIS §5 DP15) — 자식 팝오버가 key window를 가져가지 않아
    /// 본체가 계속 key로 남는 것이 근거입니다. 본체의 `.keyboardShortcut` 등록 두 줄을 지우면 이 테스트는 실패합니다.
    @MainActor
    func testShortcutClosesDetailWhileChildPopoverIsOpen() throws {
        let app = XCUIApplication()
        _ = openDashboard(app)

        let loadAverageText = detailValue(app, containing: "Load Average")
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(loadAverageText.waitForExistence(timeout: 2), "⌘1로 CPU 상세가 나타나지 않았습니다.")
        XCTAssertEqual(app.popovers.count, 2, "CPU 카드를 선택하면 팝오버 수가 2가 되어야 합니다.")

        loadAverageText.click()

        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(
            waitUntil({ app.popovers.count == 1 }, timeout: 2),
            "팝업 콘텐츠를 클릭한 뒤 단축키를 눌렀는데도 팝오버 수가 1로 줄지 않았습니다. 현재: \(app.popovers.count)"
        )
    }

    /// Memory 상세에서도 같은 성질이 성립하는지 확인합니다. CPU 쪽만 확인하면 Memory 쪽 단축키 등록이
    /// 빠져도 이 회귀를 잡지 못하므로 두 카드를 각각 확인합니다. 근거는 위 CPU 쪽 테스트와 같습니다.
    @MainActor
    func testMemoryShortcutClosesDetailWhileChildPopoverIsOpen() throws {
        let app = XCUIApplication()
        _ = openDashboard(app)

        let currentUsageHeading = detailValue(app, containing: "현재 사용량 순위")
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(currentUsageHeading.waitForExistence(timeout: 2), "⌘2로 Memory 상세가 나타나지 않았습니다.")
        XCTAssertEqual(app.popovers.count, 2, "Memory 카드를 선택하면 팝오버 수가 2가 되어야 합니다.")

        currentUsageHeading.click()

        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(
            waitUntil({ app.popovers.count == 1 }, timeout: 2),
            "팝업 콘텐츠를 클릭한 뒤 단축키를 눌렀는데도 팝오버 수가 1로 줄지 않았습니다. 현재: \(app.popovers.count)"
        )
    }

    /// 다른 카드의 단축키를 누르면 선택이 그 카드로 옮겨가는지 확인합니다. CPU 상세가 열린 상태에서
    /// ⌘2를 누르면 선택이 Memory로 이동해야 합니다(ANALYSIS §2 「팝오버 열림과 카드 선택」).
    @MainActor
    func testOtherCardShortcutMovesSelectionWhileDetailIsOpen() throws {
        let app = XCUIApplication()
        _ = openDashboard(app)

        let loadAverageText = detailValue(app, containing: "Load Average")
        let currentUsageHeading = detailValue(app, containing: "현재 사용량 순위")

        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(loadAverageText.waitForExistence(timeout: 2), "⌘1로 CPU 상세가 나타나지 않았습니다.")

        loadAverageText.click()
        app.typeKey("2", modifierFlags: .command)

        XCTAssertTrue(currentUsageHeading.waitForExistence(timeout: 2), "⌘2로 Memory 상세가 나타나지 않았습니다.")
        XCTAssertTrue(waitUntil({ !loadAverageText.exists }, timeout: 2), "Memory로 전환한 뒤에도 CPU 상세가 남아 있습니다.")
        XCTAssertEqual(app.popovers.count, 2, "카드를 오가는 동안 팝오버 수가 2에 머물러야 합니다.")
    }

    /// task-016 검증 조건 "내용이 고정 크기를 넘으면 잘리지 않고 팝업 안에서만 스크롤되며 카드와 본체는
    /// 움직이지 않습니다"의 회귀 테스트입니다. 스와이프 전후로 팝업 콘텐츠 안 "Load Average" 줄의 y 위치가
    /// 이동하는지, 그 동안 `DashboardDetail`(고정 크기 `ScrollView`) 프레임 자체는 그대로인지를 확인합니다.
    ///
    /// 앱 시작 직후에는 프로세스 조사 결과가 아직 도착하지 않아 내용이 짧아 스와이프를 해도 위치가 움직이지
    /// 않을 수 있습니다. 이 상태로 곧장 프레임 불변만 단언하면 스크롤이 실제로 막혀 있어도 통과해버리는
    /// 위양성이 됩니다. 그래서 스와이프로 y가 실제로 움직이는 것을 먼저 확인한 뒤에만 프레임 불변을 단언합니다.
    @MainActor
    func testDetailContentScrollsWithinFixedPopoverFrame() throws {
        let app = XCUIApplication()
        _ = openDashboard(app)

        let loadAverageText = detailValue(app, containing: "Load Average")
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(loadAverageText.waitForExistence(timeout: 2), "⌘1로 CPU 상세가 나타나지 않았습니다.")

        let detail = detailContent(app)
        let popoverFrameBeforeSwipe = detail.frame
        let yBeforeSwipe = loadAverageText.frame.origin.y

        let contentMoved = waitUntil({
            detail.swipeUp()
            return abs(loadAverageText.frame.origin.y - yBeforeSwipe) > 1
        }, timeout: 10)
        XCTAssertTrue(
            contentMoved,
            "스와이프를 해도 콘텐츠 위치가 움직이지 않았습니다 — 프로세스 조사 결과가 아직 도착하지 않아 스크롤할 내용이 없을 수 있습니다."
        )

        XCTAssertEqual(
            detail.frame, popoverFrameBeforeSwipe,
            "스크롤 뒤 팝업 콘텐츠 프레임이 달라졌습니다. 이전: \(popoverFrameBeforeSwipe), 이후: \(detail.frame)"
        )
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
