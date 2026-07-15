import SwiftUI
import RevenueCat

// Offre unique présentée après la roulette de fin d'onboarding : abo annuel à
// prix cassé (19,99 €/an via le produit `promoAnnualID`), prix plein barré,
// essai gratuit mis en avant. Fermeture (croix) ⇒ on laisse passer (onClose).
struct PromoOfferSheet: View {
    @EnvironmentObject var purchases: PurchaseManager
    /// Fermeture sans achat (croix) → poursuivre l'app.
    var onClose: () -> Void
    /// Achat (ou restauration) réussi → débloquer et poursuivre.
    var onPurchased: () -> Void

    @State private var showError = false

    private var promoPrice: String { purchases.promoPrice(fallback: "19,99 €") }
    private var fullPrice: String { purchases.annualFullPrice(fallback: "29,99 €") }
    private var perMonth: String? { purchases.promoPricePerMonth() }

    /// Essai gratuit du produit promo (si l'offre d'intro est éligible).
    private var trial: StoreProductDiscount? {
        purchases.promoPackage?.storeProduct.introductoryDiscount
    }
    private var hasTrial: Bool { trial?.paymentMode == .freeTrial }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Palette.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 8)

                    Text("Ton offre unique")
                        .font(SolaFont.display(30, weight: .heavy)).tracking(-0.6)
                        .foregroundStyle(Palette.ink)

                    discountBadge
                        .padding(.top, 28)

                    priceRow
                        .padding(.top, 28)

                    Text("Une fois cette offre fermée, elle disparaît.\nLe meilleur prix sur l'abonnement annuel.")
                        .font(SolaFont.body(14)).foregroundStyle(Palette.ink3)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 18)

                    Spacer(minLength: 16)

                    planCard
                    ctaButton.padding(.top, 10)
                    Text(hasTrial ? "Essai gratuit puis \(promoPrice)/an · Annulable à tout moment"
                                  : "Sans engagement · Annulable à tout moment")
                        .font(SolaFont.caption).foregroundStyle(Palette.ink3)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, Frame.padH)
                .padding(.top, geo.safeAreaInsets.top + 48)
                .padding(.bottom, geo.safeAreaInsets.bottom + 14)
                .frame(maxWidth: Frame.maxContentWidth)
                .frame(maxWidth: .infinity)
                .solaScrollableIfNeeded()

                closeButton
                    .padding(.horizontal, Frame.padH)
                    .padding(.top, geo.safeAreaInsets.top + 6)
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .alert("Achat indisponible", isPresented: $showError) {
            Button("Réessayer") { Task { await purchases.loadOfferings() } }
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchases.lastError ?? String(localized: "Impossible de contacter la boutique. Vérifie ta connexion puis réessaie."))
        }
        .task { if purchases.promoPackage == nil { await purchases.loadOfferings() } }
    }

    // MARK: - Sous-vues

    private var closeButton: some View {
        HStack {
            Button { onClose() } label: {
                Icon(name: "x", size: 16, stroke: 2.5)
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 34, height: 34)
                    .background(GlassCircle(tint: Palette.surface, tintOpacity: 0.36))
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private var discountBadge: some View {
        VStack(spacing: 2) {
            Text("-70 %")
                .font(SolaFont.display(40, weight: .heavy)).tracking(-1)
                .foregroundStyle(Palette.onAmber)
            Text("SUR L'ANNÉE")
                .font(SolaFont.dataSmall).tracking(1.5)
                .foregroundStyle(Palette.onAmber.opacity(0.8))
        }
        .padding(.horizontal, 36).padding(.vertical, 22)
        .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Palette.amber))
        .shadowSoft()
        .overlay(alignment: .topLeading) { sparkle.offset(x: -10, y: -8) }
        .overlay(alignment: .bottomTrailing) { sparkle.offset(x: 10, y: 8) }
    }

    private var sparkle: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(Palette.gold)
    }

    private var priceRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(fullPrice)
                .font(SolaFont.body(20, weight: .semibold))
                .foregroundStyle(Palette.ink3)
                .strikethrough(true, color: Palette.ink3)
            Text(promoPrice)
                .font(SolaFont.display(34, weight: .heavy)).tracking(-0.6)
                .foregroundStyle(Palette.ink)
            Text("/an").font(SolaFont.body(16)).foregroundStyle(Palette.ink3)
        }
        .lineLimit(1).minimumScaleFactor(0.7)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Annuel — offre unique")
                    .font(SolaFont.body(15, weight: .bold)).foregroundStyle(Palette.ink)
                Spacer()
                Text(perMonth.map { String(localized: "\($0)/mois") } ?? promoPrice)
                    .font(SolaFont.body(15, weight: .heavy)).foregroundStyle(Palette.ink)
            }
            Text(hasTrial ? "3 jours d'essai gratuit, puis \(promoPrice)/an" : "\(promoPrice) facturé chaque année")
                .font(SolaFont.body(12)).foregroundStyle(Palette.ink3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlassPanel(radius: Radius.lg, tint: Palette.accentSoft, tintOpacity: 0.5))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Palette.amberDeep, lineWidth: 2)
        )
    }

    private var ctaButton: some View {
        Button {
            Task {
                guard let pkg = purchases.promoPackage else {
                    if purchases.promoPackage == nil { await purchases.loadOfferings() }
                    if purchases.promoPackage == nil { showError = true; return }
                    return
                }
                let ok = await purchases.purchase(pkg)
                if ok { onPurchased() }
                else if purchases.lastError != nil { showError = true }
            }
        } label: {
            ZStack {
                if purchases.purchasing {
                    ProgressView().tint(Palette.onAmber)
                } else {
                    Text(hasTrial ? "Commencer l'essai gratuit" : "Profiter de l'offre")
                        .font(SolaFont.body(17, weight: .bold)).foregroundStyle(Palette.onAmber)
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
}
