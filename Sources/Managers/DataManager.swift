import Foundation
import SwiftData
import SwiftUI

/// 每日提问：按当天日期确定性地选一条，降低「对着空白页」的门槛、引导用户开口说。
/// 同一天打开多次是同一条，每天自动换。语料走口语化、温柔，适合「对它说话」回答。
enum DailyPrompt {
    static let all: [String] = [
        String(localized: "What small thing made you smile today?"),
        String(localized: "What color is your mood right now?"),
        String(localized: "Who said something kind to you today?"),
        String(localized: "If one word could describe today, what would it be?"),
        String(localized: "Is anything weighing on you today? Say it out loud."),
        String(localized: "What's something you're looking forward to lately?"),
        String(localized: "Are you happy with yourself today? In what way?"),
        String(localized: "What would you say to yourself a year from now?"),
        String(localized: "Tired today? What took the most out of you?"),
        String(localized: "What sounds are around you right now? Describe them to the book."),
        String(localized: "Who left the strongest impression on you today?"),
        String(localized: "Is there a small thing you actually did well?"),
        String(localized: "Who are you most grateful for today?"),
        String(localized: "If you could redo one moment today, which would it be?"),
        String(localized: "What do you want most right now?"),
        String(localized: "How does your body feel today?"),
        String(localized: "What's been bothering you lately? Saying it helps."),
        String(localized: "Any new discovery or idea that popped up today?"),
        String(localized: "Where do you most want to be right now?"),
        String(localized: "Did you do something kind for yourself today?"),
    ]

    static func today(_ date: Date = Date()) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[((day % all.count) + all.count) % all.count]
    }
}

/// 连续记录保护（streak saver）：漏写一天不归零，每月最多兜底 2 天。
/// 漏写的那天会被「记一笔」进 UserDefaults，currentStreak 计数时把它视同在轨，
/// 从而跨过单日中断。每月配额独立计算（按年-月键），自然重置。
enum StreakSaver {
    static let monthlyAllowance = 2

    private static let datesKey = "streakSaverDates"
    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func savedDates() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: datesKey) ?? [])
    }
    static func isSaved(_ date: Date) -> Bool {
        savedDates().contains(fmt.string(from: date))
    }
    /// 本月已用保护次数（按当前日历的年-月比对）。
    static func usedThisMonth() -> Int {
        let cal = Calendar.current
        let now = cal.dateComponents([.year, .month], from: Date())
        return savedDates().reduce(0) { count, s in
            guard let d = fmt.date(from: s) else { return count }
            let c = cal.dateComponents([.year, .month], from: d)
            return (c.year == now.year && c.month == now.month) ? count + 1 : count
        }
    }
    static func leftThisMonth() -> Int {
        max(0, monthlyAllowance - usedThisMonth())
    }
    /// 记一个兜底日。幂等：已存在则不重复扣减。
    static func save(_ date: Date) {
        let key = fmt.string(from: date)
        var set = savedDates()
        guard !set.contains(key) else { return }
        set.insert(key)
        UserDefaults.standard.set(Array(set), forKey: datesKey)
    }
}

