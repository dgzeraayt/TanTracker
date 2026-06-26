import Foundation
import RevenueCat

/// Gestion des abonnements via RevenueCat.
/// L'entitlement `premium` (mappé sur les abos mensuel + annuel) déverrouille l'app.
@MainActor
final class PurchaseManager: ObservableObject {
    // Identifiants produits App Store — doivent matcher les *store identifiers* RevenueCat.
    static let monthlyID = "com.meflabs.suny.monthly"
    static let annualID  = "com.meflabs.suny.annual"
    /// Abo annuel « offre unique » à prix cassé (19,99 €/an), proposé après la
    /// roulette de fin d'onboarding. Rangé comme package `annual_promo` dans
    /// l'offering courante (même approche que les autres projets, ex. ScrollUps).
    static let promoAnnualID = "com.meflabs.suny.annual.promo"

    /// Entitlement RevenueCat qui donne accès à l'app.
    static let entitlementID = "premium"

    /// Clé API publique RevenueCat (plateforme Apple, production).
    static let revenueCatAPIKey = "appl_xKvYMYpxGsOkONRGexcEGZqqQoN"

    @Published private(set) var offering: Offering?
    @Published private(set) var isSubscribed = false
    @Published var purchasing = false
    @Published var lastError: String?
    /// Déverrouillage manuel réservé aux builds DEBUG / captures.
    @Published var manualUnlock = false

    func grantAccess() {
        #if DEBUG
        manualUnlock = true
        #endif
    }

    #if DEBUG
    // Déverrouillage en dev / captures : `SOLA_PRO=1` ou `SOLA_SCREEN`.
    private static let debugUnlocked = ProcessInfo.processInfo.environment["SOLA_PRO"] != nil
        || ProcessInfo.processInfo.environment["SOLA_SCREEN"] != nil
    var isPro: Bool { Self.debugUnlocked || manualUnlock || isSubscribed }
    #else
    var isPro: Bool { isSubscribed }
    #endif

    private static var configured = false

    init() {
        Self.configureIfNeeded()
        Task {
            await refreshCustomerInfo()
            await loadOfferings()
        }
        observeCustomerInfo()
    }

    /// Configure le SDK RevenueCat une seule fois, au plus tôt dans le cycle de vie.
    static func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        #if DEBUG
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: revenueCatAPIKey)
    }

    // MARK: - Packages

    var monthlyPackage: Package? { package(for: Self.monthlyID) }
    var annualPackage: Package? { package(for: Self.annualID) }

    /// Package de l'offre promo (`annual_promo`) dans l'offering courante.
    var promoPackage: Package? { package(for: Self.promoAnnualID) }

    func package(for productID: String) -> Package? {
        offering?.availablePackages.first { $0.storeProduct.productIdentifier == productID }
    }

    /// Prix promo localisé (ex. « 19,99 € ») ou repli si l'offre n'est pas chargée.
    func promoPrice(fallback: String) -> String {
        promoPackage?.storeProduct.localizedPriceString ?? fallback
    }

    /// Prix annuel plein localisé (ex. « 29,99 € »), pour l'afficher barré face au prix promo.
    func annualFullPrice(fallback: String) -> String {
        annualPackage?.storeProduct.localizedPriceString ?? fallback
    }

    /// Prix promo ramené au mois (ex. « 1,66 € »), pour une accroche « /mois ».
    func promoPricePerMonth() -> String? {
        promoPackage?.storeProduct.localizedPricePerMonth
    }

    /// Prix localisé (devise de l'utilisateur) ou repli si le catalogue n'est pas chargé.
    func displayPrice(for productID: String, fallback: String) -> String {
        package(for: productID)?.storeProduct.localizedPriceString ?? fallback
    }

    /// Indique si le produit propose un essai gratuit (offre d'introduction).
    func hasFreeTrial(for productID: String) -> Bool {
        package(for: productID)?.storeProduct.introductoryDiscount?.paymentMode == .freeTrial
    }

    /// Durée de l'essai gratuit (ex. « 3 jours ») si disponible.
    func freeTrialLabel(for productID: String) -> String? {
        guard let disc = package(for: productID)?.storeProduct.introductoryDiscount,
              disc.paymentMode == .freeTrial else { return nil }
        let n = disc.subscriptionPeriod.value
        switch disc.subscriptionPeriod.unit {
        case .day:   return n == 1 ? "1 jour" : "\(n) jours"
        case .week:  return n == 1 ? "1 semaine" : "\(n) semaines"
        case .month: return n == 1 ? "1 mois" : "\(n) mois"
        case .year:  return "\(n) an"
        @unknown default: return "\(n)"
        }
    }

    /// Prix localisé ramené à la semaine (ex. « 0,58 € »), pour afficher une accroche
    /// « par semaine » sur l'offre annuelle. `nil` si le catalogue n'est pas chargé.
    func localizedPricePerWeek(for productID: String) -> String? {
        package(for: productID)?.storeProduct.localizedPricePerWeek
    }

    /// Économie de l'abonnement annuel vs 12× le mensuel (en %), si les prix sont chargés.
    var annualSavingsPercent: Int? {
        guard let m = monthlyPackage?.storeProduct.price,
              let a = annualPackage?.storeProduct.price else { return nil }
        let yearly = m * 12
        guard yearly > 0 else { return nil }
        let pct = NSDecimalNumber(decimal: (yearly - a) / yearly).doubleValue * 100
        return pct > 0 ? Int(pct.rounded()) : nil
    }

    // MARK: - Chargement

    func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            offering = offerings.current
            if offering == nil {
                lastError = "Aucune offre d'abonnement n'est disponible pour le moment."
            } else {
                lastError = nil
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            updateSubscription(from: info)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Achat / restauration

    @discardableResult
    func purchase(_ package: Package) async -> Bool {
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return false }
            updateSubscription(from: result.customerInfo)
            if !isSubscribed {
                lastError = "L'achat a été validé, mais l'accès Goldn+ n'a pas été activé. Vérifie l'entitlement RevenueCat « \(Self.entitlementID) »."
            } else {
                lastError = nil
            }
            return isSubscribed
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Variante par identifiant produit (pour les écrans qui sélectionnent par ID).
    @discardableResult
    func purchase(_ productID: String) async -> Bool {
        guard let pkg = package(for: productID) else {
            lastError = "Le produit « \(productID) » est introuvable dans l'offre RevenueCat actuelle."
            return false
        }
        return await purchase(pkg)
    }

    func restore() async {
        _ = await restorePurchases()
    }

    @discardableResult
    func restorePurchases() async -> Bool {
        purchasing = true
        defer { purchasing = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            updateSubscription(from: info)
            if !isSubscribed {
                lastError = "Aucun abonnement Goldn+ actif n'a été trouvé sur ce compte Apple."
            } else {
                lastError = nil
            }
            return isSubscribed
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Privé

    private func updateSubscription(from info: CustomerInfo) {
        isSubscribed = info.entitlements[Self.entitlementID]?.isActive == true
    }

    private func observeCustomerInfo() {
        Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.updateSubscription(from: info)
            }
        }
    }
}
