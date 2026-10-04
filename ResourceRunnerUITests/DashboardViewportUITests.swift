import AppKit
import XCTest

final class DashboardViewportUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(cards: Int, top: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--dashboard-preferences-ui-test")
        app.launchEnvironment["RR_DASHBOARD_CARD_MASK"] = String(cards)
        app.launchEnvironment["RR_DASHBOARD_TOP_MASK"] = String(top)
        app.launch()
        let status = app.statusItems.firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        status.click()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "DashboardContainer")
            .firstMatch.waitForExistence(timeout: 5))
        return app
    }

    private func card(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: name).firstMatch
    }

    private func detail(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "DashboardDetail").firstMatch
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 2) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return !element.exists
    }

    @MainActor
    func testHiddenShortcutAndLiveSelectionRemovalRestoreFocusToFirstVisibleCard() {
        let app = launch(cards: 3, top: 0)
        app.typeKey("4", modifierFlags: .command)
        XCTAssertFalse(detail(in: app).exists, "숨긴 Disk 단축키가 상세를 열면 안 됩니다.")

        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(detail(in: app).waitForExistence(timeout: 2))
        app.typeKey("2", modifierFlags: [.command, .shift])
        XCTAssertTrue(waitUntilGone(card("MemoryCard", in: app)))
        XCTAssertTrue(card("CPUCard", in: app).exists)
        XCTAssertTrue(waitUntilGone(detail(in: app)))
        app.typeKey("2", modifierFlags: .command)
        XCTAssertFalse(detail(in: app).exists, "제거한 Memory의 ⌘2는 무동작이어야 합니다.")

        // 선택한 Memory를 제거한 뒤 첫 표시 카드로 키보드 초점이 돌아왔는지 두 활성화 키로 확인합니다.
        Thread.sleep(forTimeInterval: 0.25)
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(detail(in: app).waitForExistence(timeout: 2),
            "남은 첫 카드 CPU가 Return으로 활성화되지 않았습니다.")
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(waitUntilGone(detail(in: app)))
        Thread.sleep(forTimeInterval: 0.25)
        app.typeKey(" ", modifierFlags: [])
        XCTAssertTrue(detail(in: app).waitForExistence(timeout: 2),
            "남은 첫 카드 CPU가 Space로 활성화되지 않았습니다.")
        app.typeKey("1", modifierFlags: [.command, .shift])
        XCTAssertTrue(waitUntilGone(card("CPUCard", in: app)))
        XCTAssertTrue(waitUntilGone(detail(in: app)))
        XCTAssertTrue(app.buttons["DashboardOpenSettings"].waitForExistence(timeout: 2))
        app.typeKey("1", modifierFlags: .command)
        XCTAssertFalse(detail(in: app).exists, "모든 카드를 숨긴 뒤 ⌘1은 무동작이어야 합니다.")
    }

    @MainActor
    func testActualLastCardAndMemoryRankingChangesKeepDetailWithinVisibleScreen() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let screenHeight = screen.frame.height
        let visible = screen.visibleFrame
        for scenario in [(cards: 2, top: 0, key: "2", last: "MemoryCard", detail: "DashboardDetail"),
                         (cards: 2, top: 2, key: "2", last: "MemoryCard", detail: "DashboardDetail"),
                         (cards: 6, top: 3, key: "3", last: "NetworkCard", detail: "NetworkDetail"),
                         (cards: 15, top: 3, key: "4", last: "DiskCard", detail: "DiskDetail")] {
            let app = launch(cards: scenario.cards, top: scenario.top)
            let last = card(scenario.last, in: app)
            XCTAssertTrue(last.exists)
            let body = app.descendants(matching: .any)
                .matching(identifier: "DashboardContainer").firstMatch
            let bodyFrame = body.frame
            app.typeKey(scenario.key, modifierFlags: .command)
            let content = app.descendants(matching: .any)
                .matching(identifier: scenario.detail).firstMatch
            XCTAssertTrue(content.waitForExistence(timeout: 2))
            print("VIEWPORT_FRAME cards=\(scenario.cards) top=\(scenario.top) "
                + "visible=\(visible) body=\(bodyFrame) detail=\(content.frame)")
            XCTAssertLessThanOrEqual(content.frame.width, 400)
            XCTAssertLessThanOrEqual(content.frame.height, 480)
            XCTAssertGreaterThanOrEqual(content.frame.minX, visible.minX + 8)
            XCTAssertLessThanOrEqual(content.frame.maxX, visible.maxX - 8)
            XCTAssertGreaterThanOrEqual(content.frame.minY,
                screenHeight - visible.maxY + 8)
            XCTAssertLessThanOrEqual(content.frame.maxY,
                screenHeight - visible.minY - 8)
            XCTAssertEqual(body.frame, bodyFrame, "상세 공간을 위해 본체를 줄이면 안 됩니다.")
            app.terminate()
        }
    }
}
