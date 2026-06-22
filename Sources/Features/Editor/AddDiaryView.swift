import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation

struct AddDiaryView: View {
    @Environment(\.palette) private var pal
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var editingEntry: DiaryEntry? = nil
    /// 从「今日引导」进入时携带的 prompt，作为正文占位提示展示（不预填内容）。
    var initialPrompt: String? = nil

    @State private var content: String
    @State private var showLocation: Bool
    @State private var location: String
    @State private var fontSize: Double
    @State private var fontFamily: DiaryFont
    @State private var fontColor: DiaryFontColor
    @State private var showFontPanel = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photos: [Data]
    @State private var newMemos: [VoiceResult] = []
    @State private var existingMemos: [VoiceMemo]
    @State private var deletedMemoIDs: Set<UUID> = []
    @State private var showRecorder = false
    @State private var showPaywall = false
    @State private var paywallFeature: PaywallView.PaywallFeature? = nil
    @State private var showPhotoLimitAlert = false
    @State private var locationFetcher = LocationFetcher()
    @State private var isFetchingLocation = false
    @State private var showDiscardConfirm = false
    @State private var detent: PresentationDetent
    @FocusState private var writing: Bool

    // 初始快照：用于「有改动才提示未保存」的比对（编辑已有日记时尤其需要）。
    private let initialContent: String
    private let initialShowLocation: Bool
    private let initialLocation: String
    private let initialFontSize: Double
    private let initialFontFamily: DiaryFont
    private let initialFontColor: DiaryFontColor
    private let initialPhotos: [Data]

    init(editingEntry: DiaryEntry? = nil, initialPrompt: String? = nil) {
        self.editingEntry = editingEntry
        self.initialPrompt = initialPrompt
        let content0      = editingEntry?.content ?? ""
        let showLocation0 = editingEntry?.showLocation ?? AppSettings.lastAutoLocation
        let location0     = editingEntry?.location ?? ""
        let fontSize0     = editingEntry != nil ? editingEntry!.fontSize : AppSettings.lastFontSize
        let fontFamily0   = editingEntry?.resolvedFont ?? AppSettings.lastFont
        let fontColor0    = editingEntry != nil
            ? (DiaryFontColor(rawValue: editingEntry!.fontColorHex) ?? .theme)
            : AppSettings.lastFontColor
        let photos0       = editingEntry?.photos ?? []

        _content       = State(initialValue: content0)
        _showLocation  = State(initialValue: showLocation0)
        _location      = State(initialValue: location0)
        _fontSize      = State(initialValue: fontSize0)
        _fontFamily    = State(initialValue: fontFamily0)
        _fontColor     = State(initialValue: fontColor0)
        _photos        = State(initialValue: photos0)
        _existingMemos = State(initialValue:
            (editingEntry?.voiceMemos ?? []).sorted { $0.createdAt < $1.createdAt })

        initialContent = content0
        initialShowLocation = showLocation0
        initialLocation = location0
        initialFontSize = fontSize0
        initialFontFamily = fontFamily0
        initialFontColor = fontColor0
        initialPhotos = photos0

        // 起步高度：新建=半屏；已有日记按内容长短，长内容直接大屏。
        let isLong = (editingEntry?.content.count ?? 0) > 200
        _detent = State(initialValue: editingEntry == nil ? .medium : (isLong ? .large : .medium))
    }

