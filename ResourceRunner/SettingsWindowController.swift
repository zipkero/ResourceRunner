import AppKit
import SwiftUI

/// 앱 수명 동안 하나의 설정 창을 소유합니다. 창을 닫아도 인스턴스를 유지합니다.
@MainActor
final class SettingsWindowController: NSWindowController {
    private let loginController: LoginItemController
    private let activate: () -> Void

    init(preferencesStore: PreferencesStore, loginController: LoginItemController,
         activate: (() -> Void)? = nil) {
        self.loginController = loginController
        self.activate = activate ?? { NSApp.activate() }
        let content = PreferencesView(preferencesStore: preferencesStore,
            loginController: loginController)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "ResourceRunner 설정"
        window.identifier = NSUserInterfaceItemIdentifier("ResourceRunnerSettingsWindow")
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: content)
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { nil }

    func open() {
        loginController.refresh()
        activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        // 같은 앱에서 다른 창을 거쳐 돌아올 때도 macOS의 실제 승인을 다시 읽습니다.
        loginController.refresh()
    }
}
