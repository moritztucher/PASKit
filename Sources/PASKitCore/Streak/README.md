# Streak

Pure streak / day-rollover engine — value-in/value-out, so persistence stays app-side. Milestone tables (7/21/66, icons, copy) stay app vocabulary.

## API

- `PASStreakState` — `Codable` value (`streak`, raise-only `longestStreak`, `lastActiveDay`, `freezeBalance`, `lastFreezeGrantAt`).
- `PASStreakEngine.rolledOver(_:today:calendar:config:)` — day rollover in the proven order: freeze-consume → streak roll → free grant. Returns `PASStreakRolloverOutcome` (`freezeConsumed` / `freezeGranted` / `streakDidReset`).
- `PASStreakEngine.recordingActivity(_:at:calendar:config:)` — first-activity-today increment + `lastActiveDay` stamp; same-day repeats are no-ops.
- `PASStreakConfig` — `freezeCap` / `freeFreezeInterval`, both default-off.

## Example

```swift
let config = PASStreakConfig(freezeCap: 2, freeFreezeInterval: 30 * 24 * 3600)  // omit → freezes off

let (rolled, outcome) = PASStreakEngine.rolledOver(state, config: config)
if outcome.freezeConsumed { showStreakSavedNotice() }

let (next, firstToday) = PASStreakEngine.recordingActivity(rolled, config: config)
if firstToday { checkMilestones(next.streak) }
```

Run `rolledOver` at launch **and** on every `scenePhase == .active` — iOS keeps apps resident for days, so a launch-only rollover leaves streaks stale.
