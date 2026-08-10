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

    /// 표시 상태를 기록하는 테스트 전용 출력.
    final class RecordingOutput: StatusBarControllerOutput {
        private(set) var reportedValues: [Bool] = []

        func popoverPresented(_ isPresented: Bool) {
            reportedValues.append(isPresented)
        }
    }

    @Test func statusItemHasFixedSquareLength() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())

        #expect(controller.statusItem.length == NSStatusItem.squareLength)
    }

    @Test func popoverUsesTransientBehavior() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())

        #expect(controller.popover.behavior == .transient)
    }

    /// 아래 출력 테스트는 delegate 메서드를 직접 호출하므로 `NSPopover`를 거치지 않습니다.
    /// 배선이 끊겨도 그 테스트는 통과하므로, 실제 delegate 연결은 여기서 따로 확인합니다.
    /// 이 연결이 끊기면 `popoverPresented(_:)`가 영영 호출되지 않고 수집 일정이 팝오버 상태에 반응하지 않습니다.
    @Test func popoverDelegateIsWiredToController() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())

        #expect(controller.popover.delegate === controller)
    }

    @Test func delegateOutputReflectsActualShowAndCloseInOrder() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())
        let output = RecordingOutput()
        controller.output = output

        // 실제 화면 표시 없이도 delegate 이벤트만으로 출력이 표시 상태를 그대로 반영하는지 확인합니다.
        controller.popoverDidShow(Notification(name: NSPopover.didShowNotification, object: controller.popover))
        controller.popoverDidClose(Notification(name: NSPopover.didCloseNotification, object: controller.popover))
        controller.popoverDidShow(Notification(name: NSPopover.didShowNotification, object: controller.popover))

        #expect(output.reportedValues == [true, false, true])
    }

    // `togglePopover()`가 실제로 `NSPopover.isShown`을 뒤집는지는 단위 테스트 host 프로세스가
    // 비활성 상태라 `NSPopover.show()`가 화면에 실제로 표시되지 않아 여기서 검증하지 않습니다.
    // 실제 클릭 이벤트로 열고 닫는 경로는 ResourceRunnerUITests가 검증합니다.

    /// task-012 검증 조건: `StatusBarController`가 받은 값을 버튼 접근성 이름에 그대로 반영하는지 확인합니다.
    @Test func renderReflectsReceivedAccessibilityLabelOnButton() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())
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

    /// task-012 검증 조건: 다섯 상태를 순환시켜도 `NSStatusItem.length`와 버튼 이미지 참조가 변하지 않는지 확인합니다.
    @Test func cyclingThroughAllStatesKeepsLengthAndButtonImageStable() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())
        guard let button = controller.statusItem.button else {
            Issue.record("status item에 button이 없습니다")
            return
        }

        let fixedLength = controller.statusItem.length
        let fixedImage = button.image

        let states: [CharacterActivityState] = [.low, .moderate, .high, .veryHigh, .sustainedHigh]
        for state in states {
            controller.render(.presenting(state))

            #expect(controller.statusItem.length == fixedLength)
            #expect(button.image === fixedImage)
        }
    }

    /// task-012 검증 조건: 팝오버를 연 뒤 표시 경로만 실행해 `NSPopover.isShown`이 유지되는지 확인합니다.
    /// 이 관찰은 Debug 우클릭 주입 메뉴를 거치지 않습니다. 그 메뉴를 여는 동작은 메뉴바 항목 클릭이라
    /// `NSPopover`가 외부 클릭으로 판정해 팝오버를 닫는데, 그것은 주입 수단의 성질이지 표시 경로의 결과가 아닙니다.
    @Test func renderKeepsAnOpenPopoverShown() {
        let controller = StatusBarController(popoverContent: EmptyDashboardStub())
        guard let button = controller.statusItem.button else {
            Issue.record("status item에 button이 없습니다")
            return
        }

        // 단위 테스트 host 프로세스는 비활성 상태로 시작하고 `NSPopover.show(...)`는 비활성 앱에서 표시되지 않습니다.
        // `togglePopover()`의 여는 경로와 같이 앱을 먼저 활성화하되, 활성화는 비동기로 완료되므로
        // 실제로 활성 상태가 될 때까지 run loop를 돌린 뒤 팝오버를 엽니다.
        NSApp.activate()
        let activationDeadline = Date().addingTimeInterval(2)
        while !NSApp.isActive && Date() < activationDeadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        controller.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        guard controller.popover.isShown else {
            Issue.record("팝오버가 열리지 않아 보존 여부를 관찰할 수 없습니다 (앱 활성 상태: \(NSApp.isActive))")
            return
        }

        let states: [CharacterActivityState] = [.low, .moderate, .high, .veryHigh, .sustainedHigh]
        for state in states {
            controller.render(.presenting(state))

            #expect(controller.popover.isShown)
        }

        controller.popover.performClose(nil)
    }
}

private struct EmptyDashboardStub: View {
    var body: some View {
        EmptyView()
    }
}
