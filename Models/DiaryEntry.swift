//
//  DiaryEntry.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/9/28.
//

import Foundation
import SwiftUI
import SwiftData

@Model

class DiaryEntry {
    var id: UUID = UUID()  // 唯一标识符，默认生成新的 UUID
    var content: String? = ""  // 日记内容，默认为空字符串
    var date: Date = Date()  // 创建日期，默认为当前日期
    var location: String? = ""  // 日记记录的位置信息，默认为空字符串
    var emojiString: String = ""  // 日记心情
    var pageNumber: Int = -1  // 页码
    var showLocation: Bool = false  // 是否显示地址
    var fontColorHex: String?  // 可选的十六进制颜色字符串
    var fontStyle: String = ""  // 字体类型
    var fontSize: CGFloat = 17  // 字体大小

    // 初始化方法
    init(id: UUID = UUID(),
         content: String? = "",
         date: Date = Date(),
         location: String? = "",
         emojiString: String = "",
         showLocation: Bool = false,
         fontColorHex: String? = nil,
         fontStyle: String = "",
         fontSize: CGFloat = 17) {
        self.id = id
        self.content = content
        self.date = date
        self.location = location
        self.emojiString = emojiString
        self.showLocation = showLocation
        self.fontColorHex = fontColorHex
        self.fontStyle = fontStyle
        self.fontSize = fontSize
    }

    // SwiftUI 颜色计算属性（不存储）
    var fontColor: Color {
        get {
            if let hex = fontColorHex, let color = Color(hex: hex) {
                return color
            } else {
                return .primary
            }
        }
        set {
            fontColorHex = newValue.toHex()
        }
    }
}


class IdentifiedHostingController<Content: View>: UIHostingController<Content> {
    let id: UUID

    init(id: UUID, rootView: Content) {
        self.id = id
        super.init(rootView: rootView)
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b: Double
        switch hexSanitized.count {
        case 6:
            r = Double((rgb & 0xFF0000) >> 16) / 255
            g = Double((rgb & 0x00FF00) >> 8) / 255
            b = Double(rgb & 0x0000FF) / 255
            self.init(red: r, green: g, blue: b)
        default:
            return nil
        }
    }

    func toHex() -> String? {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }

        return String(format: "#%02X%02X%02X",
                      Int(r * 255),
                      Int(g * 255),
                      Int(b * 255))
    }
}
