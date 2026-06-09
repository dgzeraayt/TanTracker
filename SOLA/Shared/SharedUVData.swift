import Foundation

// MARK: - Données UV partagées app ⇄ widget (App Group)
// Ce fichier doit être membre des DEUX targets : l'app principale (écriture)
// et l'extension widget (lecture). Aucune dépendance UI — pur modèle + store.

/// Un point de prévision UV journalier (pour la vue large 7 jours).
struct SharedUVDay: Codable, Equatable {
    let dayLabel: String   // ex. "Lun"
    let weatherIcon: String // nom d'icône (SF Symbol fallback géré côté vue)
    let levelLabel: String // ex. "Élevé"
    let value: Double      // UV max du jour
}

/// Instantané des dernières données UV, écrit par l'app, lu par le widget.
struct SharedUVData: Codable, Equatable {
    let current: Double
    let peak: Double
    let levelLabel: String      // niveau de l'UV courant ("Modéré"…)
    let city: String
    let idealWindow: String
    let forecast: [SharedUVDay]  // 7 jours (peut être vide)
    let updatedAt: Date

    /// Donnée de repli si rien n'a encore été partagé.
    static let placeholder = SharedUVData(
        current: 0, peak: 0, levelLabel: "—", city: "—",
        idealWindow: "—", forecast: [], updatedAt: .distantPast)

    /// Les données sont-elles exploitables (non vides et pas trop vieilles) ?
    var isAvailable: Bool { updatedAt != .distantPast }
    /// Considérées périmées au-delà de 6 h (le widget affiche alors un état dédié).
    var isStale: Bool {
        guard isAvailable else { return true }
        return Date().timeIntervalSince(updatedAt) > 6 * 3600
    }
}

// MARK: - Store App Group
enum SharedStore {
    /// Identifiant App Group — doit être activé sur les 2 targets.
    static let appGroupID = "group.com.meflabs.SOLA"
    private static let key = "sola_shared_uv"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Écrit l'instantané (appelé par l'app à chaque rafraîchissement UV).
    static func write(_ data: SharedUVData) {
        guard let defaults, let raw = try? JSONEncoder().encode(data) else { return }
        defaults.set(raw, forKey: key)
    }

    /// Lit l'instantané (appelé par le widget). nil si indisponible.
    static func read() -> SharedUVData? {
        guard let defaults, let raw = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(SharedUVData.self, from: raw) else { return nil }
        return decoded
    }
}
