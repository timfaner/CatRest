#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CatRest"
BUNDLE_ID="local.codex.CatRest"
MIN_SYSTEM_VERSION="13.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"

if pgrep -x "$APP_NAME" >/dev/null; then
  pkill -x "$APP_NAME"
fi

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -d "$ROOT_DIR/videos" ]]; then
  rm -rf "$APP_RESOURCES/videos"
  cp -R "$ROOT_DIR/videos" "$APP_RESOURCES/videos"
fi

if [[ -d "$ROOT_DIR/Assets" ]]; then
  rm -rf "$APP_RESOURCES/Assets"
  mkdir -p "$APP_RESOURCES/Assets"
  cp "$ROOT_DIR"/Assets/MenuBarCatClock*.png "$APP_RESOURCES/Assets/"
  cp "$ROOT_DIR/Assets/CatRestIconSource.png" "$APP_RESOURCES/Assets/"
fi

if [[ -f "$ROOT_DIR/Assets/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Assets/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
fi

cat > "$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
  </array>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE" "$@"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME is running."
    ;;
  --smoke-cycle|smoke-cycle)
    open_app --args --auto-start --auto-continue-after-rest --work-seconds 3 --rest-seconds 4
    sleep 10
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME survived smoke work/rest cycle."
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--smoke-cycle]" >&2
    exit 2
    ;;
esac
