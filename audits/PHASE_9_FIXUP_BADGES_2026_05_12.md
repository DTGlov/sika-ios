# Phase 9 fix-ups + /badges page — 2026-05-12

Implementer: Claude Code
Source-of-truth audits:
  - `/audits/BADGES_PAGE_2026_05_12.md` (this page)
  - `/audits/STREAKS_PAGE_2026_05_12.md` (shared Phase 9 model context)
  - `/audits/MOMENTUM_PAGE_2026_05_12.md` (shared Phase 9 model context)

First of five PRs to ship /health Explore destinations + final 9.5a
wiring. Bundled: PART A locks the Phase 9 models down (the
preconditions every subsequent page assumes), PART B builds the
/badges destination.

## PART A — Phase 9 model verifications

| # | Check | Status | Detail |
|---|---|---|---|
| 1 | `HealthLabel` has all 5 cases | **verified** | `Health.swift` already exposes `.excellent / .good / .fair / .needsAttention / .critical` plus `.from(score:)`, `.displayName`, `.color`. |
| 2 | Tier enum has all 5 cases | **verified** | Named `MomentumTier` on iOS (not `Tier`); covers bronze → silver → gold → platinum → diamond with `.threshold`, `.color`, `.iconName`, `.displayName`, `.from(totalPoints:)`. |
| 3 | `MomentumEvent` struct exists | **added** | Phase 9 shipped `MomentumEventType` + an inline Encodable in `MomentumService.award(...)` for the write path. No Decodable struct existed for the read side. Added a sibling `MomentumEvent: Identifiable, Codable, Equatable` in `Health.swift` right after `Momentum`. PR 3 (/momentum) consumes it. |
| 4 | `Streaks` has no `id` field | **verified** | The struct's only identifier is `userId` (the table's PK is `user_id`). |
| 5 | `UserBadge.unlockedAt` is `Date` | **verified** | `let unlockedAt: Date` in `Health.swift`. |
| 6 | `awardMomentum` writes `tier` alongside `total_points` | **verified** | `MomentumService.award(userId:event:)` upserts an `UpsertRow` carrying both fields plus the inline event insert into `momentum_events`. |

**Net change in PART A:** one struct added (`MomentumEvent`). Everything else was already correct; the prompt's "verify or fix" check passed without action on five of six items.

## PART B — /badges page

### Shared catalog
- `Core/Constants/GamificationCatalog.swift` (new) — pieces that
  don't already live in `Health.swift`:
  - `RarityVisualConfig` + `RarityConfig.config(for:)` — frame
    color, radial gradient, glow intensity per `BadgeRarity`.
    Common = green #00D9A3 (20% glow); Rare = gold #D4AF37 (35% glow).
  - `MomentumAmounts` — user-facing labels per `MomentumEventType`
    in MOMENTUM_AMOUNTS insertion order. The numeric `.points`
    already lives on the enum.
  - `StreakMilestones` — `logging` (7/14/30/60/100), `savings`
    (4/12/26/52) + `nextLogging(after:)` and `nextSavings(after:)`
    helpers.

  Note: `BadgeCatalog` + `BadgeRarity` + `MomentumTier` (with
  `.threshold`/`.color`/`.iconName`) already live in `Health.swift`;
  the catalog file complements rather than duplicates them.

### Feature files (Features/Badges/)
- `BadgeWithUnlockStatus.swift` (new) — decorated view model
  combining a `BadgeCatalogEntry` with its unlock state. Static
  `partition(userBadges:)` returns `(earned, locked)` both pre-sorted
  by catalog `sortOrder`. Locked badges keep their description so
  the criteria reads as a tease (audit Section 3, matches web).
- `Components/BadgeCardView.swift` (new) — single tile.
  - Size enum (`.sm` / `.md` / `.lg`) — at `.md`, rare medallions
    render at 80pt vs commons at 64pt (audit: rare visibly larger).
  - Earned medallion: rarity-tinted gradient + frame + glow shadow,
    full-color icon.
  - Locked medallion: muted fill + frame, grayscale icon at 60%
    opacity, `lock.fill` overlay anchored bottom-right of the
    circle with a subtle halo (background-color disc + 0.5pt stroke).
  - Body shows name + description; description text-color stays the
    same for earned vs locked (criteria-as-tease).
