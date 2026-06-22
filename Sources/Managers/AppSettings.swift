import SwiftUI

/// App 级别偏好，集中管理 UserDefaults key 与默认值。
/// 仅保存用户上一次写日记时的习惯，新建日记时自动沿用。
@MainActor
enum AppSettings {

    // MARK: - 上次使用的字体

    @AppStorage("lastFontName")
    static var lastFontName: String = DiaryFont.system.rawValue

    static var lastFont: DiaryFont {
        DiaryFont(rawValue: lastFontName) ?? .system
    }

    // MARK: - 上次使用的字号

    @AppStorage("lastFontSize")
    static var lastFontSize: Double = 17

    // MARK: - 上次使用的颜色

    @AppStorage("lastFontColorHex")
    static var lastFontColorHex: String = ""

    static var lastFontColor: DiaryFontColor {
        DiaryFontColor(rawValue: lastFontColorHex) ?? .theme
    }

    // MARK: - 上次是否记录地点

    @AppStorage("lastAutoLocation")
    static var lastAutoLocation: Bool = false
}
