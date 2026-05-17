# PHASE — IBS CACHE STALENESS HOTFIX (Tier 1a)

**Date:** 2026-05-19
**Branch:** `fix/ibs-cache-staleness-hotfix`
**Scope:** iOS (Sika Project / ios / Sika)
**Driver:** Live overdraft bug surfaced during dogfood. User report:
"had 20 GHS in MoMo, logged 200 expense, account went to −120, no IBS."
**Audit reference:** [`IBS_COVERAGE_2026_05_19.md`](./IBS_COVERAGE_2026_05_19.md) — §8 (repro trace), §9 (cache call-site enumeration), §10 (recommended fix scope).

---

## What shipped

5 explicit `recomputeAccountBalances()` calls added at the 5 cache-blind insert/load sites identified by the audit. Each call uses the existing fire-and-forget / `await`-in-place pattern that already coexists with the surrounding refresh ops. Total diff: **+9 / −1** across **2 files**.

| # | Site | File:line (post-edit) | Why |
|---|------|------------------------|-----|
| 1 | `AppState.loadProfile()` — after parallel fetch lands `self.transactions = transactions` | `Sika/Core/State/AppState.swift:589` | Cold-start: cache is `[:]` until user visits Accounts tab. This seeds it as soon as profile loads, so the first FAB tap sees real balances instead of the `openingBalance` fallback. |
| 2 | `AddTransactionWizardView.performAdd()` — appended inside the existing Task wrapping `refreshTransactionsListAfterSave` | `Sika/Features/Transactions/AddTransactionWizardView.swift:294-295` | Sequential inserts: cache was stale after every successful wizard save. This refreshes immediately so a follow-up insert in the same session sees post-A balance. |
| 3 | `AppState.logIncomeNudge()` — after `refreshHomeData()`, before the hooks Task | `Sika/Core/State/AppState.swift:836` | Income nudge (positive delta) still needs to update the cache; otherwise a subsequent expense check reads pre-nudge balance and overshoots IBS thresholds. |
| 4 | `AppState.confirmPendingRecurring()` — after `refreshHomeData()`, before the hooks Task | `Sika/Core/State/AppState.swift:906` | "Log it" on a pending recurring inserts a row directly; cache stays stale. Same staleness pattern as #2/#3. |
| 5 | `AppState.contributeToGoal()` — after `loadGoalsList()` + `refreshHealthSnapshot()`, before `return true` | `Sika/Core/State/AppState.swift:1864` | Goal contribute mutates the source account but never re-fetched balances. A subsequent expense from the same account would have read pre-contribution numbers. |

