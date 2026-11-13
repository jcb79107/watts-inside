# Native menu verification — 1.1.9

On Jason’s Mac, 2026-11-13:

- Apple’s real menu and Watt’s Inside both show **Slow Charger** with the current 15 W adapter. No charging settings were changed.
- Control Center reads `com.apple.PerfPowerServices.slowChargerUpdatedNotification` using `notify_get_state`, and compares its UInt64 state to exactly 1. Verified against the installed arm64e binary: registration at 0x1005b2848, stored notification object at 0x1005b29d0, state read/comparison at 0x1005b1718–0x1005b1740. Live read returned 1.
- The app reads the same state only when opening the menu. Registration is canceled immediately; no timer, background helper, hardware/model wattage table, or extra dependency. Unknown state and failed reads omit the label. Battery power always suppresses it.
- This notification name is private and may change in future macOS versions. Unsupported systems safely retain the normal battery information.
- Information rows now use AppKit NSTextField labels with semantic labelColor. Disabled NSMenuItem titles were dimmed even with attributed colors. Actions remain ordinary native NSMenuItems. Actual window screenshots verify readable heading and status text alongside Apple’s menu.
- The live system-hosted status-item window is **59 pt** wide at 99% charging versus **71 pt** for Apple’s percentage + battery: **12 pt / 16.9% less width**. This includes macOS’s padding, rather than only the image width. The previously approved optical spacing and 11 pt icon height are unchanged.
- Regression checks cover all percentages 0–100 with and without a bolt (requested item length at most 48 pt before system-added spacing), disconnected slow state, absent state, and isolated notification states 0, 1, 2 and UInt64.max. Tests never set Apple’s notification state.

Physical unplug/replug with another adapter and future macOS releases were not tested. No claim is made about another charger from its wattage alone.
