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

    weak var output: StatusBarControllerOutput?

#if DEBUG
    /// 우클릭 디버그 메뉴에서 상태를 고르면 호출되는 콜백. Release 빌드에는 이 진입점이 존재하지 않습니다.
    var debugStateInjector: ((CharacterActivityState) -> Void)?
#endif

    init<Content: View>(popoverContent: Content) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: popoverContent)

        super.init()

        popover.delegate = self

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
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
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
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    @objc private func injectDebugState(_ sender: NSMenuItem) {
        guard let state = sender.representedObject as? CharacterActivityState else { return }
        debugStateInjector?(state)
    }
#endif
}

extension StatusBarController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
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
