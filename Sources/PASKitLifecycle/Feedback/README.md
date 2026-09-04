# Feedback

In-app feedback prompt + form. PASKit owns the UI; the app owns the transport.

## API

- `View.presentAppFeedback(initialCondition:askLaterCondition:keys:copy:content:)` — two-stage prompt (mirrors `presentAppRating`); accepting presents the supplied view as a sheet.
- `PASAppFeedbackKeys` — `UserDefaults` keys behind the one-shot state. `.standard` for new apps; pass the keys you already shipped if you're migrating a local feedback prompt.
- `PASAppFeedbackCopy` — alert copy per stage. `.standard` matches PASKit's shipped strings verbatim; strings are shown as-is, so pass `String(localized:)` to localise.
- `FeedbackSheet` — custom form (category picker, name, email, message); adaptive two-pane on regular width / macOS, stacked on compact iOS with a full-width large Send. Customization: `heroSymbol: nil` hides the symbol, `initialName` / `initialEmail` prefill the fields, `showsCloseButton` adds an ⓧ (and drops Cancel on compact).
- `FeedbackPayload` — the typed payload (`category`, `name`, `email`, `message`) handed to `onSubmit`. Apps with a locked design language can build their own form over this payload and keep only the transport shared.
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
