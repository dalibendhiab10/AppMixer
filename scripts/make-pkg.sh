#!/bin/zsh
# Build AppMixer.app and wrap it in an installer package.
#   usage: scripts/make-pkg.sh <version>
# Env (all optional):
#   UNIVERSAL=0            build for the host architecture only (default: arm64 + x86_64)
#   CODESIGN_IDENTITY      "Developer ID Application: ..." (default: ad-hoc "-")
#   INSTALLER_IDENTITY     "Developer ID Installer: ..." (default: unsigned pkg)
set -euo pipefail

VERSION="${1:?usage: make-pkg.sh <version>}"
cd "$(dirname "$0")/.."

ARCH_FLAGS=()
if [[ "${UNIVERSAL:-1}" == "1" ]]; then ARCH_FLAGS=(--arch arm64 --arch x86_64); fi

swift build -c release "${ARCH_FLAGS[@]}"
BIN_DIR="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"

OUT=build
rm -rf "$OUT"
STAGE="$OUT/root/Applications"
APP="$STAGE/AppMixer.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/AppMixer" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
[ -f Resources/MenuBarIcon.png ] && cp Resources/MenuBarIcon.png "$APP/Contents/Resources/"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"

IDENTITY="${CODESIGN_IDENTITY:--}"
if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi

cat > "$OUT/components.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><array><dict>
  <key>RootRelativeBundlePath</key><string>Applications/AppMixer.app</string>
  <key>BundleIsRelocatable</key><false/>
  <key>BundleIsVersionChecked</key><false/>
  <key>BundleOverwriteAction</key><string>upgrade</string>
</dict></array></plist>
PLIST

PKG="$OUT/AppMixer-$VERSION.pkg"
pkgbuild --root "$OUT/root" --component-plist "$OUT/components.plist" \
  --identifier com.bendhiab.AppMixer.pkg --version "$VERSION" --install-location / \
  ${INSTALLER_IDENTITY:+--sign "$INSTALLER_IDENTITY"} "$PKG"

echo "Built $PKG"
