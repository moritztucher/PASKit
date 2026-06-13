# Time

Calendar math for day-gating / streaks / rollovers, plus the two duration shapes Foundation doesn't produce cleanly. Date-to-string formatting stays on `formatted(.dateTime…)` / `RelativeDateTimeFormatter` — deliberately not wrapped.

## API

- `Date` extension (every method takes `calendar:`, default `.current`): `pasStartOfDay` / `pasEndOfDay`, `pasIsSameDay(as:)`, `pasDaysSince(_:)` (both ends startOfDay-normalized — kills the cross-midnight off-by-one), `pasAdding(days:)`, `pasStartOfWeek()` (honors `firstWeekday`), `pasIsSameWeek(as:)` (granularity compare for weekly resets), `pasHoursUntilMidnight()`.
- `PASDurationFormat` — `compact(seconds:)` (`"42s"` / `"4m 12s"` / `"1h 03m"`) and `clock(seconds:)` (`"4:12"` / `"1:04:12"`); `Int` + `TimeInterval` overloads, negatives clamp.

## Example

```swift
date.pasIsSameDay(as: lastOpen)
today.pasDaysSince(challengeStart)        // whole days, startOfDay-normalized
date.pasStartOfWeek()                     // honors the calendar's firstWeekday
PASDurationFormat.compact(seconds: 252)   // "4m 12s"
PASDurationFormat.clock(seconds: 3852)    // "1:04:12"
```

Inject a fixed `calendar:` in tests for deterministic results across timezones and DST.
