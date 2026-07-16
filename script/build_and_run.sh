#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/MacPastie"
DERIVED_DATA="$ROOT_DIR/.build"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="阿康的 Mac 贴贴"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
BUNDLE_ID="com.akang.macpastie"
CONFIGURATION="${AKANG_BUILD_CONFIGURATION:-Release}"
SIGNING_MODE="${AKANG_SIGNING_MODE:-development}"
DEVELOPER_ID_APPLICATION="${DEVELOPER_ID_APPLICATION:-}"
SPARKLE_EDDSA_PUBLIC_KEY="${SPARKLE_EDDSA_PUBLIC_KEY:-}"

cd "$PROJECT_DIR"
xcodegen generate

BUILD_ARGS=(
  -project MacPastie.xcodeproj
  -scheme MacPastie
  -configuration "$CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA"
  ONLY_ACTIVE_ARCH=NO
  ARCHS="arm64 x86_64"
  SPARKLE_EDDSA_PUBLIC_KEY="$SPARKLE_EDDSA_PUBLIC_KEY"
)

if [[ "$SIGNING_MODE" == "distribution" ]]; then
  if [[ -z "$DEVELOPER_ID_APPLICATION" || -z "$SPARKLE_EDDSA_PUBLIC_KEY" ]]; then
    echo "发布构建需要 DEVELOPER_ID_APPLICATION 和 SPARKLE_EDDSA_PUBLIC_KEY。" >&2
    exit 2
  fi
  BUILD_ARGS+=(CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION")
else
  BUILD_ARGS+=(CODE_SIGNING_ALLOWED=NO)
fi

xcodebuild "${BUILD_ARGS[@]}" clean build

SOURCE_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$DIST_DIR"
ditto "$SOURCE_APP" "$APP_BUNDLE"

if [[ "$SIGNING_MODE" == "distribution" ]]; then
  /usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
else
  /usr/bin/codesign \
    --force \
    --deep \
    --sign - \
    --identifier "$BUNDLE_ID" \
    --requirements "=designated => identifier \"$BUNDLE_ID\"" \
    --entitlements "$PROJECT_DIR/MacPastie.entitlements" \
    "$APP_BUNDLE" >/dev/null

  /usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
fi

case "$MODE" in
  --build-only|build-only)
    echo "$APP_NAME 已构建：$APP_BUNDLE"
    ;;
  run)
    /usr/bin/open "$APP_BUNDLE"
    ;;
  --verify|verify)
    /usr/bin/open "$APP_BUNDLE"
    sleep 2
    pgrep -f "$APP_BUNDLE/Contents/MacOS/$APP_NAME" >/dev/null
    echo "$APP_NAME 已启动：$APP_BUNDLE"
    ;;
  *)
    echo "用法：$0 [run|--build-only|--verify]" >&2
    exit 2
    ;;
esac
