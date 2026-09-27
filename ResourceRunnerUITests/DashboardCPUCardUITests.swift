//
//  DashboardCPUCardUITests.swift
//  ResourceRunnerUITests
//
//  Created by zipkero on 8/15/26.
//

import XCTest

/// 팝오버를 열면 CPU 값·그래프 수집 진행·TOP 5 머리글이 접근성 이름에 함께 있는지 확인합니다.
final class DashboardCPUCardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOpeningPopoverShowsCPUValueCollectionProgressAndTopApplicationsHeading() throws {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "메뉴바 항목이 나타나지 않았습니다.")

        // 팝오버가 닫힌 수집 주기는 정상 2초·저전력 5초입니다. 두 경우 모두 첫 기준점과 다음 유효 tick 뒤에 엽니다.
        Thread.sleep(forTimeInterval: 12)

        statusItem.click()

        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 5), "메뉴바 항목을 누른 뒤 팝오버가 나타나지 않았습니다.")
        // CPU 카드는 하위 Text를 하나의 Button 접근성 이름으로 묶으므로 첫 팝오버 AX 트리를 한 번에 보존합니다.
        let firstPopoverAX = popover.debugDescription
        let firstCPUButtonAX = firstPopoverAX.split(separator: "\n").first { $0.contains("identifier: 'CPUCard'") } ?? ""
        XCTAssertFalse(firstCPUButtonAX.isEmpty, "첫 팝오버 AX 조회에 CPU 카드가 없습니다. AX: \(firstPopoverAX)")
        XCTAssertTrue(firstCPUButtonAX.contains("전체 사용률"), "첫 팝오버 AX 조회에 CPU 값이 없습니다. AX: \(firstPopoverAX)")
        XCTAssertTrue(
            firstCPUButtonAX.contains("앱 TOP 5 · 시스템 프로세스 제외"),
            "첫 팝오버 AX 조회에 TOP 5 안내 문구가 없습니다. AX: \(firstPopoverAX)"
        )
        XCTAssertFalse(
            firstCPUButtonAX.contains("label: 'CPU 카드, 수집 중,"),
            "첫 팝오버 AX 조회에 로딩 상태가 남았습니다. AX: \(firstPopoverAX)"
        )
        let cpuCard = popover.descendants(matching: .any).matching(identifier: "CPUCard").firstMatch
        XCTAssertTrue(cpuCard.exists, "팝오버 첫 조회에 CPU 카드가 없습니다.")

        // 값을 기다리지 않고 첫 카드 AX 이름을 보존합니다. 이후 tick이 도착해도 이 판정은 바뀌지 않습니다.
        let label = cpuCard.label
        XCTAssertTrue(label.contains("전체 사용률"), "CPU 값 텍스트가 접근성 이름에 없습니다. 실제 값: \(label)")
        XCTAssertFalse(label.hasPrefix("CPU 카드, 수집 중,"), "팝오버 첫 조회에 로딩 상태가 남았습니다. 실제 값: \(label)")
        XCTAssertNotNil(label.range(of: #"User [0-9]+%"#, options: .regularExpression), "CPU User 수치가 접근성 이름에 없습니다. 실제 값: \(label)")
        XCTAssertNotNil(label.range(of: #"System [0-9]+%"#, options: .regularExpression), "CPU System 수치가 접근성 이름에 없습니다. 실제 값: \(label)")
        XCTAssertTrue(label.contains("두 계열 중첩 그래프"), "CPU 그래프의 중첩 관계가 접근성 이름에 없습니다. 실제 값: \(label)")
        XCTAssertTrue(label.contains("기준선 50%"), "CPU 기준선 값이 접근성 이름에 없습니다. 실제 값: \(label)")
        XCTAssertTrue(label.contains("최근 10분 그래프"), "CPU 그래프의 시간 창이 접근성 이름에 없습니다. 실제 값: \(label)")
        XCTAssertNotNil(
            label.range(of: #"데이터 수집 중 · [0-9]{2}:[0-9]{2} / 10:00"#, options: .regularExpression),
            "CPU 그래프의 수집 진행 문구가 접근성 이름에 없습니다. 실제 값: \(label)"
        )
        XCTAssertTrue(
            label.contains("앱 TOP 5 · 시스템 프로세스 제외"),
            "TOP 5 머리글이 접근성 이름에 없습니다. 실제 값: \(label)"
        )
    }

    /// task-015 검증 조건: 앱 시작 직후 수집 중 상태의 CPU 카드 프레임과 첫 수집이 도착한 뒤의 프레임이 같은지 확인합니다.
    /// 이 단언이 고정하는 것은 "첫 수집이 카드를 부풀리지 않는다"입니다 — 상태별로 슬롯을 접는 분기를
    /// 되살리면(그래프·순위 자리가 값이 생긴 뒤에야 나타나면) 이 단언이 실패해야 합니다(ANALYSIS §5 DP17).
    @MainActor
    func testCPUCardFrameStaysSameBeforeAndAfterFirstCollection() throws {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "메뉴바 항목이 나타나지 않았습니다.")

        statusItem.click()

        let cpuCard = app.descendants(matching: .any).matching(identifier: "CPUCard").firstMatch
        XCTAssertTrue(cpuCard.waitForExistence(timeout: 5), "팝오버를 연 뒤 CPU 카드가 나타나지 않았습니다.")

        // 첫 수집이 도착하기 전(수집 중일 수 있는 시점)의 프레임을 먼저 잡습니다.
        let frameBeforeFirstCollection = cpuCard.frame

        XCTAssertTrue(
            waitUntilLabelContainsUsage(cpuCard, timeout: 5),
            "CPU 카드가 5초 안에 수집 중 상태를 벗어나지 못했습니다. 실제 값: \(cpuCard.label)"
        )

        XCTAssertEqual(
            cpuCard.frame, frameBeforeFirstCollection,
            "첫 수집이 도착한 뒤 CPU 카드 프레임이 바뀌었습니다. 이전: \(frameBeforeFirstCollection), 이후: \(cpuCard.frame)"
        )
    }

    private func waitUntilLabelContainsUsage(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.label.contains("전체 사용률") {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        return element.label.contains("전체 사용률")
    }
}
