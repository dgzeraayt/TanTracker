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

/// Pourquoi un achat n'a pas abouti. Sert à distinguer les cas dans PostHog :
/// une annulation volontaire n'a rien à voir avec un accès qui ne se débloque pas.
enum PurchaseFailureKind: String {
    case storeError         = "store_error"          // erreur remontée par StoreKit / RevenueCat
    case entitlementMissing = "entitlement_missing"  // achat validé mais entitlement absent
    case productUnavailable = "product_unavailable"  // produit absent de l'offering courante
}

enum AppEvent {
    case appOpened
    case onboardingStarted
    case onboardingStepViewed(step: Int, name: String)
    case onboardingCompleted
    case paywallViewed(source: String, variant: String)
    case paywallPlanSelected(plan: String)
    case purchaseStarted(plan: String)
    case purchaseCompleted(plan: String, price: String, value: Double, currency: String, hasFreeTrial: Bool)
    case purchaseCancelled(plan: String)
    case purchaseFailed(plan: String, kind: PurchaseFailureKind, reason: String)
    case purchaseRestored
    case exitOfferShown, exitOfferAccepted
    case spinWheelSpun
    case spinWheelRewardClaimed(rewardPercent: Int)

    var name: String {
        switch self {
        case .appOpened: return "app_opened"
        case .onboardingStarted: return "onboarding_started"
        case .onboardingStepViewed: return "onboarding_step_viewed"
        case .onboardingCompleted: return "onboarding_completed"
        case .paywallViewed: return "paywall_viewed"
        case .paywallPlanSelected: return "paywall_plan_selected"
        case .purchaseStarted: return "purchase_started"
        case .purchaseCompleted: return "purchase_completed"
        case .purchaseCancelled: return "purchase_cancelled"
        case .purchaseFailed: return "purchase_failed"
        case .purchaseRestored: return "purchase_restored"
        case .exitOfferShown: return "exit_offer_shown"
        case .exitOfferAccepted: return "exit_offer_accepted"
        case .spinWheelSpun: return "spin_wheel_spun"
        case .spinWheelRewardClaimed: return "spin_wheel_reward_claimed"
        }
    }

    var properties: [String: Any]? {
        switch self {
        case let .onboardingStepViewed(step, name): return ["step": step, "name": name]
        case let .paywallViewed(source, variant): return ["source": source, "variant": variant]
        case let .paywallPlanSelected(plan): return ["plan": plan]
        case let .purchaseStarted(plan): return ["plan": plan]
        case let .purchaseCompleted(plan, price, value, currency, hasFreeTrial):
            return ["plan": plan, "price": price, "value": value,
                    "currency": currency, "has_free_trial": hasFreeTrial]
        case let .purchaseCancelled(plan): return ["plan": plan]
        case let .purchaseFailed(plan, kind, reason): return ["plan": plan, "kind": kind.rawValue, "reason": reason]
        case let .spinWheelRewardClaimed(rewardPercent): return ["reward_percent": rewardPercent]
        default: return nil
        }
    }
}

// MARK: - Façade

enum Analytics {
    private static let tiktok = TikTokAnalytics(sink: Analytics.defaultTikTokSink())
    static var provider: AnalyticsProvider = CompositeAnalyticsProvider([
        PostHogAnalytics(),
        tiktok
    ])
    static private(set) var isOptedIn = false

    private static func defaultTikTokSink() -> TikTokEventSink {
        #if canImport(TikTokBusinessSDK)
        return TikTokBusinessSink()
        #else
        return NoopTikTokSink()
        #endif
    }

    static func setup() { provider.setup() }

    /// Au lancement : présente le prompt ATT natif, puis exécute `completion`.
    /// Découplé du bandeau de consentement analytics (guideline 2.1) — n'envoie
    /// aucune donnée et n'initialise pas le SDK, c'est purement le prompt système.
    static func requestTracking(completion: @escaping () -> Void) {
        tiktok.requestTracking(completion: completion)
    }

    static func optIn()  { isOptedIn = true;  provider.optIn();  provider.reloadFeatureFlags() }
    static func optOut() { isOptedIn = false; provider.optOut() }

    static func capture(_ event: AppEvent) {
        guard isOptedIn else { return }              // no-op tant que pas consenti
        provider.capture(event.name, event.properties)
    }

    static func reloadFlags() { provider.reloadFeatureFlags() }
}
