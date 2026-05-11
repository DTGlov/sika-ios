import SwiftUI

/// Phase 9.5a Explore section stub. 9.5b replaces with the real
/// Badges grid (earned + locked achievements).
struct BadgesGridPlaceholderView: View {
    var body: some View {
        HealthPlaceholderShell(
            iconName: "chart.line.uptrend.xyaxis",
            iconColor: Color(hex: 0xA78BFA),
            title: "Badges",
            comingSoonCopy: "Coming soon — earned badges and locked achievements."
        )
    }
}
