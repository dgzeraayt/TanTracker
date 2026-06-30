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
                headline: String(localized: "Assez de soleil pour aujourd'hui."),
                detail: String(localized: "Mets-toi à l'ombre : ta peau continue de bronzer au repos."),
                tone: .alert)
        }

        // 2) Nuit / pas de soleil exploitable.
        if hour >= 20 || hour < 6 || uv < 1 {
            return CoachMessage(
                headline: String(localized: "Le soleil est trop bas pour bronzer."),
                detail: hasExposureToday
                    ? String(localized: "Belle séance aujourd'hui. Hydrate ta peau pour faire durer ton bronzage.")
                    : String(localized: "Demain, le meilleur moment pour bronzer : \(idealWindow)."),
                tone: .neutral)
        }

        // 3) Approche du plafond.
        if dose.level == .high {
            return CoachMessage(
                headline: String(localized: "Tu approches de ta limite du jour."),
                detail: String(localized: "Encore \(dose.remainingMinutes) min, puis mets-toi à l'ombre. Remets de la crème."),
                tone: .caution)
        }

        // 4) UV fort + dose en cours : encadrer.
        if dose.level == .caution {
            return CoachMessage(
                headline: String(localized: "Pense à lever le pied."),
                detail: String(localized: "Encore \(dose.remainingMinutes) min de soleil sans risque aujourd'hui."),
                tone: .caution)
        }

        // 5) UV élevé mais dose encore basse.
        if uv >= 6 {
            return CoachMessage(
                headline: String(localized: "Le soleil tape fort en ce moment."),
                detail: String(localized: "Avec ta crème, tu peux rester \(dose.remainingMinutes) min. Sinon, vise le créneau plus doux : \(idealWindow)."),
                tone: .neutral)
        }

        // 6) Conditions favorables, dose basse.
        return CoachMessage(
            headline: hasExposureToday ? String(localized: "Tu peux continuer en douceur.") : String(localized: "C'est un bon moment pour bronzer."),
            detail: String(localized: "Jusqu'à \(dose.remainingMinutes) min de soleil sans risque. Meilleur créneau : \(idealWindow)."),
            tone: .positive)
    }
}
