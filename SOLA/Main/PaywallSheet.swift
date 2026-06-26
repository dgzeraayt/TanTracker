import SwiftUI

// Paywall natif (design maîtrisé dans le code). Structure « parcours » :
// titre fort, preuve sociale, timeline de progression (Aujourd'hui → Semaine 4),
// deux offres côte à côte puis CTA. Contenu scrollable pour rester lisible sur
// petits écrans et gros Dynamic Type. Branché RevenueCat via PurchaseManager.
struct PaywallSheet: View {
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// Paywall bloquant (accès à l'app) : pas de bouton de fermeture.
    var mandatory: Bool = false
    /// Action « Passer » : si fournie, elle fait avancer dans l'app (présentation
    /// plein écran). Sinon, en sheet, le bouton ferme simplement le paywall.
    /// Appelée aussi après un achat/restauration réussi.
    var onSkip: (() -> Void)? = nil
    /// Action spécifique au bouton de fermeture (croix) — exit-intent. Si fournie,
    /// elle est appelée à la place de `onSkip` quand l'utilisateur ferme sans acheter
    /// (ex. lancer la roulette d'offre). Sans effet si le paywall est `mandatory`.
    var onClose: (() -> Void)? = nil

    @State private var selectedID = PurchaseManager.annualID
    @State private var showError = false

    // Étapes du parcours (timeline). Icônes 3D « clay » de l'onboarding, chacune
    // avec son accent de marque pour rythmer la progression dans le temps.
    private struct Step { let img: String; let tint: Color; let title: String; let detail: String }
    private let steps: [Step] = [
        Step(img: ClayIMG.skinPalette, tint: Palette.gold,
             title: "Aujourd'hui — Analyse ta peau",
             detail: "On calcule ton phototype et ta dose de soleil sûre.\nTa première session démarre."),
        Step(img: ClayIMG.shield, tint: Palette.success,
             title: "Semaine 1 — Sans te brûler",
             detail: "Tu connais ta fenêtre idéale chaque jour.\nFini les coups de soleil."),
        Step(img: ClayIMG.sun, tint: Palette.amber,
             title: "Semaine 2 — Un hâle régulier",
             detail: "Ton teint dore vite et uniformément.\nLes bons réflexes s'installent."),
        Step(img: ClayIMG.statistics, tint: Palette.terra,
             title: "Semaine 4 — Ton bilan",
             detail: "Tu vois ta progression en photos.\nTu gardes un hâle durable.")
    ]

    private var selectedHasTrial: Bool { purchases.hasFreeTrial(for: selectedID) }
    private var ctaTitle: String {
        if selectedHasTrial { return "Commencer pour 0,00 €" }
        return "Continuer"
    }
    private var trialLabel: String? { purchases.freeTrialLabel(for: PurchaseManager.annualID) }

    var body: some View {
        GeometryReader { geo in
            let contentWidth = min(geo.size.width, Frame.maxContentWidth)
            ZStack(alignment: .top) {
                Palette.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Text("Reprends le contrôle\nde ton bronzage")
                        .font(SolaFont.display(30, weight: .heavy)).tracking(-0.6)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    statsRow
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)

                    Spacer(minLength: 16)

                    timeline

                    Spacer(minLength: 16)

                    VStack(spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            planCard(
                                id: PurchaseManager.monthlyID, title: "Mensuel",
                                price: purchases.displayPrice(for: PurchaseManager.monthlyID, fallback: "9,99 €"),
                                sub: "par mois", trial: nil)
                            planCard(
                                id: PurchaseManager.annualID, title: "Annuel",
                                price: purchases.localizedPricePerWeek(for: PurchaseManager.annualID) ?? "0,58 €",
                                sub: "par semaine", trial: trialLabel.map { "\($0) d'essai gratuit" })
                        }
                        ctaButton
                        Text(footnote)
                            .font(SolaFont.caption).foregroundStyle(Palette.ink3)
                            .frame(maxWidth: .infinity, alignment: .center)
                        footerLinks.padding(.top, 2)
                    }
                }
                .padding(.horizontal, Frame.padH)
                .padding(.top, geo.safeAreaInsets.top + 48)
                .padding(.bottom, geo.safeAreaInsets.bottom + 14)
                .frame(width: contentWidth, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .top)
                // Écran fixe quand tout tient ; devient défilable seulement si le
                // contenu déborde (petits écrans / gros Dynamic Type) pour ne rien rogner.
                .solaScrollableIfNeeded()

