# Mac 本机构建 iOS 包与上架

> 本机：家里 Mac。iOS 的**编译、签名、上传、送审只能在这台机器**完成（依赖 Xcode / Transporter，无 Windows 版）。
> Android 双机都能出，见《双机出包约定.md》；鸿蒙见《Mac本机构建鸿蒙包.md》。
> 整理日期：2026-10-23，基于 1.0.0 (5) 送审全流程实录。

---

## 一、环境清单

| 组件 | 版本 / 值 |
|---|---|
| macOS / Xcode | Xcode **26.3**（Build 17C529） |
| Flutter SDK | **3.47.5** stable（与 Windows 一致） |
| Apple ID | `leihaocs@foxmail.com` |
| Team ID | `6D7W6L5VH9` |
| Bundle ID | `com.bookmovie.revisit.app` |
| App Store Connect App ID | `6817832283` |
| 内购商品 ID | `com.bookmovie.revisit.app.pro.lifetime`（非消耗型） |
| 上传工具 | Transporter（Mac App Store 免费）/ `xcrun altool` |
| API 私钥 | `~/Codes/appbackup/` 下的 `AuthKey_*.p8`（**不入库**） |

---

## 二、出包流程

### 一键脚本（推荐）

```bash
cd ~/Projects/shuying/flutter_app

./tool/ios_ipa.sh testflight   # 产出本地 IPA，交给 Transporter 上传 TestFlight
./tool/ios_ipa.sh app-store    # 由 Xcode 直接上传 App Store Connect（本地不出 IPA）
./tool/ios_ipa.sh development  # 本地调试包（免费账号可用）
./tool/release.sh ios          # 等价入口，内部调用 ios_ipa.sh auto
```

脚本会自动完成：探测签名证书 → 推断 Team ID → 生成 `ExportOptions.plist` → `pod install` → 从 `pubspec.yaml` 注入版本号 → `flutter build ipa`。

### 手工等价步骤

```bash
flutter pub get
(cd ios && pod install)          # 不做这步会报 "sandbox is not in sync with the Podfile.lock"
flutter build ipa --release \
  --dart-define="APP_VERSION=1.0.0 (5)" \
  --export-options-plist=ios/ExportOptions-AppStore.plist
```

产物：`build/ios/ipa/*.ipa`，归档到仓库根目录 `dist/1.0.0+N/`。

### 上传到 TestFlight / ASC

```bash
# 方式一：Transporter（最稳）
#   打开 Transporter → 同一 Apple ID 登录 → 拖入 IPA → 交付

# 方式二：命令行
xcrun altool --upload-app -f <IPA路径> -t ios --apiKey <KEY> --apiIssuer <ISSUER>
```

上传后在 ASC → TestFlight → 内部测试组添加该构建，处理完（通常几分钟到十几分钟）即可装到手机。

---

## 三、版本号与构建号

当前正式基线为用户指定的 5，候选号固定 6。只有用户明确指定新的正式构建号，才调整为新正式号 +1；重复编译、审核通过/失败和上传冲突均不自动升号。构建入口会执行 `tool/build_version.sh` 校验。

- **唯一来源**：`flutter_app/pubspec.yaml` 的 `version: 1.0.0+N`
- 构建号 = `N`，注入到 Xcode 的 `CURRENT_PROJECT_VERSION`
- 若商店提示构建号重复或不符合其接收要求，报告用户处理；不得因此自行改变正式基线或候选号

### ★ 坑 1：改了 pubspec，构建号却没变

**现象**：`pubspec.yaml` 已改成 `1.0.0+5`，但打出来的包仍是 `(4)`，上传被 Apple 拒绝 —— *"版本必须高于已上传的 4"*。

**原因**：Flutter 的 `ios/Flutter/Generated.xcconfig` 没同步 `FLUTTER_BUILD_NUMBER`，Xcode 读到的还是旧值。

**处理**：

```bash
# 确认实际生效的构建号
grep -E "FLUTTER_BUILD_NUMBER|FLUTTER_BUILD_NAME" ios/Flutter/Generated.xcconfig

# 不对就清缓存重来
flutter clean && flutter pub get && (cd ios && pod install)
./tool/ios_ipa.sh testflight
```

**出包后务必核对 IPA 里的真实构建号**（`Info.plist` 的 `CFBundleVersion`），不要只看 pubspec。

---

## 四、上架资料清单

| 项目 | 位置 | 本次实际值 |
|---|---|---|
| 名称 | App 信息 | 书影温故 |
| 副标题 | App 信息 | 记录你的读书与观影轨迹 |
| 类别 | App 信息 | 主 **图书**（BOOKS）／副 **娱乐**（ENTERTAINMENT） |
| 描述 / 关键词 | 版本页 | 见 `store/ios上架资料填写清单.md` 草稿 |
| **版权** | **版本页**（不是 App 信息页！） | `Hao Lei` |
| 内容版权问卷 | App 信息 | 选「**否**，不包含第三方内容」（选否即无需输入文字） |
| App 隐私 | App 隐私 | 「**不收集数据**」（本次无网络请求、无统计 SDK） |
| 年龄分级 | App 信息 | 问卷全选「无」 |
| 审核联系 | 版本页 → App 审核信息 | 姓名 / 电话 / 邮箱 + 备注（含沙盒账号） |
| 演示账号 | App 审核信息 | **留空**（无需登录，留空反而更快） |
| 备案号 | App 内设置页 + 版本资料 | 粤ICP备2026143055号-2A |
| 发布方式 | 版本页 | **手动发布**（`AFTER_APPROVAL`） |

### ★ 坑 2：版权字段找不到输入框

