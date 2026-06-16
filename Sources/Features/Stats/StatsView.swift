import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]

    private var streak: Int { DataManager.currentStreak(entries) }
    private var totalCount: Int { entries.count }
    private var voiceCount: Int { entries.filter { !($0.voiceMemos?.isEmpty ?? true) }.count }
    private var thisMonthCount: Int {
        let cal = Calendar.current
        return entries.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                pal.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Metric.l) {
                        summaryGrid
                        calendarHeatmap
                        voiceRatio
                    }
                    .padding(Metric.l)
                }
            }
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(pal.accent)
                }
            }
        }
    }

    // MARK: 数字汇总

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Metric.m) {
            statCard(value: "\(streak)", label: "连续天数", icon: "flame.fill", color: .orange)
            statCard(value: "\(totalCount)", label: "总篇数", icon: "book.fill", color: pal.accent)
            statCard(value: "\(thisMonthCount)", label: "本月篇数", icon: "calendar", color: pal.accent)
            statCard(value: voiceRatioString, label: "语音日记", icon: "mic.fill", color: pal.accent)
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: Metric.s) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
            Text(value).font(.system(size: 32, weight: .bold)).foregroundStyle(pal.ink)
            Text(label).font(.dCaption).foregroundStyle(pal.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(Metric.l)
        .background(pal.card, in: RoundedRectangle(cornerRadius: Metric.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(pal.line, lineWidth: 1))
    }

    // MARK: 日历热力图（近 35 天）

    private var calendarHeatmap: some View {
        VStack(alignment: .leading, spacing: Metric.m) {
            Text("最近记录").font(.dCallout).foregroundStyle(pal.ink)

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
        .background(pal.card, in: RoundedRectangle(cornerRadius: Metric.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(pal.line, lineWidth: 1))
    }

    // MARK: 语音比例条

    private var voiceRatio: some View {
        VStack(alignment: .leading, spacing: Metric.s) {
            Text("语音 vs 纯文字").font(.dCallout).foregroundStyle(pal.ink)
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
                Text("语音 \(voiceCount) 篇").font(.dCaption).foregroundStyle(pal.inkSoft)
                Spacer()
                Circle().fill(pal.line).frame(width: 8, height: 8)
                Text("纯文字 \(totalCount - voiceCount) 篇").font(.dCaption).foregroundStyle(pal.inkSoft)
            }
        }
        .padding(Metric.m)
        .background(pal.card, in: RoundedRectangle(cornerRadius: Metric.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(pal.line, lineWidth: 1))
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
