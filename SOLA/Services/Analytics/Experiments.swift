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
