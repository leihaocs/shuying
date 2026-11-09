#!/usr/bin/env bash
#
# 书影温故（Reel&Read）· 把 HAP 装到已连接的鸿蒙真机
#
#   ./tool/ohos_install.sh                      安装默认产物
#   ./tool/ohos_install.sh <xxx.hap>            安装指定 HAP
#   HDC_TARGET=192.168.3.83:36489 ./tool/ohos_install.sh <xxx.hap>
#                                             指定已连接的目标
#
# 真机准备（只需一次）：
#   1. 设置 → 关于本机 → 连点「版本号」7 次，打开开发者模式
#   2. 设置 → 系统和更新 → 开发人员选项 → 打开「USB 调试」
#   3. USB 连上 Mac（要能传数据的线），手机上点「允许 USB 调试」
#
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"
source "$APP_DIR/tool/build_version.sh"

HDC="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
if [ ! -x "$HDC" ]; then
  echo "==> 找不到 hdc：$HDC"
  exit 1
fi

HAP="${1:-$APP_DIR/ohos/entry/build/default/outputs/default/entry-default-signed.hap}"
[ -f "$HAP" ] || { echo "==> HAP 不存在：$HAP"; exit 1; }

# 真机测试也使用 release/AOT 业务代码；旧 SDK debug/JIT 快照与引擎不兼容。
python3 "$APP_DIR/tool/check_ohos_hap.py" "$HAP" "$APP_VER_NAME" "$APP_VER_BUILD"

echo "==> 查找设备…"
if ! TARGET_LIST="$("$HDC" list targets 2>&1)"; then
  printf '%s\n' "$TARGET_LIST" >&2
  echo "==> 无法获取鸿蒙设备列表。" >&2
  exit 1
fi
TARGET_LIST="$(printf '%s\n' "$TARGET_LIST" | sed '/^\[Empty\]/d; /^[[:space:]]*$/d')"
if [ -z "$TARGET_LIST" ]; then
  cat <<'EOF'
没有检测到鸿蒙设备。请检查：
  1. 手机已用数据线连到 Mac（部分线只能充电）
  2. 手机已开启开发者模式 + USB 调试，并点了「允许 USB 调试」
  3. hdc 服务正常（可执行：hdc kill && hdc start -r）
EOF
  exit 1
fi
if [ -n "${HDC_TARGET:-}" ]; then
  if [[ "$HDC_TARGET" == *$'\n'* ]] ||
    ! printf '%s\n' "$TARGET_LIST" | grep -Fx -- "$HDC_TARGET" >/dev/null; then
    echo "==> 指定目标未连接：$HDC_TARGET" >&2
    exit 1
  fi
  TARGET="$HDC_TARGET"
else
  TARGET="$(printf '%s\n' "$TARGET_LIST" | head -1)"
fi
echo "==> 设备：$TARGET"

echo "==> 安装 $(basename "$HAP")"
INSTALL_STATUS=0
INSTALL_OUTPUT="$("$HDC" -t "$TARGET" install -r "$HAP" 2>&1)" || INSTALL_STATUS=$?
printf '%s\n' "$INSTALL_OUTPUT"
# Some hdc versions return zero even when BundleManager rejected the install.
# Require the explicit success marker and reject all error/failure output.
if [ "$INSTALL_STATUS" -ne 0 ] ||
  printf '%s\n' "$INSTALL_OUTPUT" | grep -Ei '(^|[^[:alpha:]])(error|fail|failed|failure|fatal|timeout)([^[:alpha:]]|$)|timed[[:space:]]+out|connection[[:space:]]+(lost|closed|refused)' >/dev/null ||
  ! printf '%s\n' "$INSTALL_OUTPUT" | grep -Ei 'install[[:space:]]+bundle[[:space:]]+successfully' >/dev/null; then
  echo "==> 安装未确认成功（hdc 退出码：$INSTALL_STATUS），未卸载或清空任何数据。" >&2
  exit 1
fi

echo "==> 完成，请在手机上手动打开书影温故。查看日志："
echo "    $HDC -t $TARGET shell hilog | grep -i flutter"
