import SwiftUI

// MARK: - 1 · Welcome / splash
struct ScrWelcome: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow

    var body: some View {
        ScreenScaffold(
            background: LinearGradient(colors: [
                Color(oklch: 0.42, 0.09, 50),
                Color(oklch: 0.24, 0.04, 48),
                Color(oklch: 0.18, 0.02, 52)
            ], startPoint: .top, endPoint: .bottom),
            lightStatusBar: true
        ) {
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(RadialGradient(colors: [Palette.gold, Palette.amberDeep],
                                         center: .init(x: 0.35, y: 0.30), startRadius: 4, endRadius: 90))
                    .frame(width: 96, height: 96)
                    .overlay(Icon(name: "sun", size: 50, stroke: 2).foregroundStyle(Palette.onAmber))
                    .shadow(color: Color(red: 0.94, green: 0.75, blue: 0.35).opacity(0.35), radius: 30)
                VStack(spacing: 12) {
                    Text("SOLA")
                        .font(SolaFont.display(64, weight: .heavy)).tracking(3)
                        .foregroundStyle(.white)
                    Text("BRONZAGE · INTELLIGENT")
                        .font(SolaFont.mono(12.5)).tracking(3)
                        .foregroundStyle(.white.opacity(0.62))
                }
                .padding(.top, 26)
                LeadText(text: "Ton coach solaire personnel. Bronze plus beau, plus vite, sans brûler.",
                         color: .white.opacity(0.78), size: 16.5)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 270)
                    .padding(.top, 26)
                Spacer()
                VStack(spacing: 12) {
                    SolaButton(title: "Commencer", kind: .amber) { advance() }
                    SolaButton(title: "J'ai déjà un compte", kind: .ghost, icon: nil,
                               ghostBorder: .white.opacity(0.25), ghostText: .white) { advance() }
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Frame.padH)
            .padding(.top, 30).padding(.bottom, 36)
        }
    }
    private func advance() { ctrl.next { flow.finishOnboarding() } }
}

// MARK: - Slides intro (value props)
struct IntroSlide: View {
    var idx: Int
    var total: Int = 3
    var img: String
    var tone: StripedPlaceholder.Tone
    var eyebrowLabel: String
    var eyebrowIcon: String
    var title: String
    var bodyText: String
    var accent: Color

    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SolaMark(size: 20, color: Palette.ink)
                    Spacer()
                    Button { ctrl.skip { flow.finishOnboarding() } } label: {
                        Text("Passer").font(SolaFont.mono(12.5)).foregroundStyle(Palette.ink3)
                    }.buttonStyle(.plain)
                }
                .padding(.top, 6).padding(.bottom, 18)
                .padding(.horizontal, Frame.padH)

                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        RemoteImage(url: img, tone: tone)
                            .frame(height: 360)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        Icon(name: eyebrowIcon, size: 24)
                            .foregroundStyle(accent)
                            .frame(width: 50, height: 50)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.9)))
                            .shadow(color: .black.opacity(0.18), radius: 7, y: 4)
                            .padding(18)
                    }
                    Eyebrow(text: eyebrowLabel).padding(.top, 30).padding(.bottom, 12)
                    DisplayText(text: title, size: 38)
                    LeadText(text: bodyText).padding(.top, 14)
                }
                .padding(.horizontal, Frame.padH)

                Spacer(minLength: 16)

                HStack {
                    HStack(spacing: 8) {
                        ForEach(0..<total, id: \.self) { i in
                            Capsule().fill(i == idx ? Palette.ink : Palette.line)
                                .frame(width: i == idx ? 24 : 7, height: 7)
                        }
                    }
                    Spacer()
                    Button { advance() } label: {
                        HStack(spacing: 9) { Text("Suivant"); Icon(name: "arrowR", size: 19) }
                            .font(SolaFont.body(16, weight: .bold))
                            .foregroundStyle(Palette.inkOn)
                            .padding(.leading, 30).padding(.trailing, 22)
                            .frame(height: 58)
                            .background(Capsule().fill(Palette.ink))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, Frame.padH)
                .padding(.top, 16).padding(.bottom, 18)
            }
        }
    }
    private func advance() { ctrl.next { flow.finishOnboarding() } }
}

