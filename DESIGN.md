# One change: the icon

Watt’s Inside should replace the battery glyph, not redesign battery management.

## Interaction contract

- Left click: Apple's actual battery menu, including the controls and information macOS chooses to show on this machine.
- Right click: app maintenance only (Quit). No app branding in the ordinary battery experience.
- Keyboard and VoiceOver: the same primary action as left click; an accessible current percentage and power-state description.
- No extra dashboards, onboarding tours, animations, charging controls, or estimated battery-health advice.

## State decisions

| State | Replacement icon | Clicked experience |
| --- | --- | --- |
| Discharging | Percentage inside battery | Apple's battery menu |
| Charging | Percentage with charging bolt | Apple's charge status and estimate, when available |
| Connected, not charging | Percentage with plug marker | Apple's explanation; never infer the cause |
| Optimized charging hold | Connected icon | Apple's hold explanation and Charge to Full Now |
| Charge limit reached | Connected icon | Apple's limit text and Charge to Full Now |
| Fully charged | Connected icon | Apple's charged state |
| Low Power Mode | Percentage remains legible; native semantic treatment to be verified against the system | Apple's energy-mode controls |
| Low battery | Native warning treatment to be verified against the system | Apple's battery status |
| Service recommended | Preserve readable percentage | Apple's diagnostic wording, without inventing a diagnosis |
| Missing/unreadable battery | Question mark; accessible unavailable label | A clear unavailable state; never retain a stale percentage |

Keep the shape steady where possible, use the system typeface, preserve contrast in light/dark and selected states, and never use color alone to communicate status. Display a charging bolt only while charging. Do not call a rounded 100% reading fully charged without the system's charged flag.

## Feasibility gate — not implemented

The current app still uses its own minimal NSMenu. AppKit exposes menus for an app's own status items; no supported API for borrowing Control Center's battery menu has been identified.

Investigate an Accessibility handoff on the actual target Mac before implementation. Verify whether the native battery control remains reachable with Apple's menu-bar icon hidden, whether its menu opens at an acceptable location, and whether keyboard dismissal and VoiceOver work. Do not ship a solution that requires duplicate visible battery icons, guessed screen coordinates, or silently changes system preferences. Any Accessibility permission must be explained and granted by the user; never enable it automatically.

If that handoff cannot satisfy these conditions, report the incompatibility rather than claiming a cloned menu provides the same experience. Charging controls and significant-energy information cannot be replaced with invented rows or inert buttons.

## Validation required

Inspect the native menu and accessibility tree while unlocked; test hidden/visible native battery, click/keyboard/VoiceOver, dismissal, appearance, charger transitions, charging holds, charge limits, and wake. The Mac was subsequently unlocked and the native popup was inspected; the handoff behavior remains unverified.

## Inspection result — November 13, 2026

The open popup belongs to `com.apple.controlcenter`, window `Control Center`. Its accessible content was:

- `battery-header`: Battery; Power Source: Power Adapter; Fully Charged; No Apps Using Significant Energy.
- Battery Settings… button.

The inspection tool then reported `noWindowsAvailable`, followed by a timeout when reading Control Center again. The available snapshot contained the popup contents, not a persistent battery menu-bar action. This establishes that the open menu can be read, not that our app can invoke it. No hidden-icon test succeeded or was performed, and no system settings or permissions were changed.

AppKit's documented `NSStatusItem.menu` accepts an app-owned NSMenu. No public borrowing API was identified. Accessibility actions are a separate possible automation route, not an embeddable native menu; their availability with the native icon hidden, positioning, and permission behavior still require a successful prototype. Do not infer that route is impossible merely from the inspection tool's timeout.

References:
- https://developer.apple.com/documentation/appkit/nsstatusitem/menu
- https://developer.apple.com/documentation/applicationservices/axuielement_h

Decision: do not add an unverified native-menu bridge to the released app. Exact native-menu replacement is not currently demonstrated.

## Prototype supersedes earlier feasibility notes

A successful hidden-icon route was tested using the Battery tile in Control Center. See [Prototypes/README.md](Prototypes/README.md) for the procedure, observed results, restored settings, and integration limits. The earlier inability to inspect the menu was a tool/sandbox limitation, not proof that the handoff could not work. Production integration remains separate from this successful probe.
