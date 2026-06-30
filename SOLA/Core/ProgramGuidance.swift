import Foundation

// MARK: - Conseil contextuel Programme (UV + heure + météo)
// Produit un CoachMessage adapté à l'onglet Programme,
// indépendant de la dose accumulée (contrairement à Coach).

enum ProgramGuidance {
    // Seuils propres au Programme (planification), distincts de ceux de Coach (temps réel).
    private static let minTanningUV: Double = 3    // en-dessous : bronzage négligeable
    private static let peakUV: Double = 8          // au-delà : pic, séance courte
    private static let eveningHour: Int = 19       // après : bascule vers la routine du soir

    /// Génère le message contextuel affiché en tête de l'onglet Programme.
    static func message(uv: Double,
                        hour: Int,
                        condition: WeatherCondition,
                        idealWindow: String) -> CoachMessage {
        // 1) Météo défavorable — pluie / averses / orage.
        if condition == .rain || condition == .showers || condition == .thunderstorm {
            return CoachMessage(
                headline: String(localized: "Pluie attendue."),
                detail: String(localized: "Privilégie un autre moment ou la routine du soir."),
                tone: .alert)
        }
        // 2) UV trop faible pour bronzer.
        if uv < minTanningUV {
            return CoachMessage(
                headline: String(localized: "UV faible (\(Int(uv.rounded()))) pour l'instant."),
                detail: String(localized: "Attends ton créneau idéal \(idealWindow)."),
                tone: .neutral)
        }
        // 3) UV au pic — protection renforcée.
        if uv >= peakUV {
            return CoachMessage(
                headline: String(localized: "UV au pic — séance courte."),
                detail: String(localized: "Crème impérative et limite ton exposition."),
                tone: .caution)
        }
        // 4) Fin de journée — orienter vers la routine soir.
        if hour >= eveningHour {
            return CoachMessage(
                headline: String(localized: "Le soleil baisse."),
                detail: String(localized: "Pense à ta routine du soir pour entretenir ton bronzage."),
                tone: .neutral)
        }
        // 5) Conditions favorables.
        return CoachMessage(
            headline: String(localized: "Bonnes conditions."),
            detail: String(localized: "C'est le moment de bronzer malin."),
            tone: .positive)
    }
}
