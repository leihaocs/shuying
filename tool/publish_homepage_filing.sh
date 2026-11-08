#!/usr/bin/env bash
# 在现有阿里云服务器的暂存目录执行，仅发布官网首页和公安备案图标。
set -euo pipefail

page_dir="$(cd "${1:?请传入首页暂存目录}" && pwd)"
web_dir=/data/www
[[ "$(uname -s)" == Linux && -d "$web_dir" ]] || {
  echo '请在现有阿里云网站服务器上运行。' >&2
  exit 1
}
cd "$page_dir"
sha256sum -c SHA256SUMS
for name in index.html beian.png; do
  [[ ! -L "$web_dir/$name" ]] || { echo "拒绝覆盖符号链接：$name" >&2; exit 1; }
  [[ ! -e "$web_dir/$name" || -f "$web_dir/$name" ]] || exit 1
done
# 首页在准备之后若有他人改动，先重新核对，不直接覆盖。
sha256sum -c INDEX_BEFORE.sha256
backup_dir="$(mktemp -d "$page_dir/previous.XXXXXX")"
cp "$web_dir/index.html" "$backup_dir/index.html"
if [[ -f "$web_dir/beian.png" ]]; then cp "$web_dir/beian.png" "$backup_dir/beian.png"; fi

# 原首页和父目录均由 root 管理；密码仅在用户自己的终端输入。
sudo -v
temp_index="$(sudo mktemp "$web_dir/.index-filing.XXXXXX")"
trap 'sudo rm -f -- "$temp_index"' EXIT
sudo /usr/bin/install -o root -g root -m 0644 beian.png "$web_dir/beian.png"
sudo /usr/bin/install -o root -g root -m 0644 index.html "$temp_index"
sudo /bin/mv -fT -- "$temp_index" "$web_dir/index.html"
(cd "$web_dir" && sha256sum -c "$page_dir/SHA256SUMS")
echo "首页及公安备案图标发布完成；原文件备份：$backup_dir"
