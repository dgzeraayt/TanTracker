import SwiftUI
import StoreKit

// MARK: - 15 · Goal
struct ScrGoal: View {
    @EnvironmentObject var store: AppStore
    private let opts: [TanGoal] = [.subtleGlow, .deepTan, .maintain, .safe]
    var body: some View {
        OnbQuestion(step: 9, eyebrow: "Ton objectif", title: "Quelle teinte vises-tu ?",
                    sub: "On calibre ton plan d'exposition sur cet objectif.") {
            ForEach(opts, id: \.self) { g in
                OptionRow(asset: asset(for: g), title: g.title, sub: g.subtitle, selected: store.profile.goal == g)
                    .onTapGesture { store.profile.goal = g }
            }
        }
    }

    private func asset(for goal: TanGoal) -> String {
        switch goal {
        case .subtleGlow: return ClayIMG.sun
        case .deepTan: return ClayIMG.flame
        case .maintain: return ClayIMG.timer
        case .safe: return ClayIMG.shield
        }
    }
}

// MARK: - 16 · Current tan level
struct ScrTanLevel: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var store: AppStore
    private let shades = [
        Color(oklch: 0.90, 0.035, 72), Color(oklch: 0.83, 0.055, 68), Color(oklch: 0.75, 0.07, 64),
        Color(oklch: 0.66, 0.08, 60), Color(oklch: 0.56, 0.08, 56)
    ]
    private let labels = ["Très clair","Légèrement hâlé","Hâlé","Bien doré","Bronzé"]
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                OnbTop(step: 10, total: 16)
                Eyebrow(text: "Point de départ").padding(.bottom, 12)
                DisplayText(text: "Ta teinte actuelle ?", size: 38)
                LeadText(text: "On suivra ta progression à partir d'ici.").padding(.top, 14)
                GeometryReader { proxy in
                    ZStack {
                        ForEach(IMG.tintLevels.indices, id: \.self) { i in
                            RemoteImage(url: IMG.tintLevels[i], tone: .warm)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                                .opacity(i == store.profile.startTanLevel ? 1 : 0)
                        }
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .animation(.easeInOut(duration: 0.22), value: store.profile.startTanLevel)
                .padding(.top, 26)
                HStack(spacing: 8) {
                    ForEach(Array(shades.enumerated()), id: \.offset) { i, s in
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(s)
                            .frame(height: 56)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Palette.ink, lineWidth: i == store.profile.startTanLevel ? 3 : 0))
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    store.profile.startTanLevel = i
                                }
                            }
                    }
                }
                .padding(.top, 18)
                HStack {
                    Text("CLAIR").font(SolaFont.mono(11)).foregroundStyle(Palette.ink3)
                    Spacer()
                    Badge(text: "Niveau \(store.profile.startTanLevel + 1) · \(labels[store.profile.startTanLevel])", style: .amber)
                    Spacer()
                    Text("BRONZÉ").font(SolaFont.mono(11)).foregroundStyle(Palette.ink3)
                }
                .padding(.top, 16)
                Spacer()
                SolaButton(title: "Continuer") { ctrl.next { flow.finishOnboarding() } }.padding(.bottom, 18)
            }
            .padding(.horizontal, Frame.padH)
        }
    }
}

// MARK: - 17 · Where
struct ScrWhere: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var store: AppStore
    private let places: [(String, String)] = [
        ("Plage / mer", ClayIMG.beach), ("Piscine", ClayIMG.pool), ("Jardin / balcon", ClayIMG.leaf),
        ("Cabine UV", ClayIMG.thermo), ("Autobronzant", ClayIMG.skinPalette), ("Montagne / ski", ClayIMG.mountain)
    ]
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                OnbTop(step: 11, total: 16)
                Eyebrow(text: "Tes habitudes").padding(.bottom, 12)
                DisplayText(text: "Où bronzes-tu le plus ?", size: 38)
                LeadText(text: "Plusieurs choix possibles.").padding(.top, 14)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)], spacing: 11) {
                    ForEach(Array(places.enumerated()), id: \.offset) { i, p in
                        PillOption(selected: store.profile.places.contains(i), label: p.0) {
                            ClayAssetImage(name: p.1, size: 64)
                                .frame(height: 62)
                        }
                        .onTapGesture {
                            if store.profile.places.contains(i) { store.profile.places.remove(i) }
                            else { store.profile.places.insert(i) }
                        }
                    }
                }
                .padding(.top, 26)
                Spacer()
                SolaButton(title: "Continuer") { ctrl.next { flow.finishOnboarding() } }.padding(.bottom, 18)
            }
            .padding(.horizontal, Frame.padH)
        }
    }
}

