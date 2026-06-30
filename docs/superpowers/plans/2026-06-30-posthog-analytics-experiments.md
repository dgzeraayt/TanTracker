# PostHog Analytics + Consent + A/B Infra — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Brancher PostHog Cloud EU dans l'app Goldn avec consentement opt-in strict, tracking du funnel, et une infra A/B test pilotable à distance par feature flags.

**Architecture:** Trois services découplés dans `SOLA/Services/Analytics/` — `Analytics` (façade + protocole + impl PostHog + mock), `ConsentManager` (état RGPD), `Experiments` (feature flags). PostHog est initialisé opt-out par défaut dans `SOLAApp.init()` ; le consentement bascule en opt-in. L'UI ne touche jamais le SDK directement.

**Tech Stack:** Swift / SwiftUI, package SPM `posthog-ios` (≥ 3.0), PostHog Cloud EU.

## Global Constraints

- Host PostHog : `https://eu.i.posthog.com` (Cloud EU).
- Clé API : `phc_…` (Project API Key) en constante de config — **valeur réelle fournie par l'utilisateur, sinon placeholder explicite**.
- **Opt-in strict** : PostHog démarre `optOut`, **aucun** event tant que `ConsentManager.state != .granted`.
- Aucune PII envoyée (pas d'email, pas d'IDFA). Identité = ID anonyme PostHog.
- Feature flags : **fallback `"control"` systématique** si non chargé / hors-ligne / refus de consentement.
- Nouveaux fichiers sous `SOLA/` → auto-inclus (groupes synchronisés Xcode 16). Pas d'édition pbxproj pour les `.swift`.
- Build de référence : `xcodebuild -scheme SOLA` fait foi. Les erreurs SourceKit « cannot find X » sont des **faux positifs** (cross-fichiers) — ignorer.
- **Pas de cible XCTest** dans le projet → la « vérification » d'une tâche = compilation `xcodebuild` réussie + (quand pertinent) contrôle runtime via `MockAnalyticsProvider` ou dashboard PostHog.
- Travailler sur une branche dédiée (`feat/posthog-analytics`), pas sur `main`.

### Commande de vérification de compilation (réutilisée partout)

```bash
cd /Users/maher/Documents/bronzage/TanTracker
xcodebuild build -project SOLA.xcodeproj -scheme SOLA \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
# Attendu : ** BUILD SUCCEEDED **
```

---

### Task 1: Ajouter le package SPM PostHog + constantes de config

**Files:**
- Modify: `SOLA.xcodeproj/project.pbxproj` (ajout du package, en miroir de RevenueCat aux objets `A0000100/101/102/103`)
- Create: `SOLA/Services/Analytics/AnalyticsConfig.swift`

**Interfaces:**
- Produces: `enum AnalyticsConfig { static let postHogAPIKey: String; static let postHogHost: String }`

- [ ] **Step 1: Ajouter la référence de package distante**

Dans `SOLA.xcodeproj/project.pbxproj`, section `XCRemoteSwiftPackageReference` (après l'objet `A0000100`), ajouter :

```
		A0000200 /* XCRemoteSwiftPackageReference "posthog-ios" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/PostHog/posthog-ios.git";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = 3.0.0;
			};
		};
```

- [ ] **Step 2: Ajouter la dépendance produit**

Section `XCSwiftPackageProductDependency` (après `A0000102`), ajouter :

```
		A0000201 /* PostHog */ = {
			isa = XCSwiftPackageProductDependency;
			package = A0000200 /* XCRemoteSwiftPackageReference "posthog-ios" */;
			productName = PostHog;
		};
```

- [ ] **Step 3: Ajouter le PBXBuildFile + les rattachements**

a) Section `PBXBuildFile` (près de `A0000103`) :

```
		A0000203 /* PostHog in Frameworks */ = {isa = PBXBuildFile; productRef = A0000201 /* PostHog */; };
```

b) Dans la `Frameworks` build phase de la cible SOLA (là où sont `A0000103`/`A0000104`), ajouter la ligne :

```
				A0000203 /* PostHog in Frameworks */,
```

c) Dans `packageProductDependencies` de la cible SOLA (là où sont `A0000101`/`A0000102`) :

