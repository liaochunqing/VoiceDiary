import Foundation
import SwiftData
import SwiftUI

/// 一篇日记。所有属性带默认值、关系为 optional —— 满足 NSPersistentCloudKitContainer 私有同步要求。
@Model
final class DiaryEntry {
    var id: UUID = UUID()
    var content: String = ""
    var date: Date = Date()
    var location: String = ""
    var showLocation: Bool = false
    var emoji: String = ""
    var pageNumber: Int = 0

    // 字体（用户可调）
    var fontName: String = "System"
    var fontSize: Double = 17
    var fontColorHex: String = ""

    @Attribute(.externalStorage) var photos: [Data] = []

    @Relationship(deleteRule: .cascade, inverse: \VoiceMemo.entry)
    var voiceMemos: [VoiceMemo]? = nil

    init(content: String = "",
         date: Date = Date(),
         location: String = "",
         showLocation: Bool = false,
         emoji: String = "",
         photos: [Data] = []) {
        self.content = content
        self.date = date
        self.location = location
        self.showLocation = showLocation
        self.emoji = emoji
        self.photos = photos
    }

    /// 排序后的语音备忘。
    var memos: [VoiceMemo] {
        (voiceMemos ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var fontColor: Color {
        // 返回用户自选颜色，无选择时返回 nil，由视图层决定使用主题色
        Color(hexString: fontColorHex) ?? Color(lightHex: 0x221A0E, darkHex: 0xECE0C8)
    }

    /// 当前日记的字体枚举（用于编辑器面板）。
    var resolvedFont: DiaryFont {
        DiaryFont(rawValue: fontName) ?? .system
    }

    /// 创建本日记正文用的 SwiftUI Font。
    func bodyFont(palette: DiaryPalette) -> Font {
        resolvedFont.swiftUIFont(size: fontSize)
    }

    /// 正文颜色（从 fontColorHex 解析，空串回退到主题 ink）。
    func bodyColor(palette: DiaryPalette) -> Color {
        if fontColorHex.isEmpty { return palette.ink }
        return fontColor
    }
}

/// 一段语音备忘（元数据 + 端侧转写文本）。音频本体放在独立的 `VoiceAudio` 库里，
/// 通过 `audioID` 跨库引用——这样「同步录音」开关能单独控制音频上不上 iCloud。
@Model
final class VoiceMemo {
    var id: UUID = UUID()
    /// 关联音频实体的 ID（音频存于独立 VoiceAudio 库，可单独决定是否同步）。
    var audioID: UUID? = nil
    var duration: Double = 0
    var transcript: String = ""
    var createdAt: Date = Date()
    var entry: DiaryEntry? = nil

    init(audioID: UUID? = nil, duration: Double = 0, transcript: String = "", createdAt: Date = Date()) {
        self.audioID = audioID
        self.duration = duration
        self.transcript = transcript
        self.createdAt = createdAt
    }
}

/// 录音音频本体。单独成库（独立 `cloudKitDatabase`），由「同步录音」开关决定是否上 iCloud。
/// 与 VoiceMemo 是跨库 UUID 引用（VoiceMemo.audioID == VoiceAudio.id），非 SwiftData 关系。
@Model
final class VoiceAudio {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var data: Data? = nil

    init(id: UUID = UUID(), data: Data? = nil) {
        self.id = id
        self.data = data
    }
}

extension Color {
    /// 从 "#RRGGBB" / "RRGGBB" 解析。
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        guard s.count == 6, let v = UInt(s, radix: 16) else { return nil }
        self.init(hex: v)
    }
}
