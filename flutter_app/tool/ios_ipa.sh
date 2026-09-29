#!/usr/bin/env bash
#
# 书影温故（Reel&Read）iOS 签名打包
#
# 前置条件：Xcode 已登录 Apple ID（Xcode → Settings → Accounts → + → Apple ID），
#           并在 Runner target 的 Signing & Capabilities 中选中 Team（勾选自动签名）。
#
#   ./tool/ios_ipa.sh             自动探测证书并打包
#   ./tool/ios_ipa.sh development 强制 development 导出（免费账号可用，供本地安装）
#   ./tool/ios_ipa.sh app-store   直接上传 App Store Connect（需付费开发者账号）
#   ./tool/ios_ipa.sh ad-hoc      强制 Ad Hoc 分发（需付费账号 + 在开发者网站手动添加设备 UDID）
#   ./tool/ios_ipa.sh testflight  导出 App Store 类型 IPA 到本地，用 Transporter 上传到 TestFlight
#
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

export PATH="$HOME/development/flutter/bin:$PATH"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

REQUESTED="${1:-auto}"

# --- 1. 列出可用的代码签名身份 ---
IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"

if [ -z "$IDENTITIES" ] || echo "$IDENTITIES" | grep -q "0 valid identities found"; then
  cat <<'EOF'
未找到任何代码签名证书。

请先完成一次（只需一次）：
  1. 打开 Xcode → Settings（⌘,）→ Accounts → 左下角 "+" → 选 Apple ID → 登录 leihaocs@foxmail.com
  2. 登录后在 Accounts 里点中该账号，右下角 "Manage Certificates…" → "+" → Apple Development
  3. 打开 ios/Runner.xcworkspace，选中 Runner target → Signing & Capabilities
     → 勾选 Automatically manage signing → Team 选择上面的账号
  4. 重新执行本脚本
EOF
  exit 1
fi

echo "==> 可用签名证书："
echo "$IDENTITIES" | sed -n 's/.*"\(.*\)".*/\1/p' | sed 's/^/    /'

# --- 2. 判断导出方式 ---
has_dist()  { echo "$IDENTITIES" | grep -qiE 'Apple Distribution|iPhone Distribution'; }
has_dev()   { echo "$IDENTITIES" | grep -qiE 'Apple Development|iPhone Developer'; }

METHOD="$REQUESTED"
LOCAL_IPA=0
if [ "$METHOD" = "auto" ]; then
  if has_dist; then METHOD="app-store"; else METHOD="development"; fi
fi

# TestFlight：签名方式等同 App Store（Apple Distribution），但产出本地 IPA 交给 Transporter 上传
if [ "$METHOD" = "testflight" ]; then
  if ! has_dist; then
    cat <<'EOF'
TestFlight 需要 Apple Distribution 证书，而它只有付费开发者账号才能签发。
当前钥匙串里只有 Apple Development 证书（免费 Personal Team），无法导出 TestFlight 包。

请加入 Apple Developer Program（¥688/年），生效后：
  1. Xcode → Settings（⌘,）→ Accounts → 选中账号 → Download Manual Profiles
  2. 打开 ios/Runner.xcworkspace → Runner target → Signing & Capabilities
     → Team 换成付费账号（个人 / 公司名，而不是 Personal Team）
  3. 重新执行 ./tool/ios_ipa.sh testflight
EOF
    exit 1
  fi
  METHOD="app-store"; LOCAL_IPA=1
fi

if { [ "$METHOD" = "app-store" ] || [ "$METHOD" = "ad-hoc" ]; } && ! has_dist; then
  echo "==> 未找到 Apple Distribution 证书，退回 development 导出"
  METHOD="development"
fi
echo "==> 导出方式：$METHOD"

# --- 3. 从证书中提取 Team ID（OU 字段） ---
pick_identity() {
  echo "$IDENTITIES" | grep -E "$1" | head -1 | sed -n 's/.*"\(.*\)".*/\1/p' || true
}

