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
        if ProcessInfo.processInfo.arguments.contains("--task002-disk-probe") {
            do {
                let snapshot = try DiskNativeAdapter().read()
                let raw = try URL(fileURLWithPath: "/").resourceValues(forKeys: [
                    .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
                    .volumeAvailableCapacityForImportantUsageKey])
                print("TASK002 date=\(ISO8601DateFormatter().string(from: Date())) pid=\(ProcessInfo.processInfo.processIdentifier) driverLookup=\(snapshot.driverLookup) volumeLookup=\(snapshot.volumeLookup) physicalComplete=\(snapshot.physicalTotalsComplete) relationshipsComplete=\(snapshot.relationshipsComplete)")
                print("TASK002 rawRoot total=\(raw.volumeTotalCapacity.map(String.init) ?? "nil") rawAvailable=\(raw.volumeAvailableCapacity.map(String.init) ?? "nil") importantAvailable=\(raw.volumeAvailableCapacityForImportantUsage.map(String.init) ?? "nil")")
                let system = snapshot.systemVolume
                print("TASK002 system total=\(system.totalBytes) available=\(system.availableBytes) used=\(system.usedBytes) decimalTotal=\(ResourceQuantityFormatter.storageBytes(system.totalBytes, locale: Locale(identifier: "en_US"))) decimalAvailable=\(ResourceQuantityFormatter.storageBytes(system.availableBytes, locale: Locale(identifier: "en_US"))) decimalUsed=\(ResourceQuantityFormatter.storageBytes(system.usedBytes, locale: Locale(identifier: "en_US"))) bsd=\(system.bsdName ?? "nil") drivers=\(system.driverIDs.sorted()) relation=\(system.relationReason)")
                for driver in snapshot.drivers {
                    print("TASK002 driver id=\(driver.registryID) bsd=\(driver.bsdNames.sorted()) kind=\(driver.kind.rawValue) read=\(driver.readBytes) write=\(driver.writtenBytes) readOps=\(driver.readOperations.map(String.init) ?? "nil") writeOps=\(driver.writeOperations.map(String.init) ?? "nil") opsReason=\(driver.operationsReason) external=\(driver.external.rawValue) externalReason=\(driver.externalReason) removable=\(driver.removable.map(String.init) ?? "nil") ejectable=\(driver.ejectable.map(String.init) ?? "nil")")
                }
                for volume in snapshot.volumes {
                    print("TASK002 volume identity=\(volume.identity) mounts=\(volume.mountPaths.sorted()) total=\(volume.totalBytes) available=\(volume.availableBytes) used=\(volume.usedBytes) bsd=\(volume.bsdName ?? "nil") scope=\(volume.scope.rawValue) drivers=\(volume.driverIDs.sorted()) shared=\(volume.sharedCapacity)")
                }
                fflush(stdout)
                exit(0)
            } catch {
                print("TASK002 ERROR \(error)")
                fflush(stdout)
                exit(2)
            }
        }
#endif
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
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--task014-probe") {
            Task014Probe.emit("probe-ready pid=\(getpid())")
            coordinator?.statusBarController.togglePopover()
            Task014Probe.emit("popover-shown=\(coordinator?.statusBarController.popover.isShown ?? false)")
        }
#endif
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
