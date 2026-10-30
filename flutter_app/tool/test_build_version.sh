#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

printf 'version: 1.0.0+7\n' > "$FIXTURE_DIR/pubspec.yaml"
for attempt in 1 2; do
  (
    APP_DIR="$FIXTURE_DIR"
    source "$TOOL_DIR/build_version.sh"
    test "$SHUYING_OFFICIAL_BUILD_NUMBER" = 6
    test "$SHUYING_IOS_VERSION_NAME" = '1.0.1'
    test "$SHUYING_IOS_BUILD_NUMBER" = 7
    test "$APP_VER_RAW" = '1.0.0+7'
    test "$DART_DEFINE" = '--dart-define=APP_VERSION=1.0.0 (7)'
  )
done

for invalid in 6 8; do
  printf 'version: 1.0.0+%s\n' "$invalid" > "$FIXTURE_DIR/pubspec.yaml"
  if (APP_DIR="$FIXTURE_DIR"; source "$TOOL_DIR/build_version.sh") > "$FIXTURE_DIR/output" 2>&1; then
    echo "错误：不符合约定的构建号 $invalid 未被拒绝。" >&2
    exit 1
  fi
  grep -q '候选号必须固定为 7' "$FIXTURE_DIR/output"
done
echo '通过：正式基线 6，各端重复构建固定 7，旧候选 6 与误升号 8 均被拒绝。'
