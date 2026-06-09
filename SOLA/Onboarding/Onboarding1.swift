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
                            Text("SOLA")
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
                HStack {
                    Spacer()
                    Button { ctrl.skip { flow.finishOnboarding() } } label: {
                        Text("Passer").font(SolaFont.mono(12.5)).foregroundStyle(Palette.ink3)
                    }.buttonStyle(.plain)
                    .opacity(isAnimating ? 1 : 0)
                }
                .padding(.top, 6).padding(.bottom, 18)
                .padding(.horizontal, Frame.padH)

                VStack(alignment: .leading, spacing: 0) {
                    RemoteImage(url: img, tone: tone)
                        .frame(height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        .scaleEffect(isAnimating ? 1 : 0.9)
                        .opacity(isAnimating ? 1 : 0)
                    Eyebrow(text: eyebrowLabel).padding(.top, 30).padding(.bottom, 12)
                        .offset(y: isAnimating ? 0 : 10)
                        .opacity(isAnimating ? 1 : 0)
                    DisplayText(text: title, size: 38)
                        .offset(y: isAnimating ? 0 : 10)
                        .opacity(isAnimating ? 1 : 0)
                    LeadText(text: bodyText).padding(.top, 14)
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
                   bodyText: "SOLA suit ton bronzage en temps réel et t'affiche tes progrès vers ta teinte rêvée. Tu sais exactement où tu en es.",
                   accent: Palette.terra)
    }
}
struct ScrIntro2: View {
    var body: some View {
        IntroSlide(idx: 1, img: IMG.beach, tone: .base,
                   eyebrowLabel: "Fenêtre UV idéale", eyebrowIcon: "cloudSun",
                   title: "S'exposer au moment\nperfait",
                   bodyText: "SOLA calcule l'indice UV de ta région et te dit quand c'est le bon moment pour bronzer. Pas de devinette, juste de la science.",
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
                    .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .stroke(nameFocused ? Palette.ink : Palette.lineSoft, lineWidth: 1.5)))
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
        }
    }
}

// MARK: - 8 · Âge
struct ScrAge: View {
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var store: AppStore
    @GestureState private var dragAccum: CGFloat = 0
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

// MARK: - 9 · Phototype intro
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
                OnbTop(step: 5, total: 17, onlyBack: true)
                Spacer()
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.ink)
                    .frame(width: 72, height: 72)
                    .overlay(Icon(name: "palette", size: 34).foregroundStyle(Palette.gold))
                    .padding(.bottom, 26)
                Eyebrow(text: "Étape 1 sur 3 · Ton profil de peau").padding(.bottom, 12)
                DisplayText(text: "Trouvons ton phototype", size: 46)
                LeadText(text: "5 questions rapides sur ta peau, tes yeux et comment tu réagis au soleil. C'est l'échelle Fitzpatrick, la fondation de tout ce qu'on te recommandera.").padding(.top, 16)
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
        QuizGridScreen(step: 6, eyebrow: "Phototype · 1/5", title: "Couleur de tes yeux ?") {
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
        QuizGridScreen(step: 7, eyebrow: "Phototype · 2/5", title: "Couleur naturelle de tes cheveux ?") {
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
                OnbTop(step: 8, total: 17)
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
                        ("thermo","Brûle souvent, bronze très peu"),
                        ("cloudSun","Brûle un peu, puis bronze"),
                        ("sun","Bronze facilement, brûle rarement"),
                        ("umbrella","Bronze toujours, ne brûle jamais")]
    var body: some View {
        OnbQuestion(step: 9, eyebrow: "Phototype · 4/5", title: "Au soleil, ta peau…") {
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
        ("spots","Beaucoup","Sur tout le visage et corps"),
        ("sparkle","Quelques-unes","Surtout l'été au soleil"),
        ("drop","Très peu", nil),
        ("user","Aucune", nil)
    ]
    var body: some View {
        OnbQuestion(step: 10, eyebrow: "Phototype · 5/5", title: "Des taches de rousseur ?") {
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
    @State private var isLoading = true
    @State private var analysisStep = 0

    private var type: Fitzpatrick { PhototypeScoring.compute(from: store.profile) }
    private let steps = ["Carnation", "Cheveux", "Yeux", "Réaction solaire", "Taches de rousseur"]

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
                    VStack(spacing: 32) {
                        VStack(spacing: 16) {
                            ForEach(0..<steps.count, id: \.self) { i in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(i < analysisStep ? Palette.gold :
                                                  i == analysisStep ? Palette.amberDeep : Palette.surface2)
                                            .frame(width: 36, height: 36)
                                        if i < analysisStep {
                                            Icon(name: "check", size: 16, stroke: 2).foregroundStyle(Palette.onAmber)
                                        } else {
                                            Text("\(i + 1)")
                                                .font(SolaFont.display(14, weight: .heavy))
                                                .foregroundStyle(i == analysisStep ? Palette.onAmber : Palette.ink3)
                                        }
                                    }
                                    Text(steps[i])
                                        .font(SolaFont.body(15, weight: i <= analysisStep ? .semibold : .regular))
                                        .foregroundStyle(i <= analysisStep ? .white : .white.opacity(0.5))
                                    Spacer()
                                }
                                if i < steps.count - 1 {
                                    VStack {
                                        Spacer().frame(height: 4)
                                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                                            .fill(i < analysisStep ? Palette.gold.opacity(0.6) : Palette.surface2)
                                            .frame(height: 2)
                                            .frame(maxWidth: .infinity)
                                            .padding(.leading, 18)
                                        Spacer().frame(height: 4)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.white.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.white.opacity(0.1), lineWidth: 1)))

                        VStack(spacing: 8) {
                            Text("Analyse de ton phototype")
                                .font(SolaFont.body(14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            ProgressView(value: Double(analysisStep) / Double(steps.count))
                                .tint(Palette.gold)
                                .frame(height: 3)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, Frame.padH)
            } else {
                VStack(spacing: 0) {
                    Spacer()
                    Badge(text: "Profil établi", icon: "check", style: .amber).padding(.bottom, 22)
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [type.swatch, type.swatch.opacity(0.8)],
                                                center: .init(x: 0.35, y: 0.35), startRadius: 10, endRadius: 70))
                            .frame(width: 140, height: 140)
                            .overlay(
                                Circle()
                                    .stroke(Palette.gold.opacity(0.3), lineWidth: 1)
                                    .frame(width: 160, height: 160)
                            )
                            .shadow(color: type.swatch.opacity(0.5), radius: 40, x: 0, y: 20)
                        Text(type.roman)
                            .font(SolaFont.display(56, weight: .heavy))
                            .foregroundStyle(Palette.onAmber)
                    }
                    .padding(.bottom, 28)

                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Eyebrow(text: "Fitzpatrick", color: .white.opacity(0.65))
                            DisplayText(text: type.title, size: 42, color: .white)
                                .multilineTextAlignment(.center)
                        }
                        LeadText(text: type.summary, color: .white.opacity(0.82))
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
            }
        }
        .onAppear {
            if isLoading {
                for i in 0...steps.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.35) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            analysisStep = i
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(steps.count) * 0.35 + 0.6) {
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
