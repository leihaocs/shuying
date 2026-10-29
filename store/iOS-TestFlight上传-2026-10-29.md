# iOS TestFlight 上传记录

2026-10-29。用户已明确授权上传现有 iOS 1.0.0(6) 到 TestFlight，不自动提交 App Review 或发布。

- IPA：`dist/1.0.0-6/20261029-release/shuying-ios-1.0.0-6.ipa`。
- 已重新读取包内 Info.plist，确认为 `com.bookmovie.revisit.app`、1.0.0(6)，SHA-256 与成品清单一致：`089d67b781d232f65f78a7c6782d3499645043db2b3d89ef2b76d8eb6a16b947`。
- 尝试复用 Xcode 已保存登录上传现有归档，明确设置 `manageAppVersionAndBuildNumber=false`。命令返回 `exportArchive Failed to Use Accounts`，没有上传成功。
- 用户已提供 Issuer ID，使用既有私钥完成 API 认证，确认 App ID 为 `6817832283`。认证配置仅保存在本机，不将私钥或令牌写入项目。
- 已实际提交现有 IPA，Apple 返回两项 409 校验错误：`Invalid Pre-Release Train`（1.0.0 已关闭新构建提交），以及 `CFBundleShortVersionString` 必须高于已批准的 1.0.0。上传日志：`/private/tmp/shuying-testflight-upload-6.json`。
- 已通过 App Store Connect API 确认未出现构建 6。注意：本次 altool 即便退出码为 0，日志仍明确为 `UPLOAD FAILED`，不得判为成功。
- 用户已明确同意仅将 iOS 营销版本调整为 **1.0.1(6)**。`build_version.sh` 记录 iOS 专用营销版本，`ios_ipa.sh` 传入明确版本参数，并设置 `manageAppVersionAndBuildNumber=false`；正式基线仍为 5、构建号仍为 6。版本守卫检查通过，误升到 7 仍会被拒绝。
- 新 IPA：`dist/1.0.1-6/20261029-ios-testflight/shuying-ios-1.0.1-6.ipa`，21.71 MiB，SHA-256：`8fa07dd37e2715b8018be75c796d7f5004e68d5ad30fa1814f24b962b94d369d`。
- 包内核对：`com.bookmovie.revisit.app`，1.0.1(6)，最低 iOS 15.0；`codesign --verify --deep --strict` 通过，Apple Distribution / Team `6D7W6L5VH9`，App Store Profile，无调试权限、无设备限制。包内已有 `ITSAppUsesNonExemptEncryption=false`。
- Apple 于 19:30 接收新包，明确返回 **`UPLOAD SUCCEEDED with no errors`**，Delivery UUID：`fe86c84a-4520-46ae-9a48-a45bf8d9af1b`。
- 最终状态：**上传成功，Apple 处理通过，已启用内部测试**。App Store Connect 返回营销版本 `1.0.1`、构建号 `6`、`processingState=VALID`。已将该构建加入既有“内部测试”组（写入返回 204），再次读取确认组内包含该构建，`internalBuildState=IN_BETA_TESTING`。可以在 iPhone TestFlight 中安装。
- Build ID：`fe86c84a-4520-46ae-9a48-a45bf8d9af1b`；内部测试组 ID：`abf6ff2d-79a0-403c-ac67-8495f9906d07`。状态摘要归档于 `dist/1.0.1-6/20261029-ios-testflight/testflight-status.json`。
- 上传日志：`/private/tmp/shuying-testflight-upload-101-6.json`。鸿蒙与安卓原包的六项 SHA-256 全部复核通过，未创建或撤销密钥、未操作界面、未提交 App Review 或发布。

Issuer ID 的位置依据 [Apple 令牌文档](https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests)：App Store Connect → Users and Access → Integrations，页面顶部的 Issuer ID。
