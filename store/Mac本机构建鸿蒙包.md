# Mac 本机构建鸿蒙包

> 本机：家里 Mac。鸿蒙**只能在这台机器**出包（DevEco Studio 无 Windows 版，HarmonyOS 工具链依赖 macOS）。
> Android 双机都能出，见《双机出包约定.md》；iOS 见《Mac本机构建iOS包与上架.md》。
> 更新日期：2026-10-27。

---

## 一、环境清单

| 组件 | 版本 / 路径 |
|---|---|
| DevEco Studio | `/Applications/DevEco-Studio.app` |
| HarmonyOS SDK | **26.0.0**（编译）/ 最低兼容 `6.0.0(20)` / 目标 API 26 |
| **鸿蒙专用 Flutter** | `~/flutter_ohos`，**Flutter 3.7.12**（ohos 分支，Dart 2.19） |
| 通用 Flutter（其他端用） | `~/development/flutter`，3.47.5 |
| hdc 工具 | `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc` |
| 发布构建 SDK 根目录 | `DEVECO_SDK_HOME` 与 `HOS_SDK_HOME` 均为 `/Applications/DevEco-Studio.app/Contents/sdk` |
| 发布构建配套工具 | DevEco 内置 `Contents/tools/node`、`tools/hvigor/bin`、`tools/ohpm/bin` 与 `Contents/jbr/Contents/Home` |
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
./tool/release.sh ohos
```

脚本使用 `~/flutter_ohos`，配置上表的官方 DevEco SDK、内置 Node/Hvigor/OHPM/JBR，清理构建缓存后执行 `flutter build app --release`。不要再使用旧 `~/openharmony/sdk` 的 API 15 环境。版本取自 `pubspec.yaml`，同时传入 `--build-name`、`--build-number` 和 `--dart-define=APP_VERSION`，让安装包版本与设置页一致。

构建前会自动运行 `tool/patch_ohos_text_input.py`，为当前 3.7.12 OHOS 引擎补齐输入法删除事件。补丁作用于 SDK 缓存的 6 个 HAR 变体，每个原文件保存在同目录的 `flutter.har.before-shuying-ime-fix`，重复执行不会重复打补丁；升级 SDK 后若源码结构不匹配会停止，需重新评估。仅修改工程生成的 `ohos/har/flutter.har` 无效，Flutter 会在下次构建时从 SDK 覆盖它。

单独检查与行为测试（不修改 SDK）：

```bash
python3 tool/patch_ohos_text_input.py --sdk "$HOME/flutter_ohos" --check
python3 tool/patch_ohos_text_input.py --sdk "$HOME/flutter_ohos" --self-test
```

行为测试使用 DevEco 内置 TypeScript 编译器执行实际 HAR 中的编辑类，验证数字、中英文、光标、选区、组合状态及表情删除。它不能代替 HarmonyOS 6.1 真机输入法复测。

商店上传产物：

```
ohos/build/outputs/default/ohos-default-signed.app
```

本机鸿蒙 Flutter 分支已支持命令行 `flutter build app`，无需操作 DevEco 界面。商店上传用的是签名 **`.app`**，**不要用 `.hap` 当商店包**，调试与发布不混用。

### 调试包

使用仓库入口，业务代码仍按 release/AOT 编译，仅签名使用既有 debug Profile：

```bash
# 仓库根目录
bash flutter_app/tool/release.sh ohos-test
bash flutter_app/tool/ohos_install.sh <生成的签名HAP绝对路径>
```

脚本临时选 debug 签名，结束后恢复原本地私有配置；只适用于 Profile 授权设备。当前旧 SDK 的 debug/JIT 产物已实测因 VM 快照与引擎不一致而启动闪退，不使用 `flutter build hap --debug` 生成此真机验收包。安装入口会核对实际版本、AOT 与快照兼容性，以 `install -r` 覆盖安装，之后由用户手动打开。


### 支持设备声明（2026-10-27 审核退回修正）

`entry/src/main/module.json5` 与 `entry/src/ohosTest/module.json5` 的 `deviceTypes` 均明确为 `["phone"]`。当前仅开放已做真机验证的手机；平板等设备补测后再添加。不要使用模板默认值 `"default"`：旧包可构建、可安装，但本次上架审核已判定它不属于支持的设备类型。

重新构建后核对发布产物，避免误传仍声明 `default` 的旧包：

```bash
python3 - <<'PY'
import io, json, zipfile
app = 'ohos/build/outputs/default/ohos-default-signed.app'
with zipfile.ZipFile(app) as bundle:
    haps = [name for name in bundle.namelist() if name.endswith('.hap')]
    assert haps, 'APP 包中没有 HAP'
    for name in haps:
        with zipfile.ZipFile(io.BytesIO(bundle.read(name))) as hap:
            devices = json.loads(hap.read('module.json'))['module']['deviceTypes']
            assert devices == ['phone'], (name, devices)
            print(name, devices)
PY
```

---

## 四、版本号（容易漏）

只有用户明确指定新的正式构建号才调整候选号；重复编译、改包重提或商店号冲突不授权升号。发布脚本先按 `tool/build_version.sh` 校验正式号 +1，再以 `pubspec.yaml` 为版本来源，鸿蒙包内版本写在：

```
flutter_app/ohos/AppScope/app.json5
  "versionCode": 6        ← 固定为用户指定正式号 5 +1
  "versionName": "1.0.0"  ← 展示版本
```

### ★ 坑 2：旧产物与版本号不同步

当前状态：

```
pubspec.yaml:              1.0.0+6
ohos/AppScope/app.json5:   versionCode 6 / versionName 1.0.0
```

当前本机鸿蒙 Flutter 分支的 `build app` / `build hap` 会在构建时同步 `AppScope/app.json5` 的版本；发布脚本还会显式传入版本参数。修改 `pubspec.yaml` 后必须重新构建，并核对实际上传文件，不能继续上传旧 `.app`。

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

1. 命令行执行 `./tool/release.sh ohos` 生成签名 **Release `.app`**，核对版本和设备声明
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
| 2 | 鸿蒙版本一直上不去 | 核对 `pubspec.yaml`、`app.json5` 与实际上传 `.app` 的构建号；修改版本后重新构建（见坑 2） |
| 3 | 构建报各种依赖/缓存错 | 清 `oh_modules`、`.hvigor`、`entry/build` 后重来 |
| 4 | 用了错误的 Flutter | 鸿蒙必须 `~/flutter_ohos`（3.7.12），不是 3.47.5 |
| 5 | 商店上传失败 | 传的是 `.hap`；商店要 `.app` |
| 6 | 安装失败 | 签名配置选错（发布 Profile 不能替代调试授权）；确认设备已授权 |
| 7 | hdc 找不到设备 | 换能传数据的线 / 重开无线调试看新端口 / `hdc kill && hdc start -r` |
| 8 | 审核提示设备类型超出支持范围 | `deviceTypes` 仍为 `default`；改为明确的 `phone`，重建并核对最终 `.app` 内 HAP 的 `module.json` |

---

## 八、命令速查

```bash
# 核对三端版本
grep "^version:" pubspec.yaml
grep -E "versionCode|versionName" ohos/AppScope/app.json5

# 配置官方 DevEco 环境 + 清理缓存 + 生成商店 APP
./tool/release.sh ohos

# 安装
./tool/ohos_install.sh

# 确认签名配置状态（不该出现在 git 改动里）
git status --short
git ls-files -v | grep -v "^H "
```
