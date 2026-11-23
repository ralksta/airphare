#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AirPhare"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT_DIR/Resources/Info.plist")"
IDENTITY="${DEVELOPER_ID_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-airphare-notary}"
UNIVERSAL=true
SKIP_NOTARY=false
PUBLISH=false

usage() {
    cat <<EOF
Usage: ./scripts/release-dmg.sh [options]

Options:
  --version <ver>           Release version (default from Info.plist: $VERSION)
  --identity <name>         Codesign identity (default: auto-detect 'Developer ID Application')
  --notary-profile <name>   notarytool keychain profile (default: $NOTARY_PROFILE)
  --arm64-only              Build Apple Silicon only instead of Universal (arm64 + x86_64)
  --skip-notary             Skip Apple notarization & stapling (for local testing only)
  --publish                 Create GitHub Release v<version> and upload DMG via gh CLI
  -h, --help                Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --identity) IDENTITY="$2"; shift 2 ;;
        --notary-profile) NOTARY_PROFILE="$2"; shift 2 ;;
        --arm64-only) UNIVERSAL=false; shift ;;
        --skip-notary) SKIP_NOTARY=true; shift ;;
        --publish) PUBLISH=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if [[ -z "$IDENTITY" ]]; then
    IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application:/ {print $2; exit}')"
fi

if [[ -z "$IDENTITY" ]]; then
    echo "Error: No 'Developer ID Application' certificate found in keychain."
    exit 1
fi

echo "==> Release: $APP_NAME v$VERSION"
echo "==> Identity: $IDENTITY"

cd "$ROOT_DIR"

echo "==> Running unit tests..."
swift test

echo "==> Building release binary..."
if [[ "$UNIVERSAL" == true ]]; then
    swift build -c release --arch arm64 --arch x86_64
    BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME"
else
    swift build -c release
    BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"
fi

if [[ ! -f "$BIN_PATH" ]]; then
    echo "Error: Binary not found at $BIN_PATH"
    exit 1
fi

file "$BIN_PATH"

echo "==> Assembling $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"
if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "==> Code signing $APP_BUNDLE (Hardened Runtime + Timestamp)..."
codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
RW_DMG_PATH="$BUILD_DIR/${APP_NAME}-${VERSION}-rw.dmg"
STAGING_DIR="$BUILD_DIR/dmg-staging"
MOUNT_DIR="/Volumes/$APP_NAME"

echo "==> Preparing styled DMG layout..."
rm -rf "$STAGING_DIR" "$DMG_PATH" "$RW_DMG_PATH"
mkdir -p "$STAGING_DIR/.background"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

if [[ -f "$ROOT_DIR/Resources/dmg-background.png" ]]; then
    cp "$ROOT_DIR/Resources/dmg-background.png" "$STAGING_DIR/.background/background.png"
fi

# Create temporary read-write HFS+ DMG, apply Finder icon layout, then convert to compressed UDZO
hdiutil create -fs HFS+ -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -format UDRW -ov "$RW_DMG_PATH" >/dev/null
rm -rf "$STAGING_DIR"

if [[ -d "$MOUNT_DIR" ]]; then
    hdiutil detach "$MOUNT_DIR" -quiet || true
fi

DEVICE="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG_PATH" | awk '/\/Volumes\// {print $1; exit}')"
sleep 1

if [[ -d "$MOUNT_DIR" ]]; then
    osascript <<APPLESCRIPT || true
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {220, 140, 820, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 120
        try
            set background picture of viewOptions to file ".background:background.png"
        end try
        set position of item "$APP_NAME.app" of container window to {165, 200}
        set position of item "Applications" of container window to {435, 200}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
    sync
    hdiutil detach "$DEVICE" -quiet || hdiutil detach "$MOUNT_DIR" -force -quiet || true
fi

echo "==> Converting styled DMG to compressed UDZO at $DMG_PATH..."
hdiutil convert "$RW_DMG_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG_PATH"

echo "==> Signing DMG..."
codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"

if [[ "$SKIP_NOTARY" == false ]]; then
    echo "==> Submitting DMG to Apple Notary Service (profile: $NOTARY_PROFILE)..."
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

    echo "==> Stapling notarization ticket to DMG..."
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"

    echo "==> Verifying Gatekeeper acceptance..."
    spctl -a -t open --context context:primary-signature -v "$DMG_PATH"
else
    echo "==> Skipping notarization (--skip-notary)."
fi

SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
echo "==> Done: $DMG_PATH"
echo "==> SHA-256: $SHA256"

if [[ "$PUBLISH" == true ]]; then
    TAG="v$VERSION"
    echo "==> Publishing GitHub Release $TAG..."
    NOTES="$(cat <<EOF
## AirPhare $TAG

Native macOS menu bar Wi-Fi watchdog, Control Center replacement, DFS/IPv6-loop detector & CSV network logger.

### What's New in $TAG
- **24h / 7-Day History & Swift Charts:** Built-in History tab reading directly from \`airphare-log.csv\` with uptime %, average SNR/latency KPIs, incident counters (DFS drift, 2.4 GHz fallbacks, IPv6 outages, Wi-Fi jitter, ISP issues), and interactive Swift Charts curves.
- **4-Way DNS Comparison:** Benchmarks your active system DNS against \`1.1.1.1\`, \`8.8.8.8\`, and your router — highlighting the fastest server live and logging all 4 into CSV.
- **1-Click Markdown Diagnostic Report:** Copies a clean, formatted Markdown snapshot of your Wi-Fi link, latency, DNS, RF scan, throughput, and 24h summary straight to the clipboard.
- **Right-Click Context Menu:** Right-click the menu bar icon for instant Quick Check, Full Benchmark, Channel Scan, Wi-Fi Reset, Copy Report, Reveal CSV Log, and Router access.
- **Styled Drag-to-Applications DMG:** Custom North Sea background & clean Finder layout, Universal Binary (\`arm64\` + \`x86_64\`), signed with Developer ID & notarized by Apple.

### Installation
1. Download \`$DMG_NAME\` below.
2. Open the DMG and drag **AirPhare.app** into **Applications**.
3. Launch **AirPhare** (Gatekeeper verified: \`source=Notarized Developer ID\`).

### Checksum
\`\`\`
SHA-256 ($DMG_NAME): $SHA256
\`\`\`
EOF
)"
    gh release create "$TAG" "$DMG_PATH" \
        --title "AirPhare $TAG" \
        --notes "$NOTES"
    echo "==> Published: https://github.com/ralksta/airphare/releases/tag/$TAG"
fi
