# Transaction Model Inspection — 2026-05-07

Auditor: Claude Code (read-only)
Purpose: Verify iOS data layer alignment with web's savings bucket
+ WeeklyChart math, ahead of Phase 3 fix prompt.

---

## 1. Transaction Model

File: `Sika/Core/Models/Transaction.swift`

### Properties

| Line | Property | Type | CodingKey |
|------|----------|------|-----------|
| 4 | `id` | `UUID` | `id` |
| 5 | `userId` | `UUID` | `user_id` |
| 6 | `type` | `TransactionType` | `type` |
| 7 | `amount` | `Decimal` | `amount` |
| 8 | `accountId` | `UUID` | `account_id` |
| 9 | `fromAccountId` | `UUID?` | `from_account_id` |
| 10 | `categoryId` | `UUID?` | `category_id` |
| 11 | `goalId` | `UUID?` | `goal_id` |
| 12 | `transactionDate` | `String` | `transaction_date` |
| 13 | `note` | `String?` | `note` |
| 16 | `isActive` | `Bool?` (deprecated) | `is_active` |
| 17 | `softDeleted` | `Bool?` | `soft_deleted` |
| 18 | `generatedFromRecurring` | `UUID?` | `generated_from_recurring` |
| 19 | `createdAt` | `Date?` | `created_at` |
| 20 | `updatedAt` | `Date?` | `updated_at` |

Local-only:
- Line 42: `var isPending: Bool = false` — not in CodingKeys; never decoded/encoded.

Computed properties:
- Line 44: `var displayAmount: Decimal { amount }` — currently a passthrough.

### `paidFromGoalId` field: **NOT PRESENT**

Evidence: lines 4–20 list every property; no `paidFromGoalId`. Lines 22–38 list every CodingKey; no entry mapping to `"paid_from_goal_id"`. The only goal-related field is `goalId` at line 11 (CodingKey `"goal_id"`, line 30).

Decoding behavior: PostgREST returns all columns by default (TransactionService uses bare `.select()`). When the server includes a `paid_from_goal_id` column, Swift's `Codable` ignores keys that aren't in the model's `CodingKeys` enum. So no decode error, but **the field is silently dropped** — every iOS Transaction has zero knowledge of paid-from-goal status.

### Goal-field nullability

- `goalId: UUID?` (line 11) — optional, matches web's nullable column.

### Verbatim source

```swift
struct Transaction: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    let type: TransactionType
    let amount: Decimal
    let accountId: UUID
    let fromAccountId: UUID?
    let categoryId: UUID?
    let goalId: UUID?
    let transactionDate: String
    let note: String?
    /// DEPRECATED: transactions table has no is_active column. Optional so
    /// decoding tolerates the missing key. Remove when no callsites set it.
    let isActive: Bool?
    let softDeleted: Bool?
    let generatedFromRecurring: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case amount
        case accountId = "account_id"
        case fromAccountId = "from_account_id"
        case categoryId = "category_id"
        case goalId = "goal_id"
        case transactionDate = "transaction_date"
        case note
        case isActive = "is_active"
        case softDeleted = "soft_deleted"
        case generatedFromRecurring = "generated_from_recurring"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Local-only flag: true when this row is an optimistic insert not yet confirmed.
    /// Not in CodingKeys — never decoded from or encoded to Supabase.
    var isPending: Bool = false

    var displayAmount: Decimal { amount }
}
```

`TransactionDraft` (insert payload, lines 48–70) likewise has no `paidFromGoalId` field. No way for iOS to currently write a paid-from-goal expense.

---

## 2. paidFromGoal usages elsewhere

`grep -rn "paid_from_goal\|paidFromGoal" Sika/ --include="*.swift"` →

```
NONE FOUND
```

Zero references anywhere in iOS source — no model field, no service column-list, no calculator filter, no view, no comment. This concept does not exist in iOS yet.

---

## 3. Account Model

File: `Sika/Core/Models/Account.swift`

### accountType field

- Line 11: `let accountType: AccountType` (Codable, `Equatable`, `Hashable`).
- Line 25 CodingKey: `case accountType = "account_type"`.

### AccountType enum cases (line 4)

```swift
enum AccountType: String, Codable, CaseIterable {
    case general, wallet, cash, savings, investment, other
}
```

Cases: `general`, `wallet`, `cash`, **`savings`**, **`investment`**, `other`.

- Has `.savings`: **YES** (line 4: `case general, wallet, cash, savings, investment, other`)
- Has `.investment`: **YES** (same line)

### Existing "is savings account" helper

**NONE.** No method or computed property on `Account` or `AccountType` answers "is this a savings/investment account?" — see grep results in Section 4.

### Verbatim source

