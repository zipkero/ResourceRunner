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
        #expect(store.current.preferences.includesSystemProcesses == false)
        #expect(store.current.preferences.detailListLimit == .twenty)
        #expect(store.current.preferences.automaticallyClosesPopover == true)
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

    @Test func previousPayloadPreservesExistingChoicesAndDefaultsOnlyNewFields() {
        let storage = RecordingPreferencesStorage([
            "schemaVersion": 1,
            "showsCPUCard": false,
            "showsMemoryCard": false,
            "showsNetworkCard": false,
            "showsDiskCard": false,
            "showsCPUTopApplications": false,
            "showsMemoryTopApplications": false,
            "graphTimeRange": "oneMinute",
            "refreshProfile": "energySaving"
        ])
        let store = PreferencesStore(storage: storage)
        let preferences = store.current.preferences

        #expect(preferences.showsCPUCard == false)
        #expect(preferences.showsMemoryCard == false)
        #expect(preferences.showsNetworkCard == false)
        #expect(preferences.showsDiskCard == false)
        #expect(preferences.showsCPUTopApplications == false)
        #expect(preferences.showsMemoryTopApplications == false)
        #expect(preferences.graphTimeRange == .oneMinute)
        #expect(preferences.refreshProfile == .energySaving)
        #expect(preferences.includesSystemProcesses == false)
        #expect(preferences.detailListLimit == .twenty)
        #expect(preferences.automaticallyClosesPopover == true)
        #expect(store.current.revision == 0)
        #expect(storage.writes.isEmpty)
    }

    @Test func eachInvalidNewFieldFallsBackWithoutChangingOtherFields() {
        let valid: [String: Any] = [
            "schemaVersion": 1,
            "showsCPUCard": false,
            "graphTimeRange": "fiveMinutes",
            "refreshProfile": "fast",
            "includesSystemProcesses": true,
            "detailListLimit": "fifty",
            "automaticallyClosesPopover": false
        ]
        let invalidFields: [(String, Any, Bool, DetailListLimit, Bool)] = [
            ("includesSystemProcesses", 1, false, .fifty, false),
            ("includesSystemProcesses", "true", false, .fifty, false),
            ("detailListLimit", 50, true, .twenty, false),
            ("detailListLimit", "hundred", true, .twenty, false),
            ("automaticallyClosesPopover", 0, true, .fifty, true),
            ("automaticallyClosesPopover", "false", true, .fifty, true)
        ]
        for (key, value, included, limit, closes) in invalidFields {
            var payload = valid
            payload[key] = value
            let storage = RecordingPreferencesStorage(payload)
            let preferences = PreferencesStore(storage: storage).current.preferences
            #expect(preferences.showsCPUCard == false)
            #expect(preferences.graphTimeRange == .fiveMinutes)
            #expect(preferences.refreshProfile == .fast)
            #expect(preferences.includesSystemProcesses == included)
            #expect(preferences.detailListLimit == limit)
            #expect(preferences.automaticallyClosesPopover == closes)
            #expect(storage.writes.isEmpty)
        }
        for key in ["includesSystemProcesses", "detailListLimit", "automaticallyClosesPopover"] {
            var payload = valid
            payload.removeValue(forKey: key)
            let preferences = PreferencesStore(storage: RecordingPreferencesStorage(payload)).current.preferences
            #expect(preferences.showsCPUCard == false)
            #expect(preferences.includesSystemProcesses == (key == "includesSystemProcesses" ? false : true))
            #expect(preferences.detailListLimit == (key == "detailListLimit" ? .twenty : .fifty))
            #expect(preferences.automaticallyClosesPopover == (key == "automaticallyClosesPopover" ? true : false))
        }
    }

    @Test func newSettingsPublishOneSnapshotPerChangeAndRestore() {
        let storage = RecordingPreferencesStorage()
        let store = PreferencesStore(storage: storage)
        var seen: [PreferencesSnapshot] = []
        store.onChange = { seen.append($0) }

        store.update { $0.includesSystemProcesses = true }
        store.update { $0.detailListLimit = .ten }
        store.update { $0.automaticallyClosesPopover = false }
        #expect(seen.map(\.revision) == [1, 2, 3])
        #expect(seen[0].preferences.includesSystemProcesses == true)
        #expect(seen[0].preferences.detailListLimit == .twenty)
        #expect(seen[1].preferences.detailListLimit == .ten)
        #expect(seen[1].preferences.automaticallyClosesPopover == true)
        #expect(seen[2] == store.current)
        #expect(storage.writes.count == 3)
        #expect(store.current.preferences.includesSystemProcesses == true)
        #expect(store.current.preferences.detailListLimit == .ten)
        #expect(store.current.preferences.automaticallyClosesPopover == false)

        store.restoreDefaults()
        #expect(seen.count == 4)
        #expect(storage.writes.count == 4)
        #expect(store.current == PreferencesSnapshot(preferences: .defaults, revision: 4))
        #expect(seen[3] == store.current)
        #expect(storage.writes[3]["includesSystemProcesses"] as? Bool == false)
        #expect(storage.writes[3]["detailListLimit"] as? String == "twenty")
        #expect(storage.writes[3]["automaticallyClosesPopover"] as? Bool == true)
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
            "graphTimeRange", "refreshProfile", "includesSystemProcesses",
            "detailListLimit", "automaticallyClosesPopover"
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
            $0.includesSystemProcesses = true
            $0.detailListLimit = .fifty
            $0.automaticallyClosesPopover = false
        }
        let restored = PreferencesStore(storage: storage)
        #expect(restored.current.preferences == initial.current.preferences)
        #expect(restored.current.revision == 0)
        let payload = defaults.dictionary(forKey: UserDefaultsPreferencesStorage.key)!
        #expect(payload.count == 12)
        #expect(payload["schemaVersion"] as? Int == 1)
        #expect(payload["refreshProfile"] as? String == "maximumEnergySaving")
        #expect(payload["graphTimeRange"] as? String == "fiveMinutes")
        #expect(payload["detailListLimit"] as? String == "fifty")
        for key in ["showsCPUCard", "showsMemoryCard", "showsNetworkCard", "showsDiskCard",
                    "showsCPUTopApplications", "showsMemoryTopApplications",
                    "includesSystemProcesses", "automaticallyClosesPopover"] {
            let number = payload[key] as? NSNumber
            #expect(number != nil && CFGetTypeID(number!) == CFBooleanGetTypeID())
        }
    }

    @Test func allDetailLimitsRoundTripWithTheirDerivedCounts() {
        for (limit, count) in [(DetailListLimit.ten, 10), (.twenty, 20), (.fifty, 50)] {
            let storage = RecordingPreferencesStorage()
            let store = PreferencesStore(storage: storage)
            store.update { $0.detailListLimit = limit }
            let restored = PreferencesStore(storage: storage)
            #expect(restored.current.preferences.detailListLimit == limit)
            #expect(restored.current.preferences.detailListLimit.count == count)
            #expect(storage.writes.count == 1)
            #expect(storage.writes[0]["detailListLimit"] as? String == limit.rawValue)
        }
    }
}
