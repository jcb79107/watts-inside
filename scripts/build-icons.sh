#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
actool="$(xcrun --find actool 2>/dev/null || true)"
if [ -z "$actool" ]; then actool="/Applications/Xcode.app/Contents/Developer/usr/bin/actool"; fi
if [ ! -x "$actool" ]; then
    echo "Full Xcode is required to rebuild icon assets. Normal app builds use the committed assets." >&2
    exit 1
fi
catalog="build/Brand.xcassets"
iconset="$catalog/AppIcon.appiconset"
mkdir -p "$iconset" build/brand-assets
printf '{"images":[' > "$iconset/Contents.json"
separator=""
for size in 16 32 128 256 512; do
    for scale in 1 2; do
        suffix=""
        if [ "$scale" = 2 ]; then suffix="@2x"; fi
        name="icon_${size}x${size}${suffix}.png"
        sips -z "$((size * scale))" "$((size * scale))" Assets/AppIcon.png --out "$iconset/$name" >/dev/null
        printf '%s{"idiom":"mac","size":"%sx%s","scale":"%sx","filename":"%s"}' "$separator" "$size" "$size" "$scale" "$name" >> "$iconset/Contents.json"
        separator=","
    done
done
printf '],"info":{"version":1,"author":"xcode"}}' >> "$iconset/Contents.json"
"$actool" "$catalog" --compile build/brand-assets --platform macosx --minimum-deployment-target 13.0 --app-icon AppIcon --output-partial-info-plist build/brand-assets/icon-info.plist
cp build/brand-assets/AppIcon.icns build/brand-assets/Assets.car Assets/
