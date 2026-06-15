import WidgetKit
import SwiftUI
import UIKit
import CoreText

// MARK: - Palette répliquée depuis la DA Suny (OKLCH -> sRGB)
extension Color {
    init(oklch L: Double, _ C: Double, _ H: Double, opacity: Double = 1) {
        let hr = H * .pi / 180
        let a = C * cos(hr), b = C * sin(hr)
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b
        let l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_
        var r =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        var g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        var bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        func gamma(_ x: Double) -> Double {
            let c = max(0, min(1, x))
            return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
        }
        r = gamma(r); g = gamma(g); bb = gamma(bb)
        self.init(.sRGB, red: r, green: g, blue: bb, opacity: opacity)
    }
    init(lightOKLCH light: (Double, Double, Double), darkOKLCH dark: (Double, Double, Double)) {
        let l = UIColor(Color(oklch: light.0, light.1, light.2))
        let d = UIColor(Color(oklch: dark.0, dark.1, dark.2))
        self = Color(UIColor { $0.userInterfaceStyle == .dark ? d : l })
    }
}

enum WPalette {
    static let bg        = Color(lightOKLCH: (0.962, 0.018, 72), darkOKLCH: (0.15, 0.02, 260))
    static let surface   = Color(lightOKLCH: (0.988, 0.010, 82), darkOKLCH: (0.22, 0.03, 255))
    static let ink       = Color(lightOKLCH: (0.205, 0.014, 52), darkOKLCH: (0.95, 0.01, 280))
    static let ink3      = Color(lightOKLCH: (0.455, 0.026, 58), darkOKLCH: (0.66, 0.02, 280))
    static let amber     = Color(oklch: 0.800, 0.130, 78)
    static let amberDeep = Color(oklch: 0.700, 0.135, 70)
    static let gold      = Color(oklch: 0.840, 0.120, 92)
    static let terra     = Color(oklch: 0.660, 0.140, 46)
    static let warning   = Color(oklch: 0.720, 0.160, 70)
    static let alert     = Color(oklch: 0.640, 0.165, 32)
    static let lineSoft  = Color(lightOKLCH: (0.928, 0.012, 72), darkOKLCH: (0.25, 0.02, 260))
    static let tintGold  = Color(lightOKLCH: (0.945, 0.050, 92), darkOKLCH: (0.30, 0.06, 90))
}

// MARK: - Polices custom (mêmes que l'app : Archivo / Hanken Grotesk)
enum WFont {
    private static let registered: Bool = {
        for name in ["Archivo", "HankenGrotesk", "JetBrainsMono"] {
            let url = Bundle.main.url(forResource: name, withExtension: "ttf")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
            if let url { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
        }
        return true
    }()
    static func display(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        _ = registered
        if !UIFont.fontNames(forFamilyName: "Archivo").isEmpty {
            return .custom("Archivo", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        _ = registered
        if !UIFont.fontNames(forFamilyName: "Hanken Grotesk").isEmpty {
            return .custom("Hanken Grotesk", size: size).weight(weight)
        }
        return .system(size: size, weight: weight)
    }
}

// SF Symbol pour la météo (l'app écrit "sun" / "cloudSun").
private func sfIcon(_ name: String) -> String {
    switch name {
    case "cloudSun", "cloud.sun": return "cloud.sun.fill"
    case "cloud": return "cloud.fill"
    default: return "sun.max.fill"
    }
}

// MARK: - Données partagées (copie autonome — doit matcher l'app)
struct SharedUVDay: Codable, Equatable {
    let dayLabel: String; let weatherIcon: String; let levelLabel: String; let value: Double
}
struct SharedUVData: Codable, Equatable {
    let current: Double; let peak: Double; let levelLabel: String; let city: String
    let idealWindow: String; let forecast: [SharedUVDay]; let updatedAt: Date

    static let sampleDays: [SharedUVDay] = [
        .init(dayLabel: "Dim", weatherIcon: "sun", levelLabel: "Élevé", value: 7),
        .init(dayLabel: "Lun", weatherIcon: "cloudSun", levelLabel: "Modéré", value: 4),
        .init(dayLabel: "Mar", weatherIcon: "sun", levelLabel: "Élevé", value: 7),
        .init(dayLabel: "Mer", weatherIcon: "sun", levelLabel: "Élevé", value: 7)
    ]
    static let placeholder = SharedUVData(
        current: 5, peak: 9, levelLabel: "Modéré", city: "Barcelona",
        idealWindow: "12 h–15 h", forecast: sampleDays, updatedAt: Date())
}
enum SharedStore {
    static let appGroupID = "group.com.meflabs.SOLA"
    private static let key = "sola_shared_uv"
    static func read() -> SharedUVData? {
        guard let d = UserDefaults(suiteName: appGroupID), let raw = d.data(forKey: key),
              let v = try? JSONDecoder().decode(SharedUVData.self, from: raw) else { return nil }
        return v
    }
}

// MARK: - Provider
struct UVEntry: TimelineEntry { let date: Date; let data: SharedUVData }

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UVEntry { UVEntry(date: Date(), data: .placeholder) }
    func getSnapshot(in context: Context, completion: @escaping (UVEntry) -> Void) {
        completion(UVEntry(date: Date(), data: SharedStore.read() ?? .placeholder))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<UVEntry>) -> Void) {
        let data = SharedStore.read() ?? .placeholder
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [UVEntry(date: Date(), data: data)], policy: .after(next)))
    }
}

