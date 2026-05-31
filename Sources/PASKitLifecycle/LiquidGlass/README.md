# LiquidGlass

iOS 26 Liquid Glass surface + button modifiers with a pre-26 fallback. Surfaces only — do not apply to nav bars or toolbars, which adopt Liquid Glass automatically on iOS 26 (style them via the cross-version `.toolbarBackground(_:for:)` family).

## API

- `PASGlass` — chainable: `.regular.tint(...)` colours the glass material, `.foreground(...)` colours the wrapped content.
- `PASGlassButtonVariant` — `.regular` / `.clear`.
- `View.paskitGlass(_:in:)` — surface modifier.
- `View.paskitGlassButtonStyle(_:)` — button style.

## Example

```swift
Card(...).paskitGlass(in: .rect(cornerRadius: 16))
Card(...).paskitGlass(.regular.tint(.orange), in: .rect(cornerRadius: 16))       // tint glass
Card(...).paskitGlass(.regular.foreground(.white), in: .capsule)                 // tint text
Card(...).paskitGlass(.regular.tint(.orange).foreground(.white), in: .capsule)   // both

Button("Continue") { ... }.paskitGlassButtonStyle()
Button("Dismiss") { ... }.paskitGlassButtonStyle(.clear)
```

iOS 26+ uses Apple's `glassEffect` / `.buttonStyle(.glass)`; earlier OSes fall back to `.regularMaterial` (+ optional tint overlay) / `.borderedProminent` (or `.bordered` for `.clear`).
