//
//  PASGlassButtonVariant.swift
//  PASKitLifecycle
//
//  Variants for `pasGlassButtonStyle`. Maps to Apple's `.glass` button
//  style on iOS 26+; pre-26 falls back to `.borderedProminent` / `.bordered`.
//

import Foundation

/// Variants for `pasGlassButtonStyle`. Maps to Apple's `.glass` button
/// style on iOS 26+; pre-26 falls back to `.borderedProminent` / `.bordered`.
public enum PASGlassButtonVariant: Sendable {
    case regular
    case clear
}
