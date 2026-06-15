import Foundation
import Combine

// MARK: - Source UNIQUE de la prévision UV (2.2)
// La prévision — et donc la « fenêtre idéale » (ex. 18h00 – 19h30) — est calculée
// UNE seule fois ici puis propagée à tous les écrans (Accueil, Plan, UV, reco) via
// l'environnement. Avant, chaque écran appelait `UVService.fetch` dans son propre
// `@State`, ce qui multipliait les appels réseau et pouvait afficher des fenêtres
// divergentes (dont le repli `.sample`). Plus aucune valeur codée en dur par écran.
@MainActor
final class ForecastStore: ObservableObject {
    @Published private(set) var forecast: UVForecast = .sample
    @Published private(set) var isLoading = false

    private var loadedKey: String?
    private var loadedAt: Date?
    /// Fraîcheur acceptable d'une prévision avant re-fetch (30 min).
    private let maxAge: TimeInterval = 30 * 60

    /// Charge la prévision pour une localisation. Déduplique : un seul fetch par
    /// localisation tant que la donnée est fraîche, quel que soit l'écran appelant.
    func loadIfNeeded(lat: Double, lon: Double, city: String) async {
        let key = "\(lat),\(lon)"
        let fresh = loadedAt.map { Date().timeIntervalSince($0) < maxAge } ?? false
        if key == loadedKey && fresh { return }
        isLoading = true
        let f = await UVService.fetch(lat: lat, lon: lon)
        forecast = f
        loadedKey = key
        loadedAt = Date()
        isLoading = false
        // Publication widget (App Group) faite une seule fois, à la source.
        WidgetBridge.publish(forecast: f, city: city)
    }
}

/// Un jour de prévision UV (pour la vue large du widget).
struct DailyUV: Equatable {
    let dayLabel: String   // ex. "Lun"
    let uvMax: Double
    let sunny: Bool        // ensoleillé (UV élevé) vs voilé
}

struct UVForecast: Equatable {
    var current: Double
    var maxToday: Double
    var temperature: Double
    var hourly: [(hour: String, uv: Double)]      // heures de jour
    var peakHourIndex: Int
    var idealWindow: String
    var weatherLabel: String
    var daily: [DailyUV] = []                      // prévision 7 jours
    // Aperçu de demain (nil si la prévision ne couvre pas demain) — calculé ici,
    // à la source unique, comme la fenêtre idéale du jour.
    var tomorrowMaxUV: Double? = nil
    var tomorrowWindow: String? = nil

    static func == (lhs: UVForecast, rhs: UVForecast) -> Bool {
        lhs.current == rhs.current && lhs.maxToday == rhs.maxToday &&
        lhs.temperature == rhs.temperature && lhs.hourly.map(\.uv) == rhs.hourly.map(\.uv) &&
        lhs.daily == rhs.daily
    }

    /// Données de repli (cohérentes avec la maquette) si le réseau échoue.
    static let sample = UVForecast(
        current: 8, maxToday: 10, temperature: 28,
        hourly: [("8h",2),("9h",3.8),("10h",5.8),("11h",8.2),("12h",10),
                 ("13h",9.6),("14h",7.4),("15h",5.2),("16h",4.2),
                 ("17h",3.4),("18h",2.6),("19h",1.6)].map { ($0.0, $0.1) },
        peakHourIndex: 4, idealWindow: "17h00 – 18h30", weatherLabel: "Ensoleillé")
}

