# TikTok Business SDK — intégration & événements

**Date :** 2026-07-21
**App :** Goldn (target interne SOLA)
**Objectif :** renvoyer les conversions de l'app vers TikTok (TikTok Business SDK for iOS) pour optimiser les campagnes TikTok Ads et mesurer le ROAS.

## Décisions cadrées

- **ATT :** on ajoute le prompt App Tracking Transparency (via la méthode fournie par le SDK). IDFA si accepté, fallback SKAdNetwork sinon.
- **Consentement :** TikTok est gaté par le **même** opt-in que PostHog (`Analytics.isOptedIn`). Rien n'est envoyé tant que la bannière de consentement n'est pas acceptée.
- **Credentials :** pas encore disponibles → placeholders + `TikTokAdsConfig.isConfigured`, comme `AnalyticsConfig` pour PostHog. L'app fonctionne sans (SDK non initialisé si non configuré).

## Architecture

TikTok se branche **sans modifier aucun call-site existant**. Aujourd'hui la façade `Analytics` détient un seul `provider` (PostHog). On introduit un `CompositeAnalyticsProvider` qui diffuse chaque appel vers `[PostHogAnalytics, TikTokAnalytics]`.

```
Analytics.capture(.purchaseCompleted(...))
        │
        ▼
CompositeAnalyticsProvider  (implémente AnalyticsProvider)
    ├──► PostHogAnalytics   (inchangé)
    └──► TikTokAnalytics    (nouveau)
```

- `setup()` / `optIn()` / `optOut()` / `capture()` → fan-out vers les deux providers.
- `featureFlag()` / `featureFlagPayload()` / `reloadFeatureFlags()` → délégués **à PostHog seul** (TikTok ne gère pas de flags). Le composite délègue au premier provider qui les supporte.
- `Analytics.capture(...)` reste gaté par `isOptedIn` (inchangé) → TikTok hérite du même gating.

**Fichiers :**
- `SOLA/Services/Analytics/TikTokAdsConfig.swift` — config + `isConfigured`.
- `SOLA/Services/Analytics/TikTokAnalytics.swift` — provider TikTok (mapping des events).
- `SOLA/Services/Analytics/CompositeAnalyticsProvider.swift` — fan-out.
- `SOLA/Services/Analytics/Analytics.swift` — `provider` par défaut passe de `PostHogAnalytics()` à `CompositeAnalyticsProvider([...])`. Enum `AppEvent` : enrichir le case `purchaseCompleted`.

**Dépendance SPM :** `https://github.com/tiktok/tiktok-business-ios-sdk`, produit `TikTokBusinessSDK`. Ajoutée au `.xcodeproj` comme RevenueCat / PostHog.

## Config d'init du SDK

API réelle (Objective-C, appelable depuis Swift) :

```swift
let config = TikTokConfig(accessToken: nil,
                          appId: TikTokAdsConfig.iosAppID,       // App Store ID iOS
                          tiktokAppId: TikTokAdsConfig.tiktokAppID) // ID numérique TikTok
config?.disablePaymentTracking()   // on émet nos propres CompletePayment/StartTrial (RevenueCat) → évite le double comptage
#if DEBUG
config?.enableDebugMode()          // Test Events dans TikTok Events Manager
#endif
TikTokBusiness.initializeSdk(config)
```

- On **garde** l'auto-tracking install/launch → `LaunchAPP` gratuit.
- On **désactive** le payment tracking auto (StoreKit observer du SDK) car nos events revenu sont émis manuellement avec la vraie valeur/devise + logique d'essai.

## Consentement + ATT

Séquence, déclenchée quand l'utilisateur accepte la bannière (`ConsentManager.grant()` → `Analytics.optIn()`) :

1. `Analytics.optIn()` → `TikTokAnalytics.optIn()` : le SDK est autorisé à envoyer (init si `isConfigured` et pas déjà fait).
2. Juste après, au premier plan, on demande l'ATT via le SDK :
   ```swift
   TikTokBusiness.requestTrackingAuthorization { _ in }
   ```
   Le SDK récupère l'IDFA si l'utilisateur autorise ; sinon SKAdNetwork.
3. Au démarrage, `ConsentManager.init()` réapplique l'état (`state == .granted → Analytics.optIn()`), donc TikTok reprend sans re-prompt.