```
				A0000201 /* PostHog */,
```

d) Dans `packageReferences` du projet (là où est `A0000100`) :

```
				A0000200 /* XCRemoteSwiftPackageReference "posthog-ios" */,
```

- [ ] **Step 4: Créer les constantes de config**

`SOLA/Services/Analytics/AnalyticsConfig.swift` :

```swift
import Foundation

/// Configuration PostHog (Cloud EU). La clé est une *Project API Key* publique
/// (préfixe phc_) — pas un secret serveur, elle peut vivre dans le binaire.
enum AnalyticsConfig {
    /// ⚠️ Remplacer par la vraie Project API Key PostHog (phc_…).
    static let postHogAPIKey = "phc_REPLACE_ME"
    static let postHogHost = "https://eu.i.posthog.com"

    /// `true` tant que la vraie clé n'est pas renseignée → l'init PostHog est sautée
    /// proprement (l'app marche sans analytics).
    static var isConfigured: Bool { postHogAPIKey.hasPrefix("phc_") && postHogAPIKey != "phc_REPLACE_ME" }
}
```

- [ ] **Step 5: Résoudre le package + compiler**

```bash
cd /Users/maher/Documents/bronzage/TanTracker
xcodebuild -resolvePackageDependencies -project SOLA.xcodeproj -scheme SOLA 2>&1 | tail -8
```
Attendu : résolution sans erreur, `PostHog` listé dans les packages résolus. Puis lancer la commande de build (Global Constraints). Attendu : `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add SOLA.xcodeproj/project.pbxproj SOLA/Services/Analytics/AnalyticsConfig.swift
git commit -m "build(analytics): add PostHog SPM package + config constants"
```

---

### Task 2: Couche Analytics (protocole + impl PostHog + mock + events + façade)

**Files:**
- Create: `SOLA/Services/Analytics/Analytics.swift`

**Interfaces:**
- Consumes: `AnalyticsConfig` (Task 1)
- Produces:
  - `protocol AnalyticsProvider` avec `optIn()`, `optOut()`, `capture(_:_: )`, `featureFlag(_:) -> Any?`, `featureFlagPayload(_:) -> Any?`, `reloadFeatureFlags()`
  - `final class PostHogAnalytics: AnalyticsProvider`
  - `final class MockAnalyticsProvider: AnalyticsProvider` (expose `captured: [(String, [String:Any]?)]`)
  - `enum AppEvent { … var name: String; var properties: [String:Any]? }`
  - `enum Analytics { static var provider: AnalyticsProvider; static var isOptedIn: Bool; static func setup(); static func capture(_ AppEvent); static func optIn(); static func optOut(); static func reloadFlags() }`

- [ ] **Step 1: Écrire le fichier complet**

`SOLA/Services/Analytics/Analytics.swift` :

