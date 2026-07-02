# Chantier #3 — Relance d'onboarding non terminé (design)

**Date :** 2026-07-02
**Branche :** `feat/onboarding-reminder` (empilée sur `feat/localization`)

## Objectif

Ré-engager les utilisateurs qui commencent l'onboarding sans le terminer, via une
notification locale du soir, tant que l'onboarding n'est pas complété.

## Contrainte clé découverte

La permission de notification est demandée au **tout dernier écran** de l'onboarding
(`Onboarding2.swift:379`), et l'accorder déclenche immédiatement `finishOnboarding()`.
Donc, sans changement, un abandonneur n'a **jamais** donné la permission → impossible
de le notifier.

**Solution retenue :** autorisation **provisoire** (`.provisional`) demandée
silencieusement (sans pop-up) dès le début de l'onboarding. Elle permet une
livraison discrète (centre de notifications, sans bannière ni son) pour tous ceux
qui commencent. L'écran final d'opt-in reste proposé pour passer aux notifications
complètes (bannière + son).

## Comportement

- **Quand :** planifiée au 1er écran d'onboarding (`onboardingStarted`,
  `OnboardingContainer:49`).
- **Fréquence :** chaque soir à **19h00**, en boucle, tant que l'onboarding n'est pas
  terminé (`UNCalendarNotificationTrigger(hour: 19, repeats: true)` — iOS redéclenche
  seul). Aujourd'hui si avant 19h, sinon dès demain (comportement natif du trigger).
- **Annulation :** à la complétion (`AppFlow.finishOnboarding` →
  `NotificationManager.cancelOnboardingReminder()`).
- **Intrusion :** faible — provisoire = livraison silencieuse, donc « chaque soir »
  reste acceptable sans cap.

## Copie (localisée fr/en/es/it/pt dans `SOLA/Localizable.xcstrings`)

- Titre : « Ton coach solaire t'attend ☀️ »
- Corps : « Termine ton profil en 1 min pour débloquer tes recommandations perso. »

## Composants

- `NotificationManager` : `requestProvisionalAuthorization()`,
  `scheduleOnboardingReminder()`, `static cancelOnboardingReminder()`.
- `AlertID.onboardingReminder = "onboarding-relance"` (id stable).
- `OnboardingContainer` : au step 0, provisoire + planification.
- `AppFlow.finishOnboarding` : annulation.

## Cas limites

- Permission déjà refusée → aucune livraison (acceptable).
- Restart onboarding → `onboardingStarted` re-planifie.
- Notif déjà en attente → même `id`, pas de doublon.

## Test

Hook DEBUG `SOLA_NOTIF_TEST` : planifie la relance à +10 s au lieu de 19h.
Vérifié au simulateur : contenu résolu à l'exécution en EN (« Your sun coach is
waiting ☀️ ») et ES (« Tu coach solar te espera ☀️ »).