```swift
enum AccountType: String, Codable, CaseIterable {
    case general, wallet, cash, savings, investment, other
}

struct Account: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let accountType: AccountType
    /// Lucide icon name OR emoji glyph; resolve via IconResolver.
    /// Optional so decoding tolerates rows without an icon column.
    let icon: String?
    let balance: Decimal?
    let isDefault: Bool?
    let archived: Bool?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case accountType = "account_type"
        case icon
        case balance
        case isDefault = "is_default"
        case archived
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

---

## 4. Savings-account type predicates

`grep -rn "\.savings\|\.investment\|account_type\|SAVINGS_ACCOUNT_TYPES" Sika/ --include="*.swift"` →

```
Sika/Core/Models/Account.swift:25
  case accountType = "account_type"
Sika/Core/Calculators/BucketSpendCalculator.swift:70
  BucketRow(name: "Savings", spent: spent["savings"] ?? 0, limit: limits["savings"] ?? 0, color: .savings)
Sika/Core/Calculators/BucketSpendCalculator.swift:92
  case .savings: return SikaTheme.Color.bucketSavings
Sika/Features/Home/AuthenticatedHomeView.swift:91
  savingsPercent: profile.savingsPercentValue
Sika/Features/Home/AuthenticatedHomeView.swift:95
  savingsPercent: profile.savingsPercentValue,
Sika/Features/Transactions/AddTransactionWizardView.swift:263
  previewAccount(name: "🐷 Savings", type: .savings),
Sika/Features/Transactions/Components/Step1/AccountChipsRow.swift:78
  // Fallback to account_type mapping when icon column is null/empty.
Sika/Features/Transactions/Components/Step1/AccountChipsRow.swift:87
  case .savings: return "🐷"
Sika/Features/Transactions/Components/Step1/AccountChipsRow.swift:88
  case .investment: return "📈"
```

**No predicate exists** for "is this account savings/investment". All matches are:
- Bucket display strings (`name: "Savings"`)
- BucketColor enum cases (display tint, not account-type)
- Profile percent fields (`savingsPercent` — bucket percent, not account)
- Preview/seed data (`previewAccount(... type: .savings)`)
- Emoji fallback mapping in `AccountChipsRow`

There is **no `SAVINGS_ACCOUNT_TYPES` constant**, no `Account.isSavingsLike` helper, no `[AccountType]` predicate set anywhere. Phase 3 needs to introduce one.

---

## 5. BucketSpendCalculator

File: `Sika/Core/Calculators/BucketSpendCalculator.swift`

### Current `compute()` signature (lines 22–31)

```swift
static func compute(
    transactions: [Transaction],
    categories: [TransactionCategory],
    budgetBuckets: [BudgetBucket],
    cycle: Cycle,
    monthlyIncome: Decimal,
    needsPercent: Decimal,
    wantsPercent: Decimal,
    savingsPercent: Decimal
) -> [BucketRow]
```

### Inputs

- `transactions: [Transaction]`
- `categories: [TransactionCategory]`
- `budgetBuckets: [BudgetBucket]`
- `cycle: Cycle`
- `monthlyIncome: Decimal`
- `needsPercent: Decimal`, `wantsPercent: Decimal`, `savingsPercent: Decimal`

### `accounts` parameter present: **NO**

The calculator has no way to look up account types. Implementing the savings-bucket Rule 2 (inbound transfers to savings/investment count as Savings spend) will require either passing `[Account]` or passing a precomputed `Set<UUID>` of savings-like account IDs.

### Current savings filter

The calculator does NOT have a separate savings filter. It applies one filter pipeline to all expense transactions and groups by `category.bucketId`:

```swift
// Lines 49–52
let cycleExpenses = transactions
    .filter { $0.type == .expense }
    .filter { $0.transactionDate >= startStr && $0.transactionDate <= endStr }
    .filter { $0.goalId == nil }
