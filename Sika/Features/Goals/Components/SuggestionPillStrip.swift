import SwiftUI

/// 4-suggestion-pill strip shown on the empty Goals list state.
/// Tapping a pill opens the create modal — presentational only (no prefill).
struct SuggestionPillStrip: View {
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(GoalConstants.suggestionPills.prefix(2)) { pill in
                    pillView(pill)
                }
            }
            HStack(spacing: 8) {
                ForEach(GoalConstants.suggestionPills.suffix(2)) { pill in
                    pillView(pill)
                }
            }
        }
    }

    private func pillView(_ pill: GoalConstants.SuggestionPill) -> some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(pill.emoji)
                    .font(.system(size: 14))
                Text(pill.label)
                    .font(SikaTheme.Typography.sans(13, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(SikaTheme.Color.card)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(SikaTheme.Color.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
