//
//  DashboardCPUCardUITests.swift
//  ResourceRunnerUITests
//
//  Created by zipkero on 8/15/26.
//

import XCTest

/// task-008 검증 조건: 팝오버를 열면 CPU 값 텍스트와 TOP 5 안내 문구가 존재하고 로딩 문구가 나타나지 않는지 확인합니다.
///
/// 이 환경(자동화된 실행)에서는 test runner bootstrap이 "Timed out while enabling automation mode."로
/// 멈춰 XCUITest 자체를 실행할 수 없었습니다. 실제 macOS 세션에서 Xcode로 실행해 확인해야 합니다.
/// 실행이 안 되었다는 사실과 이유는 구현 보고 §비고·한계에 남깁니다.
final class DashboardCPUCardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOpeningPopoverShowsCPUValueAndTopApplicationsCaptionWithoutLoadingText() throws {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "메뉴바 항목이 나타나지 않았습니다.")

        statusItem.click()

        let cpuCard = app.descendants(matching: .any).matching(identifier: "CPUCard").firstMatch
        XCTAssertTrue(cpuCard.waitForExistence(timeout: 5), "팝오버를 연 뒤 CPU 카드가 나타나지 않았습니다.")

        // CPU Collector는 두 번째 tick부터 값을 만들므로, 앱 시작 직후 첫 조회에서는
        // 카드가 "수집 중"일 수 있습니다. 값이 채워질 때까지 정상 수집 주기(최대 2초) 안에서 기다립니다.
        XCTAssertTrue(
            waitUntilLabelNoLongerContainsCollecting(cpuCard, timeout: 5),
            "CPU 카드가 5초 안에 수집 중 상태를 벗어나지 못했습니다. 실제 값: \(cpuCard.label)"
        )

        let label = cpuCard.label
        XCTAssertFalse(label.contains("수집 중"), "값이 있는데도 로딩 문구가 남아 있습니다. 실제 값: \(label)")
        XCTAssertTrue(label.contains("전체 사용률"), "CPU 값 텍스트가 접근성 이름에 없습니다. 실제 값: \(label)")
        XCTAssertTrue(
            label.contains("시스템 프로세스는 TOP 5에 포함되지 않습니다"),
            "TOP 5 안내 문구가 접근성 이름에 없습니다. 실제 값: \(label)"
        )
    }

    private func waitUntilLabelNoLongerContainsCollecting(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.label.contains("수집 중") {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        return !element.label.contains("수집 중")
    }
}
