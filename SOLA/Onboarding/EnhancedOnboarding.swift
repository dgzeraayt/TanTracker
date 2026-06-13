import SwiftUI

// MARK: - Interactive Quiz Screen
struct InteractiveQuizStep: View {
    let question: String
    let description: String
    let options: [(icon: String, title: String, subtitle: String)]
    @State private var selectedIndex: Int?
    var onSelect: (Int) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisplayText(text: question, size: 32, color: Palette.ink)
                .padding(.bottom, 12)
            LeadText(text: description, size: 14).padding(.bottom, 24)

            VStack(spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedIndex = i
                            HapticsManager.shared.select()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSelect(i)
                        }
                    }) {
                        HStack(spacing: 14) {
                            Icon(name: option.icon, size: 24)
                                .foregroundStyle(selectedIndex == i ? Palette.gold : Palette.bronze)
                                .frame(width: 50, height: 50)
                                .background(GlassPanel(radius: 14,
                                                       tint: selectedIndex == i ? Palette.ink : Palette.surface,
                                                       tintOpacity: selectedIndex == i ? 0.72 : 0.30))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(SolaFont.body(15, weight: .semibold))
                                    .foregroundStyle(selectedIndex == i ? Palette.inkOn : Palette.ink)
                                Text(option.subtitle)
                                    .font(SolaFont.body(12))
                                    .foregroundStyle(selectedIndex == i ? Palette.inkOn.opacity(0.72) : Palette.ink3)
                            }

                            Spacer()

                            if selectedIndex == i {
                                Icon(name: "check", size: 18, stroke: 2.6)
                                    .foregroundStyle(.white)
                                    .celebration(true)
                            }
                        }
                        .padding(14)
                        .background(GlassPanel(radius: Radius.md,
                                               tint: selectedIndex == i ? Palette.ink : Palette.surface,
                                               tintOpacity: selectedIndex == i ? 0.74 : 0.30))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .stroke(selectedIndex == i ? Palette.ink.opacity(0.70) : Palette.line.opacity(0.48), lineWidth: 1.5)
                        )
                        .scaleEffect(selectedIndex == i ? 1.02 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Animated Progress Ring
struct AnimatedOnboardingProgress: View {
    let current: Int
    let total: Int
    var size: CGFloat = 100

    @State private var progress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.lineSoft, lineWidth: 8)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [Palette.gold, Palette.amberDeep],
                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text("\(current)/\(total)")
                    .font(SolaFont.display(size * 0.3, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("Étapes").font(SolaFont.body(11)).foregroundStyle(Palette.ink3)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                progress = Double(current) / Double(total)
            }
        }
        .onChange(of: current) { _, _ in
            withAnimation(.easeOut(duration: 0.5)) {
                progress = Double(current) / Double(total)
            }
        }
    }
}

// MARK: - Phototype Visual Preview
struct PhototypePreview: View {
    let fitzpatrick: Fitzpatrick
    var size: CGFloat = 80

    private var skinColor: Color {
        switch fitzpatrick {
        case .I: return Color(oklch: 0.92, 0.04, 70)
        case .II: return Color(oklch: 0.88, 0.06, 60)
        case .III: return Color(oklch: 0.82, 0.08, 50)
        case .IV: return Color(oklch: 0.70, 0.10, 45)
        case .V: return Color(oklch: 0.55, 0.12, 40)
        case .VI: return Color(oklch: 0.40, 0.08, 35)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(skinColor)
                .overlay(
                    Circle().stroke(Palette.line, lineWidth: 1)
                )
                .frame(width: size, height: size)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)

            Text(fitzpatrick.roman)
                .font(SolaFont.display(14, weight: .bold))
                .foregroundStyle(Palette.ink)
        }
    }
}

// MARK: - Enhanced Phototype Quiz
struct EnhancedPhototypeQuiz: View {
    @State private var currentStep = 0
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow

    let steps: [(String, String, String)] = [
        ("Carnation", "Comment tu décris ta peau naturelle?", "Aucun bronzage"),
        ("Cheveux", "Quelle est la couleur naturelle de tes cheveux?", "Sans modification"),
        ("Yeux", "Quelle est la couleur de tes yeux?", "Vue claire"),
        ("Réaction", "Comment ta peau réagit au soleil?", "Première exposition"),
        ("Taches", "As-tu des taches de rousseur?", "Naturelles ou rares")
    ]

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                // Progress header
                HStack(alignment: .center, spacing: 16) {
                    Button(action: { if currentStep > 0 { currentStep -= 1 } }) {
                        Icon(name: "arrowL", size: 22).foregroundStyle(Palette.ink)
                    }
                    .opacity(currentStep > 0 ? 1 : 0.3)
                    .disabled(currentStep == 0)

                    Spacer()

                    AnimatedOnboardingProgress(current: currentStep + 1, total: steps.count, size: 70)

                    Spacer()

                    Button(action: {}) {
                        Text("Ignorer").font(SolaFont.body(13)).foregroundStyle(Palette.ink3)
                    }
                }
                .padding(.top, 4)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        let (title, _, _) = steps[currentStep]

                        // Step indicator
                        Badge(text: title, style: .amber)
                            .padding(.top, 20).padding(.bottom, 12)

                        // Content based on step
                        if currentStep == 0 {
                            carnationQuiz()
                        } else if currentStep == 1 {
                            hairColorQuiz()
                        } else if currentStep == 2 {
                            eyeColorQuiz()
                        } else if currentStep == 3 {
                            reactionQuiz()
                        } else {
                            frecklesQuiz()
                        }

