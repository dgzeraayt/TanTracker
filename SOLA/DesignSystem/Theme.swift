import SwiftUI

// MARK: - Palette (mappée 1:1 sur les tokens oklch de styles.css)
enum Palette {
    // surfaces - light mode
    static let bg        = Color(oklch: 0.962, 0.018, 72)
    static let bgWarm    = Color(oklch: 0.945, 0.026, 66)
    static let surface   = Color(oklch: 0.988, 0.010, 82)
    static let surface2  = Color(oklch: 0.972, 0.013, 78)
    static let line      = Color(oklch: 0.892, 0.016, 70)
    static let lineSoft  = Color(oklch: 0.928, 0.012, 72)

    // ink - light mode
    static let ink   = Color(oklch: 0.205, 0.014, 52)
    static let ink2  = Color(oklch: 0.452, 0.020, 54)
    static let ink3  = Color(oklch: 0.620, 0.022, 60)
    static let inkOn = Color(oklch: 0.985, 0.010, 82)

    // accents
    static let amber     = Color(oklch: 0.800, 0.130, 78)
    static let amberDeep = Color(oklch: 0.700, 0.135, 70)
    static let gold      = Color(oklch: 0.840, 0.120, 92)
    static let terra     = Color(oklch: 0.660, 0.140, 46)
    static let bronze    = Color(oklch: 0.530, 0.105, 58)
    static let alert     = Color(oklch: 0.640, 0.165, 32)

    // tints (card fills)
    static let tintAmber  = Color(oklch: 0.930, 0.052, 80)
    static let tintGold   = Color(oklch: 0.945, 0.050, 92)
    static let tintTerra  = Color(oklch: 0.918, 0.046, 48)
    static let tintBronze = Color(oklch: 0.905, 0.040, 62)

    // texte sur accents chauds
    static let onAmber = Color(oklch: 0.28, 0.05, 56) // ≈ #3a2410

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
enum Radius {
    static let lg: CGFloat = 30
    static let md: CGFloat = 22
    static let sm: CGFloat = 16
}

// MARK: - Typographie
// Archivo (display), Hanken Grotesk (body), JetBrains Mono (mono).
// Repli automatique sur le système si les polices ne sont pas présentes.
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

    private static func custom(_ name: String, size: CGFloat, fallback: Font) -> Font {
        #if canImport(UIKit)
        if UIFont(name: name, size: size) != nil { return .custom(name, size: size) }
        #endif
        return fallback
    }
}

// MARK: - Ombres
extension View {
    func solaShadow() -> some View {
        self.shadow(color: Color(red: 0.31, green: 0.20, blue: 0.08).opacity(0.18),
                    radius: 15, x: 0, y: 10)
    }
    func solaShadowSm() -> some View {
        self.shadow(color: Color(red: 0.31, green: 0.20, blue: 0.08).opacity(0.16),
                    radius: 7, x: 0, y: 4)
    }
}

// Dimensions de l'écran de référence (iPhone, 390 x 844)
enum Frame {
    static let width: CGFloat = 390
    static let height: CGFloat = 844
    static let padH: CGFloat = 26
}
