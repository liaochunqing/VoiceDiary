import SwiftUI
import SwiftData

/// 统计页：连续记录 / 数字汇总 / 热力图 / 语音比例。纯数字，端侧计算。
/// 情绪/趋势/关键词/AI 小结在独立的「洞察」页（InsightsView）。
struct StatsView: View {
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]

    private var stats: DataManager.StreakStats { DataManager.streakStats(entries) }
    private var totalCount: Int { entries.count }
    private var voiceCount: Int { entries.filter { !($0.voiceMemos?.isEmpty ?? true) }.count }
    private var thisMonthCount: Int {
        let cal = Calendar.current
        return entries.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }.count
    }
    private var totalWords: Int { entries.reduce(0) { $0 + $1.content.count } }
    private var recordedDays: Int {
        let cal = Calendar.current
        return Set(entries.map { cal.startOfDay(for: $0.date) }).count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(spacing: Metric.l) {
                        streakHeader
                        summaryGrid
                        calendarHeatmap
                        voiceRatio
                    }
                    .padding(Metric.l)
                    .readableColumn()
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(pal.accent)
                }
            }
        }
    }

    // MARK: 连续记录头卡（温柔版 streak）

    private var streakHeader: some View {
        let s = stats
        return VStack(spacing: Metric.s) {
            Text(s.current >= 1 ? "🔥" : "🌱")
                .font(.system(size: 40))
            Text("\(s.current)")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(pal.ink)
            Text(streakHeadline(s))
                .font(.dSubhead)
                .foregroundStyle(pal.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Metric.l)
        .diaryCard()
    }

    private func streakHeadline(_ s: DataManager.StreakStats) -> String {
        if s.current == 0 {
            return s.longest > 0
                ? String(localized: "Start today and build it back up")
                : String(localized: "Write your first entry to start a streak")
        }
        if s.recordedToday {
            return String(localized: "On a streak — keep it going 🎉")
        }
        return String(localized: "Nothing logged today — don't break the chain")
    }

    // MARK: 数字汇总

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Metric.m) {
            statCard(value: "\(stats.longest)", label: "Longest streak", icon: "trophy.fill", color: .orange)
            statCard(value: "\(totalCount)", label: "Total entries", icon: "book.fill", color: pal.accent)
            statCard(value: "\(thisMonthCount)", label: "This month", icon: "calendar", color: pal.accent)
            statCard(value: voiceRatioString, label: "Voice entries", icon: "mic.fill", color: pal.accent)
            statCard(value: "\(totalWords)", label: "Total words", icon: "textformat", color: pal.accent)
            statCard(value: "\(recordedDays)", label: "Days logged", icon: "checkmark.seal.fill", color: pal.accent)
        }
    }

    private func statCard(value: String, label: LocalizedStringKey, icon: String, color: Color) -> some View {
        VStack(spacing: Metric.s) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
            Text(value).font(.system(size: 32, weight: .bold)).foregroundStyle(pal.ink)
            Text(label).font(.dCaption).foregroundStyle(pal.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(Metric.l)
        .diaryCard()
    }

    // MARK: 日历热力图（近 35 天）

    private var calendarHeatmap: some View {
        VStack(alignment: .leading, spacing: Metric.m) {
            Text("Recent activity").font(.dSerifSubhead.weight(.semibold)).foregroundStyle(pal.ink)

            let days = last35Days()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let hasEntry = entryExists(on: day)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hasEntry ? pal.accent : pal.line.opacity(0.4))
                        .frame(height: 28)
                        .overlay(
                            Text(dayLabel(day))
                                .font(.system(size: 8))
                                .foregroundStyle(hasEntry ? pal.onAccent : pal.inkSoft)
                        )
                }
            }
        }
        .padding(Metric.m)
        .diaryCard()
    }

    // MARK: 语音比例条

    private var voiceRatio: some View {
        VStack(alignment: .leading, spacing: Metric.s) {
            Text("Voice vs. Text").font(.dSerifSubhead.weight(.semibold)).foregroundStyle(pal.ink)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(pal.line.opacity(0.4))
                    if totalCount > 0 {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(pal.accent)
                            .frame(width: geo.size.width * CGFloat(voiceCount) / CGFloat(totalCount))
                    }
                }
                .frame(height: 12)
            }
            .frame(height: 12)
            HStack {
                Circle().fill(pal.accent).frame(width: 8, height: 8)
                Text("Voice \(voiceCount)").font(.dCaption).foregroundStyle(pal.inkSoft)
                Spacer()
                Circle().fill(pal.line).frame(width: 8, height: 8)
                Text("Text \(totalCount - voiceCount)").font(.dCaption).foregroundStyle(pal.inkSoft)
            }
        }
        .padding(Metric.m)
        .diaryCard()
    }

    // MARK: 工具

    private var voiceRatioString: String {
        guard totalCount > 0 else { return "0%" }
        return "\(Int(Double(voiceCount) / Double(totalCount) * 100))%"
    }

    private func last35Days() -> [Date] {
        let cal = Calendar.current
        return (0..<35).compactMap { cal.date(byAdding: .day, value: -34 + $0, to: Date()) }
            .map { cal.startOfDay(for: $0) }
    }

    private func entryExists(on day: Date) -> Bool {
        let cal = Calendar.current
        return entries.contains { cal.isDate($0.date, inSameDayAs: day) }
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }
}
