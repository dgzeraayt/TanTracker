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
