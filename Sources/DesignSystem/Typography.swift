import SwiftUI

/// 字号层级，对齐 Apple HIG SF Pro 字阶。
/// 全部用语义化 `.font(.style)`，自动支持 Dynamic Type。
/// 避免硬编码 `.system(size:)` — 用户调大字体时全域同步缩放。
///
/// 使用场景速查：
/// ┌──────────────┬──────┬──────────┬─────────────────────────┐
/// │ Token        │ HIG  │ Weight   │ 典型场景                 │
/// ├──────────────┼──────┼──────────┼─────────────────────────┤
/// │ .dLargeDate  │ 34pt │ .bold    │ 写日记页大日期           │
/// │ .dPageTitle  │ 28pt │ .bold    │ 页面标题（设置、目录）   │
/// │ .dTitle      │ 22pt │ .bold    │ 弹窗标题 / 功能大标题    │
/// │ .dHeadline   │ 17pt │ .semibold│ 段落标题                 │
/// │ .dBody       │ 17pt │ —        │ 正文 / 长文本            │
/// │ .dCallout    │ 16pt │ —        │ 次级标题 / 按钮文字      │
/// │ .dSubhead    │ 15pt │ —        │ 列表行 / 设置项 / 辅助   │
/// │ .dFootnote   │ 13pt │ —        │ 脚注 / 时间戳            │
/// │ .dCaption    │ 12pt │ —        │ meta 说明 / 小字         │
/// │ .dLabel      │ 11pt │ .semibold│ 分区标签（最小字号）     │
/// └──────────────┴──────┴──────────┴─────────────────────────┘
extension Font {
    // MARK: 标题级

    /// 34pt bold — 写日记页大日期、封面日号
    static let dLargeDate = Font.largeTitle.bold()

    /// 28pt bold — 页面标题（设置页、目录页）
    static let dPageTitle = Font.title.bold()

    /// 22pt bold — 弹窗 / 卡片大标题
    static let dTitle = Font.title2.bold()

    // MARK: 段落级

    /// 17pt semibold — 段落小标题
    static let dHeadline = Font.headline

    /// 17pt regular — 正文、日记内容、长文本
    static let dBody = Font.body

    // MARK: 辅助级

    /// 16pt regular — 次级标题、按钮文案、列表摘要
    static let dCallout = Font.callout

    /// 15pt regular — 设置项标题、列表行、次要文字
    static let dSubhead = Font.subheadline

    /// 13pt regular — 脚注、时间戳
    static let dFootnote = Font.footnote

    /// 12pt regular — meta 说明、时长、提示
    static let dCaption = Font.caption

    /// 11pt semibold — 分区标签（最小字号，Apple HIG 红线）
    static let dLabel = Font.caption2.weight(.semibold)

    // MARK: 原衬线别名（现统一回归苹果标准系统字体，保持调用点不变）

    /// 34pt bold — 页面大标题（目录 / 设置）
    static let dSerifTitle = Font.largeTitle.bold()

    /// 28pt bold — 次级页面 / 弹窗标题、空状态主标题
    static let dSerifPageTitle = Font.title.bold()

    /// 22pt semibold — 卡片大标题
    static let dSerifHeadline = Font.title2.weight(.semibold)

    /// 20pt regular — 阅读正文（详情 / 长文，放大一档）
    static let dSerifReading = Font.title3

    /// 17pt regular — 列表预览 / 文案正文
    static let dSerifBody = Font.body

    /// 15pt regular — 次级文案
    static let dSerifSubhead = Font.subheadline
}
