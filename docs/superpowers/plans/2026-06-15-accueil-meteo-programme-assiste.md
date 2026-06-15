# Refonte Accueil + Météo + Programme assisté — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter une vraie météo (jour + 7 jours) sur l'accueil et transformer le Programme en séance guidée assistée, en réutilisant l'infra existante.

**Architecture:** Trois chantiers livrables indépendamment, ordre 2 → 1 → 3. (2) étend `UVService`/`UVForecast` avec la vraie météo Open-Meteo. (1) ajoute un bloc météo à l'accueil et transforme le bouton « Lancer ma séance » en raccourci vers le Programme. (3) câble la checklist du Programme au `ExposureTimerView` existant, ajoute un bandeau contextuel et programme les rappels au démarrage.

**Tech Stack:** Swift / SwiftUI, Xcode 26.2, Open-Meteo (gratuit, sans clé), Combine.

---

## Notes de vérification (lire avant de commencer)

**Ce projet n'a AUCUN test target XCTest** (cibles : `SOLA` app + `SunyWidget`). On ne crée pas de test target (édition `project.pbxproj` à la main = risqué, hors périmètre). Deux moyens de vérification :

1. **Gate de compilation (obligatoire à chaque task qui touche du code app)** :
   ```bash
   xcodebuild -project SOLA.xcodeproj -scheme SOLA \
     -destination 'platform=iOS Simulator,name=iPhone 17' build
   ```
   Attendu : `** BUILD SUCCEEDED **`.

2. **Vérif logique pure (TDD via `swift` autonome)** : pour les unités de logique pure (mapping
   weathercode, message contextuel), on écrit un fichier `/tmp/*.swift` autonome avec la logique +
   des `assert`, exécuté par `swift /tmp/x.swift`. Le fichier est jetable ; le code de prod est
   ensuite collé dans le vrai fichier app. Cela donne un vrai cycle rouge→vert sans test target.

3. **Vérif visuelle (manuelle, pour les tasks UI)** : booter un simulateur, installer, lancer en
   ciblant l'écran via la variable lue par `MainAppView.applyDebugScreen` (`SOLA_SCREEN`) :
   ```bash
   xcrun simctl boot "iPhone 17" 2>/dev/null || true
   xcodebuild -project SOLA.xcodeproj -scheme SOLA \
     -destination 'platform=iOS Simulator,name=iPhone 17' \
     -derivedDataPath /tmp/sola-dd build
   xcrun simctl install booted /tmp/sola-dd/Build/Products/Debug-iphonesimulator/SOLA.app
   SIMCTL_CHILD_SOLA_SCREEN=plan xcrun simctl launch booted com.meflabs.SOLA   # ou =home
   xcrun simctl io booted screenshot /tmp/sola-screen.png
   ```
   `SOLA_SCREEN` accepté : `home`, `plan`, `plan-soir`, `uv`, `reco`, `analysis`, `journal`, `profile`.

Commits fréquents. Branche de travail : `feat/accueil-meteo-programme-assiste` (déjà créée).

---

# CHANTIER 2 — Vraie météo dans `UVService`

But : remplacer le `weatherLabel` dérivé de l'UV par une vraie condition météo Open-Meteo, et
enrichir la prévision 7 jours (condition + temp min/max).

## Task 2.1 : Type `WeatherCondition` (logique pure, TDD autonome)

**Files:**
- Create: `SOLA/Services/WeatherCondition.swift`

- [ ] **Step 1 : Écrire le test autonome qui échoue**

Créer `/tmp/wmo_check.swift` :