All five calls are direct `await recomputeAccountBalances()` invocations on `self` (already `@MainActor`). The wizard-side call (#2) is the one wrapped in `Task { … }` because that site has been background-fire-and-forget since T2 (it sits outside the wizard's lifecycle critical path).

---

## Why (root cause from audit §8-9)

`AppState.accountsBalances: [UUID: Decimal]` is a private(set) cached map. It is **only** populated by `recomputeAccountBalances()` (network round-trip), which prior to this PR fired from exactly 5 sites — *none of which are user-driven inserts or cold-start*:

1. `createAccount` (after a new account is added)
2. `updateAccount` (after edit)
3. `reconcileAccountInline` (after reconcile adjustment insert)
4. `deleteAccountWithReassign` (after delete)
5. `AccountsView.task` (first appearance of Accounts tab)

The wizard's `validateBalance` reads from this cache via `AccountBalanceEngine.balance(for:in:)` at `AccountBalanceEngine.swift:56-58`:

```swift
balances[account.id] ?? account.openingBalance ?? 0
```

**The bug:** when the cache is `[:]` (cold-start session, no Accounts tab visit), the fallback returns `account.openingBalance` — which is typically the LARGEST stale value possible (the seed before any expense was applied). The user's MoMo was seeded at, say, 500 GHS, accumulated −480 of expenses to land at a real balance of 20. The wizard read 500. `200 < 500` → IBS skipped → expense lands → real balance = −120.

**The "sometimes IBS fires" pattern:** IBS fires when the user happened to visit Accounts at some point that session (which seeded the cache) AND has done no inserts since (so the cache is still fresh). Both conditions are user-habit-dependent and invisible from the UI, which is why the bug is non-deterministic.

This PR closes the cold-start hole (#1) and the post-insert staleness hole (#2/#3/#4/#5).

---

## Trade-off acknowledged

**Cost:** 5 new network round-trips on hot paths — every wizard save, every income-nudge log, every recurring confirm, every goal contribute. `recomputeAccountBalances()` calls `transactionService.fetchAllForBalances`, so each is a Supabase round-trip.

**Why accepted:** the cache miss → openingBalance fallback path is a live correctness bug, not a perf issue. Worse to leak overdrafts to production than to add a few hundred ms per save while a clean fix lands. The wizard-side recompute (#2) runs inside a fire-and-forget `Task` after `dismiss()`, so the user-visible Save→dismiss latency is unaffected. The other four (`loadProfile`, `logIncomeNudge`, `confirmPendingRecurring`, `contributeToGoal`) are already awaiting other refresh ops on the same hot path, so the additive latency is a single extra round-trip queued behind work that was already happening.

**Mitigation timeline:** Tier 1b (next PR, this week) will refactor `accountsBalances` to a computed property derived live from `appState.accounts` + `appState.transactions`. That eliminates the cache entirely AND removes all 5 of these recompute calls + the original 5 site recomputes, replacing them with an O(N) in-memory fold per read (negligible for any realistic transaction count). At that point this PR's adds become dead code and get deleted along with `recomputeAccountBalances()` itself.

---

## Known follow-ups (out of scope here)

### Tier 1b — Architectural fix (PR 2, this week)
Convert `AppState.accountsBalances` from a cached `[UUID: Decimal]` private(set) var to a live computed property derived from `appState.accounts` + `appState.transactions`. Delete `recomputeAccountBalances()` entirely. Audit §10 sizing: 1-file refactor in `AppState.swift` + careful audit of all 7 consumers of `accountsBalances` listed in audit §9 to confirm none rely on side-effects. Estimated effort: 1-2 hours plus regression check.

### Tier 2 — Coverage GAPs (PR 3)
The audit identified 5 GAPs total. This PR addresses cache freshness for paths that already have a validation check (the FAB-new path). The remaining gaps are paths that have NO validation check at all:

- **Path B — Edit branch** (`AddTransactionWizardViewModel.swift:187`): `validateBalance` returns nil for any `isEditMode == true`. Fix is a delta-aware check (changing 20 → 200 on an expense should trigger IBS; changing 20 → 10 should not). Audit §4 has the delta sketch.
- **Path K — Goal contribute** (`ContributeSheet.submit` → `AppState.contributeToGoal`): no balance check before the insert. PR 3 will add a "Insufficient balance in {accountName}" toast + early return — IBS overlay can't be reused here because the host context is different.
- **Path I — Pending recurring "Log it"** (`confirmPendingRecurring`): same as Path K, add local toast.
- **Path J — Recurring detail "Log this instance now"** (`logRecurringInstanceNow`): same as Path K, add local toast.

### Stays as-is (by design)
- **Path H — Recurring auto-fire** (`generateAndCollectPending`): silent overdraft is intentional — matches web parity. Auto-generated rows never block on balance; user remediates after the fact.

---

## Build status

`xcodebuild -project Sika.xcodeproj -scheme Sika -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' -configuration Debug build` → **BUILD SUCCEEDED**.

---

## Acceptance test (real device)

See PR description for the full 20-step script. The critical case is: **force-quit → cold launch → skip Accounts tab → FAB new expense > balance → IBS must fire on the first Next-tap**. Pre-fix, this silently overdrew. Post-fix, the cache is seeded by `loadProfile` before the wizard can be opened, so `validateBalance` reads the real number from `transactions` rather than the stale `openingBalance` fallback.
