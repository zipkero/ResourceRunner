import XCTest

final class DashboardPreferencesVisibilityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func app(cards: Int, top: Int = 3) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--dashboard-preferences-ui-test")
        app.launchEnvironment["RR_DASHBOARD_CARD_MASK"] = String(cards)
        app.launchEnvironment["RR_DASHBOARD_TOP_MASK"] = String(top)
        app.launch()
        return app
    }

    private func openDashboard(_ app: XCUIApplication) -> XCUIElement {
        let status = app.statusItems.firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        status.click()
        let container = app.descendants(matching: .any)
            .matching(identifier: "DashboardContainer").firstMatch
        XCTAssertTrue(container.waitForExistence(timeout: 5))
        return container
    }

    @MainActor
    func testAllOffShowsSettingsActionAndNoCardAccessibilityElements() {
        let app = app(cards: 0)
        let container = openDashboard(app)
        XCTAssertTrue(container.exists)
        let settings = app.buttons["DashboardOpenSettings"]
        XCTAssertTrue(settings.exists)
        XCTAssertEqual(settings.label, "설정 열기")
        XCTAssertTrue(settings.isHittable)
        XCTAssertLessThan(container.frame.height, 100, "전체 숨김은 카드 자리를 예약하지 않아야 합니다.")
        XCTAssertTrue(container.frame.contains(settings.frame), "설정 버튼은 본체 안에 있어야 합니다.")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "CPUCard").firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "MemoryCard").firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "NetworkCard").firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "DiskCard").firstMatch.exists)
        settings.click()
        XCTAssertTrue(container.exists)
    }

    @MainActor
    func testLiveHideAndReshowRemovesCardAndRankingButKeepsDetail() {
        let app = app(cards: 3, top: 0)
        let container = openDashboard(app)
        let cpu = app.descendants(matching: .any).matching(identifier: "CPUCard").firstMatch
        let memory = app.descendants(matching: .any).matching(identifier: "MemoryCard").firstMatch
        XCTAssertTrue(cpu.exists)
        XCTAssertTrue(memory.exists)
        XCTAssertFalse(cpu.label.contains("TOP 5"))
        XCTAssertFalse(memory.label.contains("TOP 5"))
        let initialHeight = container.frame.height

        cpu.click()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "DashboardDetail")
            .firstMatch.waitForExistence(timeout: 2))

        let status = app.statusItems.firstMatch
        status.rightClick()
        let hide = app.menuItems["Toggle cpu Card"]
        XCTAssertTrue(hide.waitForExistence(timeout: 2))
        hide.click()
        status.click()
        XCTAssertFalse(cpu.exists)
        XCTAssertTrue(memory.waitForExistence(timeout: 2))
        XCTAssertLessThan(container.frame.height, initialHeight)
        app.typeKey("1", modifierFlags: .command)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "DashboardDetail")
            .firstMatch.exists)

        status.rightClick()
        let show = app.menuItems["Toggle cpu Card"]
        XCTAssertTrue(show.waitForExistence(timeout: 2))
        show.click()
        status.click()
        XCTAssertTrue(cpu.waitForExistence(timeout: 2))
        XCTAssertFalse(cpu.label.contains("TOP 5"))
        XCTAssertTrue(memory.exists)
    }
}
