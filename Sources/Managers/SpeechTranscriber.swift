@preconcurrency import Speech
import os

/// 端侧语音转写。强制 on-device，绝不经过网络/第三方。
enum SpeechTranscriber {
    /// 请求语音识别权限。
    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
    }

    /// 转写录音文件，返回识别文本（失败返回空串）。全程本机完成。
    static func transcribe(url: URL, locale: Locale = Locale(identifier: "zh-CN")) async -> String {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else { return "" }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true   // 红线：不走网络
        }
        // 回调可能多次触发（partial/final/error），用 Sendable 安全锁保证只 resume 一次。
        let resumed = OSAllocatedUnfairLock(initialState: false)
        return await withCheckedContinuation { cont in
            recognizer.recognitionTask(with: request) { result, error in
                let shouldResume: String? = resumed.withLock { done in
                    guard !done else { return nil }
                    if let result, result.isFinal {
                        done = true
                        return result.bestTranscription.formattedString
                    } else if error != nil {
                        done = true
                        return ""
                    }
                    return nil
                }
                if let text = shouldResume { cont.resume(returning: text) }
            }
        }
    }
}
