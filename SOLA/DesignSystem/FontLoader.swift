import SwiftUI
import CoreText

// Enregistre les polices custom (Archivo / Hanken Grotesk / JetBrains Mono)
// embarquées dans le bundle. Appelé au lancement de l'app et du widget — les
// fichiers sont des Google Fonts variables (licence OFL).
enum FontLoader {
    private static var done = false

    static func registerAll() {
        guard !done else { return }
        done = true
        for name in ["Archivo", "HankenGrotesk", "JetBrainsMono"] {
            let url = Bundle.main.url(forResource: name, withExtension: "ttf")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
            if let url {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}
