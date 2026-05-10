# Phase REC_1 — Recurring Tab UI — 2026-05-10

Implementer: Claude Code
Source-of-truth audit: `/audits/RECURRING_TAB_2026_05_10.md` (web — not present in iOS repo at PR time; the prompt's inline spec served as the working blueprint)

Phase 7 already shipped the recurring engine (`RecurringDateMath` date math, auto-log generation, confirm/skip helpers, IncomeNudgeService side). This phase ships the dedicated /recurring tab surface — list with Recurring/Paused tabs, add/edit form sheet, pause/resume, soft delete, manual sync, intro hint, quick templates, and per-recurring detail page with Log/Skip CTAs.

## What Shipped

### Models
- `Models/JoinedRefs.swift` — shared `JoinedAccountRef` / `JoinedCategoryRef` / `JoinedBucketRef` projections (Codable + Equatable + Hashable + Identifiable). Reusable across tabs that need PostgREST embeds.
- `Models/RecurringTransaction.swift` — extended with optional `account: JoinedAccountRef?` and `category: JoinedCategoryRef?` joined fields. Existing fetches that don't request the embed see nil; new `fetchAll` populates them. Added `Hashable` conformance for `navigationDestination(item:)`.
- `Models/QuickTemplate.swift` — new struct + `QuickTemplates.all` (5 hardcoded entries).

### Engine (`RecurringDateMath`)
Phase 7 already had `nextDueDate`, `nextWeekday`, `nextBiweeklyDate`, `nextMonthlyDate`, `monthlyDate`, `nextYearlyDate`. Added:
- `formatScheduleSummary(_:)` — "15th of each month", "Every Mon", "Every other Wed", "Last day of each month", "Annually on Mon d", etc.
- `currentInstancePeriod(_:today:)` — returns `(start, end)` date strings for the period containing today (week/biweek for weekly, full calendar month for monthly; nil for daily/yearly).
- `isHandledThisInstance(_:today:)` — predicate driving the "Handled" pill on cards. Non-auto-log only; checks whether `lastGeneratedDate` falls in the current period.
- `dueDateInfo(_:today:)` — returns `DueDateInfo` (label / colorHex / isBold) for the card's due-date strip. Handles OVERDUE / TODAY / Tomorrow / "in N days" / "Mon d" / "Mon d, yyyy" per audit Section 3.
- New `DueDateInfo` struct.
- Also added `RecurringFrequency.displayLabel` extension.

### Service (`RecurringService`)
Phase 7 had `dueRecurring`, `generateAndCollectPending`, `confirmPending`, `skipPending`, `insertAutoLoggedTransaction`, `updateLastGeneratedDate`. Added:
- `fetchAll(userId:)` — joined fetch (account + category + bucket) for the list page. FK shorthand resolves cleanly here (recurring_transactions has only one FK to accounts and one to categories, so no PGRST200 disambiguation is needed).
- `create(payload:)` and `update(id:payload:)` — backed by a new `RecurringPayload` struct mirroring the table's row shape.
- `setPaused(id:isPaused:)` — single-column update.
- `softDelete(id:)` — sets `is_active = false`. Already-generated transactions are kept (web's FK on `transactions.generated_from_recurring` doesn't fire on UPDATE).
- `syncNow(userId:)` — calls the existing `generateAndCollectPending` to materialize any missed auto-logs.
- `logInstanceNow(userId:recurring:dueDate:)` — alias of `confirmPending` for the detail page's "Log this instance now" CTA.
- `skipPeriod(recurringId:dueDate:)` — alias of `skipPending` for the detail page's "Skip this period" CTA.

### State (`AppState`)
Added:
- Nested `RecurringTab` enum (`.expense` / `.paused`)
- `recurringList: [RecurringTransaction]`, `recurringTab`, `recurringLoading`, `recurringSyncing`
- Computed: `expenseRecurrings` (sorted by next due date asc), `pausedRecurrings` (sorted by `updatedAt` desc)
- Actions: `loadRecurrings()`, `togglePaused(_:)` (optimistic with revert on failure), `deleteRecurring(_:)` (soft delete + local removal), `syncRecurringNow()` (with spinner state), `logRecurringInstanceNow(_:dueDate:)`, `skipRecurringPeriod(_:dueDate:)`, `reloadRecurringsAfterFormSave()`
- Private `recurringWith(_:isPaused:)` helper — rebuilds the immutable struct with one field swapped (all model fields are `let`, so a synthesized memberwise init gets used).

### Components
Under `Features/Recurring/List/`:
- `RecurringCardView.swift` — 2-section card per audit Section 3. Top strip with due-date label + Handled / Nudge pill; body row with dot + name + meta on tappable left, amount + 3-button row (pause/resume / edit / delete) on right.
- `RecurringTabsView.swift` — 2-tab segmented strip with count chips. Red accent (#F43F5E) for Recurring, amber accent (#FBBF24) for Paused.
- `QuickTemplatesStrip.swift` — 5 hardcoded chips + "For income, manage your sources in Settings → Income." footer.

Under `Features/Recurring/Form/`:
- `FrequencyChipsView.swift` — 5-chip 3-column grid; active styling green #00D9A3 border + 10% bg + green fg.
- `DayOfWeekPickerView.swift` — 7-button row (S/M/T/W/T/F/S labels, full-name accessibility); active is solid green.
- `DayOfMonthPickerView.swift` — number input (1–28, clamped on input via `onChange`) + Last-day toggle. Both bind to the same `selectedDay: Int?` state. -1 means "last day".
- `RecurringFormSheet.swift` — bottom sheet at `.large` detent. Field order matches audit Section 4. Validates `canSubmit` (amount > 0, account selected, schedule_day required for weekly/biweekly/monthly). Non-optimistic submit with spinner on the button. Toast on success/error. Pre-fills from `editingItem` (edit) or `templateDefaults` (template tap). Paused toggle visible only on edit.

Under `Features/Recurring/`:
- `RecurringDetailView.swift` — NavigationStack push destination. Summary card + "THIS PERIOD" section + Log/Skip CTAs (only when `!autoLog && !isHandled && !isPaused`); status card otherwise. Toasts on action; pops back on success.
- `RecurringView.swift` — orchestrator. Header (title + sync button + Add button), `recurring_intro` HintCard, tabs view, list (skeleton / empty state with optional CTA / day cards), Quick Templates strip on the Recurring tab only. Owns sheet/alert/navigation state.

### Wiring
- `Features/Shell/AuthenticatedRootView.swift` — `case .recurring:` now renders `NavigationStack { RecurringView() }` (replaced `RecurringTabPlaceholder()`). NavigationStack wrap enables `navigationDestination(item:)` for the detail page push.

## Locked architectural decisions

- **Single phase, ~12 files.** No sub-phases.
- **New rows always type=.expense.** No type picker. Income recurrings are legacy — type stays editable only when `editingItem.type == .income` (the form preserves it via `editingItem?.type ?? .expense`).
- **Two tabs.** Recurring (type=.expense AND !isPaused) / Paused (any type, isPaused). Counts client-side from the loaded list.
- **Soft delete via `is_active = false`.** Already-generated transactions kept.
- **Optimistic UI on pause/resume; non-optimistic on save.** Form sheet shows a spinner on the submit button until the round-trip resolves.
- **scheduleDay is a single Int? on the model.** Per-frequency semantics (weekly/biweekly: 0–6 Sun=0; monthly: 1–28 or -1 for last day; daily/yearly: unused).
- **Day-of-month cap is 28.** Clamps on input via `onChange(of:)`.
- **canSubmit gate**: amount > 0 + account selected + (schedule_day required for weekly/biweekly/monthly only).
- **Form is bottom sheet** (iOS idiom); web uses centered Dialog. Detent: `.large`.
- **Detail view is NavigationStack push.** Web uses `/recurring/[id]` route; iOS uses `navigationDestination(item:)` keyed on `RecurringTransaction`.
- **NO mutation hooks anywhere.** Create / edit / pause / resume / delete / sync / log / skip do NOT tick streaks/momentum/badges. Matches web exactly.
- **Manual sync icon** uses SwiftUI's `rotationEffect` + repeating animation (iOS 17 compatible — `.symbolEffect(.rotate, ...)` is iOS 18+).
- **Frequency chip active styling: green** (NOT gold) — different from Transactions tab's gold accents, matches web's recurring-form chip palette.
- **Quick templates: 5 hardcoded entries.** All monthly. Only "Utility bill" has `auto_log = false`.
- **Delete confirmation**: SwiftUI `.alert(_:isPresented:presenting:)`. Copy: "Delete this recurring transaction? Already-generated transactions are kept."

## Adaptations from the prompt's blueprint

1. **`amount: Double` → `Decimal`** (iOS Phase 7 convention). The `RecurringPayload` Encodable also uses Decimal.
2. **`@Published` on AppState → `@Observable` `private(set) var`** (Phase precedent).
3. **`AuthenticatedShell` with SwiftUI `TabView`** is wrong for iOS — iOS uses a custom `MainTabBar` in `AuthenticatedRootView`. Just replaced the `case .recurring:` placeholder.
4. **`RecurringEngine` namespace** doesn't exist in iOS — Phase 7 named the namespace `RecurringDateMath`. Extended that instead of renaming; saves churn on Phase 7 callers (RecurringService, AppState's existing pendingRecurring path).
5. **`AccountRef` / `Category` joined types** were prompt-blueprint placeholders. Created `JoinedAccountRef` / `JoinedCategoryRef` / `JoinedBucketRef` in a shared file under `Models/JoinedRefs.swift` so the Transactions tab T2 can reuse them when it lands.
6. **`JSONDecoder.supabase`** — not present in iOS; the Supabase SDK's default decoder works because all date-shaped fields on RecurringTransaction are already Strings (per Phase 9's Goal.deadline lesson) and timestamps (`createdAt` / `updatedAt`) are nullable Date? with ISO8601 default decoding.
7. **`AmountKeypad` from Transactions T2** — explicitly skipped per the prompt; used a plain `TextField` with `.keyboardType(.decimalPad)`.
8. **iOS `Account` has `archived`**, not `isArchived`. Filter sites adjusted.
9. **iOS `Account` has `accountType`**, not `type`. Embed select uses `account_type`.
10. **iOS `BudgetBucket` has only `id` + `name` + `sortOrder`** — no `color` field. The card-view bucket-tinting uses SikaTheme bucket tokens at the view layer rather than a row-supplied color.
11. **`.symbolEffect(.rotate, ...)` is iOS 18+** — used `rotationEffect(.degrees(...))` + repeating linear animation instead. Same visual result on iOS 17.6.
12. **Hashable conformance** — added to `RecurringTransaction` and `JoinedAccountRef`/`JoinedCategoryRef`/`JoinedBucketRef` so `navigationDestination(item:)` accepts the type.
13. **Toast API** — iOS has `ToastManager` (Observable) accessed via `@Environment(ToastManager.self) private var toasts` and `toasts.show(message, kind:)`. Used throughout for save / pause / delete / sync feedback.

