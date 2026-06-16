import SwiftUI
import AVFoundation
import SwiftData

struct DiaryDetailView: View {
    @Environment(\.palette) private var pal
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let entry: DiaryEntry
    let page: Int

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playingMemoID: UUID?
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            pal.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Metric.l)
                    .padding(.top, Metric.m)
                    .padding(.bottom, Metric.m)

                ScrollView {
                    VStack(alignment: .leading, spacing: Metric.m) {
                        metaRow
                        textCard
                        if !entry.photos.isEmpty { photoGrid }
                        if let memos = entry.voiceMemos, !memos.isEmpty {
                            ForEach(memos) { memo in
                                voiceBar(memo: memo)
                            }
                        }
                    }
                    .padding(.horizontal, Metric.l)
                    .padding(.bottom, Metric.xxl)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationBarHidden(true)
        .alert("删除这篇日记？", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { deleteEntry() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销")
        }
        .onDisappear { player?.stop() }
    }

    // MARK: 顶部导航

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(pal.ink)
                    .frame(width: 36, height: 36)
                    .background(pal.card, in: Circle())
                    .overlay(Circle().stroke(pal.line, lineWidth: 1))
            }
            Spacer()
            Text(pageTitle)
                .font(.dCallout)
                .foregroundStyle(pal.inkSoft)
            Spacer()
            Menu {
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(pal.ink)
                    .frame(width: 36, height: 36)
                    .background(pal.card, in: Circle())
                    .overlay(Circle().stroke(pal.line, lineWidth: 1))
            }
        }
    }

    // MARK: 元信息行

    private var metaRow: some View {
        HStack(spacing: Metric.s) {
            Text(entry.emoji).font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text(fullDateString).font(.dLargeDate).foregroundStyle(pal.ink)
                if entry.showLocation, !entry.location.isEmpty {
                    Label(entry.location, systemImage: "mappin")
                        .font(.dCaption).foregroundStyle(pal.inkSoft)
                }
            }
            Spacer()
            Text("第\(page)页")
                .font(.dMicro)
                .foregroundStyle(pal.inkSoft)
                .padding(.horizontal, Metric.s)
                .padding(.vertical, 4)
                .background(pal.card, in: Capsule())
                .overlay(Capsule().stroke(pal.line, lineWidth: 1))
        }
    }

    // MARK: 正文卡片

    private var textCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Metric.cardRadius).fill(pal.card)
                .overlay(PaperLines(color: pal.line).clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius)))
                .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(pal.line, lineWidth: 1))

            Text(entry.content.isEmpty ? "（空）" : entry.content)
                .font(.dBody)
                .foregroundStyle(entry.content.isEmpty ? pal.inkSoft : pal.ink)
                .lineSpacing(8)
                .padding(Metric.l)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: 配图

    private var photoGrid: some View {
        let photos = entry.photos
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                         spacing: Metric.s) {
            ForEach(photos.indices, id: \.self) { i in
                if let ui = UIImage(data: photos[i]) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: Metric.thumbRadius))
                }
            }
        }
    }

    // MARK: 语音条

    private func voiceBar(memo: VoiceMemo) -> some View {
        let isThisPlaying = isPlaying && playingMemoID == memo.id
        return HStack(spacing: Metric.s) {
            Button { togglePlay(memo: memo) } label: {
                Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(pal.onAccent)
                    .frame(width: 32, height: 32)
                    .background(pal.accent, in: Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                if !memo.transcript.isEmpty {
                    Text(memo.transcript)
                        .font(.dCaption).foregroundStyle(pal.ink)
                        .lineLimit(2)
                }
                Text(durString(memo.duration))
                    .font(.dCaption).foregroundStyle(pal.inkSoft)
            }

            Spacer()

            Image(systemName: "waveform")
                .foregroundStyle(pal.accent.opacity(0.6))
        }
        .padding(Metric.m)
        .background(pal.card, in: RoundedRectangle(cornerRadius: Metric.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(pal.line, lineWidth: 1))
    }

    // MARK: 逻辑

    private func togglePlay(memo: VoiceMemo) {
        if isPlaying && playingMemoID == memo.id {
            player?.pause()
            isPlaying = false
            return
        }
        player?.stop()
        guard let data = memo.audio else { return }
        player = try? AVAudioPlayer(data: data)
        player?.play()
        isPlaying = true
        playingMemoID = memo.id
    }

    private func deleteEntry() {
        player?.stop()
        context.delete(entry)
        try? context.save()
        dismiss()
    }

    private var pageTitle: String { "第 \(page) 页" }

    private var fullDateString: String {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        f.locale = Locale(identifier: "zh-CN")
        return f.string(from: entry.date)
    }

    private func durString(_ d: Double) -> String {
        String(format: "%d:%02d", Int(d) / 60, Int(d) % 60)
    }
}
