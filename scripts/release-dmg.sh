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

# Auto-detect Developer ID Application certificate if not provided
if [[ -z "$IDENTITY" ]]; then
    IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application:/ {print $2; exit}')"
fi

if [[ -z "$IDENTITY" ]]; then
    echo "Error: No 'Developer ID Application' certificate found in keychain."
    echo "Create one in Xcode -> Settings -> Accounts -> Manage Certificates -> '+' -> Developer ID Application,"
    echo "or pass --identity \"Developer ID Application: ...\"."
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
STAGING_DIR="$BUILD_DIR/dmg-staging"

echo "==> Creating DMG at $DMG_PATH..."
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"

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

### Highlights
- **Native Wi-Fi Menu Bar Replacement:** Wi-Fi toggle, RF proximity-matched Known Networks, on-demand Other Networks with inline password prompt, and Wi-Fi Settings shortcut.
- **Silent Zero-Load Watchdog:** Tracks band, channel/DFS drift, SNR, Wi-Fi vs. ISP latency, stale IPv6 prefixes / routing loops, and DNS latency.
- **On-Demand Deep Diagnostics:** ETSI-aware channel recommendations and Apple \`networkQuality\` throughput & bufferbloat benchmark.
- **Rich English CSV Logger:** 58 telemetry columns saved locally to \`~/Library/Application Support/AirPhare/airphare-log.csv\`.
- **6 Languages Built In:** English, Deutsch, Italiano, Français, Español, Nederlands (auto-detect + live switcher).

### Installation
1. Download \`$DMG_NAME\` below.
2. Open the DMG and drag **AirPhare.app** into **Applications**.
3. Launch **AirPhare** (signed & notarized with Apple Developer ID).

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