// MARK: - 18 · Frequency
struct ScrFrequency: View {
    @EnvironmentObject var store: AppStore
    private let opts: [(String, String, String?)] = [
        (ClayIMG.sun,"Tous les jours","Dès qu'il y a du soleil"),
        (ClayIMG.cloudSun,"Plusieurs fois par semaine", nil),
        (ClayIMG.timer,"Le week-end surtout", nil),
        (ClayIMG.beach,"En vacances seulement", nil)
    ]
    var body: some View {
        OnbQuestion(step: 12, eyebrow: "Tes habitudes", title: "À quelle fréquence t'exposes-tu ?") {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, o in
                OptionRow(asset: o.0, title: o.1, sub: o.2, selected: store.profile.frequency == i)
                    .onTapGesture { store.profile.frequency = i }
            }
        }
    }
}

// MARK: - 19 · Concerns (multi)
struct ScrConcerns: View {
    @EnvironmentObject var store: AppStore
    private let opts: [(String, String, String?)] = [
        (ClayIMG.flame,"Coups de soleil","Je rougis vite"),
        (ClayIMG.timer,"Vieillissement prématuré", nil),
        (ClayIMG.freckles,"Taches pigmentaires", nil),
        (ClayIMG.skinPalette,"Bronzage irrégulier", nil)
    ]
    var body: some View {
        OnbQuestion(step: 13, eyebrow: "Sécurité de la peau", title: "Tes préoccupations ?",
                    sub: "On renforcera les alertes en conséquence.") {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, o in
                OptionRow(asset: o.0, title: o.1, sub: o.2, selected: store.profile.concerns.contains(i))
                    .onTapGesture {
                        if store.profile.concerns.contains(i) { store.profile.concerns.remove(i) }
                        else { store.profile.concerns.insert(i) }
                    }
            }
        }
    }
}

// MARK: - 20 · SPF habits
struct ScrSPF: View {
    @EnvironmentObject var store: AppStore
    private let opts: [(String, String, String?)] = [
        (ClayIMG.sun,"Jamais","Ça empêche de bronzer, non ?"),
        (ClayIMG.beach,"Seulement à la plage", nil),
        (ClayIMG.cloudSun,"Les jours de grand soleil", nil),
        (ClayIMG.shield,"Tous les jours","Bravo, continue !")
    ]
    var body: some View {
        OnbQuestion(step: 14, eyebrow: "Sécurité de la peau", title: "Tu mets de la crème solaire…") {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, o in
                OptionRow(asset: o.0, title: o.1, sub: o.2, selected: store.profile.spfHabit == i)
                    .onTapGesture { store.profile.spfHabit = i }
            }
        }
    }
}

// MARK: - 20b · Risques sans protection
struct ScrRisks: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @State private var isAnimating = false

    // 3 risques, un mot-clé chacun : l'écran porte un message, pas une liste.
    private let risks: [(String, String)] = [
        (ClayIMG.flame, "Coups de soleil"),
        (ClayIMG.timer, "Vieillissement prématuré"),
        (ClayIMG.shield, "Risque de cancer cutané")
    ]

    var body: some View {
        ScreenScaffold(
            background: LinearGradient(colors: [
                Color(oklch: 0.30, 0.08, 38), Color(oklch: 0.18, 0.04, 42)
            ], startPoint: .top, endPoint: .bottom),
            lightStatusBar: true
        ) {
            VStack(alignment: .leading, spacing: 0) {
                OnbTop(step: 14, total: 16, onlyBack: true)

                Spacer()

                Eyebrow(text: "Le soleil sans limite", color: Color(oklch: 0.74, 0.16, 36))
                    .padding(.bottom, 12)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 10)
                DisplayText(text: "Bronzer oui.\nBrûler, non.", size: 44, color: .white)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 10)
                LeadText(text: "Sans dose maîtrisée, ta peau paie le prix :",
                         color: .white.opacity(0.78))
                    .padding(.top, 14)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 10)

                // Liste légère : icône + mot, séparées par un trait fin.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(risks.enumerated()), id: \.offset) { i, r in
                        HStack(spacing: 14) {
                            ClayAssetImage(name: r.0, size: 34)
                                .frame(width: 36)
                            Text(r.1)
                                .font(SolaFont.body(16.5, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 15)
                        if i < risks.count - 1 {
                            Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
                        }
                    }
                }
                .padding(.top, 12)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 14)

                // Une seule carte solution : le message, pas la feature-list.
                HStack(spacing: 14) {
                    ClayAssetTile(name: ClayIMG.shield, size: 42, tile: 50, selected: true)
                    Text("SUNY calcule ta dose sûre du jour et t'alerte avant la brûlure.")
                        .font(SolaFont.body(15, weight: .medium))
                        .foregroundStyle(.white)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.gold.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Palette.gold.opacity(0.30), lineWidth: 1)))
                .padding(.top, 22)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 18)

                Spacer()

                SolaButton(title: "Bronzer en sécurité", kind: .amber) { ctrl.next { flow.finishOnboarding() } }
                    .padding(.bottom, 16)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
            }
            .padding(.horizontal, Frame.padH)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) { isAnimating = true }
        }
    }
}

