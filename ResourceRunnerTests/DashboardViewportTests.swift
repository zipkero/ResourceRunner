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

    @Test func memoryNormalizationFollowsItsActualPositionOnlyWhenRankingIsVisible() {
        // Memory가 마지막 카드면 높이 차이만큼 아래쪽 끝이 움직이고 중심은 그 절반만 움직입니다.
        #expect(DashboardViewportPolicy.normalizedAnchorCenterY(
            cardCenterY: 104, card: .memory, memoryHeight: 169,
            memoryIsAboveAnchor: false) ==
            DashboardViewportPolicy.normalizedAnchorCenterY(
                cardCenterY: 96.5, card: .memory, memoryHeight: 184,
                memoryIsAboveAnchor: false))
        #expect(DashboardViewportPolicy.normalizedAnchorCenterY(
            cardCenterY: 104, card: .disk, memoryHeight: 169,
            memoryIsAboveAnchor: true) == 89)
        #expect(DashboardViewportPolicy.normalizedAnchorCenterY(
            cardCenterY: 104, card: .cpu, memoryHeight: nil,
            memoryIsAboveAnchor: false) == 104)
        #expect(DashboardViewportPolicy.normalizedAnchorCenterY(
            cardCenterY: 104, card: .memory, memoryHeight: nil,
            memoryIsAboveAnchor: false) == 104)
    }

    @Test func currentLastCardRejectsOldRevisionOlderViewAndStaleRemoval() {
        let viewport = DashboardViewport()
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 280, height: 400),
            styleMask: .borderless, backing: .buffered, defer: false)
        let memory = NSView(frame: CGRect(x: 0, y: 120, width: 260, height: 169))
        let disk = NSView(frame: CGRect(x: 0, y: 0, width: 260, height: 112))
        let newMemory = NSView(frame: CGRect(x: 0, y: 0, width: 260, height: 90))
        window.contentView?.addSubview(memory)
        window.contentView?.addSubview(disk)
        window.contentView?.addSubview(newMemory)

        viewport.configure(visibleCards: [.cpu, .memory, .disk], revision: 1,
            normalizesMemoryHeight: true)
        viewport.registerCard(view: memory, card: .memory, revision: 1, order: 1, isLast: false)
        viewport.registerCard(view: disk, card: .disk, revision: 1, order: 2, isLast: true)
        #expect(viewport.expectedAnchor == .disk)
        #expect(viewport.lowestAnchorView === disk)
        #expect(viewport.memoryCardView === memory)

        viewport.configure(visibleCards: [.cpu, .memory], revision: 2,
            normalizesMemoryHeight: false)
        #expect(viewport.expectedAnchor == .memory)
        #expect(viewport.lowestAnchorView == nil)
        #expect(viewport.memoryCardView == nil)
        viewport.registerCard(view: disk, card: .disk, revision: 1, order: 3, isLast: true)
        viewport.unregisterCard(view: memory, card: .memory, revision: 1)
        #expect(viewport.lowestAnchorView == nil)
        viewport.registerCard(view: newMemory, card: .memory, revision: 2, order: 5, isLast: true)
        #expect(viewport.lowestAnchorView === newMemory)
        viewport.registerCard(view: memory, card: .memory, revision: 2, order: 1, isLast: true)
        viewport.unregisterCard(view: memory, card: .memory, revision: 2)
        #expect(viewport.lowestAnchorView === newMemory)
        viewport.unregisterCard(view: newMemory, card: .memory, revision: 2)
        #expect(viewport.lowestAnchorView == nil)
        #expect(viewport.memoryCardView == nil)
    }

    @Test func focusReturnTargetUsesCurrentVisibilityAndRejectsReorderedIntent() throws {
        let store = DashboardPresentationStore()
        store.selectCard(.disk)
        store.selectCard(.disk)
        let original = try #require(store.focusReturnRequest(after: .disk))
        #expect(original.target == .card(.disk))
        #expect(store.acceptsFocusReturn(original))

        var preferences = AppPreferences.defaults
        preferences.showsDiskCard = false
        store.applyPreferences(PreferencesSnapshot(preferences: preferences, revision: 1))
        #expect(!store.acceptsFocusReturn(original))
        let fallback = try #require(store.focusReturnRequest(after: .disk))
        #expect(fallback.target == .card(.cpu))
        preferences.showsCPUCard = false
        preferences.showsMemoryCard = false
        preferences.showsNetworkCard = false
        store.applyPreferences(PreferencesSnapshot(preferences: preferences, revision: 2))
        #expect(!store.acceptsFocusReturn(fallback))
        let allOff = try #require(store.focusReturnRequest(after: .disk))
        #expect(allOff.target == .settings)
        store.selectCard(.disk)
        #expect(store.acceptsFocusReturn(allOff))
        preferences.showsCPUCard = true
        store.applyPreferences(PreferencesSnapshot(preferences: preferences, revision: 3))
        store.selectCard(.cpu)
        #expect(!store.acceptsFocusReturn(allOff))
    }

    @Test func noCurrentAnchorClosesOwnedDetailAndKeepsScreenBasedDefaultSize() async throws {
        let screen = try #require(NSScreen.main)
        let viewport = DashboardViewport()
        viewport.apply(screen: screen)
        let detail = NSWindow(contentRect: CGRect(x: 80, y: 80, width: 426, height: 506),
            styleMask: .borderless, backing: .buffered, defer: false)
        detail.isReleasedWhenClosed = false
        detail.orderFront(nil)
        viewport.registerDetail(window: detail, selection: .memory,
            contentSize: CGSize(width: 400, height: 480))
        viewport.configure(visibleCards: [], revision: 1, normalizesMemoryHeight: false)
        try await Task.sleep(for: .milliseconds(150))
        #expect(!detail.isVisible)
        #expect(viewport.expectedAnchor == nil)
        #expect(viewport.detailSize == DashboardViewportPolicy.detailSize(
            visibleFrame: screen.visibleFrame, chrome: viewport.detailChrome))
    }

    @Test func actualMemoryLastAndDiskLastFramesUseDifferentHeightCorrections() throws {
        let screen = try #require(NSScreen.main)
        let window = NSWindow(contentRect: CGRect(x: screen.visibleFrame.minX + 20,
            y: screen.visibleFrame.minY + 8, width: 280, height: 400),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let memory = NSView(frame: CGRect(x: 0, y: 112, width: 260, height: 169))
        let disk = NSView(frame: CGRect(x: 0, y: 0, width: 260, height: 112))
        window.contentView?.addSubview(memory)
        window.contentView?.addSubview(disk)
        window.orderFront(nil)

        let viewport = DashboardViewport()
        viewport.apply(screen: screen)
        viewport.configure(visibleCards: [.memory], revision: 1,
            normalizesMemoryHeight: false)
        viewport.registerCard(view: memory, card: .memory, revision: 1, order: 1, isLast: true)
        let memoryCenter = window.convertToScreen(memory.convert(memory.bounds, to: nil)).midY
        let noRankingSize = viewport.detailSize
        #expect(noRankingSize == DashboardViewportPolicy.detailSize(
            visibleFrame: screen.visibleFrame, chrome: viewport.detailChrome,
            lowestAnchorCenterY: memoryCenter))

        viewport.configure(visibleCards: [.memory], revision: 2,
            normalizesMemoryHeight: true)
        viewport.registerCard(view: memory, card: .memory, revision: 2, order: 1, isLast: true)
        #expect(viewport.detailSize == DashboardViewportPolicy.detailSize(
            visibleFrame: screen.visibleFrame, chrome: viewport.detailChrome,
            lowestAnchorCenterY: memoryCenter + CGFloat(169 - 184) / 2))
        #expect(viewport.detailSize.height < noRankingSize.height)

        viewport.configure(visibleCards: [.memory, .disk], revision: 3,
            normalizesMemoryHeight: true)
        viewport.registerCard(view: memory, card: .memory, revision: 3, order: 1, isLast: false)
        viewport.registerCard(view: disk, card: .disk, revision: 3, order: 2, isLast: true)
        let diskCenter = window.convertToScreen(disk.convert(disk.bounds, to: nil)).midY
        #expect(viewport.detailSize == DashboardViewportPolicy.detailSize(
            visibleFrame: screen.visibleFrame, chrome: viewport.detailChrome,
            lowestAnchorCenterY: diskCenter + 169 - 184))
    }
}