```swift
import Foundation
import PostHog

// MARK: - Provider abstrait (couture pour tests/mock)

protocol AnalyticsProvider: AnyObject {
    func setup()
    func optIn()
    func optOut()
    func capture(_ event: String, _ properties: [String: Any]?)
    func featureFlag(_ key: String) -> Any?
    func featureFlagPayload(_ key: String) -> Any?
    func reloadFeatureFlags()
}

// MARK: - Impl réelle PostHog

final class PostHogAnalytics: AnalyticsProvider {
    func setup() {
        guard AnalyticsConfig.isConfigured else { return }
        let config = PostHogConfig(apiKey: AnalyticsConfig.postHogAPIKey,
                                   host: AnalyticsConfig.postHogHost)
        config.optOut = true            // opt-in strict : rien tant que pas de consentement
        config.captureScreenViews = false
        config.captureApplicationLifecycleEvents = false
        PostHogSDK.shared.setup(config)
    }
    func optIn()  { PostHogSDK.shared.optIn() }
    func optOut() { PostHogSDK.shared.optOut() }
    func capture(_ event: String, _ properties: [String: Any]?) {
        PostHogSDK.shared.capture(event, properties: properties)
    }
    func featureFlag(_ key: String) -> Any? { PostHogSDK.shared.getFeatureFlag(key) }
    func featureFlagPayload(_ key: String) -> Any? { PostHogSDK.shared.getFeatureFlagPayload(key) }
    func reloadFeatureFlags() { PostHogSDK.shared.reloadFeatureFlags() }
}

// MARK: - Mock (preview / debug, sans réseau)

final class MockAnalyticsProvider: AnalyticsProvider {
    private(set) var captured: [(String, [String: Any]?)] = []
    private(set) var optedIn = false
    var flags: [String: Any] = [:]
    func setup() {}
    func optIn()  { optedIn = true }
    func optOut() { optedIn = false }
    func capture(_ event: String, _ properties: [String: Any]?) { captured.append((event, properties)) }
    func featureFlag(_ key: String) -> Any? { flags[key] }
    func featureFlagPayload(_ key: String) -> Any? { nil }
    func reloadFeatureFlags() {}
}

// MARK: - Events typés

enum AppEvent {
    case appOpened
    case consentGranted, consentDenied
    case onboardingStarted
    case onboardingStepViewed(step: Int, name: String)
    case onboardingCompleted
    case paywallViewed(source: String, variant: String)
    case paywallPlanSelected(plan: String)
    case purchaseStarted(plan: String)
    case purchaseCompleted(plan: String, price: String)
    case purchaseFailed(reason: String)
    case purchaseRestored
    case exitOfferShown, exitOfferAccepted

    var name: String {
        switch self {
        case .appOpened: return "app_opened"
        case .consentGranted: return "consent_granted"
        case .consentDenied: return "consent_denied"
        case .onboardingStarted: return "onboarding_started"
        case .onboardingStepViewed: return "onboarding_step_viewed"
        case .onboardingCompleted: return "onboarding_completed"
        case .paywallViewed: return "paywall_viewed"
        case .paywallPlanSelected: return "paywall_plan_selected"
        case .purchaseStarted: return "purchase_started"
        case .purchaseCompleted: return "purchase_completed"
        case .purchaseFailed: return "purchase_failed"
        case .purchaseRestored: return "purchase_restored"
        case .exitOfferShown: return "exit_offer_shown"
        case .exitOfferAccepted: return "exit_offer_accepted"
        }
    }

    var properties: [String: Any]? {
        switch self {
        case let .onboardingStepViewed(step, name): return ["step": step, "name": name]
        case let .paywallViewed(source, variant): return ["source": source, "variant": variant]
        case let .paywallPlanSelected(plan): return ["plan": plan]
        case let .purchaseStarted(plan): return ["plan": plan]
        case let .purchaseCompleted(plan, price): return ["plan": plan, "price": price]
        case let .purchaseFailed(reason): return ["reason": reason]
        default: return nil
        }
    }
}

// MARK: - Façade

enum Analytics {
    static var provider: AnalyticsProvider = PostHogAnalytics()
    static private(set) var isOptedIn = false

    static func setup() { provider.setup() }

    static func optIn()  { isOptedIn = true;  provider.optIn();  provider.reloadFeatureFlags() }
    static func optOut() { isOptedIn = false; provider.optOut() }

    static func capture(_ event: AppEvent) {
        guard isOptedIn else { return }              // no-op tant que pas consenti
        provider.capture(event.name, event.properties)
    }

    static func reloadFlags() { provider.reloadFeatureFlags() }
}
```

- [ ] **Step 2: Compiler**

Lancer la commande de build (Global Constraints). Attendu : `** BUILD SUCCEEDED **`. (Ignorer les faux positifs SourceKit.)

- [ ] **Step 3: Commit**

```bash
git add SOLA/Services/Analytics/Analytics.swift
git commit -m "feat(analytics): provider protocol, PostHog impl, mock, typed events, facade"
```

---

### Task 2b: Vérifier le no-op via le mock (contrôle runtime sans cible test)

**Files:**
- Create (temporaire) : `SOLA/Services/Analytics/AnalyticsSmoke.swift`

**Interfaces:**
- Consumes: `Analytics`, `MockAnalyticsProvider`, `AppEvent` (Task 2)

- [ ] **Step 1: Écrire un smoke check DEBUG**

`SOLA/Services/Analytics/AnalyticsSmoke.swift` :

