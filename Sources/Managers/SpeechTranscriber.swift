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

    /// 用户在设置里手动指定转写语言的 UserDefaults key（空串 = 自动跟随系统）。
    static let overrideKey = "transcriptionLanguage"

    /// 选取识别语言：
    /// 1) 用户在设置里手动选了、且该语言端侧可用 → 用它；
    /// 2) 否则跟随设备首选语言，限定在「端侧可用」范围内（隐私红线）；
    /// 3) 再不行回退英文 / 中文，最终兜底英文。
    static func preferredLocale() -> Locale {
        if let override = UserDefaults.standard.string(forKey: overrideKey), !override.isEmpty {
            let loc = Locale(identifier: override)
            if let r = SFSpeechRecognizer(locale: loc), r.supportsOnDeviceRecognition {
                return loc
            }
        }
        for lang in Locale.preferredLanguages {
            let cand = Locale(identifier: lang)
            if let r = SFSpeechRecognizer(locale: cand), r.isAvailable, r.supportsOnDeviceRecognition {
                return cand
            }
        }
        for id in ["en-US", "zh-CN"] {
            let l = Locale(identifier: id)
            if let r = SFSpeechRecognizer(locale: l), r.isAvailable, r.supportsOnDeviceRecognition {
                return l
            }
        }
        return Locale(identifier: "en-US")
    }

    /// 设备上「端侧模型已安装」的识别语言列表，按本地化名去重排序，用于设置页选单。
    static func availableOnDeviceLocales() -> [Locale] {
        var seen = Set<String>()
        var result: [Locale] = []
        for loc in SFSpeechRecognizer.supportedLocales() {
            guard !seen.contains(loc.identifier),
                  let r = SFSpeechRecognizer(locale: loc), r.supportsOnDeviceRecognition
            else { continue }
            seen.insert(loc.identifier)
            result.append(loc)
        }
        return result.sorted {
            let a = Locale.current.localizedString(forIdentifier: $0.identifier) ?? $0.identifier
            let b = Locale.current.localizedString(forIdentifier: $1.identifier) ?? $1.identifier
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }

    /// 该 locale 是否为中日韩（无词间空格、用全角标点）。
    static func isCJK(_ locale: Locale) -> Bool {
        guard let code = locale.language.languageCode?.identifier else { return false }
        return ["zh", "ja", "ko", "yue"].contains(code)
    }

    /// 转写录音文件，返回识别文本（失败返回空串）。全程本机完成。
    static func transcribe(url: URL, locale: Locale? = nil) async -> String {
        let loc = locale ?? preferredLocale()
        guard let recognizer = SFSpeechRecognizer(locale: loc), recognizer.isAvailable else { return "" }
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
