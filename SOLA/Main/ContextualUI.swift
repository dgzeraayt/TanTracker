import SwiftUI

// MARK: - Time of Day Context
enum TimeOfDayContext {
    case early      // 5-10
    case morning    // 10-13 (best UV)
    case afternoon  // 13-17 (peak UV)
    case evening    // 17-21
    case night      // 21-5

    var icon: String {
        switch self {
        case .early: return "sunrise"
        case .morning: return "sun"
        case .afternoon: return "sunFull"
        case .evening: return "sunset"
        case .night: return "moon"
        }
    }

    var label: String {
        switch self {
        case .early: return "Aube"
        case .morning: return "Matin"
        case .afternoon: return "Après-midi"
        case .evening: return "Soirée"
        case .night: return "Nuit"
        }
    }

    var recommendation: String {
        switch self {
        case .early: return "Parfait pour débuter ta routine matinale"
        case .morning: return "Créneau idéal pour t'exposer au soleil!"
        case .afternoon: return "Pics d'UV - Sois prudent et applique SPF"
        case .evening: return "Temps pour les soins after-sun"
        case .night: return "Repos et récupération"
        }
    }

    var suggestedAction: String {
        switch self {
        case .early: return "Routine matin"
        case .morning: return "Débute l'exposition"
        case .afternoon: return "Réapplique SPF"
        case .evening: return "After-sun + hydratation"
        case .night: return "Dors bien!"
        }
    }

    static func current() -> TimeOfDayContext {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<10: return .early
        case 10..<13: return .morning
        case 13..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
}

// MARK: - Contextual Home Card
struct ContextualHeroCard: View {
    @EnvironmentObject var store: AppStore
    let timeContext: TimeOfDayContext

    private var accentColor: Color {
        switch timeContext {
        case .early: return Color(oklch: 0.72, 0.12, 50)
        case .morning: return Palette.gold
        case .afternoon: return Palette.alert
        case .evening: return Palette.terra
        case .night: return Color(oklch: 0.35, 0.08, 260)
        }
    }

    private var backgroundColor: Color {
        switch timeContext {
        case .early: return Color(oklch: 0.92, 0.04, 50)
        case .morning: return Palette.tintGold
        case .afternoon: return Palette.alert.opacity(0.12)
        case .evening: return Palette.tintTerra
        case .night: return Color(oklch: 0.22, 0.04, 260)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Icon(name: timeContext.icon, size: 24).foregroundStyle(accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeContext.label)
                        .font(SolaFont.mono(11)).tracking(0.7)
                        .foregroundStyle(accentColor)
                    Text(timeContext.recommendation)
                        .font(SolaFont.body(13, weight: .semibold))
                        .foregroundStyle(timeContext == .night ? Color.white : Palette.ink)
                }
                Spacer()
            }

            HStack {
                Icon(name: "arrowR", size: 18).foregroundStyle(accentColor)
                Text(timeContext.suggestedAction)
                    .font(SolaFont.body(14, weight: .semibold))
                    .foregroundStyle(timeContext == .night ? Color.white : Palette.ink)
                Spacer()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(accentColor.opacity(0.2)))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(backgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(accentColor.opacity(0.3), lineWidth: 1.5))
    }
}

// MARK: - Smart Tips Based on Context
struct ContextualTips: View {
    let timeContext: TimeOfDayContext

    private var tips: [String] {
        switch timeContext {
        case .early:
            return [
                "Applique ta crème de jour avec SPF 30",
                "Hydrate-toi bien avant la journée",
                "Prépare ton plan d'exposition"
            ]
        case .morning:
            return [
                "C'est l'heure idéale pour t'exposer!",
                "L'UV est optimal entre 10h-12h",
                "Démarre ton timer d'exposition"
            ]
        case .afternoon:
            return [
                "Les UV sont à leur pic",
                "Réapplique ta crème SPF",
                "Cherche de l'ombre si besoin"
            ]
        case .evening:
            return [
                "Applique ton soin after-sun",
                "Hydrate ta peau généreusement",
                "Prends une photo de suivi (optionnel)"
            ]
        case .night:
            return [
                "Ton corps récupère et se répare",
                "Dors 7-8h pour une belle peau",
                "Demain, même routine!"
            ]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONSEILS DU MOMENT")
                .font(SolaFont.mono(10)).tracking(0.7)
                .foregroundStyle(Palette.ink3)

            VStack(spacing: 8) {
                ForEach(Array(tips.enumerated()), id: \.offset) { i, tip in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Palette.gold)
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                        Text(tip)
                            .font(SolaFont.body(13))
                            .foregroundStyle(Palette.ink2)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .fill(Palette.gold.opacity(0.1)))
    }
}

// MARK: - Smart Notification
struct SmartNotificationBanner: View {
    @EnvironmentObject var store: AppStore
    let timeContext: TimeOfDayContext
    @State private var dismissed = false

