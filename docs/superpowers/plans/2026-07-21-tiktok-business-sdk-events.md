# TikTok Business SDK — Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Envoyer les conversions de Goldn (ouverture, onboarding, tunnel paywall, essai/achat avec valeur+devise) vers TikTok Business SDK pour optimiser les campagnes TikTok Ads et mesurer le ROAS.

**Architecture:** TikTok se branche comme second `AnalyticsProvider` derrière un `CompositeAnalyticsProvider` qui diffuse chaque appel vers `[PostHog, TikTok]`. Aucun call-site `Analytics.capture(...)` existant ne change. Le SDK réel est isolé derrière un protocole `TikTokEventSink` (couture testable). Le gating consentement/ATT réutilise le flux `Analytics.optIn()` existant.

**Tech Stack:** Swift, SwiftUI, SPM, RevenueCat (StoreProduct → prix/devise/essai), TikTokBusinessSDK 1.7.x, PostHog (inchangé).

## Global Constraints

- **Config client SDK :** `iosAppID = "6779321701"`, `tiktokAppID = "7664919269825691656"`. Ce sont les **seules** valeurs câblées.
- **⚠️ App secret TikTok :** ne JAMAIS l'embarquer dans le binaire ni le committer. Le SDK client ne l'utilise pas.
- **Gating :** rien n'est envoyé à TikTok avant consentement. Le SDK n'est **initialisé qu'à l'opt-in** (pas au launch), pour ne pas auto-tracker install/launch avant consentement.
- **Un seul event revenu par achat** (`StartTrial` OU `CompletePayment`) → pas de double comptage. `disablePaymentTracking()` sur la config SDK.
- **Pas de cible XCTest :** les tests sont des smoke-asserts DEBUG (pattern `AnalyticsSmoke`). `xcodebuild build` est le gate compile autoritatif ; les erreurs SourceKit « cannot find X » sont de faux positifs.
- **Usage strings :** français uniquement, en build settings `INFOPLIST_KEY_*` (cohérent avec camera/location/photo existants). Pas de localisation par lproj.
- **Nom collision :** la classe SDK s'appelle `TikTokConfig` → notre config d'app s'appelle `TikTokAdsConfig`.

---

## Recette réutilisable — build & smoke run

**Build (gate compile autoritatif) :**
```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DD build 2>&1 | tail -8
```
Attendu : `** BUILD SUCCEEDED **`.

**Smoke run (exécute les asserts DEBUG et affiche les ✅) :**
```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl install booted "$(find build/DD/Build/Products/Debug-iphonesimulator -maxdepth 1 -name '*.app' | head -1)"
SIMCTL_CHILD_SOLA_ANALYTICS_SMOKE=1 xcrun simctl launch --console-pty --terminate-running-process booted com.meflabs.SOLA 2>&1 | grep -E "✅|assert|Fatal|❌" | head -20
```
Attendu : lignes `✅ ... OK`, aucune ligne `assert`/`Fatal`.

---

## File Structure

- **Create** `SOLA/Services/Analytics/TikTokAdsConfig.swift` — IDs + `isConfigured`.
- **Create** `SOLA/Services/Analytics/TikTokAnalytics.swift` — provider TikTok + protocole `TikTokEventSink` + mapping `AppEvent → event TikTok` + sink réel `TikTokBusinessSink` + `NoopTikTokSink`.
- **Create** `SOLA/Services/Analytics/CompositeAnalyticsProvider.swift` — fan-out multi-providers.
- **Create** `SOLA/Services/Analytics/TikTokAnalyticsSmoke.swift` — smoke-asserts (mock sink).
- **Modify** `SOLA/Services/Analytics/Analytics.swift` — enum `AppEvent.purchaseCompleted` enrichi ; `provider` par défaut = composite.
- **Modify** `SOLA/Services/PurchaseManager.swift` (~ligne 200) — passe value/currency/hasFreeTrial.
- **Modify** `SOLA/SOLAApp.swift` — appelle `TikTokAnalyticsSmoke.run()` sous env DEBUG.
- **Modify** `SOLA.xcodeproj/project.pbxproj` — dépendance SPM TikTokBusinessSDK ; `INFOPLIST_KEY_NSUserTrackingUsageDescription`.
- **Modify** `App-Info.plist` — `SKAdNetworkItems`.
- **Modify** `SOLA/PrivacyInfo.xcprivacy` — tracking IDFA.

