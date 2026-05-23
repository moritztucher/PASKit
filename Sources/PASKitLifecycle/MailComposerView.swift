//
//  MailComposerView.swift
//  PASKitLifecycle
//
//  Thin SwiftUI wrapper over `MFMailComposeViewController` for in-app feedback
//  email. iOS-only — `MessageUI` is not available on macOS.
//

#if canImport(MessageUI) && canImport(UIKit)
import MessageUI
import SwiftUI
import UIKit

public struct MailComposerView: UIViewControllerRepresentable {

    public let recipients: [String]
    public let subject: String
    public let body: String
    public let onDismiss: ((Swift.Result<MFMailComposeResult, Error>) -> Void)?

    public init(
        recipients: [String],
        subject: String = "",
        body: String = "",
        onDismiss: ((Swift.Result<MFMailComposeResult, Error>) -> Void)? = nil
    ) {
        self.recipients = recipients
        self.subject = subject
        self.body = body
        self.onDismiss = onDismiss
    }

    /// Whether the device has a configured mail account and can present the
    /// composer. Check before presenting — on a device with no mail account
    /// the composer cannot be shown.
    public static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    public func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }

    public func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    public final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: ((Swift.Result<MFMailComposeResult, Error>) -> Void)?

        init(onDismiss: ((Swift.Result<MFMailComposeResult, Error>) -> Void)?) {
            self.onDismiss = onDismiss
        }

        public func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
            if let error {
                onDismiss?(.failure(error))
            } else {
                onDismiss?(.success(result))
            }
        }
    }
}
#endif
