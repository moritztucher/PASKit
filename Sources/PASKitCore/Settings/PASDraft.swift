//
//  PASDraft.swift
//  PASKitCore
//
//  A UserDefaults-backed box for one in-progress Codable value — the
//  "resume after kill" pattern: snapshot a form/onboarding draft on every
//  meaningful change and on scene-phase change, restore at launch, clear
//  on completion. Persistence is best-effort: a value that fails to
//  encode/decode reads as no draft.
//

import Foundation

/// Persists one Codable draft value under a UserDefaults key.
///
/// ```swift
/// let draft = PASDraft<OnboardingDraft>(key: "onboarding.draft")
/// draft.save(snapshot)            // on change / scenePhase != .active
/// if let saved = draft.load() {…} // at launch — hydrate, then resume
/// draft.clear()                   // on completion
/// ```
public struct PASDraft<Value: Codable> {
    private let key: String
    private let defaults: UserDefaults

    public init(key: String, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }

    public func save(_ value: Value) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    public func load() -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