---

### Task 1 : Dépendance SPM TikTokBusinessSDK

Ajoute le package via édition directe du `project.pbxproj` (IDs propres `A0000xxx`, comme PostHog `A0000300`). Nouveaux IDs : `A0000400` (ref package), `A0000401` (product dependency), `A0000402` (build file).

**Files:**
- Modify: `SOLA.xcodeproj/project.pbxproj` (4 sections)

**Interfaces:**
- Produces: le module `TikTokBusinessSDK` (import Swift disponible dans la target SOLA).

- [ ] **Step 1 : PBXBuildFile — ajouter la ligne**

Dans la section `/* Begin PBXBuildFile section */` (après la ligne `A0000302 /* PostHog in Frameworks */ ...`), insérer :
```
		A0000402 /* TikTokBusinessSDK in Frameworks */ = {isa = PBXBuildFile; productRef = A0000401 /* TikTokBusinessSDK */; };
```

- [ ] **Step 2 : PBXFrameworksBuildPhase — lier dans la target SOLA**

Dans `A0000010 /* Frameworks */`, la liste `files = (`, après `A0000302 /* PostHog in Frameworks */,` insérer :
```
				A0000402 /* TikTokBusinessSDK in Frameworks */,
```

- [ ] **Step 3 : PBXNativeTarget SOLA — packageProductDependencies**

Dans le bloc target SOLA, `packageProductDependencies = (`, après `A0000301 /* PostHog */,` insérer :
```
				A0000401 /* TikTokBusinessSDK */,
```

- [ ] **Step 4 : PBXProject — packageReferences**

Dans `A0000005 /* Project object */`, `packageReferences = (`, après `A0000300 /* XCRemoteSwiftPackageReference "posthog-ios" */,` insérer :
```
				A0000400 /* XCRemoteSwiftPackageReference "tiktok-business-ios-sdk" */,
```

- [ ] **Step 5 : XCRemoteSwiftPackageReference — déclarer le repo**

Dans `/* Begin XCRemoteSwiftPackageReference section */`, après le bloc `A0000300 ... posthog-ios ...` insérer :
```
		A0000400 /* XCRemoteSwiftPackageReference "tiktok-business-ios-sdk" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/tiktok/tiktok-business-ios-sdk.git";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = 1.7.0;
			};
		};
```

- [ ] **Step 6 : XCSwiftPackageProductDependency — déclarer le produit**

Dans `/* Begin XCSwiftPackageProductDependency section */`, après le bloc `A0000301 /* PostHog */ ...` insérer :
```
		A0000401 /* TikTokBusinessSDK */ = {
			isa = XCSwiftPackageProductDependency;
			package = A0000400 /* XCRemoteSwiftPackageReference "tiktok-business-ios-sdk" */;
			productName = TikTokBusinessSDK;
		};
```

- [ ] **Step 7 : Résoudre le package**

Run :
```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA -resolvePackageDependencies 2>&1 | tail -15
```
Attendu : résolution sans erreur, `tiktok-business-ios-sdk` listé (version 1.7.x).

- [ ] **Step 8 : Vérifier le build (module importable)**

Créer temporairement en tête de `SOLA/SOLAApp.swift` la ligne `import TikTokBusinessSDK`, puis lancer la commande **Build** de la recette. Attendu : `** BUILD SUCCEEDED **`. Retirer ensuite l'import temporaire (il sera ajouté proprement dans le sink en Task 4).

- [ ] **Step 9 : Commit**

```bash
git add SOLA.xcodeproj/project.pbxproj
git commit -m "build(tiktok): add TikTok Business SDK via SPM"
```

---

### Task 2 : TikTokAdsConfig

**Files:**
- Create: `SOLA/Services/Analytics/TikTokAdsConfig.swift`

