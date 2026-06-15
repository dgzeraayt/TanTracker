import SwiftUI

// MARK: - Refonte UI (langage visuel partagé)
// Briques communes aux 4 écrans refondus (Aujourd'hui, Programme, Journal, Profil) :
// surfaces chaudes teintées + motif soleil signature, en-têtes en CASSE NORMALE
// (fini les capitales espacées), chip de série, tab bar flottante à scanner central.

// Routeur d'onglets : pilote la sélection depuis la tab bar, le scanner central
// et les raccourcis (avatar → Profil).
@MainActor
final class TabRouter: ObservableObject {
    @Published var selection: Int = 0
    /// Mis à `true` pour demander le démarrage de la séance guidée dans le Programme.
    /// L'accueil le déclenche (raccourci) ; le Programme le consomme puis le remet à `false`.
    @Published var requestSessionStart: Bool = false
}

// MARK: - Carte héros teintée à motif soleil
// Surface chaude (tintGold) avec une grande icône soleil en filigrane dans le coin :
// la signature de marque qu'on retrouve d'un écran à l'autre.
struct SunHero<Content: View>: View {
    var tint: Color = Palette.tintGold
    var motif: String = ClayIMG.sun        // emblème 3D clay posé dans le coin
    var showMotif: Bool = true             // false quand le contenu porte déjà son propre clay
    var padding: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .topTrailing) {
                if showMotif {
                    ClayAssetImage(name: motif, size: 104, shadow: false)
                        .opacity(0.92)
                        .offset(x: 20, y: -16)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .modifier(HeroSurface(tint: tint, radius: Radius.lg))
    }
}

// Surface des héros : verre teinté (iOS 26) ou couleur pleine en repli.
struct HeroSurface: ViewModifier {
    var tint: Color
    var radius: CGFloat
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(Glass.regular.tint(tint), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            content
                .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(tint))
                .shadowSoft()
        }
    }
}

// MARK: - Anneau de progression « soleil »
// Grand anneau avec contenu central libre + une pastille soleil posée en haut.
struct SunRing<Center: View>: View {
    var progress: Double            // 0...1
    var size: CGFloat = 188
    var stroke: CGFloat = 13
    var track: Color = Palette.amberDeep.opacity(0.15)
    @ViewBuilder var center: () -> Center

    @State private var animated: Double = 0
    private var target: Double { min(1, max(0.001, progress)) }

    var body: some View {
        ZStack {
            // Rail visible : la portion « consommée » du temps sûr du jour.
            Circle().stroke(track, style: StrokeStyle(lineWidth: stroke))
            // Jauge : temps restant, dégradé angulaire ambre → or.
            Circle()
                .trim(from: 0, to: animated)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Palette.amberDeep, Palette.amber, Palette.gold, Palette.amber]),
                        center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)),
                    style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center()
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.85)) { animated = target }
        }
        .onChange(of: progress) { _, _ in
            withAnimation(.easeOut(duration: 0.5)) { animated = target }
        }
    }
}

// MARK: - Carte « temps de bronzage sans risque » (réutilisable + accessible)
// Niveau de risque pilotant l'anneau, le badge et les couleurs.
enum TanRisk {
    case safe, caution, danger

    // Anneau : jaune pâle → orange (safe), orange (attention), rouge (danger).
    var ringColors: [Color] {
        switch self {
        case .safe:    return [Palette.gold, Palette.amber, Palette.terra]
        case .caution: return [Palette.gold, Palette.warning, Palette.terra]
        case .danger:  return [Palette.terra, Palette.alert, Color(oklch: 0.55, 0.19, 18)]
        }
    }
    // Couleur unie de la jauge (style épuré, façon Gauge des premiers commits).
    var ringColor: Color {
        switch self {
        case .safe:    return Palette.amberDeep
        case .caution: return Palette.warning
        case .danger:  return Palette.alert
        }
    }
    var label: String {
        switch self {
        case .safe:    return "sans risque"
        case .caution: return "prudence"
        case .danger:  return "risque élevé"
        }
    }
    var icon: String { self == .danger ? "alertTri" : "shield" }
    // Symbole net teinté pour le badge (évite l'icône clay colorée).
    var symbol: String {
        switch self {
        case .safe:    return "checkmark.seal.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .danger:  return "exclamationmark.octagon.fill"
        }
    }
    var fg: Color {
        switch self {
        case .safe:    return Palette.success
        case .caution: return Color(oklch: 0.48, 0.13, 60)   // orange foncé lisible
        case .danger:  return Palette.alert
        }
    }
    var bg: Color {
        switch self {
        case .safe:    return Palette.success.opacity(0.14)
        case .caution: return Palette.warning.opacity(0.20)
        case .danger:  return Palette.alert.opacity(0.13)
        }
    }
    var voiceOver: String {
        switch self {
        case .safe:    return "sans risque"
        case .caution: return "prudence recommandée"
        case .danger:  return "risque élevé de coup de soleil"
        }
    }
}

