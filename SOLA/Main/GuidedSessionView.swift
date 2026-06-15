import SwiftUI

// MARK: - Séance guidée pas-à-pas
// Parcours plein écran qui tient la main à l'utilisateur, une étape à la fois :
// 1) Mets ta crème → 2) Bronze côté face (minuteur) → 3) Retourne-toi côté dos
// (minuteur) → 4) Remets de la crème. Réutilise ExposureTimer pour les décomptes,
// HapticsManager / LiveActivityManager / NotificationManager pour l'assistance.
// Chaque étape franchie coche la routine du jour correspondante (indices 10–13).
struct GuidedSessionView: View {
    let safeMinutes: Int
    let uv: Double
    let spf: Int

    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var timer = ExposureTimer()

    @State private var stepIndex = 0
    @State private var elapsedAccum: TimeInterval = 0   // temps de bronzage cumulé (phases)
    @State private var logged = false
    @State private var activityStarted = false

    private var perFace: Int { max(1, safeMinutes / 2) }

    private enum Kind { case info, timer }
    private struct Step {
        let kind: Kind
        let icon: String        // SF Symbol
        let title: String
        let subtitle: String
        let cta: String         // libellé du bouton primaire
        let routine: Int        // index routine du jour à cocher (10–13)
        let minutes: Int        // durée (étapes timer)
    }

    private var steps: [Step] {
        [
            Step(kind: .info, icon: "drop.fill",
                 title: "Mets ta crème SPF \(spf)",
                 subtitle: "Sur toutes les zones exposées, avant de sortir.",
                 cta: "C'est fait", routine: 10, minutes: 0),
            Step(kind: .timer, icon: "sun.max.fill",
                 title: "Bronze côté face",
                 subtitle: "\(perFace) min — commence allongé sur le dos.",
                 cta: "Démarrer", routine: 11, minutes: perFace),
            Step(kind: .timer, icon: "arrow.triangle.2.circlepath",
                 title: "Retourne-toi · côté dos",
                 subtitle: "\(perFace) min — retourne-toi sur le ventre.",
                 cta: "Démarrer", routine: 12, minutes: perFace),
            Step(kind: .info, icon: "drop.fill",
                 title: "Remets de la crème",
                 subtitle: "Surtout après une baignade. Pense à t'hydrater.",
                 cta: "Terminé", routine: 13, minutes: 0)
        ]
    }

    private var step: Step { steps[stepIndex] }
    private var isLast: Bool { stepIndex == steps.count - 1 }

