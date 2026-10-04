import AppKit
import Testing
@testable import ResourceRunner

@MainActor
private final class SettingsTestStorage: PreferencesStorage {
    var saved: Any?
    var writes = 0
    func read() -> Any? { saved }
    func write(_ dictionary: [String: Any]) { saved = dictionary; writes += 1 }
}

@MainActor
private final class SettingsTestLoginService: LoginItemServing {
    var current: LoginItemStatus = .notRegistered
    var reads = 0
    var mutations = 0
    var settingsOpens = 0
    func status() -> LoginItemStatus { reads += 1; return current }
    func register() async throws { mutations += 1 }
    func unregister() async throws { mutations += 1 }
    func openSystemSettingsLoginItems() { settingsOpens += 1 }
}

@MainActor
struct SettingsWindowControllerTests {
    @Test func windowIsReusedAndOpenOnlyRefreshesActualStatus() {
        let storage = SettingsTestStorage()
        let preferences = PreferencesStore(storage: storage)
        let service = SettingsTestLoginService()
        let login = LoginItemController(service: service)
        var activations = 0
        let controller = SettingsWindowController(preferencesStore: preferences,
            loginController: login, activate: { activations += 1 })
        let original = controller.window

        #expect(original != nil)
        #expect(original?.identifier?.rawValue == "ResourceRunnerSettingsWindow")
        #expect(original?.isVisible == false)
        #expect(activations == 0)
        #expect(service.reads == 1)
        #expect(service.mutations == 0)
        #expect(storage.writes == 0)

        controller.open()
        #expect(original?.isVisible == true)
        #expect(activations == 1)
        #expect(service.reads >= 2)
        let readsAfterFirstOpen = service.reads
        service.current = .requiresApproval
        original?.close()
        #expect(original?.isVisible == false)
        controller.open()
        #expect(controller.window === original)
        #expect(login.actualStatus == .requiresApproval)
        #expect(activations == 2)
        #expect(service.reads > readsAfterFirstOpen)
        #expect(service.mutations == 0)
        #expect(service.settingsOpens == 0)
        original?.close()
    }

    @Test func returningToAlreadyOpenSettingsWindowRefreshesActualStatus() {
        let service = SettingsTestLoginService()
        let login = LoginItemController(service: service)
        let controller = SettingsWindowController(
            preferencesStore: PreferencesStore(storage: SettingsTestStorage()),
            loginController: login, activate: {})
        controller.open()
        let readsBeforeReturn = service.reads
        service.current = .enabled
        controller.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification,
            object: controller.window))
        #expect(service.reads == readsBeforeReturn + 1)
        #expect(login.actualStatus == .enabled)
        #expect(service.mutations == 0)
        controller.window?.close()
    }

    @Test func allActualStatesAndRequestResultsRemainDistinct() {
        #expect(PreferencesView.statusDescription(.enabled).contains("허용"))
        #expect(PreferencesView.statusDescription(.notRegistered).contains("등록되지"))
        #expect(PreferencesView.statusDescription(.requiresApproval).contains("승인"))
        #expect(PreferencesView.statusDescription(.notFound).contains("찾을 수 없"))
        #expect(PreferencesView.statusDescription(.unknown(42)).contains("확인할 수 없"))

        let success = LoginItemRequestResult(operationID: 1, requestedEnabled: true,
            actualStatus: .enabled, outcome: .succeeded)
        let pending = LoginItemRequestResult(operationID: 2, requestedEnabled: true,
            actualStatus: .requiresApproval, outcome: .requiresApproval)
        let failure = LoginItemRequestResult(operationID: 3, requestedEnabled: false,
            actualStatus: .enabled, outcome: .failed("테스트 해제 실패"))
        #expect(PreferencesView.resultDescription(success).contains("켜기가 확인"))
        #expect(PreferencesView.resultDescription(pending).contains("승인"))
        #expect(!PreferencesView.resultDescription(pending).contains("켜기가 확인"))
        #expect(PreferencesView.resultDescription(failure).contains("테스트 해제 실패"))
    }
}
