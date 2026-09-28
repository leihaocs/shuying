# 书影温故 (Reel & Read) · Flutter 三端版

一套 Dart 代码，同时构建 **iOS / Android / HarmonyOS**。

| 项 | 值 |
|---|---|
| 中文名 | 书影温故 |
| 英文名 | Reel & Read |
| 包名 / Bundle ID / bundleName | `com.bookmovie.revisit.app` |

> 上架（开发者注册、三端签名、提交审核）的完整流程见
> [`docs/三端开发者注册与上架执行流程.md`](docs/三端开发者注册与上架执行流程.md)；
> 软著、备案、隐私政策的细节见 [`docs/上架前置资质与备案指引.md`](docs/上架前置资质与备案指引.md)；
> 备案认证按顺序一步步执行见 [`docs/备案认证执行手册.md`](docs/备案认证执行手册.md)；
> **Windows / macOS 两台机器分别做什么**见 [`docs/双机分工与交接清单.md`](docs/双机分工与交接清单.md)。

- 记录每本书的阅读轨迹：页数、时长、进度、多轮重读
- 书籍状态：想读 / 在读 / 再次阅读 / 已读 N 次
- 记录每部电影：想看 / 已看 N 次，含观看时间与星级
- 统计：阅读时长、累计页数、近 7 天趋势、最近动态
- 数据全部保存在本机（`shared_preferences`），无需后端、无需登录

---

## 一、目录结构

```
flutter_app/
├── pubspec.yaml
├── lib/
│   ├── main.dart                  入口，注入 Store 与主题
│   ├── models/models.dart         数据模型 + JSON 序列化（uid / Book / Movie / 轮次 / 记录）
│   ├── domain/
│   │   ├── books.dart             书籍状态推导、进度计算、汇总
│   │   ├── movies.dart            电影状态推导
│   │   └── fmt.dart               日期/时长格式化
│   ├── store/app_store.dart       全局状态 + 本地持久化（唯一的存储出入口）
│   ├── theme/app_theme.dart       设计令牌与明暗主题
│   ├── widgets/                   CardBox / Pill / ProgressRing / 表单抽屉 等
│   └── pages/                     书架、书籍详情、电影、电影详情、统计
├── android/                       Android 平台工程（flutter create 生成）
└── tool/
    ├── bootstrap.sh               一键生成三端平台工程
    ├── gen-keystore.ps1           生成 release 签名密钥（Windows）
    └── gen-keystore.sh            生成 release 签名密钥（macOS/Linux）
```

> 迁移说明：`lib/models` + `lib/domain` + `lib/store` 与原 Web 版的
> `src/types.ts` / `src/lib/*.ts` / `src/store.tsx` 是逐函数对应的，业务逻辑没有丢。

---

## 二、环境准备

| 工具 | 用途 | 安装 |
|---|---|---|
| Flutter SDK ≥ 3.22 | 通用三端 | `brew install --cask flutter` 或官网下载 |
| Xcode ≥ 15 | iOS 构建 | App Store，装完执行 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| CocoaPods | iOS 依赖 | `sudo gem install cocoapods` |
| Android Studio + JDK 17 | Android 构建 | 官网；SDK Manager 装 Android SDK / Build-Tools |
| DevEco Studio ≥ 5.0 | 鸿蒙签名与上架 | 华为开发者官网 |
| OpenHarmony Flutter SDK | 鸿蒙构建 | 见第五节 |

检查：

```bash
flutter doctor -v
```

`Android toolchain` 与 `Xcode` 两项必须是 ✅。

> ⚠️ Windows 上可以开发和构建 Android（需另装 Android Studio + JDK），但 **iOS 必须 macOS**，
> 鸿蒙出包也建议在 macOS 上配合 DevEco Studio 完成。

---

## 三、生成平台工程

`lib/` 是跨端共享的，`android/ ios/ ohos/` 三个平台目录需要由 Flutter 生成
（平台模板随 SDK 版本变化，由工具生成比手写可靠）。

```bash
# macOS / Linux
cd flutter_app
chmod +x tool/bootstrap.sh
./tool/bootstrap.sh com.bookmovie.revisit.app
```

或者手动执行：

```bash
flutter create --platforms=android,ios --org com.bookmovie.revisit --project-name app .
flutter pub get
```

