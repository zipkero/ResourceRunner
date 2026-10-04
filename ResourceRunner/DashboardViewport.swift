import AppKit
import Combine
import SwiftUI

/// 팝오버 콘텐츠 크기와 실제 창 chrome를 분리해 화면 가용 영역을 계산합니다.
nonisolated enum DashboardViewportPolicy {
    static let edgeMargin: CGFloat = 8
    static let maximumDetail = CGSize(width: 400, height: 480)
    static let initialChrome = CGSize(width: 26, height: 26)
    // Memory의 검증된 가장 긴 원문 상태에 필요한 높이입니다. 카드에 빈 높이를 예약하지 않습니다.
    static let longestMemoryHeight: CGFloat = 184

    static func normalizedAnchorCenterY(diskCenterY: CGFloat, memoryHeight: CGFloat) -> CGFloat {
        diskCenterY + memoryHeight - longestMemoryHeight
    }

    static func normalizedAnchorCenterY(cardCenterY: CGFloat, card: DashboardSelection,
                                        memoryHeight: CGFloat?, memoryIsAboveAnchor: Bool) -> CGFloat {
        guard let memoryHeight else { return cardCenterY }
        let difference = memoryHeight - longestMemoryHeight
        if card == .memory { return cardCenterY + difference / 2 }
        return cardCenterY + (memoryIsAboveAnchor ? difference : 0)
    }

    static func detailSize(visibleFrame: CGRect, chrome: CGSize,
                           lowestAnchorCenterY: CGFloat? = nil) -> CGSize {
        let anchorHeight = lowestAnchorCenterY.map {
            2 * ($0 - visibleFrame.minY - edgeMargin) - chrome.height
        } ?? maximumDetail.height
        return CGSize(width: min(maximumDetail.width,
            max(0, visibleFrame.width - 2 * edgeMargin - chrome.width)),
            height: min(maximumDetail.height,
                max(0, visibleFrame.height - 2 * edgeMargin - chrome.height),
                max(0, anchorHeight)))
    }

    static func containedOrigin(window: CGRect, visibleFrame: CGRect) -> CGPoint? {
        let inside = visibleFrame.insetBy(dx: edgeMargin, dy: edgeMargin)
        guard window.width <= inside.width, window.height <= inside.height else { return nil }
        return CGPoint(x: min(max(window.minX, inside.minX), inside.maxX - window.width),
                       y: min(max(window.minY, inside.minY), inside.maxY - window.height))
    }

    static func contains(_ window: CGRect, visibleFrame: CGRect, tolerance: CGFloat = 0.5) -> Bool {
        let inside = visibleFrame.insetBy(dx: edgeMargin, dy: edgeMargin)
        return window.minX >= inside.minX - tolerance && window.maxX <= inside.maxX + tolerance
            && window.minY >= inside.minY - tolerance && window.maxY <= inside.maxY + tolerance
    }
}

/// 본체와 네 상세가 함께 쓰는 화면 경계. 본체 카드 크기는 바꾸지 않습니다.
@MainActor
final class DashboardViewport: ObservableObject {
    @Published private(set) var detailSize = DashboardViewportPolicy.maximumDetail
    private(set) var visibleFrame: CGRect?
    private weak var currentScreen: NSScreen?
    private(set) var detailChrome = DashboardViewportPolicy.initialChrome
    weak var detailWindow: NSWindow?
    private(set) var detailSelection: DashboardSelection?
    var requestCorrection: (() -> Void)?
    var requestBodyFocus: (() -> Bool)?
    private(set) var expectedAnchor: DashboardSelection?
    private(set) var displayRevision: UInt64 = 0
    private var configured = false
    private var visibleCards = DashboardSelection.cardOrder
    private var normalizesMemoryHeight = true
    private(set) weak var lowestAnchorView: NSView?
    private(set) weak var memoryCardView: NSView?
    private var anchorOrder: UInt64 = 0
    private var memoryOrder: UInt64 = 0
    private var anchorFrame: CGRect?
    private var memoryFrame: CGRect?

