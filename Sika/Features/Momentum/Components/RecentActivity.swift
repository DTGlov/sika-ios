import SwiftUI

/// "Recent Activity" list — at most 30 most-recent momentum events.
/// Each row: event label (top) + relative time (bottom) + gold "+N"
/// trailing. Conditional render owned by the parent (only mounted
/// when `events.isEmpty == false`).
struct RecentActivity: View {
    let events: [MomentumEvent]

    private let goldAccent = Color(hex: 0xD4A017)

    /// `.full` produces "2 hours ago", "3 days ago", "yesterday" —
    /// matches the audit's intent. (`.named` from the prompt doesn't
    /// exist on iOS's `RelativeDateTimeFormatter.UnitsStyle`.)
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(SikaTheme.Typography.sans(15, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    activityRow(event: event)
                    if index < events.count - 1 {
                        Divider().background(SikaTheme.Color.mutedForeground.opacity(0.1))
                    }
                }
            }
            .padding(.vertical, 4)
            .background(SikaTheme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func activityRow(event: MomentumEvent) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(MomentumAmounts.label(for: event.eventType))
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text(Self.formatter.localizedString(for: event.createdAt, relativeTo: Date()))
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
            Spacer()
            Text("+\(event.points)")
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(goldAccent)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
