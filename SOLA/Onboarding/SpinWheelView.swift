import SwiftUI

// Roulette de fin d'onboarding (exit-intent) : « Tourne pour débloquer une
// réduction exclusive ». Esprit roulette de casino, calé sur la DA Goldn :
// cadre doré à ampoules, secteurs ambre/encre liserés d'or, moyeu soleil bombé,
// décélération réaliste + tics haptiques. La roue est truquée : elle s'arrête
// toujours sur le secteur gagnant, qui débouche sur l'offre unique (PromoOfferSheet).
struct SpinWheelView: View {
    /// Appelé une fois l'animation de roue terminée (→ présenter l'offre promo).
    var onFinished: () -> Void

    // Secteurs de la roue. `win` marque le secteur gagnant visé par le tirage.
    private struct Segment { let label: String; let win: Bool; let gift: Bool }
    private let segments: [Segment] = [
        Segment(label: "30 %", win: false, gift: false),
        Segment(label: String(localized: "Raté"), win: false, gift: false),
        Segment(label: "50 %", win: false, gift: false),
        Segment(label: "70 %", win: false, gift: false),
        Segment(label: "60 %", win: false, gift: false),
        Segment(label: "",     win: true,  gift: true)      // ← gagnant : le cadeau
    ]

    /// Réduction annoncée dans la pop-up de victoire (claim marketing).
    private let rewardPercent = 70

    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var didSpin = false
    @State private var hubPulse = false
    @State private var showReward = false

    // Géométrie (diamètres fixes pour un rendu net).
    private let frameD: CGFloat = 320
    private let discD: CGFloat = 274
    private let bulbCount = 24

    private var seg: Double { 360.0 / Double(segments.count) }
    private var winIndex: Int { segments.firstIndex { $0.win } ?? 0 }

    // Or de marque (dégradés du cadre et du moyeu).
    private var goldRing: AngularGradient {
        AngularGradient(colors: [Palette.amberDeep, Palette.gold, Palette.amber,
                                 Palette.gold, Palette.amberDeep],
                        center: .center)
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                Text("Tourne pour débloquer\nune réduction exclusive")
                    .font(SolaFont.display(30, weight: .heavy)).tracking(-0.6)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Frame.padH)

                Spacer(minLength: 28)

                wheel.frame(width: frameD, height: frameD)

                Spacer(minLength: 28)

