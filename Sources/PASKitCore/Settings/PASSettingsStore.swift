//
//  PASSettingsStore.swift
//  PASKitCore
//
//  Base class for an app's UserDefaults-backed settings store. Subclass it
//  and declare one `@PASDefault` property per setting — the base carries
//  `@Observable` and a single tracked anchor, so SwiftUI views re-evaluate
//  whenever any setting in the store changes (per-store granularity).
//

import Foundation
import Observation

/// Observable write-through settings store.
///
/// ```swift
/// final class SettingsStore: PASSettingsStore {
///     @PASDefault("settings.hapticsEnabled") var hapticsEnabled = true
///     @PASDefault("settings.customRest")     var customRest: Int?
/// }
/// ```
///
/// Inject a suite for App Group sharing or tests:
/// `SettingsStore(defaults: UserDefaults(suiteName: "group.…")!)`.
@Observable
open class PASSettingsStore {
    /// Backing store. `.standard` by default; inject a suite for App Groups
    /// (widget sharing) or an isolated suite in tests.
    @ObservationIgnored public let defaults: UserDefaults

    /// Observation anchor — every `@PASDefault` read touches it, every write
    /// bumps it. One anchor per store keeps the design macro-free at the cost
    /// of per-store (not per-key) invalidation.
    private var changeCount = 0

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Registers the current observation access. Called by `@PASDefault` on
    /// every read — not intended for app code.
    public func registerRead() {
        _ = changeCount
    }

    /// Signals that a setting changed. Called by `@PASDefault` on every
    /// write — not intended for app code.
    public func noteChange() {
        changeCount += 1
    }

    /// Removes a stored value so the setting reads as its declared default
    /// again ("reset to default").
    public func removeValue(forKey key: String) {
        defaults.removeObject(forKey: key)
        noteChange()
    }
}
