import SwiftUI

// MARK: - Palette (mappée 1:1 sur les tokens oklch de styles.css)
// Les surfaces / encres / lignes sont dynamiques : elles basculent
// automatiquement en mode sombre. Les accents de marque (ambre, or,
// terracotta) restent identiques dans les deux apparences.
enum Palette {
    // surfaces
    static let bg        = Color(lightOKLCH: (0.962, 0.018, 72),  darkOKLCH: (0.15, 0.02, 260))
    static let bgWarm    = Color(lightOKLCH: (0.945, 0.026, 66),  darkOKLCH: (0.18, 0.025, 258))
    static let surface   = Color(lightOKLCH: (0.988, 0.010, 82),  darkOKLCH: (0.22, 0.03, 255))
    static let surface2  = Color(lightOKLCH: (0.972, 0.013, 78),  darkOKLCH: (0.26, 0.03, 256))
    static let line      = Color(lightOKLCH: (0.892, 0.016, 70),  darkOKLCH: (0.30, 0.03, 260))
    static let lineSoft  = Color(lightOKLCH: (0.928, 0.012, 72),  darkOKLCH: (0.25, 0.02, 260))

    // ink
    static let ink   = Color(lightOKLCH: (0.205, 0.014, 52), darkOKLCH: (0.95, 0.01, 280))
    static let ink2  = Color(lightOKLCH: (0.420, 0.020, 54), darkOKLCH: (0.80, 0.02, 290))
    // Texte secondaire : assombri par paliers (0.620 -> 0.520 -> 0.455) pour rester
    // lisible en plein soleil, y compris sur les cartes ambre/or claires (tintAmber/tintGold).
    static let ink3  = Color(lightOKLCH: (0.455, 0.026, 58), darkOKLCH: (0.66, 0.02, 280))
    static let inkOn = Color(lightOKLCH: (0.985, 0.010, 82), darkOKLCH: (0.16, 0.02, 260))

    // accents (identiques clair/sombre — couleurs de marque)
    static let amber     = Color(oklch: 0.800, 0.130, 78)
    static let amberDeep = Color(oklch: 0.700, 0.135, 70)
    static let gold      = Color(oklch: 0.840, 0.120, 92)
    static let terra     = Color(oklch: 0.660, 0.140, 46)
    static let bronze    = Color(oklch: 0.530, 0.105, 58)
    static let alert     = Color(oklch: 0.640, 0.165, 32)
    // accent doux (fonds de pastilles, surbrillances légères)
    static let accentSoft = Color(lightOKLCH: (0.930, 0.052, 80), darkOKLCH: (0.30, 0.06, 78))

    // états sémantiques
    static let success = Color(oklch: 0.620, 0.150, 150)
    static let warning = Color(oklch: 0.720, 0.160, 70)

    // échelle UV (vert -> rouge) — partagée par UvScale, badges, jauges de dose
    static let uvLow       = Color(oklch: 0.78, 0.150, 150)
    static let uvModerate  = Color(oklch: 0.82, 0.150, 95)
    static let uvHigh      = Color(oklch: 0.78, 0.160, 60)
    static let uvVeryHigh  = Color(oklch: 0.66, 0.180, 35)
    static let uvExtreme   = Color(oklch: 0.55, 0.190, 18)

    // tints (card fills) — assombris en dark mode
    static let tintAmber  = Color(lightOKLCH: (0.930, 0.052, 80), darkOKLCH: (0.28, 0.05, 70))
    static let tintGold   = Color(lightOKLCH: (0.945, 0.050, 92), darkOKLCH: (0.30, 0.06, 90))
    static let tintTerra  = Color(lightOKLCH: (0.918, 0.046, 48), darkOKLCH: (0.32, 0.07, 40))
    static let tintBronze = Color(lightOKLCH: (0.905, 0.040, 62), darkOKLCH: (0.30, 0.05, 60))

    // texte sur accents chauds (accents fixes => couleur fixe)
    static let onAmber = Color(oklch: 0.28, 0.05, 56) // ≈ #3a2410

    /// Couleur d'un indice UV donné (pour curseurs, badges, libellés).
    static func uvColor(_ uv: Double) -> Color {
        switch uv {
        case ..<3:  return uvLow
        case ..<6:  return uvModerate
        case ..<8:  return uvHigh
        case ..<11: return uvVeryHigh
        default:    return uvExtreme
        }
    }

