import Foundation

// MARK: - Conseil contextuel Programme (UV + heure + météo)
// Produit un CoachMessage adapté à l'onglet Programme,
// indépendant de la dose accumulée (contrairement à Coach).

enum ProgramGuidance {
    /// Génère le message contextuel affiché en tête de l'onglet Programme.
    static func message(uv: Double,
                        hour: Int,
                        condition: WeatherCondition,
                        idealWindow: String) -> CoachMessage {
        // 1) Météo défavorable — pluie / averses / orage.
        if condition == .rain || condition == .showers || condition == .thunderstorm {
            return CoachMessage(
                headline: "Pluie attendue.",
                detail: "Privilégie un autre moment ou la routine du soir.",
                tone: .alert)
        }
        // 2) UV trop faible pour bronzer.
        if uv < 3 {
            return CoachMessage(
                headline: "UV faible (\(Int(uv.rounded()))) pour l'instant.",
                detail: "Attends ton créneau idéal \(idealWindow).",
                tone: .neutral)
        }
        // 3) UV au pic — protection renforcée.
        if uv >= 8 {
            return CoachMessage(
                headline: "UV au pic — séance courte.",
                detail: "Crème impérative et limite ton exposition.",
                tone: .caution)
        }
        // 4) Fin de journée — orienter vers la routine soir.
        if hour >= 19 {
            return CoachMessage(
                headline: "Le soleil baisse.",
                detail: "Pense à ta routine du soir pour entretenir ton bronzage.",
                tone: .neutral)
        }
        // 5) Conditions favorables.
        return CoachMessage(
            headline: "Bonnes conditions.",
            detail: "C'est le moment de bronzer malin.",
            tone: .positive)
    }
}