    private var isEditing: Bool { editingEntry != nil }

    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !newMemos.isEmpty
        || !existingMemos.filter { !deletedMemoIDs.contains($0.id) }.isEmpty
    }

    /// 是否有未保存改动。新建=有任何内容/附件；编辑=跟初始快照不一致。
    private var hasChanges: Bool {
        if editingEntry == nil {
            return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !newMemos.isEmpty || !photos.isEmpty
        }
        return content != initialContent
            || showLocation != initialShowLocation
            || location != initialLocation
            || fontSize != initialFontSize
            || fontFamily != initialFontFamily
            || fontColor != initialFontColor
            || photos != initialPhotos
            || !newMemos.isEmpty
            || !deletedMemoIDs.isEmpty
    }

    private var activeMemos: [VoiceMemo] {
        existingMemos.filter { !deletedMemoIDs.contains($0.id) }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Metric.l)
                    .padding(.top, Metric.m)
                    .padding(.bottom, Metric.m)

                // 正文填满剩余空间，是绝对主角；附件以小胶囊按需出现，
                // 录音/照片/字体/地点归一条底部工具栏，纸面最大化。
                contentEditor
                    .frame(minHeight: 120, maxHeight: .infinity)
                    .padding(.horizontal, Metric.l)

                attachmentStrip

                bottomToolbar
                    .padding(.horizontal, Metric.l)
                    .padding(.top, Metric.m)
                    .padding(.bottom, Metric.s)
            }
            .readableColumn()
        }
        .sheet(isPresented: $showRecorder) {
            RecordingView(
                hasExistingContent: !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) { result in
                showRecorder = false
                guard let r = result else { return }
                if r.insertText, !r.transcript.isEmpty {
                    if r.overwrite {
                        content = r.transcript
                    } else {
                        content += (content.isEmpty ? "" : "\n") + r.transcript
                    }
                    incrementTranscriptionCount()
                }
                if r.keepAudio { newMemos.append(r) }
            }
            // 方案C：底部半屏浮层，日记页在上方露出（不离开编辑页）。带抓手、
            // 可在 半屏↔大 之间拖动（编辑文字时系统自动顶到大）。禁用下滑误关，
            // 录音进行中只能经顶部 ✕（会停录音、释放资源）退出。
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showFontPanel) {
            FontPickerPanel(
                font: $fontFamily,
                size: $fontSize,
                color: $fontColor,
                onClose: { showFontPanel = false },
                onApply: { showFontPanel = false },
                onPaywall: {
                    showFontPanel = false
                    paywallFeature = .fonts
                    showPaywall = true
                }
            )
            .presentationDetents([.fraction(0.65), .large])
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: paywallFeature)
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            let isUnlocked = PurchaseManager.shared.isUnlocked
            // 非会员选了多张：提示后只保留第一张。
            if !isUnlocked && items.count > 1 {
                showPhotoLimitAlert = true
            }
            Task { @MainActor in
                let allowed = isUnlocked ? items : Array(items.prefix(1))
                var datas: [Data] = []
                for item in allowed {
                    if let d = try? await item.loadTransferable(type: Data.self),
                       let compressed = UIImage(data: d)?.diaryCompressed() {
                        datas.append(compressed)
                    }
                }
                let maxPhotos = isUnlocked ? 4 : 1
                photos = Array((photos + datas).prefix(maxPhotos))
                photoItems = []
            }
        }
        .alert("1 photo only", isPresented: $showPhotoLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The free plan allows 1 photo per entry. Upgrade to add up to 4.")
        }
        .task {
            // 定位默认已开时 onChange 不会触发，手动补一次初始抓取。
            if showLocation && location.isEmpty { fetchLocation() }
        }
        .onChange(of: showLocation) { _, show in
            if show && location.isEmpty { fetchLocation() }
        }
        // ── 半屏 sheet 行为 ──
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        // 有改动时挡住下滑，逼用户走 ✕ 走确认；没改动可随意下滑关闭。
        .interactiveDismissDisabled(hasChanges)
        // 开始打字时升到大屏，避免 medium 被键盘挤没。
        .onChange(of: writing) { _, focused in
            if focused { detent = .large }
        }
        .confirmationDialog("Unsaved changes", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
            if canSave { Button("Save") { save() } }
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: 顶部栏

    private var topBar: some View {
        HStack {
            Button {
                if hasChanges { showDiscardConfirm = true } else { dismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(pal.ink)
                    .frame(width: 36, height: 36)
                    .background(pal.card, in: Circle())
                    .softEdge(Circle())
            }
            Spacer()
            Text(isEditing ? String(localized: "Edit Entry") : dateString)
                .font(.dCallout).foregroundStyle(pal.inkSoft)
            Spacer()
            Button { save() } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
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
            if content.isEmpty {
                VStack(alignment: .leading, spacing: Metric.s) {
                    if let prompt = initialPrompt {
                        Text(prompt)
                            .font(fontFamily.swiftUIFont(size: fontSize))
                            .foregroundStyle(pal.ink.opacity(0.55))
                        Text("Tap the mic and talk to it, or write below…")
                            .font(.dCaption)
                            .foregroundStyle(pal.inkSoft)
                    } else {
                        Text("Write something, or tap the mic and talk to it…")
                            .font(fontFamily.swiftUIFont(size: fontSize))
                            .foregroundStyle(pal.inkSoft)
                    }
                }
                .padding(Metric.l)
                .allowsHitTesting(false)
            }

            // TextEditor 填满父级分配的高度，内部自行滚动超长内容
            TextEditor(text: $content)
                .font(fontFamily.swiftUIFont(size: fontSize))
                .foregroundStyle(fontColor.resolved(palette: pal))
                .scrollContentBackground(.hidden)
                .padding(Metric.m)
                .focused($writing)
                .id(fontColor)
        }
        .paperLinedCard()
    }

    // MARK: 附件胶囊条（语音 / 照片 / 地点，只在存在时横向排列）

    @ViewBuilder
    private var attachmentStrip: some View {
        let hasAny = !activeMemos.isEmpty || !newMemos.isEmpty
            || !photos.isEmpty || showLocation
        if hasAny {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metric.s) {
                    ForEach(activeMemos) { m in
                        voiceChip(durStr(m.duration), isNew: false) {
                            deletedMemoIDs.insert(m.id)
                        }
                    }
                    ForEach(newMemos.indices, id: \.self) { i in
                        voiceChip(durStr(newMemos[i].duration), isNew: true) {
                            newMemos.remove(at: i)
                        }
                    }
                    ForEach(photos.indices, id: \.self) { i in
                        if let ui = UIImage(data: photos[i]) {
                            photoChip(ui) { photos.remove(at: i) }
                        }
                    }
                    if showLocation { locationChip }
                }
                .padding(.horizontal, Metric.l)
                .padding(.top, Metric.m)
            }
        }
    }

    private func voiceChip(_ text: String, isNew: Bool, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isNew ? "waveform.badge.plus" : "waveform")
                .font(.system(size: 12)).foregroundStyle(pal.accent)
            Text(text).font(.dCaption).foregroundStyle(pal.ink)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14)).foregroundStyle(pal.inkSoft)
            }
        }
        .padding(.horizontal, Metric.s).padding(.vertical, 6)
        .background(pal.card, in: Capsule())
        .softEdge(Capsule(), elevation: 0.5)
    }

    private func photoChip(_ ui: UIImage, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14)).foregroundStyle(pal.inkSoft)
            }
        }
        .padding(4)
        .background(pal.card, in: RoundedRectangle(cornerRadius: 12))
        .softEdge(RoundedRectangle(cornerRadius: 12), elevation: 0.5)
    }

    @ViewBuilder
    private var locationChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 12)).foregroundStyle(pal.accent)
            if isFetchingLocation {
                Text("Locating…").font(.dCaption).foregroundStyle(pal.inkSoft)
            } else {
                Text(location.isEmpty ? String(localized: "Current location") : location)
                    .font(.dCaption).foregroundStyle(pal.ink).lineLimit(1)
            }
            Button {
                showLocation = false
                location = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14)).foregroundStyle(pal.inkSoft)
            }
        }
        .padding(.horizontal, Metric.s).padding(.vertical, 6)
        .background(pal.card, in: Capsule())
        .softEdge(Capsule(), elevation: 0.5)
    }

    // MARK: 底部统一工具栏（录音 / 照片 / 字体 / 地点，等宽图标钮）

    private var bottomToolbar: some View {
        HStack(spacing: Metric.xs) {
            toolButton(icon: "mic.fill", label: "Record", active: false) {
                tryStartRecording()
            }

            // 照片：本身就是相册选择器，点开系统选图
            PhotosPicker(selection: $photoItems,
                         maxSelectionCount: 4,
                         matching: .images) {
                toolLabel(icon: "photo", label: "Photo", active: false, swatch: nil)
            }
            .buttonStyle(.plain)

            // 字体：角标小圆点显示当前字色
            Button { showFontPanel = true } label: {
                toolLabel(icon: "textformat", label: "Font",
                          active: false, swatch: fontColor.resolved(palette: pal))
            }
            .buttonStyle(.plain)

            toolButton(icon: showLocation ? "mappin.circle.fill" : "mappin.and.ellipse",
                       label: "Place", active: showLocation) {
                showLocation.toggle()
                if !showLocation { location = "" }
            }
        }
        .padding(Metric.xs)
        .diaryCard()
    }

    private func toolButton(icon: String, label: LocalizedStringKey, active: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            toolLabel(icon: icon, label: label, active: active, swatch: nil)
        }
        .buttonStyle(.plain)
    }

    private func toolLabel(icon: String, label: LocalizedStringKey, active: Bool, swatch: Color?) -> ToolLabel {
        ToolLabel(pal: pal, icon: icon, label: label, active: active, swatch: swatch)
    }

    // MARK: 保存

    private func save() {
        guard canSave else { return }
        if let entry = editingEntry {
            entry.content     = content
            entry.location    = showLocation ? location : ""
            entry.showLocation = showLocation
            entry.fontSize    = fontSize
            entry.fontName    = fontFamily.rawValue
            entry.fontColorHex = fontColor.rawValue
            entry.photos      = photos
            for id in deletedMemoIDs {
                if let m = existingMemos.first(where: { $0.id == id }) {
                    deleteAudio(of: m)
                    context.delete(m)
                }
            }
            for m in newMemos {
                let audio = VoiceAudio(data: m.audio)
                context.insert(audio)
                let memo = VoiceMemo(audioID: audio.id, duration: m.duration, transcript: m.transcript)
                memo.entry = entry; context.insert(memo)
            }
        } else {
            let entry = DiaryEntry(content: content, date: Date(),
                                   location: showLocation ? location : "",
                                   showLocation: showLocation, emoji: "", photos: photos)
            entry.fontSize    = fontSize
            entry.fontName    = fontFamily.rawValue
            entry.fontColorHex = fontColor.rawValue
            context.insert(entry)
            for m in newMemos {
                let audio = VoiceAudio(data: m.audio)
                context.insert(audio)
                let memo = VoiceMemo(audioID: audio.id, duration: m.duration, transcript: m.transcript)
                memo.entry = entry; context.insert(memo)
            }
        }
        try? context.save()
        AppSettings.lastFontName = fontFamily.rawValue
        AppSettings.lastFontSize = fontSize
        AppSettings.lastFontColorHex = fontColor.rawValue
        AppSettings.lastAutoLocation = showLocation
        // 今天写完了，撤掉今晚那条提醒，别再催。
        NotificationManager().cancelTodayReminder()
        dismiss()
    }

    /// 删除一条语音备忘对应的跨库音频实体（VoiceAudio 与 VoiceMemo 无 SwiftData 关系，需手动清理）。
    private func deleteAudio(of memo: VoiceMemo) {
        guard let aid = memo.audioID else { return }
        let desc = FetchDescriptor<VoiceAudio>(predicate: #Predicate { $0.id == aid })
        for a in (try? context.fetch(desc)) ?? [] { context.delete(a) }
    }

    // MARK: 位置获取

    private func fetchLocation() {
        isFetchingLocation = true
        locationFetcher.onResult = { label in
            location = label; isFetchingLocation = false
        }
        locationFetcher.fetch()
    }

    // MARK: 免费额度

    private static let maxFreeTranscriptionsPerDay = 3

    private var dailyTranscriptionKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"
        return "transcriptionCount_\(f.string(from: Date()))"
    }

    private var dailyTranscriptionCount: Int {
        UserDefaults.standard.integer(forKey: dailyTranscriptionKey)
    }

    private func canTranscribeToday() -> Bool {
        PurchaseManager.shared.isUnlocked || dailyTranscriptionCount < Self.maxFreeTranscriptionsPerDay
    }

    private func incrementTranscriptionCount() {
        let key = dailyTranscriptionKey
        UserDefaults.standard.set(dailyTranscriptionCount + 1, forKey: key)
    }

    private func tryStartRecording() {
        if canTranscribeToday() {
            showRecorder = true
        } else {
            paywallFeature = .voice
            showPaywall = true
        }
    }

    // MARK: 工具

    private var dateString: String {
        let f = DateFormatter()
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        if let e = editingEntry {
            let isSameYear = cal.component(.year, from: e.date) == currentYear
            f.dateFormat = isSameYear ? "MM/dd HH:mm" : "yyyy/MM/dd HH:mm"
            return f.string(from: e.date)
        }
        f.dateFormat = "MM.dd"
        return f.string(from: Date())
    }

    private func durStr(_ d: TimeInterval) -> String {
        String(format: "%d:%02d", Int(d) / 60, Int(d) % 60)
    }
}

