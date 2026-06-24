import SwiftUI
import SwiftData

struct DiaryListView: View {
    @Environment(\.palette) private var pal
    @Environment(\.bookNavigator) private var navigator
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]
    @State private var search = ""
    @State private var showSearch = false
    @FocusState private var searchFocused: Bool
    @State private var showEditor = false
    /// 从「今日状态条」进编辑器时携带的 prompt；FAB 进则置 nil。
    @State private var pendingPrompt: String? = nil
    @State private var showInsights = false
    @State private var showPrompts = false
    @State private var showStats = false

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

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PaperBackground()

            VStack(spacing: Metric.m) {
                header
                if showSearch {
                    searchBar
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if entries.isEmpty || filtered.isEmpty {
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Metric.m) {
                            ForEach(filtered, id: \.id) { entry in
                                let gi = entries.firstIndex { $0.id == entry.id } ?? 0
                                let page = gi + 1
                                Button {
                                    navigator.goToEntry(at: gi)
                                } label: {
                                    DiaryRow(entry: entry, page: page)
                                }
                                .buttonStyle(.plain)
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
        .dimmedSheet(isPresented: $showEditor) { AddDiaryView(initialPrompt: pendingPrompt) }
        .dimmedSheet(isPresented: $showInsights) { InsightsView() }
        .dimmedSheet(isPresented: $showPrompts) { PromptsView() }
        .dimmedSheet(isPresented: $showStats) { StatsView() }
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

    private var emptyState: some View {
        VStack(spacing: 20) {
            bookBadge
            Text("No entries yet")
                .font(.dSerifPageTitle)
                .foregroundStyle(pal.ink)
            Text("Tap ＋ in the corner\nto write today — or record your voice.")
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

    // MARK: 指向 + 的引导（仅空状态）

    private var arrowGuide: some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.down.right")
                .font(.system(size: 26, weight: .semibold))
            Text("Start here")
                .font(.dFootnote)
        }
        .foregroundStyle(pal.accent.opacity(0.7))
    }

    // MARK: 新建按钮（传统圆形 FAB）

    private var fab: some View {
        AddEntryFAB { pendingPrompt = nil; showEditor = true }
            .padding(Metric.xl)
    }
}

// MARK: - 日记列表行

private struct DiaryRow: View {
    @Environment(\.palette) private var pal
    let entry: DiaryEntry
    let page: Int

    var body: some View {
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
                    ForEach(entry.photos.prefix(3).indices, id: \.self) { i in
                        if let ui = Thumbnailer.thumbnail(entry.photos[i], side: 38) {
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
                Text("Page \(page)")
                    .font(.dLabel)
                    .tracking(1)
                    .foregroundStyle(pal.inkSoft.opacity(0.5))
            }
        }
        .padding(Metric.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .diaryCard()
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
