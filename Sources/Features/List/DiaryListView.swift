import SwiftUI
import SwiftData
import UIKit

struct DiaryListView: View {
    @Environment(\.palette) private var pal
    @Environment(\.bookNavigator) private var navigator
    @Environment(\.modelContext) private var context
    @Environment(DeletionCoordinator.self) private var deletionCoordinator
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]
    @State private var search = ""
    @State private var showSearch = false
    @FocusState private var searchFocused: Bool
    @State private var showEditor = false
    /// 从「今日状态条」进编辑器时携带的 prompt；胶囊按钮进则置 nil。
    @State private var pendingPrompt: String? = nil
    /// 「Talk」按钮点下 → 编辑器打开后自动拉起录音。
    @State private var pendingAutoRecord = false
    @State private var showInsights = false
    @State private var showPrompts = false
    @State private var showStats = false
    /// 左滑「Edit」选中的待编辑日记；非空即弹编辑器。
    @State private var editTarget: DiaryEntry? = nil
    /// 左滑「Delete」选中的待删日记；非空即弹确认 alert。
    @State private var deleteTarget: DiaryEntry? = nil
    /// alert 确认后立刻加入此集合，把 entry 从 ForEach 移除，避免 context.delete 后再访问 photos 崩溃。
    @State private var deletedIDs: Set<UUID> = []
    /// 目录页手势提示是否已收起（用户建了自己的第一篇 / 手动 × 后置 true，不再出现）。
    @AppStorage("contentsGestureHintDone") private var gestureHintDone = false
    private var stats: DataManager.StreakStats { DataManager.streakStats(entries) }

    private var filtered: [DiaryEntry] {
        guard !search.isEmpty else { return entries }
        let q = search
        let dateFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd"; return f }()
        return entries.filter {
            $0.content.localizedCaseInsensitiveContains(q)
            || $0.location.localizedCaseInsensitiveContains(q)
            || $0.memos.contains { $0.transcript.localizedCaseInsensitiveContains(q) }
            || dateFmt.string(from: $0.date).contains(q)
        }
    }

    /// 实际参与渲染的日记：批量删除期间整体清空，单条删除（含详情页）按 id 隐藏，
    /// 配合 `DeletionCoordinator` 避免 `context.delete + save` 后 `DiaryRow` 仍访问
    /// `entry.photos`（externalStorage）崩溃。
    private var visibleEntries: [DiaryEntry] {
        guard !deletionCoordinator.isBulkDeleting else { return [] }
        return filtered.filter {
            !deletedIDs.contains($0.id) && !deletionCoordinator.hiddenIDs.contains($0.id)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PaperBackground()

            VStack(spacing: Metric.m) {
                header
                if showSearch {
                    searchBar
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if showGestureHint {
                    gestureHint
                        .transition(.opacity)
                }
                if visibleEntries.isEmpty {
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Metric.m) {
                            ForEach(visibleEntries, id: \.id) { entry in
                                let gi = entries.firstIndex { $0.id == entry.id } ?? 0
                                // entries 是新→旧排序(reverse)，书里也是新→旧(index 3 = 最新)
                                // gi=0 = 最新 = 第 1 篇，直接用 gi 作为 entryIndex
                                let page = gi + 1
                                let pending = deletedIDs.contains(entry.id) || deletionCoordinator.hiddenIDs.contains(entry.id)
                                DiaryRow(entry: entry, page: page, isPendingDelete: pending)
                                    .onTapGesture { navigator.goToEntry(at: gi) }
                                    .contextMenu {
                                        Button { editTarget = entry; showEditor = true } label: {
                                            Label("Edit", systemImage: "square.and.pencil")
                                        }
                                        Button(role: .destructive) { deleteTarget = entry } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, Metric.l)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .readableColumn()

            // 空状态 / 无结果：作为 ZStack 直接子视图整屏居中，与搜索栏高度、机型无关
            if entries.isEmpty {
                emptyState
            } else if filtered.isEmpty {
                noResults
            }

            if entries.isEmpty {
                arrowGuide
                    .padding(.trailing, Metric.xl + 6)
                    .padding(.bottom, Metric.xl + 64)
            }

            fab
        }
        // 用户建了自己的第一篇（欢迎页之外）后，目录手势提示功成身退，永久收起。
        .onChange(of: entries.count) { _, newCount in
            if newCount >= 2 { gestureHintDone = true }
        }
        // 新建与编辑共用同一个编辑器 sheet：editTarget 非空＝左滑「Edit」进编辑，否则＝新建。
        .dimmedSheet(isPresented: $showEditor, detents: [.fraction(2/3), .large], onDismiss: { editTarget = nil; pendingAutoRecord = false }) {
            AddDiaryView(editingEntry: editTarget,
                         initialPrompt: editTarget == nil ? pendingPrompt : nil,
                         autoFocusText: editTarget == nil && !pendingAutoRecord,
                         autoStartRecording: pendingAutoRecord)
        }
        .dimmedSheet(isPresented: $showInsights) { InsightsView() }
        .dimmedSheet(isPresented: $showPrompts) { PromptsView() }
        .dimmedSheet(isPresented: $showStats) { StatsView() }
        .alert("Delete this entry?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Delete", role: .destructive) { if let e = deleteTarget { deleteEntry(e) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone")
        }
    }

    /// 删除一条日记。跨库音频无 SwiftData 级联，删前手动清理对应 VoiceAudio
    /// （与 DiaryDetailView.deleteEntry 同一逻辑）。
    ///
    /// 时序要点：`context.delete` 只是标记 isDeleted=true，backing data（含
    /// @Attribute.externalStorage 的 photos）在 `context.save` 之前**不会** detach。
    /// 所以立刻 delete 让 DiaryRow guard 生效，save 延迟到视图移除之后执行。
    private func deleteEntry(_ entry: DiaryEntry) {
        deletedIDs.insert(entry.id)
        // 立刻标记删除：同步设置 isDeleted=true，DiaryRow guard 马上生效；
        // 关键 —— 此时尚未 save，backing data 完整，即使极端情况下访问 photos 也不崩。
        context.delete(entry)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            for memo in entry.memos {
                guard let aid = memo.audioID else { continue }
                let desc = FetchDescriptor<VoiceAudio>(predicate: #Predicate { $0.id == aid })
                for a in (try? context.fetch(desc)) ?? [] { context.delete(a) }
            }
            // save 后 externalStorage 才真正清理；此时 DiaryRow 应已从视图层级移除
            try? context.save()
        }
    }

    // MARK: 顶部栏（标题行 + 三入口）

    private var header: some View {
        VStack(spacing: Metric.m) {
            // 标题行：目录 + 搜索图标 + 设置齿轮
            HStack(alignment: .center, spacing: Metric.l) {
                Text("Contents").font(.dSerifTitle).foregroundStyle(pal.ink)
                Spacer()
                // 搜索：点一下展开/收起下方搜索条（放齿轮左边）。收起时清空关键词。
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        showSearch.toggle()
                    }
                    if showSearch {
                        searchFocused = true
                    } else {
                        search = ""
                        searchFocused = false
                    }
                } label: {
                    Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(showSearch ? pal.accent : pal.inkSoft)
                }
                Button { navigator.goToSettings() } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(pal.inkSoft)
                }
            }

            // 今日状态条：streak + 今天是否已写 + 今日 prompt 预览，一键进编辑器。
            // 第一屏的「写今天」紧迫感全靠它——没写时暖色高亮 + 今日提问 + Write 按钮。
            todayStatusCard

            // 三入口：今日引导 · AI 洞察 · 统计（一排等宽特性卡，醒目可点）
            HStack(spacing: Metric.s) {
                featureButton(icon: "lightbulb.fill", label: "Today's Prompt") { showPrompts = true }
                featureButton(icon: "sparkles", label: "AI Insights") { showInsights = true }
                featureButton(icon: "chart.bar.fill", label: "Stats") { showStats = true }
            }
        }
        .padding(.horizontal, Metric.l)
        .padding(.top, Metric.s)
    }

    // MARK: 今日状态条

    private var todayStatusCard: some View {
        let written = stats.recordedToday
        let streak = stats.current
        let savers = stats.saversLeft
        return Button {
            editTarget = nil
            pendingPrompt = written ? nil : DailyPrompt.today()
            showEditor = true
        } label: {
            HStack(spacing: Metric.m) {
                ZStack {
                    Circle()
                        .fill(written ? pal.accentSoft : pal.accent.opacity(0.16))
                        .frame(width: 38, height: 38)
                    Image(systemName: written ? "checkmark" : "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(written ? pal.accent : pal.leatherDark)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle(written: written, streak: streak))
                        .font(.dSubhead.weight(.semibold))
                        .foregroundStyle(pal.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if written {
                        Text(savers > 0
                             ? String(localized: "❄︎ \(savers) streak-savers left this month")
                             : DailyPrompt.today())
                            .font(.dCaption)
                            .foregroundStyle(pal.inkSoft)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Text(DailyPrompt.today())
                            .font(.dCaption)
                            .foregroundStyle(pal.inkSoft)
                            .lineLimit(2)
                            .italic()
                    }
                }

                Spacer(minLength: 0)

                if !written {
                    Text("Write")
                        .font(.dCaption.weight(.bold))
                        .foregroundStyle(pal.onAccent)
                        .padding(.horizontal, Metric.s + 2)
                        .padding(.vertical, 5)
                        .background(pal.accent, in: Capsule())
                }
            }
            .padding(Metric.m)
            .background(
                RoundedRectangle(cornerRadius: Metric.cardRadius)
                    .fill(written ? pal.card : pal.accentSoft.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metric.cardRadius)
                    .stroke(written ? pal.line : pal.accent.opacity(0.22), lineWidth: 1)
            )
            .softEdge(RoundedRectangle(cornerRadius: Metric.cardRadius))
            .contentShape(RoundedRectangle(cornerRadius: Metric.cardRadius))
        }
        .buttonStyle(.plain)
    }

    private func statusTitle(written: Bool, streak: Int) -> String {
        if written {
            return streak > 0
                ? String(localized: "Day \(streak) streak · written today")
                : String(localized: "Written today")
        }
        return streak > 0
            ? String(localized: "Day \(streak) streak — keep it alive")
            : String(localized: "Write your first page today")
    }

    // MARK: 特性入口卡（图标徽章 + 名称，暗金点缀引导点击）

    private func featureButton(icon: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Metric.s) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(pal.accent)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [pal.accentSoft, pal.accentSoft.opacity(0.5)],
                                           startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(Circle().strokeBorder(pal.accent.opacity(0.18), lineWidth: 1))
                Text(label)
                    .font(.dCaption.weight(.semibold))
                    .foregroundStyle(pal.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Metric.s)
            .padding(.horizontal, Metric.s)
            .background(
                RoundedRectangle(cornerRadius: Metric.cardRadius).fill(pal.card)
            )
            .softEdge(RoundedRectangle(cornerRadius: Metric.cardRadius))
            .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
        }
        .buttonStyle(FeatureButtonStyle())
    }

    // MARK: 搜索栏

    private var searchBar: some View {
        HStack(spacing: Metric.s) {
            Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundStyle(pal.inkSoft)
            TextField("Search text, transcripts, places, dates…", text: $search)
                .font(.dSubhead)
                .focused($searchFocused)
                .submitLabel(.search)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(pal.inkSoft.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, Metric.m)
        .padding(.vertical, Metric.s + 2)
        .diaryCard(radius: 12, elevation: 0.5)
        .padding(.horizontal, Metric.l)
    }

    // MARK: 空状态（一条数据都没有）

    // MARK: 目录页手势提示（仅「只有欢迎页」这一刻出现，教左右滑翻页 + 长按编辑删除）

    /// 仅当本机只剩内置欢迎页一篇、且用户还没收起时出现。
    private var showGestureHint: Bool { !gestureHintDone && entries.count == 1 }

    private var gestureHint: some View {
        HStack(spacing: Metric.s) {
            Text("← → Swipe to flip pages · Long-press to edit")
                .font(.dCaption)
                .foregroundStyle(pal.inkSoft)
            Spacer(minLength: Metric.s)
            Button {
                withAnimation { gestureHintDone = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(pal.inkSoft.opacity(0.7))
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.leading, Metric.m)
        .padding(.trailing, Metric.xs)
        .padding(.vertical, Metric.xs)
        .background(pal.card.opacity(0.6), in: Capsule())
        .softEdge(Capsule())
        .padding(.horizontal, Metric.l)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            bookBadge
            Text("No entries yet")
                .font(.dSerifPageTitle)
                .foregroundStyle(pal.ink)
            Text("Tap Write to start typing,\nor Talk to speak your mind.")
                .font(.dSerifReading)
                .foregroundStyle(pal.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 还原设计稿方案A：浅米渐变圆角方块 + 书（尺寸按真机屏宽放大）
    private var bookBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(lightHex: 0xFFFDF6, darkHex: 0x2A2014),
                             Color(lightHex: 0xF3E6C8, darkHex: 0x3A2D18)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 130, height: 130)
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(pal.line, lineWidth: 1)
                )
                .shadow(color: pal.accent.opacity(0.12), radius: 18, y: 8)
            Image(systemName: "book")
                .font(.system(size: 54, weight: .regular))
                .foregroundStyle(pal.accent)
        }
    }

    // MARK: 搜索无结果

    private var noResults: some View {
        VStack(spacing: Metric.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(pal.inkSoft.opacity(0.6))
            Text("No matching entries")
                .font(.dSubhead).foregroundStyle(pal.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 指向右下角胶囊的引导箭头（仅空状态）

    private var arrowGuide: some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.down.right")
                .font(.system(size: 26, weight: .semibold))
            Text("Start here")
                .font(.dFootnote)
        }
        .foregroundStyle(pal.accent.opacity(0.7))
    }

    // MARK: 新建按钮（两段胶囊：Write ┃ Talk）

    private var fab: some View {
        SplitEntryCapsule(
            onWrite: {
                editTarget = nil
                pendingPrompt = nil
                pendingAutoRecord = false
                showEditor = true
            },
            onTalk: {
                editTarget = nil
                pendingPrompt = nil
                pendingAutoRecord = true
                showEditor = true
            }
        )
        .padding(Metric.xl)
    }
}

// MARK: - 日记列表行

private struct DiaryRow: View {
    @Environment(\.palette) private var pal
    let entry: DiaryEntry
    let page: Int
    /// ForEach 创建行时同步传入：`deletedIDs.contains(id) || hiddenIDs.contains(id)`。
    /// 纯 Swift Bool，不碰托管对象，彻底规避 save 后 backing data detach 导致的
    /// `entry.photos`（@Attribute.externalStorage）fatal error。
    let isPendingDelete: Bool

    var body: some View {
        if isPendingDelete || entry.isDeleted { EmptyView() } else {
        VStack(alignment: .leading, spacing: Metric.xs) {
            // meta：日期 · 语音 · 地址 并排在第一行
            HStack(spacing: Metric.xs) {
                Text(dateStr).font(.dCaption).foregroundStyle(pal.inkSoft)
                if let m = entry.memos.first {
                    dot
                    HStack(spacing: 3) {
                        Image(systemName: "mic.fill").font(.system(size: 12))
                        Text(durStr(m.duration))
                    }
                    .font(.dCaption.weight(.semibold))
                    .foregroundStyle(pal.accent)
                }
                if entry.showLocation, !entry.location.isEmpty {
                    dot
                    HStack(spacing: 3) {
                        LocationPin(size: 12, color: pal.accent)
                        Text(entry.location)
                            .lineLimit(1).truncationMode(.tail)
                    }
                    .font(.dCaption)
                    .foregroundStyle(pal.inkSoft)
                }
                Spacer(minLength: 0)
            }
            Text(entry.content)
                .font(entry.resolvedFont.swiftUIFont(size: 17))
                .foregroundStyle(entry.bodyColor(palette: pal))
                .lineLimit(2).multilineTextAlignment(.leading)
                .lineSpacing(2)
            if !entry.photos.isEmpty {
                HStack(spacing: Metric.xs) {
                    ForEach(Array(entry.photos.prefix(3).enumerated()), id: \.offset) { _, photo in
                        if let ui = Thumbnailer.thumbnail(photo, side: 38) {
                            Image(uiImage: ui).resizable().scaledToFill()
                                .frame(width: 38, height: 38)
                                .clipShape(RoundedRectangle(cornerRadius: Metric.thumbRadius))
                        }
                    }
                    if entry.photos.count > 3 {
                        Text("+\(entry.photos.count - 3)")
                            .font(.dCaption).foregroundStyle(pal.inkSoft)
                            .frame(width: 38, height: 38)
                            .background(pal.line, in: RoundedRectangle(cornerRadius: Metric.thumbRadius))
                    }
                }
                .padding(.top, 2)
            }
            // 页码放右下角
            HStack {
                Spacer()
                Text("Entry \(page)")
                    .font(.dLabel)
                    .tracking(1)
                    .foregroundStyle(pal.inkSoft.opacity(0.5))
            }
        }
        .padding(Metric.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .diaryCard()
        }
    }

    private var dot: some View { Text("·").font(.dCaption).foregroundStyle(pal.inkSoft) }
    private var dateStr: String {
        let f = DateFormatter()
        let cal = Calendar.current
        let isSameYear = cal.component(.year, from: entry.date) == cal.component(.year, from: Date())
        f.dateFormat = isSameYear ? "MM/dd" : "yyyy/MM/dd"
        return f.string(from: entry.date)
    }
    private func durStr(_ d: Double) -> String { String(format: "%d:%02d", Int(d) / 60, Int(d) % 60) }
}

// MARK: - 特性入口按钮按压反馈（轻微缩放 + 压暗，强化「可点」感）

private struct FeatureButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Previews

#if DEBUG
struct DiaryListView_Previews: PreviewProvider {
    static var previews: some View {
        let container = PreviewHelper.container()
        Group {
            PreviewWrapper(container: container) { DiaryListView() }
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("SE")

            PreviewWrapper(container: container) { DiaryListView() }
                .previewDevice("iPhone 16 Pro")
                .previewDisplayName("16 Pro")

            PreviewWrapper(container: container) { DiaryListView() }
                .previewDevice("iPhone 16 Pro Max")
                .previewDisplayName("Pro Max")

            PreviewWrapper(container: container) { DiaryListView() }
                .previewDevice("iPad (10th generation)")
                .previewDisplayName("iPad 10")
        }
    }
}
#endif
