# IBS COVERAGE AUDIT — Insufficient Balance Sheet gate coverage across all transaction insert paths

**Date:** 2026-05-19
**Scope:** iOS (Sika Project / ios / Sika). Forensic audit triggered by user report:
"had 20 GHS in MoMo, logged 200 expense, account went to -120, IBS didn't
fire that time but does fire other times."

**Key terminology used below:**
- "IBS" — `InsufficientBalanceOverlay` (introduced T3 redesign,
  `Sika/Features/Transactions/Components/InsufficientBalanceOverlay.swift:25`).
- "validateBalance" — `AddTransactionWizardViewModel.validateBalance(accounts:balances:)`
  at `Sika/Features/Transactions/AddTransactionWizardViewModel.swift:183`.
- "accountsBalances" — `AppState.accountsBalances` cache map
  (`Sika/Core/State/AppState.swift:71`), recomputed by
  `recomputeAccountBalances()` at line 1972, fed by
  `AccountBalanceEngine.compute(...)` at
  `Sika/Core/Services/AccountBalanceEngine.swift:16`.

---

## 1. ENTRY POINTS — every UI surface that initiates a transaction insert

Confirmed by exhaustive grep for `transactionService.insert`,
`insertReconcileAdjustment`, `confirmPending`, `logInstanceNow`,
`GoalService.contribute`, and the lone other `insertAutoLoggedTransaction`
helper. Mapping:

| # | Entry point | Trigger file:line | Verified in code? |
|---|---|---|---|
| A | FAB → AddTransactionWizardView (main path) | `Features/Shell/AuthenticatedRootView.swift:57-68` (`.sheet(isPresented:)` + `FloatingActionButton`) | YES |
| B | T1 list row → Edit | `Features/Transactions/TransactionsView.swift:162` (`editingTransaction = ...`) → `:53-58` (`.sheet(item:)` opens wizard with `editingTransaction: txn`) | YES |
| C | Step 1 ReconcileLink → in-wizard reconcile mode | `Features/Transactions/Step1/AddTransactionStep1View.swift:48,73-92` (writes `appState.reconcileContext`) → `AddTransactionWizardView.swift:87-94` (`.onChange` swaps to reconcile mode) | YES — does NOT insert an expense/transfer/income; instead enters a mode that ultimately inserts an `adjustment`. |
| D | Accounts tab scale icon → standalone reconcile sheet | `Features/Accounts/AccountsView.swift:69-77` (sets `reconcileContext`) → `:112-121` (`.sheet(item: reconcileContext)` opens `ReconcileAccountSheet`) → `ReconcileAccountSheet.commit()` calls `appState.reconcileAccountInline` at `.swift:178` | YES |
| E | IBS Reconcile remediation → in-wizard reconcile mode | `AddTransactionWizardView.swift:220-226` (`handleReconcileFromIBS`) sets `appState.reconcileContext` → same swap as (C) | YES |
| F | IBS Top up remediation → wizard in income mode | `AddTransactionWizardView.swift:204-208` (`handleTopUp`): clears IBS, flips `selectedType = .income`, returns to Step 1 (`currentStep = .howMuch`). User then re-walks the wizard normally — eventually re-enters `performAdd` with type `.income`. | YES |
| G | Income nudge "log this paycheck" | `AppState.swift:794-841` (`logIncomeNudge(_:)`). Triggered from `Features/Home/Components/IncomeNudgeCardView.swift:28-43` → `AuthenticatedHomeView.swift:161`. | YES |
| H | Recurring auto-fire (silent generation) | `AppState.swift` calls `recurringService.generateAndCollectPending(...)` at line 332 (`loadNudgesAndRecurring`, runs once per session) and on manual `syncRecurringNow` at 1208 → `RecurringService.swift:71-99` (`generateAndCollectPending`) → `:84-89` calls `insertAutoLoggedTransaction` for `auto_log=true` rules. **AUTO-CREATE PATH EXISTS.** | YES |
| I | Pending recurring "Log it" from Home card | `AppState.swift:888-910` (`confirmPendingRecurring`) → `RecurringService.swift:103-110` (`confirmPending`) → inserts via `insertAutoLoggedTransaction`. UI: `Features/Home/Components/PendingRecurringCardView.swift` via `AuthenticatedHomeView.swift:167-175`. | YES |
| J | Recurring detail "Log this instance now" | `AppState.swift:1220-1239` (`logRecurringInstanceNow`) → `RecurringService.swift:233-239` (`logInstanceNow` is an alias of `confirmPending`). | YES |
| K | Goals contribute flow → transfer with `goal_id` | `Features/Goals/Components/ContributeSheet.swift:295-301` → `AppState.contributeToGoal` (`AppState.swift:1807-1867`) → `GoalService.contribute` (`Core/Services/GoalService.swift:205-255`). Inserts `type: "transfer"`, `account_id = from`, `to_account_id = goal.fundingAccountId`. | YES |
| L | Goal payment flow → expense with `paid_from_goal_id` | NOT a separate insert path. The `paid_from_goal_id` field is just a column on a regular expense row, set inside the FAB wizard via `Features/Transactions/Step3/TargetGoalPicker.swift` (sets `viewModel.selectedGoalId`) → packed into the draft at `AddTransactionWizardViewModel.swift:283`. Routes through Entry Point A. | YES (folded into A) |
| M | Inline reconcile from Edit modal expander | NOT shipped on iOS. Web has a 3rd reconcile path embedded in the account edit form; iOS `AccountFormSheet.swift` does NOT expose this. Confirmed by grep. Only iOS reconcile entries are (C)/(D)/(E). | N/A |