enum UVService {
    /// Récupère l'indice UV horaire + température via Open-Meteo (gratuit, sans clé).
    static func fetch(lat: Double, lon: Double) async -> UVForecast {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(lat)),
            .init(name: "longitude", value: String(lon)),
            .init(name: "hourly", value: "uv_index,temperature_2m"),
            .init(name: "daily", value: "uv_index_max"),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "7")
        ]
        guard let url = comps.url else { return .sample }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try parse(data) ?? .sample
        } catch {
            return .sample
        }
    }

    private struct Response: Decodable {
        struct Hourly: Decodable { let time: [String]; let uv_index: [Double]; let temperature_2m: [Double] }
        struct Daily: Decodable { let time: [String]; let uv_index_max: [Double] }
        let hourly: Hourly
        let daily: Daily
    }


    private static func parse(_ data: Data) throws -> UVForecast? {
        let r = try JSONDecoder().decode(Response.self, from: data)
        let times = r.hourly.time
        let uvs = r.hourly.uv_index
        let temps = r.hourly.temperature_2m
        guard times.count == uvs.count, !uvs.isEmpty else { return nil }

        let cal = Calendar.current
        let nowHour = cal.component(.hour, from: .now)

        // On restreint l'horaire à AUJOURD'HUI (24 premières entrées) : avec
        // forecast_days=7, la série horaire couvre 7×24 h.
        let todayCount = min(24, times.count)

        // graphe : une barre par heure de 8h à 19h (aujourd'hui uniquement).
        // La plage couvre la fin de journée pour que la « fenêtre idéale » (souvent
        // en soirée, quand l'UV redescend sous 5) reste visible sur le graphe.
        var graph: [(String, Double)] = []
        var currentUV = 0.0
        var currentTemp = 0.0
        for i in 0..<todayCount {
            let h = hour(from: times[i])
            if h == nowHour { currentUV = uvs[i]; currentTemp = temps[i] }
            if (8...19).contains(h) { graph.append(("\(h)h", max(0, uvs[i]))) }
        }
        if graph.isEmpty {
            for i in 0..<min(12, todayCount) { graph.append((shortHour(times[i]), max(0, uvs[i]))) }
        }
        let peak = graph.enumerated().max(by: { $0.element.1 < $1.element.1 })?.offset ?? 0
        let maxUV = r.daily.uv_index_max.first ?? (uvs.max() ?? 0)
        if currentUV == 0 { currentUV = uvs[min(nowHour, uvs.count - 1)] }
        if currentTemp == 0 { currentTemp = temps[min(nowHour, temps.count - 1)] }

        // fenêtre idéale : créneau de l'après-midi où l'UV redescend sous 5
        let window = idealWindow(times: Array(times.prefix(todayCount)),
                                 uvs: Array(uvs.prefix(todayCount)))

        // prévision 7 jours (labels jour court + UV max).
        let daily = buildDaily(times: r.daily.time, maxima: r.daily.uv_index_max)

        // Aperçu de demain : UV max (daily[1]) + fenêtre conseillée dérivée des
        // heures 24–47 de la série horaire (même critère prudent UV 2–5).
        let tomorrowMax = r.daily.uv_index_max.count > 1 ? r.daily.uv_index_max[1] : nil
        let tomorrowWindow = times.count > 24
            ? tomorrowIdealWindow(times: Array(times[24..<min(48, times.count)]),
                                  uvs: Array(uvs[24..<min(48, uvs.count)]))
            : nil

        return UVForecast(
            current: (currentUV * 10).rounded() / 10,
            maxToday: (maxUV * 10).rounded() / 10,
            temperature: currentTemp.rounded(),
            hourly: graph.map { ($0.0, $0.1) },
            peakHourIndex: peak,
            idealWindow: window,
            weatherLabel: weatherLabel(uv: currentUV, temp: currentTemp),
            daily: daily,
            tomorrowMaxUV: tomorrowMax.map { ($0 * 10).rounded() / 10 },
            tomorrowWindow: tomorrowWindow)
    }

    /// Construit la prévision journalière (label jour court FR + UV max).
    private static func buildDaily(times: [String], maxima: [Double]) -> [DailyUV] {
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM-dd"
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        let dayFmt = DateFormatter()
        dayFmt.locale = Locale(identifier: "fr_FR")
        dayFmt.dateFormat = "EEE"

        var result: [DailyUV] = []
        for (i, t) in times.enumerated() where i < maxima.count {
            let uvMax = max(0, maxima[i])
            let label: String
            if let d = inFmt.date(from: t) {
                label = dayFmt.string(from: d).capitalized.replacingOccurrences(of: ".", with: "")
            } else {
                label = "J\(i)"
            }
            result.append(DailyUV(dayLabel: label, uvMax: (uvMax * 10).rounded() / 10, sunny: uvMax >= 5))
        }
        return Array(result.prefix(7))
    }

    private static func hour(from iso: String) -> Int {
        // "2026-06-09T14:00"
        guard let t = iso.split(separator: "T").last, let h = Int(t.prefix(2)) else { return 0 }
        return h
    }
    private static func shortHour(_ iso: String) -> String { "\(hour(from: iso))h" }

    private static func idealWindow(times: [String], uvs: [Double]) -> String {
        // après le pic, premier créneau de ~90 min avec UV 2–5
        let nowHour = Calendar.current.component(.hour, from: .now)
        for (i, t) in times.enumerated() {
            let h = hour(from: t)
            if h > nowHour && (2.0...5.0).contains(uvs[i]) {
                return String(format: "%dh00 – %dh30", h, h + 1)
            }
        }
        return "Tôt le matin ou en fin de journée"
    }

    /// Fenêtre conseillée pour DEMAIN : premier créneau de la journée (8h–19h)
    /// où l'UV est dans la zone prudente 2–5 (assez pour bronzer, sans brûler).
    private static func tomorrowIdealWindow(times: [String], uvs: [Double]) -> String? {
        for (i, t) in times.enumerated() where i < uvs.count {
            let h = hour(from: t)
            if (8...19).contains(h) && (2.0...5.0).contains(uvs[i]) {
                return String(format: "%dh00 – %dh30", h, h + 1)
            }
        }
        return nil
    }

    private static func weatherLabel(uv: Double, temp: Double) -> String {
        switch uv {
        case ..<2: return "Couvert"
        case ..<5: return "Voilé"
        default:   return "Ensoleillé"
        }
    }
}