                        Spacer()
                    }
                    .padding(.horizontal, Frame.padH)
                }

                // Navigation
                HStack(spacing: 12) {
                    if currentStep > 0 {
                        Button(action: { currentStep -= 1 }) {
                            Text("Précédent")
                                .font(SolaFont.body(14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(Palette.ink)
                                .background(GlassPanel(radius: Radius.pill, tint: Palette.surface, tintOpacity: 0.30))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if currentStep < steps.count - 1 {
                        Button(action: { currentStep += 1 }) {
                            Text("Suivant")
                                .font(SolaFont.body(14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(.white)
                                .background(Palette.amberDeep)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        SolaButton(title: "Voir mon phototype", kind: .amber, isCTA: true) {
                            ctrl.next { flow.finishOnboarding() }
                        }
                    }
                }
                .padding(.horizontal, Frame.padH)
                .padding(.bottom, 18)
            }
        }
    }

    @ViewBuilder private func carnationQuiz() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            DisplayText(text: "Quelle est ta carnation?", size: 28)
            LeadText(text: "En l'absence de bronzage, comment tu décris naturellement ta peau?")

            HStack(spacing: 12) {
                ForEach([Fitzpatrick.I, .II, .III, .IV, .V, .VI], id: \.self) { fitz in
                    Button(action: { store.profile.phototype = fitz }) {
                        PhototypePreview(fitzpatrick: fitz, size: 60)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private func hairColorQuiz() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            DisplayText(text: "Couleur de cheveux", size: 28)
            LeadText(text: "Quelle est ta couleur naturelle?")

            VStack(spacing: 10) {
                ForEach([("Très clair", Color(oklch: 0.92, 0.02, 60)), ("Clair", Color(oklch: 0.85, 0.03, 55)), ("Châtain clair", Color(oklch: 0.70, 0.06, 45)), ("Châtain", Color(oklch: 0.55, 0.08, 40)), ("Brun foncé", Color(oklch: 0.40, 0.05, 35)), ("Noir", Color(oklch: 0.25, 0.02, 20))], id: \.0) { label, color in
                    HStack(spacing: 12) {
                        Circle().fill(color).frame(width: 40, height: 40)
                        Text(label).font(SolaFont.body(14, weight: .semibold)).foregroundStyle(Palette.ink)
                        Spacer()
                    }
                    .padding(12)
                    .background(GlassPanel(radius: Radius.md, tint: Palette.surface, tintOpacity: 0.30))
                    .cornerRadius(Radius.md)
                }
            }
        }
    }

    @ViewBuilder private func eyeColorQuiz() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            DisplayText(text: "Couleur des yeux", size: 28)
            LeadText(text: "Quelle est ta teinte d'yeux naturelle?")

            VStack(spacing: 10) {
                ForEach([("Bleus", Color.blue), ("Verts", Color.green), ("Noisette", Color(oklch: 0.70, 0.08, 45)), ("Marron", Color(oklch: 0.50, 0.05, 40)), ("Noirs", Color.black)], id: \.0) { label, color in
                    HStack(spacing: 12) {
                        Circle().fill(color).frame(width: 40, height: 40)
                        Text(label).font(SolaFont.body(14, weight: .semibold)).foregroundStyle(Palette.ink)
                        Spacer()
                    }
                    .padding(12)
                    .background(GlassPanel(radius: Radius.md, tint: Palette.surface, tintOpacity: 0.30))
                    .cornerRadius(Radius.md)
                }
            }
        }
    }

    @ViewBuilder private func reactionQuiz() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            DisplayText(text: "Réaction au soleil", size: 28)
            LeadText(text: "Qu'est-ce qui arrive à ta peau en première exposition?")

            VStack(spacing: 10) {
                ForEach([("Brûle systématiquement", "flame"), ("Brûle facilement", "alertTri"), ("Brûle légèrement", "clock"), ("Brûle rarement", "sun"), ("Brûle très rarement", "sunFull")], id: \.0) { label, icon in
                    HStack(spacing: 12) {
                        Icon(name: icon, size: 24).foregroundStyle(Palette.terra)
                        Text(label).font(SolaFont.body(14, weight: .semibold)).foregroundStyle(Palette.ink)
                        Spacer()
                    }
                    .padding(12)
                    .background(GlassPanel(radius: Radius.md, tint: Palette.surface, tintOpacity: 0.30))
                    .cornerRadius(Radius.md)
                }
            }
        }
    }

    @ViewBuilder private func frecklesQuiz() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            DisplayText(text: "Taches de rousseur", size: 28)
            LeadText(text: "As-tu des taches de rousseur naturelles?")

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Circle().fill(Palette.bronze).frame(width: 40, height: 40)
                    Text("Oui, j'en ai").font(SolaFont.body(14, weight: .semibold)).foregroundStyle(Palette.ink)
                    Spacer()
                }
                .padding(12)
                .background(GlassPanel(radius: Radius.md, tint: Palette.surface, tintOpacity: 0.30))
                .cornerRadius(Radius.md)

                HStack(spacing: 12) {
                    Circle().fill(Palette.lineSoft).frame(width: 40, height: 40)
                    Text("Non, aucune").font(SolaFont.body(14, weight: .semibold)).foregroundStyle(Palette.ink)
                    Spacer()
                }
                .padding(12)
                .background(GlassPanel(radius: Radius.md, tint: Palette.surface, tintOpacity: 0.30))
                .cornerRadius(Radius.md)
            }
        }
    }
}