```swift
import Foundation

enum WeatherCondition: String {
    case clear, partlyCloudy, cloudy, fog, rain, showers, thunderstorm, snow

    init(weatherCode code: Int) {
        switch code {
        case 0:                          self = .clear
        case 1, 2:                       self = .partlyCloudy
        case 3:                          self = .cloudy
        case 45, 48:                     self = .fog
        case 51...57, 61...67:           self = .rain
        case 80...82:                    self = .showers
        case 71...77, 85, 86:            self = .snow
        case 95, 96, 99:                 self = .thunderstorm
        default:                         self = .partlyCloudy
        }
    }

    var label: String {
        switch self {
        case .clear:        return "Ensoleillé"
        case .partlyCloudy: return "Partiellement nuageux"
        case .cloudy:       return "Nuageux"
        case .fog:          return "Brouillard"
        case .rain:         return "Pluie"
        case .showers:      return "Averses"
        case .thunderstorm: return "Orage"
        case .snow:         return "Neige"
        }
    }

    /// True quand l'ensoleillement permet un vrai bronzage (pas couvert/pluie).
    var isSunny: Bool { self == .clear || self == .partlyCloudy }
}

assert(WeatherCondition(weatherCode: 0) == .clear)
assert(WeatherCondition(weatherCode: 2) == .partlyCloudy)
assert(WeatherCondition(weatherCode: 3) == .cloudy)
assert(WeatherCondition(weatherCode: 48) == .fog)
assert(WeatherCondition(weatherCode: 63) == .rain)
assert(WeatherCondition(weatherCode: 81) == .showers)
assert(WeatherCondition(weatherCode: 75) == .snow)
assert(WeatherCondition(weatherCode: 95) == .thunderstorm)
assert(WeatherCondition(weatherCode: 1234) == .partlyCloudy)  // défaut
assert(WeatherCondition.clear.isSunny == true)
assert(WeatherCondition.rain.isSunny == false)
assert(WeatherCondition.clear.label == "Ensoleillé")
print("OK WeatherCondition")
```

- [ ] **Step 2 : Lancer le test, vérifier qu'il passe (logique correcte avant intégration)**

Run : `swift /tmp/wmo_check.swift`
Attendu : `OK WeatherCondition` (aucune assertion échouée). Si une assertion casse, corriger le
mapping AVANT de continuer.

- [ ] **Step 3 : Créer le fichier de prod**

Créer `SOLA/Services/WeatherCondition.swift` avec exactement le contenu du `enum WeatherCondition`
ci-dessus (sans les `assert`/`print`), précédé de `import Foundation`. Ajouter en plus la propriété
d'icône (SF Symbols, dispo sans asset) :

```swift
extension WeatherCondition {
    /// SF Symbol (remplissage) représentant la condition.
    var sfSymbol: String {
        switch self {
        case .clear:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy:       return "cloud.fill"
        case .fog:          return "cloud.fog.fill"
        case .rain:         return "cloud.rain.fill"
        case .showers:      return "cloud.heavyrain.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .snow:         return "snowflake"
        }
    }
}
```

- [ ] **Step 4 : Ajouter le fichier à la cible SOLA et compiler**

Le fichier doit être référencé par la cible `SOLA` dans `SOLA.xcodeproj/project.pbxproj`. Si tu
utilises Xcode, ajoute-le au groupe `Services` (cible SOLA cochée). En CLI, ouvrir le projet et
glisser le fichier, ou ajouter manuellement les 3 entrées pbxproj (PBXFileReference,
PBXBuildFile, membership du PBXSourcesBuildPhase de SOLA). Puis :

Run :
```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Attendu : `** BUILD SUCCEEDED **`.

- [ ] **Step 5 : Commit**

```bash
git add SOLA/Services/WeatherCondition.swift SOLA.xcodeproj/project.pbxproj
git commit -m "feat(meteo): type WeatherCondition (mapping WMO Open-Meteo)"
```

## Task 2.2 : Étendre `DailyUV` et `UVForecast` avec les champs météo

**Files:**
- Modify: `SOLA/Services/UVService.swift:38-42` (struct `DailyUV`)
- Modify: `SOLA/Services/UVService.swift:44-70` (struct `UVForecast` + `.sample` + `==`)

- [ ] **Step 1 : Étendre `DailyUV`**

Remplacer la struct `DailyUV` (lignes 38-42) par :

```swift
struct DailyUV: Equatable {
    let dayLabel: String        // ex. "Lun"
    let uvMax: Double
    let sunny: Bool             // conservé pour compat widget
    let condition: WeatherCondition
    let tempMax: Double
    let tempMin: Double
}
```

- [ ] **Step 2 : Étendre `UVForecast` (champ `condition`)**

Dans `struct UVForecast` (après `var weatherLabel: String`, ligne 51), ajouter :

```swift
    var condition: WeatherCondition = .clear
```

Et remplacer l'init de `.sample` (lignes 65-69) par une version qui fournit les nouveaux champs
`DailyUV` (le `daily` de sample est vide aujourd'hui, donc rien à changer côté daily) et ajoute la
condition :

```swift
    static let sample = UVForecast(
        current: 8, maxToday: 8, temperature: 28,
        hourly: [("8h",2),("9h",3.8),("10h",5.8),("11h",8.2),("12h",10),
                 ("13h",9.6),("14h",7.4),("15h",5.2),("16h",3.4)].map { ($0.0, $0.1) },
        peakHourIndex: 4, idealWindow: "16h00 – 17h30", weatherLabel: "Ensoleillé",
        condition: .clear)
