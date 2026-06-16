import StoreKit

@MainActor @Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    private let productID = "com.chunqingliao.VoiceDiary.fullunlock"

    var isUnlocked = false
    var product: Product?
    var isPurchasing = false
    var purchaseError: String?

    // 单例生命周期与 App 等长，无需 cancel
    private var updateTask: Task<Void, Never>?

    init() {
        updateTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        do {
            let products = try await Product.products(for: [productID])
            product = products.first
        } catch {}
        await checkEntitlements()
    }

    func purchase() async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
        isPurchasing = false
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let tx) = result else { return }
        if tx.productID == productID && tx.revocationDate == nil {
            isUnlocked = true
        }
        await tx.finish()
    }

    private func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.productID == productID {
                isUnlocked = true
                return
            }
        }
    }

    var priceString: String {
        product?.displayPrice ?? "¥15"
    }
}
