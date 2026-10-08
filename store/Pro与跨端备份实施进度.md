# Pro 与跨端备份实施进度

更新：2026-10-02。用户已在 iPhone 13（iOS 27）通过 TestFlight 安装旧构建；本次修改尚未上传 TestFlight。

## 版本功能

| 功能 | 免费 | Pro 一次性解锁 |
|---|---|---|
| 书籍、阅读轮次、阅读记录、电影与观影记录 | 支持 | 支持 |
| 基础统计、主题、JSON 文件/文本备份与合并 | 支持 | 支持 |
| 按年份回顾、12 个月阅读/观影趋势、复制年度报告 | 仅示例预览 | 使用实际数据 |

购买不随 JSON 导出，不保证跨商店会员互通；同一商店账号使用恢复购买。当前没有云同步和订阅。界面价格来自商店，未配置商品时显示不可用，不虚构价格或本地解锁。

## 数据与互通

- 记录从旧 shared_preferences 自动迁移到应用私有 `state.v1.json`；串行写入、刷新临时文件后原子替换，保留 `.previous` 上一份。
- 保存期间有指示，失败显示重试提示；损坏本地文件阻止修改，不用空数据覆盖。仍需真机验证立即强制退出、升级迁移与低存储情况。
- iOS、Android、鸿蒙使用同一 JSON schema 1：`app=bookmovie_revisit`，包含 books/movies、轮次、日志及观影记录，时间用 UTC。
- 导入只合并，不提供覆盖恢复：按稳定 ID 去重，书籍/电影字段取更新时间较新的版本；嵌套记录合并，重复导入不重复。相同 ID 的同一日志冲突以所属条目的更新顺序决定；这不代替实时多设备同步。
- 相同书名但不同 ID 保留为不同条目。删除不传播；导入旧备份可能恢复曾删除的条目。空备份不会清空，非法格式先整体验证后拒绝，文件上限 20 MB。
- 三端已编写系统文件选择器桥接；iOS Release 原生编译与鸿蒙完整 Release HAP 构建通过，各端实际文件往返仍需设备验收。

## 购买准备（必须完成后才宣称可销售）

### iOS

1. App Store Connect → 协议、税务和银行业务：完成付费协议、税务及收款资料。
2. App → App 内购买项目：创建非消耗型「Pro 永久解锁」，产品 ID `com.bookmovie.revisit.app.pro.lifetime`，设置售价、地区、本地化及审核截图。
3. 代码已接入 StoreKit 2 商品查询、签名验证、购买、恢复、退款/撤销权益刷新。创建沙盒测试账号或使用 TestFlight 测试：成功、取消、待处理、重装恢复、退款。
4. 首次内购与新版本一起提交审核；核对购买页、隐私网页、审核说明一致。

### Google Play

1. Play Console 完成开发者和商家资料；创建同 ID 的非消耗型一次性商品及购买选项，配置价格与测试账号。
2. 在本机 Gradle 用户属性配置 `PLAY_LICENSE_KEY=<Play Console 应用许可 RSA 公钥>`，不将其与私钥混淆；构建后从内部测试轨道安装。
3. 代码接入 Billing 8.3.0、商店报价/offer token、购买签名验证、交易确认及恢复查询。Android SDK 已补齐，原生 Release APK 已编译并签名；Play 实际购买尚未验证。
4. 本地验签和商店查询已实现；后续服务器验单、退款通知及跨商店账号权益尚未实现，不能对外承诺这些能力。

### 国内 Android / 鸿蒙

现有 Google Play 购买不能用于国内渠道。鸿蒙基础功能和 JSON 文件桥接已实现，但当前是 OpenHarmony SDK 工程，尚无华为 IAP 和各国内商店支付实现。先核实对应商店个人开发者的付费/结算资格，再取得正式 SDK、商品和测试环境接入；没有验证的渠道保持不可购买，不给测试按钮伪造 Pro。

## 执行顺序与预计工作天数

天数是工作量估计，不包含备案、商店审核及账户审核等待。

| 步骤 | 用时 | 在哪里、怎么做 | 并行关系 |
|---|---|---|---|
| 1 数据真机验收 | D1–D2 | 新构建覆盖安装；先备份，测试记录保存、重启、迁移、损坏输入和两端反复合并 | 与 2、3 并行 |
| 2 商业后台配置 | D1–D2 | Apple/Play 完成协议、商品、价区、测试账号；确认鸿蒙/国内商店结算资格 | 与测试并行 |
| 3 网站与备案资料 | D1–D3 起 | 部署新版隐私和支持页，核对 URL；按已确定的联网 APP 流程办理备案 | 与开发、测试并行；外部等待另计 |
| 4 真购买与恢复验收 | D3–D4 | TestFlight/Play 内测；购买、取消、待处理、恢复、退款；截图登记 | 依赖 2 和可安装构建 |
| 5 三端文件往返 | D3–D4 | iOS 导出→安卓/鸿蒙导入→新增→导回 iOS；重复导入核对全部记录 | 依赖各端构建；可与 4 并行 |
| 6 上架资料收尾 | D4–D5 | 商店文案、最终 UI 截图、年龄分级、隐私/数据安全、价格地区、审核联系人和内购审核截图 | 可先填草稿；依赖最终行为 |
| 7 候选版本与提交 | D5–D6 | 修复验收问题，递增构建号，签名打包；只提交验收通过的渠道 | 依赖前述必需项；各商店可并行 |

