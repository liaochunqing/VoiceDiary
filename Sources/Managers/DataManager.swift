import Foundation
import SwiftData
import SwiftUI

enum DataManager {
    /// 连续记录天数：从今天（或昨天）起向前数有日记的连续天数。
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
        } else {
            return 0
        }
        var streak = 0
        while daySet.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
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
                let memo = VoiceMemo(audio: Data(), duration: dur, transcript: text, createdAt: day(d))
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
}
