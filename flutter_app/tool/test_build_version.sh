#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

printf 'version: 1.0.0+6\n' > "$FIXTURE_DIR/pubspec.yaml"
for attempt in 1 2; do
  (
    APP_DIR="$FIXTURE_DIR"
    source "$TOOL_DIR/build_version.sh"
    test "$SHUYING_OFFICIAL_BUILD_NUMBER" = 5
    test "$SHUYING_IOS_VERSION_NAME" = '1.0.1'
    test "$SHUYING_IOS_BUILD_NUMBER" = 7
    test "$APP_VER_RAW" = '1.0.0+6'
    test "$DART_DEFINE" = '--dart-define=APP_VERSION=1.0.0 (6)'
  )
done

printf 'version: 1.0.0+7\n' > "$FIXTURE_DIR/pubspec.yaml"
if (APP_DIR="$FIXTURE_DIR"; source "$TOOL_DIR/build_version.sh") > "$FIXTURE_DIR/output" 2>&1; then
  echo '错误：误升号 7 未被拒绝。' >&2
  exit 1
fi
grep -q '候选号必须固定为 6' "$FIXTURE_DIR/output"
echo '通过：iOS 明确授权固定 1.0.1(7)，其他平台重复构建保持 6，全局误升到 7 被拒绝。'
