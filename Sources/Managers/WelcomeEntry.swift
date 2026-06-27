import Foundation
import SwiftData

/// 首次启动（且本机没有任何日记）时灌入的一篇内置「欢迎日记」。
/// 正文用 `String(localized:)` 走字符串目录，自动跟随系统语言（英文源 + 简中）。
/// 只负责「写下属于你的第一页」前的引导，文案即三条手势教学。
enum WelcomeEntry {

    /// 是否已经播种过欢迎日记（按安装计一次，删了也不再回来）。
    private static let seededKey = "welcomeEntrySeeded"

    /// 若本机从未播种且当前确实没有任何日记，则插入一篇欢迎日记。
    /// 调用时机：引导（Onboarding）完成那一刻 —— 即真正的「全新用户」入口。
    @MainActor
    static func seedIfNeeded(into context: ModelContext, existingCount: Int) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        UserDefaults.standard.set(true, forKey: seededKey)

        // 已有日记（例如 iCloud 同步下来）就不再塞欢迎页，避免突兀。
        guard existingCount == 0 else { return }

        let body = [
            String(localized: "Welcome to your voice diary ☺"),
            String(localized: "Tap “Talk” and your words turn into text in real time."),
            String(localized: "← → Swipe left or right to flip between pages, like a real notebook."),
            String(localized: "Press and hold an entry in Contents to edit or delete it."),
            String(localized: "Flip back to Contents and write your first page."),
        ].joined(separator: "\n\n")

        let entry = DiaryEntry(content: body, date: Date())
        context.insert(entry)
        try? context.save()
    }
}