```swift
#if DEBUG
import Foundation

/// Smoke check du no-op opt-in. Appelé manuellement depuis SOLAApp en DEBUG
/// si l'env `SOLA_ANALYTICS_SMOKE` est présent, puis retiré.
enum AnalyticsSmoke {
    static func run() {
        let mock = MockAnalyticsProvider()
        Analytics.provider = mock
        Analytics.capture(.appOpened)                 // doit être ignoré (pas opt-in)
        assert(mock.captured.isEmpty, "capture avant consentement doit être no-op")
        Analytics.optIn()
        Analytics.capture(.onboardingStepViewed(step: 3, name: "ScrAge"))
        assert(mock.captured.count == 1, "capture après opt-in doit passer")
        assert(mock.captured.first?.0 == "onboarding_step_viewed")
        print("✅ AnalyticsSmoke OK")
    }
}
#endif
```

- [ ] **Step 2: Brancher temporairement + lancer**

Dans `SOLAApp.init()`, ajouter temporairement (en DEBUG) :
```swift
#if DEBUG
if ProcessInfo.processInfo.environment["SOLA_ANALYTICS_SMOKE"] != nil { AnalyticsSmoke.run() }
#endif
```
Compiler (commande Global Constraints) — attendu `** BUILD SUCCEEDED **`. Le test runtime réel se fera quand l'app tourne ; ici on valide surtout que ça compile et que la logique tient.

- [ ] **Step 3: Retirer le smoke + commit**

Retirer le bloc temporaire de `SOLAApp.init()` ET supprimer `AnalyticsSmoke.swift` (YAGNI une fois validé), OU le garder gardé par l'env. Choix : **le garder** (utile, gardé par DEBUG+env, zéro impact prod).

```bash
git add SOLA/Services/Analytics/AnalyticsSmoke.swift SOLA/SOLAApp.swift
git commit -m "test(analytics): DEBUG smoke check du no-op opt-in"
```

---

### Task 3: ConsentManager

**Files:**
- Create: `SOLA/Services/Analytics/ConsentManager.swift`

**Interfaces:**
- Consumes: `Analytics` (Task 2)
- Produces: `enum ConsentState: String { case undecided, granted, denied }` ; `@MainActor final class ConsentManager: ObservableObject` avec `@Published state`, `shouldPromptConsent: Bool`, `grant()`, `deny()`

- [ ] **Step 1: Écrire le fichier**

`SOLA/Services/Analytics/ConsentManager.swift` :

```swift
import Foundation

enum ConsentState: String { case undecided, granted, denied }

@MainActor
final class ConsentManager: ObservableObject {
    private static let key = "analytics_consent"
    @Published private(set) var state: ConsentState

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.key)
        state = raw.flatMap(ConsentState.init(rawValue:)) ?? .undecided
        // Réapplique l'état au démarrage (PostHog est opt-out par défaut).
        if state == .granted { Analytics.optIn() }
    }

    var shouldPromptConsent: Bool { state == .undecided }

    func grant() {
        set(.granted)
        Analytics.optIn()
        Analytics.capture(.consentGranted)
        Analytics.capture(.appOpened)
    }

    func deny() {
        Analytics.capture(.consentDenied)   // no-op (pas opt-in) — gardé pour symétrie
        set(.denied)
        Analytics.optOut()
    }

    private func set(_ s: ConsentState) {
        state = s
        UserDefaults.standard.set(s.rawValue, forKey: Self.key)
    }
}
```

- [ ] **Step 2: Compiler** — commande Global Constraints, attendu `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add SOLA/Services/Analytics/ConsentManager.swift
git commit -m "feat(analytics): ConsentManager opt-in strict persisté"
```

---

### Task 4: Experiments (feature flags)

**Files:**
- Create: `SOLA/Services/Analytics/Experiments.swift`

**Interfaces:**
- Consumes: `Analytics` (Task 2)
- Produces: `enum Experiment: String { case paywallLayout = "paywall_layout" }` ; `enum Experiments { static func variant(_:default:) -> String; static func payload(_:) -> [String:Any]?; static func isEnabled(_:) -> Bool; static func reload() }`

- [ ] **Step 1: Écrire le fichier**