// MARK: - 21 · Location
struct ScrLocation: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var location: LocationManager

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                OnbTop(step: 15, total: 16)
                Eyebrow(text: "Données UV locales").padding(.bottom, 12)
                DisplayText(text: "Où es-tu ?", size: 38)
                LeadText(text: "Pour l'indice UV, la météo et le créneau d'exposition idéal de ta région.").padding(.top, 14)
                ZStack {
                    RemoteImage(url: IMG.coast)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(.black.opacity(0.22))
                        .frame(height: 200)
                    Icon(name: "pin", size: 26).foregroundStyle(Palette.gold)
                        .frame(width: 54, height: 54).background(Circle().fill(Palette.ink))
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
                }
                .padding(.top, 26)
                CardBox(padding: 18) {
                    HStack(spacing: 14) {
                        Icon(name: "pin", size: 22).foregroundStyle(Palette.terra)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(store.profile.city).font(SolaFont.body(16, weight: .bold))
                            Text(location.coordinate == nil ? "À détecter" : "Détecté automatiquement")
                                .font(SolaFont.body(13)).foregroundStyle(Palette.ink3)
                        }
                        Spacer()
                        Text("Modifier").font(SolaFont.mono(12)).foregroundStyle(Palette.ink3)
                    }
                }
                .padding(.top, 18)
                Spacer()
                SolaButton(title: "Continuer", icon: "pin") {
                    location.request()
                    ctrl.next { flow.finishOnboarding() }
                }
                .padding(.bottom, 18)
            }
            .padding(.horizontal, Frame.padH)
        }
        // Le dialogue natif de localisation s'affiche dès cet écran (pas après
        // « Continuer »). request() est idempotent : sans effet si déjà répondu.
        .onAppear { location.request() }
        .onReceive(location.$coordinate.compactMap { $0 }) { coord in
            store.profile.latitude = coord.latitude
            store.profile.longitude = coord.longitude
        }
        .onReceive(location.$city.compactMap { $0 }) { c in store.profile.city = c }
    }
}

// MARK: - 22 · Notifications
struct ScrNotif: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager
    private let previews: [(String, String, String, String)] = [
        (ClayIMG.shield, "SPF à renouveler", "Tu es au soleil depuis 1h40. Remets une couche dans 20 min.", "12:40"),
        (ClayIMG.cloudSun, "Fenêtre UV idéale", "UV 5 à Nice : parfait pour progresser sans forcer.", "14:05"),
        (ClayIMG.flame, "Limite bientôt atteinte", "Pause dans 8 min pour éviter la rougeur.", "15:18")
    ]
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        OnbTop(step: 16, total: 16)
                        ClayAssetTile(name: ClayIMG.bell, size: 70, tile: 82)
                            .padding(.bottom, 24)
                        DisplayText(text: "Reste protégé·e", size: 38)
                        LeadText(text: "SUNY t'enverra des rappels intelligents — uniquement utiles.").padding(.top, 14)

                        VStack(spacing: 10) {
                            ForEach(Array(previews.enumerated()), id: \.offset) { i, preview in
                                NotificationPreviewCard(asset: preview.0,
                                                        title: preview.1,
                                                        message: preview.2,
                                                        time: preview.3)
                                    .padding(.horizontal, CGFloat(i) * 5)
                            }
                        }
                        .padding(.top, 26)
                    }
                    .padding(.horizontal, Frame.padH)
                }
                VStack(spacing: 10) {
                    SolaButton(title: "Activer les notifications", icon: nil) {
                        Task {
                            let granted = await notifications.requestAuthorization()
                            store.data.notifPrefs.authorized = granted
                            ctrl.next { flow.finishOnboarding() }
                        }
                    }
                }
                .padding(.bottom, 18)
                .padding(.horizontal, Frame.padH)
            }
        }
    }
}

