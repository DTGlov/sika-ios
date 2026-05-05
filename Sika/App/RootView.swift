import SwiftUI

struct RootView: View {
    var body: some View {
        VStack(spacing: SikaTheme.Spacing.lg) {
            Text("Sika")
                .font(.largeTitle).bold()
                .foregroundStyle(SikaTheme.Color.foreground)
            Text("Foundation ready")
                .font(.subheadline)
                .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SikaTheme.Color.background)
    }
}

#Preview {
    RootView()
}