> 脚本参数是**完整包名**，内部拆成 `--org com.bookmovie.revisit --project-name app`，
> 拼回来正好是 `com.bookmovie.revisit.app`（**上架后不可更改**）。
> Flutter 会把包名最后一段当作项目名，但 `pubspec.yaml` 的 `name: shuying` 不会被改，
> `test/` 里的 `package:shuying` import 不受影响。
> 鸿蒙的 `ohos/` 目录在装好鸿蒙版 SDK 后再生成，见第五节。
>
> 🔴 **千万不要**在已有工程上带 `--overwrite` 重跑 `flutter create`：
> 它会覆盖 `lib/main.dart`、`README.md` 等已有文件（本项目踩过这个坑）。
> 需要重生成时，先生成到临时目录再把 `android/` `ios/` 拷回来。

### 运行

```bash
flutter run                      # 自动选设备
flutter run -d <device-id>       # flutter devices 查看
flutter run -d chrome            # 先在浏览器里看效果（不生成平台包）
```

改 App 显示名称（三端都要设成 `书影温故`）：

- Android：`android/app/src/main/AndroidManifest.xml` 的 `android:label`（**已设置**）
- iOS：`ios/Runner/Info.plist` 的 `CFBundleDisplayName`
- 鸿蒙：`ohos/entry/src/main/resources/base/element/string.json` 的 `app_name`

> App 内 UI 文案已统一为「书影温故」（2026-09-23，共 16 处，`flutter analyze` 零告警）；
> 待真机回归确认首页 / 弹窗标题不溢出，见
> [`docs/三端开发者注册与上架执行流程.md`](docs/三端开发者注册与上架执行流程.md) 第 0.2 节。

改应用图标：把 PNG 放进 `assets/`，用
`dart run flutter_launcher_icons`（需自行添加 `flutter_launcher_icons` 依赖）。

---

## 四、Android 打包

### 1. 生成签名密钥（只做一次，务必备份！）

```powershell
# Windows（交互式：自动找 keytool / Android Studio JBR，生成密钥并自动写出 key.properties）
powershell -ExecutionPolicy Bypass -File tool\gen-keystore.ps1
```

```bash
# macOS / Linux
./tool/gen-keystore.sh
```

**两个脚本都带强保护**：工程根目录存在 `tool/keystore-fingerprint.txt` 时，
脚本会校验本机 `.jks` 是否与登记一致——**避免在另一台机器上误生成新密钥**（那会让 App 无法覆盖安装、备案信息作废）。

| 命令 | 用途 |
|---|---|
| `tool\gen-keystore.ps1`（或 `./tool/gen-keystore.sh`） | 首次生成密钥（带防误生成拦截） |
| `... -Check` （或 `./tool/gen-keystore.sh --check`） | 校验现有 `.jks` 指纹；一致则自动补齐 `android/key.properties` |
| `... -Force` （或 `./tool/gen-keystore.sh --force`） | 明知有正式密钥仍要重新生成（危险） |

**跨机器切换（Windows ↔ macOS）推荐姿势**：
1. 把 `.jks` 用 U 盘 / 网盘拷到新机器的 `~/keys/` 或 `%USERPROFILE%\keys\`
2. 在新机器跑 `-Check`：脚本会算指纹、与登记表比对，一致则**自动写出当前机器路径的 `android/key.properties`**
3. 拷贝过程损坏？`-Check` 会打印 ❌ 不一致，从备份重取
4. 密码记不得？`-Check` 会先问密码；之后从 `android/key.properties` 读

或手动执行 keytool：

```bash
keytool -genkeypair -v \
  -keystore ~/keys/shuyingwengu-release.jks \
  -alias shuyingwengu \
  -keyalg RSA -keysize 2048 -validity 10000
