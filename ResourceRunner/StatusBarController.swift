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
/// 메뉴바 항목은 고정 폭(`NSStatusItem.squareLength`)이며 버튼 이미지만 교체합니다.
/// 팝오버는 `.transient` behavior로 외부 상호작용에서 스스로 닫히고,
/// delegate가 보고하는 실제 표시 상태를 단일 소스로 삼아 클릭 토글과 어긋나지 않게 합니다.
@MainActor
final class StatusBarController: NSObject {
    /// 메뉴바 항목에 표시할 이미지의 한 변 길이.
    /// 메뉴바 높이는 22pt지만 자산을 22pt로 그대로 표시하면 여백 없이 꽉 차 다른 메뉴바 항목보다 커 보입니다.
    /// macOS 메뉴바 글리프 관례에 맞춰 18pt로 줄여 위아래 여백을 남깁니다.
    static let statusImageLength: CGFloat = 18

    let statusItem: NSStatusItem
    let popover: NSPopover

    weak var output: StatusBarControllerOutput?

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

        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

extension StatusBarController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        output?.popoverPresented(true)
    }

    func popoverDidClose(_ notification: Notification) {
        output?.popoverPresented(false)
    }
}