private struct NotificationPreviewCard: View {
    let asset: String
    let title: String
    let message: String
    let time: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            ClayAssetImage(name: asset, size: 48)
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("SUNY")
                        .font(SolaFont.body(12, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    Text(time)
                        .font(SolaFont.body(12, weight: .medium))
                        .foregroundStyle(Palette.ink3)
                }
                Text(title)
                    .font(SolaFont.body(15.5, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text(message)
                    .font(SolaFont.body(13.2))
                    .lineSpacing(2)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.70), lineWidth: 1)
                )
        )
        .shadow(color: Color(red: 0.31, green: 0.20, blue: 0.08).opacity(0.13),
                radius: 12, x: 0, y: 7)
    }
}

// MARK: - 23 · Rating
struct ScrRating: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @Environment(\.requestReview) private var requestReview
    @State private var didRequestReview = false
    var body: some View {
        ScreenScaffold(background: Palette.bgWarm) {
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { _ in Icon(name: "star", size: 28, filled: true).foregroundStyle(Palette.amberDeep) }
                }
                .padding(.bottom, 18)
                DisplayText(text: "Rejoins 250 000\namoureux du soleil", size: 38)
                    .multilineTextAlignment(.center)
                LeadText(text: "SUNY est noté 4,9/5 sur l'App Store.").multilineTextAlignment(.center)
                    .frame(maxWidth: 300).padding(.top, 14)
                CardBox {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            ForEach(0..<5, id: \.self) { _ in Icon(name: "star", size: 14, filled: true).foregroundStyle(Palette.amberDeep) }
                        }.padding(.bottom, 10)
                        Text("« Premier été sans coup de soleil et le plus beau bronzage de ma vie. L'appli me dit exactement combien de temps rester. »")
                            .font(SolaFont.body(15)).lineSpacing(6).foregroundStyle(Palette.ink)
                        HStack(spacing: 14) {
                            RemoteImage(url: IMG.faceFreckles, tone: .warm)
                                .frame(width: 36, height: 36).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Camille R.").font(SolaFont.body(14, weight: .bold))
                                Text("Phototype II").font(SolaFont.body(13)).foregroundStyle(Palette.ink3)
                            }
                        }.padding(.top, 14)
                    }
                }
                .padding(.top, 26)
                Spacer()
                SolaButton(title: "Continuer") { ctrl.next { flow.finishOnboarding() } }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Frame.padH).padding(.bottom, 18)
        }
        .onAppear {
            // Pop-up native iOS « Noter l'app » : présentée une seule fois, à
            // l'apparition de l'écran avis. iOS décide du moment réel d'affichage.
            guard !didRequestReview else { return }
            didRequestReview = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { requestReview() }
        }
    }
}

