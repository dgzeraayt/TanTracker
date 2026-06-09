import Foundation

// MARK: - B3 · Coaching contextuel temps réel
// Transforme la donnée UV brute en instruction vivante qui dépend de l'heure,
// de l'UV courant et de la dose déjà accumulée. Ton toujours protecteur :
// le seuil sûr est un plafond, jamais une cible à dépasser.

struct CoachMessage {
    var headline: String   // instruction courte et vivante
    var detail: String     // contexte chiffré
    var tone: Tone

    enum Tone { case neutral, positive, caution, alert }
}

enum Coach {
    /// Génère le message de coaching du moment.
    static func message(uv: Double,
                        dose: ExposureDose,
                        idealWindow: String,
                        hour: Int,
                        hasExposureToday: Bool) -> CoachMessage {

        // 1) Seuil déjà atteint : priorité absolue à la protection.
        if dose.level == .reached {
            return CoachMessage(
                headline: "Tu as atteint ta dose sûre du jour.",
                detail: "Mets-toi à l'ombre et couvre-toi. Ta peau continue de développer sa teinte au repos.",
                tone: .alert)
        }

        // 2) Nuit / pas de soleil exploitable.
        if hour >= 20 || hour < 6 || uv < 1 {
            return CoachMessage(
                headline: "Pas d'UV à cette heure.",
                detail: hasExposureToday
                    ? "Belle session aujourd'hui. Hydrate ta peau pour fixer ta teinte."
                    : "Repère ta fenêtre de demain : \(idealWindow).",
                tone: .neutral)
        }

        // 3) Approche du plafond.
        if dose.level == .high {
            return CoachMessage(
                headline: "Tu approches de ton seuil.",
                detail: "Encore \(dose.remainingMinutes) min sûres. Prépare-toi à te couvrir et réapplique ta crème.",
                tone: .caution)
        }

        // 4) UV fort + dose en cours : encadrer.
        if dose.level == .caution {
            return CoachMessage(
                headline: "Surveille ta dose.",
                detail: "Il te reste \(dose.remainingMinutes) min avant ton seuil. Fenêtre douce : \(idealWindow).",
                tone: .caution)
        }

        // 5) UV élevé mais dose encore basse.
        if uv >= 6 {
            return CoachMessage(
                headline: "UV élevé en ce moment.",
                detail: "Tu peux t'exposer \(dose.remainingMinutes) min en sécurité avec ta crème. Fenêtre plus douce : \(idealWindow).",
                tone: .neutral)
        }

        // 6) Conditions favorables, dose basse.
        return CoachMessage(
            headline: hasExposureToday ? "Tu peux poursuivre en douceur." : "Bon moment pour bronzer en sécurité.",
            detail: "Il te reste \(dose.remainingMinutes) min sûres. Fenêtre optimale : \(idealWindow).",
            tone: .positive)
    }
}