                topBar
                    .padding(.horizontal, Frame.padH)
                    .frame(width: contentWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.top, geo.safeAreaInsets.top + 6)
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .alert("Achat indisponible", isPresented: $showError) {
            Button("Réessayer") { Task { await purchases.loadOfferings() } }
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchases.lastError ?? "Impossible de contacter la boutique. Vérifie ta connexion puis réessaie.")
        }
        .task {
            if purchases.offering == nil { await purchases.loadOfferings() }
        }
    }

    private var footnote: String {
        if let t = trialLabel, selectedHasTrial {
            return "\(t) offerts · Annulable à tout moment"
        }
        return "Sans engagement · Annulable à tout moment"
    }

    // MARK: - Barre supérieure (Restaurer / fermer)
    private var topBar: some View {
        HStack {
            Button {
                Task {
                    let restored = await purchases.restorePurchases()
                    if restored {
                        if let onSkip { onSkip() } else if !mandatory { dismiss() }
                    } else { showError = true }
                }
            } label: {
                Text("Restaurer")
                    .font(SolaFont.body(15, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
            }
            .buttonStyle(.plain)

            Spacer()

            if !mandatory {
                Button {
                    if let onClose { onClose() }
                    else if let onSkip { onSkip() }
                    else { dismiss() }
                } label: {
                    Icon(name: "x", size: 16, stroke: 2.5)
                        .foregroundStyle(Palette.ink2)
                        .frame(width: 34, height: 34)
                        .background(GlassCircle(tint: Palette.surface, tintOpacity: 0.36))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Preuve sociale (note + utilisateurs, encadrés de lauriers)
    private var statsRow: some View {
        HStack(spacing: 26) {
            statBadge(value: "4,8 ★", label: "Note App")
            statBadge(value: "10k+", label: "Utilisateurs")
        }
    }

    private func statBadge(value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "laurel.leading")
                .font(.system(size: 26)).foregroundStyle(Palette.gold.opacity(0.7))
            VStack(spacing: 1) {
                Text(value).font(SolaFont.body(17, weight: .heavy)).foregroundStyle(Palette.ink)
                Text(label).font(SolaFont.caption).foregroundStyle(Palette.ink3)
            }
            Image(systemName: "laurel.trailing")
                .font(.system(size: 26)).foregroundStyle(Palette.gold.opacity(0.7))
        }
    }

    // MARK: - Timeline de progression
    // Ligne verticale continue reliant des nœuds « clay » colorés ; titre + détail
    // (2 lignes) à droite. Hauteur de ligne flexible → s'adapte au Dynamic Type.
    private var timeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .center, spacing: 14) {
                    node(step, idx: idx)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title)
                            .font(SolaFont.body(17, weight: .bold)).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(step.detail)
                            .font(SolaFont.body(14)).foregroundStyle(Palette.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 11)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func node(_ step: Step, idx: Int) -> some View {
        let badge: CGFloat = 50
        return ZStack {
            VStack(spacing: 0) {
                Rectangle().fill(idx == 0 ? Color.clear : Palette.line)
                    .frame(width: 2).frame(maxHeight: .infinity)
                Rectangle().fill(idx == steps.count - 1 ? Color.clear : Palette.line)
                    .frame(width: 2).frame(maxHeight: .infinity)
            }
            Circle().fill(Palette.bg).frame(width: badge, height: badge)
            GlassCircle(tint: step.tint, tintOpacity: 0.5).frame(width: badge, height: badge)
            Circle().strokeBorder(step.tint.opacity(0.85), lineWidth: 2).frame(width: badge, height: badge)
            ClayAssetImage(name: step.img, size: 30, shadow: false)
        }
        .frame(width: badge)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Carte d'offre (sélectionnable, format vertical côte à côte)
    private func planCard(id: String, title: String, price: String, sub: String, trial: String?) -> some View {
        let selected = selectedID == id
        return Button {
            HapticsManager.shared.select()
            selectedID = id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title).font(SolaFont.body(15, weight: .bold)).foregroundStyle(Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    ZStack {
                        Circle().strokeBorder(selected ? Palette.amberDeep : Palette.line, lineWidth: 2)
                            .frame(width: 22, height: 22)
                        if selected {
                            Circle().fill(Palette.amberDeep).frame(width: 22, height: 22)
                            Icon(name: "check", size: 11, stroke: 3).foregroundStyle(.white)
                        }
                    }
                }
                Text(price).font(SolaFont.display(24, weight: .heavy)).tracking(-0.5)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(sub).font(SolaFont.body(12)).foregroundStyle(Palette.ink3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GlassPanel(radius: Radius.lg,
                                   tint: selected ? Palette.accentSoft : Palette.surface,
                                   tintOpacity: selected ? 0.5 : 0.30))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(selected ? Palette.amberDeep : Palette.line, lineWidth: selected ? 2 : 1)
            )
            .overlay(alignment: .top) {
                if let trial {
                    Text(trial.uppercased())
                        .font(SolaFont.dataSmall).tracking(0.3)
                        .foregroundStyle(Palette.onAmber)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Palette.gold))
                        .shadowSoft()
                        .offset(y: -12)
                }
            }
        }
        .buttonStyle(.plain)
        .pressAnimation()
        .padding(.top, trial != nil ? 8 : 0)
    }

    // MARK: - CTA
    private var ctaButton: some View {
        Button {
            Task {
                if purchases.offering == nil {
                    await purchases.loadOfferings()
                    if purchases.offering == nil { showError = true; return }
                }
                let ok = await purchases.purchase(selectedID)
                if ok {
                    if let onSkip { onSkip() }
                    else if !mandatory { dismiss() }
                } else if purchases.lastError != nil {
                    showError = true
                }
            }
        } label: {
            ZStack {
                if purchases.purchasing {
                    ProgressView().tint(Palette.onAmber)
                } else {
                    Text(ctaTitle).font(SolaFont.body(17, weight: .bold)).foregroundStyle(Palette.onAmber)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(Capsule().fill(Palette.amber))
            .shadowSoft()
        }
        .buttonStyle(.plain)
        .pressAnimation()
        .disabled(purchases.purchasing)
    }

    // MARK: - Liens légaux
    private var footerLinks: some View {
        HStack(spacing: 22) {
            Button("Confidentialité") { openURL(URL(string: "https://goldnapp.com/privacy")!) }
            Text("·").foregroundStyle(Palette.ink3)
            Button("EULA") { openURL(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) }
        }
        .font(SolaFont.body(11.5))
        .foregroundStyle(Palette.ink3)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .lineLimit(1).minimumScaleFactor(0.85)
    }
}
