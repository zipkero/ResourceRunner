import XCTest

final class SettingsWindowUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(cards: Int = 15, login: String = "notRegistered",
                        register: String = "enabled", unregister: String = "notRegistered") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--dashboard-preferences-ui-test", "--settings-ui-test"]
        app.launchEnvironment["RR_DASHBOARD_CARD_MASK"] = String(cards)
        app.launchEnvironment["RR_LOGIN_STATUS"] = login
        app.launchEnvironment["RR_LOGIN_REGISTER_OUTCOME"] = register
        app.launchEnvironment["RR_LOGIN_UNREGISTER_OUTCOME"] = unregister
        app.launch()
        return app
    }

    private func persistentApp(suite: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--preferences-persistence-ui-test", "--settings-ui-test"]
        app.launchEnvironment["RR_PREFERENCES_TEST_SUITE"] = suite
        app.launchEnvironment["RR_LOGIN_STATUS"] = "enabled"
        app.launchEnvironment["RR_LOGIN_UNREGISTER_OUTCOME"] = "failure"
        return app
    }

    private func settingsWindow(_ app: XCUIApplication) -> XCUIElement {
        app.windows["ResourceRunner 설정"]
    }

    private func switchValue(_ element: XCUIElement) -> Int? {
        (element.value as? NSNumber)?.intValue
    }

    private func textValue(_ element: XCUIElement) -> String {
        (element.value as? String) ?? element.label
    }

    private func closeSettings(_ app: XCUIApplication) {
        settingsWindow(app).buttons["_XCUI:CloseWindow"].click()
    }

    private func focusByTab(_ identifier: String, in app: XCUIApplication) -> Bool {
        for _ in 0..<24 {
            if let line = app.debugDescription.split(separator: "\n")
                .first(where: { $0.contains("identifier: '\(identifier)'") }),
               line.contains("Keyboard Focused") { return true }
            app.typeKey(.tab, modifierFlags: [])
        }
        return false
    }

    private func settingsOwnsKeyboardFocus(_ app: XCUIApplication) -> Bool {
        let tree = app.debugDescription
        guard let start = tree.range(of: "identifier: 'ResourceRunnerSettingsWindow'") else {
            return false
        }
        let suffix = tree[start.lowerBound...]
        let windowTree = suffix.prefix(upTo: suffix.range(of: "    MenuBar,")?.lowerBound ?? suffix.endIndex)
        return windowTree.contains("Keyboard Focused")
    }

    private func openFromStatusMenu(_ app: XCUIApplication) {
        let status = app.statusItems.firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        status.rightClick()
        let item = app.menuItems["openSettingsFromMenu:"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.click()
        XCTAssertTrue(settingsWindow(app).waitForExistence(timeout: 3))
    }

    @MainActor
    func testRightClickAndCommandCommaReuseOneWindowWithoutOpeningAtLaunch() {
        let app = launch()
        XCTAssertFalse(settingsWindow(app).exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "DashboardContainer").firstMatch.exists)
        openFromStatusMenu(app)
        XCTAssertEqual(app.windows.matching(identifier: "ResourceRunner 설정").count, 1)
        let login = app.staticTexts["SettingsLoginStatus"]
        XCTAssertTrue(login.exists)
        XCTAssertTrue(textValue(login).contains("등록되지"))
        closeSettings(app)
        XCTAssertFalse(settingsWindow(app).exists)
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(settingsWindow(app).waitForExistence(timeout: 3))
        XCTAssertEqual(app.windows.matching(identifier: "ResourceRunner 설정").count, 1)
    }

    @MainActor
    func testProcessScopeAndDetailLimitControlsApplyInCurrentWindow() {
        let app = launch()
        openFromStatusMenu(app)
        let window = settingsWindow(app)
        let scope = app.switches["SettingsIncludeSystemProcesses"]
        XCTAssertTrue(scope.waitForExistence(timeout: 3))
        XCTAssertEqual(switchValue(scope), 0)
        app.typeKey("0", modifierFlags: [.command, .option])
        XCTAssertEqual(switchValue(scope), 1)

        let limit = app.popUpButtons["SettingsDetailListLimit"]
        XCTAssertTrue(limit.waitForExistence(timeout: 3))
        XCTAssertTrue(textValue(limit).contains("20"))
        limit.click()
        app.menuItems["50개"].click()
        XCTAssertTrue(textValue(limit).contains("50"))
        limit.click()
        app.menuItems["10개"].click()
        XCTAssertTrue(textValue(limit).contains("10"))
        XCTAssertTrue(focusByTab("SettingsNextDetailListLimit", in: app))
        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(textValue(limit).contains("20"))
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(textValue(limit).contains("50"))
        XCTAssertTrue(window.exists)
        XCTAssertEqual(app.windows.matching(identifier: "ResourceRunnerSettingsWindow").count, 1)
    }

    @MainActor
    func testAutomaticPopoverCloseToggleSupportsKeyboardAndAccessibility() {
        let app = launch()
        openFromStatusMenu(app)
        let window = settingsWindow(app)
        let toggle = app.switches["SettingsAutomaticallyClosesPopover"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        XCTAssertEqual(toggle.label, "팝오버 자동 닫기")
        XCTAssertEqual(switchValue(toggle), 1)
        app.typeKey("-", modifierFlags: [.command, .option])
        XCTAssertEqual(switchValue(toggle), 0)
        app.typeKey("-", modifierFlags: [.command, .option])
        XCTAssertEqual(switchValue(toggle), 1)
        toggle.click()
        XCTAssertEqual(switchValue(toggle), 0)
        XCTAssertTrue(window.exists)
        XCTAssertEqual(app.windows.matching(identifier: "ResourceRunnerSettingsWindow").count, 1)
    }

    @MainActor
    func testAutomaticCloseOffKeepsExplicitBodyAndDetailEscape() {
        let app = launch()
        openFromStatusMenu(app)
        let toggle = app.switches["SettingsAutomaticallyClosesPopover"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.click()
        XCTAssertEqual(switchValue(toggle), 0)
        closeSettings(app)

        let status = app.statusItems.firstMatch
        status.click()
        let body = app.descendants(matching: .any).matching(identifier: "DashboardContainer").firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 3))
        app.typeKey("1", modifierFlags: .command)
        let detail = app.descendants(matching: .any).matching(identifier: "DashboardDetail").firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 3))
        app.typeKey(.pageDown, modifierFlags: [])
        app.typeKey(.pageUp, modifierFlags: [])
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(detail.exists)
        XCTAssertTrue(body.exists)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(body.exists)
    }

    @MainActor
    func testSettingsEscapeDoesNotDismissOwnedPopoverWhenAutomaticCloseIsOff() {
        let app = launch()
        openFromStatusMenu(app)
        let toggle = app.switches["SettingsAutomaticallyClosesPopover"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.click()
        closeSettings(app)

        app.statusItems.firstMatch.click()
        let body = app.descendants(matching: .any).matching(identifier: "DashboardContainer").firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 3))
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(settingsWindow(app).waitForExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(body.exists)
    }

    /// Release 구성에서도 실행되는 읽기 전용 진입 검증입니다.
    @MainActor
    func testReadOnlyStatusMenuSettingsAccess() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertFalse(settingsWindow(app).exists)
        openFromStatusMenu(app)
        XCTAssertTrue(app.switches["SettingsLoginToggle"].exists)
        XCTAssertEqual(app.windows.matching(identifier: "ResourceRunner 설정").count, 1)
        closeSettings(app)
        XCTAssertFalse(settingsWindow(app).exists)
    }

    @MainActor
    func testReleaseBuildRightClickOpensSingleSettingsWindow() throws {
        guard let path = ProcessInfo.processInfo.environment["RR_RELEASE_APP_PATH"] else {
            throw XCTSkip("Release 앱 경로를 전달한 별도 실행에서 검증합니다.")
        }
        let app = XCUIApplication(url: URL(fileURLWithPath: path))
        app.launch()
        XCTAssertFalse(settingsWindow(app).exists)
        openFromStatusMenu(app)
        XCTAssertEqual(app.windows.matching(identifier: "ResourceRunner 설정").count, 1)
        let include = app.switches["SettingsIncludeSystemProcesses"]
        let limit = app.popUpButtons["SettingsDetailListLimit"]
        let autoClose = app.switches["SettingsAutomaticallyClosesPopover"]
        XCTAssertTrue(include.exists && limit.exists && autoClose.exists)
        print("TASK016_RELEASE_CURRENT include=\(switchValue(include)) limit=\(textValue(limit)) auto=\(switchValue(autoClose))")
        if ProcessInfo.processInfo.environment["RR_EXPECT_DEFAULT_PREFERENCES"] == "1" {
            XCTAssertEqual(switchValue(include), 0)
            XCTAssertTrue(textValue(limit).contains("20"))
            XCTAssertEqual(switchValue(autoClose), 1)
        }
        if ProcessInfo.processInfo.environment["RR_EXPECT_SAVED_PREFERENCES"] == "1" {
            XCTAssertEqual(switchValue(include), 1)
            XCTAssertTrue(textValue(limit).contains("50"))
            XCTAssertEqual(switchValue(autoClose), 1)
        }
        if ProcessInfo.processInfo.environment["RR_EXPECT_NATIVE_LOGIN_ENABLED"] == "1" {
            XCTAssertEqual(switchValue(app.switches["SettingsLoginToggle"]), 1)
            XCTAssertTrue(textValue(app.staticTexts["SettingsLoginStatus"]).contains("허용"))
        }
        closeSettings(app)
    }

    // 안정 경로의 Release 앱에서만 실행하며, 각 단계의 실제 OS 상태는 외부에서 대조합니다.
    private func nativeReleaseApp() throws -> XCUIApplication {
        guard let path = ProcessInfo.processInfo.environment["RR_NATIVE_RELEASE_APP_PATH"] else {
            throw XCTSkip("실제 로그인 검증용 Release 앱 경로가 필요합니다.")
        }
        return XCUIApplication(url: URL(fileURLWithPath: path))
    }

    @MainActor
    func testNativeLoginInitialReadOnly() throws {
        let app = try nativeReleaseApp()
        app.launch()
        XCTAssertFalse(settingsWindow(app).exists)
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(identifier: "DashboardContainer").firstMatch.exists)
        openFromStatusMenu(app)
        let status = app.staticTexts["SettingsLoginStatus"]
        let firstStatus = textValue(status)
        NSLog("RR_NATIVE_INITIAL status=%@", firstStatus)
        XCTAssertTrue(firstStatus.contains("등록되지") || firstStatus.contains("찾을 수 없"), firstStatus)
        XCTAssertEqual(switchValue(app.switches["SettingsLoginToggle"]), 0)
        app.buttons["SettingsLoginRefresh"].click()
        XCTAssertEqual(textValue(status), firstStatus)
        closeSettings(app)
    }

    @MainActor
    func testNativeLoginRegister() throws {
        let app = try nativeReleaseApp()
        app.launch()
        openFromStatusMenu(app)
        let status = app.staticTexts["SettingsLoginStatus"]
        let firstStatus = textValue(status)
        XCTAssertTrue(firstStatus.contains("등록되지") || firstStatus.contains("찾을 수 없"), firstStatus)
        app.switches["SettingsLoginToggle"].click()
        let result = app.staticTexts["SettingsLoginResult"]
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        let statusText = textValue(status)
        let resultText = textValue(result)
        NSLog("RR_NATIVE_REGISTER status=%@ result=%@", statusText, resultText)
        XCTAssertFalse(resultText.contains("실패"), resultText)
        XCTAssertTrue(statusText.contains("허용") || statusText.contains("승인"), statusText)
        app.buttons["SettingsLoginRefresh"].click()
        XCTAssertTrue(textValue(status).contains("허용") || textValue(status).contains("승인"))
        closeSettings(app)
    }

    @MainActor
    func testNativeLoginUnregisterAndRestore() throws {
        let app = try nativeReleaseApp()
        app.launch()
        openFromStatusMenu(app)
        let status = app.staticTexts["SettingsLoginStatus"]
        let initialStatus = textValue(status)
        XCTAssertTrue(initialStatus.contains("허용") || initialStatus.contains("승인"), initialStatus)
        if initialStatus.contains("승인") {
            app.buttons["SettingsUnregisterLoginItem"].click()
        } else {
            app.switches["SettingsLoginToggle"].click()
        }
        let result = app.staticTexts["SettingsLoginResult"]
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        NSLog("RR_NATIVE_UNREGISTER status=%@ result=%@", textValue(status), textValue(result))
        XCTAssertTrue(textValue(status).contains("등록되지"), textValue(status))
        XCTAssertEqual(switchValue(app.switches["SettingsLoginToggle"]), 0)
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)

        app.switches["SettingsLoginToggle"].click()
        let registered = NSPredicate(format: "value CONTAINS %@ OR value CONTAINS %@", "허용", "승인")
        expectation(for: registered, evaluatedWith: status)
        waitForExpectations(timeout: 10)
        app.buttons["SettingsRestoreDefaults"].click()
        XCTAssertTrue(textValue(app.staticTexts["SettingsOrdinaryRestoreResult"]).contains("복원"))
        let loginRestore = app.staticTexts["SettingsLoginRestoreResult"]
        XCTAssertTrue(loginRestore.waitForExistence(timeout: 10))
        let restored = NSPredicate(format: "value CONTAINS %@", "해제가 확인")
        expectation(for: restored, evaluatedWith: loginRestore)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(textValue(status).contains("등록되지"), textValue(status))
        NSLog("RR_NATIVE_RESTORE status=%@ login=%@", textValue(status), textValue(loginRestore))
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
        closeSettings(app)
    }

    @MainActor
    func testNativeLoginPrepareNextLogin() throws {
        let app = try nativeReleaseApp()
        app.launch()
        openFromStatusMenu(app)
        let status = app.staticTexts["SettingsLoginStatus"]
        let initialStatus = textValue(status)
        XCTAssertTrue(initialStatus.contains("등록되지") || initialStatus.contains("찾을 수 없"), initialStatus)
        app.switches["SettingsLoginToggle"].click()
        let result = app.staticTexts["SettingsLoginResult"]
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        NSLog("RR_NATIVE_PREPARE status=%@ result=%@", textValue(status), textValue(result))
        XCTAssertTrue(textValue(status).contains("허용"), textValue(status))
        XCTAssertEqual(switchValue(app.switches["SettingsLoginToggle"]), 1)
        closeSettings(app)
        XCTAssertFalse(settingsWindow(app).exists)
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(identifier: "DashboardContainer").firstMatch.exists)
    }

    @MainActor
    func testNativeSystemSettingsRemovalRefreshesAppStatus() throws {
        let app = try nativeReleaseApp()
        app.launch()
        openFromStatusMenu(app)
        let status = app.staticTexts["SettingsLoginStatus"]
        XCTAssertTrue(textValue(status).contains("허용"), textValue(status))
        let systemSettings = XCUIApplication(bundleIdentifier: "com.apple.systempreferences")
        systemSettings.activate()
        let loginItem = systemSettings.staticTexts["open-at-login-item-ResourceRunner.app-icon"]
        XCTAssertTrue(loginItem.waitForExistence(timeout: 5))
        XCTAssertEqual((loginItem.value as? String) ?? loginItem.label, "ResourceRunner.app")
        loginItem.click()
        let remove = systemSettings.buttons["제거"]
        XCTAssertTrue(remove.isEnabled)
        remove.click()
        let itemGone = NSPredicate(format: "exists == false")
        expectation(for: itemGone, evaluatedWith: loginItem)
        waitForExpectations(timeout: 10)
        app.activate()
        app.buttons["SettingsLoginRefresh"].click()
        let refreshed = textValue(status)
        NSLog("RR_NATIVE_EXTERNAL_REMOVAL status=%@", refreshed)
        XCTAssertTrue(refreshed.contains("등록되지") || refreshed.contains("찾을 수 없"), refreshed)
        XCTAssertEqual(switchValue(app.switches["SettingsLoginToggle"]), 0)
        XCTAssertFalse(app.staticTexts["SettingsLoginResult"].exists)
        systemSettings.terminate()
        closeSettings(app)
    }

    @MainActor
    func testAllCardsOffOpensSettingsAndRestoresVisibleCard() {
        let app = launch(cards: 0)
        let status = app.statusItems.firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        status.click()
        let open = app.buttons["DashboardOpenSettings"]
        XCTAssertTrue(open.waitForExistence(timeout: 3))
        open.click()
        XCTAssertTrue(settingsWindow(app).waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.7)
        XCTAssertTrue(settingsOwnsKeyboardFocus(app),
            "지연된 대시보드 포커스 복귀가 설정창의 key 상태를 빼앗으면 안 됩니다.")
        let cpu = app.switches["SettingsCPUCard"]
        XCTAssertTrue(cpu.waitForExistence(timeout: 3))
        XCTAssertEqual(switchValue(cpu), 0)
        cpu.click()
        XCTAssertEqual(switchValue(cpu), 1)
        closeSettings(app)
        if !app.buttons["CPUCard"].exists { status.click() }
        XCTAssertTrue(app.buttons["CPUCard"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testAllOrdinaryControlsAndResetKeepSeparateLoginResult() {
        let app = launch()
        openFromStatusMenu(app)
        for id in ["SettingsCPUCard", "SettingsMemoryCard", "SettingsNetworkCard",
                   "SettingsDiskCard", "SettingsCPUTop5", "SettingsMemoryTop5"] {
            let control = app.switches[id]
            XCTAssertTrue(control.exists, id)
            XCTAssertEqual(switchValue(control), 1, id)
            control.click()
            XCTAssertEqual(switchValue(control), 0, id)
        }
        let graph = app.popUpButtons["SettingsGraphRange"]
        XCTAssertTrue(graph.exists)
        graph.click()
        app.menuItems["최근 1분"].click()
        XCTAssertTrue((graph.value as? String ?? "").contains("최근 1분"))
        let profile = app.popUpButtons["SettingsRefreshProfile"]
        XCTAssertTrue(profile.exists)
        profile.click()
        app.menuItems["매우 절전"].click()
        XCTAssertTrue((profile.value as? String ?? "").contains("매우 절전"))

        app.buttons["SettingsRestoreDefaults"].click()
        XCTAssertTrue(textValue(app.staticTexts["SettingsOrdinaryRestoreResult"]).contains("복원"))
        XCTAssertTrue(app.staticTexts["SettingsLoginRestoreResult"].waitForExistence(timeout: 3))
        for id in ["SettingsCPUCard", "SettingsMemoryCard", "SettingsNetworkCard",
                   "SettingsDiskCard", "SettingsCPUTop5", "SettingsMemoryTop5"] {
            XCTAssertEqual(switchValue(app.switches[id]), 1, id)
        }
        XCTAssertTrue((graph.value as? String ?? "").contains("최근 10분"))
        XCTAssertTrue((profile.value as? String ?? "").contains("기본"))
    }

    @MainActor
    func testChangedSettingsSurviveRelaunchThenRestoreSeparatelyFromLoginFailure() {
        let suite = "ResourceRunnerUITest.\(UUID().uuidString)"
        let app = persistentApp(suite: suite)
        addTeardownBlock {
            if app.state != .notRunning { app.terminate() }
            app.launchArguments.append("--preferences-persistence-cleanup")
            app.launch()
            app.terminate()
        }
        app.launch()
        openFromStatusMenu(app)
        for id in ["SettingsCPUCard", "SettingsMemoryCard", "SettingsNetworkCard",
                   "SettingsDiskCard", "SettingsCPUTop5", "SettingsMemoryTop5"] {
            app.switches[id].click()
            XCTAssertEqual(switchValue(app.switches[id]), 0, id)
        }
        let graph = app.popUpButtons["SettingsGraphRange"]
        graph.click()
        app.menuItems["최근 1분"].click()
        let profile = app.popUpButtons["SettingsRefreshProfile"]
        profile.click()
        app.menuItems["매우 절전"].click()
        app.switches["SettingsIncludeSystemProcesses"].click()
        let limit = app.popUpButtons["SettingsDetailListLimit"]
        limit.click()
        app.menuItems["50개"].click()
        app.switches["SettingsAutomaticallyClosesPopover"].click()
        app.terminate()

        // 같은 격리 domain에서 새 프로세스를 띄워 저장값의 최초 표시를 확인합니다.
        app.launch()
        XCTAssertFalse(settingsWindow(app).exists)
        let status = app.statusItems.firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        status.click()
        XCTAssertTrue(app.buttons["DashboardOpenSettings"].waitForExistence(timeout: 3))
        for id in ["CPUCard", "MemoryCard", "NetworkCard", "DiskCard"] {
            XCTAssertFalse(app.buttons[id].exists, id)
        }
        app.buttons["DashboardOpenSettings"].click()
        XCTAssertTrue(settingsWindow(app).waitForExistence(timeout: 3))
        for id in ["SettingsCPUCard", "SettingsMemoryCard", "SettingsNetworkCard",
                   "SettingsDiskCard", "SettingsCPUTop5", "SettingsMemoryTop5"] {
            XCTAssertEqual(switchValue(app.switches[id]), 0, id)
        }
        XCTAssertTrue((app.popUpButtons["SettingsGraphRange"].value as? String ?? "")
            .contains("최근 1분"))
        XCTAssertTrue((app.popUpButtons["SettingsRefreshProfile"].value as? String ?? "")
            .contains("매우 절전"))
        XCTAssertEqual(switchValue(app.switches["SettingsIncludeSystemProcesses"]), 1)
        XCTAssertTrue(textValue(app.popUpButtons["SettingsDetailListLimit"]).contains("50"))
        XCTAssertEqual(switchValue(app.switches["SettingsAutomaticallyClosesPopover"]), 0)

        app.buttons["SettingsRestoreDefaults"].click()
        XCTAssertTrue(textValue(app.staticTexts["SettingsOrdinaryRestoreResult"]).contains("복원"))
        let loginRestore = app.staticTexts["SettingsLoginRestoreResult"]
        let failure = NSPredicate(format: "value CONTAINS %@", "테스트 해제 실패")
        expectation(for: failure, evaluatedWith: loginRestore)
        waitForExpectations(timeout: 3)
        for id in ["SettingsCPUCard", "SettingsMemoryCard", "SettingsNetworkCard",
                   "SettingsDiskCard", "SettingsCPUTop5", "SettingsMemoryTop5"] {
            XCTAssertEqual(switchValue(app.switches[id]), 1, id)
        }
        XCTAssertTrue((app.popUpButtons["SettingsGraphRange"].value as? String ?? "")
            .contains("최근 10분"))
        XCTAssertTrue((app.popUpButtons["SettingsRefreshProfile"].value as? String ?? "")
            .contains("기본"))
        XCTAssertEqual(switchValue(app.switches["SettingsIncludeSystemProcesses"]), 0)
        XCTAssertTrue(textValue(app.popUpButtons["SettingsDetailListLimit"]).contains("20"))
        XCTAssertEqual(switchValue(app.switches["SettingsAutomaticallyClosesPopover"]), 1)
        app.terminate()

        app.launch()
        openFromStatusMenu(app)
        XCTAssertEqual(switchValue(app.switches["SettingsCPUCard"]), 1)
        XCTAssertTrue((app.popUpButtons["SettingsGraphRange"].value as? String ?? "")
            .contains("최근 10분"))
        XCTAssertTrue((app.popUpButtons["SettingsRefreshProfile"].value as? String ?? "")
            .contains("기본"))
        XCTAssertEqual(switchValue(app.switches["SettingsIncludeSystemProcesses"]), 0)
        XCTAssertTrue(textValue(app.popUpButtons["SettingsDetailListLimit"]).contains("20"))
        XCTAssertEqual(switchValue(app.switches["SettingsAutomaticallyClosesPopover"]), 1)
    }

    @MainActor
    func testSchemaOneOldPayloadKeepsOldValuesAndDefaultsNewFields() {
        let suite = "ResourceRunnerUITest.\(UUID().uuidString)"
        let app = persistentApp(suite: suite)
        app.launchArguments.append("--preferences-persistence-seed-schema1")
        addTeardownBlock {
            if app.state != .notRunning { app.terminate() }
            app.launchArguments = ["--preferences-persistence-ui-test", "--preferences-persistence-cleanup", "--settings-ui-test"]
            app.launch()
            app.terminate()
        }
        app.launch()
        XCTAssertFalse(settingsWindow(app).exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "DashboardContainer").firstMatch.exists)
        openFromStatusMenu(app)
        XCTAssertEqual(switchValue(app.switches["SettingsCPUCard"]), 0)
        XCTAssertEqual(switchValue(app.switches["SettingsCPUTop5"]), 0)
        XCTAssertTrue(textValue(app.popUpButtons["SettingsGraphRange"]).contains("최근 5분"))
        XCTAssertTrue(textValue(app.popUpButtons["SettingsRefreshProfile"]).contains("절전"))
        XCTAssertEqual(switchValue(app.switches["SettingsIncludeSystemProcesses"]), 0)
        XCTAssertTrue(textValue(app.popUpButtons["SettingsDetailListLimit"]).contains("20"))
        XCTAssertEqual(switchValue(app.switches["SettingsAutomaticallyClosesPopover"]), 1)
        app.terminate()
        app.launchArguments.removeAll(where: { $0 == "--preferences-persistence-seed-schema1" })
        app.launch()
        openFromStatusMenu(app)
        XCTAssertEqual(switchValue(app.switches["SettingsCPUCard"]), 0)
        XCTAssertEqual(switchValue(app.switches["SettingsIncludeSystemProcesses"]), 0)
        XCTAssertTrue(textValue(app.popUpButtons["SettingsDetailListLimit"]).contains("20"))
        XCTAssertEqual(switchValue(app.switches["SettingsAutomaticallyClosesPopover"]), 1)
    }

    @MainActor
    func testLoginSuccessFailureApprovalRefreshAndExplicitSystemSettings() {
        let app = launch(login: "notRegistered", register: "approval")
        openFromStatusMenu(app)
        app.switches["SettingsLoginToggle"].click()
        let status = app.staticTexts["SettingsLoginStatus"]
        let result = app.staticTexts["SettingsLoginResult"]
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        XCTAssertTrue(textValue(status).contains("승인"))
        XCTAssertTrue(textValue(result).contains("승인"))
        XCTAssertEqual(switchValue(app.switches["SettingsLoginToggle"]), 0)
        XCTAssertTrue(app.buttons["SettingsUnregisterLoginItem"].exists)
        app.buttons["SettingsOpenSystemLoginItems"].click()
        app.buttons["SettingsLoginRefresh"].click()
        XCTAssertTrue(textValue(status).contains("허용"))
        XCTAssertEqual(switchValue(app.switches["SettingsLoginToggle"]), 1)
        app.switches["SettingsLoginToggle"].click()
        XCTAssertTrue(textValue(status).contains("등록되지"))
    }

    @MainActor
    func testLoginFailureDoesNotUndoOrdinaryRestore() {
        let app = launch(login: "enabled", unregister: "failure")
        openFromStatusMenu(app)
        app.switches["SettingsCPUCard"].click()
        app.buttons["SettingsRestoreDefaults"].click()
        XCTAssertEqual(switchValue(app.switches["SettingsCPUCard"]), 1)
        XCTAssertTrue(app.staticTexts["SettingsOrdinaryRestoreResult"].exists)
        let loginRestore = app.staticTexts["SettingsLoginRestoreResult"]
        let failure = NSPredicate(format: "value CONTAINS %@", "테스트 해제 실패")
        expectation(for: failure, evaluatedWith: loginRestore)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(textValue(app.staticTexts["SettingsLoginStatus"]).contains("허용"))
        XCTAssertTrue(focusByTab("SettingsLoginRefresh", in: app))
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(textValue(app.staticTexts["SettingsLoginStatus"]).contains("허용"))
    }

    @MainActor
    func testSuccessfulRegistrationShowsConfirmedEnabledState() {
        let app = launch()
        openFromStatusMenu(app)
        app.typeKey("9", modifierFlags: [.command, .option])
        let result = app.staticTexts["SettingsLoginResult"]
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        XCTAssertTrue(textValue(result).contains("켜기가 확인"))
        XCTAssertEqual(switchValue(app.switches["SettingsLoginToggle"]), 1)
        XCTAssertTrue(textValue(app.staticTexts["SettingsLoginStatus"]).contains("허용"))
    }

    @MainActor
    func testNotFoundAndUnknownStatesKeepExplicitRefreshAndFailureSeparate() {
        let missing = launch(login: "notFound", register: "failure")
        openFromStatusMenu(missing)
        let status = missing.staticTexts["SettingsLoginStatus"]
        XCTAssertTrue(textValue(status).contains("찾을 수 없"))
        missing.switches["SettingsLoginToggle"].click()
        let result = missing.staticTexts["SettingsLoginResult"]
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        XCTAssertTrue(textValue(result).contains("테스트 등록 실패"))
        XCTAssertTrue(textValue(status).contains("찾을 수 없"))
        XCTAssertTrue(focusByTab("SettingsLoginRefresh", in: missing))
        missing.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(textValue(status).contains("찾을 수 없"))
        missing.terminate()

        let unknown = launch(login: "unknown")
        openFromStatusMenu(unknown)
        XCTAssertTrue(textValue(unknown.staticTexts["SettingsLoginStatus"])
            .contains("확인할 수 없"))
        XCTAssertTrue(unknown.buttons["SettingsLoginRefresh"].exists)
    }

    @MainActor
    func testNativeSettingsControlsCanBeReachedAndActivatedByKeyboard() {
        let app = launch(login: "approval")
        openFromStatusMenu(app)
        let cpu = app.switches["SettingsCPUCard"]
        XCTAssertEqual(cpu.label, "CPU")
        app.typeKey("1", modifierFlags: [.command, .option])
        XCTAssertEqual(switchValue(cpu), 0)
        for (key, identifier) in [("2", "SettingsMemoryCard"), ("3", "SettingsNetworkCard"),
                                  ("4", "SettingsDiskCard"), ("5", "SettingsCPUTop5"),
                                  ("6", "SettingsMemoryTop5")] {
            app.typeKey(key, modifierFlags: [.command, .option])
            XCTAssertEqual(switchValue(app.switches[identifier]), 0, identifier)
        }

        let graph = app.popUpButtons["SettingsGraphRange"]
        XCTAssertEqual(graph.label, "표시 시간")
        app.typeKey("7", modifierFlags: [.command, .option])
        XCTAssertTrue((graph.value as? String ?? "").contains("최근 1분"))
        app.typeKey("7", modifierFlags: [.command, .option])
        XCTAssertTrue((graph.value as? String ?? "").contains("최근 5분"))
        app.typeKey("7", modifierFlags: [.command, .option])
        XCTAssertTrue((graph.value as? String ?? "").contains("최근 10분"))
        XCTAssertTrue(focusByTab("SettingsNextGraphRange", in: app))
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue((graph.value as? String ?? "").contains("최근 1분"))

        let profile = app.popUpButtons["SettingsRefreshProfile"]
        XCTAssertEqual(profile.label, "갱신 속도")
        app.typeKey("8", modifierFlags: [.command, .option])
        XCTAssertTrue((profile.value as? String ?? "").contains("절전"))
        app.typeKey("8", modifierFlags: [.command, .option])
        XCTAssertTrue((profile.value as? String ?? "").contains("매우 절전"))
        app.typeKey("8", modifierFlags: [.command, .option])
        XCTAssertTrue((profile.value as? String ?? "").contains("빠름"))
        app.typeKey("8", modifierFlags: [.command, .option])
        XCTAssertTrue((profile.value as? String ?? "").contains("기본"))
        XCTAssertTrue(focusByTab("SettingsNextRefreshProfile", in: app))
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue((profile.value as? String ?? "").contains("절전"))

        XCTAssertTrue(focusByTab("SettingsOpenSystemLoginItems", in: app))
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(focusByTab("SettingsLoginRefresh", in: app))
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(textValue(app.staticTexts["SettingsLoginStatus"]).contains("허용"))

        XCTAssertTrue(focusByTab("SettingsRestoreDefaults", in: app))
        app.typeKey(.return, modifierFlags: [])
        XCTAssertEqual(switchValue(cpu), 1)
        XCTAssertTrue(textValue(app.staticTexts["SettingsOrdinaryRestoreResult"]).contains("복원"))
    }

    @MainActor
    func testApprovalCanBeUnregisteredByKeyboard() {
        let app = launch(login: "approval")
        openFromStatusMenu(app)
        XCTAssertTrue(focusByTab("SettingsUnregisterLoginItem", in: app))
        app.typeKey(" ", modifierFlags: [])
        let status = app.staticTexts["SettingsLoginStatus"]
        let notRegistered = NSPredicate(format: "value CONTAINS %@", "등록되지")
        expectation(for: notRegistered, evaluatedWith: status)
        waitForExpectations(timeout: 3)
    }

    @MainActor
    func testSettingsWindowKeepsKeyAfterSelectedCardIsRemovedDuringFocusReturn() {
        let app = launch(cards: 3)
        let status = app.statusItems.firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        status.click()
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "DashboardDetail").firstMatch.waitForExistence(timeout: 3))
        // 명시적 DEBUG fixture 단축키는 제거와 설정 열기를 120ms 복귀보다 앞서 한 이벤트로 보냅니다.
        app.typeKey("9", modifierFlags: [.command, .shift])
        XCTAssertTrue(settingsWindow(app).waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.7)
        // 설정창이 key여도 초기 AX 자식 포커스가 비어 있을 수 있어 첫 Tab 뒤 소유 창을 확인합니다.
        app.typeKey(.tab, modifierFlags: [])
        XCTAssertTrue(settingsOwnsKeyboardFocus(app))
        XCTAssertEqual(switchValue(app.switches["SettingsCPUCard"]), 0)
        XCTAssertTrue(app.switches["SettingsMemoryCard"].isHittable)
    }
}
