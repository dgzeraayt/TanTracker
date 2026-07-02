import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    @Published var authorized = false

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            authorized = granted
            return granted
        } catch {
            return false
        }
    }

    /// Autorisation « provisoire » : accordée silencieusement, sans pop-up. Permet
    /// de délivrer discrètement des rappels (centre de notifications, sans bannière
    /// ni son) dès le début de l'onboarding — avant l'écran d'opt-in explicite, qui
    /// reste proposé à la fin pour passer aux notifications complètes.
    @discardableResult
    func requestProvisionalAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge, .provisional])
            await refreshStatus()
            return granted
        } catch {
            return false
        }
    }

    /// Relance d'onboarding : rappel chaque soir à 19h tant que l'onboarding n'est
    /// pas terminé. iOS redéclenche le trigger calendaire tout seul ; on l'annule à
    /// la complétion via `NotificationManager.cancelOnboardingReminder()`.
    func scheduleOnboardingReminder() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Ton coach solaire t'attend ☀️")
        content.body = String(localized: "Termine ton profil en 1 min pour débloquer tes recommandations perso.")
        content.sound = .default

        #if DEBUG
        // Test : déclenche ~10 s après au lieu d'attendre 19h.
        if ProcessInfo.processInfo.environment["SOLA_NOTIF_TEST"] != nil {
            let t = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: AlertID.onboardingReminder, content: content, trigger: t))
            return
        }
        #endif

        var comps = DateComponents()
        comps.hour = 19
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: AlertID.onboardingReminder, content: content, trigger: trigger))
    }

    /// Annule la relance d'onboarding (statique : pas besoin de l'état publié).
    static func cancelOnboardingReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [AlertID.onboardingReminder])
    }

    /// Programme un rappel de réapplication SPF selon le SPF (intervalle dérivé).
    func scheduleSPFReminder(spf: Int) {
        let minutes = Alerts.reapplyInterval(spf: spf)
        post(Alerts.spfReapply(spf: spf), after: TimeInterval(minutes * 60))
    }

    /// Compat : ancien appel par minutes fixes.
    func scheduleSPFReminder(after minutes: Int = 120) {
        post(Alerts.spfReapply(spf: 30), after: TimeInterval(minutes * 60))
    }

    /// Programme l'alerte de fin de dose sûre (limite d'exposition).
    func scheduleBurnAlert(after seconds: TimeInterval) {
        post(AlertMessage(id: AlertID.burnRisk,
                          title: String(localized: "Limite d'exposition atteinte"),
                          body: String(localized: "Mets-toi à l'ombre : tu as atteint ta dose UV sûre du jour.")),
             after: max(1, seconds))
    }

    /// Programme l'alerte de retournement à mi-parcours d'une session.
    func scheduleFlipAlert(after seconds: TimeInterval) {
        post(Alerts.flip(), after: max(1, seconds))
    }

    /// Alerte « pic UV élevé » du jour (si le pic dépasse le seuil). No-op sinon.
    func scheduleUVPeakAlert(maxToday: Double, window: String, after seconds: TimeInterval = 1) {
        guard let msg = Alerts.uvPeak(maxToday: maxToday, window: window) else { return }
        post(msg, after: max(1, seconds))
    }

    /// Alerte « risque élevé » quand la dose approche ~80 % du plafond.
    func scheduleDoseThresholdAlert(remainingMinutes: Int, after seconds: TimeInterval) {
        post(Alerts.doseThreshold(remainingMinutes: remainingMinutes), after: max(1, seconds))
    }

    /// Rappel proactif coup de soleil, ~10 min avant le plafond.
    func scheduleBurnRiskAlert(inMinutes: Int, after seconds: TimeInterval) {
        post(Alerts.burnRisk(inMinutes: inMinutes), after: max(1, seconds))
    }

    func scheduleUVWindow(at window: String) {
        post(AlertMessage(id: "uv-window", title: String(localized: "Fenêtre UV idéale"),
                          body: String(localized: "C'est le bon moment pour bronzer en sécurité (\(window)).")),
             after: 60 * 60)
    }

    func cancel(_ id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Programme une notification locale à partir d'un AlertMessage (source unique).
    private func post(_ alert: AlertMessage, after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let req = UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
}
