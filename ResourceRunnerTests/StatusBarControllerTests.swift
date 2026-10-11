//
//  StatusBarControllerTests.swift
//  ResourceRunnerTests
//
//  Created by zipkero on 8/2/26.
//

import Testing
import AppKit
import SwiftUI
@testable import ResourceRunner

/// task-001 검증 조건: `StatusBarController`의 고정 길이, `.transient` behavior,
/// delegate 기반 `popoverPresented(Bool)` 출력을 AppKit 통합 테스트로 확인합니다.
@MainActor
struct StatusBarControllerTests {

    @Test func focusReturnAllowsOwnedWindowsButRejectsKeySettingsWindow() {
        let body = NSWindow(contentRect: .zero, styleMask: .borderless,
            backing: .buffered, defer: false)
        let detail = NSWindow(contentRect: .zero, styleMask: .borderless,
            backing: .buffered, defer: false)
        let settings = NSWindow(contentRect: .zero, styleMask: .borderless,
            backing: .buffered, defer: false)
        body.addChildWindow(detail, ordered: .above)
        #expect(StatusBarController.canRestoreBodyFocus(keyWindow: nil, body: body, detail: detail))
        #expect(StatusBarController.canRestoreBodyFocus(keyWindow: body, body: body, detail: detail))
        #expect(StatusBarController.canRestoreBodyFocus(keyWindow: detail, body: body, detail: detail))
        #expect(!StatusBarController.canRestoreBodyFocus(keyWindow: settings, body: body, detail: detail))
    }

    /// 표시 상태를 기록하는 테스트 전용 출력.
    final class RecordingOutput: StatusBarControllerOutput {
        private(set) var reportedValues: [Bool] = []

        func popoverPresented(_ isPresented: Bool) {
            reportedValues.append(isPresented)
        }
    }

