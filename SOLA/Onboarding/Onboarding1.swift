import SwiftUI

// MARK: - 1 · Welcome / splash
struct ScrWelcome: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @State private var isAnimating = false

    var body: some View {
        ScreenScaffold(
            background: ZStack {
                Image(IMG.welcomeSunbathe)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                LinearGradient(colors: [
                    Color.black.opacity(0.20),
                    Color.black.opacity(0.00),
                    Color(red: 0.20, green: 0.10, blue: 0.05).opacity(0.42)
                ], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

                LinearGradient(colors: [
                    Color.clear,
                    Color(red: 0.95, green: 0.58, blue: 0.22).opacity(0.14),
                    Color(red: 0.16, green: 0.08, blue: 0.04).opacity(0.28)
                ], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
            },
            lightStatusBar: true
        ) {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(spacing: 13) {
                        VStack(spacing: 6) {
                            Text("Goldn")
                                .font(SolaFont.display(44, weight: .heavy))
                                .tracking(2)
                                .foregroundStyle(.white)
                            Text("BRONZE · INTELLIGEMMENT")
                                .font(SolaFont.mono(10.5, weight: .medium))
                                .tracking(2.5)
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        Text("Ton coach solaire perso.\nBronze mieux, sans te brûler.")
                            .font(SolaFont.body(19, weight: .medium))
                            .lineSpacing(6)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.94))
                            .fixedSize(horizontal: false, vertical: true)

                        WelcomeSwipeButton(title: "Commencer") { advance() }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 21)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .background(WelcomeWarmGlass(radius: 34, opacity: 0.52))
                    .padding(.bottom, 8)
                    .scaleEffect(isAnimating ? 1 : 0.96, anchor: .bottom)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 24)
                }
                .padding(.horizontal, 26)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                    isAnimating = true
                }
            }
        }
    }
    private func advance() { ctrl.next { flow.finishOnboarding() } }
}

private struct WelcomeWarmGlass: View {
    var radius: CGFloat
    var opacity: Double

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(colors: [
                    Color(red: 1.00, green: 0.90, blue: 0.78).opacity(opacity),
                    Color(red: 0.78, green: 0.62, blue: 0.50).opacity(opacity * 0.76)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white.opacity(0.62), lineWidth: 1)
            )
            .shadow(color: Color(red: 0.18, green: 0.09, blue: 0.04).opacity(0.20),
                    radius: 18, x: 0, y: 10)
    }
}

private struct WelcomeSwipeButton: View {
    let title: String
    var action: () -> Void

    @State private var dragX: CGFloat = 0
    @State private var completed = false

