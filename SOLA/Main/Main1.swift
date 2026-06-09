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
    @State private var forecast: UVForecast = .sample
    @State private var showSession = false
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
                        ScreenTitle(text: "Bonjour\n\(store.profile.firstName) !")
                        Spacer()
                        HStack(spacing: 8) {
                            IconButton(icon: "bell") {
                                Task { _ = await notifications.requestAuthorization() }
                            }
                            NavigationLink(value: HomeRoute.profile) { AvatarView() }
                        }
                    }
                    .padding(.top, 4)

                    // hero : bronzage + dose du jour réunis dans une seule carte
                    NavigationLink(value: HomeRoute.reco) {
                        CardBox(padding: 20) {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Eyebrow(text: "Ton bronzage aujourd'hui")
                                    Spacer()
                                    Icon(name: "chevR", size: 16).foregroundStyle(Palette.ink3)
                                }
                                HStack(spacing: 18) {
                                    Gauge(value: store.currentTanIndex, size: 112, label: "Bronzage", sub: store.tanLevelLabel)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("Ta teinte est").font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.ink3)
                                        Text(hueLabel).font(SolaFont.display(22, weight: .bold))
                                            .tracking(-0.6).foregroundStyle(Palette.ink).padding(.top, 3)
                                        LeadText(text: heroLead, size: 13).padding(.top, 6)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.top, 14)

                                Rectangle().fill(Palette.lineSoft).frame(height: 1).padding(.top, 16)

                                // Dose du jour (B1) : dose UV cumulée vs seuil sûr du phototype
                                DoseCard(dose: store.todayDose(currentUV: forecast.current))
                                    .padding(.top, 14)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 18)

                    // CTA session active (B2) : « Je bronze maintenant »
                    Button { HapticsManager.shared.select(); showSession = true } label: {
                        HStack(spacing: 12) {
                            Icon(name: "sun", size: 22).foregroundStyle(Palette.onAmber)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Je bronze maintenant").font(SolaFont.cardTitle).foregroundStyle(Palette.onAmber)
                                Text("Minuteur & alertes · \(store.safeMinutes(uv: forecast.current)) min max sans coup de soleil")
                                    .font(SolaFont.caption).foregroundStyle(Palette.onAmber.opacity(0.8))
                            }
                            Spacer(minLength: 0)
                            Icon(name: "chevR", size: 18).foregroundStyle(Palette.onAmber.opacity(0.8))
                        }
                        .padding(.horizontal, 18).frame(height: 70)
                        .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Palette.amber))
                        .shadowSoft()
                    }
                    .buttonStyle(.plain)
                    .pressAnimation()
                    .padding(.top, 12)

                    // Coaching contextuel (B3)
                    CoachCard(message: Coach.message(
                        uv: forecast.current,
                        dose: store.todayDose(currentUV: forecast.current),
                        idealWindow: forecast.idealWindow,
                        hour: Calendar.current.component(.hour, from: .now),
                        hasExposureToday: store.todayHasExposure))
                        .padding(.top, 12)

                    // plan progress (compact : %, barre, semaine, objectif)
                    CardBox(padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Eyebrow(text: "Ton plan sur \(store.profile.targetWeeks) semaines")
                                Spacer()
                                Pill(text: "Semaine \(store.currentWeek)", variant: .accent, isData: true)
                            }
                            HStack(spacing: 12) {
                                Text("\(Int(store.planProgress * 100))%")
                                    .font(SolaFont.display(24, weight: .heavy)).foregroundStyle(Palette.ink)
                                Track(value: store.planProgress)
                            }
                            Text("Objectif : \(store.profile.goal.title.lowercased())")
                                .font(SolaFont.body(12.5)).foregroundStyle(Palette.ink3)
                        }
                    }
                    .padding(.top, 12)

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
        .task(id: locationKey) {
            forecast = await UVService.fetch(lat: store.profile.latitude, lon: store.profile.longitude)
            WidgetBridge.publish(forecast: forecast, city: store.profile.city)
        }
        .fullScreenCover(isPresented: $showSession) {
            ExposureTimerView(safeMinutes: store.safeMinutes(uv: forecast.current), uv: forecast.current)
        }
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

    // (numéro, titre, sous-titre, méta)
    private var steps: [(String, String, String, String)] {
        if evening {
            return [
                ("1","Nettoie ta peau","Retire crème, sel et chlore","Au retour"),
                ("2","Applique de l'after-sun","Apaise et fait durer le bronzage","Dans l'heure"),
                ("3","Hydrate-toi","Crème riche sur les zones exposées","Avant le coucher"),
                ("4","Prends une photo","Pour suivre ta progression","Optionnel")
            ]
        }
        return [
            ("1","Mets ta crème SPF \(spf)","Sur toutes les zones exposées","Avant de sortir"),
            ("2","Bronze \(safeMin) min max","Commence côté face · \(perFace) min",forecast.idealWindow),
            ("3","Retourne-toi","Côté dos · \(perFace) min","À mi-temps"),
            ("4","Remets de la crème","Surtout après une baignade","Toutes les 2h")
        ]
    }
    private var doneCount: Int { (0..<steps.count).filter { store.isRoutineDone(base + $0) }.count }
    private var phase: PlanPhase {
        PlanProgram.phase(week: store.currentWeek, targetWeeks: store.profile.targetWeeks,
                          phototype: store.profile.phototype, goal: store.profile.goal)
    }
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        ScreenTitle(text: "Ton plan")
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
                    .padding(.top, 16)

                    // Phase du programme (B5) — compact : focus, barre, repères, conseil
                    if !evening {
                        CardBox(padding: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    SectionLabel(text: phase.label + " · " + phase.name)
                                    Spacer()
                                    Pill(text: "Sem. \(store.currentWeek)/\(store.profile.targetWeeks)", variant: .accent, isData: true)
                                }
                                Text(phase.focus).font(SolaFont.body(15.5, weight: .bold)).foregroundStyle(Palette.ink)
                                Track(value: store.planProgress, height: 7)
                                HStack(spacing: 14) {
                                    HStack(spacing: 5) {
                                        Icon(name: "timer", size: 12).foregroundStyle(Palette.amberDeep)
                                        Text("~\(phase.dailyMinutes) min de soleil/jour").font(SolaFont.body(12, weight: .semibold)).foregroundStyle(Palette.ink2)
                                    }
                                    HStack(spacing: 5) {
                                        Icon(name: "cloudSun", size: 12).foregroundStyle(Palette.amberDeep)
                                        Text("Idéal \(forecast.idealWindow)").font(SolaFont.body(12, weight: .semibold)).foregroundStyle(Palette.ink2)
                                    }
                                }
                                HStack(spacing: 5) {
                                    Icon(name: "shield", size: 12).foregroundStyle(Palette.amberDeep)
                                    Text(phase.tip).font(SolaFont.body(11.5)).foregroundStyle(Palette.ink3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.top, 12)
                    }

                    HStack(alignment: .center) {
                        Eyebrow(text: evening ? "Ta routine du soir" : "Ta routine soleil, adaptée à ta peau")
                        Spacer()
                        Badge(text: "\(doneCount)/\(steps.count) fait", style: .amber)
                    }
                    .padding(.top, 14)
                    Track(value: Double(doneCount) / Double(steps.count), height: 7).padding(.top, 9)

                    VStack(spacing: 7) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                            let done = store.isRoutineDone(base + i)
                            Button { store.toggleRoutine(base + i) } label: {
                                CardBox(fill: done ? Palette.surface2 : Palette.surface, padding: 11, shadow: !done) {
                                    HStack(spacing: 12) {
                                        stepBubble(s.0, done: done)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(s.1).font(SolaFont.body(14.5, weight: .bold)).foregroundStyle(Palette.ink)
                                            Text(s.2).font(SolaFont.body(12.5)).foregroundStyle(Palette.ink3)
                                        }
                                        Spacer(minLength: 0)
                                        HStack(spacing: 5) {
                                            Icon(name: "clock", size: 12).foregroundStyle(Palette.amberDeep)
                                            Text(s.3).font(SolaFont.body(11.5, weight: .medium)).foregroundStyle(Palette.ink2)
                                                .lineLimit(1)
                                        }
                                        .layoutPriority(1)
                                    }
                                    .opacity(done ? 0.72 : 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 12)

                    if !evening {
                        ZStack(alignment: .leading) {
                            RemoteImage(url: IMG.position, tone: .deep).frame(height: 58)
                            LinearGradient(colors: [.black.opacity(0.72), .black.opacity(0.18)], startPoint: .leading, endPoint: .trailing)
                            VStack(alignment: .leading, spacing: 2) {
                                Eyebrow(text: "Pour bronzer uniforme", color: .white.opacity(0.7))
                                Text("CHANGE DE POSITION SOUVENT").font(SolaFont.display(15, weight: .bold)).tracking(-0.4).foregroundStyle(.white)
                            }
                            .padding(.horizontal, 16)
                        }
                        .frame(height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .padding(.top, 12)

                        PillLabelButton(title: "Lancer le minuteur", icon: "timer") { showTimer = true }
                            .padding(.top, 10)
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
        loading = true
        forecast = await UVService.fetch(lat: store.profile.latitude, lon: store.profile.longitude)
        loading = false
        // Publie vers le widget (App Group).
        WidgetBridge.publish(forecast: forecast, city: store.profile.city)
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