`SOLA/Services/Analytics/Experiments.swift` :

```swift
import Foundation

/// Clés de feature flags PostHog. Une clé = un test piloté depuis le dashboard.
enum Experiment: String {
    case paywallLayout = "paywall_layout"   // chantier #2
}

enum Experiments {
    /// Variante d'un test multivarié. Fallback "control" si non chargé / hors-ligne / opt-out.
    static func variant(_ e: Experiment, default fallback: String = "control") -> String {
        guard Analytics.isOptedIn, let v = Analytics.provider.featureFlag(e.rawValue) else { return fallback }
        if let s = v as? String { return s }
        if let b = v as? Bool { return b ? "test" : fallback }
        return fallback
    }

    /// Payload de remote config (prix, copy, ordre…). nil si absent.
    static func payload(_ e: Experiment) -> [String: Any]? {
        guard Analytics.isOptedIn else { return nil }
        return Analytics.provider.featureFlagPayload(e.rawValue) as? [String: Any]
    }

    /// Flag booléen simple (kill-switch, toggle de feature).
    static func isEnabled(_ key: String) -> Bool {
        guard Analytics.isOptedIn else { return false }
        return (Analytics.provider.featureFlag(key) as? Bool) ?? false
    }

    static func reload() { Analytics.reloadFlags() }
}
```

- [ ] **Step 2: Compiler** — commande Global Constraints, attendu `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add SOLA/Services/Analytics/Experiments.swift
git commit -m "feat(analytics): Experiments helper sur feature flags PostHog"
```

---

### Task 5: Init PostHog + injection ConsentManager

**Files:**
- Modify: `SOLA/SOLAApp.swift`

**Interfaces:**
- Consumes: `Analytics.setup()` (Task 2), `ConsentManager` (Task 3)
- Produces: `ConsentManager` disponible en `@EnvironmentObject` ; PostHog initialisé au lancement

- [ ] **Step 1: Initialiser PostHog dans `SOLAApp.init()`**

Modifier le `init()` de `struct SOLAApp` :

```swift
init() {
    FontLoader.registerAll()
    Analytics.setup()
}
```

- [ ] **Step 2: Ajouter le ConsentManager à RootView**

Dans `struct RootView`, ajouter le StateObject (à côté des autres managers) :

```swift
@StateObject private var consent = ConsentManager()
```

Et l'injecter dans la chaîne `.environmentObject(...)` du `body` (après `.environmentObject(personalization)`) :

```swift
.environmentObject(consent)
```

- [ ] **Step 3: Compiler** — commande Global Constraints, attendu `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add SOLA/SOLAApp.swift
git commit -m "feat(analytics): init PostHog au lancement + injection ConsentManager"
```

---

### Task 6: Bottom sheet de consentement (différée après chargement)

**Files:**
- Create: `SOLA/Services/Analytics/ConsentSheet.swift`
- Modify: `SOLA/SOLAApp.swift` (présentation dans `RootView`)

**Interfaces:**
- Consumes: `ConsentManager` (Task 3)
- Produces: `struct ConsentSheet: View` (callbacks `onAccept`, `onRefuse`)

- [ ] **Step 1: Écrire la sheet**

`SOLA/Services/Analytics/ConsentSheet.swift` (suit les composants existants — `SolaButton`, `Palette`, `DisplayText`/`LeadText` si dispo ; sinon `Text`) :

```swift
import SwiftUI

/// Bandeau de consentement analytics (opt-in RGPD). Non-dismissible : un choix est requis.
struct ConsentSheet: View {
    var onAccept: () -> Void
    var onRefuse: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Aide-nous à améliorer Goldn")
                .font(.title2.bold()).multilineTextAlignment(.center)
            Text("On mesure l'usage de l'app de façon anonyme (via PostHog, hébergé en Europe) pour l'améliorer. Aucune donnée personnelle, pas de publicité. Tu peux refuser, l'app marche pareil.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Link("Politique de confidentialité", destination: URL(string: "https://goldn.app/privacy")!)
                .font(.footnote)
            VStack(spacing: 10) {
                Button(action: onAccept) {
                    Text("Accepter").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent)
                Button(action: onRefuse) {
                    Text("Refuser").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
            }
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }
}
```
> Note : remplacer l'URL `https://goldn.app/privacy` par l'URL réelle de la politique de confidentialité. Et adapter aux composants maison (`SolaButton`, `Palette`) si on veut le style Goldn — fonctionnellement, ce qui précède suffit.

