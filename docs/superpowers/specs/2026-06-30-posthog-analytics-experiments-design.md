# Chantier #1 — PostHog : Analytics + Consentement + Infra A/B

**Date :** 2026-06-30
**Statut :** Design validé, prêt pour plan d'implémentation
**App :** Goldn (cible Xcode `SOLA`, bundle `com.meflabs.SOLA`)

## Objectif

Brancher PostHog (Cloud EU) dans l'app pour :
1. Tracker le funnel acquisition → revenu → rétention.
2. Gérer le consentement RGPD en **opt-in strict**.
3. Poser l'**infra A/B test pilotable depuis PostHog** (feature flags) — changer un test sans repasser par une review App Store.

C'est le **premier** des 4 chantiers de la roadmap (PostHog → Abonnements → Notif relance → Localisation). Il est prérequis des chantiers #2 (A/B paywall) et #3 (event d'abandon d'onboarding).

## Contexte technique (état actuel)

- Aucun SDK analytics présent (ni PostHog, ni autre).
- Managers injectés en `@StateObject` / environnement dans `RootView` (`SOLAApp.swift`) : `AppStore`, `AppFlow`, `PurchaseManager`, `NotificationManager`, `PersonalizationManager`, etc.
- `PurchaseManager` montre le pattern de config SDK (clé en constante statique, `configureIfNeeded()` appelé une fois).
- `AppFlow.stage` = `.onboarding` | `.main` ; `finishOnboarding()` au bout de l'onboarding.
- Pas de cible XCTest (vérification par xcodebuild + dashboard PostHog + provider mock).

## Décisions validées

| Sujet | Décision |
|---|---|
| Hébergement | PostHog **Cloud EU** — host `https://eu.i.posthog.com` |
| Clé API | Project API Key `phc_…` (fournie au moment de coder), rangée en constante de config |
| Consentement | **Opt-in strict** : opt-out par défaut, zéro event tant que non accepté |
| Bannière | Bottom sheet non-dismissible, **affichée après le chargement du 1er écran** (pas au cold launch / splash), ~0,4 s après l'apparition de `RootView` |
| Refus | App fonctionne normalement, aucun event, aucune participation aux A/B tests (variantes = `control`) |
| ATT | Pas de prompt ATT (PostHog n'utilise pas l'IDFA). Si attribution pub un jour → ATT séquencé avant la bannière |
| Architecture | Approche A : wrapper fin + couture protocole pour testabilité |
| A/B tests | Variantes **embarquées dans le build**, sélection/config pilotée à distance par feature flags. Copy/prix/ordre/visibilité = 100 % distant ; nouvelle UI = doit exister dans le build |

## Architecture

Nouveau dossier `SOLA/Services/Analytics/`.

### `ConsentManager.swift`
`ObservableObject` — source de vérité du consentement.

```swift
enum ConsentState: String { case undecided, granted, denied }

@MainActor final class ConsentManager: ObservableObject {
    @Published private(set) var state: ConsentState   // persisté UserDefaults "analytics_consent"
    var shouldPromptConsent: Bool { state == .undecided }
    func grant()  // state=.granted, Analytics.optIn(), capture(.consentGranted)+(.appOpened)
    func deny()   // state=.denied, Analytics.optOut()
}
```

### `Analytics.swift`
Façade statique + couture protocole.

```swift
protocol AnalyticsProvider {
    func optIn(); func optOut()
    func capture(_ event: String, _ properties: [String: Any]?)
    func featureFlag(_ key: String) -> Any?
    func featureFlagPayload(_ key: String) -> Any?
    func reloadFeatureFlags()
}

final class PostHogAnalytics: AnalyticsProvider { /* impl SDK PostHog */ }
final class MockAnalyticsProvider: AnalyticsProvider { /* no-op + capture en mémoire pour debug/preview */ }

enum AppEvent {            // events typés (voir taxonomie)
    case appOpened
    case consentGranted, consentDenied
    case onboardingStarted, onboardingStepViewed(step: Int, name: String), onboardingCompleted
    case paywallViewed(source: String, variant: String)
    case paywallPlanSelected(plan: String)
    case purchaseStarted(plan: String), purchaseCompleted(plan: String, price: String)
    case purchaseFailed(reason: String), purchaseRestored
    case exitOfferShown, exitOfferAccepted
    var name: String { … }
    var properties: [String: Any]? { … }
}

enum Analytics {
    static var provider: AnalyticsProvider = PostHogAnalytics()
    static func capture(_ event: AppEvent)         // no-op si consentement ≠ granted
    static func optIn(); static func optOut()
}
```

