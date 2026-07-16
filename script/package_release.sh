#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="1.0.0"
APP_NAME="阿康的 Mac 贴贴"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME.app"
RELEASE_DIR="$ROOT_DIR/release"
ARCHIVE_PATH="$RELEASE_DIR/AkangMacTieTie-v${APP_VERSION}-macos.zip"

cd "$ROOT_DIR"
AKANG_BUILD_CONFIGURATION=Release ./script/build_and_run.sh --build-only

mkdir -p "$RELEASE_DIR"
rm -f "$ARCHIVE_PATH"
ditto --norsrc --noextattr --noqtn --noacl -c -k --keepParent "$SOURCE_APP" "$ARCHIVE_PATH"

unzip -tq "$ARCHIVE_PATH" >/dev/null
echo "正式发布包：$ARCHIVE_PATH"
