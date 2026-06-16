import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation

struct AddDiaryView: View {
    @Environment(\.palette) private var pal
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var editingEntry: DiaryEntry? = nil

    @State private var content: String
    @State private var showLocation: Bool
    @State private var location: String
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photos: [Data]
    @State private var newMemos: [VoiceResult] = []
    @State private var existingMemos: [VoiceMemo]
    @State private var deletedMemoIDs: Set<UUID> = []
    @State private var showRecorder = false
    @State private var locationFetcher = LocationFetcher()
    @State private var isFetchingLocation = false
    @FocusState private var writing: Bool

    init(editingEntry: DiaryEntry? = nil) {
        self.editingEntry = editingEntry
        _content       = State(initialValue: editingEntry?.content ?? "")
        _showLocation  = State(initialValue: editingEntry?.showLocation ?? false)
        _location      = State(initialValue: editingEntry?.location ?? "")
        _photos        = State(initialValue: editingEntry?.photos ?? [])
        _existingMemos = State(initialValue:
            (editingEntry?.voiceMemos ?? []).sorted { $0.createdAt < $1.createdAt })
    }

    private var isEditing: Bool { editingEntry != nil }

    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !newMemos.isEmpty
        || !existingMemos.filter { !deletedMemoIDs.contains($0.id) }.isEmpty
    }

    private var activeMemos: [VoiceMemo] {
        existingMemos.filter { !deletedMemoIDs.contains($0.id) }
    }

    var body: some View {
        ZStack {
            pal.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Metric.l)
                    .padding(.top, Metric.m)
                    .padding(.bottom, Metric.m)

                // 正文填满剩余空间；语音/图片/日期/地址锁在下方始终可见
                VStack(alignment: .leading, spacing: Metric.m) {
                    contentEditor
                        .frame(minHeight: 120, maxHeight: .infinity)

                    voiceSection
                    photoStrip
                    dateRow
                    locationRow
                }
                .padding(.horizontal, Metric.l)
                .padding(.bottom, Metric.m)
            }
        }
        .fullScreenCover(isPresented: $showRecorder) {
            RecordingView { result in
                showRecorder = false
                guard let r = result else { return }
                if r.insertText, !r.transcript.isEmpty {
                    content += (content.isEmpty ? "" : "\n") + r.transcript
                }
                if r.keepAudio { newMemos.append(r) }
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
        .onChange(of: showLocation) { _, show in
            if show && location.isEmpty { fetchLocation() }
        }
    }

    // MARK: 顶部栏

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(pal.ink)
                    .frame(width: 36, height: 36)
                    .background(pal.card, in: Circle())
                    .overlay(Circle().stroke(pal.line, lineWidth: 1))
            }
            Spacer()
            Text(isEditing ? "编辑日记" : dateString)
                .font(.dCallout).foregroundStyle(pal.inkSoft)
            Spacer()
            Button { save() } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canSave ? pal.onAccent : pal.inkSoft)
                    .frame(width: 36, height: 36)
                    .background(canSave ? pal.accent : pal.card, in: Circle())
                    .overlay(Circle().stroke(canSave ? .clear : pal.line, lineWidth: 1))
            }
            .disabled(!canSave)
        }
    }

    // MARK: 正文（自适应高度，用隐形 Text 驱动）

    private var contentEditor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Metric.cardRadius).fill(pal.card)
                .overlay(PaperLines(color: pal.line)
                    .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius)))
                .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(pal.line, lineWidth: 1))

            if content.isEmpty {
                Text("写点什么，或点麦克风说给它听…")
                    .font(.dBody).foregroundStyle(pal.inkSoft)
                    .padding(Metric.l)
                    .allowsHitTesting(false)
            }

            // TextEditor 填满父级分配的高度，内部自行滚动超长内容
            TextEditor(text: $content)
                .font(.dBody).foregroundStyle(pal.ink)
                .scrollContentBackground(.hidden)
                .padding(Metric.m)
                .focused($writing)
        }
    }

    // MARK: 语音区

    @ViewBuilder
    private var voiceSection: some View {
        if !activeMemos.isEmpty || !newMemos.isEmpty {
            VStack(alignment: .leading, spacing: Metric.s) {
                ForEach(activeMemos) { m in
                    memoRow(
                        icon: "waveform",
                        text: m.transcript.isEmpty ? "语音 \(durStr(m.duration))" : m.transcript,
                        dur: m.duration,
                        onDelete: { deletedMemoIDs.insert(m.id) }
                    )
                }
                ForEach(newMemos.indices, id: \.self) { i in
                    memoRow(
                        icon: "waveform.badge.plus",
                        text: newMemos[i].transcript.isEmpty ? "新录音 \(durStr(newMemos[i].duration))" : newMemos[i].transcript,
                        dur: newMemos[i].duration,
                        onDelete: { newMemos.remove(at: i) }
                    )
                }
                Button { showRecorder = true } label: {
                    Label("添加语音", systemImage: "mic.fill")
                        .font(.dCaption.weight(.semibold))
                        .foregroundStyle(pal.onAccent)
                        .padding(.horizontal, Metric.m)
                        .padding(.vertical, Metric.s)
                        .background(pal.accent, in: Capsule())
                }
            }
        } else {
            // 没有语音时只显示录音入口
            Button { showRecorder = true } label: {
                Label("录音", systemImage: "mic.fill")
                    .font(.dCaption.weight(.semibold))
                    .foregroundStyle(pal.accent)
                    .padding(.horizontal, Metric.m)
                    .padding(.vertical, Metric.s)
                    .background(pal.card, in: Capsule())
                    .overlay(Capsule().stroke(pal.line, lineWidth: 1))
            }
        }
    }

    private func memoRow(icon: String, text: String, dur: Double, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: Metric.s) {
            Image(systemName: icon).foregroundStyle(pal.accent)
                .frame(width: 24)
            Text(text).font(.dCaption).foregroundStyle(pal.ink).lineLimit(1)
            Spacer()
            Text(durStr(dur)).font(.dCaption).foregroundStyle(pal.inkSoft)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(pal.inkSoft)
                    .font(.system(size: 18))
            }
        }
        .padding(.horizontal, Metric.m)
        .padding(.vertical, Metric.s)
        .background(pal.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(pal.line, lineWidth: 1))
    }

    // MARK: 图片栏

    private var photoStrip: some View {
        let line = pal.line
        let inkSoft = pal.inkSoft
        return HStack(spacing: Metric.s) {
            PhotosPicker(selection: $photoItems, maxSelectionCount: 4, matching: .images) {
                RoundedRectangle(cornerRadius: Metric.thumbRadius)
                    .strokeBorder(line, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                    .frame(width: 60, height: 60)
                    .overlay(Image(systemName: "camera").foregroundStyle(inkSoft))
            }
            ForEach(photos.indices, id: \.self) { i in
                if let ui = UIImage(data: photos[i]) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: Metric.thumbRadius))
                        Button { photos.remove(at: i) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white).shadow(radius: 2)
                        }
                        .offset(x: 4, y: -4)
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: 日期栏

    private var dateRow: some View {
        Label(dateString, systemImage: "calendar")
            .font(.dCaption).foregroundStyle(pal.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 地点栏

    private var locationRow: some View {
        HStack(spacing: Metric.s) {
            Button {
                showLocation.toggle()
                if !showLocation { location = "" }
            } label: {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(showLocation ? pal.accent : pal.inkSoft)
                    .frame(width: 20)
            }

            if showLocation {
                if isFetchingLocation {
                    ProgressView().tint(pal.accent)
                    Text("获取位置中…").font(.dCaption).foregroundStyle(pal.inkSoft)
                } else {
                    TextField("地点", text: $location)
                        .font(.dCaption).foregroundStyle(pal.ink)
                }
            } else {
                Text("添加地点").font(.dCaption).foregroundStyle(pal.inkSoft)
            }
            Spacer()
        }
    }

    // MARK: 保存

    private func save() {
        guard canSave else { return }
        if let entry = editingEntry {
            entry.content     = content
            entry.location    = showLocation ? location : ""
            entry.showLocation = showLocation
            entry.photos      = photos
            for id in deletedMemoIDs {
                if let m = existingMemos.first(where: { $0.id == id }) { context.delete(m) }
            }
            for m in newMemos {
                let memo = VoiceMemo(audio: m.audio, duration: m.duration, transcript: m.transcript)
                memo.entry = entry; context.insert(memo)
            }
        } else {
            let entry = DiaryEntry(content: content, date: Date(),
                                   location: showLocation ? location : "",
                                   showLocation: showLocation, emoji: "", photos: photos)
            context.insert(entry)
            for m in newMemos {
                let memo = VoiceMemo(audio: m.audio, duration: m.duration, transcript: m.transcript)
                memo.entry = entry; context.insert(memo)
            }
        }
        try? context.save()
        dismiss()
    }

    // MARK: 位置获取

    private func fetchLocation() {
        isFetchingLocation = true
        locationFetcher.onResult = { label in
            location = label; isFetchingLocation = false
        }
        locationFetcher.fetch()
    }

    // MARK: 工具

    private var dateString: String {
        let f = DateFormatter()
        if let e = editingEntry {
            f.dateFormat = "yyyy/MM/dd HH:mm"
            return f.string(from: e.date)
        }
        f.dateFormat = "yyyy.MM.dd"
        return f.string(from: Date())
    }

    private func durStr(_ d: TimeInterval) -> String {
        String(format: "%d:%02d", Int(d) / 60, Int(d) % 60)
    }
}

// MARK: - 位置获取器

@MainActor
private final class LocationFetcher: NSObject {
    private let manager = CLLocationManager()
    var onResult: ((String) -> Void)?

    func fetch() {
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
}

extension LocationFetcher: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        CLGeocoder().reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            let place = placemarks?.first
            let label = [place?.locality, place?.name].compactMap { $0 }.joined(separator: " · ")
            let result = label.isEmpty ? "当前位置" : label
            Task { @MainActor [weak self] in self?.onResult?(result) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: any Error) {
        Task { @MainActor [weak self] in self?.onResult?("当前位置") }
    }
}
