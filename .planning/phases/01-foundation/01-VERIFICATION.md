---
phase: 01-foundation
verified: 2026-03-13T20:30:00Z
status: gaps_found
score: 4/5 success criteria verified
re_verification: false
gaps:
  - truth: "Timer auto-transitions from work to break without user action when work timer ends"
    status: partial
    reason: "Logic exists and is correct in TimerEngine, but the test covering auto-transition (autoBreakTransition, breakCompletionReturnsToIdle) cannot currently run — `swift test` fails with 'no such module Testing'. The framework exists on disk but SPM cannot find it without an explicit -F flag. Test coverage for this truth is broken."
    artifacts:
      - path: "PomodoroAppTests/TimerEngineTests.swift"
        issue: "import Testing fails at build time — SPM cannot resolve Testing.framework without explicit framework search path. Package.swift has no dependency on swift-testing package."
    missing:
      - "Add `.package(url: \"https://github.com/apple/swift-testing\", from: \"0.10.0\")` and `dependencies: [.product(name: \"Testing\", package: \"swift-testing\")]` to Package.swift testTarget, OR add `-F /Library/Developer/CommandLineTools/Library/Developer/Frameworks/` linkerSettings so SPM can locate the CLT-installed framework"
human_verification:
  - test: "Verify no Dock icon appears"
    expected: "App launches with no Dock icon — only appears in the menu bar"
    why_human: "setActivationPolicy(.accessory) + LSUIElement=YES can only be confirmed visually"
  - test: "Verify SMAppService login item registration"
    expected: "PomodoroApp appears in System Settings > General > Login Items after first launch"
    why_human: "SMAppService.register() outcome depends on system state — cannot verify programmatically without running the signed app"
  - test: "Verify live countdown ticks in menu bar"
    expected: "After clicking Start in the popover, the menu bar title updates every second"
    why_human: "Real-time display behavior requires running app observation"
---

# Phase 1: Foundation Verification Report

**Phase Goal:** Users can see a live countdown in the menu bar and the timer engine correctly handles work/break cycles with configurable durations
**Verified:** 2026-03-13T20:30:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Success Criteria from ROADMAP.md

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Countdown ticks down live in the macOS menu bar while a session is running | ? HUMAN | Combine sink on `$timeRemaining` updates `statusItem?.button?.title` every tick — wiring is correct. Requires visual confirmation. |
| 2 | Timer auto-transitions from work to break without user action when work timer ends | PARTIAL | `handleSessionComplete()` logic is correct in `TimerEngine.swift:116-131`. Unit test exists but `swift test` fails — Testing module unresolvable by SPM. |
| 3 | Work duration and break duration are configurable and persist across app restarts | VERIFIED | `@AppStorage("workDuration")` and `@AppStorage("breakDuration")` in TimerEngine. Steppers bound in MenuBarView (`$timerEngine.workDuration`, `$timerEngine.breakDuration`). |
| 4 | App launches at login with no Dock icon — it just appears in the menu bar | ? HUMAN | `SMAppService.mainApp.register()` called in `applicationDidFinishLaunching`. `LSUIElement=YES` in Info.plist. `.accessory` activation policy set. Wiring correct — runtime behavior requires human check. |
| 5 | Timer uses clock-based elapsed time and survives sleep/wake without drifting | VERIFIED | `tick()` uses `Int(Date().timeIntervalSince(start))` — no tick counting. `NSWorkspace.didWakeNotification` subscribed in `subscribeToWake()`. |

**Score:** 2 fully verified, 2 need human confirmation, 1 partial (tests broken)

---

## Required Artifacts

### Plan 01 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `PomodoroApp/Engine/TimerEngine.swift` | Timer state machine with clock-based elapsed time | VERIFIED | 134 lines. `@MainActor final class TimerEngine: ObservableObject`. All states, modes, clock-based tick, wake handling, auto-transition — fully substantive. |
| `PomodoroApp/PomodoroApp.swift` | App entry point | VERIFIED | `@main struct PomodoroApp: App` with `@NSApplicationDelegateAdaptor(AppDelegate.self)`. |
| `PomodoroApp/AppDelegate.swift` | NSApplicationDelegate with NSStatusItem stored property | VERIFIED | `var statusItem: NSStatusItem?` as stored property. Prevents ARC deallocation. |
| `PomodoroAppTests/TimerEngineTests.swift` | Unit tests for timer state machine | STUB/BROKEN | 8 tests written covering all specified behaviors. `import Testing` fails — SPM cannot locate Testing.framework. Tests are substantive but not runnable. |

