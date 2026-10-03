import CoreFoundation
import Foundation
import Testing
@testable import ResourceRunner

@MainActor
private final class RecordingPreferencesStorage: PreferencesStorage {
    var value: Any?
    private(set) var writes: [[String: Any]] = []

    init(_ value: Any? = nil) {
        self.value = value
    }

    func read() -> Any? { value }

    func write(_ dictionary: [String: Any]) {
        writes.append(dictionary)
        value = dictionary
    }
}

@MainActor
struct PreferencesStoreTests {
    @Test func changeCallbackPublishesSavedSnapshotOncePerMutation() {
        let storage = RecordingPreferencesStorage()
        let store = PreferencesStore(storage: storage)
        var seen: [PreferencesSnapshot] = []
        store.onChange = { seen.append($0) }
        #expect(seen.isEmpty)

        store.update { $0.refreshProfile = .fast }
        store.restoreDefaults()
        #expect(seen.count == 2)
        #expect(seen[0].revision == 1)
        #expect(seen[0].preferences.refreshProfile == .fast)
        #expect(seen[1] == store.current)
        #expect(storage.writes.count == 2)
    }

    @Test func defaultsAndInitialReadDoNotWrite() {
        let storage = RecordingPreferencesStorage()
        let store = PreferencesStore(storage: storage)

        #expect(store.current == PreferencesSnapshot(preferences: .defaults, revision: 0))
        #expect(storage.writes.isEmpty)
        #expect(store.current.preferences.graphTimeRange.duration == 600)
    }

    @Test func invalidContainerOrSchemaUsesAllDefaults() {
        let malformed: [Any?] = ["broken", ["showsCPUCard": false],
            ["schemaVersion": 2, "showsCPUCard": false],
            ["schemaVersion": true, "showsCPUCard": false]]
        for value in malformed {
            let storage = RecordingPreferencesStorage(value)
            let store = PreferencesStore(storage: storage)
            #expect(store.current.preferences == .defaults)
            #expect(storage.writes.isEmpty)
        }
    }

    @Test func supportedDictionaryRecoversOnlyInvalidFields() {
        let storage = RecordingPreferencesStorage([
            "schemaVersion": 1,
            "showsCPUCard": false,
            "showsMemoryCard": NSNumber(value: 0),
            "showsNetworkCard": "false",
            "showsDiskCard": true,
            "showsCPUTopApplications": false,
            "showsMemoryTopApplications": NSNumber(value: 1),
            "graphTimeRange": "fiveMinutes",
            "refreshProfile": "futureProfile"
        ])
        let store = PreferencesStore(storage: storage)

        #expect(store.current.preferences.showsCPUCard == false)
        #expect(store.current.preferences.showsMemoryCard == true)
        #expect(store.current.preferences.showsNetworkCard == true)
        #expect(store.current.preferences.showsDiskCard == true)
        #expect(store.current.preferences.showsCPUTopApplications == false)
        #expect(store.current.preferences.showsMemoryTopApplications == true)
        #expect(store.current.preferences.graphTimeRange == .fiveMinutes)
        #expect(store.current.preferences.refreshProfile == .standard)
        #expect(storage.writes.isEmpty)
    }

    @Test func explicitChangesAndRestoreEachPublishAndSaveOnce() {
        let storage = RecordingPreferencesStorage()
        let store = PreferencesStore(storage: storage)

        store.update {
            $0.showsCPUCard = false
            $0.refreshProfile = .fast
        }
        #expect(store.current.revision == 1)
        #expect(store.current.preferences.showsCPUCard == false)
        #expect(store.current.preferences.refreshProfile == .fast)
        #expect(storage.writes.count == 1)

        store.update { $0.graphTimeRange = .oneMinute }
        #expect(store.current.revision == 2)
        #expect(store.current.preferences.showsCPUCard == false)
        #expect(store.current.preferences.graphTimeRange == .oneMinute)
        #expect(storage.writes.count == 2)

        store.restoreDefaults()
        #expect(store.current == PreferencesSnapshot(preferences: .defaults, revision: 3))
        #expect(storage.writes.count == 3)
        #expect(Set(storage.writes[2].keys) == Set([
            "schemaVersion", "showsCPUCard", "showsMemoryCard", "showsNetworkCard",
            "showsDiskCard", "showsCPUTopApplications", "showsMemoryTopApplications",
            "graphTimeRange", "refreshProfile"
        ]))
    }

    @Test func isolatedUserDefaultsRoundTripWritesSupportedFieldsOnly() {
        let suiteName = "PreferencesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let storage = UserDefaultsPreferencesStorage(defaults: defaults)
        let initial = PreferencesStore(storage: storage)
        #expect(defaults.object(forKey: UserDefaultsPreferencesStorage.key) == nil)

        initial.update {
            $0.showsCPUCard = false
            $0.showsMemoryCard = false
            $0.showsNetworkCard = false
            $0.showsDiskCard = false
            $0.showsCPUTopApplications = false
            $0.showsMemoryTopApplications = false
            $0.graphTimeRange = .fiveMinutes
            $0.refreshProfile = .maximumEnergySaving
        }
        let restored = PreferencesStore(storage: storage)
        #expect(restored.current.preferences == initial.current.preferences)
        #expect(restored.current.revision == 0)
        let payload = defaults.dictionary(forKey: UserDefaultsPreferencesStorage.key)!
        #expect(payload.count == 9)
        #expect(payload["schemaVersion"] as? Int == 1)
        #expect(payload["refreshProfile"] as? String == "maximumEnergySaving")
        #expect(payload["graphTimeRange"] as? String == "fiveMinutes")
        for key in ["showsCPUCard", "showsMemoryCard", "showsNetworkCard", "showsDiskCard",
                    "showsCPUTopApplications", "showsMemoryTopApplications"] {
            let number = payload[key] as? NSNumber
            #expect(number != nil && CFGetTypeID(number!) == CFBooleanGetTypeID())
        }
    }
}
