import SwiftUI

// MARK: - Scaffold d'écran (fond plein cadre + vraie status bar système)
struct ScreenScaffold<Content: View>: View {
    var background: AnyView
    /// Écran à fond sombre : status bar en contenu clair.
    var lightStatusBar: Bool = false
    @ViewBuilder var content: () -> Content

    init(background: some View, lightStatusBar: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.background = AnyView(background)
        self.lightStatusBar = lightStatusBar
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .top) {
            background.ignoresSafeArea()
            // taches colorées floutées (écrans clairs uniquement) : matière pour le verre dépoli.
            // Sur fond sombre, on les omet pour préserver le contraste du texte blanc.
            if !lightStatusBar {
                WarmBlobs().ignoresSafeArea().allowsHitTesting(false)
            }
            // Le contenu respecte la safe area (le fond, lui, déborde dessous).
            // C'est ce qui garantit l'espacement sous la status bar.
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // On masque la barre de navigation système partout : chaque écran a son propre
        // en-tête (ScreenTitle / bouton retour custom). Sans ça, un écran poussé réserve
        // l'espace d'une barre vide tandis qu'une racine d'onglet ne le fait pas — d'où
        // l'espacement incohérent constaté entre Plan/« Ton temps de soleil » et UV/Journal.
        .toolbar(.hidden, for: .navigationBar)
        // Les écrans à fond sombre forcé (photo plein cadre) gardent une status
        // bar claire. Les écrans normaux suivent l'apparence globale (thème),
        // ce qui laisse le dark mode s'appliquer.
        .modifier(ForcedDarkStatusBar(on: lightStatusBar))
    }
}

private struct ForcedDarkStatusBar: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.preferredColorScheme(.dark) }
        else { content }
    }
}

// MARK: - Backdrop coloré flouté (réfraction du verre)
struct WarmBlobs: View {
    var dark: Bool = false
    var body: some View {
        let op: Double = dark ? 0.30 : 0.45
        ZStack {
            Circle().fill(Palette.amber.opacity(op)).frame(width: 360, height: 360)
                .blur(radius: 90).offset(x: -130, y: -200)
            Circle().fill(Palette.terra.opacity(op * 0.8)).frame(width: 320, height: 320)
                .blur(radius: 100).offset(x: 150, y: 70)
            Circle().fill(Palette.gold.opacity(op)).frame(width: 300, height: 300)
                .blur(radius: 90).offset(x: 120, y: 460)
        }
    }
}

// MARK: - Verre dépoli (glassmorphism)
struct GlassPanel: View {
    var radius: CGFloat = Radius.lg
    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.04)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.12)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                                  lineWidth: 1)
            )
    }
}

// Variante circulaire (boutons icônes)
struct GlassCircle: View {
    var body: some View {
        Circle().fill(.ultraThinMaterial)
            .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.04)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
    }
}