enum DataManager {
    /// 连续记录天数：从今天（或昨天）起向前数有日记的连续天数；
    /// 途中的「保护日」（StreakSaver）视同在轨，跨过单日中断不归零。
    static func currentStreak(_ entries: [DiaryEntry]) -> Int {
        let cal = Calendar.current
        let daySet = Set(entries.map { cal.startOfDay(for: $0.date) })
        guard !daySet.isEmpty else { return 0 }
        let today = cal.startOfDay(for: Date())
        var cursor: Date
        if daySet.contains(today) {
            cursor = today
        } else if let y = cal.date(byAdding: .day, value: -1, to: today), daySet.contains(y) {
            cursor = y
        } else if let y = cal.date(byAdding: .day, value: -1, to: today), StreakSaver.isSaved(y) {
            // 今天还没写、昨天也没写但昨天被兜底了 → 从昨天接着数。
            cursor = y
        } else {
            return 0
        }
        var streak = 0
        while daySet.contains(cursor) || StreakSaver.isSaved(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// 进入前台时调用：若昨天漏写、前天在轨（写了或已被兜底），且本月还有保护次数，
    /// 就自动为昨天补一个「连续记录保护」，避免单日中断归零。幂等，可重复调用。
    static func reconcileSaver(_ entries: [DiaryEntry]) {
        let cal = Calendar.current
        let daySet = Set(entries.map { cal.startOfDay(for: $0.date) })
        let today = cal.startOfDay(for: Date())
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today),
              let dayBefore = cal.date(byAdding: .day, value: -2, to: today) else { return }
        guard !daySet.contains(yesterday) else { return }      // 昨天写了 → 不用兜
        guard !StreakSaver.isSaved(yesterday) else { return }  // 已兜过 → 不重复
        // 前天在轨（写了或已被兜底）→ 这是可补救的单日中断；否则 streak 早已断，兜底无意义。
        guard daySet.contains(dayBefore) || StreakSaver.isSaved(dayBefore) else { return }
        guard StreakSaver.leftThisMonth() > 0 else { return }
        StreakSaver.save(yesterday)
    }

    /// 温柔版 streak 的一组数字：当前连续、历史最长、今天是否已记录、本月剩余保护次数。
    /// 「最长」即使当前连续断了也保留——努力不清零，不羞辱用户。
    struct StreakStats {
        var current: Int
        var longest: Int
        var recordedToday: Bool
        var saversLeft: Int
    }

    static func streakStats(_ entries: [DiaryEntry]) -> StreakStats {
        let cal = Calendar.current
        let days = Set(entries.map { cal.startOfDay(for: $0.date) }).sorted()
        var longest = 0
        var run = 0
        var prev: Date?
        for day in days {
            if let p = prev, let next = cal.date(byAdding: .day, value: 1, to: p), next == day {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            prev = day
        }
        let today = cal.startOfDay(for: Date())
        return StreakStats(current: currentStreak(entries),
                           longest: longest,
                           recordedToday: days.contains(today),
                           saversLeft: StreakSaver.leftThisMonth())
    }

#if DEBUG
    /// DEBUG：launch 传 `-seedDemo 1` 时清库并灌入演示数据，方便对照设计稿。
    @MainActor
    static func seedDemoIfNeeded(_ context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "seedDemo") else { return }
        if let existing = try? context.fetch(FetchDescriptor<DiaryEntry>()) {
            existing.forEach { context.delete($0) }
        }
        let cal = Calendar.current
        let now = Date()
        func day(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: now) ?? now }
        let p1 = demoPhoto([0xF0C896, 0xC8763A])
        let p2 = demoPhoto([0xBFD8C8, 0x6B8F7A])
        let p3 = demoPhoto([0xE8D2B0, 0xC8A87A])

        // (距今天数, 心情, 内容, 地点, 配图, 语音[时长,转写])
        let items: [(Int, String, String, String, [Data], (Double, String)?)] = [
            (0, "😊", "今天去公园散步，拍了几张照片，心情也跟着明朗起来了。傍晚的风很舒服，坐在湖边发了会儿呆。", "上海 · 人民公园", [p1, p2], (12, "今天去公园散步，心情很好。")),
            (1, "😴", "加班到很晚，但终于把那个拖了一周的项目收尾了，松了一口气。", "公司", [], nil),
            (2, "🥳", "和好久不见的朋友聚会，吃了好吃的火锅，聊到深夜，太开心了～", "成都 · 春熙路", [p3], (30, "和朋友吃火锅，很开心。")),
            (3, "🌧", "下雨天，哪也没去，在家泡了壶茶看了一整天书，难得的安静。", "家", [], nil),
            (5, "✨", "学会了一道新菜，糖醋排骨，家里人都说好吃，很有成就感。", "家", [p1, p3], nil),
            (7, "😢", "有点想念远方的朋友了，翻了翻以前的合照，时间过得真快。", "", [], nil),
        ]
        for (d, emoji, content, loc, photos, voice) in items {
            let e = DiaryEntry(content: content, date: day(d), location: loc,
                               showLocation: !loc.isEmpty, emoji: emoji, photos: photos)
            context.insert(e)
            if let (dur, text) = voice {
                let memo = VoiceMemo(duration: dur, transcript: text, createdAt: day(d))
                memo.entry = e
                context.insert(memo)
            }
        }
        try? context.save()
    }

    private static func demoPhoto(_ hexes: [UInt]) -> Data {
        let size = CGSize(width: 240, height: 240)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = hexes.map { UIColor(Color(hex: $0)).cgColor }
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors as CFArray, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(grad, start: .zero,
                                             end: CGPoint(x: size.width, y: size.height), options: [])
        }
        return img.pngData() ?? Data()
    }
