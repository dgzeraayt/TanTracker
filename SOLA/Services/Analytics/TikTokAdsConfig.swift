import Foundation

/// Configuration du TikTok Business SDK (côté client).
/// `iosAppID` (App Store ID) et `tiktokAppID` (ID numérique TikTok Ads Manager)
/// sont des identifiants publics → OK dans le binaire.
/// ⚠️ L'app secret TikTok N'ENTRE PAS ici : c'est un secret serveur (Events API),
/// jamais embarqué dans l'app.
enum TikTokAdsConfig {
    static let iosAppID = "6779321701"
    static let tiktokAppID = "7664919269825691656"

    /// `false` si un ID est vide → le SDK n'est jamais initialisé (l'app marche sans).
    static var isConfigured: Bool { !iosAppID.isEmpty && !tiktokAppID.isEmpty }
}
