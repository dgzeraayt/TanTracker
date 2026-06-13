import SwiftUI

// MARK: - Routine Step Guide
struct RoutineStepGuide: Identifiable {
    let id: Int
    let title: String
    let description: String
    let icon: String
    let tips: [String]
    let duration: Int? // en minutes
    let videoUrl: String? = nil
}

extension RoutineStepGuide {
    static let allSteps: [RoutineStepGuide] = [
        RoutineStepGuide(
            id: 0,
            title: "Exposé",
            description: "Sors-toi! C'est le moment de t'exposer au soleil.",
            icon: "sun",
            tips: [
                "Expose-toi à la meilleure heure (10h-16h)",
                "La durée dépend de ton phototype et de l'indice UV",
                "Utilise un timer pour pas dépasser ta limite",
                "Si tu brûlis, rentre à l'intérieur immédiatement"
            ],
            duration: nil
        ),
        RoutineStepGuide(
            id: 1,
            title: "SPF 30",
            description: "Applique une couche généreuse de crème solaire SPF 30 minimum.",
            icon: "shield",
            tips: [
                "Réapplique toutes les 2 heures",
                "N'oublie pas les oreilles, la nuque et les pieds",
                "Attends 15 min après application avant le soleil",
                "Préfère les crèmes aux sprays (meilleure couverture)"
            ],
            duration: 3
        ),
        RoutineStepGuide(
            id: 2,
            title: "Hydrater",
            description: "Hydrate ta peau après l'exposition au soleil.",
            icon: "drop",
            tips: [
                "Utilise une brumiste ou un spray hydratant",
                "Hydrate tous les 2h pendant l'exposition",
                "Préfère l'eau thermale si possible",
                "Bois aussi 2L d'eau par jour"
            ],
            duration: 2
        ),
        RoutineStepGuide(
            id: 3,
            title: "After-sun",
            description: "Applique un soin after-sun le soir avant le coucher.",
            icon: "leaf",
            tips: [
                "Utilise un gel ou baume after-sun",
                "L'aloe vera calme les irritations légères",
                "Hydrate la peau en profondeur",
                "Aide à fixer le bronzage plus longtemps"
            ],
            duration: 5
        ),
        RoutineStepGuide(
            id: 4,
            title: "Photo",
            description: "Prends une photo de suivi pour mesurer ta progression.",
            icon: "camera",
            tips: [
                "Prends une photo dans les mêmes conditions (lumière, vêtements)",
                "Face à la caméra, en bonne lumière naturelle",
                "Évite les ombres et la lumière directe du soleil",
                "SUNY analysa ta teinte, ton éclat et l'uniformité"
            ],
            duration: 2
        )
    ]
}

// MARK: - Routine Step Detail Modal
struct RoutineStepDetailModal: View {
    let step: RoutineStepGuide
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            ScreenScaffold(background: Palette.bg) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Icon(name: "arrowL", size: 22).foregroundStyle(Palette.ink)
                        }
                        Spacer()
                    }
                    .padding(.top, 4)

                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Icon(name: step.icon, size: 40).foregroundStyle(Palette.amberDeep)
                        DisplayText(text: step.title, size: 32, color: Palette.ink)
                        LeadText(text: step.description, size: 15).lineLimit(3)
                    }
                    .padding(.top, 20)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Duration
                            if let duration = step.duration {
                                HStack(spacing: 12) {
                                    Icon(name: "timer", size: 20).foregroundStyle(Palette.terra)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Durée recommandée").font(SolaFont.body(12)).foregroundStyle(Palette.ink3)
                                        Text("\(duration) min").font(SolaFont.display(18, weight: .bold)).foregroundStyle(Palette.terra)
                                    }
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .fill(Palette.tintTerra))
                            }

                            // Tips
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Conseils")
                                    .font(SolaFont.body(14, weight: .semibold))
                                    .foregroundStyle(Palette.ink)

                                VStack(spacing: 10) {
                                    ForEach(Array(step.tips.enumerated()), id: \.offset) { i, tip in
                                        HStack(alignment: .top, spacing: 12) {
                                            Circle().fill(Palette.bronze)
                                                .frame(width: 6, height: 6)
                                                .padding(.top, 6)
                                            Text(tip)
                                                .font(SolaFont.body(13))
                                                .foregroundStyle(Palette.ink2)
                                                .lineLimit(4)
                                        }
                                    }
                                }
                            }

                            Color.clear.frame(height: 20)
                        }
                        .padding(.top, 16)
                    }

                    Spacer()

                    SolaButton(title: "J'ai compris", kind: .amber) {
                        dismiss()
                    }
                    .padding(.bottom, 18)
                }
                .padding(.horizontal, Frame.padH)
            }
        }
    }
}

// MARK: - Interactive Timer
struct InteractiveTimer: View {
    @State private var secondsRemaining: Int = 0
    @State private var isRunning = false
    @State private var timerDisplayMode: TimerDisplayMode = .input
    let maxSeconds: Int

