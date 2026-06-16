import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case darkGold = "darkGold"
    case celadon  = "celadon"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .darkGold: return "暗金"
        case .celadon:  return "茶绿"
        }
    }

    var palette: DiaryPalette {
        switch self {
        case .darkGold: return .darkGold
        case .celadon:  return .celadon
        }
    }

    var leatherGradient: [Color] {
        switch self {
        case .darkGold: return [Color(hex: 0x5C3D1E), Color(hex: 0x3A2210)]
        case .celadon:  return [Color(hex: 0x3A5438), Color(hex: 0x2A3C28)]
        }
    }
}

@MainActor @Observable
final class ThemeManager {
    var current: AppTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "appTheme") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "appTheme") ?? ""
        current = AppTheme(rawValue: saved) ?? .darkGold
    }

    var palette: DiaryPalette { current.palette }
}
