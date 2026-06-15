# Refonte Accueil + Météo + Programme assisté — Design

Date : 2026-06-15
App : SOLA / SUNY (TanTracker) — iOS SwiftUI

## Contexte

L'app a aujourd'hui :

- **Accueil (`AppHome`, `Main1.swift`)** : en-tête, `SafeTanCard` (héros), bouton « Lancer ma séance »
  (ouvre `ExposureTimerView` en `fullScreenCover`), bento *Indice UV* + *Meilleur créneau*, carte
  *Semaine X/12* → onglet Programme, `CoachCard`, CTA widget.
- **Programme (`AppPlan`, `Main1.swift`)** : toggle Jour/Soir, carte phase
  (Préparation → Construction → Entretien), checklist statique de routine cochée à la main.
  Pas de timer ici.
- **Infra déjà existante et réutilisable :**
  - `ExposureTimerView` (`Main2.swift:803`) : minuteur circulaire, bandeau + vibration « retourne-toi »
    à mi-temps, rappel SPF, alerte coup de soleil, Live Activity, enregistrement de session à la fin.
    C'est **déjà une séance guidée**, mais lancée comme écran orphelin.
  - `NotificationManager` : `scheduleSPFReminder`, `scheduleBurnAlert`, `scheduleFlipAlert`,
    `scheduleUVPeakAlert`, `scheduleDoseThresholdAlert`, `scheduleUVWindow`, `scheduleBurnRiskAlert`.
  - `LiveActivityManager` : Dynamic Island / écran verrouillé.
  - `Coach.message(uv:dose:idealWindow:hour:hasExposureToday:)` : messages contextuels.
  - `UVService` / `UVForecast` : récupère déjà via Open-Meteo l'UV horaire, température réelle,
    prévision UV 7 jours (`DailyUV { dayLabel, uvMax, sunny }`), aperçu de demain. **Pas** de vraie
    météo (couverture nuageuse / pluie) : `weatherLabel` est dérivé de l'UV, pas observé.

## Objectif

Trois chantiers cohérents, livrables indépendamment, dans l'ordre **2 → 1 → 3** :

1. **Accueil = tableau de bord** : le bouton séance devient un raccourci vers le flux guidé du
   Programme ; ajout d'un bloc météo (aujourd'hui + 7 jours).
2. **Vraie météo dans `UVService`** : couverture réelle + temp min/max (alimente le chantier 1).
3. **Programme « vraiment assisté »** : séance guidée live câblée à la checklist + intelligence
   contextuelle + rappels.

Principe directeur : **réorganiser et câbler l'existant**, ne reconstruire que le strict nécessaire.
La séance est « possédée » par le Programme ; l'accueil n'en est qu'un raccourci.

---

## Chantier 2 — Vraie météo dans `UVService` (à faire en premier)

### Changements API
Étendre la requête Open-Meteo (`UVService.fetch`) :
- `hourly` : ajouter `weather_code`.
- `daily` : ajouter `weather_code`, `temperature_2m_max`, `temperature_2m_min`.

### Modèle
- Nouveau `enum WeatherCondition { clear, partlyCloudy, cloudy, fog, rain, showers, thunderstorm, snow }`
  avec : `init(weatherCode: Int)` (mapping WMO Open-Meteo), `iconName` (asset/SF Symbol existant),
  `label` (FR : « Ensoleillé », « Nuageux », « Pluie », « Orage »…).
- Étendre `DailyUV` : ajouter `condition: WeatherCondition`, `tempMax: Double`, `tempMin: Double`.
  (Conserver `dayLabel`, `uvMax`, `sunny` pour compat ; `sunny` peut être dérivé de `condition`.)
