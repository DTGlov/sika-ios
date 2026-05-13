# Phase T3 — IBS redesign + standalone reconcile sheet race fix

**Date:** 2026-05-13
**Branch:** `feature/transactions-t3-ibs-redesign`
**Approach:** Replace T3's divergent InsufficientBalanceSheet with a
web-aligned overlay (Top up / Use different account / Reconcile / Cancel,
no Log anyway). Migrate both wizard reconcile entries — IBS-Reconcile and
Step 1 ReconcileLink — to an in-wizard reconcile mode driven by
`AppState.reconcileContext` (no sheet dismiss/re-present, no 350ms detent
quirk). Fix the standalone reconcile sheet race from Accounts T1 as a
sibling fix in the same PR.

## What changed

### Reconcile sheet race fix (Accounts T1 hotfix)

Standalone reconcile entry from the Accounts tab scale icon used
`.sheet(isPresented:)` + a separate `@State reconcileTarget: Account?`.
Classic SwiftUI binding race: the bool flip and the target write are two
state updates; the sheet body's `if let acc = reconcileTarget` could read
nil on first evaluation, showing a blank/black sheet on first tap, and
the previous account's content on second tap.

Refactored `AccountsView` to use `.sheet(item: $reconcileContext)` with
a new `ReconcileContext: Identifiable` (in `Sika/Core/Models/`). Single
binding, no race. The `sikaBalance` is captured at button-tap time and
frozen on the context — matches web's behavior where the displayed
"Sika shows" value doesn't drift if balances recompute mid-flow.

`ReconcileAccountSheet` itself unchanged — props were already `let`, and
`@State` initialized inline at declaration site (no deferred
`.onAppear`-set state).

### IBS redesign

#### Architectural decisions

- **IBS is an inline `.overlay` on the wizard, NOT a second `.sheet`.**
  Mirrors web's pattern of never dismissing the main sheet during a
  remediation. Sidesteps the ~350ms detent re-present quirk that
  affected the prior T3 reconcile-from-IBS path.
- **Hard block on "Log anyway" override.** All `forceOverdraftSave`
  state and the override warning toast infrastructure
  (`pendingWarningToast`, `WarningToastEvent`, `WarningToastView`,
  `enqueueWarningToast`, `dismissWarningToast`) removed entirely.
- **State preservation matches web:** all remediations destructive
  on commit (original expense draft discarded). "Use different
  account" preserves wizard state, including the failing accountId.
- **Account exclusion matches web:** failing account stays selected
  in the chip strip, not filtered, not warning-marked.
- **Three content variants:** underwater (balance < 0) / empty
  (balance == 0) / insufficient (balance > 0 && amount > balance).
  Same three remediation rows across all variants.
- **Trigger moved to Next-tap:** Step 1's Next handler validates
  for expense; Step 2's Next handler validates for transfer (against
  the From account). Income and adjustment skip the check entirely.
  Exact-match `balance == amount` passes through.

#### In-wizard reconcile mode

Both wizard-side reconcile entries — IBS "Reconcile balance" and Step 1's
ReconcileLink shortcut — now write to `AppState.reconcileContext`. The
wizard's `.onChange(of: appState.reconcileContext)` calls
`viewModel.enterReconcileMode(accountId:)` to swap `selectedType` to
`.adjustment` and pre-fill the locked account. The wizard's `body`
renders `WizardReconcileMode` instead of the normal 3-step body when
`reconcileContext != nil`. The locked-account header, "Sika shows"
display, decimal-pad input, signed-diff card, and "Create adjustment"
save button live in `WizardReconcileMode`. The 3-dot step indicator,
Back button, and any in-step Cancel are HIDDEN in this mode — the only
escape mid-reconcile is whole-sheet dismiss (matches web's
`!reconcileContext` gate at transaction-sheet.tsx:708).

