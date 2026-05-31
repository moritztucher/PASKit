//
//  DefaultLoadingView.swift
//  PASKitLifecycle
//
//  PASKit's default loading view — exposed so apps that want the default
//  treatment with extra decoration can compose it directly. For the bound
//  overlay modifier see `View+Loading.swift`.
//

import SwiftUI

/// PASKit's default loading view — a large `ProgressView`, optional caption,
/// rounded `.regularMaterial` card. Exposed so apps that want the default
/// treatment with extra decoration can compose it directly.
public struct DefaultLoadingView: View {

    public let message: String?

    public init(message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            if let message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
    }
}