#endif

    // MARK: PDF 导出 HTML

    static func exportHTML(entries: [DiaryEntry]) -> String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy/MM/dd  EEE"

        let rows = entries.enumerated().map { idx, e -> String in
            let dateStr   = fmt.string(from: e.date)
            let page      = String(localized: "Page \(idx + 1)")
            let content   = e.content.isEmpty ? String(localized: "(voice only)") : String(e.content.prefix(80))
            let locStr    = e.showLocation && !e.location.isEmpty
                ? "<div class='loc'>📍 \(esc(e.location))</div>"
                : ""
            let voiceMemo = e.memos.first
            let badge     = voiceMemo != nil
                ? "<span class='badge'>🎙 \(durStr(voiceMemo!.duration))</span>"
                : ""
            return """
            <tr>
              <td class="col-date">\(esc(dateStr))</td>
              <td class="col-content"><div class="preview">\(esc(content))</div>\(badge)\(locStr)</td>
              <td class="col-page">\(page)</td>
            </tr>
            """
        }.joined()

        let total = entries.count
        let dates: String = {
            guard let first = entries.last?.date, let last = entries.first?.date else { return "" }
            let f = DateFormatter(); f.dateStyle = .long; f.locale = .autoupdatingCurrent
            return "\(f.string(from: first)) — \(f.string(from: last))"
        }()

        return """
        <!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8">
        <style>
        *{box-sizing:border-box;margin:0;padding:0;-webkit-print-color-adjust:exact;print-color-adjust:exact}
        @page{size:A4;margin:0}
        body{font-family:-apple-system,"PingFang SC",sans-serif;background:#D9CDB8;padding:32px 0 64px}
        /* 导出 PDF 时去掉屏幕预览的灰底/页边距/阴影，让每页边到边、分页不被顶歪 */
        @media print{
          body{background:#fff;padding:0}
          .page{margin:0 auto;box-shadow:none}
        }
        .page{width:794px;min-height:1123px;margin:0 auto 28px;box-shadow:0 4px 20px rgba(0,0,0,.18);page-break-after:always}
        /* 封面 */
        .cover{background:linear-gradient(135deg,#5C3D1E,#3A2210);display:flex;flex-direction:column;align-items:center;justify-content:center;padding:80px;min-height:1123px}
        .cover hr{width:100%;border:none;border-top:1px solid rgba(200,150,12,.3);margin:28px 0}
        .cover-title{font-size:52px;font-weight:700;color:#C8960C;letter-spacing:14px}
        .cover-sub{font-size:18px;font-weight:600;color:rgba(200,150,12,.6);letter-spacing:5px;margin-top:12px}
        .cover-slogan{font-size:13px;color:rgba(200,150,12,.4);letter-spacing:3px;margin-top:8px}
        .cover-meta{margin-top:40px;font-size:14px;color:rgba(200,150,12,.5);line-height:2.2;text-align:center;letter-spacing:1px}
        /* 列表页 */
        .list-page{background:#F5EBD5;padding:64px 72px}
        .list-header{display:flex;justify-content:space-between;align-items:baseline;padding-bottom:14px;border-bottom:1.5px solid #C8960C;margin-bottom:32px}
        .list-header-title{font-size:13px;font-weight:600;color:#7A6A55;letter-spacing:2px}
        .list-header-count{font-size:12px;color:#7A6A55;opacity:.6}
        table{width:100%;border-collapse:collapse}
        thead th{font-size:11px;font-weight:600;color:#7A6A55;letter-spacing:1.5px;text-align:left;padding:0 0 10px;border-bottom:1px solid #E0D0B0}
        thead th.col-page{text-align:right}
        tbody tr{border-bottom:1px solid #EDE0C8}
        tbody tr:last-child{border-bottom:none}
        tbody td{padding:14px 0;vertical-align:top;font-size:13px;color:#221A0E}
        .col-date{width:130px;color:#7A6A55;font-size:12px;white-space:pre-wrap;padding-right:16px}
        .col-content{color:#221A0E;line-height:1.5}
        .preview{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
        .badge{display:inline-block;font-size:10px;font-weight:600;color:#C8960C;background:rgba(200,150,12,.08);border:1px solid rgba(200,150,12,.25);border-radius:100px;padding:1px 7px;margin-top:4px}
        .loc{font-size:11px;color:#7A6A55;margin-top:4px}
        .col-page{width:60px;text-align:right;font-size:11px;color:#7A6A55;opacity:.5;padding-left:8px;white-space:nowrap}
        .footer{margin-top:48px;text-align:center;font-size:11px;color:#7A6A55;opacity:.5;letter-spacing:1px}
        </style></head><body>
        <div class="page cover">
          <hr>
          <div class="cover-title">我 的 日 记</div>
          <div class="cover-sub">VOICEPAPER</div>
          <div class="cover-slogan">翻开本子，对它说话</div>
          <hr>
          <div class="cover-meta">\(esc(dates))<br>共 \(total) 篇</div>
        </div>
        <div class="page list-page">
          <div class="list-header">
            <span class="list-header-title">日 记 列 表</span>
            <span class="list-header-count">共 \(total) 篇</span>
          </div>
          <table>
            <thead><tr>
              <th class="col-date">日期</th>
              <th class="col-content">内容摘要</th>
              <th class="col-page">页码</th>
            </tr></thead>
            <tbody>\(rows)</tbody>
          </table>
          <div class="footer">由 VoicePaper 导出 · 翻开本子，对它说话</div>
        </div>
        </body></html>
        """
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func durStr(_ d: Double) -> String {
        String(format: "%d:%02d", Int(d) / 60, Int(d) % 60)
    }
}
