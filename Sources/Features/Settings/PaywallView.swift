import SwiftUI
import StoreKit

// MARK: - PaywallView

struct PaywallView: View {
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss

    let feature: PaywallFeature?

    @State private var manager = PurchaseManager.shared
    @State private var selectedProduct: Product?

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
            case .insights: return String(localized: "AI Insight Summaries")
            case .prompts:  return String(localized: "All Prompt Packs")
            case .general:  return "Pro"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(spacing: 0) {
                    closeButton
                    heroSection
                    featureGrid
                    pricingSection
                    ctaButton
                    restoreButton
                    legalFootnote
                }
                .padding(.horizontal, Metric.l)
                .padding(.bottom, Metric.xxl)
                .readableColumn()
            }
            .scrollIndicators(.hidden)
        }
        .task { await manager.refresh() }
        .onAppear {
            // 默认选中年度产品（推荐）
            if selectedProduct == nil {
                selectedProduct = manager.subscriptionProducts.first { ProductTier(rawValue: $0.id) == .annual }
                    ?? manager.subscriptionProducts.first
            }
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
            // App icon
            Image(systemName: "book.closed.fill")
                .font(.system(size: 44))
                .foregroundStyle(pal.accent)
                .padding(.bottom, Metric.xs)

            Text(headlineText)
                .font(.dSerifPageTitle)
                .foregroundStyle(pal.ink)
                .multilineTextAlignment(.center)

            Text(subheadlineText)
                .font(.dCaption)
                .foregroundStyle(pal.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Metric.l)
        }
        .padding(.vertical, Metric.l)
    }

    private var headlineText: String {
        if let f = feature, f != .general {
            return String(localized: "Unlock \(f.localizedName)")
        }
        return String(localized: "Upgrade to Full")
    }

    private var subheadlineText: String {
        String(localized: "One subscription unlocks everything — keep writing without limits.")
    }

    // MARK: - Feature Grid

    private var featureGrid: some View {
        VStack(spacing: Metric.xs) {
            ForEach(featureItems) { item in
                featureRow(item)
            }
        }
        .padding(.vertical, Metric.m)
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
                        free: "3 per day",
                        pro: "Unlimited"),
            FeatureItem(icon: "photo.on.rectangle",
                        title: "Photos per entry",
                        free: "1",
                        pro: "Up to 4"),
            FeatureItem(icon: "icloud",
                        title: "iCloud backup",
                        free: "On device only",
                        pro: "Cloud backup + across devices"),
            FeatureItem(icon: "paintpalette",
                        title: "Themes & fonts",
                        free: "1 theme · 1 font",
                        pro: "5 themes · many fonts"),
            FeatureItem(icon: "sparkles",
                        title: "Mood insights",
                        free: "Mood + keywords",
                        pro: "AI weekly/monthly summary"),
            FeatureItem(icon: "arrow.up.doc",
                        title: "PDF export",
                        free: "None",
                        pro: "Export whole book"),
        ]
    }

    private func featureRow(_ item: FeatureItem) -> some View {
        HStack(spacing: Metric.s) {
            Image(systemName: item.icon)
                .font(.system(size: 16))
                .foregroundStyle(pal.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(pal.ink)
                HStack(spacing: 6) {
                    Text(item.free)
                        .font(.system(size: 12))
                        .foregroundStyle(pal.inkSoft)
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(pal.inkSoft)
                    Text(item.pro)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(pal.accent)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Metric.m)
        .padding(.vertical, Metric.s)
        .diaryCard(radius: Metric.thumbRadius, elevation: 0.5)
    }

    // MARK: - Pricing Selector

    private var pricingSection: some View {
        VStack(spacing: Metric.s) {
            // 订阅选项
            ForEach(manager.subscriptionProducts, id: \.id) { product in
                pricingChip(product)
            }

            // 永久买断
            if let lifetime = manager.lifetimeProduct {
                pricingChip(lifetime)
            }
        }
        .padding(.vertical, Metric.m)
    }

    private func pricingChip(_ product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id
        let tier = ProductTier(rawValue: product.id)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProduct = product
            }
        } label: {
            HStack(spacing: Metric.s) {
                // 选中指示器
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? pal.accent : pal.line, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(pal.accent)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(tierLabel(tier))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(pal.ink)

                        if tier == .annual {
                            Text("Best Value")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(pal.onAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(pal.accent, in: Capsule())
                        }
                    }

                    if let monthly = manager.monthlyEquivalent(for: product) {
                        Text("\(monthly)/mo")
                            .font(.system(size: 12))
                            .foregroundStyle(pal.inkSoft)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(pal.ink)

                if let trial = manager.trialText(for: product) {
                    Text(trial)
                        .font(.system(size: 10))
                        .foregroundStyle(pal.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(pal.accent.opacity(0.1), in: Capsule())
                }
            }
            .padding(.horizontal, Metric.m)
            .padding(.vertical, Metric.s + 4)
            .background(
                isSelected ? pal.card : pal.card.opacity(0.6),
                in: RoundedRectangle(cornerRadius: Metric.thumbRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metric.thumbRadius)
                    .stroke(isSelected ? pal.accent : pal.line, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func tierLabel(_ tier: ProductTier?) -> String {
        switch tier {
        case .weekly:   return String(localized: "Weekly")
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
            return tier == .lifetime ? String(localized: "Buy Lifetime") : String(localized: "Continue · \(tierLabel(tier))")
        }
        return String(localized: "Choose a plan")
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task { await manager.restore() }
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
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(.system(size: 10))
                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(pal.inkSoft)
                Link("Privacy Policy", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
                    .font(.system(size: 10))
            }
            .foregroundStyle(pal.inkSoft.opacity(0.6))
        }
        .padding(.top, Metric.l)
    }
}

// MARK: - Preview

#Preview {
    PaywallView(feature: .general)
        .environment(\.palette, .darkGold)
}
