# Native battery menu probe

Tested on macOS 26.5.2, November 13, 2026. This is an investigation tool, not shipping app code.

## Result

**The real Apple battery panel can be opened with the menu-bar battery icon hidden, through the Battery tile in Control Center.**

1. With the native icon visible, `com.apple.menuextra.battery` exposes AXPress. The action returned success (0).
2. Disabled Battery in System Settings → Menu Bar. The battery AXMenuBarItem disappeared, and the direct probe returned `BATTERY_ACTION_FOUND=false`.
3. Opened Control Center using AXPress on `com.apple.menuextra.controlcenter`. Battery was not in this machine's existing layout.
4. Temporarily added Battery to Control Center through Edit Controls → Battery → Add to Control Center.
5. Pressed `controlcenter-battery` while the menu-bar battery icon remained disabled. Control Center exposed the real battery panel: `battery-header`, Battery Settings…, and its native status rows. No replacement menu was rendered by the probe.
6. Restored the original settings: native battery icon enabled, temporary Battery tile removed.

## Product implications

- A working route exists: open Control Center, then press its Battery tile.
- This uses Apple's panel and its available controls, rather than copying them.
- The panel belongs to Control Center. It is not embedded in or anchored to our status item; opening Control Center is an intermediate visible step.
- The app would require Accessibility authorization and Battery configured in Control Center. The probe ran with the host's existing Accessibility trust; no permission was granted automatically. A standalone app's authorization must be tested separately.
- Production integration needs bounded retries for panel appearance, exact identifier matching, missing-tile and denied-permission handling, and a right-click Quit action.
- Charging holds, limit controls, VoiceOver, multiple displays, and other macOS versions were not tested. The currently available native panel was tested, not every possible charge state.

## Reproduce

```sh
xcrun swiftc Prototypes/BatteryMenuProbe.swift -o /tmp/BatteryMenuProbe
/tmp/BatteryMenuProbe
/tmp/BatteryMenuProbe --press-control-center
# After Control Center is visible:
/tmp/BatteryMenuProbe --press-battery
```

The host running the probe must already be authorized for Accessibility. Do not interpret an untrusted or sandbox-restricted scan as absence of the system control. The extra editing flags are investigation utilities and should only be used while the corresponding control picker/context menu is open. The probe logs system UI labels; do not commit raw logs.

## Related implementations

- Better Battery 2's App Store listing advertises its own battery information, stats, and configurable symbols; it does not establish reuse of Apple's menu: https://apps.apple.com/us/app/better-battery-2-stats-info/id1455789676
- Citrus Battery explicitly describes a menu styled like Control Center, rather than borrowing the panel: https://github.com/citrus-apps/citrus-battery

No third-party code was copied.