- [ ] **Step 2: Présenter la sheet après chargement dans RootView**

Dans `struct RootView`, ajouter un état :
```swift
@State private var showConsent = false
```
Sur le conteneur du `body` (le `Group { … }`), ajouter :
```swift
.sheet(isPresented: $showConsent) {
    ConsentSheet(
        onAccept: { consent.grant(); showConsent = false },
        onRefuse: { consent.deny();  showConsent = false }
    )
}
.onAppear {
    guard consent.shouldPromptConsent else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        if consent.shouldPromptConsent { showConsent = true }
    }
}
```

- [ ] **Step 3: Compiler** — commande Global Constraints, attendu `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Vérification runtime (manuelle)**

Lancer l'app au simulateur (premier lancement / app fraîchement réinstallée). Attendu : la sheet **n'apparaît pas immédiatement** sur écran blanc, mais ~0,4 s après que l'onboarding est visible. « Accepter » et « Refuser » la ferment et ne la refont plus réapparaître au relancement.

- [ ] **Step 5: Commit**

```bash
git add SOLA/Services/Analytics/ConsentSheet.swift SOLA/SOLAApp.swift
git commit -m "feat(analytics): bottom sheet de consentement différée après chargement"
```

---

### Task 7: Instrumenter le funnel onboarding

**Files:**
- Modify: `SOLA/Onboarding/OnboardingContainer.swift` (events `onboarding_started`, `onboarding_step_viewed`)
- Modify: `SOLA/SOLAApp.swift` (`AppFlow.finishOnboarding()` → `onboarding_completed`)

**Interfaces:**
- Consumes: `Analytics`, `AppEvent` (Task 2)

- [ ] **Step 1: `onboarding_started` + `onboarding_step_viewed`**

Dans `OnboardingContainer.body`, sur le `ForEach(0..<29…)` qui affiche `screen(for: i)`, ajouter un `.onAppear` qui envoie l'event de l'écran courant. Concrètement, sur la branche `if i == ctrl.index { screen(for: i)…`, ajouter après les modifiers existants :

```swift
.onAppear {
    if i == 0 { Analytics.capture(.onboardingStarted) }
    Analytics.capture(.onboardingStepViewed(step: i, name: "onb_\(i)"))
}
```

- [ ] **Step 2: `onboarding_completed`**

Dans `AppFlow.finishOnboarding()` (`SOLAApp.swift`), première ligne du corps :

```swift
func finishOnboarding() {
    Analytics.capture(.onboardingCompleted)
    store.finalizeOnboarding()
    withAnimation(.easeInOut(duration: 0.35)) { stage = .main }
}
```

- [ ] **Step 3: Compiler** — commande Global Constraints, attendu `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add SOLA/Onboarding/OnboardingContainer.swift SOLA/SOLAApp.swift
git commit -m "feat(analytics): instrumente le funnel onboarding (started/step/completed)"
```

---

### Task 8: Instrumenter les events d'achat + paywall

**Files:**
- Modify: `SOLA/Services/PurchaseManager.swift` (`purchase_started/completed/failed`, `purchase_restored`)
- Modify: `SOLA/Main/PaywallSheet.swift` (`paywall_viewed`, `paywall_plan_selected`)
- Modify: `SOLA/Main/PaywallExitOfferFlow.swift` (`exit_offer_shown/accepted`)

**Interfaces:**
- Consumes: `Analytics`, `AppEvent` (Task 2), `Experiments.variant(.paywallLayout)` (Task 4)

- [ ] **Step 1: Events d'achat dans `PurchaseManager.purchase(_ package:)`**

Dans `func purchase(_ package: Package) async -> Bool`, au début (après `purchasing = true`) :
```swift
let planID = package.storeProduct.productIdentifier
Analytics.capture(.purchaseStarted(plan: planID))
```
Dans le bloc succès (quand `isSubscribed` devient vrai) :
```swift
Analytics.capture(.purchaseCompleted(plan: planID, price: package.storeProduct.localizedPriceString))
```
Dans le `catch` (et le cas `!isSubscribed`) :
```swift
Analytics.capture(.purchaseFailed(reason: error.localizedDescription))   // dans le catch
```
Dans `restorePurchases()`, sur succès (`isSubscribed == true`) :
```swift
Analytics.capture(.purchaseRestored)
```

- [ ] **Step 2: Events paywall dans `PaywallSheet`**

Repérer la vue racine de `PaywallSheet` (son `body`). Sur son conteneur, ajouter :
```swift
.onAppear {
    Analytics.capture(.paywallViewed(source: "main", variant: Experiments.variant(.paywallLayout)))
}
```
Sur l'action de sélection d'un plan (le tap qui choisit mensuel/annuel), ajouter avant l'achat :
```swift
Analytics.capture(.paywallPlanSelected(plan: selectedProductID))
```
> `selectedProductID` = l'identifiant du produit choisi dans la vue ; si la sélection passe directement à `purchase(_:)`, capter avec l'ID passé à l'achat.

- [ ] **Step 3: Events roulette dans `PaywallExitOfferFlow`**

Sur l'apparition de la roulette/offre de sortie :
```swift
.onAppear { Analytics.capture(.exitOfferShown) }
```
Sur l'acceptation de l'offre (avant/au moment de lancer l'achat promo) :
```swift
Analytics.capture(.exitOfferAccepted)
```

- [ ] **Step 4: Compiler** — commande Global Constraints, attendu `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add SOLA/Services/PurchaseManager.swift SOLA/Main/PaywallSheet.swift SOLA/Main/PaywallExitOfferFlow.swift
git commit -m "feat(analytics): instrumente paywall, achats et offre de sortie"
```

---

### Task 9: Vérification end-to-end (dashboard PostHog)

**Files:** aucun (vérification)

**Pré-requis :** la vraie clé `phc_…` doit être renseignée dans `AnalyticsConfig.swift` (sinon l'init est sautée et rien ne part). Si l'utilisateur ne l'a pas fournie, **s'arrêter et la demander**.

- [ ] **Step 1: Renseigner la clé** dans `SOLA/Services/Analytics/AnalyticsConfig.swift`, puis build + run au simulateur.

- [ ] **Step 2: Parcours nominal** — accepter le consentement → faire l'onboarding → atteindre le paywall.

- [ ] **Step 3: Vérifier dans PostHog (Activity / Live events)** que `consent_granted`, `app_opened`, `onboarding_started`, plusieurs `onboarding_step_viewed`, `onboarding_completed`, `paywall_viewed` (avec `variant: "control"`) arrivent.

- [ ] **Step 4: Vérifier le refus** — réinstaller l'app, **refuser** le consentement, refaire l'onboarding. Attendu : **aucun** event dans PostHog.

- [ ] **Step 5: Vérifier le fallback flag** — sans créer de flag côté PostHog, `Experiments.variant(.paywallLayout)` doit rendre `"control"` (visible dans la propriété `variant` de `paywall_viewed`).

- [ ] **Step 6: Commit (clé)**

```bash
git add SOLA/Services/Analytics/AnalyticsConfig.swift
git commit -m "chore(analytics): clé PostHog de production"
```

---

## Self-Review (couverture du spec)

- ✅ Architecture 3 services + couture protocole → Tasks 2/3/4.
- ✅ Package SPM + init opt-out par défaut → Tasks 1/5.
- ✅ Consentement opt-in différé après chargement → Tasks 3/6.
- ✅ Taxonomie d'events (onboarding, paywall, achats, exit offer) → Tasks 7/8.
- ✅ Helper feature flags + fallback control → Task 4.
- ✅ Stratégie de vérification (compile + mock + dashboard, pas de XCTest) → Tasks 2b/9.
- ✅ Confidentialité (URL politique, mention PostHog) → Task 6 (note URL à remplacer).
- ⏳ Dépendance externe : clé `phc_…` (Task 1 placeholder, Task 9 réelle) et URL politique de confidentialité — à fournir par l'utilisateur.
