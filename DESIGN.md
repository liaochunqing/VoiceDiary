# VoiceDiary 视觉语言 · redesign-v2「精装纸本」

> 目标：从「系统默认工具」升级到「精装日记本」的高级感。
> 核心手法 = **纸张材质（新拟物）** + **衬线书卷标题** + **更大留白** + **圆形图标语言**。
> 一套材质语言，5 套配色主题共用——换主题只换色板，质感恒定。

---

## 1. 三条总原则

1. **不用硬边框做分隔**。满屏 1px 描边是廉价感的头号来源。改用「柔和阴影 + 卡面比纸面亮 + 顶亮底暗发丝斜面」营造浮起厚度。
2. **标题与阅读文案走衬线（宋体 / `.serif`）**，UI 操作类文字（按钮、开关、设置项、meta）保持 SF。书卷气只加在「读」的部分，不污染「用」的部分。
3. **留白优先**。卡片内边距、分组间距宁大勿小，标题字号拉大一档拉开层级。

---

## 2. 材质语言（`Sources/DesignSystem/Components/PaperLines.swift`）

所有修饰器与配色解耦，阴影一律用**中性黑低透明度**（深色模式下 `pal.ink` 是亮色，当阴影会变发光，禁止用 ink 做阴影）。

| 修饰器 / 视图 | 用途 | 关键参数 |
|---|---|---|
| `.diaryCard(radius:elevation:)` | 通用纸感卡片 | 双层投影（环境光 12/y6 + 接触影 2/y1）+ 渐变发丝斜面（白0.35→line0.45）；`elevation 0.5` 给搜索框/小卡轻浮 |
| `.paperLinedCard(radius:)` | 正文信纸卡（详情正文、编辑区） | 横线纸纹在底、文字在上 + 同款斜面与投影 |
| `.softEdge(shape:elevation:)` | 圆 / 胶囊小控件 | 渐变发丝边 + 轻投影，替代生硬描边；传入与背景同形状的 shape |
| `PaperBackground` | 整屏底纸 | 纯色 + 顶部微光泽 + 一层 `PaperGrain` 细颗粒（正片叠底） |
| `PaperGrain` | 纸张颗粒 | 一次性 `Canvas` 噪点，`SeededRNG` 固定分布不抖动 |

**用法**
```swift
// 卡片：去掉 .background(pal.card,…) + .overlay(…stroke line)，换成：
SomeContent().padding(Metric.l).diaryCard()

// 正文信纸：
TextEditor(...).paperLinedCard()

// 圆/胶囊按钮：保留 .background(pal.card, in: Circle())，描边换成：
.background(pal.card, in: Circle()).softEdge(Circle())

// 整屏背景：把 pal.paper.ignoresSafeArea() 换成：
ZStack { PaperBackground(); … }
```

---

## 3. 圆形图标语言 / 分组卡（设置 · 入口 · 数据类界面）

材质之上的一层**空间骨架**，让设置 / 入口 / 数据这类「一项一行」或「带图标的卡」界面统一精致。组件都在 `PaperLines.swift`，全 app 共用——别再各页手搓裸 `Image(systemName:)` 行。

| 组件 | 用途 | 规格 |
|---|---|---|
| `IconBadge` | 圆形图标徽章（撑行高 + 视觉锚点） | 默认 38pt 圆 + `accent.opacity(0.14)` 底 + 15pt semibold 图标；可配 `diameter / glyphSize / tint` |
| `SectionCard` | 分组卡 | 组标题在卡外（纯文字 uppercase 小标签 + tracking 0.6）+ 内容套 `diaryCard(radius:18)` |
| `IconRowLabel` | 行左半 | `IconBadge` + 标题（`.dSubhead`）+ 可选副标题（`.dCaption`）；开关 / 箭头 / 取值行共用 |
| `RowDivider` | 行内分隔线 | 左缩进 50（38 图标 + 12 间距），不切到图标列 |

**适用边界（重要）**
- ✅ 用：设置页、付费墙功能行、统计数字卡、列表入口卡——凡是「图标 + 文字」成行 / 成卡的。
- ❌ 不用：阅读（详情）与输入（编辑、录音、字体选择）界面。它们走 `paperLinedCard` 信纸 + 大留白阅读版式，硬塞圆形图标只会变乱。

**图标颜色**：默认 `accent` 单色，随 5 主题变化（守材质统一，别做成多彩图标）。仅两种强语义破例——隐私 / 安全 = 绿（呼应「音频不出本机」红线卖点），危险操作 = 红。

