#!/usr/bin/env bash
#
# 生成 iOS / Android / 鸿蒙通用 9:16 上架截图。
# 需要：Xcode 模拟器 + 已安装 Pillow（pip3 install Pillow）。
#
#   ./tool/generate_screenshots.sh [output_dir]
#
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

SIM_ID="851501C5-DF97-48D6-81E4-9D46DA29B3C3"   # iPhone 17 Pro Max (6.9")
OUT_DIR="${1:-$APP_DIR/../store/screenshots}"
mkdir -p "$OUT_DIR"

export PATH="$HOME/development/flutter/bin:$PATH"

boot_sim() {
  if ! xcrun simctl list devices | grep -q "$SIM_ID.*Booted"; then
    echo "==> 启动模拟器 $SIM_ID"
    xcrun simctl boot "$SIM_ID"
    open -a Simulator
    sleep 5
  fi
  # 把状态栏统一成 09:41、满电、满信号，避免真实时间分散注意力
  xcrun simctl status_bar "$SIM_ID" override \
    --time "09:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3 2>/dev/null || true
}

FLUTTER_PID=""

run_tab() {
  local tab="$1"
  echo "==> 运行 Tab $tab"
  xcrun simctl uninstall "$SIM_ID" com.bookmovie.revisit.app 2>/dev/null || true
  flutter run -d "$SIM_ID" --dart-define=SHUYING_SCREENSHOT=true --dart-define=SHUYING_TAB="$tab" >/tmp/shuying_screenshot_tab${tab}.log 2>&1 &
  FLUTTER_PID=$!
  sleep 45
}

run_privacy() {
  echo "==> 运行隐私同意页"
  xcrun simctl uninstall "$SIM_ID" com.bookmovie.revisit.app 2>/dev/null || true
  flutter run -d "$SIM_ID" >/tmp/shuying_screenshot_privacy.log 2>&1 &
  FLUTTER_PID=$!
  sleep 45
}

kill_flutter() {
  if [ -n "$FLUTTER_PID" ]; then
    kill "$FLUTTER_PID" 2>/dev/null || true
    wait "$FLUTTER_PID" 2>/dev/null || true
    FLUTTER_PID=""
  fi
}

screenshot() {
  local name="$1"
  xcrun simctl io "$SIM_ID" screenshot "$OUT_DIR/ios-6.9/${name}.png" 2>/dev/null || \
    xcrun simctl io booted screenshot "$OUT_DIR/ios-6.9/${name}.png"
  echo "    $OUT_DIR/ios-6.9/${name}.png"
}

resize() {
  python3 - <<PY
import os
from PIL import Image
src = os.path.expanduser("$OUT_DIR/ios-6.9")
sizes = {
    "ios-6.5": (1284, 2778),
    "android-9-16": (1080, 1920),
    "huawei-9-16": (1080, 1920),
}
for folder, (w, h) in sizes.items():
    dst = os.path.join("$OUT_DIR", folder)
    os.makedirs(dst, exist_ok=True)
    for f in sorted(os.listdir(src)):
        if not f.endswith(".png"):
            continue
        im = Image.open(os.path.join(src, f))
        im2 = im.resize((w, h), Image.Resampling.LANCZOS)
        im2.save(os.path.join(dst, f))
PY
}

echo "==> 输出目录：$OUT_DIR"
mkdir -p "$OUT_DIR/ios-6.9"

boot_sim

run_privacy
screenshot "00-隐私同意"
kill_flutter

run_tab 0
screenshot "01-书架"
kill_flutter

run_tab 1
screenshot "02-电影"
kill_flutter

run_tab 2
screenshot "03-统计"
kill_flutter

echo "==> 生成 6.5 英寸 / Android / 鸿蒙 9:16 尺寸"
resize

echo "==> 完成"
