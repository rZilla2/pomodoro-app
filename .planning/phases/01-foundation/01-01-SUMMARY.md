---
phase: 01-foundation
plan: 01
subsystem: engine
tags: [swift, swiftui, appkit, timer, macos, menubar, spm]

# Dependency graph
requires: []
provides:
  - TimerEngine state machine with clock-based elapsed time
  - Xcode project scaffold with SPM build support
  - AppDelegate with NSStatusItem stored property
  - Info.plist with LSUIElement=YES and sandbox entitlements
affects: [01-02, 02-floating-panel, 03-audio-polish]

# Tech tracking
tech-stack:
  added: [swift-6.0, swiftui, appkit, swift-testing]
  patterns: [clock-based-elapsed-time, main-actor-isolation, nsstatus-item-retention, agent-mode-app]

key-files:
  created:
    - PomodoroApp/PomodoroApp.swift
    - PomodoroApp/AppDelegate.swift
    - PomodoroApp/Engine/TimerEngine.swift
    - PomodoroApp/Info.plist
    - PomodoroApp/PomodoroApp.entitlements
    - PomodoroAppTests/TimerEngineTests.swift
    - Package.swift
    - PomodoroApp.xcodeproj/project.pbxproj
  modified: []

key-decisions:
  - "Used SPM (Package.swift) as primary build system since Xcode.app not installed; kept xcodeproj for future Xcode use"
  - "Used Swift Testing framework instead of XCTest (XCTest unavailable with Command Line Tools only)"
  - "Added startWithDuration/startBreakWithDuration test helpers for short-duration timer tests"

patterns-established:
  - "Clock-based elapsed time: Date().timeIntervalSince(startDate), never timeRemaining -= 1"
  - "@MainActor on all engine classes for Swift 6 strict concurrency"
  - "NSStatusItem as strong stored property on AppDelegate"
  - "Timer closure uses Task { @MainActor in } for actor isolation"

requirements-completed: [TIMR-02, TIMR-03, TIMR-04, TIMR-05]

# Metrics
duration: 5min
completed: 2026-03-13
---

# Phase 1 Plan 01: Xcode Project Scaffold + TimerEngine Summary

**TimerEngine state machine with clock-based elapsed time, auto work-to-break transitions, and 8 passing unit tests via Swift Testing**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-13T19:44:35Z
- **Completed:** 2026-03-13T19:49:41Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- Xcode project scaffold with SPM build (macOS 13+, Swift 6, strict concurrency)
- TimerEngine with full state machine: idle/running/paused/onBreak transitions
- Clock-based elapsed time using Date().timeIntervalSince -- no tick counting
- Auto-transition from work to break when timer hits 0, break returns to idle
- Sleep/wake handling via NSWorkspace.didWakeNotification
- AppDelegate with NSStatusItem stored property showing "25:00"
- All 8 unit tests pass (Swift Testing framework)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Xcode project and app scaffold** - `392351c` (feat)
2. **Task 2 RED: Failing TimerEngine tests** - `bd7b33c` (test)
3. **Task 2 GREEN: Implement TimerEngine** - `be063f2` (feat)

## Files Created/Modified
- `Package.swift` - SPM package definition (macOS 13+, Swift 6)
- `PomodoroApp.xcodeproj/project.pbxproj` - Xcode project for future Xcode-based builds
- `PomodoroApp/PomodoroApp.swift` - @main App struct with NSApplicationDelegateAdaptor
- `PomodoroApp/AppDelegate.swift` - NSApplicationDelegate with NSStatusItem, accessory policy
- `PomodoroApp/Engine/TimerEngine.swift` - Core timer state machine (@MainActor, ObservableObject)
- `PomodoroApp/Info.plist` - LSUIElement=YES for agent-mode app
- `PomodoroApp/PomodoroApp.entitlements` - App sandbox enabled for SMAppService
- `PomodoroAppTests/TimerEngineTests.swift` - 8 unit tests covering all state transitions
- `.gitignore` - Excludes .build/ and .swiftpm/

## Decisions Made
- **SPM as primary build system:** Xcode.app not installed on this machine (only Command Line Tools). Created Package.swift for `swift build`/`swift test`. Kept xcodeproj for when Rod opens it in Xcode.
- **Swift Testing over XCTest:** XCTest requires Xcode.app. Swift Testing framework is available in Command Line Tools at `/Library/Developer/CommandLineTools/Library/Developer/Frameworks/Testing.framework`.
- **Test helper methods:** Added `startWithDuration(seconds:)` and `startBreakWithDuration(seconds:)` to TimerEngine for short-duration timer tests (1-2 seconds instead of 25 minutes).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] No Xcode.app installed -- switched to SPM build**
- **Found during:** Task 1 (project scaffold)
- **Issue:** `xcodebuild` requires Xcode.app, not just Command Line Tools. Machine has CLT only.
- **Fix:** Created Package.swift for SPM-based build. Kept xcodeproj for future Xcode use.
- **Files modified:** Package.swift
- **Verification:** `swift build` succeeds, `swift test` runs all tests
- **Committed in:** 392351c (Task 1 commit)

**2. [Rule 3 - Blocking] XCTest unavailable -- switched to Swift Testing**
- **Found during:** Task 2 (unit tests)
- **Issue:** `import XCTest` fails with CLT -- XCTest.framework ships only with Xcode.app
- **Fix:** Used Swift Testing framework (@Test, #expect) which is available in CLT
- **Files modified:** PomodoroAppTests/TimerEngineTests.swift
- **Verification:** All 8 tests pass via `swift test`
- **Committed in:** bd7b33c, be063f2 (Task 2 commits)

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both fixes necessary to build and test without Xcode.app. No scope creep. When Xcode is available, the xcodeproj file is ready.

## Issues Encountered
- `Info.plist` cannot be a resource in SPM -- used `exclude` directive instead
- Linker warning about Testing.framework built for macOS 14.0 vs deployment target 13.0 -- harmless, tests run correctly

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- TimerEngine ready for Plan 02 to wire up live countdown to NSStatusItem
- AppDelegate already has statusItem property and timerEngine reference
- When Xcode.app is installed, `xcodebuild` commands will work with the existing xcodeproj

---
*Phase: 01-foundation*
*Completed: 2026-03-13*
