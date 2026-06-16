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
- [x] 工程骨架 + 设计系统 + 模型（含 VoiceMemo）
- [x] 封面页（皮质）+ 列表页样板（含 🎤 语音标记）
- [ ] 翻页引擎（pageCurl）/ 写日记(pills+录音) / 详情(语音条) / 设置 / 统计 / 导出 / 付费
- [ ] 录音功能（AVAudioRecorder + Speech on-device，方案见 `../VoiceDiary-backup/REBUILD_PLAN.md`）
- 详细方案与设计图：`REBUILD_PLAN.md`、`voice-feature-mockups.html`（在 backup 里，待迁入）
