import SwiftUI
import SwiftData
import Charts

/// 洞察页：情绪头卡 / 趋势曲线 / 关键词云（免费）+ AI 周小结（Pro）。
/// 端侧实时计算，内容不出设备。纯数字统计在独立的「统计」页（StatsView）。
struct InsightsView: View {
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]
    @State private var purchaseManager = PurchaseManager.shared

    @State private var analysis = Analysis()
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(spacing: Metric.l) {
                        moodHeader
                        if !analysis.trend.isEmpty { trendCard }
                        if !analysis.keywords.isEmpty { keywordCard }
                        aiSummaryCard
                    }
                    .padding(Metric.l)
                    .readableColumn()
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(pal.accent)
                }
            }
        }
        .dimmedSheet(isPresented: $showPaywall) {
            PaywallView(feature: .insights)
        }
        .task(id: entries.count) { recomputeAnalysis() }
    }

    // MARK: 本周情绪头卡（免费 · NaturalLanguage）

    private var moodHeader: some View {
        HStack(spacing: Metric.l) {
            Text(moodEmoji).font(.system(size: 48))
            VStack(alignment: .leading, spacing: 4) {
                Text(moodTitle).font(.dSerifHeadline).foregroundStyle(pal.ink)
                Text(moodSubtitle)
                    .font(.dCaption).foregroundStyle(pal.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metric.l)
        .diaryCard()
    }

    private var moodEmoji: String {
        guard let m = analysis.weekMood else { return "🌱" }
        if m > 0.15 { return "☀️" }
        if m < -0.15 { return "🌧️" }
        return "⛅️"
    }

    private var moodTitle: String {
        guard let m = analysis.weekMood else { return String(localized: "Start writing to read your mood") }
        if m > 0.15 { return String(localized: "A warmer week") }
        if m < -0.15 { return String(localized: "A heavier week") }
        return String(localized: "A steady week")
    }

    private var moodSubtitle: String {
        guard analysis.weekMood != nil else {
            return String(localized: "Write a few entries and your recent mood will show up here.")
        }
        let n = analysis.weekCount
        if let m = analysis.weekMood, m < -0.15 {
            return String(localized: "\(n) entries in the last 7 days. Mood's been low — you don't have to carry it alone.")
        }
        return String(localized: "\(n) entries in the last 7 days. Keep writing, and your mood will speak for itself.")
    }

    // MARK: 情绪趋势（免费 · Swift Charts）

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: Metric.s) {
            Text("Mood Trend").font(.dSerifSubhead.weight(.semibold)).foregroundStyle(pal.ink)
            Text("A mood score for each entry (−1 low → +1 bright), computed on device in real time")
                .font(.dCaption).foregroundStyle(pal.inkSoft)

            Chart(analysis.trend) { p in
                AreaMark(x: .value("Date", p.date), y: .value("Mood", p.score))
                    .foregroundStyle(
                        LinearGradient(colors: [pal.accent.opacity(0.28), pal.accent.opacity(0)],
                                       startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Date", p.date), y: .value("Mood", p.score))
                    .foregroundStyle(pal.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: -1...1)
            .chartYAxis {
                AxisMarks(values: [-1, 0, 1]) { _ in
                    AxisGridLine().foregroundStyle(pal.line.opacity(0.5))
                }
            }
            .chartXAxis(.hidden)
            .frame(height: 130)
            .padding(.top, Metric.xs)
        }
        .padding(Metric.m)
        .diaryCard()
    }

    // MARK: 关键词云（免费 · NaturalLanguage 名词抽取）

    private var keywordCard: some View {
        VStack(alignment: .leading, spacing: Metric.s) {
            Text("Recently mentioned").font(.dSerifSubhead.weight(.semibold)).foregroundStyle(pal.ink)
            Text("Pulled automatically from your words — nothing is uploaded")
                .font(.dCaption).foregroundStyle(pal.inkSoft)

            FlowLayout(spacing: 9) {
                ForEach(analysis.keywords) { kw in
                    Text(kw.word)
                        .font(keywordFont(kw.count))
                        .foregroundStyle(keywordColor(kw.count))
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .background(pal.card, in: RoundedRectangle(cornerRadius: 11))
                        .softEdge(RoundedRectangle(cornerRadius: 11))
                }
            }
            .padding(.top, Metric.xs)
        }
        .padding(Metric.m)
        .diaryCard()
    }

    private var maxKeywordCount: Int { analysis.keywords.map(\.count).max() ?? 1 }
    // 按词频分 3 档，但都用语义 token（随 Dynamic Type 缩放），不硬编码 size。
    private func keywordFont(_ c: Int) -> Font {
        let r = Double(c) / Double(maxKeywordCount)
        if r > 0.66 { return .dSerifBody.weight(.semibold) }   // 17
        if r > 0.33 { return .dSubhead.weight(.semibold) }     // 15
        return .dCaption.weight(.medium)                       // 12
    }
    private func keywordColor(_ c: Int) -> Color {
        Double(c) / Double(maxKeywordCount) > 0.55 ? pal.accent : pal.inkSoft
    }

    // MARK: 每周回顾（Pro · 端侧模板，未来可升级 Foundation Models）

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: Metric.s) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(pal.accent)
                Text("Weekly Recap").font(.dSerifSubhead.weight(.semibold)).foregroundStyle(pal.ink)
                Text("PRO")
                    .font(.system(size: 10.5, weight: .bold)).foregroundStyle(pal.accent)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(pal.accentSoft, in: RoundedRectangle(cornerRadius: 6))
            }

            if purchaseManager.isUnlocked {
                Text(localSummary)
                    .font(.dSerifBody).foregroundStyle(pal.ink)
                    .lineSpacing(5).fixedSize(horizontal: false, vertical: true)
            } else {
                lockedSummary
            }
        }
        .padding(Metric.m)
        .diaryCard()
    }

    private var lockedSummary: some View {
        ZStack {
            // 模糊展示的是**真实**的本地小结，不是写死的假文案。
            Text(localSummary)
                .font(.dSerifBody).foregroundStyle(pal.ink)
                .lineSpacing(5).blur(radius: 5).opacity(0.5)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: Metric.s) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20)).foregroundStyle(pal.accent)
                    .frame(width: 44, height: 44).background(pal.accentSoft, in: Circle())
                Text("Recap your week at a glance")
                    .font(.dSubhead.weight(.semibold)).foregroundStyle(pal.ink)
                Text("Built from your entries, on device — your words never leave your phone")
                    .font(.dCaption).foregroundStyle(pal.inkSoft)
                    .multilineTextAlignment(.center)
                Button { showPaywall = true } label: {
                    Text("Unlock with Pro")
                        .font(.dSubhead.weight(.semibold)).foregroundStyle(pal.onAccent)
                        .padding(.horizontal, Metric.l).padding(.vertical, Metric.s)
                        .background(pal.accent, in: Capsule())
                }
                .padding(.top, 2)
            }
        }
    }

    /// 每周回顾：基于端侧情绪分 + 关键词的模板小结（非生成式 AI，但全部离线计算）。
    /// 未来可用 iOS 18+ Foundation Models 替换为真生成式小结，此处保持接口不变。
    private var localSummary: String {
        let n = analysis.weekCount
        guard n > 0 else { return String(localized: "No entries this week yet. Open the book and tell it about your day.") }
        let moodWord: String = {
            guard let m = analysis.weekMood else { return String(localized: "calm") }
            if m > 0.15 { return String(localized: "mostly warm") }
            if m < -0.15 { return String(localized: "a little low") }
            return String(localized: "fairly steady")
        }()
        var s = String(localized: "This week you wrote \(n) entries, feeling \(moodWord).")
        let topWords = analysis.keywords.prefix(3).map(\.word)
        if !topWords.isEmpty {
            let joined = topWords.joined(separator: ", ")
            s += " " + String(localized: "You often mentioned \(joined).")
        }
        s += " " + String(localized: "Keep writing — and leave yourself a little room to breathe next week.")
        return s
    }

    // MARK: 分析计算

    struct TrendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let score: Double
    }

    struct Analysis {
        var weekMood: Double? = nil
        var weekCount: Int = 0
        var trend: [TrendPoint] = []
        var keywords: [EmotionAnalyzer.Keyword] = []
    }

    /// 端侧计算：近 30 篇情绪点 + 近 7 天平均情绪 + 关键词。条目不多，开销可忽略。
    private func recomputeAnalysis() {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = Array(entries.prefix(30))

        let points: [TrendPoint] = recent.reversed().compactMap { e in
            guard let s = EmotionAnalyzer.sentiment(for: EmotionAnalyzer.text(of: e)) else { return nil }
            return TrendPoint(date: e.date, score: s)
        }
        let weekScores = points.filter { $0.date >= weekAgo }.map(\.score)
        let weekMood = weekScores.isEmpty ? nil : weekScores.reduce(0, +) / Double(weekScores.count)
        let weekCount = entries.filter { $0.date >= weekAgo }.count
        let kws = EmotionAnalyzer.keywords(from: recent.map { EmotionAnalyzer.text(of: $0) })

        analysis = Analysis(weekMood: weekMood, weekCount: weekCount, trend: points, keywords: kws)
    }
}
