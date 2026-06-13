//
//  UserDefaultsStorable.swift
//  PASKitCore
//
//  Types that can round-trip through UserDefaults for `@PASDefault`.
//  Primitives, Date/Data/URL, Optional, and RawRepresentable enums are
//  covered; apps conform their setting enums with an empty extension.
//

import Foundation

/// A value that can be read from and written to `UserDefaults`.
///
/// `readValue` returns `nil` when the key is absent (or holds an
/// incompatible type) so the caller can fall back to a declared default.
public protocol UserDefaultsStorable {
    static func readValue(from defaults: UserDefaults, forKey key: String) -> Self?
    func writeValue(to defaults: UserDefaults, forKey key: String)
}

// MARK: - Primitives

extension Bool: UserDefaultsStorable {
    public static func readValue(from defaults: UserDefaults, forKey key: String) -> Bool? {
        defaults.object(forKey: key) as? Bool
    }

    public func writeValue(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension Int: UserDefaultsStorable {
    public static func readValue(from defaults: UserDefaults, forKey key: String) -> Int? {
        defaults.object(forKey: key) as? Int
    }

    public func writeValue(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension Double: UserDefaultsStorable {
    public static func readValue(from defaults: UserDefaults, forKey key: String) -> Double? {
        defaults.object(forKey: key) as? Double
    }

    public func writeValue(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension String: UserDefaultsStorable {
    public static func readValue(from defaults: UserDefaults, forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    public func writeValue(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension Date: UserDefaultsStorable {
    public static func readValue(from defaults: UserDefaults, forKey key: String) -> Date? {
        defaults.object(forKey: key) as? Date
    }

    public func writeValue(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension Data: UserDefaultsStorable {
    public static func readValue(from defaults: UserDefaults, forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func writeValue(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension URL: UserDefaultsStorable {
    public static func readValue(from defaults: UserDefaults, forKey key: String) -> URL? {
        defaults.url(forKey: key)
    }

    public func writeValue(to defaults: UserDefaults, forKey key: String) {
        // `set(_: URL?, forKey:)` archives the URL — pairs with `url(forKey:)`.
        defaults.set(self, forKey: key)
    }
}

// MARK: - Optional

/// Writing `nil` removes the key; an absent key reads as `nil` (the outer
/// optional), which makes the wrapper fall back to the declared default.
/// Declare optional settings with a `nil` default — a non-nil default would
/// be indistinguishable from "explicitly set to nil".
extension Optional: UserDefaultsStorable where Wrapped: UserDefaultsStorable {
    public static func readValue(from defaults: UserDefaults, forKey key: String) -> Wrapped?? {
        guard let value = Wrapped.readValue(from: defaults, forKey: key) else { return nil }
        return .some(value)
    }

    public func writeValue(to defaults: UserDefaults, forKey key: String) {
        switch self {
        case .some(let value): value.writeValue(to: defaults, forKey: key)
        case .none: defaults.removeObject(forKey: key)
        }
    }
}

// MARK: - RawRepresentable

/// Any `RawRepresentable` whose raw value is storable conforms with an empty
/// extension: `extension WeightUnit: UserDefaultsStorable {}`.
public extension UserDefaultsStorable where Self: RawRepresentable, RawValue: UserDefaultsStorable {
    static func readValue(from defaults: UserDefaults, forKey key: String) -> Self? {
        guard let raw = RawValue.readValue(from: defaults, forKey: key) else { return nil }
        return Self(rawValue: raw)
    }

    func writeValue(to defaults: UserDefaults, forKey key: String) {
        rawValue.writeValue(to: defaults, forKey: key)
    }
}
