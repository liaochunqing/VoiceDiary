import SwiftUI
import StoreKit

// MARK: - PaywallView

struct PaywallView: View {
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss

    let feature: PaywallFeature?

    @State private var manager = PurchaseManager.shared
    @State private var selectedProduct: Product?
    @State private var showAllFeatures = false
    @State private var showRestoreAlert = false
    @State private var restoreResultText = ""

    /// 如果从特定功能触发，展示不同的 headline。
    enum PaywallFeature: String {
        case iCloud, photos, voice, themes, fonts, pdf, stats, insights, prompts, general

        /// 触发付费墙的功能名（用于「解锁 X」标题），按当前语言本地化。
        var localizedName: String {
            switch self {
            case .iCloud:   return String(localized: "iCloud Sync")
            case .photos:   return String(localized: "Unlimited Photos")
            case .voice:    return String(localized: "Unlimited Transcription")
            case .themes:   return String(localized: "All Themes")
            case .fonts:    return String(localized: "All Fonts")
            case .pdf:      return String(localized: "PDF Export")
            case .stats:    return String(localized: "Full Stats")
            case .insights: return String(localized: "Weekly Recap")
            case .prompts:  return String(localized: "All Prompt Packs")
            case .general:  return "Pro"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                closeButton
                    .padding(.horizontal, Metric.l)

                ScrollView {
                    VStack(spacing: 0) {
                        heroSection
                        featureGrid
                        pricingSection
                    }
                    .padding(.horizontal, Metric.l)
                    .padding(.bottom, Metric.m)
                    .readableColumn()
                }
                .scrollIndicators(.hidden)

                footerBar
            }
        }
        .task { await manager.refresh() }
        .onAppear { selectDefaultIfNeeded() }
        // 产品是异步加载的，加载完成后再补默认选中（否则首屏选不到、CTA 卡在 Choose a plan）
        .onChange(of: manager.subscriptionProducts.count) { _, _ in
            selectDefaultIfNeeded()
        }
        .alert(restoreResultText, isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(pal.inkSoft)
                    .frame(width: 36, height: 36)
                    .background(pal.card, in: Circle())
                    .softEdge(Circle())
            }
            .padding(.top, Metric.m)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: Metric.s) {
            Text(headlineText)
                .font(.dSerifPageTitle)
                .foregroundStyle(pal.ink)
                .multilineTextAlignment(.center)
            // 副标题点明三大差异化卖点，给海外用户一个「为什么付费」的理由。
            Text("Voice journaling, on-device mood insight, and a private book that's yours forever.")
                .font(.dCaption)
                .foregroundStyle(pal.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Metric.m)
    }

    private var headlineText: String {
        if let f = feature, f != .general {
            return String(localized: "Unlock \(f.localizedName)")
        }
        return String(localized: "Upgrade to Full")
    }

    // MARK: - Footer (docked)

