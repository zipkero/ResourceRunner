import AppKit
import XCTest

/// 서명된 앱의 Disk 카드와 실제 볼륨·드라이버 상세, 공통 닫힘 경로를 확인합니다.
final class DiskCardUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testFourCardSummaryFitsVisibleScreenAndKeepsDiskCapacityAccessible() throws {
        let app = XCUIApplication()
        app.launch()
        let status = app.statusItems.firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        status.click()

        let body = app.descendants(matching: .any).matching(identifier: "DashboardContainer").firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        let cards = ["CPUCard", "MemoryCard", "NetworkCard", "DiskCard"].map {
            app.descendants(matching: .any).matching(identifier: $0).firstMatch
        }
        for card in cards {
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            XCTAssertTrue(card.isHittable, "네 카드가 스크롤 없이 보여야 합니다: \(card.identifier)")
        }
        XCTAssertFalse(app.scrollViews.containing(.any, identifier: "DiskCard").firstMatch.exists)
        XCTAssertEqual(body.frame.width, 280, accuracy: 1)
        XCTAssertEqual(cards[0].frame.width, 264, accuracy: 1)
        XCTAssertEqual(cards[0].frame.height, 241, accuracy: 1)
        XCTAssertEqual(cards[2].frame.height, 112, accuracy: 1)
        XCTAssertEqual(cards[3].frame.height, 112, accuracy: 1)
        for pair in zip(cards, cards.dropFirst()) {
            XCTAssertEqual(pair.1.frame.minY - pair.0.frame.maxY, 6, accuracy: 1)
        }
        let screen = try XCTUnwrap(NSScreen.main)
        let visible = screen.visibleFrame
        XCTAssertLessThanOrEqual(body.frame.maxY, screen.frame.height - visible.minY)
        XCTAssertGreaterThanOrEqual(body.frame.minY, screen.frame.height - visible.maxY)
        XCTAssertTrue(cards[0].label.contains("TOP 5"))
        XCTAssertTrue(cards[1].label.contains("Pressure"))
        XCTAssertTrue(cards[1].label.contains("Swap"))
        XCTAssertTrue(cards[3].label.contains("Disk 최근 10분 그래프"))
        XCTAssertTrue(waitUntil({ cards[3].label.contains("저장 공간 전체") }, timeout: 15))
        XCTAssertTrue(cards[3].label.contains("회수 가능한 공간 포함"))
        print("TASK011_FOUR_CARD visible=\(visible) body=\(body.frame) cards=\(cards.map(\.frame)) disk=\(cards[3].label)")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "task011-four-card-summary"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testRealDiskCardDetailAndReturnKeepFrames() throws {
        let app = XCUIApplication()
        app.launch()
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10))
        statusItem.click()

        let disk = app.descendants(matching: .any).matching(identifier: "DiskCard").firstMatch
        XCTAssertTrue(disk.waitForExistence(timeout: 10))
        let dashboard = app.descendants(matching: .any).matching(identifier: "DashboardContainer").firstMatch
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5))
        XCTAssertFalse(app.scrollViews.containing(.any, identifier: "DiskCard").firstMatch.exists)
        XCTAssertTrue(disk.isHittable, "Disk 카드가 본체 스크롤 없이 보여야 합니다.")

        let cardBefore = disk.frame
        let bodyBefore = dashboard.frame
        print("TASK011_ACTUAL_UI cardBefore=\(cardBefore) bodyBefore=\(bodyBefore) label=\(disk.label)")
        XCTAssertEqual(cardBefore.height, 112, accuracy: 1)

        disk.click()
        let detail = app.descendants(matching: .any).matching(identifier: "DiskDetail").firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertEqual(app.popovers.count, 2)
        XCTAssertLessThanOrEqual(detail.frame.width, 400)
        XCTAssertLessThanOrEqual(detail.frame.height, 480)
        let summary = detail.descendants(matching: .any).matching(identifier: "DiskSummary").firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        let volume = detail.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "DiskVolume-"))
            .firstMatch
        XCTAssertTrue(volume.waitForExistence(timeout: 10))
        print("TASK011_ACTUAL_UI summary=\(summary.label) volume=\(volume.label)")
        XCTAssertTrue(summary.label.contains("전체"))
        XCTAssertTrue(summary.label.contains("사용 가능"))
        XCTAssertTrue(summary.label.contains("전체 − 사용 가능"))
        XCTAssertTrue(volume.label.contains("사용 중"))
        XCTAssertTrue(volume.label.contains("공유 공간"))
        XCTAssertEqual(disk.frame, cardBefore)
        XCTAssertEqual(dashboard.frame, bodyBefore)

        let close = app.buttons.matching(identifier: "DiskDetailClose").firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 2))
        close.click()
        XCTAssertTrue(waitUntil({ !detail.exists }, timeout: 3))
        XCTAssertEqual(disk.frame, cardBefore)
        XCTAssertEqual(dashboard.frame, bodyBefore)
        disk.click()
        XCTAssertTrue(detail.waitForExistence(timeout: 3))
        disk.click()
        XCTAssertTrue(waitUntil({ !detail.exists }, timeout: 3))
        print("TASK011_ACTUAL_UI cardAfter=\(disk.frame) bodyAfter=\(dashboard.frame)")
    }

    @MainActor
    func testSandboxCapacityUsesDecimalUnitsAndReclaimableSpace() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--dashboard-preferences-ui-test", "-AppleLocale", "en_US"]
        app.launch()
        let status = app.statusItems.firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        status.click()
        let disk = app.buttons["DiskCard"]
        XCTAssertTrue(disk.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil({ disk.label.contains("저장 공간 전체") }, timeout: 15), disk.label)
        let pattern = #"저장 공간 전체 ([0-9,.]+) ([KMGT]?B), 사용 가능 ([0-9,.]+) ([KMGT]?B)"#
        let expression = try NSRegularExpression(pattern: pattern)
        let label = disk.label
        let match = try XCTUnwrap(expression.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)))
        let decimalUnits: [String: Double] = ["B": 1, "KB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12]
        func displayedBytes(number: Int, unit: Int) throws -> Double {
            let numberRange = try XCTUnwrap(Range(match.range(at: number), in: label))
            let unitRange = try XCTUnwrap(Range(match.range(at: unit), in: label))
            let value = try XCTUnwrap(Double(label[numberRange].replacingOccurrences(of: ",", with: "")))
            return value * (try XCTUnwrap(decimalUnits[String(label[unitRange])]))
        }
        let values = try URL(fileURLWithPath: "/").resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        let total = try XCTUnwrap(values.volumeTotalCapacity)
        let important = try XCTUnwrap(values.volumeAvailableCapacityForImportantUsage)
        XCTAssertEqual(try displayedBytes(number: 1, unit: 2), Double(total), accuracy: 50_000_001)
        // 보조 조회와 UI 관찰의 시각 차이를 허용하되 순수 여유 공간과 이진 환산의 큰 차이를 검출합니다.
        XCTAssertEqual(try displayedBytes(number: 3, unit: 4), Double(important), accuracy: 1_000_000_000)
        XCTAssertTrue(label.contains("회수 가능한 공간 포함"))
        XCTAssertFalse(app.scrollViews.containing(.any, identifier: "DiskCard").firstMatch.exists)
        XCTAssertEqual(disk.frame.height, 112, accuracy: 1)
        print("MACOS_CAPACITY_RAW total=\(total) rawAvailable=\(values.volumeAvailableCapacity ?? -1) importantAvailable=\(important) card=\(label) frame=\(disk.frame)")
        let body = app.descendants(matching: .any).matching(identifier: "DashboardContainer").firstMatch
        let bodyFrame = body.frame
        let cardFrame = disk.frame
        disk.click()
        let summary = app.descendants(matching: .any).matching(identifier: "DiskSummary").firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("회수할 수 있는 공간"))
        XCTAssertTrue(summary.label.contains("실제 파일 점유량이 아닙니다"))
        print("MACOS_CAPACITY_DETAIL summary=\(summary.label)")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "macOS-capacity-detail"
        attachment.lifetime = .keepAlways
        add(attachment)
        let volume = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "DiskVolume-")).firstMatch
        XCTAssertTrue(volume.waitForExistence(timeout: 5))
        XCTAssertTrue(volume.label.contains("사용 중"))
        XCTAssertTrue(volume.label.contains("회수할 수 있는 공간"))
        print("MACOS_CAPACITY_VOLUME row=\(volume.label)")
        app.buttons["DiskDetailClose"].click()
        XCTAssertTrue(waitUntil({ !summary.exists }, timeout: 3))
        XCTAssertEqual(disk.frame, cardFrame)
        XCTAssertEqual(body.frame, bodyFrame)
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
