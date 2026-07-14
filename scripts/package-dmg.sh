#!/usr/bin/env bash
# Build Nab.app and wrap it in a drag-to-Applications .dmg.
#
#   scripts/package-dmg.sh [version]
#
# Produces dist/Nab-<version>.dmg containing a proper Nab.app bundle
# (ad-hoc signed, so it launches as an app instead of opening Terminal) and a
# Finder window that shows the app next to Applications with a "drag here" arrow.
#
# The build is unsigned/unnotarized, so first-run still shows Gatekeeper's
# "unidentified developer" prompt — users right-click > Open (or allow it in
# System Settings > Privacy & Security). That is expected without a $99 Apple
# Developer account.
set -euo pipefail

VERSION="${1:-0.3.0}"
APP_NAME="Nab"
BUNDLE_ID="com.nabapp.Nab"
VOL_NAME="Nab"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; hdiutil detach "/Volumes/$VOL_NAME" -quiet 2>/dev/null || true' EXIT

echo "==> Building release binary (universal if possible)"
if swift build -c release --arch arm64 --arch x86_64 2>"$WORK/build.log"; then
  BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
  echo "    universal (arm64 + x86_64)"
else
  echo "    universal build failed, falling back to native arch (see below)"
  tail -3 "$WORK/build.log" || true
  swift build -c release
  BIN_DIR="$(swift build -c release --show-bin-path)"
fi
BIN="$BIN_DIR/$APP_NAME"
[ -f "$BIN" ] || { echo "error: binary not found at $BIN" >&2; exit 1; }
file "$BIN"

echo "==> Generating icon + DMG background"
swift "$ROOT/scripts/make-assets.swift" icon "$WORK/icon.png"
swift "$ROOT/scripts/make-assets.swift" background "$WORK/background.png"
# The 1320x800 background is a 2x asset for a 660x400-point window. Tag it 144 DPI
# so Finder scales it to 660x400 points (crisp on Retina) instead of drawing it at
# native pixel size and clipping the right half.
sips -s dpiWidth 144 -s dpiHeight 144 "$WORK/background.png" >/dev/null

# Build AppIcon.icns from the 1024 master.
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for sz in 16 32 128 256 512; do
  sips -z $sz $sz         "$WORK/icon.png" --out "$ICONSET/icon_${sz}x${sz}.png"    >/dev/null
  sips -z $((sz*2)) $((sz*2)) "$WORK/icon.png" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$WORK/AppIcon.icns"

echo "==> Assembling $APP_NAME.app"
APP="$WORK/$APP_NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$WORK/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSInputMonitoringUsageDescription</key>
    <string>Nab watches for the double-tap ⌘ / ⌃ gestures that trigger capture and share.</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# Prefer the stable local identity (scripts/dev-signing-cert.sh) so keychain
# ACLs and TCC grants (Accessibility / Screen Recording) survive rebuilds.
# Fall back to ad-hoc, which is valid but resets those approvals every build.
SIGN_ID="-"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "Nab Dev Signing"; then
  SIGN_ID="Nab Dev Signing"
  echo "==> Signing with stable identity '$SIGN_ID'"
else
  echo "==> Ad-hoc signing (run scripts/dev-signing-cert.sh once to stop the"
  echo "    per-build keychain / permission prompts)"
fi
# Signing gives a valid, self-consistent signature so macOS won't call the app
# "damaged". It is still unsigned by a registered developer, so first launch
# shows the normal "unidentified developer" prompt (right-click > Open). Do NOT
# add a Finder custom icon here: that leaves a com.apple.FinderInfo xattr that
# codesign rejects, which can turn into a "damaged" error. The app's own
# AppIcon.icns renders once the volume is mounted and Launch Services indexes it.
codesign --force --deep --sign "$SIGN_ID" "$APP"
codesign --verify --deep --strict "$APP" && echo "    signature ok"

echo "==> Staging DMG contents"
STAGE="$WORK/stage"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/$APP_NAME.app"
cp "$WORK/background.png" "$STAGE/.background/background.png"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating writable DMG"
RW="$WORK/rw.dmg"
SIZE_MB=$(( $(du -sm "$STAGE" | cut -f1) + 30 ))
hdiutil create -srcfolder "$STAGE" -volname "$VOL_NAME" -fs HFS+ \
  -format UDRW -size "${SIZE_MB}m" -ov "$RW" >/dev/null

MOUNT="/Volumes/$VOL_NAME"
hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
hdiutil attach "$RW" -readwrite -noverify -noautoopen >/dev/null
# Give Finder a moment to register the new volume.
for _ in 1 2 3 4 5; do [ -d "$MOUNT" ] && break; sleep 1; done

echo "==> Laying out Finder window"
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        -- Outer height = content(400) + title bar (~28) so the 660x400 background fills the content area.
        set the bounds of container window to {200, 120, 860, 548}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 128
        set text size of opts to 12
        set background picture of opts to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {165, 205}
        set position of item "Applications" of container window to {495, 205}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
sync

echo "==> Compressing final DMG"
mkdir -p "$DIST"
OUT="$DIST/${APP_NAME}-${VERSION}.dmg"
hdiutil detach "$MOUNT" -quiet
rm -f "$OUT"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null

echo
echo "Done: $OUT"
ls -lh "$OUT"
