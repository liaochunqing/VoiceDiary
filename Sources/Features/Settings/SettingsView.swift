import SwiftUI
import SwiftData
import UIKit

/// 「检查更新」结果：查 App Store 最新版本与本地比对。
private enum UpdateCheckResult {
    case available(version: String, url: URL)
    case upToDate
    case failed
}

struct SettingsView: View {
    @Environment(\.palette) private var pal
    @Environment(\.bookNavigator) private var navigator
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]

    @State private var notifManager = NotificationManager()
    @State private var lockManager = PrivacyLockManager()
    @State private var purchaseManager = PurchaseManager.shared

    @State private var showPDFPreview = false
    @State private var showPaywall = false
    @State private var paywallFeature: PaywallView.PaywallFeature? = nil
    @State private var iCloudEnabled = UserDefaults.standard.bool(forKey: "iCloudEnabled")
    @State private var audioSyncEnabled = UserDefaults.standard.object(forKey: "audioSyncEnabled") as? Bool ?? true
    @State private var showICloudSheet = false
    @State private var showNotifDeniedAlert = false
    @State private var isCheckingUpdate = false
    @State private var updateResult: UpdateCheckResult?
    @AppStorage("isSoundEnabled") private var isSoundEnabled: Bool = true
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage: String = ""
    @State private var availableLocales: [Locale] = []
    @Environment(\.modelContext) private var context
    @State private var showDeleteAllAlert = false
    @State private var storageSize: String = "Calculating…"

    // 隐私锁图标用安全绿，呼应「音频不出本机」红线卖点；其余图标统一 accent。
    private let safeGreen = Color(lightHex: 0x4E8C5A, darkHex: 0x6FBF7E)

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Metric.l) {
                    // 顶部标题
                    Text("Settings")
                        .font(.dSerifTitle)
                        .foregroundStyle(pal.ink)
                        .padding(.top, Metric.m)

                    if purchaseManager.isUnlocked {
                        unlockedCard
                    } else {
                        paywallCard
                    }
                    preferencesSection
                    themeSection
                    privacySection
                    dataSection
                    supportSection
                    aboutSection
                    #if DEBUG
                    debugSection
                    #endif
                }
                .padding(.horizontal, Metric.l)
                .padding(.bottom, Metric.xxl)
                .readableColumn()
            }
            .scrollIndicators(.hidden)
        }
        .dimmedSheet(isPresented: $showPDFPreview) { PDFPreviewView(entries: entries) }
        .dimmedSheet(isPresented: $showPaywall) {
            PaywallView(feature: paywallFeature)
        }
        .dimmedSheet(isPresented: $showICloudSheet) {
            ICloudSyncSheet(iCloudEnabled: $iCloudEnabled, audioSyncEnabled: $audioSyncEnabled)
        }
        // 打开设置页 / 从系统设置返回时，同步真实授权状态，保证开关不撒谎。
        .task {
            await notifManager.refreshAuthorizationStatus()
            calculateStorageSize()
            availableLocales = SpeechTranscriber.availableOnDeviceLocales()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await notifManager.refreshAuthorizationStatus() }
            }
        }
        .alert("Notifications are turned off", isPresented: $showNotifDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("To get writing reminders, enable notifications in Settings › VoicePaper › Notifications.")
        }
        .alert("Delete All Entries?", isPresented: $showDeleteAllAlert) {
            Button("Delete All", role: .destructive) { deleteAllEntries() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all \(entries.count) entries and their recordings. This can't be undone.")
        }
        .alert("Check for Updates", isPresented: Binding(
            get: { updateResult != nil },
            set: { if !$0 { updateResult = nil } }
        ), presenting: updateResult) { result in
            if case let .available(_, url) = result {
                Button("Update") { UIApplication.shared.open(url) }
                Button("Later", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { result in
            switch result {
            case let .available(version, _):
                Text("Version \(version) is available on the App Store.")
            case .upToDate:
                Text("You already have the latest version.")
            case .failed:
                Text("Couldn't check for updates. Check your connection and try again.")
            }
        }
    }

    // MARK: 解锁完整版（顶部横幅）

    private var paywallCard: some View {
        Button {
            paywallFeature = .general
            showPaywall = true
        } label: {
            HStack(spacing: Metric.l) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: Metric.xs) {
                    Text("Upgrade to Full")
                        .font(.dTitle)
                        .foregroundStyle(.white)
                    Text("Unlimited transcription · All themes · All fonts")
                        .font(.dCaption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, Metric.l)
            .padding(.vertical, Metric.xl)
            .background(
                LinearGradient(
                    colors: [pal.accent, pal.leather],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: Metric.cardRadius)
            )
        }
    }

    // MARK: 已解锁状态卡（成为会员后替代升级卡——给正向反馈，而非直接消失留空）

    private var unlockedCard: some View {
        HStack(spacing: Metric.l) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: Metric.xs) {
                Text("Full unlocked")
                    .font(.dTitle)
                    .foregroundStyle(.white)
                Text("Thanks for your support — every feature is on.")
                    .font(.dCaption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(.horizontal, Metric.l)
        .padding(.vertical, Metric.xl)
        .background(
            LinearGradient(
                colors: [pal.accent, pal.leather],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Metric.cardRadius)
        )
    }

    // MARK: 偏好（提醒 + 翻页声音）

    private var preferencesSection: some View {
        settingCard(title: "Preferences") {
            VStack(spacing: 0) {
                HStack(spacing: Metric.m) {
                    IconRowLabel(icon: "bell", label: "Remind me to write")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { notifManager.isEnabled },
                        set: { newVal in
                            if newVal {
                                // 未决定 → 弹 app 内系统授权框；已授权 → 直接开启；
                                // 已被系统拒绝 → 无法再弹框，提示去系统设置开启（不静默失败）。
                                Task {
                                    let granted = await notifManager.requestPermission()
                                    notifManager.isEnabled = granted
                                    if !granted && notifManager.isDeniedBySystem {
                                        showNotifDeniedAlert = true
                                    }
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
                    RowDivider()
                    HStack(spacing: Metric.m) {
                        IconRowLabel(icon: "clock", label: "Reminder time")
                        Spacer()
                        DatePicker("", selection: Binding(
                            get: { notifManager.reminderTime },
                            set: { notifManager.reminderTime = $0 }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden().tint(pal.accent)
                    }
                    .padding(.vertical, Metric.m)
                }

                RowDivider()

                HStack(spacing: Metric.m) {
                    IconRowLabel(icon: "character.bubble", label: "Transcription language")
                    Spacer()
                    Menu {
                        Picker("", selection: $transcriptionLanguage) {
                            Text("Automatic").tag("")
                            ForEach(availableLocales, id: \.identifier) { loc in
                                Text(localeDisplayName(loc.identifier)).tag(loc.identifier)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(localeDisplayName(transcriptionLanguage))
                                .font(.dSubhead)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(pal.inkSoft)
                    }
                }
                .padding(.vertical, Metric.m)

                RowDivider()

                HStack(spacing: Metric.m) {
                    IconRowLabel(icon: "speaker.wave.2", label: "Page-turn sound")
                    Spacer()
                    Toggle("", isOn: $isSoundEnabled).tint(pal.accent).labelsHidden()
                }
                .padding(.vertical, Metric.m)
            }
        }
    }

    /// 语言标识符 → 本地化显示名；空串显示「自动」。
    private func localeDisplayName(_ id: String) -> String {
        guard !id.isEmpty else { return String(localized: "Automatic") }
        return Locale.current.localizedString(forIdentifier: id) ?? id
    }

    // MARK: 隐私与安全

    private var privacySection: some View {
        settingCard(title: "Privacy & Security") {
            HStack(spacing: Metric.m) {
                IconRowLabel(icon: "faceid", tint: safeGreen,
                           label: "Face ID / Passcode Lock",
                           subtitle: "Require authentication when opening the app")
                Spacer()
                // 隐私锁免费：私密日记的信任底座，不做付费项。
                Toggle("", isOn: Binding(
                    get: { lockManager.isEnabled },
                    set: { lockManager.isEnabled = $0 }
                ))
                .tint(pal.accent).labelsHidden()
            }
            .padding(.vertical, Metric.m)
        }
    }

    // MARK: 数据（统计已移到目录页，与 AI 洞察 / 今日引导并列）

    private var dataSection: some View {
        settingCard(title: "Data") {
            VStack(spacing: 0) {
                // iCloud 同步：Pro 功能。云端备份+跨设备是会员特权，本机存储免费。
                Button {
                    guard purchaseManager.isUnlocked else {
                        paywallFeature = .iCloud
                        showPaywall = true
                        return
                    }
                    showICloudSheet = true
                } label: {
                    settingRow(icon: "icloud", label: "iCloud Sync",
                               locked: !purchaseManager.isUnlocked)
                }

                RowDivider()

                Button { showPDFPreview = true } label: {
                    settingRow(icon: "arrow.up.doc", label: "Export as PDF")
                }

                RowDivider()

                HStack(spacing: Metric.m) {
                    IconRowLabel(icon: "internaldrive", label: "Storage Usage")
                    Spacer()
                    Text(storageSize).font(.dSubhead).foregroundStyle(pal.inkSoft)
                }
                .padding(.vertical, Metric.m)

                RowDivider()

                Button { showDeleteAllAlert = true } label: {
                    HStack(spacing: Metric.m) {
                        IconRowLabel(icon: "trash", tint: Color.red, label: "Delete All Entries")
                        Spacer()
                    }
                    .padding(.vertical, Metric.m)
                }
            }
        }
    }

    // MARK: 主题

    private var themeSection: some View {
        settingCard(title: "Appearance") {
            // 等宽 5 列：色环 + 名称在下 + 锁角标。避免单行硬塞导致名称换行变形。
            HStack(alignment: .top, spacing: Metric.xs) {
                ForEach(AppTheme.allCases) { theme in
                    themeChip(
                        theme,
                        selected: themeManager.current == theme,
                        locked: theme != .darkGold && theme != .celadon && theme != .rose && !purchaseManager.isUnlocked
                    ) { selectTheme(theme) }
                }
            }
            .padding(.vertical, Metric.m)
        }
    }

    private func selectTheme(_ theme: AppTheme) {
        if theme != .darkGold, theme != .celadon, theme != .rose, !purchaseManager.isUnlocked {
            paywallFeature = .themes
            showPaywall = true
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) { themeManager.current = theme }
    }

    private func themeChip(_ theme: AppTheme, selected: Bool, locked: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(theme.palette.accent)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(selected ? pal.accent : pal.line,
                                                 lineWidth: selected ? 2.5 : 1))
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.palette.onAccent)
                    }
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(pal.inkSoft)
                            .frame(width: 16, height: 16)
                            .background(pal.card, in: Circle())
                            .overlay(Circle().stroke(pal.line, lineWidth: 0.5))
                            .offset(x: 15, y: -15)
                    }
                }
                Text(theme.displayName)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? pal.ink : pal.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    #if DEBUG
    // MARK: 调试（仅 DEBUG）

    private var debugSection: some View {
        settingCard(title: "🛠 Debug") {
            HStack(spacing: Metric.m) {
                IconRowLabel(icon: "wrench.and.screwdriver", label: "Simulate Pro",
                           subtitle: "Toggles isUnlocked · DEBUG only")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { purchaseManager.isUnlocked },
                    set: { newVal in
                        purchaseManager.isUnlocked = newVal
                        UserDefaults.standard.set(newVal, forKey: "debugForceUnlocked")
                    }
                ))
                .tint(pal.accent).labelsHidden()
            }
            .padding(.vertical, Metric.m)
        }
    }
    #endif

    // MARK: 支持我们

    private var supportSection: some View {
        settingCard(title: "Support Us") {
            VStack(spacing: 0) {
                Button { rateApp() } label: { settingRow(icon: "star", label: "Rate Us") }

                RowDivider()
                Button { shareApp() } label: {
                    settingRow(icon: "square.and.arrow.up", label: "Share with Friends")
                }

                RowDivider()
                Button {
                    if let url = URL(string: "mailto:support@windylabs.app?subject=Voice%20Diary%20Feedback") {
                        UIApplication.shared.open(url)
                    }
                } label: { settingRow(icon: "envelope", label: "Feedback") }

                RowDivider()
                Button {
                    if let url = URL(string: "itms-apps://itunes.apple.com/developer/id\("8X79G5XCU6")") {
                        UIApplication.shared.open(url)
                    }
                } label: { settingRow(icon: "apps.iphone", label: "More Apps") }
            }
        }
    }

    // MARK: 关于

    private var aboutSection: some View {
        settingCard(title: "About") {
            VStack(spacing: 0) {
                // 检查更新：查 App Store 最新版本与本地比对，有新版引导去更新。
                Button { Task { await checkForUpdate() } } label: {
                    HStack(spacing: Metric.m) {
                        IconRowLabel(icon: "arrow.triangle.2.circlepath", label: "Check for Updates")
                        Spacer()
                        if isCheckingUpdate {
                            ProgressView().tint(pal.accent)
                        } else {
                            Text("v\(appVersion)")
                                .font(.dCaption)
                                .foregroundStyle(pal.inkSoft)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(pal.inkSoft.opacity(0.7))
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .padding(.vertical, Metric.m)
                }
                .disabled(isCheckingUpdate)

                RowDivider()
                Button {
                    if let url = URL(string: "https://windylabs.app/voicepaper/privacy.html") {
                        UIApplication.shared.open(url)
                    }
                } label: { settingRow(icon: "doc.text", label: "Privacy Policy") }

                RowDivider()
                Button { Task { await purchaseManager.restore() } } label: {
                    settingRow(icon: "arrow.clockwise", label: "Restore Purchases")
                }

                RowDivider()
                Button {
                    if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    settingRow(icon: "creditcard", label: "Manage Subscription")
                }
            }
        }
    }

    // App Store 页面地址：评分用 write-review 直达写评价，分享用 https 页面（任意人可点开）。
    private static let appStoreID = "6670278331"

    /// 「给我们评分」：直达 App Store 写评价页；itms-apps 打不开时用 https 兜底。
    private func rateApp() {
        let review = "itms-apps://itunes.apple.com/app/id\(Self.appStoreID)?action=write-review"
        let web = "https://apps.apple.com/app/id\(Self.appStoreID)?action=write-review"
        if let url = URL(string: review), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: web) {
            UIApplication.shared.open(url)
        }
    }

    /// 「分享给朋友」：带一句邀请语 + App Store 链接，从最顶层 VC 弹分享面板（iPad 需 popover 锚点，否则崩）。
    private func shareApp() {
        guard let url = URL(string: "https://apps.apple.com/app/id\(Self.appStoreID)") else { return }
        let invite = String(localized: "I use VoicePaper to journal every day — just open the book and talk to it. Try it:")
        presentShareSheet(items: [invite, url])
    }

    @MainActor
    private func presentShareSheet(items: [Any]) {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let root = (scene.keyWindow ?? scene.windows.first)?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = top.view
        vc.popoverPresentationController?.sourceRect = CGRect(
            x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
        vc.popoverPresentationController?.permittedArrowDirections = []
        top.present(vc, animated: true)
    }

    // MARK: 共用组件（骨架已抽到 DesignSystem：SectionCard / IconRowLabel / RowDivider，全 app 共用）

    private func settingCard<C: View>(title: LocalizedStringKey, @ViewBuilder content: @escaping () -> C) -> some View {
        SectionCard(title: title) { content() }
    }

    private func settingRow(icon: String, label: LocalizedStringKey, locked: Bool = false) -> some View {
        HStack(spacing: Metric.m) {
            IconRowLabel(icon: icon, label: label)
            Spacer()
            if locked {
                Image(systemName: "lock.fill").foregroundStyle(pal.inkSoft).font(.dCaption)
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(pal.inkSoft.opacity(0.7))
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.vertical, Metric.m)
    }

    private func settingRowValue(icon: String, label: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: Metric.m) {
            IconRowLabel(icon: icon, label: label)
            Spacer()
            Text(value).font(.dSubhead).foregroundStyle(pal.inkSoft)
        }
        .padding(.vertical, Metric.m)
    }

    // MARK: 逻辑

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.2.0"
    }

    private func calculateStorageSize() {
        Task.detached(priority: .utility) {
            let formatted = Self.appDataSize()
            await MainActor.run { self.storageSize = formatted }
        }
    }

    /// 统计本 App 实际占用的磁盘。SwiftData 的库（Main.store / Audio.store）和
    /// `@Attribute(.externalStorage)` 的照片/音频大块都落在 Application Support
    /// （不在 Documents——旧实现只扫 Documents，所以永远显示 0）。这里把
    /// Application Support 与 Documents 一起算上，覆盖所有真实数据。
    private static nonisolated func appDataSize() -> String {
        let fm = FileManager.default
        let roots = [
            fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            fm.urls(for: .documentDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        var total: Int64 = 0
        // 不跳过隐藏文件：external storage 在 `.Main.store_SUPPORT` 这类点开头目录里。
        for root in roots {
            guard let enumerator = fm.enumerator(at: root,
                                                 includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]) else { continue }
            for case let url as URL in enumerator {
                let attrs = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey])
                guard attrs?.isRegularFile == true else { continue }
                total += Int64(attrs?.totalFileAllocatedSize ?? attrs?.fileSize ?? 0)
            }
        }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private func deleteAllEntries() {
        for entry in entries {
            for memo in entry.memos {
                guard let aid = memo.audioID else { continue }
                let desc = FetchDescriptor<VoiceAudio>(predicate: #Predicate { $0.id == aid })
                for a in (try? context.fetch(desc)) ?? [] { context.delete(a) }
            }
            context.delete(entry)
        }
        try? context.save()
    }

    /// 查 App Store 最新版本（iTunes Lookup API），与本地版本号数值比对。
    /// 有新版 → 弹更新提示并可直达 App Store；否则提示已最新 / 检查失败。
    @MainActor
    private func checkForUpdate() async {
        isCheckingUpdate = true
        defer { isCheckingUpdate = false }

        struct Lookup: Decodable {
            struct Item: Decodable { let version: String; let trackViewUrl: String }
            let results: [Item]
        }
        guard var comps = URLComponents(string: "https://itunes.apple.com/lookup") else {
            updateResult = .failed; return
        }
        comps.queryItems = [URLQueryItem(name: "id", value: Self.appStoreID)]
        guard let url = comps.url else { updateResult = .failed; return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let lookup = try JSONDecoder().decode(Lookup.self, from: data)
            // results 为空 = App Store 暂查不到该版本，按「已最新」处理，不打扰用户。
            guard let item = lookup.results.first, let storeURL = URL(string: item.trackViewUrl) else {
                updateResult = .upToDate; return
            }
            if appVersion.compare(item.version, options: .numeric) == .orderedAscending {
                updateResult = .available(version: item.version, url: storeURL)
            } else {
                updateResult = .upToDate
            }
        } catch {
            updateResult = .failed
        }
    }
}

// MARK: - iCloud 同步弹窗

/// 设置「iCloud 同步」行点开的底部弹窗：说明 + 自动同步 + 同步录音 一站处理。
/// 开关只写 UserDefaults，由下次启动时 `makeContainer` 读取生效（同步时机由 iCloud 系统调度，故不重建容器）。
private struct ICloudSyncSheet: View {
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss
    @Binding var iCloudEnabled: Bool
    @Binding var audioSyncEnabled: Bool

    private let okGreen = Color(red: 0.45, green: 0.69, blue: 0.53)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metric.l) {
                Text("iCloud Sync")
                    .font(.dSerifPageTitle)
                    .foregroundStyle(pal.ink)
                    .padding(.top, Metric.s)

                Text("Entries stay on your device by default. Turn this on to sync to your personal iCloud for backup and across devices — never through our servers.")
                    .font(.dSubhead).foregroundStyle(pal.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Metric.s) {
                    // 自动同步（总开关）
                    HStack {
                        Text("Auto Sync").font(.dSubhead).foregroundStyle(pal.ink)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { iCloudEnabled },
                            set: { v in
                                iCloudEnabled = v
                                UserDefaults.standard.set(v, forKey: "iCloudEnabled")
                            }
                        ))
                        .tint(pal.accent).labelsHidden()
                    }
                    .padding(Metric.m)
                    .diaryCard()

                    if iCloudEnabled {
                        Label("Sync is on — scheduled automatically by iCloud",
                              systemImage: "checkmark.circle.fill")
                            .font(.dCaption).foregroundStyle(okGreen)
                            .padding(.horizontal, Metric.xs)
                    }

                    // 同步录音原声（开了自动同步才可用）
                    VStack(alignment: .leading, spacing: Metric.xs) {
                        HStack {
                            Text("Sync original audio").font(.dSubhead).foregroundStyle(pal.ink)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { audioSyncEnabled },
                                set: { v in
                                    audioSyncEnabled = v
                                    UserDefaults.standard.set(v, forKey: "audioSyncEnabled")
                                }
                            ))
                            .tint(pal.accent).labelsHidden()
                            .disabled(!iCloudEnabled)
                        }
                        Text("When off, recordings stay on this device; only text and photos sync.")
                            .font(.dCaption).foregroundStyle(pal.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Metric.m)
                    .diaryCard()
                    .opacity(iCloudEnabled ? 1 : 0.45)
                }

                Button { dismiss() } label: {
                    Text("Done")
                        .font(.dSubhead.weight(.semibold))
                        .foregroundStyle(pal.accent)
                        .frame(maxWidth: .infinity)
                        .padding(Metric.m)
                        .diaryCard(elevation: 0.5)
                }
                .padding(.top, Metric.xs)
            }
            .padding(Metric.l)
        }
        .background(pal.paper)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - PDF 预览 & 导出

import WebKit

struct PDFPreviewView: View {
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss
    let entries: [DiaryEntry]

    @State private var isLoaded = false
    @State private var isExporting = false
    @State private var showPaywall = false
    private let webView = WKWebView()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(lightHex: 0xD9CDB8, darkHex: 0x2A231A).ignoresSafeArea()
                DiaryWebView(webView: webView,
                             html: DataManager.exportHTML(entries: entries),
                             onLoaded: { isLoaded = true })
                if !isLoaded {
                    ProgressView().tint(pal.accent)
                }
            }
            .navigationTitle("Export Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(pal.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Group {
                        if isExporting {
                            ProgressView().tint(pal.accent)
                        } else {
                            Button("Export") { handleExport() }
                                .font(.body.bold())
                                .foregroundStyle(isLoaded ? pal.accent : pal.inkSoft)
                        }
                    }
                    .disabled(!isLoaded || isExporting)
                }
            }
        }
        .dimmedSheet(isPresented: $showPaywall) { PaywallView(feature: .pdf) }
    }

    private func handleExport() {
        guard PurchaseManager.shared.isUnlocked else {
            showPaywall = true
            return
        }
        isExporting = true
        Task { @MainActor in
            // 分页渲染必须在主线程（依赖 webView 的 print formatter）。
            let data = paginatedPDFData()
            isExporting = false
            do {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(String(localized: "My Diary.pdf"))
                try data.write(to: url)
                shareFile(url)
            } catch {}
        }
    }

    /// 用 UIPrintPageRenderer + UIMarkupTextPrintFormatter，按 A4 真分页生成 PDF。
    /// 不用 `webView.viewPrintFormatter()`：WKWebView 跨进程渲染，drawPage 在 PDF 上下文里
    /// 抓不到内容（页数对但每页空白）。改用进程内渲染 HTML 字符串，分页正常且不空白。
    @MainActor
    private func paginatedPDFData() -> Data {
        let html = DataManager.exportHTML(entries: entries)
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        // 页尺寸对齐 HTML 画布 794×1123（= A4@96dpi，794:1123 正好是 A4 比例）。
        // 这样 UIMarkupTextPrintFormatter 按 px≈pt 排版不会右侧裁切，min-height:1123 正好满一页；
        // 打开/打印时按 A4 等比缩放。
        let pageRect = CGRect(x: 0, y: 0, width: 794, height: 1123)
        renderer.setValue(NSValue(cgRect: pageRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: pageRect), forKey: "printableRect")

        let pdf = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdf, pageRect, nil)
        let pageCount = renderer.numberOfPages   // 触发分页计算
        for i in 0..<pageCount {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: pageRect)
        }
        UIGraphicsEndPDFContext()
        return pdf as Data
    }

    @MainActor
    private func shareFile(_ url: URL) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return }
        // 找到最顶层已呈现的 VC（PDF 预览本身是 sheet，需从它上面 present）
        var top = root
        while let presented = top.presentedViewController { top = presented }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = top.view
        top.present(vc, animated: true)
    }
}

private struct DiaryWebView: UIViewRepresentable {
    let webView: WKWebView
    let html: String
    let onLoaded: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onLoaded: onLoaded) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onLoaded: () -> Void
        init(onLoaded: @escaping () -> Void) { self.onLoaded = onLoaded }
        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) { onLoaded() }
    }
}