ECS 购买不作为本地记录或 iOS StoreKit 编译前提。备案接入与未来服务器验单如采用阿里云方案，再按实际部署选购。不要把等待备案或购买服务器等同于已完成上线条件。

Google Play 一次性商品的 offer token 接入参考：[Android 官方文档](https://developer.android.com/google/play/billing/one-time-product-multi-purchase-options-offers)。

## 本次验证结果与产物

- 24 项 Flutter 自动测试通过，`flutter analyze --no-pub` 无问题。
- iOS 1.0.0 (2) 已完成签名归档和 App Store 类型本地 IPA 导出（约 21 MB）：`flutter_app/build/ios/ipa/Reel&Read.ipa`。尚未上传。构建提示启动图仍为默认占位素材，正式发布前检查启动页。
- 鸿蒙完整 Release HAP 构建通过：`flutter_app/ohos/entry/build/default/outputs/default/entry-default-signed.hap`；该工程使用本地调试签名，商店签名和真机验收另做。
- Android SDK / NDK 已安装，Release APK 构建通过，版本 1.0.0 (2)，包含 arm64-v8a、armeabi-v7a、x86_64；最低 Android API 24。

下一步先在 Apple 后台配置 Pro 商品，再通过 Transporter 上传新版 IPA，使用已有 iPhone 13 覆盖安装验收。与此并行更新公网隐私页面、准备商店资料和备案；Android 原生构建已完成，鸿蒙支付需明确正式目标 SDK 与商家资格。

三端统一交付目录为 `dist/1.0.0-2/`。鸿蒙包使用 OpenHarmony 本地调试证书、Profile 无登记设备；零售华为手机须先确认系统并配置匹配设备的华为调试签名。目前 `hdc list targets` 未检测到连接设备。

Android APK 签名验证通过，证书 MD5 与登记一致；同版 Google Play AAB 也已产出。详细包路径和安装步骤见 [三端测试包与鸿蒙真机安装](三端测试包与鸿蒙真机安装.md)。

目标鸿蒙设备已确认为华为 Mate 80 / HarmonyOS 7。现有 OpenHarmony API 15 HAP 未经该设备验证，需核对官方对应 SDK 与真机签名；电脑尚未检测到该设备。

## 鸿蒙版本支持决策（2026-10-02）

- 发布最低支持：HarmonyOS 6.0（API 20）；重点支持和真机验收：HarmonyOS 7，用户设备为 Mate 80。
- HarmonyOS 5 不纳入首发支持承诺和必测矩阵，不为其增加额外兼容分支。当前记录、文件选择器和统计代码没有证据显示支持 5 必然引发问题；主要成本是旧版 Flutter/依赖兼容和增加设备回归测试。排除 5 是控制首发范围，不是断言该系统有问题。
- 使用一份 HAP 覆盖 6 和 7，不为两个系统维护不同 JSON 协议或业务代码。
- 正式开发套件升级评估目标为 HarmonyOS 7 对应 API 26，最低兼容字段为 `6.0.0(20)`。须根据新工具的实际格式配置 compile/target SDK 并验证 Flutter 引擎及插件，禁止仅改数字宣称适配完成。
- 当前已有 HAP 仍是 OpenHarmony API 15 的编译与本地签名产物，不作为“最低 6、已适配 6/7”的正式包。尚未升级官方 SDK，也没有完成华为真机签名。
- 验收必须同时包含：Mate 80 / HarmonyOS 7 真机，以及 HarmonyOS 6 的真实设备或可信远程设备测试。模拟器仅补充布局检查，不能替代真机文件选择、保存和安装验签。
- 两个系统均测试：覆盖升级数据迁移、立即退出保存、JSON 文件双向合并、系统文件选择器、主题/统计；Pro 支付另依赖华为 IAP 接入与商品配置。

参考：[华为官方升级适配指南](https://developer.huawei.com/consumer/en/doc/harmonyos-releases/upgrade-adaptation)，[HarmonyOS 6 API 20 官方变更说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-releases/apidiff-6002)。
