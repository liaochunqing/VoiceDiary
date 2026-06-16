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
        fontColorHex.isEmpty ? Palette.ink : (Color(hexString: fontColorHex) ?? Palette.ink)
    }
}

/// 一段语音备忘（音频 + 端侧转写文本）。音频随用户私有 iCloud 同步。
@Model
final class VoiceMemo {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var audio: Data? = nil
    var duration: Double = 0
    var transcript: String = ""
    var createdAt: Date = Date()
    var entry: DiaryEntry? = nil

    init(audio: Data? = nil, duration: Double = 0, transcript: String = "", createdAt: Date = Date()) {
        self.audio = audio
        self.duration = duration
        self.transcript = transcript
        self.createdAt = createdAt
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
