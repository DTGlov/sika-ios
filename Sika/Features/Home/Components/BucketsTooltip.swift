import SwiftUI

/// Sheet explaining how buckets work. Triggered by (i) icon in BucketStrip header.
struct BucketsTooltip: View {
    @Binding var isPresented: Bool
    let needsPercent: Decimal
    let wantsPercent: Decimal
    let savingsPercent: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.lg) {
            HStack {
                Text("How buckets work")
                    .font(SikaTheme.Typography.sans(20, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(SikaTheme.Color.muted))
                }
                .buttonStyle(.plain)
            }

            Text(splitSummary)
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: SikaTheme.Spacing.md) {
                bucketLine(
                    name: "Needs",
                    color: SikaTheme.Color.bucketNeeds,
                    description: "Must-haves like rent, food, transport"
                )
                bucketLine(
                    name: "Wants",
                    color: SikaTheme.Color.bucketWants,
                    description: "Eating out, entertainment, gym"
                )
                bucketLine(
                    name: "Savings",
                    color: SikaTheme.Color.bucketSavings,
                    description: "Savings, investments, emergency fund"
                )
            }

            Spacer()
        }
        .padding(SikaTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SikaTheme.Color.background)
    }

    private var splitSummary: String {
        let n = formatPercent(needsPercent)
        let w = formatPercent(wantsPercent)
        let s = formatPercent(savingsPercent)
        return "Your income is split \(n)/\(w)/\(s) by default — Needs / Wants / Savings. Customize the split in Settings."
    }

    private func formatPercent(_ value: Decimal) -> String {
        let n = NSDecimalNumber(decimal: value).intValue
        return "\(n)"
    }

    private func bucketLine(name: String, color: Color, description: String) -> some View {
        HStack(alignment: .top, spacing: SikaTheme.Spacing.md) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(color)
                Text(description)
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
        }
    }
}
