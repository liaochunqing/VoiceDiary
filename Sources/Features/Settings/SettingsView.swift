import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.palette) private var pal
    @Environment(\.bookNavigator) private var navigator
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]

    @State private var notifManager = NotificationManager()
    @State private var lockManager = PrivacyLockManager()
    @State private var purchaseManager = PurchaseManager.shared

    @State private var showStats = false
    @State private var iCloudEnabled = UserDefaults.standard.bool(forKey: "iCloudEnabled")
    @AppStorage("isSoundEnabled") private var isSoundEnabled: Bool = true

    var body: some View {
        ZStack {
            pal.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Metric.m) {
                    // 顶部标题
                    Text("设置")
                        .font(.dPageTitle)
                        .foregroundStyle(pal.ink)
                        .padding(.top, Metric.m)

                    if !purchaseManager.isUnlocked {
                        paywallCard
                    }
                    reminderSection
                    privacySection
                    dataSection
                    themeSection
                    aboutSection
                }
                .padding(.horizontal, Metric.l)
                .padding(.bottom, Metric.xxl)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showStats) { StatsView() }
    }

    // MARK: 解锁完整版（顶部横幅）

    private var paywallCard: some View {
        Button {
            Task { await purchaseManager.purchase() }
        } label: {
            HStack(spacing: Metric.m) {
                VStack(alignment: .leading, spacing: Metric.xs) {
                    Text("✨ 解锁完整版").font(.dTitle).foregroundStyle(.white)
                    Text("导出 PDF · 无限图片 · 优先支持")
                        .font(.dCaption).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(purchaseManager.isPurchasing ? "购买中…" : purchaseManager.priceString)
                        .font(.dCallout.weight(.bold)).foregroundStyle(.white)
                    Text("一次买断").font(.dCaption).foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, Metric.l)
            .padding(.vertical, Metric.xl)
            .background(
                LinearGradient(colors: [pal.accent, pal.leather],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: Metric.cardRadius)
            )
        }
        .disabled(purchaseManager.isPurchasing)
    }

    // MARK: 每日提醒

    private var reminderSection: some View {
        settingCard(title: "每日提醒", icon: "bell") {
            VStack(spacing: 0) {
                HStack {
                    Text("提醒我写日记").font(.dSubhead).foregroundStyle(pal.ink)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { notifManager.isEnabled },
                        set: { newVal in
                            if newVal {
                                Task {
                                    let granted = await notifManager.requestPermission()
                                    if !granted { return }
                                    notifManager.isEnabled = true
                                }
                            } else {
                                notifManager.isEnabled = false
                            }
                        }
                    ))
                    .tint(pal.accent).labelsHidden()
                }
                .padding(.vertical, Metric.m)

                if notifManager.isEnabled {
                    Divider().background(pal.line)
                    HStack {
                        Text("提醒时间").font(.dSubhead).foregroundStyle(pal.ink)
                        Spacer()
                        DatePicker("", selection: Binding(
                            get: { notifManager.reminderTime },
                            set: { notifManager.reminderTime = $0 }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden().tint(pal.accent)
                    }
                    .padding(.vertical, Metric.m)
                }

                Divider().background(pal.line)

                HStack {
                    Text("翻页声音").font(.dSubhead).foregroundStyle(pal.ink)
                    Spacer()
                    Toggle("", isOn: $isSoundEnabled).tint(pal.accent).labelsHidden()
                }
                .padding(.vertical, Metric.m)
            }
        }
    }

    // MARK: 隐私与安全

    private var privacySection: some View {
        settingCard(title: "隐私与安全", icon: "lock") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Face ID / 密码锁").font(.dSubhead).foregroundStyle(pal.ink)
                    Text("打开 App 时需要验证").font(.dCaption).foregroundStyle(pal.inkSoft)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { lockManager.isEnabled },
                    set: { lockManager.isEnabled = $0 }
                ))
                .tint(pal.accent).labelsHidden()
            }
            .padding(.vertical, Metric.m)
        }
    }

    // MARK: 数据与备份

    private var dataSection: some View {
        settingCard(title: "数据与备份", icon: "externaldrive") {
            VStack(spacing: 0) {
                HStack {
                    Label("iCloud 同步", systemImage: "icloud")
                        .font(.dSubhead).foregroundStyle(pal.ink)
                    Spacer()
                    Toggle("", isOn: $iCloudEnabled)
                        .tint(pal.accent).labelsHidden()
                        .onChange(of: iCloudEnabled) { _, v in
                            UserDefaults.standard.set(v, forKey: "iCloudEnabled")
                        }
                }
                .padding(.vertical, Metric.m)

                Divider().background(pal.line).padding(.leading, 36)

                Button { exportPDF() } label: {
                    settingRow(icon: "arrow.up.doc", label: "导出为 PDF",
                               locked: !purchaseManager.isUnlocked)
                }

                Divider().background(pal.line).padding(.leading, 36)

                Button { showStats = true } label: {
                    settingRow(icon: "chart.bar", label: "我的统计")
                }
            }
        }
    }

    // MARK: 主题

    private var themeSection: some View {
        settingCard(title: "主题", icon: "paintpalette") {
            HStack(spacing: Metric.s) {
                ForEach(AppTheme.allCases) { theme in
                    themeChip(theme, selected: themeManager.current == theme) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            themeManager.current = theme
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, Metric.s)
        }
    }

    private func themeChip(_ theme: AppTheme, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Metric.xs) {
                Circle().fill(theme.palette.accent).frame(width: 12, height: 12)
                Text(theme.displayName).font(.dSubhead)
            }
            .foregroundStyle(selected ? pal.onAccent : pal.ink)
            .padding(.horizontal, Metric.m)
            .padding(.vertical, Metric.s)
            .background(selected ? pal.accent : pal.card, in: Capsule())
            .overlay(Capsule().stroke(selected ? .clear : pal.line, lineWidth: 1))
        }
    }

    // MARK: 关于

    private var aboutSection: some View {
        settingCard(title: "关于", icon: "info.circle") {
            VStack(spacing: 0) {
                settingRowValue(icon: "number", label: "版本", value: appVersion)

                Divider().background(pal.line).padding(.leading, 36)
                Button {
                    if let url = URL(string: "itms-apps://itunes.apple.com/app/id6670278331?action=write-review") {
                        UIApplication.shared.open(url)
                    }
                } label: { settingRow(icon: "star", label: "给我们评分") }

                Divider().background(pal.line).padding(.leading, 36)
                Button { Task { await purchaseManager.restore() } } label: {
                    settingRow(icon: "arrow.clockwise", label: "恢复购买")
                }

                Divider().background(pal.line).padding(.leading, 36)
                Button {
                    if let url = URL(string: "https://www.apple.com/legal/privacy/") {
                        UIApplication.shared.open(url)
                    }
                } label: { settingRow(icon: "doc.text", label: "隐私政策") }

                Divider().background(pal.line).padding(.leading, 36)
                Button { shareApp() } label: {
                    settingRow(icon: "square.and.arrow.up", label: "分享给朋友")
                }

                Divider().background(pal.line).padding(.leading, 36)
                Button {
                    if let url = URL(string: "mailto:liaochunqing520@gmail.com?subject=翻页日记 意见反馈") {
                        UIApplication.shared.open(url)
                    }
                } label: { settingRow(icon: "envelope", label: "意见反馈") }

                Divider().background(pal.line).padding(.leading, 36)
                Button {
                    if let url = URL(string: "itms-apps://itunes.apple.com/developer/id\("8X79G5XCU6")") {
                        UIApplication.shared.open(url)
                    }
                } label: { settingRow(icon: "apps.iphone", label: "其他产品") }
            }
        }
    }

    @State private var showShareSheet = false

    private func shareApp() {
        guard let url = URL(string: "https://apps.apple.com/app/id6670278331"),
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        root.present(vc, animated: true)
    }

    // MARK: 共用组件

    private func settingCard<C: View>(title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Metric.s) {
            Label(title, systemImage: icon)
                .font(.dCaption.weight(.semibold))
                .foregroundStyle(pal.inkSoft)
                .textCase(.uppercase)

            content()
                .padding(.horizontal, Metric.m)
                .background(pal.card, in: RoundedRectangle(cornerRadius: Metric.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(pal.line, lineWidth: 1))
        }
    }

    private func settingRow(icon: String, label: String, locked: Bool = false) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.dSubhead).foregroundStyle(pal.ink)
            Spacer()
            if locked {
                Image(systemName: "lock.fill").foregroundStyle(pal.inkSoft).font(.dCaption)
            }
            Image(systemName: "chevron.right").foregroundStyle(pal.inkSoft).font(.dCaption)
        }
        .padding(.vertical, Metric.m)
    }

    private func settingRowValue(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.dSubhead).foregroundStyle(pal.ink)
            Spacer()
            Text(value).font(.dCaption).foregroundStyle(pal.inkSoft)
        }
        .padding(.vertical, Metric.m)
    }

    // MARK: 逻辑

    private func exportPDF() {
        guard purchaseManager.isUnlocked else { return }
        // TODO: PDFKit 导出
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.2.0"
    }
}
