//
//  OneSessionMonitoringIntegrationUITests.swift
//  ResourceRunnerUITests
//

import XCTest

/// task-014: 실제 수집, 두 카드 상세, 메뉴바 상태 변화를 앱 한 번의 실행 안에서 확인합니다.
/// 팝오버 전이 시각은 앱의 MonitoringScheduler 로그와 같은 세션으로 대조할 수 있게 남깁니다.
final class OneSessionMonitoringIntegrationUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCardsDetailsAndRealCPULoadInOneAppSession() throws {
        let app = XCUIApplication()
        app.launch()
        record("app launched")

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "메뉴바 항목이 나타나지 않았습니다.")
        XCTAssertTrue(
            waitUntil({ statusItem.label == "ResourceRunner, 낮음" }, timeout: 15),
            "실제 부하를 주기 전 메뉴바 상태가 낮음으로 안정되지 않았습니다: \(statusItem.label)"
        )

        statusItem.click()
        record("dashboard opened")
        let cpuCard = app.descendants(matching: .any).matching(identifier: "CPUCard").firstMatch
        let memoryCard = app.descendants(matching: .any).matching(identifier: "MemoryCard").firstMatch
        XCTAssertTrue(cpuCard.waitForExistence(timeout: 5), "CPU 카드가 나타나지 않았습니다.")
        XCTAssertTrue(memoryCard.waitForExistence(timeout: 5), "Memory 카드가 나타나지 않았습니다.")
        XCTAssertTrue(
            waitUntil({ cpuCard.label.contains("전체 사용률") }, timeout: 10),
            "CPU 카드에 실제 수집값이 표시되지 않았습니다: \(cpuCard.label)"
        )
        XCTAssertTrue(
            waitUntil({ memoryCard.label.contains("사용 중") }, timeout: 10),
            "Memory 카드에 실제 수집값이 표시되지 않았습니다: \(memoryCard.label)"
        )

        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(waitUntil({ app.popovers.count == 2 }, timeout: 3), "CPU 상세 팝업이 열리지 않았습니다.")
        XCTAssertTrue(detailValue(app, containing: "Load Average").exists, "CPU 상세 값이 없습니다.")
        record("CPU detail opened")
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(waitUntil({ app.popovers.count == 1 }, timeout: 3), "CPU 상세 팝업이 닫히지 않았습니다.")
        record("CPU detail closed")

        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(waitUntil({ app.popovers.count == 2 }, timeout: 3), "Memory 상세 팝업이 열리지 않았습니다.")
        XCTAssertTrue(detailValue(app, containing: "현재 사용량 순위").exists, "Memory 상세 값이 없습니다.")
        record("Memory detail opened")
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(waitUntil({ app.popovers.count == 1 }, timeout: 3), "Memory 상세 팝업이 닫히지 않았습니다.")
        record("Memory detail closed")

        statusItem.click()
        XCTAssertTrue(waitUntil({ app.popovers.count == 0 }, timeout: 3), "본체 팝오버가 닫히지 않았습니다.")
        record("dashboard closed")

        var loadProcesses: [Process] = []
        defer { terminate(loadProcesses) }
        for _ in 0..<14 {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/yes")
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            loadProcesses.append(process)
        }
        record("CPU load started pids=\(loadProcesses.map(\.processIdentifier))")

        let highLabels = ["ResourceRunner, 매우 높음", "ResourceRunner, 장시간 고부하"]
        XCTAssertTrue(
            waitUntil({ highLabels.contains(statusItem.label) }, timeout: 35),
            "실제 CPU 부하 뒤 메뉴바 상태가 매우 높음으로 전환되지 않았습니다: \(statusItem.label)"
        )
        record("high CPU label observed: \(statusItem.label)")

        terminate(loadProcesses)
        loadProcesses.removeAll()
        record("CPU load stopped")
        XCTAssertTrue(
            waitUntil({ statusItem.label == "ResourceRunner, 낮음" }, timeout: 35),
            "부하 종료 뒤 메뉴바 상태가 낮음으로 복귀하지 않았습니다: \(statusItem.label)"
        )
        record("low CPU label restored")

        statusItem.click()
        XCTAssertTrue(cpuCard.waitForExistence(timeout: 5), "같은 앱 세션에서 대시보드가 다시 열리지 않았습니다.")
        XCTAssertTrue(memoryCard.exists, "재개방한 대시보드에 Memory 카드가 없습니다.")
        record("dashboard reopened")
        statusItem.click()
        XCTAssertTrue(waitUntil({ app.popovers.count == 0 }, timeout: 3), "재개방한 대시보드가 닫히지 않았습니다.")
        record("dashboard reclosed")
    }

    private func detailValue(_ app: XCUIApplication, containing substring: String) -> XCUIElement {
        app.popovers.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", substring)).firstMatch
    }

    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    private func terminate(_ processes: [Process]) {
        for process in processes where process.isRunning { process.terminate() }
        for process in processes { process.waitUntilExit() }
    }

    private func record(_ event: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        print("TASK014_ONE_SESSION \(formatter.string(from: Date())) runnerPID=\(ProcessInfo.processInfo.processIdentifier) \(event)")
    }
}