    private let height: CGFloat = 62
    private let knobSize: CGFloat = 50
    private let inset: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let maxDrag = max(0, geo.size.width - knobSize - inset * 2)
            let progress = maxDrag > 0 ? dragX / maxDrag : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.95))
                    .overlay(Capsule().stroke(.white.opacity(0.70), lineWidth: 1))

                Capsule()
                    .fill(Palette.amber.opacity(0.18))
                    .frame(width: knobSize + inset * 2 + dragX)

                Text(title)
                    .font(SolaFont.body(18, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity)
                    .opacity(0.95 - progress * 0.45)

                Circle()
                    .fill(Palette.amber)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(
                        Icon(name: "arrowR", size: 22, stroke: 2)
                            .foregroundStyle(Palette.onAmber)
                    )
                    .shadow(color: Color(red: 0.30, green: 0.14, blue: 0.04).opacity(0.20),
                            radius: 10, x: 0, y: 5)
                    .offset(x: inset + dragX)
                    .gesture(
                        DragGesture(minimumDistance: 3)
                            .onChanged { value in
                                guard !completed else { return }
                                dragX = min(max(0, value.translation.width), maxDrag)
                            }
                            .onEnded { _ in
                                guard !completed else { return }
                                if dragX > maxDrag * 0.72 {
                                    complete(maxDrag: maxDrag)
                                } else {
                                    withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                                        dragX = 0
                                    }
                                }
                            }
                    )
            }
            .contentShape(Capsule())
            .accessibilityLabel(Text(title))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { complete(maxDrag: maxDrag) }
        }
        .frame(height: height)
    }

    private func complete(maxDrag: CGFloat) {
        completed = true
        HapticsManager.shared.select()
        withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
            dragX = maxDrag
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            action()
        }
    }
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
    @State private var isAnimating = false

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                // Onboarding obligatoire : aucune étape n'est skippable (hors scan peau).
                Spacer().frame(height: 24)

                VStack(alignment: .leading, spacing: 0) {
                    RemoteImage(url: img, tone: tone)
                        .frame(height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        .scaleEffect(isAnimating ? 1 : 0.9)
                        .opacity(isAnimating ? 1 : 0)
                    Eyebrow(text: tr(eyebrowLabel)).padding(.top, 30).padding(.bottom, 12)
                        .offset(y: isAnimating ? 0 : 10)
                        .opacity(isAnimating ? 1 : 0)
                    DisplayText(text: tr(title), size: 38)
                        .offset(y: isAnimating ? 0 : 10)
                        .opacity(isAnimating ? 1 : 0)
                    LeadText(text: tr(bodyText)).padding(.top, 14)
                        .offset(y: isAnimating ? 0 : 10)
                        .opacity(isAnimating ? 1 : 0)
                }
                .padding(.horizontal, Frame.padH)

                Spacer(minLength: 16)

                HStack {
                    HStack(spacing: 8) {
                        ForEach(0..<total, id: \.self) { i in
                            Capsule().fill(i == idx ? Palette.ink : Palette.line)
                                .frame(width: i == idx ? 24 : 7, height: 7)
                                .animation(.easeInOut(duration: 0.3), value: idx)
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
                    .offset(y: isAnimating ? 0 : 20)
                    .opacity(isAnimating ? 1 : 0)
                }
                .padding(.horizontal, Frame.padH)
                .padding(.top, 16).padding(.bottom, 18)
            }
            .onbScrollable()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                isAnimating = true
            }
        }
    }
    private func advance() { ctrl.next { flow.finishOnboarding() } }
}

struct ScrIntro1: View {
    var body: some View {
        IntroSlide(idx: 0, img: IMG.faceFreckles, tone: .warm,
                   eyebrowLabel: "Suivi quotidien", eyebrowIcon: "trend",
                   title: "Vois ta teinte évoluer\nchaque jour",
                   bodyText: "Goldn suit ton bronzage en temps réel et t'affiche tes progrès vers ta teinte rêvée. Tu sais exactement où tu en es.",
                   accent: Palette.terra)
    }
}
struct ScrIntro2: View {
    var body: some View {
        IntroSlide(idx: 1, img: IMG.beach, tone: .base,
                   eyebrowLabel: "Fenêtre UV idéale", eyebrowIcon: "cloudSun",
                   title: "S'exposer au moment\nperfait",
                   bodyText: "Goldn calcule l'indice UV de ta région et te dit quand c'est le bon moment pour bronzer. Pas de devinette, juste de la science.",
                   accent: Palette.amberDeep)
    }
}
struct ScrIntro3: View {
    var body: some View {
        IntroSlide(idx: 2, img: IMG.sunbathe, tone: .deep,
                   eyebrowLabel: "Peau protégée", eyebrowIcon: "shield",
                   title: "La teinte sans\nla brûlure",
                   bodyText: "Rappels SPF, durée d'exposition sûre et alertes personnalisées selon ton phototype. Bronzage oui, coup de soleil non.",
                   accent: Palette.bronze)
    }
}

