# SOLA — Extensions natives (Widget & Live Activity)

Ce document décrit l'installation des extensions natives ajoutées au projet :
le **widget UV** (WidgetKit) et, plus tard, la **Live Activity** (ActivityKit).

L'app est un projet **Xcode natif** (SwiftUI). Il n'y a pas de couche Expo/JS :
toutes les étapes se font dans Xcode.

---

## 1. Fichiers ajoutés

```
Shared/
  SharedUVData.swift        ← modèle + store App Group (MEMBRE DES 2 TARGETS)
  SunSessionAttributes.swift ← attributs Live Activity (MEMBRE DES 2 TARGETS)

SolaWidget/                 ← cible widget (à créer dans Xcode, voir §3)
  WidgetTheme.swift         ← couleurs/échelle UV recréées (cohérence de marque)
  UVProvider.swift          ← TimelineProvider lisant l'App Group
  UVWidgetViews.swift       ← vues small / medium / large / accessory
  SunSessionLiveActivity.swift ← UI Live Activity (lock screen + Dynamic Island)
  SolaWidgetBundle.swift    ← @main WidgetBundle (widget + Live Activity)

SOLA/Services/
  WidgetBridge.swift        ← l'app publie l'UV vers l'App Group (déjà câblé)
  LiveActivityManager.swift ← start/update/end de la Live Activity (déjà câblé)
```

L'app appelle déjà `WidgetBridge.publish(...)` à chaque rafraîchissement UV
(écrans Accueil et UV) et `LiveActivityManager` pendant une session de bronzage
(`ExposureTimerView`) : aucune action JS/SwiftUI supplémentaire requise.

---

## 2. App Group (partage app ⇄ widget)

Identifiant : **`group.com.meflabs.SOLA`** (aligné sur le bundle `com.meflabs.SOLA`).

À activer sur **les deux** targets (app `SOLA` + extension `SolaWidget`) :

1. Sélectionne le projet **SOLA** → target **SOLA** → onglet **Signing & Capabilities**.
2. **+ Capability** → **App Groups** → coche/ajoute `group.com.meflabs.SOLA`.
3. Répète pour le target **SolaWidget**.

> Si tu changes l'identifiant, mets-le à jour dans `Shared/SharedUVData.swift`
> (`SharedStore.appGroupID`).

---

## 3. Créer le target Widget Extension

1. **File ▸ New ▸ Target… ▸ Widget Extension**.
2. Nom : **`SolaWidget`**. Décoche « Include Configuration Intent » (widget statique).
   Coche **« Include Live Activity »** (Feature 3) — ou ajoute simplement nos
   fichiers, la `ActivityConfiguration` est gérée par `SolaWidgetBundle.swift`.
3. Xcode crée un dossier avec un fichier exemple : **supprime le `.swift` généré**
   (on utilise nos fichiers de `SolaWidget/`).
4. Ajoute nos fichiers au target :
   - Sélectionne les 5 fichiers de `SolaWidget/` + les 2 fichiers de `Shared/`.
   - Dans l'inspecteur de fichier (à droite) → **Target Membership** :
     - `SharedUVData.swift` et `SunSessionAttributes.swift` → cochés pour
       **SOLA** ET **SolaWidget**.
     - les fichiers `SolaWidget/*` → cochés pour **SolaWidget** uniquement.
5. Vérifie que `SOLA/Services/WidgetBridge.swift` et
   `SOLA/Services/LiveActivityManager.swift` sont membres du target **SOLA**.
6. Déploiement minimum du widget : **iOS 16** (les `#available` gèrent 16.1 pour
   ActivityKit et 17 pour `containerBackground`).

---

## 4. Build & run

```bash
# Ouvre le projet
open SOLA.xcodeproj

# Build app + extension depuis la ligne de commande (simulateur)
xcodebuild -project SOLA.xcodeproj -scheme SOLA \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

Dans Xcode : sélectionne le schéma **SOLA**, lance sur simulateur/appareil.
Ajoute ensuite le widget depuis l'écran d'accueil (appui long → **+**) ou
l'écran de verrouillage (Réglages → personnaliser).

### Vérifier le partage de données
1. Lance l'app, ouvre l'onglet **UV** (déclenche un fetch → écrit l'App Group).
2. Ajoute le widget : il doit afficher l'UV de ta ville.
3. Avant tout fetch, le widget montre l'état **« Ouvre SOLA pour les UV »**.

---

## 5. Notes de cohérence visuelle

Le widget **ne partage pas** le design system de l'app (process séparé).
`WidgetTheme.swift` recrée à l'identique les couleurs ambre/crème et l'échelle
UV (mêmes valeurs OKLCH que `SOLA/DesignSystem/Theme.swift`). Si tu modifies un
token de marque dans l'app, répercute-le dans `WidgetTheme.swift`.

---

## 6. Live Activity « Sun exposure » (ActivityKit)

Affichée pendant une session de bronzage (`ExposureTimerView`) : localisation,
UV courant, compte à rebours **avant risque de coup de soleil** et barre de
progression (début → seuil). À l'échéance, l'activité passe à l'état final
**« Seuil atteint — couvre-toi »** puis se termine. Aucune prolongation possible.

### Activation requise
1. Dans le **target SOLA** (app), ouvre `Info.plist` (ou onglet *Info*) et ajoute :
   - **`NSSupportsLiveActivities`** = `YES` (booléen).
2. Aucune capability supplémentaire : ActivityKit ne requiert pas d'entitlement
   dédié, mais les Live Activities doivent être **autorisées par l'utilisateur**
   (Réglages ▸ SOLA ▸ Activités en direct). Le code vérifie déjà
   `ActivityAuthorizationInfo().areActivitiesEnabled` avant de démarrer.

### Tester
1. Sur un **appareil réel** (Dynamic Island) ou simulateur iPhone 15 Pro.
2. Lance une session depuis « Je bronze maintenant » → appuie **Démarrer**.
3. Verrouille l'écran : la Live Activity montre le compte à rebours et la barre.
4. Laisse filer jusqu'au seuil : l'état bascule sur « Seuil atteint — couvre-toi »
   et l'activité se retire après ~60 s.

> Le câblage start/update/end est déjà en place dans `ExposureTimerView` via
> `LiveActivityManager.shared`. Rien à brancher côté JS.
