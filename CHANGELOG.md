# Changelog

## 1.0.0+2 候选版本 - 2026-10-02（未上传）

- 本机记录迁移至私有 JSON 文件，串行原子写入，保留上一份并提示保存错误。
- 三端系统文件选择器导出/导入 JSON，取消覆盖导入，嵌套记录按 ID 合并、重复导入去重。
- 免费基础功能与 Pro 年度回顾分层，接入 StoreKit 2 / Google Play Billing 商品、购买与恢复；商品后台及真实交易待验证，鸿蒙/国内渠道购买尚未接入。
- 修正网页与应用内隐私政策，政策版本变更重新请求同意。
- 24 项自动测试通过；iOS 无签名 Release、正式签名 IPA 导出和鸿蒙签名 Release HAP 构建通过；Android SDK / NDK 已补齐并完成正式签名 APK 构建。
- 详细后续步骤见 store/Pro与跨端备份实施进度.md。

## 鸿蒙支持范围 - 2026-10-02

- 用户确定最低支持 HarmonyOS 6，重点验收 Mate 80 / HarmonyOS 7；HarmonyOS 5 不纳入首发支持承诺。
- 现有 API 15 HAP 不标记为已适配 6/7；官方 SDK 升级评估、华为签名和双版本真机验收尚待完成。

## 三端测试包 - 2026-10-02

- 三端统一候选版本 1.0.0 (2)，交付目录 dist/1.0.0-2/。
- 鸿蒙重新注入设置页版本号；现有 HAP 使用 OpenHarmony 调试签名，华为零售真机安装需配置匹配设备的华为证书/Profile。
- Android 补齐 SDK/NDK 与 Kotlin 插件，原生文件选择器和 Play Billing 编译通过，APK 使用现有 release 密钥。

## 发布进度 - 2026-10-01

- iOS 1.0.0 (1) 已导出正式分发 IPA（Apple Distribution，Team 6D7W6L5VH9）。
- 用户确认 iPhone 13（iOS 27）已通过 TestFlight 安装并打开书架，原始截图已归档到 store/testing/。
- 阿里云域名已申请，ECS 未购买；完整回归、商店资料与备案路径核实进入并行阶段。
- 根目录发布手册更新为当前进度，纠正账号待审批、旧 Team ID、图标不存在及 iOS 需统一等待软著等历史说法。

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
