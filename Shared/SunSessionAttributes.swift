import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Attributs Live Activity « Sun exposure »
// Décrit une session de bronzage active. Ce fichier doit être membre des DEUX
// targets : l'app (démarre/met à jour/termine) et l'extension widget (UI).
//
// Ton strictement préventif : le compte à rebours mène au SEUIL DE RISQUE, qui
// est un plafond. À l'échéance, l'activité passe en état final « couvre-toi » —
// jamais de prolongation.

#if canImport(ActivityKit)
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

    // Données fixes pour la durée de la session.
    var city: String
    var uvIndex: Double
    var safeMinutes: Int
}
#endif
