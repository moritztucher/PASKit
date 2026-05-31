//
//  AppInfoFooter.swift
//  PASKitLifecycle
//
//  Settings-screen footer: app icon + display name + version. Loads the app's
//  own primary icon at runtime via `CFBundleIcons`. iOS-only — relies on
//  `UIImage(named:)`.
//

#if canImport(UIKit)
import PASKitCore
import SwiftUI
import UIKit

public struct AppInfoFooter: View {

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            if let icon = Self.appIcon {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Text(AppInfo.displayName)
                .font(.headline)
            Text("Version \(AppInfo.versionWithBuild)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// The app's own primary icon, loaded from the bundle's `CFBundleIcons` at
    /// runtime. Returns `nil` if the bundle has no primary icon configured.
    static var appIcon: UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let lastFile = files.last
        else {
            return nil
        }
        return UIImage(named: lastFile)
    }
}
#endif