    func configure(visibleCards: [DashboardSelection], revision: UInt64,
                   normalizesMemoryHeight: Bool) {
        guard revision >= displayRevision else { return }
        if configured, revision == displayRevision, self.visibleCards == visibleCards,
           self.normalizesMemoryHeight == normalizesMemoryHeight { return }
        configured = true
        displayRevision = revision
        self.visibleCards = visibleCards
        self.normalizesMemoryHeight = normalizesMemoryHeight
        expectedAnchor = visibleCards.last
        lowestAnchorView = nil
        memoryCardView = nil
        anchorOrder = 0
        memoryOrder = 0
        anchorFrame = nil
        memoryFrame = nil
        requestCorrection?()
        closeDetailWithoutAnchor(after: revision)
    }

    private func closeDetailWithoutAnchor(after revision: UInt64) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(60)) { [weak self] in
            guard let self, self.displayRevision == revision else { return }
            if let anchor = self.lowestAnchorView,
               let window = anchor.window, anchor.bounds.height > 0,
               window.screen == self.currentScreen {
                return
            }
            self.detailWindow?.close()
        }
    }

    func apply(screen: NSScreen, measuredDetailChrome: CGSize? = nil) {
        currentScreen = screen
        visibleFrame = screen.visibleFrame
        if let measuredDetailChrome { detailChrome = measuredDetailChrome }
        let anchorCenterY: CGFloat? = {
            guard let view = lowestAnchorView, let window = view.window,
                  window.screen == screen, view.bounds.height > 0 else { return nil }
            guard let card = expectedAnchor else { return nil }
            let memoryHeight: CGFloat? = {
                guard normalizesMemoryHeight, visibleCards.contains(.memory),
                      let memory = memoryCardView,
                      memory.window === window,
                      memory.bounds.height > 0 else { return nil }
                return memory.bounds.height
            }()
            let center = window.convertToScreen(view.convert(view.bounds, to: nil)).midY
            let memoryIsAbove = visibleCards.firstIndex(of: .memory).map { memoryIndex in
                memoryIndex < visibleCards.count - 1
            } ?? false
            return DashboardViewportPolicy.normalizedAnchorCenterY(cardCenterY: center,
                card: card, memoryHeight: memoryHeight,
                memoryIsAboveAnchor: memoryIsAbove)
        }()
        let next = DashboardViewportPolicy.detailSize(visibleFrame: screen.visibleFrame,
            chrome: detailChrome, lowestAnchorCenterY: anchorCenterY)
        if detailSize != next { detailSize = next }
        if anchorCenterY == nil, detailWindow != nil {
            closeDetailWithoutAnchor(after: displayRevision)
        }
    }

    func registerCard(view: NSView, card: DashboardSelection, revision: UInt64,
                      order: UInt64, isLast: Bool) {
        guard configured, revision == displayRevision, visibleCards.contains(card),
              let window = view.window, card == .memory || isLast else { return }
        let frame = window.convertToScreen(view.convert(view.bounds, to: nil))
        var changed = false
        if card == .memory, order >= memoryOrder {
            changed = changed || memoryCardView !== view || memoryFrame != frame
            memoryCardView = view
            memoryOrder = order
            memoryFrame = frame
        }
        if isLast, card == expectedAnchor, order >= anchorOrder {
            changed = changed || lowestAnchorView !== view || anchorFrame != frame
            lowestAnchorView = view
            anchorOrder = order
            anchorFrame = frame
        }
        guard changed else { return }
        if let screen = window.screen { apply(screen: screen) }
        requestCorrection?()
    }

    func unregisterCard(view: NSView, card: DashboardSelection, revision: UInt64) {
        guard revision == displayRevision else { return }
        if card == .memory, memoryCardView === view {
            memoryCardView = nil
            memoryFrame = nil
        }
        if card == expectedAnchor, lowestAnchorView === view {
            lowestAnchorView = nil
            anchorFrame = nil
        }
        if let screen = view.window?.screen ?? detailWindow?.screen { apply(screen: screen) }
        requestCorrection?()
        if lowestAnchorView == nil { closeDetailWithoutAnchor(after: revision) }
    }

    func registerDetail(window: NSWindow?, removingWindow: NSWindow? = nil,
                        selection: DashboardSelection, contentSize: CGSize) {
        if let window {
            let newWindow = detailWindow !== window
            detailWindow = window
            detailSelection = selection
            if contentSize.width > 0, contentSize.height > 0 {
                let chrome = CGSize(width: max(0, window.frame.width - contentSize.width),
                                    height: max(0, window.frame.height - contentSize.height))
                if let screen = window.screen { apply(screen: screen, measuredDetailChrome: chrome) }
            }
            if newWindow, let screen = window.screen,
               !DashboardViewportPolicy.contains(window.frame, visibleFrame: screen.visibleFrame) {
                requestCorrection?()
            }
        } else if detailSelection == selection, detailWindow === removingWindow {
            detailWindow = nil
            detailSelection = nil
        }
    }
}