    var body: some View {
        if !dismissed && shouldShow {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Icon(name: notificationIcon, size: 20)
                        .foregroundStyle(notificationColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notificationTitle)
                            .font(SolaFont.body(13, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Text(notificationMessage)
                            .font(SolaFont.body(12))
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer()
                    Button(action: { dismissed = true }) {
                        Icon(name: "x", size: 16).foregroundStyle(Palette.ink3)
                    }
                }
                .padding(12)
                .background(notificationBackgroundColor)
            }
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(notificationBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(notificationColor.opacity(0.2), lineWidth: 1))
            .transition(.slideInFromBottom(true))
        }
    }

    private var shouldShow: Bool {
        switch timeContext {
        case .morning:
            return !store.todayHasExposure
        case .afternoon:
            return store.todayHasExposure
        case .evening:
            return store.todayRoutine().completed.count < 5
        default:
            return false
        }
    }

    private var notificationIcon: String {
        switch timeContext {
        case .morning: return "sun"
        case .afternoon: return "shield"
        case .evening: return "leaf"
        default: return "bell"
        }
    }

    private var notificationColor: Color {
        switch timeContext {
        case .morning: return Palette.gold
        case .afternoon: return Palette.alert
        case .evening: return Palette.terra
        default: return Palette.bronze
        }
    }

    private var notificationBackgroundColor: Color {
        switch timeContext {
        case .morning: return Palette.tintGold
        case .afternoon: return Palette.alert.opacity(0.12)
        case .evening: return Palette.tintTerra
        default: return Palette.surface
        }
    }

    private var notificationTitle: String {
        switch timeContext {
        case .morning: return "Créneau idéal !"
        case .afternoon: return "Protège-toi !"
        case .evening: return "Répare ta peau !"
        default: return "Rappel SUNY"
        }
    }

    private var notificationMessage: String {
        switch timeContext {
        case .morning: return "Débute ton exposition maintenant"
        case .afternoon: return "Réapplique ta crème SPF"
        case .evening: return "Applique ton after-sun"
        default: return "À bientôt!"
        }
    }
}

// MARK: - Context-aware Home Enhancement
struct ContextualHomeView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager
    let timeContext: TimeOfDayContext

    private let routine: [(String, String)] = [
        ("Exposé","sun"), ("SPF 30","shield"), ("Hydrater","drop"),
        ("After-sun","leaf"), ("Photo","camera")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Contextual Banner
            SmartNotificationBanner(timeContext: timeContext)
                .padding(.bottom, 14)

            // Contextual Hero
            ContextualHeroCard(timeContext: timeContext)
                .padding(.bottom, 14)

            // Smart Tips
            ContextualTips(timeContext: timeContext)
                .padding(.bottom, 14)

            // Routine (filtered based on context)
            VStack(alignment: .leading, spacing: 12) {
                Text("PROCHAINES ACTIONS")
                    .font(SolaFont.mono(11)).tracking(0.7)
                    .foregroundStyle(Palette.ink3)

                VStack(spacing: 8) {
                    ForEach(contextualRoutineItems, id: \.0) { icon, label in
                        let done = store.isRoutineDone(routineIndex(label))
                        HStack(spacing: 12) {
                            Icon(name: done ? "check" : icon, size: 18)
                                .foregroundStyle(done ? Palette.gold : Palette.bronze)
                                .frame(width: 32, height: 32)
                                .background(GlassPanel(radius: 10,
                                                       tint: done ? Palette.ink : Palette.surface,
                                                       tintOpacity: done ? 0.72 : 0.28))

                            Text(label)
                                .font(SolaFont.body(13, weight: .semibold))
                                .foregroundStyle(done ? Palette.ink3 : Palette.ink)
                            Spacer()
                            if done {
                                Icon(name: "check", size: 14, stroke: 2).foregroundStyle(Palette.gold)
                            }
                        }
                        .padding(10)
                        .background(GlassPanel(radius: Radius.md,
                                               tint: done ? Palette.surface2 : Palette.surface,
                                               tintOpacity: done ? 0.22 : 0.30))
                        .onTapGesture {
                            HapticsManager.shared.tap()
                            store.toggleRoutine(routineIndex(label))
                        }
                    }
                }
            }
            .padding(14)
            .background(GlassPanel(radius: Radius.md, tint: Palette.surface, tintOpacity: 0.30))
        }
    }

    private var contextualRoutineItems: [(String, String)] {
        switch timeContext {
        case .early, .morning:
            return [("shield", "SPF 30"), ("sun", "Exposé")]
        case .afternoon:
            return [("shield", "Réappliquer SPF"), ("drop", "Hydrater")]
        case .evening:
            return [("leaf", "After-sun"), ("drop", "Hydrater"), ("camera", "Photo")]
        case .night:
            return []
        }
    }

    private func routineIndex(_ label: String) -> Int {
        switch label {
        case "Exposé": return 0
        case "SPF 30", "Réappliquer SPF": return 1
        case "Hydrater": return 2
        case "After-sun": return 3
        case "Photo": return 4
        default: return 0
        }
    }
}
