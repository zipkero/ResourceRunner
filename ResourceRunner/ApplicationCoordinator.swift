//
//  ApplicationCoordinator.swift
//  ResourceRunner
//
//  Created by zipkero on 8/2/26.
//

import AppKit

/// 앱 수명 동안 필요한 객체를 한 번만 구성하고 소유하는 경계.
/// task-001 범위에서는 메뉴바 셸(`StatusBarController`)만 구성합니다.
/// 캐릭터 표시, 생명주기 관찰과 수집 일정은 이후 Task에서 이 타입에 추가됩니다.
@MainActor
final class ApplicationCoordinator {
    let statusBarController: StatusBarController

    init() {
        statusBarController = StatusBarController(popoverContent: DashboardView())
        statusBarController.output = self
    }
}

extension ApplicationCoordinator: StatusBarControllerOutput {
    func popoverPresented(_ isPresented: Bool) {
        // task-009에서 이 값을 MonitoringLifecycleStore의 popoverPresented 입력으로 전달합니다.
        // task-001 범위에는 수집 일정이 없으므로 아직 아무 것도 하지 않습니다.
    }
}
