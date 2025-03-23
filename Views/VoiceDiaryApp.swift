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
        
        var sharedModelContainer: ModelContainer = {
            let schema = Schema([DiaryEntry.self])
            
            // ✅ 关键修复：明确指定容器名称
            let configuration = ModelConfiguration(
                "VoiceDiaryModel",  // 任意非空名称
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .environmentObject(globalData)

        }
    }
}