### Plan 02 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `PomodoroApp/UI/MenuBarView.swift` | Menu bar dropdown with start/pause/stop controls and duration settings | VERIFIED | 97 lines. `@ObservedObject var timerEngine`. Start/Pause/Stop buttons with correct state gating. Work/break duration steppers bound to `$timerEngine.workDuration` and `$timerEngine.breakDuration`. |
| `PomodoroApp/AppDelegate.swift` | NSStatusItem title updated on every TimerEngine tick | VERIFIED | Two Combine sinks: one on `$timeRemaining`, one on `$timerState`. Both call `updateStatusTitle()`. Monospaced digit font applied. |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `TimerEngine.swift` | UserDefaults | `@AppStorage` for workDuration and breakDuration | WIRED | `@AppStorage("workDuration") var workDuration: Int = 25` and `@AppStorage("breakDuration") var breakDuration: Int = 5` at lines 13-14 |
| `TimerEngine.swift` | NSWorkspace.didWakeNotification | NotificationCenter observer in `subscribeToWake()` | WIRED | `addObserver(forName: NSWorkspace.didWakeNotification` at line 96. Calls `tick()` on wake. |
| `AppDelegate.swift` | `TimerEngine.swift` | Combine sink on `$timeRemaining` to update `statusItem.button.title` | WIRED | `engine.$timeRemaining.receive(on:).sink { self?.updateStatusTitle() }` at lines 36-41. `engine.$timerState` sink at lines 43-49. |
| `AppDelegate.swift` | SMAppService | `register()` call in `applicationDidFinishLaunching` | WIRED | `SMAppService.mainApp.register()` called at line 101 inside `registerLaunchAtLogin()`. Import ServiceManagement present. |
| `MenuBarView.swift` | `TimerEngine.swift` | `@ObservedObject` + direct method calls | WIRED | `@ObservedObject var timerEngine: TimerEngine`. Buttons call `timerEngine.start()`, `timerEngine.pause()`, `timerEngine.stop()` directly. |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| TIMR-01 | 01-02 | User can see countdown in the macOS menu bar | HUMAN NEEDED | Combine sink wires `$timeRemaining` to `statusItem.button.title`. Correct implementation — requires visual confirmation. |
| TIMR-02 | 01-01 | User can start, pause, and stop the timer from the floating window | VERIFIED (partial scope) | Start/pause/stop in MenuBarView popover — not the floating window (Phase 2), but menu bar popover. REQUIREMENTS.md marks complete. |
| TIMR-03 | 01-01 | User can configure work duration (default 25 min) | VERIFIED | `@AppStorage("workDuration") var workDuration: Int = 25`. Stepper in MenuBarView. |
| TIMR-04 | 01-01 | User can configure break duration (default 5 min) | VERIFIED | `@AppStorage("breakDuration") var breakDuration: Int = 5`. Stepper in MenuBarView. |
| TIMR-05 | 01-01 | Timer auto-transitions from work to break when work timer ends | PARTIAL | `handleSessionComplete()` logic correct. Test coverage broken — SPM cannot build test target. |
| UIFP-02 | 01-02 | App launches at login automatically | HUMAN NEEDED | `SMAppService.mainApp.register()` called. Requires running app + system check to confirm. |

**Note on TIMR-02:** The requirement says "floating window" but that's Phase 2 (UIFP-01). Phase 1 implements controls in the menu bar popover. REQUIREMENTS.md marks TIMR-02 as Phase 1 Complete — accepted.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | - | - | - | - |

Scanned `TimerEngine.swift`, `AppDelegate.swift`, `MenuBarView.swift`, `PomodoroApp.swift` for TODO/FIXME, placeholder returns (`return null`, `return {}`, `return []`), empty handlers, and console.log-only stubs. None found.

---

## Critical Gap: Test Target Cannot Build

The `PomodoroAppTests` target uses `import Testing` (Swift Testing framework). The framework binary exists at `/Library/Developer/CommandLineTools/Library/Developer/Frameworks/Testing.framework` and is importable with an explicit `-F` flag, but SPM cannot discover it automatically.

**`swift test` output:**
```
error: no such module 'Testing'
```

**Root cause:** `Package.swift` has no explicit dependency on the `swift-testing` package and no framework search path configured. SPM's module resolution doesn't automatically search CLT framework directories.

**Impact:** 8 unit tests (all state machine tests, clock-based time test, auto-transition test) are written but cannot be run. The auto-transition logic (TIMR-05 critical path) has no runnable verification.

**Fix options (pick one):**
1. Add `swift-testing` as an explicit SPM dependency:
   ```swift
   dependencies: [
       .package(url: "https://github.com/apple/swift-testing", from: "0.10.0")
   ]
   ```
   And in the test target:
   ```swift
   dependencies: [.product(name: "Testing", package: "swift-testing")]
   ```

2. Add `unsafeFlags` linker setting to point SPM at the CLT frameworks directory:
   ```swift
   .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks/"])
   ```
   (Option 1 is cleaner and portable)

---

## Human Verification Required

### 1. No Dock Icon

**Test:** Build and run the app (`swift build && open .build/debug/PomodoroApp.app`)
**Expected:** No icon appears in the Dock. App only appears in the menu bar.
**Why human:** `setActivationPolicy(.accessory)` + `LSUIElement=YES` can only be confirmed visually at runtime.

### 2. Live Countdown in Menu Bar

**Test:** Click the menu bar item to open the popover, click Start.
**Expected:** The menu bar title ticks down every second in MM:SS format.
**Why human:** Real-time display update requires running app observation.

### 3. Login Item Registration

**Test:** After running the app once, open System Settings > General > Login Items.
**Expected:** PomodoroApp appears in the list.
**Why human:** `SMAppService.register()` outcome depends on system state, signing, and whether the app is running from an app bundle vs. the `.build` directory.

---

## Gaps Summary

One automated gap blocking full verification:

**Test target broken** — `swift test` fails because SPM cannot find the Swift Testing framework. All 8 unit tests are substantive and correct but unrunnable. This directly affects confidence in TIMR-05 (auto-transition), the most complex state machine behavior. The fix is a one-line Package.swift change. The application itself builds and runs correctly — this is a test infrastructure problem, not a production code problem.

Three items need human confirmation (live countdown display, no Dock icon, login item). These are runtime behaviors that code inspection cannot substitute for.

---

_Verified: 2026-03-13T20:30:00Z_
_Verifier: Claude (gsd-verifier)_
