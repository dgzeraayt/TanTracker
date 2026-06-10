import SwiftUI

struct MainAppView: View {
    @State private var selection = 0
    @State private var homePath = NavigationPath()

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $homePath) { AppHome() }
                .tabItem { Label("Accueil", systemImage: "house.fill") }
                .tag(0)
            NavigationStack { AppPlan() }
                .tabItem { Label("Plan", systemImage: "checklist") }
                .tag(1)
            NavigationStack { AppAnalysis() }
                .tabItem { Label("Analyse", systemImage: "camera.viewfinder") }
                .tag(2)
            NavigationStack { AppUV() }
                .tabItem { Label("UV", systemImage: "sun.max.fill") }
                .tag(3)
            NavigationStack { AppHistory() }
                .tabItem { Label("Journal", systemImage: "book.fill") }
                .tag(4)
        }
        .tint(Palette.amberDeep)
        .onAppear(perform: applyDebugScreen)
    }

    // Ciblage d'un écran via SOLA_SCREEN (vérification only).
    private func applyDebugScreen() {
        guard let s = ProcessInfo.processInfo.environment["SOLA_SCREEN"] else { return }
        switch s {
        case "plan", "plan-soir": selection = 1
        case "analysis": selection = 2
        case "uv": selection = 3
        case "journal": selection = 4
        case "reco": selection = 0; homePath.append(HomeRoute.reco)
        case "profile": selection = 0; homePath.append(HomeRoute.profile)
        default: selection = 0
        }
    }
}
