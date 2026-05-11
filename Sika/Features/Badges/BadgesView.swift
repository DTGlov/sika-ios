import SwiftUI

/// /badges destination — full badges grid with Earned + Locked
/// sections. Wired in from /health detail's Explore section (Phase
/// 9.5a) in a follow-up PR. This view itself is self-contained.
///
/// Reads exclusively from `appState.healthSnapshot?.userBadges`. No
/// direct DB queries, no mutation hooks. Matches web's behavior: the
/// page never re-fetches mid-session — fresh data lands on the next
/// navigate-away-and-back, when Home re-loads the snapshot.
///
/// Layout: 3-column LazyVGrid with 24pt inter-card spacing. Section
/// spacing between Earned and Locked headers is 32pt (audit Section 3:
/// `space-y-8`).
struct BadgesView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                progressCount
                earnedSection
                lockedSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 96)
        }
        .background(SikaTheme.Color.background)
        .navigationTitle("Your Badges")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Data slicing

    private var userBadges: [UserBadge] {
        appState.healthSnapshot?.userBadges ?? []
    }

    private var partitioned: (earned: [BadgeWithUnlockStatus], locked: [BadgeWithUnlockStatus]) {
        BadgeWithUnlockStatus.partition(userBadges: userBadges)
    }

    // MARK: - Progress count

    private var progressCount: some View {
        let p = partitioned
        let total = p.earned.count + p.locked.count
        return HStack(spacing: 0) {
            Text("Earned: ")
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Text("\(p.earned.count) of \(total)")
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .monospacedDigit()
        }
    }

    // MARK: - Earned section

    @ViewBuilder
    private var earnedSection: some View {
        let earned = partitioned.earned
        if !earned.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("EARNED", muted: false)
                LazyVGrid(columns: gridColumns, spacing: 24) {
                    ForEach(earned) { badge in
                        BadgeCardView(badge: badge, size: .md)
                    }
                }
            }
        }
    }

    // MARK: - Locked section

    @ViewBuilder
    private var lockedSection: some View {
        let locked = partitioned.locked
        if !locked.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("LOCKED", muted: true)
                LazyVGrid(columns: gridColumns, spacing: 24) {
                    ForEach(locked) { badge in
                        BadgeCardView(badge: badge, size: .md)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ label: String, muted: Bool) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(muted ? SikaTheme.Color.mutedForeground : SikaTheme.Color.foreground)
    }

    private var gridColumns: [GridItem] {
        // 3-col matches web's grid-cols-3 on mobile.
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }
}