    var body: some View {
        ScreenScaffold(
            background: LinearGradient(colors: [
                Color(oklch: 0.46, 0.09, 54), Color(oklch: 0.24, 0.04, 50)
            ], startPoint: .top, endPoint: .bottom),
            lightStatusBar: true
        ) {
            VStack(spacing: 0) {
                header
                Spacer()
                content
                Spacer()
                footer
            }
            .padding(.horizontal, Frame.padH).padding(.top, 8).padding(.bottom, 24)
            .animation(.easeInOut(duration: 0.3), value: stepIndex)
            .animation(.easeInOut(duration: 0.25), value: timer.finished)
        }
        .onAppear { configureForStep() }
        .onChange(of: stepIndex) { _, _ in configureForStep() }
        .onChange(of: timer.finished) { _, done in
            guard done, step.kind == .timer else { return }
            HapticsManager.shared.success()
            // Laisse voir « Terminé » une seconde, puis enchaîne — sauf si l'utilisateur
            // a déjà avancé manuellement entre-temps (évite un double saut d'étape).
            let idx = stepIndex
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if stepIndex == idx { advance() }
            }
        }
        .onChange(of: timer.progress) { _, p in
            if timer.running {
                LiveActivityManager.shared.update(
                    progress: p, endDate: Date().addingTimeInterval(timer.remaining), paused: false)
            }
        }
        .onDisappear {
            // Sortie anticipée : clôt proprement la Live Activity (sans état « atteint »).
            if !logged { LiveActivityManager.shared.end(reached: false) }
        }
    }

    // MARK: En-tête (fermer + progression d'étapes)
    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Icon(name: "chevD", size: 22).foregroundStyle(.white)
                    .frame(width: 46, height: 46).background(Circle().fill(.white.opacity(0.18)))
            }.buttonStyle(.plain)
            Spacer()
            HStack(spacing: 7) {
                ForEach(steps.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= stepIndex ? Palette.gold : Color.white.opacity(0.22))
                        .frame(width: i == stepIndex ? 22 : 9, height: 9)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: stepIndex)
                }
            }
        }
    }

    // MARK: Contenu de l'étape
    @ViewBuilder private var content: some View {
        VStack(spacing: 22) {
            Text("ÉTAPE \(stepIndex + 1) / \(steps.count)")
                .font(SolaFont.mono(12)).tracking(2).foregroundStyle(.white.opacity(0.55))

            if step.kind == .timer {
                timerRing
            } else {
                Image(systemName: step.icon)
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(Palette.gold)
                    .frame(width: 150, height: 150)
                    .background(Circle().fill(.white.opacity(0.08)))
            }

            VStack(spacing: 8) {
                Text(step.title)
                    .font(SolaFont.display(26, weight: .heavy)).tracking(-0.4)
                    .foregroundStyle(.white).multilineTextAlignment(.center)
                Text(step.subtitle)
                    .font(SolaFont.body(15)).foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
        }
        .id(stepIndex)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
    }

    private var timerRing: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.15), lineWidth: 16).frame(width: 200, height: 200)
            Circle().trim(from: 0, to: timer.progress)
                .stroke(timer.finished ? Palette.alert : Palette.gold,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90)).frame(width: 200, height: 200)
                .animation(.linear(duration: 0.2), value: timer.progress)
            VStack(spacing: 4) {
                Image(systemName: step.icon)
                    .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                if timer.finished {
                    Text("TERMINÉ").font(SolaFont.display(28, weight: .heavy)).foregroundStyle(.white)
                } else {
                    Text(timer.remainingLabel)
                        .font(SolaFont.display(46, weight: .heavy)).foregroundStyle(.white)
                    Text("restant").font(SolaFont.body(13)).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: Bouton primaire
    @ViewBuilder private var footer: some View {
        if step.kind == .info {
            SolaButton(title: step.cta, kind: .amber, icon: "check") { advance() }
        } else if timer.finished {
            SolaButton(title: isLast ? "Terminer" : "Étape suivante", kind: .light, icon: nil) { advance() }
        } else if timer.running {
            SolaButton(title: "Mettre en pause", kind: .light, icon: nil) { timer.pause() }
        } else {
            SolaButton(title: timer.elapsed > 0 ? "Reprendre" : step.cta, kind: .amber, icon: "timer") {
                startCurrentTimer()
            }
        }
    }

    // MARK: Logique
    private func configureForStep() {
        if step.kind == .timer { timer.configure(minutes: step.minutes) }
    }

    private func startCurrentTimer() {
        timer.start()
        guard !activityStarted else { return }
        activityStarted = true
        let prefs = store.data.notifPrefs
        let total = TimeInterval(safeMinutes * 60)
        if usedSPFHabit, prefs.spfReminders { notifications.scheduleSPFReminder(spf: spf) }
        if prefs.burnAlerts { notifications.scheduleBurnAlert(after: total) }
        LiveActivityManager.shared.start(
            city: store.profile.city, uv: uv, safeMinutes: safeMinutes,
            endDate: Date().addingTimeInterval(total))
    }

    private var usedSPFHabit: Bool { store.profile.spfHabit > 0 }

    private func advance() {
        // Cumule le temps de bronzage de l'étape timer qu'on quitte.
        if step.kind == .timer { elapsedAccum += timer.elapsed }
        // Coche la routine du jour correspondante.
        if !store.isRoutineDone(step.routine) { store.toggleRoutine(step.routine) }

        if isLast {
            finish()
        } else {
            HapticsManager.shared.select()
            stepIndex += 1
        }
    }

    private func finish() {
        guard !logged else { dismiss(); return }
        logged = true
        HapticsManager.shared.success()
        let minutes = max(1, Int(elapsedAccum / 60))
        store.addSession(TanSession(durationMinutes: minutes, usedSPF: usedSPFHabit, uvIndex: uv,
                                    note: "Séance guidée"))
        LiveActivityManager.shared.end(reached: true)
        dismiss()
    }
}
