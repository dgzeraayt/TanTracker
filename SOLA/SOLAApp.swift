import SwiftUI

@main
struct SOLAApp: App {
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
    @StateObject private var notifications = NotificationManager()
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var theme = ThemeManager()
    @StateObject private var personalization = PersonalizationManager()

    init() {
        let s = AppStore()
        _store = StateObject(wrappedValue: s)
        _flow = StateObject(wrappedValue: AppFlow(store: s))
    }

    var body: some View {
        Group {
            switch flow.stage {
            case .onboarding:
                OnboardingContainer()
                    .transition(.asymmetric(insertion: .opacity,
                                            removal: .move(edge: .leading)))
            case .main:
                MainAppView()
                    .transition(.move(edge: .trailing))
            }
        }
        .environmentObject(flow)
        .environmentObject(store)
        .environmentObject(location)
        .environmentObject(notifications)
        .environmentObject(purchases)
        .environmentObject(theme)
        .environmentObject(personalization)
        .preferredColorScheme(theme.getColorScheme())
        .task { await notifications.refreshStatus() }
    }
}
