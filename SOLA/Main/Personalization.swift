import SwiftUI

// MARK: - Personalization Models
struct UserPreferences: Codable {
    var accentColor: AccentColorOption = .gold
    var targetWeeklyExposure: Int = 300  // minutes
    var preferredLanguage: String = "fr"
}

enum AccentColorOption: String, CaseIterable, Codable {
    case gold = "Gold"
    case amber = "Amber"
    case terra = "Terra"
    case bronze = "Bronze"

    var color: Color {
        switch self {
        case .gold: return Palette.gold
        case .amber: return Palette.amber
        case .terra: return Palette.terra
        case .bronze: return Palette.bronze
        }
    }

    var colorDeep: Color {
        switch self {
        case .gold: return Palette.amberDeep
        case .amber: return Palette.amberDeep
        case .terra: return Palette.terra
        case .bronze: return Palette.bronze
        }
    }

    var label: String {
        switch self {
        case .gold: return String(localized: "Or doré")
        case .amber: return String(localized: "Ambre chaud")
        case .terra: return String(localized: "Terre brûlée")
        case .bronze: return String(localized: "Bronze profond")
        }
    }
}

// MARK: - Personalization Manager
@MainActor
final class PersonalizationManager: ObservableObject {
    @Published var preferences: UserPreferences

    private let userDefaults = UserDefaults.standard
    private let preferencesKey = "sola_user_preferences"

    init() {
        if let data = userDefaults.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = UserPreferences()
        }
    }

    func updatePreferences(_ newPreferences: UserPreferences) {
        preferences = newPreferences
        if let encoded = try? JSONEncoder().encode(newPreferences) {
            userDefaults.set(encoded, forKey: preferencesKey)
        }
    }

    func updateAccentColor(_ color: AccentColorOption) {
        preferences.accentColor = color
        updatePreferences(preferences)
    }

    func updateTargetExposure(_ minutes: Int) {
        preferences.targetWeeklyExposure = minutes
        updatePreferences(preferences)
    }
}

// MARK: - Accent Color Picker
struct AccentColorPicker: View {
    @EnvironmentObject var personalization: PersonalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COULEUR D'ACCENT").font(SolaFont.mono(11)).tracking(0.7).foregroundStyle(Palette.ink3).padding(.bottom, 4)