// MARK: - 底部工具栏按钮标签（抽成独立 View，避开 PhotosPicker 闭包的 actor 隔离限制）

private struct ToolLabel: View {
    let pal: DiaryPalette
    let icon: String
    let label: LocalizedStringKey
    let active: Bool
    var swatch: Color? = nil

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(pal.accent)
                    .frame(height: 20)
                if let swatch {
                    Circle().fill(swatch)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(pal.card, lineWidth: 1.5))
                        .offset(x: 5, y: 2)
                }
            }
            Text(label).font(.dCaption)
                .foregroundStyle(active ? pal.ink : pal.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Metric.s)
        .background(active ? pal.paper : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - 图片压缩

private extension UIImage {
    /// 等比缩到 maxDimension 内，再以 JPEG quality 压缩，降低 CloudKit 存储压力。
    func diaryCompressed(maxDimension: CGFloat = 1080, quality: CGFloat = 0.8) -> Data? {
        let scale = min(1, min(maxDimension / size.width, maxDimension / size.height))
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality)
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
            // 只取最具体的一个地名，不拼完整地址（太长不好显示）。
            // 优先 name（iOS 逆地理最具体字段），其次 POI、街道、街区、城市。
            let result = place?.name
                ?? place?.areasOfInterest?.first
                ?? place?.thoroughfare
                ?? place?.subLocality
                ?? place?.locality
                ?? String(localized: "Current location")
            Task { @MainActor [weak self] in self?.onResult?(result) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: any Error) {
        Task { @MainActor [weak self] in self?.onResult?(String(localized: "Current location")) }
    }
}
