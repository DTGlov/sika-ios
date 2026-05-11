# /streaks page — 2026-05-12

Implementer: Claude Code
Source-of-truth audit: `/audits/STREAKS_PAGE_2026_05_12.md`
Predecessor: `/audits/PHASE_9_FIXUP_BADGES_2026_05_12.md` (PR 1 —
Phase 9 model fix-ups + /badges + GamificationCatalog)

Second of five PRs shipping /health Explore destinations. Surfaces
the streaks data already loaded by Phase 9 into a dedicated page:
Logging streak, Saving streak, Streak Freezes. Read-only.

## What Shipped

### Feature files (Features/Streaks/)
- `StreakLabels.swift` (new) — pure helpers ported from web:
  - `lastLogged(loggingLastDate:)` → "Never" / "Today" / "Yesterday"
    / "{N} days ago"
  - `lastSaved(savingsLastWeek:)` → "Never" / "This week" / "Last
    week" / "{N} weeks ago"
  - `hasLoggedToday(loggingLastDate:)` / `hasSavedThisWeek(savingsLastWeek:)`
  - `todayUTC()` / `mondayUTC()` — UTC `YYYY-MM-DD` strings.
    `mondayUTC` uses `Calendar(identifier: .iso8601)` so Monday is
    day-1 (matches web's ISO Monday computation).
  - Shared `en_US_POSIX` + UTC formatter so the format string
    doesn't drift on non-Gregorian device calendars.

- `Components/LoggingStreakCard.swift` (new) — Logging stat card.
  Yellow accent (#FBBF24, `flame.fill`). 40pt bold count + unit
  ("day"/"days" with singular/plural). Detail rows: Longest, Last
  logged, Next milestone (hidden when maxed). "Today" renders in
  gold (#D4A017).

- `Components/SavingStreakCard.swift` (new) — Saving stat card.
  Gold accent (#D4A017, `dollarsign.circle.fill`). 40pt bold count
  + unit ("week"/"weeks"). Detail rows: Longest, Last contributed,
  Next milestone (hidden when maxed). "This week" renders in gold.

- `Components/FreezesCard.swift` (new) — Freezes card. Blue accent
  (#60A5FA, `snowflake`). "Streak Freezes" title + counter line +
  2 visual slots (rounded squares; filled = banked) + helper text:
  "Freezes protect your streak when life gets in the way. Earn 1
  every 10 days of logging. Max 2 banked." MAX_FREEZES = 2 hardcoded
  to match web.

- `StreaksView.swift` (new) — orchestrator. `ScrollView` + 16pt
  VStack of the three cards. Sticky inline nav title "Your Streaks".
  Entry animation: `.easeOut(0.3)` with stagger delays 0 / 0.08 /
  0.16s — ~460ms total cascade. Each card opacity 0→1 + offset
  16→0 on visibility flip.

### Wiring
- `Sika/Features/Health/HealthDetailView.swift` —
  `.navigationDestination(isPresented: $showStreaks)` now pushes
  `StreaksView()` directly.
- `Sika/Features/Health/Placeholders/StreakDetailPlaceholderView.swift`
  — **deleted** (Option B, matches the Badges chore precedent).

### Data source
Reads exclusively from `appState.healthSnapshot?.streaks`. No
direct Supabase fetch, no mutation hooks, no subscriptions. Snapshot
refresh happens on the existing navigate-away-and-back path (Home
re-loads on `loadProfile` / `refreshHomeData`).

## Locked architectural decisions

- **Standardized sticky header** across all four health-adjacent
  pages (/health, /badges, /streaks, /momentum). Diverges from
  web's /streaks which uses a non-sticky bordered ArrowLeft.
- **No mutationCount subscription.** Page reads the snapshot
  loaded at session start; mutations elsewhere don't push updates.
- **No useStreakHealth on mount.** Web has it commented out;
  not ported.
- **No skeleton state.** If `streaks == nil`, all three cards
  render with zeros / "Never" — no shimmer, no "loading…" text.
- **Three full-width cards on iOS** — no 50/50 split on tablet.
  Consistency with the rest of the navigation stack > responsive
  layout.
- **Stagger timings exact**: 0 / 0.08 / 0.16s delays. `.easeOut`
  duration 0.3s for each. No springs, no count-ups on the big
  numbers, no flame pulse.
- **Singular/plural** matches web (`day` vs `days`, `week` vs
  `weeks`) keyed on `current == 1`.
- **Next-milestone row conditional** — hidden when the user is
  past the last milestone (`nextLogging(after:)` / `nextSavings(after:)`
  return nil).
- **No mutation hooks.** Pure read + nav. Matches Settings /
  /badges / /momentum.

## Adaptations from the prompt's blueprint

1. **`@Environment(AppState.self)`** instead of `@EnvironmentObject`
   — iOS pattern. AppState is `@Observable`.
2. **Cards moved to `.frame(maxWidth: .infinity, alignment: .leading)`**
   in addition to internal `.padding(20)` so they fill the parent
   VStack's width. The audit's "all three cards full-width" requires
   this for the inner VStack to actually expand.
3. **Saving icon: `dollarsign.circle.fill`.** The prompt accepted
   either `dollarsign.circle.fill` or `creditcard.circle.fill`;
   went with dollarsign for direct currency association (matches
   web's Coins icon semantic, not chrome).
4. **DateFormatter pinned to `en_US_POSIX`** for the YYYY-MM-DD
   formatter so the format string doesn't get reinterpreted on
   devices set to Buddhist / Japanese / Hebrew calendars.
5. **Placeholder rewired this PR** (Option B — delete + update nav
   glue, matches the Badges chore precedent so PR 5 reduces to
   acceptance testing + cleanup).

## Out of scope

- StreakStrip dashboard pill (dead code on web)
- Calendar heatmap of logged days
- Freeze usage history / log
- mutationCount subscription
- useStreakHealth on page mount
- Skeleton state
- Tiered streak badges (lives in /badges)
- Share CTA
- Vacation mode
- Pull-to-refresh on /streaks

## Acceptance

15-step real-device test plan in PR body. Critical checks:
  - Steps 5–7: stagger timings (0 / 0.08 / 0.16s)
  - Steps 11–12: gold highlight on "Today" / "This week"
  - Step 13: nil streaks → zeros / "Never" without crash
