import SwiftUI

enum HomeRoute: Hashable { case profile, skin, reco, uv, achievements, analytics, challenges, personalization, settings }

// Avatar : vraie photo de suivi si dispo, sinon initiales du prénom.
struct AvatarView: View {
    @EnvironmentObject var store: AppStore
    var size: CGFloat = 46
    private var initials: String {
        let parts = store.profile.name.split(separator: " ").prefix(2)
        let s = parts.compactMap { $0.first }.map(String.init).joined()
        return s.isEmpty ? "" : s.uppercased()
    }
    var body: some View {
        Group {
            if let name = store.lastPhotoSessions.last?.photoFilename, let img = PhotoStore.load(name) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Palette.amber, Palette.amberDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                    if initials.isEmpty {
                        Icon(name: "sun", size: size * 0.5, stroke: 2).foregroundStyle(Palette.onAmber)
                    } else {
                        Text(initials).font(SolaFont.display(size * 0.4, weight: .bold)).foregroundStyle(Palette.onAmber)
                    }
                }
            }
        }
        .frame(width: size, height: size).clipShape(Circle())
        .overlay(Circle().stroke(Palette.surface, lineWidth: 2))
        .solaShadowSm()
    }
}

// MARK: - A1 · Accueil
struct AppHome: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager
    @EnvironmentObject var forecastStore: ForecastStore
    @EnvironmentObject var tab: TabRouter
    private var forecast: UVForecast { forecastStore.forecast }
    private var uvWord: String {
        switch forecast.current {
        case ..<3: return "faible"; case ..<6: return "modéré"
        case ..<8: return "élevé"; default: return "très élevé"
        }
    }
    private var hueLabel: String {
        solaHueLabel(store.currentTanIndex, newline: true).uppercased()
    }
    private var heroLead: String {
        store.todayHasExposure
            ? "Séance soleil du jour faite — belle progression !"
            : "Tu n'as pas encore pris le soleil aujourd'hui."
    }
    private var locationKey: String { "\(store.profile.latitude),\(store.profile.longitude)" }
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bonjour \(store.profile.firstName)")
                                .font(SolaFont.body(14, weight: .semibold)).foregroundStyle(Palette.ink3)
                            Text("Le soleil t'attend.")
                                .font(SolaFont.display(25, weight: .heavy)).tracking(-0.5)
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        VStack(spacing: 6) {
                            Button { HapticsManager.shared.select(); tab.selection = 4 } label: { AvatarView() }
                                .buttonStyle(.plain)
                            StreakChip(days: store.streak)
                        }
                    }
                    .padding(.top, 4)

                    // Action principale unique : ouvre le parcours guidé dans le Programme.
                    Button {
                        HapticsManager.shared.select()
                        tab.requestSessionStart = true
                        tab.selection = 1
                    } label: {
                        HStack(spacing: 10) {
                            Icon(name: "sun", size: 20).foregroundStyle(Palette.onAmber)
                            Text("Lancer ma séance").font(SolaFont.body(17, weight: .bold)).foregroundStyle(Palette.onAmber)
                        }
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(Capsule().fill(Palette.amber))
                        .shadowSoft()
                    }
                    .buttonStyle(.plain)
                    .pressAnimation()
                    .padding(.top, 20)

                    // Bento : conditions du jour, glançables (UV → détail, créneau idéal)
                    HStack(spacing: 12) {
                        NavigationLink(value: HomeRoute.uv) {
                            CardBox(padding: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        ClayAssetImage(name: ClayIMG.sun, size: 22, shadow: false)
                                        Text("Indice UV").font(SolaFont.body(12.5)).foregroundStyle(Palette.ink3)
                                    }
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text(forecast.current.formatted(.number.precision(.fractionLength(0...1))))
                                            .font(SolaFont.display(22, weight: .heavy)).foregroundStyle(Palette.ink)
                                        Text(uvWord).font(SolaFont.body(12, weight: .bold))
                                            .foregroundStyle(Palette.uvColorInk(forecast.current))
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        CardBox(padding: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    ClayAssetImage(name: ClayIMG.timer, size: 22, shadow: false)
                                    Text("Meilleur créneau").font(SolaFont.body(12.5)).foregroundStyle(Palette.ink3)
                                        .lineLimit(1).minimumScaleFactor(0.8)
                                }
                                Text(forecast.idealWindow).font(SolaFont.display(18, weight: .heavy))
                                    .foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.6)
                            }
                        }
                    }
                    .padding(.top, 12)

                    WeatherBlock(forecast: forecast)
                        .padding(.top, 12)

                    // Avancement du programme (source unique : semaine x/12) → onglet Programme
                    Button { HapticsManager.shared.select(); tab.selection = 1 } label: {
                        CardBox(padding: 15) {
                            HStack(spacing: 13) {
                                Icon(name: "trend", size: 18).foregroundStyle(Palette.amberDeep)
                                    .frame(width: 38, height: 38)
                                    .background(Circle().fill(Palette.tintGold))
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text("Semaine \(store.currentWeek) sur \(store.profile.targetWeeks)")
                                            .font(SolaFont.body(14.5, weight: .bold)).foregroundStyle(Palette.ink)
                                        Spacer(minLength: 6)
                                        Text(store.profile.goal.title).font(SolaFont.body(12.5)).foregroundStyle(Palette.ink3)
                                            .lineLimit(1)
                                    }
                                    Track(value: store.planProgress, height: 7)
                                }
                                Icon(name: "chevR", size: 18).foregroundStyle(Palette.ink3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)

                    // Coaching contextuel
                    CoachCard(message: Coach.message(
                        uv: forecast.current,
                        dose: store.todayDose(currentUV: forecast.current),
                        idealWindow: forecast.idealWindow,
                        hour: Calendar.current.component(.hour, from: .now),
                        hasExposureToday: store.todayHasExposure))
                        .padding(.top, 12)

                    WidgetCTACard()
                        .padding(.top, 12)

                    TabBarSpacer()
                }
                .padding(.horizontal, Frame.padH)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .profile: AppProfile()
            case .skin: AppProfileSkin()
            case .reco: AppReco()
            case .uv: AppUV()
            case .achievements: AppAchievements()
            case .analytics: AnalyticsDashboard()
            case .challenges: AppChallenges()
            case .personalization: AppPersonalization()
            case .settings: AppProfileSettings()
            }
        }
        .task(id: locationKey) {
            await forecastStore.loadIfNeeded(lat: store.profile.latitude, lon: store.profile.longitude, city: store.profile.city)
        }
    }

}

