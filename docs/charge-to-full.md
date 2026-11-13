# Charge to Full Now

This asks macOS to temporarily override Optimized Battery Charging or its charge limit. It does not install a helper, invoke sudo, or write to the SMC. Before overriding a charge limit, it saves the exact limit durably. It restores that limit at verified 100% completion, unplugging, or normal app quit; after a crash it retains the saved limit for recovery on reopening. You can also choose Restore [your limit]% Charge Limit from the menu.

Apple does not provide a public API for this action. The app loads the private `PowerUISmartChargeClient` at runtime, checks required methods, validates the returned state, and rechecks permission and power connection before requesting the override. If the interface is absent, unknown, or fails to return valid state, the action is omitted. Rejected requests show an error; the app never claims charging started just because it sent a request. macOS controls charging. Our real-device test found that its restore call could return 80% instead of the saved 95%; the app corrects that mismatch once and verifies the exact limit before deleting its recovery record. Failed restoration retains the record and a retry action. The app must be running to restore automatically; no background helper runs after force-quit.

**Compatibility limitation:** this interface can change in a macOS update. Its live read path was verified on macOS 26.5.2; a real 95% override and exact restoration were verified on an already-full battery. A complete discharge/recharge cycle and Optimized Battery Charging-only override remain untested. This build is not intended for Mac App Store submission because it uses a private API.

The small charging adapter is adapted from MIT-licensed [Lithe](https://github.com/asmeurer/Lithe). See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).

