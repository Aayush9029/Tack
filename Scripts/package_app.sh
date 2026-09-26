#!/usr/bin/env bash
# Build the SwiftPM executable and assemble Tack.app: Info.plist, resources,
# fonts, the Liquid Glass icon compiled by actool, and a signature.
set -euo pipefail

CONF=${1:-release}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

source "$ROOT/version.env"
SIGNING_MODE=${SIGNING_MODE:-}
APP_IDENTITY=${APP_IDENTITY:-}
SIGN_KEYCHAIN=${SIGN_KEYCHAIN:-}

ARCH_LIST=( ${ARCHES:-$(uname -m)} )
for ARCH in "${ARCH_LIST[@]}"; do
  swift build -c "$CONF" --arch "$ARCH"
done

APP="$ROOT/${APP_NAME}.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>${MACOS_MIN_VERSION}</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSUIElement</key><true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key><string>${BUNDLE_ID}</string>
            <key>CFBundleURLSchemes</key><array><string>tack</string></array>
        </dict>
    </array>
    <key>ATSApplicationFontsPath</key><string>Fonts</string>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Aayush Pokharel. MIT License.</string>
    <key>GitCommit</key><string>${GIT_COMMIT}</string>
</dict>
</plist>
PLIST

binaries=()
for ARCH in "${ARCH_LIST[@]}"; do
  binaries+=("$(swift build -c "$CONF" --arch "$ARCH" --show-bin-path)/$APP_NAME")
done
BIN_DIR=$(dirname "${binaries[0]}")
if [[ ${#binaries[@]} -gt 1 ]]; then
  lipo -create "${binaries[@]}" -output "$APP/Contents/MacOS/$APP_NAME"
else
  cp "${binaries[0]}" "$APP/Contents/MacOS/$APP_NAME"
fi
chmod +x "$APP/Contents/MacOS/$APP_NAME"

cp -R "$ROOT/Resources/." "$APP/Contents/Resources/"

# The command line tool ships inside the app; Settings links it onto the PATH.
mkdir -p "$APP/Contents/Helpers"
cli=()
for ARCH in "${ARCH_LIST[@]}"; do
  cli+=("$(swift build -c "$CONF" --arch "$ARCH" --show-bin-path)/TackCLI")
done
if [[ ${#cli[@]} -gt 1 ]]; then lipo -create "${cli[@]}" -output "$APP/Contents/Helpers/tack"; else cp "${cli[0]}" "$APP/Contents/Helpers/tack"; fi

shopt -s nullglob
for bundle in "$BIN_DIR/"*.bundle; do
  cp -R "$bundle" "$APP/Contents/Resources/"
done
shopt -u nullglob

# actool turns the Icon Composer file into Assets.car for macOS 26 and an .icns
# for everything that still reads CFBundleIconFile.
ICON_OUT="$ROOT/.build/icon"
mkdir -p "$ICON_OUT"
xcrun actool "$ROOT/Icon/AppIcon.icon" \
  --compile "$ICON_OUT" \
  --platform macosx \
  --minimum-deployment-target "$MACOS_MIN_VERSION" \
  --app-icon AppIcon \
  --output-partial-info-plist "$ICON_OUT/partial.plist" \
  --output-format human-readable-text --errors --warnings >/dev/null
cp "$ICON_OUT/Assets.car" "$APP/Contents/Resources/"
[[ -f "$ICON_OUT/AppIcon.icns" ]] && cp "$ICON_OUT/AppIcon.icns" "$APP/Contents/Resources/"

chmod -R u+w "$APP"
xattr -cr "$APP"
find "$APP" -name '._*' -delete

ENTITLEMENTS="$ROOT/Scripts/Tack.entitlements"
if [[ "$SIGNING_MODE" == "adhoc" || -z "$APP_IDENTITY" ]]; then
  codesign --force --sign "-" "$APP/Contents/Helpers/tack"
  codesign --force --sign "-" --entitlements "$ENTITLEMENTS" "$APP"
else
  KEYCHAIN_ARGS=()
  [[ -n "$SIGN_KEYCHAIN" ]] && KEYCHAIN_ARGS=(--keychain "$SIGN_KEYCHAIN")
  while IFS= read -r -d '' bundle; do
    codesign --force --timestamp --options runtime "${KEYCHAIN_ARGS[@]}" --sign "$APP_IDENTITY" "$bundle"
  done < <(find "$APP/Contents/Resources" -name '*.bundle' -type d -print0)
  codesign --force --timestamp --options runtime "${KEYCHAIN_ARGS[@]}" --sign "$APP_IDENTITY" "$APP/Contents/Helpers/tack"
  codesign --force --timestamp --options runtime "${KEYCHAIN_ARGS[@]}" \
    --entitlements "$ENTITLEMENTS" --sign "$APP_IDENTITY" "$APP"
fi

echo "Created $APP"
