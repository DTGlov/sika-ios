import Foundation

/// Every PostHog event Sika fires. Names match web's analytics module
/// exactly — see web's src/lib/analytics/identify.ts. Do not add new
/// events here without updating web in parallel; cross-platform event
/// taxonomy must stay synchronized.
enum AnalyticsEvent {
    case appLaunched(firstLaunch: Bool)
    case signedUp

    case onboardingCompleted(stepsCompleted: Int)

    case transactionLogged(type: TransactionType, bucket: String?)

    case decisionOpened
    case decisionVerdictReceived(verdict: String)

    case monthlyRecapViewed
    case monthlyRecapShared

    enum TransactionType: String {
        case income, expense, transfer, adjustment
    }

    /// PostHog event name. MUST match web's event names exactly.
    var name: String {
        switch self {
        case .appLaunched: return "app_launched"
        case .signedUp: return "signed_up"
        case .onboardingCompleted: return "onboarding_completed"
        case .transactionLogged: return "transaction_logged"
        case .decisionOpened: return "decision_opened"
        case .decisionVerdictReceived: return "decision_verdict_received"
        case .monthlyRecapViewed: return "monthly_recap_viewed"
        case .monthlyRecapShared: return "monthly_recap_shared"
        }
    }

    /// Properties to attach to this event. Property keys must match
    /// web's exactly (camelCase as web wrote them, except where noted).
    var properties: [String: Any]? {
        switch self {
        case .appLaunched(let firstLaunch):
            return ["first_launch": firstLaunch]
        case .signedUp:
            return nil
        case .onboardingCompleted(let stepsCompleted):
            return ["stepsCompleted": stepsCompleted]
        case .transactionLogged(let type, let bucket):
            var props: [String: Any] = ["type": type.rawValue]
            if let bucket { props["bucket"] = bucket }
            return props
        case .decisionOpened, .monthlyRecapViewed, .monthlyRecapShared:
            return nil
        case .decisionVerdictReceived(let verdict):
            return ["verdict": verdict]
        }
    }
}
