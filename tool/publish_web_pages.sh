#!/usr/bin/env bash
# 在阿里云服务器运行：bash publish_web_pages.sh <包含网页和 SHA256SUMS 的目录>
# 首次创建目标文件可能需要 sudo；之后仅这两个网页归部署账户所有。
set -euo pipefail

page_dir="$(cd "${1:?请传入网页暂存目录}" && pwd)"
web_dir=/data/www
[[ "$(uname -s)" == Linux && -d "$web_dir" ]] || {
  echo '请在现有阿里云网站服务器上运行。' >&2
  exit 1
}
cd "$page_dir"
sha256sum -c SHA256SUMS

for name in privacy.html support.html; do
  [[ ! -L "$web_dir/$name" ]] || { echo "拒绝覆盖符号链接：$name" >&2; exit 1; }
  [[ ! -e "$web_dir/$name" || -f "$web_dir/$name" ]] || exit 1
done
backup_dir="$(mktemp -d "$page_dir/previous.XXXXXX")"
for name in privacy.html support.html; do
  if [[ -f "$web_dir/$name" ]]; then cp "$web_dir/$name" "$backup_dir/$name"; fi
done

if [[ -w "$web_dir/privacy.html" && -w "$web_dir/support.html" ]]; then
  # ponytail: 父目录由 root 管理，两张小静态页原位写入；需要原子发布时再设专用目录。
  cat privacy.html > "$web_dir/privacy.html"
  cat support.html > "$web_dir/support.html"
else
  sudo_args=()
  if [[ "${NONINTERACTIVE:-0}" == 1 ]]; then sudo_args+=(-n); fi
  sudo "${sudo_args[@]}" /usr/bin/install -o "$(id -un)" -g "$(id -gn)" -m 0644 \
    "$page_dir/privacy.html" "$page_dir/support.html" "$web_dir/"
fi

(cd "$web_dir" && sha256sum -c "$page_dir/SHA256SUMS")
echo "发布完成；原网页备份：$backup_dir"
