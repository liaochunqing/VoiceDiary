import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case darkGold    = "darkGold"
    case celadon     = "celadon"
    case rose        = "rose"
    case nightBlue   = "nightBlue"
    case grapePurple = "grapePurple"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .darkGold:    return String(localized: "Dark Gold")
        case .celadon:     return String(localized: "Celadon")
        case .rose:        return String(localized: "Rose")
        case .nightBlue:   return String(localized: "Night Blue")
        case .grapePurple: return String(localized: "Grape")
        }
    }

    var palette: DiaryPalette {
        switch self {
        case .darkGold:    return .darkGold
        case .celadon:     return .celadon
        case .rose:        return .rose
        case .nightBlue:   return .nightBlue
        case .grapePurple: return .grapePurple
        }
    }

    var leatherGradient: [Color] {
        switch self {
        case .darkGold:    return [Color(hex: 0x5C3D1E), Color(hex: 0x3A2210)]
        case .celadon:     return [Color(hex: 0x3A5438), Color(hex: 0x2A3C28)]
        case .rose:        return [Color(hex: 0x5C2A35), Color(hex: 0x3A1820)]
        case .nightBlue:   return [Color(hex: 0x2A3A58), Color(hex: 0x1A2638)]
        case .grapePurple: return [Color(hex: 0x3C2848), Color(hex: 0x281838)]
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