**Interfaces:**
- Produces: `enum TikTokAdsConfig { static let iosAppID: String; static let tiktokAppID: String; static var isConfigured: Bool }`

- [ ] **Step 1 : Écrire le fichier**

```swift
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
```

- [ ] **Step 2 : Ajouter le fichier à la target** — grâce à `fileSystemSynchronizedGroups`, le dossier `SOLA/` est auto-synchronisé ; aucune édition pbxproj nécessaire. Vérifier via la commande **Build** : `** BUILD SUCCEEDED **`.

- [ ] **Step 3 : Commit**

```bash
git add SOLA/Services/Analytics/TikTokAdsConfig.swift
git commit -m "feat(tiktok): add TikTokAdsConfig (App ID + TikTok App ID)"
```

---

### Task 3 : Enrichir `AppEvent.purchaseCompleted` (value + currency + trial)

Le case porte aujourd'hui `(plan, price)`. On ajoute `value: Double`, `currency: String`, `hasFreeTrial: Bool` pour alimenter TikTok. PostHog reçoit ces champs en bonus.

**Files:**
- Modify: `SOLA/Services/Analytics/Analytics.swift` (case `purchaseCompleted`, ~L64, ~L79, ~L94)
- Modify: `SOLA/Services/PurchaseManager.swift` (~L200)

**Interfaces:**
- Produces: `AppEvent.purchaseCompleted(plan: String, price: String, value: Double, currency: String, hasFreeTrial: Bool)` dont `.properties` renvoie `["plan", "price", "value", "currency", "has_free_trial"]`.

- [ ] **Step 1 : Modifier le case de l'enum**

Dans `Analytics.swift`, remplacer :
```swift
    case purchaseCompleted(plan: String, price: String)
```
par :
```swift
    case purchaseCompleted(plan: String, price: String, value: Double, currency: String, hasFreeTrial: Bool)
```

- [ ] **Step 2 : Modifier le mapping `properties`**

Dans `var properties`, remplacer :
```swift
        case let .purchaseCompleted(plan, price): return ["plan": plan, "price": price]
```
par :
```swift
        case let .purchaseCompleted(plan, price, value, currency, hasFreeTrial):
            return ["plan": plan, "price": price, "value": value,
                    "currency": currency, "has_free_trial": hasFreeTrial]
```
(Le `case .purchaseCompleted: return "purchase_completed"` dans `var name` reste inchangé.)

- [ ] **Step 3 : Modifier le call-site dans PurchaseManager**

Dans `PurchaseManager.purchase(_ package:)`, remplacer :
```swift
                Analytics.capture(.purchaseCompleted(plan: planID, price: package.storeProduct.localizedPriceString))
```
par :
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

- [ ] **Step 4 : Build** — commande **Build** de la recette. Attendu : `** BUILD SUCCEEDED **`.

- [ ] **Step 5 : Commit**

```bash
git add SOLA/Services/Analytics/Analytics.swift SOLA/Services/PurchaseManager.swift
git commit -m "feat(analytics): enrich purchase_completed with value/currency/trial"
```

---

### Task 4 : TikTokAnalytics (sink + mapping + sink réel)

Cœur du chantier. `TikTokEventSink` isole le SDK (testable). `TikTokAnalytics` implémente `AnalyticsProvider`, initialise le SDK **à l'opt-in** et traduit chaque `AppEvent` vers l'event TikTok standard.

**Files:**
- Create: `SOLA/Services/Analytics/TikTokAnalytics.swift`

**Interfaces:**
- Consumes: `TikTokAdsConfig` (Task 2) ; `AnalyticsProvider` (existant, `Analytics.swift`).
- Produces:
  - `protocol TikTokEventSink: AnyObject { func initializeSDK(); func requestATT(); func track(event: String, properties: [String: Any]) }`
  - `final class TikTokAnalytics: AnalyticsProvider` avec `init(sink: TikTokEventSink)`
  - `static func map(_ event: String, _ props: [String: Any]) -> (name: String, props: [String: Any])?`
  - `final class TikTokBusinessSink: TikTokEventSink` (réel) et `final class NoopTikTokSink: TikTokEventSink`