// MARK: - 24 · Photo capture
struct ScrPhotoCapture: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var store: AppStore
    @State private var picked: UIImage?
    @State private var showPicker = false

    var body: some View {
        ScreenScaffold(background: Color(oklch: 0.20, 0.012, 52), lightStatusBar: true) {
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    if let img = picked {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: 230, height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    } else {
                        RemoteImage(url: IMG.facePortrait, tone: .deep)
                            .frame(width: 230, height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    }
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 2.5, dash: [9, 7]))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(24)
                }
                .padding(.bottom, 30)
                Eyebrow(text: "Analyse IA · 1 photo", color: .white.opacity(0.6))
                DisplayText(text: "Scanne ta peau", size: 38, color: .white).padding(.top, 10)
                LeadText(text: "Un selfie en lumière naturelle. L'IA évalue ta teinte, ton éclat et l'état de ta peau.",
                         color: .white.opacity(0.78)).multilineTextAlignment(.center).frame(maxWidth: 300).padding(.top, 14)
                Spacer()
                VStack(spacing: 10) {
                    SolaButton(title: picked == nil ? "Prendre une photo" : "Analyser ma peau",
                               kind: .amber, icon: "camera") {
                        if picked == nil { showPicker = true }
                        else { saveAndAdvance() }
                    }
                    Button { showPicker = true } label: {
                        Text("Importer depuis la galerie").font(SolaFont.body(16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity).frame(height: 46)
                    }.buttonStyle(.plain)
                    if picked == nil {
                        Button { skipPhoto() } label: {
                            Text("Passer cette étape").font(SolaFont.body(15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity).frame(height: 40)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Frame.padH).padding(.bottom, 18)
        }
        .sheet(isPresented: $showPicker) {
            CameraPhotoPicker(image: $picked)
        }
    }

    private func saveAndAdvance() {
        if let img = picked, let name = PhotoStore.save(img) {
            let profile = store.profile
            // Mesure on-device hors main thread, puis conseil IA optionnel. La baseline
            // et tous les scans suivants utilisent ainsi la MÊME méthode → comparables.
            Task {
                let measured = await Task.detached(priority: .userInitiated) {
                    SkinAnalysis.analyze(img)
                }.value
                var result = measured
                if let measured { result?.advice = SkinAdvice.make(for: measured, profile: profile) }
                await MainActor.run {
                    store.addSession(TanSession(durationMinutes: 0, usedSPF: false,
                                                uvIndex: 0, note: "Photo de référence",
                                                photoFilename: name, metrics: result))
                }
            }
        }
        ctrl.next { flow.finishOnboarding() }
    }

    /// Sans photo, l'écran d'analyse n'a rien à analyser : on saute jusqu'aux
    /// résultats (l'écran Résultats gère déjà l'absence de scan).
    private func skipPhoto() {
        HapticsManager.shared.tap()
        ctrl.advance(by: 2) { flow.finishOnboarding() }
    }
}

// MARK: - 25 · Analyzing (loading, auto-advance)
struct ScrAnalyzing: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var store: AppStore
    @State private var progress = 0
    @State private var doneCount = 0
    private let steps: [String] = [
        "Détection du teint de peau", "Mesure de ta teinte",
        "Évaluation de l'uniformité", "Calcul de ton plan UV"
    ]
    private let assets = [ClayIMG.cameraScan, ClayIMG.skinPalette, ClayIMG.pool, ClayIMG.sun]
    private var targetIndex: Int { store.previewBaseline }
    var body: some View {
        ScreenScaffold(background: Palette.bgWarm) {
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Gauge(value: progress, size: 184, label: nil, sub: nil)
                    ClayAssetImage(name: ClayIMG.cameraScan, size: 88)
                    Eyebrow(text: "Analyse en cours").offset(y: 44)
                }
                .padding(.bottom, 34)
                DisplayText(text: "L'IA étudie\nta peau…", size: 38).multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        HStack(spacing: 14) {
                            ZStack {
                                ClayAssetTile(name: assets[i], size: 32, tile: 40, selected: i < doneCount)
                                    .opacity(i < doneCount ? 1 : 0.62)
                                if i < doneCount {
                                    Icon(name: "check", size: 10, stroke: 3)
                                        .foregroundStyle(Palette.onAmber)
                                        .frame(width: 18, height: 18)
                                        .background(Circle().fill(Palette.gold))
                                        .offset(x: 14, y: 13)
                                }
                            }
                            Text(s).font(SolaFont.body(15, weight: .semibold))
                                .foregroundStyle(i < doneCount ? Palette.ink : Palette.ink3)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.top, 30)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Frame.padH).padding(.bottom, 18)
        }
        .onAppear { runAnalysis() }
    }
    private func runAnalysis() {
        let goal = max(1, targetIndex)
        for t in stride(from: 0.0, through: 1.0, by: 0.02) {
            DispatchQueue.main.asyncAfter(deadline: .now() + t * 1.8) {
                progress = Int(t * Double(goal))
            }
        }
        for k in 1...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * 0.55) {
                withAnimation { doneCount = k }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { ctrl.next { flow.finishOnboarding() } }
    }
}

