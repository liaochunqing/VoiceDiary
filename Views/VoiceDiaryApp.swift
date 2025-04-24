//
//  VoiceDiaryApp.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/8/30.
//

import SwiftUI
import SwiftData

@main
struct VoiceDiaryApp: App {
    @StateObject private var globalData = GlobalData()
        
//        var sharedModelContainer: ModelContainer = {
//            let schema = Schema([DiaryEntry.self])
//            
//            let configuration = ModelConfiguration(
//                "VoiceDioryModel",
//                schema: schema,
//                isStoredInMemoryOnly: false,
//                cloudKitDatabase: .private("iCloud.com.chunqingliao.VoiceDiary") // 需替换为你的 Team ID 和 Bundle ID
//            )
//            
//            do {
//                return try ModelContainer(for: schema, configurations: [configuration])
//            } catch {
//                fatalError("Failed to create ModelContainer: \(error)")
//            }
//        }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for:[DiaryEntry.self])
                .environmentObject(globalData)

        }
    }
}
