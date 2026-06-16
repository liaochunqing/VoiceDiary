# VoiceDiary（全新工程）

「能翻页的皮质日记本 + 语音日记」。2026-06-16 从零重建（旧工程见 `../VoiceDiary-backup`，仅作历史参考）。

## 复用的上架 ID（其余全部重建）
- Bundle ID：`com.chunqingliao.VoiceDiary`
- App Store ID：`6670278331`，显示名「翻页日记」
- IAP product：`com.chunqingliao.VoiceDiary.fullunlock`（一次性买断 ¥15，NonConsumable）
- iCloud 容器：`iCloud.com.chunqingliao.VoiceDiary`（CloudKit 私有库）
- Team：`8X79G5XCU6`，部署目标 iOS 17.5，仅 iPhone

## 工程方式
- **XcodeGen**：改配置改 `project.yml`，然后 `xcodegen generate` 重新生成 `.xcodeproj`（生成物，不手改）。
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
