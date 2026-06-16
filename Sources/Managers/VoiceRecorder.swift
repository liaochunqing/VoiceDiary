import AVFoundation
import Observation

/// 语音录制器：AVAudioRecorder 录 m4a，实时取电平做波形与计时。
/// iOS 17 `@Observable` + `AVAudioApplication` 新权限 API，主线程隔离。
@MainActor
@Observable
final class VoiceRecorder {
    enum Phase { case idle, recording, finished }

    var phase: Phase = .idle
    var elapsed: TimeInterval = 0
    /// 最近一段归一化电平（0...1），用于波形动画。
    var levels: [CGFloat] = Array(repeating: 0.04, count: barCount)
    private(set) var audioURL: URL?

    static let barCount = 42

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    /// 请求麦克风权限（iOS 17 新 API）。
    func requestMicPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memo-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,                       // 单声道，省空间利于 iCloud 同步
            AVEncoderBitRateKey: 48_000,                    // 低码率，约 360KB/分钟
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let r = try AVAudioRecorder(url: url, settings: settings)
        r.isMeteringEnabled = true
        r.record()

        recorder = r
        audioURL = url
        elapsed = 0
        levels = Array(repeating: 0.04, count: Self.barCount)
        phase = .recording

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard let r = recorder, r.isRecording else { return }
        r.updateMeters()
        let power = r.averagePower(forChannel: 0)            // dBFS，约 -160...0
        let norm = max(0.04, min(1, CGFloat(pow(10, power / 40))))
        levels.append(norm)
        if levels.count > Self.barCount { levels.removeFirst() }
        elapsed = r.currentTime
    }

    @discardableResult
    func stop() -> URL? {
        recorder?.stop()
        timer?.invalidate(); timer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        phase = .finished
        return audioURL
    }

    /// 放弃当前录音并删除临时文件。
    func discard() {
        recorder?.stop()
        timer?.invalidate(); timer = nil
        if let u = audioURL { try? FileManager.default.removeItem(at: u) }
        recorder = nil; audioURL = nil; elapsed = 0; phase = .idle
    }

    var timeString: String { String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60) }
}
