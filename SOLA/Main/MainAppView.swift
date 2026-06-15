import SwiftUI

struct MainAppView: View {
    @StateObject private var tab = TabRouter()
    @State private var homePath = NavigationPath()

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
        .onOpenURL(perform: handleDeepLink)
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
        default: tab.selection = 0
        }
    }
}
