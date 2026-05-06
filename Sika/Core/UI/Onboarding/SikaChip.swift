import SwiftUI

/// Selectable chip — used by frequency selector and extra-income templates.
struct SikaChip: View {
    let title: String
    var subtitle: String? = nil
    var isSelected: Bool = false
    var isDisabled: Bool = false
    var trailingIcon: String? = nil
    var tint: Color = SikaTheme.Color.sikaAccent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SikaTheme.Spacing.xs) {
                VStack(alignment: .center, spacing: 2) {
                    Text(title)
                        .font(SikaTheme.Typography.sans(13, weight: .semibold))
                        .foregroundStyle(foregroundColor)
                    if let subtitle {
                        Text(subtitle)
                            .font(SikaTheme.Typography.sans(11))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)
                    }
                }
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(foregroundColor)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .padding(.horizontal, SikaTheme.Spacing.sm)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: SikaTheme.Radius.md)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.md))
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var foregroundColor: Color {
        if isSelected { return tint }
        return SikaTheme.Color.foreground
    }

    private var backgroundColor: Color {
        if isSelected { return tint.opacity(0.12) }
        return SikaTheme.Color.muted
    }

    private var borderColor: Color {
        if isSelected { return tint }
        return SikaTheme.Color.border
    }
}
