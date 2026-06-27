import SwiftData
import SwiftUI

#if DEBUG
/// 截图专用假数据：自然日记 + 语音 + 配图，7天以上 streak，情绪多样化。
/// 英文版通过 launch argument `-screenshotData 1` 触发；中文版由设置页 Debug 按钮显式调用。
/// 两者都会先清空已有数据。
enum ScreenshotSeeder {

    private enum SeedLanguage { case english, chinese }

    /// 在 VoiceDiaryApp.makeContainer() 里调用：检测 launch arg，若开启则灌入英文截图数据。
    @MainActor
    static func seedIfRequested(_ context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "screenshotData") else { return }
        seed(context, language: .english)
    }

    /// 设置页 Debug 按钮：清空并灌入中文截图数据（中文区上架截图用）。
    @MainActor
    static func seedChinese(_ context: ModelContext) {
        seed(context, language: .chinese)
    }

    /// 启动参数 `-screenshotDataZH 1`：自动化截图时灌入中文数据。
    @MainActor
    static func seedChineseIfRequested(_ context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "screenshotDataZH") else { return }
        seed(context, language: .chinese)
    }

    // MARK: - 核心：清空 + 灌入指定语言数据

    @MainActor
    private static func seed(_ context: ModelContext, language: SeedLanguage) {
        // 清空旧数据 + 灌入新数据。
        // 启动时调用：无视图监听，同步安全；设置页调用：已由调用方用 Task 包裹。
        if let existing = try? context.fetch(FetchDescriptor<DiaryEntry>()) {
            for entry in existing {
                for memo in entry.memos {
                    if let aid = memo.audioID {
                        let desc = FetchDescriptor<VoiceAudio>(predicate: #Predicate { $0.id == aid })
                        for a in (try? context.fetch(desc)) ?? [] { context.delete(a) }
                    }
                }
                context.delete(entry)
            }
            try? context.save()
        }

        let cal = Calendar.current
        let now = Date()
        func day(_ d: Int) -> Date {
            cal.date(byAdding: .day, value: -d, to: now) ?? now
        }

        // 生成几张暖色调渐变图当配图
        let p1 = makePhoto([0xE8B87A, 0xD4925A])  // 暖金
        let p2 = makePhoto([0x8FB8A0, 0x5A9068])  // 森林绿
        let p3 = makePhoto([0xD4A0C0, 0xA06088])  // 玫瑰
        let p4 = makePhoto([0xA0B8D8, 0x6080A8])  // 天蓝
        let photos = [p1, p2, p3, p4]

        let items = language == .chinese ? chineseItems(photos) : englishItems(photos)

        for (d, emoji, content, loc, entryPhotos, voiceTranscript) in items {
            let e = DiaryEntry(
                content: content,
                date: day(d),
                location: loc,
                showLocation: !loc.isEmpty,
                emoji: emoji,
                photos: entryPhotos
            )
            context.insert(e)
            if let transcript = voiceTranscript {
                let memo = VoiceMemo(duration: Double.random(in: 15...45),
                                     transcript: transcript,
                                     createdAt: day(d))
                memo.entry = e
                context.insert(memo)
            }
        }
        try? context.save()
    }

    // MARK: - 英文数据集

    /// (距今天数, 心情emoji, 正文, 地点, 配图, 语音转写)
    private static func englishItems(_ p: [Data]) -> [(Int, String, String, String, [Data], String?)] {
        let (p1, p2, p3, p4) = (p[0], p[1], p[2], p[3])
        return [
            (0, "😊",
             """
             Finally finished that book I've been reading for weeks. The ending caught me off guard — not the twist I expected, but the one I needed.

             Sat by the window with a cup of Earl Grey, watched the evening light shift across the room. It's these quiet moments that make me feel most like myself.

             I think the book's main idea will stay with me for a while: "We don't remember days, we remember moments." Kind of why I started this diary in the first place.
             """,
             "Blue Bottle Coffee · San Francisco",
             [p1, p2],
             "Finally finished my book today. The ending was unexpected but beautiful. Sat with tea and watched the sunset."),

            (1, "🌟",
             """
             Aced the presentation I'd been dreading all week. The team actually applauded — I didn't expect that at all.

             All that prep paid off. I woke up at 5am to go through my slides one more time, and I'm so glad I did. One of the senior engineers came up afterwards and said it was the clearest product pitch she'd seen this quarter.

             Treated myself to ramen after work. Sometimes you just need to celebrate the wins, no matter how small.
             """,
             "SoMa · San Francisco",
             [],
             "Aced my presentation today! The team applauded. All the prep work paid off. Treating myself to ramen."),

            (2, "🌿",
             """
             Spent the morning hiking in Muir Woods. The redwoods have this way of making all your problems feel small. There's something almost sacred about standing under trees that have been alive for centuries.

             The trail was quiet — just the sound of birds and my own footsteps on the damp earth. Made it to the top just as the fog was lifting over the valley. Absolutely breathtaking.

             I need to do this more often. Nature is the best therapy.
             """,
             "Muir Woods · California",
             [p3, p4],
             "Went hiking in Muir Woods today. Redwoods make everything feel small in the best way. Fog lifting over the valley was stunning."),

            (3, "💭",
             """
             Can't stop thinking about what Mom said on the phone. She told me she's proud of the person I've become. We don't say things like that enough in our family, so when she did, it hit differently.

             She's been going through her old photo albums and sent me a picture of us at the beach when I was five. I barely remember that day, but she says it was one of her happiest.

             Called her back just to say I love her too. These moments matter more than anything else.
             """,
             "Home",
             [],
             "Talked to Mom today. She said she's proud of me. We don't say things like that enough. Looking at old photos together."),

            (5, "🎨",
             """
             Started a little watercolor project — just for fun, no pressure. I've been wanting to try painting for years but always told myself I wasn't "artistic enough." Today I decided that's nonsense.

             Bought a cheap set of paints and a sketchbook from the art store down the street. Painted the view from my window. It's not great, but it's mine. And honestly? The process was so calming.

             Maybe creativity isn't about being good. Maybe it's just about showing up and letting something out.
             """,
             "Mission District · San Francisco",
             [p1],
             nil),

            (7, "☕️",
             """
             Rainy Sunday. Made pancakes. Read. Didn't look at my phone for six whole hours. I think that's a personal record.

             There's something luxurious about a day with no plans. The rain against the window, the smell of coffee, a book I've been meaning to read for months. No notifications. No urgency.

             I should do this once a week. My brain feels... quieter.
             """,
             "Home",
             [],
             "Rainy Sunday. Pancakes and a book. No phone for six hours. My brain feels quieter. Need more days like this."),

            (8, "✈️",
             """
             Booked the ticket. Tokyo, here I come. I've been saving for this trip for almost two years, and it still doesn't feel real.

             April, cherry blossom season. I've already made a list of every ramen shop, bookstore, and garden I want to visit. My friend Yuki is going to show me around for the first few days.

             This is the first big trip I'm taking completely on my own. A little nervous, mostly excited. Feels like the start of something.
             """,
             "Home · Planning mode",
             [p4],
             nil),
        ]
    }

    // MARK: - 中文数据集

    /// (距今天数, 心情emoji, 正文, 地点, 配图, 语音转写)
    private static func chineseItems(_ p: [Data]) -> [(Int, String, String, String, [Data], String?)] {
        let (p1, p2, p3, p4) = (p[0], p[1], p[2], p[3])
        return [
            (0, "😊",
             """
             终于把读了好几周的那本书看完了。结尾完全出乎意料——不是我猜的那种反转，却是我真正需要的那种。

             坐在窗边，泡了一杯伯爵红茶，看着傍晚的光一点点移过房间。正是这些安静的瞬间，让我觉得最像自己。

             书里有句话大概会跟着我很久：“我们记不住日子，我们记住的是瞬间。”也许这就是我开始写日记的原因。
             """,
             "蓝瓶咖啡 · 上海",
             [p1, p2],
             "今天终于把书读完了。结尾意外又美好。泡了茶，看着夕阳坐了好一会儿。"),

            (1, "🌟",
             """
             搞定了担心了一整周的那场汇报。团队居然鼓掌了——完全没想到。

             所有的准备都值了。早上五点就起来又把幻灯片过了一遍，现在庆幸自己这么做了。结束后一位资深工程师走过来，说这是她这个季度见过最清楚的一次产品讲解。

             下班奖励自己一碗拉面。有时候就是需要给自己的小胜利庆祝一下，不管它多小。
             """,
             "徐汇 · 上海",
             [],
             "今天汇报顺利搞定！团队都鼓掌了。准备没有白费，奖励自己去吃拉面。"),

            (2, "🌿",
             """
             上午去莫干山徒步了一圈。走在大树下，所有的烦恼好像都被衬得很小。站在活了上百年的树底下，有种近乎神圣的感觉。

             山道很安静——只有鸟叫和自己踩在湿润泥土上的脚步声。爬到山顶时，雾正好从山谷里散开，美得让人屏息。

             我得多来几次。大自然才是最好的疗愈。
             """,
             "莫干山 · 浙江",
             [p3, p4],
             "今天去莫干山徒步。大树让人觉得烦恼都很小。山顶的雾散开那一刻太美了。"),

            (3, "💭",
             """
             一直在想妈妈在电话里说的那句话。她说，为我现在成为的样子感到骄傲。我们家很少把这种话说出口，所以她说的时候，分量格外不一样。

             她最近在翻旧相册，发给我一张我五岁时在海边的照片。那天我几乎不记得了，她却说那是她最开心的日子之一。

             我又打回去，只为了告诉她我也爱她。这些瞬间，比什么都重要。
             """,
             "家",
             [],
             "今天和妈妈通了电话。她说为我骄傲。我们平时太少说这种话了。一起看了好多老照片。"),

            (5, "🎨",
             """
             开始随便画点水彩——纯粹好玩，没有压力。想试着画画想了好多年，却总跟自己说“我没那个天分”。今天决定，这都是胡说。

             在街角的美术店买了一套便宜颜料和一本速写本，画了窗外的景色。画得不算好，但它是我的。而且说真的？画的过程特别让人平静。

             也许创造力本来就不是为了画得好，只是为了出现，然后让心里的东西流出来。
             """,
             "愚园路 · 上海",
             [p1],
             nil),

            (7, "☕️",
             """
             下雨的周日。做了松饼。看书。整整六个小时没碰手机，我觉得这是个人纪录。

             什么计划都没有的一天有种奢侈的感觉。雨打在窗上，咖啡的香气，一本想读好几个月的书。没有通知，没有催促。

             我应该每周都来这么一次。脑子感觉……安静多了。
             """,
             "家",
             [],
             "下雨的周日。松饼配书，六小时没看手机。脑子安静多了。要多来几天这样的日子。"),

            (8, "✈️",
             """
             机票订了。东京，我来了。为这趟旅行存了快两年的钱，到现在还觉得不真实。

             四月，樱花季。我已经列好了想去的每一家拉面店、书店和庭院。朋友 Yuki 头几天会带我四处逛。

             这是我第一次完全靠自己出的远门。有点紧张，更多的是兴奋。感觉像是某件事的开始。
             """,
             "家 · 计划中",
             [p4],
             nil),
        ]
    }

    // MARK: - Private

    private static func makePhoto(_ hexes: [UInt]) -> Data {
        let size = CGSize(width: 400, height: 300)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = hexes.map { UIColor(Color(hex: $0)).cgColor }
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors as CFArray, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(grad, start: .zero,
                                             end: CGPoint(x: size.width, y: size.height), options: [])
        }
        return img.pngData() ?? Data()
    }
}
#endif
