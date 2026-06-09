import WidgetKit
import SwiftUI

// MARK: - Entrée de timeline
struct UVEntry: TimelineEntry {
    let date: Date
    let data: SharedUVData
    /// true si aucune donnée exploitable n'est partagée (état "indisponible").
    var unavailable: Bool { !data.isAvailable }
    var stale: Bool { data.isStale }
}

// MARK: - Provider
// Lit l'instantané écrit par l'app dans l'App Group. Rafraîchit la timeline
// toutes les 30 min (l'app force aussi un reload à chaque fetch UV).
struct UVProvider: TimelineProvider {
    func placeholder(in context: Context) -> UVEntry {
        UVEntry(date: Date(), data: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (UVEntry) -> Void) {
        let data = SharedStore.read() ?? .preview
        completion(UVEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UVEntry>) -> Void) {
        let data = SharedStore.read() ?? .placeholder
        let entry = UVEntry(date: Date(), data: data)
        // Rechargement périodique modéré pour préserver le budget système.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// Donnée d'aperçu (galerie de widgets, avant toute écriture de l'app).
extension SharedUVData {
    static let preview = SharedUVData(
        current: 6.2, peak: 9.0, levelLabel: "Élevé", city: "Nice",
        idealWindow: "16h00 – 17h30",
        forecast: (0..<7).map { i in
            SharedUVDay(dayLabel: ["Lun","Mar","Mer","Jeu","Ven","Sam","Dim"][i],
                        weatherIcon: i % 3 == 0 ? "cloudSun" : "sun",
                        levelLabel: ["Modéré","Élevé","Très élevé"][i % 3],
                        value: [4.5, 7.2, 9.0, 8.1, 6.4, 5.0, 3.8][i])
        },
        updatedAt: Date())
}
