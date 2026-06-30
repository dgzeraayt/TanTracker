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
