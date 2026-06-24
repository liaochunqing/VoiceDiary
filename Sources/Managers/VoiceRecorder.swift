import AVFoundation
@preconcurrency import Speech
import Observation

private final class TapState {
    private let lock = NSLock()
    private var _request: SFSpeechAudioBufferRecognitionRequest?

    var request: SFSpeechAudioBufferRecognitionRequest? {
        get { lock.lock(); defer { lock.unlock() }; return _request }
        set { lock.lock(); defer { lock.unlock() }; _request = newValue }
    }

    var file: AVAudioFile?
    var latestRMS: CGFloat = 0.04
}

private func audioRMS(_ buffer: AVAudioPCMBuffer) -> CGFloat {
    guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0.04 }
    let count = Int(buffer.frameLength)
    var sum: Float = 0
    for i in 0..<count { sum += data[i] * data[i] }
    return CGFloat(max(0.04, min(1.0, Double(sqrt(sum / Float(count))) * 8)))
}

@MainActor
@Observable
final class VoiceRecorder {

    enum Phase { case idle, recording, finished }

    var phase: Phase = .idle
    var elapsed: TimeInterval = 0
    var levels: [CGFloat] = Array(repeating: 0.04, count: barCount)
    var liveTranscript: String = ""
    /// 录音被中断（来电/闹钟/切后台/音频服务重置）时置 true，UI 据此提示「已保存这段」。
    var wasInterrupted = false

    private(set) var audioURL: URL?

    static let barCount = 42

    @ObservationIgnored private var engine = AVAudioEngine()
    @ObservationIgnored private var recognizer: SFSpeechRecognizer?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var startDate: Date = Date()
    @ObservationIgnored private var tapState = TapState()

    // 累积文本：已提交的（前面各段拼好的）转写内容
    @ObservationIgnored private var accumulated: String = ""
    // 当前这一段识别 task 的最新结果
    @ObservationIgnored private var pendingText: String = ""
    // 静默检测定时器：文本停止变化一段时间后提交当前段并重启 task
    @ObservationIgnored private var settleTimer: Timer?
    // task 代次令牌：重启后旧 task 的迟到回调据此忽略
    @ObservationIgnored private var taskGeneration = 0
    // 当前段开始时间：用于「段缓冲封顶」兜底，限制易失缓冲体量
    @ObservationIgnored private var segmentStartDate = Date()
    // 本次录音使用的识别语言（决定标点/拼接风格）
    @ObservationIgnored private var recognitionLocale = Locale(identifier: "en-US")
    @ObservationIgnored private var localeIsCJK = false

    // 静默多久算一段结束（秒）。超过则提交当前段、补逗号、起新段。
    private let settleInterval: TimeInterval = 2.0
    // 单段连续识别上限（秒）。即便一直在说，超过也强制提交+重启 task，
    // 限制易失缓冲最大体量，并避开端侧识别 ~1 分钟硬上限。
    private let maxSegmentInterval: TimeInterval = 40.0

    func requestMicPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memo-\(UUID().uuidString).caf")
        audioURL = url

