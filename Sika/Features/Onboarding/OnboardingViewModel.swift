import Foundation
import SwiftUI
import Observation
import Supabase

/// In-memory representation of an extra income source while it's being added.
struct TempIncomeSource: Identifiable, Equatable, Hashable {
    let id = UUID()
    let templateKey: String
    let name: String
    let amount: Decimal
    let frequency: IncomeFrequency
    let expectedDay: Int?
}

@Observable
@MainActor
final class OnboardingViewModel {
    var step: Int = 1
    let totalSteps: Int = 5

    var selectedCurrencyCode: String = "GHS"
    var currencySearch: String = ""

    var primaryName: String = ""
    var primaryAmountInput: String = ""
    var primaryFrequency: IncomeFrequency = .monthly
    var primaryExpectedDay: Int? = nil

    var extraSources: [TempIncomeSource] = []
    var activeExtraTemplateKey: String? = nil
    var extraInputAmount: String = ""

    var isSaving: Bool = false
    var serverError: String? = nil

    struct ExtraTemplate: Identifiable, Equatable, Hashable {
        let id: String
        let name: String
        let frequency: IncomeFrequency
        let expectedDay: Int?
    }

    static let extraTemplates: [ExtraTemplate] = [
        .init(id: "weekly-allowance",  name: "Weekly Allowance",  frequency: .weekly,    expectedDay: 1),
        .init(id: "monthly-allowance", name: "Monthly Allowance", frequency: .irregular, expectedDay: nil),
        .init(id: "side-hustle",       name: "Side Hustle",       frequency: .irregular, expectedDay: nil),
        .init(id: "benefit",           name: "Benefit / Subsidy", frequency: .monthly,   expectedDay: 1),
    ]

    var primaryAmount: Decimal? {
        let trimmed = primaryAmountInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let value = Decimal(string: trimmed), value > 0 else { return nil }
        return value
    }

    var canSubmitPrimary: Bool {
        let trimmedName = primaryName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, let amount = primaryAmount, amount > 0 else { return false }
        if primaryFrequency.requiresExpectedDay {
            return primaryExpectedDay != nil
        }
        return true
    }

    var totalMonthly: Decimal {
        var total = Decimal(0)
        if let amount = primaryAmount {
            total += amount * primaryFrequency.monthlyMultiplier
        }
        for s in extraSources {
            total += s.amount * s.frequency.monthlyMultiplier
        }
        return total
    }

    func goNext() {
        guard step < totalSteps else { return }
        step += 1
    }

    func goBack() {
        guard step > 1 else { return }
        step -= 1
    }

    func submitPrimary() -> Bool {
        guard canSubmitPrimary else { return false }
        goNext()
        return true
    }

    func tapExtraTemplate(_ template: ExtraTemplate) {
        if extraSources.contains(where: { $0.templateKey == template.id }) { return }
        if activeExtraTemplateKey == template.id {
            cancelExtraInput()
        } else {
            activeExtraTemplateKey = template.id
            extraInputAmount = ""
        }
    }

    func confirmExtraAmount(_ template: ExtraTemplate) {
        let trimmed = extraInputAmount.trimmingCharacters(in: .whitespaces)
        guard let amount = Decimal(string: trimmed), amount > 0 else { return }
        let temp = TempIncomeSource(
            templateKey: template.id,
            name: template.name,
            amount: amount,
            frequency: template.frequency,
            expectedDay: template.expectedDay
        )
        extraSources.append(temp)
        activeExtraTemplateKey = nil
        extraInputAmount = ""
    }

    func cancelExtraInput() {
        activeExtraTemplateKey = nil
        extraInputAmount = ""
    }

    func removeExtra(templateKey: String) {
        extraSources.removeAll { $0.templateKey == templateKey }
    }

    func finish(appState: AppState, incomeService: IncomeService, profileService: ProfileService) async {
        isSaving = true
        serverError = nil
        defer { isSaving = false }

        guard let primaryAmount = primaryAmount,
              let session = appState.session else {
            serverError = "Missing required data"
            return
        }
        let userId = session.user.id

        var drafts: [IncomeSourceDraft] = [
            IncomeSourceDraft(
                userId: userId,
                name: primaryName.trimmingCharacters(in: .whitespaces),
                amount: primaryAmount,
                frequency: primaryFrequency,
                expectedDay: primaryFrequency.requiresExpectedDay ? primaryExpectedDay : nil,
                isActive: true,
                notes: nil
            )
        ]
        for s in extraSources {
            drafts.append(IncomeSourceDraft(
                userId: userId,
                name: s.name,
                amount: s.amount,
                frequency: s.frequency,
                expectedDay: s.expectedDay,
                isActive: true,
                notes: nil
            ))
        }

        do {
            let inserted = try await incomeService.insertMany(drafts)
            let total = totalMonthlyIncome(inserted)
            let updatedProfile = try await profileService.updateAfterOnboarding(
                monthlyIncome: total,
                currency: selectedCurrencyCode
            )
            appState.completeOnboarding(updatedProfile: updatedProfile, sources: inserted)
            AnalyticsService.shared.capture(.onboardingCompleted(stepsCompleted: 5))
        } catch {
            #if DEBUG
            print("⚠️ Onboarding finish failed: \(error)")
            #endif
            serverError = "Couldn't save. Please try again."
        }
    }
}
