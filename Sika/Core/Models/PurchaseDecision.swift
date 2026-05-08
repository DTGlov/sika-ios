import Foundation
import SwiftUI

/// LLM-determined verdict for a purchase analysis.
/// Mirror of web's Verdict union (src/types/decision.ts).
enum Verdict: String, Codable, CaseIterable, Equatable {
    case goAhead      = "go_ahead"
    case notNow       = "not_now"
    case onlyIf       = "only_if"
    case thinkAboutIt = "think_about_it"

    /// Display label: rawValue with underscores → spaces, uppercased.
    var displayLabel: String {
        rawValue.replacingOccurrences(of: "_", with: " ").uppercased()
    }
}

/// Color treatment for the verdict pill. The LLM picks accent independently
/// from verdict — iOS uses this field as authoritative for color.
/// Mirror of web's accent union.
enum DecisionAccent: String, Codable, CaseIterable, Equatable {
    case green
    case amber
    case red
    case blue
}

/// Bucket categorization for purchase analysis.
/// Mirror of web's PurchaseDecisionBucket.
enum PurchaseDecisionBucket: String, Codable, CaseIterable, Equatable, Identifiable {
    case needs
    case wants
    case savings

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .needs:   return "Needs"
        case .wants:   return "Wants"
        case .savings: return "Savings"
        }
    }

    /// Brand color for the bucket. Mirrors web's BUCKET_CONFIG and
    /// matches SikaTheme.Color.bucket{Needs,Wants,Savings} hexes.
    var color: Color {
        switch self {
        case .needs:   return Color(hex: 0x00D9A3)
        case .wants:   return Color(hex: 0xFBBF24)
        case .savings: return Color(hex: 0x60A5FA)
        }
    }
}

/// Urgency signal. Optional in the request — user may not specify.
/// Mirror of web's PurchaseUrgency.
enum PurchaseUrgency: String, Codable, CaseIterable, Equatable, Identifiable {
    case now
    case canWait = "can_wait"
    case notSure = "not_sure"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .now:     return "Need it now"
        case .canWait: return "Can wait"
        case .notSure: return "Not sure"
        }
    }
}

/// Request body for POST /api/decisions/ask.
/// Mirror of web's askSchema (ask/route.ts).
struct PurchaseAnalysisRequest: Codable {
    let itemName: String
    let amount: Double
    let bucket: PurchaseDecisionBucket
    let urgency: PurchaseUrgency?

    enum CodingKeys: String, CodingKey {
        case itemName = "item_name"
        case amount, bucket, urgency
    }
}

/// Response wrapping the persisted row id + the LLM payload.
struct AskDecisionResponse: Codable {
    let id: UUID
    let decision: DecisionData
}

/// LLM-generated decision payload.
/// Mirror of web's DecisionData.
struct DecisionData: Codable, Equatable {
    let verdict: Verdict
    let verdictLine: String
    let reasoning: String
    let impact: Impact
    let accent: DecisionAccent

    struct Impact: Codable, Equatable {
        let bucketAfter: BucketAfter
        let goalImpact: GoalImpact?
        let opportunityCost: String?

        enum CodingKeys: String, CodingKey {
            case bucketAfter     = "bucket_after"
            case goalImpact      = "goal_impact"
            case opportunityCost = "opportunity_cost"
        }
    }

    struct BucketAfter: Codable, Equatable {
        let bucket: PurchaseDecisionBucket
        let pctAfter: Int
        let overBudget: Bool

        enum CodingKeys: String, CodingKey {
            case bucket
            case pctAfter   = "pct_after"
            case overBudget = "over_budget"
        }
    }

    struct GoalImpact: Codable, Equatable {
        let goalName: String
        let pctOfGoal: Int
        let comment: String

        enum CodingKeys: String, CodingKey {
            case goalName  = "goal_name"
            case pctOfGoal = "pct_of_goal"
            case comment
        }
    }

    enum CodingKeys: String, CodingKey {
        case verdict
        case verdictLine = "verdict_line"
        case reasoning, impact, accent
    }
}

/// Outcome reported back to the server after user picks a final CTA.
enum DecisionOutcome: String, Codable {
    case bought
    case skipped
}
