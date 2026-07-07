import SwiftUI
import AVFoundation
import SwiftData

struct DiaryDetailView: View {
    @Environment(\.palette) private var pal
    @Environment(\.modelContext) private var context
    @Environment(\.bookNavigator) private var navigator
    @Environment(DeletionCoordinator.self) private var deletionCoordinator

    let entry: DiaryEntry
    let page: Int

    @State private var coordinator = AudioCoordinator()
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playingMemoID: UUID?
    @State private var showDeleteAlert = false
    @State private var showEditor = false
    @State private var photoViewerIndex: Int? = nil

    // 自适应布局测量：正文自然高度、日期头高度、附件卡高度
    @State private var textContentH: CGFloat = 0
    @State private var headerH: CGFloat = 0
    @State private var attachH: CGFloat = 0

    private var sortedMemos: [VoiceMemo] {
        (entry.voiceMemos ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PaperBackground()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Metric.l)
                    .padding(.top, Metric.m)
                    .padding(.bottom, Metric.m)

                // 日期头 + 正文 + 附件卡顺次排布：附件卡紧跟正文下方（不再 pin 到屏幕底）。
                // 正文卡按内容自适应高度但封顶——文字过长时只在卡内上下滚动，
                // 附件卡始终留在正文正下方、不会被顶出屏幕。
                GeometryReader { geo in
                    let hasAttach = !sortedMemos.isEmpty || !entry.photos.isEmpty
                    let gaps = (hasAttach ? Metric.m * 3 : Metric.m * 2)
                    let chrome = headerH + attachH + gaps + Metric.xs + Metric.xl
                    let textMax = max(140, geo.size.height - chrome)

                    VStack(alignment: .leading, spacing: Metric.m) {
                        dateHeader
                            .measureHeight { headerH = $0 }
                        textCard(maxHeight: textMax)
                        if hasAttach {
                            attachmentCard(memos: sortedMemos)
                                .measureHeight { attachH = $0 }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Metric.l)
                    .padding(.top, Metric.xs)
                    .padding(.bottom, Metric.xl)
                }
            }
            .readableColumn()
        }
        .alert("Delete this entry?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteEntry() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone")
        }
        .dimmedSheet(isPresented: $showEditor, detents: [.fraction(2/3), .large]) {
            AddDiaryView(editingEntry: entry)
        }
        .overlay {
            if let idx = photoViewerIndex {
                PhotoFullScreenView(
                    photos: entry.photos,
                    initialIndex: idx,
                    onDismiss: { withAnimation { photoViewerIndex = nil } }
                )
                .transition(.opacity)
            }
        }
        .onDisappear { player?.stop() }
    }

    // MARK: 顶部栏

    private var topBar: some View {
        HStack {
            // 返回目录按钮（图标 + 文字）
            Button { navigator.goToList() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Back to Contents")
                        .font(.dCaption.weight(.semibold))
                }
                .foregroundStyle(pal.ink)
                .padding(.horizontal, Metric.m)
                .padding(.vertical, Metric.s)
                .background(pal.card, in: Capsule())
                .softEdge(Capsule())
            }
            Spacer()
            Text("Entry \(page)")
                .font(.dCallout)
                .foregroundStyle(pal.inkSoft)
            Spacer()
            HStack(spacing: Metric.s) {
                iconBtn("trash", tint: pal.inkSoft) { showDeleteAlert = true }
                iconBtn("square.and.pencil", tint: pal.inkSoft) { preWarmKeyboard(); showEditor = true }
            }
        }
    }

    private func iconBtn(_ systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
        }
    }

    // MARK: 正文卡片（UITextView 支持 Select/Select All → Copy）

    /// 正文卡：高度随内容自适应，但封顶为 maxHeight；超出即在卡内上下滚动，
    /// 从而把附件卡留在正文正下方、不被长文顶出屏幕。
    private func textCard(maxHeight: CGFloat) -> some View {
        // 从 UIFont 精确计算横线位置：
        //   第一条线 = 外层 padding(Metric.l) + 字体 ascender（SwiftUI Text 无额外内边距）
        //   行间距   = 字体 lineHeight + lineSpacing(6)（与 Text 上 .lineSpacing(6) 保持一致）
        let uiFont  = entry.resolvedFont.uiFont(size: CGFloat(entry.fontSize))
        let lineH   = uiFont.lineHeight + 6
        let firstY  = Metric.l + uiFont.ascender

        // 首帧 textContentH 尚未测得（0）时先用满高，量到后再收紧到内容高度。
        let boxH = textContentH > 0 ? min(textContentH, maxHeight) : maxHeight
        return ScrollView(showsIndicators: textContentH > maxHeight) {
            Group {
                if entry.content.isEmpty {
                    Text("(empty)")
                        .font(.dSerifReading).foregroundStyle(pal.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // SelectableTextView（UITextView isEditable=false, isSelectable=true）
                    // 支持长按拖选任意区间后拷贝；isScrollEnabled=false 让高度随内容自适应，
                    // 外层 ScrollView 负责超长时滚动。
                    SelectableTextView(
                        text: entry.content,
                        textColor: UIColor(entry.bodyColor(palette: pal)),
                        font: uiFont
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Metric.l)
            .measureHeight { textContentH = $0 }
        }
        .frame(height: boxH)
        .paperLinedCard(linesSpacing: lineH, linesFirstY: firstY)
    }

    // MARK: 日期页眉（正文卡上方，左日期右地点 + 一条底线）

    private var dateHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                if let year = yearString {
                    Text(year)
                        .font(.dCaption)
                        .foregroundStyle(pal.inkSoft)
                }
                Text(monthDayString)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(pal.ink)
                Text(weekdayTimeString)
                    .font(.dCaption)
                    .foregroundStyle(pal.inkSoft)
            }
            Spacer()
            if entry.showLocation, !entry.location.isEmpty {
                HStack(spacing: 4) {
                    LocationPin(size: 13, color: pal.accent)
                    Text(entry.location)
                        .font(.dCaption)
                        .foregroundStyle(pal.inkSoft)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, Metric.xs)
        .padding(.bottom, Metric.s)
        .overlay(alignment: .bottom) {
            Rectangle().fill(pal.line).frame(height: 1)
        }
    }

    // MARK: 横向图片条

    private var photoStrip: some View {
        HStack(spacing: Metric.s) {
            ForEach(Array(entry.photos.enumerated()), id: \.offset) { i, photo in
                if let ui = Thumbnailer.thumbnail(photo, side: 60) {
                    Button { withAnimation { photoViewerIndex = i } } label: {
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: Metric.thumbRadius))
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: 附件卡（语音 + 照片合一张，细分隔线分行 → 盒子从多个变一个）

    private func attachmentCard(memos: [VoiceMemo]) -> some View {
        let hasVoice = !memos.isEmpty
        let hasPhoto = !entry.photos.isEmpty
        return VStack(alignment: .leading, spacing: Metric.m) {
            if hasVoice {
                segLabel("Voice", "· \(memos.count)")
                VStack(spacing: 0) {
                    ForEach(Array(memos.enumerated()), id: \.element.id) { idx, memo in
                        if idx > 0 { hairline }
                        voiceRow(memo: memo)
                    }
                }
            }
            if hasVoice && hasPhoto { hairline }
            if hasPhoto {
                segLabel("Photos", "· \(entry.photos.count)")
                photoStrip
            }
        }
        .padding(Metric.l)
        .diaryCard()
    }

    private var hairline: some View {
        Rectangle().fill(pal.line.opacity(0.6)).frame(height: 1)
    }

    // MARK: 分区小标签（金点 + 文字，附件卡内）

    private func segLabel(_ title: LocalizedStringKey, _ trailing: String) -> some View {
        HStack(spacing: Metric.xs) {
            Circle().fill(pal.gold).frame(width: 5, height: 5)
            Text(title).font(.dLabel).foregroundStyle(pal.inkSoft)
            Text(trailing).font(.dLabel).foregroundStyle(pal.inkSoft.opacity(0.8))
            Spacer()
        }
    }

    // MARK: 语音行（无独立边框，靠附件卡承载 + 细分隔线分行）

    @ViewBuilder
    private func voiceRow(memo: VoiceMemo) -> some View {
        let isThisPlaying = isPlaying && playingMemoID == memo.id
        HStack(spacing: Metric.s) {
            Button { togglePlay(memo: memo) } label: {
                Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(pal.onAccent)
                    .frame(width: 30, height: 30)
                    .background(pal.accent, in: Circle())
            }
            WaveformStatic(color: isThisPlaying ? pal.accent : pal.inkSoft)
                .frame(height: 22)
            Text(durString(memo.duration)).font(.dCaption).foregroundStyle(pal.inkSoft)
        }
        .padding(.vertical, Metric.s)
    }

    // MARK: 逻辑

    private func togglePlay(memo: VoiceMemo) {
        if isPlaying && playingMemoID == memo.id {
            player?.pause(); isPlaying = false; return
        }
        player?.stop()
        guard let data = audioData(for: memo) else { return }
        let p = try? AVAudioPlayer(data: data)
        coordinator.onFinish = { isPlaying = false; playingMemoID = nil }
        p?.delegate = coordinator; p?.play()
        player = p; isPlaying = true; playingMemoID = memo.id
    }

    /// 从独立的 VoiceAudio 库按 audioID 取出音频本体。
    private func audioData(for memo: VoiceMemo) -> Data? {
        guard let aid = memo.audioID else { return nil }
        let desc = FetchDescriptor<VoiceAudio>(predicate: #Predicate { $0.id == aid })
        return (try? context.fetch(desc))?.first?.data
    }

    private func deleteEntry() {
        player?.stop()
        // 先隐藏条目（列表页 DiaryRow guard 会立刻拦掉），再无动画切回目录，
        // 等列表页就绪后才动 context，彻底避免 updateEntries 打断 pageCurl。
        deletionCoordinator.hiddenIDs.insert(entry.id)
        navigator.goToList(animated: false)
        Task { @MainActor in
            // 给 UIPageViewController 一个 runloop 周期完成 setViewControllers
            try? await Task.sleep(nanoseconds: 400_000_000)
            context.delete(entry)
            // 跨库音频无 SwiftData 级联，删日记前手动清理对应 VoiceAudio。
            for memo in entry.memos {
                guard let aid = memo.audioID else { continue }
                let desc = FetchDescriptor<VoiceAudio>(predicate: #Predicate { $0.id == aid })
                for a in (try? context.fetch(desc)) ?? [] { context.delete(a) }
            }
            try? context.save()
            deletionCoordinator.hiddenIDs.remove(entry.id)
        }
    }

    private func dateString(_ format: String) -> String {
        let f = DateFormatter()
        // 跟随用户当前 locale，避免海外英语用户看到中文式日期排列。
        f.locale = Locale.current
        f.dateFormat = format
        return f.string(from: entry.date)
    }

    private var yearString: String? {
        let y = dateString("yyyy")
        let currentYear = DateFormatter()
        currentYear.dateFormat = "yyyy"
        return y == currentYear.string(from: Date()) ? nil : y
    }
    private var monthDayString: String { dateString("MM.dd") }
    private var weekdayTimeString: String { dateString("HH:mm") }

    private func durString(_ d: Double) -> String {
        String(format: "%d:%02d", Int(d) / 60, Int(d) % 60)
    }
}

// MARK: - 高度测量（自适应布局用）

private struct DetailHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    /// 测量自身高度并回调（按调用点各自取值，互不干扰）。
    func measureHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { g in
                Color.clear.preference(key: DetailHeightKey.self, value: g.size.height)
            }
        )
        .onPreferenceChange(DetailHeightKey.self) { onChange($0) }
    }
}

// MARK: - 可选择 UITextView（Select → Select All → Copy 标准交互）

private struct SelectableTextView: UIViewRepresentable {
    let text: String
    let textColor: UIColor
    let font: UIFont

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable      = false
        tv.isSelectable    = true
        tv.isScrollEnabled = false   // 关掉内部滚动 → 卡片自适应文字高度，外层 ScrollView 负责滚动
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        uiView.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: style
        ])
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let w = proposal.width ?? UIScreen.main.bounds.width
        let fitted = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude))
        return CGSize(width: w, height: ceil(fitted.height))
    }
}

