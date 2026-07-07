import SwiftUI
import SwiftData

#if DEBUG
/// 预览专用：构建内存 ModelContainer，塞入示例日记数据。
/// 各 View 的 #Preview 可共享此 helper，避免重复代码。
enum PreviewHelper {
    /// 带示例数据的 in-memory 容器。含 6 篇不同心情/长度的日记。
    @MainActor
    static func container() -> ModelContainer {
        let schema = Schema([DiaryEntry.self, VoiceMemo.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext
        seedSampleEntries(into: ctx)
        return container
    }

    /// 空容器（用于需要 modelContext 但不关心数据的页面，如编辑器新建）。
    @MainActor
    static func emptyContainer() -> ModelContainer {
        let schema = Schema([DiaryEntry.self, VoiceMemo.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }

    /// 创建单篇示例日记（供 Detail 等需要具体 entry 的页面）。
    @MainActor
    static func sampleEntry() -> DiaryEntry {
        let e = DiaryEntry(
            content: "今天是个好日子，阳光洒在窗台上，我泡了一杯热茶，坐在书桌前翻开这本日记。\n\n最近在读一本关于创造力的书，里面说写日记是最好的思维整理方式。我觉得很有道理——把脑子里的想法倒出来，就像收拾房间一样，整个人都会清爽很多。\n\n傍晚去跑了步，耳机里放着 lo-fi，整个世界都慢下来了。",
            date: Date(),
            location: "上海 · 武康路",
            showLocation: true,
            emoji: "😊"
        )
        let memo = VoiceMemo(duration: 15, transcript: "今天心情很好，写了很多东西。", createdAt: Date())
        memo.entry = e
        return e
    }

    // MARK: - Private

    @MainActor
    private static func seedSampleEntries(into ctx: ModelContext) {
        let cal = Calendar.current
        let now = Date()
        func day(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: now) ?? now }

        let items: [(Int, String, String, String)] = [
            (0, "😊", "今天去公园散步，拍了几张照片，心情也跟着明朗起来了。傍晚的风很舒服，坐在湖边发了会儿呆。最近工作不算太忙，终于有时间好好享受生活。\n\n晚上回家做了番茄牛腩，炖了两个小时，整个厨房都是香味。", "上海 · 人民公园"),
            (1, "😴", "加班到很晚，但终于把那个拖了一周的项目收尾了，松了一口气。回家的路上买了杯热巧克力，甜的东西总能治愈疲惫。\n\n躺在床上刷了会儿手机，看到一个视频说「人生没有白走的路」，突然觉得最近的努力都值得。", "公司"),
            (2, "🥳", "和好久不见的朋友聚会，吃了好吃的火锅，聊到深夜，太开心了～大家各自忙碌却还能聚在一起，这种感觉真好。\n\n朋友说他年底要结婚了，时间过得真快啊。", "成都 · 春熙路"),
            (3, "🌧", "下雨天，哪也没去，在家泡了壶茶看了一整天书，难得的安静。雨点打在窗户上，滴滴答答的，像一首催眠曲。\n\n读完了村上春树的《挪威的森林》，结尾有点伤感。", "家"),
            (5, "✨", "学会了一道新菜，糖醋排骨，家里人都说好吃，很有成就感。做饭这件事，越做越上瘾。\n\n下次想试试做红烧肉。", "家"),
            (7, "😢", "有点想念远方的朋友了，翻了翻以前的合照，时间过得真快。那些一起度过的日子，回想起来都是温暖的。\n\n给朋友发了条消息，他说他也想我了。", ""),
        ]
        for (d, emoji, content, location) in items {
            let e = DiaryEntry(content: content, date: day(d), location: location,
                               showLocation: !location.isEmpty, emoji: emoji)
            ctx.insert(e)
            // 给部分条目加语音备忘
            if d == 0 || d == 2 {
                let memo = VoiceMemo(
                    duration: d == 0 ? 12 : 30,
                    transcript: d == 0 ? "今天去公园散步，心情很好。" : "和朋友吃火锅，很开心。",
                    createdAt: day(d)
                )
                memo.entry = e
                ctx.insert(memo)
            }
        }
        try? ctx.save()
    }
}

// MARK: - 设备常量

/// 预览用的代表设备列表（覆盖主流尺寸族，跳过小众设备）。
enum PreviewDevices {
    /// iPhone SE 3rd — 小屏 375×667，价格敏感用户群
    static let se = PreviewDevice(rawValue: "iPhone SE (3rd generation)")
    /// iPhone 16 Pro — 标准屏 393×852，最主流尺寸
    static let standard = PreviewDevice(rawValue: "iPhone 16 Pro")
    /// iPhone 16 Pro Max — 大屏 430×932，Pro 用户
    static let large = PreviewDevice(rawValue: "iPhone 16 Pro Max")
    /// iPad 10th gen — 10.9" 占比 ~70% 活跃 iPad（TelemetryDeck 2026）
    static let ipad = PreviewDevice(rawValue: "iPad (10th generation)")
}

/// 用于包覆在 preview content 外层的通用 modifier：
/// 注入 palette + bookNavigator + modelContainer（避免每个 preview 重复写）。
struct PreviewWrapper<Content: View>: View {
    let content: Content
    let container: ModelContainer
    let palette: DiaryPalette

    init(
        palette: DiaryPalette = .darkGold,
        container: ModelContainer? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.palette = palette
        self.container = container ?? PreviewHelper.emptyContainer()
        self.content = content()
    }

    var body: some View {
        content
            .modelContainer(container)
            .environment(ThemeManager())
            .environment(DeletionCoordinator())
            .environment(\.palette, palette)
            .environment(\.bookNavigator, BookNavigator())
    }
}
#endif