// MARK: - 5 · Referral
struct ScrReferral: View {
    @EnvironmentObject var store: AppStore
    private let opts = [("music","TikTok"),("camera","Instagram"),("store","App Store"),
                        ("user","Un·e ami·e"),("globe","Recherche web")]
    var body: some View {
        OnbQuestion(step: 1, eyebrow: "Une dernière chose", title: "Comment as-tu connu Goldn ?") {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, o in
                OptionRow(icon: o.0, title: tr(o.1), selected: store.profile.referral == o.1)
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
                OptionRow(icon: o.0, title: tr(o.1), selected: store.profile.gender == o.1)
                    .onTapGesture { store.profile.gender = o.1 }
            }
        }
    }
}

// MARK: - 7 · Prénom
struct ScrName: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var store: AppStore
    @FocusState private var nameFocused: Bool
    @State private var isAnimating = false

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    OnbTop(step: 3, total: 17)
                    Eyebrow(text: "Commençons").padding(.bottom, 12)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 10)
                    DisplayText(text: "Ton prénom ?", size: 38)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 10)
                    LeadText(text: "On personnalise juste après.").padding(.top, 14)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 10)

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
                    .background(GlassPanel(radius: Radius.md, tint: Palette.surface, tintOpacity: 0.32))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(nameFocused ? Palette.ink : Palette.lineSoft.opacity(0.55), lineWidth: 1.5))
                    .padding(.top, 22)
                    .scaleEffect(isAnimating ? 1 : 0.95)
                    .opacity(isAnimating ? 1 : 0)
                }
                .padding(.horizontal, Frame.padH)
                Spacer()
                SolaButton(title: "Continuer") { ctrl.next { flow.finishOnboarding() } }
                    .padding(.horizontal, Frame.padH).padding(.bottom, 18)
                    .offset(y: isAnimating ? 0 : 20)
                    .opacity(isAnimating ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { nameFocused = false }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                    isAnimating = true
                }
            }
            .onbScrollable()
        }
    }
}

// MARK: - 8 · Âge
struct ScrAge: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var store: AppStore
    @State private var ageAtDragStart: Int? = nil
    @State private var isAnimating = false

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    OnbTop(step: 4, total: 17)
                    Eyebrow(text: "Commençons").padding(.bottom, 12)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 10)
                    DisplayText(text: "Quel âge ?", size: 38)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 10)
                    LeadText(text: "Ta peau change, on adapte les recommandations.").padding(.top, 14)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 10)

                    ageWheel.padding(.top, 8)
                        .scaleEffect(isAnimating ? 1 : 0.95)
                        .opacity(isAnimating ? 1 : 0)
                }
                .padding(.horizontal, Frame.padH)
                Spacer()
                SolaButton(title: "Continuer") { ctrl.next { flow.finishOnboarding() } }
                    .padding(.horizontal, Frame.padH).padding(.bottom, 18)
                    .offset(y: isAnimating ? 0 : 20)
                    .opacity(isAnimating ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                    isAnimating = true
                }
            }
            .onbScrollable()
        }
    }

    private var ageWheel: some View {
        let age = store.profile.age
        return ZStack {
            GlassPanel(radius: 20, tint: Palette.surface, tintOpacity: 0.32)
                .shadowSoft()
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
                .onChanged { value in
                    let base = ageAtDragStart ?? age
                    if ageAtDragStart == nil { ageAtDragStart = base }
                    setAge(base + Int((-value.translation.height / 22).rounded()))
                }
                .onEnded { value in
                    let base = ageAtDragStart ?? age
                    // Projection du « flick » : inertie naturelle façon roue iOS
                    let projected = base + Int((-value.predictedEndTranslation.height / 22).rounded())
                    withAnimation(.easeOut(duration: 0.4)) { setAge(projected) }
                    ageAtDragStart = nil
                }
        )
    }

    private func setAge(_ value: Int) {
        let clamped = min(99, max(13, value))
        guard clamped != store.profile.age else { return }
        store.profile.age = clamped
        HapticsManager.shared.tap()   // détent par cran, comme une roue native
    }
}

