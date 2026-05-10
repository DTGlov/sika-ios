import SwiftUI

/// Reusable inline stat tile for the detail page hero stats grid.
struct StatTile: View {
    let label: String
    let value: String
    var color: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Text(value)
                .font(SikaTheme.Typography.sans(15, weight: .bold))
                .foregroundStyle(color ?? SikaTheme.Color.foreground)
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(SikaTheme.Color.muted.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
