# Windows 本机构建安卓包

> 记录 2026-10-23 在本机（Windows）从零搭建安卓构建环境的全过程与结论。
> 维护者：本机使用人。Mac 侧不受本文影响。

---

## 一、边界变化（重要）

`Windows接手与软著准备清单.md` 原先定的边界是：

> Windows 只做文档和脱敏材料，不动依赖 / 平台 / 签名；不导入或重建 Mac 密钥。

**该边界已于 2026-10-23 主动放宽**：为支持「家里 Mac + 办公 Windows 双机都能出安卓包」，
本机现已具备完整的安卓调试包 / 正式包构建能力，发布密钥已导入本机。

**仍保留的边界**：

| 事项 | 本机能否做 |
|---|---|
| 安卓调试包 | ✅ |
| 安卓正式包（可上架） | ✅ |
| 鸿蒙 `.app` 打包 | ❌ HarmonyOS 构建依赖 DevEco / macOS 工具链，Windows 不支持 |
| iOS 编译与上传 | ❌ 仍需在 Mac 上用 Xcode / Transporter |
| 密钥泄露风险 | ⚠️ 发布密钥现存在于两台机器，见第七节备份要求 |

**仓库仍不入库**：密钥、密码、`key.properties`、`local.properties`、`pubspec_overrides.yaml`。
（已逐条用 `git check-ignore -v` 验证，见第三节。）

---

## 二、环境清单

### 本机新装（全部在 C 盘）

| 组件 | 版本 / 内容 | 路径 |
|---|---|---|
| JDK | Temurin 17.0.20.1 | `C:\dev\jdk-17` |
| Android SDK | platform 35 / 36、build-tools 36.1.0 + 37.0.0、platform-tools | `C:\Android\sdk` |
| SDK 许可证 | 手写哈希（绕过 `sdkmanager` 无法交互的问题） | `C:\Android\sdk\licenses` |
| Gradle | 9.3.1 + 依赖缓存 | `C:\Users\leih\.gradle` |
| Pub 缓存 | — | `C:\Users\leih\AppData\Local\Pub\Cache` |
| 构建脚本 | 一键出调试包 | `C:\dev\出调试包.bat` |
| **安卓发布密钥** | alias `shuyingwengu` | `C:\Users\leih\keys\shuyingwengu-release.jks` |
| 签名配置 | 4 行（含密码） | `flutter_app\android\key.properties` |

### 复用（未移动）

| 组件 | 版本 | 路径 |
|---|---|---|
| Flutter SDK | 3.47.5 stable | `D:\Codes\flutterdev\flutter` |

### 用户级环境变量

```
JAVA_HOME                  = C:\dev\jdk-17
ANDROID_HOME               = C:\Android\sdk
ANDROID_SDK_ROOT           = C:\Android\sdk
PUB_HOSTED_URL             = https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL   = https://storage.flutter-io.cn
PATH                       += C:\dev\jdk-17\bin ; C:\Android\sdk\platform-tools ; D:\Codes\flutterdev\flutter\bin
```

> ⚠️ **两个镜像变量是必需的**：本机访问 `storage.googleapis.com` / `download.flutter.io`
> 会被 reset，构建会卡在下载 Flutter 引擎产物。
> 注：`dl.google.com` 是通的（Android SDK 组件走它），清华 / 腾讯云镜像也通。

---

## 三、敏感文件清单（切勿提交）

| 文件 | 忽略规则来源 | 说明 |
|---|---|---|
| `flutter_app\android\key.properties` | `flutter_app\android\.gitignore:12` | 含明文签名密码 |
| `flutter_app\pubspec_overrides.yaml` | `flutter_app\.gitignore:43` | 本机依赖覆盖，**提交会破坏 Mac 的鸿蒙构建** |
| `flutter_app\android\local.properties` | `flutter_app\android\.gitignore:6` | 本机 SDK 路径 |
| `*.jks` / `*.keystore` | `flutter_app\android\.gitignore` | 密钥本体 |

随时可用这条命令复查：

```powershell
git check-ignore -v flutter_app\android\key.properties flutter_app\pubspec_overrides.yaml flutter_app\android\local.properties
```

---

## 四、常用命令

在 `d:\Codes\APPdev\flutter_app` 下执行（新开终端即可，环境变量已设好）：

```powershell
# 调试包（全架构通用，148 MB，任何设备都能装）
flutter build apk --debug --flavor direct

# 调试包（仅 arm64，约 60 MB，真机通用）
flutter build apk --debug --flavor direct --target-platform android-arm64

# 正式包（可上架、可覆盖安装，51.2 MB）
flutter build apk --release --flavor direct

# 装到手机（先开 USB 调试并接线）
adb install -r build\app\outputs\flutter-apk\app-direct-debug.apk
adb devices -l

# 真机热重载调试
flutter run --flavor direct
```

