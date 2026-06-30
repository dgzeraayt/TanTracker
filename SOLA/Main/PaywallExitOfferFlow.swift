import SwiftUI

// Parcours « exit-intent » réutilisable autour du paywall :
//   paywall (fermable) → croix → roulette → offre unique à prix cassé.
// Un achat (paywall ou offre) appelle `onPurchaseComplete` (ou laisse simplement
// `isPro` débloquer l'app). Refuser l'offre ramène au paywall : l'accès reste
// verrouillé, la roulette n'est qu'une tentative de rétention.
struct PaywallExitOfferFlow: View {
    /// Appelé après un achat/restauration réussi. Optionnel : sur le mur d'accès,
    /// `isPro` bascule seul et la vue racine montre l'app ; en fin d'onboarding,
    /// on s'en sert pour terminer l'onboarding.
    var onPurchaseComplete: (() -> Void)? = nil

    private enum Stage { case paywall, wheel, promo }
    @State private var stage: Stage = .paywall

    var body: some View {
        ZStack {
            switch stage {
            case .paywall:
                PaywallSheet(
                    mandatory: false,
                    onSkip: { onPurchaseComplete?() },                       // achat/restauration réussi
                    onClose: { Analytics.capture(.exitOfferShown); withAnimation(.easeInOut) { stage = .wheel } } // croix → roulette
                )
                .transition(.opacity)
            case .wheel:
                SpinWheelView(onFinished: { withAnimation(.easeInOut) { stage = .promo } })
                    .transition(.opacity)
            case .promo:
                PromoOfferSheet(
                    onClose: { withAnimation(.easeInOut) { stage = .paywall } }, // refus → retour paywall (verrouillé)
                    onPurchased: { Analytics.capture(.exitOfferAccepted); onPurchaseComplete?() }
                )
                .transition(.move(edge: .bottom))
            }
        }
    }
}
