# Styling

Brand-free styling *mechanisms* — the layer under per-app token systems. Token values and vocabularies (spacing/radius/color/motion enums) stay per-app; PASKit has no design layer.

## API

- `Animation.respectingReducedMotion(_:)` — `nil` when Reduce Motion is on (for call sites that read the environment).
- `View.pasAnimation(_:reducedMotion:value:)` — `animation(_:value:)` that honors Reduce Motion itself.
- `Color(light:dark:)` — appearance-resolving color without an asset catalog (UIColor/NSColor bridged, cross-platform).
- `Font.pasScaled(_:relativeTo:weight:design:)` — system font at a custom point size that tracks Dynamic Type via `UIFontMetrics` (fixed-size fallback on macOS).
- `PASFontRegistration.registerBundledFonts(named:bundle:)` — `CTFontManager` workaround for Xcode's `GENERATE_INFOPLIST_FILE` dropping `UIAppFonts`.
- `PASPressableButtonStyle` / `.buttonStyle(.pasPressable(…))` — press-scale + spring with an optional `PASHaptic` on the press-down edge.

## Example

```swift
withAnimation(.easeOut(duration: 0.25).respectingReducedMotion(reduceMotion)) { … }
Text("Streak").font(.pasScaled(28, relativeTo: .title, weight: .heavy))
Button("Start") { … }.buttonStyle(.pasPressable())
static let card = Color(light: .white, dark: Color(red: 0.11, green: 0.11, blue: 0.12))
```
