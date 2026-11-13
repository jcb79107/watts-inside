# Real charging-override regression test

macOS 26.5.2, Apple silicon, November 13, 2026.

Original settings: charge limit 100%, Optimized Battery Charging on. Battery already full. Temporarily set 95% through System Settings.

## Bugs reproduced in 1.1.0

The actual menu command successfully invoked the private charging service. It changed `isMCLCurrentlyEnabled` to raw 3 and the reported active limit to 100. The app treated raw 3 as unsupported and lost the override state.

Calling macOS `enableMCL:` returned success but restored **80**, not the recorded **95**. Calling `setMCLLimit:95 error:` after ending the override restored exactly 95. Do not call `enableMCL:` again after that corrective write.

## Fixed real-device result

Activated the fixed app's Charge to Full Now menu item with the 95% test limit. Separately ran the exact production SmartCharge and Battery implementations with assertions around every state transition:

| Step | Active limit | Override active | Saved recovery limit |
| --- | --- | --- | --- |
| Before | 95 | false | none |
| Request accepted | 100 | true | 95 |
| Automatic completion handling | 95 | false | none |

Result: PASS. The battery was already 100% and reported charged/not charging, so this validates the real override/completion/restoration path, not delivery of additional battery charge. System Settings independently confirmed the restored 95% limit.

After testing, restored the original 100% setting through System Settings and verified Optimized Battery Charging remained on.

## Regression coverage

- Recognize raw 3 as override; reject unknown raw values.
- Persist original limit before sending a mutation; fail closed if persistence fails.
- Recover saved limit with a newly created service instance.
- Restore 95 even when enableMCL returns 80.
- Keep recovery record on failed restore or corrective write; retry succeeds.
- Do not stop at a below-100 charged flag or while still charging at displayed 100.
- Restore when disconnected, fully charged at 100, or normally quitting.

## Remaining limits

No physical discharge/recharge cycle, unplug/replug, crash/relaunch hardware cycle, or OBC-only hold was performed. Those branches have fake-client tests where applicable. Private API behavior on other macOS versions is not established. A force-quit leaves no background worker; reopen the app to recover its saved limit.