            VStack(spacing: 10) {
                ForEach(AccentColorOption.allCases, id: \.self) { option in
                    Button(action: { personalization.updateAccentColor(option) }) {
                        HStack(spacing: 12) {
                            Circle().fill(option.color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle().stroke(personalization.preferences.accentColor == option ? Palette.ink : Color.clear, lineWidth: 2.5)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label)
                                    .font(SolaFont.body(14, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                Text("Teinte \(option.rawValue.lowercased())")
                                    .font(SolaFont.body(12))
                                    .foregroundStyle(Palette.ink3)
                            }

                            Spacer()

                            if personalization.preferences.accentColor == option {
                                Icon(name: "check", size: 18, stroke: 2.6)
                                    .foregroundStyle(option.color)
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(option.color.opacity(0.1)))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .stroke(option.color.opacity(0.2), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(GlassPanel(radius: 18, tint: Palette.surface, tintOpacity: 0.30))
    }
}

// MARK: - Goal Customization
struct GoalCustomization: View {
    @EnvironmentObject var personalization: PersonalizationManager
    @EnvironmentObject var store: AppStore
    @State private var selectedExposure: Int = 300

    var weeklyHours: Double {
        Double(selectedExposure) / 60.0
    }

    // Minutes d'exposition réellement cumulées cette semaine (lundi → aujourd'hui).
    private var thisWeekMinutes: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let weekdayIdx = (cal.component(.weekday, from: today) + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -weekdayIdx, to: today) else { return 0 }
        return store.data.sessions
            .filter { $0.date >= monday }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OBJECTIF D'EXPOSITION HEBDOMADAIRE").font(SolaFont.mono(11)).tracking(0.7).foregroundStyle(Palette.ink3).padding(.bottom, 4)

            VStack(spacing: 16) {
                // Current display
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cible hebdomadaire").font(SolaFont.body(12)).foregroundStyle(Palette.ink3)
                        Text("\(selectedExposure) min")
                            .font(SolaFont.display(28, weight: .bold))
                            .foregroundStyle(Palette.terra)
                        Text("Cette semaine : \(thisWeekMinutes) / \(selectedExposure) min")
                            .font(SolaFont.body(12))
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer()
                    Icon(name: "sun", size: 40).foregroundStyle(Palette.terra)
                }
                .padding(12)
                .background(GlassPanel(radius: Radius.md, tint: Palette.tintTerra, tintOpacity: 0.44))

                Track(value: selectedExposure > 0 ? min(1, Double(thisWeekMinutes) / Double(selectedExposure)) : 0,
                      height: 8, fill: Palette.terra)

                // Slider
                VStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { Double(selectedExposure) },
                        set: { selectedExposure = Int($0) }
                    ), in: 60...600, step: 30)
                    .tint(Palette.terra)

                    HStack {
                        Text("60 min").font(SolaFont.mono(10)).foregroundStyle(Palette.ink3)
                        Spacer()
                        Text("600 min").font(SolaFont.mono(10)).foregroundStyle(Palette.ink3)
                    }
                }

                // Presets
                HStack(spacing: 8) {
                    ForEach([60, 180, 300, 450], id: \.self) { value in
                        Button(action: { selectedExposure = value }) {
                            Text("\(value / 60)h")
                                .font(SolaFont.mono(12, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .foregroundStyle(selectedExposure == value ? .white : Palette.ink)
                                .background(
                                    GlassPanel(radius: Radius.md,
                                               tint: selectedExposure == value ? Palette.terra : Palette.surface,
                                               tintOpacity: selectedExposure == value ? 0.66 : 0.26)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                SolaButton(title: "Confirmer l'objectif", kind: .amber) {
                    personalization.updateTargetExposure(selectedExposure)
                    HapticsManager.shared.success()
                }
            }
        }
        .padding(16)
        .background(GlassPanel(radius: 18, tint: Palette.surface, tintOpacity: 0.30))
        .onAppear { selectedExposure = personalization.preferences.targetWeeklyExposure }
    }
}

// MARK: - Notification Settings
// Pilote les VRAIES préférences de notification (store.data.notifPrefs), celles
// que la planification utilise réellement — plus de système parallèle fantôme.
struct NotificationSettings: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOTIFICATIONS & RAPPELS").font(SolaFont.mono(11)).tracking(0.7).foregroundStyle(Palette.ink3).padding(.bottom, 4)

            VStack(spacing: 12) {
                if !notifications.authorized {
                    Button {
                        Task { _ = await notifications.requestAuthorization() }
                    } label: {
                        HStack(spacing: 10) {
                            Icon(name: "bell", size: 18).foregroundStyle(Palette.onAmber)
                            Text("Autoriser les notifications")
                                .font(SolaFont.body(14, weight: .bold)).foregroundStyle(Palette.onAmber)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14).frame(height: 48)
                        .background(Capsule().fill(Palette.amber))
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 10) {
                    notificationToggle(
                        icon: "bell",
                        title: "Rappels SPF",
                        description: "Réappliquer la protection",
                        isOn: Binding(get: { store.data.notifPrefs.spfReminders },
                                      set: { store.data.notifPrefs.spfReminders = $0 })
                    )

                    notificationToggle(
                        icon: "sun",
                        title: "Fenêtre UV idéale",
                        description: "Au meilleur créneau d'exposition",
                        isOn: Binding(get: { store.data.notifPrefs.uvWindow },
                                      set: { store.data.notifPrefs.uvWindow = $0 })
                    )

                    notificationToggle(
                        icon: "flame",
                        title: "Alertes de brûlure",
                        description: "Quand tu approches ton seuil",
                        isOn: Binding(get: { store.data.notifPrefs.burnAlerts },
                                      set: { store.data.notifPrefs.burnAlerts = $0 })
                    )
                }
            }
        }
        .padding(16)
        .background(GlassPanel(radius: 18, tint: Palette.surface, tintOpacity: 0.30))
    }

    private func notificationToggle(icon: String, title: LocalizedStringKey, description: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Icon(name: icon, size: 20)
                .foregroundStyle(Palette.amberDeep)
                .frame(width: 36, height: 36)
                .background(GlassCircle(tint: Palette.tintAmber, tintOpacity: 0.48))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(description).font(SolaFont.body(11)).foregroundStyle(Palette.ink3)
            }

            Spacer()

            Toggle("", isOn: isOn).labelsHidden().tint(Palette.amberDeep)
        }
        .padding(10)
        .background(GlassPanel(radius: Radius.md, tint: Palette.tintAmber, tintOpacity: 0.36))
    }
}

// MARK: - Full Personalization Screen
struct AppPersonalization: View {
    @EnvironmentObject var personalization: PersonalizationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        IconButton(icon: "chevL", iconSize: 20) { dismiss() }
                        ScreenTitle(text: "Personnalisation")
                        Spacer()
                    }
                    .padding(.top, 4)

                    AccentColorPicker()
                        .padding(.top, 20)

                    GoalCustomization()
                        .padding(.top, 14)

                    NotificationSettings()
                        .padding(.top, 14)

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, Frame.padH)
            }
        }
    }
}