// MARK: - CTA · Ajouter le widget (refermable, mémorisé)
struct WidgetCTACard: View {
    @AppStorage("sola_widget_cta_dismissed") private var dismissed = false
    @State private var showHowTo = false

    var body: some View {
        if !dismissed {
            CardBox(padding: 16) {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Palette.amberDeep)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(Palette.tintGold))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ajoute le widget SUNY")
                                .font(SolaFont.body(15.5, weight: .bold)).foregroundStyle(Palette.ink)
                            Text("Ton UV du jour et ton temps de bronzage sûr, direct sur l'écran d'accueil.")
                                .font(SolaFont.body(12.5)).foregroundStyle(Palette.ink3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Button {
                            HapticsManager.shared.select()
                            withAnimation(.easeOut(duration: 0.2)) { dismissed = true }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.ink3)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Palette.lineSoft.opacity(0.5)))
                        }.buttonStyle(.plain)
                    }
                    Button {
                        HapticsManager.shared.select(); showHowTo = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("Voir comment l'ajouter").font(SolaFont.body(14, weight: .bold)).foregroundStyle(Palette.onAmber)
                            Icon(name: "chevR", size: 15).foregroundStyle(Palette.onAmber)
                        }
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Capsule().fill(Palette.amber))
                    }.buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showHowTo) { WidgetHowToSheet() }
        }
    }
}

