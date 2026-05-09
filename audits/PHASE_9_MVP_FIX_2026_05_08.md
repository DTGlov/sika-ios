# Phase 9 MVP — HealthRow + Score/Streaks/Momentum/Badges + Celebration — 2026-05-08

Implementer: Claude Code
Source-of-truth audit: `/audits/HEALTH_ROW_2026_05_08.md` (web — not present in iOS repo at PR time; the prompt's inline spec served as the working blueprint)
Web reference file: `lib/health-score.ts` (pasted into chat by the user — ported faithfully)

This phase closes the Home rebuild MVP. After this ships, every visible surface on Home is rebuilt; remaining work is **Phase 9.5** (`/health` detail page, `/badges` grid, tier-up celebration with confetti, milestone toasts) and **Phase 6.1** (motif visual polish).

## What Shipped

### Models (`Models/Health.swift`)
- `HealthLabel` (5 cases: excellent/good/fair/needsAttention/critical) with `displayName` + `color` + `from(score:)` threshold function
- `HealthFactorId` (5 cases) with `displayName` + `weight` (matches web's FACTOR_NAMES + FACTOR_WEIGHTS)
- `HealthFactor` (struct with id/name/weight/score/description/tip)
- `HealthScore` (total/label/factors)
- `Streaks` (Codable mirror of `streaks` table — 12 fields)
- `MomentumTier` (5 cases — bronze 0 / silver 500 / gold 2000 / platinum 5000 / diamond 10000) with `threshold` / `color` / `iconName` (SF Symbol) / `from(totalPoints:)`
- `MomentumEventType` (7 cases) with `points` (mirror of MOMENTUM_AMOUNTS)
- `Momentum` (Codable mirror of `momentum` table) with `resolvedTier` accessor
- `BadgeRarity` (common/rare) with `frameColor`
- `BadgeCatalogEntry` + `BadgeCatalog` enum (8 hardcoded entries — mirror of web's BADGES_CATALOG)
- `BadgeTrigger` (6 cases) with `badgeIds` mapping to candidate badges
- `UserBadge` (Codable mirror of `user_badges` table)
- `HealthSnapshot` (composes score/streaks/momentum/userBadges)

### Services
- `Services/StreakEngine.swift` — pure date math, `final enum`-style namespace
  - `updateLoggingStreak(current:today:)` — daily; +1 per first user-initiated transaction of the day
  - `updateSavingsStreak(current:today:)` — weekly; Monday-anchored via ISO 8601 calendar
  - Freeze logic: every 10 days banks one (max 2); consumed on missed-day gap; breaks if insufficient
  - `hasLoggedToday`, `mondayOfWeek`, `daysBetween`, `weeksBetween` helpers
- `Services/StreakService.swift` (final class) — Supabase wrapper
  - `fetchOrCreateStreaks(userId:)`
  - `updateLoggingStreak(userId:)` / `updateSavingsStreak(userId:)` — read → mutate via engine → persist
  - `fetchStreaksOrNil(userId:)` for snapshot composition
- `Services/MomentumService.swift` (final class)
  - `award(userId:event:)` — fetchOrCreate + tier delta + upsert + event log
  - `fetchMomentumOrNil(userId:)` for snapshot composition
- `Services/BadgeService.swift` (final class)
  - `checkAndUnlock(userId:trigger:)` — filter candidates → check conditions → batch insert → return new rows
  - `markCelebrationShown(userBadgeId:)`
  - `fetchUserBadges(userId:)` — newest first
  - Per-badge condition checks: `transactionCount`, `loggingStreakValue`, `savingsStreakValue`, `completedGoalsCount`, `checkSafetyNet`
- `Services/HealthScoreCalculator.swift` (final class) — **the load-bearing port**
  - `computeHealthScore(userId:categories:budgetBuckets:)` — parallel base fetch → cycle range derive → cycle expense fetch → 5 factors → weighted total
  - `computeEmergencyCoverage`, `computeBudgetDiscipline`, `computeConsistency`, `computeGoalCommitment`, `computeDiversification` — line-for-line port of web's lib/health-score.ts (verified against the file pasted into chat)
  - Uses caller-supplied `categories` + `budgetBuckets` arrays (already loaded in AppState) to resolve `category_id → bucket name` rather than the nested PostgREST embed (`category:categories!category_id(bucket:budget_buckets(name))`)
  - Internal Codable structs: `ProfileFields`, `StreaksMinimal`, `GoalRow`, `CycleExpenseRow`
- `Services/HealthService.swift` (final class) — composer
  - `fetchSnapshot(userId:categories:budgetBuckets:)` — async-let parallel fetch of score + streaks + momentum + badges; degrades each to nil/empty on error

### State (`Core/State/AppState.swift`)
Additions:
- `private(set) var healthSnapshot: HealthSnapshot?`
- `private(set) var unviewedBadgeUnlocks: [UserBadge]`
- `var hasLoggedToday: Bool` (computed from snapshot via StreakEngine)
- `loadHealthSnapshot()` private — populates snapshot + enqueues unviewed unlocks (cross-platform handoff)
- `fireCycleEndedBadgeCheck()` private — fired once per profile load (mirror of web's dashboard-mount useEffect)
- `refreshHealthSnapshot()` public — re-runs loadHealthSnapshot
- `fireTransactionLoggedHooks()` public — the load-bearing mutation hook
- `dismissBadgeCelebration(_:)` public — removes from queue + persists celebration_shown=true

`loadProfile` and `refreshHomeData` both call `loadHealthSnapshot()` after the existing parallel batch resolves. `loadProfile` additionally fires the cycle_ended badge check.

### Mutation hook retrofits
- `AppState.logIncomeNudge` (Phase 7) — fires `fireTransactionLoggedHooks` after the income transaction insert succeeds
- `AppState.confirmPendingRecurring` (Phase 7) — fires `fireTransactionLoggedHooks` after the recurring confirm
- `Features/Transactions/AddTransactionWizardView.swift` — fires `appState.fireTransactionLoggedHooks` after the wizard's `transactionService.insert` succeeds

`fireTransactionLoggedHooks`:
1. `streakService.updateLoggingStreak`
2. `momentumService.award(.transactionLogged)` (+2)
3. If `streakResult?.milestoneHit == 7`: `momentumService.award(.loggingStreak7Days)` (+50)
4. Parallel `badgeService.checkAndUnlock(.transactionLogged)` + `(.streakUpdated)` if streak result was non-nil
5. Append any new unlocks to `unviewedBadgeUnlocks`
6. `loadHealthSnapshot` to refresh score

Auto-generated recurring transactions (`RecurringService.insertAutoLoggedTransaction`) DO NOT call this — matches web.

### Components
- `Features/Home/Components/HealthRow.swift` — pill on Home, 62pt minHeight, top row (score + label) + bottom row (conditional streak chip + tier chip + badge count) + trailing chevron. Skeleton state when `snapshot.score == nil`. Streak flame pulses when `loggingCurrent > 0 && !hasLoggedToday`.
- `Features/Home/Components/BadgeCelebrationSheet.swift` — `.fullScreenCover` modal. Spring-entry medallion (`response: 0.4, dampingFraction: 0.7`), `UINotificationFeedbackGenerator(.success)` haptic on appear, "BADGE UNLOCKED" header, name in rarity color, description, "Continue" CTA in rarity color. Auto-dismiss 5s via `Task.sleep`. NO confetti (Phase 9.5 reserves that for tier-up).

### Wiring (`Features/Home/AuthenticatedHomeView.swift`)
- `HealthRow` slotted between `SundayRecapCard` and the IncomeNudges/PendingRecurring section
- `.fullScreenCover(item: nextBadgeCelebration)` driven by a Binding to `appState.unviewedBadgeUnlocks.first` — cover automatically advances to the next unlock as each is dismissed

## Locked architectural decisions

- **Client-side compute** for all 4 surfaces (mirrors web). No new HTTP routes; direct Supabase reads + writes via Swift SDK.
- **Score is a pure function of DB state** — never persisted. Recomputes on profile load + after every mutation hook.
- **Mutation hooks fire-and-forget** — never block the user mutation path. Wrapped in detached `Task { ... }` from the success branch of each insert.
- **Auto-generated recurring transactions DO NOT trip the streak** — matches web's intent (the user didn't act).
- **Cross-platform celebration handoff** — `user_badges.celebration_shown=false` rows are enqueued on profile load, regardless of which platform unlocked them.
- **HealthRow tap is a no-op for MVP** — `/health` detail page deferred to Phase 9.5.
- **Hardcoded BADGES_CATALOG in Swift** — mirrors web's hardcoded TS catalog. Adding a badge requires a coordinated client release on both platforms.
- **8 badges total** (4 common: first_steps, week_warrior, goal_getter, consistent_saver; 4 rare: century_club, month_of_discipline, seeker, safety_net).
- **5 momentum tiers** with thresholds 0/500/2000/5000/10000.
- **5 score labels** with HealthLabel.from(score:) thresholds at 80/60/40/20.
- **BadgeRarity is styling-only** (common = green frame, rare = gold). Not a hierarchy / progression axis.
- **Caller-supplied categories + budgetBuckets** for HealthScoreCalculator — avoids the nested PostgREST embed and reuses arrays AppState already holds.
- **Goal IS-NULL filters applied post-fetch in Swift** — the iOS Supabase SDK's `.is()` filter signature is awkward, and existing iOS services (MonthlyRecapService) also fetch loosely + filter post-hoc. This is the established pattern.
- **Celebration sheet uses `.fullScreenCover`** (not `.sheet`) per audit guidance — the modal blocks all Home interaction until dismissed.
- **No confetti on badge celebration** — confetti is reserved for tier-up in Phase 9.5. Spring + haptic + auto-dismiss is the locked iOS interaction.

## Adaptations from the prompt's templates

1. **`actor` services → `final class` + `SupabaseManager.shared.client`** (Phase 2–8 precedent throughout the iOS codebase).
2. **`SupabaseClient.shared.client` → `SupabaseManager.shared.client`** (correct iOS singleton).
3. **`@Observable @MainActor AppState` is already in place** — no change needed; just added new fields to it.
4. **`Color(hex: 0x...)`** — works because the existing `SwiftUI.Color` extension in SikaTheme.swift accepts `UInt32`.
5. **`differenceInDays` (date-fns) → Calendar.dateComponents** — explicit `startOfDay` normalization at both ends so DST doesn't bite.
6. **Monday anchor for savings streak** — Calendar(identifier: .iso8601) with explicit `.timeZone = .current`. Matches web's date-fns startOfWeek with weekStartsOn: 1.
7. **`fetchGoalAmounts(supabase, goalId).net`** is web-side; no equivalent on iOS. Ported as `HealthScoreCalculator.fetchGoalNet(goalId:)` reading `goal_contributions` with conservative `(amount, type)` schema and degrading to 0 on schema mismatch / missing table. BadgeService has its own copy of this read for the `safety_net` check.
8. **Goal `is_active` / `completed_at` fields not on the iOS Goal model** — `HealthScoreCalculator.GoalRow` is a private decode-only struct that selects them directly without modifying the public Goal type.
9. **Nested PostgREST embed for transaction.category.bucket.name** — replaced with caller-supplied `categories: [TransactionCategory]` + `budgetBuckets: [BudgetBucket]` arrays. AppState passes those through HealthService → HealthScoreCalculator. Fewer round-trips, and the bucket-name lookup is just a Dictionary.
10. **Phase enum `Equatable` for badge celebration queue** — used a Binding-with-no-op-set on `appState.unviewedBadgeUnlocks.first` instead of an `@State` mirror. The cover auto-advances when the head changes.

## Behavioral notes

- **Score recomputes after every mutation** that triggers `fireTransactionLoggedHooks` — the snapshot `loadHealthSnapshot` runs at the end of the hook.
- **Streak chip pulse** activates only when `loggingCurrent > 0 && !hasLoggedToday`. Once today's transaction is logged, the snapshot refresh updates `loggingLastDate` and the pulse stops on next render.
- **Cross-platform handoff** — when iOS loads, every `user_badges` row with `celebration_shown=false` is enqueued in `unviewedBadgeUnlocks`, regardless of where the unlock happened. Dismissing the sheet flips `celebration_shown` to true, persisted via `BadgeService.markCelebrationShown`.
- **Cycle-ended badge check** runs once per profile load, evaluating only `safety_net`. Same trigger fires the safety-net check after a goal contribution would in Phase 9.5+ (no contribute flow on iOS yet).
- **Auto-dismiss timer** is canceled if the user taps Continue early or the cover disappears for any reason (`onDisappear`).

## Dormant plumbing (no callers in MVP)

iOS has no goal-contribution flow yet (Phase 2 shipped a read-only Goals widget). The following is built and tested-by-build, but currently has zero call sites:

- `StreakService.updateSavingsStreak` (the engine code is exercised by `updateLoggingStreak` paths)
- `MomentumEventType.goalContribution` (+10) and `.goalCompleted` (+100)
- `BadgeTrigger.contributionMade` and `.goalCompleted` and the `consistent_saver` / `safety_net` / `goal_getter` / `seeker` condition checks (the read paths execute on every profile-load `cycleEnded` trigger and after each transaction insert via `streakUpdated`, but `consistent_saver` requires `savings_current >= 4` which never increments without contribute)

When iOS ships its goal-contribution flow, that flow's success branch should call:
```swift
Task {
    await streakService.updateSavingsStreak(userId: userId)
    await momentumService.award(userId: userId, event: .goalContribution)
    _ = await badgeService.checkAndUnlock(userId: userId, trigger: .contributionMade)
    let streakUnlocks = await badgeService.checkAndUnlock(userId: userId, trigger: .streakUpdated)
    // append streakUnlocks to unviewedBadgeUnlocks
    await refreshHealthSnapshot()
}
```

## Out of scope (Phase 9.5 / 9.x)

- `/health` detail page with per-factor cards + animated bars + tip text
- `/badges` grid view (Earned + Locked sections)
- Tier-up celebration sheet with confetti
- Score change count-up animation
- Streak break detection toast (`logging_just_broken`)
- Streak milestone toasts (7/14/30/60/100, 4/12/26/52)
- `streaks_intro` HintCard placement
- Custom badge artwork (using SF Symbols mapped from web's Lucide)
- `transaction_logged_via_nudge` differentiation — all user-initiated paths award `transaction_logged` (+2). The +5 nudge variant is a small UX nicety that isn't worth the branch yet.
- `bucket_within_limit_full_month` event — no obvious caller in iOS or web; deferred.
- `account_reconciled` event — no badges in trigger map; deferred.
- HealthRow tap → `/health` detail page
- iPad-specific layout for the celebration sheet

## Acceptance status

Build passes (`xcodebuild ... iPhone 16 ... -configuration Debug build` → BUILD SUCCEEDED). The full real-device acceptance script in the prompt is for the implementer to run after merge.

The dormant savings-streak path is intentionally untested-on-device for this PR — it has no callers. Phase 9.5 (or whichever phase wires the contribute flow) will exercise it.
