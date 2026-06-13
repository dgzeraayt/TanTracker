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
            .background(GlassPanel(radius: Radius.md, tint: Palette.surface, tintOpacity: 0.30))

            // Manual selection (if not using system)
            if !theme.useSystemSettings {
                HStack(spacing: 12) {
                    ForEach([false, true], id: \.self) { isDark in
                        Button(action: { theme.setDarkMode(isDark) }) {
                            VStack(spacing: 8) {
                                Icon(name: isDark ? "moon" : "sun", size: 22)
                                Text(isDark ? "Sombre" : "Clair")
                                    .font(SolaFont.body(13, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .foregroundStyle(theme.isDarkMode == isDark ? .white : Palette.ink)
                            .background(
                                GlassPanel(radius: Radius.md,
                                           tint: theme.isDarkMode == isDark ? Palette.ink : Palette.surface,
                                           tintOpacity: theme.isDarkMode == isDark ? 0.74 : 0.28)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(GlassPanel(radius: 18, tint: Palette.surface, tintOpacity: 0.30))
    }
}

