#!/usr/bin/env bash
# 生成 Android release 签名密钥（.jks）并自动写出 android/key.properties。
#
# 用法（在 flutter_app 目录下执行）：
#   ./tool/gen-keystore.sh                  # 生成密钥（带防误生成保护）
#   ./tool/gen-keystore.sh --check          # 校验现有 .jks 指纹是否与登记表一致
#   ./tool/gen-keystore.sh --check <jks>    # 校验指定 .jks
#   ./tool/gen-keystore.sh --force          # 明知已有正式密钥仍要生成新的（危险）
#
# 前置：JDK 17+（keytool 在 PATH），或通过 KEYTOOL=... 环境变量指定。
# 产出：
#   1. ~/keys/shuyingwengu-release.jks   ← 密钥本体，务必备份到网盘 + U 盘
#   2. android/key.properties            ← 构建时读取，已被 .gitignore 忽略
#
# ⚠️ 密钥一旦用于上架就不可更换（换密钥 = 用户无法覆盖安装）。
#    密钥文件丢失 = 应用永远无法更新，只能换包名重新上架。
#
# ⚠️ 换机器时**不要**在新机器上跑本脚本重新生成！
#    把原机器上的 .jks 原样拷到 ~/keys/，然后跑 --check 验证指纹即可。
#    正确的密钥指纹登记在 tool/keystore-fingerprint.txt。
#
# 兼容：macOS 自带的 bash 3.2（不使用 bash 4+ 的 mapfile/readarray）。

set -euo pipefail
cd "$(dirname "$0")/.."

alias_name="shuyingwengu"
dname="CN=ShuYingWenGu, OU=Personal, O=BookMovie, L=City, S=State, C=CN"
reg_file="tool/keystore-fingerprint.txt"
mode="generate"
force=0
jks_arg=""

while [ $# -gt 0 ]; do
  case "$1" in
    --check) mode="check" ;;
    --force) force=1 ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) jks_arg="$1" ;;
  esac
  shift
done

# ── 1. 定位 keytool ─────────────────────────────────────────────
KEYTOOL="${KEYTOOL:-keytool}"
if ! command -v "$KEYTOOL" >/dev/null 2>&1; then
  for c in \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" \
    "$HOME/Library/Application Support/JetBrains/Toolbox/apps/android-studio/jbr/Contents/Home/bin/keytool"; do
    if [ -x "$c" ]; then KEYTOOL="$c"; break; fi
  done
fi
if ! command -v "$KEYTOOL" >/dev/null 2>&1; then
  echo "[错误] 未找到 keytool。请先安装 JDK 17+（brew install --cask temurin）或 Android Studio。" >&2
  exit 1
fi

# ── 2. 工具函数 ─────────────────────────────────────────────────
reg_value() {
  [ -f "$reg_file" ] || return 0
  awk -F= -v k="$1" '$1==k { sub(/^[^=]*=/, ""); print; exit }' "$reg_file" 2>/dev/null || true
}

# 从 key.properties 读 storePassword（存在才输出）
pass_from_props() {
  [ -f android/key.properties ] || return 0
  awk -F= '$1=="storePassword" { print $2; exit }' android/key.properties 2>/dev/null || true
}

# 取密码：优先 key.properties，否则交互输入
get_pass() {
  local p
  p="$(pass_from_props)"
  if [ -n "$p" ]; then echo "$p"; return 0; fi
  read -r -s -p "请输入 keystore 密码（不回显）：" p >&2 || true
  echo >&2
  echo "$p"
}

