# Developer ID signing and notarization

Current public downloads are still ad-hoc signed and **not notarized**. Do not describe a release as notarized until Apple accepts it, its ticket is stapled, and Gatekeeper assessment passes.

## One-time account setup

1. Enroll in the Apple Developer Program if needed. The account holder creates a **Developer ID Application** certificate in Xcode → Settings → Accounts → Manage Certificates. An Apple Development certificate is not a substitute.
2. Install the certificate with its private key in the signing Mac’s keychain. Confirm it appears in `security find-identity -v -p codesigning`.
3. Store notarization credentials securely with the interactive command below. Use an Apple ID app-specific password and the developer Team ID, or configure notarytool with an App Store Connect API key. Do not paste secrets into a chat, commit them, or put them in shell scripts.

```sh
xcrun notarytool store-credentials WattsInside-Notary
```

## Release

Run from a clean checkout on the intended build architecture:

```sh
./test.sh
./scripts/notarize.sh "Developer ID Application: Your Name (TEAMID)" WattsInside-Notary
```

The script validates the keychain profile, builds the app, signs with hardened runtime and a secure timestamp, uploads a ZIP to Apple, requires an Accepted result, staples and validates the ticket, runs Gatekeeper assessment, and only then creates `build/notarization/Watts-Inside-notarized.zip`. No sandbox or permissive entitlements are added. It does not install or publish automatically.

If Apple rejects a submission, inspect `build/notarization/result.json`, then retrieve its log:

```sh
xcrun notarytool log SUBMISSION_ID --keychain-profile WattsInside-Notary build/notarization/log.json
```

Before publishing, test the signed app’s battery menu and read-only smart-charging availability; verify its icon, signature, version, architecture, and a quarantined download’s first launch. Signing does not establish compatibility with every macOS version. Update README and release notes only after the signed release is verified. Keep the published icon/banner assets with the release so their download links remain valid.

Notarization removes the unsigned/unverified-developer block; macOS may still show its normal first-download confirmation. It does not replace App Store review or guarantee acceptance of future releases.

References: [Apple’s notarization guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates).
