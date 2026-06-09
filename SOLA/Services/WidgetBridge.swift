import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Pont app → widget
// Mappe la prévision interne (UVForecast) vers le modèle partagé (SharedUVData),
// l'écrit dans l'App Group et demande au widget de recharger sa timeline.
// Additif : n'affecte en rien la logique UV/MED existante.
enum WidgetBridge {

    /// Niveau qualitatif de l'UV courant (même découpage que l'écran UV).
    private static func levelLabel(_ uv: Double) -> String {
        switch uv {
        case ..<3: return "Faible"; case ..<6: return "Modéré"
        case ..<8: return "Élevé"; case ..<11: return "Très élevé"; default: return "Extrême"
        }
    }

    /// Publie la dernière prévision UV vers le widget.
    static func publish(forecast: UVForecast, city: String) {
        // Prévision 7 jours réelle si disponible, sinon repli sur aujourd'hui.
        let days: [SharedUVDay]
        if forecast.daily.isEmpty {
            days = [SharedUVDay(
                dayLabel: "Auj",
                weatherIcon: forecast.current >= 5 ? "sun" : "cloudSun",
                levelLabel: levelLabel(forecast.maxToday),
                value: forecast.maxToday)]
        } else {
            days = forecast.daily.map { d in
                SharedUVDay(
                    dayLabel: d.dayLabel,
                    weatherIcon: d.sunny ? "sun" : "cloudSun",
                    levelLabel: levelLabel(d.uvMax),
                    value: d.uvMax)
            }
        }

        let data = SharedUVData(
            current: forecast.current,
            peak: forecast.maxToday,
            levelLabel: levelLabel(forecast.current),
            city: city,
            idealWindow: forecast.idealWindow,
            forecast: days,
            updatedAt: Date())

        SharedStore.write(data)

        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
}
