# VoiceDiary（全新工程）

「能翻页的皮质日记本 + 语音日记」。2026-06-16 从零重建（旧工程见 `../VoiceDiary-backup`，仅作历史参考）。

## 复用的上架 ID（其余全部重建）
- Bundle ID：`com.chunqingliao.VoiceDiary`
- App Store ID：`6670278331`，显示名「翻页日记」
- IAP product：`com.chunqingliao.VoiceDiary.fullunlock`（一次性买断 ¥15，NonConsumable）
- iCloud 容器：`iCloud.com.chunqingliao.VoiceDiary`（CloudKit 私有库）
- Team：`8X79G5XCU6`，部署目标 iOS 17.5，仅 iPhone

## UI 设计准则

- **用图标替代文字按钮**：界面上的操作按钮优先使用 SF Symbols 图标，不写文字标签。文字只保留在内容展示区、空状态提示、以及确实无法用图标传达语义的极少数场景（如付费页定价）。目的：减少视觉噪声，与「仿真日记本」的物理感风格保持一致。
- **操作按钮统一圆形背景**：`Image(systemName:).frame(36×36).background(pal.card, in: Circle()).overlay(Circle().stroke(pal.line))`，危险操作（删除）图标用红色/accent 强调。
- **顶栏最多三个操作位**：左一（返回/关闭）、中间（标题）、右侧最多两个操作图标，不使用 menu 隐藏常用动作。

## 技术栈
- **Swift 6 language mode**（`SWIFT_VERSION 6.0` + `SWIFT_STRICT_CONCURRENCY complete`，编译期数据竞争检查）。
- SwiftUI（iOS 17.5+）、`@Observable`（Observation）、SwiftData `@Model` + CloudKit 私有同步、async/await + `@MainActor`。
- 录音 `AVAudioRecorder` + `AVAudioApplication`（iOS17 权限）、转写 `Speech`（on-device）、`PhotosUI`。
- 并发约定：跨线程一次性回调用 `OSAllocatedUnfairLock`；Apple 旧框架（Speech）用 `@preconcurrency import`；不使用 `@unchecked Sendable` 糊弄。

## 工程方式
- **XcodeGen**：改配置改 `project.yml`，然后 `xcodegen generate` 重新生成 `.xcodeproj`（生成物，不手改）。新增 `.swift` 文件后必须重新 generate。
- 编译验证：`xcodebuild -project VoiceDiary.xcodeproj -scheme VoiceDiary -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
- 演示数据：DEBUG 下 launch 传 `-seedDemo 1`（见 `DataManager.seedDemoIfNeeded`）。

## 目录
```
Sources/
  App/            VoiceDiaryApp, RootView
  DesignSystem/   Theme(Palette) / Spacing(Metric) / Typography(Font) / Components(PaperLines…)
  Models/         DiaryEntry, VoiceMemo（SwiftData，CloudKit 同步兼容）
  Managers/       DataManager（streak / 演示种子）…后续：录音/转写/通知/隐私锁/购买/导出
  Features/       Cover / List / Editor / Detail / Settings …
  Resources/      Assets.xcassets, zh-Hans.lproj, en.lproj
Support/          VoiceDiary.entitlements, VoiceDiary.storekit
```

## 设计系统（区别于旧工程的关键）
- **固定 pt token，不再按机型等比缩放**（旧工程 `W_SCALE/H_SCALE` 是失真根源）。
- 颜色 `Palette`（浅/深双色自适应）、间距圆角 `Metric`、字号 `Font.d*`、纸纹 `PaperLines`。
- 配色：纸张 `#FBF3E3` / 卡片白 / 主色橙 `#C8763A` / 皮革 `#6B4226→#4A2C17` / 暗金 `#D8B56A` / 暗夜棕 `#2B2420`。

## 红线
- **录音/转写全程端侧，不经过开发者或第三方服务器**（Speech 强制 on-device）。
- iCloud 同步走用户自己的私有 iCloud（`NSPersistentCloudKitContainer`），开发者看不到内容。音频也随私有 iCloud 同步（低码率 AAC）。

## 进度

### 已完成（2026-06-16/17 redesign-v2）

