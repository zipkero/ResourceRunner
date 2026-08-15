//
//  DashboardCardSelectionUITests.swift
//  ResourceRunnerUITests
//
//  Created by zipkero on 8/15/26.
//

import XCTest

/// task-010 검증 조건: 팝오버를 연 뒤 각 카드의 단축키를 눌러 상세가 나타나는지, 같은 단축키를 다시 눌러
/// 요약 안내로 돌아오는지, 선택 전후 팝오버 프레임 크기가 동일한지를 확인합니다.
///
/// macOS 키보드 탐색(Full Keyboard Access)은 기본값이 꺼짐이고, 꺼진 상태에서는 Tab이 표준 `Button`에 닿지
/// 않는다는 것을 실행 중인 앱에서 확인했습니다(ANALYSIS §5 DP15). 그래서 카드 선택·복귀는 Tab이 아니라
/// `⌘1`(CPU)·`⌘2`(Memory) 단축키로 수행하며, 이 테스트도 그 수단을 그대로 씁니다.
///
/// 상세 영역의 SwiftUI `Text`는 접근성 계층에서 `AXValue`로만 문자열을 내보내고 `AXLabel`은 비어 있습니다.
/// 그래서 부분 일치 조회는 `label`이 아니라 `value`를 기준으로 만들어야 하며,
/// `label`로 조회하면 화면에 문구가 있어도 항상 0개가 잡힙니다(실행 중인 앱의 계층 덤프로 확인).
/// 문자열 전체가 같은 조회는 `app.staticTexts[문자열]` 첨자가 `value`까지 훑으므로 그대로 씁니다.
///
/// 팝오버는 `NSStatusItem` 아래 `Popover` 원소로 나타나고 `app.windows`에는 잡히지 않으므로,
/// 프레임 비교 대상도 `app.popovers`로 찾습니다.
///
/// VoiceOver의 실제 낭독은 spec.md 제외 범위이므로 여기서 확인하지 않습니다.
final class DashboardCardSelectionUITests: XCTestCase {

    private static let summaryGuidanceText = "카드를 선택하면 상세 정보가 여기에 표시됩니다."

    /// 상세 영역 문구를 부분 일치로 찾는 조회. 위 주석의 이유로 `value`를 기준으로 삼습니다.
    private func detailText(_ app: XCUIApplication, containing substring: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", substring)).firstMatch
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// `⌘1`로 CPU 상세가 나타나고 다시 누르면 요약 안내로 돌아오는지, `⌘2`로 Memory도 같은지 확인합니다.
    @MainActor
    func testKeyboardShortcutTogglesCardDetailAndReturnsToSummary() throws {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "메뉴바 항목이 나타나지 않았습니다.")

        statusItem.click()

        let cpuCard = app.descendants(matching: .any).matching(identifier: "CPUCard").firstMatch
        XCTAssertTrue(cpuCard.waitForExistence(timeout: 5), "팝오버를 연 뒤 CPU 카드가 나타나지 않았습니다.")

        // CPU Collector는 두 번째 tick부터 값을 만들므로, 앱 시작 직후에는 CPU 카드가 아직 `.collecting`일 수
        // 있습니다. 그 상태에서 상세를 열면 "Load Average" 대신 "아직 CPU 값이 수집되지 않았습니다."가 나와
        // 아래 단언이 어긋나므로, task-008 UI 테스트와 같은 방식으로 값이 채워질 때까지 먼저 기다립니다.
        XCTAssertTrue(
            waitUntilLabelNoLongerContainsCollecting(cpuCard, timeout: 5),
            "CPU 카드가 5초 안에 수집 중 상태를 벗어나지 못했습니다. 실제 값: \(cpuCard.label)"
        )

        let guidance = app.staticTexts[Self.summaryGuidanceText]
        XCTAssertTrue(guidance.waitForExistence(timeout: 2), "선택 전 요약 안내 문구가 상세 영역에 나타나지 않았습니다.")

        let loadAverageText = detailText(app, containing: "Load Average")
        let currentUsageHeading = app.staticTexts["현재 사용량 순위"]

        // ⌘1: CPU 카드 선택 -> 상세 등장 -> 다시 눌러 요약 안내로 복귀.
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(loadAverageText.waitForExistence(timeout: 2), "⌘1로 CPU 상세(Load Average)가 나타나지 않았습니다.")
        XCTAssertTrue(waitUntilGone(guidance, timeout: 2), "CPU 카드를 선택했는데도 요약 안내 문구가 사라지지 않았습니다.")

        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(guidance.waitForExistence(timeout: 2), "같은 ⌘1을 다시 눌렀는데도 요약 안내 문구로 돌아오지 않았습니다.")
        XCTAssertTrue(waitUntilGone(loadAverageText, timeout: 2), "선택 해제 후에도 CPU 상세(Load Average)가 남아 있습니다.")

        // ⌘2: Memory 카드 선택 -> 상세 등장 -> 다시 눌러 요약 안내로 복귀.
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(currentUsageHeading.waitForExistence(timeout: 2), "⌘2로 Memory 상세(현재 사용량 순위)가 나타나지 않았습니다.")
        XCTAssertTrue(waitUntilGone(guidance, timeout: 2), "Memory 카드를 선택했는데도 요약 안내 문구가 사라지지 않았습니다.")

        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(guidance.waitForExistence(timeout: 2), "같은 ⌘2를 다시 눌렀는데도 요약 안내 문구로 돌아오지 않았습니다.")
        XCTAssertTrue(
            waitUntilGone(currentUsageHeading, timeout: 2),
            "선택 해제 후에도 Memory 상세(현재 사용량 순위)가 남아 있습니다."
        )
    }