```

- [ ] **Step 3 : Mettre à jour `==`**

Dans `static func == ` (lignes 58-62), ajouter la comparaison de condition. Remplacer le corps par :

```swift
        lhs.current == rhs.current && lhs.maxToday == rhs.maxToday &&
        lhs.temperature == rhs.temperature && lhs.condition == rhs.condition &&
        lhs.hourly.map(\.uv) == rhs.hourly.map(\.uv) &&
        lhs.daily == rhs.daily
```

- [ ] **Step 4 : Compiler (échoue attendu — `buildDaily` et `parse` pas encore à jour)**

Run :
```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Attendu : ÉCHEC de compilation sur `DailyUV(...)` dans `buildDaily` (arguments manquants) et sur
`weatherLabel:` (ok) — c'est normal, corrigé en Task 2.3. Ne pas committer un état cassé : enchaîner
directement sur Task 2.3 avant de committer.

## Task 2.3 : Étendre le parsing Open-Meteo (weather_code + temp min/max)

**Files:**
- Modify: `SOLA/Services/UVService.swift:76-83` (queryItems)
- Modify: `SOLA/Services/UVService.swift:93-98` (struct `Response`)
- Modify: `SOLA/Services/UVService.swift:101-181` (parse + buildDaily)

- [ ] **Step 1 : Ajouter les champs à la requête**

Dans `fetch`, remplacer les deux lignes `hourly` et `daily` des `queryItems` (lignes 79-80) par :

```swift
            .init(name: "hourly", value: "uv_index,temperature_2m,weather_code"),
            .init(name: "daily", value: "uv_index_max,weather_code,temperature_2m_max,temperature_2m_min"),
```

- [ ] **Step 2 : Étendre `Response`**

Remplacer la struct `Response` (lignes 93-98) par :

```swift
    private struct Response: Decodable {
        struct Hourly: Decodable {
            let time: [String]; let uv_index: [Double]
            let temperature_2m: [Double]; let weather_code: [Int]
        }
        struct Daily: Decodable {
            let time: [String]; let uv_index_max: [Double]
            let weather_code: [Int]
            let temperature_2m_max: [Double]; let temperature_2m_min: [Double]
        }
        let hourly: Hourly
        let daily: Daily
    }
```

- [ ] **Step 3 : Calculer la condition courante dans `parse`**

Dans `parse`, après la boucle qui calcule `currentUV`/`currentTemp` (après ligne 130), ajouter le
calcul de la condition courante à l'index de l'heure courante :

```swift
        // Condition météo courante : weather_code à l'index de l'heure courante.
        let codes = r.hourly.weather_code
        var currentCode = codes.first ?? 0
        for i in 0..<todayCount where hour(from: times[i]) == nowHour {
            currentCode = codes[i]
        }
        let currentCondition = WeatherCondition(weatherCode: currentCode)
```

- [ ] **Step 4 : Passer condition + daily enrichi à l'appel `buildDaily` et au retour**

Remplacer l'appel `let daily = buildDaily(...)` (ligne 137) par :

```swift
        let daily = buildDaily(times: r.daily.time, maxima: r.daily.uv_index_max,
                               codes: r.daily.weather_code,
                               tmax: r.daily.temperature_2m_max,
                               tmin: r.daily.temperature_2m_min)
```

Dans le `return UVForecast(...)` (lignes 147-157), remplacer la ligne
`weatherLabel: weatherLabel(uv: currentUV, temp: currentTemp),` par :

```swift
            weatherLabel: currentCondition.label,
            condition: currentCondition,
```

(Garder les autres lignes du init telles quelles. La fonction `weatherLabel(uv:temp:)` lignes
214-220 devient inutilisée — la supprimer pour éviter le warning.)

- [ ] **Step 5 : Mettre à jour `buildDaily`**

Remplacer la signature et le corps de `buildDaily` (lignes 161-181) par :