```

> 🔴 **这个 `.jks` 文件丢了，你的 App 就永远无法更新**，只能换包名重新上架。
> 请同时备份到网盘和 U 盘。
> **不要**在新机器上重新生成密钥——会让 App 无法覆盖安装、备案信息作废。

### 2. 签名配置（`android/key.properties`）

脚本会自动生成；手动配置时参考 `android/key.properties.example`：

```properties
storePassword=你的store密码
keyPassword=你的key密码
keyAlias=shuyingwengu
storeFile=/Users/你的用户名/keys/shuyingwengu-release.jks
```

`key.properties` 已被 `.gitignore` 忽略，不要提交。

### 3. 构建配置（`android/app/build.gradle.kts`，已配置好）

工程已内置：检测到 `android/key.properties` 存在时自动用正式签名，
不存在时 release 构建回退 debug 签名（仅供本机调试，不可上架）。

### 4. 构建

```bash
flutter build apk --release --split-per-abi   # 国内安卓市场（体积小，推荐）
flutter build appbundle --release             # Google Play 用 .aab
```

产物：

- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

验证签名：

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

> 备案时要填的证书 MD5 指纹就来自上面这条命令的输出。

---

## 五、HarmonyOS 打包

鸿蒙**不是** Flutter 官方支持的平台，需要华为维护的 OpenHarmony 分支 SDK。

### 1. 安装鸿蒙版 Flutter

```bash
git clone -b dev https://gitee.com/openharmony-sig/flutter_flutter.git ~/flutter_ohos
export PATH="$HOME/flutter_ohos/bin:$PATH"     # 建议写进 ~/.zshrc
flutter doctor -v                              # 应出现 HarmonyOS toolchain 一项
```

按官方仓库 README 配置 `HOS_SDK_HOME` / DevEco 路径与 `ohpm`、`hvigor`。

### 2. 生成鸿蒙工程

```bash
cd flutter_app
flutter create --platforms ohos --org com.bookmovie.revisit --project-name app .
flutter pub get
flutter run -d <ohos-device-id>
```

### 3. 依赖适配

鸿蒙分支需要插件的 ohos 实现。若 `pub get` 报错或运行时报 `MissingPluginException`，
在 `pubspec.yaml` 末尾加：

```yaml
dependency_overrides:
  shared_preferences_ohos:
    git:
      url: https://gitee.com/openharmony-sig/flutter_packages.git
      path: packages/shared_preferences/shared_preferences_ohos
```

> 仓库地址与目录结构以 OpenHarmony SIG 最新文档为准。
> 本项目的存储被收敛在 `lib/store/app_store.dart` 的两个方法里，
> 万一 `shared_preferences` 不适配，改成 `dart:io` 写文件只需要改这一个文件。

### 4. 签名与出包

证书与 Profile 在 AGC「证书、APP ID 和 Profile」页面创建（`.p12` 密钥库 + `.cer` 证书 + `.p7b` Profile），
然后在 DevEco Studio 打开 `ohos/` 目录：
`File → Project Structure → Signing Configs` 填入证书，或勾选自动签名（需登录华为账号），
最后 `Build → Build Hap(s)/APP(s) → Build APP(s)`，产出 `.app` 用于上架。

```bash
flutter build hap --release          # 输出到 ohos/entry/build/default/outputs/
```

---

## 六、iOS 打包

```bash
cd flutter_app
flutter build ipa --release
```

或图形化：

```bash
open ios/Runner.xcworkspace
```

1. 选中 `Runner` Target → `Signing & Capabilities`
2. 勾选 `Automatically manage signing`，Team 选你的 Apple 开发者账号
3. Bundle Identifier 改成你的唯一 ID（与包名一致）
4. `Product → Archive` → `Distribute App` → `App Store Connect` → `Upload`
5. 到 [App Store Connect](https://appstoreconnect.apple.com) 填资料、提交审核

---

## 七、发布上架

> 本节是速览版。**开发者账号注册、三端标识符与签名落地、推进顺序**见
> [`docs/三端开发者注册与上架执行流程.md`](docs/三端开发者注册与上架执行流程.md)；
> **软著材料排版、备案表单字段、隐私政策全文**见
> [`docs/上架前置资质与备案指引.md`](docs/上架前置资质与备案指引.md)。

### 第 0 步：中国大陆的硬性前置资质（三端都要）

| 资质 | 说明 | 成本 |
|---|---|---|
| **软件著作权（软著）** | 国内应用市场基本强制。走中国版权保护中心（30~60 工作日，官费 0 元），或**易版权平台的「电子版权认证证书」**（10~15 工作日，华为侧认可，常有免费额度） | 自办 0 元；加急代办 300~1500 元 |
| **APP 备案（工信部）** | 2023 年 9 月起强制。通过你的云服务商（阿里云/腾讯云）代提交，需实名 + 已备案域名或云资源 | 免费，约 1~20 个工作日 |
| **隐私政策 URL** | 必须能公网访问。本 App 只在本机存储数据、不联网上传，写起来很简单 | 免费 |

备案号形如 `粤ICP备xxxxxxxx号-1A`，**App Store 中国区、华为应用市场、国内安卓市场都要填**。

隐私政策最小可用模板（托管到 GitHub Pages / 任意静态站即可）：

```markdown
# 书影温故 隐私政策

本应用不收集、不上传、不共享任何个人信息。
您创建的书籍、电影与记录数据仅保存在您设备的本地存储中，
卸载应用即会一并删除。本应用不含任何广告与第三方统计 SDK。