**Info.plist / projet :**
- `NSUserTrackingUsageDescription` (localisé FR/EN/ES/IT/PT-PT/PT-BR — cohérent avec la localisation existante).
- Identifiants **SKAdNetwork** de TikTok (`SKAdNetworkItems`).
- Mise à jour du **privacy manifest** `PrivacyInfo.xcprivacy` : IDFA + domaines de tracking TikTok + types de données collectées.

## ⭐ Mapping des événements

Chaque `AppEvent` interne → event standard TikTok. `TikTokAnalytics.capture(name, properties)` fait la traduction via une table `name → (tiktokEvent, param builder)`. Les events non listés sont **ignorés** (pas de bruit pour l'algo).

| `AppEvent` interne (name) | Event TikTok | Paramètres |
|---|---|---|
| *(auto SDK)* | `LaunchAPP` | auto (install/launch tracking) |
| `onboarding_completed` | `CompleteTutorial` | — |
| `paywall_viewed` | `ViewContent` | `content_type="paywall"`, `content_id=variant` |
| `paywall_plan_selected` | `AddToCart` | `content_id=plan` |
| `purchase_started` | `InitiateCheckout` | `content_id=plan` |
| `purchase_completed` **avec essai gratuit** | `StartTrial` | `value`, `currency`, `content_id=plan` |
| `purchase_completed` **sans essai** | `CompletePayment` | `value`, `currency`, `content_id=plan` |
| `consent_*`, `onboarding_started`, `onboarding_step_viewed`, `purchase_failed`, `purchase_restored`, `exit_offer_*` | *ignorés* | — |

**Émission via l'API typée :**
```swift
let e = TikTokBaseEvent(eventName: "CompletePayment")
e.addProperty(withKey: "value", value: 4.99)      // Double, valeur numérique
e.addProperty(withKey: "currency", value: "EUR")  // code ISO 4217
e.addProperty(withKey: "content_id", value: planID)
TikTokBusiness.trackTTEvent(e)
```

### Valeur + devise (le point critique ROAS)

Aujourd'hui `purchase_completed` ne porte que le prix **localisé** (`"4,99 €"`), inexploitable. On enrichit :

```swift
// Analytics.swift — enum AppEvent
case purchaseCompleted(plan: String, price: String, value: Double, currency: String, hasFreeTrial: Bool)
```
`properties` expose `value`, `currency`, `has_free_trial` (en plus de `plan`/`price` pour PostHog).

Call-site `PurchaseManager.purchase(_:)` (≈ ligne 200) :
```swift
let sp = package.storeProduct
let hasTrial = sp.introductoryDiscount?.paymentMode == .freeTrial
Analytics.capture(.purchaseCompleted(
    plan: planID,
    price: sp.localizedPriceString,
    value: (sp.price as NSDecimalNumber).doubleValue,
    currency: sp.currencyCode ?? "USD",
    hasFreeTrial: hasTrial))
```
`TikTokAnalytics` choisit `StartTrial` vs `CompletePayment` selon `has_free_trial`. **Un seul** event revenu par achat → pas de double comptage.

### Limite connue (assumée)

L'essai gratuit weekly (3 j) émet `StartTrial` au démarrage. La conversion essai→payant au jour 4 se produit côté serveur (renouvellement) et l'app n'est pas forcément ouverte → non capté par le SDK. Capter 100 % des conversions d'essai nécessiterait un branchement serveur (webhook RevenueCat → TikTok Events API), **hors périmètre** de ce chantier.

## Tests

- `TikTokAnalytics` testable via un **mock du SDK** (protocole `TikTokEventSink` injecté, comme `MockAnalyticsProvider`). Assertions : chaque `AppEvent` produit le bon nom d'event TikTok + params (surtout `value`/`currency`, et le choix `StartTrial` vs `CompletePayment` selon `has_free_trial`). Events ignorés → aucun appel au sink.
- `CompositeAnalyticsProvider` : un `capture` diffuse bien aux deux providers ; `featureFlag` ne touche que PostHog.
- Build authoritatif via `xcodebuild` (pas de cible XCTest → smoke via le hook `SOLA_SCREEN` / `AnalyticsSmoke`). Erreurs SourceKit "cannot find X" = faux positifs.
- Vérif manuelle finale dans **TikTok Events Manager → Test Events** (mode debug) une fois les credentials réels renseignés.

## Hors périmètre (YAGNI)

- Webhook serveur RevenueCat → TikTok (conversions d'essai, renouvellements).
- Login Kit / Share Kit TikTok (SDK différent).
- Deep-linking / attribution deferred au-delà de ce que le SDK fait par défaut.