- [ ] **Step 1 : Écrire le fichier complet**

```swift
import Foundation

// MARK: - Couture SDK (testable)

/// Abstraction du SDK TikTok réel — permet de mocker en test.
protocol TikTokEventSink: AnyObject {
    func initializeSDK()
    func requestATT()
    func track(event: String, properties: [String: Any])
}

// MARK: - Provider TikTok

/// Renvoie les conversions vers TikTok. Gating : le SDK n'est initialisé qu'à
/// l'`optIn()` (consentement), jamais au launch → rien avant consentement.
final class TikTokAnalytics: AnalyticsProvider {
    private let sink: TikTokEventSink
    private var started = false

    init(sink: TikTokEventSink) { self.sink = sink }

    func setup() { /* rien : init différée à optIn() pour respecter le consentement */ }

    func optIn() {
        guard TikTokAdsConfig.isConfigured else { return }
        if !started { started = true; sink.initializeSDK() }
        sink.requestATT()
    }

    func optOut() { /* le SDK n'est jamais démarré sans opt-in ; rien à défaire */ }

    func capture(_ event: String, _ properties: [String: Any]?) {
        guard TikTokAdsConfig.isConfigured, started else { return }
        guard let mapped = Self.map(event, properties ?? [:]) else { return }
        sink.track(event: mapped.name, properties: mapped.props)
    }

    // TikTok ne gère pas de feature flags.
    func featureFlag(_ key: String) -> Any? { nil }
    func featureFlagPayload(_ key: String) -> Any? { nil }
    func reloadFeatureFlags() {}

    // MARK: Mapping AppEvent → event standard TikTok

    /// Traduit un event interne (name + properties) vers l'event TikTok.
    /// Renvoie `nil` pour les events non pertinents pub (ignorés).
    static func map(_ event: String, _ props: [String: Any]) -> (name: String, props: [String: Any])? {
        switch event {
        case "onboarding_completed":
            return ("CompleteTutorial", [:])
        case "paywall_viewed":
            var p: [String: Any] = ["content_type": "paywall"]
            if let variant = props["variant"] { p["content_id"] = variant }
            return ("ViewContent", p)
        case "paywall_plan_selected":
            return ("AddToCart", contentID(props, key: "plan"))
        case "purchase_started":
            return ("InitiateCheckout", contentID(props, key: "plan"))
        case "purchase_completed":
            let hasTrial = (props["has_free_trial"] as? Bool) ?? false
            var p = contentID(props, key: "plan")
            if let value = props["value"] { p["value"] = value }
            if let currency = props["currency"] { p["currency"] = currency }
            return (hasTrial ? "StartTrial" : "CompletePayment", p)
        default:
            return nil
        }
    }

    private static func contentID(_ props: [String: Any], key: String) -> [String: Any] {
        if let v = props[key] { return ["content_id": v] }
        return [:]
    }
}

// MARK: - Sink réel (SDK TikTok)

#if canImport(TikTokBusinessSDK)
import TikTokBusinessSDK

final class TikTokBusinessSink: TikTokEventSink {
    func initializeSDK() {
        let config = TikTokConfig(accessToken: nil,
                                  appId: TikTokAdsConfig.iosAppID,
                                  tiktokAppId: TikTokAdsConfig.tiktokAppID)
        config?.disablePaymentTracking()   // on émet nos propres events revenu → pas de doublon
        #if DEBUG
        config?.enableDebugMode()          // Test Events dans TikTok Events Manager
        #endif
        TikTokBusiness.initializeSdk(config)
    }

    func requestATT() {
        TikTokBusiness.requestTrackingAuthorization { _ in }
    }

    func track(event: String, properties: [String: Any]) {
        let e = TikTokBaseEvent(eventName: event)
        for (k, v) in properties { e.addProperty(withKey: k, value: v) }
        TikTokBusiness.trackTTEvent(e)
    }
}
#endif

// MARK: - Sink no-op (fallback si module absent)

final class NoopTikTokSink: TikTokEventSink {
    func initializeSDK() {}
    func requestATT() {}
    func track(event: String, properties: [String: Any]) {}
}
```