// MARK: - Barre UV (échelle 0–11, dégradé DA)
private struct UVBar: View {
    let uv: Double
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(WPalette.lineSoft)
                Capsule()
                    .fill(LinearGradient(colors: [WPalette.gold, WPalette.amber, WPalette.terra, WPalette.alert],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, geo.size.width * min(1, uv / 11)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Résumé (réutilisé small + colonne gauche du medium)
private struct UVSummary: View {
    let data: SharedUVData
    var numberSize: CGFloat = 56
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(data.city).font(WFont.body(15, .bold)).foregroundStyle(WPalette.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Image(systemName: "location.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(WPalette.amberDeep)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 2)
            Text("\(Int(data.current.rounded()))")
                .font(WFont.display(numberSize, .heavy))
                .foregroundStyle(WPalette.ink)
                .minimumScaleFactor(0.5).lineLimit(1)
            Spacer(minLength: 2)
            Text(data.levelLabel).font(WFont.body(13, .semibold)).foregroundStyle(WPalette.ink3)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text("Pic : \(String(format: "%.1f", data.peak))")
                .font(WFont.body(12)).foregroundStyle(WPalette.ink3)
            UVBar(uv: data.current).padding(.top, 5)
        }
    }
}

// MARK: - Petit widget
private struct SmallView: View {
    let data: SharedUVData
    var body: some View { UVSummary(data: data) }
}

// MARK: - Widget moyen (résumé + prévision)
private struct MediumView: View {
    let data: SharedUVData
    private var days: [SharedUVDay] {
        data.forecast.isEmpty ? SharedUVData.sampleDays : Array(data.forecast.prefix(4))
    }
    var body: some View {
        HStack(spacing: 14) {
            UVSummary(data: data, numberSize: 46).frame(width: 116)
            Rectangle().fill(WPalette.lineSoft).frame(width: 1)
            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                    HStack(spacing: 8) {
                        Text(d.dayLabel).font(WFont.body(12, .semibold)).foregroundStyle(WPalette.ink3)
                            .frame(width: 30, alignment: .leading)
                        Image(systemName: sfIcon(d.weatherIcon)).font(.system(size: 13))
                            .foregroundStyle(WPalette.amberDeep).frame(width: 18)
                        Text(d.levelLabel).font(WFont.body(11, .medium)).foregroundStyle(WPalette.ink3)
                            .frame(width: 52, alignment: .leading).lineLimit(1).minimumScaleFactor(0.7)
                        UVBar(uv: d.value, height: 5).frame(maxWidth: .infinity)
                        Text("\(Int(d.value.rounded()))").font(WFont.display(13, .bold))
                            .foregroundStyle(WPalette.ink).frame(width: 16, alignment: .trailing)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }
}

// MARK: - Vue d'entrée + configuration
struct SunyWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UVEntry
    var body: some View {
        Group {
            if family == .systemMedium { MediumView(data: entry.data) }
            else { SmallView(data: entry.data) }
        }
        .containerBackground(WPalette.bg, for: .widget)
        .widgetURL(URL(string: "suny://uv"))
    }
}

struct SunyWidget: Widget {
    let kind = "SunyUVWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SunyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("UV Goldn")
        .description("Ton indice UV du jour et la prévision, en un coup d'œil.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct SunyWidgetBundle: WidgetBundle {
    var body: some Widget {
        SunyWidget()
        if #available(iOS 16.1, *) {
            SunSessionLiveActivity()
        }
    }
}
