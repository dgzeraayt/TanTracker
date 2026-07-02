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
    /// Relance d'onboarding non terminé (rappel calendaire répétitif du soir).
    static let onboardingReminder = "onboarding-relance"
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
            title: String(localized: "Pic UV élevé aujourd'hui (UV \(v))"),
            body: String(localized: "Limite l'exposition aux heures de pointe. Fenêtre plus douce : \(window)."))
    }

    // MARK: Seuil de dose pendant l'exposition (~80 %)
    static func doseThreshold(remainingMinutes: Int) -> AlertMessage {
        AlertMessage(
            id: AlertID.doseThreshold,
            title: String(localized: "Risque élevé"),
            body: String(localized: "Tu approches de ta dose sûre (encore ~\(max(0, remainingMinutes)) min). Pense à te couvrir ou à chercher l'ombre."))
    }

    // MARK: Rappel proactif coup de soleil (calculé sur le temps sûr restant)
    static func burnRisk(inMinutes: Int) -> AlertMessage {
        AlertMessage(
            id: AlertID.burnRisk,
            title: String(localized: "Cherche l'ombre"),
            body: String(localized: "Risque de coup de soleil dans ~\(max(1, inMinutes)) min. Couvre-toi avant d'atteindre ton seuil."))
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
            title: String(localized: "Réapplique ta crème (SPF \(spf))"),
            body: String(localized: "La protection s'estompe avec le temps, la transpiration et la baignade. Réapplique pour rester protégé."))
    }

    // MARK: Retournement à mi-parcours (teinte uniforme)
    static func flip() -> AlertMessage {
        AlertMessage(
            id: AlertID.flip,
            title: String(localized: "Change de position"),
            body: String(localized: "Mi-parcours : retourne-toi pour une teinte uniforme."))
    }
}
