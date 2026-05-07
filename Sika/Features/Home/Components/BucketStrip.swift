import SwiftUI

/// Three progress bars for Needs/Wants/Savings spend vs limit.
struct BucketStrip: View {
    let rows: [BucketSpendCalculator.BucketRow]
    let needsPercent: Decimal
    let wantsPercent: Decimal
    let savingsPercent: Decimal
    let currencyCode: String
    let onTap: () -> Void

    @State private var showTooltip = false

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.md) {
            header

            VStack(spacing: SikaTheme.Spacing.md) {
                ForEach(rows) { row in
                    BucketRowView(row: row, currencyCode: currencyCode)
                }
            }
        }
        .padding(SikaTheme.Spacing.md)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, SikaTheme.Spacing.lg)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .sheet(isPresented: $showTooltip) {
            BucketsTooltip(
                isPresented: $showTooltip,
                needsPercent: needsPercent,
                wantsPercent: wantsPercent,
                savingsPercent: savingsPercent
            )
            .presentationDetents([.medium])
        }
    }

    private var header: some View {
        HStack(spacing: SikaTheme.Spacing.xs) {
            Text("BUCKETS · THIS MONTH")
                .font(SikaTheme.Typography.sans(11, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .tracking(1)
            Button(action: { showTooltip = true }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
            .buttonStyle(.plain)
            Spacer()
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
    }
}

private struct BucketRowView: View {
    let row: BucketSpendCalculator.BucketRow
    let currencyCode: String

    private var progress: Double {
        guard row.limit > 0 else { return 0 }
        let p = NSDecimalNumber(decimal: row.spent / row.limit).doubleValue
        return min(max(p, 0), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.name)
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Spacer()
                Text("\(CurrencyFormatter.compact(row.spent, code: currencyCode)) of \(CurrencyFormatter.compact(row.limit, code: currencyCode))")
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }

            ProgressView(value: progress)
                .tint(row.color.swiftUIColor)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
        }
    }
}
