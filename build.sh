#!/bin/bash
# Builds build/s4bridge (command line) and build/S4 Fader Bridge.app (menu-bar app).
# Requires Xcode Command Line Tools (xcode-select --install).
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build
swiftc -O Sources/Bridge.swift Sources/CLI/main.swift -o build/s4bridge

APP="build/S4 Fader Bridge.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O Sources/Bridge.swift Sources/App/main.swift -o "$APP/Contents/MacOS/S4FaderBridge"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built: build/s4bridge and $APP"
