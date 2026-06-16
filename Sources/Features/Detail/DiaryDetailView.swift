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
    @State private var showNewEntry = false
    @State private var photoViewerIndex: Int? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            pal.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Metric.l)
                    .padding(.top, Metric.m)
                    .padding(.bottom, Metric.m)

                // 文本撑满剩余空间；语音/图片/日期锁在下方始终可见
                VStack(alignment: .leading, spacing: Metric.m) {
                    textCard
                        .frame(maxHeight: .infinity)

                    let sorted = (entry.voiceMemos ?? []).sorted { $0.createdAt < $1.createdAt }
                    ForEach(sorted) { voiceBar(memo: $0) }
                    if !entry.photos.isEmpty { photoStrip }
                    metaSection
                }
                .padding(.horizontal, Metric.l)
                .padding(.bottom, Metric.m)
            }
            // 可拖拽新建按钮
            DraggableFAB { showNewEntry = true }
                .padding(Metric.xl)
        }
        .alert("删除这篇日记？", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { deleteEntry() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销")
        }
        .fullScreenCover(isPresented: $showEditor) {
            AddDiaryView(editingEntry: entry)
        }
        .fullScreenCover(isPresented: $showNewEntry) {
            AddDiaryView()
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
                    Text("返回目录")
                        .font(.dCaption.weight(.semibold))
                }
                .foregroundStyle(pal.ink)
                .padding(.horizontal, Metric.m)
                .padding(.vertical, Metric.s)
                .background(pal.card, in: Capsule())
                .overlay(Capsule().stroke(pal.line, lineWidth: 1))
            }
            Spacer()
            Text("第 \(page) 页")
                .font(.dCallout)
                .foregroundStyle(pal.inkSoft)
            Spacer()
            HStack(spacing: Metric.s) {
                iconBtn("trash", tint: .red) { showDeleteAlert = true }
                iconBtn("pencil") { showEditor = true }
            }
        }
    }

    private func iconBtn(_ name: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint ?? pal.ink)
                .frame(width: 36, height: 36)
                .background(pal.card, in: Circle())
                .overlay(Circle().stroke(pal.line, lineWidth: 1))
        }
    }

    // MARK: 正文卡片（UITextView 支持 Select/Select All → Copy）

    private var textCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Metric.cardRadius).fill(pal.card)
                .overlay(PaperLines(color: pal.line)
                    .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius)))
                .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(pal.line, lineWidth: 1))

            if entry.content.isEmpty {
                Text("（空）")
                    .font(.dBody).foregroundStyle(pal.inkSoft)
                    .padding(Metric.l)
            } else {
                SelectableTextView(
                    text: entry.content,
                    textColor: UIColor(pal.ink)
                )
                .padding(Metric.l)
            }
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

    // MARK: 元信息区（日期 + 地点各占一行）

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: Metric.xs) {
            Label(timeString, systemImage: "clock")
                .font(.dCaption).foregroundStyle(pal.inkSoft)
            if entry.showLocation, !entry.location.isEmpty {
                Label(entry.location, systemImage: "mappin")
                    .font(.dCaption).foregroundStyle(pal.inkSoft)
            }
        }
        .padding(.top, Metric.xs)
    }

    // MARK: 语音条

    @ViewBuilder
    private func voiceBar(memo: VoiceMemo) -> some View {
        let isThisPlaying = isPlaying && playingMemoID == memo.id
        HStack(spacing: Metric.s) {
            Button { togglePlay(memo: memo) } label: {
                Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(pal.onAccent)
                    .frame(width: 32, height: 32)
                    .background(pal.accent, in: Circle())
            }
            WaveformStatic(color: isThisPlaying ? pal.accent : pal.inkSoft)
                .frame(height: 24)
            Spacer()
            Text(durString(memo.duration)).font(.dCaption).foregroundStyle(pal.inkSoft)
            Image(systemName: "waveform")
                .foregroundStyle(pal.accent.opacity(isThisPlaying ? 1 : 0.5))
                .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: isThisPlaying)
        }
        .padding(Metric.m)
        .background(pal.card, in: RoundedRectangle(cornerRadius: Metric.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(pal.line, lineWidth: 1))
    }

    // MARK: 逻辑

    private func togglePlay(memo: VoiceMemo) {
        if isPlaying && playingMemoID == memo.id {
            player?.pause(); isPlaying = false; return
        }
        player?.stop()
        guard let data = memo.audio else { return }
        let p = try? AVAudioPlayer(data: data)
        coordinator.onFinish = { isPlaying = false; playingMemoID = nil }
        p?.delegate = coordinator; p?.play()
        player = p; isPlaying = true; playingMemoID = memo.id
    }

    private func deleteEntry() {
        player?.stop()
        context.delete(entry)
        try? context.save()
        navigator.goToList()
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: entry.date)
    }

    private func durString(_ d: Double) -> String {
        String(format: "%d:%02d", Int(d) / 60, Int(d) % 60)
    }
}

// MARK: - 可选择 UITextView（Select → Select All → Copy 标准交互）

private struct SelectableTextView: UIViewRepresentable {
    let text: String
    let textColor: UIColor

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable      = false
        tv.isSelectable    = true
        tv.isScrollEnabled = true   // 文本区内部自行滚动
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 8
        uiView.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: textColor,
            .paragraphStyle: style
        ])
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        // 接受父级分配的尺寸，UITextView 内部处理超长内容的滚动
        let w = proposal.width  ?? UIScreen.main.bounds.width
        let h = proposal.height ?? 160
        return CGSize(width: w, height: h)
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
