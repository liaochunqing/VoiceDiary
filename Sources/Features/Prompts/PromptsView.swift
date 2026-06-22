import SwiftUI

// MARK: - 引导合集数据

/// 一组主题引导。免费只放「日常随记」，其余为 Pro。
struct PromptPack: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let isPro: Bool
    let prompts: [String]

    /// 按天确定性地取一条（同一天同一条，每天换）。
    func pick(_ date: Date = Date()) -> String {
        guard !prompts.isEmpty else { return "" }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return prompts[((day % prompts.count) + prompts.count) % prompts.count]
    }

    var randomPrompt: String { prompts.randomElement() ?? "" }
}

extension PromptPack {
    /// 免费基础组，复用 DailyPrompt 语料。
    static let daily = PromptPack(
        id: "daily",
        title: String(localized: "Everyday"),
        subtitle: String(localized: "The basic set — free, forever"),
        icon: "sun.max", isPro: false, prompts: DailyPrompt.all)

    static let pro: [PromptPack] = [
        PromptPack(id: "soothe",
                   title: String(localized: "Calm Down"),
                   subtitle: String(localized: "When anxious or low, say it slowly"),
                   icon: "bubbles.and.sparkles", isPro: true, prompts: [
            String(localized: "What's weighing on you most right now? Try saying it to the book."),
            String(localized: "If this feeling sat somewhere in your body, where would it be?"),
            String(localized: "This thing that hurts — what's the worst case? Is it really that bad?"),
            String(localized: "If a friend were going through this, how would you comfort them?"),
            String(localized: "Was there a moment today that wasn't as bad as you feared?"),
            String(localized: "What do you need most right now — rest, to vent, or a hug?"),
            String(localized: "Now that it's out, leave yourself one gentle word."),
        ]),
        PromptPack(id: "review",
                   title: String(localized: "Weekly Review"),
                   subtitle: String(localized: "Once a week — look back on wins and growth"),
                   icon: "arrow.triangle.2.circlepath", isPro: true, prompts: [
            String(localized: "What made you proudest this week?"),
            String(localized: "What didn't go well, and how would you adjust next time?"),
            String(localized: "Where did most of your time go this week? Was it worth it?"),
            String(localized: "Who helped you this week? Did you thank them properly?"),
            String(localized: "If you scored this week, what would it be — and why?"),
            String(localized: "What's the one thing you most want to move forward next week?"),
            String(localized: "Did you take care of yourself this week?"),
        ]),
        PromptPack(id: "english",
                   title: String(localized: "English Practice"),
                   subtitle: String(localized: "Answer in English — practice speaking while you journal"),
                   icon: "character.bubble", isPro: true, prompts: [
            "What made you smile today?",
            "Describe today in three words. Why those?",
            "What are you grateful for right now?",
            "What's something you're looking forward to?",
            "If you could redo one moment today, which one?",
            "How are you really feeling, honestly?",
            "What did you learn about yourself this week?",
        ]),
        PromptPack(id: "gratitude",
                   title: String(localized: "Gratitude"),
                   subtitle: String(localized: "Note something to be thankful for each day"),
                   icon: "heart", isPro: true, prompts: [
            String(localized: "Name three small things worth being grateful for today."),
            String(localized: "Who made your day a little better today?"),
            String(localized: "Of all you have, what have you been overlooking lately?"),
            String(localized: "What did your body do for you today? Thank it."),
            String(localized: "What's the warmest thing someone said to you recently?"),
            String(localized: "Which moment today would you like to keep?"),
            String(localized: "Right now, who do you most want to thank?"),
        ]),
        PromptPack(id: "night",
                   title: String(localized: "Wind Down"),
                   subtitle: String(localized: "Let go of today; leave a word for tomorrow"),
                   icon: "moon.stars", isPro: true, prompts: [
            String(localized: "Today can be set down now — what would you like to put down first?"),
            String(localized: "What's the one thing you most want to do well tomorrow?"),
            String(localized: "Which moment today made you feel most at ease?"),
            String(localized: "Anything left unsaid? Tell the book first."),
            String(localized: "Leave yourself a goodnight for today."),
            String(localized: "When you wake tomorrow, what do you hope to feel first?"),
            String(localized: "Right now, what does your body want most?"),
        ]),
    ]
}

// MARK: - 今日引导页（每日 prompt + Pro 主题合集）

struct PromptsView: View {
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss
    @State private var purchaseManager = PurchaseManager.shared

    @State private var todayPrompt = PromptPack.daily.pick()
    @State private var pickedPrompt: String? = nil
    @State private var selectedPack: PromptPack? = nil
    @State private var showEditor = false
    @State private var showPaywall = false

