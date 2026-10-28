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
source "$APP_DIR/tool/build_version.sh"

HDC="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
if [ ! -x "$HDC" ]; then
  echo "==> 找不到 hdc：$HDC"
  exit 1
fi

HAP="${1:-$APP_DIR/ohos/entry/build/default/outputs/default/entry-default-signed.hap}"
[ -f "$HAP" ] || { echo "==> HAP 不存在：$HAP"; exit 1; }

# 真机测试也使用 release/AOT 业务代码；旧 SDK debug/JIT 快照与引擎不兼容。
python3 - "$HAP" "$APP_VER_NAME" "$APP_VER_BUILD" <<'PY'
import json, re, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    names = z.namelist()
    app = json.loads(z.read('module.json'))['app']
    if (app['bundleName'], app['versionName'], str(app['versionCode'])) != (
            'com.bookmovie.revisit.app.hm', sys.argv[2], sys.argv[3]):
        sys.exit('拒绝安装：包名或实际版本与当前候选不一致。')
    if not any(n.endswith('/libapp.so') for n in names) or any(
            n.endswith(('/kernel_blob.bin', '/vm_snapshot_data', '/isolate_snapshot_data'))
            for n in names):
        sys.exit('拒绝安装：该包含 debug/JIT 业务产物，请用 release.sh ohos-test 生成测试包。')
    for name in (n for n in names if n.endswith('/libapp.so')):
        data = z.read(name)
        header = data.find(bytes.fromhex('f5f5dcdc'))
        version = data[header + 20:header + 52] if header >= 0 else b''
        engine = name.rsplit('/', 1)[0] + '/libflutter.so'
        if not re.fullmatch(b'[0-9a-f]{32}', version) or version not in z.read(engine):
            sys.exit('拒绝安装：Dart 业务快照与 Flutter 引擎版本不匹配。')
print('==> 已核对实际版本、release/AOT 业务产物及引擎快照兼容性')
PY

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

echo "==> 安装 $(basename "$HAP")"
"$HDC" -t "$TARGETS" install -r "$HAP"

echo "==> 完成，请在手机上手动打开书影温故。查看日志："
echo "    $HDC -t $TARGETS shell hilog | grep -i flutter"
