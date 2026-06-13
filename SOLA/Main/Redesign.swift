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
    var label: String {
        switch self {
        case .safe:    return "sans risque"
        case .caution: return "prudence"
        case .danger:  return "risque élevé"
        }
    }
    var icon: String { self == .danger ? "alertTri" : "shield" }
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
                // Rail : la portion de temps déjà consommée.
                Circle().stroke(Palette.amberDeep.opacity(0.15), style: StrokeStyle(lineWidth: stroke))
                // Jauge : temps restant, dégradé angulaire animé.
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: risk.ringColors),
                                        center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)),
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 5) {
                    ClayAssetImage(name: ClayIMG.sun, size: 34)
                        .scaleEffect(pulse ? 1.07 : 1.0)
                    Text("tu peux bronzer")
                        .font(SolaFont.body(13)).foregroundStyle(Palette.ink3)
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text("\(minutes)")
                            .font(SolaFont.display(64, weight: .heavy)).tracking(-2)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1).minimumScaleFactor(0.5)
                        Text("min")
                            .font(SolaFont.body(18, weight: .semibold)).foregroundStyle(Palette.ink3)
                    }
                    badge
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
        HStack(spacing: 5) {
            Icon(name: risk.icon, size: 12).foregroundStyle(risk.fg)
                .scaleEffect(badgeIn ? 1 : 0.4)
                .opacity(badgeIn ? 1 : 0)
            Text(risk.label)
                .font(SolaFont.body(12.5, weight: .bold)).foregroundStyle(risk.fg)
        }
        .padding(.horizontal, 11).padding(.vertical, 4)
        .background(Capsule().fill(risk.bg))
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

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            tabButton(0, "home", "Aujourd'hui")
            tabButton(1, "checkCircle", "Programme")
            centerButton
            tabButton(3, "book", "Journal")
            tabButton(4, "user", "Profil")
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .modifier(TabBarGlass())
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    private func tabButton(_ index: Int, _ icon: String, _ title: String) -> some View {
        let active = tab.selection == index
        return Button {
            HapticsManager.shared.select()
            tab.selection = index
        } label: {
            VStack(spacing: 4) {
                Icon(name: icon, size: 22, filled: active).foregroundStyle(active ? Palette.amberDeep : Palette.ink3)
                Text(title).font(SolaFont.body(9.5, weight: active ? .bold : .medium))
                    .foregroundStyle(active ? Palette.amberDeep : Palette.ink3)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var centerButton: some View {
        Button {
            HapticsManager.shared.select()
            tab.selection = 2
        } label: {
            VStack(spacing: 4) {
                Icon(name: "camera", size: 23).foregroundStyle(Palette.onAmber)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Palette.amber))
                    .shadowSoft()
                Text("Scanner").font(SolaFont.body(9.5, weight: .medium))
                    .foregroundStyle(tab.selection == 2 ? Palette.amberDeep : Palette.ink3)
            }
            .frame(maxWidth: .infinity)
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
            content.glassEffect(glass, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else if let fill {
            content
                .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
                .overlay(borderOverlay)
                .modifier(ConditionalShadow(on: shadow))
        } else {
            content
                .background(GlassPanel(radius: radius))
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
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Palette.lineSoft, lineWidth: 1))
                )
                .shadowRaised()
        }
    }
}
