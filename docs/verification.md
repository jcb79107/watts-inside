# Verification

`test.sh` checks battery parsing, boundary readings, full/finishing/held/limited states, disconnected override rejection, private-interface absence, unknown states, action rejection, and routing to the correct temporary override with a fake client. It also renders discharging and charging icons at 0, 9, 85, 100, and unknown percent.

Verified on Apple silicon/macOS 26.5.2: release build/signature, live battery and smart-charge reads, the running native menu's contents, and Battery Settings navigation. The real command was exercised with a temporary 95% limit; the production backend was verified transitioning to override and back to exactly 95%. A test-only SIGKILL immediately after the real menu action also verified that reopening the unchanged release restored exactly 95%. Original test-machine settings were restored afterward. Regression tests include the observed 80% restore mismatch, durable recovery across service recreation, failure/retry, unplugging, and completion (not merely a rounded 100%). Intel, older macOS, full charge cycles, sleep/wake, and physical VoiceOver/right-click testing remain unverified.

The final audit and its fixed findings are recorded in [docs/ponytail-audit.md](ponytail-audit.md).

