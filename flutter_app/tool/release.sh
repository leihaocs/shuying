#!/usr/bin/env bash
#
# 书影（ShuYing）三端 release 一键构建
#
#   ./tool/release.sh            构建全部三端
#   ./tool/release.sh android    仅 Android（APK + AAB）
#   ./tool/release.sh ios        仅 iOS（需要已配置签名）
#   ./tool/release.sh ohos       仅 HarmonyOS（商店 APP）
#   ./tool/release.sh ohos-test  HarmonyOS release 业务代码 + 真机调试签名 HAP
#
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

MAIN_FLUTTER="$HOME/development/flutter"
OHOS_FLUTTER="$HOME/flutter_ohos"

export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

TARGET="${1:-all}"

# 读取统一版本并校验：候选号始终为用户指定的正式号 +1。
source "$APP_DIR/tool/build_version.sh"
echo "==> 版本号：pubspec.yaml = $APP_VER_RAW → 注入 $APP_VER_NAME ($APP_VER_BUILD)"

build_android() {
  echo "==> Android release（APK + AAB）"
  export PATH="$MAIN_FLUTTER/bin:$PATH"
  flutter pub get
  flutter build apk --release --flavor direct "$DART_DEFINE"
  flutter build appbundle --release --flavor play "$DART_DEFINE"
  echo "    APK: build/app/outputs/flutter-apk/app-direct-release.apk"
  echo "    AAB: build/app/outputs/bundle/playRelease/app-play-release.aab"
}

build_ios() {
  echo "==> iOS release"
  # 签名证书探测 / ExportOptions 生成 / teamID 推断都在 ios_ipa.sh 里完成；
  # 前置条件：Xcode → Settings → Accounts 登录 leihaocs@foxmail.com。
  "$APP_DIR/tool/ios_ipa.sh" testflight
}

build_ohos() {
  local artifact="${1:-app}"
  echo "==> HarmonyOS release（${artifact}）"
  local deveco_contents="/Applications/DevEco-Studio.app/Contents"
  export DEVECO_SDK_HOME="$deveco_contents/sdk"
  export HOS_SDK_HOME="$DEVECO_SDK_HOME"
  export NODE_HOME="$deveco_contents/tools/node"
  export JAVA_HOME="$deveco_contents/jbr/Contents/Home"
  export PATH="$OHOS_FLUTTER/bin:$NODE_HOME/bin:$deveco_contents/tools/hvigor/bin:$deveco_contents/tools/ohpm/bin:$JAVA_HOME/bin:$PATH"

  if [ ! -x "$OHOS_FLUTTER/bin/flutter" ] || [ ! -d "$DEVECO_SDK_HOME/default" ]; then
    echo "    构建失败：未找到鸿蒙 Flutter 或 DevEco HarmonyOS SDK"
    return 1
  fi

  # Flutter 每次构建会从 SDK 缓存复制 HAR，先应用可重复的输入法补丁。
  python3 "$APP_DIR/tool/patch_ohos_text_input.py" --sdk "$OHOS_FLUTTER"
  python3 "$APP_DIR/tool/patch_ohos_text_input.py" --sdk "$OHOS_FLUTTER" --check

  # ohpm clean 对超过 500 个文件的目录会报 safe-delete 错误，先手动清干净。
  rm -rf ohos/oh_modules ohos/oh-package-lock.json5 ohos/.hvigor ohos/entry/build
  # hvigor 的 compiler.cache 遇到残留目录会 EISDIR。
  rm -rf "$APP_DIR/.hvigor"

  flutter pub get
  flutter build "$artifact" --release --no-pub --build-name="$APP_VER_NAME" --build-number="$APP_VER_BUILD" "$DART_DEFINE"
  if [ "$artifact" = app ]; then
    echo "    APP: ohos/build/outputs/default/ohos-default-signed.app"
  else
    echo "    HAP: ohos/entry/build/default/outputs/default/entry-default-signed.hap"
  fi
}

# 调试签名与业务构建模式分开：旧 SDK 的 debug 引擎与 JIT 快照不兼容。
# 临时选择已授权设备的签名，成功或失败均逐字恢复本地私有配置。
build_ohos_test() (
  signing_backup="$(mktemp)"
  cp "$APP_DIR/ohos/build-profile.json5" "$signing_backup"
  trap 'build_status=$?; cp "$signing_backup" "$APP_DIR/ohos/build-profile.json5"; rm -f "$signing_backup"; exit "$build_status"' EXIT
  python3 - "$APP_DIR/ohos/build-profile.json5" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
data = json.loads(p.read_text())
assert any(c['name'] == 'debug' for c in data['app']['signingConfigs']), '缺少既有调试签名'
for product in data['app']['products']:
    product['signingConfig'] = 'debug'
p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
PY
  build_ohos hap
)

case "$TARGET" in
  android) build_android ;;
  ios)     build_ios ;;
  ohos)    build_ohos ;;
  ohos-test) build_ohos_test ;;
  all)     build_android; build_ios; build_ohos ;;
  *) echo "用法: $0 [android|ios|ohos|ohos-test|all]"; exit 1 ;;
esac

echo "==> 完成"
