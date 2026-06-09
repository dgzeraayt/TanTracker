import SwiftUI

enum HomeRoute: Hashable { case profile, reco, achievements, analytics, challenges, personalization, settings }

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
    private let routine: [(String, String)] = [
        ("Exposé","sun"), ("SPF 30","shield"), ("Hydrater","drop"),
        ("After-sun","leaf"), ("Photo","camera")
    ]
    private var hueLabel: String {
        solaHueLabel(store.currentTanIndex, newline: true).uppercased()
    }
    private var heroLead: String {
        store.todayHasExposure
            ? "Dose UV du jour validée. Belle progression !"
            : "Pas encore d'exposition aujourd'hui — vise ta fenêtre idéale."
    }
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        DisplayText(text: "BONJOUR\n\(store.profile.firstName) !", size: 42)
                        Spacer()
                        HStack(spacing: 8) {
                            IconButton(icon: "bell") {
                                Task { _ = await notifications.requestAuthorization() }
                            }
                            NavigationLink(value: HomeRoute.profile) { AvatarView() }
                        }
                    }
                    .padding(.top, 4)

                    // hero score card
                    NavigationLink(value: HomeRoute.reco) {
                        CardBox(padding: 26) {
                            VStack(spacing: 0) {
                                Eyebrow(text: "Ton bronzage aujourd'hui").frame(maxWidth: .infinity)
                                HStack(spacing: 20) {
                                    Gauge(value: store.currentTanIndex, size: 132, label: "Indice", sub: store.tanLevelLabel)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("Ta teinte est").font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.ink3)
                                        Text(hueLabel).font(SolaFont.display(24, weight: .bold))
                                            .tracking(-0.7).foregroundStyle(Palette.ink).padding(.top, 3)
                                        LeadText(text: heroLead, size: 13.5).padding(.top, 8)
                                    }
                                }
                                .padding(.top, 16)
                                PillLabelButton(title: "Voir le détail").padding(.top, 18).allowsHitTesting(false)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)

                    // plan progress
                    CardBox(padding: 18) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 0) {
                                Eyebrow(text: "Progression du plan")
                                Text("\(Int(store.planProgress * 100))%").font(SolaFont.display(38, weight: .heavy)).foregroundStyle(Palette.ink).padding(.top, 6)
                                Track(value: store.planProgress).padding(.top, 10)
                                Text("Semaine \(store.currentWeek)/\(store.profile.targetWeeks) · objectif \(store.profile.goal.title.lowercased())")
                                    .font(SolaFont.body(13)).foregroundStyle(Palette.ink3).padding(.top, 9)
                            }
                            RemoteImage(url: IMG.shoulders, tone: .warm)
                                .frame(width: 96, height: 110).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    .padding(.top, 14)

                    // routine (cochable + persistée)
                    let completedCount = store.todayRoutine().completed.filter { $0 < 5 }.count
                    let isComplete = completedCount == 5
                    HStack {
                        Text("Routine du jour").font(SolaFont.display(20, weight: .bold)).tracking(-0.3)
                        Spacer()
                        Text("\(completedCount)/5")
                            .font(SolaFont.mono(12.5)).foregroundStyle(isComplete ? Palette.gold : Palette.ink3)
                    }
                    .padding(.top, 20).padding(.bottom, 14)
                    HStack {
                        ForEach(Array(routine.enumerated()), id: \.offset) { i, r in
                            let done = store.isRoutineDone(i)
                            Button {
                                HapticsManager.shared.tap()
                                store.toggleRoutine(i)
                                if isComplete {
                                    HapticsManager.shared.celebration()
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Icon(name: done ? "check" : r.1, size: done ? 22 : 23, stroke: done ? 2.6 : 1.7)
                                        .foregroundStyle(done ? Palette.gold : Palette.bronze)
                                        .frame(width: 52, height: 52)
                                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(done ? Palette.ink : Palette.surface))
                                        .modifier(ConditionalShadow(on: !done))
                                    Text(r.0).font(SolaFont.body(11.5, weight: .semibold))
                                        .foregroundStyle(done ? Palette.ink : Palette.ink3)
                                }
                                .frame(maxWidth: .infinity)
                                .celebration(done && isComplete)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Célébration si routine complète
                    if isComplete {
                        HStack(spacing: 10) {
                            Icon(name: "sparkle", size: 18).foregroundStyle(Palette.gold)
                            Text("Routine complète ! Bravo 💪")
                                .font(SolaFont.body(14, weight: .semibold))
                                .foregroundStyle(Palette.gold)
                            Spacer()
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(Palette.gold.opacity(0.15)))
                        .padding(.top, 12)
                        .transition(.slideInFromBottom(true))
                    }

                    // AM / PM
                    HStack(spacing: 14) {
                        ampmCard(tint: Palette.tintGold, accent: Palette.amberDeep, icon: "sun",
                                 label: "MATIN", title: "PROTÉGER\n& EXPOSER")
                        ampmCard(tint: Palette.tintTerra, accent: Palette.terra, icon: "moon",
                                 label: "SOIR", title: "RÉPARER\n& HYDRATER")
                    }
                    .padding(.top, 20)

                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, Frame.padH)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .profile: AppProfile()
            case .reco: AppReco()
            case .achievements: AppAchievements()
            case .analytics: AnalyticsDashboard()
            case .challenges: AppChallenges()
            case .personalization: AppPersonalization()
            case .settings: AppSettings()
            }
        }
    }

    private func ampmCard(tint: Color, accent: Color, icon: String, label: String, title: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(tint)
            VStack(alignment: .leading) {
                HStack(spacing: 8) {
                    Icon(name: icon, size: 17)
                    Text(label).font(SolaFont.mono(10.5)).tracking(0.5)
                }
                .foregroundStyle(accent)
                Spacer()
                Text(title).font(SolaFont.display(17, weight: .bold)).tracking(-0.3).foregroundStyle(Palette.ink)
            }
            .padding(16)
        }
        .frame(height: 132)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - A3 · Plan du jour (dérivé du phototype + UV réel)
