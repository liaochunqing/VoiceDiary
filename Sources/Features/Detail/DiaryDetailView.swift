import SwiftUI
import AVFoundation
import SwiftData

struct DiaryDetailView: View {
    @Environment(\.palette) private var pal
    @Environment(\.modelContext) private var context
    @Environment(\.bookNavigator) private var navigator

    let entry: DiaryEntry
    let page: Int

    @State private var coordinator = AudioCoordinator()
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playingMemoID: UUID?
    @State private var showDeleteAlert = false
    @State private var showEditor = false
    @State private var photoViewerIndex: Int? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PaperBackground()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Metric.l)
                    .padding(.top, Metric.m)
                    .padding(.bottom, Metric.m)

                // 正文信纸自适应内容（落款在卡内底部）；语音/照片分区列于其下
                ScrollView(showsIndicators: false) {
                    let sorted = (entry.voiceMemos ?? []).sorted { $0.createdAt < $1.createdAt }
                    VStack(alignment: .leading, spacing: Metric.m) {
                        dateHeader
                        textCard

                        // 语音 + 照片合进一张「附件」卡，整页只剩正文卡 + 附件卡两块
                        if !sorted.isEmpty || !entry.photos.isEmpty {
                            attachmentCard(memos: sorted)
                        }
                    }
                    .padding(.horizontal, Metric.l)
                    .padding(.top, Metric.xs)
                    .padding(.bottom, 88)
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
        .sheet(isPresented: $showEditor) {
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
            Text("Page \(page)")
                .font(.dCallout)
                .foregroundStyle(pal.inkSoft)
            Spacer()
            HStack(spacing: Metric.s) {
                emojiBtn("🗑️") { showDeleteAlert = true }
                emojiBtn("✏️") { showEditor = true }
            }
        }
    }

    private func emojiBtn(_ emoji: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(emoji)
                .font(.system(size: 17))
                .frame(width: 36, height: 36)
                .background(pal.card, in: Circle())
                .softEdge(Circle())
        }
    }

    // MARK: 正文卡片（UITextView 支持 Select/Select All → Copy）

    private var textCard: some View {
        VStack(alignment: .leading, spacing: Metric.m) {
            if entry.content.isEmpty {
                Text("(empty)")
                    .font(.dSerifReading).foregroundStyle(pal.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // 原生 Text + textSelection：保留长按选择/拷贝，又不引入嵌套 UITextView
                // 的滚动/选择手势冲突——长正文时外层 ScrollView 才能正常滚到附件。
                Text(entry.content)
                    .font(entry.bodyFont(palette: pal))
                    .foregroundStyle(entry.bodyColor(palette: pal))
                    .lineSpacing(6)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Metric.l)
        .paperLinedCard()
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
            ForEach(entry.photos.indices, id: \.self) { i in
                if let ui = UIImage(data: entry.photos[i]) {
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
        // 跨库音频无 SwiftData 级联，删日记前手动清理对应 VoiceAudio。
        for memo in entry.memos {
            guard let aid = memo.audioID else { continue }
            let desc = FetchDescriptor<VoiceAudio>(predicate: #Predicate { $0.id == aid })
            for a in (try? context.fetch(desc)) ?? [] { context.delete(a) }
        }
        context.delete(entry)
        try? context.save()
        navigator.goToList()
    }

    private func dateString(_ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
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
    private var weekdayTimeString: String { dateString("EEE  HH:mm") }

    private func durString(_ d: Double) -> String {
        String(format: "%d:%02d", Int(d) / 60, Int(d) % 60)
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
            ForEach(heights.indices, id: \.self) { i in
                Capsule().fill(color).frame(width: 2.5, height: heights[i])
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
