//
//  AppUpdateView.swift
//  PASKitLifecycle
//
//  Presented when `VersionCheckManager` returns an available update. Uses
//  SwiftUI defaults — the app supplies its accent via `.tint(...)`.
//

import SwiftUI

public struct AppUpdateView: View {

    @Environment(\.openURL) private var openURL

    public let update: VersionCheckManager.Result
    public let forceUpdate: Bool

    /// - Parameters:
    ///   - update: The available-update record from `VersionCheckManager`.
    ///   - forceUpdate: When `true`, the sheet is non-dismissible. Defaults to
    ///     `false` — reserve the hard gate for security releases.
    public init(update: VersionCheckManager.Result, forceUpdate: Bool = false) {
        self.update = update
        self.forceUpdate = forceUpdate
    }

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.up.app.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("App Update Available")
                    .font(.title2.bold())
                Text("Version **\(update.currentVersion)** → **\(update.availableVersion)**")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let url = URL(string: update.appURL) {
                Button("Update App") { openURL(url) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .interactiveDismissDisabled(forceUpdate)
    }
}