// Feuille d'instructions pas-à-pas (iOS n'autorise pas l'ajout de widget par code).
struct WidgetHowToSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    private let steps: [String] = [
        "Appuie longuement sur une zone vide de l'écran d'accueil, jusqu'à ce que les icônes bougent.",
        "Touche le bouton « + » en haut à gauche de l'écran.",
        "Cherche « SUNY » dans la liste, puis sélectionne-le.",
        "Choisis la taille du widget et touche « Ajouter le widget »."
    ]

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(spacing: 0) {
                // Barre : poignée + fermeture
                HStack {
                    Capsule().fill(Palette.lineSoft).frame(width: 38, height: 5)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .trailing) {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.ink3)
                                    .frame(width: 30, height: 30).background(Circle().fill(Palette.lineSoft.opacity(0.5)))
                            }.buttonStyle(.plain)
                        }
                }
                .padding(.top, 10).padding(.horizontal, Frame.padH)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Hero : carrousel des vrais widgets (petit + moyen)
                        widgetCarousel
                            .padding(.top, 8).padding(.bottom, 22)

                        Text("Ajoute le widget SUNY")
                            .font(SolaFont.display(28, weight: .heavy)).tracking(-0.6)
                            .foregroundStyle(Palette.ink)
                        Text("Garde ton UV du jour et ton temps de bronzage sûr à portée de regard, sans ouvrir l'app.")
                            .font(SolaFont.body(14.5)).foregroundStyle(Palette.ink3)
                            .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 7).padding(.bottom, 26)

                        // Timeline numérotée avec ligne de liaison
                        VStack(spacing: 0) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { i, text in
                                stepRow(index: i, isLast: i == steps.count - 1, text: text)
                            }
                        }
                        Color.clear.frame(height: 10)
                    }
                    .padding(.horizontal, Frame.padH)
                }

                // CTA ancré en bas
                Button { dismiss() } label: {
                    Text("J'ai compris").font(SolaFont.body(16, weight: .bold)).foregroundStyle(Palette.onAmber)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Capsule().fill(Palette.amber))
                        .shadowSoft()
                }.buttonStyle(.plain)
                .padding(.horizontal, Frame.padH).padding(.top, 8).padding(.bottom, 12)
            }
        }
    }

    // MARK: Carrousel d'aperçu des vrais widgets (mêmes rendus que SUNYWidget)
    private static let sampleCity = "Barcelona"
    private static let sampleUV = 5, samplePeak = 9.0, sampleLevel = "Modéré"
    private static let sampleDays: [(String, String, String, Double)] = [
        ("Dim", "sun.max.fill", "Élevé", 7), ("Lun", "cloud.sun.fill", "Modéré", 4),
        ("Mar", "sun.max.fill", "Élevé", 7), ("Mer", "sun.max.fill", "Élevé", 7)
    ]

    private var widgetCarousel: some View {
        VStack(spacing: 12) {
            // Fond « écran d'accueil » discret pour faire ressortir les widgets crème.
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [Palette.tintGold, Palette.bgWarm],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                TabView(selection: $page) {
                    smallWidgetMock.frame(width: 158, height: 158).frame(maxWidth: .infinity).tag(0)
                    mediumWidgetMock.frame(height: 158).padding(.horizontal, 14).tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 186)
            }
            .frame(height: 186)
            HStack(spacing: 7) {
                ForEach(0..<2, id: \.self) { i in
                    Capsule().fill(i == page ? Palette.amberDeep : Palette.lineSoft)
                        .frame(width: i == page ? 18 : 7, height: 7)
                        .animation(.spring(response: 0.3), value: page)
                }
            }
        }
    }

    private func widgetCard<Content: View>(_ content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.bg))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.lineSoft, lineWidth: 1))
            .shadow(color: Palette.ink.opacity(0.12), radius: 12, x: 0, y: 7)
    }

    private var smallWidgetMock: some View {
        widgetCard(
            widgetSummary(numberSize: 56)
                .padding(14)
                .frame(width: 158, height: 158, alignment: .leading)
        )
    }

    private var mediumWidgetMock: some View {
        widgetCard(
            HStack(spacing: 14) {
                widgetSummary(numberSize: 44).frame(width: 116)
                Rectangle().fill(Palette.lineSoft).frame(width: 1)
                VStack(spacing: 0) {
                    ForEach(Array(Self.sampleDays.enumerated()), id: \.offset) { _, d in
                        HStack(spacing: 8) {
                            Text(d.0).font(SolaFont.body(12, weight: .semibold)).foregroundStyle(Palette.ink3)
                                .frame(width: 30, alignment: .leading)
                            Image(systemName: d.1).font(.system(size: 13)).foregroundStyle(Palette.amberDeep).frame(width: 18)
                            Text(d.2).font(SolaFont.body(11, weight: .medium)).foregroundStyle(Palette.ink3)
                                .frame(width: 50, alignment: .leading).lineLimit(1).minimumScaleFactor(0.7)
                            uvMiniBar(d.3, height: 5).frame(maxWidth: .infinity)
                            Text("\(Int(d.3))").font(SolaFont.display(13, weight: .bold)).foregroundStyle(Palette.ink)
                                .frame(width: 14, alignment: .trailing)
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        )
    }

    private func widgetSummary(numberSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(Self.sampleCity).font(SolaFont.body(15, weight: .bold)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Image(systemName: "location.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.amberDeep)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 2)
            Text("\(Self.sampleUV)").font(SolaFont.display(numberSize, weight: .heavy))
                .foregroundStyle(Palette.ink).minimumScaleFactor(0.5).lineLimit(1)
            Spacer(minLength: 2)
            Text(Self.sampleLevel).font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.ink3)
            Text("Pic : \(String(format: "%.1f", Self.samplePeak))").font(SolaFont.body(12)).foregroundStyle(Palette.ink3)
            uvMiniBar(Double(Self.sampleUV), height: 6).padding(.top, 5)
        }
    }

    private func uvMiniBar(_ uv: Double, height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.lineSoft)
                Capsule().fill(LinearGradient(colors: [Palette.gold, Palette.amber, Palette.terra, Palette.alert],
                                              startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, geo.size.width * min(1, uv / 11)))
            }
        }
        .frame(height: height)
    }

    // Une étape : pastille numérotée + ligne verticale de liaison + texte.
    private func stepRow(index: Int, isLast: Bool, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(Palette.amber).frame(width: 36, height: 36)
                        .shadow(color: Palette.amberDeep.opacity(0.3), radius: 3, y: 2)
                    Text("\(index + 1)").font(SolaFont.display(17, weight: .heavy)).foregroundStyle(Palette.onAmber)
                }
                if !isLast {
                    RoundedRectangle(cornerRadius: 1.5).fill(Palette.amber.opacity(0.35))
                        .frame(width: 3).frame(maxHeight: .infinity)
                }
            }
            Text(text)
                .font(SolaFont.body(15.5, weight: .semibold)).foregroundStyle(Palette.ink)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6).padding(.bottom, isLast ? 0 : 24)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - A3 · Plan du jour (dérivé du phototype + UV réel)
