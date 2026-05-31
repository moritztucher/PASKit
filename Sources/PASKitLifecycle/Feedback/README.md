# Feedback

In-app feedback prompt + form. PASKit owns the UI; the app owns the transport.

## API

- `View.presentAppFeedback(initialCondition:askLaterCondition:content:)` — two-stage prompt (mirrors `presentAppRating`); accepting presents the supplied view as a sheet.
- `FeedbackSheet` — custom form (category picker, name, email, message); adaptive two-pane on regular width / macOS, stacked on compact iOS.
- `FeedbackPayload` — the typed payload (`category`, `name`, `email`, `message`) handed to `onSubmit`.
- `MailComposerView` (iOS-only) — thin wrapper over `MFMailComposeViewController` for the simple "open a prefilled mail draft" case.

## Example

```swift
// Prompt-driven:
ContentView().presentAppFeedback(
    initialCondition: { await sessions.count >= 5 },
    askLaterCondition: { await sessions.count >= 12 }
) {
    FeedbackSheet { payload in
        try await sendFeedback(payload)   // email, HTTP, webhook — your call
    }
}

// Or from a Settings row:
.sheet(isPresented: $showFeedback) {
    FeedbackSheet { payload in try await sendFeedback(payload) }
}
```
