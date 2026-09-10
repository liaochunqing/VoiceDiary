import SwiftUI
import AVFoundation

/// 转写文字的处理方式
enum TextAction: CaseIterable {
    case append
    case overwrite
    case none

    var label: String {
        switch self {
        case .append:    return String(localized: "Append to end")
        case .overwrite: return String(localized: "Replace text")
        case .none:      return String(localized: "Don't add to text")
        }
    }

    var hint: String {
        switch self {
        case .append:    return String(localized: "Add the transcript after your existing text")
        case .overwrite: return String(localized: "Replace your existing text with the transcript")
        case .none:      return String(localized: "Keep the voice clip only, don't save the transcript")
        }
    }
}

/// 录音结果：交给写日记页决定如何落库。
struct VoiceResult {
    var audio: Data
    var duration: TimeInterval
    var transcript: String
    var insertText: Bool
    var overwrite: Bool
    var keepAudio: Bool
}

/// 录音面板：录音中 / 停止后共用一个骨架，状态驱动行为切换。
struct RecordingView: View {
    @Environment(\.palette) private var pal
    /// 编辑页是否已有正文：为 true 时停止后才出现「追加 / 覆盖」小分段，
    /// 否则默认追加、不打扰。
    var hasExistingContent: Bool = false
    /// 录音 sheet 的高度档位：转写文字塞不下时自动从 medium 升到 large。
    var detent: Binding<PresentationDetent>? = nil
    /// 本周剩余免费转写次数；nil = Pro 用户（不限），非 nil 时在界面展示剩余次数。
    var remainingTranscriptions: Int? = nil
    let onDone: (VoiceResult?) -> Void

    private enum Stage { case prep, recording, stopped, denied }

    @State private var recorder = VoiceRecorder()
    @State private var stage: Stage = .prep
    @State private var transcript = ""
    @State private var duration: TimeInterval = 0
    @State private var audioData: Data?
    @State private var player: AVAudioPlayer?
    @State private var audioPreparationTask: Task<Void, Never>?
    @State private var isPreparingAudio = false
    @State private var audioPreparationFailed = false
    /// 录音被中断后自动落盘，置 true 让停止页提示用户「这段已保存」。
    @State private var showInterruptedNotice = false

    // 停止后的决策状态（初始值从设置读取）
    @State private var textAction: TextAction = .append
    @State private var keepAudio = true

    // 录音中转写文字的自然高度（用于让文字框随内容长高）
    @State private var liveContentHeight: CGFloat = 0
    // 脉动动画：驱动红点 + 卡边呼吸
    @State private var isPulsing = false

    // MARK: - Body

