# Idle usage and Ice check — November 13, 2026

Installed Apple silicon app on macOS 26.5.2, connected to power at 100%. Measured the app process with `top -l 7 -s 5 -pid PID -stats pid,command,cpu,time,mem,threads,idlew,power`. Each observation covered roughly 30 seconds. Memory is top's MEM value; these are short observations, not a battery-runtime or watts benchmark.

| Build/session | Reported CPU samples | CPU time change | Memory | Idle wakeup count change |
| --- | --- | --- | --- | --- |
| 1.1.2, existing process | Six 0.0%, one 0.9% | 0.79 → 0.84 seconds | 19 MB | 125 → 126 |
| 1.1.3, after startup settled | All seven 0.0% | 0.21 → 0.21 seconds | 13 MB | 6 → 6 |

The first interval averaged approximately 0.16% of one CPU core based on accumulated CPU time. The second had no CPU-time increase at top's displayed precision. Memory differences between fresh and older processes do not establish an optimization or leak. No claim of zero energy use; no battery-discharge endurance test performed.

## Ice and icon

Ice 0.11.13-dev.2 omitted the old item and retained stale layout snapshots. Its public source filters empty window titles in active-space enumeration: [MenuBarItem.swift](https://github.com/jordanbaird/Ice/blob/main/Ice/MenuBar/MenuBarItems/MenuBarItem.swift).

Added a stable AppKit autosave name, image-only button title, and window title after rendering. Reopened Ice to refresh its cached inventory. The real layout then showed Watt’s Inside in Hidden; dragged it into Visible successfully. Added identity does not introduce a helper or polling. Apple’s Battery checkbox was found enabled and turned off again.

Reduced icon body height from 16 to 14 points, font from 12 heavy to 11 bold, and removed the cramped plug marker. A bolt appears only while charging. System template rendering and the accessible battery label remain intact.
