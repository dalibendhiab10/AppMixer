#!/bin/zsh
set -e
cd "$(dirname "$0")"
swift build -c release
APP=AppMixer.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/AppMixer "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
mkdir -p "$APP/Contents/Resources"
[ -f Resources/MenuBarIcon.png ] && cp Resources/MenuBarIcon.png "$APP/Contents/Resources/"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Built $APP — run: open $APP"
