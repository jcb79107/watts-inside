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

## Ten-minute run of 1.1.4

November 13, 2026, 11:13:38–11:23:44 Central; 606 seconds, 61 samples at nominal 10-second intervals. Same installed process throughout; its menu remained closed, plugged in at 100%. Ordinary desktop activity and separate test processes continued. Raw app-only samples: [idle-1.1.4.csv](idle-1.1.4.csv).

- Accumulated CPU: 0.10 → 0.24 seconds, **0.14 seconds used**, approximately **0.023% of one core** over the interval.
- Highest reported CPU interval: **0.3%**.
- Memory: **12–13 MB** at top's rounded precision, starting and ending at **12 MB**. No sustained upward trend observed.
- Cumulative idle wakeups: 4 → 15, **11 additional wakeups** in 606 seconds.
- After measurement, Apple's live leaks tool reported **12.3 MB physical footprint**, **12.7 MB peak**.

### Leak investigation

The installed app's live scan flagged **277 allocations / 14,000 bytes** under three NSXPCConnection root cycles. A repeat scan after the follow-up investigation reported exactly the same count, bytes, and footprint. Do not describe this as zero leaks.

A minimal accessory AppKit status app with no battery code reproduced three NSXPCConnection root cycles totaling 14,096 bytes. This supports a framework-initialization explanation for this fixed small finding; it is not proof every flagged allocation is harmless.

Separate read-only checks with Apple's `leaks --noContent --atExit` reported zero leaks for one public Battery.read call, 1,000 public Battery.read calls, and a SmartCharge state read. A renderer stress process rendered and decoded 10,000 icons across 0–100 and both charging states. It reported one 32-byte ImageIO initialization allocation (`IIOGetCodesigningIdentifier`); the one-render control reported the same 32 bytes. Its final footprint was 8,449 KB, peak 8,545 KB. The image decoder is part of that test harness, not the app's icon-refresh path.

Conclusion: no growing idle or per-render leak observed in these checks. The native renderer remains tiny; no workaround added for fixed framework allocations. This is not a multi-day soak, a full charging-cycle test, or a battery-runtime measurement.
