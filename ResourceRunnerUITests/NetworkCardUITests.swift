import XCTest

/// 서명된 앱 한 세션에서 실제 Network 카드와 카드 옆 상세의 위치·원본 문자열을 관찰합니다.
final class NetworkCardUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testRealNetworkCardDetailAndReturnKeepFrames() throws {
        let app = XCUIApplication()
        app.launch()
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10))
        statusItem.click()

        let network = app.descendants(matching: .any).matching(identifier: "NetworkCard").firstMatch
        XCTAssertTrue(network.waitForExistence(timeout: 10))
        let dashboard = app.descendants(matching: .any).matching(identifier: "DashboardContainer").firstMatch
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5))
        let scroll = app.scrollViews.containing(.any, identifier: "NetworkCard").firstMatch
        XCTAssertTrue(scroll.exists)
        for _ in 0..<4 where !network.isHittable { scroll.swipeUp() }
        XCTAssertTrue(network.isHittable, "Network 카드가 본체 스크롤에서 도달되지 않았습니다.")

        let cardBefore = network.frame
        let bodyBefore = dashboard.frame
        print("TASK010_ACTUAL_UI cardBefore=\(cardBefore) bodyBefore=\(bodyBefore) label=\(network.label)")
        XCTAssertEqual(cardBefore.height, 101, accuracy: 1)

        network.click()
        let detail = app.descendants(matching: .any).matching(identifier: "NetworkDetail").firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertEqual(app.popovers.count, 2)
        XCTAssertEqual(detail.frame.size, CGSize(width: 400, height: 480))
        let cadence = detail.staticTexts.matching(identifier: "NetworkUpdateCadence").firstMatch
        XCTAssertTrue(cadence.exists)
        XCTAssertTrue(cadence.label.contains("별도 느린 주기"))
        let row = detail.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "NetworkInterface-"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "실제 native 대상 상세 행이 없습니다.")
        print("TASK010_ACTUAL_UI detail=\(detail.frame) row=\(row.label)")
        XCTAssertTrue(row.label.contains("현재 RX"))
        XCTAssertTrue(row.label.contains("현재 TX"))
        XCTAssertTrue(row.label.contains("원시 누적 RX"))
        XCTAssertTrue(row.label.contains("IPv4"))
        XCTAssertTrue(row.label.contains("IPv6"))
        XCTAssertTrue(row.label.contains("링크 속도"))
        XCTAssertEqual(network.frame, cardBefore)
        XCTAssertEqual(dashboard.frame, bodyBefore)

        let close = app.buttons.matching(identifier: "NetworkDetailClose").firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 2))
        close.click()
        XCTAssertTrue(waitUntil({ !detail.exists }, timeout: 3))
        XCTAssertEqual(network.frame, cardBefore)
        XCTAssertEqual(dashboard.frame, bodyBefore)
        network.click()
        XCTAssertTrue(detail.waitForExistence(timeout: 3))
        network.click()
        XCTAssertTrue(waitUntil({ !detail.exists }, timeout: 3))
        print("TASK010_ACTUAL_UI cardAfter=\(network.frame) bodyAfter=\(dashboard.frame)")
    }

    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
