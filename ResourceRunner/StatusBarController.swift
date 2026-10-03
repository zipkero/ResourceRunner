//
//  StatusBarController.swift
//  ResourceRunner
//
//  Created by zipkero on 8/2/26.
//

import AppKit
import SwiftUI

/// 팝오버의 실제 표시·닫힘을 coordinator에 알리는 출력 계약.
/// `StatusBarController`의 delegate 이벤트가 단일 소스이며, 이 출력이 표시 상태의 진실을 대표합니다.
@MainActor
protocol StatusBarControllerOutput: AnyObject {
    func popoverPresented(_ isPresented: Bool)
}

/// `NSStatusItem`, `NSPopover`와 팝오버 delegate를 소유하는 AppKit 경계.
/// 메뉴바 항목은 고정 폭(`NSStatusItem.squareLength`)이고 버튼 이미지는 구성 시점에 한 번만 설정합니다.
/// 상태가 바뀌어도 갱신되는 것은 버튼의 접근성 이름 하나뿐입니다.
/// 팝오버는 `.transient` behavior로 외부 상호작용에서 스스로 닫히고,
/// delegate가 보고하는 실제 표시 상태를 단일 소스로 삼아 클릭 토글과 어긋나지 않게 합니다.
/// Debug 빌드에서는 우클릭이 다섯 상태를 주입하는 디버그 메뉴를 열며, 이 경로는 Release 빌드 산출물에 존재하지 않습니다.
@MainActor
final class StatusBarController: NSObject {
    /// 메뉴바 항목에 표시할 이미지의 한 변 길이.
    /// 메뉴바 높이는 22pt지만 자산을 22pt로 그대로 표시하면 여백 없이 꽉 차 다른 메뉴바 항목보다 커 보입니다.
    /// macOS 메뉴바 글리프 관례에 맞춰 18pt로 줄여 위아래 여백을 남깁니다.
    static let statusImageLength: CGFloat = 18

    let statusItem: NSStatusItem
    let popover: NSPopover
    let viewport: DashboardViewport?
    private var screenObserver: NSObjectProtocol?
    private var correctionScheduled = false
    private var keyMonitor: Any?
    var keyboardDismiss: (() -> Bool)?

    weak var output: StatusBarControllerOutput?

#if DEBUG
    /// 우클릭 디버그 메뉴에서 상태를 고르면 호출되는 콜백. Release 빌드에는 이 진입점이 존재하지 않습니다.
    var debugStateInjector: ((CharacterActivityState) -> Void)?
    var debugCardVisibilityInjector: ((DashboardSelection) -> Void)?
#endif

    init<Content: View>(popoverContent: Content, viewport: DashboardViewport? = nil) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        self.viewport = viewport
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: popoverContent)

        super.init()

        popover.delegate = self
        viewport?.requestCorrection = { [weak self] in self?.scheduleFrameCorrection() }
        viewport?.requestBodyFocus = { [weak self] in
            self?.popover.contentViewController?.view.window?.makeKey()
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.handleOwnedKey(event) ?? event }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.scheduleFrameCorrection() }
        }

        if let button = statusItem.button {
            // 자산 카탈로그가 돌려주는 공유 인스턴스의 크기를 직접 바꾸지 않도록 복사본을 사용합니다.
            let image = NSImage(named: "StatusCatStatic")?.copy() as? NSImage
            image?.size = NSSize(width: Self.statusImageLength, height: Self.statusImageLength)
            image?.isTemplate = true
            button.image = image
            button.target = self
            button.action = #selector(togglePopover)
#if DEBUG
            // 좌클릭은 기존 팝오버 토글을 그대로 쓰고, 우클릭만 디버그 상태 메뉴로 분기합니다.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
#endif
        }
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    /// 현재 본체·상세 소유 창의 키만 처리해 다른 앱과 다른 창의 입력을 건드리지 않습니다.
    private func handleOwnedKey(_ event: NSEvent) -> NSEvent? {
        guard let window = event.window,
              window === popover.contentViewController?.view.window
                || window === viewport?.detailWindow else { return event }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard modifiers.isEmpty else { return event }
        if event.keyCode == 53, keyboardDismiss?() == true { return nil }
        if event.keyCode == 116 || event.keyCode == 121,
           let detail = viewport?.detailWindow, detail.isVisible,
           let content = detail.contentView,
           let scroll = Self.firstScrollView(in: content) {
            let clip = scroll.contentView
            let end = max(0, (scroll.documentView?.frame.height ?? 0) - clip.bounds.height)
            let next = min(end, max(0, clip.bounds.minY
                + (event.keyCode == 121 ? clip.bounds.height : -clip.bounds.height)))
            clip.scroll(to: CGPoint(x: clip.bounds.minX, y: next))
            scroll.reflectScrolledClipView(clip)
            return nil
        }
        return event
    }

    private static func firstScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        for child in view.subviews {
            if let scroll = firstScrollView(in: child) { return scroll }
        }
        return nil
    }

    /// 팝오버가 닫혀 있으면 버튼에 고정해 열고, 열려 있으면 닫습니다.
    ///
    /// 여는 경로에서 앱을 활성화하고 팝오버 창을 key로 만듭니다.
    /// `LSUIElement` 앱은 일반 창이 없어 팝오버를 띄워도 저절로 활성화되지 않는데,
    /// 그 상태에서는 다른 앱을 클릭해도 이벤트가 이 앱에 오지 않아
    /// `.transient`가 닫을 계기를 얻지 못합니다. 활성화해 두면 외부 클릭이 활성 해제로 이어져 팝오버가 닫힙니다.
    ///
    /// 활성화는 팝오버를 열 때마다 이전 최전면 앱의 포커스를 가져가는 대가를 치릅니다.
    /// 그럼에도 지우면 안 됩니다 — 비활성 앱의 창은 key window가 될 수 없어 키 이벤트를 받지 못하므로,
    /// 활성화를 없애면 외부 클릭 닫힘과 함께 대시보드의 키보드 탐색까지 깨집니다.
    /// 키보드 탐색은 ROADMAP 최종 관문의 접근성 항목이자 docs/product.md의 대시보드 요구사항입니다.
    /// 포커스를 뺏지 않으면서 키 이벤트를 받으려면 `NSPanel`의 `.nonactivatingPanel`이 필요한데,
    /// 그건 ANALYSIS §5 DP1이 기각한 옵션 C입니다.
    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

