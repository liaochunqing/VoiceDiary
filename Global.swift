//
//  Global.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/9/13.
//

import Foundation
import SwiftUI

// MARK: - 屏幕尺寸相关
struct Screen {
    static let width = UIScreen.main.bounds.width
    static let height = UIScreen.main.bounds.height
//    static let maxLength = max(Screen.width, Screen.height)
//    static let minLength = min(Screen.width, Screen.height)
}

// MARK: - 适配比例
func W_SCALE(_ value: CGFloat) -> CGFloat {
    return value * (Screen.width / 390)  // 以 iPhone 14 Pro 的宽度 390 为基准
}

func H_SCALE(_ value: CGFloat) -> CGFloat {
    return value * (Screen.height / 844)  // 以 iPhone 14 Pro 的高度 844 为基准
}

// MARK: - 常用颜色
//extension Color {
//    static let themePrimary = Color("PrimaryColor") // 主题色，可以在Assets里定义
//    static let themeSecondary = Color("SecondaryColor")
//    static let themeBackground = Color(UIColor.systemBackground)
//}


extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#") // 跳过'#'字符
        
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0xFF00) >> 8) / 255.0
        let b = Double(rgbValue & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - 常用间距
struct Spacing {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}

// MARK: - 自定义字体
extension Font {
    static let customTitle = Font.system(size: 24, weight: .bold)
    static let customBody = Font.system(size: 16)
}

// MARK: - 日志打印
func LogDebug(_ message: String, file: String = #file, line: Int = #line) {
    #if DEBUG
    print("[DEBUG] \(message) (\(file):\(line))")
    #endif
}

// MARK: - 设备类型判断
struct DeviceType {
    static let isiPhone = UIDevice.current.userInterfaceIdiom == .phone
    static let isiPad = UIDevice.current.userInterfaceIdiom == .pad
}

// MARK: - 延时执行
func runAfter(_ delay: Double, _ action: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
}

// MARK: - 获取当前系统版本
struct SystemVersion {
    static let current = UIDevice.current.systemVersion
    static let isAbove14 = (Double(SystemVersion.current) ?? 0.0) >= 14.0
}

// MARK: - 判断深色模式
func isDarkMode() -> Bool {
    return UITraitCollection.current.userInterfaceStyle == .dark
}

// MARK: - URL打开
func openURL(_ urlString: String) {
    if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
