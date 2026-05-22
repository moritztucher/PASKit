# PASKitUI

**Status:** Built — design tokens.
**Dependencies:** SwiftUI only (`UIKit`/`AppKit` bridged where needed).
**Platforms:** iOS 18+, macOS 15+.

## Purpose

The studio's shared design tokens — *not* a component library. Spacing, corner radius, and colour utilities every app reads. Migrated from the AnalyticsDashboard's `ADDesignKit` during the PASKit ↔ Dashboard reconciliation (see `docs/adr/`).

## Components

### Theme — ✅ built (`Theme.swift`)
`Theme.Spacing` (extraSmall…extraLarge), `Theme.CornerRadius`, `Theme.ScreenEdge` (per-platform edge padding). The Dashboard-specific chart / delta / status opacity tokens were left in the Dashboard's `ADDesignKit`.

### Color+LightDark — ✅ built (`Color+LightDark.swift`)
`Color(light:dark:)` — an appearance-resolving colour needing no asset catalog, bridged through `UIColor` / `NSColor`. Plus `Color.tileBackground`, a cross-platform secondary background.

## Notes

PASKitUI is deliberately tokens-only. Branded components — buttons, cards, typography styles — stay per-app; a shared component library homogenises apps that should look distinct. The Dashboard's Typography views and analytics components stayed in `ADDesignKit`.
