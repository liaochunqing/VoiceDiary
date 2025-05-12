//
//  VoiceDiaryApp.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/8/30.
//

import SwiftUI
import SwiftData
import CloudKit

@main
struct VoiceDiaryApp: App {
    @State private var modelContainer: ModelContainer?

    @StateObject private var globalData = GlobalData()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var emojiSettings = EmojiSettings()

    init() {
            UserDefaults.standard.register(defaults: ["isSoundEnabled": true])
//        UserDefaults.standard.register(defaults: ["showLocation": true])
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                ContentView()
                    .modelContainer(modelContainer)
                    .environmentObject(globalData)
                    .environmentObject(locationManager)
                    .environmentObject(emojiSettings)

            } else {
                ProgressView("Loading...")
                    .task {
                        await initializeModelContainer()
                    }
            }
        }
    }
    
    func initializeModelContainer() async {
            let schema = Schema([DiaryEntry.self])

            let iCloudEnabled = UserDefaults.standard.bool(forKey: "iCloudEnabled")
        
            let configuration: ModelConfiguration
            if iCloudEnabled {
                configuration = ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .private("iCloud.com.chunqingliao.VoiceDiary")
                )
            } else {
                configuration = ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .none
                )
            }

            do {
                let container = try ModelContainer(for: schema, configurations: [configuration])
                modelContainer = container
            } catch {
                print("Failed to create ModelContainer: \(error)")
            }
        }
}