如对本政策有疑问，请联系：380174722@qq.com
```

### iOS App Store

1. 加入 [Apple Developer Program](https://developer.apple.com/programs/)：688 元/年（个人）
2. App Store Connect → 我的 App → 新建 App（记录 Bundle ID）
3. 上传包 → TestFlight 内测 → 提交审核（一般 1–3 天）
4. 中国区需在「App 信息」填写 ICP 备案号
5. 审核要点：必须有可访问的隐私政策；无账号体系则不需要「删除账号」入口

### Android 国内渠道

| 渠道 | 地址 | 费用 |
|---|---|---|
| 华为 AppGallery | developer.huawei.com | 免费 |
| 小米应用商店 | dev.mi.com | 免费 |
| OPPO 开放平台 | open.oppomobile.com | 免费 |
| vivo 开放平台 | dev.vivo.com.cn | 免费 |
| 荣耀开发者 | developer.honor.com | 免费 |
| 应用宝（腾讯） | open.qq.com | 免费 |

每家都要单独注册、实名、单独提交 APK + 软著 + 备案号 + 隐私政策。
华为应用市场对个人开发者的部分品类有限制，工具类一般没问题。

> Google Play 需 25 美元一次性费用，且新政策要求组织账号或完成测试门槛，
> 面向国内用户可以不做。

### HarmonyOS 应用市场

1. [华为开发者联盟](https://developer.huawei.com/consumer/cn/) 实名认证
2. [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html) → 我的应用 → 新建应用，**平台选 HarmonyOS**
3. 上传 `.app` 包 → 填资料（软著、备案号、隐私政策）→ 提交审核
4. ⚠️ 鸿蒙应用与 Android 应用在 AGC 里是**两个独立条目**，要分别过审

### 内测分发

- iOS：TestFlight
- Android：各市场「内部测试」轨道，或 Firebase App Distribution
- 鸿蒙：AGC 邀请内测 / DevEco 直连真机

---

## 八、发布前检查清单

- [ ] 包名 / Bundle ID 三端均为 `com.bookmovie.revisit.app`，不再更改
- [ ] 签名密钥已生成并**异地备份**（Android `.jks`、鸿蒙 `.p12`，丢了无法更新）
- [ ] App 名称 `书影温故`、图标、启动图已替换，代码内 UI 文案也已统一
- [ ] 版本号 `pubspec.yaml` 的 `version:`（`1.0.0+1`，`+` 后面是构建号，每次提交必须递增）
- [ ] 各尺寸截图已准备（iOS 需 6.7"/6.5"/5.5" 等，Android 各市场要求不同）
- [ ] 隐私政策 URL 可公网访问（App 内文本与公网版一致）
- [ ] 软著证书、备案号已拿到
- [ ] 真机回归：新增/编辑/删除书籍、记录阅读、读完、再读一次、补记往期、电影全流程
- [ ] 明暗主题都正常

---

## 九、常见坑

| 现象 | 原因 / 解决 |
|---|---|
| iOS 构建报 `Podfile` 错误 | `cd ios && pod install --repo-update` |
| Android 报 `minSdkVersion` 冲突 | 在 `android/app/build.gradle.kts` 提高 `minSdk` 到 23+ |
| 鸿蒙运行报 `MissingPluginException` | 插件缺 ohos 实现，见第五节第 3 点 |
| 应用市场驳回「缺少备案」 | 先把备案办下来，没有捷径 |
| 升级版本后 iOS 上传报「构建号重复」 | `pubspec.yaml` 的 `+N` 必须递增 |
| 在已有工程重跑 `flutter create --overwrite` 导致文件被覆盖 | 从 git 恢复，或生成到临时目录再拷贝平台目录 |
| `flutter create` 后 `main.dart` 变成计数器 Demo | 同上，`--overwrite` 会覆盖已有文件 |
| 数据丢失 | 数据在本机，卸载即清除。后续如需云同步，改 `app_store.dart` 即可接入 |

---

## 十、参考链接

- Flutter 官方：https://docs.flutter.dev/deployment
- OpenHarmony Flutter 分支：https://gitee.com/openharmony-sig/flutter_flutter
- 华为 AGC 上架指引：https://developer.huawei.com/consumer/cn/doc/app/agc-help-releaseapkrpk-0000001106463276
- APP 备案指引（华为）：https://developer.huawei.com/consumer/cn/doc/app/50130
- 苹果 App Store Connect 帮助：https://developer.apple.com/cn/help/app-store-connect/