Le no-op « tant que non consenti » est garanti à deux niveaux : `Analytics.capture` vérifie le consentement, et PostHog est en `optOut` par défaut côté SDK.

### `Experiments.swift`
Façade au-dessus des feature flags.

```swift
enum Experiment: String {
    case paywallLayout = "paywall_layout"   // utilisé au chantier #2 ; d'autres clés s'ajoutent ici
}

enum Experiments {
    static func variant(_ e: Experiment, default fallback: String = "control") -> String
    static func payload(_ e: Experiment) -> [String: Any]?
    static func isEnabled(_ key: String) -> Bool
    static func reload()
}
```

- Fallback **`control`** systématique si flag non chargé / hors-ligne / consentement refusé.
- L'exposition d'une variante s'accompagne d'un event (ex. `paywall_viewed` avec `variant`) pour que PostHog relie exposition ↔ résultat.

### Intégration
- **Package SPM** `posthog-ios` ajouté au projet (`SOLA.xcodeproj`).
- **Init** dans `SOLAApp.init()` (à côté de `FontLoader.registerAll()`) : `PostHogConfig(apiKey:host:)`, `optOut` par défaut, puis `PostHogSDK.shared.setup(config)`.
- **`RootView`** : `@StateObject private var consent = ConsentManager()`, injecté en environnement. Présentation de la bannière via overlay/`fullScreenCover` gardé par `consent.shouldPromptConsent`, déclenché après apparition + délai.
- Clé API en constante de config (mirroir de `PurchaseManager.revenueCatAPIKey`), avec possibilité d'un projet **DEBUG** distinct plus tard.

## Flux de consentement

1. 1er lancement → `RootView` rend l'onboarding (écran 0).
2. ~0,4 s après apparition → bottom sheet non-dismissible : « Accepter » / « Refuser » + lien politique de confidentialité.
3. `grant()` → `optIn()`, events partent (`consent_granted`, `app_opened`), flags rechargés.
4. `deny()` → reste opt-out, aucun event, variantes = `control`.
5. Décision persistée → la sheet ne réapparaît plus.
6. (Futur) interrupteur dans le profil pour révoquer/redonner le consentement.

## Taxonomie d'events (jeu de départ)

| Event | Propriétés | Déclenchement |
|---|---|---|
| `app_opened` | — | lancement (si consenti) |
| `consent_granted` / `consent_denied` | — | choix bannière |
| `onboarding_started` | — | écran 0 |
| `onboarding_step_viewed` | `step`, `name` | chaque écran d'onboarding |
| `onboarding_completed` | — | fin onboarding |
| `paywall_viewed` | `source`, `variant` | affichage paywall |
| `paywall_plan_selected` | `plan` | tap sur une offre |
| `purchase_started` | `plan` | début achat |
| `purchase_completed` | `plan`, `price` | achat validé |
| `purchase_failed` | `reason` | échec |
| `purchase_restored` | — | restauration |
| `exit_offer_shown` / `exit_offer_accepted` | — | roulette de sortie |

`onboarding_abandoned` se déduit côté PostHog (`started` sans `completed`) — réutilisé par le chantier #3 (notif de relance).

## Confidentialité

- Politique de confidentialité à mettre à jour : mention de **PostHog (analytics, hébergement UE)**, finalité (mesure d'audience / amélioration produit), opt-in. Paragraphe à fournir.
- Aucune PII envoyée ; identité = ID anonyme PostHog (pas d'IDFA, pas d'email).

## Stratégie de vérification

Pas de cible XCTest dans le projet → vérification par :
1. **Compilation** : `xcodebuild` (cible `SOLA`) doit réussir.
2. **`MockAnalyticsProvider`** : permet previews/DEBUG sans réseau ; capture en mémoire pour inspection.
3. **Dashboard PostHog** : vérifier que `app_opened` / `consent_granted` / `onboarding_*` arrivent en live après acceptation, et **rien** après refus.
4. **Feature flag de fumée** : un flag de test renvoie bien sa variante, et `control` en fallback (mode avion / refus).

## Hors périmètre (ce chantier)

- La refonte du paywall et les abonnements weekly/lifetime (**chantier #2**).
  - 🅿️ Rappel #2 : 1er paywall (weekly 4,99 + lifetime 24,99) → roulette → lifetime promo 19,99.
- La notif de relance d'onboarding (**chantier #3**).
- La localisation (**chantier #4**).
- L'interrupteur opt-out dans les réglages (itération ultérieure).
- Le premier vrai A/B test (cible décidée après les premières données).