```swift
    private static func buildDaily(times: [String], maxima: [Double],
                                   codes: [Int], tmax: [Double], tmin: [Double]) -> [DailyUV] {
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM-dd"
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        let dayFmt = DateFormatter()
        dayFmt.locale = Locale(identifier: "fr_FR")
        dayFmt.dateFormat = "EEE"

        var result: [DailyUV] = []
        for (i, t) in times.enumerated() where i < maxima.count {
            let uvMax = max(0, maxima[i])
            let label: String
            if let d = inFmt.date(from: t) {
                label = dayFmt.string(from: d).capitalized.replacingOccurrences(of: ".", with: "")
            } else {
                label = "J\(i)"
            }
            let cond = WeatherCondition(weatherCode: i < codes.count ? codes[i] : 0)
            result.append(DailyUV(
                dayLabel: label,
                uvMax: (uvMax * 10).rounded() / 10,
                sunny: cond.isSunny,
                condition: cond,
                tempMax: (i < tmax.count ? tmax[i] : 0).rounded(),
                tempMin: (i < tmin.count ? tmin[i] : 0).rounded()))
        }
        return Array(result.prefix(7))
    }
```

- [ ] **Step 6 : Compiler**

Run :
```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Attendu : `** BUILD SUCCEEDED **`. Si `WidgetBridge.publish` ou un autre consommateur de `DailyUV`
casse, voir Task 2.4.

- [ ] **Step 7 : Commit**

```bash
git add SOLA/Services/UVService.swift
git commit -m "feat(meteo): vraie condition Open-Meteo + temp min/max sur 7 jours"
```

## Task 2.4 : Réparer les consommateurs de `DailyUV` (widget)

**Files:**
- Modify : tout fichier qui construit un `DailyUV(...)` hors `UVService` (probable : `WidgetBridge.swift`)

- [ ] **Step 1 : Trouver les usages**

Run : `grep -rn "DailyUV(" SOLA --include="*.swift"`
Attendu : lister les sites de construction. Le seul légitime restant doit être `buildDaily`.

- [ ] **Step 2 : Corriger chaque site**

Pour chaque `DailyUV(...)` qui ne compile plus (ex. dans `WidgetBridge` ou un décodage App Group),
fournir les nouveaux champs `condition`, `tempMax`, `tempMin`. Si le widget sérialise `DailyUV` dans
l'App Group, ajouter les champs au modèle encodé/décodé côté widget de façon cohérente. Si le widget
n'a pas besoin de la météo, mapper `condition` depuis `sunny` (`sunny ? .clear : .cloudy`) et
`tempMax/tempMin` à `0` au décodage legacy.

- [ ] **Step 3 : Compiler app + extension**

Run :
```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Attendu : `** BUILD SUCCEEDED **` (app ET SunyWidget compilent).

- [ ] **Step 4 : Commit**

```bash
git add -A
git commit -m "fix(meteo): adapter les consommateurs de DailyUV aux nouveaux champs"
```

---

# CHANTIER 1 — Accueil = tableau de bord

But : ajouter un bloc météo (jour + 7 jours) et transformer « Lancer ma séance » en raccourci vers
le Programme.

## Task 1.1 : Trigger de séance partagé sur `TabRouter`

**Files:**
- Modify: `SOLA/Main/Redesign.swift:10-13` (`TabRouter`)

- [ ] **Step 1 : Ajouter le flag de démarrage de séance**

Remplacer la classe `TabRouter` (lignes 10-13) par :

```swift
@MainActor
final class TabRouter: ObservableObject {
    @Published var selection: Int = 0
    /// Mis à `true` pour demander le démarrage de la séance guidée dans le Programme.
    /// L'accueil le déclenche (raccourci) ; le Programme le consomme puis le remet à `false`.
    @Published var requestSessionStart: Bool = false
}
```

- [ ] **Step 2 : Compiler**

Run :
```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Attendu : `** BUILD SUCCEEDED **`.

- [ ] **Step 3 : Commit**

```bash
git add SOLA/Main/Redesign.swift
git commit -m "feat(programme): trigger de séance partagé sur TabRouter"
```

## Task 1.2 : « Lancer ma séance » → raccourci vers le Programme

**Files:**
- Modify: `SOLA/Main/Main1.swift:41` (state `showSession`)
- Modify: `SOLA/Main/Main1.swift:112-124` (bouton)
- Modify: `SOLA/Main/Main1.swift:218-220` (`.fullScreenCover`)

- [ ] **Step 1 : Remplacer l'action du bouton**

Remplacer le bloc bouton (lignes 113-124) par une action qui bascule sur le Programme et demande le
démarrage de la séance :

```swift
                    Button {
                        HapticsManager.shared.select()
                        tab.requestSessionStart = true
                        tab.selection = 1
                    } label: {
                        HStack(spacing: 10) {
                            Icon(name: "sun", size: 20).foregroundStyle(Palette.onAmber)
                            Text("Lancer ma séance").font(SolaFont.body(17, weight: .bold)).foregroundStyle(Palette.onAmber)
                        }
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(Capsule().fill(Palette.amber))
                        .shadowSoft()
                    }
                    .buttonStyle(.plain)
                    .pressAnimation()
                    .padding(.top, 14)
