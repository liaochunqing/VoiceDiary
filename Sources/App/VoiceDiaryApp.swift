import SwiftUI
import SwiftData

@main
struct VoiceDiaryApp: App {
    @State private var container: ModelContainer?
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootView()
                        .modelContainer(container)
                        .environment(themeManager)
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
            DataManager.seedDemoIfNeeded(made.mainContext)
            DiaryFont.validateAllFonts()
            #endif
            container = made
            // 续期每日提醒的滚动调度窗口（多天非重复通知会用完）。
            NotificationManager().refreshScheduleIfNeeded()
        }
    }
}