#### 翻页引擎
- [x] `UIPageViewController(.pageCurl)` 真实翻书效果，DataSource/Delegate 全部 `nonisolated + MainActor.assumeIsolated`
- [x] `BookNavigator`（`@MainActor final class`）程序化翻页：`goToList() / goToSettings() / goToEntry(at:)`
- [x] 多页连翻动画：每页间隔 70ms 顺序调用 `setViewControllers`，模拟真实翻多页效果
- [x] 页面结构：`[0=封面, 1=设置, 2=目录, 3..N=日记详情]`，direction 根据目标 index 自动判断
- [x] `ThemedPage` wrapper 解决 `UIHostingController` 内主题切换不生效问题（`@Observable ThemeManager` 动态读取）
- [x] 翻页音效（`fp3.m4a`），`UserDefaults "isSoundEnabled"` 控制开关
- [x] 禁用 `UITapGestureRecognizer`，防止 pageCurl 单击拦截设置页 Toggle 等控件

#### 封面页（CoverView）
- [x] 标题字体加大一倍（"我 的 日 记" 60pt bold，"VOICE DIARY" 22pt semibold）
- [x] 连续打卡 streak 徽章、「轻触翻开」提示改用 `.dSubhead`

#### 目录页（DiaryListView）
- [x] 标题从「日记」改为「目录」
- [x] 每条 cell 右下角显示「第 n 页」胶囊（离目录最近 = 第 1 页，依次递增）
- [x] 移除顶部 EmojiBubbleView 储蓄罐
- [x] 设置按钮点击通过翻页动画跳转到设置页
- [x] FAB「+」改为 `DraggableFAB`（可拖拽悬浮，按下拖动改变位置，点击触发新建）

#### 详情页（DiaryDetailView）
- [x] 左上角「返回目录」胶囊按钮（图标 + 文字）
- [x] 顶栏右侧：垃圾桶（删除，红色）+ 铅笔（编辑），纯图标圆形按钮
- [x] 正文使用 `SelectableTextView`（`UITextView` 封装），长按弹「选择 / 全选」→ 选区后弹「拷贝」，标准 iOS 文字选择交互
- [x] 正文区 `frame(maxHeight: .infinity)` 填满剩余屏幕空间，`UITextView` 内部自行滚动超长内容
- [x] 语音条 / 图片条 / 日期 / 地点固定在文本区下方，始终可见不被挤出屏幕
- [x] 地点单独一行显示（不与日期并排）
- [x] 详情页也有可拖拽 FAB「+」（点击新建日记）

#### 编辑页（AddDiaryView）
- [x] 移除 Emoji 选择 pills 行，emoji 字段保留在 Model 但 UI 不展示
- [x] 布局与详情页保持一致：正文 → 语音 → 图片 → 日期 → 地点
- [x] 正文 `TextEditor` + `frame(minHeight: 120, maxHeight: .infinity)` 填满剩余空间，内部自行滚动
- [x] 语音条支持删除（`xmark.circle.fill`），「添加语音」/ 「录音」按钮左对齐
- [x] 图片栏 60×60 缩略图，支持删除
- [x] 地点行：图钉按钮开关，开启后自动 CLGeocoder 反地理编码填充，可手动编辑

#### 设置页（SettingsView）
- [x] 无 NavigationStack / 无「完成」按钮，通过 `bookNavigator` 翻页进入
- [x] 付费墙横幅置于顶部（仅未购买时显示）
- [x] 每日提醒 + 翻页声音 Toggle
- [x] 关于区：隐私政策、分享给朋友（UIActivityViewController）、意见反馈（mailto）、其他产品、恢复购买
- [x] 主题切换（橙调 / 暗金 / 茶绿），实时生效

#### 共用组件
- [x] `DraggableFAB`（`DesignSystem/Components/`）：拖拽手势 + 单击区分，初始位置右下角
- [x] `EmojiBubbleView`（SpriteKit + CoreMotion 重力感应 + CHHapticEngine）：代码保留，暂不挂入目录
- [x] Swift 6 并发：`nonisolated` + `MainActor.assumeIsolated`，`@preconcurrency import CoreMotion`

---

### 待完成
- [ ] 录音功能（AVAudioRecorder + Speech on-device `requiresOnDeviceRecognition = true`）
- [ ] 统计页（StatsView）
- [ ] PDFKit 导出（付费功能）
- [ ] 详细方案与设计图：`REBUILD_PLAN.md`、`voice-feature-mockups.html`（backup 里，待迁入）
