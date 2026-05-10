# Phase Accounts T1 — Accounts Tab UI + Reconcile + Delete-with-Reassign — 2026-05-12

Implementer: Claude Code
Source-of-truth audit: `/audits/ACCOUNTS_TAB_2026_05_12.md` (web — not present in iOS repo at PR time; the prompt's inline spec served as the working blueprint)

This is the final placeholder tab on iOS. After this lands, **all 5 tabs render real surfaces** (Home / Transactions / Accounts / Goals / Recurring). The Accounts tab includes list view + Add/Edit modal + inline reconcile expander + standalone reconcile sheet + delete-with-reassign + balance computation engine.

## What Shipped

### Models
- `Models/Account.swift` — substantial rewrite to match web's schema:
  - **AccountType** cases changed from `general/wallet/cash/savings/investment/other` → `bank/momo/cash/savings/investment/other`. Custom `init(from decoder:)` maps legacy `general` → `.bank` and `wallet` → `.momo` so any existing iOS-created rows still decode. Standard encode produces canonical raw values.
  - Added `openingBalance: Decimal?` mapped to `opening_balance` column (replaces Phase 1.5's `balance: Decimal?` which mapped to a column that was never the right name).
  - Added `isActive: Bool?` mapped to `is_active` column (replaces Phase 1.5's `archived: Bool?` mapped to `archived` column — wrong column name lesson, like `fromAccountId` before T1).
  - Added `sortOrder: Int?` mapped to `sort_order`.
  - Added `color: String?` (dead-write column — set on save from `AccountTypeConfig.hexString`, never read).
  - `icon` is now also dead-write (was previously read by some surfaces; reads now go through `AccountTypeConfig.emoji`).

### Engine + Service
- `Services/AccountBalanceEngine.swift` (new) — pure helper. Mirror of web's `computeAccountBalances`. Uses `Decimal` (iOS convention). Sign rules: income +, expense −, transfer −/+ (FROM/TO), adjustment + (signed). Seeds with `openingBalance ?? 0`.
- `Services/AccountService.swift` — full rewrite:
  - `fetchAll()` now filters `is_active=true` and orders by `sort_order` then `created_at`.
  - `countTransactionsReferencingAccountId(_:)` — pre-delete count for the reassign overlay.
  - `reassignTransactions(from:to:)` — bulk update of `transactions.account_id`.
  - `delete(id:)` — hard delete.
  - `clearAllDefaults(userId:)` — step 1 of two-step single-default enforcement.
  - `create(payload:)` + `update(id:payload:)` with explicit Encodable structs (`AccountInsert`, `AccountUpdate`).
  - `insertReconcileAdjustment(...)` — inserts an adjustment transaction with `category_id=null` and a "Reconciled to {amount}" note.
- `Services/TransactionService.swift` — added `fetchAllForBalances(userId:)` for the balance fold (no joins, no pagination, all rows for the user).

### State (`AppState`)
Added:
- `accountsBalances: [UUID: Decimal]` — derived map per render
- `totalActiveBalance: Decimal` computed
- `recomputeAccountBalances()` — pulls all transactions + folds via engine
- `reloadAccountsAndBalances()` — refreshes list + balances together (used after CRUD)
- `createAccount(...)` — single-default + first-account auto-default + `sort_order` derivation
- `updateAccount(...)` — single-default enforcement when promoting to default
- `reconcileAccountInline(...)` — inserts adjustment + recomputes balances
- `countTransactionsForAccount(_:)` — pre-delete probe
- `deleteAccountWithReassign(_:reassignTo:)` — bulk reassign + hard delete

### Components (`Features/Accounts/`)
- `AccountTypeConfig.swift` — 6-type config map (label / colorHex / emoji + `color: Color` + `hexString: String`).
- `AccountsView.swift` (orchestrator) — header (title + + Add gold pill), Total Balance card, two HintCards (`accountsIntro` conditional on all opening balances == 0; `accountsReconcileReminder` always), per-account `AccountRowView` list, empty state ("No accounts yet. Tap "Add" to create one."), 3 sheet wirings (form / reconcile / delete), simple-confirm Alert for accounts with zero transactions.
- `Components/AccountRowView.swift` — 2-section card per audit Section 3.1: top row (dot + emoji tile + name + Default pill + type label + ⚖️ ✏️ 🗑️ buttons; trash hidden when `isDefault==true`) + balance row. NO whole-card tap target.
- `Components/AccountFormSheet.swift` — bottom sheet for create + edit. Conditional rendering:
  - Opening balance label: `"Current balance — RIGHT NOW (${symbol})"` on create with helper text; `"Opening balance (${symbol})"` on edit, no helper text.
  - Active toggle + reconcile expander only render in edit mode.
  - Submit button hidden when reconcile expander is open.
- `Components/ReconcileAccountSheet.swift` — standalone reconcile sheet for the ⚖️ row icon. Shares submit logic with the inline expander via `appState.reconcileAccountInline`.
- `Components/DeleteAccountSheet.swift` — two-step delete flow when transactions exist: pick reassign target → confirmation Alert → bulk reassign + hard delete. Shows count "{N} transaction(s)" and target name in the confirm copy.

### Wiring
- `Features/Shell/AuthenticatedRootView.swift` — `case .accounts:` now renders `NavigationStack { AccountsView() }` (replaced `AccountsTabPlaceholder()`).

### Cross-tab consumer migrations (Account model rename ripple)
The `archived` → `isActive` rename touched 4 picker filter sites:
- `AddTransactionWizardViewModel.availableFromAccounts` / `availableToAccounts` (Phase 7)
- `TransactionFilterSheet` Account section (T1)
- `RecurringFormSheet` Account picker (Recurring)
- `GoalFormSheet` Save-to picker + default selection (Goals T1)
- `ContributeSheet` From-account exclusion (Goals T1)

Each switched from `$0.archived != true` → `$0.isActive != false`. Same semantic ("not archived").

`AccountType.general` / `.wallet` removed: 2 fallback emoji switches updated:
- `AccountChipsRow.fallbackEmoji` (Phase 7)
- `AddTransactionWizardView` preview-only mock data

## Locked architectural decisions

- **Direct Supabase reads/writes** via Swift SDK. No HTTP routes for Accounts.
- **`accounts.color` and `.icon` are dead-write columns** — set on save from `AccountTypeConfig`, never read. iOS rendering uses the config directly. Schema parity with web is preserved (we still write the values).
- **Running balance fully derived per render** via `AccountBalanceEngine.compute`. NO cached `current_balance` column.
- **`opening_balance` is one column with two labels**:
  - Add modal: `"Current balance — RIGHT NOW (${symbol})"` + helper text
  - Edit modal: `"Opening balance (${symbol})"` + no helper
  Editing it shifts the running balance by delta — correct because the engine seeds with `openingBalance` and folds transactions on top.
- **Two reconcile paths** (both insert an adjustment via `appState.reconcileAccountInline`):
  - Inline expander on the Edit form
  - Standalone sheet from the ⚖️ row icon
  **TODO Phase 9.5b**: both sites have a TODO comment to wire `awardMomentum(.accountReconciled)` + `checkAndUnlockBadges(.accountReconciled)`. The MomentumEventType enum already has `.accountReconciled` (+3 pts). The badge trigger doesn't (`BadgeTrigger.accountReconciled`'s `badgeIds` is `[]` per Phase 9), so badge step is technically a no-op until 9.5b adds qualifying badges.
- **Single-default constraint** enforced client-side via two-step write: `clearAllDefaults` then insert/update with `is_default=true`.
- **First account auto-defaulted** at insert time when `accounts.filter { isActive != false }.isEmpty` — fix-on-way for web TBD #4.
- **Soft archive** via `is_active=false`. NO restore UI. Archived accounts disappear from lists/pickers (consumers filter `isActive != false`).
- **Hard delete with reassign** — only updates `transactions.account_id`. FK errors on `transactions.to_account_id`, `goals.funding_account_id`, `recurring_transactions.account_id` surface as a generic "Failed to delete account" toast (matches web).
- **Per-row card has NO whole-card tap target** — every action goes through one of the icon buttons.
- **Trash icon hidden when `is_default=true`** — user must promote a different account first.
- **Sort by `sort_order` asc, then `created_at` asc** — creation order.
- **HintCards**: `accountsIntro` only when `accounts.length > 0 && every(opening_balance == 0)`; `accountsReconcileReminder` always.
- **Empty state bare** — "No accounts yet. Tap "Add" to create one." Centered muted text.
- **NO mutation hooks** on any path in T1 (configuration paths don't tick; reconcile momentum stubbed for 9.5b).

## Adaptations from the prompt's blueprint

1. **`@Published` AppState → `@Observable` `private(set) var`** (Phase precedent).
2. **`profile?.id` → `session?.user.id`** (iOS uses AuthFlow case).
3. **`Double` amounts → `Decimal`** throughout. Engine, payloads, and view formatting all use Decimal; UI animation values bridge via `NSDecimalNumber.doubleValue` where needed (none required this PR).
4. **`mutationCount` doesn't exist on iOS** — refresh via `recomputeAccountBalances()` + `reloadAccountsAndBalances()` directly.
5. **`AppState.openReconcileSheet` / TransactionSheet reconcile mode** doesn't exist on iOS — T1 (transactions list) is read-only; there's no unified TransactionSheet from T1. Built a dedicated `ReconcileAccountSheet` for the standalone path. Same submit logic as the inline expander.
6. **`AuthenticatedShell` doesn't exist on iOS** — wired in `AuthenticatedRootView` with custom `MainTabBar`.
7. **iOS `AccountType` cases were `general`/`wallet`** — aligned to web's `bank`/`momo`. Custom `Decodable` keeps backward compat for any existing rows. Existing consumers (3 fallback emoji switches + 1 mock data block) updated.
8. **Phase 1.5's `archived` and `balance` columns** were misnamed — fixed to web's `is_active` and `opening_balance`. Same lesson as `fromAccountId` → `toAccountId` from T1. No existing consumers were reading these for behavioral logic (all just filtered or displayed defaults), so the migration is non-breaking.
9. **`JSONDecoder.supabase`** doesn't exist on iOS — using `PostgrestResponse<[Account]>.value` direct decoding.

## Behavioral notes

- **Initial balances load**: orchestrator's `.task` calls `recomputeAccountBalances()`. Subsequent reloads happen after every CRUD via `reloadAccountsAndBalances()`.
- **Add account**: when accounts list is empty, the toggle is moot — first account becomes default regardless of user choice. Subsequent accounts respect the toggle but trigger `clearAllDefaults` first if turning ON.
- **Edit → flip is_default ON**: previous default loses its star (server-side via `clearAllDefaults`); UI reload picks up both rows' new state.
- **Edit → flip is_active OFF**: account removed from all pickers immediately; row hidden from list immediately.
- **Inline reconcile**: opening the expander hides the Save Changes button (web parity — prevents accidental save of two changes at once).
- **Empty actual balance + diff card**: card only appears when input is non-empty.
- **Diff = 0**: submit shows "Balance already matches" toast (no DB write).
- **Standalone reconcile**: same submit path; sheet dismisses on success after toast.
- **Delete with zero transactions**: simple confirmation Alert, immediate hard delete.
- **Delete with transactions**: full reassign sheet → pick target → confirm Alert with explicit count + target name → bulk reassign + delete.
- **FK error on delete**: generic "Failed to delete account" toast (matches web). User must manually clean up references in goals / recurring / transfers.

## Out of scope (Phase 9.5b / future)

- **Reconcile momentum chain** (both paths): `awardMomentum(.accountReconciled)` + `checkAndUnlockBadges(.accountReconciled)`. TODO comments are at both sites in `AccountService.insertReconcileAdjustment` and `AppState.reconcileAccountInline`.
- **Archive restore UI** — matches web (dead-letter once archived).
- **Per-account history / detail page** — not on web either.
- **FK cascade error UX** — currently surfaces a generic toast; could enumerate the blocking surfaces and direct user to fix them.
- **Drag-handle reorder** of `sort_order`.
- **Per-account currency override / daily limits** — out of scope.
