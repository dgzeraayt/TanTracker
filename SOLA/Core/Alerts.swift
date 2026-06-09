import Foundation

// MARK: - Feature 1 · Génération centralisée des alertes
// Source unique de vérité pour TOUS les messages d'alerte (pic UV, seuil de
// dose, rappel proactif coup de soleil, réapplication crème).
// Réutilise le calcul MED/dose existant (AppStore.safeMinutes / todayDose).
//
// Ton STRICTEMENT préventif : le seuil sûr est un plafond. Aucun message
// n'invite à rester ou à prolonger l'exposition.

/// Un message d'alerte prêt à être programmé en notification locale.
struct AlertMessage {
    /// Identifiant stable (permet d'annuler/remplacer une alerte programmée).
    let id: String
    let title: String
    let body: String
}

enum AlertID {
    static let uvPeak     = "alert-uv-peak"
    static let doseThreshold = "alert-dose-threshold"
    static let burnRisk   = "alert-burn-risk"
    static let spfReapply = "alert-spf-reapply"
    static let flip       = "alert-flip"
}

enum Alerts {
    /// Seuil d'UV (prévision du jour) au-delà duquel on prévient l'utilisateur.
    static let highUVThreshold: Double = 8
    /// Fraction du plafond sûr déclenchant l'alerte « risque élevé ».
    static let doseWarnFraction: Double = 0.80
    /// Marge de pré-alerte coup de soleil (minutes avant le plafond).
    static let burnLeadMinutes: Int = 10

    // MARK: Pic UV (prévision du jour)
    /// Alerte si le pic UV prévu dépasse le seuil élevé. nil sinon.
    static func uvPeak(maxToday: Double, window: String) -> AlertMessage? {
        guard maxToday >= highUVThreshold else { return nil }
        let v = maxToday.formatted(.number.precision(.fractionLength(0...1)))
        return AlertMessage(
            id: AlertID.uvPeak,
            title: "Pic UV élevé aujourd'hui (UV \(v))",
            body: "Limite l'exposition aux heures de pointe. Fenêtre plus douce : \(window).")
    }

    // MARK: Seuil de dose pendant l'exposition (~80 %)
    static func doseThreshold(remainingMinutes: Int) -> AlertMessage {
        AlertMessage(
            id: AlertID.doseThreshold,
            title: "Risque élevé",
            body: "Tu approches de ta dose sûre (encore ~\(max(0, remainingMinutes)) min). Pense à te couvrir ou à chercher l'ombre.")
    }

    // MARK: Rappel proactif coup de soleil (calculé sur le temps sûr restant)
    static func burnRisk(inMinutes: Int) -> AlertMessage {
        AlertMessage(
            id: AlertID.burnRisk,
            title: "Cherche l'ombre",
            body: "Risque de coup de soleil dans ~\(max(1, inMinutes)) min. Couvre-toi avant d'atteindre ton seuil.")
    }

    // MARK: Réapplication de crème (selon SPF et durée écoulée)
    /// Intervalle de réapplication conseillé (minutes) selon le SPF.
    static func reapplyInterval(spf: Int) -> Int {
        // Plus le SPF est bas, plus on réapplique tôt. Plafonné à 2h.
        switch spf {
        case ..<20: return 80
        case ..<30: return 100
        default:    return 120
        }
    }

    static func spfReapply(spf: Int) -> AlertMessage {
        AlertMessage(
            id: AlertID.spfReapply,
            title: "Réapplique ta crème (SPF \(spf))",
            body: "La protection s'estompe avec le temps, la transpiration et la baignade. Réapplique pour rester protégé.")
    }

    // MARK: Retournement à mi-parcours (teinte uniforme)
    static func flip() -> AlertMessage {
        AlertMessage(
            id: AlertID.flip,
            title: "Change de position",
            body: "Mi-parcours : retourne-toi pour une teinte uniforme.")
    }
}
