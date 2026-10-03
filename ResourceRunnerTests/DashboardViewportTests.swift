import AppKit
import Testing
@testable import ResourceRunner

@MainActor
struct DashboardViewportTests {
    @Test func detailUsesActualChromeAndEightPointVisibleMargins() {
        let normal = DashboardViewportPolicy.detailSize(
            visibleFrame: CGRect(x: 0, y: 0, width: 1728, height: 1084),
            chrome: CGSize(width: 26, height: 26))
        #expect(normal == CGSize(width: 400, height: 480))

        let narrow = DashboardViewportPolicy.detailSize(
            visibleFrame: CGRect(x: 100, y: 50, width: 420, height: 450),
            chrome: CGSize(width: 26, height: 26))
        #expect(narrow == CGSize(width: 378, height: 408))
        #expect(narrow.width + 26 + 16 == 420)
        #expect(narrow.height + 26 + 16 == 450)

        let small = DashboardViewportPolicy.detailSize(
            visibleFrame: CGRect(x: 0, y: 0, width: 1168, height: 729),
            chrome: CGSize(width: 26, height: 26), lowestAnchorCenterY: 89)
        #expect(small == CGSize(width: 400, height: 136))
        #expect(small.height + 26 == 2 * (89 - DashboardViewportPolicy.edgeMargin))
        #expect(DashboardViewportPolicy.normalizedAnchorCenterY(
            diskCenterY: 104, memoryHeight: 169) ==
            DashboardViewportPolicy.normalizedAnchorCenterY(
                diskCenterY: 89, memoryHeight: 184))
    }

    @Test func outerWindowClampPreservesSizeAndEightPointMargin() {
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1084)
        let original = CGRect(x: 957, y: 365, width: 306, height: 694)
        let origin = DashboardViewportPolicy.containedOrigin(window: original, visibleFrame: screen)
        #expect(origin == CGPoint(x: 957, y: 365))

        let overTop = CGRect(x: 957, y: 390, width: 306, height: 694)
        let corrected = try? #require(DashboardViewportPolicy.containedOrigin(window: overTop,
            visibleFrame: screen))
        #expect(corrected?.y == 382)
        if let corrected {
            #expect(DashboardViewportPolicy.contains(
                CGRect(origin: corrected, size: overTop.size), visibleFrame: screen))
        }
        #expect(DashboardViewportPolicy.containedOrigin(
            window: CGRect(x: 0, y: 0, width: 500, height: 500),
            visibleFrame: CGRect(x: 0, y: 0, width: 400, height: 400)) == nil)
    }

    @Test func detailRegistrationKeepsOnlyCurrentOwnedWindow() {
        let viewport = DashboardViewport()
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 426, height: 506),
            styleMask: .borderless, backing: .buffered, defer: false)
        viewport.registerDetail(window: window, selection: .network,
            contentSize: CGSize(width: 400, height: 480))
        #expect(viewport.detailWindow === window)
        #expect(viewport.detailSelection == .network)
        viewport.registerDetail(window: nil, removingWindow: window,
            selection: .disk, contentSize: .zero)
        #expect(viewport.detailWindow === window)
        let replacement = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 426, height: 506),
            styleMask: .borderless, backing: .buffered, defer: false)
        viewport.registerDetail(window: replacement, selection: .network,
            contentSize: CGSize(width: 400, height: 480))
        viewport.registerDetail(window: nil, removingWindow: window,
            selection: .network, contentSize: .zero)
        #expect(viewport.detailWindow === replacement)
        viewport.registerDetail(window: nil, removingWindow: replacement,
            selection: .network, contentSize: .zero)
        #expect(viewport.detailWindow == nil)
    }
}
