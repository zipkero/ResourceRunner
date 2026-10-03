import AppKit
import SwiftUI
import Testing
@testable import ResourceRunner

@MainActor
struct DashboardPreferencesVisibilityTests {
    private let icons = StubApplicationIconProvider(images: [:])

    private func preferences(cards: Int, top: Int) -> AppPreferences {
        var value = AppPreferences.defaults
        value.showsCPUCard = cards & 1 != 0
        value.showsMemoryCard = cards & 2 != 0
        value.showsNetworkCard = cards & 4 != 0
        value.showsDiskCard = cards & 8 != 0
        value.showsCPUTopApplications = top & 1 != 0
        value.showsMemoryTopApplications = top & 2 != 0
        return value
    }

    private func renderHeight(cards: Int, top: Int) throws -> CGFloat {
        let snapshot = PreferencesSnapshot(preferences: preferences(cards: cards, top: top), revision: 0)
        let view = DashboardView(store: DashboardPresentationStore(preferencesSnapshot: snapshot),
            iconProvider: icons).frame(width: 280)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try #require(renderer.nsImage).size.height
    }

    @Test func allSixtyFourCardAndTopCombinationsUseOnlyVisibleNaturalHeights() throws {
        var checked = 0
        for top in 0..<4 {
            let empty = try renderHeight(cards: 0, top: top)
            var single: [CGFloat] = []
            for index in 0..<4 {
                single.append(try renderHeight(cards: 1 << index, top: top))
            }
            for cards in 0..<16 {
                let actual = try renderHeight(cards: cards, top: top)
                let count = cards.nonzeroBitCount
                if count == 0 {
                    #expect(actual == empty)
                } else {
                    let bodyPadding = 2 * DashboardStyle.Summary.bodyPadding
                    let expected = single.enumerated().reduce(bodyPadding + CGFloat(max(0, count - 1))
                        * DashboardView.cardSpacing) {
                        result, entry in
                        result + (cards & (1 << entry.offset) != 0 ? entry.element - bodyPadding : 0)
                    }
                    #expect(abs(actual - expected) <= 2,
                        "cards=\(cards), top=\(top): \(actual), expected \(expected)")
                }
                checked += 1
            }
            #expect(single.allSatisfy { $0 > empty })
        }
        #expect(checked == 64)
        #expect(try renderHeight(cards: 1, top: 0) < renderHeight(cards: 1, top: 1))
        #expect(try renderHeight(cards: 2, top: 0) < renderHeight(cards: 2, top: 2))
        #expect(try renderHeight(cards: 4, top: 0) == renderHeight(cards: 4, top: 3))
        #expect(try renderHeight(cards: 8, top: 0) == renderHeight(cards: 8, top: 3))
    }

    @Test func hidingSelectedCardAdvancesGenerationAndRejectsHiddenEntryAndLateClose() {
        let store = DashboardPresentationStore()
        store.selectCard(.cpu)
        let oldGeneration = store.selectionGeneration
        var next = AppPreferences.defaults
        next.showsCPUCard = false
        next.showsCPUTopApplications = false
        store.applyPreferences(PreferencesSnapshot(preferences: next, revision: 1))
        #expect(store.selection == .none)
        #expect(store.selectionGeneration > oldGeneration)
        let hiddenGeneration = store.selectionGeneration
        store.selectCard(.cpu)
        #expect(store.selection == .none)
        #expect(store.selectionGeneration == hiddenGeneration)
        store.selectCard(.memory)
        #expect(store.selection == .memory)
        store.dismissDetail(for: .cpu, generation: oldGeneration)
        #expect(store.selection == .memory)
        next.showsCPUCard = true
        store.applyPreferences(PreferencesSnapshot(preferences: next, revision: 2))
        #expect(store.selection == .memory)
        #expect(!store.preferencesSnapshot.preferences.showsCPUTopApplications)
        store.selectCard(.cpu)
        #expect(store.selection == .cpu)
        store.dismissDetail(for: .cpu, generation: oldGeneration)
        #expect(store.selection == .cpu)
    }

    @Test func allOffSettingsActionUsesInjectedCallback() {
        var opens = 0
        let view = DashboardView(store: DashboardPresentationStore(), iconProvider: icons,
            onOpenSettings: { opens += 1 })
        view.onOpenSettings()
        #expect(opens == 1)
    }
}
