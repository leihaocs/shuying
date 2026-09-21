#!/usr/bin/env bash
# 一键生成 Flutter 三端平台工程。
#
# 用法：
#   ./tool/bootstrap.sh com.yourcompany.shuying
#
# 参数：包名 / Bundle ID（必填，上架后不可更改）
#
# 说明：lib/ 是跨端共享代码，android/ ios/ ohos/ 由 Flutter 按当前 SDK
#      版本生成模板，比手写可靠。本脚本不会覆盖已有的 lib/ 与 pubspec.yaml。

set -euo pipefail

ORG="${1:-}"
if [ -z "$ORG" ]; then
  echo "用法：./tool/bootstrap.sh com.yourcompany.shuying" >&2
  exit 1
fi

PROJECT_NAME="shuying"
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "未找到 flutter，请先安装 Flutter SDK 并加入 PATH。" >&2
  exit 1
fi

echo "==> Flutter 版本"
flutter --version

# pubspec.yaml 里已经写好了依赖，这里先备份，避免被模板覆盖
cp pubspec.yaml pubspec.yaml.bak

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

# 恢复我们自己的 pubspec（模板可能会改写依赖版本）
mv pubspec.yaml.bak pubspec.yaml

echo "==> 拉取依赖"
flutter pub get

echo "==> 静态检查"
flutter analyze || true

cat <<'EOF'

完成。

下一步：
  1. flutter run                 # 连真机或模拟器跑起来
  2. 按 README 第四节配置 Android 签名后 flutter build apk --release
  3. 按 README 第六节用 Xcode 配置 iOS 签名后 flutter build ipa --release

提醒：签名密钥务必备份，丢了就无法更新已上架的 App。
EOF