struct AppPlan: View {
    @EnvironmentObject var store: AppStore
    @State private var evening = false
    @State private var forecast: UVForecast = .sample
    @State private var showTimer = false

    // index de routine : 10–13 réservés au plan « jour », 20–23 au plan « soir »
    private var base: Int { evening ? 20 : 10 }
    private var safeMin: Int { store.safeMinutes(uv: forecast.current) }
    private var perFace: Int { max(1, safeMin / 2) }
    private var spf: Int { store.profile.phototype.recommendedSPF }

    // (numéro, titre, sous-titre, méta, icône)
    private var steps: [(String, String, String, String, String)] {
        if evening {
            return [
                ("1","Nettoyer la peau","Retire SPF et impuretés","Au retour","drop"),
                ("2","After-sun · Aloe vera","Apaise et prolonge la teinte","Dans l'heure","leaf"),
                ("3","Hydrater","Crème riche sur les zones exposées","Avant le coucher","drop"),
                ("4","Photo de suivi","Documente ta progression","Optionnel","camera")
            ]
        }
        return [
            ("1","Crème solaire SPF \(spf)","Protection large spectre","Avant de sortir","sun"),
            ("2","Exposition · \(safeMin) min","Face avant · \(perFace) min",forecast.idealWindow,"timer"),
            ("3","Retournement","Face arrière · \(perFace) min","À mi-parcours","refresh"),
            ("4","Réappliquer SPF \(spf)","Baignade ou transpiration","Toutes les 2h","shield")
        ]
    }
    private var doneCount: Int { (0..<steps.count).filter { store.isRoutineDone(base + $0) }.count }
    private var headerTitle: String {
        evening ? "Routine du soir" : "Fenêtre \(forecast.idealWindow)"
    }
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        IconButton(icon: evening ? "moon" : "sun", ink: true, iconSize: 20)
                        Spacer()
                        Badge(text: "UV \(forecast.current.formatted(.number.precision(.fractionLength(0...1))))", icon: "sparkle")
                    }
                    .padding(.top, 4)

                    HStack(spacing: 0) {
                        segButton("Jour", icon: "sun", on: !evening) { evening = false }
                        segButton("Soir", icon: "moon", on: evening) { evening = true }
                    }
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Palette.surface2)
                        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Palette.lineSoft, lineWidth: 1)))
                    .padding(.top, 14)

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow(text: "Plan du jour · \(steps.count) étapes · phototype \(store.profile.phototype.roman)")
                            Text(headerTitle).font(SolaFont.display(20, weight: .bold)).tracking(-0.3)
                        }
                        Spacer()
                        Badge(text: "\(doneCount)/\(steps.count) fait", style: .amber)
                    }
                    .padding(.top, 16)
                    Track(value: Double(doneCount) / Double(steps.count)).padding(.top, 12)

                    VStack(spacing: 8) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                            let done = store.isRoutineDone(base + i)
                            Button { store.toggleRoutine(base + i) } label: {
                                CardBox(fill: done ? Palette.surface2 : Palette.surface, padding: 12, shadow: !done) {
                                    HStack(spacing: 14) {
                                        stepBubble(s.0, done: done)
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(s.1).font(SolaFont.body(16, weight: .bold)).foregroundStyle(Palette.ink)
                                            Text(s.2).font(SolaFont.body(13)).foregroundStyle(Palette.ink3)
                                            HStack(spacing: 6) {
                                                Icon(name: "clock", size: 13).foregroundStyle(Palette.amberDeep)
                                                Text(s.3).font(SolaFont.mono(11.5)).foregroundStyle(Palette.ink2)
                                            }.padding(.top, 5)
                                        }
                                        Spacer(minLength: 0)
                                        Icon(name: s.4, size: 20).foregroundStyle(Palette.bronze)
                                            .frame(width: 42, height: 42)
                                            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Palette.bgWarm))
                                    }
                                    .opacity(done ? 0.72 : 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 14)

                    if !evening {
                        ZStack(alignment: .bottomLeading) {
                            RemoteImage(url: IMG.position, tone: .deep).frame(height: 104)
                            LinearGradient(colors: [.black.opacity(0.78), .black.opacity(0)], startPoint: .bottom, endPoint: .top)
                            VStack(alignment: .leading, spacing: 4) {
                                Eyebrow(text: "Conseil position", color: .white.opacity(0.7))
                                Text("ÉPAULES EN RETRAIT").font(SolaFont.display(21, weight: .bold)).tracking(-0.7).foregroundStyle(.white)
                            }
                            .padding(.horizontal, 18).padding(.bottom, 14)
                        }
                        .frame(height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        .padding(.top, 14)

                        PillLabelButton(title: "Lancer le minuteur", icon: "timer") { showTimer = true }
                            .padding(.top, 12)
                    }
                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, Frame.padH)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task(id: locationKey) { forecast = await UVService.fetch(lat: store.profile.latitude, lon: store.profile.longitude) }
        .fullScreenCover(isPresented: $showTimer) {
            ExposureTimerView(safeMinutes: safeMin, uv: forecast.current)
        }
    }
    private var locationKey: String { "\(store.profile.latitude),\(store.profile.longitude)" }

    private func segButton(_ title: String, icon: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) { Icon(name: icon, size: 15); Text(title.uppercased()) }
                .font(SolaFont.body(13, weight: .bold)).tracking(1)
                .foregroundStyle(on ? Palette.onAmber : Palette.ink3)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(Capsule().fill(on ? Palette.amber : Color.clear))
        }.buttonStyle(.plain)
    }
    private func stepBubble(_ n: String, done: Bool) -> some View {
        ZStack {
            Circle().fill(done ? Palette.ink : Palette.tintAmber).frame(width: 30, height: 30)
            if done { Icon(name: "check", size: 15, stroke: 3).foregroundStyle(Palette.gold) }
            else { Text(n).font(SolaFont.display(15, weight: .bold)).foregroundStyle(Palette.bronze) }
        }
    }
}

