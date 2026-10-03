import CoreFoundation
import Foundation
import Observation

@MainActor
protocol PreferencesStorage {
    func read() -> Any?
    func write(_ dictionary: [String: Any])
}

@MainActor
struct UserDefaultsPreferencesStorage: PreferencesStorage {
    static let key = "preferences.v1"
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func read() -> Any? {
        defaults.object(forKey: Self.key)
    }

    func write(_ dictionary: [String: Any]) {
        defaults.set(dictionary, forKey: Self.key)
    }
}

nonisolated struct PreferencesSnapshot: Equatable, Sendable {
    let preferences: AppPreferences
    let revision: UInt64
}

@Observable
@MainActor
final class PreferencesStore {
    private let storage: any PreferencesStorage
    private(set) var current: PreferencesSnapshot

    convenience init() {
        self.init(storage: UserDefaultsPreferencesStorage())
    }

    init(storage: any PreferencesStorage) {
        self.storage = storage
        current = PreferencesSnapshot(
            preferences: Self.decode(storage.read()), revision: 0
        )
    }

    func update(_ change: (inout AppPreferences) -> Void) {
        var preferences = current.preferences
        change(&preferences)
        publish(preferences)
    }

    func restoreDefaults() {
        publish(.defaults)
    }

    private func publish(_ preferences: AppPreferences) {
        // 한 값으로 게시해 관찰자가 새 설정과 이전 revision을 섞어 읽지 않게 합니다.
        let next = PreferencesSnapshot(
            preferences: preferences, revision: current.revision + 1
        )
        storage.write(Self.encode(preferences))
        current = next
    }

    private static func decode(_ raw: Any?) -> AppPreferences {
        guard let dictionary = raw as? [String: Any],
              let schema = dictionary["schemaVersion"] as? NSNumber,
              CFGetTypeID(schema) == CFNumberGetTypeID(),
              schema.intValue == 1, schema.doubleValue == 1 else {
            return .defaults
        }

        var preferences = AppPreferences.defaults
        preferences.showsCPUCard = boolean(dictionary["showsCPUCard"]) ?? preferences.showsCPUCard
        preferences.showsMemoryCard = boolean(dictionary["showsMemoryCard"]) ?? preferences.showsMemoryCard
        preferences.showsNetworkCard = boolean(dictionary["showsNetworkCard"]) ?? preferences.showsNetworkCard
        preferences.showsDiskCard = boolean(dictionary["showsDiskCard"]) ?? preferences.showsDiskCard
        preferences.showsCPUTopApplications = boolean(dictionary["showsCPUTopApplications"]) ?? preferences.showsCPUTopApplications
        preferences.showsMemoryTopApplications = boolean(dictionary["showsMemoryTopApplications"]) ?? preferences.showsMemoryTopApplications
        if let rawRange = dictionary["graphTimeRange"] as? String,
           let range = GraphTimeRange(rawValue: rawRange) {
            preferences.graphTimeRange = range
        }
        if let rawProfile = dictionary["refreshProfile"] as? String,
           let profile = RefreshProfile(rawValue: rawProfile) {
            preferences.refreshProfile = profile
        }
        return preferences
    }

    private static func boolean(_ raw: Any?) -> Bool? {
        guard let number = raw as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    private static func encode(_ preferences: AppPreferences) -> [String: Any] {
        [
            "schemaVersion": 1,
            "showsCPUCard": preferences.showsCPUCard,
            "showsMemoryCard": preferences.showsMemoryCard,
            "showsNetworkCard": preferences.showsNetworkCard,
            "showsDiskCard": preferences.showsDiskCard,
            "showsCPUTopApplications": preferences.showsCPUTopApplications,
            "showsMemoryTopApplications": preferences.showsMemoryTopApplications,
            "graphTimeRange": preferences.graphTimeRange.rawValue,
            "refreshProfile": preferences.refreshProfile.rawValue
        ]
    }
}
