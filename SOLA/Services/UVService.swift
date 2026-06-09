import Foundation

struct UVForecast: Equatable {
    var current: Double
    var maxToday: Double
    var temperature: Double
    var hourly: [(hour: String, uv: Double)]      // heures de jour
    var peakHourIndex: Int
    var idealWindow: String
    var weatherLabel: String

    static func == (lhs: UVForecast, rhs: UVForecast) -> Bool {
        lhs.current == rhs.current && lhs.maxToday == rhs.maxToday &&
        lhs.temperature == rhs.temperature && lhs.hourly.map(\.uv) == rhs.hourly.map(\.uv)
    }

    /// Données de repli (cohérentes avec la maquette) si le réseau échoue.
    static let sample = UVForecast(
        current: 8, maxToday: 8, temperature: 28,
        hourly: [("8h",2),("9h",3.8),("10h",5.8),("11h",8.2),("12h",10),
                 ("13h",9.6),("14h",7.4),("15h",5.2),("16h",3.4)].map { ($0.0, $0.1) },
        peakHourIndex: 4, idealWindow: "16h00 – 17h30", weatherLabel: "Ensoleillé")
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
            .init(name: "forecast_days", value: "1")
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
        struct Daily: Decodable { let uv_index_max: [Double] }
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

        // graphe : une barre par heure de 8h à 16h
        var graph: [(String, Double)] = []
        var currentUV = 0.0
        var currentTemp = 0.0
        for (i, t) in times.enumerated() {
            let h = hour(from: t)
            if h == nowHour { currentUV = uvs[i]; currentTemp = temps[i] }
            if (8...16).contains(h) { graph.append(("\(h)h", max(0, uvs[i]))) }
        }
        if graph.isEmpty {
            for (i, t) in times.enumerated() where i < 9 { graph.append((shortHour(t), max(0, uvs[i]))) }
        }
        let peak = graph.enumerated().max(by: { $0.element.1 < $1.element.1 })?.offset ?? 0
        let maxUV = r.daily.uv_index_max.first ?? (uvs.max() ?? 0)
        if currentUV == 0 { currentUV = uvs[min(nowHour, uvs.count - 1)] }
        if currentTemp == 0 { currentTemp = temps[min(nowHour, temps.count - 1)] }

        // fenêtre idéale : créneau de l'après-midi où l'UV redescend sous 5
        let window = idealWindow(times: times, uvs: uvs)

        return UVForecast(
            current: (currentUV * 10).rounded() / 10,
            maxToday: (maxUV * 10).rounded() / 10,
            temperature: currentTemp.rounded(),
            hourly: graph.map { ($0.0, $0.1) },
            peakHourIndex: peak,
            idealWindow: window,
            weatherLabel: weatherLabel(uv: currentUV, temp: currentTemp))
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

    private static func weatherLabel(uv: Double, temp: Double) -> String {
        switch uv {
        case ..<2: return "Couvert"
        case ..<5: return "Voilé"
        default:   return "Ensoleillé"
        }
    }
}
