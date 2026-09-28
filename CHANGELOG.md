# Changelog

## 1.0.0+1 - 2026-09-22

### 新增
- 书影温故（Reel&Read）Flutter 三端应用首发：iOS / Android / HarmonyOS。
- 阅读与观影记录：支持书籍（想读/在读/再读/已读 N 次）与电影的多轮观看记录。
- 纯本机存储：基于 `shared_preferences` 的 JSON 持久化，无后端、无账号。
- 隐私门：首次启动需同意隐私政策，同意后进入主页。
- 统计页：可视化阅读与观影概览。
- 设置页：主题模式切换、隐私政策、撤回同意、清空所有数据、关于与版本信息。

### 平台
- Android：包名 `com.bookmovie.revisit.app`，release APK 已签名。
- iOS：Bundle ID `com.bookmovie.revisit.app`，未签名归档已产出
  （`build/ios/Runner.xcarchive`）；本机 Xcode 已升级到 26.6。
  出包需付费开发者账号：`./tool/ios_ipa.sh testflight`（TestFlight 内部测试，免审核）
  或 `./tool/ios_ipa.sh app-store`（App Store 上架）。
  免费 Personal Team 无法签发 Distribution 证书，且真机注册受 Xcode 版本限制。
- HarmonyOS：包名 `com.bookmovie.revisit.app`，API 15，自签 release HAP
  （真机调试用；上架华为应用市场需在 AGC 换取正式证书重新签名）。

### 杂项
- 【更名】应用中文名改为「书影温故」，英文名 `Reel&Read`
  （三端显示名、iOS `CFBundleName`、Android `android:label`、鸿蒙 `app_name` 已全部同步）。
- 三端应用显示名统一为“书影温故”。
- 替换默认 Flutter logo 为书影温故品牌图标（书本 + 胶片光影）。
- 移除 HarmonyOS 未使用的 `ohos.permission.INTERNET` 权限。
- 修复隐私政策文案与实际行为一致：当前版本不申请任何系统权限；联系邮箱改为 `leihaocs@gmail.com`。
- 新增 iOS `PrivacyInfo.xcprivacy` 并挂入 Runner 资源阶段，声明 `UserDefaults` / `FileTimestamp` / `DiskSpace` 用途，避免 ITMS-91053。
- iOS 工程已写入 `DEVELOPMENT_TEAM = Y25KP5S862`（Personal Team）。
- 新增 `tool/generate_screenshots.sh`：基于 iPhone 17 Pro Max 模拟器自动生成 6.9" / 6.5" / Android / 鸿蒙 9:16 截图。
- 新增 `store/上架素材.md` 与根目录 `privacy.html`（可直接公网托管）。
