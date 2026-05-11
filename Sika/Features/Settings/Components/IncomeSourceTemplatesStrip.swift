import SwiftUI

/// Hardcoded quick-add template for the Income Sources section.
/// Tapping a chip pre-fills the form sheet with these defaults. Mirror of
/// the audit Section 5.5 template set. iOS pre-fills (unlike web's
/// `void template;` no-op — fix-on-way for the cross-platform behavior).
struct IncomeSourceTemplate: Identifiable, Equatable {
    let id: String
    let label: String
    let emoji: String
    let frequency: IncomeFrequency
    /// Suggested `expected_day` value. `nil` for irregular templates.
    let suggestedExpectedDay: Int?
}

enum IncomeSourceTemplates {
    static let all: [IncomeSourceTemplate] = [
        IncomeSourceTemplate(id: "salary",     label: "Salary",     emoji: "💼", frequency: .monthly,   suggestedExpectedDay: 28),
        IncomeSourceTemplate(id: "allowance",  label: "Allowance",  emoji: "🎁", frequency: .monthly,   suggestedExpectedDay: 1),
        IncomeSourceTemplate(id: "freelance",  label: "Freelance",  emoji: "💻", frequency: .irregular, suggestedExpectedDay: nil),
        IncomeSourceTemplate(id: "investment", label: "Investment", emoji: "📈", frequency: .monthly,   suggestedExpectedDay: 15),
        IncomeSourceTemplate(id: "other",      label: "Other",      emoji: "💰", frequency: .monthly,   suggestedExpectedDay: nil),
    ]
}

/// Horizontal strip of 5 income-source quick-add chips.
/// Sits below the sources list, above the "Total monthly income" row.
struct IncomeSourceTemplatesStrip: View {
    let onTemplateTap: (IncomeSourceTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK ADD")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(IncomeSourceTemplates.all) { template in
                        chip(template)
                    }
                }
            }
        }
    }

    private func chip(_ template: IncomeSourceTemplate) -> some View {
        Button {
            onTemplateTap(template)
        } label: {
            HStack(spacing: 6) {
                Text(template.emoji)
                    .font(.system(size: 14))
                Text(template.label)
                    .font(SikaTheme.Typography.sans(12, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(SikaTheme.Color.card)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(SikaTheme.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
