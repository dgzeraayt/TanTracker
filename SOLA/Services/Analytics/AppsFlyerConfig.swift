import Foundation

/// Configuration du SDK AppsFlyer (attribution + SKAdNetwork pour TikTok Ads).
/// Le dev key est une clé cliente publique (comme celle de RevenueCat ou PostHog)
/// → OK dans le binaire. Il s'agit de la clé du compte AppsFlyer de l'acheteur,
/// relue dans App Settings le 2026-09-08.
enum AppsFlyerConfig {
    static let devKey = "fDFVLwWGpwQqKnYoNP2Czi"
    static let appleAppID = "6779321701"

    /// `false` si un identifiant est vide → le SDK n'est jamais initialisé (l'app marche sans).
    static var isConfigured: Bool { !devKey.isEmpty && !appleAppID.isEmpty }
}
