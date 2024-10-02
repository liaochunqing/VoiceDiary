//
//  DiaryGroup.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/9/28.
//

import Foundation
import SwiftUI
struct DiaryGroup: Identifiable, Codable {
    var id = UUID()                   // 唯一标识符
    var title: String                 // 分组标题
//    var colorString: String           // 存储颜色的字符串
    var icon: String                  // 图标（可以使用系统 SF Symbols）

    // 计算属性：将字符串转换为 Color
//    var color: Color {
//        Color(hex: colorString)  // 使用扩展方法将十六进制字符串转换为 Color
//    }

    // 初始化方法
    init(title: String, color: Color, icon: String) {
        self.title = title
//        self.colorString = color.toHex() // 将 Color 转换为十六进制字符串
        self.icon = icon
    }
}
