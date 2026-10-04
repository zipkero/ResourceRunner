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
        // Scene 요구만 충족하며 제품 설정은 아래 명령과 AppKit 단일 창이 소유합니다.
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("설정…") { appDelegate.openSettings() }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