struct AppPlan: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var forecastStore: ForecastStore
    @EnvironmentObject var tab: TabRouter
    @State private var showSession = false
    @State private var evening: Bool
    @State private var picked: UIImage?
    @State private var showPicker = false

    init() {
        var initialEvening = false
        #if DEBUG
        // Ciblage du mode soir via SOLA_SCREEN=plan-soir (vérification only).
        if ProcessInfo.processInfo.environment["SOLA_SCREEN"] == "plan-soir" { initialEvening = true }
        #endif
        _evening = State(initialValue: initialEvening)
    }

    private var forecast: UVForecast { forecastStore.forecast }
    // index de routine : 10–13 réservés au plan « jour », 20–23 au plan « soir »
    private var base: Int { evening ? 20 : 10 }
    private var safeMin: Int { store.safeMinutes(uv: forecast.current) }
    private var perFace: Int { max(1, safeMin / 2) }
    private var spf: Int { store.profile.phototype.recommendedSPF }

    private struct PlanStep {
        let num: String
        let title: String
        let sub: String
        let meta: String
        var photo = false       // étape « prendre une photo » → ouvre l'appareil
    }
    private var steps: [PlanStep] {
        if evening {
            return [
                PlanStep(num: "1", title: "Nettoie ta peau", sub: "Retire crème, sel et chlore", meta: "Au retour"),
                PlanStep(num: "2", title: "Applique de l'after-sun", sub: "Apaise et fait durer le bronzage", meta: "Dans l'heure"),
                PlanStep(num: "3", title: "Hydrate-toi", sub: "Crème riche sur les zones exposées", meta: "Avant le coucher"),
                PlanStep(num: "4", title: "Prends une photo", sub: "Pour suivre ta progression", meta: "Au coucher", photo: true)
            ]
        }
        return [
            PlanStep(num: "1", title: "Mets ta crème SPF \(spf)", sub: "Sur toutes les zones exposées", meta: "Avant de sortir"),
            PlanStep(num: "2", title: "Bronze \(safeMin) min max", sub: "Commence côté face · \(perFace) min", meta: forecast.idealWindow),
            PlanStep(num: "3", title: "Retourne-toi", sub: "Côté dos · \(perFace) min", meta: "À mi-temps"),
            PlanStep(num: "4", title: "Remets de la crème", sub: "Surtout après une baignade", meta: "Toutes les 2h")
        ]
    }
    // Toutes les étapes comptent (y compris « prends une photo »).
    private var doneCount: Int { steps.indices.filter { store.isRoutineDone(base + $0) }.count }
    private var phase: PlanPhase {
        PlanProgram.phase(week: store.currentWeek, targetWeeks: store.profile.targetWeeks,
                          phototype: store.profile.phototype, goal: store.profile.goal)
    }

    // Démarrage de séance demandé (depuis l'accueil) : ouvre la séance guidée en mode Jour.
    private func consumeSessionRequest() {
        evening = false
        if !store.data.programStarted { store.data.programStarted = true }
        showSession = true
        tab.requestSessionStart = false
    }

    // Avant démarrage : la routine du jour est masquée derrière un bouton d'engagement.
    private var startProgramCard: some View {
        SunHero(motif: ClayIMG.sun) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Prêt à bronzer malin ?")
                        .font(SolaFont.display(20, weight: .heavy)).tracking(-0.4).foregroundStyle(Palette.ink)
                    Text("Démarre ton programme pour débloquer ta routine du jour, étape par étape.")
                        .font(SolaFont.body(13.5)).foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    HapticsManager.shared.select()
                    withAnimation(.easeOut(duration: 0.35)) { store.data.programStarted = true }
                } label: {
                    HStack(spacing: 10) {
                        Icon(name: "sun", size: 19).foregroundStyle(Palette.onAmber)
                        Text("Démarrer mon programme").font(SolaFont.body(16, weight: .bold)).foregroundStyle(Palette.onAmber)
                    }
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(Capsule().fill(Palette.amber))
                    .shadowSoft()
                }
                .buttonStyle(.plain)
                .pressAnimation()
            }
        }
    }

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    ScreenTitle(text: "Ton programme")
                    Spacer()
                    UvBadge(uv: forecast.current)
                }
                .padding(.top, 4)

                HStack(spacing: 0) {
                    segButton("Jour", icon: "sun", on: !evening) { evening = false }
                    segButton("Soir", icon: "moon", on: evening) { evening = true }
                }
                .padding(5)
                .background(GlassPanel(radius: 30, tint: Palette.surface, tintOpacity: 0.30))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Palette.lineSoft.opacity(0.55), lineWidth: 1))
                .padding(.top, 14)

                // Bandeau contextuel ProgramGuidance (UV + heure + météo).
                CoachCard(message: ProgramGuidance.message(
                    uv: forecast.current,
                    hour: Calendar.current.component(.hour, from: .now),
                    condition: forecast.condition,
                    idealWindow: forecast.idealWindow))
                    .padding(.top, 14)

                // Phase + parcours en 3 étapes (compact, identique jour et soir).
                SunHero(motif: ClayIMG.leaf) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("\(phase.label) · \(phase.name)")
                                .font(SolaFont.body(12.5, weight: .bold)).foregroundStyle(Palette.amberDeep)
                            Spacer()
                            Pill(text: "Sem. \(store.currentWeek)/\(store.profile.targetWeeks)", variant: .accent, isData: true)
                        }
                        Text(phase.focus).font(SolaFont.display(19, weight: .heavy)).tracking(-0.4).foregroundStyle(Palette.ink)
                        HStack(spacing: 0) {
                            ForEach(Array(phaseNames.enumerated()), id: \.offset) { i, name in
                                phaseNode(index: i + 1, name: name)
                                if i < phaseNames.count - 1 {
                                    Rectangle()
                                        .fill(i + 1 < phase.index ? Palette.amber : Palette.lineSoft)
                                        .frame(height: 2).frame(maxWidth: .infinity)
                                        .offset(y: -9)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 14)

                if store.data.programStarted {
                    Button {
                        HapticsManager.shared.select()
                        showSession = true
                    } label: {
                        HStack(spacing: 10) {
                            Icon(name: evening ? "moon" : "sun", size: 19).foregroundStyle(Palette.onAmber)
                            Text(evening ? "Lancer ma routine du soir" : "Lancer ma séance")
                                .font(SolaFont.body(16, weight: .bold)).foregroundStyle(Palette.onAmber)
                        }
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Capsule().fill(Palette.amber))
                        .shadowSoft()
                    }
                    .buttonStyle(.plain)
                    .pressAnimation()
                    .padding(.top, 16)
                    HStack {
                        Text(evening ? "Ta routine du soir" : "Ta routine du jour")
                            .font(SolaFont.body(16, weight: .bold)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(doneCount) / \(steps.count) fait")
                            .font(SolaFont.body(13, weight: .bold)).foregroundStyle(Palette.amberDeep)
                            .contentTransition(.numericText())
                    }
                    .padding(.top, 18).padding(.bottom, 11)

                    VStack(spacing: 8) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                            let done = store.isRoutineDone(base + i)
                            Button {
                                HapticsManager.shared.select()
                                if evening && s.photo {
                                    showPicker = true
                                } else {
                                    withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) {
                                        store.toggleRoutine(base + i)
                                    }
                                }
                            } label: {
                                CardBox(fill: done ? Palette.surface2 : Palette.surface, padding: 11, shadow: !done) {
                                    HStack(spacing: 12) {
                                        stepBubble(s.num, done: done)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(s.title).font(SolaFont.body(14.5, weight: .bold)).foregroundStyle(Palette.ink)
                                                .strikethrough(done, color: Palette.ink3)
                                            Text(s.sub).font(SolaFont.body(12.5)).foregroundStyle(Palette.ink3)
                                        }
                                        Spacer(minLength: 0)
                                        HStack(spacing: 5) {
                                            Icon(name: "clock", size: 12).foregroundStyle(Palette.amberDeep)
                                            Text(s.meta).font(SolaFont.body(11.5, weight: .medium)).foregroundStyle(Palette.ink2)
                                                .lineLimit(1)
                                        }
                                        .layoutPriority(1)
                                        checkCircle(done: done)
                                    }
                                    .opacity(done ? 0.72 : 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .pressAnimation()
                        }
                    }
                    .animation(.spring(response: 0.34, dampingFraction: 0.62), value: doneCount)
                } else {
                    startProgramCard.padding(.top, 16)
                }

            }
            .padding(.horizontal, Frame.padH)
            .padding(.bottom, 84)
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showSession) {
            // Parcours guidé pas-à-pas. Jour : crème → face → dos → crème.
            // Soir : nettoie → after-sun → hydrate → photo. Coche la routine (10–13 / 20–23).
            GuidedSessionView(mode: evening ? .evening : .day,
                              safeMinutes: safeMin, uv: forecast.current, spf: spf)
        }
        .onChange(of: tab.requestSessionStart) { _, requested in
            // Le flag est posé alors que le Programme est déjà monté.
            guard requested else { return }
            consumeSessionRequest()
        }
        .onAppear {
            // Le flag a été posé avant que le Programme soit monté (bascule d'onglet).
            if tab.requestSessionStart { consumeSessionRequest() }
        }
        .task(id: locationKey) {
            await forecastStore.loadIfNeeded(lat: store.profile.latitude, lon: store.profile.longitude, city: store.profile.city)
        }
        .sheet(isPresented: $showPicker) { CameraPhotoPicker(image: $picked) }
        .onChange(of: picked) { _, img in
            // Photo (étape bonus du soir) : même flux que le Journal (PhotoStore + session).
            if let img, let name = PhotoStore.save(img) {
                store.addSession(TanSession(durationMinutes: 0, usedSPF: false, uvIndex: 0,
                                            note: "Suivi photo", photoFilename: name))
                if !store.isRoutineDone(23) { store.toggleRoutine(23) }
            }
        }
    }

    private var locationKey: String { "\(store.profile.latitude),\(store.profile.longitude)" }

    // L'arc des 3 phases sur la durée du plan (intégré à la carte de phase).
    private let phaseNames = ["Préparation", "Construction", "Entretien"]
    private func phaseNode(index: Int, name: String) -> some View {
        let done = index < phase.index
        let active = index == phase.index
        return VStack(spacing: 6) {
            ZStack {
                GlassCircle(tint: active ? Palette.amber : (done ? Palette.ink : Palette.surface),
                            tintOpacity: active ? 0.62 : (done ? 0.74 : 0.30))
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(active ? Color.clear : Palette.lineSoft, lineWidth: 1))
                if done { Icon(name: "check", size: 14, stroke: 3).foregroundStyle(Palette.gold) }
                else {
                    Text("\(index)").font(SolaFont.display(14, weight: .bold))
                        .foregroundStyle(active ? Palette.onAmber : Palette.ink3)
                }
            }
            Text(name).font(SolaFont.body(10.5, weight: active ? .bold : .regular))
                .foregroundStyle(active ? Palette.ink : Palette.ink3)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(width: 70)
    }

    private func segButton(_ title: String, icon: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) { Icon(name: icon, size: 15); Text(title) }
                .font(SolaFont.body(14, weight: .bold))
                .foregroundStyle(on ? Palette.onAmber : Palette.ink3)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(Capsule().fill(on ? Palette.amber : Color.clear))
        }.buttonStyle(.plain)
    }
    // Pastille de numéro qui bascule en coche quand l'étape est faite (pop animé).
    private func stepBubble(_ n: String, done: Bool) -> some View {
        ZStack {
            Circle().fill(done ? Palette.ink : Palette.tintAmber).frame(width: 30, height: 30)
            if done {
                Icon(name: "check", size: 15, stroke: 3).foregroundStyle(Palette.gold)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            } else {
                Text(n).font(SolaFont.display(15, weight: .bold)).foregroundStyle(Palette.bronze)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: done)
    }
    // Cercle à cocher (affordance d'interaction, à droite de chaque étape).
    private func checkCircle(done: Bool) -> some View {
        ZStack {
            Circle().fill(done ? Palette.amber : Color.clear)
                .overlay(Circle().stroke(done ? Palette.amber : Palette.line, lineWidth: 1.8))
                .frame(width: 24, height: 24)
            if done {
                Icon(name: "check", size: 13, stroke: 3).foregroundStyle(Palette.onAmber)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
        .scaleEffect(done ? 1.06 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: done)
    }
}

// MARK: - A4 · Indice UV (données live Open-Meteo)
struct AppUV: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var location: LocationManager
    @EnvironmentObject var notifications: NotificationManager
    @EnvironmentObject var forecastStore: ForecastStore
    private var forecast: UVForecast { forecastStore.forecast }

    private var uvLevel: String {
        switch forecast.current {
        case ..<3: return "Faible"; case ..<6: return "Modéré"
        case ..<8: return "Élevé"; case ..<11: return "Très élevé"; default: return "Extrême"
        }
    }
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            SectionLabel(text: "Aujourd'hui · \(store.profile.city)")
                            ScreenTitle(text: "Indice UV")
                        }
                        Spacer()
                        IconButton(icon: "pin", iconSize: 20) { location.request() }
                    }
                    .padding(.top, 4)

                    CardBox(fill: .clear, padding: 26, shadow: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(forecast.current.formatted(.number.precision(.fractionLength(0...1))))
                                        .font(SolaFont.display(64, weight: .heavy)).foregroundStyle(Palette.ink)
                                    Pill(text: uvLevel, icon: "flame", variant: .uv(forecast.current)).padding(.top, 8)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 0) {
                                    Icon(name: forecast.current >= 5 ? "sun" : "cloudSun", size: 42).foregroundStyle(Palette.amberDeep)
                                    Text("\(Int(forecast.temperature))°C · \(forecast.weatherLabel)").font(SolaFont.body(16, weight: .bold)).padding(.top, 8)
                                    Text("Max UV \(forecast.maxToday.formatted(.number.precision(.fractionLength(0...1))))").font(SolaFont.body(13)).foregroundStyle(Palette.ink2)
                                }
                            }
                            UvScale(position: min(1, forecast.current / 11), showLabels: true).padding(.top, 24)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(LinearGradient(colors: [Palette.tintGold, Palette.tintAmber], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .padding(.top, 18)
                    .overlay(alignment: .topTrailing) {
                        if forecastStore.isLoading { ProgressView().padding(20) }
                    }

                    CardBox {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("UV sur la journée").font(SolaFont.body(16, weight: .bold))
                                Spacer()
                                if forecast.peakHourIndex < forecast.hourly.count {
                                    Text("PIC \(forecast.hourly[forecast.peakHourIndex].hour)").font(SolaFont.mono(11.5)).foregroundStyle(Palette.ink3)
                                }
                            }
                            let maxUV = max(1, forecast.hourly.map(\.uv).max() ?? 1)
                            BarsChart(values: forecast.hourly.map { $0.uv / maxUV * 100 }, peakIndex: forecast.peakHourIndex).padding(.top, 18)
                            HStack {
                                ForEach(Array(forecast.hourly.enumerated()), id: \.offset) { _, h in
                                    Text(h.hour).font(SolaFont.mono(10)).foregroundStyle(Palette.ink3).frame(maxWidth: .infinity)
                                }
                            }.padding(.top, 8)
                        }
                    }
                    .padding(.top, 16)

                    CardBox(fill: Palette.ink) {
                        HStack(spacing: 14) {
                            Icon(name: "cloudSun", size: 26).foregroundStyle(Palette.onAmber)
                                .frame(width: 50, height: 50)
                                .background(GlassPanel(radius: 16, tint: Palette.gold, tintOpacity: 0.58))
                            VStack(alignment: .leading, spacing: 3) {
                                Eyebrow(text: "Meilleur créneau pour bronzer", color: Color(red: 1, green: 0.94, blue: 0.86).opacity(0.6))
                                Text(forecast.idealWindow).font(SolaFont.display(20, weight: .bold)).tracking(-0.3).foregroundStyle(.white)
                                Text("Assez d'UV pour bronzer, sans brûler").font(SolaFont.body(13)).foregroundStyle(Color(red: 1, green: 0.94, blue: 0.86).opacity(0.7))
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.top, 16)
                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, Frame.padH)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task(id: locationKey) { await loadForecast() }
        .onReceive(location.$coordinate.compactMap { $0 }) { coord in
            store.profile.latitude = coord.latitude
            store.profile.longitude = coord.longitude
        }
        .onReceive(location.$city.compactMap { $0 }) { store.profile.city = $0 }
    }
    private var locationKey: String { "\(store.profile.latitude),\(store.profile.longitude)" }
    private func loadForecast() async {
        // Source unique : un seul fetch partagé (widget publié à la source).
        await forecastStore.loadIfNeeded(lat: store.profile.latitude, lon: store.profile.longitude, city: store.profile.city)
        // Active le rappel « fenêtre idéale » si l'utilisateur l'a demandé.
        if store.data.notifPrefs.uvWindow && notifications.authorized {
            notifications.scheduleUVWindow(at: forecast.idealWindow)
        }
        // Alerte de pic UV élevé du jour (no-op si sous le seuil ou alertes désactivées).
        if store.data.notifPrefs.burnAlerts && notifications.authorized {
            notifications.scheduleUVPeakAlert(maxToday: forecast.maxToday, window: forecast.idealWindow)
        }
    }
}

// Barre d'échelle UV (dégradé vert→rouge + curseur)
struct UVBar: View {
    var position: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(LinearGradient(colors: [
                    Color(oklch: 0.82, 0.13, 145), Color(oklch: 0.86, 0.14, 95),
                    Color(oklch: 0.80, 0.15, 60), Color(oklch: 0.68, 0.17, 35),
                    Color(oklch: 0.55, 0.18, 12)
                ], startPoint: .leading, endPoint: .trailing))
                .frame(height: 12)
                Circle().fill(.white)
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 3))
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                    .offset(x: geo.size.width * position - 10)
            }
        }
        .frame(height: 20)
    }
}
