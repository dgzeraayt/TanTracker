import SwiftUI

// Conversion OKLCH -> sRGB pour reproduire fidèlement les couleurs du design
// (le design system SOLA est défini en oklch dans styles.css).
extension Color {
    /// - Parameters:
    ///   - L: lightness 0...1
    ///   - C: chroma (≈ 0...0.4)
    ///   - H: hue en degrés
    init(oklch L: Double, _ C: Double, _ H: Double, opacity: Double = 1) {
        let hr = H * .pi / 180
        let a = C * cos(hr)
        let b = C * sin(hr)

        // OKLab -> LMS'
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        // LMS -> linear sRGB
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

    /// Couleur dynamique clair/sombre définie en OKLCH.
    /// Se résout automatiquement selon l'apparence active (système ou forcée
    /// via `.preferredColorScheme`). Permet au dark mode de s'appliquer à toute
    /// l'app sans toucher chaque écran.
    init(lightOKLCH light: (Double, Double, Double),
         darkOKLCH dark: (Double, Double, Double)) {
        #if canImport(UIKit)
        let l = UIColor(Color(oklch: light.0, light.1, light.2))
        let d = UIColor(Color(oklch: dark.0, dark.1, dark.2))
        self = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? d : l
        })
        #else
        self.init(oklch: light.0, light.1, light.2)
        #endif
    }
}
