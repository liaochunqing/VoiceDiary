import SwiftUI
import SwiftData

@main
struct VoiceDiaryApp: App {
    @State private var container: ModelContainer?
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
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

    @MainActor
    private func makeContainer() async {
        let schema = Schema([DiaryEntry.self, VoiceMemo.self])
        let iCloudOn = UserDefaults.standard.bool(forKey: "iCloudEnabled")
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: iCloudOn ? .private("iCloud.com.chunqingliao.VoiceDiary") : .none
        )
        let made = (try? ModelContainer(for: schema, configurations: [config]))
            ?? (try? ModelContainer(for: schema,
                                    configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .none)]))
        if let made {
            #if DEBUG
            DataManager.seedDemoIfNeeded(made.mainContext)
            #endif
            container = made
        }
    }
}