    /// Variante foncée et saturée de la couleur UV, lisible comme texte sur tint clair.
    static func uvColorInk(_ uv: Double) -> Color {
        switch uv {
        case ..<3:  return Color(oklch: 0.48, 0.150, 150) // vert foncé
        case ..<6:  return Color(oklch: 0.50, 0.130, 88)  // ambre foncé
        case ..<8:  return Color(oklch: 0.50, 0.150, 55)  // orange foncé
        case ..<11: return Color(oklch: 0.50, 0.180, 32)  // rouge-orange
        default:    return Color(oklch: 0.46, 0.190, 18)  // rouge foncé
        }
    }

    // DARK MODE variants
    static func darkBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(oklch: 0.15, 0.02, 260) : bg
    }

    static func darkSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(oklch: 0.22, 0.03, 255) : surface
    }

    static func darkInk(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(oklch: 0.95, 0.01, 280) : ink
    }

    static func darkInk2(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(oklch: 0.78, 0.02, 290) : ink2
    }

    static func darkInk3(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(oklch: 0.60, 0.02, 280) : ink3
    }

    static func darkLine(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(oklch: 0.30, 0.03, 260) : line
    }

    static func darkLineSoft(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(oklch: 0.25, 0.02, 260) : lineSoft
    }

    static func darkTintAmber(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(oklch: 0.28, 0.05, 70) : tintAmber
    }

    static func darkTintGold(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(oklch: 0.30, 0.06, 90) : tintGold
    }

    static func darkTintTerra(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(oklch: 0.32, 0.07, 40) : tintTerra
    }
}

// MARK: - Rayons
// lg = radius standard des cartes. Une seule échelle pour tout l'app.
enum Radius {
    static let sm: CGFloat = 16
    static let md: CGFloat = 22
    static let lg: CGFloat = 30
    static let pill: CGFloat = 999
}

// MARK: - Espacement (échelle 4/8/12/16/24)
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Typographie
// DEUX familles, règle stricte :
//  • Sans-serif (Archivo display / Hanken Grotesk body) = titres, corps, descriptions.
//  • Monospace (JetBrains Mono) = UNIQUEMENT 2 rôles : overlines/labels en capitales
//    (sectionLabel) et données chiffrées/techniques (dataLarge, dataSmall : UV, %, J-0…).
// Tout autre usage de monospace est proscrit.
enum SolaFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        custom("Archivo", size: size, fallback: .system(size: size, weight: weight, design: .default))
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        custom("HankenGrotesk", size: size, fallback: .system(size: size, weight: weight, design: .default))
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        custom("JetBrainsMono", size: size, fallback: .system(size: size, weight: weight, design: .monospaced))
    }

    // MARK: rôles sémantiques (à privilégier sur les tailles brutes)
    /// Titre d'écran — UN seul style partout (sans-serif display).
    static var screenTitle: Font { display(34, weight: .heavy) }
    /// Overline / label de section, capitales (monospace — rôle autorisé).
    static var sectionLabel: Font { mono(11, weight: .medium) }
    /// Titre de carte (sans-serif).
    static var cardTitle: Font { body(17, weight: .bold) }
    static var bodyLarge: Font { body(16, weight: .regular) }
    static var body: Font { body(14, weight: .regular) }
    static var caption: Font { body(12, weight: .regular) }
    /// Donnée chiffrée mise en avant (monospace — rôle autorisé).
    static var dataLarge: Font { mono(20, weight: .semibold) }
    /// Petite donnée chiffrée / compteur (monospace — rôle autorisé).
    static var dataSmall: Font { mono(11, weight: .medium) }

    private static func custom(_ name: String, size: CGFloat, fallback: Font) -> Font {
        #if canImport(UIKit)
        if UIFont(name: name, size: size) != nil { return .custom(name, size: size) }
        #endif
        return fallback
    }
}

// MARK: - Ombres (2 niveaux max : soft et raised)
extension View {
    /// Élévation légère (cartes, pills).
    func shadowSoft() -> some View {
        self.shadow(color: Color(red: 0.31, green: 0.20, blue: 0.08).opacity(0.16),
                    radius: 7, x: 0, y: 4)
    }
    /// Élévation marquée (éléments flottants, CTA).
    func shadowRaised() -> some View {
        self.shadow(color: Color(red: 0.31, green: 0.20, blue: 0.08).opacity(0.18),
                    radius: 15, x: 0, y: 10)
    }
    // Alias rétrocompatibles (anciens noms).
    func solaShadow() -> some View { shadowRaised() }
    func solaShadowSm() -> some View { shadowSoft() }
}

// Dimensions de l'écran de référence (iPhone, 390 x 844)
enum Frame {
    static let width: CGFloat = 390
    static let height: CGFloat = 844
    static let padH: CGFloat = 26
}