// MARK: - Styles de texte
extension View {
    func eyebrow() -> some View {
        self.font(SolaFont.mono(11, weight: .medium))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(Palette.ink3)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Palette.ink3
    var body: some View {
        Text(text)
            .font(SolaFont.mono(11, weight: .medium))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

struct DisplayText: View {
    let text: String
    var size: CGFloat = 46
    var color: Color = Palette.ink
    var body: some View {
        Text(text.uppercased())
            .font(SolaFont.display(size, weight: .heavy))
            .tracking(size * -0.035)
            .lineSpacing(0)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct LeadText: View {
    let text: String
    var color: Color = Palette.ink2
    var size: CGFloat = 16
    var body: some View {
        Text(text)
            .font(SolaFont.body(size))
            .lineSpacing(size * 0.5)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Carte (verre dépoli par défaut ; fill explicite = surface solide)
struct CardBox<Content: View>: View {
    var fill: Color? = nil
    var radius: CGFloat = Radius.lg
    var padding: CGFloat = 22
    var shadow: Bool = true
    var borderColor: Color? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(
                Group {
                    if let bc = borderColor, fill != nil {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(bc, lineWidth: 1)
                    }
                }
            )
            .modifier(ConditionalShadow(on: shadow))
    }

    @ViewBuilder private var background: some View {
        if let fill {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
        } else {
            GlassPanel(radius: radius)
        }
    }
}

struct ConditionalShadow: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.solaShadowSm() } else { content }
    }
}

// MARK: - Boutons
enum SolaButtonKind { case primary, amber, light, ghost }

struct SolaButton: View {
    let title: String
    var kind: SolaButtonKind = .primary
    var icon: String? = "arrowR"
    var height: CGFloat = 58
    var fontSize: CGFloat = 16
    var ghostBorder: Color = Palette.line
    var ghostText: Color = Palette.ink
    var isCTA: Bool = false  // Célébration pour CTA majeur
    var action: () -> Void = {}

    @State private var showCelebration = false

    var body: some View {
        Button(action: {
            HapticsManager.shared.select()
            if isCTA { showCelebration = true }
            action()
        }) {
            HStack(spacing: 9) {
                Text(title)
                if let icon { Icon(name: icon, size: 19) }
            }
            .font(SolaFont.body(fontSize, weight: .bold))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundStyle(fg)
            .background(bg)
            .overlay(border)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .pressAnimation()
        .overlay(
            ZStack {
                if showCelebration {
                    ConfettiView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                showCelebration = false
                            }
                        }
                }
            }
        )
    }

    private var fg: Color {
        switch kind {
        case .primary: return Palette.inkOn
        case .amber: return Palette.onAmber
        case .light: return Palette.ink
        case .ghost: return ghostText
        }
    }
    @ViewBuilder private var bg: some View {
        switch kind {
        case .primary: Palette.ink
        case .amber: Palette.amberDeep
        case .light: GlassPanel(radius: 40)
        case .ghost: Color.clear
        }
    }
    @ViewBuilder private var border: some View {
        if kind == .ghost {
            Capsule().stroke(ghostBorder, lineWidth: 1.5)
        }
    }
}

// Étiquette mono "pill" (boutons secondaires)
struct PillLabelButton: View {
    let title: String
    var icon: String? = nil
    var kind: SolaButtonKind = .primary
    var height: CGFloat = 52
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let icon { Icon(name: icon, size: 18) }
                Text(title.uppercased())
            }
            .font(SolaFont.mono(13, weight: .semibold))
            .tracking(1)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundStyle(kind == .primary ? Palette.inkOn : Palette.ink)
            .background(kind == .primary ? Palette.ink : Palette.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bouton icône circulaire
struct IconButton: View {
    let icon: String
    var ink: Bool = false
    var bare: Bool = false
    var size: CGFloat = 46
    var iconSize: CGFloat = 21
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            Icon(name: icon, size: iconSize)
                .foregroundStyle(ink ? Palette.inkOn : Palette.ink)
                .frame(width: size, height: size)
                .background(iconBackground)
                .modifier(ConditionalShadow(on: !ink && !bare))
        }
        .buttonStyle(.plain)
    }
    @ViewBuilder private var iconBackground: some View {
        if bare { Color.clear }
        else if ink { Circle().fill(Palette.ink) }
        else { GlassCircle() }
    }
}

// MARK: - Badge
struct Badge: View {
    let text: String
    var icon: String? = nil
    enum Style { case normal, amber, alert }
    var style: Style = .normal

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Icon(name: icon, size: 13) }
            Text(text.uppercased())
        }
        .font(SolaFont.mono(11, weight: .medium))
        .tracking(0.6)
        .foregroundStyle(fg)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(bg))
    }
    private var fg: Color {
        switch style {
        case .normal: return Palette.bronze
        case .amber: return Palette.onAmber
        case .alert: return Palette.alert
        }
    }
    private var bg: Color {
        switch style {
        case .normal: return Palette.bgWarm
        case .amber: return Palette.amber
        case .alert: return Color(oklch: 0.92, 0.06, 32)
        }
    }
}

// MARK: - Badge UV compact (LE composant unique pour « UV x,x » en haut d'écran)
// Tous les écrans qui affichent l'indice UV compact passent par lui : même style,
// même icône, même format de nombre. La valeur vient toujours du ForecastStore
// partagé (source unique), jamais d'un fetch propre à l'écran.
struct UvBadge: View {
    let uv: Double
    var body: some View {
        Badge(text: "UV \(uv.formatted(.number.precision(.fractionLength(0...1))))", icon: "sparkle")
    }
}

// MARK: - Barre de progression
struct Track: View {
    var value: Double // 0...1
    var height: CGFloat = 9
    var fill: Color = Palette.amberDeep
    @State private var displayValue: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.lineSoft)
                ZStack(alignment: .trailing) {
                    Capsule().fill(fill).frame(width: max(0, geo.size.width * displayValue))
                    // Shimmer effect at the edge
                    if displayValue > 0 && displayValue < 1 {
                        Capsule().fill(
                            LinearGradient(colors: [fill.opacity(0), fill, fill.opacity(0)],
                                         startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: 30)
                        .offset(x: geo.size.width * displayValue - 15)
                    }
                }
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                displayValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                displayValue = newValue
            }
        }
    }
}

// Segments (onboarding progress)
struct Segments: View {
    let total: Int
    let filled: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule().fill(i < filled ? Palette.ink : Palette.line)
                    .frame(height: 5)
            }
        }
    }
}
