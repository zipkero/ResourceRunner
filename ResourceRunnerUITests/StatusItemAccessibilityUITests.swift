//
//  StatusItemAccessibilityUITests.swift
//  ResourceRunnerUITests
//
//  Created by zipkero on 8/10/26.
//

import XCTest

/// task-012 검증 조건: 실행 중인 앱의 접근성 트리에 메뉴바 항목의 접근성 이름이 노출되고,
/// Debug 우클릭 메뉴로 상태를 주입하면 그 이름이 따라 바뀌는지 다섯 상태 전부에 대해 단언합니다.
///
/// 이 테스트는 팝오버 열림 유지를 관찰 대상으로 두지 않습니다. 주입 메뉴를 여는 동작은 메뉴바 항목 클릭이라
/// `NSPopover`가 외부 클릭으로 판정해 팝오버를 닫으며, 그것은 주입 수단의 성질입니다.
/// 팝오버 보존은 주입 수단을 거치지 않는 `StatusBarControllerTests`에서 확인합니다.
///
/// VoiceOver의 실제 낭독은 spec.md 제외 범위이므로 여기서 확인하지 않습니다.
final class StatusItemAccessibilityUITests: XCTestCase {

    /// Debug 주입 메뉴 항목의 제목과 그 상태에서 기대하는 접근성 이름.
    /// 제목은 `StatusBarController`의 디버그 메뉴가 `CharacterActivityState` case 이름을 그대로 쓴 값입니다.
    private static let injectionCases: [(menuItemTitle: String, expectedLabel: String)] = [
        ("moderate", "ResourceRunner, 보통"),
        ("high", "ResourceRunner, 높음"),
        ("veryHigh", "ResourceRunner, 매우 높음"),
        ("sustainedHigh", "ResourceRunner, 장시간 고부하"),
        ("low", "ResourceRunner, 낮음"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testStatusItemAccessibilityLabelFollowsInjectedState() throws {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "메뉴바 항목이 나타나지 않았습니다.")

        // 기본 실행은 `low`에서 시작하므로 주입 전 이름이 이미 그 상태를 담고 있어야 합니다.
        XCTAssertEqual(
            statusItem.label,
            "ResourceRunner, 낮음",
            "기동 직후 메뉴바 항목의 접근성 이름이 초기 상태를 담고 있지 않습니다."
        )

        for injection in Self.injectionCases {
            statusItem.rightClick()

            let menuItem = app.menuItems[injection.menuItemTitle]
            XCTAssertTrue(
                menuItem.waitForExistence(timeout: 2),
                "Debug 주입 메뉴에서 \(injection.menuItemTitle) 항목을 찾지 못했습니다."
            )
            menuItem.click()

            XCTAssertTrue(
                waitForLabel(injection.expectedLabel, of: statusItem, timeout: 2),
                "\(injection.menuItemTitle) 주입 뒤 접근성 이름이 \(injection.expectedLabel)로 바뀌지 않았습니다. "
                    + "실제 값: \(statusItem.label)"
            )
        }
    }

    /// 주입은 `AsyncStream` 소비를 거쳐 반영되므로 이름 변경이 클릭 직후에 보장되지 않습니다.
    private func waitForLabel(_ expected: String, of element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.label == expected {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        return element.label == expected
    }
}
