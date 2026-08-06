//
//  ResourceRunnerUITests.swift
//  ResourceRunnerUITests
//
//  Created by zipkero on 8/2/26.
//

import XCTest

final class ResourceRunnerUITests: XCTestCase {

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    /// task-001 검증 조건: 메뉴바 클릭 → 팝오버가 열립니다.
    @MainActor
    func testMenuBarClickOpensPopover() throws {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "메뉴바 항목이 나타나지 않았습니다.")

        statusItem.click()

        let dashboardTitle = app.staticTexts["ResourceRunner"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 2), "메뉴바 클릭 뒤 팝오버가 열리지 않았습니다.")
    }

    /// task-001 검증 조건: 메뉴바 클릭을 반복해도(열림 → 닫힘 → 열림) 표시 상태가 어긋나지 않습니다.
    /// 시스템 전체를 대상으로 하는 실제 "외부 클릭"은 이 accessory 앱이 참조 가능한 창을 갖지 않아
    /// XCUITest 좌표 합성이 불안정합니다(비고 참조). 이 테스트는 같은 메뉴바 항목을 반복 클릭해
    /// `StatusBarController.togglePopover()`의 열기·닫기 경로를 모두 실행하고
    /// `NSPopover.isShown`이 매번 예상과 일치하는지 확인합니다.
    @MainActor
    func testMenuBarClickTogglesPopoverRepeatedlyWithoutDrift() throws {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "메뉴바 항목이 나타나지 않았습니다.")

        let dashboardTitle = app.staticTexts["ResourceRunner"]

        for iteration in 0..<5 {
            statusItem.click()
            XCTAssertTrue(
                dashboardTitle.waitForExistence(timeout: 2),
                "반복 \(iteration): 클릭 뒤 팝오버가 열리지 않았습니다."
            )

            // 합성 클릭이 사람의 클릭 간격 없이 연속으로 들어오면 NSPopover의 자체 outside-click
            // 판정과 경쟁할 수 있어 짧은 간격을 둡니다.
            Thread.sleep(forTimeInterval: 0.3)

            statusItem.click()
            XCTAssertTrue(
                waitUntilGone(dashboardTitle, timeout: 2),
                "반복 \(iteration): 재클릭 뒤 팝오버가 닫히지 않았습니다."
            )

            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    // Xcode 템플릿의 testLaunchPerformance()는 XCTApplicationLaunchMetric이 메인 창 표시를
    // 기준으로 launch 완료를 판정합니다. 이 앱은 task-001에서 Dock 없는 accessory 앱(창 없음)으로
    // 바뀌어 반복 측정마다 iteration 수가 들쭉날쭉 실패해, 이 아키텍처와 근본적으로 맞지 않는
    // 템플릿 성능 테스트를 제거했습니다.

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        return !element.exists
    }
}