    enum TimerDisplayMode {
        case input, running, finished
    }

    var formattedTime: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Big timer display
            ZStack {
                Circle()
                    .fill(Palette.tintGold)
                    .overlay(
                        Circle().stroke(Palette.amberDeep, lineWidth: 3)
                            .padding(16)
                    )

                VStack(spacing: 4) {
                    Text(formattedTime)
                        .font(SolaFont.display(56, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Text("d'exposition sûre")
                        .font(SolaFont.body(13))
                        .foregroundStyle(Palette.ink3)
                }
            }
            .frame(height: 240)

            // Controls
            HStack(spacing: 12) {
                if timerDisplayMode == .input {
                    Button(action: { secondsRemaining = max(0, secondsRemaining - 60) }) {
                        Icon(name: "minus", size: 20).foregroundStyle(.white)
                            .frame(height: 52)
                            .frame(maxWidth: .infinity)
                            .background(Palette.ink)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("\(secondsRemaining / 60) min")
                        .font(SolaFont.display(24, weight: .bold))
                        .foregroundStyle(Palette.ink)

                    Spacer()

                    Button(action: { secondsRemaining = min(maxSeconds, secondsRemaining + 60) }) {
                        Icon(name: "plus", size: 20).foregroundStyle(.white)
                            .frame(height: 52)
                            .frame(maxWidth: .infinity)
                            .background(Palette.amber)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else if timerDisplayMode == .running {
                    SolaButton(title: isRunning ? "Pause" : "Reprendre", kind: .amber) {
                        withAnimation {
                            isRunning.toggle()
                        }
                    }
                    SolaButton(title: "Terminer", kind: .primary) {
                        withAnimation {
                            timerDisplayMode = .finished
                            isRunning = false
                        }
                    }
                }
            }

            if timerDisplayMode == .input {
                SolaButton(title: "Démarrer le timer", kind: .amber, isCTA: true) {
                    withAnimation {
                        timerDisplayMode = .running
                        isRunning = true
                        startTimer()
                    }
                }
            }

            if timerDisplayMode == .finished {
                VStack(spacing: 12) {
                    Icon(name: "check", size: 32).foregroundStyle(Palette.gold)
                    Text("Exposition complétée !")
                        .font(SolaFont.display(20, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("Belle session de bronzage en toute sécurité 🌞")
                        .font(SolaFont.body(14))
                        .foregroundStyle(Palette.ink3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Palette.gold.opacity(0.15)))
            }
        }
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if isRunning && secondsRemaining > 0 {
                secondsRemaining -= 1
                if secondsRemaining == 0 {
                    HapticsManager.shared.success()
                    isRunning = false
                    timerDisplayMode = .finished
                }
            }
        }
    }
}

// MARK: - Enhanced Routine View
struct EnhancedRoutineView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedStep: RoutineStepGuide?
    @State private var showTimer = false

    private let routine: [(String, String)] = [
        ("Exposé","sun"), ("SPF 30","shield"), ("Hydrater","drop"),
        ("After-sun","leaf"), ("Photo","camera")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Routine du jour").font(SolaFont.display(20, weight: .bold))
                Spacer()
                Text("\(store.todayRoutine().completed.count)/5")
                    .font(SolaFont.mono(12.5)).foregroundStyle(Palette.ink3)
            }
            .padding(.top, 20).padding(.bottom, 14)

            VStack(spacing: 10) {
                ForEach(Array(routine.enumerated()), id: \.offset) { i, r in
                    let done = store.isRoutineDone(i)
                    let step = RoutineStepGuide.allSteps[i]

                    Button {
                        selectedStep = step
                    } label: {
                        HStack(spacing: 12) {
                            Icon(name: done ? "check" : r.1, size: done ? 20 : 22)
                                .foregroundStyle(done ? Palette.gold : Palette.bronze)
                                .frame(width: 44, height: 44)
                                .background(GlassPanel(radius: 12,
                                                       tint: done ? Palette.ink : Palette.surface,
                                                       tintOpacity: done ? 0.72 : 0.30))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title)
                                    .font(SolaFont.body(14, weight: .semibold))
                                    .foregroundStyle(done ? Palette.ink3 : Palette.ink)
                                Text(step.description)
                                    .font(SolaFont.body(12))
                                    .foregroundStyle(Palette.ink3)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if !done {
                                Icon(name: "arrowR", size: 16).foregroundStyle(Palette.bronze)
                            }
                        }
                        .padding(12)
                        .background(GlassPanel(radius: Radius.md,
                                               tint: done ? Palette.surface2 : Palette.surface,
                                               tintOpacity: done ? 0.22 : 0.30))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .stroke(Palette.line.opacity(0.42), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .sheet(item: $selectedStep) { step in
                        RoutineStepDetailModal(step: step)
                    }
                }
            }

            if showTimer {
                Divider().padding(.vertical, 16)
                InteractiveTimer(maxSeconds: 1800)
            }
        }
    }
}
