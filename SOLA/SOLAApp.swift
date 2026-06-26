import SwiftUI

@main
struct SOLAApp: App {
    init() { FontLoader.registerAll() }
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// Étape globale de l'app : onboarding -> app principale
@MainActor
final class AppFlow: ObservableObject {
    enum Stage { case onboarding, main }
    @Published var stage: Stage
    let store: AppStore

    init(store: AppStore) {
        self.store = store
        var initial: Stage = store.data.onboardingComplete ? .main : .onboarding
        #if DEBUG
        if ProcessInfo.processInfo.environment["SOLA_SCREEN"] != nil { initial = .main }
        if ProcessInfo.processInfo.environment["SOLA_ONB"] != nil { initial = .onboarding }
        #endif
        stage = initial
    }

    func finishOnboarding() {
        store.finalizeOnboarding()
        withAnimation(.easeInOut(duration: 0.35)) { stage = .main }
    }
    func restart() {
        store.restartOnboarding()
        withAnimation(.easeInOut(duration: 0.35)) { stage = .onboarding }
    }
}

struct RootView: View {
    @StateObject private var store: AppStore
    @StateObject private var flow: AppFlow
    @StateObject private var location = LocationManager()
    @StateObject private var forecastStore = ForecastStore()
    @StateObject private var notifications = NotificationManager()
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var personalization = PersonalizationManager()

    init() {
        let s = AppStore()
        _store = StateObject(wrappedValue: s)
        _flow = StateObject(wrappedValue: AppFlow(store: s))
    }

    private var forcePaywall: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["SOLA_PAYWALL"] != nil
        #else
        return false
        #endif
    }

    var body: some View {
        Group {
            if forcePaywall && !purchases.isPro {
                PaywallSheet(mandatory: false, onSkip: { purchases.grantAccess() })
            } else {
            switch flow.stage {
            case .onboarding:
                OnboardingContainer()
                    .transition(.asymmetric(insertion: .opacity,
                                            removal: .move(edge: .leading)))
            case .main:
                // Mur d'accès : l'app n'est accessible qu'avec un abonnement actif.
                // La croix lance la roulette + l'offre promo (rétention) ; refuser
                // ramène au paywall — l'accès reste verrouillé tant que `isPro` est faux.
                if purchases.isPro {
                    MainAppView()
                        .transition(.move(edge: .trailing))
                } else {
                    PaywallExitOfferFlow()
                        .transition(.opacity)
                }
            }
            }
        }
        .tint(personalization.preferences.accentColor.color)
        .animation(.easeInOut(duration: 0.4), value: purchases.isPro)
        .environmentObject(flow)
        .environmentObject(store)
        .environmentObject(location)
        .environmentObject(forecastStore)
        .environmentObject(notifications)
        .environmentObject(purchases)
        .environmentObject(personalization)
        .preferredColorScheme(.light)
        .task { await notifications.refreshStatus() }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["SOLA_LIVEACT"] != nil {
                LiveActivityManager.shared.start(
                    city: "Barcelona", uv: 9, safeMinutes: 27,
                    endDate: Date().addingTimeInterval(27 * 60))
            }
            #endif
        }
    }
}
