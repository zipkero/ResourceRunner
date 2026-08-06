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
}

private struct EmptyDashboardStub: View {
    var body: some View {
        EmptyView()
    }
}