struct ScrIntro1: View {
    var body: some View {
        IntroSlide(idx: 0, img: IMG.faceFreckles, tone: .warm,
                   eyebrowLabel: "Suivi quotidien", eyebrowIcon: "trend",
                   title: "Ton bronzage,\njour après jour",
                   bodyText: "SOLA mesure l'évolution de ta teinte et te montre tes progrès vers ton objectif doré.",
                   accent: Palette.terra)
    }
}
struct ScrIntro2: View {
    var body: some View {
        IntroSlide(idx: 1, img: IMG.beach, tone: .base,
                   eyebrowLabel: "Fenêtre UV idéale", eyebrowIcon: "cloudSun",
                   title: "Bronze au\nbon moment",
                   bodyText: "Indice UV en temps réel, météo et créneau parfait pour t'exposer en sécurité.",
                   accent: Palette.amberDeep)
    }
}
struct ScrIntro3: View {
    var body: some View {
        IntroSlide(idx: 2, img: IMG.sunbathe, tone: .deep,
                   eyebrowLabel: "Peau protégée", eyebrowIcon: "shield",
                   title: "Sans jamais\nbrûler",
                   bodyText: "Rappels SPF, durée d'exposition sûre et alertes selon ton phototype. Le hâle, pas le coup de soleil.",
                   accent: Palette.bronze)
    }
}

// MARK: - 5 · Referral
struct ScrReferral: View {
    @EnvironmentObject var store: AppStore
    private let opts = [("music","TikTok"),("camera","Instagram"),("store","App Store"),
                        ("user","Un·e ami·e"),("globe","Recherche web")]
    var body: some View {
        OnbQuestion(step: 1, eyebrow: "Une dernière chose", title: "Comment as-tu connu SOLA ?") {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, o in
                OptionRow(icon: o.0, title: o.1, selected: store.profile.referral == o.1)
                    .onTapGesture { store.profile.referral = o.1 }
            }
        }
    }
}

// MARK: - 6 · Gender
struct ScrGender: View {
    @EnvironmentObject var store: AppStore
    private let opts = [("user","Femme"),("user","Homme"),("user","Autre"),("lock","Je préfère ne pas dire")]
    var body: some View {
        OnbQuestion(step: 2, eyebrow: "À propos de toi", title: "Tu es…",
                    sub: "On adapte les recommandations de dose UV à ta physiologie.") {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, o in
                OptionRow(icon: o.0, title: o.1, selected: store.profile.gender == o.1)
                    .onTapGesture { store.profile.gender = o.1 }
            }
        }
    }
}