```

Then at lines 55–58:

```swift
for tx in cycleExpenses {
    guard let categoryId = tx.categoryId,
          let bucketName = categoryIdToBucketName[categoryId] else { continue }
    spent[bucketName, default: 0] += tx.amount
}
```

**Two correctness issues visible already:**

1. The `goalId == nil` filter at line 52 is effectively a no-op for the spending pipeline. `goalId` is set on **transfers** that contribute TO a goal — but the pipeline already filters to `type == .expense` first. So no row reaches the `goalId == nil` filter with a non-nil `goalId`. The intent (per the comment at line 11: "excluding paid-from-target transactions (goalId set)") is **wrong**: the field that means "paid from goal's saved funds" is `paid_from_goal_id`, which iOS does not model.
2. Transfers to savings/investment accounts are never added to the Savings bucket. The pipeline rejects all non-`.expense` rows. Web's Rule 2 is missing entirely.

---

## 6. SpendCalculator.cycleSpent

File: `Sika/Core/Calculators/SpendCalculator.swift`

### Verbatim implementation (lines 50–61)

```swift
/// Cycle-bounded spent total (expense transactions in cycle).
/// Excludes paid-from-target transactions (goalId set) — those don't
/// count as net spend because the saving already accounted for them.
static func cycleSpent(transactions: [Transaction], cycle: Cycle) -> Decimal {
    let start = dateString(cycle.start)
    let end = dateString(cycle.end)
    return transactions
        .filter { $0.type == .expense }
        .filter { $0.transactionDate >= start && $0.transactionDate <= end }
        .filter { $0.goalId == nil }
        .reduce(Decimal(0)) { $0 + $1.amount }
}
```

### Filter on goal: uses `goalId == nil`

### Correctness: **WRONG**

Web filters `paid_from_goal_id == nil` (the column that flags "this expense was paid from a goal's saved funds"). The iOS filter at line 59 uses `goalId == nil`, which is a different concept (`goal_id` flags "this transfer contributes TO a goal" and is set only on transfers, never expenses).

Because the pipeline already filters `type == .expense` first, no expense row ever has `goalId` set, so the `goalId == nil` filter is a **no-op**. iOS currently includes paid-from-goal expenses in `cycleSpent`, double-counting against the user (they save into the goal, then the goal's spending is also counted as cycle spend).

The doc comment at lines 50–52 is also misleading — it asserts the filter "excludes paid-from-target transactions" but the filter doesn't actually do that.

---

## 7. Cycle Struct

File: `Sika/Core/Models/Cycle.swift`

### Properties (lines 5–9)

```swift
struct Cycle: Equatable, Hashable {
    let start: Date
    let end: Date
    let label: String
    let isCurrent: Bool
    ...
}
```

- Has `isCurrent: Bool`: **YES** (line 9)
- Has `end: Date`: **YES** (line 7)

### Cycle-aware "now" anchoring possible: **YES**

Both properties needed are present:

- `isCurrent` (line 9, set in `CycleCalculator` at lines 75 and 110 via `today >= start && today <= end`) tells the chart whether to clamp "now" against `min(today, cycle.end)` (current cycle) versus rendering a full historical cycle.
- `end: Date` provides the right boundary for the past-cycle case.

Computed property at lines 13–19 yields a stable `yyyy-MM-dd` `startDateString` if needed for chart caching keys.

---

## 8. Apple Charts

`grep -rn "import Charts" Sika/ --include="*.swift"` →

```
NONE FOUND
```

- Callsites: **0**
- Locations: NONE
- First-introduction in Phase 3: **CONFIRMED YES**

No existing dependency on Apple Charts framework anywhere in the iOS codebase. Phase 3's WeeklyChart will be the first `import Charts` in the project.

---

## 9. TransactionService Query

File: `Sika/Core/Services/TransactionService.swift`

### Verbatim `fetchAll` (lines 18–28)

```swift
/// Fetch all transactions for the current user, in date-descending order.
/// Used by AppState bootstrap and pull-to-refresh.
func fetchAll() async throws -> [Transaction] {
    let response: PostgrestResponse<[Transaction]> = try await client
        .from("transactions")
        .select()
        .order("transaction_date", ascending: false)
        .order("created_at", ascending: false)
        .execute()
    return response.value
}
```

### Select clause: bare `.select()` — pulls all columns

No column list. PostgREST returns every column on the `transactions` table including, presumably, `paid_from_goal_id` (silently dropped on decode — see Section 1).

### Joins account/to_account: **NO**

The query is single-table. No `from("transactions").select("*, account:accounts(*)")` or similar nested resource shape.

### Strategy for account-type lookup in iOS: **client-side dict via `appState.accounts`**

`AppState` already holds `accounts: [Account]` populated alongside transactions in the same `loadProfile` / `refreshHomeData` parallel fan-out. The Phase 3 calculator can take `[Account]` (or a precomputed `Set<UUID>`) and resolve `transaction.accountId` / `transaction.fromAccountId` to an `AccountType` in O(1) via a Dictionary.

No service-layer changes required for the lookup. No need to introduce nested PostgREST resource queries.

---

## Phase 3 Implementation Plan

Based on the findings above, the fix prompt needs to:

### Concrete code changes by file

1. **`Sika/Core/Models/Transaction.swift`** — Add the missing field
   - Insert `let paidFromGoalId: UUID?` (place after `goalId` for clarity at line 11).
   - Add `case paidFromGoalId = "paid_from_goal_id"` to the `CodingKeys` enum (after `goalId` at line 30).
   - Optional but recommended: also add to `TransactionDraft` so iOS can write paid-from-goal expenses if/when the wizard supports a "spend from goal" flow.

2. **`Sika/Core/Calculators/SpendCalculator.swift`** — Fix the `cycleSpent` filter
   - Replace `.filter { $0.goalId == nil }` (line 59) with `.filter { $0.paidFromGoalId == nil }`.
   - Update the doc comment at lines 50–52 to accurately describe what the filter does.

3. **`Sika/Core/Calculators/BucketSpendCalculator.swift`** — Fix the bucket math, add Rule 2
   - Replace `.filter { $0.goalId == nil }` (line 52) with `.filter { $0.paidFromGoalId == nil }`.
   - Add `accounts: [Account]` parameter to `compute()`.
   - After the existing per-bucket expense aggregation, add a second pass:
     - Filter transactions by `type == .transfer`
     - Filter by `transactionDate` in cycle window
     - Look up `accountId` (the destination — per `Transaction.swift` semantics confirmed during diagnostic phase, `accountId` is the destination on transfers and `fromAccountId` is the source)
     - If destination account's `accountType` is `.savings` or `.investment`, add `tx.amount` to `spent["savings"]`.
   - Update `BucketStrip` callsite in `AuthenticatedHomeView.swift` (lines 79-99 region) to pass `appState.accounts`.

4. **`Sika/Core/Models/Account.swift`** — Add a savings-account predicate
   - Add `var isSavingsLike: Bool { accountType == .savings || accountType == .investment }` on `Account`, OR a static set on `AccountType`: `static let savingsLike: Set<AccountType> = [.savings, .investment]`. The latter is more reusable from contexts that don't have the full Account struct.

5. **`Sika/Features/Home/Components/WeeklyChart.swift` (new)** — First Charts integration
   - `import Charts`
   - Take `transactions: [Transaction]`, `cycle: Cycle`, `currencyCode: String`
   - Cycle-aware "now" anchor: if `cycle.isCurrent`, clamp the upper bound to `min(today, cycle.end)`; else render the whole cycle window.
   - Aggregate expense amounts (already filtered for `paidFromGoalId == nil`) into 7 weekly buckets within the cycle.
   - Use SwiftUI Charts' `BarMark` or `LineMark` per the visual spec (TBD — Phase 3 prompt should lock visual choice).
   - Wire below `BucketStrip` in `AuthenticatedHomeView`.

### Preview-helper compile fixes

After adding `paidFromGoalId: UUID?` to Transaction, search for any `Transaction(...)` memberwise inits that need updating. Likely just one in `AddTransactionWizardViewModel.swift` (Step 3 save flow). Add `paidFromGoalId: nil` to those callsites.

### Top-of-mind concrete deliverables

- **iOS Transaction model gains `paidFromGoalId: UUID?`** (closes the silent-drop gap from Section 1).
- **`SpendCalculator.cycleSpent` and `BucketSpendCalculator` switch from the no-op `goalId == nil` filter to the correct `paidFromGoalId == nil` filter.** This will materially change the displayed numbers for users who have paid-from-goal expenses.
- **`BucketSpendCalculator` accepts `[Account]` and adds Rule 2**: inbound transfers to savings/investment accounts contribute to the Savings bucket spend within the cycle.
- **`WeeklyChart`** is the first `import Charts` callsite; takes cycle + transactions and uses `cycle.isCurrent` + `cycle.end` for now-anchoring.
- **`AccountType.savingsLike` (or `Account.isSavingsLike`)** as a reusable predicate.

### Risk areas

- **Behavioral delta is non-zero**: currently iOS includes paid-from-goal expenses in `cycleSpent` (because the filter is a no-op). After the fix, those expenses will be excluded. Users will see their "Spent" number drop. The PR description should call this out so the change isn't mistaken for a regression.
- **Transfer direction semantics**: the iOS transfer convention (per the `AddTransactionWizardViewModel` switch we audited in earlier phases) is `accountId = destination`, `fromAccountId = source`. The Rule 2 lookup must use `accountId` as the destination. Confirm this against any future schema changes.
- **`paid_from_goal_id` column existence**: this audit assumes web's column exists in the live database. If the iOS-pointed Supabase project hasn't applied the migration that adds it, the model field will always decode as nil and Phase 3's behavior change won't fire. Worth a quick `psql \d transactions` check before merging the fix.
- **`BudgetBucket` join in queries**: out of scope for Phase 3 per current state. Bucket name resolution stays via the in-memory `appState.budgetBuckets` lookup added in Phase 2.
- **Charts framework + iOS 17.6 deployment target**: SwiftUI Charts is iOS 16+, so 17.6 is fine. No back-deploy concerns.
- **WeeklyChart visual spec**: not specified in this audit's source. Phase 3 prompt needs to lock bars vs. lines, color, axis labels, and overspend visual treatment before implementation.
