import SwiftUI

// Paywall présentable en feuille (depuis l'Analyse, le Journal ou le Profil).
// Partage la logique d'achat StoreKit 2 avec l'écran d'onboarding ScrPaywall.
struct PaywallSheet: View {
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var annual = true

    private let perks = [
        "Analyse IA illimitée de ta peau",
        "Suivi photo illimité de ton bronzage",
        "Plan UV quotidien & alertes brûlure",
        "Indice UV et fenêtre idéale en direct"
    ]
    private var selectedID: String { annual ? PurchaseManager.annualID : PurchaseManager.monthlyID }
    private var ctaTitle: String {
        if purchases.purchasing { return "Traitement…" }
        if let p = purchases.product(for: selectedID), p.subscription?.introductoryOffer != nil {
            return "Essai gratuit de 7 jours"
        }
        return "S'abonner"
    }

    var body: some View {
        ScreenScaffold(
            background: LinearGradient(colors: [
                Color(oklch: 0.46, 0.09, 54), Color(oklch: 0.24, 0.04, 50), Color(oklch: 0.18, 0.02, 52)
            ], startPoint: .top, endPoint: .bottom),
            lightStatusBar: true
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SolaMark(size: 22, color: .white)
                    Spacer()
                    Button { dismiss() } label: {
                        Icon(name: "cross", size: 18, stroke: 2.4).foregroundStyle(.white.opacity(0.8))
                            .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.12)))
                    }.buttonStyle(.plain)
                }
                .padding(.top, 8)

                Spacer()
                DisplayText(text: "Débloque ton\nété parfait", size: 44, color: .white)
                VStack(alignment: .leading, spacing: 13) {
                    ForEach(perks, id: \.self) { t in
                        HStack(spacing: 14) {
                            Icon(name: "check", size: 14, stroke: 3).foregroundStyle(Palette.onAmber)
                                .frame(width: 26, height: 26).background(Circle().fill(Palette.gold))
                            Text(t).font(SolaFont.body(15.5, weight: .medium)).foregroundStyle(.white.opacity(0.92))
                        }
                    }
                }
                .padding(.top, 22)
                HStack(spacing: 14) {
                    priceCard(tag: "MENSUEL",
                              price: purchases.displayPrice(for: PurchaseManager.monthlyID, fallback: "6,99 €"),
                              sub: "/ mois", selected: !annual)
                        .onTapGesture { annual = false }
                    priceCard(tag: "ANNUEL",
                              price: purchases.displayPrice(for: PurchaseManager.annualID, fallback: "34,99 €"),
                              sub: "/ an · 2,92 €/mois", selected: annual)
                        .onTapGesture { annual = true }
                }
                .padding(.top, 26)
                Spacer()
                SolaButton(title: ctaTitle, kind: .amber, icon: purchases.purchasing ? nil : "arrowR") {
                    Task {
                        let ok = await purchases.purchase(selectedID)
                        if ok { dismiss() }
                    }
                }
                .disabled(purchases.purchasing)
                HStack(spacing: 16) {
                    Button("Restaurer") { Task { await purchases.restore(); if purchases.isPro { dismiss() } } }
                    Text("·")
                    Button("Plus tard") { dismiss() }
                    Text("·")
                    Text("CGU")
                }
                .buttonStyle(.plain)
                .font(SolaFont.body(12.5)).foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity).padding(.top, 14)
            }
            .padding(.horizontal, Frame.padH).padding(.bottom, 18)
        }
        .onChange(of: purchases.isPro) { _, isPro in if isPro { dismiss() } }
    }

    private func priceCard(tag: String, price: String, sub: String, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tag).font(SolaFont.mono(11)).tracking(1)
                .foregroundStyle(selected ? Palette.onAmber : .white.opacity(0.6))
            Text(price).font(SolaFont.display(28, weight: .heavy))
                .foregroundStyle(selected ? Palette.onAmber : .white).padding(.top, 6)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(sub).font(SolaFont.body(13)).foregroundStyle(selected ? Palette.onAmber.opacity(0.7) : .white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(selected ? Palette.gold : Color.white.opacity(0.08))
        )
        .overlay(alignment: .topTrailing) {
            if tag == "ANNUEL" { Badge(text: "-58%").offset(x: -12, y: -11) }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(selected ? 0 : 0.18), lineWidth: 1.5)
        )
    }
}