// MARK: - 7 · Prénom + âge
struct ScrAge: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var store: AppStore
    @FocusState private var nameFocused: Bool
    @GestureState private var dragAccum: CGFloat = 0

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    OnbTop(step: 3, total: 16)
                    Eyebrow(text: "À propos de toi").padding(.bottom, 12)
                    DisplayText(text: "Toi, en bref", size: 38)
                    LeadText(text: "Ton prénom et ton âge — la sensibilité aux UV évolue avec l'âge.").padding(.top, 14)

                    // prénom
                    HStack(spacing: 12) {
                        Icon(name: "user", size: 20).foregroundStyle(Palette.bronze)
                        TextField("Ton prénom", text: Binding(
                            get: { store.profile.name },
                            set: { store.profile.name = $0 }))
                            .font(SolaFont.body(17, weight: .semibold))
                            .focused($nameFocused)
                            .submitLabel(.done)
                    }
                    .padding(.horizontal, 18).frame(height: 58)
                    .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .stroke(nameFocused ? Palette.ink : Palette.lineSoft, lineWidth: 1.5)))
                    .padding(.top, 22)

                    // roue d'âge (glisser pour changer)
                    ageWheel.padding(.top, 8)
                }
                .padding(.horizontal, Frame.padH)
                Spacer()
                SolaButton(title: "Continuer") { ctrl.next { flow.finishOnboarding() } }
                    .padding(.horizontal, Frame.padH).padding(.bottom, 18)
            }
            .contentShape(Rectangle())
            .onTapGesture { nameFocused = false }
        }
    }

    private var ageWheel: some View {
        let age = store.profile.age
        return ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.surface).solaShadowSm()
                .frame(height: 72)
            VStack(spacing: 4) {
                ForEach(-2...2, id: \.self) { off in
                    let n = age + off
                    let dist = abs(off)
                    HStack(spacing: 6) {
                        Text("\(n)")
                        if dist == 0 { Text("ans").font(SolaFont.body(18)).foregroundStyle(Palette.ink3) }
                    }
                    .font(SolaFont.display(dist == 0 ? 52 : dist == 1 ? 30 : 22, weight: .heavy))
                    .foregroundStyle(dist == 0 ? Palette.ink : Palette.ink3)
                    .opacity(dist == 0 ? 1 : 0.55 - Double(dist) * 0.12)
                }
            }
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .updating($dragAccum) { value, state, _ in state = value.translation.height }
                .onChanged { value in
                    let steps = Int((-value.translation.height / 26).rounded())
                    let newAge = min(99, max(13, age + steps))
                    if newAge != store.profile.age { store.profile.age = newAge }
                }
        )
    }
}

// MARK: - 8 · Phototype intro
struct ScrPhotoIntro: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    private let types = ["I","II","III","IV","V","VI"]
    private let cols = [
        Color(oklch: 0.90, 0.04, 70), Color(oklch: 0.84, 0.06, 66), Color(oklch: 0.76, 0.08, 62),
        Color(oklch: 0.64, 0.09, 58), Color(oklch: 0.50, 0.08, 54), Color(oklch: 0.36, 0.05, 50)
    ]
    var body: some View {
        ScreenScaffold(background: Palette.bgWarm) {
            VStack(alignment: .leading, spacing: 0) {
                OnbTop(step: 3, total: 16, onlyBack: true)
                Spacer()
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.ink)
                    .frame(width: 72, height: 72)
                    .overlay(Icon(name: "palette", size: 34).foregroundStyle(Palette.gold))
                    .padding(.bottom, 26)
                Eyebrow(text: "Étape 1 sur 3 · Ton profil de peau").padding(.bottom, 12)
                DisplayText(text: "Trouvons ton phototype", size: 46)
                LeadText(text: "5 questions rapides sur ta peau, tes yeux et ta réaction au soleil. C'est l'échelle de Fitzpatrick — la base de toutes tes recommandations.").padding(.top, 16)
                HStack(spacing: 14) {
                    ForEach(Array(types.enumerated()), id: \.offset) { i, t in
                        Text(t)
                            .font(SolaFont.display(16, weight: .bold))
                            .foregroundStyle(i > 2 ? .white : Palette.onAmber)
                            .frame(width: 46, height: 46)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(cols[i]))
                    }
                }
                .padding(.top, 30)
                Spacer()
                SolaButton(title: "Commencer le test") { ctrl.next { flow.finishOnboarding() } }
                    .padding(.bottom, 18)
            }
            .padding(.horizontal, Frame.padH)
        }
    }
}

