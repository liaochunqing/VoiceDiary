//
//  SettingsView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/9/2.
//

import Foundation
import SwiftUI
import SwiftData

struct SettingsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case month = "本月"
        case year = "本年"
        case all = "全部"
        
        var id: String { self.rawValue }
    }

    @State private var selectedTab: Tab = .month
    @Query(sort: \DiaryEntry.date, order: .reverse) private var allEntries: [DiaryEntry]

    private var filteredEntries: [DiaryEntry] {
        switch selectedTab {
        case .month:
            return allEntries.filter {
                Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
            }
        case .year:
            return allEntries.filter {
                Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .year)
            }
        case .all:
            return allEntries
        }
    }
    
    var body: some View {
        ZStack{
            Color(.secondarySystemBackground)
                .ignoresSafeArea()
                
            VStack
            {
                
                Text("设置")
                    .font(.title)
                    .foregroundColor(.black)
//                    .background(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
//                    .padding(.top)//
                
                Text("心情储蓄罐")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity,alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .padding(.top)
                
                EmojiBubbleView(
                    width: Screen.width - 2 * W_SCALE(16),
                    height: H_SCALE(200),
                    emojis: ["🥳", "😊", "😢", "😡", "😭", "🤯",
                             "😴", "🤔", "😤", "😄", "😊", "😢",
                             "😡", "😭", "🤯", "😴", "🤔", "😤",
                             "😄", "😊", "😢", "😡", "😭", "🤯",
                             "😴", "🤔", "😤", "😄", "😭", "🤯"],
                    emojiSize: W_SCALE(20),
                    gravityScale: 20.0
                )
                
                VStack(spacing: H_SCALE(16)) {
                    HStack {
                        Text("心情时间段")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
//
                        
//                        Spacer()
                        // 顶部 Segment 控制
                        Picker("筛选", selection: $selectedTab) {
                            ForEach(Tab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    HStack {
                        Text("emjo大小")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        // 顶部 Segment 控制
                        Picker("筛选", selection: $selectedTab) {
                            ForEach(Tab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal)

                    HStack {
                        Text("emjio旋转")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        // 顶部 Segment 控制
                        Picker("筛选", selection: $selectedTab) {
                            ForEach(Tab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal)
                    .padding(.bottom)

                }
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 4, y: 4)
                .shadow(color: Color.white.opacity(0.7), radius: 4, x: -4, y: -4)
//                .padding()
                
                Spacer()
               
            }
            .padding(.horizontal)

        }
        
    }
}

#Preview {
    ContentView()
        .environmentObject(GlobalData())
        .modelContainer(

            try! ModelContainer(
                        for: DiaryEntry.self,
                        configurations: ModelConfiguration(
                            isStoredInMemoryOnly: true  // 内存存储不污染正式数据
                        )
                    )
                )

}
