//
//  SettingsView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/9/2.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @Binding var offset: CGFloat  // 初始偏移量为负值，隐藏设置界面
    @Binding var startLocation:CGFloat // 手势起点
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
                
                Button(action: {
                                // 关闭全屏视图
                    dismiss()
                            }) {
                                Text("关闭")
                                    .padding()
                                    .background(Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
            }
            
            
        }
        .offset(x: offset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // 从右向左滑动，改变偏移量
                    if value.translation.width < 0 {
                        offset = max(value.translation.width, -UIScreen.main.bounds.width)
                    }
                }
                .onEnded { value in
                    // 滑动超过一定距离时关闭设置界面
                    if value.translation.width < -100 {
                        withAnimation {
                            offset = -UIScreen.main.bounds.width
                        }
                    } else {
                        // 否则还原设置界面
                        withAnimation {
                            offset = 0
                        }
                    }
                }
        )
    }
}

#Preview {
    ContentView()
}
