import AppsFlyerLib
import Foundation
import RevenueCat
import UIKit

/// Attribution d'installation AppsFlyer + events in-app.
///
/// Ajouté en 2026-09 pour mesurer les campagnes TikTok Ads (même montage que
/// ControlDopamine). L'attribution atteint AppsFlyer par trois chemins :
///
/// 1. **SKAdNetwork** — le seul signal sur lequel TikTok optimise. Le SDK
///    s'enregistre et fixe les conversion values LUI-MÊME, selon le schéma
///    configuré dans AppsFlyer Conversion Studio. Apple ne retient que le premier
///    appelant : ni l'app ni le SDK TikTok ne doivent appeler
///    `updatePostbackConversionValue` (voir `TikTokBusinessSink`).
/// 2. **RevenueCat → AppsFlyer (serveur à serveur)** — `startSession()` transmet
///    l'ID AppsFlyer à RevenueCat, qui remonte renouvellements, conversions
///    essai→payant, annulations et remboursements. Le client ne peut pas les voir
///    (ils arrivent des jours plus tard, app fermée).
/// 3. **Les events loggés ici** — signal client immédiat pour que TikTok ait de
///    quoi optimiser avant que le revenu serveur n'arrive.
///
/// Contrairement à ControlDopamine (variante Strict, sans IDFA), Goldn affiche
/// déjà le prompt ATT (SDK TikTok) et déclare `NSPrivacyTracking = true` : on
/// utilise donc le SDK standard et on attend la réponse ATT avant `start()`
/// pour que l'IDFA soit inclus quand l'utilisateur consent.
@MainActor
enum AppsFlyerTracker {

    /// Délai max d'attente de la réponse ATT avant d'envoyer l'install (le prompt
    /// est présenté ~0,5 s après l'activation de la scène, voir `RootView`).
    private static let attTimeoutSeconds: TimeInterval = 60

    private(set) static var isConfigured = false

    /// Initialise le SDK et arme le listener session-ready.
    ///
    /// Doit tourner dans `application(_:didFinishLaunchingWithOptions:)`. En v7,
    /// `start()` n'est valide QUE dans le bloc session-ready (déclenché sur le
    /// main thread à chaque passage au premier plan). Ailleurs, l'install postback
    /// est perdu.
    static func configure() {
        #if DEBUG
        // Captures d'écran / smoke : pas d'install ni de session sur le vrai compte.
        if ProcessInfo.processInfo.environment["SOLA_SCREEN"] != nil
            || ProcessInfo.processInfo.environment["SOLA_ANALYTICS_SMOKE"] != nil {
            return
        }
        #endif
        guard AppsFlyerConfig.isConfigured else { return }

        // Garantit que `Purchases.shared` existe quand le bridge tourne (idempotent).
        PurchaseManager.configureIfNeeded()

        let lib = AppsFlyerLib.shared()
        lib.initialize(devKey: AppsFlyerConfig.devKey, appId: AppsFlyerConfig.appleAppID)
        lib.waitForATTUserAuthorization(timeoutInterval: attTimeoutSeconds)
        #if DEBUG
        lib.isDebug = true
        #endif
        isConfigured = true

        // Se redéclenche à chaque premier plan → doit rester idempotent (c'est le cas).
        lib.registerSessionReadyListener {
            MainActor.assumeIsolated {
                Self.startSession()
            }
        }
    }

    /// Event in-app, fire-and-forget : AppsFlyer bufferise et réessaie lui-même.
    static func log(_ event: AppsFlyerEvent) {
        guard isConfigured else { return }
        AppsFlyerLib.shared().logEvent(event.name, withValues: event.payload)
    }

    // MARK: - Session

    private static func startSession() {
        AppsFlyerLib.shared().start()
        bridgeDeviceIDToRevenueCat()
    }

    /// Estampille l'ID AppsFlyer sur l'abonné RevenueCat : sans ça l'intégration
    /// RevenueCat → AppsFlyer tourne mais chaque event tombe sur un utilisateur
    /// inconnu et apparaît en organique.
    private static func bridgeDeviceIDToRevenueCat() {
        guard Purchases.isConfigured else { return }
        Purchases.shared.attribution.setAppsflyerID(AppsFlyerLib.shared().getAppsFlyerUID())
    }
}

/// `UIApplicationDelegate` minimal dont le seul rôle est d'initialiser AppsFlyer
/// au seul moment supporté par le SDK v7 : `didFinishLaunchingWithOptions`.
final class AppsFlyerLifecycleDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MainActor.assumeIsolated {
            AppsFlyerTracker.configure()
        }
        return true
    }
}
