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

    /// Programme un rappel de réapplication SPF dans `minutes`.
    func scheduleSPFReminder(after minutes: Int = 120) {
        schedule(id: "spf-reminder", title: "Réapplique ta crème solaire",
                 body: "Cela fait 2h — protège ta peau pour continuer à bronzer sans brûler.",
                 after: TimeInterval(minutes * 60))
    }

    /// Programme l'alerte de fin de dose sûre (limite d'exposition).
    func scheduleBurnAlert(after seconds: TimeInterval) {
        schedule(id: "burn-alert", title: "Limite d'exposition atteinte",
                 body: "Mets-toi à l'ombre : tu as atteint ta dose UV sûre du jour.",
                 after: max(1, seconds))
    }

    func scheduleUVWindow(at window: String) {
        schedule(id: "uv-window", title: "Fenêtre UV idéale",
                 body: "C'est le bon moment pour bronzer en sécurité (\(window)).",
                 after: 60 * 60)
    }

    func cancel(_ id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    private func schedule(id: String, title: String, body: String, after: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: after, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
}
