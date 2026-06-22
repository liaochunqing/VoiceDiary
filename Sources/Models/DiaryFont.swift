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
enum DiaryFontColor: String, CaseIterable {

    case theme  = ""
    case yellow = "#C8960C"
    case red    = "#C0392B"
    case blue   = "#2472A4"
    case green  = "#2E6B4F"
    case purple = "#6B3FA0"

    var displayName: String {
        switch self {
        case .theme:  return String(localized: "Theme Ink")
        case .yellow: return String(localized: "Ginger")
        case .red:    return String(localized: "Vermilion")
        case .blue:   return String(localized: "Cobalt")
        case .green:  return String(localized: "Pine")
        case .purple: return String(localized: "Wisteria")
        }
    }

    /// 深色模式下使用的更明亮版本，保证在深色纸面仍清晰可读。
    private var darkHex: String {
        switch self {
        case .theme:  return ""
        case .yellow: return "#FFD54F"
        case .red:    return "#EF9A9A"
        case .blue:   return "#7FB0E0"
        case .green:  return "#84C9A3"
        case .purple: return "#CE93D8"
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
