#if DEBUG
import Foundation

/// Smoke-asserts du mapping TikTok. Appelé depuis SOLAApp en DEBUG si l'env
/// `SOLA_ANALYTICS_SMOKE` est présent. Zéro impact en prod.
enum TikTokAnalyticsSmoke {

    /// Sink de test qui enregistre les events envoyés au SDK.
    final class RecordingSink: TikTokEventSink {
        private(set) var initialized = false
        private(set) var attRequested = false
        private(set) var tracked: [(String, [String: Any])] = []
        func initializeSDK() { initialized = true }
        func requestATT(completion: @escaping () -> Void) { attRequested = true; completion() }
        func track(event: String, properties: [String: Any]) { tracked.append((event, properties)) }
    }

    static func run() {
        let sink = RecordingSink()
        let tt = TikTokAnalytics(sink: sink)

        // 1) Avant démarrage : capture ignorée (SDK non démarré).
        tt.capture("purchase_started", ["plan": "weekly"])
        assert(sink.tracked.isEmpty, "TikTok ne doit rien envoyer avant le démarrage")

        // 2) Lancement : prompt ATT natif SANS init du SDK (aucune donnée avant consentement).
        tt.requestTracking { }
        assert(sink.attRequested, "requestTracking doit demander l'ATT")
        assert(!sink.initialized, "requestTracking ne doit PAS initialiser le SDK avant consentement")

        // 3) Consentement : init du SDK (le statut ATT déjà choisi sera lu par le SDK).
        tt.optIn()
        assert(sink.initialized, "optIn doit initialiser le SDK")

        // 3) onboarding fini → CompleteTutorial.
        tt.capture("onboarding_completed", nil)
        assert(sink.tracked.last?.0 == "CompleteTutorial", "onboarding_completed → CompleteTutorial")

        // 4) paywall vu → ViewContent + content_type/paywall.
        tt.capture("paywall_viewed", ["source": "main", "variant": "A"])
        assert(sink.tracked.last?.0 == "ViewContent")
        assert(sink.tracked.last?.1["content_type"] as? String == "paywall")
        assert(sink.tracked.last?.1["content_id"] as? String == "A")

        // 5) plan choisi → AddToCart.
        tt.capture("paywall_plan_selected", ["plan": "annual"])
        assert(sink.tracked.last?.0 == "AddToCart")
        assert(sink.tracked.last?.1["content_id"] as? String == "annual")

        // 6) paiement lancé → InitiateCheckout.
        tt.capture("purchase_started", ["plan": "annual"])
        assert(sink.tracked.last?.0 == "InitiateCheckout")

        // 7) achat SANS essai → CompletePayment + value/currency.
        tt.capture("purchase_completed", ["plan": "annual", "price": "39,99 €",
                                          "value": 39.99, "currency": "EUR", "has_free_trial": false])
        assert(sink.tracked.last?.0 == "CompletePayment", "sans essai → CompletePayment")
        assert(sink.tracked.last?.1["value"] as? Double == 39.99)
        assert(sink.tracked.last?.1["currency"] as? String == "EUR")

        // 8) achat AVEC essai (weekly) → StartTrial + value/currency.
        tt.capture("purchase_completed", ["plan": "weekly", "price": "4,99 €",
                                          "value": 4.99, "currency": "EUR", "has_free_trial": true])
        assert(sink.tracked.last?.0 == "StartTrial", "avec essai → StartTrial")
        assert(sink.tracked.last?.1["value"] as? Double == 4.99)

        // 9) event non pertinent → ignoré.
        let before = sink.tracked.count
        tt.capture("purchase_failed", ["reason": "x"])
        tt.capture("consent_granted", nil)
        assert(sink.tracked.count == before, "les events non mappés doivent être ignorés")

        // 10) Composite : featureFlag ne touche que PostHog (TikTok renvoie nil).
        let mock = MockAnalyticsProvider(); mock.flags = ["k": "v"]
        let composite = CompositeAnalyticsProvider([mock, TikTokAnalytics(sink: RecordingSink())])
        composite.capture("purchase_started", ["plan": "weekly"])
        assert(mock.captured.count == 1, "composite doit diffuser à PostHog")
        assert(composite.featureFlag("k") as? String == "v", "featureFlag délégué à PostHog")

        print("✅ TikTokAnalyticsSmoke OK")
    }
}
#endif