**Other entry points searched and confirmed NOT to exist:**
- No direct insert from the Home `RecentTransactionsWidget` (read-only).
- No insert from `Settings` screens.
- No insert from `Momentum`, `Health`, or `Goals` detail views (other than via `ContributeSheet`).
- No insert from `BudgetBucket` actions.
- No background notification / push handler that inserts.
- No watchOS / Siri / Shortcuts entry point in this repo.

**Total: 11 distinct insert-paths** (A through M, minus L which folds into A and M which doesn't exist).

---

## 2. PER-PATH ANALYSIS

For each path: trigger site → validation status → insert call site → IBS coverage.

### A. FAB → AddTransactionWizardView (new transaction, type=expense / income / transfer)

- **Trigger:** `AuthenticatedRootView.swift:57-62` (FAB tap sets `isAddTransactionPresented = true`); sheet body at `:63-68` mounts wizard with no `editingTransaction`.
- **Validation site:** `AddTransactionWizardView.swift:171-181` (`handleNextFromStep1`) for expense; `:185-195` (`handleNextFromStep2`) for transfer. Both call `viewModel.validateBalance(accounts:balances: appState.accountsBalances)`.
- **Does `validateBalance` run?**
  - Expense: YES, on Step 1's Next-tap.
  - Income: NO — `validateBalance` returns nil for income (`AddTransactionWizardViewModel.swift:198-199`). Correct (no debit).
  - Transfer: YES, on Step 2's Next-tap, against `selectedFromAccountId` (`AddTransactionWizardViewModel.swift:196-197`).
  - Adjustment: NO — wizard cannot author adjustments directly; bails (`AddTransactionWizardViewModel.swift:303-307`).
- **Insert call site:** `AddTransactionWizardView.swift:264` (`transactionService.insert(prepared.draft)`).
- **IBS opens on failure?** YES — `ibsContext = context` at `:177` and `:191`, rendered via `.overlay { if let context = ibsContext { InsufficientBalanceOverlay(...) } }` at `:73-86`.
- **Classification:** PROTECTED (subject to the freshness gap of Section 8/9, but a check is wired).

### B. T1 list row → Edit (existing transaction)

- **Trigger:** `TransactionsView.swift:162` (`editingTransaction = TransactionsView.transaction(from: row)`); sheet at `:53-58` mounts wizard with `editingTransaction: txn`.
- **Validation site:** Same wizard, but…
- **Does `validateBalance` run?** **NO.** `AddTransactionWizardViewModel.swift:187` explicitly bails: `guard !isEditMode else { return nil }`. Comment at `:181-182` rationalises: "Edit mode also skips — the original row's amount already moved the balance, so an edit isn't a fresh debit; reapplying the guard would block legitimate corrections."
- **Insert call site:** `AddTransactionWizardView.swift:325` (`transactionService.update(id: existingId, payload: payload)`) — note this is UPDATE not INSERT, but it still mutates balance.
- **IBS opens on failure?** **NEVER** — validateBalance returns nil short-circuit.
- **Classification:** **GAP** (see Section 4 for analysis of whether this is truly safe).

### C. Step 1 ReconcileLink → in-wizard reconcile mode

- **Trigger:** `Step1Content.handleReconcileTap` (`AddTransactionStep1View.swift:73-92`) writes `appState.reconcileContext = ReconcileContext(accountId:, sikaBalance:)`.
- **Validation site:** N/A — this enters reconcile mode, which doesn't insert an expense/transfer. The eventual insert is an `adjustment`.
- **Does `validateBalance` run?** NO. Adjustments don't debit (they signed-add the diff), so a balance check is meaningless.
- **Insert call site:** `AddTransactionWizardView.performReconcileSave` (`:363-391`) → `appState.reconcileAccountInline` (`AppState.swift:2092-2114`) → `AccountService.insertReconcileAdjustment` (`AccountService.swift:117-156`). Inserts `type: "adjustment"` with `amount = actualBalance - sikaBalance` (signed).
- **IBS opens on failure?** N/A.
- **Classification:** EXEMPT (adjustment, no debit semantic).

### D. Accounts tab scale icon → standalone reconcile sheet

- **Trigger:** `AccountsView.swift:69-77` sets `reconcileContext`; sheet at `:112-121` opens `ReconcileAccountSheet`.
- **Validation site:** N/A.
- **Does `validateBalance` run?** NO.
- **Insert call site:** `ReconcileAccountSheet.commit()` (`:168-191`) → `appState.reconcileAccountInline` → same insert as (C).
- **IBS opens on failure?** N/A.
- **Classification:** EXEMPT (adjustment).

### E. IBS Reconcile remediation → in-wizard reconcile mode

- **Trigger:** `AddTransactionWizardView.handleReconcileFromIBS` (`:220-226`) clears IBS, writes `appState.reconcileContext`.
- Same fate as (C) past that point.
- **Classification:** EXEMPT (adjustment).

### F. IBS Top up remediation → wizard in income mode

- **Trigger:** `AddTransactionWizardView.handleTopUp` (`:204-208`) clears IBS, flips `selectedType = .income`, `currentStep = .howMuch`.
- **Validation site:** Same wizard, when user eventually taps Next → Save.
- **Does `validateBalance` run?** Income is skipped by design (no debit). When the user Next-taps Step 1 with `.income`, `handleNextFromStep1` at `:172` runs `if viewModel.selectedType == .expense` — the guard misses for `.income`, so `goToNextStep()` runs immediately.
- **Insert call site:** Same as (A): `transactionService.insert(prepared.draft)` at `:264`.
- **IBS opens on failure?** N/A — income can never insufficient-balance.
- **Classification:** EXEMPT (income).

### G. Income nudge "log this paycheck"

- **Trigger:** `IncomeNudgeCardView.swift:28-43` "Yes, log it" tap → `AuthenticatedHomeView.swift:161` callback → `AppState.logIncomeNudge(_:)` (`AppState.swift:794-841`).
- **Validation site:** **NONE.** No call to `validateBalance` (which lives on the wizard view-model anyway, not on AppState).
- **Does `validateBalance` run?** NO.
- **Insert call site:** `AppState.swift:823` (`transactionService.insert(draft)`). Draft hard-codes `type: .income` at `:812`.
- **IBS opens on failure?** N/A — income, no debit.
- **Classification:** EXEMPT (income only — see Section 6).

### H. Recurring auto-fire (silent generation, `auto_log=true`)

- **Trigger:** `AppState.loadNudgesAndRecurring()` (`:323-337`) — fires ONCE per session at profile load (gated by `hasGeneratedThisSession`), and `AppState.syncRecurringNow()` (`:1204-1216`) when user taps the manual sync icon on the Recurring tab. Both call `recurringService.generateAndCollectPending`.
- **Validation site:** **NONE.** `RecurringService.generateAndCollectPending` (`:71-99`) iterates due rules and unconditionally inserts via `insertAutoLoggedTransaction` (`:119-147`). No balance check anywhere.
- **Does `validateBalance` run?** NO.
- **Insert call site:** `RecurringService.swift:135` (`client.from("transactions").insert(Row(...))`). Type is whatever the rule says — including `.expense`.
- **IBS opens on failure?** **NEVER.** There's no UI sheet over which to render an overlay.
- **Classification:** **GAP** — by-design, matches web. Recurrings can overdraw silently. Documented in PHASE_T3_IBS_REDESIGN audit as accepted divergence. But the user's reported bug isn't this path (they remember tapping FAB and entering 200).

### I. Pending recurring "Log it" from Home card

- **Trigger:** `PendingRecurringCardView` → `AuthenticatedHomeView.swift:171` → `AppState.confirmPendingRecurring` (`:888-910`).
- **Validation site:** NONE. Calls `recurringService.confirmPending` (`RecurringService.swift:103-110`) which calls `insertAutoLoggedTransaction` (same as H).
- **Does `validateBalance` run?** NO.
- **Insert call site:** Same as (H).
- **IBS opens on failure?** **NEVER.** No wizard mounted; only the Home card.
- **Classification:** **GAP** — user tap that can overdraw. The card surface has no IBS host.

### J. Recurring detail "Log this instance now"

- **Trigger:** `Features/Recurring/RecurringDetailView.swift` (not read, but `AppState.swift:1220-1239` confirms wiring) → `RecurringService.logInstanceNow` which is an alias of `confirmPending`.
- **Classification:** **GAP** — same as (I).

### K. Goals contribute flow

- **Trigger:** `ContributeSheet.submit` (`:278-311`) → `AppState.contributeToGoal` (`AppState.swift:1807-1867`) → `GoalService.contribute` (`GoalService.swift:205-255`).
- **Validation site:** **NONE.** `contributeToGoal` does not consult `accountsBalances` or call any check.
- **Does `validateBalance` run?** NO. (And `validateBalance` lives on the wizard view-model, not on AppState — it's not reachable from here without refactor.)
- **Insert call site:** `GoalService.swift:230` (`.insert(InsertRow(...))`) — type `"transfer"`, `account_id = fromAccountId` (the debited account), `to_account_id = goal.fundingAccountId`, `goal_id = goal.id`.
- **IBS opens on failure?** **NEVER.** ContributeSheet has its own self-contained UI; no IBS overlay host.
- **Classification:** **GAP** — user can contribute more than they have in the From account, overdrawing it silently. PHASE_T3_IBS_REDESIGN ships a pending follow-up "9.5c overpayment guard for goals" that calls this out as a known hole.

---

## 3. CRITICAL — FIND THE GAP

| Path | Type | Classification | Notes |
|---|---|---|---|
| A — FAB wizard | expense/income/transfer | PROTECTED | Subject to stale-cache issue, see §8/§9 |
| B — Edit existing transaction | expense/income/transfer | **GAP** | `validateBalance` returns nil for `isEditMode`. Editing 20 → 200 expense overdraws without warning. See §4. |
| C — Step 1 ReconcileLink → adjustment | adjustment | EXEMPT | Adjustment doesn't debit |
| D — Standalone reconcile sheet | adjustment | EXEMPT | Same |
| E — IBS Reconcile remediation | adjustment | EXEMPT | Same |
| F — IBS Top up | income | EXEMPT | Income, no debit |
| G — Income nudge "log it" | income | EXEMPT (by type) | But see §6 for confirmation |
| H — Recurring auto-fire | expense (typically) | **GAP** | Silent; matches web policy |
| I — Pending recurring "Log it" | expense (typically) | **GAP** | User tap that overdraws silently |
| J — Recurring detail "Log instance now" | expense (typically) | **GAP** | Same |
| K — Goals contribute | transfer (debits From) | **GAP** | Known follow-up |

**TOTAL GAPs: 5** (B, H, I, J, K).

**TOTAL EXEMPT: 5** (C, D, E, F, G).

**TOTAL PROTECTED: 1** (A) — but see §8/§9, the protection is effectively broken by a stale-cache problem under common usage patterns.

---

## 4. EDIT BRANCH SPECIFICALLY

`AddTransactionWizardViewModel.validateBalance` at line 187:
```
guard !isEditMode else { return nil }
```
Comment (`:180-182`):
> Edit mode also skips — the original row's amount already moved the balance,
> so an edit isn't a fresh debit; reapplying the guard would block
> legitimate corrections.

**The reasoning is partially correct, partially wrong.** It assumes the wizard's `accountsBalances` snapshot ALREADY accounts for the original row's effect (i.e., that "current balance" includes the row being edited). If the original was 50 expense and you raise it to 200, the math should be:
- Pre-edit balance = current cached balance (with the 50 expense already subtracted)
- Post-edit balance = current cached balance + 50 (refund) − 200 (new debit) = current − 150
- True overdraw check: `(amountChange = 200 − 50 = 150)` > `(current + originalAmount)`

The current code skips the check entirely. **A user who edits 20 → 200 on the same account that has 30 GHS will overdraw to −150 with NO warning.** The "legitimate corrections" rationale only holds if the new amount ≤ old amount (downward correction), or the new amount ≤ (current + old amount) (the account can absorb the increase). Neither is enforced.

**Should the edit branch check balance?** YES — but with a delta math that adds back the original row's signed impact before comparing:

```swift
// Recover what the original row debited (signed); subtract from current to get
// "what would the balance be if this row didn't exist", then check amount > that.
let effectiveBalance: Decimal
switch originalRow.type {
case .expense:    effectiveBalance = current + originalRow.amount
case .income:     effectiveBalance = current - originalRow.amount
case .transfer:   effectiveBalance = current + originalRow.amount  // when this account was the source
case .adjustment: effectiveBalance = current - originalRow.amount  // signed already
}
guard amount > effectiveBalance else { return nil }
```
(Transfer needs further branching by `From` vs `To` and account-switching mid-edit.)

For the user's report, the edit-branch gap is **not the primary suspect** (they recall tapping FAB and entering a new 200 expense, not editing). But it IS an independent live bug.

---

## 5. TRANSFER PATH

**Does the check read the From account (not To)?**
YES — `AddTransactionWizardViewModel.swift:196-197`:
```
case .transfer:
    debitAccountId = selectedFromAccountId
```
Correct.

**When does it run?**
`handleNextFromStep2()` in `AddTransactionWizardView.swift:185-195` — only at **Next-tap on Step 2** (the transfer-accounts step). It does NOT re-run when:
- The user changes the From chip (no `.onChange` observer wired to `selectedFromAccountId`)
- The user goes Back from Step 3 to Step 2 to change accounts (still no re-validate; Next-tap fires again on next forward)
- The user changes the amount on Step 1 then comes back to Step 2 via Next

**Edge case trace: From has insufficient balance → Next → IBS → "Use different account" → switch chip → does anything re-validate?**

1. User on Step 2 transfer, From=MoMo (20), To=Bank, amount=200.
2. Taps Next. `handleNextFromStep2()` runs validateBalance → returns context, sets `ibsContext` (IBS opens).
3. User taps "Use a different account" → `handleUseDifferentAccount()` at `:213-215`: clears `ibsContext = nil`. Wizard is still on Step 2. No state change to `selectedFromAccountId`.
4. User taps a different From chip. `AccountChipsRow.AccountChip.onTap` (`AccountChipsRow.swift:30-34`) just writes `selectedId = account.id` inside `withAnimation`. **No re-validation. No IBS re-fire on chip change.**
5. User taps Next again. **NOW** `handleNextFromStep2()` runs and re-validates against the new From. If the new From also overdraws, IBS opens again. Good.

**However:** if the user picks a NEW From with insufficient balance and the user does NOT re-tap Next but instead goes directly back via Back, then back to Forward through Step 1, the only revalidation site is each Next handler — so they can't reach Save without Next-tap revalidation. The Next-tap-only model is logically sufficient on the happy path.

**But:** there is **no revalidation on amount change after first Next**. Scenario: user enters 100, Next-passes (balance was 150), goes to Step 2, picks From, taps Next, but on Step 3 (via Back) bumps amount to 300 in Step 1 and Next-taps from Step 1 again. `handleNextFromStep1` fires `validateBalance` afresh — so this is actually fine.

**Net for transfer:** Next-tap-only revalidation IS correct on iOS for transfer, assuming all forward transitions require Next-tap. There's no Save-tap revalidation in `performSave` (`AddTransactionWizardView.swift:230-249` confirms: comment at 245-247 says "by the time Save fires on Step 3, the check has already passed. No revalidation here").

**Subtle hole:** if balance changes (e.g., a background recurring auto-fire silently drops the balance, OR another instance of the app inserted a transaction since the wizard opened), the cached snapshot used at Next-tap is still STALE. See §9.

---

## 6. INCOME NUDGE PATH

`AppState.logIncomeNudge(_ nudge: IncomeNudge)` — `AppState.swift:794-841`. Full code:

```swift
func logIncomeNudge(_ nudge: IncomeNudge) async {
    guard let userId = session?.user.id else { return }
    guard let account = accounts.first(where: { $0.isDefault == true })
        ?? accounts.first else {
        #if DEBUG
        print("⚠️ logIncomeNudge: no account available; cannot insert")
        #endif
        return
    }

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    let today = formatter.string(from: Date())

    let draft = TransactionDraft(
        userId: userId,
        type: .income,                          // ← HARD-CODED income
        amount: nudge.incomeSource.amount,
        accountId: account.id,
        toAccountId: nil,
        categoryId: nil,
        transactionDate: today,
        note: nudge.incomeSource.name,
        paidFromGoalId: nil
    )

    do {
        _ = try await transactionService.insert(draft)
        try await incomeNudgeService.recordDismissal(
            userId: userId,
            sourceId: nudge.incomeSource.id,
            dueDate: nudge.dueDate,
            action: .logged
        )
        withAnimation(.easeOut(duration: 0.2)) {
            incomeNudges.removeAll { $0.id == nudge.id }
        }
        await refreshHomeData()
        Task { await fireTransactionLoggedHooks() }
    } catch {
        #if DEBUG
        print("⚠️ logIncomeNudge failed: \(error)")
        #endif
    }
}
```

**Confirmed:** `type: .income`. Income credits, never debits. **No IBS check needed.** EXEMPT, correctly so.

Side note: `refreshHomeData` (called after the insert at line 833) refetches `transactions`, `accounts`, etc., but **does NOT call `recomputeAccountBalances`**. The balance map stays stale until the user visits Accounts. See §9.

---

## 7. AMOUNT TIMING

**When does validateBalance run on iOS?**

| Save / Next tap | Step 1 (amount) | Step 2 (accounts/category) | Step 3 (details) |
|---|---|---|---|
| Expense | YES (Next-tap, `handleNextFromStep1`) | n/a (category step) | NO (Save) |
| Transfer | NO (Next-tap doesn't validate, transfer skips Step 2 balance step) | YES (Next-tap, `handleNextFromStep2`) | NO (Save) |
| Income | NO (skipped by type) | NO | NO |
| Adjustment | NO | NO | NO |

**Save tap?** NO. `performSave()` comment at `AddTransactionWizardView.swift:245-247`:
> IBS-redesign: balance validation runs at Next-tap (Step 1 expense,
> Step 2 transfer) — by the time Save fires on Step 3, the check
> has already passed. No revalidation here, no override flag.

**Re-check on chip change?** NO. `AccountChipsRow` (`AccountChipsRow.swift:30-34`) just writes `selectedId`. No `.onChange` observer in `Step1Content` or the wizard that re-fires `validateBalance` when account selection changes.

**Edge case: enter 200 against MoMo (20 balance) → Next → IBS → "Use different account" → switch to a different chip → does anything re-validate?**

Walk-through:
1. Step 1: amount=200, selectedAccountId=MoMo. Tap Next.
2. `handleNextFromStep1` runs `validateBalance` → returns context (since 200 > 20). Sets `ibsContext`. IBS opens. **Wizard stays on Step 1.**
3. User taps "Use a different account" row. `handleUseDifferentAccount` (`:213-215`) just clears `ibsContext`. Wizard still Step 1, `selectedAccountId` still MoMo.
4. User taps a different chip (say Bank). `AccountChipsRow` writes `selectedAccountId = Bank.id`.
5. User taps Next AGAIN. `handleNextFromStep1` re-runs `validateBalance` against Bank's balance. If Bank has enough, advances to Step 2. **This is correct.**

**However:** the protection ONLY fires because step transition requires another Next-tap. If a refactor ever auto-advanced after chip selection, the check would be skipped. Currently safe.

**The dangerous variant:** if the user picks an account on Step 1 BEFORE entering the amount, then bumps the amount on the numpad to 200 (in place, without leaving Step 1), then taps Next — the validation runs fresh on the current `amountString` and `selectedAccountId`. Safe.

**The truly dangerous edge:** the wizard's `accountsBalances` snapshot is a reference to `appState.accountsBalances` which is captured by SwiftUI's @Observable as a current value. If `appState.accountsBalances` itself is stale (because nothing recomputed it after the last insert), the check uses stale numbers. See §9.

---

## 8. ACTUAL REPRO SCENARIO

**Given:** user reports 20 GHS in MoMo, logged 200 expense via FAB wizard, balance went to −120, IBS did NOT fire.

**Most likely sequence in code:**

1. **Session start.** User signs in or app cold-starts. `AppState.loadProfile()` (`:545-605`) runs the big parallel fetch, populating `accounts` and `transactions` arrays from the server. **`recomputeAccountBalances()` is NOT called.** `accountsBalances` remains `[:]` (empty map).
2. **User does NOT visit the Accounts tab.** No other surface seeds the balance map. `accountsBalances == [:]` for the entire session.
3. **User taps FAB on Home or Transactions tab.** Wizard opens. **The wizard does NOT call `recomputeAccountBalances` in any lifecycle hook** — confirmed by grep over `AddTransactionWizardView.swift` for `onAppear` / `task` / `recompute`.
4. **User enters 200, picks MoMo, taps Next.** `handleNextFromStep1` calls `validateBalance(accounts: accounts, balances: appState.accountsBalances)` — passing the empty map.
5. **Inside `validateBalance`:** `AccountBalanceEngine.balance(for: account, in: balances)` (`AccountBalanceEngine.swift:56-58`) returns `balances[account.id] ?? account.openingBalance ?? 0`. Since the map is empty, it falls back to `account.openingBalance`.
6. **If `MoMo.openingBalance` is something high** — e.g., the user originally seeded MoMo with 500 GHS, and has since accumulated −480 GHS of expenses bringing the real balance down to 20 — the fallback returns 500. `200 > 500` is FALSE. `validateBalance` returns nil. **IBS does not fire.** Wizard advances to Step 2.
7. User completes the wizard. The 200 expense is inserted via `transactionService.insert` (`:264`). `appState.addOptimisticTransaction` adds to `pendingTransactions`. `replaceOptimisticTransaction` moves it into `transactions`. **`recomputeAccountBalances` is NEVER called from this path.** Even if `accountsBalances` had been seeded, it would now be stale by exactly the 200 expense.
8. Server now reflects MoMo = −120. App's `transactions` array reflects the row. App's `accountsBalances` map still `[:]` or stale-by-200.

**The check that SHOULD have fired and didn't:** the Step-1 Next-tap balance check. It fired, but read the wrong number (opening balance instead of derived balance). The fundamental bug is two-fold:
- **(a) Wizard doesn't seed/refresh balances before the check.**
- **(b) `accountsBalances` is not refreshed after ANY user-driven transaction insert** — so even if the user visited Accounts first (seeding the map), subsequent expenses see pre-mutation balances.

**The "sometimes it fires" pattern:** IBS fires when the user happens to have visited the Accounts tab at any point that session (seeding `accountsBalances`) AND has done no inserts since (so the cache is still fresh). It silently fails when the user goes FAB-first without Accounts.

**Why this is non-deterministic from the user's perspective:** their habit of visiting tabs varies session to session. The bug is invisible because nothing in the UI indicates which "version" of the balance the check is using.

---

## 9. STATE STALENESS HYPOTHESIS — verified

### When does `accountsBalances` refresh?

Exhaustive `recomputeAccountBalances` / `reloadAccountsAndBalances` call sites (from grep, project-wide):

1. `AppState.swift:1991` — `reloadAccountsAndBalances` → `recomputeAccountBalances`. Called only by:
   - `createAccount` (`:2032`) — after a new account is added.
   - `updateAccount` (`:2075`) — after an account is edited.
2. `AppState.swift:2106` — inside `reconcileAccountInline`, after the adjustment insert.
3. `AppState.swift:2144` — inside `deleteAccountWithReassign`, after delete.
4. `AccountsView.swift:144` — `.task { await appState.recomputeAccountBalances() }`. Fires on Accounts tab's first appearance per `View` lifecycle.

**That's it.** Five sites total. None of them are wired to:
- `loadProfile` (initial bootstrap) — `accountsBalances` starts EMPTY and stays empty until the user opens Accounts.
- `refreshHomeData` (pull-to-refresh on Home) — fetches transactions/accounts but doesn't recompute balances.
- `loadFirstTransactionsPage` (Transactions tab refresh) — doesn't touch balances.
- `addOptimisticTransaction` / `replaceOptimisticTransaction` / `removeOptimisticTransaction` — these mutate `pendingTransactions`/`transactions` only, never recompute.
- `performAdd` / `performEdit` (wizard insert/update) — comment-confirmed: no recompute call.
- `logIncomeNudge` — calls `refreshHomeData` (which doesn't recompute) + `fireTransactionLoggedHooks`.
- `confirmPendingRecurring` — same: `refreshHomeData` + hooks.
- `contributeToGoal` — calls `loadGoalsList` and `refreshHealthSnapshot`. **No balance recompute.**
- Recurring auto-fire (`generateAndCollectPending`) — pure SQL insert, no AppState refresh.
- Transaction delete (`deleteTransactionFromList`) — no recompute.
- Wizard `.onAppear`/`.task` — none present.

### Computed live or cached?

**Cached.** `accountsBalances` is a `[UUID: Decimal]` private(set) property recomputed only by `recomputeAccountBalances()` which makes a network round-trip (`transactionService.fetchAllForBalances`). Nothing derives balances live from `appState.transactions` in the validation path.

### Could it be stale after a recent insert?

**Yes — guaranteed stale after every user-driven insert path** (A/B/G/H/I/J/K). Even after the standalone reconcile (D), the recompute fires AFTER the adjustment, so a subsequent wizard tap reads correct numbers for that path only.

### If user logs A then immediately tries B, does B see post-A or pre-A balance?

**B sees pre-A balance.** Concretely: user enters 50 expense, IBS doesn't fire (balance was 100), expense lands, `accountsBalances` not recomputed. User enters another 80 expense via FAB on the same account: `validateBalance` reads 100 (pre-A), `80 < 100`, IBS doesn't fire — but the real balance is 50, and 80 > 50, so they overdraw silently to −30.

### What about the empty-map fallback?

When `accountsBalances == [:]` (Accounts tab never visited this session), every account in the wizard's chip strip resolves to `account.openingBalance` via `AccountBalanceEngine.balance(for:in:)` fallback at `AccountBalanceEngine.swift:57`. **Opening balance is typically the LARGEST stale value possible** (it's the seed before any spend was applied). This is the most pathological case and matches the user's report.

---

## 10. RECOMMENDED FIX SCOPE

**Tier 1 — must-fix for the user's reported repro (one-line + one new call site):**

1. **Seed and refresh `accountsBalances` aggressively.** Add `await appState.recomputeAccountBalances()` to:
   - `AppState.loadProfile()` (right after the parallel fetch block lands `self.accounts` / `self.transactions`, around `:579-587`). One line. Closes the cold-start hole.
   - After each successful transaction insert: in `AppState.replaceOptimisticTransaction` OR inside the wizard's `performAdd`/`performEdit` after `transactionService.insert/update`. The cleanest hook is at the wizard level: fire `Task { await appState.recomputeAccountBalances() }` next to the existing `Task { await appState.refreshTransactionsListAfterSave() }` at `AddTransactionWizardView.swift:293`. One line.
   - Inside `AppState.logIncomeNudge` (after insert at `:823`). One line.
   - Inside `AppState.confirmPendingRecurring` (after `recurringService.confirmPending` at `:897-901`). One line.
   - Inside `AppState.contributeToGoal` (after `service.contribute` at `:1820-1828`). One line.

**Tier 1 alternative (architectural, eliminates whole class of bug):** make `accountsBalances` a computed property derived live from `appState.accounts` + `appState.transactions` instead of a cached `[UUID: Decimal]` private(set) var. Drop `recomputeAccountBalances()` entirely. Trade-off: a full fold of `transactions` runs on every read, but on iOS device the user's transaction count is small (typically <10k) and SwiftUI's @Observable will only re-read when downstream consumers diff. This is the cleaner long-term shape.

**Tier 2 — close the secondary GAPs:**

2. **Edit branch (Path B): drop the `isEditMode` guard OR replace with delta-aware check.** Current `AddTransactionWizardViewModel.swift:187` returns nil for any edit. Replace with the delta-math sketch in §4 so 20→200 edits trigger IBS while 20→10 edits don't.

3. **Goal contribute (Path K): add a balance check at `ContributeSheet.submit` OR inside `AppState.contributeToGoal`.** The 9.5c follow-up named in PHASE_T3_IBS_REDESIGN docs already calls for an "overpayment guard for goals." Implementation: before the insert, check `AccountBalanceEngine.balance(for: fromAccount, in: appState.accountsBalances) >= amount`, otherwise surface a toast or sheet. Cannot reuse IBS overlay directly (different host); simplest is a local "Insufficient balance in {accountName}" toast + early return.

4. **Pending recurring "Log it" (Paths I/J): same as K** — a local toast on overdraft inside `AppState.confirmPendingRecurring` / `logRecurringInstanceNow`. Auto-fire (Path H) is by-design silent per web parity; leave as-is unless product asks for change.

**Tier 3 — defensive polish:**

5. Add an `.onAppear { await appState.recomputeAccountBalances() }` to the wizard sheet's root in `AddTransactionWizardView.body`. Belt-and-suspenders even if Tier-1.1 ships.

6. Add a freshness timestamp + `Equatable` snapshot to `accountsBalances` so `validateBalance` can refuse to run if the cache is older than N seconds.

### Sizing

- **Tier 1 fix is 5 one-line changes across 2 files.** Tightly scoped. No new types, no UI changes. The single most impactful change is the wizard-side recompute call at `AddTransactionWizardView.swift:293` (1 line, kills the user's reported repro for FAB-new path).
- **Tier 1 alternative (computed property)** is a 1-file refactor in `AppState.swift` + delete of `recomputeAccountBalances` + careful audit of all 7 consumers of `accountsBalances` listed in §9 to confirm none rely on side-effects. Estimated effort: 1-2 hours plus regression check.
- **Tier 2** is 3 small modifications, each ~10-20 lines.
- **Tier 3** is sugar.

### Smallest possible PR that closes the user's bug

```diff
// AppState.swift, inside loadProfile(), after self.transactions = transactions
+ await recomputeAccountBalances()
```
AND
```diff
// AddTransactionWizardView.swift, performAdd(), around :293
- Task { await appState.refreshTransactionsListAfterSave() }
+ Task {
+     await appState.refreshTransactionsListAfterSave()
+     await appState.recomputeAccountBalances()
+ }
```
Two lines. Eliminates the cold-start case (empty-map → openingBalance fallback) AND the sequential-inserts-see-stale-balance case for the FAB path. Recommend shipping this immediately as a hotfix while the broader Tier-1.2/Tier-2/architectural refactor is scoped.