// MARK: - 9 · Phototype intro
struct ScrPhotoIntro: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    private let types = ["I","II","III","IV","V","VI"]
    var body: some View {
        ScreenScaffold(background: Palette.bgWarm) {
            VStack(alignment: .leading, spacing: 0) {
                OnbTop(step: 5, total: 17, onlyBack: true)
                Spacer()
                ClayAssetTile(name: ClayIMG.skinPalette, size: 66, tile: 78)
                    .padding(.bottom, 26)
                Eyebrow(text: "Étape 1 sur 3 · Ton profil de peau").padding(.bottom, 12)
                DisplayText(text: "Trouvons ton phototype", size: 46)
                LeadText(text: "5 questions rapides sur ta peau, tes yeux et comment tu réagis au soleil. C'est l'échelle Fitzpatrick, la fondation de tout ce qu'on te recommandera.").padding(.top, 16)
                HStack(spacing: 7) {
                    ForEach(Array(types.enumerated()), id: \.offset) { i, t in
                        VStack(spacing: 2) {
                            ClayAssetImage(name: ClayIMG.phototypes[i], size: 45)
                                .frame(width: 46, height: 46)
                            Text(t)
                                .font(SolaFont.mono(10, weight: .semibold))
                                .foregroundStyle(Palette.ink3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 30)
                Spacer()
                SolaButton(title: "Commencer le test") { ctrl.next { flow.finishOnboarding() } }
                    .padding(.bottom, 18)
            }
            .padding(.horizontal, Frame.padH)
            .onbScrollable()
        }
    }
}

// MARK: - 9 · Eyes
struct ScrEyes: View {
    @EnvironmentObject var store: AppStore
    private let eyes = ["Bleu clair", "Vert / gris", "Noisette", "Marron foncé"]
    var body: some View {
        QuizGridScreen(step: 6, eyebrow: "Phototype · 1/5", title: "Couleur de tes yeux ?") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)], spacing: 11) {
                ForEach(Array(eyes.enumerated()), id: \.offset) { i, label in
                    PillOption(selected: store.profile.eyeColor == i, label: tr(label)) {
                        ClayAssetImage(name: ClayIMG.eyes[i], size: 72)
                            .frame(height: 70)
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
    private let hair = ["Blond / roux", "Châtain clair", "Châtain foncé", "Noir"]
    var body: some View {
        QuizGridScreen(step: 7, eyebrow: "Phototype · 2/5", title: "Couleur naturelle de tes cheveux ?") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)], spacing: 11) {
                ForEach(Array(hair.enumerated()), id: \.offset) { i, label in
                    PillOption(selected: store.profile.hairColor == i, label: tr(label)) {
                        ClayAssetImage(name: ClayIMG.hair[i], size: 72)
                            .frame(height: 70)
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
    private let labels = ["Type I", "Type II", "Type III", "Type IV", "Type V", "Type VI"]
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                OnbTop(step: 8, total: 17)
                Eyebrow(text: "Phototype · 3/5").padding(.bottom, 12)
                DisplayText(text: "Ta carnation naturelle ?", size: 38)
                LeadText(text: "La couleur d'une zone jamais exposée (intérieur du bras).").padding(.top, 14)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
                        PillOption(selected: store.profile.skinTone == i, label: tr(label)) {
                            ClayAssetImage(name: ClayIMG.phototypes[i], size: 72)
                                .frame(height: 66)
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
            .onbScrollable()
        }
    }
}

// MARK: - 12 · Sun reaction
struct ScrSunReact: View {
    @EnvironmentObject var store: AppStore
    private let opts = [("flame","Brûle toujours, ne bronze jamais"),
                        ("thermo","Brûle souvent, bronze très peu"),
                        ("cloudSun","Brûle un peu, puis bronze"),
                        ("sun","Bronze facilement, brûle rarement"),
                        ("umbrella","Bronze toujours, ne brûle jamais")]
    private let assets = [ClayIMG.flame, ClayIMG.thermo, ClayIMG.cloudSun, ClayIMG.sun, ClayIMG.shield]
    var body: some View {
        OnbQuestion(step: 9, eyebrow: "Phototype · 4/5", title: "Au soleil, ta peau…") {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, o in
                OptionRow(asset: assets[i], title: tr(o.1), selected: store.profile.sunReaction == i)
                    .onTapGesture { store.profile.sunReaction = i }
            }
        }
    }
}

// MARK: - 13 · Freckles
struct ScrFreckles: View {
    @EnvironmentObject var store: AppStore
    private let opts: [(String, String, String?)] = [
        (ClayIMG.freckles,"Beaucoup","Sur tout le visage et corps"),
        (ClayIMG.freckles,"Quelques-unes","Surtout l'été au soleil"),
        (ClayIMG.skinPalette,"Très peu", nil),
        (ClayIMG.skinPalette,"Aucune", nil)
    ]
    var body: some View {
        OnbQuestion(step: 10, eyebrow: "Phototype · 5/5", title: "Des taches de rousseur ?") {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, o in
                OptionRow(asset: o.0, title: tr(o.1), sub: o.2.map(tr), selected: store.profile.freckles == i)
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
    @State private var isLoading = true
    @State private var analysisStep = 0
    @State private var spin: Double = 0

    private var progress: Double { Double(min(analysisStep, steps.count)) / Double(steps.count) }
    private var currentLabel: String {
        analysisStep < steps.count ? steps[analysisStep].0 : "Finalisation"
    }

    private var type: Fitzpatrick { PhototypeScoring.compute(from: store.profile) }
    private var typeAsset: String { ClayIMG.phototypes[type.rawValue - 1] }
    private let steps: [(String, String)] = [
        ("Carnation", ClayIMG.skinPalette),
        ("Cheveux", "clay_hair_alt"),
        ("Yeux", "clay_eye_alt"),
        ("Réaction solaire", ClayIMG.sun),
        ("Taches de rousseur", ClayIMG.freckles)
    ]

    var body: some View {
        ScreenScaffold(
            background: LinearGradient(colors: [
                Color(oklch: 0.50, 0.09, 58), Color(oklch: 0.30, 0.05, 52), Color(oklch: 0.22, 0.03, 50)
            ], startPoint: .top, endPoint: .bottom),
            lightStatusBar: true
        ) {
            if isLoading {
                VStack(spacing: 0) {
                    Spacer()

                    // Spinner circulaire
                    ZStack {
                        // Halo ambiant
                        Circle()
                            .fill(RadialGradient(colors: [Palette.gold.opacity(0.22), .clear],
                                                 center: .center, startRadius: 8, endRadius: 150))
                            .frame(width: 300, height: 300)
                            .blur(radius: 8)

                        // Rail
                        Circle()
                            .stroke(.white.opacity(0.10), lineWidth: 7)
                            .frame(width: 196, height: 196)

                        // Progression
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                AngularGradient(colors: [Palette.gold.opacity(0.55), Palette.gold, .white],
                                                center: .center),
                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                            )
                            .frame(width: 196, height: 196)
                            .rotationEffect(.degrees(-90))

                        // Arc qui tourne en continu
                        Circle()
                            .trim(from: 0, to: 0.14)
                            .stroke(Palette.gold, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .frame(width: 196, height: 196)
                            .rotationEffect(.degrees(spin))

                        // Coeur : icône de l'étape en cours
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.06))
                                .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
                                .frame(width: 156, height: 156)

                            if analysisStep < steps.count {
                                ClayAssetImage(name: steps[analysisStep].1, size: 92)
                                    .id(analysisStep)
                                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                            } else {
                                Icon(name: "check", size: 48, stroke: 3)
                                    .foregroundStyle(Palette.gold)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .frame(width: 300, height: 300)

                    // Étape courante + pourcentage
                    VStack(spacing: 10) {
                        Text(currentLabel)
                            .font(SolaFont.body(18, weight: .semibold))
                            .foregroundStyle(.white)
                            .id(currentLabel)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        Text("Analyse de ton phototype")
                            .font(SolaFont.body(13))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.top, 28)

                    // Points d'étape
                    HStack(spacing: 9) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Circle()
                                .fill(i < analysisStep ? Palette.gold
                                      : (i == analysisStep ? Palette.gold.opacity(0.7) : .white.opacity(0.18)))
                                .frame(width: i == analysisStep ? 9 : 7,
                                       height: i == analysisStep ? 9 : 7)
                        }
                    }
                    .padding(.top, 22)

                    Spacer()
                }
                .padding(.horizontal, Frame.padH)
                .onAppear {
                    withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                        spin = 360
                    }
                }
            } else {
                VStack(spacing: 0) {
                    Spacer()
                    Badge(text: "Profil établi", icon: "check", style: .amber).padding(.bottom, 22)
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [type.swatch.opacity(0.40), type.swatch.opacity(0.08), .clear],
                                                 center: .center, startRadius: 14, endRadius: 105))
                            .frame(width: 230, height: 230)
                            .blur(radius: 2)
                        ClayAssetImage(name: typeAsset, size: 164)
                            .overlay(
                                Circle()
                                    .stroke(Palette.gold.opacity(0.30), lineWidth: 1)
                                    .frame(width: 164, height: 164)
                            )
                        Text(type.roman)
                            .font(SolaFont.display(22, weight: .heavy))
                            .foregroundStyle(Palette.onAmber)
                            .frame(width: 48, height: 34)
                            .background(Capsule().fill(Palette.gold))
                            .overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 1))
                            .offset(y: 78)
                    }
                    .padding(.bottom, 28)

                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Eyebrow(text: "Fitzpatrick", color: .white.opacity(0.65))
                            DisplayText(text: tr(type.title), size: 42, color: .white)
                                .multilineTextAlignment(.center)
                        }
                        LeadText(text: tr(type.summary), color: .white.opacity(0.82))
                            .multilineTextAlignment(.center).frame(maxWidth: 320)
                    }

                    VStack(spacing: 12) {
                        HStack(spacing: 11) {
                            revealStat(top: "~\(type.safeMinutesAtUV8)", unit: "min", label: "sans brûler")
                            revealStat(top: "SPF \(type.recommendedSPF)", unit: "", label: "minimum")
                        }
                        HStack(spacing: 11) {
                            revealStat(top: "\(type.safeMinutesAtUV8 * 3)", unit: "min", label: "exposition max")
                            revealStat(top: type.roman, unit: "", label: "classe UV")
                        }
                    }
                    .padding(.top, 32)

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
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .onbScrollable()
            }
        }
        .onAppear {
            if isLoading {
                let stepDuration = 0.85
                for i in 0...steps.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stepDuration) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            analysisStep = i
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(steps.count) * stepDuration + 0.7) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isLoading = false
                    }
                }
            }
        }
    }

    private func revealStat(top: String, unit: String, label: String) -> some View {
        VStack(spacing: 6) {
            (Text(top).font(SolaFont.display(20, weight: .heavy))
             + Text(unit).font(SolaFont.body(12, weight: .semibold)))
                .foregroundStyle(.white)
            Text(label).font(SolaFont.body(11.5)).foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16).padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1))
        )
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
                OnbTop(step: step, total: 17)
                Eyebrow(text: tr(eyebrow)).padding(.bottom, 12)
                DisplayText(text: tr(title), size: 38)
                content().padding(.top, 28)
                Spacer()
                SolaButton(title: "Continuer") { ctrl.next { flow.finishOnboarding() } }.padding(.bottom, 18)
            }
            .padding(.horizontal, Frame.padH)
            .onbScrollable()
        }
    }
}