if [ "$METHOD" = "app-store" ] || [ "$METHOD" = "ad-hoc" ]; then
  IDENTITY="$(pick_identity 'Apple Distribution|iPhone Distribution')"
else
  IDENTITY="$(pick_identity 'Apple Development|iPhone Developer')"
fi
[ -n "$IDENTITY" ] || IDENTITY="$(pick_identity '.')"
echo "==> 使用证书：$IDENTITY"

# openssl 输出的 subject 形如 "... CN=Apple Development: xxx (YYYY), OU=Y25KP5S862, O=..."
# 注意 OU 后没有空格，同时兼容 "OU = " 的旧格式。
TEAM_ID="$(security find-certificate -c "$IDENTITY" -p 2>/dev/null \
  | openssl x509 -noout -subject 2>/dev/null \
  | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1 || true)"

# 证书还没生成时，回退到 Xcode 已登录账号里的 Team ID
if [ -z "$TEAM_ID" ]; then
  TEAM_ID="$(defaults read com.apple.dt.Xcode 2>/dev/null \
    | grep -oE 'teamID = "[A-Z0-9]{10}"' | head -1 \
    | grep -oE '[A-Z0-9]{10}' || true)"
fi

# 免费（Personal Team）账号无法生成 App Store 分发证书，也不允许无设备出包
IS_FREE_TEAM="$(defaults read com.apple.dt.Xcode 2>/dev/null \
  | grep -c 'isFreeProvisioningTeam = 1' || true)"

echo "==> Team ID：${TEAM_ID:-（未解析到，交给 Xcode 自动推断）}"

if [ "${IS_FREE_TEAM:-0}" != "0" ]; then
  echo "==> 检测到免费 Apple ID（Personal Team）："
  echo "    · 不能生成 Apple Distribution 证书，无法导出 App Store / TestFlight 包"
  echo "    · 免费账号出 development 包前，必须先用 USB 或 Wi-Fi 连上一台 iPhone 完成设备注册"
  if [ "$METHOD" = "app-store" ]; then
    echo "==> 当前请求 app-store 导出，免费账号不支持；如需上架请加入 Apple Developer Program"
    exit 1
  fi
fi

# --- 4. 生成 ExportOptions.plist ---
EXPORT_PLIST="ios/ExportOptions.plist"
# destination=export 才会产出本地 IPA（development / ad-hoc / testflight）
# destination=upload 由 Xcode 直接上传 App Store Connect，本地不出 IPA
if [ "$METHOD" = "app-store" ] && [ "$LOCAL_IPA" != "1" ]; then
  DEST="upload"; THINNING="none"
else
  DEST="export"; THINNING="none"
fi

cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>${METHOD}</string>
	<key>destination</key>
	<string>${DEST}</string>
	<key>signingStyle</key>
	<string>automatic</string>
