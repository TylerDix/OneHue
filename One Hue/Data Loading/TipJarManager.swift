import Combine
import StoreKit

@MainActor
final class TipJarManager: ObservableObject {

    static let shared = TipJarManager()

    static let productIDs: [String] = [
        "com.dix.OneHue.tip.small",
        "com.dix.OneHue.tip.medium",
        "com.dix.OneHue.tip.large"
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseState: PurchaseState = .idle

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case thankYou
        case failed(String)
    }

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            // Products stay empty — tip jar section won't show
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                purchaseState = .thankYou
                try? await Task.sleep(for: .seconds(3))
                if purchaseState == .thankYou {
                    purchaseState = .idle
                }
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed("Purchase could not be completed.")
            try? await Task.sleep(for: .seconds(3))
            if case .failed = purchaseState {
                purchaseState = .idle
            }
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? result.payloadValue {
                    await transaction.finish()
                    await MainActor.run { [weak self] in
                        self?.purchaseState = .thankYou
                    }
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
