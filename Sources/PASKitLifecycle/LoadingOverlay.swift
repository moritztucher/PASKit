//
//  LoadingOverlay.swift
//  PASKitLifecycle
//
//  Loading-state view modifier. Two overloads — a system-default spinner+text
//  via `.loading(isPresented:message:)`, and a fully custom view via
//  `.loading(isPresented:content:)`. PASKit owns the overlay mechanism (dim
//  backdrop, interaction blocking, fade transition); apps own the visual
//  treatment via the `content:` variant when they need brand-styled loading
//  (e.g. spinning app-icon, determinate progress ring).
//

import SwiftUI

public extension View {
    /// Overlays a system-default loading indicator while `isPresented` is true.
    /// Renders a centred `ProgressView` (optionally with a caption) over a
    /// dimmed backdrop. Blocks underlying interaction.
    ///
    /// - Parameters:
    ///   - isPresented: Binding controlling overlay visibility.
    ///   - message: Optional caption shown beneath the spinner.
    @ViewBuilder
    func loading(
        isPresented: Binding<Bool>,
        message: String? = nil
    ) -> some View {
        loading(isPresented: isPresented) {
            DefaultLoadingView(message: message)
        }
    }

    /// Overlays the supplied content while `isPresented` is true, centred
    /// over a dimmed backdrop. Use this when the app has a branded loading
    /// view (custom animation, determinate progress, app icon, etc.). Blocks
    /// underlying interaction.
    ///
    /// - Parameters:
    ///   - isPresented: Binding controlling overlay visibility.
    ///   - content: The loading view to display.
    @ViewBuilder
    func loading<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(LoadingModifier(isPresented: isPresented, overlayContent: content))
    }
}

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

private struct LoadingModifier<OverlayContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let overlayContent: () -> OverlayContent

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        overlayContent()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}
