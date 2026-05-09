import SwiftUI

/// Horizontal segmented chip strip for the period filter.
/// 5 chips bound to filters.period. Active chip uses card background on a
/// muted strip — mirror of web's segmented control.
struct PeriodTabsView: View {
    @Binding var selected: TransactionFilters.Period

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(TransactionFilters.Period.allCases) { period in
                    Button {
                        selected = period
                    } label: {
                        Text(period.displayLabel)
                            .font(SikaTheme.Typography.sans(13,
                                weight: selected == period ? .semibold : .regular))
                            .foregroundStyle(
                                selected == period
                                    ? SikaTheme.Color.foreground
                                    : SikaTheme.Color.mutedForeground
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selected == period
                                    ? SikaTheme.Color.card
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
        .background(SikaTheme.Color.muted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
    }
}
