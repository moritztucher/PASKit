//
//  PASHaptic.swift
//  PASKitCore
//
//  The system haptic primitives. Apps stay in primitives — `.success`,
//  `.medium`, `.selection` — and decide what they mean at the call site.
//  PASKit ships no semantic aliases (no `.habitCompleted`, no `.delete`):
//  vocabulary lives in the app.
//

import Foundation

/// The system haptic primitives. Apps stay in primitives — `.success`,
/// `.medium`, `.selection` — and decide what they mean at the call site.
/// PASKit ships no semantic aliases; vocabulary lives in the app.
public enum PASHaptic: Sendable {
    // UIImpactFeedbackGenerator styles.
    case light
    case medium
    case heavy
    case rigid
    case soft

    // UINotificationFeedbackGenerator types.
    case success
    case warning
    case error

    // UISelectionFeedbackGenerator.
    case selection
}
