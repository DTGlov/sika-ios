import SwiftUI

struct SikaPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(SikaTheme.Color.primaryForeground)
                } else {
                    Text(title)
                        .font(SikaTheme.Typography.sans(16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(SikaPrimaryButtonStyle(isEnabled: isEnabled && !isLoading))
        .disabled(!isEnabled || isLoading)
    }
}

private struct SikaPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? SikaTheme.Color.primaryForeground : SikaTheme.Color.mutedForeground)
            .background(isEnabled ? SikaTheme.Color.primary : SikaTheme.Color.muted)
            .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.lg))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
