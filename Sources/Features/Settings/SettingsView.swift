import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]

    @State private var notifManager = NotificationManager()
    @State private var lockManager = PrivacyLockManager()
    @State private var purchaseManager = PurchaseManager.shared

    @State private var showStats = false
    @State private var iCloudEnabled = UserDefaults.standard.bool(forKey: "iCloudEnabled")
    @State private var showReminderTimePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                pal.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Metric.m) {
                        if !purchaseManager.isUnlocked {
                            paywallCard
                        }
                        themeSection
                        reminderSection
                        privacySection
                        dataSection
                        aboutSection
                    }
                    .padding(Metric.l)
                    .padding(.bottom, Metric.xxl)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(pal.accent)
                }
            }
        }
        .sheet(isPresented: $showStats) { StatsView() }
    }

    // MARK: 付费横幅

    private var paywallCard: some View {
        Button {
            Task { await purchaseManager.purchase() }
        } label: {
            HStack(spacing: Metric.m) {
                VStack(alignment: .leading, spacing: Metric.xs) {
                    Text("解锁完整版").font(.dTitle).foregroundStyle(.white)
                    Text("导出 PDF · 无限主题 · 优先支持")
                        .font(.dCaption).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(purchaseManager.isPurchasing ? "购买中…" : purchaseManager.priceString)
                        .font(.dCallout.weight(.bold)).foregroundStyle(.white)
                    Text("一次买断").font(.dCaption).foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(Metric.l)
            .background(
                LinearGradient(colors: [pal.accent, pal.leather],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: Metric.cardRadius)
            )
        }
        .disabled(purchaseManager.isPurchasing)
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
        }
    }

    private func themeChip(_ theme: AppTheme, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Metric.xs) {
                Circle()
                    .fill(theme.palette.accent)
                    .frame(width: 12, height: 12)
                Text(theme.displayName).font(.dSubhead)
            }
            .foregroundStyle(selected ? pal.onAccent : pal.ink)
            .padding(.horizontal, Metric.m)
            .padding(.vertical, Metric.s)
            .background(selected ? pal.accent : pal.card, in: Capsule())
            .overlay(Capsule().stroke(selected ? .clear : pal.line, lineWidth: 1))
        }
    }

    // MARK: 提醒

    private var reminderSection: some View {
        settingCard(title: "每日提醒", icon: "bell") {
            VStack(spacing: Metric.m) {
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
                    .tint(pal.accent)
                    .labelsHidden()
                }
                if notifManager.isEnabled {
                    Divider().background(pal.line)
                    HStack {
                        Text("提醒时间").font(.dSubhead).foregroundStyle(pal.ink)
                        Spacer()
                        DatePicker("", selection: Binding(
                            get: { notifManager.reminderTime },
                            set: { notifManager.reminderTime = $0 }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(pal.accent)
                    }
                }
            }
        }
    }

    // MARK: 隐私

    private var privacySection: some View {
        settingCard(title: "隐私", icon: "lock") {
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
                .tint(pal.accent)
                .labelsHidden()
            }
        }
    }

    // MARK: 数据

    private var dataSection: some View {
        settingCard(title: "数据", icon: "externaldrive") {
            VStack(spacing: 0) {
                Button { showStats = true } label: {
                    settingRow(icon: "chart.bar", label: "记录统计")
                }

                Divider().background(pal.line).padding(.leading, 36)

                HStack {
                    Label("iCloud 同步", systemImage: "icloud")
                        .font(.dSubhead).foregroundStyle(pal.ink)
                    Spacer()
                    Toggle("", isOn: $iCloudEnabled)
                        .tint(pal.accent)
                        .labelsHidden()
                        .onChange(of: iCloudEnabled) { _, v in
                            UserDefaults.standard.set(v, forKey: "iCloudEnabled")
                        }
                }
                .padding(.vertical, Metric.xs)

                Divider().background(pal.line).padding(.leading, 36)

                Button {
                    exportPDF()
                } label: {
                    settingRow(icon: "arrow.up.doc", label: "导出 PDF",
                               locked: !purchaseManager.isUnlocked)
                }
            }
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
                } label: {
                    settingRow(icon: "star", label: "给我们评分")
                }

                Divider().background(pal.line).padding(.leading, 36)

                Button {
                    Task { await purchaseManager.restore() }
                } label: {
                    settingRow(icon: "arrow.clockwise", label: "恢复购买")
                }
            }
        }
    }

    // MARK: 共用组件

    private func settingCard<C: View>(title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Metric.m) {
            Label(title, systemImage: icon)
                .font(.dCaption.weight(.semibold))
                .foregroundStyle(pal.inkSoft)
                .textCase(.uppercase)

            content()
                .padding(Metric.m)
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
        .padding(.vertical, Metric.xs)
    }

    private func settingRowValue(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.dSubhead).foregroundStyle(pal.ink)
            Spacer()
            Text(value).font(.dCaption).foregroundStyle(pal.inkSoft)
        }
        .padding(.vertical, Metric.xs)
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
