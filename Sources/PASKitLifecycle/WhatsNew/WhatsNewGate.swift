//
//  WhatsNewGate.swift
//  PASKitLifecycle
//
//  Owns the What's New sheet's cadence: whether the build number has advanced
//  since the last presentation, and what to show for the builds skipped in
//  between. Pure `UserDefaults` + arithmetic — no SwiftUI, no app vocabulary.
//

import Foundation
import PASKitCore

/// Decides whether the What's New sheet is due, and collects the highlights for
/// every build the user skipped.
///
/// Gated on `CFBundleVersion` (the build number), not the marketing version:
/// build-number gating is the only cadence that shows TestFlight testers anything.
/// The App-Store-era policy of "don't interrupt for a patch" lives in authoring
/// discipline instead — a build whose ``ReleaseNote/highlights`` are empty is
/// absorbed silently (see ``highlightsForLaunch(currentBuild:notes:)``), so no
/// gate change is ever needed.
///
/// **Persistence: one key, owned by this type alone.** The key is an init
/// parameter, not a constant, because it is installed-user state: an app that has
/// already shipped a What's New sheet must pass the key it shipped with, or every
/// user sees the sheet replay. `legacyVersionKey` covers apps migrating from an
/// older `CFBundleShortVersionString`-gated sheet.
///
/// Not `@Observable` — hold it as a plain `private let` on the view that presents
/// the sheet. An injectable `UserDefaults` is what makes it testable in isolation
/// from `UserDefaults.standard`.
@MainActor
public struct WhatsNewGate {

    // MARK: - Persistence Keys

    /// The key used when a caller supplies none. New apps should take this default
    /// and never change it afterwards.
    public static let defaultLastSeenBuildKey = "paskit.whatsNew.lastSeenBuild"

    // MARK: - Dependencies

    private let defaults: UserDefaults
    private let lastSeenBuildKey: String
    private let legacyVersionKey: String?

    /// - Parameters:
    ///   - defaults: Storage for the last-seen build. Inject a suite to test.
    ///   - lastSeenBuildKey: The `Int` key holding the highest build presented so
    ///     far. Must match what the app already shipped, if anything.
    ///   - legacyVersionKey: An older `String` key from a pre-existing
    ///     version-gated sheet. When present on an install that has no
    ///     `lastSeenBuildKey` record, the install is treated as "has seen nothing"
    ///     and catches up on every authored highlight. Retired by
    ///     ``markPresented(build:)``, never here, so a kill before presentation
    ///     retries the migration next launch instead of silently losing it.
    public init(
        defaults: UserDefaults = .standard,
        lastSeenBuildKey: String = WhatsNewGate.defaultLastSeenBuildKey,
        legacyVersionKey: String? = nil
    ) {
        self.defaults = defaults
        self.lastSeenBuildKey = lastSeenBuildKey
        self.legacyVersionKey = legacyVersionKey
    }

    // MARK: - Launch Check

    /// The cards to present for the `(lastSeen, currentBuild]` interval, newest
    /// build first, or `nil` to do nothing.
    ///
    /// Return contract — all three cases are distinct and the caller must honour
    /// them:
    ///
    /// - `nil`: mark nothing, present nothing.
    /// - `[]`: the build increased but no highlights were authored in the gap.
    ///   Call ``markPresented(build:)`` and show nothing — state converges instead
    ///   of re-checking on every launch forever.
    /// - non-empty: call ``markPresented(build:)`` and show the sheet.
    ///
    /// Highlights are collected across the whole interval, newest build first, so
    /// a user who skips builds gets the catch-up. A `nil` `currentBuild` (an
    /// unparseable `CFBundleVersion`) always returns `nil` and touches no storage.
    ///
    /// - Parameter notes: The app's release list, newest build first.
    public func highlightsForLaunch(currentBuild: Int?, notes: [ReleaseNote]) -> [WhatsNewCard]? {
        guard let currentBuild else { return nil }

        guard defaults.object(forKey: lastSeenBuildKey) != nil else {
            if let legacyVersionKey, defaults.string(forKey: legacyVersionKey) != nil {
                // Existing install from before this gate shipped — treat as "never
                // seen anything" so it catches up on every authored highlight,
                // including this build's.
                return collectHighlights(after: 0, through: currentBuild, notes: notes)
            }
            // No record at all: self-heal by seeding silently and presenting
            // nothing. Matches what a caller's onboarding-incomplete branch does by
            // calling `seed(currentBuild:)` directly, so this path only matters for
            // a caller that skips that branch.
            seed(currentBuild: currentBuild)
            return nil
        }

        let lastSeen = defaults.integer(forKey: lastSeenBuildKey)
        guard currentBuild > lastSeen else {
            // Same build, or a downgrade (branch switch, older TestFlight build):
            // write nothing, so the stored value keeps the max. Re-upgrading past
            // that max still fires; downgrading and staying there never does.
            return nil
        }
        return collectHighlights(after: lastSeen, through: currentBuild, notes: notes)
    }

    /// Marks `build` as seen and retires the legacy key. Call only once the sheet
    /// is actually presented — or once the caller has decided there is nothing to
    /// present — never on a `nil` result.
    public func markPresented(build: Int) {
        defaults.set(build, forKey: lastSeenBuildKey)
        if let legacyVersionKey {
            defaults.removeObject(forKey: legacyVersionKey)
        }
    }

    /// Idempotent seed for an install with no record yet — never clobbers an
    /// existing one.
    ///
    /// Call while onboarding is incomplete, so a fresh install's build is recorded
    /// during onboarding and finishing it in-session can never trigger the sheet.
    public func seed(currentBuild: Int?) {
        guard let currentBuild, defaults.object(forKey: lastSeenBuildKey) == nil else { return }
        defaults.set(currentBuild, forKey: lastSeenBuildKey)
    }

    // MARK: - Current Build

    /// `Int(AppInfo.build)` — the running app's `CFBundleVersion`. `nil` when
    /// unparseable or absent, which makes the whole gate no-op.
    public nonisolated static var currentBuild: Int? {
        Int(AppInfo.build)
    }

    // MARK: - Collection

    /// Every highlight from builds strictly greater than `lastSeen` and at most
    /// `currentBuild`, newest build first — `notes` is already newest-first, so
    /// this is a filter plus a flatten, not a sort.
    private func collectHighlights(
        after lastSeen: Int,
        through currentBuild: Int,
        notes: [ReleaseNote]
    ) -> [WhatsNewCard] {
        notes
            .filter { $0.build > lastSeen && $0.build <= currentBuild }
            .flatMap(\.highlights)
    }
}