    private let cols = [GridItem(.flexible(), spacing: Metric.m),
                        GridItem(.flexible(), spacing: Metric.m)]

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Metric.l) {
                        title
                        todayCard
                        collectionHeader
                        grid
                        if !purchaseManager.isUnlocked { unlockBar }
                    }
                    .padding(Metric.l)
                    .readableColumn()
                }
                .scrollIndicators(.hidden)
                // 付费墙挂在内层视图：避免和外层的 fullScreenCover 同挂一个 view
                // 导致第二个 presentation 修饰器被 SwiftUI 静默吞掉。
                .sheet(isPresented: $showPaywall) {
                    PaywallView(feature: .prompts)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(pal.accent)
                }
            }
            // 点宫格进该主题的引导列表（push，不再直接跳空编辑器）。
            .navigationDestination(item: $selectedPack) { pack in
                PromptPackDetailView(pack: pack) { prompt in
                    pickedPrompt = prompt
                    showEditor = true
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            AddDiaryView(initialPrompt: pickedPrompt)
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Write something today")
                .font(.dSerifPageTitle).foregroundStyle(pal.ink)
            Text("Not sure where to start? Open the book and answer a question.")
                .font(.dCaption).foregroundStyle(pal.inkSoft)
        }
    }

    // MARK: 今日引导大卡（免费）

    private var todayCard: some View {
        Button {
            pickedPrompt = todayPrompt
            showEditor = true
        } label: {
            VStack(alignment: .leading, spacing: Metric.m) {
                HStack {
                    Text("Today · \(dateStr)")
                        .font(.dLabel).tracking(1).foregroundStyle(pal.accent)
                    Spacer()
                    Button {
                        todayPrompt = PromptPack.daily.randomPrompt
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Shuffle")
                        }
                        .font(.dCaption.weight(.medium)).foregroundStyle(pal.inkSoft)
                    }
                    .buttonStyle(.plain)
                }
                Text(todayPrompt)
                    .font(.dSerifHeadline).foregroundStyle(pal.ink)
                    .multilineTextAlignment(.leading).lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Metric.s) {
                    Image(systemName: "mic.fill")
                    Text("Answer by voice")
                }
                .font(.dSubhead.weight(.semibold)).foregroundStyle(pal.onAccent)
                .padding(.horizontal, Metric.l).padding(.vertical, Metric.s + 2)
                .frame(maxWidth: .infinity)
                .background(pal.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(Metric.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .diaryCard()
        }
        .buttonStyle(.plain)
    }

    private var collectionHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text("Prompt Packs").font(.dSerifSubhead.weight(.semibold)).foregroundStyle(pal.ink)
                Text("PRO")
                    .font(.system(size: 10.5, weight: .bold)).foregroundStyle(pal.accent)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(pal.accentSoft, in: RoundedRectangle(cornerRadius: 6))
            }
            Text("Pick a pack by mood and go deep on one theme for a few days")
                .font(.dCaption).foregroundStyle(pal.inkSoft)
        }
    }

    // MARK: 主题合集网格

    private var grid: some View {
        LazyVGrid(columns: cols, spacing: Metric.m) {
            packCard(.daily)
            ForEach(PromptPack.pro) { packCard($0) }
        }
    }

    private func packCard(_ pack: PromptPack) -> some View {
        let locked = pack.isPro && !purchaseManager.isUnlocked
        return Button {
            if locked {
                showPaywall = true
            } else {
                selectedPack = pack
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: pack.icon)
                        .font(.system(size: 24)).foregroundStyle(pal.accent)
                    Spacer()
                    Image(systemName: locked ? "lock.fill" : "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(locked ? pal.accent : Color(lightHex: 0x4E6B4A, darkHex: 0x7AAB74))
                        .frame(width: 22, height: 22)
                        .background(
                            (locked ? pal.accentSoft : Color(lightHex: 0x4E6B4A, darkHex: 0x7AAB74).opacity(0.18)),
                            in: Circle())
                }
                Text(pack.title).font(.dSerifSubhead.weight(.semibold)).foregroundStyle(pal.ink)
                Text(pack.subtitle)
                    .font(.dCaption).foregroundStyle(pal.inkSoft)
                    .lineLimit(2).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Metric.m)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .diaryCard()
        }
        .buttonStyle(.plain)
    }

    private var unlockBar: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: Metric.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock all prompt packs")
                        .font(.dSubhead.weight(.semibold)).foregroundStyle(pal.onAccent)
                    Text("5 themes · dozens of prompts · switch by mood")
                        .font(.dCaption).foregroundStyle(pal.onAccent.opacity(0.85))
                }
                Spacer()
                Text("Upgrade to Pro")
                    .font(.dCaption.weight(.bold)).foregroundStyle(pal.accent)
                    .padding(.horizontal, Metric.m).padding(.vertical, Metric.s)
                    .background(pal.onAccent, in: Capsule())
            }
            .padding(Metric.l)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [pal.accent, pal.leather],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: Metric.cardRadius))
        }
        .buttonStyle(.plain)
    }

    private var dateStr: String {
        let f = DateFormatter(); f.locale = .autoupdatingCurrent; f.setLocalizedDateFormatFromTemplate("MMMd")
        return f.string(from: Date())
    }
}

// MARK: - 主题引导列表（二级页）

/// 某个主题包的全部引导，逐条可点，选一条进编辑器。
struct PromptPackDetailView: View {
    @Environment(\.palette) private var pal
    let pack: PromptPack
    let onPick: (String) -> Void

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Metric.m) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: Metric.s) {
                            Image(systemName: pack.icon)
                                .font(.system(size: 22)).foregroundStyle(pal.accent)
                            Text(pack.title).font(.dSerifPageTitle).foregroundStyle(pal.ink)
                        }
                        Text(pack.subtitle).font(.dCaption).foregroundStyle(pal.inkSoft)
                    }
                    .padding(.bottom, Metric.xs)

                    ForEach(Array(pack.prompts.enumerated()), id: \.offset) { _, prompt in
                        Button { onPick(prompt) } label: {
                            HStack(spacing: Metric.m) {
                                Text(prompt)
                                    .font(.dSerifBody).foregroundStyle(pal.ink)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: Metric.s)
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(pal.onAccent)
                                    .frame(width: 34, height: 34)
                                    .background(pal.accent, in: Circle())
                                    .softEdge(Circle())
                            }
                            .padding(Metric.l)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .diaryCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Metric.l)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
