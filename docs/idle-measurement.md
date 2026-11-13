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

## Twenty-minute run of 1.1.10

November 13, 2026, 14:37:59–14:58:13 Central; **1,214 seconds**, 121 samples at nominal ten-second intervals. Installed `/Applications/Watt’s Inside.app`, version 1.1.10, same PID 83738 throughout. The menu had been exercised before this test and remained untouched during the measurement. AC power, 99% finishing charge at the start and end. Ordinary desktop activity was not controlled. Raw app-only samples: [idle-1.1.10.csv](idle-1.1.10.csv).

| Metric | 1.1.10, 20 minutes | Earlier 1.1.4, 10 minutes |
| --- | --- | --- |
| CPU time used | 0.87 seconds | 0.14 seconds |
| Average CPU, one core | 0.0717% | 0.023% |
| Highest sampled CPU interval | 1.0% | 0.3% |
| Rounded memory range | 16–18 MB | 12–13 MB |
| Rounded memory start → end | 16 → 18 MB | 12 → 12 MB |
| Additional idle wakeups | 53 | 11 |

113 of 121 memory samples were 17 MB, seven were 18 MB, and the initial sample was 16 MB. The first three approximately five-minute blocks each predominantly measured 17 MB; the final block contained 25 samples at 17 MB and six at 18 MB. Memory did not continuously climb, but the ending value was higher than the start. This is evidence of low, mostly stable idle use over this interval, not proof of zero leakage or unchanged memory use versus earlier versions.

After the timed capture, Apple's leak scanner reported a **17.5 MB physical footprint**, **17.9 MB peak**, and **192 allocations / 9,600 bytes** in two NSXPCConnection root cycles. These are the same category of framework-cycle findings reproduced in the earlier minimal AppKit control, but this run does not independently establish their cause. The leak scan was outside the timed idle interval.

The latest build measured higher CPU and memory than 1.1.4, though both remain small in absolute terms. Different power state (finishing charge versus fully charged), prior menu use, and uncontrolled desktop activity mean this is not a controlled version-to-version regression benchmark. No code was changed based on this run. No watts, battery-discharge runtime, multi-day soak, or repeated menu-opening leak test was measured.

A second post-run leak scan of the same process reported the identical **192 allocations / 9,600 bytes** and a slightly lower **17.4 MB** footprint (peak still 17.9 MB). This short repeat found no increase in the flagged allocations; it is not a long-duration leak proof.
