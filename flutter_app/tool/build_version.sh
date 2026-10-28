#!/usr/bin/env bash
# 由 release.sh / ios_ipa.sh 在设置 APP_DIR 后 source。
# 正式基线只接受用户明确指定，不根据修复、编译或审核状态自动改变。
SHUYING_OFFICIAL_BUILD_NUMBER=5
SHUYING_CANDIDATE_BUILD_NUMBER=$((SHUYING_OFFICIAL_BUILD_NUMBER + 1))

APP_VER_RAW="$(sed -n 's/^version:[[:space:]]*//p' "$APP_DIR/pubspec.yaml" | head -1 | tr -d '\r')"
APP_VER_NAME="${APP_VER_RAW%%+*}"
APP_VER_BUILD="${APP_VER_RAW#*+}"
if [ "$APP_VER_BUILD" != "$SHUYING_CANDIDATE_BUILD_NUMBER" ]; then
  echo "构建号不符合约定：用户指定正式号 ${SHUYING_OFFICIAL_BUILD_NUMBER}，候选号必须固定为 ${SHUYING_CANDIDATE_BUILD_NUMBER}，当前为 ${APP_VER_RAW}。" >&2
  echo "仅在用户明确指定新的正式构建号后才可更新正式基线。" >&2
  exit 1
fi
DART_DEFINE="--dart-define=APP_VERSION=$APP_VER_NAME ($APP_VER_BUILD)"
