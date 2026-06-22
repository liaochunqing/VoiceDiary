# VoiceDiary 视觉语言 · redesign-v2「精装纸本」

> 目标：从「系统默认工具」升级到「精装日记本」的高级感。
> 核心手法 = **纸张材质（新拟物）** + **衬线书卷标题** + **更大留白**。
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

## 3. 衬线字号体系（`Sources/DesignSystem/Typography.swift`）

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

## 4. 留白与间距

- 主滚动栈分组间距：`Metric.m(12) → Metric.l(16)`。
- 卡片内边距：`Metric.m(12) → Metric.l(16)`（列表行、详情卡、附件卡）。
- 列表正文加 `.lineSpacing(2)`，详情正文 UITextView `lineSpacing 6`。

---

## 5. 刻意保留的硬边框（别误删）

以下边框**传达「选中」状态**，靠实心描边表达，换成柔投影会丢状态感，故保留：
- 字体卡选中（`FontPickerPanel.fontCard`）、配色圆点选中。
- 付费方案选中（`PaywallView.pricingChip`，accent 2pt 环）。
- 录音「追加 / 覆盖」分段（`RecordingView.textModeSegment`）。
- 空状态书徽章描边（`DiaryListView.bookBadge`，对齐 HTML 设计稿）。

---

## 6. 封面 / 引导 = 皮质，不是纸

`CoverView` / `OnboardingView` 用 `leatherGradient` 皮革底 + 烫金宋体书名，**不套 `PaperBackground`**——这是「合上的精装本封面」，与翻开后的纸面形成材质对比。封面书名「我 的 日 记」用 60pt serif bold 烫金，是品牌识别核心。

---

## 7. 改造覆盖清单（redesign-v2 已完成）

List · Detail · Settings(含 iCloud 弹窗) · Stats · Paywall · Editor · Recording · FontPicker · Onboarding · Cover 全部落地。EmojiBubble / PhotoFullScreen 无卡片无需改。`BUILD SUCCEEDED`。

新增页面 / 改字号时：**优先用上面的修饰器与 `.dSerif*` token，不要再手写 `.background(pal.card)+.overlay(stroke)`。**
