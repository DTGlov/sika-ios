import SwiftUI

/// Phase 9.5a Explore section stub. 9.5b replaces with the real
/// Momentum history + tier progress surface.
struct MomentumDetailPlaceholderView: View {
    var body: some View {
        HealthPlaceholderShell(
            iconName: "rosette",
            iconColor: Color(hex: 0xD4AF37),
            title: "Momentum",
            comingSoonCopy: "Coming soon — your full momentum history and tier progress."
        )
    }
}
