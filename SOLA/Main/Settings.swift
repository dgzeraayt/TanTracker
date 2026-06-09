import SwiftUI

// MARK: - Theme Manager
@MainActor
final class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool = false
    @Published var useSystemSettings: Bool = true

    private let userDefaults = UserDefaults.standard
    private let darkModeKey = "sola_dark_mode"
    private let useSystemKey = "sola_use_system"

    init() {
        useSystemSettings = userDefaults.bool(forKey: useSystemKey)
        isDarkMode = userDefaults.bool(forKey: darkModeKey)
    }

    func setDarkMode(_ isDark: Bool) {
        isDarkMode = isDark
        userDefaults.set(isDark, forKey: darkModeKey)
    }

    func setUseSystemSettings(_ use: Bool) {
        useSystemSettings = use
        userDefaults.set(use, forKey: useSystemKey)
    }

    func getColorScheme() -> ColorScheme? {
        if useSystemSettings { return nil }
        return isDarkMode ? .dark : .light
    }
}

// MARK: - Dark Mode Toggle
struct DarkModeToggle: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.colorScheme) var systemColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apparence").font(SolaFont.display(18, weight: .bold)).tracking(-0.3)

            // System / Manual toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Utiliser les paramètres système")
                        .font(SolaFont.body(14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text("S'ajuste automatiquement")
                        .font(SolaFont.body(12))
                        .foregroundStyle(Palette.ink3)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { theme.useSystemSettings },
                    set: { theme.setUseSystemSettings($0) }
                ))
                .tint(Palette.amberDeep)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Palette.surface))

            // Manual selection (if not using system)
            if !theme.useSystemSettings {
                HStack(spacing: 12) {
                    ForEach([false, true], id: \.self) { isDark in
                        Button(action: { theme.setDarkMode(isDark) }) {
                            VStack(spacing: 8) {
                                Image(systemName: isDark ? "moon.fill" : "sun.max.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                Text(isDark ? "Sombre" : "Clair")
                                    .font(SolaFont.body(13, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .foregroundStyle(theme.isDarkMode == isDark ? .white : Palette.ink)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .fill(theme.isDarkMode == isDark ? Palette.ink : Palette.surface)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Palette.surface))
    }
}

// MARK: - Settings Screen
struct AppSettings: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeManager
    @State private var showResetConfirm = false

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        DisplayText(text: "Paramètres", size: 38)
                        Spacer()
                    }
                    .padding(.top, 4)

                    // Profile Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PROFIL").font(SolaFont.mono(11)).tracking(0.7).foregroundStyle(Palette.ink3).padding(.bottom, 4)

                        HStack(spacing: 14) {
                            AvatarView(size: 60)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(store.profile.name)
                                    .font(SolaFont.body(16, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                Text("Phototype: \(store.profile.phototype.title)")
                                    .font(SolaFont.body(12))
                                    .foregroundStyle(Palette.ink3)
                                Text("Inscrit depuis \(store.profile.planStartDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(SolaFont.body(12))
                                    .foregroundStyle(Palette.ink3)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(Palette.surface))
                    }
                    .padding(.top, 20)

                    // Theme Section
                    DarkModeToggle()
                        .padding(.top, 20)

                    // Notifications
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NOTIFICATIONS").font(SolaFont.mono(11)).tracking(0.7).foregroundStyle(Palette.ink3).padding(.bottom, 4)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Alertes SPF")
                                    .font(SolaFont.body(14, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                Text("Rappel toutes les 2 heures")
                                    .font(SolaFont.body(12))
                                    .foregroundStyle(Palette.ink3)
                            }
                            Spacer()
                            Toggle("", isOn: .constant(true))
                                .tint(Palette.amberDeep)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(Palette.surface))

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rappels d'exposition")
                                    .font(SolaFont.body(14, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                Text("Au meilleur créneau d'exposition")
                                    .font(SolaFont.body(12))
                                    .foregroundStyle(Palette.ink3)
                            }
                            Spacer()
                            Toggle("", isOn: .constant(true))
                                .tint(Palette.amberDeep)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(Palette.surface))
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.surface))
                    .padding(.top, 20)

                    // About
                    VStack(alignment: .leading, spacing: 12) {
                        Text("À PROPOS").font(SolaFont.mono(11)).tracking(0.7).foregroundStyle(Palette.ink3).padding(.bottom, 4)

                        HStack {
                            Text("Version").font(SolaFont.body(14, weight: .semibold)).foregroundStyle(Palette.ink)
                            Spacer()
                            Text("1.0.0").font(SolaFont.body(14)).foregroundStyle(Palette.ink3)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(Palette.surface))

                        HStack {
                            Text("Conditions d'utilisation").font(SolaFont.body(14, weight: .semibold)).foregroundStyle(Palette.ink)
                            Spacer()
                            Icon(name: "arrowR", size: 16).foregroundStyle(Palette.ink3)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(Palette.surface))

                        HStack {
                            Text("Politique de confidentialité").font(SolaFont.body(14, weight: .semibold)).foregroundStyle(Palette.ink)
                            Spacer()
                            Icon(name: "arrowR", size: 16).foregroundStyle(Palette.ink3)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(Palette.surface))
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.surface))
                    .padding(.top, 20)

                    // Danger Zone
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ZONE DE DANGER").font(SolaFont.mono(11)).tracking(0.7).foregroundStyle(Palette.alert).padding(.bottom, 4)

                        Button(action: { showResetConfirm = true }) {
                            HStack {
                                Icon(name: "trash", size: 18).foregroundStyle(Palette.alert)
                                Text("Réinitialiser tous les paramètres")
                                    .font(SolaFont.body(14, weight: .semibold))
                                    .foregroundStyle(Palette.alert)
                                Spacer()
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(Palette.alert.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.alert.opacity(0.08)))
                    .padding(.top, 20)

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, Frame.padH)
            }
        }
        .alert("Réinitialiser ?", isPresented: $showResetConfirm) {
            Button("Annuler", role: .cancel) { }
            Button("Réinitialiser", role: .destructive) {
                store.resetAll()
                HapticsManager.shared.success()
            }
        } message: {
            Text("Cela supprimera tous vos paramètres, sessions et photos. Cette action ne peut pas être annulée.")
        }
    }
}