页面上只看到「内容版权」问卷（选是/否），找不到填版权文本的地方。

**原因**：新版 ASC 把 `copyright` 放在**版本级**资源上，不在 App 信息页。

**两种填法**：

1. 版本页里找「版权」栏直接填（填完要保存）
2. 用 API（App Store Connect API）：

```bash
curl -X PATCH "https://api.appstoreconnect.apple.com/v1/appStoreVersions/<版本ID>" \
  -H "Authorization: Bearer <JWT>" -H "Content-Type: application/json" \
  -d '{"data":{"type":"appStoreVersions","id":"<版本ID>","attributes":{"copyright":"Hao Lei"}}}'
```

类别也可以用 API 写（`appInfos` 的 `primaryCategory` = `BOOKS`、`secondaryCategory` = `ENTERTAINMENT`）。

---

## 五、截图

### 当前 ASC 的槽位（2026 版）

| 槽位 | 要求 | 本次 |
|---|---|---|
| 带灵动岛的 iPhone（中等显示屏） | 6.1 / 6.3 寸规格（如 1206×2622） | 5 张 ✓（必需） |
| iPad 13 英寸 | 2064×2752 | 3 张 ✓（项目支持 iPad） |
| iPhone Duo | 1398×2034 或 2007×2853 | 未传（**可选**，不影响送审） |
| Apple Watch | — | 不涉及 |

> 注意：**已经没有独立的 6.9 寸槽位了**。老教程里说的"必须交 6.9 寸"在当前界面不适用，把 6.9 尺寸的图拖进「中等显示屏」会报"文件尺寸无效"。

### 素材位置

```
dist/screenshots/iphone-6.3-real/   真机 5 张（已上传）
dist/screenshots/ipad-13/           iPad 3 张（已上传）
dist/screenshots/duo-2007/          iPhone Duo 备用（2007×2853，需要时传）
dist/screenshots/duo-1398/          iPhone Duo 备用（1398×2034）
```

### ★ 坑 3：模拟器截不出可用图

iOS 26.3 模拟器**不渲染 emoji**，底部 tab 和封面会显示成 `?`。真机截图完全正常。

结论：iPad 截图要么用真机，要么只交 1 张（Apple 最低要求），别在模拟器 emoji 上耗时间。

---

## 六、内购与送审（本次最关键）

### 送审前

- 商品 `com.bookmovie.revisit.app.pro.lifetime` 状态须为 `READY_TO_SUBMIT`
- 沙盒测试员已创建（用户和访问 → 沙盒测试员），**邮箱必须是没注册过 Apple ID 的地址**
- 审核备注里写清沙盒账号与密码，否则审核员无法验证内购

### ★ 坑 4：从版本页发起送审，内购挂不进去

**现象**：在版本 1.0 点「添加以供审核」，弹窗里**只有 iOS App 1.0，没有 Pro 内购**；版本页也找不到「App 内购买项目」添加入口；从草稿页进去也没有「+」按钮。

**正确做法**（本次实测有效）：

1. 左侧栏 → **App 内购买项目** → 点 **Pro 永久解锁**
2. 在商品详情页点 **「提交以供审核」**
3. 系统会创建一个提交草稿并挂上 Pro，提示"请为此平台添加 App 版本"
4. 在**这个草稿**里把 **iOS App 版本 1.0** 也加进来
5. 确认列表同时有两条：

```
✅ iOS App 1.0（1.0.0 (5)）
✅ 书影温故 Pro 永久解锁
```

6. 点 **提交以供审核**

**原因**：从内购侧发起时，草稿允许把 App 版本一起带进来；反过来从版本页发起，弹窗里没有加内购的入口。这是界面设计的问题，不是配置错误。

**影响**：如果只提交了 App 版本而没带内购，App 上架后 Pro 会无法购买（提示"无法完成购买"）。

### 提交后

- 状态 → `WAITING_FOR_REVIEW`（等待审核），通常 1-2 个工作日
- 通过 → `PENDING_DEVELOPER_RELEASE` → 回版本页点 **发布此版本**（手动发布）
- 被拒 → 按 Resolution Center 的理由修改后重提

---

## 七、踩坑速查

| # | 现象 | 原因 / 解法 |
|---|---|---|
| 1 | 构建号没变，上传被拒 | `Generated.xcconfig` 未同步，`flutter clean` 后重打（见坑 1） |
| 2 | 找不到版权输入框 | 版权在**版本级**，见坑 2 |
| 3 | 截图提示"文件尺寸无效" | 尺寸与槽位不匹配；现在没有 6.9 槽位，别往中等显示屏拖 6.9 图 |
| 4 | 模拟器截图 emoji 变 `?` | 模拟器渲染缺陷，用真机图 |
| 5 | 送审列表里没有内购 | 从**内购页**发起提交，见坑 4 |
| 6 | Xcode 上传报 `Failed to Use Accounts` | 改用 **Transporter** 登录同一账号上传 |
| 7 | `sandbox is not in sync with Podfile.lock` | 打包前执行 `(cd ios && pod install)` |
| 8 | 构建号回退被拒 | 核对实际上传记录并报告用户，不能自行升号 |

---

## 八、命令速查

```bash
# 证书与账号
security find-identity -v -p codesigning
defaults read com.apple.dt.Xcode | grep teamID

# 出包
./tool/ios_ipa.sh testflight

# 核对包内版本
unzip -p build/ios/ipa/*.ipa Payload/Runner.app/Info.plist \
  | plutil -p - | grep -E "CFBundleShortVersion|CFBundleVersion"

# 归档
mkdir -p dist/1.0.0+N && cp build/ios/ipa/*.ipa dist/1.0.0+N/
```
