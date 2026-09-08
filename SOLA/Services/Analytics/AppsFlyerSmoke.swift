#if DEBUG
import Foundation

/// Smoke-asserts du mapping AppsFlyer (pas de cible de tests dans ce projet —
/// même convention que `TikTokAnalyticsSmoke`). Appelé depuis SOLAApp en DEBUG
/// si l'env `SOLA_ANALYTICS_SMOKE` est présent. Zéro impact en prod.
enum AppsFlyerSmoke {
    static func run() {
        // 1) Noms = identifiants « wire » stables (dashboard, TikTok, schéma SKAN).
        assert(AppsFlyerEvent.purchase(revenue: 1, currency: "EUR", productID: "x").name == "af_purchase")
        assert(AppsFlyerEvent.startTrial(price: 1, currency: "EUR", productID: "x").name == "af_start_trial")

        // 2) Achat : revenu + devise + produit.
        let purchase = AppsFlyerEvent.purchase(revenue: 39.99, currency: "EUR", productID: "annual")
        assert(purchase.values == ["af_revenue": .number(39.99), "af_currency": .text("EUR"),
                                   "af_content_id": .text("annual")])

        // 3) Essai : prix, JAMAIS de revenu.
        let trial = AppsFlyerEvent.startTrial(price: 4.99, currency: "EUR", productID: "weekly")
        assert(trial.values == ["af_price": .number(4.99), "af_currency": .text("EUR"),
                                "af_content_id": .text("weekly")])
        assert(trial.values["af_revenue"] == nil, "un essai ne doit pas porter de revenu")

        // 4) Devise absente → montant retiré aussi (pas de défaut BRL/USD silencieux).
        let noCurrency = AppsFlyerEvent.purchase(revenue: 9.99, currency: nil, productID: "lifetime")
        assert(noCurrency.values == ["af_content_id": .text("lifetime")])
        assert(noCurrency.payload["af_revenue"] == nil && noCurrency.payload["af_currency"] == nil)

        // 5) Pont vers le dictionnaire non typé du SDK.
        assert(purchase.payload["af_revenue"] as? Double == 39.99)
        assert(purchase.payload["af_currency"] as? String == "EUR")
        assert(purchase.payload.count == 3)

        // 6) Routage achat validé → essai vs revenu réel.
        assert(PurchaseManager.appsFlyerEvent(price: 4.99, currency: "EUR", productID: "weekly", isTrial: true)
               == .startTrial(price: 4.99, currency: "EUR", productID: "weekly"))
        assert(PurchaseManager.appsFlyerEvent(price: 39.99, currency: "EUR", productID: "annual", isTrial: false)
               == .purchase(revenue: 39.99, currency: "EUR", productID: "annual"))

        print("✅ AppsFlyerSmoke OK")
    }
}
#endif