- Étendre `UVForecast` : ajouter `condition: WeatherCondition` (jour courant, depuis le weathercode
  de l'heure courante). `weatherLabel` devient `condition.label` (au lieu d'être dérivé de l'UV).
- Mettre à jour `UVForecast.sample` (repli hors-ligne) et `==` en conséquence.

### Mapping WMO (résumé)
0 → clear ; 1–2 → partlyCloudy ; 3 → cloudy ; 45/48 → fog ; 51–57/61–67/80–82 → rain/showers ;
71–77/85/86 → snow ; 95/96/99 → thunderstorm.

### Critère de succès
La condition affichée correspond à la vraie météo Open-Meteo (plus seulement à l'UV) ; min/max
température disponibles par jour ; repli hors-ligne cohérent.

---

## Chantier 1 — Accueil = tableau de bord

### Raccourci séance
- Le bouton **« Lancer ma séance »** (`Main1.swift:113`) ne présente plus `ExposureTimerView` en
  `fullScreenCover`. À la place : `tab.selection = 1` (Programme) + déclenche le démarrage du flux
  guidé du Programme (voir Chantier 3 pour le mécanisme de démarrage partagé).
- Supprimer le `.fullScreenCover` correspondant sur `AppHome`.

### Bloc météo (nouveau composant `WeatherBlock`)
Inséré entre le bento UV/créneau et la carte *Semaine X/12*.
- **Aujourd'hui** : icône condition · température · UV · label (ex. « ⛅ 28° · UV 8 · Nuageux »),
  éventuellement min/max.
- **Cette semaine** : bande horizontale 7 jours depuis `forecast.daily` — par jour : `dayLabel`,
  icône `condition`, `tempMax` (et UV max en sous-texte).
- Style : réutilise `CardBox` / tokens existants (`Palette`, `SolaFont`, `ClayAssetImage`/`Icon`).
- État de chargement : si `forecastStore.isLoading` et pas de données, placeholder discret.

### Critère de succès
L'accueil affiche météo du jour + semaine réelles ; le bouton séance emmène dans le Programme et
démarre la séance guidée ; le reste de l'accueil est inchangé.

---

## Chantier 3 — Programme « vraiment assisté »

### 3a. Séance guidée live (câblée à la checklist)
Aujourd'hui la checklist `AppPlan` est statique. On la relie au minuteur :
- L'étape « Bronze X min » (jour) devient l'ancre de la séance. Au démarrage (depuis le Programme,
  ou via le raccourci accueil), la séance utilise le `ExposureTimer` existant.
- Présentation : réutiliser `ExposureTimerView` (qui gère déjà flip à mi-temps, haptics, Live
  Activity, alerte brûlure, log de session). Option de présentation à trancher dans le plan :
  - **(Recommandé)** garder `ExposureTimerView` en plein écran, lancé depuis le Programme, et à sa
    fermeture marquer l'étape « Bronze » comme faite + avancer la checklist ;
  - alternative : embarquer un timer compact dans la carte d'étape (plus de travail UI).
- Mécanisme de démarrage partagé : un point d'entrée unique (ex. flag/route sur `AppStore` ou
  `TabRouter`) que l'accueil ET le Programme déclenchent, pour garantir « la séance est possédée par
  le Programme ».
- Cocher une étape de routine reflète l'état réel (déjà géré par `store.toggleRoutine` /
  `isRoutineDone`).

### 3b. Intelligence contextuelle
- Bandeau en haut du Programme : message adaptatif selon **UV courant + heure + météo**.
  Exemples : « UV trop bas (UV 2), attends ton créneau 16h » ; « Pluie prévue cet après-midi —
  profite de la matinée » ; « UV au pic, séance courte conseillée ».
- Implémentation : étendre `Coach` (ou un helper dédié `ProgramGuidance`) prenant
  `uv, hour, condition, idealWindow, daily` → message + ton. Réutilise `CoachCard`.

### 3c. Rappels (câblage des notifs existantes)
Au démarrage de la séance, programmer via `NotificationManager` :
- `scheduleFlipAlert` à mi-temps (mi-durée de la séance) ;
- `scheduleSPFReminder(after: 120)` — remettre la crème dans 2h ;
- rappel routine du soir (réutiliser le canal de notif existant) ;
- conserver le câblage `scheduleUVWindow` / `scheduleUVPeakAlert` déjà présent.
Tous conditionnés à l'autorisation notifications (déjà gérée).

### Critère de succès
Démarrer une séance depuis l'accueil OU le Programme lance le même flux guidé ; le timer pilote la
progression de la routine ; le bandeau contextuel reflète UV/heure/météo ; les rappels se
programment au démarrage.

---

## Hors périmètre (YAGNI)
- Pas de nouveau backend météo (on reste sur Open-Meteo gratuit, sans clé).
- Pas de refonte visuelle du design system ni des onglets autres que Accueil/Programme.
- Pas de timer embarqué custom si la réutilisation de `ExposureTimerView` suffit (à confirmer au plan).
- Pas de prévisions météo > 7 jours.

## Risques / points d'attention
- `UVForecast.==` et `.sample` doivent être mis à jour avec les nouveaux champs, sinon comparaisons
  et repli hors-ligne cassent.
- Le weathercode horaire « courant » doit être aligné sur le même index que `current`/`temperature`.
- Le mécanisme de démarrage partagé de séance ne doit pas créer deux sources de vérité (un seul flag).
- Vérifier que les icônes de condition existent dans le design system (`ClayIMG`/`Icon`) ou en ajouter.

## Ordre de livraison
Chantier 2 (météo) → Chantier 1 (accueil) → Chantier 3 (programme assisté). Chacun est livrable et
testable indépendamment.