    @Test func statusItemHasFixedSquareLength() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())
        defer { finishFixture(controller) }

        #expect(controller.statusItem.length == NSStatusItem.squareLength)
    }

    @Test func popoverUsesTransientBehavior() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())
        defer { finishFixture(controller) }

        #expect(controller.popover.behavior == .transient)
    }

    @Test func savedOffAndRapidChangesKeepPopoverAndDelegateIdentity() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub(),
            automaticallyClosesPopover: false)
        defer { finishFixture(controller) }
        let output = RecordingOutput()
        controller.output = output
        let popover = controller.popover
        let delegate = popover.delegate
        #expect(popover.contentViewController == nil)
        #expect(popover.behavior == .applicationDefined)

        controller.applyAutomaticallyClosesPopover(true)
        #expect(popover.behavior == .transient)
        controller.applyAutomaticallyClosesPopover(false)
        #expect(popover.behavior == .applicationDefined)
        controller.applyAutomaticallyClosesPopover(true)
        #expect(popover.behavior == .transient)
        #expect(controller.popover === popover)
        #expect(popover.contentViewController == nil)
        #expect(popover.delegate === delegate)
        #expect(output.reportedValues.isEmpty)
    }

    /// delegate 배선이 끊기면 실제 열림·닫힘 출력이 수집 일정으로 전달되지 않습니다.
    @Test func popoverDelegateIsWiredToController() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())
        defer { finishFixture(controller) }

        #expect(controller.popover.delegate === controller)
    }

    @Test func delegateOutputReflectsActualShowAndCloseInOrder() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())
        defer { finishFixture(controller) }
        let output = RecordingOutput()
        controller.output = output
        activateTestApp()
        controller.togglePopover()
        #expect(controller.popover.isShown)
        #expect(controller.popover.contentViewController != nil)
        controller.togglePopover()
        waitForPopoverClose(controller)
        #expect(!controller.popover.isShown)
        #expect(controller.popover.contentViewController == nil)
        controller.togglePopover()
        #expect(controller.popover.isShown)
        let didShowDeadline = Date().addingTimeInterval(2)
        while output.reportedValues.count < 3 && Date() < didShowDeadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        #expect(output.reportedValues == [true, false, true])
        controller.popover.performClose(nil)
    }

    /// 닫힘의 해제와 재열림의 새 host를 실제 AppKit delegate 경계에서 확인합니다.
    @Test func closeReleasesHostAndRapidReopenKeepsNewHost() async {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())
        defer { finishFixture(controller) }
        let output = RecordingOutput()
        controller.output = output
        activateTestApp()
        controller.togglePopover()
        guard let first = controller.popover.contentViewController,
              controller.popover.isShown else {
            Issue.record("첫 팝오버가 열리지 않았습니다")
            return
        }
        controller.togglePopover()
        waitForPopoverClose(controller)
        #expect(controller.popover.contentViewController == nil)
        let reportedAfterClose = output.reportedValues
        controller.popoverDidShow(Notification(name: NSPopover.didShowNotification,
            object: controller.popover))
        #expect(output.reportedValues == reportedAfterClose)
        controller.togglePopover()
        guard let second = controller.popover.contentViewController,
              controller.popover.isShown else {
            Issue.record("두 번째 팝오버가 열리지 않았습니다")
            return
        }
        #expect(second !== first)
        let reported = output.reportedValues
        controller.popoverDidClose(Notification(name: NSPopover.didCloseNotification,
            object: controller.popover))
        #expect(output.reportedValues == reported)
        #expect(controller.popover.contentViewController === second)
        try? await Task.sleep(for: .milliseconds(550))
        #expect(controller.popover.isShown)
        #expect(controller.popover.contentViewController === second)
        controller.popover.performClose(nil)
    }

    @Test func reopenAsSoonAsPopoverReportsClosedSchedulesCorrection() async throws {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub(),
            viewport: DashboardViewport())
        defer { finishFixture(controller) }
        let output = RecordingOutput()
        controller.output = output
        activateTestApp()
        controller.togglePopover()
        let first = try #require(controller.popover.contentViewController)
        #expect(controller.popover.isShown)
        let firstShowDeadline = Date().addingTimeInterval(2)
        while !output.reportedValues.contains(true) && Date() < firstShowDeadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.002))
        }
        #expect(output.reportedValues == [true])

        controller.togglePopover()
        let deadline = Date().addingTimeInterval(2)
        while controller.popover.isShown && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.002))
        }
        #expect(!controller.popover.isShown)
        controller.togglePopover()
        let second = try #require(controller.popover.contentViewController)
        let window = try #require(second.view.window)
        let screen = try #require(window.screen ?? NSScreen.main)
        #expect(second !== first)
        #expect(controller.popover.isShown)

        window.setFrameOrigin(CGPoint(x: screen.visibleFrame.maxX + 100,
            y: screen.visibleFrame.minY + 20))
        try await Task.sleep(for: .milliseconds(550))
        #expect(controller.popover.isShown)
        #expect(controller.popover.contentViewController === second)
        #expect(output.reportedValues == [true, false, true])
        #expect(DashboardViewportPolicy.contains(window.frame,
            visibleFrame: screen.visibleFrame))
        controller.popover.performClose(nil)
    }

    /// task-012 검증 조건: `StatusBarController`가 받은 값을 버튼 접근성 이름에 그대로 반영하는지 확인합니다.
    @Test func renderReflectsReceivedAccessibilityLabelOnButton() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())
        defer { finishFixture(controller) }
        guard let button = controller.statusItem.button else {
            Issue.record("status item에 button이 없습니다")
            return
        }

        controller.render(.presenting(.moderate))

        #expect(button.accessibilityLabel() == "ResourceRunner, 보통")

        controller.render(.presenting(.sustainedHigh))

        #expect(button.accessibilityLabel() == "ResourceRunner, 장시간 고부하")
    }

    /// task-012 검증 조건: 표시 경로가 접근성 값을 설정하지 않아 상태 문자열이 접근성 이름 한 자리에만 존재합니다.
    @Test func renderDoesNotSetAccessibilityValue() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())
        defer { finishFixture(controller) }
        guard let button = controller.statusItem.button else {
            Issue.record("status item에 button이 없습니다")
            return
        }

        let valueBeforeRender = button.accessibilityValue() as? String

        let states: [CharacterActivityState] = [.low, .moderate, .high, .veryHigh, .sustainedHigh]
        for state in states {
            controller.render(.presenting(state))

            // 표시 경로가 값을 건드리지 않으므로 구성 시점 값에서 달라지지 않고,
            // 어떤 상태 설명도 값에 나타나지 않습니다.
            #expect(button.accessibilityValue() as? String == valueBeforeRender)
        }
    }

    /// 색상 전환은 폭·실루엣 크기를 유지하고 이미지를 재사용합니다.
    @Test func cyclingStatesKeepsSizeAndReusesCachedColorImages() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())
        defer { finishFixture(controller) }
        guard let button = controller.statusItem.button, let nativeImage = button.image else {
            Issue.record("status item의 이미지가 없습니다")
            return
        }
        let fixedLength = controller.statusItem.length
        var images: [CharacterActivityState: NSImage] = [:]
        let states: [CharacterActivityState] = [.low, .moderate, .high, .veryHigh, .sustainedHigh]
        for state in states {
            controller.render(.presenting(state))
            #expect(controller.statusItem.length == fixedLength)
            #expect(button.image?.size == NSSize(width: 18, height: 18))
            #expect(button.image?.isTemplate == (state == .low || state == .moderate))
            #expect(button.toolTip == button.accessibilityLabel())
            images[state] = button.image
        }
        #expect(images[.low] === nativeImage)
        #expect(images[.moderate] === nativeImage)
        #expect(images[.high] !== images[.veryHigh])
        #expect(images[.veryHigh] !== images[.sustainedHigh])
        for state in states.reversed() {
            controller.render(.presenting(state))
            #expect(button.image === images[state])
        }
    }

    @Test func coloredIconsPreserveMaskAndUseExpectedCPUColors() throws {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())
        defer { finishFixture(controller) }
        let button = try #require(controller.statusItem.button)
        let expectations: [(CharacterActivityState, NSColor)] = [
            (.high, .systemYellow), (.veryHigh, .systemOrange), (.sustainedHigh, .systemRed)
        ]
        var alphaMasks: [[Int]] = []
        for (state, color) in expectations {
            controller.render(.presenting(state))
            let image = try #require(button.image)
            // TIFF는 drawing-handler 이미지의 RGB를 Generic RGB로 재해석하므로 실제 그리기 경로를 검사합니다.
            let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil,
                pixelsWide: 18, pixelsHigh: 18, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0))
            let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
            NSGraphicsContext.restoreGraphicsState()
            let expected = try #require(color.usingColorSpace(.deviceRGB))
            var mask: [Int] = []
            var opaquePixels = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    let pixel = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                    mask.append(Int((pixel.alphaComponent * 255).rounded()))
                    if pixel.alphaComponent > 0.95 {
                        opaquePixels += 1
                        #expect(abs(pixel.redComponent - expected.redComponent) < 0.02)
                        #expect(abs(pixel.greenComponent - expected.greenComponent) < 0.02)
                        #expect(abs(pixel.blueComponent - expected.blueComponent) < 0.02)
                    }
                }
            }
            #expect(opaquePixels > 0)
            #expect(mask.contains(0))
            alphaMasks.append(mask)
        }
        #expect(alphaMasks[0] == alphaMasks[1])
        #expect(alphaMasks[1] == alphaMasks[2])
    }

    /// task-012 검증 조건: 팝오버를 연 뒤 표시 경로만 실행해 `NSPopover.isShown`이 유지되는지 확인합니다.
    /// 이 관찰은 Debug 우클릭 주입 메뉴를 거치지 않습니다. 그 메뉴를 여는 동작은 메뉴바 항목 클릭이라
    /// `NSPopover`가 외부 클릭으로 판정해 팝오버를 닫는데, 그것은 주입 수단의 성질이지 표시 경로의 결과가 아닙니다.
    @Test func renderKeepsAnOpenPopoverShown() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())
        defer { finishFixture(controller) }
        let output = RecordingOutput()
        controller.output = output
        guard controller.statusItem.button != nil else {
            Issue.record("status item에 button이 없습니다")
            return
        }

        activateTestApp()
        controller.togglePopover()

        guard controller.popover.isShown else {
            Issue.record("팝오버가 열리지 않아 보존 여부를 관찰할 수 없습니다 (앱 활성 상태: \(NSApp.isActive))")
            return
        }

        let originalPopover = controller.popover
        let originalContent = controller.popover.contentViewController
        let delegateCount = output.reportedValues.count
        controller.applyAutomaticallyClosesPopover(false)
        #expect(controller.popover.behavior == .applicationDefined)
        #expect(controller.popover.isShown)
        controller.applyAutomaticallyClosesPopover(true)
        #expect(controller.popover.behavior == .transient)
        #expect(controller.popover.isShown)
        #expect(controller.popover === originalPopover)
        #expect(controller.popover.contentViewController === originalContent)
        #expect(output.reportedValues.count == delegateCount)

        let states: [CharacterActivityState] = [.low, .moderate, .high, .veryHigh, .sustainedHigh]
        for state in states {
            controller.render(.presenting(state))

            #expect(controller.popover.isShown)
        }

        controller.popover.performClose(nil)
    }

    private func finishFixture(_ controller: StatusBarController) {
        // 다음 시험에 이전 메뉴바 scene과 닫힘 delegate가 남지 않게 생성한 항목만 정리합니다.
        if controller.popover.isShown || controller.popover.contentViewController != nil {
            controller.popover.performClose(nil)
            let deadline = Date().addingTimeInterval(2)
            while (controller.popover.isShown || controller.popover.contentViewController != nil)
                && Date() < deadline {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
            }
            #expect(!controller.popover.isShown)
            #expect(controller.popover.contentViewController == nil)
        }
        NSStatusBar.system.removeStatusItem(controller.statusItem)
    }

    private func activateTestApp() {
        NSApp.activate()
        let deadline = Date().addingTimeInterval(2)
        while !NSApp.isActive && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
    }

    private func waitForPopoverClose(_ controller: StatusBarController) {
        let deadline = Date().addingTimeInterval(2)
        while controller.popover.contentViewController != nil && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }
}

private struct EmptyDashboardStub: View {
    var body: some View {
        EmptyView()
    }
}