    var body: some View {
        ZStack {
            PaperBackground()

            switch stage {
            case .prep:   prepView
            case .denied: deniedView
            case .recording, .stopped:
                unifiedView
            }
        }
        .task { await begin() }
        .onChange(of: recorder.liveTranscript) { _, newVal in
            if stage == .stopped, !newVal.isEmpty, newVal.count > transcript.count {
                transcript = newVal
            }
        }
        // 锁屏、回到主屏或切换 App 都是正常录音状态；只有系统抢占音频时才停止并保存。
        // 来电/闹钟/Siri/其他 App 抢音频 → 中断开始时落盘保住已录内容。
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { note in
            guard stage == .recording else { return }
            if let info = note.userInfo,
               let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
               let type = AVAudioSession.InterruptionType(rawValue: raw),
               type == .began {
                handleInterrupt()
            }
        }
        // 音频服务被重置（罕见但致命）→ 同样落盘。
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)) { _ in
            if stage == .recording { handleInterrupt() }
        }
    }

    // MARK: - 准备中 / 拒绝

    private var prepView: some View {
        VStack(spacing: Metric.m) {
            ProgressView()
            Text("Preparing the mic…").font(.dSubhead).foregroundStyle(pal.inkSoft)
        }
    }

    private var deniedView: some View {
        VStack(spacing: Metric.l) {
            Image(systemName: "mic.slash").font(.system(size: 40)).foregroundStyle(pal.inkSoft)
            Text("Microphone access needed").font(.dSerifPageTitle).foregroundStyle(pal.ink)
            Text("Allow VoicePaper to use the microphone in Settings › Privacy › Microphone. Recordings stay on your device and your own iCloud.")
                .font(.dSubhead).foregroundStyle(pal.inkSoft)
                .multilineTextAlignment(.center).padding(.horizontal, Metric.xl)
            Button("OK") { onDone(nil) }.tint(pal.accent)
        }
    }

    // MARK: - 统一界面（录音中 / 停止后共用骨架）

    private var unifiedView: some View {
      GeometryReader { geo in
        VStack(spacing: 0) {
            sharedTopBar(
                title: stage == .recording ? "Recording" : "This recording",
                showRecordingDot: stage == .recording
            )

            // 免费用户剩余次数提示
            if let remaining = remainingTranscriptions {
                HStack {
                    Spacer()
                    Text(recordingRemainingText(remaining))
                        .font(.dCaption)
                        .foregroundStyle(pal.inkSoft)
                    Spacer()
                }
                .padding(.top, Metric.xs)
            }

            VStack(spacing: Metric.m) {
                // 计时器 + 波形 — 仅录音中显示；停止后语音条自带迷你波形和时长
                if stage == .recording {
                    timerSection
                    waveformSection
                }

                // 转写文字 — 录音中只读滚动（随内容长高），停止后可编辑
                transcriptSection(availableHeight: geo.size.height)

                // 停止后：语音条紧贴文字下方，可选「追加 / 覆盖」分段
                if stage == .stopped {
                    stoppedAttachments
                }

                // 被中断自动落盘后的提示
                if stage == .stopped, showInterruptedNotice {
                    HStack(spacing: Metric.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Recording was interrupted — what you said so far is saved.")
                            .font(.dCaption)
                            .foregroundStyle(pal.inkSoft)
                    }
                    .padding(.horizontal, Metric.l)
                }

                Spacer(minLength: Metric.m)

                // 底部动作：录音中 = 停止按钮；停止后 = 加入日记
                if stage == .recording {
                    recordingBottom
                } else {
                    confirmButtons
                }
            }
            .padding(.top, Metric.s)
            .frame(maxHeight: .infinity, alignment: .top)
        }
      }
    }

    // MARK: - 计时器

    private var timerSection: some View {
        Text(recorder.timeString)
            .font(.system(size: 44, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Color(hex: 0xD9534F).opacity(0.85))
            .animation(.easeInOut(duration: 0.25), value: stage)
    }

    // MARK: - 波形

    private var waveformSection: some View {
        WaveformView(
            levels: recorder.levels,
            color: pal.accent
        )
        .frame(height: 56)
        .padding(.horizontal, Metric.xl)
        .shadow(color: pal.accent.opacity(0.25), radius: 8, y: 0)
        .animation(.easeInOut(duration: 0.3), value: stage)
    }

    // MARK: - 转写文字区

    private func transcriptSection(availableHeight: CGFloat) -> some View {
        Group {
            if stage == .recording {
                // 录音中：只读滚动卡片，随内容长高
                liveTranscriptView(availableHeight: availableHeight)
            } else {
                // 停止后：可编辑 TextEditor
                editableTranscriptView
            }
        }
        .padding(.horizontal, Metric.l)
    }

    // 文字框最小高度（少量文字时保持紧凑）
    private let liveBoxMin: CGFloat = 72
    // 文字框之外的固定元素（顶栏/计时/波形/停止键/留白）预留高度，
    // 用 availableHeight 减去它得到文字框可占用的上限。
    private let liveChromeReserve: CGFloat = 360

    private func liveTranscriptView(availableHeight: CGFloat) -> some View {
        let pad = Metric.m * 2
        let maxBox = max(liveBoxMin, availableHeight - liveChromeReserve)
        let desired = liveContentHeight + pad
        let boxHeight = min(max(desired, liveBoxMin), maxBox)

        return ScrollViewReader { proxy in
            ScrollView {
                Text(recorder.liveTranscript.isEmpty ? String(localized: "Start speaking…") : recorder.liveTranscript)
                    .font(.dBody)
                    .foregroundStyle(recorder.liveTranscript.isEmpty ? pal.inkSoft : pal.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Metric.m)
                    .background(GeometryReader { g in
                        Color.clear.preference(key: TranscriptHeightKey.self, value: g.size.height)
                    })
                    .id("txt")
            }
            .frame(height: boxHeight)
            .diaryCard()
            .overlay(
                RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
                    .stroke(pal.accent.opacity(isPulsing ? 0.25 : 0.08), lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
            .animation(.easeInOut(duration: 0.22), value: boxHeight)
            .onPreferenceChange(TranscriptHeightKey.self) { h in
                liveContentHeight = h
                // 半屏装不下 → 自动升到大屏；大屏仍装不下则由 ScrollView 滚动
                if desired > maxBox, detent?.wrappedValue == .medium {
                    withAnimation(.easeInOut(duration: 0.28)) { detent?.wrappedValue = .large }
                }
            }
            .onChange(of: recorder.liveTranscript) { _, _ in
                withAnimation { proxy.scrollTo("txt", anchor: .bottom) }
            }
        }
    }

    private var editableTranscriptView: some View {
        VStack(alignment: .leading, spacing: Metric.xs) {
            sectionLabel("Transcript (editable)")

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous).fill(pal.card)
                    .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.35), pal.line.opacity(0.45)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 1))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)

                if transcript.isEmpty {
                    Text("(no speech detected)")
                        .font(.dSerifReading).foregroundStyle(pal.inkSoft)
                        .padding(Metric.l)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $transcript)
                    .font(.dBody).foregroundStyle(pal.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 64)
                    .padding(Metric.s)
            }
            .frame(minHeight: 80)
        }
    }

    // MARK: - 录音中底部

    private var recordingBottom: some View {
        VStack(spacing: Metric.s) {
            Button { finish() } label: {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: 0xD9534F))
                    .frame(width: 64, height: 64)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(.white)
                            .frame(width: 24, height: 24)
                    }
                    .shadow(color: Color(hex: 0xD9534F).opacity(0.45), radius: 14, y: 6)
            }
            Text("Stop")
                .font(.dCaption.weight(.semibold))
                .foregroundStyle(Color(hex: 0xD9534F).opacity(0.8))
        }
        .padding(.bottom, Metric.l)
    }

    // MARK: - 停止后精简回顾

    /// 语音条 + 追加/覆盖分段，紧贴可编辑文字下方
    private var stoppedAttachments: some View {
        VStack(spacing: Metric.s) {
            // 语音条：默认保留；小 ✕ 移除则仅保留文字
            if keepAudio { voiceRowSlim } else { audioRemovedNotice }

            // 仅当编辑页已有正文时，才需要选择追加 / 覆盖
            if hasExistingContent { textModeSegment }
        }
        .padding(.horizontal, Metric.l)
    }

    /// 底部主操作：加入日记 + 重录
    private var confirmButtons: some View {
        VStack(spacing: Metric.s) {
            Button { confirm() } label: {
                Group {
                    if isPreparingAudio {
                        Text("Optimizing audio…")
                    } else {
                        Text("Add to entry")
                    }
                }
                    .font(.dCallout.weight(.semibold))
                    .foregroundStyle(pal.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Metric.m)
                    .background(canConfirm ? pal.accent : pal.accent.opacity(0.4),
                                in: RoundedRectangle(cornerRadius: Metric.buttonRadius))
            }
            .disabled(!canConfirm)

            Button { redo() } label: {
                Text("Re-record")
                    .font(.dSubhead)
                    .foregroundStyle(pal.inkSoft)
            }
        }
        .padding(.horizontal, Metric.l)
        .padding(.bottom, Metric.l)
    }

    /// 既没有文字、也移除了语音时，没有可加入的内容 → 禁用「加入日记」
    private var canConfirm: Bool {
        guard !isPreparingAudio else { return false }
        if keepAudio { return audioData?.isEmpty == false }
        return !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: 精简语音条（播放 + 迷你波形 + 时长 + 移除）

    private var voiceRowSlim: some View {
        HStack(spacing: Metric.s) {
            Button { togglePlay() } label: {
                Group {
                    if isPreparingAudio {
                        ProgressView().tint(pal.onAccent).controlSize(.small)
                    } else {
                        Image(systemName: player?.isPlaying == true ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .foregroundStyle(pal.onAccent)
                .frame(width: 28, height: 28)
                .background(pal.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(isPreparingAudio || audioData == nil)

            WaveformView(levels: recorder.levels, color: pal.accent.opacity(0.45))
                .frame(height: 20)

            Text(durString(duration))
                .font(.dCaption).foregroundStyle(pal.inkSoft).monospacedDigit()

            Button { keepAudio = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(pal.inkSoft)
                    .frame(width: 26, height: 26)
                    .background(pal.card, in: Circle())
                    .softEdge(Circle(), elevation: 0.5)
            }
            .buttonStyle(.plain)
        }
        .padding(Metric.m)
        .diaryCard()
    }

    private var audioRemovedNotice: some View {
        HStack(spacing: Metric.xs) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 13)).foregroundStyle(pal.inkSoft)
            Group {
                if audioPreparationFailed {
                    Text("Audio couldn't be compressed. Your transcript is still available.")
                } else {
                    Text("Don't save audio, keep text only")
                }
            }
            .font(.dCaption).foregroundStyle(pal.inkSoft)
            Spacer()
            if !audioPreparationFailed {
                Button { keepAudio = true } label: {
                    Text("Undo").font(.dCaption.weight(.semibold)).foregroundStyle(pal.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Metric.m)
        .diaryCard()
    }

    // MARK: 追加 / 覆盖 小分段（仅编辑页已有正文时出现）

    private var textModeSegment: some View {
        HStack(spacing: 3) {
            segButton(.append)
            segButton(.overwrite)
        }
        .padding(3)
        .background(pal.paper, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(pal.line, lineWidth: 1))
    }

    private func segButton(_ action: TextAction) -> some View {
        Button { textAction = action } label: {
            Text(action.label)
                .font(.dCaption.weight(textAction == action ? .semibold : .regular))
                .foregroundStyle(textAction == action ? pal.onAccent : pal.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Metric.s)
                .background(textAction == action ? pal.accent : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 共用组件

    private func sharedTopBar(title: LocalizedStringKey, showRecordingDot: Bool = false) -> some View {
        HStack {
            Button { discardAll() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(pal.ink)
                    .frame(width: 34, height: 34)
                    .background(pal.card, in: Circle())
                    .softEdge(Circle(), elevation: 0.5)
            }
            Spacer()
            HStack(spacing: 6) {
                if showRecordingDot {
                    Circle()
                        .fill(Color(hex: 0xD9534F))
                        .frame(width: 8, height: 8)
                        .scaleEffect(isPulsing ? 1.0 : 0.6)
                        .opacity(isPulsing ? 1.0 : 0.4)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                }
                Text(title).font(.dCallout).foregroundStyle(pal.ink)
            }
            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, Metric.l)
        .padding(.top, Metric.l)
        .padding(.bottom, Metric.m)
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: Metric.xs) {
            Circle()
                .fill(pal.gold)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.dLabel)
                .foregroundStyle(pal.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 逻辑

    /// 剩余次数提示文本：String(localized:) 返回已本地化的字符串，再由 Text 以 verbatim 渲染。
    private func recordingRemainingText(_ remaining: Int) -> String {
        String(localized: "\(remaining) free recordings left this week")
    }

    /// 录音被中断时保命：让 recorder 落盘，再把停止态铺好，提示用户这段已保存。
    private func handleInterrupt() {
        isPulsing = false
        recorder.interruptAndSave()
        duration = recorder.elapsed
        transcript = recorder.liveTranscript
        textAction = .append
        keepAudio = true
        stage = .stopped
        showInterruptedNotice = true
        prepareAudio()
    }

    private func begin() async {
        guard stage == .prep else { return }
        let mic = await recorder.requestMicPermission()
        _ = await SpeechTranscriber.requestAuthorization()
        guard mic else { stage = .denied; return }
        do { try recorder.start(); stage = .recording; isPulsing = true }
        catch { stage = .denied }
    }

    private func finish() {
        isPulsing = false
        _ = recorder.stop()
        duration = recorder.elapsed
        transcript = recorder.liveTranscript
        // 重置决策为设置中的默认值
        textAction = .append
        keepAudio = true
        stage = .stopped
        prepareAudio(refreshTranscript: true)
    }

    /// 将原始 PCM 转为固定 64 kbps AAC。失败时不保存巨大 PCM，仅保留转写文字。
    private func prepareAudio(refreshTranscript: Bool = false) {
        audioPreparationTask?.cancel()
        audioData = nil
        audioPreparationFailed = false
        isPreparingAudio = true

        guard let url = recorder.audioURL else {
            isPreparingAudio = false
            audioPreparationFailed = true
            keepAudio = false
            return
        }

        audioPreparationTask = Task {
            do {
                let data = try await VoiceRecorder.compressedAudioData(from: url)
                try Task.checkCancellation()
                audioData = data
            } catch is CancellationError {
                return
            } catch {
                audioData = nil
                audioPreparationFailed = true
                keepAudio = false
            }
            isPreparingAudio = false

            if refreshTranscript {
                try? await Task.sleep(for: .milliseconds(600))
                if !recorder.liveTranscript.isEmpty { transcript = recorder.liveTranscript }
            }
        }
    }

    private func confirm() {
        player?.stop()
        // 文字为空即视为「不加入正文」，无需单独的选项
        let hasText = !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        onDone(VoiceResult(
            audio: audioData ?? Data(),
            duration: duration,
            transcript: transcript,
            insertText: hasText,
            overwrite: textAction == .overwrite,
            keepAudio: keepAudio
        ))
    }

    private func redo() {
        player?.stop(); player = nil
        audioPreparationTask?.cancel(); audioPreparationTask = nil
        recorder.discard()
        recorder.wasInterrupted = false
        transcript = ""; duration = 0; audioData = nil
        isPreparingAudio = false
        audioPreparationFailed = false
        textAction = .append
        keepAudio = true
        showInterruptedNotice = false
        stage = .prep
        Task { await begin() }
    }

    private func discardAll() {
        player?.stop(); player = nil
        audioPreparationTask?.cancel(); audioPreparationTask = nil
        recorder.discard()
        onDone(nil)
    }

    private func togglePlay() {
        if player?.isPlaying == true { player?.pause(); return }
        if player == nil, let data = audioData {
            player = try? AVAudioPlayer(data: data)
        }
        player?.play()
    }

    private func durString(_ d: TimeInterval) -> String {
        String(format: "%d:%02d", Int(d) / 60, Int(d) % 60)
    }
}

// MARK: - 转写文字自然高度测量

private struct TranscriptHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - WaveformView

struct WaveformView: View {
    let levels: [CGFloat]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 3) {
                ForEach(Array(levels.enumerated()), id: \.offset) { i, level in
                    Capsule().fill(color)
                        .frame(maxWidth: .infinity)
                        .frame(height: max(3, level * geo.size.height))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}
