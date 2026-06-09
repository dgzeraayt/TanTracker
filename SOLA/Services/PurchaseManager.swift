import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let monthlyID = "com.meflabs.SOLA.monthly"
    static let annualID  = "com.meflabs.SOLA.annual"
    static let productIDs = [monthlyID, annualID]

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedIDs: Set<String> = []
    @Published var purchasing = false
    @Published var lastError: String?

    var isPro: Bool { !purchasedIDs.isEmpty }

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }
    deinit { updatesTask?.cancel() }

    func product(for id: String) -> Product? { products.first { $0.id == id } }

    /// Prix affiché (devise locale) ou repli si le catalogue n'est pas chargé.
    func displayPrice(for id: String, fallback: String) -> String {
        product(for: id)?.displayPrice ?? fallback
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func purchase(_ id: String) async -> Bool {
        guard let product = product(for: id) else {
            // Pas de catalogue (ex. simulateur sans config StoreKit) : on n'échoue pas l'UX.
            return false
        }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                    return true
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await StoreKit.AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil { owned.insert(transaction.productID) }
            }
        }
        purchasedIDs = owned
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }
}
