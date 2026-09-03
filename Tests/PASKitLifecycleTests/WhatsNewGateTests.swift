//
//  WhatsNewGateTests.swift
//  PASKitLifecycleTests
//
//  Covers WhatsNewGate's full matrix: fresh installs, the legacy-key migration,
//  catch-up across a multi-build gap, empty gaps, same-build and downgrade
//  no-ops, an unparseable build, and seed's idempotency. Each test gets its own
//  UserDefaults suite, so this file never touches `UserDefaults.standard`.
//

import Foundation
import Testing
@testable import PASKitLifecycle

@Suite("WhatsNewGate")
final class WhatsNewGateTests {

    private let suiteName: String
    private let defaults: UserDefaults

    private let buildKey = "test.whatsNew.lastSeenBuild"
    private let legacyKey = "test.lastWhatsNewVersion"

    init() {
        let name = "PASKitLifecycleTests.WhatsNewGate.\(UUID().uuidString)"
        suiteName = name
        defaults = UserDefaults(suiteName: name) ?? .standard
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Fixtures

    /// A gate that migrates — the shape an already-shipped app uses.
    @MainActor
    private func makeGate() -> WhatsNewGate {
        WhatsNewGate(defaults: defaults, lastSeenBuildKey: buildKey, legacyVersionKey: legacyKey)
    }

    private func card(_ title: String) -> WhatsNewCard {
        WhatsNewCard(symbol: "star", title: title, subtitle: "\(title) subtitle")
    }

    /// Newest first, like a real release list. Builds 5 and 3 carry a highlight;
    /// build 4 — the "empty gap" build — carries none.
    private var notes: [ReleaseNote] {
        [
            ReleaseNote(build: 5, version: "1.0.0", date: "2026-09-05", changes: ["+ five"], highlights: [card("Five")]),
            ReleaseNote(build: 4, version: "1.0.0", date: "2026-09-04", changes: ["+ four"], highlights: []),
            ReleaseNote(build: 3, version: "1.0.0", date: "2026-09-03", changes: ["+ three"], highlights: [card("Three")]),
        ]
    }

    // MARK: - Fresh Install

    @MainActor
    @Test("No record at all seeds the current build and presents nothing")
    func neitherKeyPresentSeedsAndReturnsNil() {
        let result = makeGate().highlightsForLaunch(currentBuild: 5, notes: notes)

        #expect(result == nil)
        #expect(defaults.integer(forKey: buildKey) == 5, "must self-heal by seeding the current build")
    }

    // MARK: - Legacy Migration

    @MainActor
    @Test("A legacy-keyed install catches up on every authored highlight")
    func legacyKeyTreatsLastSeenAsZero() {
        defaults.set("1.0.0", forKey: legacyKey)

        let result = makeGate().highlightsForLaunch(currentBuild: 5, notes: notes)

        #expect(result?.map(\.title) == ["Five", "Three"])
    }

    @MainActor
    @Test("Reading alone does not retire the legacy key")
    func legacyKeySurvivesTheRead() {
        defaults.set("1.0.0", forKey: legacyKey)

        _ = makeGate().highlightsForLaunch(currentBuild: 5, notes: notes)

        #expect(
            defaults.string(forKey: legacyKey) != nil,
            "only markPresented retires it — a kill before presentation must retry next launch"
        )
    }

    @MainActor
    @Test("markPresented writes the build and retires the legacy key")
    func markPresentedRetiresLegacyKey() {
        defaults.set("1.0.0", forKey: legacyKey)

        makeGate().markPresented(build: 5)

        #expect(defaults.integer(forKey: buildKey) == 5)
        #expect(defaults.string(forKey: legacyKey) == nil)
    }

    @MainActor
    @Test("Without a legacy key configured, a fresh install just seeds")
    func noLegacyKeyConfiguredSeeds() {
        defaults.set("1.0.0", forKey: legacyKey)
        let gate = WhatsNewGate(defaults: defaults, lastSeenBuildKey: buildKey)

        let result = gate.highlightsForLaunch(currentBuild: 5, notes: notes)

        #expect(result == nil, "a gate with no legacy key must ignore one that happens to be present")
        #expect(defaults.integer(forKey: buildKey) == 5)
    }

    // MARK: - Catch-Up

    @MainActor
    @Test("A multi-build gap collects every highlight, newest build first")
    func multiBuildGapOrdersNewestFirst() {
        defaults.set(2, forKey: buildKey)

        let result = makeGate().highlightsForLaunch(currentBuild: 5, notes: notes)

        #expect(result?.map(\.title) == ["Five", "Three"])
    }

    @MainActor
    @Test("A gap with no authored highlights returns empty, not nil")
    func emptyGapReturnsEmptyArray() {
        defaults.set(3, forKey: buildKey)

        let result = makeGate().highlightsForLaunch(currentBuild: 4, notes: notes)

        #expect(result != nil, "the build increased, so the caller must still mark presented")
        #expect(result?.isEmpty == true, "no highlights were authored in the gap")
    }

    @MainActor
    @Test("Marking an empty gap converges — the same build never re-fires")
    func markedEmptyGapConverges() {
        defaults.set(3, forKey: buildKey)
        let gate = makeGate()
        _ = gate.highlightsForLaunch(currentBuild: 4, notes: notes)
        gate.markPresented(build: 4)

        #expect(gate.highlightsForLaunch(currentBuild: 4, notes: notes) == nil)
    }

    // MARK: - No-Ops

    @MainActor
    @Test("The same build writes nothing")
    func sameBuildWritesNothing() {
        defaults.set(5, forKey: buildKey)

        let result = makeGate().highlightsForLaunch(currentBuild: 5, notes: notes)

        #expect(result == nil)
        #expect(defaults.integer(forKey: buildKey) == 5)
    }

    @MainActor
    @Test("A downgrade leaves the stored maximum untouched")
    func downgradeLeavesStoredMax() {
        defaults.set(99, forKey: buildKey)

        let result = makeGate().highlightsForLaunch(currentBuild: 3, notes: notes)

        #expect(result == nil)
        #expect(defaults.integer(forKey: buildKey) == 99, "branch-switching to an older build must never lower the max")
    }

    @MainActor
    @Test("An unparseable build writes nothing at all")
    func nilBuildWritesNothing() {
        let result = makeGate().highlightsForLaunch(currentBuild: nil, notes: notes)

        #expect(result == nil)
        #expect(defaults.object(forKey: buildKey) == nil)
        #expect(defaults.string(forKey: legacyKey) == nil)
    }

    // MARK: - Seed

    @MainActor
    @Test("seed is idempotent and never clobbers an existing record")
    func seedIsIdempotent() {
        let gate = makeGate()
        gate.seed(currentBuild: 5)
        gate.seed(currentBuild: 99)

        #expect(defaults.integer(forKey: buildKey) == 5)
    }

    @MainActor
    @Test("Seeding does not suppress a genuinely higher build later")
    func seedThenHigherBuildStillFires() {
        let gate = makeGate()
        gate.seed(currentBuild: 3)

        #expect(gate.highlightsForLaunch(currentBuild: 5, notes: notes)?.map(\.title) == ["Five"])
    }

    @MainActor
    @Test("Seeding a nil build does nothing")
    func seedNilBuildDoesNothing() {
        makeGate().seed(currentBuild: nil)

        #expect(defaults.object(forKey: buildKey) == nil)
    }
}
