import Foundation

nonisolated enum GraphTimeRange: String, CaseIterable, Sendable {
    case oneMinute
    case fiveMinutes
    case tenMinutes

    var duration: TimeInterval {
        switch self {
        case .oneMinute: 60
        case .fiveMinutes: 300
        case .tenMinutes: 600
        }
    }
}

nonisolated enum RefreshProfile: String, CaseIterable, Sendable {
    case fast
    case standard
    case energySaving
    case maximumEnergySaving
}

nonisolated struct AppPreferences: Equatable, Sendable {
    var showsCPUCard = true
    var showsMemoryCard = true
    var showsNetworkCard = true
    var showsDiskCard = true
    var showsCPUTopApplications = true
    var showsMemoryTopApplications = true
    var graphTimeRange: GraphTimeRange = .tenMinutes
    var refreshProfile: RefreshProfile = .standard

    static let defaults = AppPreferences()
}
