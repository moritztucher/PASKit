//
//  SettingsStoreTests.swift
//  PASKitCoreTests
//
//  @PASDefault write-through, default fallback, reset, and the optional
//  "nil = key absence" rule. Plus PASDraft's Codable round-trip. Each suite
//  instance gets its own UserDefaults suite so tests stay isolated and
//  parallel-safe.
//

import Foundation
import Testing
import PASKitCore

private enum TestUnit: String, UserDefaultsStorable { case kg, lb }

private final class TestStore: PASSettingsStore {
    @PASDefault("hapticsEnabled") var hapticsEnabled = true
    @PASDefault("launchCount") var launchCount = 0
    @PASDefault("unit") var unit: TestUnit = .kg
    @PASDefault("customRest") var customRest: Int?
}

@Suite("PASSettingsStore")
final class SettingsStoreTests {

    private let suiteName = "PASKitCoreTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() { defaults = UserDefaults(suiteName: suiteName)! }
    deinit { defaults.removePersistentDomain(forName: suiteName) }

    @Test("Unset settings read their declared defaults")
    func readsDeclaredDefaults() {
        let store = TestStore(defaults: defaults)
        #expect(store.hapticsEnabled == true)
        #expect(store.launchCount == 0)
        #expect(store.unit == .kg)
        #expect(store.customRest == nil)
    }

    @Test("Writes persist and a fresh store over the same suite sees them")
    func writeThroughPersists() {
        let store = TestStore(defaults: defaults)
        store.hapticsEnabled = false
        store.launchCount = 3
        store.unit = .lb

        #expect(store.hapticsEnabled == false)
        #expect(store.launchCount == 3)
        #expect(store.unit == .lb)
        #expect(defaults.string(forKey: "unit") == "lb")

        let reopened = TestStore(defaults: defaults)
        #expect(reopened.hapticsEnabled == false)
        #expect(reopened.unit == .lb)
    }

    @Test("removeValue restores the declared default")
    func removeValueResets() {
        let store = TestStore(defaults: defaults)
        store.hapticsEnabled = false
        store.removeValue(forKey: "hapticsEnabled")
        #expect(store.hapticsEnabled == true)
    }

    @Test("An optional setting stores nil as key absence")
    func optionalStoresNilAsAbsence() {
        let store = TestStore(defaults: defaults)
        store.customRest = 90
        #expect(store.customRest == 90)
        #expect(defaults.object(forKey: "customRest") != nil)

        store.customRest = nil
        #expect(store.customRest == nil)
        #expect(defaults.object(forKey: "customRest") == nil)
    }
}

private struct DraftFixture: Codable, Equatable {
    var step: Int
    var name: String
}

@Suite("PASDraft")
final class DraftTests {

    private let suiteName = "PASKitCoreTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() { defaults = UserDefaults(suiteName: suiteName)! }
    deinit { defaults.removePersistentDomain(forName: suiteName) }

    @Test("load returns nil when nothing is saved")
    func loadsNilWhenEmpty() {
        let draft = PASDraft<DraftFixture>(key: "onboarding.draft", defaults: defaults)
        #expect(draft.load() == nil)
    }

    @Test("save then load round-trips the value")
    func roundTrips() {
        let draft = PASDraft<DraftFixture>(key: "onboarding.draft", defaults: defaults)
        let value = DraftFixture(step: 2, name: "Mo")
        draft.save(value)
        #expect(draft.load() == value)
    }

    @Test("clear removes the saved draft")
    func clearRemovesDraft() {
        let draft = PASDraft<DraftFixture>(key: "onboarding.draft", defaults: defaults)
        draft.save(DraftFixture(step: 1, name: "x"))
        draft.clear()
        #expect(draft.load() == nil)
    }
}
