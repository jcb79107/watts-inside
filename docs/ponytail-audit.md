What this repo does: Watt’s Inside displays battery percentage inside a native menu-bar icon and provides a small native battery menu. It optionally asks macOS for a temporary full-charge override and saves the original limit for verified restoration. Assumed load: one user, one menu-bar process, system battery notifications.

## Must fix — fixed in 1.1.2

1. **Restoration stalled after macOS ended an override** (`Sources/SmartCharge.swift`, `restoreIfFinished`).
   - What this is: Recovery restores the saved charge limit at completion or disconnect.
   - Problem: An inactive override with a mismatched limit, such as 80 instead of saved 95, skipped restoration forever unless the user selected Restore or quit.
   - Fix: Completion/disconnect checks no longer require the override still to be active. A regression test reproduces the mismatch.
   - If skipped: The user can remain on the wrong charge limit after automatic system restoration.

2. **Recovery failures could be hidden or lose their record** (`Sources/SmartCharge.swift`, `chargeToFullNow` and `restoreIfFinished`).
   - What this is: Failed system calls must preserve the original limit and report failure.
   - Problem: An unreadable state silently returned success to the menu, and a rejected override discarded its record even if the reported limit had changed. A pending retry also unnecessarily required battery telemetry.
   - Fix: Failed state queries throw when recovery is outstanding. Clear rejected-request records only after verifying the unchanged original limit. Retry an already-started restoration without requiring battery telemetry. Tests cover all three cases.
   - If skipped: Recovery can be hidden, delayed, or become impossible after a partial mutation.

3. **Binary downloads lacked license notices** (`build.sh`).
   - What this is: The app includes an MIT-licensed charging adapter.
   - Problem: Notices existed in the source repo but were absent from the distributed app.
   - Fix: Copy both project license and third-party notices into bundle Resources before signing. Compare bundled files against originals during release checks.
   - If skipped: Binary recipients would not receive the required attribution.

## Should fix — fixed in 1.1.2

4. **Below-full charge could be announced as Fully Charged** (`Sources/Battery.swift`, `status`).
   - What this is: The tooltip and accessibility label use the basic battery status.
   - Problem: macOS can report its charged flag at a configured limit below 100.
   - Fix: Require displayed 100 as well as the charged flag for Fully Charged. Preserve explicit limit/hold details in the menu; add a regression test.
   - If skipped: The icon’s spoken label and tooltip could contradict the charge-limit menu.

## Verification and scope

Read every production Swift file, tests, build/test scripts, README, design notes, charging test record, prototype source/documentation, ignore rules, and license notices. No external dependencies or network code. Production has no Accessibility use, shell execution, privileged helper, or polling timer. Scratch probes and research clones outside the repository are not shipped.

Passed regression suite, optimized build, strict bundle signature validation, license-content comparisons, icon rendering checks (0, 9, 85, 100, unknown; charging and connected), and native menu inspection on Apple silicon/macOS 26.5.2. Earlier real-device override/restoration and SIGKILL/reopen results are documented separately; new edge cases use a fake private client and do not alter hardware policy. Live readback remains 100 with no active override or saved recovery record.

Installation and login startup use normal macOS controls, documented in README. No custom installer, updater, settings window, or login helper added. Quit/restore before deleting the app so an outstanding recovery record is not abandoned.

Verdict: All concrete audit findings fixed. Suitable for local daily use with the documented private-API and platform-validation limits; not a signed/notarized public-distribution guarantee.

Not checked: physical full-charge or unplug cycles, sleep/wake, login/reboot startup, OBC-only hold, physical VoiceOver/right-click use, Intel, older macOS, multiple displays, or long-duration energy measurements. Private PowerUI calls are synchronous and can change with macOS updates. A force-quit needs reopening for recovery; finish or restore an app-owned override before changing the limit elsewhere.
