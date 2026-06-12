//
//  PASDefault.swift
//  PASKitCore
//
//  One-line UserDefaults-backed property for `PASSettingsStore` subclasses.
//  Reads fall back to the declared default (kept in the wrapper, not the
//  registration domain); writes go straight through to the store's defaults.
//

import Foundation

/// A write-through UserDefaults property on a `PASSettingsStore` subclass.
///
/// ```swift
/// @PASDefault("settings.hapticsEnabled") var hapticsEnabled = true
/// @PASDefault("settings.weightUnit")     var weightUnit: WeightUnit =
///     Locale.current.measurementSystem == .metric ? .kg : .lb
/// @PASDefault("settings.customRest")     var customRest: Int?   // nil = key absent
/// ```
@propertyWrapper
public struct PASDefault<Value: UserDefaultsStorable> {
    private let key: String
    private let defaultValue: Value

    public init(wrappedValue: Value, _ key: String) {
        self.defaultValue = wrappedValue
        self.key = key
    }

    @available(*, unavailable, message: "@PASDefault only works on properties of a PASSettingsStore subclass")
    public var wrappedValue: Value {
        get { fatalError("@PASDefault requires an enclosing PASSettingsStore") }
        // swiftlint:disable:next unused_setter_value
        set { fatalError("@PASDefault requires an enclosing PASSettingsStore") }
    }

    public static subscript<Instance: PASSettingsStore>(
        _enclosingInstance instance: Instance,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<Instance, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<Instance, Self>
    ) -> Value {
        get {
            let wrapper = instance[keyPath: storageKeyPath]
            instance.registerRead()
            return Value.readValue(from: instance.defaults, forKey: wrapper.key) ?? wrapper.defaultValue
        }
        set {
            let wrapper = instance[keyPath: storageKeyPath]
            newValue.writeValue(to: instance.defaults, forKey: wrapper.key)
            instance.noteChange()
        }
    }
}

public extension PASDefault {
    /// Allows `@PASDefault("key") var value: Int?` without an explicit
    /// `= nil` — the declared default for an optional setting is `nil`.
    init<Wrapped>(_ key: String) where Value == Wrapped? {
        self.init(wrappedValue: nil, key)
    }
}
