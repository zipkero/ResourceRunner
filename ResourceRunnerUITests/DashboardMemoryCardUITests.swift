//
//  DashboardMemoryCardUITests.swift
//  ResourceRunnerUITests
//
//  Created by zipkero on 8/15/26.
//

import XCTest

/// task-009 검증 조건: 팝오버를 열면 Memory 카드 접근성 이름에 현재 Memory Pressure 단계 문자열이 있는지 확인합니다.
///
/// 이 환경(자동화된 실행)에서는 test runner bootstrap이 "Timed out while enabling automation mode."로
/// 멈춰 XCUITest 자체를 실행할 수 없었습니다(task-008과 같은 한계). 실제 macOS 세션에서 Xcode로 실행해 확인해야 합니다.
/// 실행이 안 되었다는 사실과 이유는 구현 보고 §비고·한계에 남깁니다.
final class DashboardMemoryCardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOpeningPopoverShowsMemoryPressureStageInAccessibilityLabel() throws {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "메뉴바 항목이 나타나지 않았습니다.")

        statusItem.click()

        let memoryCard = app.descendants(matching: .any).matching(identifier: "MemoryCard").firstMatch
        XCTAssertTrue(memoryCard.waitForExistence(timeout: 5), "팝오버를 연 뒤 Memory 카드가 나타나지 않았습니다.")

        // Memory는 순간값 조회라 첫 조회에서 바로 값이 나오지만, 수집 주기 안의 여유를 두고 기다립니다.
        XCTAssertTrue(
            waitUntilLabelNoLongerContainsCollecting(memoryCard, timeout: 5),
            "Memory 카드가 5초 안에 수집 중 상태를 벗어나지 못했습니다. 실제 값: \(memoryCard.label)"
        )

        let label = memoryCard.label
        XCTAssertFalse(label.contains("수집 중"), "값이 있는데도 로딩 문구가 남아 있습니다. 실제 값: \(label)")
        // 실제 기기의 Memory Pressure는 정상·경고·위험 중 무엇이든 될 수 있으므로 세 라벨 중 하나가 있는지만 확인합니다.
        XCTAssertTrue(
            ["정상", "경고", "위험"].contains { label.contains("Memory Pressure \($0)") },
            "Memory Pressure 단계 문자열이 접근성 이름에 없습니다. 실제 값: \(label)"
        )
        XCTAssertTrue(label.contains("사용 중 메모리"), "사용 중 메모리 값이 접근성 이름에 없습니다. 실제 값: \(label)")
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
