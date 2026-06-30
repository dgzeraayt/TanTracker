import Foundation
import PostHog

// MARK: - Provider abstrait (couture pour tests/mock)

protocol AnalyticsProvider: AnyObject {
    func setup()
    func optIn()
    func optOut()
    func capture(_ event: String, _ properties: [String: Any]?)
    func featureFlag(_ key: String) -> Any?
    func featureFlagPayload(_ key: String) -> Any?
    func reloadFeatureFlags()
}

// MARK: - Impl réelle PostHog

final class PostHogAnalytics: AnalyticsProvider {
    func setup() {
        guard AnalyticsConfig.isConfigured else { return }
        let config = PostHogConfig(apiKey: AnalyticsConfig.postHogAPIKey,
                                   host: AnalyticsConfig.postHogHost)
        config.optOut = true            // opt-in strict : rien tant que pas de consentement
        config.captureScreenViews = false
        config.captureApplicationLifecycleEvents = false
        PostHogSDK.shared.setup(config)
    }
    func optIn()  { PostHogSDK.shared.optIn() }
    func optOut() { PostHogSDK.shared.optOut() }
    func capture(_ event: String, _ properties: [String: Any]?) {
        PostHogSDK.shared.capture(event, properties: properties)
    }
    func featureFlag(_ key: String) -> Any? { PostHogSDK.shared.getFeatureFlag(key) }
    func featureFlagPayload(_ key: String) -> Any? { PostHogSDK.shared.getFeatureFlagPayload(key) }
    func reloadFeatureFlags() { PostHogSDK.shared.reloadFeatureFlags() }
}

// MARK: - Mock (preview / debug, sans réseau)

final class MockAnalyticsProvider: AnalyticsProvider {
    private(set) var captured: [(String, [String: Any]?)] = []
    private(set) var optedIn = false
    var flags: [String: Any] = [:]
    func setup() {}
    func optIn()  { optedIn = true }
    func optOut() { optedIn = false }
    func capture(_ event: String, _ properties: [String: Any]?) { captured.append((event, properties)) }
    func featureFlag(_ key: String) -> Any? { flags[key] }
    func featureFlagPayload(_ key: String) -> Any? { nil }
    func reloadFeatureFlags() {}
}

// MARK: - Events typés

enum AppEvent {
    case appOpened
    case consentGranted, consentDenied
    case onboardingStarted
    case onboardingStepViewed(step: Int, name: String)
    case onboardingCompleted
    case paywallViewed(source: String, variant: String)
    case paywallPlanSelected(plan: String)
    case purchaseStarted(plan: String)
    case purchaseCompleted(plan: String, price: String)
    case purchaseFailed(reason: String)
    case purchaseRestored
    case exitOfferShown, exitOfferAccepted

    var name: String {
        switch self {
        case .appOpened: return "app_opened"
        case .consentGranted: return "consent_granted"
        case .consentDenied: return "consent_denied"
        case .onboardingStarted: return "onboarding_started"
        case .onboardingStepViewed: return "onboarding_step_viewed"
        case .onboardingCompleted: return "onboarding_completed"
        case .paywallViewed: return "paywall_viewed"
        case .paywallPlanSelected: return "paywall_plan_selected"
        case .purchaseStarted: return "purchase_started"
        case .purchaseCompleted: return "purchase_completed"
        case .purchaseFailed: return "purchase_failed"
        case .purchaseRestored: return "purchase_restored"
        case .exitOfferShown: return "exit_offer_shown"
        case .exitOfferAccepted: return "exit_offer_accepted"
        }
    }

    var properties: [String: Any]? {
        switch self {
        case let .onboardingStepViewed(step, name): return ["step": step, "name": name]
        case let .paywallViewed(source, variant): return ["source": source, "variant": variant]
        case let .paywallPlanSelected(plan): return ["plan": plan]
        case let .purchaseStarted(plan): return ["plan": plan]
        case let .purchaseCompleted(plan, price): return ["plan": plan, "price": price]
        case let .purchaseFailed(reason): return ["reason": reason]
        default: return nil
        }
    }
}

// MARK: - Façade

enum Analytics {
    static var provider: AnalyticsProvider = PostHogAnalytics()
    static private(set) var isOptedIn = false

    static func setup() { provider.setup() }

    static func optIn()  { isOptedIn = true;  provider.optIn();  provider.reloadFeatureFlags() }
    static func optOut() { isOptedIn = false; provider.optOut() }

    static func capture(_ event: AppEvent) {
        guard isOptedIn else { return }              // no-op tant que pas consenti
        provider.capture(event.name, event.properties)
    }

    static func reloadFlags() { provider.reloadFeatureFlags() }
}
