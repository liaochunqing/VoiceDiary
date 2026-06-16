import SwiftUI
import AVFoundation

/// 录音结果：交给写日记页决定如何落库。
struct VoiceResult {
    var audio: Data
    var duration: TimeInterval
    var transcript: String
    var insertText: Bool
    var keepAudio: Bool
}

/// 录音面板：准备 → 录音中 → 转写 → 预览选择去向。
struct RecordingView: View {
    @Environment(\.palette) private var pal
    let onDone: (VoiceResult?) -> Void

    private enum Stage { case prep, recording, transcribing, preview, denied }

    @State private var recorder = VoiceRecorder()
    @State private var stage: Stage = .prep
    @State private var transcript = ""
    @State private var duration: TimeInterval = 0
    @State private var audioData: Data?
    @State private var player: AVAudioPlayer?

    var body: some View {
        ZStack {
            pal.paper.ignoresSafeArea()
            switch stage {
            case .prep:         prepView
            case .denied:       deniedView
            case .recording:    recordingView
            case .transcribing: transcribingView
            case .preview:      previewView
            }
        }
        .task { await begin() }
    }

    // MARK: 阶段视图

    private var prepView: some View {
        VStack(spacing: Metric.m) {
            ProgressView()
            Text("正在准备麦克风…").font(.dSubhead).foregroundStyle(pal.inkSoft)
        }
    }

    private var deniedView: some View {
        VStack(spacing: Metric.l) {
            Image(systemName: "mic.slash").font(.system(size: 40)).foregroundStyle(pal.inkSoft)
            Text("需要麦克风权限").font(.dTitle).foregroundStyle(pal.ink)
            Text("请在「设置 › 隐私 › 麦克风」中允许翻页日记使用麦克风。录音只存在本机和你自己的 iCloud。")
                .font(.dSubhead).foregroundStyle(pal.inkSoft)
                .multilineTextAlignment(.center).padding(.horizontal, Metric.xl)
            Button("好") { onDone(nil) }.tint(pal.accent)
        }
    }

