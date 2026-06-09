import SwiftUI

// MARK: - Tokens design du widget
// Le widget tourne dans un process séparé et NE partage PAS le code de l'app.
// On recrée donc ici les couleurs strictement nécessaires, identiques à l'app
// (mêmes valeurs OKLCH que SOLA/DesignSystem/Theme.swift + Color+OKLCH.swift),
// pour une cohérence de marque jusque dans l'extension native.

extension Color {
    /// Conversion OKLCH → sRGB (copie fidèle de l'init de l'app).
    init(oklch L: Double, _ C: Double, _ H: Double, opacity: Double = 1) {
        let hr = H * .pi / 180
        let a = C * cos(hr)
        let b = C * sin(hr)

        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

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
}

/// Palette du widget — sous-ensemble strict des tokens de l'app.
enum WidgetPalette {
    // surfaces / crème
    static let bg       = Color(oklch: 0.962, 0.018, 72)
    static let surface  = Color(oklch: 0.988, 0.010, 82)
    static let cream    = Color(oklch: 0.945, 0.050, 92)

    // encre
    static let ink   = Color(oklch: 0.205, 0.014, 52)
    static let ink2  = Color(oklch: 0.452, 0.020, 54)
    static let ink3  = Color(oklch: 0.520, 0.024, 58)

    // ambre (marque)
    static let amber     = Color(oklch: 0.800, 0.130, 78)
    static let amberDeep = Color(oklch: 0.700, 0.135, 70)
    static let onAmber   = Color(oklch: 0.28, 0.05, 56)

    // échelle UV (identique à l'app)
    static let uvLow      = Color(oklch: 0.78, 0.150, 150)
    static let uvModerate = Color(oklch: 0.82, 0.150, 95)
    static let uvHigh     = Color(oklch: 0.78, 0.160, 60)
    static let uvVeryHigh = Color(oklch: 0.66, 0.180, 35)
    static let uvExtreme  = Color(oklch: 0.55, 0.190, 18)

    /// Couleur d'un indice UV donné.
    static func uvColor(_ uv: Double) -> Color {
        switch uv {
        case ..<3:  return uvLow
        case ..<6:  return uvModerate
        case ..<8:  return uvHigh
        case ..<11: return uvVeryHigh
        default:    return uvExtreme
        }
    }

    /// Dégradé complet de l'échelle UV (mini-barre).
    static var uvGradient: LinearGradient {
        LinearGradient(colors: [uvLow, uvModerate, uvHigh, uvVeryHigh, uvExtreme],
                       startPoint: .leading, endPoint: .trailing)
    }
}