On reconcile commit: `AppState.reconcileAccountInline` inserts the
adjustment (same path as the standalone Accounts-tab reconcile —
adjustments don't fire the mutation chain), shows "Reconciled to
{amount}" toast, clears `appState.reconcileContext`, dismisses the
wizard. Original expense draft (if any) discarded — matches web's
`handleClose` after reconcile commit.

#### Polish divergences from web (audit-approved)

- `.transition(.move(edge: .bottom).combined(with: .opacity))` on the
  overlay — web has a hard cut, iOS slides up
- `.sensoryFeedback(.selection)` on row tap +  `.sensoryFeedback(.success)`
  on handler firing — web has no haptics
- `.ultraThinMaterial.opacity(0.6)` scrim — web is plain `bg-black/60`
- Single iOS bottom-sheet detent — no platform branching for centered
  desktop layout (web has `md:items-center`)

### Files

#### Added
- `Sika/Core/Models/ReconcileContext.swift` — shared `Identifiable`
  context for both the Accounts-tab `.sheet(item:)` and the in-wizard
  reconcile mode written via `AppState.reconcileContext`.
- `Sika/Features/Transactions/Components/InsufficientBalanceOverlay.swift`
  — new web-aligned overlay component. Houses the redefined
  `InsufficientBalanceContext` with fields renamed to `accountBalance` /
  `amountRequested` (parity with audit-named tokens). Three content
  variants, three remediation rows, scrim + transition + sensory feedback.
- `audits/PHASE_T3_IBS_REDESIGN_2026_05_13.md` — this record.

#### Modified
- `Sika/Features/Accounts/AccountsView.swift` — `.sheet(isPresented:)` →
  `.sheet(item: $reconcileContext)`. Row callback captures sikaBalance at
  tap time and stores it on the new `ReconcileContext`.
- `Sika/Features/Transactions/AddTransactionWizardView.swift` —
  - `onReconcileTap` parameter and the wizard-dismiss callback path
    removed entirely.
  - `forceOverdraftSave` `@State` removed. Override branch in
    `performSave` and warning-toast-after-save logic removed.
  - `.sheet(item: $ibsContext)` replaced with `.overlay { ... }`.
  - New Next-tap interception: `handleNextFromStep1` (expense) +
    `handleNextFromStep2` (transfer) run `validateBalance` and set
    `ibsContext` on detection — Save-tap check removed (web's `handleNext`
    is the trigger site).
  - New IBS handlers: `handleTopUp`, `handleUseDifferentAccount`,
    `handleReconcileFromIBS`.
  - New `.onChange(of: appState.reconcileContext)` calls
    `viewModel.enterReconcileMode(accountId:)`.
  - New `reconcileModeBody` + `WizardReconcileMode` private subview
    render reconcile UI inline in the wizard sheet.
  - New `performReconcileSave` commits via
    `AppState.reconcileAccountInline`, surfaces "Reconciled to
    {amount}" toast, clears `appState.reconcileContext`, dismisses.
  - `.onDisappear` clears `appState.reconcileContext` so the next
    wizard presentation doesn't inherit it.
- `Sika/Features/Transactions/AddTransactionWizardViewModel.swift` —
  - `InsufficientBalanceContext` field rename: `currentBalance` →
    `accountBalance`, `attemptedAmount` → `amountRequested` (parity
    with the new audit-derived overlay tokens).
  - New `reconcileActualString`, `reconcileActualDecimal`,
    `reconcileDiff(sikaBalance:)`, `canSaveReconcile(sikaBalance:)`
    helpers for the in-wizard reconcile step.
  - New `enterReconcileMode(accountId:)` — mirrors web's pre-fill
    `useEffect` at transaction-sheet.tsx:122-127.
- `Sika/Features/Transactions/Step1/AddTransactionStep1View.swift`
  (`Step1Content`) — `onReconcileTap` parameter dropped. ReconcileLink
  callback now writes directly to `appState.reconcileContext`. Stale
  "Reconcile coming soon" toast removed.
- `Sika/Features/Transactions/Components/Step1/ReconcileLink.swift` —
  docstring updated to describe the in-wizard handoff.
- `Sika/Features/Shell/AuthenticatedRootView.swift` —
  `reconcileTarget` / `isReconcileFromWizardPresented` `@State` +
  the `.sheet(isPresented: $isReconcileFromWizardPresented)` block +
  the wizard's `onReconcileTap` callback all removed. `WarningToastView`
  overlay removed.
- `Sika/Core/State/AppState.swift` — new
  `var reconcileContext: ReconcileContext? = nil`. `pendingWarningToast`,
  `enqueueWarningToast`, `dismissWarningToast`, `WarningToastEvent`
  struct all removed.
- `audits/PHASE_T3_FIX_2026_05_13.md` — marked superseded; reconcile
  portion still correct.

#### Deleted
- `Sika/Features/Transactions/Components/InsufficientBalanceSheet.swift`
  — replaced by `InsufficientBalanceOverlay.swift`.
- `Sika/Core/UI/Toast/WarningToastView.swift` — no longer needed without
  the Log anyway override path.

## Pending follow-ups (post-dogfood)

- **9.5b reconcile momentum unification** — `awardMomentum(.accountReconciled)`
  + `checkAndUnlockBadges(.accountReconciled)` should fire from both
  reconcile paths (standalone Accounts-tab sheet AND in-wizard reconcile
  mode). Both now route through `AppState.reconcileAccountInline`, so
  the unification is a single-site fix.
- **9.5c overpayment guard for goals** — paid-from-target overdraft
  warning is independent of IBS (different account math).
- **News image bug** — unrelated to T3.
