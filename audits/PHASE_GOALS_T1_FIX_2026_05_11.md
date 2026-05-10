# Phase Goals T1 — Goals Tab UI + Contribute Chain — 2026-05-11

Implementer: Claude Code
Source-of-truth audit: `/audits/GOALS_TAB_2026_05_11.md` (web — not present in iOS repo at PR time; the prompt's inline spec served as the working blueprint)

Phase 2 shipped a Home-page Goals widget that hardcoded `current = 0` for all goals (later fixed via `GoalBalanceCalculator` in Phase 9 follow-up). This phase ships the dedicated `/goals` tab — list, detail, new/edit form, contribute, next-cycle — plus the contribute mutation chain (savings streak + momentum + badge) using the Phase 9 hook plumbing that was specifically left dormant for this moment.

## What Shipped

### Models
- `Models/Goal.swift` — extended with `previousGoalId`, `cycleCount`, `completedAt`, `isActive`. Renamed Phase 2's misnamed `accountId`/`account_id` → `fundingAccountId`/`funding_account_id` to match the actual DB column. No existing consumers (Phase 2 widget hardcoded `current=0` so the field was never read), so the rename is non-breaking.
- `Models/GoalProgress.swift` (new) — pure value type with `goal`, `currentAmount: Decimal`, `progressPercent: Double?`, `daysRemaining: Int?`, `requiredMonthlyPace: Decimal?`, `requiredWeeklyPace: Decimal?`, `isOnTrack: Bool?`, `fundingAccount: JoinedAccountRef?`. Identifiable + Equatable.

### Engine
- `Services/GoalEngine.swift` (new) — pure helpers:
  - `computeProgress(goal:currentAmount:fundingAccount:today:)` — pace status, days remaining, required monthly/weekly pace
  - `suggestNextCycleName(currentName:completionDate:)` — strips trailing year suffix, appends `{nextYear} {H1|H2}`
  - `suggestNextDeadline(completionDate:)` — `+6 months`, formatted YYYY-MM-DD
  - `parseDateOnly(_:)` — public so callers can parse `Goal.deadline` strings (Phase 9 lesson)

### Service (`GoalService`)
- Added `fetchAll(userId:)`, `fetchOne(id:)`, `fetchAmounts(goalId:)` (parallel queries → `(contributions, payments, net)` Decimal tuple), `fetchContributions(goalId:)` (joined fetch with FK constraint names from T1 lesson), `fetchPayments(goalId:)`, `fetchPreviousCycle(previousGoalId:)`
- `CreatePayload` + `UpdatePayload` Encodable structs
- `create(payload:)`, `update(id:payload:)`, `archive(id:)`, `delete(id:)`, `markComplete(id:)`
- `contribute(userId:goal:fromAccountId:amount:note:transactionDate:currentAmount:)` — inserts a transfer transaction (`account_id` = source, `to_account_id` = goal's funding account, `goal_id` set; matching T1's "source → destination" convention) and auto-completes if target was hit
- `createNextCycle(...)` — inserts the next-cycle goal carrying icon/color/funding forward + setting `previous_goal_id` and bumping `cycle_count`

### State (`AppState`)
- `goalsList: [Goal]`, `goalsProgressMap: [UUID: GoalProgress]`, `goalsLoading: Bool`
- Computed: `activeGoals`, `completedGoals`, `totalSavedAcrossActiveGoals`
- 7 actions:
  - `loadGoalsList()` — fetches goals + per-goal amounts in parallel via `withTaskGroup`, then composes `GoalProgress` snapshots
  - `contributeToGoal(...)` — inserts transfer + auto-completes + fires the **savings streak + momentum + badge mutation chain** (Phase 9 hooks: `streakService.updateSavingsStreak`, `momentumService.award(event: .goalContribution)`, `badgeService.checkAndUnlock(trigger: .contributionMade)` and `(trigger: .streakUpdated)`) + appends new unlocks to `unviewedBadgeUnlocks` + `loadGoalsList()` refresh + `refreshHealthSnapshot()`
  - `archiveGoal(_:)` (soft delete: `is_archived=true`)
  - `deleteGoal(_:)` (hard delete; transactions remain)
  - `createGoal(payload:)`, `updateGoal(id:payload:)`
  - `startNextGoalCycle(...)` — wraps `GoalService.createNextCycle` and reloads
- Updated existing `topGoals` to use `isArchived` (was `archived`) following the model rename.

### Components (under `Features/Goals/`)
- `GoalConstants.swift` — 6 hex colors + 12 emoji glyphs + 4 suggestion pills + `resolveColor(_:)` helper that parses hex strings to `Color`
- `GoalsView.swift` (orchestrator) — header (title + total saved sub-line + "+ New Goal" gold pill) + skeleton/empty/list states + active section + completed section at 70% opacity + 3 sheet wirings (form/contribute/next-cycle) + navigationDestination on `Goal.self` to `GoalDetailView`
- `GoalDetailView.swift` — hero card (accent-tinted bg) with icon + name + cycle indicator + currentAmount big bold + target sub-line + animated progress bar; stats grid (Days left, Monthly pace, Status, Completed, Contributions, Payments, Save to); Add Contribution / Start Next Cycle CTA depending on state; previous-cycle backlink chip when `previousGoalId` set; embedded contributions + payments lists; ⋯ menu with Edit / Archive / Delete + SwiftUI alerts for confirmations
- `Components/GoalCardView.swift` — list card: icon tile (15% accent bg) + name + Trophy if completed + Cycle N badge + amount line + 3 action icons (Edit / + Add or ↻ next-cycle) as hit-test islands; spring-animated progress bar; pace chip ("On Track" gold / "Behind" orange); perpetual indicator with infinity glyph
- `Components/GoalFormSheet.swift` — bottom sheet at `.large`. Field order: Icon (12-glyph FlowLayout grid) + Color (6 round dots) → Name → Description → Type (Target / Perpetual radio cards) → Target Amount + Deadline (target only) → Save to (Picker) → Priority slider 1–10 → submit button colored to accent. Validates name+account+(target/deadline if target). Toasts on success/failure.
- `Components/ContributeSheet.swift` — bottom sheet with accent-tinted preview card (icon + name + after-amount line + spring-animated progress bar `0.4s/0.8 damping`) + From Account picker (excludes goal's funding account) + Amount field + Date picker + Note. Submit calls `contributeToGoal` which fires the mutation chain.
- `Components/NextCycleSheet.swift` — bottom sheet pre-filled via `GoalEngine.suggestNextCycleName` + `suggestNextDeadline(+6mo)`. Carries target/priority forward. On success, dismisses and forwards the new goal to the parent for navigation.
- `Components/StatTile.swift` — reusable label/value tile for the detail page stats grid
- `Components/SuggestionPillStrip.swift` — empty-state 4-pill strip; tap opens create modal (presentational only — no prefill)

### Wiring
- `Features/Shell/AuthenticatedRootView.swift` — `case .goals:` now renders `NavigationStack { GoalsView() }` (replaced `GoalsTabPlaceholder()`).

## Locked architectural decisions

- **NO `goal_contributions` table** — contributions are `transactions` rows with `type='transfer'` and `goal_id` set; payments are `type='expense'` with `paid_from_goal_id` set (T2). `GoalService.fetchAmounts` runs two parallel queries and nets them.
- **`current_amount` fully derived per render**. No cached column; the value lives in `GoalProgress.currentAmount` rebuilt every load.
- **Transfer column convention** matches T1: `account_id` = source (FROM), `to_account_id` = destination (TO). For a contribution, FROM = user's chosen account, TO = goal's funding account.
- **Pace status binary**: `On Track` (gold/green) | `Behind` (orange) | `nil`. NO `Ahead` state — matches the audit lock.
- **6 hardcoded GOAL_COLORS** + **12 emoji glyphs** as constants. Default green `#00D9A3` and 🎯.
- **Soft archive** (`is_archived=true`); **NO restore UI** — matches web's dead-letter behavior. Archive is reachable from the detail page menu only (not the list).
- **Hard delete** with confirmation alert ("Contributions stay as transactions. This can't be undone.").
- **Contribute fires the full mutation chain** — savings streak + momentum (`.goalContribution`, +10) + 2 badge triggers (`.contributionMade`, `.streakUpdated`). New unlocks merge into `unviewedBadgeUnlocks` so the existing celebration sheet on Home picks them up.
- **Auto-completion**: if a contribution pushes `currentAmount + amount >= target_amount` on a target goal that isn't already complete, `completed_at` is stamped in the same call.
- **Cycle system** (locked in this PR): `previous_goal_id` + `cycle_count` + `completed_at` columns drive the "Cycle N" indicator + Start Next Cycle CTA + previous-cycle backlink.
- **Goal.deadline as `String?`** (Phase 9 lesson reapplied) — Supabase `date` columns can't decode as `Date`. `GoalEngine.parseDateOnly(_:)` handles parsing at comparison sites.
- **Currency-aware formatter** throughout — uses `CurrencyFormatter.format(_:code:)` with `appState.currencyCode`. Web's `formatGHS` bug in NextCycleModal is intentionally NOT replicated.
- **Detail page push** via `navigationDestination(item:)` keyed on `Goal` (Hashable already exists). No new modal patterns.

## Adaptations from the prompt's blueprint

1. **`@Published` AppState → `@Observable` `private(set) var`** (Phase precedent).
2. **`profile?.id` → `session?.user.id`** (iOS uses the AuthFlow case, not a separate `profile` var).
3. **`Double` amounts → `Decimal`** throughout. Tuples returned by `fetchAmounts` are typed `(Decimal, Decimal, Decimal)`. UI sites bridge to Double for animation values via `NSDecimalNumber.doubleValue`.
4. **`appState.streaks` / `appState.momentum` / `appState.tierUpTier`** in the prompt don't exist — Phase 9 stores all of that in `healthSnapshot`. The chain calls fire the Phase 9 service helpers directly and `refreshHealthSnapshot()` picks up the changes.
5. **`enqueueBadgeCelebrations` doesn't exist** — direct `unviewedBadgeUnlocks.append(...)` matches Phase 9's existing pattern in `loadHealthSnapshot`.
6. **`mutationCount` doesn't exist on iOS** — skipped; tab refreshes are driven by `loadGoalsList()` + `refreshHealthSnapshot()` directly.
7. **`showToast` doesn't exist on AppState** — toasts are presented from views via `@Environment(ToastManager.self)`. AppState methods return `Bool` and views show toasts based on the result.
8. **`AccountRef(... type: ... color: ...)`** in the prompt doesn't match iOS — `Account.accountType` (not `type`), no `color` field. Used `JoinedAccountRef` (introduced in the Recurring phase) which already has the correct shape.
9. **Phase 2 Goal model used `accountId` / `account_id`** — likely wrong column name (web schema uses `funding_account_id`). Renamed during this PR; no existing consumers, no rollback risk.
10. **`AuthenticatedShell` with SwiftUI `TabView`** doesn't exist on iOS — the shell is `AuthenticatedRootView` with a custom `MainTabBar`. Just replaced the `case .goals:` branch.
11. **Phase 9 hook signatures** are `(userId: UUID)` keyword args returning typed result types; the prompt used positional + string-based. Adapted call sites to the actual signatures.
12. **`isOnTrack` for "Ahead" state** — the audit explicitly forbids an `Ahead` chip; the engine returns Bool? (true=On Track, false=Behind, nil=N/A) and the chip rendering matches.
13. **`previous cycle backlink` navigation** — for T1, the chip displays the previous cycle's name but tapping is a no-op. Wiring it to push the same `GoalDetailView` recursively requires plumbing a navigation path through; flagged for T2.

## Behavioral notes

- **Initial load**: orchestrator's `.task` only fires `loadGoalsList()` if the list is empty.
- **Filter change → no refetch**: there are no filters in T1.
- **Contribute → auto-completion** path:
  1. Insert transfer transaction with `goal_id`
  2. Server-side cascade tests `currentAmount + amount >= target_amount`; if true and goal isn't already complete, sets `completed_at = NOW()`
  3. Mutation chain fires (savings streak update, momentum award, badge checks)
  4. `loadGoalsList()` reloads — completed goal moves to the Completed section
  5. `refreshHealthSnapshot()` recomputes Sika score
- **Empty state**: `goals_intro` HintCard + Target icon + 4 suggestion pills (each tap opens the create form, no prefill — matches web).
- **Card animations**: progress bar uses spring `(response: 0.6, dampingFraction: 0.85)` on mount and on value change. Stagger entry by index intentionally NOT shipped — `LazyVStack` doesn't compose well with delay-based stagger; flagged as polish for Phase 9.5b.
- **Contribute progress preview**: `(response: 0.4, dampingFraction: 0.8)` for snappier responsive feel as the user types.

## Out of scope (T2 / future)

T2 will pick up:
- "Paid from a target?" expander on the transaction sheet (`paid_from_goal_id` column wiring)
- Payment-completes-target auto-completion (when an expense paid from goal empties the fund)
- `awardMomentum(event: .goalCompleted)` (+100) from the payment-side completion path
- Optional 🎯 badge on transaction rows for transfers with `goal_id` set

Permanently out of scope:
- Archive restore UI (matches web)
- Bulk operations (matches web)
- Real-time Supabase subscriptions
- Currency conversion across goal denominations
- Stagger animation on card mount (LazyVStack incompatibility)
- formatGHS hardcoded amount in NextCycleModal — iOS uses currency-aware formatter throughout, deliberately NOT replicating the web bug
- Previous-cycle backlink tap navigation (T2 will plumb the navigation path)
