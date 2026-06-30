import Foundation

/// Configuration PostHog (Cloud EU). La clé est une *Project API Key* publique
/// (préfixe phc_) — pas un secret serveur, elle peut vivre dans le binaire.
enum AnalyticsConfig {
    static let postHogAPIKey = "phc_mbKYgHXaLeeE5WtG7aPpBoSPitdQcNZZmZnfpc9VQRZx"
    static let postHogHost = "https://eu.i.posthog.com"

    /// URL de la politique de confidentialité (affichée dans la bannière de consentement).
    static let privacyPolicyURL = "https://goldnapp.com/privacy"

    /// `true` tant que la vraie clé n'est pas renseignée → l'init PostHog est sautée
    /// proprement (l'app marche sans analytics).
    static var isConfigured: Bool { postHogAPIKey.hasPrefix("phc_") && postHogAPIKey != "phc_REPLACE_ME" }
}
