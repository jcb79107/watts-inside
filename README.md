# Watt’s Inside

Your battery percentage. Inside the battery.

A tiny native macOS menu-bar app inspired by the iPhone battery indicator. Written in Swift with AppKit and IOKit. No dependencies, network requests, analytics, polling timers, or Dock icon.

- Bold percentage cut into a solid battery, with a bolt while charging.
- Native template image follows menu-bar appearance and selection.
- Updates on system power-source notifications and wake.
- VoiceOver label and a menu with battery status, Battery Settings, and Quit.
- Unknown battery data displays `?`, never a made-up percentage.

The solid silhouette intentionally does not represent charge level; the number does. The icon widens to keep `100` and the charging bolt legible. A connected adapter does not necessarily mean the battery is charging (for example, when macOS pauses charging).

## Build and run

Requires macOS 13 or newer and Xcode Command Line Tools with Swift 6 or newer. Builds for the Mac running the command (Apple silicon or Intel).

```sh
./test.sh
./build.sh
open "build/Watt’s Inside.app"
```

Drag the app to Applications if you want to keep it. To start it at login, add it in System Settings → General → Login Items. Hide Apple's battery indicator in System Settings → Menu Bar (or Control Center on older macOS). This app does not change system preferences automatically. Command-drag the menu-bar icon to reposition it.

The build is locally ad-hoc signed, not Developer ID signed or notarized. Source builds are the supported installation path; downloaded binaries may trigger Gatekeeper. Do not disable Gatekeeper globally.

## Small by design

Two Swift source files. One native status item and one IOKit run-loop source. No preferences database, launch agent, updater, helper process, or package manager. Quit from its menu; uninstall by deleting the app. It reads only the internal Mac battery, not accessories or UPS devices. On a desktop Mac it shows battery unavailable.

`test.sh` checks parsing, boundary values, adapter/charging distinctions, and rendering, and writes `build/preview.png`. Hardware verification was performed on an Apple silicon Mac running macOS 26.5.2; Intel, older macOS, full charge cycles, and sleep/wake transitions still need hardware testing.

## License

MIT. Contributions that keep the app small are welcome.
