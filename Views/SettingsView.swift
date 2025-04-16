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
//    @Binding var offset: CGFloat  // 初始偏移量为负值，隐藏设置界面
//    @Binding var startLocation:CGFloat // 手势起点
    @Environment(\.dismiss) var dismiss // 用于关闭视图

    var body: some View {
        ZStack{
            Color.gray.ignoresSafeArea(.all)
            
            VStack
            {
                
                Text("设置界面")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding(.top,10)
               
            }
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
