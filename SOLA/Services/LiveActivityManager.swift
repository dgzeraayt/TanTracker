import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Gestionnaire de la Live Activity « Sun exposure »
// Démarre / met à jour / termine l'activité pendant une session de bronzage.
// Garde-fou : à l'atteinte du seuil, on termine avec l'état `reached`
// (« couvre-toi »). Aucune API de prolongation n'est exposée.
@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private var activity: Activity<SunSessionAttributes>? {
        get { _activity as? Activity<SunSessionAttributes> }
        set { _activity = newValue }
    }
    private var _activity: Any?
    #endif

    /// Les Live Activities sont-elles autorisées par le système ?
    var isAvailable: Bool {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        #endif
        return false
    }

    /// Démarre l'activité au lancement d'une session.
    func start(city: String, uv: Double, safeMinutes: Int, endDate: Date) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), isAvailable else { return }
        // Une seule session active à la fois.
        if activity != nil { return }

        let attributes = SunSessionAttributes(city: city, uvIndex: uv, safeMinutes: safeMinutes)
        let state = SunSessionAttributes.ContentState(endDate: endDate, progress: 0, phase: .running)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: endDate.addingTimeInterval(60)))
        } catch {
            activity = nil
        }
        #endif
    }

    /// Met à jour la progression / la phase pendant la session.
    func update(progress: Double, endDate: Date, paused: Bool) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), let activity else { return }
        let state = SunSessionAttributes.ContentState(
            endDate: endDate,
            progress: min(1, max(0, progress)),
            phase: paused ? .paused : .running)
        Task { await activity.update(.init(state: state, staleDate: endDate.addingTimeInterval(60))) }
        #endif
    }

    /// Termine l'activité. `reached` = seuil atteint (état final « couvre-toi »).
    func end(reached: Bool) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), let activity else { return }
        let finalState = SunSessionAttributes.ContentState(
            endDate: Date(),
            progress: reached ? 1 : activityProgressFallback,
            phase: reached ? .reached : .running)
        Task {
            await activity.end(.init(state: finalState, staleDate: nil),
                               dismissalPolicy: reached ? .after(.now + 60) : .immediate)
        }
        self.activity = nil
        #endif
    }

    private var activityProgressFallback: Double { 1 }
}