// MARK: - 26 · Results
struct ScrResults: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var store: AppStore
    private var metrics: [(String, String, String)] {
        guard let m = store.latestMetrics else { return [] }
        return [
            ("Teinte", "\(m.tan)%", ClayIMG.skinPalette),
            ("Éclat", "\(m.glow)%", ClayIMG.sun),
            ("Uniformité", "\(m.evenness)%", ClayIMG.pool),
            ("Rougeur", "\(m.redness)%", ClayIMG.flame)
        ]
    }
    private var profileAsset: String { ClayIMG.phototypes[store.profile.phototype.rawValue - 1] }
    private var hasScan: Bool { store.latestMetrics != nil }
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Badge(text: hasScan ? "Analyse terminée" : "Profil établi", icon: "check", style: .amber).padding(.bottom, 18)
                        DisplayText(text: "Voici ta peau aujourd'hui", size: 46)
                        CardBox {
                            HStack(spacing: 18) {
                                ZStack {
                                    Gauge(value: store.previewBaseline, size: 132, label: nil, sub: nil)
                                    ClayAssetImage(name: profileAsset, size: 90)
                                }
                                VStack(alignment: .leading, spacing: 0) {
                                    Eyebrow(text: "Ta teinte est")
                                    Text((store.latestMetrics?.hueLabel ?? "À analyser"))
                                        .font(SolaFont.display(23, weight: .bold))
                                        .tracking(-0.7).foregroundStyle(Palette.ink).padding(.top, 4)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Badge(text: "Niveau \(AppStore.level(forIndex: store.previewBaseline)) · Phototype \(store.profile.phototype.roman)").padding(.top, 12)
                                }
                            }
                        }
                        .padding(.top, 22)
                        if hasScan {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(Array(metrics.enumerated()), id: \.offset) { _, m in
                                    CardBox(padding: 16, shadow: false, borderColor: Palette.lineSoft) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                ClayAssetImage(name: m.2, size: 38)
                                                Spacer()
                                                Text(m.1).font(SolaFont.display(24, weight: .heavy)).foregroundStyle(Palette.ink)
                                            }
                                            Text(m.0).font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.ink2)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 14)
                        } else {
                            CardBox(padding: 16, shadow: false, borderColor: Palette.lineSoft) {
                                HStack(spacing: 14) {
                                    ClayAssetImage(name: ClayIMG.cameraScan, size: 42)
                                    Text("Scanne ta peau depuis l'onglet Analyse pour des métriques détaillées.")
                                        .font(SolaFont.body(14)).foregroundStyle(Palette.ink2)
                                }
                            }
                            .padding(.top, 14)
                        }
                    }
                    .padding(.horizontal, Frame.padH)
                }
                SolaButton(title: "Voir mon plan") { ctrl.next { flow.finishOnboarding() } }
                    .padding(.horizontal, Frame.padH).padding(.top, 14).padding(.bottom, 18)
            }
        }
    }
}

// MARK: - 27 · Plan ready
struct ScrPlanReady: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var store: AppStore
    private var rows: [(String, String, String)] {
        let p = store.profile
        return [
            (ClayIMG.skinPalette,"Objectif", p.goal.title),
            (ClayIMG.timer,"Dose quotidienne", "\(store.safeMinutes(uv: 8)) min · UV élevé"),
            (ClayIMG.shield,"Protection","SPF \(p.phototype.recommendedSPF) + réappli toutes les 2h"),
            (ClayIMG.sun,"1er résultat visible","dès la semaine 2")
        ]
    }
    var body: some View {
        ScreenScaffold(background: Palette.bgWarm) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Eyebrow(text: "Ton plan personnalisé est prêt").padding(.bottom, 12)
                DisplayText(text: "\(store.profile.targetWeeks) semaines vers ton objectif", size: 44)
                VStack(spacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                        CardBox(padding: 18) {
                            HStack(spacing: 14) {
                                ClayAssetTile(name: r.0, size: 42, tile: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.1).font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.ink3)
                                    Text(r.2).font(SolaFont.body(16, weight: .bold))
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .padding(.top, 26)
                Spacer()
                SolaButton(title: "Activer mon plan") { ctrl.next { flow.finishOnboarding() } }.padding(.bottom, 18)
            }
            .padding(.horizontal, Frame.padH)
        }
    }
}

// MARK: - 28 · Paywall
struct ScrPaywall: View {
    @EnvironmentObject var flow: AppFlow

    var body: some View {
        PaywallSheet(mandatory: true) {
            flow.finishOnboarding()
        }
    }
}
