import SwiftUI

/// 2-section card per audit Section 3.
/// Top strip: due-date label + Handled / Nudge pill.
/// Body: dot + name + meta on left (tappable → detail), amount + 3-button row on right.
struct RecurringCardView: View {
    let recurring: RecurringTransaction
    let currencyCode: String
    let onOpenDetail: () -> Void
    let onTogglePause: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private let greenColor = Color(hex: 0x00D9A3)
    private let redColor = Color(hex: 0xF43F5E)

    private var accentColor: Color {
        recurring.type == .income ? greenColor : redColor
    }

    private var dueInfo: DueDateInfo {
        RecurringDateMath.dueDateInfo(recurring)
    }

    private var isHandled: Bool {
        !recurring.autoLog && RecurringDateMath.isHandledThisInstance(recurring)
    }

    var body: some View {
        VStack(spacing: 0) {
            topStrip
            Divider()
            bodyRow
        }
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
    }

    // MARK: - Top strip

    private var topStrip: some View {
        HStack {
            Text(recurring.isPaused ? "Paused" : "Next due: \(dueInfo.label)")
                .font(SikaTheme.Typography.sans(11, weight: dueInfo.isBold ? .semibold : .regular))
                .foregroundStyle(
                    recurring.isPaused
                        ? Color(hex: 0xFBBF24)
                        : Color(hex: dueInfo.colorHex)
                )

            Spacer()

            if isHandled {
                handledPill
            } else if !recurring.autoLog && !recurring.isPaused {
                nudgePill
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var handledPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .semibold))
            Text("Handled")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(greenColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(greenColor.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var nudgePill: some View {
        Text("Nudge")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(SikaTheme.Color.mutedForeground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(SikaTheme.Color.muted)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Body row

    private var bodyRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onOpenDetail) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(SikaTheme.Typography.sans(15, weight: .bold))
                            .foregroundStyle(SikaTheme.Color.foreground)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(metaLine)
                            .font(SikaTheme.Typography.sans(11))
                            .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.85))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 8) {
                Text(formattedAmount)
                    .font(SikaTheme.Typography.sans(17, weight: .bold))
                    .foregroundStyle(accentColor)
                    .monospacedDigit()

                actionButtons
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var actionButtons: some View {
        HStack(spacing: 0) {
            iconButton(
                systemName: recurring.isPaused ? "play.fill" : "pause.fill",
                action: onTogglePause
            )
            iconButton(systemName: "pencil", action: onEdit)
            iconButton(systemName: "trash", action: onDelete)
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

    // MARK: - Computed

    private var displayName: String {
        if let note = recurring.note, !note.isEmpty { return note }
        if let cat = recurring.category?.name { return cat }
        return recurring.frequency.displayLabel
    }

    private var metaLine: String {
        var parts: [String] = []
        if let acc = recurring.account?.name { parts.append(acc) }
        if let cat = recurring.category?.name, recurring.note != nil { parts.append(cat) }
        parts.append(RecurringDateMath.formatScheduleSummary(recurring))
        return parts.joined(separator: " · ")
    }

    private var formattedAmount: String {
        CurrencyFormatter.format(recurring.amount, code: currencyCode)
    }
}
