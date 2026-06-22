import SwiftUI

// MARK: - Palette struct

struct DiaryPalette {
    let paper: Color
    let card: Color
    let line: Color
    let ink: Color
    let inkSoft: Color
    let accent: Color
    let accentSoft: Color
    let gold: Color
    let leather: Color
    let leatherDark: Color
    let onAccent: Color

    // MARK: 暗金 Dark Gold（默认）
    static let darkGold = DiaryPalette(
        paper:       Color(lightHex: 0xF5EBD5, darkHex: 0x1E1810),
        card:        Color(lightHex: 0xFFFEF8, darkHex: 0x2A2014),
        line:        Color(lightHex: 0xD9CBAC, darkHex: 0x3E3222),
        ink:         Color(lightHex: 0x221A0E, darkHex: 0xECE0C8),
        inkSoft:     Color(lightHex: 0x8A7860, darkHex: 0x8A7860),
        accent:      Color(lightHex: 0x7A5A14, darkHex: 0xC9A23A),
        accentSoft:  Color(hex: 0xE8C97A),
        gold:        Color(hex: 0xC9A23A),
        leather:     Color(hex: 0x5C3D1E),
        leatherDark: Color(hex: 0x3A2210),
        onAccent:    .white
    )

    // MARK: 茶绿 Celadon
    static let celadon = DiaryPalette(
        paper:       Color(lightHex: 0xF1F0E8, darkHex: 0x181C14),
        card:        Color(lightHex: 0xFAFAF5, darkHex: 0x21261E),
        line:        Color(lightHex: 0xD5D2C4, darkHex: 0x323A2C),
        ink:         Color(lightHex: 0x252820, darkHex: 0xE0E4D8),
        inkSoft:     Color(lightHex: 0x808678, darkHex: 0x808678),
        accent:      Color(lightHex: 0x4E6B4A, darkHex: 0x7AAB74),
        accentSoft:  Color(hex: 0x99B894),
        gold:        Color(hex: 0x7AAB74),
        leather:     Color(hex: 0x3A5438),
        leatherDark: Color(hex: 0x2A3C28),
        onAccent:    .white
    )

    // MARK: 玫红 Rose
    static let rose = DiaryPalette(
        paper:       Color(lightHex: 0xFDF6F0, darkHex: 0x1E1518),
        card:        Color(lightHex: 0xFFFAF7, darkHex: 0x2A1C20),
        line:        Color(lightHex: 0xD9C5C0, darkHex: 0x3E2A2C),
        ink:         Color(lightHex: 0x2C1A1E, darkHex: 0xF0E4E0),
        inkSoft:     Color(lightHex: 0x907070, darkHex: 0x907070),
        accent:      Color(lightHex: 0xC44B6B, darkHex: 0xD4879A),
        accentSoft:  Color(hex: 0xD4879A),
        gold:        Color(hex: 0xD4879A),
        leather:     Color(hex: 0x5C2A35),
        leatherDark: Color(hex: 0x3A1820),
        onAccent:    .white
    )

    // MARK: 深蓝夜色 Night Blue
    static let nightBlue = DiaryPalette(
        paper:       Color(lightHex: 0xF2F0F5, darkHex: 0x141A24),
        card:        Color(lightHex: 0xFAFAFD, darkHex: 0x1C2230),
        line:        Color(lightHex: 0xD0D4E0, darkHex: 0x2A3242),
        ink:         Color(lightHex: 0x1A1E28, darkHex: 0xE0E4F0),
        inkSoft:     Color(lightHex: 0x808898, darkHex: 0x808898),
        accent:      Color(lightHex: 0x3A5A8C, darkHex: 0x5A7AB0),
        accentSoft:  Color(hex: 0x5A7AB0),
        gold:        Color(hex: 0xB8A060),
        leather:     Color(hex: 0x2A3A58),
        leatherDark: Color(hex: 0x1A2638),
        onAccent:    .white
    )

    // MARK: 葡萄紫 Grape Purple
    static let grapePurple = DiaryPalette(
        paper:       Color(lightHex: 0xF6F2F8, darkHex: 0x1C1622),
        card:        Color(lightHex: 0xFCFAFE, darkHex: 0x241E2C),
        line:        Color(lightHex: 0xD8D0E0, darkHex: 0x342A3C),
        ink:         Color(lightHex: 0x241A28, darkHex: 0xE8E0F0),
        inkSoft:     Color(lightHex: 0x9888A0, darkHex: 0x9888A0),
        accent:      Color(lightHex: 0x6B4A8A, darkHex: 0x9A78B0),
        accentSoft:  Color(hex: 0x9A78B0),
        gold:        Color(hex: 0xB89860),
        leather:     Color(hex: 0x3C2848),
        leatherDark: Color(hex: 0x281838),
        onAccent:    .white
    )
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var palette: DiaryPalette = .darkGold
}
