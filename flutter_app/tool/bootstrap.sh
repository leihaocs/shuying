#!/usr/bin/env bash
# 一键生成 Flutter 三端平台工程。
#
# 用法：
#   ./tool/bootstrap.sh com.bookmovie.revisit.app
#
# 参数：完整包名 / Bundle ID（必填，上架后不可更改）
#
# 说明：lib/ 是跨端共享代码，android/ ios/ ohos/ 由 Flutter 按当前 SDK
#      版本生成模板，比手写可靠。本脚本不会覆盖已有的 lib/ 与 pubspec.yaml。
#
# 注意：--project-name 取包名最后一段（app），而 pubspec.yaml 的 name 保持
#      shuying（test/ 里的 package:shuying import 依赖它）。
#      Dart 包名与上架包名互不相干，不要为了「看起来统一」去改 pubspec 的 name。

set -euo pipefail

BUNDLE_ID="${1:-}"
if [ -z "$BUNDLE_ID" ]; then
  echo "用法：./tool/bootstrap.sh com.bookmovie.revisit.app" >&2
  echo "      参数是完整包名 / Bundle ID（上架后不可更改）。" >&2
  exit 1
fi

# 把完整包名拆成两段交给 Flutter：
#   com.bookmovie.revisit.app  →  --org com.bookmovie.revisit  --project-name app
# Flutter 用 <org>.<project-name> 作为 applicationId / Bundle ID / bundleName，
# 拼回来正好等于完整包名。
ORG="${BUNDLE_ID%.*}"
PROJECT_NAME="${BUNDLE_ID##*.}"
if [ -z "$ORG" ] || [ -z "$PROJECT_NAME" ] || [ "$ORG" = "$BUNDLE_ID" ]; then
  echo "包名格式不合法（至少需要两段），示例：com.bookmovie.revisit.app" >&2
  exit 1
fi

echo "==> 目标包名：${BUNDLE_ID}（org=${ORG}, project=${PROJECT_NAME}）"
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "未找到 flutter，请先安装 Flutter SDK 并加入 PATH。" >&2
  exit 1
fi

echo "==> Flutter 版本"
flutter --version

# pubspec.yaml 里已经写好了依赖，这里先备份，避免被模板覆盖。
# 注意：flutter create --overwrite 会覆盖 lib/、test/、README.md 等，
# 一并备份，生成平台工程后再恢复。
cp pubspec.yaml pubspec.yaml.bak
cp -R lib lib.bak
cp -R test test.bak 2>/dev/null || true
cp analysis_options.yaml analysis_options.yaml.bak
cp README.md README.md.bak
cp .gitignore .gitignore.bak

# 中途失败也把 pubspec 还原回来
restore_pubspec() {
  if [ -f pubspec.yaml.bak ]; then
    mv -f pubspec.yaml.bak pubspec.yaml
  fi
}
trap restore_pubspec EXIT

PLATFORMS="android,ios"

# 如果当前 Flutter 支持 ohos（鸿蒙分支），一并生成
if flutter create --help 2>&1 | grep -q "ohos"; then
  echo "==> 检测到鸿蒙支持，将同时生成 ohos 工程"
  PLATFORMS="android,ios,ohos"
else
  echo "==> 当前 Flutter 未启用 ohos 平台，仅生成 android / ios"
  echo "    鸿蒙请参考 README 第五节，切换到 OpenHarmony 分支 SDK 后重跑本脚本"
fi

echo "==> 生成平台工程"
flutter create --platforms="$PLATFORMS" \
  --org "$ORG" \
  --project-name "$PROJECT_NAME" \
  --overwrite \
  .

# 恢复我们自己的代码与配置（模板会覆盖 lib/、test/、README.md 等）
mv pubspec.yaml.bak pubspec.yaml
rm -rf lib && mv lib.bak lib
rm -rf test && mv test.bak test
mv analysis_options.yaml.bak analysis_options.yaml
mv README.md.bak README.md
mv .gitignore.bak .gitignore

echo "==> 拉取依赖"
flutter pub get

echo "==> 校验三端标识符（三项都应等于 ${BUNDLE_ID}）"
grep -n "applicationId" android/app/build.gradle.kts 2>/dev/null \
  || echo "  [Android] 未找到 applicationId，请手工确认"
grep -n "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj 2>/dev/null | head -3 \
  || echo "  [iOS] 未找到 Bundle ID，请手工确认"
if [ -f ohos/AppScope/app.json5 ]; then
  grep -n "bundleName" ohos/AppScope/app.json5 2>/dev/null \
    || echo "  [HarmonyOS] 未找到 bundleName，请手工确认"
fi

echo "==> 静态检查"
flutter analyze || true

cat <<EOF

完成。

下一步：
  1. flutter run                 # 连真机或模拟器跑起来
  2. 按 README 第四节配置 Android 签名后 flutter build apk --release
  3. 按 README 第六节用 Xcode 配置 iOS 签名后 flutter build ipa --release

显示名（三端都要设成「书影温故」）：
  Android：android/app/src/main/AndroidManifest.xml 的 android:label
  iOS    ：ios/Runner/Info.plist 的 CFBundleDisplayName
  鸿蒙   ：ohos/entry/src/main/resources/base/element/string.json 的 app_name

提醒：签名密钥（Android .jks / 鸿蒙 .p12）务必备份，丢了就无法更新已上架的
      应用；包名 ${BUNDLE_ID} 一旦上架同样不可更改。
EOF
