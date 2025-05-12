//
//  SettingsView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/9/2.
//

import Foundation
import SwiftUI
import SwiftData
import StoreKit


struct SettingsView: View {
    @State private var selectedTimeRange: TimeRangeTab = .month
    @State private var selectedTab: Tab = .mid
    @State private var selectedSpeed: Speed = .mid
    @State private var showRestartAlert = false

    @State private var emojis: [String] = []
    @State private var emojisSize: CGFloat = W_SCALE(20)
    @State private var isRotationEnabled = true
    @State private var gravityScale: CGFloat = W_SCALE(10)
    @State private var isThemeChanged = false
    
    @State private var currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
    @State private var appStoreVersion: String = ""
    @State private var updateAvailable: Bool = false
    
    @Environment(\.openURL) var openURL
    @AppStorage("selectedTheme") private var selectedTheme: AppTheme = .light
    
    let rightButtonSize = W_SCALE(36)
    let appID = "6670278331" //
    let appURL = URL(string: "https://apps.apple.com/app/6670278331")! //

    
    @AppStorage("iCloudEnabled") private var iCloudEnabled = false
    @AppStorage("isFaceIDEnabled") private var isFaceIDEnabled = false
    @AppStorage("isSoundEnabled") private var isSoundEnabled: Bool = true

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack{
            Color(.systemBackground)
                .ignoresSafeArea()
            
            // 包裹 VStack 的 ScrollView 以启用垂直滚动
            ScrollView {
                VStack
                {
                    Text("设置")
                        .font(.title)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    
                    
                    Text("emoji储蓄罐")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                        gravityScale: gravityScale,
                        isThemeChanged: isThemeChanged
                    )
                                        
                    emojiSetup
                    
                    Text("通用")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity,alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .padding(.top)
                        .padding(.top)
                        .padding(.leading)

                    generalSetup
                    
                    Text("支持")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity,alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .padding(.top)
                        .padding(.top)
                        .padding(.leading)

                    supportSetup
                    
                    Text("其他作品")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity,alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .padding(.top)
                        .padding(.top)
                        .padding(.leading)

                    otherProduct
                    
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
                    .foregroundStyle(.primary)
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
                    .foregroundStyle(.primary)
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
                    .foregroundStyle(.primary)
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
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                Spacer()
                
                Toggle("", isOn: $isRotationEnabled)
                
            }
            .padding(.horizontal)
            .padding(.bottom)

        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(W_SCALE(15))
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)

    }
    
    private var generalSetup: some View {

        VStack(spacing: H_SCALE(16)) {
            HStack {
                Text("主题外观")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Picker("", selection: $selectedTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedTheme) {
                        isThemeChanged = !isThemeChanged
                        }
            }
            .padding(.horizontal)
            .padding(.top)
            
            HStack {
                Text("iCloud同步")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Toggle("", isOn: $iCloudEnabled)
                .onChange(of: iCloudEnabled) {
                    showRestartAlert = true
                    }
                .alert("需要重启应用", isPresented: $showRestartAlert) {
                            Button("知道了", role: .cancel) { }
                        } message: {
                            Text("重启app才能生效")
                        }
            }
            .padding(.horizontal)
//            .padding(.top)
            
            HStack {
                Text("翻页声效")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Toggle("", isOn: $isSoundEnabled)
            }
            .padding(.horizontal)
                        
            HStack {
                Text("面容ID")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Toggle("", isOn: $isFaceIDEnabled)
                .onChange(of: isFaceIDEnabled) {
                                        // 提示用户重启应用以应用更改
                }
            }
            .padding(.horizontal)
            .padding(.bottom)

        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(W_SCALE(15))
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
        
    }
    
    private var supportSetup: some View {
        VStack(spacing: H_SCALE(25)) {
            HStack {
                Text("意见反馈")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Button(action: { }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: rightButtonSize, height: rightButtonSize)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.black)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            HStack {
                Text("分享给朋友")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                ShareLink(item: appURL) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: rightButtonSize, height: rightButtonSize)
                                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.black)
                                }
                            }
            }
            .padding(.horizontal)
            
            HStack {
                Text("给好评")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Button(action: {
                    // 方法一：弹出评分提示
                    if let scene = UIApplication.shared.connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                    }

                    // 方法二：跳转到 App Store 的评价页面
                    /*
                    if let url = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                    */
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: rightButtonSize, height: rightButtonSize)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.black)
                    }
                }
                
            }
            .padding(.horizontal)
            
            HStack {
                Text("当前版本")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                if updateAvailable {
                    Button(action: {
                        // 跳转到 App Store 更新页面
                        if let url = URL(string: "https://apps.apple.com/\(appID))") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("去更新")
                            .foregroundColor(.blue)
                    }
                } else {
                    Text("\(currentVersion) (已是最新)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
            .onAppear {
                fetchAppStoreVersion { version in
                    DispatchQueue.main.async {
                        if let version = version {
                            self.appStoreVersion = version
                            self.updateAvailable = version.compare(self.currentVersion, options: .numeric) == .orderedDescending
                        }
                    }
                }
            }

        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(W_SCALE(15))
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
    }
    
    private var otherProduct: some View {

        VStack(spacing: H_SCALE(16)) {
            HStack {
                Image("sleep") // 替换为你的图片名称
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: W_SCALE(40), maxHeight: W_SCALE(40))
                    .cornerRadius(8)
                
                VStack{
                    Text("睡眠伙伴")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Text("专注睡眠的音乐和白噪音")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Button(action: { }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: rightButtonSize, height: rightButtonSize)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.black)
                    }
                }
                
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(W_SCALE(15))
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
        .onTapGesture {
            if let url = URL(string: "https://apps.apple.com/app/6504686224") {
                                openURL(url)
                            }
        }
    }

    func fetchAppStoreVersion(completion: @escaping (String?) -> Void) {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)") else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let appStoreVersion = results.first?["version"] as? String else {
                completion(nil)
                return
            }
            completion(appStoreVersion)
        }.resume()
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

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .system: return "自动"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
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
