# Mac 本机构建鸿蒙包

> 本机：家里 Mac。鸿蒙**只能在这台机器**出包（DevEco Studio 无 Windows 版，HarmonyOS 工具链依赖 macOS）。
> Android 双机都能出，见《双机出包约定.md》；iOS 见《Mac本机构建iOS包与上架.md》。
> 整理日期：2026-10-23。

---

## 一、环境清单

| 组件 | 版本 / 路径 |
|---|---|
| DevEco Studio | `/Applications/DevEco-Studio.app` |
| HarmonyOS SDK | **26.0.0**（编译）/ 最低兼容 `6.0.0(20)` / 目标 API 26 |
| **鸿蒙专用 Flutter** | `~/flutter_ohos`，**Flutter 3.7.12**（ohos 分支，Dart 2.19） |
| 通用 Flutter（其他端用） | `~/development/flutter`，3.47.5 |
| hdc 工具 | `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc` |
| 包名 | `com.bookmovie.revisit.app.hm` |
| 华为后台 APP ID | `6917619319382055664` |

> ⚠️ **鸿蒙必须用 `~/flutter_ohos` 这个 SDK**，不是日常那个 3.47.5。它是 OpenHarmony SIG 的分支（Dart 2.19），`pubspec.yaml` 里的 `environment` 下限放宽到 2.19 就是为了兼容它。

---

## 二、签名与密钥（重点）

### 文件位置

| 用途 | 路径 |
|---|---|
| 发布证书 `.cer` | `~/Codes/appbackup/harmony/书影温故发布证书.cer` |
| 发布 Profile `.p7b` | `~/Codes/appbackup/harmony/shuying-hm-releaseRelease.p7b` |
| 密钥库 `.p12` | `~/development/keys/shuying-harmonyos/shuying-release.p12` |
| keyAlias | `shuying-release` |
| 签名算法 | `SHA256withECDSA` |

**密码不在本文档、不在命令、不在仓库。** 只存在于 `flutter_app/ohos/build-profile.json5` 的本地副本里。

### ★ 坑 1：`build-profile.json5` 的本地/远端双版本

这个文件里含**明文签名密码**，所以它有两个版本同时存在：

| | 内容 | 谁能看到 |
|---|---|---|
| 本地工作区 | 含完整签名配置（能打包） | 只有本机 |
| GitHub 远端 | `signingConfigs: []`（干净） | 所有人 |

靠 git 的 `skip-worktree` 标记实现：

```bash
# 查看免检标记（S 开头就是）
git ls-files -v | grep -v "^H "
#   S flutter_app/ohos/build-profile.json5

# 设置 / 取消
git update-index --skip-worktree flutter_app/ohos/build-profile.json5
git update-index --no-skip-worktree flutter_app/ohos/build-profile.json5
```

**规则**：

- ✅ 正常构建不受影响（文件在磁盘上是完整版）
- ❌ 不要对它执行 `git checkout --`（会把密码覆盖成空版本）
- ❌ 不要 `git add -f` 它（强制提交会泄露密码）
- 备份在：`~/Codes/appbackup/harmony/build-profile.signed.json5.bak`
- 换机器：把备份拷回 `flutter_app/ohos/build-profile.json5` 即可

---

## 三、构建流程

### 发布包（上架用）

```bash
cd ~/Projects/shuying/flutter_app
export PATH="$HOME/flutter_ohos/bin:$PATH"     # ★ 必须切到鸿蒙 SDK
flutter --version                               # 确认显示 3.7.12

# 清理（oh_modules 缓存脏了会导致各种诡异报错）
rm -rf ohos/oh_modules ohos/oh-package-lock.json5 ohos/.hvigor ohos/entry/build

flutter build hap --release
```

产物：

```
ohos/entry/build/default/outputs/default/entry-default-signed.hap
```

商店上传用的是 **`.app`**（在 DevEco 里 Build → Build Hap(s)/APP(s) → 生成 Release APP），**不要用 `.hap` 当商店包**，调试与发布不混用。

### 调试包