// MARK: - 9 · Eyes
struct ScrEyes: View {
    @EnvironmentObject var store: AppStore
    private let eyes: [(String, Color)] = [
        ("Bleu clair", Color(oklch: 0.78, 0.07, 230)),
        ("Vert / gris", Color(oklch: 0.72, 0.07, 160)),
        ("Noisette", Color(oklch: 0.58, 0.09, 70)),
        ("Marron foncé", Color(oklch: 0.34, 0.05, 60))
    ]
    var body: some View {
        QuizGridScreen(step: 4, eyebrow: "Phototype · 1/5", title: "Couleur de tes yeux ?") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)], spacing: 11) {
                ForEach(Array(eyes.enumerated()), id: \.offset) { i, e in
                    PillOption(selected: store.profile.eyeColor == i, label: e.0) {
                        Circle().fill(e.1).frame(width: 40, height: 40)
                            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 3))
                    }
                    .onTapGesture { store.profile.eyeColor = i }
                }
            }
        }
    }
}

// MARK: - 10 · Hair
struct ScrHair: View {
    @EnvironmentObject var store: AppStore
    private let hair: [(String, Color)] = [
        ("Blond / roux", Color(oklch: 0.80, 0.09, 75)),
        ("Châtain clair", Color(oklch: 0.60, 0.07, 60)),
        ("Châtain foncé", Color(oklch: 0.42, 0.05, 55)),
        ("Noir", Color(oklch: 0.26, 0.02, 50))
    ]
    var body: some View {
        QuizGridScreen(step: 5, eyebrow: "Phototype · 2/5", title: "Couleur naturelle de tes cheveux ?") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)], spacing: 11) {
                ForEach(Array(hair.enumerated()), id: \.offset) { i, e in
                    PillOption(selected: store.profile.hairColor == i, label: e.0) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(e.1).frame(width: 40, height: 40)
                    }
                    .onTapGesture { store.profile.hairColor = i }
                }
            }
        }
    }
}

// MARK: - 11 · Skin tone
struct ScrSkin: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var store: AppStore
    private let tones = [
        Color(oklch: 0.93, 0.03, 70), Color(oklch: 0.88, 0.045, 68), Color(oklch: 0.80, 0.06, 64),
        Color(oklch: 0.68, 0.07, 60), Color(oklch: 0.54, 0.07, 56), Color(oklch: 0.40, 0.05, 52)
    ]
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                OnbTop(step: 6, total: 16)
                Eyebrow(text: "Phototype · 3/5").padding(.bottom, 12)
                DisplayText(text: "Ta carnation naturelle ?", size: 38)
                LeadText(text: "La couleur d'une zone jamais exposée (intérieur du bras).").padding(.top, 14)
                HStack(spacing: 8) {
                    ForEach(Array(tones.enumerated()), id: \.offset) { i, t in
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(t)
                                .frame(height: 90)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Palette.ink, lineWidth: i == store.profile.skinTone ? 3 : 0))
                            if i == store.profile.skinTone {
                                Icon(name: "check", size: 12, stroke: 3).foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(Palette.ink))
                                    .offset(y: 58)
                            }
                        }
                        .onTapGesture { store.profile.skinTone = i }
                    }
                }
                .padding(.top, 30)
                HStack { Text("CLAIR"); Spacer(); Text("FONCÉ") }
                    .font(SolaFont.mono(11)).foregroundStyle(Palette.ink3).padding(.top, 14)
                Spacer()
                SolaButton(title: "Continuer") { ctrl.next { flow.finishOnboarding() } }.padding(.bottom, 18)
            }
            .padding(.horizontal, Frame.padH)
        }
    }
}

// MARK: - 12 · Sun reaction
struct ScrSunReact: View {
    @EnvironmentObject var store: AppStore
    private let opts = [("flame","Brûle toujours, ne bronze jamais"),
                        ("thermo","Brûle souvent, bronze à peine"),
                        ("cloudSun","Brûle un peu, puis bronze"),
                        ("sun","Bronze facilement, brûle rarement"),
                        ("umbrella","Bronze toujours, ne brûle jamais")]
    var body: some View {
        OnbQuestion(step: 7, eyebrow: "Phototype · 4/5", title: "Au soleil, ta peau…") {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, o in
                OptionRow(icon: o.0, title: o.1, selected: store.profile.sunReaction == i)
                    .onTapGesture { store.profile.sunReaction = i }
            }
        }
    }
}