// MARK: - A4 · Indice UV (données live Open-Meteo)
struct AppUV: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var location: LocationManager
    @EnvironmentObject var notifications: NotificationManager
    @State private var forecast: UVForecast = .sample
    @State private var loading = true

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
                            Eyebrow(text: "Aujourd'hui · \(store.profile.city)")
                            Text("Indice UV").font(SolaFont.display(27, weight: .bold)).tracking(-0.7)
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
                                    Badge(text: uvLevel, icon: "flame", style: .amber).padding(.top, 8)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 0) {
                                    Icon(name: forecast.current >= 5 ? "sun" : "cloudSun", size: 42).foregroundStyle(Palette.amberDeep)
                                    Text("\(Int(forecast.temperature))°C · \(forecast.weatherLabel)").font(SolaFont.body(16, weight: .bold)).padding(.top, 8)
                                    Text("Max UV \(forecast.maxToday.formatted(.number.precision(.fractionLength(0...1))))").font(SolaFont.body(13)).foregroundStyle(Palette.ink3)
                                }
                            }
                            UVBar(position: min(1, forecast.current / 11)).padding(.top, 24)
                            HStack {
                                Text("FAIBLE"); Spacer(); Text("MODÉRÉ"); Spacer(); Text("ÉLEVÉ"); Spacer(); Text("EXTRÊME")
                            }
                            .font(SolaFont.mono(10.5)).foregroundStyle(Palette.onAmber.opacity(0.6)).padding(.top, 10)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(LinearGradient(colors: [Palette.tintGold, Palette.tintAmber], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .padding(.top, 18)
                    .overlay(alignment: .topTrailing) {
                        if loading { ProgressView().padding(20) }
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
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.gold))
                            VStack(alignment: .leading, spacing: 3) {
                                Eyebrow(text: "Fenêtre idéale", color: Color(red: 1, green: 0.94, blue: 0.86).opacity(0.6))
                                Text(forecast.idealWindow).font(SolaFont.display(20, weight: .bold)).tracking(-0.3).foregroundStyle(.white)
                                Text("UV modéré · bronzage sûr").font(SolaFont.body(13)).foregroundStyle(Color(red: 1, green: 0.94, blue: 0.86).opacity(0.7))
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
        loading = true
        forecast = await UVService.fetch(lat: store.profile.latitude, lon: store.profile.longitude)
        loading = false
        // Active le rappel « fenêtre idéale » si l'utilisateur l'a demandé.
        if store.data.notifPrefs.uvWindow && notifications.authorized {
            notifications.scheduleUVWindow(at: forecast.idealWindow)
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