/// 마지막 카드의 실제 NSView 위치를 공유 높이 계산에만 사용합니다.
struct DashboardLowestAnchorCapture: NSViewRepresentable {
    @ObservedObject var viewport: DashboardViewport
    let card: DashboardSelection
    let revision: UInt64
    let isLast: Bool

    func makeNSView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.viewport = viewport
        view.card = card
        view.revision = revision
        view.isLast = isLast
        return view
    }

    func updateNSView(_ view: AnchorView, context: Context) {
        view.viewport = viewport
        view.card = card
        view.revision = revision
        view.isLast = isLast
        view.report()
    }

    static func dismantleNSView(_ view: AnchorView, coordinator: ()) {
        view.viewport?.unregisterCard(view: view, card: view.card, revision: view.revision)
    }

    final class AnchorView: NSView {
        weak var viewport: DashboardViewport?
        var card: DashboardSelection = .none
        var revision: UInt64 = 0
        var isLast = false
        private static var nextOrder: UInt64 = 0
        let order: UInt64 = {
            nextOrder &+= 1
            return nextOrder
        }()
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                viewport?.unregisterCard(view: self, card: card, revision: revision)
            } else {
                report()
            }
        }
        override func layout() { super.layout(); report() }
        func report() {
            let card = card
            let revision = revision
            let isLast = isLast
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil,
                      self.card == card, self.revision == revision,
                      self.isLast == isLast else { return }
                self.viewport?.registerCard(view: self, card: card,
                    revision: revision, order: self.order, isLast: isLast)
            }
        }
    }
}

/// SwiftUI `.popover`가 만든 실제 자식 창을 그 콘텐츠에서 직접 넘깁니다.
struct DashboardDetailWindowCapture: NSViewRepresentable {
    @ObservedObject var viewport: DashboardViewport
    let selection: DashboardSelection

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onWindowChange = { [weak viewport] window, removed, size in
            viewport?.registerDetail(window: window, removingWindow: removed,
                selection: selection, contentSize: size)
        }
        return view
    }

    func updateNSView(_ view: TrackingView, context: Context) {
        view.onWindowChange = { [weak viewport] window, removed, size in
            viewport?.registerDetail(window: window, removingWindow: removed,
                selection: selection, contentSize: size)
        }
        view.reportWindow()
    }

    final class TrackingView: NSView {
        var onWindowChange: ((NSWindow?, NSWindow?, CGSize) -> Void)?
        weak var lastWindow: NSWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportWindow()
        }

        override func layout() {
            super.layout()
            reportWindow()
        }

        func reportWindow() {
            // SwiftUI 갱신 중 Published 상태를 쓰지 않도록 다음 main turn에 측정합니다.
            let callback = onWindowChange
            let currentWindow = window
            let removed = currentWindow == nil ? lastWindow : nil
            if let currentWindow { lastWindow = currentWindow }
            let size = bounds.size
            DispatchQueue.main.async { callback?(currentWindow, removed, size) }
        }
    }
}