// MARK: - 落款分隔虚线

private struct DashedRule: View {
    let color: Color
    var body: some View {
        GeometryReader { g in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0.5))
                p.addLine(to: CGPoint(x: g.size.width, y: 0.5))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .frame(height: 1)
    }
}

// MARK: - 静态波形装饰

private struct WaveformStatic: View {
    let color: Color
    private let heights: [CGFloat] = [8, 16, 22, 12, 18, 10, 20, 14, 22, 9, 16, 12]

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(Array(heights.enumerated()), id: \.offset) { i, h in
                Capsule().fill(color).frame(width: 2.5, height: h)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 音频播放结束协调者

@MainActor
private final class AudioCoordinator: NSObject {
    var onFinish: (() -> Void)?
}

extension AudioCoordinator: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.onFinish?() }
    }
}

// MARK: - Previews

#if DEBUG
struct DiaryDetailView_Previews: PreviewProvider {
    @MainActor
    static func makeEntry() -> DiaryEntry {
        let e = DiaryEntry(
            content: "今天是个好日子，阳光洒在窗台上，我泡了一杯热茶。\n\n最近在读一本关于创造力的书，里面说写日记是最好的思维整理方式。傍晚去跑了步，耳机里放着 lo-fi，整个世界都慢下来了。",
            date: Date(),
            location: "上海 · 武康路",
            showLocation: true,
            emoji: "😊"
        )
        return e
    }

    static var previews: some View {
        let container = PreviewHelper.container()
        let entry = makeEntry()
        container.mainContext.insert(entry)

        return Group {
            PreviewWrapper(container: container) { DiaryDetailView(entry: entry, page: 1) }
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("SE")

            PreviewWrapper(container: container) { DiaryDetailView(entry: entry, page: 1) }
                .previewDevice("iPhone 16 Pro")
                .previewDisplayName("16 Pro")

            PreviewWrapper(container: container) { DiaryDetailView(entry: entry, page: 1) }
                .previewDevice("iPhone 16 Pro Max")
                .previewDisplayName("Pro Max")

            PreviewWrapper(container: container) { DiaryDetailView(entry: entry, page: 1) }
                .previewDevice("iPad (10th generation)")
                .previewDisplayName("iPad 10")
        }
    }
}
#endif
