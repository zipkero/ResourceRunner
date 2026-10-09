import XCTest

final class ExpandedPreferencesIntegrationUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func wait(_ condition: () -> Bool, seconds: TimeInterval = 5) -> Bool {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    private func body(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "DashboardContainer").firstMatch
    }

    private func groupRows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.popovers.descendants(matching: .disclosureTriangle)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "AppRow-"))
    }

    private func group(_ name: String, in app: XCUIApplication) -> XCUIElement {
        groupRows(app).matching(identifier: "AppRow-/tmp/\(name).app").firstMatch
    }

    private func group00ChildValues(_ app: XCUIApplication) -> XCUIElementQuery {
        app.popovers.staticTexts.matching(identifier: "AppRow-/tmp/RRFixtureGroup00.app")
    }

    private func expandGroup00(in app: XCUIApplication) {
        let row = group("RRFixtureGroup00", in: app)
        let scroll = app.popovers.scrollViews["DashboardDetail"]
        for step in 0..<12 where !row.isHittable {
            let rowFrame = row.frame
            let viewport = scroll.frame
            print("TASK016_GROUP_SCROLL step=\(step) row=\(rowFrame) viewport=\(viewport)")
            if rowFrame.midY > viewport.maxY { app.typeKey(.pageDown, modifierFlags: []) }
            else if rowFrame.midY < viewport.minY { app.typeKey(.pageUp, modifierFlags: []) }
            else { break }
        }
        XCTAssertTrue(row.isHittable, "혼합 UID 앱 행이 상세 스크롤 안에서 도달 가능해야 합니다.")
        if (row.value as? NSNumber)?.intValue != 1 {
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
                .withOffset(CGVector(dx: 0, dy: 8)).click()
        }
        XCTAssertTrue(wait({ (row.value as? NSNumber)?.intValue == 1 }),
                      "혼합 UID 앱 행의 실제 펼침 상태가 1이어야 합니다.")
    }

    private func showDetail(_ key: String, in app: XCUIApplication) {
        XCTAssertTrue(body(app).exists)
        body(app).click()
        // 설정창 클릭으로 자식 팝오버만 닫혔을 수 있으므로 다른 카드를 먼저 고릅니다.
        app.typeKey(key == "1" ? "2" : "1", modifierFlags: .command)
        app.typeKey(key, modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "DashboardDetail")
            .firstMatch.waitForExistence(timeout: 3))
    }

    private func selectLimit(_ count: Int, in app: XCUIApplication) {
        let picker = app.popUpButtons["SettingsDetailListLimit"]
        picker.click()
        app.menuItems["\(count)개"].click()
        XCTAssertTrue((picker.value as? String ?? "").contains(String(count)))
    }

    private func increaseRowNames(_ app: XCUIApplication) -> [String] {
        let tree = app.debugDescription
        guard let heading = tree.range(of: "value: 최근 10분 증가량 순위") else { return [] }
        let remainder = tree[heading.upperBound...]
        guard let usageRow = remainder.range(of: "DisclosureTriangle") else { return [] }
        let section = String(remainder[..<usageRow.lowerBound])
        let expression = try! NSRegularExpression(pattern: "value: (RRFixture(?:Group[0-9]{2}|OtherOnly))")
        let range = NSRange(section.startIndex..<section.endIndex, in: section)
        return expression.matches(in: section, range: range).compactMap { match in
            Range(match.range(at: 1), in: section).map { String(section[$0]) }
        }
    }

    private func byteNumber(_ text: String, unit: String) -> Double? {
        let expression = try! NSRegularExpression(pattern: "([0-9]+(?:\\.[0-9]+)?),?\\s+\(unit)")
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: range),
              let numberRange = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[numberRange])
    }

    private func open(_ app: XCUIApplication) {
        app.activate()
        Thread.sleep(forTimeInterval: 0.35)
        app.statusItems.firstMatch.click()
        XCTAssertTrue(body(app).waitForExistence(timeout: 3))
    }

    @MainActor
    func testActualOutsideClickAndOtherAppActivationFollowBothBehaviors() {
        let app = XCUIApplication()
        app.launchArguments += ["--popover-behavior-ui-test", "--dashboard-preferences-ui-test", "--settings-ui-test"]
        app.launch()
        let status = app.statusItems.firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        open(app)
        finder.activate()
        XCTAssertTrue(wait({ !self.body(app).exists }), "기본 켬에서 다른 앱 활성화가 본체를 닫아야 합니다.")
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows["ResourceRunner 설정"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        XCTAssertTrue(wait({ !self.body(app).exists }))
        open(app)
        let outside = settings.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5))
        let outsidePoint = CGPoint(x: settings.frame.minX + settings.frame.width * 0.05,
                                   y: settings.frame.minY + settings.frame.height * 0.5)
        XCTAssertFalse(body(app).frame.contains(outsidePoint), "외부 클릭 좌표는 본체 바깥이어야 합니다.")
        outside.click()
        XCTAssertTrue(wait({ !self.body(app).exists }), "기본 켬에서 같은 앱의 실제 외부 클릭이 본체를 닫아야 합니다.")

        open(app)
        app.typeKey("-", modifierFlags: [.command, .shift])
        XCTAssertTrue(body(app).exists, "열린 상태에서 behavior 변경으로 강제 닫히면 안 됩니다.")
        outside.click()
        XCTAssertTrue(body(app).exists, "끔에서 같은 앱의 외부 클릭 뒤 본체가 남아야 합니다.")
        finder.activate()
        XCTAssertTrue(body(app).exists, "끔에서 다른 앱 활성화 뒤 본체가 남아야 합니다.")
        app.activate()
        body(app).click()
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "DashboardDetail")
            .firstMatch.waitForExistence(timeout: 3))
        app.typeKey(.pageDown, modifierFlags: [])
        app.typeKey(.pageUp, modifierFlags: [])
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(body(app).exists, "상세 Escape는 본체로 복귀해야 합니다.")
        app.typeKey("-", modifierFlags: [.command, .shift])
        XCTAssertTrue(body(app).exists, "끔→켬 변경으로 강제 닫히면 안 됩니다.")
        finder.activate()
        XCTAssertTrue(wait({ !self.body(app).exists }), "다시 켠 뒤 실제 activation으로 닫혀야 합니다.")
        open(app)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(wait({ !self.body(app).exists }), "켬에서 본체 Escape가 닫아야 합니다.")
    }

    @MainActor
    func testRenderedFiftyGroupsAndMixedUIDUseProductionRankingPath() {
        let app = XCUIApplication()
        app.launchArguments += ["--process-ranking-ui-fixture", "--dashboard-preferences-ui-test", "--settings-ui-test"]
        app.launch()
        XCTAssertTrue(app.statusItems.firstMatch.waitForExistence(timeout: 5))
        open(app)
        let cpu = app.descendants(matching: .any).matching(identifier: "CPUCard").firstMatch
        XCTAssertTrue(wait({ cpu.label.contains("시스템 프로세스 제외") }, seconds: 8))
        XCTAssertFalse(cpu.label.contains("RRFixtureOtherOnly"))
        app.typeKey("1", modifierFlags: .command)
        let detail = app.descendants(matching: .any).matching(identifier: "DashboardDetail").firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 3))
        XCTAssertTrue(app.popovers.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", "상위 20개")).firstMatch.exists)
        XCTAssertEqual(groupRows(app).count, 20)
        XCTAssertTrue(group("RRFixtureGroup00", in: app).exists)
        XCTAssertFalse(group("RRFixtureOtherOnly", in: app).exists)
        expandGroup00(in: app)
        print("TASK016_CURRENT_CHILD_VALUES \(group00ChildValues(app).allElementsBoundByIndex.map { String(describing: $0.value) })")
        XCTAssertEqual(group00ChildValues(app).count, 2, "기본 제외는 현재 UID 하위 이름·값 한 쌍만 남겨야 합니다.")
        XCTAssertTrue(group00ChildValues(app).allElementsBoundByIndex.contains {
            String(describing: $0.value).contains("current (PID 50000)")
        })
        XCTAssertFalse(group00ChildValues(app).allElementsBoundByIndex.contains {
            String(describing: $0.value).contains("other (PID 60000)")
        })
        showDetail("2", in: app)
        let memoryCard = app.descendants(matching: .any).matching(identifier: "MemoryCard").firstMatch
        XCTAssertTrue(memoryCard.label.contains("시스템 프로세스 제외"), memoryCard.label)
        XCTAssertEqual(groupRows(app).count, 20)
        XCTAssertFalse(group("RRFixtureOtherOnly", in: app).exists)
        let currentOnlyMemory = byteNumber(group("RRFixtureGroup00", in: app).label, unit: "MB")
        XCTAssertNotNil(currentOnlyMemory)
        XCTAssertTrue(wait({ self.increaseRowNames(app).count == 20 }, seconds: 40))
        XCTAssertEqual(increaseRowNames(app), (0..<20).map { String(format: "RRFixtureGroup%02d", $0) })
        print("TASK016_DEFAULT_MEMORY_AX usage=\(groupRows(app).count) increase=\(increaseRowNames(app).count) currentMB=\(String(describing: currentOnlyMemory))")

        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows["ResourceRunner 설정"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        let title = settings.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03))
        title.press(forDuration: 0.2, thenDragTo: title.withOffset(CGVector(dx: -450, dy: 0)))
        app.switches["SettingsAutomaticallyClosesPopover"].click()
        app.typeKey("0", modifierFlags: [.command, .option])
        selectLimit(50, in: app)
        XCTAssertEqual((app.switches["SettingsIncludeSystemProcesses"].value as? NSNumber)?.intValue, 1)
        settings.buttons["_XCUI:CloseWindow"].click()
        if !body(app).exists { open(app) }
        showDetail("1", in: app)
        XCTAssertTrue(wait({ app.popovers.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", "상위 50개")).firstMatch.exists }))
        XCTAssertTrue(cpu.label.contains("읽기 가능한 시스템 프로세스 포함"), cpu.label)
        XCTAssertTrue(wait({ self.group("RRFixtureOtherOnly", in: app).exists }, seconds: 12), "두 번째 실제 조사 뒤 다른 UID 전용 그룹이 50위 안에 들어야 합니다.")
        XCTAssertEqual(groupRows(app).count, 50)
        XCTAssertTrue(group("RRFixtureGroup48", in: app).exists)
        XCTAssertFalse(group("RRFixtureGroup49", in: app).exists)
        expandGroup00(in: app)
        print("TASK016_MIXED_CHILD_VALUES \(group00ChildValues(app).allElementsBoundByIndex.map { String(describing: $0.value) })")
        XCTAssertEqual(group00ChildValues(app).count, 4, "포함은 두 UID 하위 이름·값 두 쌍을 남겨야 합니다.")
        XCTAssertTrue(group00ChildValues(app).allElementsBoundByIndex.contains {
            String(describing: $0.value).contains("other (PID 60000)")
        })
        let childCPUPercent = group00ChildValues(app).allElementsBoundByIndex.compactMap { element -> Int? in
            let text = String(describing: element.value)
            guard text.contains("%") else { return nil }
            return Int(text.split(separator: "%").first?.filter(\.isNumber) ?? "")
        }
        XCTAssertEqual(childCPUPercent.count, 2)
        let groupCPUPercent = Int(group("RRFixtureGroup00", in: app).label.split(separator: "%").first?.filter(\.isNumber) ?? "")
        XCTAssertEqual(groupCPUPercent, childCPUPercent.reduce(0, +), "혼합 UID 앱 합계는 두 실제 하위 CPU 값을 더해야 합니다.")
        print("TASK016_CPU50_AX count=\(groupRows(app).count) mixedChildElements=\(group00ChildValues(app).count) otherOnly=1")

        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        selectLimit(10, in: app)
        settings.buttons["_XCUI:CloseWindow"].click()
        showDetail("1", in: app)
        XCTAssertTrue(wait({ self.groupRows(app).count == 10 }))
        XCTAssertTrue(group("RRFixtureOtherOnly", in: app).exists)
        XCTAssertFalse(group("RRFixtureGroup09", in: app).exists)
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        selectLimit(20, in: app)
        settings.buttons["_XCUI:CloseWindow"].click()
        showDetail("1", in: app)
        XCTAssertTrue(wait({ self.groupRows(app).count == 20 }))
        XCTAssertTrue(group("RRFixtureGroup18", in: app).exists)
        XCTAssertFalse(group("RRFixtureGroup19", in: app).exists)
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        selectLimit(50, in: app)
        settings.buttons["_XCUI:CloseWindow"].click()
        showDetail("1", in: app)
        XCTAssertTrue(wait({ self.groupRows(app).count == 50 }))
        showDetail("2", in: app)
        XCTAssertTrue(memoryCard.label.contains("읽기 가능한 시스템 프로세스 포함"), memoryCard.label)
        XCTAssertTrue(app.popovers.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", "상위 50개")).firstMatch.exists)
        XCTAssertEqual(groupRows(app).count, 50)
        XCTAssertTrue(group("RRFixtureOtherOnly", in: app).exists)
        XCTAssertTrue(group("RRFixtureGroup48", in: app).exists)
        XCTAssertFalse(group("RRFixtureGroup49", in: app).exists)
        print("TASK016_MEMORY_GROUP00_LABEL \(group("RRFixtureGroup00", in: app).label)")
        let combinedGigabytes = byteNumber(group("RRFixtureGroup00", in: app).label, unit: "GB")
        XCTAssertNotNil(combinedGigabytes)
        XCTAssertGreaterThan(combinedGigabytes ?? 0, 1.0, "혼합 UID Group00의 두 원시 메모리 무게 550+600 MiB가 합산되어야 합니다.")
        print("TASK016_MIXED_MEMORY_AX groupGB=\(String(describing: combinedGigabytes))")
        XCTAssertTrue(app.popovers.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", "최근 10분 증가량")).firstMatch.exists)
        print("TASK016_MEMORY50_AX count=\(groupRows(app).count)")
        print("TASK016_INCREASE_INITIAL count=\(increaseRowNames(app).count)")
        XCTAssertTrue(wait({ self.increaseRowNames(app).count == 50 }, seconds: 40),
                      "30초 기준점 이후 Memory 증가량 목록 50개가 실제 AX에 나타나야 합니다.")
        XCTAssertEqual(increaseRowNames(app).count, 50)
        XCTAssertEqual(increaseRowNames(app), (0..<50).map { String(format: "RRFixtureGroup%02d", $0) },
                       "증가량 동률은 앱 키 사전순이며 사용량의 OtherOnly와 다른 순위를 유지해야 합니다.")
        print("TASK016_INCREASE50_NAMES \(increaseRowNames(app))")
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        for count in [10, 20, 50] {
            selectLimit(count, in: app)
            settings.buttons["_XCUI:CloseWindow"].click()
            showDetail("2", in: app)
            XCTAssertTrue(wait({ self.groupRows(app).count == count }))
            XCTAssertTrue(wait({ self.increaseRowNames(app).count == count }))
            XCTAssertEqual(increaseRowNames(app), (0..<count).map { String(format: "RRFixtureGroup%02d", $0) })
            XCTAssertTrue(group("RRFixtureOtherOnly", in: app).exists)
            XCTAssertTrue(group(String(format: "RRFixtureGroup%02d", count - 2), in: app).exists)
            XCTAssertFalse(group(String(format: "RRFixtureGroup%02d", count - 1), in: app).exists)
            print("TASK016_MEMORY_AX limit=\(count) usage=\(groupRows(app).count) increase=\(increaseRowNames(app))")
            if count != 50 {
                app.typeKey(",", modifierFlags: .command)
                XCTAssertTrue(settings.waitForExistence(timeout: 3))
            }
        }
        expandGroup00(in: app)
        let childMegabytes = group00ChildValues(app).allElementsBoundByIndex.compactMap {
            byteNumber(String(describing: $0.value), unit: "MB")
        }
        XCTAssertEqual(childMegabytes.count, 2)
        let finalGroupGigabytes = byteNumber(group("RRFixtureGroup00", in: app).label, unit: "GB")
        XCTAssertEqual(finalGroupGigabytes ?? 0, childMegabytes.reduce(0, +) / 1024, accuracy: 0.06)
        print("TASK016_MIXED_MEMORY_CHILD_AX childrenMB=\(childMegabytes) groupGB=\(String(describing: finalGroupGigabytes))")
    }
}
