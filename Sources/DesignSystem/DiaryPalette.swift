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
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var palette: DiaryPalette = .darkGold
}