产物目录：`flutter_app\build\app\outputs\flutter-apk\`

**版本号纪律**（与《双机出包约定.md》一致）：

- 日常构建**不动 `+N`**：两端随时可打同一个版本号的包，签名一致，手机上可互相覆盖安装
- 所有出包固定用户指定正式号 +1（当前正式号 5、候选号 6）；只有用户明确指定新正式号才调整，商店号冲突报告用户，不自动升号
- 按用户授权同步 `pubspec.yaml` 与 `tool/build_version.sh`，让另一台机器看到一致基线
- 产物按约定归档到仓库根目录 `dist\1.0.0+N\`（`dist` 已被忽略，不入库）

---

## 五、一键脚本

```
C:\dev\出调试包.bat
```

| 用法 | 结果 |
|---|---|
| 双击 | 全架构通用调试包 |
| 拖 `arm64` 参数到它上面 | 仅 arm64 调试包 |

脚本自动完成：设置环境变量 → `pub get` → 编译 → 打印 APK 路径 → 询问是否 `adb install`。

---

## 六、踩过的坑与解法

| # | 现象 | 原因 | 解法 |
|---|---|---|---|
| 1 | Adoptium JDK 下载只有几百 KB/s | 走 GitHub Release | 改清华镜像 `mirrors.tuna.tsinghua.edu.cn/Adoptium`（182 MB / 23 秒） |
| 2 | `sdkmanager --licenses` 管道输入无效 | 它直连控制台，不读 stdin | 直连 `dl.google.com` 下载组件 zip 手动解压；再手写 `licenses\*` 哈希文件 |
| 3 | `pub get` 失败 | `pubspec.yaml` 里 5 处 Mac 路径 `/Users/leihao/...` | 用 `pubspec_overrides.yaml` 改指 pub.dev，**不动** `pubspec.yaml` |
| 4 | `Type 'UnmodifiableUint8ListView' not found` | Dart 3.13 后该类被移除，`win32` 4.x/5.x 未适配 | 覆盖 `win32: ^6.4.0` |
| 5 | `path_provider_windows` 报参数个数不匹配 | 2.2.1 依赖 `win32 <6`，与上条冲突 | 覆盖 `path_provider_windows: 2.3.0`（该版已不依赖 win32） |
| 6 | `SharedPreferencesPlugin.java:52: 找不到符号` | 插件用了 Flutter 已移除的 v1 embedding API | `shared_preferences` 整组升到 2.5.x（要求 Flutter 3.44 及以上；本机 3.47.5） |
| 7 | `Could not close incremental caches` / `Daemon compilation failed` | Kotlin daemon 在 Windows 写增量缓存失败 | 写入 `%USERPROFILE%\.gradle\gradle.properties`：<br>`kotlin.compiler.execution.strategy=in-process`<br>`kotlin.incremental=false` |
| 8 | Gradle 报 `Connection reset` 下载 `io.flutter:...` | 访问 `storage.googleapis.com` 被重置 | 设置 `FLUTTER_STORAGE_BASE_URL` 镜像 + `flutter precache --android` |

> 坑 3–6 的解法都写在 `pubspec_overrides.yaml`（gitignore 文件）里，Mac 完全不受影响。
> 坑 7 写在 Gradle 用户目录，不在仓库内。

---

## 七、双机一致性保证

**核心结论**：签名指纹一致 ⇒ 两机出的包在商店和用户设备上完全等价（可覆盖安装、可增量更新）。

导入密钥后必须校验（`flutter_app` 目录下）：

```powershell
powershell -ExecutionPolicy Bypass -File tool\gen-keystore.ps1 -Check
```

2026-10-23 实测结果，与 `tool/keystore-fingerprint.txt` 登记值逐位一致：

| 指纹 | 值 |
|---|---|
| MD5 | `95:D2:D6:AF:26:3D:54:02:75:E8:09:05:F7:5F:0C:FD` |
| SHA-1 | `0E:15:8E:04:3E:6A:BD:F1:2D:F2:B4:79:23:40:81:C6:B6:BD:36:12` |
| SHA-256 | `07:E8:7C:B1:12:1D:15:32:19:EC:57:DA:39:E0:C9:29:18:21:3F:4F:5C:14:94:49:87:73:96:41:C7:07:6E:44` |

正式包出包后再次实测 APK 内证书（`keytool -printcert -jarfile`），与上表一致 ✅。

**对应到外部系统**：

| 用途 | 用哪个值 |
|---|---|
| 阿里云备案 · 安卓证书 MD5 | `95D2D6AF263D540275E80905F75F0CFD` |
| 华为后台「开发服务」SHA-256 | `07E87CB1121D153219EC57DA39E0C92918213F4F5C14944987739641C7076E44` |
| 鸿蒙（`.hm`） | **另一套**证书，与安卓无关，不要混填 |

---

## 八、维护提醒

1. **Mac 改了 `pubspec.yaml` 后**，本机需重新 `flutter pub get`；若新增了 Mac 路径依赖，
   要同步补进 `pubspec_overrides.yaml`。
2. **不要提交 `pubspec_overrides.yaml`**，否则 Mac 的鸿蒙 fork 会被覆盖掉。
3. **密钥备份**：`C:\Users\leih\keys\shuyingwengu-release.jks` 现存在于两台机器，
   请再放到 U 盘 + 加密网盘各一份，并把 `tool\keystore-fingerprint.txt` 末尾两行补上：
   ```
   backup_1=____（网盘）
   backup_2=____（U 盘）
   ```
4. **密码归档**：`key.properties` 里有明文密码，只在本机。另存一份到密码管理器
   （条目建议名：书影温故 Android keystore）。
5. **密钥一旦丢失或泄露无法挽回**：正式发布后更换密钥会导致 Play 无法增量更新、
   老用户无法覆盖安装；华为侧也需重新提交审核。
6. **Windows 不能替代 Mac 做鸿蒙和 iOS**，这两条线仍走 Mac。