struct SafeTanCard: View {
    let minutes: Int
    let progress: Double            // fraction de temps restant, 0...1
    var risk: TanRisk = .safe
    let caption: String
    var ringSize: CGFloat = 200
    var stroke: CGFloat = 13

    @State private var animatedProgress: Double = 0
    @State private var pulse = false
    @State private var badgeIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var target: Double { min(1, max(0.001, progress)) }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // Rail 3D : rainure creusée (relief lumière/ombre neumorphique).
                Circle()
                    .stroke(Palette.lineSoft, style: StrokeStyle(lineWidth: stroke))
                    .overlay(
                        Circle().stroke(
                            LinearGradient(colors: [.black.opacity(0.12), .clear, .white.opacity(0.55)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: stroke))
                    )
                    .shadow(color: .black.opacity(0.10), radius: 3, x: 2, y: 3)
                    .shadow(color: .white.opacity(0.80), radius: 3, x: -2, y: -3)

                // Jauge 3D : tube bombé (reflet en haut, ombre en bas) + ombre portée colorée.
                ZStack {
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(risk.ringColor, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.04), .black.opacity(0.24)],
                                           startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                }
                .rotationEffect(.degrees(-90))
                .shadow(color: risk.ringColor.opacity(0.40), radius: 6, x: 0, y: 4)
                .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 1)

                VStack(spacing: 7) {
                    ClayAssetImage(name: ClayIMG.sun, size: 32)
                        .scaleEffect(pulse ? 1.07 : 1.0)
                    Eyebrow(text: "Tu peux bronzer")
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(minutes)")
                            .font(SolaFont.display(62, weight: .heavy)).tracking(-2.5)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1).minimumScaleFactor(0.5)
                        Text("min")
                            .font(SolaFont.display(22, weight: .heavy)).tracking(-0.5)
                            .foregroundStyle(Palette.ink3)
                    }
                    badge
                        .padding(.top, 1)
                }
                .padding(.horizontal, 30)
            }
            .frame(width: ringSize, height: ringSize)

            Text(caption)
                .font(SolaFont.body(13)).foregroundStyle(Palette.ink3)
                .multilineTextAlignment(.center).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
        .shadowSoft()
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0 : 0.9)) { animatedProgress = target }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.15)) { badgeIn = true }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { pulse = true }
            }
        }
        .onChange(of: progress) { _, _ in
            withAnimation(.easeOut(duration: 0.5)) { animatedProgress = target }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tu peux bronzer \(minutes) minutes, \(risk.voiceOver).")
        .accessibilityValue(caption)
    }

    private var badge: some View {
        HStack(spacing: 6) {
            Image(systemName: risk.symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(risk.fg)
            Text(risk.label)
                .font(SolaFont.body(13, weight: .bold))
                .foregroundStyle(risk.fg)
                .tracking(0.2)
        }
        .padding(.horizontal, 13).padding(.vertical, 6)
        .background(
            Capsule().fill(risk.bg)
                .overlay(Capsule().strokeBorder(risk.fg.opacity(0.20), lineWidth: 1))
        )
        .scaleEffect(badgeIn ? 1 : 0.6)
        .opacity(badgeIn ? 1 : 0)
        .padding(.top, 2)
    }

    // Glassmorphism léger : flou (matériau) + teinte chaude semi-transparente.
    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Palette.tintGold.opacity(0.5))
        }
    }
}

// MARK: - En-tête de section (casse normale, remplace l'overline en capitales)
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(SolaFont.body(16, weight: .bold)).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            trailing()
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) { self.init(title) { EmptyView() } }
}

