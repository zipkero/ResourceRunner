//
//  CPUCoreAccessibilityUITests.swift
//  ResourceRunnerUITests
//
//  task-005 검증 조건: 코어 칸 접근성 서식이 실제 SwiftUI 접근성 요소에 붙는지 확인합니다.
//

import XCTest

final class CPUCoreAccessibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCoreCellIsOneReachableElementWithLabelValueAndIdentifier() throws {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "메뉴바 항목이 나타나지 않았습니다.")
        statusItem.click()

        let cpuCard = app.descendants(matching: .any).matching(identifier: "CPUCard").firstMatch
        XCTAssertTrue(cpuCard.waitForExistence(timeout: 5), "팝오버를 연 뒤 CPU 카드가 나타나지 않았습니다.")
        XCTAssertTrue(
            waitUntil({ !cpuCard.label.hasPrefix("CPU 카드, 수집 중,") }, timeout: 5),
            "CPU 카드가 5초 안에 수집 중 상태를 벗어나지 못했습니다. 실제 값: \(cpuCard.label)"
        )

        app.typeKey("1", modifierFlags: .command)

        let coreCell = app.popovers.descendants(matching: .any).matching(identifier: "CPUCore-0").firstMatch
        XCTAssertTrue(coreCell.waitForExistence(timeout: 2), "CPUCore-0 접근성 요소를 찾지 못했습니다.")
        XCTAssertEqual(coreCell.label, "코어 0")
        XCTAssertNotNil(
            (coreCell.value as? String)?.range(of: #"^[0-9]+%$"#, options: .regularExpression),
            "코어 칸 값이 정수 퍼센트가 아닙니다. 실제 값: \(String(describing: coreCell.value))"
        )

        let descendants = coreCell.descendants(matching: .any)
        XCTAssertEqual(
            descendants.count,
            0,
            "코어 칸 안쪽의 막대·수치·번호가 별도 접근성 요소로 노출됐습니다."
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