    private var recordingView: some View {
        VStack(spacing: Metric.xl) {
            HStack {
                Button { recorder.discard(); onDone(nil) } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(pal.ink).frame(width: 34, height: 34)
                        .background(pal.card, in: Circle())
                }
                Spacer()
                Text("正在录音").font(.dCallout).foregroundStyle(pal.ink)
                Spacer()
                Color.clear.frame(width: 34, height: 34)
            }
            .padding(.horizontal, Metric.l).padding(.top, Metric.l)

            Spacer()
            Text(recorder.timeString)
                .font(.system(size: 44, weight: .bold)).monospacedDigit()
                .foregroundStyle(pal.ink)
            WaveformView(levels: recorder.levels, color: pal.accent)
                .frame(height: 64).padding(.horizontal, Metric.xl)
            Text("说完点下面的按钮，文字会自动整理")
                .font(.dCaption).foregroundStyle(pal.inkSoft)
            Spacer()

            Button { finish() } label: {
                ZStack {
                    Circle().fill(Color(hex: 0xD9534F)).frame(width: 72, height: 72)
                        .shadow(color: Color(hex: 0xD9534F).opacity(0.5), radius: 12, y: 4)
                    RoundedRectangle(cornerRadius: 6).fill(.white).frame(width: 26, height: 26)
                }
            }
            Label("转写在本机完成，音频不上传", systemImage: "lock.fill")
                .font(.dCaption).foregroundStyle(pal.inkSoft)
                .padding(.bottom, Metric.xl)
        }
    }

    private var transcribingView: some View {
        VStack(spacing: Metric.m) {
            ProgressView()
            Text("正在本机整理文字…").font(.dSubhead).foregroundStyle(pal.inkSoft)
        }
    }

    private var previewView: some View {
        VStack(spacing: Metric.m) {
            HStack {
                Text("这段录音").font(.dTitle).foregroundStyle(pal.ink)
                Spacer()
            }
            .padding(.horizontal, Metric.l).padding(.top, Metric.l)

            VStack(alignment: .leading, spacing: Metric.s) {
                Text("识别文字（可编辑）").font(.dCaption).foregroundStyle(pal.inkSoft)
                TextEditor(text: $transcript)
                    .font(.dBody).foregroundStyle(pal.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
            }
            .padding(Metric.m)
            .background(pal.card, in: RoundedRectangle(cornerRadius: Metric.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(pal.line, lineWidth: 1))
            .padding(.horizontal, Metric.l)

            voiceBar.padding(.horizontal, Metric.l)

            Spacer()

            VStack(spacing: Metric.s) {
                Button { done(insert: true, keep: false) } label: { primaryLabel("插入正文") }
                HStack(spacing: Metric.s) {
                    Button { done(insert: false, keep: true) } label: { secondaryLabel("仅存语音") }
                    Button { done(insert: true, keep: true) } label: { secondaryLabel("两者都要") }
                }
                Button { redo() } label: {
                    Text("重录").font(.dSubhead).foregroundStyle(pal.inkSoft)
                }
                .padding(.top, Metric.xs)
            }
            .padding(.horizontal, Metric.l).padding(.bottom, Metric.xl)
        }
    }

    private var voiceBar: some View {
        HStack(spacing: Metric.s) {
            Button { togglePlay() } label: {
                Image(systemName: player?.isPlaying == true ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(pal.onAccent)
                    .frame(width: 28, height: 28).background(pal.accent, in: Circle())
            }
            WaveformView(levels: recorder.levels, color: pal.accent.opacity(0.7))
                .frame(height: 24)
            Text(durString(duration)).font(.dCaption).foregroundStyle(pal.inkSoft)
        }
        .padding(Metric.m)
        .background(pal.card, in: RoundedRectangle(cornerRadius: Metric.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(pal.line, lineWidth: 1))
    }

    private func primaryLabel(_ t: String) -> some View {
        Text(t).font(.dCallout.weight(.semibold)).foregroundStyle(pal.onAccent)
            .frame(maxWidth: .infinity).padding(.vertical, Metric.m)
            .background(pal.accent, in: RoundedRectangle(cornerRadius: Metric.buttonRadius))
    }
    private func secondaryLabel(_ t: String) -> some View {
        Text(t).font(.dCallout).foregroundStyle(pal.ink)
            .frame(maxWidth: .infinity).padding(.vertical, Metric.m)
            .background(pal.card, in: RoundedRectangle(cornerRadius: Metric.buttonRadius))
            .overlay(RoundedRectangle(cornerRadius: Metric.buttonRadius).stroke(pal.line, lineWidth: 1))
    }

    // MARK: 逻辑

    private func begin() async {
        guard stage == .prep else { return }
        let mic = await recorder.requestMicPermission()
        _ = await SpeechTranscriber.requestAuthorization()
        guard mic else { stage = .denied; return }
        do { try recorder.start(); stage = .recording }
        catch { stage = .denied }
    }

    private func finish() {
        let url = recorder.stop()
        duration = recorder.elapsed
        stage = .transcribing
        Task {
            if let url { audioData = try? Data(contentsOf: url) }
            let text = url != nil ? await SpeechTranscriber.transcribe(url: url!) : ""
            transcript = text
            stage = .preview
        }
    }

    private func redo() {
        player?.stop(); player = nil
        recorder.discard()
        transcript = ""; duration = 0; audioData = nil
        stage = .prep
        Task { await begin() }
    }

    private func togglePlay() {
        if player?.isPlaying == true { player?.pause(); return }
        if player == nil, let data = audioData {
            player = try? AVAudioPlayer(data: data)
        }
        player?.play()
    }

    private func done(insert: Bool, keep: Bool) {
        player?.stop()
        onDone(VoiceResult(audio: audioData ?? Data(), duration: duration,
                           transcript: transcript, insertText: insert, keepAudio: keep))
    }

    private func durString(_ d: TimeInterval) -> String {
        String(format: "%d:%02d", Int(d) / 60, Int(d) % 60)
    }
}

// MARK: - WaveformView

struct WaveformView: View {
    let levels: [CGFloat]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 3) {
                ForEach(levels.indices, id: \.self) { i in
                    Capsule().fill(color)
                        .frame(maxWidth: .infinity)
                        .frame(height: max(3, levels[i] * geo.size.height))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}
