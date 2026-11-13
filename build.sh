#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app="build/Watt’s Inside.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp LICENSE THIRD_PARTY_NOTICES.md "$app/Contents/Resources/"
xcrun swiftc -swift-version 6 -O -target "$(uname -m)-apple-macosx13.0" Sources/*.swift -o "$app/Contents/MacOS/WattsInside"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>WattsInside</string>
<key>CFBundleIdentifier</key><string>io.github.jcb79107.watts-inside</string>
<key>CFBundleName</key><string>Watt’s Inside</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1.7</string>
<key>CFBundleVersion</key><string>9</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>LSMultipleInstancesProhibited</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
echo "Built $app"
