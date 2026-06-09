import SwiftUI

// MARK: - 15 · Goal
struct ScrGoal: View {
    @EnvironmentObject var store: AppStore
    private let opts: [TanGoal] = [.subtleGlow, .deepTan, .maintain, .safe]
    var body: some View {
        OnbQuestion(step: 9, eyebrow: "Ton objectif", title: "Quelle teinte vises-tu ?",
                    sub: "On calibre ton plan d'exposition sur cet objectif.") {
            ForEach(opts, id: \.self) { g in
                OptionRow(icon: g.icon, title: g.title, sub: g.subtitle, selected: store.profile.goal == g)
                    .onTapGesture { store.profile.goal = g }
            }
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
                RemoteImage(url: IMG.shoulders, tone: .warm)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    .padding(.top, 26)
                HStack(spacing: 8) {
                    ForEach(Array(shades.enumerated()), id: \.offset) { i, s in
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(s)
                            .frame(height: 56)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Palette.ink, lineWidth: i == store.profile.startTanLevel ? 3 : 0))
                            .onTapGesture { store.profile.startTanLevel = i }
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
        ("Plage / mer","sun"), ("Piscine","drop"), ("Jardin / balcon","leaf"),
        ("Cabine UV","gauge"), ("Autobronzant","palette"), ("Montagne / ski","arrowUp")
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
                            Icon(name: p.1, size: 26)
                                .foregroundStyle(store.profile.places.contains(i) ? Palette.gold : Palette.bronze)
                                .frame(height: 34)
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
        ("sun","Tous les jours","Dès qu'il y a du soleil"),
        ("cloudSun","Plusieurs fois par semaine", nil),
        ("cal","Le week-end surtout", nil),
        ("pin","En vacances seulement", nil)
    ]
    var body: some View {
        OnbQuestion(step: 12, eyebrow: "Tes habitudes", title: "À quelle fréquence t'exposes-tu ?") {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, o in
                OptionRow(icon: o.0, title: o.1, sub: o.2, selected: store.profile.frequency == i)
                    .onTapGesture { store.profile.frequency = i }
            }
        }
    }
}

// MARK: - 19 · Concerns (multi)
struct ScrConcerns: View {
    @EnvironmentObject var store: AppStore
    private let opts: [(String, String, String?)] = [
        ("flame","Coups de soleil","Je rougis vite"),
        ("timer","Vieillissement prématuré", nil),
        ("spots","Taches pigmentaires", nil),
        ("target","Bronzage irrégulier", nil)
    ]
    var body: some View {
        OnbQuestion(step: 13, eyebrow: "Sécurité de la peau", title: "Tes préoccupations ?",
                    sub: "On renforcera les alertes en conséquence.") {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, o in
                OptionRow(icon: o.0, title: o.1, sub: o.2, selected: store.profile.concerns.contains(i))
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
        ("sun","Jamais","Ça empêche de bronzer, non ?"),
        ("umbrella","Seulement à la plage", nil),
        ("cloudSun","Les jours de grand soleil", nil),
        ("shield","Tous les jours","Bravo, continue !")
    ]
    var body: some View {
        OnbQuestion(step: 14, eyebrow: "Sécurité de la peau", title: "Tu mets de la crème solaire…") {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, o in
                OptionRow(icon: o.0, title: o.1, sub: o.2, selected: store.profile.spfHabit == i)
                    .onTapGesture { store.profile.spfHabit = i }
            }
        }
    }
}