**圆角两档**：内容卡 / 数据卡 = `Metric.cardRadius`（16）；分组容器 = `SectionCard`（18）。容器比内容略大一档，拉开层级。

**行高**：图标 38 + 上下 `Metric.m`(12) ≈ 62pt，舒展不挤。

```swift
SectionCard(title: "Preferences") {
    VStack(spacing: 0) {
        HStack { IconRowLabel(icon: "bell", label: "Remind me"); Spacer(); Toggle(…) }
            .padding(.vertical, Metric.m)
        RowDivider()
        HStack { IconRowLabel(icon: "clock", label: "Time"); Spacer(); DatePicker(…) }
            .padding(.vertical, Metric.m)
    }
}
```

---

## 4. 衬线字号体系（`Sources/DesignSystem/Typography.swift`）

中文落到宋体（`design: .serif`），并放大一档拉开层级。

| Token | 字号 | 用途 |
|---|---|---|
| `.dSerifTitle` | 34 serif bold | 页面大标题（目录 / 设置） |
| `.dSerifPageTitle` | 28 serif bold | 次级 / 弹窗标题、空状态主标题 |
| `.dSerifHeadline` | 22 serif semibold | 卡片大标题 |
| `.dSerifReading` | 20 serif | 阅读正文（详情 / 长文） |
| `.dSerifBody` | 17 serif | 列表预览 / 文案正文 |
| `.dSerifSubhead` | 15 serif | 次级衬线文案 |

原有 SF 语义 token（`.dPageTitle / .dSubhead / .dCaption …`）保留给 UI 操作类文字。

### 衬线的边界（重要）
- **用户打的日记内容**仍走字体选择器（`DiaryFont`），**不强制衬线**——那是用户可选功能。
- 衬线只加在「我们控制的 app 文案」：标题、空状态、详情占位、付费墙标题、引导文案、封面书名。

---

## 5. 留白与间距

- 主滚动栈分组间距：`Metric.m(12) → Metric.l(16)`。
- 卡片内边距：`Metric.m(12) → Metric.l(16)`（列表行、详情卡、附件卡）。
- 卡片圆角：内容卡 `Metric.cardRadius(16)`、分组容器 `SectionCard(18)`（见第 3 节两档规则）。
- 列表正文加 `.lineSpacing(2)`，详情正文 UITextView `lineSpacing 6`。

---

## 6. 刻意保留的硬边框（别误删）

以下边框**传达「选中」状态**，靠实心描边表达，换成柔投影会丢状态感，故保留：
- 字体卡选中（`FontPickerPanel.fontCard`）、配色圆点选中。
- 付费方案选中（`PaywallView.pricingChip`，accent 2pt 环）。
- 录音「追加 / 覆盖」分段（`RecordingView.textModeSegment`）。
- 空状态书徽章描边（`DiaryListView.bookBadge`，对齐 HTML 设计稿）。

---

## 7. 封面 / 引导 = 皮质，不是纸

`CoverView` / `OnboardingView` 用 `leatherGradient` 皮革底 + 烫金宋体书名，**不套 `PaperBackground`**——这是「合上的精装本封面」，与翻开后的纸面形成材质对比。封面书名「我 的 日 记」用 60pt serif bold 烫金，是品牌识别核心。

---

## 8. 改造覆盖清单（redesign-v2 已完成）

List · Detail · Settings(含 iCloud 弹窗) · Stats · Paywall · Editor · Recording · FontPicker · Onboarding · Cover 全部落地。EmojiBubble / PhotoFullScreen 无卡片无需改。

**圆形图标语言统一（2026-06-23）**：第 3 节组件抽到 `PaperLines.swift` 全 app 共用；设置页改用 `SectionCard / IconRowLabel / RowDivider`；统计数字卡、付费墙功能行的裸图标换成 `IconBadge`；`Metric.cardRadius` 14→16 统一柔和度。阅读 / 输入类界面按第 3 节边界规则**不加**图标行（详情 / 编辑 / 录音 / 字体只享受圆角统一）。`BUILD SUCCEEDED`。

新增页面 / 改字号时：**优先用上面的修饰器、`IconBadge / SectionCard / IconRowLabel` 组件与 `.dSerif*` token，不要再手写 `.background(pal.card)+.overlay(stroke)` 或裸 `Image(systemName:)` 行。**
