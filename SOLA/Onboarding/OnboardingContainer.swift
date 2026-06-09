import SwiftUI

final class OnboardingController: ObservableObject {
    @Published var index: Int = 0
    let count: Int

    init(count: Int) { self.count = count }

    func next(complete: () -> Void) {
        if index >= count - 1 { complete() }
        else { withAnimation(.easeInOut(duration: 0.28)) { index += 1 } }
    }
    func back() {
        if index > 0 { withAnimation(.easeInOut(duration: 0.28)) { index -= 1 } }
    }
    func skip(complete: () -> Void) { complete() }
}

struct OnboardingContainer: View {
    @EnvironmentObject private var flow: AppFlow
    @StateObject private var ctrl = OnboardingController(count: 30)

    init() {
        #if DEBUG
        if let s = ProcessInfo.processInfo.environment["SOLA_ONB"], let n = Int(s) {
            let c = OnboardingController(count: 30); c.index = n
            _ctrl = StateObject(wrappedValue: c)
        }
        #endif
    }

    var body: some View {
        ZStack {
            ForEach(0..<30, id: \.self) { i in
                if i == ctrl.index {
                    screen(for: i)
                        .environmentObject(ctrl)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)))
                }
            }
        }
    }

    @ViewBuilder
    func screen(for i: Int) -> some View {
        switch i {
        case 0:  ScrWelcome()
        case 1:  ScrIntro1()
        case 2:  ScrIntro2()
        case 3:  ScrIntro3()
        case 4:  ScrReferral()
        case 5:  ScrGender()
        case 6:  ScrName()
        case 7:  ScrAge()
        case 8:  ScrPhotoIntro()
        case 9:  ScrEyes()
        case 10: ScrHair()
        case 11: ScrSkin()
        case 12: ScrSunReact()
        case 13: ScrFreckles()
        case 14: ScrPhototype()
        case 15: ScrGoal()
        case 16: ScrTanLevel()
        case 17: ScrWhere()
        case 18: ScrFrequency()
        case 19: ScrConcerns()
        case 20: ScrSPF()
        case 21: ScrRisks()
        case 22: ScrLocation()
        case 23: ScrNotif()
        case 24: ScrRating()
        case 25: ScrPhotoCapture()
        case 26: ScrAnalyzing()
        case 27: ScrResults()
        case 28: ScrPlanReady()
        default: ScrPaywall()
        }
    }
}

// Bouton "next" partagé qui pilote le contrôleur d'onboarding.
extension View {
    func onbNext(_ ctrl: OnboardingController, _ flow: AppFlow) -> some View {
        self
    }
}

// En-tête d'onboarding : retour + segments de progression
struct OnbTop: View {
    var step: Int
    var total: Int
    var onlyBack: Bool = false
    @EnvironmentObject var ctrl: OnboardingController

    var body: some View {
        HStack(spacing: 14) {
            Button { ctrl.back() } label: {
                Icon(name: "chevL", size: 20)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Palette.surface2))
            }
            .buttonStyle(.plain)
            if !onlyBack {
                Segments(total: total, filled: step)
            }
        }
        .padding(.top, 6).padding(.bottom, 22)
    }
}

// Shell générique d'écran-question (eyebrow + titre + options + CTA)
struct OnbQuestion<Content: View>: View {
    var step: Int
    var total: Int = 16
    var eyebrow: String? = nil
    var title: String
    var sub: String? = nil
    var cta: String = "Continuer"
    var ctaKind: SolaButtonKind = .primary
    var footnote: String? = nil
    @ViewBuilder var content: () -> Content

    @EnvironmentObject var ctrl: OnboardingController
    @EnvironmentObject var flow: AppFlow

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        OnbTop(step: step, total: total)
                        if let eyebrow { Eyebrow(text: eyebrow).padding(.bottom, 12) }
                        DisplayText(text: title, size: 38)
                        if let sub { LeadText(text: sub).padding(.top, 14) }
                        VStack(spacing: 11) { content() }.padding(.top, 26)
                    }
                    .padding(.horizontal, Frame.padH)
                }
                VStack(spacing: 12) {
                    if let footnote {
                        HStack(spacing: 6) {
                            Icon(name: "lock", size: 13)
                            Text(footnote)
                        }
                        .font(SolaFont.body(12.5))
                        .foregroundStyle(Palette.ink3)
                    }
                    SolaButton(title: cta, kind: ctaKind) {
                        ctrl.next { flow.finishOnboarding() }
                    }
                }
                .padding(.horizontal, Frame.padH)
                .padding(.top, 12).padding(.bottom, 18)
            }
        }
    }
}
