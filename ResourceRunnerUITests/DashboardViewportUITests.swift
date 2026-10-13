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

    /// DEBUG fixture가 본체의 관측 전용 요소 접근성 값으로 내보내는 `focus=<카드> outline=<카드>`를 기다립니다.
    private func waitForFocusState(_ expected: String, in app: XCUIApplication,
                                   timeout: TimeInterval = 2) -> String {
        waitForFocusState(in: app, timeout: timeout) { $0 == expected }
    }

    private func waitForFocusState(in app: XCUIApplication, timeout: TimeInterval = 2,
                                   until matches: (String) -> Bool) -> String {
        let probe = app.descendants(matching: .any).matching(identifier: "DashboardFocusOutlineState").firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        var current = ""
        while Date() < deadline {
            current = probe.value as? String ?? ""
            if matches(current) { return current }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return current
    }

    @MainActor
    func testCardFocusOutlineAppearsOnlyAfterKeyboardNavigation() {
        let app = launch(cards: 15, top: 0)
        // 열기 직후 포커스는 첫 카드에 있지만 테두리는 어느 카드에도 없습니다.
        XCTAssertEqual(waitForFocusState("focus=cpu outline=none", in: app), "focus=cpu outline=none")

        app.typeKey(.tab, modifierFlags: [])
        XCTAssertEqual(waitForFocusState("focus=memory outline=memory", in: app),
            "focus=memory outline=memory", "Tab으로 옮긴 카드에만 테두리가 보여야 합니다.")
        app.typeKey(.tab, modifierFlags: .shift)
        XCTAssertEqual(waitForFocusState("focus=cpu outline=cpu", in: app),
            "focus=cpu outline=cpu", "Shift-Tab으로 옮긴 카드에만 테두리가 보여야 합니다.")

        // 키보드로 연 상세를 Escape로 닫으면 원래 카드로 포커스와 테두리가 함께 돌아옵니다.
        // Network·Disk 상세는 `DashboardDetail`이 아니라 각자의 identifier로 노출됩니다.
        let networkDetail = app.descendants(matching: .any).matching(identifier: "NetworkDetail").firstMatch
        let diskDetail = app.descendants(matching: .any).matching(identifier: "DiskDetail").firstMatch
        app.typeKey("3", modifierFlags: .command)
        XCTAssertTrue(networkDetail.waitForExistence(timeout: 2))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(waitUntilGone(networkDetail))
        XCTAssertEqual(waitForFocusState("focus=network outline=network", in: app),
            "focus=network outline=network")

        // 마우스로 카드를 누른 뒤에는 포커스 복귀가 그대로이고 테두리만 숨습니다.
        card("DiskCard", in: app).click()
        XCTAssertTrue(diskDetail.waitForExistence(timeout: 2))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(waitUntilGone(diskDetail))
        XCTAssertEqual(waitForFocusState("focus=disk outline=none", in: app), "focus=disk outline=none")

        // 다시 열면 키보드 탐색 상태가 초기화됩니다.
        // 상세를 닫고 포커스가 돌아온 직후의 첫 Shift-Tab은 포커스를 Disk에 둔 채 끝날 수 있습니다.
        // 포커스 이동 순서는 이 테스트의 대상이 아니므로, 키보드 입력 뒤 포커스가 있는 카드에만 테두리가 보이는지 봅니다.
        app.typeKey(.tab, modifierFlags: .shift)
        let navigated = waitForFocusState(in: app) { state in
            let parts = state.split(separator: " ")
            guard parts.count == 2, parts[0].hasPrefix("focus="), parts[1].hasPrefix("outline=") else { return false }
            let focus = parts[0].dropFirst("focus=".count), outline = parts[1].dropFirst("outline=".count)
            return outline != "none" && outline == focus
        }
        XCTAssertTrue(["focus=disk outline=disk", "focus=network outline=network"].contains(navigated),
            "Shift-Tab 뒤에는 포커스가 있는 카드에만 테두리가 보여야 합니다: \(navigated)")
        let status = app.statusItems.firstMatch
        status.click()
        XCTAssertTrue(waitUntilGone(card("CPUCard", in: app)))
        status.click()
        XCTAssertTrue(card("CPUCard", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(waitForFocusState("focus=cpu outline=none", in: app), "focus=cpu outline=none")
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
