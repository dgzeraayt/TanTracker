import Foundation

/// Valeur attachée à un event in-app AppsFlyer. Enum fermée plutôt que `Any`
/// pour rester `Equatable` (smoke-asserts) et `Sendable`.
enum AppsFlyerEventValue: Equatable, Sendable {
    case text(String)
    case number(Double)
}

/// Les events in-app remontés à AppsFlyer.
///
/// Noms et clés = constantes documentées AppsFlyer (`AFEventPurchase`,
/// `AFEventParamRevenue`, …), écrites en littéral pour que ce fichier — la partie
/// qui vaut d'être vérifiée — n'ait aucune dépendance au SDK.
///
/// Pour ajouter un event : un `case`, étendre `name` et `values`, un smoke-assert.
enum AppsFlyerEvent: Equatable, Sendable {

    /// Achat payant immédiat (abonnement sans essai, ou lifetime).
    case purchase(revenue: Double, currency: String?, productID: String)

    /// Abonnement démarré en période d'essai gratuit.
    ///
    /// Volontairement SANS `af_revenue` : aucun argent n'a changé de main ; compter
    /// le prix comme revenu gonflerait le ROAS côté TikTok Ads. Le prix voyage en
    /// `af_price`. Le vrai revenu essai→payant arrive côté serveur via
    /// l'intégration RevenueCat → AppsFlyer.
    case startTrial(price: Double, currency: String?, productID: String)

    var name: String {
        switch self {
        case .purchase: return "af_purchase"
        case .startTrial: return "af_start_trial"
        }
    }

    /// Montant et devise voyagent ensemble ou pas du tout : AppsFlyer interprète un
    /// montant sans `af_currency` dans la devise du compte (BRL ici), ce qui
    /// relabelliserait silencieusement un achat en EUR. Sans devise StoreKit,
    /// l'event part quand même (signal de conversion) avec le seul produit.
    var values: [String: AppsFlyerEventValue] {
        let product = [Key.contentID: AppsFlyerEventValue.text(productID)]

        guard let currency else { return product }

        let amount: [String: AppsFlyerEventValue] = switch self {
        case let .purchase(revenue, _, _): [Key.revenue: .number(revenue)]
        case let .startTrial(price, _, _): [Key.price: .number(price)]
        }

        return product
            .merging(amount) { current, _ in current }
            .merging([Key.currency: .text(currency)]) { current, _ in current }
    }

    /// `values` sous la forme non typée attendue par `AppsFlyerLib.logEvent(_:withValues:)`.
    var payload: [String: Any] {
        values.mapValues { value in
            switch value {
            case let .text(string): return string as Any
            case let .number(double): return double as Any
            }
        }
    }

    // MARK: - Private

    private var currency: String? {
        switch self {
        case let .purchase(_, currency, _): return currency
        case let .startTrial(_, currency, _): return currency
        }
    }

    private var productID: String {
        switch self {
        case let .purchase(_, _, productID): return productID
        case let .startTrial(_, _, productID): return productID
        }
    }

    private enum Key {
        static let revenue = "af_revenue"
        static let price = "af_price"
        static let currency = "af_currency"
        static let contentID = "af_content_id"
    }
}