        let input = engine.inputNode
        input.removeTap(onBus: 0)

        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw NSError(
                domain: "VoiceRecorder", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Audio format not ready"]
            )
        }

        let state = TapState()
        state.file = try AVAudioFile(forWriting: url, settings: format.settings)
        tapState = state

        engine.prepare()
        try engine.start()

        startDate = Date()
        elapsed = 0
        liveTranscript = ""
        accumulated = ""
        pendingText = ""
        state.latestRMS = 0.04
        levels = Array(repeating: 0.04, count: Self.barCount)
        phase = .recording

        recognitionLocale = SpeechTranscriber.preferredLocale()
        localeIsCJK = SpeechTranscriber.isCJK(recognitionLocale)
        let sr = SFSpeechRecognizer(locale: recognitionLocale)
        recognizer = sr
        if let sr, sr.isAvailable { startContinuousRecognition() }

        let tapBlock = Self.makeTapBlock(state: state)
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: tapBlock)

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { [weak self] in self?.tick() }
            }
        }
    }

    // MARK: - 持续识别

    /// 启动一段识别 task。
    /// 端侧识别器在长静默后会重置内部状态、`formattedString` 不再含历史文本，
    /// 单条 task 全程跑会让"累积/重置"无法判别。改为：静默到阈值就提交当前段并
    /// **重启一条干净的 task**，每段都从零开始，显示 = 已提交段 + 当前段，不再靠猜。
    private func startContinuousRecognition() {
        guard let sr = recognizer, sr.isAvailable else { return }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.addsPunctuation = true
        if sr.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        tapState.request = req

        taskGeneration += 1
        let gen = taskGeneration
        segmentStartDate = Date()

        recognitionTask = sr.recognitionTask(with: req) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString ?? ""
            let isFinal = result?.isFinal ?? false

            DispatchQueue.main.async {
                MainActor.assumeIsolated { [weak self] in
                    // 已重启的旧 task 迟到回调直接丢弃
                    guard let self, self.phase == .recording, gen == self.taskGeneration else { return }
                    self.handleResult(text: text, isFinal: isFinal)
                }
            }
        }
    }

    private func handleResult(text: String, isFinal: Bool) {
        if !text.isEmpty, text != pendingText {
            // ── 第 1 层防护：识别器「假设重置/截断」检测 ──
            // 端侧识别器内部是滚动窗口，长语音会把开头的假设丢掉，
            // 导致 formattedString 突然大幅变短。若直接整体替换，前面一大段就被覆盖。
            // 检测到这种「变短且不再承接前缀」时，先把旧段落袋保住，再以新文本起新段。
            if isHypothesisReset(old: pendingText, new: text) {
                commitSegment()                 // 旧 pendingText 落进 accumulated，绝不丢
                pendingText = dedupedSeed(text) // 去掉与已落袋尾部的重叠后作为新段
            } else {
                pendingText = text
            }
            liveTranscript = joinedAccumulated(adding: pendingText)

            // 只在文本「真的变了」时才刷新静默计时；
            // 否则静默期反复吐相同部分结果会把计时器饿死、永不提交。
            settleTimer?.invalidate()
            settleTimer = Timer.scheduledTimer(withTimeInterval: settleInterval, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { [weak self] in
                        guard let self, self.phase == .recording else { return }
                        self.commitSegmentAndRestart()
                    }
                }
            }

            // ── 第 2 层防护：段缓冲封顶（兜底）──
            // 连续说话时 settleTimer 永远被重置、不会提交，整段都活在易失的 pendingText 里。
            // 这里强制限制单段时长：超过即提交并重启一条干净 task，把最大可能损失控制在一段内。
            if phase == .recording, Date().timeIntervalSince(segmentStartDate) > maxSegmentInterval {
                settleTimer?.invalidate()
                commitSegmentAndRestart()
                return
            }
        }

        // 识别器自己判定本段结束（finish() 或自然 final）→ 立即提交
        if isFinal {
            settleTimer?.invalidate()
            if phase == .recording {
                commitSegmentAndRestart()
            } else {
                commitSegment()
            }
        }
    }

    /// 判定新结果是否为识别器「重置/截断」而非正常修正。
    /// 正常修正：保留长前缀、只改末尾，二者共同前缀很长。
    /// 重置截断：丢掉开头 → 新文本明显更短，且与旧文本共同前缀很短。
    private func isHypothesisReset(old: String, new: String) -> Bool {
        guard !old.isEmpty, !new.isEmpty else { return false }
        let oldC = Array(old), newC = Array(new)
        guard oldC.count - newC.count >= 6 else { return false }   // 必须明显变短
        var cp = 0
        while cp < oldC.count, cp < newC.count, oldC[cp] == newC[cp] { cp += 1 }
        return Double(cp) < Double(newC.count) * 0.5               // 共同前缀短 → 不是承接
    }

    /// 去掉新段开头与「已落袋尾部」的重叠，避免重置边界处文字重复。
    private func dedupedSeed(_ seg: String) -> String {
        let trimmed = seg.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accumulated.isEmpty, !trimmed.isEmpty else { return trimmed }
        let tail = Array(accumulated.suffix(20))
        let head = Array(trimmed)
        let maxK = min(tail.count, head.count, 16)
        var k = maxK
        while k > 0 {
            if Array(tail.suffix(k)) == Array(head.prefix(k)) {
                return String(head.dropFirst(k))
            }
            k -= 1
        }
        return trimmed
    }

    /// 把一段文本拼到 accumulated 末尾。
    /// 上一段已有结尾标点：中日韩直接接，其它语言补空格；
    /// 没有结尾标点：中日韩补全角「，」，其它语言补「, 」。
    private func joinedAccumulated(adding segment: String) -> String {
        let seg = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !seg.isEmpty else { return accumulated }
        guard let last = accumulated.last else { return seg }

        let enders: Set<Character> = ["，", "。", "、", "！", "？", "；", "：", "…",
                                      ",", ".", "!", "?", ";", ":"]
        if enders.contains(last) {
            return localeIsCJK ? accumulated + seg : accumulated + " " + seg
        } else {
            return localeIsCJK ? accumulated + "，" + seg : accumulated + ", " + seg
        }
    }

    /// 把当前段提交进 accumulated（幂等：pendingText 为空则无操作）。
    private func commitSegment() {
        guard !pendingText.isEmpty else { return }
        accumulated = joinedAccumulated(adding: pendingText)
        pendingText = ""
        liveTranscript = accumulated
    }

    /// 提交当前段并重启一条干净的识别 task，承接下一段话。
    private func commitSegmentAndRestart() {
        commitSegment()
        recognitionTask?.cancel()
        recognitionTask = nil
        startContinuousRecognition()
    }

    // MARK: - tap / 生命周期

    nonisolated private static func makeTapBlock(
        state: TapState
    ) -> (AVAudioPCMBuffer, AVAudioTime) -> Void {
        return { buffer, _ in
            state.request?.append(buffer)
            try? state.file?.write(from: buffer)
            state.latestRMS = audioRMS(buffer)
        }
    }

    /// 被中断时保命：等价于 stop() 落盘（提交当前段、flush 音频文件、释放会话），
    /// 并标记 wasInterrupted。来电/闹钟/切后台/音频服务重置都会调它——
    /// 优先保证「已录到的内容不丢」，不尝试自动续录（短时日记场景，续录收益小、出错概率高）。
    func interruptAndSave() {
        guard phase == .recording else { return }
        wasInterrupted = true
        _ = stop()
    }

    @discardableResult
    func stop() -> URL? {
        // 先提交当前未保存的段
        settleTimer?.invalidate()
        settleTimer = nil
        commitSegment()

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        tapState.file = nil
        tapState.request = nil
        recognitionTask?.finish()
        recognitionTask = nil
        timer?.invalidate(); timer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        phase = .finished
        return audioURL
    }

    func discard() {
        settleTimer?.invalidate()
        settleTimer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine = AVAudioEngine()
        tapState.file = nil
        tapState.request = nil
        tapState = TapState()
        recognitionTask?.cancel()
        recognitionTask = nil
        timer?.invalidate(); timer = nil
        if let u = audioURL { try? FileManager.default.removeItem(at: u) }
        audioURL = nil
        elapsed = 0
        liveTranscript = ""
        accumulated = ""
        pendingText = ""
        phase = .idle
    }

    var timeString: String { String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60) }

    private func tick() {
        guard phase == .recording else { return }
        elapsed = Date().timeIntervalSince(startDate)
        levels.append(tapState.latestRMS)
        if levels.count > Self.barCount { levels.removeFirst() }
    }
}
