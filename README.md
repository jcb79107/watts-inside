# Watt’s Inside

Your battery percentage. Inside the battery.

A tiny native macOS menu-bar app. Swift, AppKit, and IOKit. No package dependencies, network requests, analytics, polling timers, Dock icon, Accessibility permission, or privileged helper.

## Everyday use

Click the battery icon for a native menu directly beneath it:

- Battery percentage and power source.
- Charging, Finishing Charge, Fully Charged, Not Charging, or Low Battery.
- Charging On Hold or Charged to a Limit when macOS reports the relevant smart-charging state.
- Time until full when the system supplies an estimate.
- Battery-health notice when the system reports reduced capacity or poor health.
- Low Power Mode status; select it to change energy mode in Battery Settings.
- Charge to Full Now when macOS reports a hold/limit and permits the override.
- Battery Settings…

Right-click (or Control-click) the icon to quit. VoiceOver receives the battery percentage and current basic power state. Unknown battery data shows `?`, never a stale or invented percentage.

The icon shows a bolt while charging and a plug when connected but not charging. Its solid silhouette is not a fill gauge; the number is the charge level. It widens for three-digit percentages and power markers. Native template rendering adapts to menu-bar appearance.

## Charge to Full Now

This asks macOS to temporarily override Optimized Battery Charging or its charge limit. It does not install a helper, invoke sudo, write to the SMC, or rewrite the permanent charge-limit preference.

Apple does not provide a public API for this action. The app loads the private `PowerUISmartChargeClient` at runtime, checks required methods, validates the returned state, and rechecks permission and power connection before requesting the override. If the interface is absent, unknown, or fails to return valid state, the action is omitted. Rejected requests show an error; the app never claims charging started just because it sent a request. The system remains responsible for charging and restoring its normal policy.

**Compatibility limitation:** this interface can change in a macOS update. Its live read path was verified on macOS 26.5.2; actual hold-to-charge transitions still require hardware validation. This build is not intended for Mac App Store submission because it uses a private API.

The small charging adapter is adapted from MIT-licensed [Lithe](https://github.com/asmeurer/Lithe). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Build and run

Requires macOS 13 or newer and Xcode Command Line Tools with Swift 6 or newer. Builds for the current Mac's architecture.

```sh
./test.sh
./build.sh
open "build/Watt’s Inside.app"
```

Drag the app to Applications to keep it. To start it at login, add it in System Settings → General → Login Items. Hide Apple's battery icon in System Settings → Menu Bar (Control Center on older macOS). Command-drag our icon to reposition it.

The app does not automatically change system preferences. Delete the app to uninstall. Builds are locally ad-hoc signed, not Developer ID signed or notarized; downloaded binaries may trigger Gatekeeper. Source builds are the supported installation path. Do not disable Gatekeeper globally.

## Deliberately small

Uses system battery-change and wake notifications. Smart-charging state is queried when opening the menu or requesting a charging override. No permanent background polling, settings window, updater, charts, or data storage.

The menu is ours, not a transplanted Control Center panel. It does not claim Apple's per-app significant-energy list: CPU usage is not equivalent to energy usage. Low Power Mode changes remain in System Settings instead of requiring administrator access. The Accessibility experiment in `Prototypes/` is not compiled into the app.

## Verification

`test.sh` checks battery parsing, boundary readings, full/finishing/held/limited states, disconnected override rejection, private-interface absence, unknown states, action rejection, and routing to the correct temporary override with a fake client. It also renders discharging, charging, and connected icons at 0, 9, 85, 100, and unknown percent.

Verified on Apple silicon/macOS 26.5.2: release build/signature, live battery and smart-charge reads, the running native menu's contents, and Battery Settings navigation. No real charging override was issued during automated tests. Intel, older macOS, full charge cycles, sleep/wake, and physical VoiceOver/right-click testing remain unverified.

## License

MIT. Contributions that keep the app small are welcome.
