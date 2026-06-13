import Foundation
import ActivityKit

// MARK: - Attributs Live Activity « Sun exposure » — SOURCE UNIQUE
// Ce fichier est membre des DEUX targets (app + extension widget) via le groupe
// synchronisé « SharedKit ». Ne pas dupliquer ailleurs : ActivityKit associe
// l'activité à son UI via ce type ; deux copies distinctes cassent le rendu.
@available(iOS 16.1, *)
struct SunSessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Date à laquelle le seuil de risque est atteint (pilote le compte à rebours).
        var endDate: Date
        /// Progression 0…1 (début de session → seuil de risque).
        var progress: Double
        /// Phase courante de la session.
        var phase: Phase

        enum Phase: String, Codable, Hashable {
            case running   // exposition en cours
            case paused    // mise en pause par l'utilisateur
            case reached   // seuil atteint → se couvrir
        }
    }

    var city: String
    var uvIndex: Double
    var safeMinutes: Int
}
