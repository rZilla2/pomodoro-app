---
phase: 01-foundation
plan: 02
subsystem: ui
tags: [swiftui, nspopover, nsstatusitem, combine, smappservice, menu-bar]

requires:
  - phase: 01-foundation/01
    provides: "TimerEngine state machine with start/pause/stop, @Published timeRemaining, work/break auto-transition"
provides:
  - "Live countdown in macOS menu bar updated every second via Combine sink"
  - "NSPopover with SwiftUI MenuBarView for start/pause/stop controls"
  - "Configurable work/break durations via steppers in popover"
  - "Launch-at-login via SMAppService auto-registration"
affects: [02-floating-panel, 03-audio-polish]

tech-stack:
  added: [NSPopover, NSStatusItem, SMAppService, Combine]
  patterns: [Combine sink for real-time UI updates, NSHostingView bridging SwiftUI into AppKit popover]

key-files:
  created:
    - PomodoroApp/UI/MenuBarView.swift
  modified:
    - PomodoroApp/AppDelegate.swift

key-decisions:
  - "NSPopover over NSMenu for menu bar dropdown -- better SwiftUI integration"
  - "Monospaced digit font (.monospacedDigit()) for countdown to prevent jitter"

patterns-established:
  - "Combine sink pattern: subscribe to @Published properties on TimerEngine, update NSStatusItem title on each tick"
  - "NSPopover + NSHostingView pattern for embedding SwiftUI views in menu bar dropdowns"

requirements-completed: [TIMR-01, UIFP-02]

duration: ~15min
completed: 2026-03-13
---

# Phase 1 Plan 2: Menu Bar UI Summary

**Live countdown wired to menu bar via Combine sink, NSPopover with start/pause/stop controls, configurable durations, and SMAppService launch-at-login**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-13T19:51:00Z
- **Completed:** 2026-03-13T20:10:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Menu bar shows live MM:SS countdown that ticks every second while timer runs
- Popover with start/pause/stop buttons and work/break duration steppers
- Monospaced digit font prevents jittery countdown display
- SMAppService.mainAppService.register() called on launch for login item
- Timer auto-transitions work to break at 00:00

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire live countdown to menu bar and add controls** - `06fe285` (feat)
   - Additional fix: `7bb6266` (fix) - monospaced digit font for countdown
2. **Task 2: Verify live countdown and controls** - checkpoint:human-verify (approved)

## Files Created/Modified
- `PomodoroApp/AppDelegate.swift` - Combine sinks on TimerEngine, NSPopover setup, SMAppService registration, statusItem title updates
- `PomodoroApp/UI/MenuBarView.swift` - SwiftUI view with timer display, start/pause/stop controls, duration steppers

## Decisions Made
- Used NSPopover over NSMenu for the menu bar dropdown -- better SwiftUI integration via NSHostingView
- Applied .monospacedDigit() font to menu bar countdown to prevent width jitter as digits change

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Monospaced digit font for countdown**
- **Found during:** Task 2 (human verification)
- **Issue:** Countdown digits caused menu bar item to jitter/shift as digit widths changed (e.g., "1" narrower than "0")
- **Fix:** Applied .monospacedDigit() font modifier to the statusItem button title
- **Files modified:** PomodoroApp/AppDelegate.swift
- **Verification:** Visual check confirmed stable width during countdown
- **Committed in:** 7bb6266

---

**Total deviations:** 1 auto-fixed (1 bug fix)
**Impact on plan:** Minor polish fix, no scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 1 complete: TimerEngine + menu bar UI fully functional
- Ready for Phase 2 (Floating Panel) -- TimerEngine is shared @ObservedObject, panel will reuse it
- Blocker: Audio files needed before Phase 3 (unchanged from prior)

## Self-Check: PASSED

- FOUND: PomodoroApp/UI/MenuBarView.swift
- FOUND: PomodoroApp/AppDelegate.swift
- FOUND: commit 06fe285
- FOUND: commit 7bb6266

---
*Phase: 01-foundation*
*Completed: 2026-03-13*
