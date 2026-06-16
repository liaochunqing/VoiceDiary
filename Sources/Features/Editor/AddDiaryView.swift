import SwiftUI
import SwiftData
import PhotosUI

struct AddDiaryView: View {
    @Environment(\.palette) private var pal
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var content = ""
    @State private var emoji = "🙂"
    @State private var showLocation = false
    @State private var location = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photos: [Data] = []
    @State private var memos: [VoiceResult] = []
    @State private var showRecorder = false
    @FocusState private var writing: Bool

    private let moods = ["🙂", "😊", "🥳", "😌", "😴", "😢", "😡", "🌧", "✨"]

    private var canSave: Bool { !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !memos.isEmpty }

    var body: some View {
        ZStack {
            pal.paper.ignoresSafeArea()
            VStack(spacing: Metric.m) {
                topBar
                pills
                editor
                if !memos.isEmpty { memoStrip }
                photoStrip
                Spacer()
            }
            .padding(.bottom, Metric.s)
        }
        .fullScreenCover(isPresented: $showRecorder) {
            RecordingView { result in
                showRecorder = false
                guard let r = result else { return }
                if r.insertText, !r.transcript.isEmpty {
                    content += (content.isEmpty ? "" : "\n") + r.transcript
                }
                if r.keepAudio { memos.append(r) }
            }
        }
        .onChange(of: photoItems) { _, items in
            Task { @MainActor in
                var datas: [Data] = []
                for item in items {
                    if let d = try? await item.loadTransferable(type: Data.self) { datas.append(d) }
                }
                photos = datas
            }
        }
    }

    // MARK: 顶部

    private var topBar: some View {
        HStack {
            iconButton("xmark") { dismiss() }
            Spacer()
            Text(dateString).font(.dLargeDate).foregroundStyle(pal.ink)
            Spacer()
            Button { save() } label: {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canSave ? pal.onAccent : pal.inkSoft)
                    .frame(width: 40, height: 40)
                    .background(canSave ? pal.accent : pal.card, in: Circle())
            }
            .disabled(!canSave)
        }
        .padding(.horizontal, Metric.l).padding(.top, Metric.m)
    }

    private func iconButton(_ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 14, weight: .bold))
                .foregroundStyle(pal.ink).frame(width: 40, height: 40)
                .background(pal.card, in: Circle())
        }
    }

    // MARK: pills

    private var pills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Metric.s) {
                Menu {
                    ForEach(moods, id: \.self) { m in Button(m) { emoji = m } }
                } label: { pill { Text(emoji); Text("心情") } }

                Button { showLocation.toggle() } label: {
                    pill(active: showLocation) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(showLocation ? "隐藏位置" : "位置")
                    }
                }

                Button { showRecorder = true } label: {
                    pill(hot: true) { Image(systemName: "mic.fill"); Text("语音") }
                }
            }
            .padding(.horizontal, Metric.l)
        }
    }

    @ViewBuilder
    private func pill<C: View>(hot: Bool = false, active: Bool = false, @ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: Metric.xs) { content() }
            .font(.dSubhead)
            .foregroundStyle(hot ? pal.onAccent : pal.ink)
            .padding(.horizontal, Metric.m).padding(.vertical, Metric.s)
            .background(hot ? pal.accent : (active ? pal.accentSoft.opacity(0.3) : pal.card), in: Capsule())
            .overlay(Capsule().stroke(hot ? .clear : pal.line, lineWidth: 1))
    }

    // MARK: 写作区（纸纹）

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Metric.cardRadius).fill(pal.card)
                .overlay(PaperLines(color: pal.line).clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius)))
                .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(pal.line, lineWidth: 1))

            if content.isEmpty {
                Text("写点什么，或点上面的 🎤 说给它听…")
                    .font(.dBody).foregroundStyle(pal.inkSoft)
                    .padding(.horizontal, Metric.l + 4).padding(.top, Metric.l + 4)
            }
            TextEditor(text: $content)
                .font(.dBody).foregroundStyle(pal.ink)
                .scrollContentBackground(.hidden)
                .padding(Metric.m)
                .focused($writing)
        }
        .frame(minHeight: 200)
        .padding(.horizontal, Metric.l)
    }

    // MARK: 语音附件

    private var memoStrip: some View {
        VStack(spacing: Metric.s) {
            ForEach(memos.indices, id: \.self) { i in
                HStack(spacing: Metric.s) {
                    Image(systemName: "waveform").foregroundStyle(pal.accent)
                    Text(memos[i].transcript.isEmpty ? "语音 \(durString(memos[i].duration))" : memos[i].transcript)
                        .font(.dCaption).foregroundStyle(pal.ink).lineLimit(1)
                    Spacer()
                    Text(durString(memos[i].duration)).font(.dCaption).foregroundStyle(pal.inkSoft)
                    Button { memos.remove(at: i) } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(pal.inkSoft)
                    }
                }
                .padding(.horizontal, Metric.m).padding(.vertical, Metric.s)
                .background(pal.card, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(pal.line, lineWidth: 1))
            }
        }
        .padding(.horizontal, Metric.l)
    }

    // MARK: 配图

    private var photoStrip: some View {
        HStack(spacing: Metric.s) {
            PhotosPicker(selection: $photoItems, maxSelectionCount: 4, matching: .images) {
                RoundedRectangle(cornerRadius: Metric.thumbRadius)
                    .strokeBorder(pal.line, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "camera").foregroundStyle(pal.inkSoft))
            }
            ForEach(photos.indices, id: \.self) { i in
                if let ui = UIImage(data: photos[i]) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: Metric.thumbRadius))
                }
            }
            Spacer()
        }
        .padding(.horizontal, Metric.l)
    }

    // MARK: 逻辑

    private func save() {
        guard canSave else { return }
        let entry = DiaryEntry(content: content, date: Date(),
                               location: showLocation ? location : "",
                               showLocation: showLocation, emoji: emoji, photos: photos)
        context.insert(entry)
        for m in memos {
            let memo = VoiceMemo(audio: m.audio, duration: m.duration, transcript: m.transcript)
            memo.entry = entry
            context.insert(memo)
        }
        try? context.save()
        dismiss()
    }

    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd"; return f.string(from: Date())
    }
    private func durString(_ d: TimeInterval) -> String { String(format: "%d:%02d", Int(d) / 60, Int(d) % 60) }
}
