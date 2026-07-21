import Foundation

// MARK: - Couture SDK (testable)

/// Abstraction du SDK TikTok réel — permet de mocker en test.
protocol TikTokEventSink: AnyObject {
    func initializeSDK()
    func requestATT()
    func track(event: String, properties: [String: Any])
}

// MARK: - Provider TikTok

/// Renvoie les conversions vers TikTok. Gating : le SDK n'est initialisé qu'à
/// l'`optIn()` (consentement), jamais au launch → rien avant consentement.
final class TikTokAnalytics: AnalyticsProvider {
    private let sink: TikTokEventSink
    private var started = false

    init(sink: TikTokEventSink) { self.sink = sink }

    func setup() { /* rien : init différée à optIn() pour respecter le consentement */ }

    func optIn() {
        guard TikTokAdsConfig.isConfigured else { return }
        if !started { started = true; sink.initializeSDK() }
        sink.requestATT()
    }

    func optOut() { /* le SDK n'est jamais démarré sans opt-in ; rien à défaire */ }

    func capture(_ event: String, _ properties: [String: Any]?) {
        guard TikTokAdsConfig.isConfigured, started else { return }
        guard let mapped = Self.map(event, properties ?? [:]) else { return }
        sink.track(event: mapped.name, properties: mapped.props)
    }

    // TikTok ne gère pas de feature flags.
    func featureFlag(_ key: String) -> Any? { nil }
    func featureFlagPayload(_ key: String) -> Any? { nil }
    func reloadFeatureFlags() {}

    // MARK: Mapping AppEvent → event standard TikTok

    /// Traduit un event interne (name + properties) vers l'event TikTok.
    /// Renvoie `nil` pour les events non pertinents pub (ignorés).
    static func map(_ event: String, _ props: [String: Any]) -> (name: String, props: [String: Any])? {
        switch event {
        case "onboarding_completed":
            return ("CompleteTutorial", [:])
        case "paywall_viewed":
            var p: [String: Any] = ["content_type": "paywall"]
            if let variant = props["variant"] { p["content_id"] = variant }
            return ("ViewContent", p)
        case "paywall_plan_selected":
            return ("AddToCart", contentID(props, key: "plan"))
        case "purchase_started":
            return ("InitiateCheckout", contentID(props, key: "plan"))
        case "purchase_completed":
            let hasTrial = (props["has_free_trial"] as? Bool) ?? false
            var p = contentID(props, key: "plan")
            if let value = props["value"] { p["value"] = value }
            if let currency = props["currency"] { p["currency"] = currency }
            return (hasTrial ? "StartTrial" : "CompletePayment", p)
        default:
            return nil
        }
    }

    private static func contentID(_ props: [String: Any], key: String) -> [String: Any] {
        if let v = props[key] { return ["content_id": v] }
        return [:]
    }
}

// MARK: - Sink réel (SDK TikTok)

#if canImport(TikTokBusinessSDK)
import TikTokBusinessSDK

final class TikTokBusinessSink: TikTokEventSink {
    func initializeSDK() {
        // accessToken n'est pas utilisé côté client (secret serveur uniquement) → chaîne vide.
        let config = TikTokConfig(accessToken: "",
                                  appId: TikTokAdsConfig.iosAppID,
                                  tiktokAppId: TikTokAdsConfig.tiktokAppID)
        config?.disablePaymentTracking()   // on émet nos propres events revenu → pas de doublon
        #if DEBUG
        config?.enableDebugMode()          // Test Events dans TikTok Events Manager
        #endif
        TikTokBusiness.initializeSdk(config)
    }

    func requestATT() {
        TikTokBusiness.requestTrackingAuthorization { _ in }
    }

    func track(event: String, properties: [String: Any]) {
        let e = TikTokBaseEvent(eventName: event)
        for (k, v) in properties { e.addProperty(withKey: k, value: v) }
        TikTokBusiness.trackTTEvent(e)
    }
}
#endif

// MARK: - Sink no-op (fallback si module absent)

final class NoopTikTokSink: TikTokEventSink {
    func initializeSDK() {}
    func requestATT() {}
    func track(event: String, properties: [String: Any]) {}
}