## Behavioral notes

- **Initial load**: orchestrator's `.task` only fires `loadRecurrings()` if the list is empty. Tab switches don't refetch.
- **Pause toggle**: optimistic — flips the in-memory flag, fires the write, reverts on error.
- **Soft delete**: confirmation alert → `softDelete` → local removal. Already-generated transactions remain.
- **Sync**: `recurringSyncing` flag drives the rotation animation. Reload happens after success to pick up new `lastGeneratedDate` timestamps.
- **Detail page Log**: calls `logRecurringInstanceNow` → toast → `dismiss()` pops back.
- **Detail page Skip**: same shape with `skipRecurringPeriod`.
- **Quick template tap**: opens form sheet with `frequency` / `autoLog` / `note` pre-filled; user fills `amount` + `account_id` + (if monthly) `schedule_day`.
- **Empty states**: Recurring tab shows CTA "Add expense"; Paused tab is read-only.

## Out of scope

Permanently (does not exist on web):
- Tab badge counts on the bottom tab bar
- Pull-to-refresh on this page
- Hard delete / undo
- Snooze / time-shift affordances
- Bulk operations
- CSV export
- Real-time Supabase subscriptions
- `streaks_intro` / mutation hooks on log/skip
- Income recurring CRUD (legacy; Settings → Income is the canonical surface)
- `IncomeAutoLogConfirmAlert` (only fires when editing legacy income; not needed for v1)

Deferred (later phases):
- Push notifications when due (separate subsystem)
- Custom AmountKeypad
- Settings tab full rebuild — for now the "Settings → Income" footer link is a styled hint only (no navigation).
