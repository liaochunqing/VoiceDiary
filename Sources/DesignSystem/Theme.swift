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

/// 「仿真日记本」配色：浅色像翻开的纸页，深色像台灯下看本子，皮革始终是棕。
enum Palette {
    static let paper       = Color(lightHex: 0xFBF3E3, darkHex: 0x2B2420) // 页面背景
    static let card        = Color(lightHex: 0xFFFFFF, darkHex: 0x362F29) // 卡片表面
    static let line        = Color(lightHex: 0xE8DCC4, darkHex: 0x473E35) // 边框 / 纸纹线
    static let ink         = Color(lightHex: 0x4A3A2C, darkHex: 0xECE3D4) // 主文字
    static let inkSoft     = Color(lightHex: 0xA8997F, darkHex: 0xA99C88) // 弱化 / meta
    static let accent      = Color(lightHex: 0xC8763A, darkHex: 0xD4894A) // 主色（暖陶土橙）
    static let accentSoft  = Color(hex: 0xF0C896)
    static let gold        = Color(hex: 0xD8B56A) // 封面 / 锁屏暗金
    static let leather     = Color(hex: 0x6B4226)
    static let leatherDark = Color(hex: 0x4A2C17)
    static let onAccent    = Color.white
}
