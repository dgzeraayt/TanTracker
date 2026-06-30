// MARK: - WMO Weather Code → Condition (Open-Meteo)

enum WeatherCondition: String {
    case clear, partlyCloudy, cloudy, fog, rain, showers, thunderstorm, snow

    init(weatherCode code: Int) {
        switch code {
        case 0:                          self = .clear
        case 1, 2:                       self = .partlyCloudy
        case 3:                          self = .cloudy
        case 45, 48:                     self = .fog
        case 51...57, 61...67:           self = .rain
        case 80...82:                    self = .showers
        case 71...77, 85, 86:            self = .snow
        case 95, 96, 99:                 self = .thunderstorm
        default:                         self = .partlyCloudy
        }
    }

    var label: String {
        switch self {
        case .clear:        return String(localized: "Ensoleillé")
        case .partlyCloudy: return String(localized: "Partiellement nuageux")
        case .cloudy:       return String(localized: "Nuageux")
        case .fog:          return String(localized: "Brouillard")
        case .rain:         return String(localized: "Pluie")
        case .showers:      return String(localized: "Averses")
        case .thunderstorm: return String(localized: "Orage")
        case .snow:         return String(localized: "Neige")
        }
    }

    /// True quand l'ensoleillement permet un vrai bronzage (pas couvert/pluie).
    var isSunny: Bool { self == .clear || self == .partlyCloudy }
}

// MARK: - SF Symbols

extension WeatherCondition {
    /// SF Symbol (remplissage) représentant la condition.
    var sfSymbol: String {
        switch self {
        case .clear:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy:       return "cloud.fill"
        case .fog:          return "cloud.fog.fill"
        case .rain:         return "cloud.rain.fill"
        case .showers:      return "cloud.heavyrain.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .snow:         return "snowflake"
        }
    }
}
