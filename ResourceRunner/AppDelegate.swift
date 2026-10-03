//
//  AppDelegate.swift
//  ResourceRunner
//
//  Created by zipkero on 8/2/26.
//

import AppKit

/// 앱 시작 시 단일 `ApplicationCoordinator`를 만들어 종료까지 강하게 보유합니다.
/// 별도 Helper나 추가 실행 대상은 만들지 않습니다.
/// 실제 잠금·해제 관찰 로그는 `ApplicationCoordinator`가 자신이 만드는 단일
/// `SystemLifecycleObserver`에서 남기므로, 여기서 별도 observer를 만들지 않습니다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: ApplicationCoordinator?
    private var preferencesStore: PreferencesStore?
    private var loginItemController: LoginItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
#if DEBUG
        let preferences: PreferencesStore
        if ProcessInfo.processInfo.arguments.contains("--dashboard-preferences-ui-test") {
            let environment = ProcessInfo.processInfo.environment
            let cardMask = Int(environment["RR_DASHBOARD_CARD_MASK"] ?? "15") ?? 15
            let topMask = Int(environment["RR_DASHBOARD_TOP_MASK"] ?? "3") ?? 3
            var fixture = AppPreferences.defaults
            fixture.showsCPUCard = cardMask & 1 != 0
            fixture.showsMemoryCard = cardMask & 2 != 0
            fixture.showsNetworkCard = cardMask & 4 != 0
            fixture.showsDiskCard = cardMask & 8 != 0
            fixture.showsCPUTopApplications = topMask & 1 != 0
            fixture.showsMemoryTopApplications = topMask & 2 != 0
            preferences = PreferencesStore(storage: DashboardUITestPreferencesStorage(initial: fixture))
        } else {
            preferences = PreferencesStore()
        }
#else
        let preferences = PreferencesStore()
#endif
        let login = LoginItemController()
        preferencesStore = preferences
        loginItemController = login
        coordinator = ApplicationCoordinator(preferencesStore: preferences,
            loginItemController: login)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        coordinator?.refreshLoginStatus()
    }
}

#if DEBUG
/// UI 테스트 설정은 프로세스 안에서만 유지해 기존 사용자 설정을 건드리지 않습니다.
@MainActor
private final class DashboardUITestPreferencesStorage: PreferencesStorage {
    private var value: [String: Any]

    init(initial: AppPreferences) {
        value = [
            "schemaVersion": 1,
            "showsCPUCard": initial.showsCPUCard,
            "showsMemoryCard": initial.showsMemoryCard,
            "showsNetworkCard": initial.showsNetworkCard,
            "showsDiskCard": initial.showsDiskCard,
            "showsCPUTopApplications": initial.showsCPUTopApplications,
            "showsMemoryTopApplications": initial.showsMemoryTopApplications,
        ]
    }

    func read() -> Any? { value }
    func write(_ dictionary: [String: Any]) { value = dictionary }
}
#endif
