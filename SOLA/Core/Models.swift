import Foundation
import SwiftUI

// Libellé de teinte — source unique de vérité (partagé entre l'analyse et l'accueil).
func solaHueLabel(_ tan: Int, newline: Bool = false) -> String {
    let sep = newline ? "\n" : " "
    switch tan {
    case ..<35: return "Clair\(sep)& naturel"
    case ..<55: return "Doré\(sep)léger"
    case ..<72: return "Doré\(sep)& lumineux"
    case ..<88: return "Caramel"
    default:    return "Caramel\(sep)intense"
    }
}

// MARK: - Phototype Fitzpatrick
enum Fitzpatrick: Int, Codable, CaseIterable, Identifiable {
    case I = 1, II, III, IV, V, VI
    var id: Int { rawValue }

    var roman: String { ["", "I", "II", "III", "IV", "V", "VI"][rawValue] }
    var title: String {
        switch self {
        case .I:   return "Type I · Très claire"
        case .II:  return "Type II · Claire"
        case .III: return "Type III · Intermédiaire"
        case .IV:  return "Type IV · Mate"
        case .V:   return "Type V · Foncée"
        case .VI:  return "Type VI · Très foncée"
        }
    }
    var summary: String {
        switch self {
        case .I:   return "Tu brûles systématiquement et ne bronzes presque jamais. La prudence est essentielle."
        case .II:  return "Tu brûles facilement et bronzes légèrement. Une exposition progressive te protège."
        case .III: return "Tu brûles légèrement puis bronzes joliment. Ton bronzage doré est très accessible — avec la bonne dose d'UV."
        case .IV:  return "Tu brûles rarement et bronzes facilement vers une teinte caramel."
        case .V:   return "Tu brûles très rarement et bronzes intensément."
        case .VI:  return "Ta peau est richement pigmentée et brûle exceptionnellement."
        }
    }
    /// Minutes avant rougeur à un UV de référence (UV 8).
    var safeMinutesAtUV8: Int {
        switch self {
        case .I: return 10; case .II: return 15; case .III: return 20
        case .IV: return 30; case .V: return 45; case .VI: return 60
        }
    }
    var recommendedSPF: Int {
        switch self {
        case .I, .II: return 50
        case .III, .IV: return 30
        case .V, .VI: return 20
        }
    }
    /// Couleur d'illustration de la pastille phototype.
    var swatch: Color {
        switch self {
        case .I:   return Color(oklch: 0.90, 0.04, 70)
        case .II:  return Color(oklch: 0.84, 0.06, 66)
        case .III: return Color(oklch: 0.76, 0.08, 62)
        case .IV:  return Color(oklch: 0.64, 0.09, 58)
        case .V:   return Color(oklch: 0.50, 0.08, 54)
        case .VI:  return Color(oklch: 0.36, 0.05, 50)
        }
    }
}

// MARK: - Objectif de bronzage
enum TanGoal: String, Codable, CaseIterable {
    case subtleGlow, deepTan, maintain, safe

    var title: String {
        switch self {
        case .subtleGlow: return "Glow doré subtil"
        case .deepTan: return "Bronzage profond"
        case .maintain: return "Maintenir ma teinte"
        case .safe: return "Bronzer en sécurité"
        }
    }
    var subtitle: String {
        switch self {
        case .subtleGlow: return "Bonne mine naturelle, lumineuse"
        case .deepTan: return "Teinte caramel, intense"
        case .maintain: return "Garder ma couleur actuelle"
        case .safe: return "Zéro risque, au minimum d'UV"
        }
    }
    var icon: String {
        switch self {
        case .subtleGlow: return "sun"
        case .deepTan: return "flame"
        case .maintain: return "refresh"
        case .safe: return "shield"
        }
    }
    /// Indice de bronzage visé (0–100).
    var targetIndex: Int {
        switch self {
        case .subtleGlow: return 75
        case .deepTan: return 92
        case .maintain: return 60
        case .safe: return 55
        }
    }
}

// MARK: - Réglages de notifications
struct NotificationPrefs: Codable, Equatable {
    var spfReminders = true
    var uvWindow = true
    var burnAlerts = true
    var authorized = false
}

// MARK: - Profil utilisateur
struct UserProfile: Codable, Equatable {
    var name: String = ""
    var gender: String = "Femme"
    var age: Int = 24
    var referral: String = ""

    // réponses brutes du quiz Fitzpatrick (index sélectionné)
    var eyeColor: Int = 0
    var hairColor: Int = 0
    var skinTone: Int = 0
    var sunReaction: Int = 0   // 0 = brûle toujours … 4 = ne brûle jamais
    var freckles: Int = 0      // 0 = beaucoup … 3 = aucune
    var phototypeRaw: Int = Fitzpatrick.III.rawValue

    var goalRaw: String = TanGoal.subtleGlow.rawValue
    var startTanLevel: Int = 1     // 0…4
    var places: Set<Int> = [0, 2]
    var frequency: Int = 1
    var concerns: Set<Int> = [0, 1, 3]
    var spfHabit: Int = 1

    var city: String = "Nice, France"
    var latitude: Double = 43.7102
    var longitude: Double = 7.2620

    var planStartDate: Date = .now
    var targetWeeks: Int = 12
    var baselineIndex: Int = 0     // indice de départ réel (0 tant qu'aucun scan ; sinon teinte mesurée)

    var phototype: Fitzpatrick {
        get { Fitzpatrick(rawValue: phototypeRaw) ?? .III }
        set { phototypeRaw = newValue.rawValue }
    }
    var goal: TanGoal {
        get { TanGoal(rawValue: goalRaw) ?? .subtleGlow }
        set { goalRaw = newValue.rawValue }
    }
    var firstName: String {
        let f = name.split(separator: " ").first.map(String.init) ?? name
        return f.isEmpty ? "toi" : f
    }
}

// MARK: - Session d'exposition
struct TanSession: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date = .now
    var durationMinutes: Int
    var usedSPF: Bool
    var uvIndex: Double
    var note: String = ""
    var photoFilename: String? = nil
    var metrics: SkinMetrics? = nil
}

// MARK: - Routine quotidienne (étapes cochées)
struct RoutineDay: Codable, Equatable {
    var dayKey: String              // "yyyy-MM-dd"
    var completed: Set<Int> = []
}

// MARK: - Conteneur persistant
struct AppData: Codable {
    var profile = UserProfile()
    var sessions: [TanSession] = []
    var routineDays: [RoutineDay] = []
    var notifPrefs = NotificationPrefs()
    var onboardingComplete = false
    var achievements: [Achievement] = Achievement.allAchievements
    /// Stocké en optionnel : les anciennes sauvegardes (sans la clé) restent décodables
    /// (un Bool non optionnel ferait échouer le décodage → réinitialisation/perte de données).
    private var programStartedFlag: Bool?
    /// L'utilisateur a explicitement démarré son programme (révèle la routine du jour).
    var programStarted: Bool {
        get { programStartedFlag ?? false }
        set { programStartedFlag = newValue }
    }
}