# 计算证书三种指纹，依次输出三行：MD5 / SHA1 / SHA256
# 任一项取不到就输出空行，便于用 sed -n 'Np' 定位
cert_fingerprints() {
  local ks="$1" pass="$2" tmp
  tmp="$(mktemp -d)"
  if ! "$KEYTOOL" -exportcert -rfc -keystore "$ks" -alias "$alias_name" \
        -storepass "$pass" -file "$tmp/c.pem" >/dev/null 2>&1; then
    rm -rf "$tmp"; return 1
  fi
  if command -v openssl >/dev/null 2>&1; then
    # 逐个容错：某个摘要算法不被 LibreSSL 支持时不影响其它项
    openssl x509 -in "$tmp/c.pem" -noout -fingerprint -md5    2>/dev/null | sed 's/^.*=//' || true
    openssl x509 -in "$tmp/c.pem" -noout -fingerprint -sha1   2>/dev/null | sed 's/^.*=//' || true
    openssl x509 -in "$tmp/c.pem" -noout -fingerprint -sha256 2>/dev/null | sed 's/^.*=//' || true
  else
    # 无 openssl 时退化为 keytool（Java 9+ 不显示 MD5，仅 SHA1/SHA256）
    echo ''
    "$KEYTOOL" -list -v -keystore "$ks" -storepass "$pass" 2>/dev/null | awk '/SHA1:/{print $2}' || true
    "$KEYTOOL" -list -v -keystore "$ks" -storepass "$pass" 2>/dev/null | awk '/SHA256:/{print $2}' || true
  fi
  rm -rf "$tmp"
}

# 指纹输出的第 1/2/3 行
fp_line() { printf '%s\n' "$1" | sed -n "${2}p"; }

# 生成/补齐 android/key.properties
write_props() {
  local pass="$1"
  if [ -d android ]; then
    cat > android/key.properties <<EOF
storePassword=$pass
keyPassword=$pass
keyAlias=$alias_name
storeFile=$jks
EOF
    echo "==> 已写出 android/key.properties"
  else
    echo "==> 跳过 key.properties：android/ 目录还不存在（跑完 flutter create 后再说）"
  fi
}

keys_dir="$HOME/keys"
jks="${jks_arg:-$keys_dir/${alias_name}-release.jks}"
reg_md5="$(reg_value MD5)"
reg_sha1="$(reg_value SHA1)"
reg_sha256="$(reg_value SHA256)"

# ── 3. 校验模式 ─────────────────────────────────────────────────
if [ "$mode" = "check" ]; then
  echo "==> 校验模式：$jks"
  if [ ! -f "$jks" ]; then
    echo "[错误] 文件不存在：$jks" >&2
    echo "       换机器时请先把原机器上的 .jks 拷到 ~/keys/。" >&2
    exit 1
  fi
  pass="$(get_pass)"
  fp_out="$(cert_fingerprints "$jks" "$pass")" || {
    echo "[错误] 读取证书失败（密码错误？）" >&2; exit 1; }
  md5="$(fp_line "$fp_out" 1)"
  sha1="$(fp_line "$fp_out" 2)"
  sha256="$(fp_line "$fp_out" 3)"

  echo "  实际    MD5    : ${md5:-（取不到）}"
  echo "  实际    SHA1   : ${sha1:-（取不到）}"
  echo "  实际    SHA256 : ${sha256:-（取不到）}"
  echo "  登记表  MD5    : ${reg_md5:-（无）}"
  echo "  登记表  SHA1   : ${reg_sha1:-（无）}"
  echo "  登记表  SHA256 : ${reg_sha256:-（无）}"
  echo ""
  if [ -n "$reg_md5" ] && [ "$md5" = "$reg_md5" ]; then
    echo "✅ 一致：这份 .jks 就是本项目的正式密钥，可放心用于构建与备案。"
    write_props "$pass"
    exit 0
  elif [ -n "$reg_sha1" ] && [ "$sha1" = "$reg_sha1" ]; then
    echo "✅ 一致（按 SHA1 判定）：这份 .jks 是正式密钥。"
    write_props "$pass"
    exit 0
  else
    echo "❌ 不一致！这份 .jks 不是本项目的正式密钥。" >&2
    echo "   千万不要用它构建上架包：备案信息对不上、老用户无法覆盖安装。" >&2
    echo "   请从备份（网盘 / U 盘）取回正确的那一份。" >&2
    exit 1
  fi
fi

# ── 4. 生成模式：防误生成拦截 ───────────────────────────────────
if [ -f "$jks" ]; then
  echo "==> 检测到已存在的密钥：$jks"
  pass_now="$(pass_from_props)"
  if [ -n "$pass_now" ]; then
    fp2_out="$(cert_fingerprints "$jks" "$pass_now" 2>/dev/null || true)"
    fp2_md5="$(fp_line "$fp2_out" 1)"
    if [ -n "$reg_md5" ] && [ "$fp2_md5" = "$reg_md5" ]; then
      echo "✅ 指纹与登记表一致 —— 这就是本项目的正式密钥，无需重新生成。"
      write_props "$pass_now"
      exit 0
    fi
  fi
  read -r -p "[警告] 覆盖已有密钥将导致无法更新已上架应用！确认覆盖？(y/N) " ans || true
  case "${ans:-}" in [Yy]*) rm -f "$jks" ;; *) echo "已取消。"; exit 0 ;; esac
