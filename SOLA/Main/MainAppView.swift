import SwiftUI

struct MainAppView: View {
    @StateObject private var tab = TabRouter()
    @State private var homePath = NavigationPath()
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.requestReview) private var requestReview
    @AppStorage("didRequestAppReview") private var didRequestAppReview = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab.selection {
                case 0: NavigationStack(path: $homePath) { AppHome() }
                case 1: NavigationStack { AppPlan() }
                case 2: NavigationStack { AppAnalysis() }
                case 3: NavigationStack { AppHistory() }
                default: NavigationStack { AppProfile() }
                }
            }
            SunTabBar()
        }
        .environmentObject(tab)
        .onAppear(perform: applyDebugScreen)
        .onAppear(perform: requestReviewIfEligible)
        .onOpenURL(perform: handleDeepLink)
    }

    // Avis App Store : demandé une seule fois, après l'onboarding et une fois
    // l'abonnement actif (cet écran n'est atteint qu'avec un abonnement).
    // Jamais pendant l'onboarding — conforme à la Guideline 5.6.3.
    private func requestReviewIfEligible() {
        guard !didRequestAppReview, purchases.isSubscribed else { return }
        didRequestAppReview = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { requestReview() }
    }

    // Deep links (widget, notifications…) : suny://<destination>
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "suny" else { return }
        switch url.host {
        case "uv":
            tab.selection = 0; homePath = NavigationPath(); homePath.append(HomeRoute.uv)
        case "reco":
            tab.selection = 0; homePath = NavigationPath(); homePath.append(HomeRoute.reco)
        case "home", nil:
            tab.selection = 0; homePath = NavigationPath()
        default:
            break
        }
    }

    // Ciblage d'un écran via SOLA_SCREEN (vérification only).
    private func applyDebugScreen() {
        guard let s = ProcessInfo.processInfo.environment["SOLA_SCREEN"] else { return }
        switch s {
        case "session": tab.selection = 1; tab.requestSessionStart = true
        case "plan", "plan-soir": tab.selection = 1
        case "analysis": tab.selection = 2
        case "journal": tab.selection = 3
        case "profile": tab.selection = 4
        case "uv": tab.selection = 0; homePath.append(HomeRoute.uv)
        case "reco": tab.selection = 0; homePath.append(HomeRoute.reco)
        case "stats", "analytics": tab.selection = 0; homePath.append(HomeRoute.analytics)
        case "achievements": tab.selection = 0; homePath.append(HomeRoute.achievements)
        case "settings": tab.selection = 0; homePath.append(HomeRoute.settings)
        case "personalization": tab.selection = 0; homePath.append(HomeRoute.personalization)
        case "skin": tab.selection = 0; homePath.append(HomeRoute.skin)
        default: tab.selection = 0
        }
    }
}
