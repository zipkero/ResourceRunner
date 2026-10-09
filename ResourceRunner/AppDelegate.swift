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
        if ProcessInfo.processInfo.arguments.contains("--preferences-persistence-ui-test"),
           let suite = ProcessInfo.processInfo.environment["RR_PREFERENCES_TEST_SUITE"],
           suite.hasPrefix("ResourceRunnerUITest."),
           let defaults = UserDefaults(suiteName: suite) {
            // 재실행 UI 검증은 테스트별 격리 domain을 사용해 실제 사용자 설정을 건드리지 않습니다.
            if ProcessInfo.processInfo.arguments.contains("--preferences-persistence-cleanup") {
                defaults.removePersistentDomain(forName: suite)
            }
            if ProcessInfo.processInfo.arguments.contains("--preferences-persistence-seed-schema1"),
               defaults.object(forKey: UserDefaultsPreferencesStorage.key) == nil {
                // 과거 payload의 기존 선택은 유지하고 새 세 필드만 기본값으로 해독하는 경로를 검증합니다.
                defaults.set(["schemaVersion": 1, "showsCPUCard": false,
                              "showsMemoryCard": true, "showsNetworkCard": true,
                              "showsDiskCard": true, "showsCPUTopApplications": false,
                              "showsMemoryTopApplications": true,
                              "graphTimeRange": "fiveMinutes", "refreshProfile": "energySaving"],
                             forKey: UserDefaultsPreferencesStorage.key)
            }
            preferences = PreferencesStore(storage: UserDefaultsPreferencesStorage(defaults: defaults))
        } else if ProcessInfo.processInfo.arguments.contains("--dashboard-preferences-ui-test") {
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
        let login: LoginItemController
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--settings-ui-test") {
            login = LoginItemController(service: SettingsUITestLoginService(
                environment: ProcessInfo.processInfo.environment))
        } else {
            login = LoginItemController()
        }
#else
        login = LoginItemController()
#endif
        preferencesStore = preferences
        loginItemController = login
        coordinator = ApplicationCoordinator(preferencesStore: preferences,
            loginItemController: login)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        coordinator?.refreshLoginStatus()
    }

    func openSettings() {
        coordinator?.openSettings()
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

/// UI 테스트 프로세스의 로그인 항목을 메모리에서만 시뮬레이션합니다.
@MainActor
private final class SettingsUITestLoginService: LoginItemServing {
    private var currentStatus: LoginItemStatus
    private let registerOutcome: String
    private let unregisterOutcome: String

    init(environment: [String: String]) {
        switch environment["RR_LOGIN_STATUS"] {
        case "enabled": currentStatus = .enabled
        case "approval": currentStatus = .requiresApproval
        case "notFound": currentStatus = .notFound
        case "unknown": currentStatus = .unknown(99)
        default: currentStatus = .notRegistered
        }
        registerOutcome = environment["RR_LOGIN_REGISTER_OUTCOME"] ?? "enabled"
        unregisterOutcome = environment["RR_LOGIN_UNREGISTER_OUTCOME"] ?? "notRegistered"
    }

    func status() -> LoginItemStatus { currentStatus }

    func register() async throws {
        if registerOutcome == "failure" {
            throw NSError(domain: "ResourceRunnerUITest", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "테스트 등록 실패"])
        }
        currentStatus = registerOutcome == "approval" ? .requiresApproval : .enabled
    }

    func unregister() async throws {
        if unregisterOutcome == "failure" {
            throw NSError(domain: "ResourceRunnerUITest", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "테스트 해제 실패"])
        }
        currentStatus = .notRegistered
    }

    func openSystemSettingsLoginItems() {
        // 명시적 버튼 동작만 테스트합니다. 시스템 설정이나 실제 등록 항목은 열지 않습니다.
        currentStatus = .enabled
    }
}
#endif
