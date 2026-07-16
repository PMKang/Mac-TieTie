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

cd "$PROJECT_DIR"
xcodegen generate

xcodebuild \
  -project MacPastie.xcodeproj \
  -scheme MacPastie \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="arm64 x86_64" \
  CODE_SIGNING_ALLOWED=NO \
  clean build

SOURCE_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$DIST_DIR"
ditto "$SOURCE_APP" "$APP_BUNDLE"

/usr/bin/codesign \
  --force \
  --deep \
  --sign - \
  --identifier "$BUNDLE_ID" \
  --requirements "=designated => identifier \"$BUNDLE_ID\"" \
  --entitlements "$PROJECT_DIR/MacPastie.entitlements" \
  "$APP_BUNDLE" >/dev/null

/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"

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
