import Foundation

/// Mirrors the public.profiles table.
///
/// NOTE: Email is NOT on this model. The profiles table has no email column —
/// email lives on auth.users and is reachable via session.user.email.
///
/// NOTE: The DB has both a `currency` column (active) and a `currency_code`
/// column (dead, unused — leftover from an incomplete migration). We model
/// only `currency`. Web reads/writes the same field.
struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    let fullName: String?
    let monthlyIncome: Decimal?
    let currency: String                // NOT NULL in DB
    let needsPercent: Decimal?
    let wantsPercent: Decimal?
    let savingsPercent: Decimal?
    let cycleStartDay: Int?
    let cardTheme: String               // NOT NULL in DB
    let themePreference: String         // NOT NULL in DB ("light" | "dark")
    let hapticsEnabled: Bool?
    let accountsBannerDismissed: Bool   // NOT NULL in DB
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case monthlyIncome = "monthly_income"
        case currency
        case needsPercent = "needs_percent"
        case wantsPercent = "wants_percent"
        case savingsPercent = "savings_percent"
        case cycleStartDay = "cycle_start_day"
        case cardTheme = "card_theme"
        case themePreference = "theme_preference"
        case hapticsEnabled = "haptics_enabled"
        case accountsBannerDismissed = "accounts_banner_dismissed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// First name extracted from fullName for greeting display.
    var firstName: String? {
        fullName?.split(separator: " ").first.map(String.init)
    }

    // The DB allows null on these fields, but Sika's product spec locks
    // the defaults at 45/15/40. Read sites use these computed properties
    // so the app is robust to partial profile rows.

    var needsPercentValue: Decimal { needsPercent ?? 45 }
    var wantsPercentValue: Decimal { wantsPercent ?? 15 }
    var savingsPercentValue: Decimal { savingsPercent ?? 40 }

    /// Returns a copy of this profile with `cardTheme` replaced.
    /// Used by AppState's optimistic update path — Profile fields are `let`,
    /// so mutation requires constructing a new instance.
    func withCardTheme(_ value: String) -> Profile {
        copy(cardTheme: value)
    }

    /// Returns a copy with `themePreference` replaced.
    func withThemePreference(_ value: String) -> Profile {
        copy(themePreference: value)
    }

    /// Returns a copy with `hapticsEnabled` replaced.
    func withHapticsEnabled(_ value: Bool) -> Profile {
        copy(hapticsEnabled: value)
    }

    /// Returns a copy with `currency` replaced.
    func withCurrency(_ value: String) -> Profile {
        copy(currency: value)
    }

    /// Returns a copy with the budget config (cycle start + 3 percentages) replaced.
    func withBudgetConfig(
        cycleStartDay: Int,
        needsPercent: Decimal,
        wantsPercent: Decimal,
        savingsPercent: Decimal
    ) -> Profile {
        copy(
            monthlyIncome: monthlyIncome,
            needsPercent: needsPercent,
            wantsPercent: wantsPercent,
            savingsPercent: savingsPercent,
            cycleStartDay: cycleStartDay
        )
    }

    /// Internal copy helper. Each parameter optional with current-value default.
    private func copy(
        fullName: String?? = nil,
        monthlyIncome: Decimal?? = nil,
        currency: String? = nil,
        needsPercent: Decimal?? = nil,
        wantsPercent: Decimal?? = nil,
        savingsPercent: Decimal?? = nil,
        cycleStartDay: Int?? = nil,
        cardTheme: String? = nil,
        themePreference: String? = nil,
        hapticsEnabled: Bool?? = nil,
        accountsBannerDismissed: Bool? = nil
    ) -> Profile {
        Profile(
            id: id,
            fullName: fullName ?? self.fullName,
            monthlyIncome: monthlyIncome ?? self.monthlyIncome,
            currency: currency ?? self.currency,
            needsPercent: needsPercent ?? self.needsPercent,
            wantsPercent: wantsPercent ?? self.wantsPercent,
            savingsPercent: savingsPercent ?? self.savingsPercent,
            cycleStartDay: cycleStartDay ?? self.cycleStartDay,
            cardTheme: cardTheme ?? self.cardTheme,
            themePreference: themePreference ?? self.themePreference,
            hapticsEnabled: hapticsEnabled ?? self.hapticsEnabled,
            accountsBannerDismissed: accountsBannerDismissed ?? self.accountsBannerDismissed,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