#if DEBUG
        if NSApp.currentEvent?.type == .rightMouseUp {
            showDebugStateMenu(relativeTo: button)
            return
        }
#endif

        if popover.isShown {
            popover.performClose(nil)
        } else {
            updateViewportFromScreen()
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            scheduleFrameCorrection()
        }
    }

    private func scheduleFrameCorrection() {
        guard !correctionScheduled else { return }
        correctionScheduled = true
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.correctFrames()
            try? await Task.sleep(for: .milliseconds(120))
            self?.correctFrames()
            // 하단 카드 상세는 macOS가 최초 창 생성 뒤 한 번 더 앵커 위치를 조정합니다.
            try? await Task.sleep(for: .milliseconds(380))
            self?.correctFrames()
            self?.correctionScheduled = false
        }
    }

    /// 상태 항목 화면과 실제 창 chrome를 읽어 보조 viewport를 정한 뒤 외곽 frame을 보정합니다.
    private func updateViewportFromScreen() {
        guard let viewport,
              let screen = statusItem.button?.window?.screen ?? popover.contentViewController?.view.window?.screen
                ?? NSScreen.main else { return }
        viewport.apply(screen: screen)
    }

    private func correctFrames() {
        guard let viewport,
              let screen = statusItem.button?.window?.screen ?? popover.contentViewController?.view.window?.screen
                ?? NSScreen.main else { return }
        viewport.apply(screen: screen)
        if let body = popover.contentViewController?.view.window {
            keepWindow(body, inside: screen.visibleFrame)
        }
        if let detail = viewport.detailWindow, detail.isVisible {
            // 상세는 콘텐츠가 등록한 정확한 자식 창만 보정합니다.
            keepWindow(detail, inside: detail.screen?.visibleFrame ?? screen.visibleFrame)
        }
    }

    private func keepWindow(_ window: NSWindow, inside visibleFrame: CGRect) {
        guard let origin = DashboardViewportPolicy.containedOrigin(window: window.frame,
            visibleFrame: visibleFrame) else { return }
        if abs(origin.x - window.frame.minX) > 0.1 || abs(origin.y - window.frame.minY) > 0.1 {
            window.setFrameOrigin(origin)
        }
    }

#if DEBUG
    /// 다섯 상태를 고를 수 있는 디버그 메뉴를 띄웁니다.
    /// 이 메뉴를 여는 동작은 메뉴바 항목 클릭이라 `NSPopover`가 외부 클릭으로 판정해 열려 있던 팝오버를 닫습니다.
    /// 표시 경로에는 팝오버 참조가 없으므로 이 닫힘은 주입 수단의 성질입니다.
    /// 메뉴 항목 제목은 XCUITest가 상태를 고르는 식별자이기도 하므로 상태 이름을 그대로 씁니다.
    private func showDebugStateMenu(relativeTo button: NSStatusBarButton) {
        let menu = NSMenu()
        let states: [CharacterActivityState] = [.low, .moderate, .high, .veryHigh, .sustainedHigh]
        for state in states {
            let item = NSMenuItem(title: "\(state)", action: #selector(injectDebugState(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = state
            menu.addItem(item)
        }
        if debugCardVisibilityInjector != nil {
            menu.addItem(.separator())
            for card in DashboardSelection.cardOrder {
                let item = NSMenuItem(title: "Toggle \(card) Card",
                    action: #selector(toggleDebugCard(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = card
                menu.addItem(item)
            }
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    @objc private func injectDebugState(_ sender: NSMenuItem) {
        guard let state = sender.representedObject as? CharacterActivityState else { return }
        debugStateInjector?(state)
    }

    @objc private func toggleDebugCard(_ sender: NSMenuItem) {
        guard let card = sender.representedObject as? DashboardSelection else { return }
        debugCardVisibilityInjector?(card)
    }
#endif
}

extension StatusBarController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        scheduleFrameCorrection()
        output?.popoverPresented(true)
    }

    func popoverDidClose(_ notification: Notification) {
        output?.popoverPresented(false)
    }
}

/// 메뉴바 버튼의 접근성 이름만 갱신합니다. 이름은 매핑에서 이미 완성돼 오므로 여기서 조합하지 않습니다.
/// 접근성 값은 설정하지 않습니다 — 상태 문자열은 접근성 이름 한 자리에만 존재합니다.
/// 버튼 이미지와 `NSStatusItem.length`는 구성 시점 값을 그대로 유지하며 이 경로가 건드리지 않습니다.
extension StatusBarController: CharacterPresentationSink {
    func render(_ presentation: CharacterPresentation) {
        statusItem.button?.setAccessibilityLabel(presentation.accessibilityLabel)
    }
}
