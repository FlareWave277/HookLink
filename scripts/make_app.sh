#!/bin/bash
# Builds HookLink.app (release) into dist/, with its icon and resources. Usage: scripts/make_app.sh
set -eu
cd "$(dirname "$0")/.."
VERSION=$(cat VERSION 2>/dev/null || echo 0.1.0)
swift build -c release
APP=dist/HookLink.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/HookLink "$APP/Contents/MacOS/HookLink"
cp -R Resources/tools Resources/presets "$APP/Contents/Resources/"
[ -f Resources/engine.json ] && cp Resources/engine.json "$APP/Contents/Resources/"
find "$APP/Contents/Resources" -name __pycache__ -prune -exec rm -rf {} +

# Icon
T=$(mktemp -d); swift scripts/make_icon.swift "$T/icon.png"
mkdir "$T/HookLink.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$T/icon.png" --out "$T/HookLink.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$T/icon.png" --out "$T/HookLink.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$T/HookLink.iconset" -o "$APP/Contents/Resources/HookLink.icns"; rm -rf "$T"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>HookLink</string>
  <key>CFBundleDisplayName</key><string>HookLink</string>
  <key>CFBundleIdentifier</key><string>io.github.hooklink</string>
  <key>CFBundleExecutable</key><string>HookLink</string>
  <key>CFBundleIconFile</key><string>HookLink</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF
codesign --force --sign - "$APP" >/dev/null 2>&1 || true   # ad-hoc signature, so macOS runs it after the right-click → Open prompt
(cd dist && rm -f HookLink.zip && ditto -c -k --keepParent HookLink.app HookLink.zip)
echo "built $APP and dist/HookLink.zip ($VERSION)"
