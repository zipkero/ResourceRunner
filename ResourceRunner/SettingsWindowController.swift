import AppKit
import SwiftUI

#if DEBUG
// UI fixture에서 창의 실제 key 상태를 접근성 조회 시점에 읽어 지연 포커스 복귀를 판정합니다.
private final class SettingsKeyWindowProbe: NSWindow {
    override func accessibilityValue() -> Any? {
        isKeyWindow ? "key" : "not-key"
    }
}
#endif

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
        let frame = NSRect(x: 0, y: 0, width: 470, height: 670)
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let window: NSWindow
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--settings-ui-test") {
            window = SettingsKeyWindowProbe(contentRect: frame, styleMask: style,
                backing: .buffered, defer: false)
        } else {
            window = NSWindow(contentRect: frame, styleMask: style,
                backing: .buffered, defer: false)
        }
#else
        window = NSWindow(contentRect: frame, styleMask: style,
            backing: .buffered, defer: false)
#endif
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
