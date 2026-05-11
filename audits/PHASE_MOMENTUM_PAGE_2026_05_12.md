# /momentum page — 2026-05-12

Implementer: Claude Code
Source-of-truth audit: `/audits/MOMENTUM_PAGE_2026_05_12.md`
Predecessors:
  - `/audits/PHASE_9_FIXUP_BADGES_2026_05_12.md` (PR 1 — catalog +
    Phase 9 model fix-ups + /badges)
  - `/audits/PHASE_STREAKS_PAGE_2026_05_12.md` (PR 2 — /streaks +
    placeholder rewire precedent)

Third of five PRs shipping /health Explore destinations. Surfaces
the momentum singleton + the top 30 recent momentum_events into a
dedicated page with four sections.

## What Shipped

### Service
- `Core/Services/MomentumService.swift` — added `fetchRecentEvents(userId:)`.
  Top 30 from `momentum_events`, ordered by `created_at` descending.
  Uses the standard `PostgrestResponse<[MomentumEvent]>` pattern
  established by the other services (no custom `JSONDecoder.supabase`).
  Intentionally **not** added to `AppState.loadProfile`'s
  parallel batch — the events table grows unbounded and shouldn't
  be hot-pathed on every app launch.

### Helper
- `Features/Momentum/MomentumProgress.swift` (new):
  - `TierProgress` struct: `currentTier`, `nextTier` (nil at Diamond),
    `progressPercent`, `pointsInTier`, `pointsNeeded`.
  - `MomentumProgressCalculator.calculateTier(totalPoints:)` iterates
    `MomentumTier.allCases` in reverse so the highest crossed
    threshold wins.
  - `nextTier(after:)` — index lookup; `nil` at Diamond.
  - `progress(totalPoints:)` — returns the full progress block,
    clamping percent to `0...1` and short-circuiting at Diamond.
  - Extension on `MomentumTier` adds a `glowColor: Color` used by
    the hero card's drop shadow (30% bronze/silver, 35% gold,
    40% platinum/diamond).

### Components (Features/Momentum/Components/)
- `TierHeroCard.swift` (new) — gradient background (transparent →
  tier-tinted 8%), 1pt frame at 25% tier color, 20pt drop shadow
  in `glowColor`. Animations:
  - TierIcon `.spring(response: 0.4, dampingFraction: 0.55)` — scale
    0.8→1, opacity 0→1 on appear (approximates web's Framer Motion
    `stiffness: 200, damping: 20`).
  - Progress bar fill: `.easeOut(0.8)` with 200ms delay after appear.
  Progress block (next-tier label + bar + "N pts to next tier") is
  rendered **only when `nextTier != nil`** — Diamond users see
  hero without it.
- `AllTiersLadder.swift` (new) — 5 rows iterating
  `MomentumTier.allCases`. Locked tiers (above current) get 30%
  icon opacity + muted name color. The active row shows a
  "CURRENT" pill in the tier's color with a 13%-opacity background
  capsule.
- `HowToEarnPoints.swift` (new) — 7 rows from
  `MomentumAmounts.entries` in **insertion order** (NOT sorted by
  points). Label left, gold "+N" right. Includes unwired event
  types (`transactionLoggedViaNudge`, `bucketWithinLimitFullMonth`)
  for cross-platform parity.
- `RecentActivity.swift` (new) — 2-line rows (label / relative time)
  + gold "+N" trailing. `RelativeDateTimeFormatter.unitsStyle = .full`
  produces "2 hours ago", "3 days ago", "yesterday".

### Orchestrator
- `MomentumView.swift` (new) — `ScrollView` + `VStack`. Loads events
  in `.task`; `RecentActivity` conditional on `!events.isEmpty`
  (matches web — no skeleton state, the section just doesn't show
  until data exists).

### Wiring
- `Sika/Features/Health/HealthDetailView.swift` —
  `.navigationDestination(isPresented: $showMomentum)` now pushes
  `MomentumView()`.
