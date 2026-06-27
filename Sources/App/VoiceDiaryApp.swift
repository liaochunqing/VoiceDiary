import SwiftUI
import SwiftData
import MetricKit
import UIKit

@main
struct VoiceDiaryApp: App {
    @State private var container: ModelContainer?
    @State private var themeManager = ThemeManager()
    @State private var deletionCoordinator = DeletionCoordinator()

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootView()
                        .modelContainer(container)
                        .environment(themeManager)
                        .environment(deletionCoordinator)
                        .environment(\.palette, themeManager.palette)
                        .tint(themeManager.palette.accent)
                } else {
                    ZStack {
                        Color(lightHex: 0xF5EBD5, darkHex: 0x1E1810).ignoresSafeArea()
                        ProgressView()
                    }
                    .task { await makeContainer() }
                }
            }
        }
    }

    @MainActor
    private func makeContainer() async {
        let cloudID = "iCloud.com.chunqingliao.VoiceDiary"
        let iCloudOn = UserDefaults.standard.bool(forKey: "iCloudEnabled")
        // 「同步录音」：键缺失默认 true（开了 iCloud 即默认连录音一起同步，注重隐私者可在设置关闭）
        let audioSyncOn = UserDefaults.standard.object(forKey: "audioSyncEnabled") as? Bool ?? true

        let fullSchema = Schema([DiaryEntry.self, VoiceMemo.self, VoiceAudio.self])

        // 主库（日记+元数据）与音频库各自独立决定是否同步 → 「同步录音」开关只影响音频库。
        func configs(cloud: Bool, audioCloud: Bool) -> [ModelConfiguration] {
            [
                ModelConfiguration("Main", schema: Schema([DiaryEntry.self, VoiceMemo.self]),
                                   cloudKitDatabase: cloud ? .private(cloudID) : .none),
                ModelConfiguration("Audio", schema: Schema([VoiceAudio.self]),
                                   cloudKitDatabase: audioCloud ? .private(cloudID) : .none)
            ]
        }

        let made = (try? ModelContainer(for: fullSchema,
                                        configurations: configs(cloud: iCloudOn, audioCloud: iCloudOn && audioSyncOn)))
            ?? (try? ModelContainer(for: fullSchema,
                                    configurations: configs(cloud: false, audioCloud: false)))
        if let made {
            DiaryFont.registerCustomFonts()
            #if DEBUG
            ScreenshotSeeder.seedIfRequested(made.mainContext)
            ScreenshotSeeder.seedChineseIfRequested(made.mainContext)
            DataManager.seedDemoIfNeeded(made.mainContext)
            DiaryFont.validateAllFonts()
            #endif
            container = made
            // 预热键盘：iOS 首次弹出键盘冷启动 ~0.5–1s，用隐藏 UITextField
            // 提前触发一次 becomeFirstResponder 再立刻 resign，把初始化成本摊到后台。
            preWarmKeyboard()
            // 续期每日提醒的滚动调度窗口（多天非重复通知会用完）。
            NotificationManager().refreshScheduleIfNeeded()
            // 订阅 MetricKit：崩溃/卡顿/耗电数据自动进入 Xcode Organizer。
            MXMetricManager.shared.add(MetricSubscriber.shared)
        }
    }
}

// MARK: - 键盘预热

/// App 启动时预热键盘：iOS 首次弹出键盘有 ~0.5–1s 冷启动延迟（加载键盘扩展），
/// 此后键盘驻留内存即秒出。用隐藏 UITextField 提前触发一次 becomeFirstResponder
/// 再立刻 resign，把冷启动成本摊到后台，编辑器首次打开就不卡了。
@MainActor
private func preWarmKeyboard() {
    let field = UITextField(frame: .zero)
    field.isHidden = true
    field.autocorrectionType = .no

    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else { return }

    window.addSubview(field)
    field.becomeFirstResponder()

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        field.resignFirstResponder()
        field.removeFromSuperview()
    }
}

// MARK: - MetricKit 订阅

/// MetricKit 要求 `NSObject` 子类，故单独抽一个 helper。
/// 数据自动进入 Xcode Organizer（无需额外代码）；DEBUG 下额外写 Caches 方便检查。
final class MetricSubscriber: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = MetricSubscriber()

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        #if DEBUG
        for p in payloads {
            logJSON(p.jsonRepresentation(), tag: "metric")
        }
        #endif
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        #if DEBUG
        for p in payloads {
            logJSON(p.jsonRepresentation(), tag: "diagnostic")
        }
        #endif
    }

    #if DEBUG
    private nonisolated func logJSON(_ data: Data, tag: String) {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
        let file = dir.appendingPathComponent("metrickit-\(tag)-\(stamp).json")
        try? data.write(to: file)
    }
    #endif
}
