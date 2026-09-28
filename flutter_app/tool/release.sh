#!/usr/bin/env bash
#
# 书影（ShuYing）三端 release 一键构建
#
#   ./tool/release.sh            构建全部三端
#   ./tool/release.sh android    仅 Android（APK + AAB）
#   ./tool/release.sh ios        仅 iOS（需要已配置签名）
#   ./tool/release.sh ohos       仅 HarmonyOS（HAP）
#
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

MAIN_FLUTTER="$HOME/development/flutter"
OHOS_FLUTTER="$HOME/flutter_ohos"
OHOS_SDK="$HOME/openharmony/sdk"
OHOS_CLI="$HOME/openharmony/oh-command-line-tools"

export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

TARGET="${1:-all}"

# 版本号注入：唯一来源是 pubspec.yaml 的 version（如 1.0.0+1）
APP_VER_RAW="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -1 | tr -d '\r')"
APP_VER_NAME="${APP_VER_RAW%%+*}"
APP_VER_BUILD="${APP_VER_RAW#*+}"
if [ "$APP_VER_BUILD" = "$APP_VER_RAW" ]; then APP_VER_BUILD="1"; fi
DART_DEFINE="--dart-define=APP_VERSION=$APP_VER_NAME ($APP_VER_BUILD)"
echo "==> 版本号：pubspec.yaml = $APP_VER_RAW → 注入 $APP_VER_NAME ($APP_VER_BUILD)"

build_android() {
  echo "==> Android release（APK + AAB）"
  export PATH="$MAIN_FLUTTER/bin:$PATH"
  flutter pub get
  flutter build apk --release "$DART_DEFINE"
  flutter build appbundle --release "$DART_DEFINE"
  echo "    APK: build/app/outputs/flutter-apk/app-release.apk"
  echo "    AAB: build/app/outputs/bundle/release/app-release.aab"
}

build_ios() {
  echo "==> iOS release"
  # 签名证书探测 / ExportOptions 生成 / teamID 推断都在 ios_ipa.sh 里完成；
  # 前置条件：Xcode → Settings → Accounts 登录 leihaocs@gmail.com。
  exec "$APP_DIR/tool/ios_ipa.sh" auto
}

build_ohos() {
  echo "==> HarmonyOS release（HAP）"
  export PATH="$OHOS_FLUTTER/bin:$OHOS_CLI/bin:$PATH"
  export OHOS_SDK_HOME="$OHOS_SDK"
  export HOS_SDK_HOME="$OHOS_SDK"
  export DEVECO_SDK_HOME="$OHOS_SDK"
  export OHOS_BASE_SDK_HOME="$OHOS_SDK/15/openharmony"

  if [ ! -d "$OHOS_FLUTTER" ] || [ ! -d "$OHOS_SDK" ]; then
    echo "    跳过：未找到鸿蒙 Flutter 或 OHOS SDK"
    return 0
  fi

  # ohpm clean 对超过 500 个文件的目录会报 safe-delete 错误，先手动清干净。
  rm -rf ohos/oh_modules ohos/oh-package-lock.json5 ohos/.hvigor ohos/entry/build
  # hvigor 的 compiler.cache 遇到残留目录会 EISDIR。
  rm -rf "$APP_DIR/.hvigor"

  flutter pub get
  flutter build hap --release "$DART_DEFINE"
  echo "    HAP: ohos/entry/build/default/outputs/default/entry-default-signed.hap"
}

case "$TARGET" in
  android) build_android ;;
  ios)     build_ios ;;
  ohos)    build_ohos ;;
  all)     build_android; build_ios; build_ohos ;;
  *) echo "用法: $0 [android|ios|ohos|all]"; exit 1 ;;
esac

echo "==> 完成"
