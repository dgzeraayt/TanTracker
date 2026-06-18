import SwiftUI

// Paywall natif (design maîtrisé dans le code), contenu scrollable (hero fixe en
// tête puis offres) pour rester lisible sur petits écrans et gros Dynamic Type.
// Branché sur les offres RevenueCat via PurchaseManager (prix localisés, essai, achat).
struct PaywallSheet: View {
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// Paywall bloquant (accès à l'app) : pas de bouton de fermeture.
    var mandatory: Bool = false
    /// Action « Passer » : si fournie, elle fait avancer dans l'app (présentation
    /// plein écran). Sinon, en sheet, le bouton ferme simplement le paywall.
    var onSkip: (() -> Void)? = nil

    @State private var selectedID = PurchaseManager.annualID
    @State private var showError = false

    // Icônes 3D « clay » de l'onboarding (pas de glyphes 2D).
    private let features: [(String, String)] = [
        (ClayIMG.skinPalette, "Analyses de peau illimitées"),
        (ClayIMG.sun, "Indice UV en direct, partout"),
        (ClayIMG.timer, "Temps d'expo idéal, sans brûler"),
        (ClayIMG.cameraScan, "Suivi photo de ta progression")
    ]

    private var selectedHasTrial: Bool { purchases.hasFreeTrial(for: selectedID) }
    private var ctaTitle: String {
        if selectedHasTrial, let t = purchases.freeTrialLabel(for: selectedID) {
            return "Commencer l'essai · \(t)"
        }
        return "Continuer"
    }

