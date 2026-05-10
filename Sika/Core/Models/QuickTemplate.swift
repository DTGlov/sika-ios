import Foundation

/// Hardcoded quick-template entry. Adding one is a code change.
/// Mirror of TEMPLATES constant in src/app/(app)/recurring/page.tsx.
struct QuickTemplate: Identifiable, Equatable {
    let id: String
    let label: String
    let emoji: String
    let frequency: RecurringFrequency
    let autoLog: Bool
    let note: String
}

enum QuickTemplates {
    static let all: [QuickTemplate] = [
        QuickTemplate(id: "monthly_rent",   label: "Monthly rent",   emoji: "🏠",  frequency: .monthly, autoLog: true,  note: "Monthly rent"),
        QuickTemplate(id: "subscription",   label: "Subscription",   emoji: "📱",  frequency: .monthly, autoLog: true,  note: "Subscription"),
        QuickTemplate(id: "utility_bill",   label: "Utility bill",   emoji: "⚡",  frequency: .monthly, autoLog: false, note: "Utility bill"),
        QuickTemplate(id: "gym_membership", label: "Gym membership", emoji: "🏋️", frequency: .monthly, autoLog: true,  note: "Gym membership"),
        QuickTemplate(id: "internet",       label: "Internet",       emoji: "📶",  frequency: .monthly, autoLog: true,  note: "Internet"),
    ]
}
