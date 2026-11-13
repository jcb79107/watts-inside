# A battery icon, with a familiar native menu

The primary interaction is a native NSMenu anchored to our status item. Right-click or Control-click exposes Quit. No onboarding, preferences window, Accessibility prompt, charts, or helper process.

## What people need

1. Check charge without clicking: number inside the battery; bolt for charging; connected/held details in the menu.
2. Understand why charging stopped: distinguish explicit macOS hold/limit state from generic Not Charging. Never infer optimized charging from the percentage alone.
3. Leave with a full battery: offer Charge to Full Now only when the system reports that the action is meaningful and allowed. Revalidate at activation, let macOS own the temporary override, show failures.
4. Extend battery life: show Low Power Mode state and take the user to the actual system control. Do not add a password prompt or administrator helper for a toggle.
5. Diagnose a problem: report the system's basic health category and provide Battery Settings. Do not fabricate a significant-energy app list from CPU usage.

## State precedence

Charging/Finishing Charge comes before full-charge detection. Fully Charged requires the system flag, external power, and displayed 100; the flag alone can also be set at a lower charge limit. Explicit optimized charging engagement overrides generic Not Charging. A reported charge limit is described as reached only when charge is within two percentage points of that limit and charging has stopped. Missing data is unavailable, never assumed full or empty.

## Charging API decision

A guarded, runtime-loaded private PowerUI client supports the temporary action without Accessibility. This is a pragmatic direct-download compatibility tradeoff, documented in the README. Unknown raw states, failed queries, missing methods, absent power, and denied overrides never enable the command. The exact original limit is saved before a temporary override. On completion, disconnect, normal quit, or explicit Restore, the app ends the override and verifies the limit; if macOS restored a different limit, one corrective write restores the saved value. A durable recovery record survives failure or force-quit. No SMC manipulation.

## Rejected native-menu handoff

The Accessibility prototype proved that hiding the native battery icon removes its direct action, but the Battery tile in Control Center can still open Apple's real panel. That intermediate panel opens in Control Center's location and requires Accessibility plus tile setup. The user chose a native menu under our own icon instead. The probe is retained for reproducibility, not shipped or used by the app.

## Visual reference

The supplied Apple website analysis reinforces system typography, restrained hierarchy, and minimal decoration. Website-specific display sizes, blue pill buttons, and marketing-page spacing do not apply to this native utility. NSMenu supplies system spacing, selection, colors, and appearance; only the battery glyph and heading weight are custom.

## Reference-led icon refinement (1.1.4)

The supplied Better Battery 2 reference sets the proportions: a soft solid battery body, rounded terminal, generous rounded numerals, and an internal charging bolt. Use the rounded system font at 13 points/heavy within a 16-point-tall body, with native template coloring. The number stays visible while charging. No extra state glyph for merely being connected. Layout expands only enough for the digits and bolt.

### Menu-bar scale correction (1.1.5)

The enlarged reference proportions were too prominent beside real menu-bar controls. Reduce the body from 16 to 13 points high, rounded digits from 13 to 11 points, and horizontal padding from 8 to 6 points. Reduce the terminal and charging bolt proportionally. Keep AppKit's standard status-item hit target and external spacing.