                Button { Analytics.capture(.spinWheelSpun); spin() } label: {
                    Text(spinning ? "La chance tourne…" : "Tourner la roue")
                        .font(SolaFont.body(17, weight: .bold)).foregroundStyle(Palette.onAmber)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(Capsule().fill(Palette.amber))
                        .shadowSoft()
                }
                .buttonStyle(.plain)
                .pressAnimation()
                .disabled(spinning || didSpin)
                .opacity(didSpin ? 0.5 : 1)
                .padding(.horizontal, Frame.padH)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: Frame.maxContentWidth)

            if showReward { rewardPopup }
        }
    }

    // MARK: - Pop-up de victoire

    private var rewardPopup: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 14) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Palette.amber)
                    .shadowSoft()

                Text("Félicitations !")
                    .font(SolaFont.display(26, weight: .heavy)).tracking(-0.5)
                    .foregroundStyle(Palette.ink)

                Text("Tu remportes\n\(rewardPercent) % de réduction")
                    .font(SolaFont.body(17, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Analytics.capture(.spinWheelRewardClaimed(rewardPercent: rewardPercent))
                    onFinished()
                } label: {
                    Text("J'en profite")
                        .font(SolaFont.body(17, weight: .bold)).foregroundStyle(Palette.onAmber)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Capsule().fill(Palette.amber))
                        .shadowSoft()
                }
                .buttonStyle(.plain)
                .pressAnimation()
                .padding(.top, 4)
            }
            .padding(26)
            .frame(maxWidth: 340)
            .background(GlassPanel(radius: Radius.lg, tint: Palette.surface, tintOpacity: 0.96))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Palette.gold.opacity(0.6), lineWidth: 1.5))
            .shadowSoft()
            .padding(.horizontal, Frame.padH)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    // MARK: - Roue

    private var wheel: some View {
        ZStack {
            // Ombre portée douce sous l'ensemble.
            Circle().fill(Palette.ink.opacity(0.18))
                .frame(width: discD, height: discD)
                .blur(radius: 22).offset(y: 14)

            // Cadre doré extérieur (statique) + ampoules.
            Circle().fill(goldRing).frame(width: frameD, height: frameD)
            Circle().strokeBorder(Palette.amberDeep.opacity(0.55), lineWidth: 2)
                .frame(width: frameD, height: frameD)
            bulbs

            // Disque des secteurs (tourne).
            ZStack {
                ForEach(Array(segments.enumerated()), id: \.offset) { idx, segment in
                    let isDark = idx.isMultiple(of: 2)
                    WedgeShape(startAngle: angle(idx), endAngle: angle(idx + 1))
                        .fill(isDark ? darkFill : goldFill)
                    WedgeShape(startAngle: angle(idx), endAngle: angle(idx + 1))
                        .stroke(Palette.gold.opacity(0.9), lineWidth: 1.5)   // liseré or
                    segmentLabel(segment, idx: idx)
                }
            }
            .frame(width: discD, height: discD)
            .clipShape(Circle())
            .rotationEffect(.degrees(rotation))
            .overlay(Circle().strokeBorder(Palette.amberDeep, lineWidth: 3)
                        .frame(width: discD, height: discD))

            hub
            pointer
        }
    }

    // Ampoules réparties sur le cadre (statiques, comme un cadre de casino).
    private var bulbs: some View {
        ForEach(0..<bulbCount, id: \.self) { i in
            Circle()
                .fill(Palette.bg)
                .frame(width: 7, height: 7)
                .overlay(Circle().strokeBorder(Palette.amberDeep.opacity(0.5), lineWidth: 0.5))
                .shadowSoft()
                .offset(y: -(frameD/2 - 13))
                .rotationEffect(.degrees(Double(i) / Double(bulbCount) * 360))
        }
    }

    // Remplissages des secteurs (dégradés radiaux pour la profondeur).
    private var darkFill: RadialGradient {
        RadialGradient(colors: [Palette.ink2, Palette.ink], center: .center,
                       startRadius: 0, endRadius: discD / 2)
    }
    private var goldFill: RadialGradient {
        RadialGradient(colors: [Palette.gold, Palette.amber], center: .center,
                       startRadius: 0, endRadius: discD / 2)
    }

    private func segmentLabel(_ segment: Segment, idx: Int) -> some View {
        let mid = (angle(idx) + angle(idx + 1)) / 2          // angle du centre du secteur
        let r = discD / 2 - 50                                // rayon de placement du label
        let rad = mid * .pi / 180
        let isDark = idx.isMultiple(of: 2)
        return Group {
            if segment.gift {
                Image(systemName: "gift.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(isDark ? Palette.gold : Palette.onAmber)
            } else {
                Text(segment.label)
                    .font(SolaFont.body(19, weight: .heavy))
                    .foregroundStyle(isDark ? Palette.inkOn : Palette.onAmber)
                    .shadow(color: .black.opacity(isDark ? 0.25 : 0), radius: 1, y: 1)
            }
        }
        // Une seule rotation (lecture radiale, du centre vers le bord) + position
        // trigonométrique sur le rayon. Le secteur du haut (mid = -90°) → texte droit.
        .rotationEffect(.degrees(mid + 90))
        .offset(x: CGFloat(cos(rad)) * r, y: CGFloat(sin(rad)) * r)
    }

    // Moyeu central : soleil doré bombé.
    private var hub: some View {
        ZStack {
            Circle().fill(goldRing).frame(width: 66, height: 66).shadowSoft()
            Circle().strokeBorder(Palette.amberDeep, lineWidth: 2).frame(width: 66, height: 66)
            Image(systemName: "sun.max.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Palette.onAmber)
        }
        .scaleEffect(hubPulse ? 1.12 : 1)
    }

    // Pointeur fixe en haut, pointant vers la roue.
    private var pointer: some View {
        Triangle()
            .fill(Palette.ink)
            .frame(width: 30, height: 26)
            .overlay(Triangle().fill(Palette.gold).frame(width: 20, height: 17).offset(y: -2))
            .shadowSoft()
            .offset(y: -(frameD / 2 - 6))
    }

    /// Angle de début du secteur `idx`, secteur 0 démarrant en haut.
    private func angle(_ idx: Int) -> Double { -90 + Double(idx) * seg }

    // MARK: - Tirage (truqué : s'arrête sur le secteur gagnant)

    private func spin() {
        guard !spinning, !didSpin else { return }
        spinning = true
        didSpin = true
        HapticsManager.shared.select()

        // Centre du secteur gagnant sous le pointeur (haut) :
        // rotation ≡ -(winIndex*seg + seg/2) (mod 360), + plusieurs tours pleins.
        let spins = 6.0
        let target = 360.0 * spins - (Double(winIndex) * seg + seg / 2)
        let duration = 4.2

        // Décélération type roulette (départ vif, longue fin).
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: duration)) {
            rotation = target
        }
        scheduleTicks(total: duration, spins: spins, finalRotation: target)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.15) {
            HapticsManager.shared.success()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { hubPulse = true }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.35)) {
                showReward = true
            }
        }
    }

    // Tics haptiques calés sur le passage des secteurs, de plus en plus espacés
    // à mesure que la roue ralentit (illusion d'un cliquet de roulette).
    private func scheduleTicks(total: Double, spins: Double, finalRotation: Double) {
        let ticks = 26
        for i in 0..<ticks {
            // progression non linéaire (easeOut) → tics resserrés au début.
            let p = Double(i) / Double(ticks)
            let eased = 1 - pow(1 - p, 3)
            let t = eased * total
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                if self.spinning { HapticsManager.shared.tap() }
            }
        }
    }
}

// MARK: - Formes

/// Secteur angulaire (part de camembert), angles en degrés.
private struct WedgeShape: Shape {
    let startAngle: Double
    let endAngle: Double
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        p.move(to: c)
        p.addArc(center: c, radius: r,
                 startAngle: .degrees(startAngle), endAngle: .degrees(endAngle),
                 clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// Triangle plein pointant vers le bas (pointeur de la roue).
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
