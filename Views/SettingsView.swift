//
//  SettingsView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/9/2.
//

import Foundation
import SwiftUI
import SwiftData
enum TimeRangeTab: String, CaseIterable, Identifiable {
    case month = "本月"
    case year = "本年"
    case all = "全部"
    
    var id: String { self.rawValue }
}

enum Tab: String, CaseIterable, Identifiable {
    case small = "小"
    case mid = "中"
    case big = "大"
    
    var id: String { self.rawValue }
}

enum Speed: String, CaseIterable, Identifiable {
    case small = "慢"
    case mid = "中"
    case big = "快"
    
    var id: String { self.rawValue }
}

struct SettingsView: View {
    @State private var selectedTimeRange: TimeRangeTab = .month
    @State private var selectedTab: Tab = .mid
    @State private var selectedSpeed: Speed = .mid

    @State private var emojis: [String] = []
    @State private var emojisSize: CGFloat = W_SCALE(20)
    @State private var isRotationEnabled = false
    @State private var gravityScale: CGFloat = W_SCALE(10)

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack{
            Color(.secondarySystemBackground)
                .ignoresSafeArea()
                
            VStack
            {
                
                Text("设置")
                    .font(.title)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Text("emoji储蓄罐")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity,alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .padding(.top)
                
                EmojiBubbleView(
                    width: Screen.width - 2 * W_SCALE(16),
                    height: H_SCALE(170),
                    emojis: emojis,
                    emojiSize: emojisSize,
                    isRotationEnabled:isRotationEnabled,
                    gravityScale: gravityScale
                )
                
                VStack(spacing: H_SCALE(16)) {
                    HStack {
                        Text("emoji时间段")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        
                        Picker("", selection: $selectedTimeRange) {
                            ForEach(TimeRangeTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: selectedTimeRange) {
                            let timeRange: TimeRange
                            switch selectedTimeRange {
                            case .month:
                                timeRange = .month
                            case .year:
                                timeRange = .year
                            case .all:
                                timeRange = .all
                            }
                            emojis = DataManager.fetchEmojis(for: timeRange, in: modelContext)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    HStack {
                        Text("emoji大小")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        // 顶部 Segment 控制
                        Picker("", selection: $selectedTab) {
                            ForEach(Tab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: selectedTab) {

                            switch selectedTab {
                            case .small:
                                emojisSize = W_SCALE(10)
                            case .mid:
                                emojisSize = W_SCALE(20)
                            case .big:
                                emojisSize = W_SCALE(40)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Text("重力加速度")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        // 顶部 Segment 控制
                        Picker("", selection: $selectedSpeed) {
                            ForEach(Speed.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: selectedSpeed) {
                            switch selectedSpeed {
                            case .small:
                                gravityScale = W_SCALE(1)
                            case .mid:
                                gravityScale = W_SCALE(10)
                            case .big:
                                gravityScale = W_SCALE(25)
                            }
                        }
                    }
                    .padding(.horizontal)

                    HStack {
                        Text("emoji旋转")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Toggle("", isOn: $isRotationEnabled)
                        
                    }
                    .padding(.horizontal)
                    .padding(.bottom)

                }
                .background(Color.white)
                .cornerRadius(W_SCALE(15))
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)


                Spacer()
               
            }
            .padding(.horizontal)

        }
        .onAppear {
            emojis = DataManager.fetchEmojis(for: .month, in: modelContext)
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
