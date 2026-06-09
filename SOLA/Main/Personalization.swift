import SwiftUI

// MARK: - Personalization Models
struct UserPreferences: Codable {
    var accentColor: AccentColorOption = .gold
    var notificationTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    var targetWeeklyExposure: Int = 300  // minutes
    var enableWeatherAlerts: Bool = true
    var enableSPFReminders: Bool = true
    var enableProgressNotifications: Bool = true
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
        case .gold: return "Or doré"
        case .amber: return "Ambre chaud"
        case .terra: return "Terre brûlée"
        case .bronze: return "Bronze profond"
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

    func updateNotificationTime(_ time: Date) {
        preferences.notificationTime = time
        updatePreferences(preferences)
    }

    func updateTargetExposure(_ minutes: Int) {
        preferences.targetWeeklyExposure = minutes
        updatePreferences(preferences)
    }

    func toggleWeatherAlerts() {
        preferences.enableWeatherAlerts.toggle()
        updatePreferences(preferences)
    }

    func toggleSPFReminders() {
        preferences.enableSPFReminders.toggle()
        updatePreferences(preferences)
    }

    func toggleProgressNotifications() {
        preferences.enableProgressNotifications.toggle()
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
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Palette.surface))
    }
}

// MARK: - Goal Customization
struct GoalCustomization: View {
    @EnvironmentObject var personalization: PersonalizationManager
    @State private var selectedExposure: Int

    init() {
        _selectedExposure = State(initialValue: 300)
    }

    var weeklyHours: Double {
        Double(selectedExposure) / 60.0
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
                        Text("≈ \(String(format: "%.1f", weeklyHours)) h par semaine")
                            .font(SolaFont.body(12))
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer()
                    Icon(name: "sun", size: 40).foregroundStyle(Palette.terra)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Palette.tintTerra))

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
                                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                        .fill(selectedExposure == value ? Palette.terra : Palette.surface)
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
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Palette.surface))
    }
}

// MARK: - Notification Settings
struct NotificationSettings: View {
    @EnvironmentObject var personalization: PersonalizationManager
    @State private var selectedTime: Date

    init() {
        _selectedTime = State(initialValue: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOTIFICATIONS & RAPPELS").font(SolaFont.mono(11)).tracking(0.7).foregroundStyle(Palette.ink3).padding(.bottom, 4)

            VStack(spacing: 12) {
                // Time picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Heure du rappel d'exposition").font(SolaFont.body(12, weight: .semibold)).foregroundStyle(Palette.ink)
                    DatePicker("Heure", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .frame(height: 120)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Palette.tintGold))

                // Toggle switches
                VStack(spacing: 10) {
                    notificationToggle(
                        icon: "bell",
                        title: "Rappels SPF",
                        description: "Réappliquer toutes les 2h",
                        isOn: personalization.preferences.enableSPFReminders,
                        action: { personalization.toggleSPFReminders() }
                    )

                    notificationToggle(
                        icon: "cloud",
                        title: "Alertes météo",
                        description: "UV élevé ou intempéries",
                        isOn: personalization.preferences.enableWeatherAlerts,
                        action: { personalization.toggleWeatherAlerts() }
                    )

                    notificationToggle(
                        icon: "sparkle",
                        title: "Progrès",
                        description: "Nouveaux badges et récompenses",
                        isOn: personalization.preferences.enableProgressNotifications,
                        action: { personalization.toggleProgressNotifications() }
                    )
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Palette.surface))
    }

    private func notificationToggle(icon: String, title: String, description: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Icon(name: icon, size: 20)
                .foregroundStyle(Palette.amberDeep)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Palette.tintAmber))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(description).font(SolaFont.body(11)).foregroundStyle(Palette.ink3)
            }

            Spacer()

            Toggle("", isOn: Binding(get: { isOn }, set: { _ in action() }))
                .tint(Palette.amberDeep)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .fill(Palette.tintAmber.opacity(0.5)))
    }
}

// MARK: - Full Personalization Screen
struct AppPersonalization: View {
    @EnvironmentObject var personalization: PersonalizationManager

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
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
