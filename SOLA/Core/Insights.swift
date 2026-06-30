import Foundation

// MARK: - B4 · Mémoire qui parle (insights)
// Dérive 1–3 observations simples de l'historique local que seule cette app
// peut produire (fenêtre horaire préférée, régularité, progression). C'est le
// moat de rétention : un historique qu'on ne veut pas perdre.

struct Insight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

enum Insights {
    /// Génère jusqu'à 3 observations à partir des sessions d'exposition.
    static func derive(from sessions: [TanSession],
                       planStart: Date,
                       currentIndex: Int,
                       baseline: Int) -> [Insight] {
        let exposures = sessions.filter { $0.durationMinutes > 0 }
        guard exposures.count >= 2 else { return [] }

        var result: [Insight] = []
        let cal = Calendar.current

        // 1) Fenêtre horaire préférée (heure moyenne pondérée par les sessions).
        let hours = exposures.map { cal.component(.hour, from: $0.date) }
        if let window = preferredWindow(hours: hours) {
            result.append(Insight(
                icon: "clock",
                title: String(localized: "Ta fenêtre préférée"),
                detail: String(localized: "Tu t'exposes surtout entre \(window.lowerBound)h et \(window.upperBound)h — \(windowSafetyNote(window.lowerBound)).")))
        }

        // 2) Régularité (sessions par semaine sur la durée du plan).
        let weeks = max(1, (cal.dateComponents([.weekOfYear], from: planStart, to: .now).weekOfYear ?? 0) + 1)
        let perWeek = Double(exposures.count) / Double(weeks)
        if perWeek >= 0.5 {
            let rounded = (perWeek * 10).rounded() / 10
            result.append(Insight(
                icon: "cal",
                title: String(localized: "Ta régularité"),
                detail: String(localized: "Environ \(formatted(rounded)) session\(rounded >= 2 ? "s" : "") par semaine. \(regularityNote(perWeek))")))
        }

        // 3) Progression d'indice depuis le départ.
        let gain = currentIndex - baseline
        if gain > 0 {
            result.append(Insight(
                icon: "trend",
                title: String(localized: "Ta progression"),
                detail: String(localized: "+\(gain) points d'indice depuis le début. Continue à ce rythme, ta teinte se construit en douceur.")))
        }

        return Array(result.prefix(3))
    }

    /// Fenêtre horaire dominante : intervalle de 2h le plus fréquent.
    private static func preferredWindow(hours: [Int]) -> ClosedRange<Int>? {
        guard !hours.isEmpty else { return nil }
        var buckets: [Int: Int] = [:]   // heure de début de tranche 2h -> compte
        for h in hours {
            let start = (h / 2) * 2
            buckets[start, default: 0] += 1
        }
        guard let best = buckets.max(by: { $0.value < $1.value })?.key else { return nil }
        return best...(best + 2)
    }

    private static func windowSafetyNote(_ startHour: Int) -> String {
        switch startHour {
        case ..<10:  return String(localized: "ta fenêtre la plus douce")
        case 10..<16: return String(localized: "pense à bien te protéger sur ce créneau")
        default:     return String(localized: "une fenêtre sûre en fin de journée")
        }
    }

    private static func regularityNote(_ perWeek: Double) -> String {
        switch perWeek {
        case ..<1:  return String(localized: "Une cadence prudente, idéale pour une teinte durable.")
        case ..<3:  return String(localized: "Un rythme régulier et sain.")
        default:    return String(localized: "Pense à laisser ta peau récupérer entre les sessions.")
        }
    }

    private static func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
