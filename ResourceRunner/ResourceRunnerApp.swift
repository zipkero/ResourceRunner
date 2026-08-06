//
//  ResourceRunnerApp.swift
//  ResourceRunner
//
//  Created by zipkero on 8/2/26.
//

import SwiftUI

@main
struct ResourceRunnerApp: App {
    // Dock 아이콘과 기본 창 대신 AppDelegate가 메뉴바 셸 구성을 전담합니다.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 일반 창을 만들지 않고 SwiftUI Scene 요구사항만 충족합니다.
        Settings {
            EmptyView()
        }
    }
}
