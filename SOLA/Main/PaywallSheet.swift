import SwiftUI
import RevenueCat
import RevenueCatUI

// Paywall distant RevenueCat (design piloté depuis le dashboard / éditeur AI).
// Présentable en feuille (Analyse, Journal, Profil) ou en mode bloquant (accès à l'app).
struct PaywallSheet: View {
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    /// Paywall bloquant (accès à l'app) : pas de bouton de fermeture.
    var mandatory: Bool = false

    var body: some View {
        PaywallView(displayCloseButton: !mandatory)
            .onPurchaseCompleted { _ in
                Task { await purchases.refreshCustomerInfo() }
                if !mandatory { dismiss() }
            }
            .onRestoreCompleted { customerInfo in
                let active = customerInfo.entitlements[PurchaseManager.entitlementID]?.isActive == true
                Task { await purchases.refreshCustomerInfo() }
                if active && !mandatory { dismiss() }
            }
            .ignoresSafeArea()
    }
}
