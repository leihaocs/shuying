#!/usr/bin/env bash
#
# 书影温故（Reel&Read）· 把 HAP 装到已连接的鸿蒙真机
#
#   ./tool/ohos_install.sh                      安装默认产物
#   ./tool/ohos_install.sh <xxx.hap>            安装指定 HAP
#
# 真机准备（只需一次）：
#   1. 设置 → 关于本机 → 连点「版本号」7 次，打开开发者模式
#   2. 设置 → 系统和更新 → 开发人员选项 → 打开「USB 调试」
#   3. USB 连上 Mac（要能传数据的线），手机上点「允许 USB 调试」
#
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

HDC="${HDC:-$HOME/openharmony/sdk/15/openharmony/15/toolchains/hdc}"
if [ ! -x "$HDC" ]; then
  echo "==> 找不到 hdc：$HDC"
  exit 1
fi

HAP="${1:-$APP_DIR/ohos/entry/build/default/outputs/default/entry-default-signed.hap}"
[ -f "$HAP" ] || { echo "==> HAP 不存在：$HAP"; exit 1; }

echo "==> 查找设备…"
TARGETS="$("$HDC" list targets 2>/dev/null | grep -v '^\[Empty\]' | head -1)"
if [ -z "$TARGETS" ]; then
  cat <<'EOF'
没有检测到鸿蒙设备。请检查：
  1. 手机已用数据线连到 Mac（部分线只能充电）
  2. 手机已开启开发者模式 + USB 调试，并点了「允许 USB 调试」
  3. hdc 服务正常（可执行：hdc kill && hdc start -r）
EOF
  exit 1
fi
echo "==> 设备：$TARGETS"

UDID="$("$HDC" -t "$TARGETS" shell bm get --udid 2>/dev/null | tr -d '\r' | tail -1 || true)"
[ -n "$UDID" ] && echo "==> 设备 UDID：$UDID"

echo "==> 安装 $(basename "$HAP")"
"$HDC" -t "$TARGETS" install "$HAP"

echo "==> 启动应用"
"$HDC" -t "$TARGETS" shell aa start -a EntryAbility -b com.bookmovie.revisit.app 2>/dev/null || true

echo "==> 完成。查看日志："
echo "    $HDC -t $TARGETS shell hilog | grep -i flutter"