// MARK: - 20b · Risques sans protection
struct ScrRisks: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow

    private let riskLevels: [(String, String, String, Color)] = [
        ("flame", "Coup de soleil", "Brûlures immédiates et rougeurs vives", Color(oklch: 0.66, 0.16, 32)),
        ("drop", "Peau qui pèle", "Ton bronzage disparaît d'un coup", Color(oklch: 0.68, 0.14, 45)),
        ("timer", "Vieillissement rapide", "Rides et taches dès 20 ans", Color(oklch: 0.62, 0.12, 55)),
        ("shield", "Cancer cutané", "Mélanome, carcinome (OMS attesté)", Color(oklch: 0.55, 0.16, 28))
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

                // DANGERS SECTION
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Icon(name: "alertTri", size: 18).foregroundStyle(Color(oklch: 0.74, 0.16, 36))
                        Text("LES DANGERS")
                            .font(SolaFont.mono(10)).tracking(0.7)
                            .foregroundStyle(Color(oklch: 0.74, 0.16, 36))
                    }

                    DisplayText(text: "Sans protection,\ntu t'abîmes", size: 32, color: .white)

                    // Risques : layout simplifié avec meilleure lisibilité
                    VStack(spacing: 8) {
                        ForEach(Array(riskLevels.enumerated()), id: \.offset) { i, r in
                            riskCard(number: i + 1, icon: r.0, title: r.1, desc: r.2, color: r.3)
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(oklch: 0.24, 0.06, 35).opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(oklch: 0.66, 0.16, 32).opacity(0.25), lineWidth: 1)))
                .padding(.horizontal, Frame.padH)
                .padding(.top, 14)

                // SOLUTION SECTION
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Icon(name: "shield", size: 18).foregroundStyle(Palette.gold)
                        Text("COMMENT SOLA PROTÈGE")
                            .font(SolaFont.mono(10)).tracking(0.7)
                            .foregroundStyle(Palette.gold)
                    }

                    VStack(spacing: 8) {
                        solutionItem(icon: "target", title: "Dose personnalisée")
                        solutionItem(icon: "timer", title: "Durée sûre chaque jour")
                        solutionItem(icon: "bell", title: "Alertes SPF auto")
                        solutionItem(icon: "check", title: "Bronzage progressif")
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.gold.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Palette.gold.opacity(0.3), lineWidth: 1)))
                .padding(.horizontal, Frame.padH)
                .padding(.top, 10)

                Spacer(minLength: 10)

                SolaButton(title: "Bronzer en sécurité", kind: .amber) { ctrl.next { flow.finishOnboarding() } }
                    .padding(.horizontal, Frame.padH).padding(.bottom, 16)
            }
        }
    }

    private func riskCard(number: Int, icon: String, title: String, desc: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Numéro dans cercle
            Text("\(number)")
                .font(SolaFont.mono(13, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color.opacity(0.15)))

            // Contenu texte
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SolaFont.body(14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(SolaFont.body(13))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .fill(color.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(color.opacity(0.15), lineWidth: 0.8)))
    }

    private func solutionItem(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Icon(name: icon, size: 16)
                .foregroundStyle(Palette.gold)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.gold.opacity(0.12)))

            Text(title)
                .font(SolaFont.body(13, weight: .medium))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .fill(.white.opacity(0.03)))
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
                SolaButton(title: "Autoriser la localisation", icon: "pin") {
                    location.request()
                    ctrl.next { flow.finishOnboarding() }
                }
                .padding(.bottom, 18)
            }
            .padding(.horizontal, Frame.padH)
        }
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
    private let items: [(String, String, String)] = [
        ("shield","Rappel de réappliquer le SPF","Toutes les 2h au soleil"),
        ("cloudSun","Fenêtre UV idéale","« C'est le bon moment pour bronzer »"),
        ("flame","Alerte limite d'exposition","Avant le risque de brûlure")
    ]
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                OnbTop(step: 16, total: 16)
                Spacer()
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.tintAmber)
                    .frame(width: 72, height: 72)
                    .overlay(Icon(name: "bell", size: 34).foregroundStyle(Palette.bronze))
                    .padding(.bottom, 24)
                DisplayText(text: "Reste protégé·e", size: 38)
                LeadText(text: "SOLA t'enverra des rappels intelligents — uniquement utiles.").padding(.top, 14)
                VStack(spacing: 11) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                        CardBox(padding: 16, shadow: false, borderColor: Palette.lineSoft) {
                            HStack(spacing: 14) {
                                Icon(name: it.0, size: 20).foregroundStyle(Palette.bronze)
                                    .frame(width: 42, height: 42)
                                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Palette.bgWarm))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(it.1).font(SolaFont.body(16, weight: .bold))
                                    Text(it.2).font(SolaFont.body(13)).foregroundStyle(Palette.ink3)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .padding(.top, 26)
                Spacer()
                VStack(spacing: 10) {
                    SolaButton(title: "Activer les notifications", icon: nil) {
                        Task {
                            let granted = await notifications.requestAuthorization()
                            store.data.notifPrefs.authorized = granted
                            ctrl.next { flow.finishOnboarding() }
                        }
                    }
                    Button { ctrl.next { flow.finishOnboarding() } } label: {
                        Text("Plus tard").font(SolaFont.body(16, weight: .bold)).foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity).frame(height: 46)
                    }.buttonStyle(.plain)
                }
                .padding(.bottom, 18)
            }
            .padding(.horizontal, Frame.padH)
        }
    }
}

// MARK: - 23 · Rating
struct ScrRating: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
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
                LeadText(text: "SOLA est noté 4,9/5 sur l'App Store.").multilineTextAlignment(.center)
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
            let metrics = SkinAnalysis.analyze(img)
            store.addSession(TanSession(durationMinutes: 0, usedSPF: false,
                                        uvIndex: 0, note: "Photo de référence",
                                        photoFilename: name, metrics: metrics))
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
    private var targetIndex: Int { store.previewBaseline }
    var body: some View {
        ScreenScaffold(background: Palette.bgWarm) {
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Gauge(value: progress, size: 184, label: nil, sub: nil)
                    Eyebrow(text: "Analyse en cours").offset(y: 44)
                }
                .padding(.bottom, 34)
                DisplayText(text: "L'IA étudie\nta peau…", size: 38).multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(i < doneCount ? Palette.ink : Palette.surface)
                                    .overlay(Circle().stroke(i < doneCount ? Color.clear : Palette.line, lineWidth: 1.5))
                                    .frame(width: 26, height: 26)
                                if i < doneCount { Icon(name: "check", size: 13, stroke: 3).foregroundStyle(Palette.gold) }
                                else { Circle().fill(Palette.amberDeep).frame(width: 8, height: 8) }
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
    private var metrics: [(String, String, String, Color)] {
        guard let m = store.latestMetrics else { return [] }
        return [
            ("Teinte", "\(m.tan)%", "drop", Palette.terra),
            ("Éclat", "\(m.glow)%", "sparkle", Palette.amberDeep),
            ("Uniformité", "\(m.evenness)%", "wave", Palette.bronze),
            ("Rougeur", "\(m.redness)%", "flame", Palette.alert)
        ]
    }
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
                                Gauge(value: store.previewBaseline, size: 130, label: "Indice", sub: "de bronzage")
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
                                                Icon(name: m.2, size: 20).foregroundStyle(m.3)
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
                                    Icon(name: "camera", size: 20).foregroundStyle(Palette.bronze)
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
            ("target","Objectif", p.goal.title),
            ("timer","Dose quotidienne", "\(store.safeMinutes(uv: 8)) min · UV élevé"),
            ("shield","Protection","SPF \(p.phototype.recommendedSPF) + réappli toutes les 2h"),
            ("trend","1er résultat visible","dès la semaine 2")
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
                                Icon(name: r.0, size: 21).foregroundStyle(Palette.bronze)
                                    .frame(width: 42, height: 42)
                                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Palette.tintAmber))
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