    private var footerBar: some View {
        VStack(spacing: 0) {
            if let err = manager.purchaseError {
                Text(err)
                    .font(.dCaption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Metric.l)
                    .padding(.top, Metric.s)
            }
            ctaButton
            restoreButton
            legalFootnote
        }
        .padding(.horizontal, Metric.l)
        .padding(.bottom, Metric.m)
        .background(
            pal.paper
                .overlay(pal.line.frame(height: 0.5), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Feature Grid

    private var featureGrid: some View {
        SectionCard(title: "What you get") {
            VStack(spacing: 0) {
                ForEach(Array(visibleFeatures.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { RowDivider() }
                    featureRow(item)
                }

                RowDivider()
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { showAllFeatures.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAllFeatures ? "Show less" : "Show all features")
                        Image(systemName: showAllFeatures ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.dCaption.weight(.semibold))
                    .foregroundStyle(pal.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Metric.s + 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Metric.s)
    }

    /// 默认只露 3 条核心卖点，其余折叠。
    private var visibleFeatures: [FeatureItem] {
        showAllFeatures ? featureItems : Array(featureItems.prefix(3))
    }

    private struct FeatureItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: LocalizedStringKey
        let free: LocalizedStringKey
        let pro: LocalizedStringKey
    }

    private var featureItems: [FeatureItem] {
        [
            FeatureItem(icon: "mic.fill",
                        title: "Transcription",
                        free: "7 per week",
                        pro: "Unlimited"),
            FeatureItem(icon: "sparkles",
                        title: "Weekly recap",
                        free: "Mood + keywords",
                        pro: "On-device weekly recap"),
            FeatureItem(icon: "icloud",
                        title: "iCloud backup",
                        free: "On device only",
                        pro: "Cloud backup + across devices"),
            FeatureItem(icon: "photo.on.rectangle",
                        title: "Photos per entry",
                        free: "1",
                        pro: "Up to 4"),
            FeatureItem(icon: "paintpalette",
                        title: "Themes & fonts",
                        free: "1 theme · 1 font",
                        pro: "5 themes · many fonts"),
            FeatureItem(icon: "arrow.up.doc",
                        title: "PDF export",
                        free: "None",
                        pro: "Export whole book"),
        ]
    }

    private func featureRow(_ item: FeatureItem) -> some View {
        HStack(spacing: Metric.m) {
            IconBadge(systemName: item.icon)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.dSubhead.weight(.semibold))
                    .foregroundStyle(pal.ink)
                HStack(spacing: 6) {
                    Text(item.free)
                        .font(.dCaption)
                        .foregroundStyle(pal.inkSoft)
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(pal.inkSoft)
                    Text(item.pro)
                        .font(.dCaption.weight(.medium))
                        .foregroundStyle(pal.accent)
                }
            }
            Spacer()
        }
        .padding(.vertical, Metric.s + 2)
    }

    // MARK: - Pricing Selector

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: Metric.s) {
            if manager.subscriptionProducts.isEmpty && manager.lifetimeProduct == nil {
                pricingPlaceholder
            } else {
                Text("Choose your plan")
                    .font(.dCaption.weight(.semibold))
                    .foregroundStyle(pal.inkSoft)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .padding(.leading, Metric.xs)
                // 订阅选项
                ForEach(manager.subscriptionProducts, id: \.id) { product in
                    pricingChip(product)
                }
                // 永久买断
                if let lifetime = manager.lifetimeProduct {
                    pricingChip(lifetime)
                }
            }
        }
        .padding(.top, Metric.m)
        .padding(.bottom, Metric.m)
    }

    /// 产品还没加载到 / 加载失败时的占位，避免一片空白。
    private var pricingPlaceholder: some View {
        VStack(spacing: Metric.s) {
            ProgressView().tint(pal.accent)
            Text(manager.purchaseError == nil
                 ? String(localized: "Loading plans…")
                 : String(localized: "Couldn't load plans. Check your connection and try again."))
                .font(.dCaption)
                .foregroundStyle(pal.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                Task { await manager.refresh() }
            } label: {
                Text("Retry")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(pal.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Metric.xl)
    }

    /// 默认选中年付（次选月付/买断）。产品异步到达后可重复调用。
    private func selectDefaultIfNeeded() {
        guard selectedProduct == nil else { return }
        selectedProduct = manager.subscriptionProducts.first { ProductTier(rawValue: $0.id) == .annual }
            ?? manager.subscriptionProducts.first
            ?? manager.lifetimeProduct
    }

    /// 年付相对月付的真实节省百分比，按 storekit 实际价动态算。
    /// 旧代码硬编码 "Save 50%"，但月付价调整后比例已变（约 37%），
    /// 算错折扣百分比会触发 App Store Guideline 3.1.2 拒审，故改为运行时计算。
    private var annualSavingsPercent: Int? {
        let monthly = manager.subscriptionProducts.first { ProductTier(rawValue: $0.id) == .monthly }
        let annual  = manager.subscriptionProducts.first { ProductTier(rawValue: $0.id) == .annual }
        guard let m = monthly, let a = annual else { return nil }
        let monthlyAnnual = NSDecimalNumber(decimal: m.price).multiplying(by: 12)
        guard monthlyAnnual.doubleValue > 0 else { return nil }
        let save = 1 - NSDecimalNumber(decimal: a.price).doubleValue / monthlyAnnual.doubleValue
        let pct = Int((save * 100).rounded())
        return pct >= 1 ? pct : nil
    }

    private func pricingChip(_ product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id
        let tier = ProductTier(rawValue: product.id)
        let isCover = (tier == .annual)   // 年付 = 精装封皮高亮卡

        let titleColor = isCover ? pal.onAccent : pal.ink
        let subColor   = isCover ? pal.onAccent.opacity(0.78) : pal.inkSoft

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProduct = product
            }
        } label: {
            HStack(spacing: Metric.s) {
                // 选中指示器（minHeight 让三张卡等高，消除 Annual badge 撑高导致的不一致）
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? (isCover ? pal.onAccent : pal.accent)
                                       : (isCover ? pal.onAccent.opacity(0.5) : pal.line),
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(isCover ? pal.onAccent : pal.accent)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(tierLabel(tier))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(titleColor)

                        if tier == .annual, let pct = annualSavingsPercent {
                            Text(String(localized: "Save \(pct)%"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(pal.leatherDark)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(pal.gold, in: Capsule())
                        }
                    }

                    if let monthly = manager.monthlyEquivalent(for: product) {
                        Text("\(monthly)/mo")
                            .font(.system(size: 12))
                            .foregroundStyle(subColor)
                    } else if tier == .lifetime {
                        Text("One-time · yours forever")
                            .font(.system(size: 12))
                            .foregroundStyle(subColor)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(product.displayPrice)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(titleColor)

                    if let trial = manager.trialText(for: product) {
                        Text(trial)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isCover ? pal.onAccent : pal.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background((isCover ? pal.onAccent : pal.accent).opacity(0.16), in: Capsule())
                    }
                }
            }
            .frame(minHeight: 54)
            .padding(.horizontal, Metric.m)
            .padding(.vertical, Metric.s + 4)
            .background(
                isCover ? pal.leather : (isSelected ? pal.card : pal.card.opacity(0.6)),
                in: RoundedRectangle(cornerRadius: Metric.cardRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metric.cardRadius)
                    .stroke(
                        isSelected ? (isCover ? pal.gold : pal.accent) : (isCover ? pal.leather : pal.line),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func tierLabel(_ tier: ProductTier?) -> String {
        switch tier {
        case .monthly:  return String(localized: "Monthly")
        case .annual:   return String(localized: "Annual")
        case .lifetime: return String(localized: "Lifetime")
        case .none:     return ""
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            Task { await manager.purchase(product) }
        } label: {
            HStack(spacing: Metric.xs) {
                if manager.isPurchasing {
                    ProgressView()
                        .tint(pal.onAccent)
                }
                Text(ctaLabel)
                    .font(.dSubhead.weight(.bold))
            }
            .foregroundStyle(pal.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Metric.m)
            .background(pal.accent, in: RoundedRectangle(cornerRadius: Metric.buttonRadius))
        }
        .disabled(selectedProduct == nil || manager.isPurchasing)
        .padding(.top, Metric.s)
    }

    private var ctaLabel: String {
        if manager.isPurchasing {
            return String(localized: "Purchasing…")
        }
        if let product = selectedProduct {
            let tier = ProductTier(rawValue: product.id)
            if tier == .lifetime { return String(localized: "Buy Lifetime") }
            if manager.trialText(for: product) != nil { return String(localized: "Start Free Trial") }
            return String(localized: "Continue · \(tierLabel(tier))")
        }
        return String(localized: "Choose a plan")
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task {
                await manager.restore()
                // 恢复后给明确反馈，换机/重装用户是高价值付费用户，恢复体验差=客诉+退款。
                restoreResultText = manager.isUnlocked
                    ? String(localized: "Pro restored. Thanks for your support!")
                    : String(localized: "No purchases found for this Apple ID.")
                showRestoreAlert = true
            }
        } label: {
            Text("Restore Purchases")
                .font(.dCaption)
                .foregroundStyle(pal.inkSoft)
        }
        .padding(.top, Metric.m)
    }

    // MARK: - Legal

    private var legalFootnote: some View {
        VStack(spacing: 4) {
            Text("Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in App Store settings. Lifetime is a one-time purchase and does not renew.")
                .font(.system(size: 10))
                .foregroundStyle(pal.inkSoft.opacity(0.7))
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Link("Terms of Use", destination: URL(string: "https://windylabs.app/voicepaper/terms.html")!)
                    .font(.system(size: 10))
                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(pal.inkSoft)
                Link("Privacy Policy", destination: URL(string: "https://windylabs.app/voicepaper/privacy.html")!)
                    .font(.system(size: 10))
            }
            .foregroundStyle(pal.inkSoft.opacity(0.6))
        }
        .padding(.top, Metric.s)
    }
}

// MARK: - Preview

#Preview {
    PaywallView(feature: .general)
        .environment(\.palette, .darkGold)
}