- `BadgesView.swift` (new) — page chrome.
  - 3-column `LazyVGrid`, 24pt inter-card spacing, 32pt between
    section headers (audit `space-y-8`).
  - Progress count line at top: "Earned: N of M".
  - Earned section header (foreground color) + Locked section header
    (muted color). Sections render conditionally — empty buckets
    don't show their header.
  - Sticky inline nav title "Your Badges" via the standard
    `.navigationTitle` + `.inline` configuration. No custom toolbar.

### Data source
- Reads `appState.healthSnapshot?.userBadges ?? []`. No direct
  Supabase fetch from this page — matches web (which also reads
  from the Zustand snapshot). Fresh data lands on
  navigate-away-and-back via the existing snapshot refresh path.

## Locked architectural decisions

- **Single shared catalog file.** `GamificationCatalog.swift`
  consolidates the visual configs + labels + milestone constants
  that PR 2 (/streaks) and PR 3 (/momentum) will also consume.
- **No mutation hooks anywhere on /badges.** Pure read view; no
  celebrations, no points awarded for viewing.
- **No live grid refresh on unlock while on-page** (matches web —
  the celebration sheet is rendered globally by the host, not by
  this page).
- **Description visible for locked badges** — the criteria *is*
  the tease. Spoiler-free is not the design.
- **Rare badges render larger at `.md`** (80pt vs 64pt). Common
  vs rare visual hierarchy is part of the reward.
- **No HTTP routes.** Direct Supabase / catalog reads.
- **camelCase Swift throughout** — the snake_case from web's
  `Badge` interface is bridged via `CodingKeys` on `UserBadge`.

## Adaptations from the prompt's blueprint

1. **Did not move `BadgeCatalog` into `GamificationCatalog.swift`.**
   The Phase 9 type already lives in `Health.swift` and is consumed
   by `BadgeService`, `HealthRow`, and the celebration sheet. Moving
   it would have rippled into ~5 unrelated files. Documented in the
   new file's header that the two are complements.
2. **`BadgeMeta` not introduced.** Phase 9's existing
   `BadgeCatalogEntry` already exposes `id` / `name` / `description`
   / `iconName` / `rarity` / `sortOrder` — exactly the shape the
   prompt wanted. Used it directly.
3. **`TiersCatalog` not introduced.** `MomentumTier` already exposes
   `.threshold`, `.color`, `.iconName`, `.displayName`,
   `.from(totalPoints:)` per case. Adding a parallel
   `TiersCatalog.meta[Tier: TierMeta]` would have been a parallel
   source of truth. PR 3 (/momentum) reads `MomentumTier` directly.
4. **`@Environment(AppState.self)`, not `@EnvironmentObject`** — the
   iOS pattern is `@Observable` + environment lookup.
5. **No `BadgesGridPlaceholderView` redirect in this PR.** The
   placeholder file lives on the unmerged `feature/health-explore-section`
   branch, not on `main`. PR 5 (Explore wiring) will swap the
   placeholder push for a direct `BadgesView` push. After this PR
   lands, `BadgesView` is reachable via direct construction; the
   navigation glue arrives in PR 5.

## Acceptance

12-step acceptance criteria in the PR body. After this PR merges,
end-to-end navigation requires either:
  - The Explore section PR to merge first, then PR 5 to swap the
    Badges placeholder for `BadgesView`, OR
  - Manual wiring in a follow-up.

Until then, `BadgesView` is build-verified and instantiable but not
reachable from the live navigation tree.

## Out of scope

- /streaks (PR 2)
- /momentum (PR 3)
- 9.5a Explore tile rewiring (PR 5)
- Live grid refresh on unlock while on page
- `unlockedAt` display on cards (web stores, hides — same here)
- Tiered badges / seasonal badges / leaderboards
- Pull-to-refresh on /badges