- [ ] **Step 2 : Build** — commande **Build**. Attendu : `** BUILD SUCCEEDED **`. (Si SourceKit signale « cannot find TikTokBusiness », c'est un faux positif — seul `xcodebuild` fait foi.)

- [ ] **Step 3 : Commit**

```bash
git add SOLA/Services/Analytics/TikTokAnalytics.swift
git commit -m "feat(tiktok): TikTokAnalytics provider + event mapping + SDK sink"
```

---

### Task 5 : CompositeAnalyticsProvider (fan-out)

**Files:**
- Create: `SOLA/Services/Analytics/CompositeAnalyticsProvider.swift`

**Interfaces:**
- Consumes: `AnalyticsProvider` (existant).
- Produces: `final class CompositeAnalyticsProvider: AnalyticsProvider` avec `init(_ providers: [AnalyticsProvider])`. `capture/setup/optIn/optOut/reloadFeatureFlags` → fan-out à tous ; `featureFlag/featureFlagPayload` → premier non-nil.

- [ ] **Step 1 : Écrire le fichier**

```swift
import Foundation

/// Diffuse chaque appel analytics vers plusieurs providers (PostHog + TikTok).
/// Les feature flags sont délégués au premier provider qui en renvoie un
/// (PostHog est placé en premier ; TikTok renvoie toujours nil).
final class CompositeAnalyticsProvider: AnalyticsProvider {
    private let providers: [AnalyticsProvider]
    init(_ providers: [AnalyticsProvider]) { self.providers = providers }

    func setup()  { providers.forEach { $0.setup() } }
    func optIn()  { providers.forEach { $0.optIn() } }
    func optOut() { providers.forEach { $0.optOut() } }

    func capture(_ event: String, _ properties: [String: Any]?) {
        providers.forEach { $0.capture(event, properties) }
    }

    func featureFlag(_ key: String) -> Any? {
        for p in providers { if let v = p.featureFlag(key) { return v } }
        return nil
    }
    func featureFlagPayload(_ key: String) -> Any? {
        for p in providers { if let v = p.featureFlagPayload(key) { return v } }
        return nil
    }
    func reloadFeatureFlags() { providers.forEach { $0.reloadFeatureFlags() } }
}
```

- [ ] **Step 2 : Build** — commande **Build**. Attendu : `** BUILD SUCCEEDED **`.

- [ ] **Step 3 : Commit**

```bash
git add SOLA/Services/Analytics/CompositeAnalyticsProvider.swift
git commit -m "feat(analytics): CompositeAnalyticsProvider (fan-out multi-providers)"
```

---

### Task 6 : Câbler le composite + smoke-asserts du mapping

Branche TikTok dans la façade `Analytics` et vérifie le mapping via des asserts DEBUG (mock sink), puis exécute le smoke run pour un vrai vert.

**Files:**
- Modify: `SOLA/Services/Analytics/Analytics.swift` (ligne `static var provider`)
- Create: `SOLA/Services/Analytics/TikTokAnalyticsSmoke.swift`
- Modify: `SOLA/SOLAApp.swift` (init, sous env DEBUG)

**Interfaces:**
- Consumes: `TikTokAnalytics`, `TikTokEventSink`, `NoopTikTokSink`, `CompositeAnalyticsProvider`, `PostHogAnalytics`.
- Produces: `enum TikTokAnalyticsSmoke { static func run() }`.

- [ ] **Step 1 : Écrire le smoke-assert (le « test », d'abord)**

Créer `SOLA/Services/Analytics/TikTokAnalyticsSmoke.swift` :
```swift
#if DEBUG
import Foundation

/// Smoke-asserts du mapping TikTok. Appelé depuis SOLAApp en DEBUG si l'env
/// `SOLA_ANALYTICS_SMOKE` est présent. Zéro impact en prod.
enum TikTokAnalyticsSmoke {

    /// Sink de test qui enregistre les events envoyés au SDK.
    final class RecordingSink: TikTokEventSink {
        private(set) var initialized = false
        private(set) var attRequested = false
        private(set) var tracked: [(String, [String: Any])] = []
        func initializeSDK() { initialized = true }
        func requestATT() { attRequested = true }
        func track(event: String, properties: [String: Any]) { tracked.append((event, properties)) }
    }

    static func run() {
        let sink = RecordingSink()
        let tt = TikTokAnalytics(sink: sink)

        // 1) Avant opt-in : capture ignorée (SDK non démarré).
        tt.capture("purchase_started", ["plan": "weekly"])
        assert(sink.tracked.isEmpty, "TikTok ne doit rien envoyer avant optIn")

        // 2) opt-in : init SDK + ATT demandée.
        tt.optIn()
        assert(sink.initialized, "optIn doit initialiser le SDK")
        assert(sink.attRequested, "optIn doit demander l'ATT")

        // 3) onboarding fini → CompleteTutorial.
        tt.capture("onboarding_completed", nil)
        assert(sink.tracked.last?.0 == "CompleteTutorial", "onboarding_completed → CompleteTutorial")

        // 4) paywall vu → ViewContent + content_type/paywall.
        tt.capture("paywall_viewed", ["source": "main", "variant": "A"])
        assert(sink.tracked.last?.0 == "ViewContent")
        assert(sink.tracked.last?.1["content_type"] as? String == "paywall")
        assert(sink.tracked.last?.1["content_id"] as? String == "A")

        // 5) plan choisi → AddToCart.
        tt.capture("paywall_plan_selected", ["plan": "annual"])
        assert(sink.tracked.last?.0 == "AddToCart")
        assert(sink.tracked.last?.1["content_id"] as? String == "annual")

        // 6) paiement lancé → InitiateCheckout.
        tt.capture("purchase_started", ["plan": "annual"])
        assert(sink.tracked.last?.0 == "InitiateCheckout")

        // 7) achat SANS essai → CompletePayment + value/currency.
        tt.capture("purchase_completed", ["plan": "annual", "price": "39,99 €",
                                          "value": 39.99, "currency": "EUR", "has_free_trial": false])
        assert(sink.tracked.last?.0 == "CompletePayment", "sans essai → CompletePayment")
        assert(sink.tracked.last?.1["value"] as? Double == 39.99)
        assert(sink.tracked.last?.1["currency"] as? String == "EUR")

        // 8) achat AVEC essai (weekly) → StartTrial + value/currency.
        tt.capture("purchase_completed", ["plan": "weekly", "price": "4,99 €",
                                          "value": 4.99, "currency": "EUR", "has_free_trial": true])
        assert(sink.tracked.last?.0 == "StartTrial", "avec essai → StartTrial")
        assert(sink.tracked.last?.1["value"] as? Double == 4.99)

        // 9) event non pertinent → ignoré.
        let before = sink.tracked.count
        tt.capture("purchase_failed", ["reason": "x"])
        tt.capture("consent_granted", nil)
        assert(sink.tracked.count == before, "les events non mappés doivent être ignorés")

        // 10) Composite : featureFlag ne touche que PostHog (TikTok renvoie nil).
        let mock = MockAnalyticsProvider(); mock.flags = ["k": "v"]
        let composite = CompositeAnalyticsProvider([mock, TikTokAnalytics(sink: RecordingSink())])
        composite.capture("purchase_started", ["plan": "weekly"])
        assert(mock.captured.count == 1, "composite doit diffuser à PostHog")
        assert(composite.featureFlag("k") as? String == "v", "featureFlag délégué à PostHog")

        print("✅ TikTokAnalyticsSmoke OK")
    }
}
#endif
```

- [ ] **Step 2 : Câbler le provider composite dans la façade**

Dans `Analytics.swift`, remplacer :
```swift
    static var provider: AnalyticsProvider = PostHogAnalytics()
```
par :
```swift
    static var provider: AnalyticsProvider = CompositeAnalyticsProvider([
        PostHogAnalytics(),
        TikTokAnalytics(sink: Analytics.defaultTikTokSink())
    ])

    private static func defaultTikTokSink() -> TikTokEventSink {
        #if canImport(TikTokBusinessSDK)
        return TikTokBusinessSink()
        #else
        return NoopTikTokSink()
        #endif
    }
```

- [ ] **Step 3 : Appeler le smoke depuis SOLAApp**

Dans `SOLAApp.swift`, dans le bloc DEBUG existant, après `AnalyticsSmoke.run()` :
```swift
        #if DEBUG
        if ProcessInfo.processInfo.environment["SOLA_ANALYTICS_SMOKE"] != nil {
            AnalyticsSmoke.run()
            TikTokAnalyticsSmoke.run()
        }
        #endif
```
(Remplace le `if ... { AnalyticsSmoke.run() }` existant par le bloc ci-dessus.)

- [ ] **Step 4 : Build** — commande **Build**. Attendu : `** BUILD SUCCEEDED **`.

- [ ] **Step 5 : Smoke run** — recette **Smoke run**. Attendu : `✅ AnalyticsSmoke OK` **et** `✅ TikTokAnalyticsSmoke OK`, aucune ligne `assert`/`Fatal`.

- [ ] **Step 6 : Commit**

```bash
git add SOLA/Services/Analytics/Analytics.swift SOLA/Services/Analytics/TikTokAnalyticsSmoke.swift SOLA/SOLAApp.swift
git commit -m "feat(tiktok): wire composite provider + mapping smoke asserts"
```

---

### Task 7 : ATT usage description + SKAdNetwork + privacy manifest

**Files:**
- Modify: `SOLA.xcodeproj/project.pbxproj` (2 blocs buildSettings, ~L293 et ~L328)
- Modify: `App-Info.plist`
- Modify: `SOLA/PrivacyInfo.xcprivacy`

- [ ] **Step 1 : Ajouter la description ATT (français) dans les 2 blocs de build settings**

Dans `project.pbxproj`, après **chacune** des deux lignes `INFOPLIST_KEY_NSCameraUsageDescription = ...;` (Debug et Release), insérer :
```
				INFOPLIST_KEY_NSUserTrackingUsageDescription = "Goldn utilise ces données pour mesurer l'efficacité de ses publicités et améliorer l'application. Aucune donnée n'est vendue.";
```

- [ ] **Step 2 : Ajouter SKAdNetworkItems dans App-Info.plist**

Dans `App-Info.plist`, à l'intérieur du `<dict>` racine, ajouter :
```xml
	<key>SKAdNetworkItems</key>
	<array>
		<dict>
			<key>SKAdNetworkIdentifier</key>
			<string>238da6jt44.skadnetwork</string>
		</dict>
	</array>
```

- [ ] **Step 3 : Mettre à jour le privacy manifest (tracking IDFA)**

Remplacer le contenu de `SOLA/PrivacyInfo.xcprivacy` par :
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<true/>
	<key>NSPrivacyTrackingDomains</key>
	<array>
		<string>analytics.tiktok.com</string>
	</array>
	<key>NSPrivacyCollectedDataTypes</key>
	<array>
		<dict>
			<key>NSPrivacyCollectedDataType</key>
			<string>NSPrivacyCollectedDataTypeDeviceID</string>
			<key>NSPrivacyCollectedDataTypeLinked</key>
			<true/>
			<key>NSPrivacyCollectedDataTypeTracking</key>
			<true/>
			<key>NSPrivacyCollectedDataTypePurposes</key>
			<array>
				<string>NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyCollectedDataType</key>
			<string>NSPrivacyCollectedDataTypePurchaseHistory</string>
			<key>NSPrivacyCollectedDataTypeLinked</key>
			<true/>
			<key>NSPrivacyCollectedDataTypeTracking</key>
			<true/>
			<key>NSPrivacyCollectedDataTypePurposes</key>
			<array>
				<string>NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising</string>
			</array>
		</dict>
	</array>
	<key>NSPrivacyAccessedAPITypes</key>
	<array/>
</dict>
</plist>
```
Note : le SDK TikTok embarque son propre `PrivacyInfo.xcprivacy` (required-reason APIs) via SPM ; ce manifest-ci ne couvre que le tracking IDFA au niveau app.

- [ ] **Step 4 : Vérifier `analytics.tiktok.com`** — confirmer dans la doc TikTok Events Manager que le domaine d'envoi est bien `analytics.tiktok.com` (sinon ajuster `NSPrivacyTrackingDomains`). Un domaine de tracking manquant → rejet App Store.

- [ ] **Step 5 : Build** — commande **Build**. Attendu : `** BUILD SUCCEEDED **`.

- [ ] **Step 6 : Vérifier la clé ATT dans l'Info.plist compilé**

Run :
```bash
plutil -p "$(find build/DD/Build/Products/Debug-iphonesimulator -maxdepth 2 -name Info.plist -path '*.app/*' | head -1)" | grep -i "UserTracking\|SKAdNetwork"
```
Attendu : `NSUserTrackingUsageDescription` présent + `SKAdNetworkItems`.

- [ ] **Step 7 : Commit**

```bash
git add SOLA.xcodeproj/project.pbxproj App-Info.plist SOLA/PrivacyInfo.xcprivacy
git commit -m "chore(tiktok): ATT usage string + SKAdNetwork ID + privacy manifest"
```

---

### Task 8 : Vérification end-to-end + ATT au consentement

Confirme que l'acceptation du consentement déclenche bien l'init TikTok + le prompt ATT (via le fan-out `Analytics.optIn()` → `TikTokAnalytics.optIn()`), sans modifier `ConsentManager`.

**Files:**
- (aucune modif de code attendue — `ConsentManager.grant()` appelle déjà `Analytics.optIn()`)

- [ ] **Step 1 : Vérifier le chemin de déclenchement ATT**

Confirmer par lecture que `ConsentManager.grant()` (L21) appelle `Analytics.optIn()`, et que `Analytics.optIn()` → `provider.optIn()` → composite → `TikTokAnalytics.optIn()` (init + `requestATT`). Aucune modif nécessaire. Documenter ici si un écart est trouvé.

- [ ] **Step 2 : Run app + accepter le consentement (prompt ATT visible)**

```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcodebuild -project SOLA.xcodeproj -scheme SOLA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DD build 2>&1 | tail -3
xcrun simctl install booted "$(find build/DD/Build/Products/Debug-iphonesimulator -maxdepth 1 -name '*.app' | head -1)"
xcrun simctl launch --console-pty booted com.meflabs.SOLA 2>&1 | grep -iE "tiktok|ATT|track" | head
```
Accepter la bannière de consentement dans le simulateur. Attendu : logs du SDK TikTok en mode debug (init) ; le prompt ATT système s'affiche. (En simulateur l'IDFA reste nul — normal ; SKAdNetwork/IDFA réels se valident sur device + TikTok Events Manager.)

- [ ] **Step 3 : Build final propre**

```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build 2>&1 | tail -5
```
Attendu : `** BUILD SUCCEEDED **`.

- [ ] **Step 4 : Vérif manuelle post-credentials (checklist, hors build)**

Une fois sur un vrai device + build TestFlight : dans **TikTok Events Manager → Test Events**, vérifier la réception de `LaunchAPP`, `CompleteTutorial`, `ViewContent`, `AddToCart`, `InitiateCheckout`, et `StartTrial`/`CompletePayment` avec `value`+`currency`.

---

## Self-review — couverture spec

- ✅ Architecture composite + provider TikTok → Tasks 4, 5, 6.
- ✅ Config IDs + isConfigured (sans app secret) → Tasks 2, Global Constraints.
- ✅ Init SDK à l'opt-in + `disablePaymentTracking` + debug mode → Task 4.
- ✅ ATT via SDK au consentement → Tasks 4 (requestATT), 8.
- ✅ Mapping des 6 events + ignore le reste + value/currency + StartTrial vs CompletePayment → Tasks 3 (données), 4 (mapping), 6 (asserts).
- ✅ Dépendance SPM → Task 1.
- ✅ Info.plist ATT + SKAdNetwork + privacy manifest → Task 7.
- ✅ Tests smoke (pas de XCTest) + build autoritatif → Task 6, recette.
- ✅ Limite essai→payant (hors périmètre) → documentée dans le spec.
