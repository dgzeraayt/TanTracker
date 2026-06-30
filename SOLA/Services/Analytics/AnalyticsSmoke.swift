#if DEBUG
import Foundation

/// Smoke check du no-op opt-in. Appelé depuis SOLAApp en DEBUG si l'env
/// `SOLA_ANALYTICS_SMOKE` est présent. Zéro impact en prod.
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