`build-profile.json5` 里已配好 `debug` 自动签名配置，构建时选 debug 签名，装到已授权的真机。

---

## 四、版本号（容易漏）

鸿蒙的版本**不在** `pubspec.yaml`，而是写在：

```
flutter_app/ohos/AppScope/app.json5
  "versionCode": 2        ← 构建号，商店唯一、只增不减
  "versionName": "1.0.0"  ← 展示版本
```

### ★ 坑 2：与 pubspec 不同步

当前状态：

```
pubspec.yaml:              1.0.0+5
ohos/AppScope/app.json5:   versionCode 2 / versionName 1.0.0
```

**鸿蒙版本号不会自动跟着 `pubspec.yaml` 变**，构建前必须手改 `app.json5`，否则鸿蒙包会一直停在被商店拒的旧构建号上。

发布前核对三处一致：

```bash
grep "^version:" pubspec.yaml
grep -E "versionCode|versionName" ohos/AppScope/app.json5
grep -E "versionCode|versionName" ohos/entry/src/main/module.json5   # 若也有，一并改
```

---

## 五、真机安装与调试

### USB

```bash
./tool/ohos_install.sh                      # 装默认产物
./tool/ohos_install.sh <指定.hap>
```

脚本内含设备检测与启动命令，找不到设备时会给出排查提示。

### 无线调试

```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
"$HDC" tconn <手机IP:端口>
"$HDC" list targets
"$HDC" -t <手机IP:端口> install -r <hap路径>
"$HDC" -t <手机IP:端口> shell aa start -a EntryAbility -b com.bookmovie.revisit.app.hm
```

手机端准备（一次）：设置 → 关于本机 → 连点版本号 7 次开开发者模式 → 开发人员选项 → 打开 USB 调试 / 无线调试，保持亮屏解锁，端口以手机显示为准。

### 日志

```bash
"$HDC" -t <目标> shell hilog | grep -i flutter
```

---

## 六、发布到华为

1. DevEco → Build → 生成 **Release `.app`**
2. 华为 AppGallery Connect → 我的应用（`APP ID 6917619319382055664`）→ 版本信息 → 上传 `.app`
3. 填写版本说明、隐私政策、备案信息
4. **包名是 `com.bookmovie.revisit.app.hm`**，与 iOS/Android 的 `com.bookmovie.revisit.app` 不同，备案各自独立
5. 提交审核

> 鸿蒙的备案变更（`.hm` 包名）与 iOS/Android 的备案是两套，需按华为要求单独办理，办完才能提审上线。

---

## 七、踩坑速查

| # | 现象 | 原因 / 解法 |
|---|---|---|
| 1 | 密码进了 git | `build-profile.json5` 被提交；用 `skip-worktree` 隔离（见坑 1） |
| 2 | 鸿蒙版本一直上不去 | `app.json5` 的 `versionCode` 没手改（见坑 2） |
| 3 | 构建报各种依赖/缓存错 | 清 `oh_modules`、`.hvigor`、`entry/build` 后重来 |
| 4 | 用了错误的 Flutter | 鸿蒙必须 `~/flutter_ohos`（3.7.12），不是 3.47.5 |
| 5 | 商店上传失败 | 传的是 `.hap`；商店要 `.app` |
| 6 | 安装失败 | 签名配置选错（发布 Profile 不能替代调试授权）；确认设备已授权 |
| 7 | hdc 找不到设备 | 换能传数据的线 / 重开无线调试看新端口 / `hdc kill && hdc start -r` |

---

## 八、命令速查

```bash
# 切环境
export PATH="$HOME/flutter_ohos/bin:$PATH"

# 核对三端版本
grep "^version:" pubspec.yaml
grep -E "versionCode|versionName" ohos/AppScope/app.json5

# 清理 + 构建
rm -rf ohos/oh_modules ohos/oh-package-lock.json5 ohos/.hvigor ohos/entry/build
flutter build hap --release

# 安装
./tool/ohos_install.sh

# 确认签名配置状态（不该出现在 git 改动里）
git status --short
git ls-files -v | grep -v "^H "
```