- `Sika/Features/Health/Placeholders/MomentumDetailPlaceholderView.swift`
  — **deleted** (Option B, matches the Badges + Streaks precedent).

### Carry-over note for PR 4
- `HealthPlaceholderShell.swift` is now an orphan — all three
  concrete placeholders that consumed it (Badges, Streaks, Momentum)
  have been deleted across PRs 1, 2, 3. Cleanup belongs in PR 4.

## Locked architectural decisions

- **Standardized sticky header** across all four health-adjacent
  pages (/health, /badges, /streaks, /momentum).
- **`MomentumService.fetchRecentEvents` lives on the page, not in
  loadProfile.** The events table grows unbounded; on-mount fetch
  is appropriate.
- **No mutationCount subscription.** Reads the snapshot loaded at
  session start. Refresh happens on navigate-away-and-back when
  `loadProfile` / `refreshHomeData` re-fires.
- **No skeleton state for Recent Activity.** Section simply doesn't
  render until events are populated.
- **No tier-up modal on this page.** Tier-up celebration lives in
  the surfaces where momentum is awarded (contribute modal etc.),
  per web's separation of concerns.
- **HowToEarnPoints in insertion order**, not sorted by points.
  This preserves the audit's logical grouping (logging events first,
  goal events next, big-ticket monthlies last).
- **Hero spring animation tuned to approximate web's Framer Motion.**
  `.spring(response: 0.4, dampingFraction: 0.55)` is the closest
  out-of-the-box match for `stiffness: 200, damping: 20`.
- **Progress bar fill animates from 0 to current percent** with an
  explicit 200ms delay so the tier icon settles first.
- **Diamond edge case**: progress block hidden when `nextTier` is
  nil. No "MAXED OUT" badge, no celebration — just a clean stop.

## Adaptations from the prompt's blueprint

1. **No `TiersCatalog`** — PR 1 explicitly chose not to introduce
   a parallel catalog because `MomentumTier` already exposes
   `.threshold`, `.color`, `.iconName`, `.displayName`, and
   `.from(totalPoints:)`. The view code iterates
   `MomentumTier.allCases` and reads the case's own accessors.
2. **`glowColor` added as an extension on `MomentumTier`**, not as
   a `TierMeta` field. Keeps the source-of-truth on the enum.
3. **`MomentumService()` instantiated freshly per call**, not via
   `.shared`. Matches the existing pattern (no `.shared` exists on
   `MomentumService`).
4. **`@Environment(AppState.self)`** instead of `@EnvironmentObject`.
5. **`session?.user.id`** instead of `appState.profile?.id` —
   profile lives inside `flow = .authenticated(profile:)`; no
   direct `.profile` accessor exists on AppState.
6. **`import Supabase` required** in `MomentumView.swift` so the
   compiler can resolve `session.user.id`. Matches the precedent in
   `GoalFormSheet`, `AddTransactionWizardView`, and other
   AppState-session-touching views.
7. **`RelativeDateTimeFormatter.unitsStyle = .full`**, not `.named`.
   The prompt's `.named` case doesn't exist on iOS's enum (valid
   cases: full / spellOut / short / abbreviated). `.full` produces
   the audit's intended "2 hours ago" / "3 days ago" output.
8. **Placeholder rewired this PR** (Option B — delete + nav
   update). Matches Badges + Streaks precedent so PR 5 reduces to
   acceptance testing.

## Out of scope

- MomentumStrip dashboard pill (dead code on web)
- TierUpModal on this page (lives in caller surfaces per web)
- Pagination beyond top 30 events / Load More button
- mutationCount subscription
- Skeleton state for activity list
- Bar chart visualizations
- Awarded actions breakdown by category
- Pull-to-refresh on /momentum

## Acceptance

22-step real-device test plan in PR body. Critical checks:
  - Step 6: TierIcon spring entrance
  - Step 9: progress bar animation timing (200ms delay + 800ms fill)
  - Step 10: progress block hidden at Diamond
  - Step 12: locked-tier visual treatment
  - Step 18: relative time formatting
  - Step 20: Recent Activity hidden when zero events