$( [ -n "$TEAM_ID" ] && echo "	<key>teamID</key>
	<string>${TEAM_ID}</string>" )
	<key>uploadBitcode</key>
	<false/>
	<key>uploadSymbols</key>
	<true/>
	<key>compileBitcode</key>
	<false/>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>thinning</key>
	<string>&lt;${THINNING}&gt;</string>
</dict>
</plist>
PLIST
echo "==> 已写入 $EXPORT_PLIST"

# --- 4.5 development 导出前的真机与环境检查 ---
if [ "$METHOD" = "development" ]; then
  # Xcode 没登录账号时，自动签名会在打包后期才报 "No Accounts"，这里提前提醒。
  if ! defaults read com.apple.dt.Xcode 2>/dev/null | grep -q 'teamID'; then
    echo "==> 警告：未在 Xcode 设置里读到已登录的 Apple ID"
    echo "    若稍后报 \"No Accounts\"，请先 Xcode → Settings（⌘,）→ Accounts → + 登录 leihaocs@foxmail.com"
  fi

  XCODE_MAJOR="$(xcodebuild -version 2>/dev/null | awk '/^Xcode /{print int($2)}' || true)"
  # 列出所有在线设备的系统版本，挑出 Xcode 能支持的最高版本（多台设备时忽略过高版本那台）
  ALL_OS="$(xcrun devicectl list devices -v 2>/dev/null \
    | grep -oE 'osVersionNumber: Optional\("[0-9.]+"\)' \
    | grep -oE '[0-9]+\.[0-9]+' | sort -u -t. -k1,1n -k2,2n)"
  DEV_OS=""
  for v in $ALL_OS; do
    if [ "${v%%.*}" -le "$XCODE_MAJOR" ]; then DEV_OS="$v"; fi
  done

  if [ -n "$ALL_OS" ]; then
    echo "==> 在线设备系统版本：$(echo $ALL_OS | tr '\n' ' ')／本机 Xcode $XCODE_MAJOR"
  fi

  if [ -n "$DEV_OS" ]; then
    echo "==> 使用兼容设备 iOS ${DEV_OS} ，其余版本过高的设备已忽略"
  elif [ -n "$ALL_OS" ]; then
    cat <<EOF

所有在线设备的系统版本都高于 Xcode $XCODE_MAJOR 的支持范围（$(echo $ALL_OS | tr '\n' ' ')）：
Xcode 无法解析更高版本 iOS 的 dyld 共享缓存，设备注册会卡在 dyld_shared_cache_extract_dylibs failed。

请换一台 iOS ${XCODE_MAJOR}.x 的 iPhone，或到 developer.apple.com → Devices 手动添加 UDID
（手动注册不需要 Xcode 准备设备，可绕开这一步）。
EOF
    exit 1
  else
    echo "==> 未检测到已连接设备（免费账号首次出包需要连一台 iPhone 完成注册）"
  fi

  FREE_GB="$(df -g /System/Volumes/Data 2>/dev/null | awk 'NR==2{print $4}')"
  echo "==> 可用磁盘：${FREE_GB:-?}GB"
  if [ "${FREE_GB:-0}" -lt 5 ]; then
    echo "==> 磁盘不足 5GB，Xcode 展开设备 dyld 共享缓存会失败，请先清理磁盘"
    exit 1
  fi
fi

# --- 5. 打包 ---
flutter pub get
# flutter build 会更新 ios/Podfile.lock 但不刷新 Pods/Manifest.lock，
# 不同步会让 xcodebuild 报 "The sandbox is not in sync with the Podfile.lock"。
(cd ios && pod install)
# 版本号注入（与 tool/release.sh 同逻辑，唯一来源是 pubspec.yaml）
APP_VER_RAW="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -1 | tr -d '\r')"
APP_VER_NAME="${APP_VER_RAW%%+*}"
APP_VER_BUILD="${APP_VER_RAW#*+}"
if [ "$APP_VER_BUILD" = "$APP_VER_RAW" ]; then APP_VER_BUILD="1"; fi
echo "==> 版本号注入：$APP_VER_NAME ($APP_VER_BUILD)"
flutter build ipa --release --dart-define="APP_VERSION=$APP_VER_NAME ($APP_VER_BUILD)" --export-options-plist="$EXPORT_PLIST"

IPA="$(ls -1 build/ios/ipa/*.ipa 2>/dev/null | head -1)"
if [ -n "$IPA" ]; then
  echo "==> 完成：$IPA"
  ls -lh "$IPA"
  if [ "$LOCAL_IPA" = "1" ]; then
    cat <<EOF

下一步（TestFlight）：
  1. 打开 Transporter（Mac App Store 免费）→ 用同一 Apple ID 登录 → 拖入上面的 IPA → 交付
     或用命令行：xcrun altool --upload-app -f "$IPA" -t ios --apiKey <KEY> --apiIssuer <ISSUER>
  2. App Store Connect → 我的 App → 书影温故 → TestFlight → 内部测试
     → 新建测试组（或加自己为测试员）→ 添加该构建 → 保存
  3. iPhone 13 上安装 TestFlight App，用同一 Apple ID 登录即可看到并安装
     内部测试不需要审核，上传处理完（通常几分钟）即可安装。
EOF
  fi
else
  echo "==> 未产出 IPA，请查看上方 xcodebuild 错误"
  exit 1
fi