elif [ -n "$reg_md5" ] && [ "$force" = "0" ]; then
  cat >&2 <<EOF

╔════════════════════════════════════════════════════════════════╗
║  ⛔ 停下！本机没有密钥，但本项目已有一份正式密钥的登记记录：  ║
╚════════════════════════════════════════════════════════════════╝

  登记表：$reg_file
  别名  ：$alias_name
  MD5   ：$reg_md5

  这意味着正式密钥**已经生成过了**（在生成它的那台机器上）。
  在另一台机器上跑本脚本会得到一份**全新的、不同的**密钥，后果：
    · 用新密钥签名的 APK 无法覆盖安装老版本（签名不一致）
    · 备案时填的证书指纹与实际上架包不符，需要走变更备案
    · 已上架的 App 永远无法更新 —— 只能换包名重新上架

  ✅ 正确做法：把原机器上的 .jks 文件拷到本机 ~/keys/，然后执行：
       ./tool/gen-keystore.sh --check

  ⚠️ 如果你确实是要**首次生成**、且登记表是过期或错误的，
     请删掉 $reg_file 或加 --force 继续。

EOF
  read -r -p "如果你确定要生成全新密钥，请输入 GENERATE-NEW-KEY 确认：" ans || true
  [ "${ans:-}" = "GENERATE-NEW-KEY" ] || { echo "已取消。"; exit 0; }
fi

# ── 5. 设置密码 ─────────────────────────────────────────────────
mkdir -p "$keys_dir"
while true; do
  read -r -s -p "请设置 keystore 密码（至少 6 位，输入不回显）：" store_pass; echo
  [ "${#store_pass}" -ge 6 ] || { echo "[错误] 密码至少 6 位。"; continue; }
  read -r -s -p "请再输入一次确认：" store_pass2; echo
  [ "$store_pass" = "$store_pass2" ] && break
  echo "[错误] 两次输入不一致，请重试。"
done

# ── 6. 生成密钥 ─────────────────────────────────────────────────
echo "[1/4] 生成密钥：$jks"
"$KEYTOOL" -genkeypair -v \
  -keystore "$jks" \
  -alias "$alias_name" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$store_pass" -keypass "$store_pass" \
  -dname "$dname"

# ── 7. 写出 android/key.properties ──────────────────────────────
write_props "$store_pass"

# ── 8. 打印指纹 ─────────────────────────────────────────────────
echo "[4/4] 完成！证书指纹："
fp3_out="$(cert_fingerprints "$jks" "$store_pass" || true)"
new_md5="$(fp_line "$fp3_out" 1)"
echo "  MD5    : ${new_md5:-（取不到，可手动跑 keytool -list -v）}"
echo "  SHA1   : $(fp_line "$fp3_out" 2)"
echo "  SHA256 : $(fp_line "$fp3_out" 3)"
if [ -n "$reg_md5" ]; then
  echo ""
  if [ "$new_md5" = "$reg_md5" ]; then
    echo "  ✅ 与登记表一致。"
  else
    echo "  ⚠️ 登记表里的 MD5 是 $reg_md5，与本次不一致 ——"
    echo "     你刚生成的是一份新密钥，请更新登记表与备案信息！"
  fi
fi

echo ""
echo "====================================================="
echo "  密钥文件：$jks"
echo "  请立即备份到网盘 + U 盘（至少两处异地）！"
echo "  丢失密钥 = 应用永远无法更新，只能换包名重新上架。"
echo "====================================================="
echo ""
echo "换机器后请执行：./tool/gen-keystore.sh --check   # 验证拷过来的密钥是对的"
echo "下一步："
echo "  flutter build apk --release --split-per-abi   # 出正式签名 APK"
echo "  keytool -printcert -jarfile <apk路径>          # 验证签名（备案时要填 MD5）"
