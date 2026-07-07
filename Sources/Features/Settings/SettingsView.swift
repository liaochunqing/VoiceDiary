import SwiftUI
import SwiftData
import UIKit

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
    @AppStorage("isSoundEnabled") private var isSoundEnabled: Bool = true
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage: String = ""
    @State private var availableLocales: [Locale] = []
    @Environment(\.modelContext) private var context
    @Environment(DeletionCoordinator.self) private var deletionCoordinator
    @State private var showDeleteAllAlert = false
    @State private var showMoreApps = false
    @State private var deleteAllResult: DeleteAllResult? = nil
    @State private var storageSize: String = String(localized: "Calculating…")

    // 隐藏入口：连点版本号 7 次 → 弹访问码弹窗（作者自用，避免重复购买自己的会员）
    @State private var versionTapCount = 0
    @State private var showUnlockPrompt = false
    @State private var unlockInput = ""
    @State private var showUnlockResult = false

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
        .dimmedSheet(isPresented: $showMoreApps) {
            MoreAppsView()
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
        .onChange(of: entries.count) { _, _ in
            calculateStorageSize()
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
        .alert(deleteAllResult == .success ? "Delete Successful" : "Delete Failed",
               isPresented: Binding(
                   get: { deleteAllResult != nil },
                   set: { if !$0 { deleteAllResult = nil } }
               )) {
            Button("OK") { deleteAllResult = nil }
        }
        // 隐藏入口：访问码正确则切换本地会员解锁；错误静默不提示，不暴露机制。
        .alert("Enter Access Code", isPresented: $showUnlockPrompt) {
            SecureField("Access Code", text: $unlockInput)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Confirm") {
                let ok = Self.verifyAccessCode(unlockInput)
                unlockInput = ""
                if ok {
                    UserDefaults.standard.set(true, forKey: "debugForceUnlocked")
                    purchaseManager.isUnlocked = true
                    showUnlockResult = true
                }
            }
            Button("Cancel", role: .cancel) { unlockInput = "" }
        }
        .alert(purchaseManager.isUnlocked ? "Pro Unlocked" : "Pro Locked", isPresented: $showUnlockResult) {
            Button("OK") {}
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
            // Simulate Pro
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

            Divider().background(pal.line)

            // Screenshot data seeder（英文）
            Button {
                UserDefaults.standard.set(true, forKey: "screenshotData")
                Task { @MainActor in
                    ScreenshotSeeder.seedIfRequested(context)
                    UserDefaults.standard.set(false, forKey: "screenshotData")
                }
            } label: {
                HStack(spacing: Metric.m) {
                    IconRowLabel(icon: "photo.artframe", label: "Reset with Screenshot Data",
                               subtitle: "English sample entries for App Store screenshots")
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(pal.accent)
                }
                .padding(.vertical, Metric.m)
            }

            Divider().background(pal.line)

            // Screenshot data seeder（中文）
            Button {
                Task { @MainActor in
                    ScreenshotSeeder.seedChinese(context)
                }
            } label: {
                HStack(spacing: Metric.m) {
                    IconRowLabel(icon: "photo.artframe", label: "用中文数据重置",
                               subtitle: "中文区上架截图用的示例日记")
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(pal.accent)
                }
                .padding(.vertical, Metric.m)
            }
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
                    if let url = URL(string: "mailto:windylabs@icloud.com?subject=Voice%20Diary%20Feedback") {
                        UIApplication.shared.open(url)
                    }
                } label: { settingRow(icon: "envelope", label: "Feedback") }

                RowDivider()
                Button { showMoreApps = true } label: { settingRow(icon: "apps.iphone", label: "More Apps") }
            }
        }
    }

    // MARK: 关于

    private var aboutSection: some View {
        settingCard(title: "About") {
            VStack(spacing: 0) {
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

                RowDivider()
                Button {
                    versionTapCount += 1
                    if versionTapCount >= 7 {
                        versionTapCount = 0
                        unlockInput = ""
                        showUnlockPrompt = true
                    }
                } label: {
                    HStack(spacing: Metric.m) {
                        IconRowLabel(icon: "info.circle", label: "Version")
                        Spacer()
                        Text("v\(appVersion)")
                            .font(.dCaption)
                            .foregroundStyle(pal.inkSoft)
                    }
                    .padding(.vertical, Metric.m)
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

    /// 隐藏入口访问码校验（作者自用，避免重复购买自己的会员）。
    private static func verifyAccessCode(_ input: String) -> Bool {
        input == "liaochunqing"
    }

    private enum DeleteAllResult {
        case success
        case failure
    }

    private func calculateStorageSize() {
        let container = context.container
        Task.detached(priority: .utility) {
            let formatted: String
            do {
                // 用独立 context 在后台读取「当前仍存在」的用户数据。
                // 不统计 SQLite/WAL 预留页：那是实现细节，不是用户的日记用量。
                let backgroundContext = ModelContext(container)
                let allEntries = try backgroundContext.fetch(FetchDescriptor<DiaryEntry>())
                let allAudio = try backgroundContext.fetch(FetchDescriptor<VoiceAudio>())

                var bytes: Int64 = 0
                for entry in allEntries {
                    bytes += Int64(entry.content.utf8.count)
                    bytes += Int64(entry.location.utf8.count)
                    bytes += entry.photos.reduce(into: 0) { $0 += Int64($1.count) }
                    bytes += entry.memos.reduce(into: 0) { $0 += Int64($1.transcript.utf8.count) }
                }
                bytes += allAudio.reduce(into: 0) { $0 += Int64($1.data?.count ?? 0) }
                formatted = Self.formattedDataSize(bytes)
            } catch {
                formatted = "—"
                #if DEBUG
                print("[Settings] Calculate storage usage failed: \(error)")
                #endif
            }
            await MainActor.run { self.storageSize = formatted }
        }
    }

    private static nonisolated func formattedDataSize(_ bytes: Int64) -> String {
        bytes == 0 ? "0 B" : ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func deleteAllEntries() {
        // 立刻通知列表页清空 ForEach：必须在动 context 之前让所有 DiaryRow 从视图层级
        // 移除，否则 delete + save 后 backing data detach，DiaryRow.body 再访问
        // entry.photos(@Attribute.externalStorage) 会触发 fatal error 崩溃。
        deletionCoordinator.isBulkDeleting = true
        Task { @MainActor in
            // 等 alert 关闭动画彻底完成（~0.4s），避免 pageCurl + alert dismiss
            // 两组动画同时操作视图层级产生 singular matrix → 崩溃；
            // 同时给列表页一拍完成清空渲染。
            try? await Task.sleep(nanoseconds: 450_000_000)

            do {
                // 删除全部 VoiceAudio，而不仅是当前日记引用到的部分；
                // 这样也会清理历史版本或异常保存留下的孤立音频。
                let entriesToDelete = try context.fetch(FetchDescriptor<DiaryEntry>())
                let audioToDelete = try context.fetch(FetchDescriptor<VoiceAudio>())
                for entry in entriesToDelete { context.delete(entry) }
                for audio in audioToDelete { context.delete(audio) }

                // ★ 与单条删除同一原则：delete 和 save 之间必须留出间隙，
                // 让视图层彻底移除所有行引用，再 detach backing data。
                try? await Task.sleep(nanoseconds: 300_000_000)
                try context.save()

                // 等 @Query 刷新落地后再解除清空状态，避免残影行访问已删对象。
                try? await Task.sleep(nanoseconds: 150_000_000)
                deletionCoordinator.isBulkDeleting = false

                // 保存已成功，用户日记数据此刻就是 0；不等待 SQLite 何时回收预留页。
                storageSize = Self.formattedDataSize(0)
                deleteAllResult = .success
            } catch {
                // save 失败时撤销内存中的删除标记，避免出现「看起来已删除」的假成功。
                context.rollback()
                deletionCoordinator.isBulkDeleting = false
                calculateStorageSize()
                deleteAllResult = .failure
                #if DEBUG
                print("[Settings] Delete all entries failed: \(error)")
                #endif
            }
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
            VStack(alignment: .leading, spacing: Metric.xl) {
                Text("iCloud Sync")
                    .font(.dSerifPageTitle)
                    .foregroundStyle(pal.ink)
                    .padding(.top, Metric.m)

                Text("Entries stay on your device by default. Turn this on to sync to your personal iCloud for backup and across devices — never through our servers.")
                    .font(.dSerifBody).foregroundStyle(pal.inkSoft)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Metric.l) {
                    // 自动同步（总开关）
                    VStack(alignment: .leading, spacing: Metric.xs) {
                        HStack {
                            Text("Auto Sync").font(.dSerifSubhead.weight(.semibold)).foregroundStyle(pal.ink)
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
                        Text("Changes take effect after the app restarts.")
                            .font(.dCaption).foregroundStyle(pal.inkSoft)
                    }
                    .padding(Metric.l)
                    .diaryCard()

                    // 同步录音原声（开了自动同步才可用）
                    VStack(alignment: .leading, spacing: Metric.xs) {
                        HStack {
                            Text("Sync original audio").font(.dSerifSubhead.weight(.semibold)).foregroundStyle(pal.ink)
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
                    .padding(Metric.l)
                    .diaryCard()
                    .opacity(iCloudEnabled ? 1 : 0.45)
                }
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

// MARK: - More Apps

private struct MoreAppsView: View {
    @Environment(\.palette) private var pal
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    private let snoreScribeURL = URL(string: "https://apps.apple.com/app/id6778848782")!

    var body: some View {
        ScrollView {
            VStack(spacing: Metric.xl) {
                Image("SnoreScribe")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                VStack(spacing: Metric.xs) {
                    Text("SnoreScribe")
                        .font(.dSerifPageTitle)
                        .foregroundStyle(pal.ink)
                    Text("Is your snoring getting better or worse?")
                        .font(.dBody)
                        .foregroundStyle(pal.inkSoft)
                        .multilineTextAlignment(.center)
                }

                Text("SnoreScribe listens while you sleep, then gives you a morning report with trends, severity scores, and insights — so you know whether your snoring is improving over time.")
                    .font(.dSerifBody)
                    .foregroundStyle(pal.inkSoft)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                Button {
                    openURL(snoreScribeURL)
                } label: {
                    HStack(spacing: Metric.xs) {
                        Image(systemName: "arrow.down.app")
                        Text("Download on the App Store")
                    }
                    .font(.dBody.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Metric.m)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(lightHex: 0x007AFF, darkHex: 0x0A84FF))
                    )
                }
            }
            .padding(.horizontal, Metric.l)
            .padding(.vertical, Metric.xl)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Previews

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let container = PreviewHelper.container()
        Group {
            PreviewWrapper(container: container) { SettingsView() }
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("SE")

            PreviewWrapper(container: container) { SettingsView() }
                .previewDevice("iPhone 16 Pro")
                .previewDisplayName("16 Pro")

            PreviewWrapper(container: container) { SettingsView() }
                .previewDevice("iPhone 16 Pro Max")
                .previewDisplayName("Pro Max")

            PreviewWrapper(container: container) { SettingsView() }
                .previewDevice("iPad (10th generation)")
                .previewDisplayName("iPad 10")
        }
    }
}
#endif
