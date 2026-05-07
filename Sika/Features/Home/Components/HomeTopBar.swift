import SwiftUI

/// Top bar for Home: SikaMark + greeting + month/year + Settings gear.
struct HomeTopBar: View {
    let firstName: String?
    let onSettingsTap: () -> Void

    var body: some View {
        HStack(spacing: SikaTheme.Spacing.md) {
            SikaMark(size: 32)

            VStack(alignment: .leading, spacing: 0) {
                Text(greeting)
                    .font(SikaTheme.Typography.sans(17, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text(monthYear)
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }

            Spacer()

            Button(action: onSettingsTap) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(SikaTheme.Color.foreground)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(SikaTheme.Color.card)
                            .overlay(Circle().strokeBorder(SikaTheme.Color.border, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, SikaTheme.Spacing.lg)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "Good morning"
        case 12..<17: timeOfDay = "Good afternoon"
        case 17..<22: timeOfDay = "Good evening"
        default: timeOfDay = "Hi"
        }
        if let name = firstName, !name.isEmpty {
            return "\(timeOfDay), \(name)"
        }
        return timeOfDay
    }

    private var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
}
