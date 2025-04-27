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
    @State private var isRotationEnabled = true
    @State private var gravityScale: CGFloat = W_SCALE(10)
    
    let rightButtonSize = W_SCALE(25)
    
    @AppStorage("iCloudEnabled") private var iCloudEnabled = false
    @AppStorage("isFaceIDEnabled") private var isFaceIDEnabled = false
    @AppStorage("isSoundEnabled") private var isSoundEnabled: Bool = true

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack{
            Color(.secondarySystemBackground)
                .ignoresSafeArea()
            
            // 包裹 VStack 的 ScrollView 以启用垂直滚动
            ScrollView {
                VStack
                {
                    Text("设置")
                        .font(.title)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    
                    Text("emoji储蓄罐")
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))
                        .frame(maxWidth: .infinity,alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .padding(.top)
                        .padding(.leading)
                    
                    EmojiBubbleView(
                        width: Screen.width - 2 * W_SCALE(16),
                        height: H_SCALE(170),
                        emojis: emojis,
                        emojiSize: emojisSize,
                        isRotationEnabled:isRotationEnabled,
                        gravityScale: gravityScale
                    )
                                        
                    emojiSetup
                    
                    Text("通用")
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))
                        .frame(maxWidth: .infinity,alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .padding(.top)
                        .padding(.top)
                        .padding(.leading)

                    generalSetup
                    
                    Text("支持")
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))
                        .frame(maxWidth: .infinity,alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .padding(.top)
                        .padding(.top)
                        .padding(.leading)

                    supportSetup
                    
                    Spacer()
                   
                }
                .padding(.horizontal)
            }

        }
        .onAppear {
            emojis = DataManager.fetchEmojis(for: .month, in: modelContext)
            }
    }
    
    // MARK: - 子视图组件
    private var emojiSetup: some View {
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
                        gravityScale = W_SCALE(35)
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

    }
    
    private var generalSetup: some View {
        VStack(spacing: H_SCALE(16)) {
            HStack {
                Text("iCloud同步")
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Toggle("", isOn: $iCloudEnabled)
                .onChange(of: iCloudEnabled) {
                                        // 提示用户重启应用以应用更改
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            HStack {
                Text("翻页声效")
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Toggle("", isOn: $isSoundEnabled)
            }
            .padding(.horizontal)
            
            HStack {
                Text("面容ID")
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Toggle("", isOn: $isFaceIDEnabled)
                .onChange(of: isFaceIDEnabled) {
                                        // 提示用户重启应用以应用更改
                }
            }
            .padding(.horizontal)

        }
        .background(Color.white)
        .cornerRadius(W_SCALE(15))
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
        
    }
    
    private var supportSetup: some View {
        VStack(spacing: H_SCALE(25)) {
            HStack {
                Text("意见反馈")
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Button(action: { }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: rightButtonSize, height: rightButtonSize)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            HStack {
                Text("分享给朋友")
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Button(action: { }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: rightButtonSize, height: rightButtonSize)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.horizontal)
            
            HStack {
                Text("给好评")
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Button(action: { }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: rightButtonSize, height: rightButtonSize)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.horizontal)
            
            HStack {
                Text("其他作品")
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Button(action: { }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: rightButtonSize, height: rightButtonSize)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)

        }
        .background(Color.white)
        .cornerRadius(W_SCALE(15))
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
    }
}

import LocalAuthentication

class BiometricAuthManager {
    func authenticate(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        // 检查设备是否支持生物识别
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "请使用面容ID解锁应用。"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            // 设备不支持生物识别
            DispatchQueue.main.async {
                completion(false)
            }
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
