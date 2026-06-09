import SwiftUI

// MARK: - Animation Modifiers
extension View {
    /// Scale + fade on press
    func pressAnimation() -> some View {
        self.modifier(PressAnimationModifier())
    }

    /// Bounce animation
    func bounceIn() -> some View {
        self.modifier(BounceInModifier())
    }

    /// Pulse animation (infinite)
    func pulse() -> some View {
        self.modifier(PulseModifier())
    }

    /// Celebration animation (scale + rotate)
    func celebration(_ trigger: Bool) -> some View {
        self.modifier(CelebrationModifier(trigger: trigger))
    }

    /// Slide in from bottom
    func slideInFromBottom(_ show: Bool) -> some View {
        self.modifier(SlideInFromBottomModifier(show: show))
    }

    /// Fade + scale
    func fadeScaleIn() -> some View {
        self.modifier(FadeScaleInModifier())
    }

    /// Shake animation (erreur)
    func shake(_ trigger: Bool) -> some View {
        self.modifier(ShakeModifier(trigger: trigger))
    }

    /// Progress fill animation
    func progressFill(_ progress: Double) -> some View {
        self.modifier(ProgressFillModifier(progress: progress))
    }
}

// MARK: - Transitions
extension AnyTransition {
    /// Glisse depuis le bas avec fondu (le paramètre garde la compat des appels existants)
    static func slideInFromBottom(_ show: Bool = true) -> AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }
}

// MARK: - Press Animation
struct PressAnimationModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
            .onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            })
    }
}

// MARK: - Bounce In
struct BounceInModifier: ViewModifier {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
    }
}

// MARK: - Pulse (Infinite)
struct PulseModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .opacity(isAnimating ? 0.8 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Celebration (Scale + Rotate)
struct CelebrationModifier: ViewModifier {
    let trigger: Bool
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    HapticsManager.shared.celebration()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) {
                        scale = 1.2
                        rotation = 6
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)) {
                            scale = 1.0
                            rotation = 0
                        }
                    }
                }
            }
    }
}

// MARK: - Slide In From Bottom
struct SlideInFromBottomModifier: ViewModifier {
    let show: Bool
    @State private var offset: CGFloat = 100

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .opacity(show ? 1 : 0)
            .onChange(of: show) { _, newValue in
                withAnimation(.easeOut(duration: 0.3)) {
                    offset = newValue ? 0 : 100
                }
            }
    }
}

// MARK: - Fade Scale In
struct FadeScaleInModifier: ViewModifier {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
    }
}

// MARK: - Shake
struct ShakeModifier: ViewModifier {
    let trigger: Bool
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    HapticsManager.shared.error()
                    for i in 0..<4 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                            withAnimation(.linear(duration: 0.05)) {
                                offset = i % 2 == 0 ? -5 : 5
                            }
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        offset = 0
                    }
                }
            }
    }
}

// MARK: - Progress Fill
struct ProgressFillModifier: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        content
            .modifier(FillProgressModifier(progress: progress))
    }

    struct FillProgressModifier: ViewModifier {
        let progress: Double
        @State private var displayProgress: Double = 0

        func body(content: Content) -> some View {
            content
                .onAppear {
                    displayProgress = progress
                }
                .onChange(of: progress) { _, newValue in
                    withAnimation(.easeOut(duration: 0.5)) {
                        displayProgress = newValue
                    }
                }
        }
    }
}

// MARK: - Confetti Animation (Celebration)
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    let count: Int = 30

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        var newParticles: [ConfettiParticle] = []
        for i in 0..<count {
            let angle = Double(i) * (360.0 / Double(count))
            let velocity = Double.random(in: 200...400)
            let colors: [Color] = [Palette.gold, Palette.amber, Palette.terra, Palette.bronze]
            let particle = ConfettiParticle(
                id: i,
                color: colors.randomElement()!,
                size: Double.random(in: 4...8),
                angle: angle,
                velocity: velocity
            )
            newParticles.append(particle)
        }
        particles = newParticles

        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.02) {
                withAnimation(.easeOut(duration: 1.5)) {
                    if i < particles.count {
                        particles[i].x = sin(particles[i].angle * .pi / 180) * particles[i].velocity
                        particles[i].y = -cos(particles[i].angle * .pi / 180) * particles[i].velocity
                        particles[i].opacity = 0
                    }
                }
            }
        }
    }

    struct ConfettiParticle: Identifiable {
        let id: Int
        let color: Color
        let size: Double
        let angle: Double
        let velocity: Double
        var x: CGFloat = 0
        var y: CGFloat = 0
        var opacity: Double = 1
    }
}
