---
phase: 03-audio-polish
plan: 01
subsystem: audio
tags: [avfoundation, avaudioplayer, ambient-sound, swiftui, spm-resources]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: TimerEngine with lifecycle hooks (start/pause/stop/break/resume)
provides:
  - AudioEngine with ambient looping and chime playback
  - AmbientSound enum with 6 sound types
  - SoundPickerView for floating panel
  - 7 bundled placeholder .m4a files via SPM resources
affects: []

# Tech tracking
tech-stack:
  added: [AVFoundation, AVAudioPlayer]
  patterns: [unowned engine reference for audio lifecycle, SPM .process resources]

key-files:
  created:
    - PomodoroApp/Engine/AudioEngine.swift
    - PomodoroApp/UI/SoundPickerView.swift
    - PomodoroApp/Resources/Sounds/rain.m4a
    - PomodoroApp/Resources/Sounds/ocean.m4a
    - PomodoroApp/Resources/Sounds/forest.m4a
    - PomodoroApp/Resources/Sounds/fireplace.m4a
    - PomodoroApp/Resources/Sounds/whitenoise.m4a
    - PomodoroApp/Resources/Sounds/coffeeshop.m4a
    - PomodoroApp/Resources/Sounds/chime.m4a
  modified:
    - Package.swift
    - PomodoroApp/Engine/TimerEngine.swift
    - PomodoroApp/AppDelegate.swift
    - PomodoroApp/UI/FloatingPanelWindow.swift
    - PomodoroApp/UI/ControlsView.swift
    - PomodoroAppTests/TimerEngineTests.swift

key-decisions:
  - "Bundle.module over Bundle.main for SPM resource lookup"
  - "Stored AVAudioPlayer properties to prevent ARC deallocation mid-playback"
  - "stopAmbient() called before playChime() in handleSessionComplete to prevent overlap"
  - "Placeholder .m4a files generated via macOS say+afconvert for development"

patterns-established:
  - "Audio lifecycle tied to TimerEngine state transitions via unowned reference"
  - "UserDefaults persistence for sound selection (key: selectedSound)"

requirements-completed: [AUDO-01, AUDO-02, AUDO-03, AUDO-04]

# Metrics
duration: 34min
completed: 2026-03-13
---

# Phase 3 Plan 01: Audio + Polish Summary

**AVFoundation-based AudioEngine with 6 ambient sounds looping during work sessions, chime on session end, and SoundPickerView in floating panel**

## Performance

- **Duration:** 34 min
- **Started:** 2026-03-14T01:23:01Z
- **Completed:** 2026-03-14T01:56:49Z
- **Tasks:** 3
- **Files modified:** 16

## Accomplishments
- AudioEngine with AVAudioPlayer-based ambient looping (infinite loop, 0.7 volume) and single-shot chime playback
- AmbientSound enum with 6 cases (rain, ocean, forest, fireplace, whitenoise, coffeeshop) and display names
- TimerEngine wired to AudioEngine at all 6 lifecycle points (start, pause, stop, startBreak, resumeWork, handleSessionComplete)
- SoundPickerView with dropdown menu embedded in floating panel
- Sound selection persisted to UserDefaults across app restarts
- 7 placeholder .m4a files bundled via SPM .process("Resources/") declaration

## Task Commits

Each task was committed atomically:

1. **Task 1: AudioEngine, AmbientSound enum, placeholder .m4a files, Package.swift resources** - `bfdddbe` (feat)
2. **Task 2: Wire AudioEngine into TimerEngine, AppDelegate, panel, add SoundPickerView** - `18e5a11` (feat)
3. **Task 3: Verify audio playback and sound picker** - checkpoint approved, post-fix `0ed8640` (fix: Bundle.module for SPM)

## Files Created/Modified
- `PomodoroApp/Engine/AudioEngine.swift` - AVAudioPlayer wrapper with startAmbient/stopAmbient/playChime/select
- `PomodoroApp/UI/SoundPickerView.swift` - Sound selection dropdown with speaker icon, TokyoNight theme
- `PomodoroApp/Resources/Sounds/*.m4a` - 7 placeholder audio files (6 ambient + 1 chime)
- `Package.swift` - Added resources: [.process("Resources/")] for SPM bundling
- `PomodoroApp/Engine/TimerEngine.swift` - Added audioEngine unowned ref, audio calls at all lifecycle points
- `PomodoroApp/AppDelegate.swift` - Creates AudioEngine before TimerEngine, passes to both
- `PomodoroApp/UI/FloatingPanelWindow.swift` - Updated init to accept and pass audioEngine
- `PomodoroApp/UI/ControlsView.swift` - Added audioEngine property, embedded SoundPickerView
- `PomodoroAppTests/TimerEngineTests.swift` - Updated init calls for new TimerEngine(audioEngine:) signature

## Decisions Made
- **Bundle.module over Bundle.main**: SPM packages must use Bundle.module for resource access; Bundle.main returns nil. Fixed post-checkpoint.
- **Stored AVAudioPlayer properties**: Local AVAudioPlayer variables get ARC-deallocated mid-playback. Stored as instance properties on AudioEngine.
- **stopAmbient before playChime ordering**: Prevents audio overlap at session end (AUDO-04 requirement).
- **Placeholder audio via say+afconvert**: Real CC0 ambient sounds from Freesound.org/Pixabay needed before shipping.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Bundle.main changed to Bundle.module for SPM resource lookup**
- **Found during:** Task 3 (checkpoint verification)
- **Issue:** Bundle.main.url(forResource:) returns nil in SPM packages; must use Bundle.module
- **Fix:** Changed all Bundle.main references to Bundle.module in AudioEngine.swift
- **Files modified:** PomodoroApp/Engine/AudioEngine.swift
- **Verification:** Audio plays correctly after fix
- **Committed in:** `0ed8640`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Essential fix for audio playback. No scope creep.

## Issues Encountered
- XCTest unavailable with Command Line Tools only (pre-existing) -- tests cannot run via `swift test` but build compiles clean

## User Setup Required
None - no external service configuration required. Placeholder audio files work for development; real CC0 audio files should be sourced before shipping.

## Next Phase Readiness
- All v1 requirements complete (TIMR-01 through TIMR-05, UIFP-01, UIFP-02, AUDO-01 through AUDO-04)
- App is functionally shippable
- Before distribution: replace placeholder .m4a with real CC0 ambient sounds, notarize with Apple Developer account

## Self-Check: PASSED

All key files verified present. All commit hashes verified in git log.

---
*Phase: 03-audio-polish*
*Completed: 2026-03-13*
