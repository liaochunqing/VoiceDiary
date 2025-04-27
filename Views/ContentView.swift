//
//  ContentView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/8/30.
//

import SwiftUI
import SwiftData

struct ContentView: View {

    @AppStorage("isFaceIDEnabled") private var isFaceIDEnabled = false
    @State private var isUnlocked = false
    private let authManager = BiometricAuthManager()
    
    var body: some View {
        Group {
            if isUnlocked || !isFaceIDEnabled {
                // 显示主界面内容
                MainAppView()
            } else {
                // 显示锁定界面
                Text("应用已锁定，请进行面容 ID 验证。")
            }
        }
        .onAppear {
            if isFaceIDEnabled {
                authManager.authenticate { success in
                    self.isUnlocked = success
                }
            } else {
                self.isUnlocked = true
            }
        }
    }
}

struct MainAppView: View {
    
    @State private var buttonPosition: CGPoint = .zero
    @State private var isButtonInitialized = false
    @State private var showAddDiaryView = false
    @EnvironmentObject var globalData: GlobalData
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 主内容视图
                DiaryView()
                    .background(Color(.secondarySystemBackground))  // 使用系统默认背景颜色
                
                // 可拖动的悬浮按钮
                if globalData.hideAddButton == false {
                    AddButton(iconName: "plus")
                        .position(buttonPosition)
                        .onTapGesture
                        {
                            showAddDiaryView = true
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let safeAreaInsets = geometry.safeAreaInsets
                                    let minY = safeAreaInsets.top + 30
                                    let maxY = Screen.height - safeAreaInsets.bottom - 30
                                    let newY = min(max(value.location.y, minY), maxY)
                                    buttonPosition = CGPoint(x: value.location.x, y: newY)
                                }
                        )
                }
                
            }
            .onAppear {
                // 在视图出现时初始化按钮位置为屏幕右下角
                if !isButtonInitialized {
                    buttonPosition = CGPoint(x: geometry.size.width - 60, y: geometry.size.height - 60)
                    isButtonInitialized = true
                }
            }
            .ignoresSafeArea(.all)
        }
        .fullScreenCover(isPresented: $showAddDiaryView) {
            AddDiaryView(existingEntry: nil, isPresented: $showAddDiaryView)
        }
    }
}

struct AddButton: View {
    var iconName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.6)) // 设置背景颜色
                .frame(width: 60, height: 60) // 设置按钮大小
//                .shadow(color: Color.white.opacity(0.7), radius: 10, x: -5, y: -5) // 亮影
//                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 5, y: 5) // 暗影
                .shadow(color: Color.black.opacity(0.9), radius: 4, x: 2, y: 2)

            Image(systemName: iconName)
                .foregroundColor(.black) // 设置图标颜色
                .font(.system(size: 30)) // 设置图标大小
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GlobalData())
        .modelContainer(
                    // ✅ 创建专用于预览的内存存储容器
                    try! ModelContainer(
                        for: DiaryEntry.self,
                        configurations: ModelConfiguration(
                            isStoredInMemoryOnly: true  // 内存存储不污染正式数据
                        )
                    )
                )

}
