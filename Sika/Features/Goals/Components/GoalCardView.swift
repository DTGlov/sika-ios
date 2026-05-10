import SwiftUI

/// Goal card for the list view. Mirror of web's GoalCard.
/// Tapping the card body navigates to detail; the 3 trailing icons
/// (Edit / Add contribution / Start next cycle) are hit-test islands.
struct GoalCardView: View {
    let progress: GoalProgress
    let currencyCode: String
    let onOpenDetail: () -> Void
    let onEdit: () -> Void
    let onContribute: () -> Void
    let onStartNextCycle: () -> Void

    private var goal: Goal { progress.goal }
    private var accentColor: Color { GoalConstants.resolveColor(goal.color) }
    private var isCompleted: Bool { goal.completedAt != nil }
    private var isPerpetual: Bool { goal.goalType == .perpetual }

    var body: some View {
        Button(action: onOpenDetail) {
            VStack(alignment: .leading, spacing: 12) {
                topRow
                if !isPerpetual, let pct = progress.progressPercent {
                    progressBar(pct: pct)
                } else if isPerpetual {
                    perpetualIndicator
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SikaTheme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(SikaTheme.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Top row

    private var topRow: some View {
        HStack(alignment: .top, spacing: 12) {
            iconTile

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(goal.name)
                        .font(SikaTheme.Typography.sans(16, weight: .bold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if isCompleted {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: 0xD4A017))
                    }
                    if let cycle = goal.cycleCount, cycle > 1 {
                        Text("Cycle \(cycle)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(SikaTheme.Color.muted)
                            .clipShape(Capsule())
                    }
                }
                if let desc = goal.description, !desc.isEmpty {
                    Text(desc)
                        .font(SikaTheme.Typography.sans(11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .lineLimit(2)
                }
                amountLine
            }

            Spacer(minLength: 0)

            actionIcons
        }
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(accentColor.opacity(0.15))
                .frame(width: 44, height: 44)
            Text(goal.icon ?? GoalConstants.defaultIcon)
                .font(.system(size: 22))
        }
    }

    @ViewBuilder
    private var amountLine: some View {
        let current = CurrencyFormatter.format(progress.currentAmount, code: currencyCode)
        if let target = goal.targetAmount, !isPerpetual {
            let total = CurrencyFormatter.format(target, code: currencyCode)
            Text("\(current) of \(total)")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .monospacedDigit()
        } else {
            Text(current)
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .monospacedDigit()
        }
    }

    private var actionIcons: some View {
        HStack(spacing: 0) {
            iconButton(systemName: "pencil", action: onEdit)
                .accessibilityLabel("Edit goal")
            if isCompleted {
                iconButton(systemName: "arrow.clockwise", action: onStartNextCycle)
                    .accessibilityLabel("Start next cycle")
            } else {
                iconButton(systemName: "plus", action: onContribute)
                    .accessibilityLabel("Add contribution")
            }
        }
    }

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress bar

    private func progressBar(pct: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(SikaTheme.Color.muted)
                    .frame(height: 8)
                GeometryReader { geo in
                    Capsule()
                        .fill(accentColor)
                        .frame(width: geo.size.width * CGFloat(pct / 100.0), height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: pct)
                }
                .frame(height: 8)
            }
            HStack {
                Text("\(Int(pct.rounded()))%")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(accentColor)
                Spacer()
                if let dr = progress.daysRemaining, !isCompleted {
                    Text("\(dr)d left")
                        .font(.system(size: 11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .monospacedDigit()
                }
                if let onTrack = progress.isOnTrack, !isCompleted {
                    paceChip(onTrack: onTrack)
                }
            }
        }
    }

    private var perpetualIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "infinity")
                .font(.system(size: 11))
            Text("Perpetual")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(accentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(accentColor.opacity(0.10))
        .clipShape(Capsule())
    }

    private func paceChip(onTrack: Bool) -> some View {
        let color = onTrack ? Color(hex: 0xD4A017) : Color(hex: 0xF97316)
        return Text(onTrack ? "On Track" : "Behind")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
