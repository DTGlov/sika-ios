# Phase 9.5a (fix-up) — /health detail Explore section — 2026-05-12

Implementer: Claude Code
Source-of-truth: `/audits/PHASE_9_MVP_FIX_2026_05_08.md` (Phase 9 model)
Predecessor: `/audits/PHASE_9_5A_FIX_2026_05_12.md` (initial 9.5a ship
that missed this section)

The initial 9.5a ship of `HealthDetailView` shipped the score hero,
stat tiles, factor breakdown, and how-this-works footer — but left
the Explore section unbuilt. Without it, /health detail felt like a
dead end. This PR closes the gap.

## What Shipped

### Components
- `Features/Health/Components/ExploreCardView.swift` (new) — single
  reusable tile used by the 2×2 grid. Chrome:
  - 16pt radius, 1pt muted border
  - 16h / 12v padding
  - Left cluster: 16pt SF Symbol in card-specific color + label in
    muted color (labels are NOT tinted to the card color — matches
    web's behavior)
  - Right: small chevron in heavily-muted color
  - `.buttonStyle(.plain)` so the row tap is a single hit area

### Placeholder destinations
9.5b replaces each with a real surface. The wrappers exist so the nav
glue in `HealthDetailView` doesn't have to change later.

- `Features/Health/Placeholders/HealthPlaceholderShell.swift` (new) —
  shared shell: large 48pt centered icon + title + one-line "Coming
  soon" copy. `.navigationTitle(title)` so the back chevron shows the
  destination name.
- `Features/Health/Placeholders/StreakDetailPlaceholderView.swift` (new)
  — flame.fill icon in #F97316 orange, title "Streaks", copy "Coming
  soon — detailed streak history and milestones."
- `Features/Health/Placeholders/MomentumDetailPlaceholderView.swift`
  (new) — rosette icon in #D4AF37 gold-amber, title "Momentum", copy
  "Coming soon — your full momentum history and tier progress."
- `Features/Health/Placeholders/BadgesGridPlaceholderView.swift` (new)
  — chart.line.uptrend.xyaxis icon in #A78BFA purple, title "Badges",
  copy "Coming soon — earned badges and locked achievements."

### Detail view + navigation glue
- `Features/Health/HealthDetailView.swift` — added:
  - `let onSwitchToTab: (MainTab) -> Void` constructor param (closure
    threaded from `AuthenticatedRootView`)
  - `exploreSection` view: 2-column `LazyVGrid` with 8pt inter-card
    spacing, 4 `ExploreCardView`s in order Streaks → Momentum →
    Goals → Badges
  - Three `@State` flags (`showStreaks` / `showMomentum` / `showBadges`)
    paired with three `.navigationDestination(isPresented:)` for the
    placeholder pushes
  - Goals tile uses `onSwitchToTab(.goals)` — no `dismiss()` needed
    because flipping `selectedTab` unmounts the entire Home stack
- `Features/Home/AuthenticatedHomeView.swift` — added
  `let onSwitchToTab: (MainTab) -> Void`. Used when constructing the
  HealthDetail destination.
- `Features/Shell/AuthenticatedRootView.swift` — passes
  `onSwitchToTab: { selectedTab = $0 }` when constructing
  AuthenticatedHomeView.

## Locked architectural decisions

- **2×2 LazyVGrid, all 4 cards always visible.** No conditional
  rendering. Matches web's unconditional RELATED_LINKS render.
- **Card order: Streaks → Momentum → Goals → Badges.** Pinned to
  web's array order.
- **Per-card icons + colors pinned to audit.** Labels stay muted —
  the icon is the only color cue on each card.
- **Goals tile = tab switch, not push.** Switching tabs at the root
  unmounts the Home NavigationStack and everything pushed onto it,
  including `HealthDetailView`. No explicit `dismiss()` needed.
  Returning to Home later starts fresh at root (intentional).
- **Other 3 tiles = NavigationStack push** to placeholder
  destinations within the current Home stack. Standard iOS back
  chevron + edge-swipe to return to /health.
- **Placeholder destinations are minimal v1 stubs.** Single 48pt
  centered icon + title + one-line copy. No skeletons, no fake
  data, no calls-to-action that don't work yet.
- **No mutation hooks anywhere.** Pure read + nav, same as the
  rest of /health detail.

## Adaptations from the prompt's blueprint

1. **`selectedTab` lives on `AuthenticatedRootView` (`@State`), not
   on AppState.** The codebase pattern is closure threading: e.g.
   `onSwitchToTransactions` is already passed down to
   ShouldIBuyButton. Added `onSwitchToTab: (MainTab) -> Void`
   following the exact same pattern — no `@Published var
   selectedTab` on AppState introduced.
2. **No explicit `dismiss()` on the Goals tile.** Tab switching at
   the root unmounts the Home stack; calling `dismiss()` would
   cause a visible pop-then-tab-switch animation. Direct tab flip
   is cleaner.
3. **Shared `HealthPlaceholderShell`.** Three concrete placeholder
   wrappers (Streak / Momentum / Badges) hand off to a single shell
   so the chrome stays consistent and replacement in 9.5b touches
   only one concrete file each (the shell stays for future stubs).
4. **iOS uses `MainTab`, not `Tab`.** The enum name is `MainTab`
   (in `Sika/Core/Navigation/MainTab.swift`).

## Out of scope (9.5b / future)

- Real Streaks detail surface
- Real Momentum detail surface
- Real Badges grid surface (catalog + unlocked state + locked-with-hint
  cards)
- HintCards on /health (web doesn't render them here either)
- Card counters / badges (e.g. "3 active streaks", "2/8 badges") on
  the Explore tiles
- Card-specific entry animations
- Card press / haptic states beyond default

## Acceptance

17-step real-device test plan in the PR body. Critical:
- Step 5: 2×2 grid renders in correct order
- Step 7: Streaks pushes within /health stack (back chevron returns)
- Step 11: Goals tile cross-stack jumps to Goals tab
- Step 14: Re-entering /health detail starts at root (no leftover
  state from the prior session)
