import Foundation

// MARK: - B5 · Plan personnalisé sur la durée
// Un programme, pas un bulletin. Dérive la phase courante (sur les `targetWeeks`)
// adaptée au phototype et à l'objectif, avec une recommandation de fenêtre
// quotidienne. Cadrage toujours protecteur : la montée en dose est progressive.

struct PlanPhase {
    let index: Int          // 1-based
    let total: Int
    let name: String
    let focus: String       // objectif de la phase
    let dailyMinutes: Int   // minutes d'exposition conseillées/jour à UV modéré
    let tip: String

    var label: String { "Phase \(index)/\(total)" }
}

enum PlanProgram {
    /// Phase courante du programme.
    /// - week: semaine en cours (1-based)
    /// - targetWeeks: durée totale du plan
    static func phase(week: Int, targetWeeks: Int,
                      phototype: Fitzpatrick, goal: TanGoal) -> PlanPhase {
        // 3 phases réparties sur la durée du plan.
        let totalPhases = 3
        let perPhase = max(1, targetWeeks / totalPhases)
        let raw = min(totalPhases, (max(1, week) - 1) / perPhase + 1)

        // Base de minutes/jour selon le phototype (tolérance plus large = type foncé).
        let base = phototype.safeMinutesAtUV8
        // Montée progressive : phase 1 = 50 %, phase 2 = 75 %, phase 3 = 100 % du seuil.
        let ramp: Double = [1: 0.5, 2: 0.75, 3: 1.0][raw] ?? 0.5
        // L'objectif module légèrement (sécurité ne pousse pas la dose).
        let goalFactor: Double = {
            switch goal {
            case .safe: return 0.7
            case .maintain: return 0.85
            case .subtleGlow: return 1.0
            case .deepTan: return 1.1
            }
        }()
        let daily = max(5, Int((Double(base) * ramp * goalFactor).rounded()))

        switch raw {
        case 1:
            return PlanPhase(index: 1, total: totalPhases, name: "Préparation",
                             focus: "Habituer ta peau en douceur",
                             dailyMinutes: daily,
                             tip: "Expositions courtes et régulières. La crème reste systématique.")
        case 2:
            return PlanPhase(index: 2, total: totalPhases, name: "Construction",
                             focus: "Développer la teinte progressivement",
                             dailyMinutes: daily,
                             tip: "Tu peux allonger un peu, sans jamais dépasser ton seuil sûr.")
        default:
            return PlanPhase(index: 3, total: totalPhases, name: "Entretien",
                             focus: "Stabiliser et préserver ta teinte",
                             dailyMinutes: daily,
                             tip: "Maintiens le rythme. Hydratation et SPF gardent ta teinte uniforme.")
        }
    }
}