    var body: some View {
        GeometryReader { geo in
            // Taille de l'image quand elle remplit toute la largeur (ratio source 941×1672).
            let heroFillH = geo.size.width * (1672.0 / 941.0)
            // Hauteur fixe du hero en mode scrollable (≈40 % de l'écran, plancher 260) :
            // un maxHeight: .infinity serait infini dans un ScrollView vertical.
            let heroH = max(260, geo.size.height * 0.40)
            // Recadrage FOCAL : on descend la fenêtre sur le visage (front → menton)
            // au lieu d'ancrer au bord haut, qui coupait la bouche et le menton.
            let heroFocalShift: CGFloat = 80
            ZStack(alignment: .top) {
                Palette.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                  VStack(spacing: 0) {
                    // Hero plein cadre, NET, bord à bord, recadré sur le VISAGE :
                    // l'image est dessinée à sa taille de remplissage puis décalée vers
                    // le haut (heroFocalShift) pour révéler tout le visage (front → menton)
                    // au lieu de couper le bas. Hauteur FLEXIBLE → pas de « trou ».
                    Image(IMG.welcomeSunbathe)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: heroFillH)
                        .offset(y: -heroFocalShift)
                        .frame(height: heroH, alignment: .top)
                        .frame(width: geo.size.width)
                        .clipped()
                        .overlay(alignment: .bottom) {
                            LinearGradient(colors: [.clear, Palette.bg], startPoint: .top, endPoint: .bottom)
                                .frame(height: 46)
                        }
                        // Pastille note posée sur la photo (bas-gauche, hors visage).
                        .overlay(alignment: .bottomLeading) {
                            ratingPill
                                .padding(.leading, Frame.padH)
                                .padding(.bottom, 14)
                        }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Bronze plus vite,\nsans jamais te brûler")
                            .font(SolaFont.display(21, weight: .heavy)).tracking(-0.4)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        featureTimeline
                            .padding(.top, 12)
                            .padding(.bottom, 14)

                        planCard(
                            id: PurchaseManager.annualID, title: "Annuel",
                            price: purchases.displayPrice(for: PurchaseManager.annualID, fallback: "24,99 €") + " /an",
                            tag: purchases.freeTrialLabel(for: PurchaseManager.annualID).map { "\($0) gratuits" },
                            badge: purchases.annualSavingsPercent.map { "−\($0) %" } ?? "Populaire")

                        planCard(
                            id: PurchaseManager.monthlyID, title: "Mensuel",
                            price: purchases.displayPrice(for: PurchaseManager.monthlyID, fallback: "8,99 €") + " /mois",
                            tag: "Sans engagement", badge: nil)
                            .padding(.top, 8)

                        ctaButton.padding(.top, 9)

                        Text(selectedHasTrial
                             ? "Aucun paiement maintenant. Annulable à tout moment."
                             : "Sans engagement. Annulable à tout moment.")
                            .font(SolaFont.caption).foregroundStyle(Palette.ink3)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 6)

                        footerLinks.padding(.top, 6)
                    }
                    .padding(.horizontal, Frame.padH)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                    .fixedSize(horizontal: false, vertical: true)
                  }
                }

                // Bouton « Passer » : présent dès qu'un skip est possible (sheet ou
                // onSkip fourni). Appelle onSkip si fourni (plein écran → avance dans
                // l'app), sinon ferme la sheet.
                if !mandatory || onSkip != nil {
                    Button {
                        if let onSkip { onSkip() } else { dismiss() }
                    } label: {
                        Text("Passer")
                            .font(SolaFont.body(14, weight: .semibold)).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 15).padding(.vertical, 8)
                            .background(Capsule().fill(.ultraThinMaterial))
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, Frame.padH)
                    .padding(.top, geo.safeAreaInsets.top + 6)
                }

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
            // Au cas où la première tentative de chargement (au lancement) ait échoué.
            if purchases.offering == nil { await purchases.loadOfferings() }
        }
    }


    // MARK: - Pastille note (preuve sociale, posée sur la photo)
    private var ratingPill: some View {
        HStack(spacing: 7) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Icon(name: "star", size: 12)
                }
            }
            Text("4,8").font(SolaFont.body(15, weight: .heavy)).foregroundStyle(Palette.ink)
            Text("· 12 400 avis").font(SolaFont.body(14)).foregroundStyle(Palette.ink3)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(GlassPanel(radius: Radius.pill, tint: Palette.surface, tintOpacity: 0.36))
        .shadowSoft()
    }

    // MARK: - Timeline des avantages
    // Ligne verticale continue qui relie les icônes « clay » (les nœuds),
    // libellé à droite. Premier nœud : pas de trait au-dessus ; dernier : pas en dessous.
    private var featureTimeline: some View {
        let rowH: CGFloat = 44
        let badge: CGFloat = 44
        let lastIndex = features.count - 1
        return VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { idx, f in
                HStack(spacing: 14) {
                    ZStack {
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(idx == 0 ? Color.clear : Palette.amberDeep.opacity(0.25))
                                .frame(width: 2).frame(maxHeight: .infinity)
                            Rectangle()
                                .fill(idx == lastIndex ? Color.clear : Palette.amberDeep.opacity(0.25))
                                .frame(width: 2).frame(maxHeight: .infinity)
                        }
                        GlassCircle(tint: Palette.accentSoft, tintOpacity: 0.48)
                            .frame(width: badge, height: badge)
                        ClayAssetImage(name: f.0, size: 30, shadow: false)
                    }
                    .frame(width: badge, height: rowH)

                    Text(f.1)
                        .font(SolaFont.body(16, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 0)
                }
                .frame(height: rowH)
            }
        }
    }

    // MARK: - Carte d'offre (sélectionnable)
    private func planCard(id: String, title: String, price: String, tag: String?, badge: String?) -> some View {
        let selected = selectedID == id
        return Button {
            HapticsManager.shared.select()
            selectedID = id
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(SolaFont.body(17, weight: .bold)).foregroundStyle(Palette.ink)
                            .lineLimit(1).fixedSize()
                        if let badge {
                            Text(badge.uppercased())
                                .font(SolaFont.dataSmall).tracking(0.4)
                                .foregroundStyle(Palette.onAmber)
                                .lineLimit(1).fixedSize()
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Palette.gold))
                        }
                    }
                    if let tag {
                        Text(tag).font(SolaFont.body(13)).foregroundStyle(Palette.ink3)
                    }
                }
                Spacer(minLength: 0)
                Text(price).font(SolaFont.body(15, weight: .bold)).foregroundStyle(Palette.ink)
                ZStack {
                    Circle().strokeBorder(selected ? Palette.amberDeep : Palette.line, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if selected {
                        Circle().fill(Palette.amberDeep).frame(width: 24, height: 24)
                        Icon(name: "check", size: 12, stroke: 3).foregroundStyle(.white)
                    }
                }
            }
            .padding(14)
            .background(GlassPanel(radius: Radius.lg,
                                   tint: selected ? Palette.accentSoft : Palette.surface,
                                   tintOpacity: selected ? 0.48 : 0.30))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(selected ? Palette.amberDeep : Palette.line, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .pressAnimation()
    }

    // MARK: - CTA
    private var ctaButton: some View {
        Button {
            Task {
                // Repli : si le catalogue n'est pas (encore) chargé, on retente avant l'achat.
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
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(Capsule().fill(Palette.amber))
            .shadowSoft()
        }
        .buttonStyle(.plain)
        .pressAnimation()
        .disabled(purchases.purchasing)
    }

    // MARK: - Liens légaux
    private var footerLinks: some View {
        HStack {
            Button("Confidentialité") { openURL(URL(string: "https://goldnapp.com/privacy")!) }
            Spacer()
            Button("EULA") { openURL(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) }
            Spacer()
            Button("Restaurer") {
                Task {
                    await purchases.restore()
                    if purchases.isPro {
                        if let onSkip { onSkip() }
                        else if !mandatory { dismiss() }
                    }
                }
            }
        }
        .font(SolaFont.body(11.5))
        .foregroundStyle(Palette.ink3)
        .buttonStyle(.plain)
        .lineLimit(1).minimumScaleFactor(0.85)
    }
}