// MARK: - 13 · Freckles
struct ScrFreckles: View {
    @EnvironmentObject var store: AppStore
    private let opts: [(String, String, String?)] = [
        ("spots","Beaucoup","Visage et corps"),
        ("sparkle","Quelques-unes","Surtout au soleil"),
        ("drop","Très peu", nil),
        ("user","Aucune", nil)
    ]
    var body: some View {
        OnbQuestion(step: 8, eyebrow: "Phototype · 5/5", title: "As-tu des taches de rousseur ?") {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, o in
                OptionRow(icon: o.0, title: o.1, sub: o.2, selected: store.profile.freckles == i)
                    .onTapGesture { store.profile.freckles = i }
            }
        }
    }
}

// MARK: - 14 · Phototype reveal (calculé)
struct ScrPhototype: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var store: AppStore

    private var type: Fitzpatrick { PhototypeScoring.compute(from: store.profile) }

    var body: some View {
        ScreenScaffold(
            background: LinearGradient(colors: [
                Color(oklch: 0.50, 0.09, 58), Color(oklch: 0.30, 0.05, 52), Color(oklch: 0.22, 0.03, 50)
            ], startPoint: .top, endPoint: .bottom),
            lightStatusBar: true
        ) {
            VStack(spacing: 0) {
                Spacer()
                Badge(text: "Profil de peau établi", icon: "check", style: .amber).padding(.bottom, 22)
                Circle().fill(type.swatch)
                    .frame(width: 130, height: 130)
                    .overlay(Text(type.roman).font(SolaFont.display(56, weight: .heavy)).foregroundStyle(Palette.onAmber))
                    .shadow(color: Color(red: 0.86, green: 0.62, blue: 0.35).opacity(0.4), radius: 30)
                    .padding(.bottom, 26)
                Eyebrow(text: "Ton phototype Fitzpatrick", color: .white.opacity(0.65))
                DisplayText(text: type.title, size: 46, color: .white).padding(.top, 10)
                    .multilineTextAlignment(.center)
                LeadText(text: type.summary, color: .white.opacity(0.82))
                    .multilineTextAlignment(.center).frame(maxWidth: 300).padding(.top, 14)
                HStack(spacing: 14) {
                    revealStat(top: "~\(type.safeMinutesAtUV8)", unit: "min", label: "avant rougeur")
                    revealStat(top: "SPF \(type.recommendedSPF)", unit: "", label: "recommandé")
                }
                .padding(.top, 28)
                Spacer()
                SolaButton(title: "Définir mon objectif", kind: .amber) {
                    store.profile.phototype = type
                    ctrl.next { flow.finishOnboarding() }
                }
                .padding(.top, 8)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Frame.padH).padding(.bottom, 18)
        }
    }
    private func revealStat(top: String, unit: String, label: String) -> some View {
        VStack(spacing: 2) {
            (Text(top).font(SolaFont.display(22, weight: .heavy))
             + Text(unit).font(SolaFont.display(14, weight: .heavy)))
                .foregroundStyle(.white)
            Text(label).font(SolaFont.body(11.5)).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14).padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.1)))
    }
}

// Shell pour les écrans à grille (yeux / cheveux) avec CTA
struct QuizGridScreen<Content: View>: View {
    var step: Int
    var eyebrow: String
    var title: String
    @ViewBuilder var content: () -> Content
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                OnbTop(step: step, total: 16)
                Eyebrow(text: eyebrow).padding(.bottom, 12)
                DisplayText(text: title, size: 38)
                content().padding(.top, 28)
                Spacer()
                SolaButton(title: "Continuer") { ctrl.next { flow.finishOnboarding() } }.padding(.bottom, 18)
            }
            .padding(.horizontal, Frame.padH)
        }
    }
}