// MARK: - 28 · Paywall (StoreKit 2)
struct ScrPaywall: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var purchases: PurchaseManager
    @State private var annual = true
    private let perks = [
        "Analyse IA illimitée de ta peau",
        "Plan UV quotidien & alertes brûlure",
        "Suivi photo de ton bronzage",
        "Indice UV et fenêtre idéale en direct"
    ]
    private var selectedID: String { annual ? PurchaseManager.annualID : PurchaseManager.monthlyID }
    private var ctaTitle: String {
        if purchases.purchasing { return "Traitement…" }
        if let p = purchases.product(for: selectedID), p.subscription?.introductoryOffer != nil {
            return "Essai gratuit de 7 jours"
        }
        return "S'abonner"
    }

    var body: some View {
        ScreenScaffold(
            background: LinearGradient(colors: [
                Color(oklch: 0.46, 0.09, 54), Color(oklch: 0.24, 0.04, 50), Color(oklch: 0.18, 0.02, 52)
            ], startPoint: .top, endPoint: .bottom),
            lightStatusBar: true
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                SolaMark(size: 22, color: .white)
                DisplayText(text: "Débloque ton\nété parfait", size: 46, color: .white).padding(.top, 22)
                VStack(alignment: .leading, spacing: 13) {
                    ForEach(perks, id: \.self) { t in
                        HStack(spacing: 14) {
                            Icon(name: "check", size: 14, stroke: 3).foregroundStyle(Palette.onAmber)
                                .frame(width: 26, height: 26).background(Circle().fill(Palette.gold))
                            Text(t).font(SolaFont.body(15.5, weight: .medium)).foregroundStyle(.white.opacity(0.92))
                        }
                    }
                }
                .padding(.top, 22)
                HStack(spacing: 14) {
                    priceCard(tag: "MENSUEL",
                              price: purchases.displayPrice(for: PurchaseManager.monthlyID, fallback: "6,99 €"),
                              sub: "/ mois", selected: !annual)
                        .onTapGesture { annual = false }
                    priceCard(tag: "ANNUEL",
                              price: purchases.displayPrice(for: PurchaseManager.annualID, fallback: "34,99 €"),
                              sub: "/ an · 2,92 €/mois", selected: annual)
                        .onTapGesture { annual = true }
                }
                .padding(.top, 26)
                Spacer()
                SolaButton(title: ctaTitle, kind: .amber, icon: purchases.purchasing ? nil : "arrowR") {
                    Task {
                        _ = await purchases.purchase(selectedID)
                        ctrl.next { flow.finishOnboarding() }
                    }
                }
                .disabled(purchases.purchasing)
                HStack(spacing: 16) {
                    Button("Restaurer") { Task { await purchases.restore(); if purchases.isPro { ctrl.next { flow.finishOnboarding() } } } }
                    Text("·")
                    Button("Plus tard") { ctrl.next { flow.finishOnboarding() } }
                    Text("·")
                    Text("CGU")
                }
                .buttonStyle(.plain)
                .font(SolaFont.body(12.5)).foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity).padding(.top, 14)
            }
            .padding(.horizontal, Frame.padH).padding(.bottom, 18)
        }
    }
    private func priceCard(tag: String, price: String, sub: String, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tag).font(SolaFont.mono(11)).tracking(1)
                .foregroundStyle(selected ? Palette.onAmber : .white.opacity(0.6))
            Text(price).font(SolaFont.display(28, weight: .heavy))
                .foregroundStyle(selected ? Palette.onAmber : .white).padding(.top, 6)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(sub).font(SolaFont.body(13)).foregroundStyle(selected ? Palette.onAmber.opacity(0.7) : .white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(selected ? Palette.gold : Color.white.opacity(0.08))
        )
        .overlay(alignment: .topTrailing) {
            if tag == "ANNUEL" { Badge(text: "-58%").offset(x: -12, y: -11) }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(selected ? 0 : 0.18), lineWidth: 1.5)
        )
    }
}
