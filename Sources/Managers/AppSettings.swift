import SwiftUI

/// App 级别偏好，集中管理 UserDefaults key 与默认值。
/// 仅保存用户上一次写日记时的习惯，新建日记时自动沿用。
@MainActor
enum AppSettings {

    static let diaryListStyleKey = "diaryListStyle"

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

    // MARK: - 转写语言（空串 = 自动跟随系统首选语言）

    @AppStorage("transcriptionLanguage")
    static var transcriptionLanguage: String = ""
}

enum DiaryListStyle: String, CaseIterable, Identifiable {
    case editorial
    case dateRail
    case voiceFirst
    case contentFirst

    var id: String { rawValue }

    var isFree: Bool {
        switch self {
        case .editorial, .dateRail:
            return true
        case .voiceFirst, .contentFirst:
            return false
        }
    }

    var titleKey: String {
        switch self {
        case .editorial:
            return "Editorial"
        case .dateRail:
            return "Date Rail"
        case .voiceFirst:
            return "Voice First"
        case .contentFirst:
            return "Content First"
        }
    }

    var subtitleKey: String {
        switch self {
        case .editorial:
            return "Clear separation between meta and writing."
        case .dateRail:
            return "A strong date anchor with a tidy reading column."
        case .voiceFirst:
            return "Gives recording details more presence."
        case .contentFirst:
            return "Keeps the writing as the main focus."
        }
    }

    var symbolName: String {
        switch self {
        case .editorial:
            return "rectangle.grid.1x2"
        case .dateRail:
            return "sidebar.left"
        case .voiceFirst:
            return "waveform"
        case .contentFirst:
            return "text.alignleft"
        }
    }
}
