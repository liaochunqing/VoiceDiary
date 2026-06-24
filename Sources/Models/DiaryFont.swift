import SwiftUI
import UIKit
import CoreText

// MARK: - DiaryFont

/// 字体家族。rawValue 为 PostScript 名称。
enum DiaryFont: String, CaseIterable {

    case system = "System"
    case haoShen = "YOUSHEhaoshenti"
    case slideXiaXing = "Slidexiaxing-Regular"
    case xiaoKeNaiLao = "ZQKNLT-Regular"
    case longCang = "LongCang-Regular"

    var displayName: String {
        switch self {
        case .system:        return String(localized: "System Default")
        case .haoShen:       return String(localized: "Handwriting")
        case .slideXiaXing:  return String(localized: "Script")
        case .xiaoKeNaiLao:  return String(localized: "Rounded")
        case .longCang:      return String(localized: "Brush")
        }
    }

    var isBuiltIn: Bool {
        self == .system
    }

    /// 创建 SwiftUI Font。
    func swiftUIFont(size: CGFloat) -> Font {
        switch self {
        case .system:
            return .system(size: size)
        default:
            return .custom(rawValue, size: size)
        }
    }

    /// 创建 UIFont（用于 UITextView 等 UIKit 场景）。
    func uiFont(size: CGFloat) -> UIFont {
        switch self {
        case .system:
            return .systemFont(ofSize: size)
        default:
            return UIFont(name: rawValue, size: size) ?? .systemFont(ofSize: size)
        }
    }

    // MARK: - 运行时字体注册

    /// 字体文件名 → PostScript 名称的映射，用于 CTFontManager 注册。
    private static let fontFiles: [(fileName: String, postscriptName: String)] = [
        ("LongCang-Regular.ttf",       "LongCang-Regular"),
        ("Slidexiaxing-Regular.ttf",   "Slidexiaxing-Regular"),
        ("YSHaoShenTi.ttf",            "YOUSHEhaoshenti"),
        ("小可奶酪体.ttf",              "ZQKNLT-Regular"),
    ]

    /// 在 App 启动时调用一次，用 CoreText 注册所有第三方字体。
    /// 无需 Info.plist 中的 UIAppFonts 即可使用。
    static func registerCustomFonts() {
        for (fileName, psName) in fontFiles {
            guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
                print("[DiaryFont] ⚠️ Font file not in bundle: \(fileName)")
                continue
            }
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                print("[DiaryFont] ✅ Registered: \(fileName) → \(psName)")
            } else {
                let e = error?.takeRetainedValue().localizedDescription ?? "unknown"
                print("[DiaryFont] ❌ Failed to register \(fileName): \(e)")
            }
        }
    }

    /// 运行时验证所有字体是否可加载。
    static func validateAllFonts() {
        print("[DiaryFont] --- Font Validation ---")
        for font in DiaryFont.allCases {
            let uiFont = UIFont(name: font.rawValue, size: 17)
            let status = uiFont != nil ? "✅" : "❌ FALLBACK"
            print("[DiaryFont]   \(status) \(font.displayName) — \"\(font.rawValue)\" → \(uiFont?.fontName ?? "nil")")
        }
        // Also list all available font family names for debugging
        let families = UIFont.familyNames.sorted()
        let customFamilies = families.filter { fam in
            let names = UIFont.fontNames(forFamilyName: fam)
            return names.contains { n in
                n.contains("LongCang") || n.contains("Slide") ||
                n.contains("YOUSHE") || n.contains("ZQKNLT")
            }
        }
        if !customFamilies.isEmpty {
            print("[DiaryFont] Custom font families loaded:")
            for fam in customFamilies {
                print("[DiaryFont]   \(fam): \(UIFont.fontNames(forFamilyName: fam))")
            }
        }
        print("[DiaryFont] --- End Font Validation ---")
    }

    /// 简短预览用字符串。
    var previewLabel: String {
        if isBuiltIn { return displayName }
        return "\(displayName) · \(String(localized: "3rd-party"))"
    }
}

// MARK: - DiaryFontColor

/// 预设字体颜色。rawValue 为浅色模式 hex（也是存库标识）。
/// 色相分布（顺时针）：yellow→orange→red→rose→fuchsia→purple→indigo→blue→teal→green→lime→olive + 无彩色三档。
enum DiaryFontColor: String, CaseIterable {

    case theme   = ""           // 跟随主题墨色（特殊）
    case yellow  = "#C8960C"   // H≈44° 金黄
    case orange  = "#C75000"   // H≈21° 橙红（与金黄明显不同）
    case red     = "#C0392B"   // H≈ 5° 朱红
    case rose    = "#B5245B"   // H≈336° 玫红
    case fuchsia = "#9C1282"   // H≈313° 洋红（紫红之间）
    case purple  = "#6B3FA0"   // H≈275° 紫
    case indigo  = "#2E3FA0"   // H≈234° 靛（蓝紫，比 purple 更蓝）
    case blue    = "#2472A4"   // H≈209° 蓝
    case teal    = "#1A7A6E"   // H≈174° 青绿
    case green   = "#2E6B4F"   // H≈153° 森林绿
    case lime    = "#4D7A1A"   // H≈ 96° 草木绿（绿与橄榄间）
    case olive   = "#6B7520"   // H≈ 65° 橄榄（偏黄绿）
    case coffee  = "#7A4F38"   // 暖棕（中等深度，有别于 black）
    case slate   = "#546E7A"   // 蓝灰（中性冷调）
    case black   = "#1C1C1C"   // 近黑

    var displayName: String {
        switch self {
        case .theme:   return String(localized: "Theme Ink")
        case .yellow:  return String(localized: "Ginger")
        case .orange:  return String(localized: "Ember")
        case .red:     return String(localized: "Vermilion")
        case .rose:    return String(localized: "Rose")
        case .fuchsia: return String(localized: "Fuchsia")
        case .purple:  return String(localized: "Wisteria")
        case .indigo:  return String(localized: "Indigo")
        case .blue:    return String(localized: "Cobalt")
        case .teal:    return String(localized: "Teal")
        case .green:   return String(localized: "Pine")
        case .lime:    return String(localized: "Fern")
        case .olive:   return String(localized: "Olive")
        case .coffee:  return String(localized: "Coffee")
        case .slate:   return String(localized: "Steel")
        case .black:   return String(localized: "Jet")
        }
    }

    /// 深色模式下使用更亮的版本，保证在深色纸面仍清晰可读。
    private var darkHex: String {
        switch self {
        case .theme:   return ""
        case .yellow:  return "#FFD54F"
        case .orange:  return "#FFAB76"
        case .red:     return "#EF9A9A"
        case .rose:    return "#F48FB1"
        case .fuchsia: return "#F06292"
        case .purple:  return "#CE93D8"
        case .indigo:  return "#9FA8DA"
        case .blue:    return "#7FB0E0"
        case .teal:    return "#4DB6AC"
        case .green:   return "#A5D6A7"
        case .lime:    return "#C5E1A5"
        case .olive:   return "#C6CA53"
        case .coffee:  return "#BCAAA4"
        case .slate:   return "#90A4AE"
        case .black:   return "#D0D0D0"
        }
    }

    /// theme 跟随主题墨色（palette.ink）；其余按浅/深模式自动切换以保证对比度。
    func resolved(palette: DiaryPalette) -> Color {
        if rawValue.isEmpty { return palette.ink }
        let light = Color(hexString: rawValue) ?? palette.ink
        let dark = Color(hexString: darkHex) ?? light
        return Color(uiColor: UIColor { trait in
            UIColor(trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}