// MARK: - Chip de série (flamme + jours)
struct StreakChip: View {
    let days: Int
    var body: some View {
        HStack(spacing: 4) {
            Icon(name: "flame", size: 13).foregroundStyle(Palette.amberDeep)
            Text(days > 0 ? "\(days) j" : "Démarre")
                .font(SolaFont.body(12, weight: .bold)).foregroundStyle(Palette.amberDeep)
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(Palette.tintGold))
    }
}

// MARK: - Tuile « bento » (asset clay + grand nombre + libellé)
struct BentoTile: View {
    let clay: String                       // identifiant d'asset clay (ClayIMG.*)
    let label: String
    let value: String
    var body: some View {
        CardBox(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ClayAssetImage(name: clay, size: 24, shadow: false)
                    Text(label).font(SolaFont.body(12.5)).foregroundStyle(Palette.ink3)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Text(value).font(SolaFont.display(22, weight: .heavy)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.55)
            }
        }
    }
}

// MARK: - Tab bar flottante (4 onglets + scanner central)
struct SunTabBar: View {
    @EnvironmentObject var tab: TabRouter
    @Namespace private var pill

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            tabButton(0, "home", "Aujourd'hui")
            tabButton(1, "checkCircle", "Programme")
            centerButton
            tabButton(3, "book", "Journal")
            tabButton(4, "user", "Profil")
        }
        .padding(.horizontal, 8).padding(.vertical, 8)
        .modifier(TabBarGlass())
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    // Teinte de l'onglet actif.
    private var activeTint: Color { Palette.amberDeep }

    private func tabButton(_ index: Int, _ icon: String, _ title: String) -> some View {
        let active = tab.selection == index
        return Button {
            HapticsManager.shared.select()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                tab.selection = index
            }
        } label: {
            VStack(spacing: 4) {
                Icon(name: icon, size: 28, filled: active)
                    .foregroundStyle(active ? activeTint : Palette.ink3)
                    .scaleEffect(active ? 1.06 : 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                if active {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.tintAmber)
                        .matchedGeometryEffect(id: "activePill", in: pill)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var centerButton: some View {
        let active = tab.selection == 2
        return Button {
            HapticsManager.shared.select()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                tab.selection = 2
            }
        } label: {
            VStack(spacing: 4) {
                Icon(name: "camera", size: 26).foregroundStyle(Palette.onAmber)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [Palette.gold, Palette.amber, Palette.amberDeep],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 2))
                    .shadow(color: Palette.amberDeep.opacity(0.40), radius: 8, x: 0, y: 4)
                    .scaleEffect(active ? 1.06 : 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Espace réservé en bas des écrans pour ne pas passer sous la tab bar flottante.
struct TabBarSpacer: View {
    var body: some View { Color.clear.frame(height: 92) }
}

// MARK: - Liquid Glass (iOS 26+)
// Surface de carte : vrai Liquid Glass quand dispo, sinon repli sur le panneau
// verre existant (matériau + reflets) ou la couleur de remplissage demandée.
struct CardSurface: ViewModifier {
    var fill: Color?
    var radius: CGFloat
    var borderColor: Color?
    var shadow: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // Liquid Glass sur toutes les cards : le remplissage devient une teinte de verre.
            content
                .overlay(borderOverlay)
                .glassEffect(glass, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .modifier(ConditionalShadow(on: shadow))
        } else {
            content
                .background(GlassPanel(radius: radius,
                                       tint: fill ?? Palette.surface,
                                       tintOpacity: fill == nil ? 0.28 : 0.36))
                .overlay(borderOverlay)
                .modifier(ConditionalShadow(on: shadow))
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        if let fill { return Glass.regular.tint(fill) }
        return Glass.regular
    }

    @ViewBuilder private var borderOverlay: some View {
        if let borderColor {
            RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(borderColor, lineWidth: 1)
        }
    }
}

// Fond de la tab bar flottante : Liquid Glass interactif sur iOS 26, sinon surface + ombre.
struct TabBarGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(),
                                in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        } else {
            content
                .background(GlassPanel(radius: 30, tint: Palette.surface, tintOpacity: 0.38))
                .shadowRaised()
        }
    }
}
