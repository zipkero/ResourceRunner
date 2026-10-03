import ServiceManagement

nonisolated enum LoginItemStatus: Equatable, Sendable {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound
    case unknown(Int)

    var isEnabled: Bool { self == .enabled }
}

@MainActor
protocol LoginItemServing {
    func status() -> LoginItemStatus
    func register() async throws
    func unregister() async throws
    func openSystemSettingsLoginItems()
}

@MainActor
struct MainAppLoginItemService: LoginItemServing {
    func status() -> LoginItemStatus {
        let nativeStatus = SMAppService.mainApp.status
        return switch nativeStatus {
        case .enabled: .enabled
        case .notRegistered: .notRegistered
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .unknown(nativeStatus.rawValue)
        }
    }

    func register() async throws {
        try SMAppService.mainApp.register()
    }

    func unregister() async throws {
        try await SMAppService.mainApp.unregister()
    }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