```

- [ ] **Step 2 : Supprimer le `.fullScreenCover` et son state**

Supprimer la ligne 41 `@State private var showSession = false`.
Supprimer le modificateur `.fullScreenCover(isPresented: $showSession) { ExposureTimerView(...) }`
(lignes 218-220).

- [ ] **Step 3 : Compiler**

Run :
```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Attendu : `** BUILD SUCCEEDED **` (le bouton n'a plus de référence à `showSession`/`ExposureTimerView`).

- [ ] **Step 4 : Commit**

```bash
git add SOLA/Main/Main1.swift
git commit -m "feat(accueil): bouton séance devient raccourci vers le Programme guidé"
```

## Task 1.3 : Composant `WeatherBlock`

**Files:**
- Create: `SOLA/Main/WeatherBlock.swift`

- [ ] **Step 1 : Créer le composant**

Créer `SOLA/Main/WeatherBlock.swift`. Il reçoit le `UVForecast` et affiche aujourd'hui + la bande
7 jours. Réutilise `CardBox`, `Palette`, `SolaFont`. Icône = `Image(systemName: condition.sfSymbol)`.

```swift
import SwiftUI

// Bloc météo de l'accueil : condition + température du jour, puis bande 7 jours
// (condition réelle Open-Meteo + temp max + UV max). Données : ForecastStore.
struct WeatherBlock: View {
    let forecast: UVForecast

    var body: some View {
        CardBox(padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                // Aujourd'hui
                HStack(spacing: 12) {
                    Image(systemName: forecast.condition.sfSymbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Palette.amberDeep)
                        .frame(width: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(forecast.temperature))° · \(forecast.condition.label)")
                            .font(SolaFont.body(15.5, weight: .bold)).foregroundStyle(Palette.ink)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Text("UV \(forecast.current.formatted(.number.precision(.fractionLength(0...1)))) · max \(forecast.maxToday.formatted(.number.precision(.fractionLength(0...1))))")
                            .font(SolaFont.body(12.5)).foregroundStyle(Palette.ink3)
                    }
                    Spacer(minLength: 0)
                }

                if !forecast.daily.isEmpty {
                    Divider().background(Palette.lineSoft)
                    // Cette semaine
                    HStack(spacing: 0) {
                        ForEach(Array(forecast.daily.prefix(7).enumerated()), id: \.offset) { _, d in
                            VStack(spacing: 5) {
                                Text(d.dayLabel)
                                    .font(SolaFont.body(11, weight: .semibold)).foregroundStyle(Palette.ink3)
                                Image(systemName: d.condition.sfSymbol)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Palette.amberDeep)
                                Text("\(Int(d.tempMax))°")
                                    .font(SolaFont.body(12, weight: .bold)).foregroundStyle(Palette.ink)
                                Text("UV\(Int(d.uvMax.rounded()))")
                                    .font(SolaFont.mono(10)).foregroundStyle(Palette.ink3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2 : Ajouter le fichier à la cible SOLA et compiler**

Ajouter `WeatherBlock.swift` à la cible `SOLA` (groupe `Main`). Vérifier que `CardBox`,
`Palette.amberDeep`, `Palette.lineSoft`, `SolaFont.mono` existent (ils sont utilisés ailleurs dans
`Main1.swift`/design system — ok). Puis :

Run :
```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Attendu : `** BUILD SUCCEEDED **`.

- [ ] **Step 3 : Commit**

```bash
git add SOLA/Main/WeatherBlock.swift SOLA.xcodeproj/project.pbxproj
git commit -m "feat(accueil): composant WeatherBlock (jour + 7 jours)"
```

## Task 1.4 : Insérer `WeatherBlock` dans l'accueil

**Files:**
- Modify: `SOLA/Main/Main1.swift:158-159` (entre le bento et la carte Semaine)

- [ ] **Step 1 : Insérer le composant**

Juste après le bloc bento `HStack { ... }.padding(.top, 12)` (qui se termine ligne 158, avant la
carte « Avancement du programme » ligne 160), insérer :

```swift
                    WeatherBlock(forecast: forecast)
                        .padding(.top, 12)
```

- [ ] **Step 2 : Compiler**

Run :
```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Attendu : `** BUILD SUCCEEDED **`.

- [ ] **Step 3 : Vérif visuelle de l'accueil**

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/sola-dd build
xcrun simctl install booted /tmp/sola-dd/Build/Products/Debug-iphonesimulator/SOLA.app
SIMCTL_CHILD_SOLA_SCREEN=home xcrun simctl launch booted com.meflabs.SOLA
xcrun simctl io booted screenshot /tmp/home.png
```
Attendu : l'accueil affiche le bloc météo (condition + temp du jour + bande 7 jours) entre le bento
et la carte Semaine. Ouvrir `/tmp/home.png` pour vérifier visuellement.

- [ ] **Step 4 : Commit**

```bash
git add SOLA/Main/Main1.swift
git commit -m "feat(accueil): afficher WeatherBlock entre le bento et la carte Semaine"
```

---

# CHANTIER 3 — Programme « vraiment assisté »

But : démarrer la séance guidée depuis le Programme (et via le raccourci accueil), afficher un
bandeau contextuel, programmer les rappels au démarrage.

## Task 3.1 : Guidance contextuelle (logique pure, TDD autonome)

**Files:**
- Create: `SOLA/Core/ProgramGuidance.swift`

- [ ] **Step 1 : Écrire le test autonome qui échoue**

Créer `/tmp/guidance_check.swift` (inclut une copie minimale de `WeatherCondition` pour l'isolation) :

```swift
import Foundation

enum WeatherCondition { case clear, partlyCloudy, cloudy, fog, rain, showers, thunderstorm, snow
    var isSunny: Bool { self == .clear || self == .partlyCloudy } }

enum ProgramGuidance {
    // Conseil contextuel pour le Programme, dérivé d'UV + heure + météo.
    static func message(uv: Double, hour: Int, condition: WeatherCondition,
                        idealWindow: String) -> String {
        if condition == .rain || condition == .showers || condition == .thunderstorm {
            return "Pluie attendue — privilégie un autre moment ou la routine du soir."
        }
        if uv < 3 {
            return "UV faible (\(Int(uv.rounded()))) — attends ton créneau idéal \(idealWindow)."
        }
        if uv >= 8 {
            return "UV au pic — séance courte et crème impérative."
        }
        if hour >= 19 {
            return "Le soleil baisse — pense à ta routine du soir."
        }
        return "Bonnes conditions — c'est le moment de bronzer malin."
    }
}

assert(ProgramGuidance.message(uv: 8, hour: 13, condition: .rain, idealWindow: "16h").contains("Pluie"))
assert(ProgramGuidance.message(uv: 2, hour: 10, condition: .clear, idealWindow: "16h00 – 17h30").contains("16h00 – 17h30"))
assert(ProgramGuidance.message(uv: 9, hour: 13, condition: .clear, idealWindow: "16h").contains("pic"))
assert(ProgramGuidance.message(uv: 5, hour: 20, condition: .clear, idealWindow: "16h").contains("soir"))
assert(ProgramGuidance.message(uv: 5, hour: 13, condition: .partlyCloudy, idealWindow: "16h").contains("bronzer"))
print("OK ProgramGuidance")
```

- [ ] **Step 2 : Lancer le test, vérifier qu'il passe**

Run : `swift /tmp/guidance_check.swift`
Attendu : `OK ProgramGuidance`.

- [ ] **Step 3 : Créer le fichier de prod**

Créer `SOLA/Core/ProgramGuidance.swift` avec `import Foundation` + l'`enum ProgramGuidance` ci-dessus
(sans les asserts ; `WeatherCondition` est déjà défini en Task 2.1, ne pas le redéclarer).

- [ ] **Step 4 : Ajouter à la cible SOLA et compiler**

Ajouter le fichier à la cible `SOLA` (groupe `Core`). Run :
```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Attendu : `** BUILD SUCCEEDED **`.

- [ ] **Step 5 : Commit**

```bash
git add SOLA/Core/ProgramGuidance.swift SOLA.xcodeproj/project.pbxproj
git commit -m "feat(programme): ProgramGuidance (conseil contextuel UV/heure/météo)"
```

## Task 3.2 : Bandeau contextuel en tête du Programme

**Files:**
- Modify: `SOLA/Main/Main1.swift:570` (juste avant la carte phase `SunHero`)

- [ ] **Step 1 : Insérer le bandeau**

Dans `AppPlan.body`, juste avant `// Phase + parcours en 3 étapes` / `SunHero(motif: ClayIMG.leaf)`
(ligne 570), insérer une `CoachCard` alimentée par `ProgramGuidance` :

```swift
                CoachCard(message: ProgramGuidance.message(
                    uv: forecast.current,
                    hour: Calendar.current.component(.hour, from: .now),
                    condition: forecast.condition,
                    idealWindow: forecast.idealWindow))
                    .padding(.top, 14)
```

(Vérifier la signature de `CoachCard` : dans `AppHome` elle est appelée avec `message:` — même
usage ici. Si `CoachCard` exige d'autres paramètres, les fournir à l'identique de l'appel accueil
`Main1.swift:185`.)

- [ ] **Step 2 : Compiler**

Run :
```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Attendu : `** BUILD SUCCEEDED **`.

- [ ] **Step 3 : Commit**

```bash
git add SOLA/Main/Main1.swift
git commit -m "feat(programme): bandeau contextuel ProgramGuidance en tête de l'onglet"
```

## Task 3.3 : Démarrer la séance guidée depuis le Programme

**Files:**
- Modify: `SOLA/Main/Main1.swift:468-484` (state + env de `AppPlan`)
- Modify: `SOLA/Main/Main1.swift` (corps de `AppPlan`, ajout d'un bouton + `.fullScreenCover` + consommation du trigger)

- [ ] **Step 1 : Ajouter env `tab` et state de séance à `AppPlan`**

Dans `AppPlan`, après `@EnvironmentObject var forecastStore: ForecastStore` (ligne 470), ajouter :

```swift
    @EnvironmentObject var tab: TabRouter
    @State private var showSession = false
```

- [ ] **Step 2 : Ajouter un bouton « Lancer ma séance » dans la routine du jour**

Dans la branche `if store.data.programStarted {` (vers ligne 595), juste avant le `HStack` du titre
« Ta routine du jour » (ligne 596), ajouter un bouton visible uniquement en mode Jour :

```swift
                    if !evening {
                        Button {
                            HapticsManager.shared.select()
                            showSession = true
                        } label: {
                            HStack(spacing: 10) {
                                Icon(name: "sun", size: 19).foregroundStyle(Palette.onAmber)
                                Text("Lancer ma séance").font(SolaFont.body(16, weight: .bold)).foregroundStyle(Palette.onAmber)
                            }
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(Capsule().fill(Palette.amber))
                            .shadowSoft()
                        }
                        .buttonStyle(.plain)
                        .pressAnimation()
                        .padding(.top, 16)
                    }
```

- [ ] **Step 3 : Présenter `ExposureTimerView` + consommer le trigger accueil**

Sur le `ScreenScaffold` de `AppPlan` (au niveau des autres modificateurs, après
`.navigationBarBackButtonHidden(true)` ligne 653), ajouter :

```swift
        .fullScreenCover(isPresented: $showSession) {
            ExposureTimerView(safeMinutes: safeMin, uv: forecast.current)
        }
        .onChange(of: tab.requestSessionStart) { _, requested in
            guard requested else { return }
            // Démarrage demandé depuis l'accueil : ouvre la séance en mode Jour.
            evening = false
            if !store.data.programStarted { store.data.programStarted = true }
            showSession = true
            tab.requestSessionStart = false
        }
        .onAppear {
            // Cas où le Programme s'affiche après que le flag a été posé.
            if tab.requestSessionStart {
                evening = false
                if !store.data.programStarted { store.data.programStarted = true }
                showSession = true
                tab.requestSessionStart = false
            }
        }
```

- [ ] **Step 4 : Marquer l'étape « Bronze » faite au retour de séance**

Pour que la séance guidée fasse progresser la checklist, à la fermeture du timer on coche l'étape
« Bronze X min » (index `base + 1` en mode Jour, soit step 11). Modifier le `.fullScreenCover`
ci-dessus pour utiliser `onDismiss` :

```swift
        .fullScreenCover(isPresented: $showSession, onDismiss: {
            // Au retour de la séance : marquer l'étape « Bronze » comme faite (mode Jour).
            if !evening, !store.isRoutineDone(10 + 1) {
                store.toggleRoutine(10 + 1)
            }
        }) {
            ExposureTimerView(safeMinutes: safeMin, uv: forecast.current)
        }
```

(Supprimer le `.fullScreenCover` simple ajouté au Step 3 et le remplacer par celui-ci ; ne garder
qu'un seul `.fullScreenCover`. `10` = `base` du plan Jour, `+1` = étape « Bronze ».)

- [ ] **Step 5 : Compiler**

Run :
```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Attendu : `** BUILD SUCCEEDED **`.

- [ ] **Step 6 : Vérif visuelle du flux**

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/sola-dd build
xcrun simctl install booted /tmp/sola-dd/Build/Products/Debug-iphonesimulator/SOLA.app
SIMCTL_CHILD_SOLA_SCREEN=home xcrun simctl launch booted com.meflabs.SOLA
xcrun simctl io booted screenshot /tmp/flow1-home.png
```
Attendu : depuis l'accueil, taper « Lancer ma séance » bascule sur l'onglet Programme et ouvre le
minuteur plein écran. (Vérifier manuellement dans le simulateur ; le screenshot capture l'état
courant.) Au retour du timer, l'étape « Bronze » de la routine du jour est cochée.

- [ ] **Step 7 : Commit**

```bash
git add SOLA/Main/Main1.swift
git commit -m "feat(programme): séance guidée lançable depuis Programme + raccourci accueil"
```

## Task 3.4 : Câbler les rappels au démarrage de la séance

**Files:**
- Modify: `SOLA/Main/Main2.swift` (fonction `startTimer()` de `ExposureTimerView`, autour de la ligne 88 où `startTimer()` est appelé)

- [ ] **Step 1 : Repérer `startTimer()`**

Run : `grep -n "func startTimer\|func logSession\|scheduleFlipAlert\|scheduleSPFReminder\|scheduleBurnAlert" SOLA/Main/Main2.swift`
Attendu : localiser `func startTimer()` dans `ExposureTimerView`. Lire son corps (il configure et
démarre `timer` et programme déjà certaines alertes — `scheduleBurnAlert`/`scheduleFlipAlert`).

- [ ] **Step 2 : Ajouter/compléter les rappels manquants**

Dans `startTimer()`, après le démarrage du timer, s'assurer que sont programmés (sans dupliquer ce
qui existe déjà) :

```swift
        let total = TimeInterval(safeMinutes * 60)
        notifications.scheduleFlipAlert(after: total / 2)          // « retourne-toi » à mi-temps
        notifications.scheduleSPFReminder(after: 120)              // remets ta crème dans 2h
        notifications.scheduleBurnAlert(after: total)              // fin de dose sûre
```

(Si `startTimer()` programme DÉJÀ `scheduleBurnAlert`/`scheduleFlipAlert`, ne pas les rajouter —
n'ajouter que ce qui manque, p. ex. le rappel SPF 2h. Vérifier d'abord au Step 1. `scheduleSPFReminder`
a deux surcharges : `scheduleSPFReminder(spf:)` et `scheduleSPFReminder(after:)` — utiliser
`after: 120`.)

- [ ] **Step 3 : Compiler**

Run :
```bash
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Attendu : `** BUILD SUCCEEDED **`.

- [ ] **Step 4 : Commit**

```bash
git add SOLA/Main/Main2.swift
git commit -m "feat(programme): programmer les rappels (flip, SPF 2h, brûlure) au démarrage de séance"
```

---

## Vérification finale (après les 3 chantiers)

- [ ] Build complet OK :
  ```bash
  xcodebuild -project SOLA.xcodeproj -scheme SOLA \
    -destination 'platform=iOS Simulator,name=iPhone 17' build
  ```
  Attendu : `** BUILD SUCCEEDED **` (app + widget).
- [ ] Accueil (`SOLA_SCREEN=home`) : bloc météo jour + 7 jours visible ; « Lancer ma séance » bascule
  sur Programme et ouvre le minuteur.
- [ ] Programme (`SOLA_SCREEN=plan`) : bandeau contextuel en tête ; bouton « Lancer ma séance » en
  mode Jour ; séance guidée (flip à mi-temps, Live Activity) ; étape « Bronze » cochée au retour.
- [ ] Aucune valeur météo codée en dur ne subsiste sur l'accueil (tout vient de `ForecastStore`).
- [ ] `git log --oneline` montre des commits atomiques par task.

## Hors périmètre (rappel)
Pas de test target XCTest, pas de backend météo tiers, pas de refonte du design system, pas de
prévision > 7 jours, pas de timer embarqué custom (réutilisation de `ExposureTimerView`).
