import SwiftUI

extension Color {
    init(hex: UInt) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
    /// 随浅/深色模式自动切换的双色。
    init(lightHex: UInt, darkHex: UInt) {
        self = Color(uiColor: UIColor { tc in
            UIColor(Color(hex: tc.userInterfaceStyle == .dark ? darkHex : lightHex))
        })
    }
}

// Palette enum 已迁移到 DiaryPalette.swift（主题系统）
