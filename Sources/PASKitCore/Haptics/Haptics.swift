//
//  Haptics.swift
//  PASKitCore
//
//  Thin wrapper over UIKit's three feedback generators. iOS-only at the
//  hardware level — gated with `#if canImport(UIKit)` so macOS compiles to
//  a no-op. PASKit owns the generic mechanism; the caller supplies the
//  enabled-gate (e.g. reading a user preference) at the call site.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// One-call haptic playback. Generators are created and fired on demand —
/// no preheated singletons. If profiling later shows the create cost
/// matters we can introduce pre-prepared generators; v1 stays simple.
@MainActor public enum Haptics {

    /// Plays the haptic immediately. iOS only — no-op on macOS or when
    /// `isEnabled` is `false`.
    ///
    /// - Parameters:
    ///   - haptic: Which primitive to play.
    ///   - isEnabled: Call-site gate. Pass `false` (typically from a user
    ///     preference) to suppress. Default `true`.
    public static func play(_ haptic: PASHaptic, isEnabled: Bool = true) {
        guard isEnabled else { return }
        #if canImport(UIKit)
        switch haptic {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
        #endif
    }
}
