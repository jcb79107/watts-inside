#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -ne 2 ] || [[ "$1" != "Developer ID Application: "* ]]; then
    echo 'Usage: ./scripts/notarize.sh "Developer ID Application: Name (TEAMID)" KEYCHAIN_PROFILE' >&2
    exit 2
fi
identity="$1"
profile="$2"
# Validate credentials before building or uploading anything.
xcrun notarytool history --keychain-profile "$profile" >/dev/null
./build.sh
app="build/Watt’s Inside.app"
mkdir -p build/notarization
codesign --force --sign "$identity" --options runtime --timestamp "$app"
codesign --verify --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" build/notarization/submission.zip
xcrun notarytool submit build/notarization/submission.zip --keychain-profile "$profile" --wait --output-format json > build/notarization/result.json
status="$(plutil -extract status raw -o - build/notarization/result.json)"
if [ "$status" != Accepted ]; then
    echo 'Notarization was not accepted. Inspect build/notarization/result.json and retrieve the submission log.' >&2
    exit 1
fi
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --strict "$app"
spctl --assess --type execute --verbose=2 "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" build/notarization/Watts-Inside-notarized.zip
echo 'Verified release: build/notarization/Watts-Inside-notarized.zip'