    /// 카드를 단축키로 선택하거나 해제해도 팝오버 프레임 크기가 바뀌지 않는지 확인합니다(ANALYSIS §5 DP14).
    @MainActor
    func testPopoverFrameSizeStaysTheSameBeforeAndAfterSelection() throws {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "메뉴바 항목이 나타나지 않았습니다.")

        statusItem.click()

        let cpuCard = app.descendants(matching: .any).matching(identifier: "CPUCard").firstMatch
        XCTAssertTrue(cpuCard.waitForExistence(timeout: 5), "팝오버를 연 뒤 CPU 카드가 나타나지 않았습니다.")

        // 값이 채워지기 전(`.collecting`)에 상세를 열면 "Load Average" 대신 수집 중 안내가 나와
        // 선택이 실제로 반영됐는지 확인하는 아래 대기가 헛돌므로, 값이 채워질 때까지 먼저 기다립니다.
        XCTAssertTrue(
            waitUntilLabelNoLongerContainsCollecting(cpuCard, timeout: 5),
            "CPU 카드가 5초 안에 수집 중 상태를 벗어나지 못했습니다. 실제 값: \(cpuCard.label)"
        )

        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 2), "팝오버를 찾지 못했습니다.")
        let frameBeforeSelection = popover.frame

        let loadAverageText = detailText(app, containing: "Load Average")
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(
            loadAverageText.waitForExistence(timeout: 2),
            "⌘1로 CPU 상세가 나타나지 않아 선택 뒤 프레임을 비교할 수 없습니다."
        )

        let frameAfterSelection = popover.frame
        XCTAssertEqual(
            frameAfterSelection, frameBeforeSelection,
            "카드를 선택한 뒤 팝오버 프레임 크기가 바뀌었습니다. 선택 전: \(frameBeforeSelection), 선택 후: \(frameAfterSelection)"
        )

        // 선택을 해제해도 마찬가지로 크기가 그대로여야 합니다.
        app.typeKey("1", modifierFlags: .command)
        let guidance = app.staticTexts[Self.summaryGuidanceText]
        XCTAssertTrue(guidance.waitForExistence(timeout: 2), "선택 해제 후 요약 안내로 돌아오지 않았습니다.")
        XCTAssertEqual(
            popover.frame, frameBeforeSelection,
            "선택 해제 후 팝오버 프레임 크기가 최초 크기와 달라졌습니다."
        )
    }

    /// CPU Collector는 두 번째 tick부터 값을 만들므로, 앱 시작 직후 첫 조회에서는 카드가 "수집 중"일 수
    /// 있습니다. 값이 채워질 때까지 정상 수집 주기(최대 2초) 안에서 기다립니다(`DashboardCPUCardUITests`와 같은 관례).
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
