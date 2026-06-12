//
//  PASActivitySheet.swift
//  PASKitSharing
//
//  UIActivityViewController for SwiftUI: a representable for
//  `.sheet(item:)` presentation, plus an imperative `present` doing the
//  top-most-view-controller walk for non-sheet contexts.
//

#if canImport(UIKit)
import SwiftUI
import UIKit

/// The system share sheet.
///
/// Declarative (preferred — pairs with `PASShareItems`):
/// ```swift
/// .sheet(item: $shareItems) { PASActivitySheet(items: $0.items) }
/// ```
///
/// Imperative, from contexts that already present a sheet of their own:
/// ```swift
/// PASActivitySheet.present(items: [image]) { dismiss() }
/// ```
public struct PASActivitySheet: UIViewControllerRepresentable {
    private let items: [Any]
    private let onComplete: (() -> Void)?

    /// - Parameters:
    ///   - items: Activity items — images, strings, URLs.
    ///   - onComplete: Runs once the share sheet finishes (shared or
    ///     cancelled).
    public init(items: [Any], onComplete: (() -> Void)? = nil) {
        self.items = items
        self.onComplete = onComplete
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        Self.makeController(items: items, onComplete: onComplete)
    }

    public func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}

    private static func makeController(
        items: [Any],
        onComplete: (() -> Void)?
    ) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let onComplete {
            controller.completionWithItemsHandler = { _, _, _, _ in onComplete() }
        }
        return controller
    }
}

@available(iOSApplicationExtension, unavailable)
public extension PASActivitySheet {
    /// Presents the share sheet over the top-most presented view
    /// controller of the active scene. On iPad the popover is anchored to
    /// the presenter's center.
    @MainActor
    static func present(items: [Any], onComplete: (() -> Void)? = nil) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let root = scene?.keyWindow?.rootViewController
            ?? scene?.windows.first?.rootViewController else { return }

        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        let controller = makeController(items: items, onComplete: onComplete)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        presenter.present(controller, animated: true)
    }
}
#endif
