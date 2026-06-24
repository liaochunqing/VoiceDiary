import StoreKit

// MARK: - Product Tier

enum ProductTier: String, CaseIterable, Identifiable {
    case monthly = "com.chunqingliao.VoiceDiary.monthly"
    case annual  = "com.chunqingliao.VoiceDiary.annual"
    case lifetime = "com.chunqingliao.VoiceDiary.fullunlock"

    var id: String { rawValue }

    /// 订阅级别（用于排序），non-consumable 排最后。
    var level: Int {
        switch self {
        case .monthly:  return 0
        case .annual:   return 1
        case .lifetime: return 2
        }
    }

    var isSubscription: Bool { self != .lifetime }
}

// MARK: - PurchaseManager

@MainActor @Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    // ── 状态 ──

    var isUnlocked = false
    var products: [Product] = []
    var isPurchasing = false
    var purchasingProductID: String?
    var purchaseError: String?

    /// 非 nil 时外部应弹出付费墙。
    var showPaywall = false

    private var updateTask: Task<Void, Never>?

    // ── 排序后的产品 ──

    /// 仅订阅类产品，按周期排序。
    var subscriptionProducts: [Product] {
        products
            .filter { ProductTier(rawValue: $0.id)?.isSubscription == true }
            .sorted { (ProductTier(rawValue: $0.id)?.level ?? 0) < (ProductTier(rawValue: $1.id)?.level ?? 0) }
    }

    var lifetimeProduct: Product? {
        products.first { ProductTier(rawValue: $0.id) == .lifetime }
    }

    // MARK: - 初始化

    init() {
        #if DEBUG
        isUnlocked = UserDefaults.standard.bool(forKey: "debugForceUnlocked")
        #endif
        updateTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        do {
            let ids = ProductTier.allCases.map(\.rawValue)
            let fetched = try await Product.products(for: ids)
            products = fetched.sorted { a, b in
                (ProductTier(rawValue: a.id)?.level ?? 0) < (ProductTier(rawValue: b.id)?.level ?? 0)
            }
            purchaseError = nil
        } catch {
            purchaseError = error.localizedDescription
        }
        await checkEntitlements()
    }

    // MARK: - 购买

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchasingProductID = product.id
        purchaseError = nil
        defer {
            isPurchasing = false
            purchasingProductID = nil
        }
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
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - 内部

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let tx) = result else { return }
        // 检查产品 ID 是否为我们管理的任一产品
        guard ProductTier(rawValue: tx.productID) != nil else {
            await tx.finish()
            return
        }
        if tx.revocationDate == nil, let expiry = tx.expirationDate {
            // 订阅：未过期
            if expiry > Date() { isUnlocked = true }
        } else if tx.revocationDate == nil && tx.expirationDate == nil {
            // 非消耗型（永久）
            isUnlocked = true
        }
        await tx.finish()
    }

    func checkEntitlements() async {
        #if DEBUG
        // debug 强制会员：跳过 StoreKit 验证，保持本地标记
        if UserDefaults.standard.bool(forKey: "debugForceUnlocked") {
            isUnlocked = true
            return
        }
        #endif
        // 先置 false：若没有任何有效权益（订阅过期/退款/从未购买）就保持未解锁。
        // 旧代码这里不重置，导致订阅过期后 isUnlocked 残留 true、用户白嫖。
        isUnlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               ProductTier(rawValue: tx.productID) != nil,
               tx.revocationDate == nil {
                if let expiry = tx.expirationDate {
                    if expiry > Date() { isUnlocked = true; return }
                } else {
                    isUnlocked = true; return
                }
            }
        }
    }

    // MARK: - 辅助

    /// 年度产品价格对应的月均价格字符串。
    func monthlyEquivalent(for product: Product) -> String? {
        guard ProductTier(rawValue: product.id) == .annual else { return nil }
        let annual = product.price
        let monthly = (annual as NSDecimalNumber).doubleValue / 12.0
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = product.priceFormatStyle.locale
        return fmt.string(from: NSNumber(value: monthly))
    }

    /// 免费试用描述（如有）。
    func trialText(for product: Product) -> String? {
        guard let intro = product.subscription?.introductoryOffer,
              intro.paymentMode == .freeTrial else { return nil }
        let p = intro.period
        let days: Int
        switch p.unit {
        case .day:   days = p.value
        case .week:  days = p.value * 7
        case .month: days = p.value * 30
        case .year:  days = p.value * 365
        @unknown default: days = p.value
        }
        return String(localized: "\(days)-day free trial")
    }
}
