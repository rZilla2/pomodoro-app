# Phase 3: Audio + Polish - Research

**Researched:** 2026-03-13
**Domain:** AVAudioPlayer ambient looping, chime playback, @AppStorage persistence, SwiftUI sound picker, SPM-only build
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUDO-01 | User hears a chime when a session ends | `AVAudioPlayer` one-shot play from `TimerEngine.handleSessionComplete()` when work mode ends; chime file bundled as `.m4a`; called before starting break timer |
| AUDO-02 | User can play ambient sound (rain, ocean, forest, fireplace, white noise, coffee shop) during focus sessions | `AudioEngine` ObservableObject with `AVAudioPlayer` stored property; `numberOfLoops = -1`; started on `TimerEngine.start()` for work sessions only |
| AUDO-03 | User can select ambient sound from the floating window | `SoundPickerView` SwiftUI row added to `ControlsView`; enum `AmbientSound` drives picker; `@AppStorage("selectedSound")` persists selection |
| AUDO-04 | Ambient sound stops on pause/stop/session end and doesn't overlap chime | `AudioEngine.stopAmbient()` called from `TimerEngine` on pause/stop/break-start/session-end; chime fires after ambient stops; single `AVAudioPlayer` instance prevents overlap |
</phase_requirements>

---

## Summary

Phase 3 adds AVFoundation audio to the already-complete macOS SwiftUI/AppKit app. The floating panel (Phase 2) is fully built. This phase has two independent audio concerns: (1) looping ambient sound tied to the work session lifecycle, and (2) a one-shot chime on work-session completion. Both use `AVAudioPlayer` — the standard macOS API for local file playback.

The architecture calls for a new `AudioEngine` ObservableObject that lives alongside `TimerEngine` in `AppDelegate`. `TimerEngine` gets callbacks into `AudioEngine` at the four state-change points that matter: start-work, pause, stop, and session-complete. A new `SoundPickerView` sits inside the existing `ControlsView`. Sound selection is a single `@AppStorage` string — zero persistence complexity.

The project uses SPM as the primary build (no Xcode.app, just Command Line Tools). Audio files must go in `PomodoroApp/Resources/` and be declared in `Package.swift` under `resources:`. This is the critical packaging difference from an Xcode-managed project where "Copy Bundle Resources" is a build phase GUI toggle.

**Primary recommendation:** Add `AudioEngine.swift` to `Engine/`, add `SoundPickerView.swift` to `UI/`, bundle 6 ambient `.m4a` files + 1 chime `.m4a` in `PomodoroApp/Resources/Sounds/`, wire `AudioEngine` into `TimerEngine` via stored reference on `AppDelegate`, and extend `ControlsView` to include the sound picker row.

---

## What Phases 1 and 2 Built (Current State)

Understanding the existing code is essential before adding audio.

| File | Role | Relevant to Phase 3 |
|------|------|---------------------|
| `AppDelegate.swift` | Owns `TimerEngine`, `FloatingPanelWindow`; Combine subscriptions for status bar updates | `AudioEngine` instance lives here too; passed to `TimerEngine` and `ControlsView` |
| `TimerEngine.swift` | `@MainActor ObservableObject`; `handleSessionComplete()` is where chime fires; `start()`, `pause()`, `stop()` are where ambient starts/stops | Add `audioEngine: AudioEngine?` weak/unowned reference; call audio methods at each lifecycle point |
| `FloatingPanelWindow.swift` | `NSPanel` subclass; already hosts `ControlsView` via `NSHostingView` | Must be updated to pass `AudioEngine` into `ControlsView` |
| `ControlsView.swift` | SwiftUI view inside the panel; has play/pause/stop/break buttons and steppers | Add `SoundPickerView` below the controls row |
| `Package.swift` | SPM config, `swift-tools-version: 6.0`, `macOS(.v13)`, no `resources:` array yet | MUST add `resources: [.process("Resources/")]` or files won't be bundled |

**Key structural insight:** The app uses SPM (not Xcode) as the build driver. `Bundle.main.url(forResource:withExtension:)` works correctly in SPM-built apps, but only if resources are declared in `Package.swift`. This is the most common Phase 3 failure point.

---

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| AVFoundation (AVAudioPlayer) | macOS 10.7+ | Ambient looping + chime playback | Apple-native API; `numberOfLoops = -1` for infinite loop; no external dependencies; simpler than AVAudioEngine for single-track playback |
| UserDefaults via @AppStorage | macOS 13+ | Persist selected ambient sound across launches | Zero-overhead; already used for `workDuration` / `breakDuration` in `TimerEngine`; consistent pattern |
| SPM `resources:` array in Package.swift | swift-tools-version 5.3+ | Bundle audio files with the app | Required for SPM-built apps; without this, `Bundle.main.url(forResource:withExtension:)` returns nil at runtime |

### No New External Libraries Needed

The existing stack handles everything Phase 3 requires:
- `AVAudioPlayer` — built into macOS, no SPM package required
- `@AppStorage` — already in use in `TimerEngine`
- SwiftUI `Picker` or custom row — built into SwiftUI

### Alternatives Considered

| Recommended | Alternative | Why Alternative Loses |
|-------------|-------------|----------------------|
| AVAudioPlayer | AVAudioEngine | AVAudioEngine is for real-time audio graphs, mixing, effects. Overkill for simple looping. 3x more setup code. |
| Bundled .m4a files | Streaming audio URLs | Streaming requires network, permission, and failure handling. Bundled = zero dependencies. |
| Single AudioEngine with two players | Separate ChimeEngine and AmbientEngine | Unnecessary separation. One AudioEngine with an ambient player and a chime player is clean and easy to reason about. |
| .m4a format | .mp3 or .wav | .m4a (AAC) gives better compression than .mp3 at the same quality; much smaller than .wav. Apple's preferred format for bundled audio. |

**Installation:** No new packages. Audio files must be sourced separately (see Open Questions).

---

## Architecture Patterns

### Recommended New and Modified Files

```
PomodoroApp/
├── AppDelegate.swift              # MODIFY: add audioEngine property; pass to TimerEngine + FloatingPanelWindow
├── Engine/
│   ├── TimerEngine.swift          # MODIFY: add audioEngine reference; call audio at lifecycle points
│   └── AudioEngine.swift          # NEW: AVAudioPlayer wrapper, ObservableObject
├── UI/
│   ├── ControlsView.swift         # MODIFY: add SoundPickerView below controls
│   ├── FloatingPanelWindow.swift  # MODIFY: pass audioEngine into ControlsView
│   └── SoundPickerView.swift      # NEW: ambient sound selector row
├── Resources/
│   └── Sounds/                    # NEW directory
│       ├── rain.m4a
│       ├── ocean.m4a
│       ├── forest.m4a
│       ├── fireplace.m4a
│       ├── whitenoise.m4a
│       ├── coffeeshop.m4a
│       └── chime.m4a
└── Package.swift                  # MODIFY: add resources: [.process("Resources/")]
```

### Pattern 1: AudioEngine ObservableObject

**What:** A `@MainActor` `ObservableObject` that holds two strong `AVAudioPlayer` properties — one for ambient looping, one for chime. It exposes simple play/stop methods that `TimerEngine` and `ControlsView` call.

**When to use:** Anytime audio state needs to be observed by SwiftUI or controlled from the timer lifecycle.

```swift
// Source: STACK.md (project research) + PITFALLS.md Pitfall 4
import AVFoundation

@MainActor
final class AudioEngine: ObservableObject {
    @Published var selectedSound: AmbientSound = AmbientSound(rawValue: UserDefaults.standard.string(forKey: "selectedSound") ?? "") ?? .rain

    private var ambientPlayer: AVAudioPlayer?
    private var chimePlayer: AVAudioPlayer?

    func startAmbient() {
        let sound = selectedSound
        guard let url = Bundle.main.url(forResource: sound.filename, withExtension: "m4a") else {
            assertionFailure("Missing bundled audio: \(sound.filename).m4a")
            return
        }
        ambientPlayer?.stop()
        ambientPlayer = try? AVAudioPlayer(contentsOf: url)
        ambientPlayer?.numberOfLoops = -1  // infinite loop
        ambientPlayer?.prepareToPlay()
        ambientPlayer?.play()
    }

    func stopAmbient() {
        ambientPlayer?.stop()
        ambientPlayer = nil
    }

    func playChime() {
        guard let url = Bundle.main.url(forResource: "chime", withExtension: "m4a") else {
            assertionFailure("Missing bundled audio: chime.m4a")
            return
        }
        chimePlayer = try? AVAudioPlayer(contentsOf: url)
        chimePlayer?.numberOfLoops = 0  // play once
        chimePlayer?.prepareToPlay()
        chimePlayer?.play()
    }

    func select(_ sound: AmbientSound) {
        selectedSound = sound
        UserDefaults.standard.set(sound.rawValue, forKey: "selectedSound")
        // If currently playing, switch immediately
        if ambientPlayer?.isPlaying == true {
            startAmbient()
        }
    }
}
```

### Pattern 2: AmbientSound Enum

**What:** A `String`-rawValue enum listing the 6 sounds. The raw value is the filename (without extension) and the `@AppStorage` key value.

```swift
// Source: project requirements AUDO-02, AUDO-03
enum AmbientSound: String, CaseIterable, Identifiable {
    case rain = "rain"
    case ocean = "ocean"
    case forest = "forest"
    case fireplace = "fireplace"
    case whitenoise = "whitenoise"
    case coffeeshop = "coffeeshop"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rain: return "Rain"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .fireplace: return "Fireplace"
        case .whitenoise: return "White Noise"
        case .coffeeshop: return "Coffee Shop"
        }
    }

    var filename: String { rawValue }
}
```

### Pattern 3: TimerEngine Audio Wiring

**What:** `TimerEngine` holds an `unowned` reference to `AudioEngine` (both are `@MainActor`, both live for the app's lifetime). The three lifecycle methods each call the correct audio action.

**When to use:** This pattern keeps audio control in one place (TimerEngine) and avoids needing Combine subscriptions for audio triggers.

```swift
// Source: ARCHITECTURE.md — TimerEngine -> AudioEngine integration point
// Modifications to TimerEngine.swift

// Add property:
unowned var audioEngine: AudioEngine

// Modify start():
func start() {
    // ... existing logic ...
    if currentMode == .work {
        audioEngine.startAmbient()
    }
}

// Modify pause():
func pause() {
    // ... existing logic ...
    audioEngine.stopAmbient()
}

// Modify stop():
func stop() {
    // ... existing logic ...
    audioEngine.stopAmbient()
}

// Modify handleSessionComplete() — work session ending:
private func handleSessionComplete() {
    ticker?.invalidate()
    ticker = nil
    if currentMode == .work {
        audioEngine.stopAmbient()   // stop ambient BEFORE chime
        audioEngine.playChime()     // chime fires once
        // ... then start break ...
    }
    // ... existing break-complete logic ...
}
```

**Critical ordering:** `stopAmbient()` MUST be called before `playChime()`. If ambient is still looping when the chime starts, the two overlap. `AVAudioPlayer` instances are independent — they do not auto-mute each other.

### Pattern 4: SoundPickerView

**What:** A compact SwiftUI row showing the current sound name with left/right arrows (or a menu) to cycle through options. Injected with `@ObservedObject var audioEngine: AudioEngine`.

```swift
// Source: ControlsView.swift styling conventions (TokyoNight theme, IconButtonStyle)
import SwiftUI

struct SoundPickerView: View {
    @ObservedObject var audioEngine: AudioEngine

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 10))
                .foregroundColor(TokyoNight.comment)

            Menu(audioEngine.selectedSound.displayName) {
                ForEach(AmbientSound.allCases) { sound in
                    Button(sound.displayName) {
                        audioEngine.select(sound)
                    }
                }
            }
            .font(.system(size: 11))
            .foregroundColor(TokyoNight.fg)
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}
```

### Pattern 5: Package.swift Resources Declaration

**What:** SPM requires an explicit `resources:` array in the target declaration to bundle non-Swift files. Without this, audio files are present in the project directory but absent from `Bundle.main` at runtime.

```swift
// CRITICAL: Without this, Bundle.main.url(forResource:withExtension:) returns nil
// Source: Swift Package Manager documentation — resources support
.executableTarget(
    name: "PomodoroApp",
    path: "PomodoroApp",
    exclude: [
        "Info.plist",
        "PomodoroApp.entitlements",
    ],
    resources: [
        .process("Resources/")   // ADD THIS LINE
    ],
    swiftSettings: [
        .swiftLanguageMode(.v6),
    ]
),
```

### Anti-Patterns to Avoid

- **Local `AVAudioPlayer` variable:** Create inside a function, ARC deallocates on return. Silent failure. Always a strong stored property on `AudioEngine`.
- **Chime before stopAmbient:** Both players play simultaneously. `stopAmbient()` first, then `playChime()`.
- **`@StateObject AudioEngine` inside a View:** Creates a second independent engine with no connection to TimerEngine. `AudioEngine` must live on `AppDelegate`, same as `TimerEngine`.
- **Skipping `resources:` in Package.swift:** The #1 mistake in SPM audio apps. `Bundle.main.url(forResource:withExtension:)` returns nil silently.
- **`AVAudioSession` calls:** This is the iOS API. It does not exist on macOS. Do not import or call it.
- **Ambient sound during break sessions:** Only start ambient on `.work` sessions. When `currentMode == .break_`, do not call `startAmbient()`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Infinite audio loop | Custom loop with completion callbacks | `player.numberOfLoops = -1` | AVAudioPlayer handles gapless looping natively at the OS level |
| Persisting sound selection | Custom storage layer | `UserDefaults.standard.set(rawValue, forKey:)` or `@AppStorage` | One string in UserDefaults; `AmbientSound.rawValue` IS the key |
| Audio file loading | Custom file manager | `Bundle.main.url(forResource:withExtension:)` | SPM bundles declared resources correctly; this is the only correct API for in-bundle files |
| Mixing prevention | Audio session management, channels, priorities | Sequential: `stopAmbient()` then `playChime()` | Two separate `AVAudioPlayer` instances don't auto-mute; explicit ordering is the solution |

**Key insight:** AVAudioPlayer is exactly sized for this use case. Every "improvement" (AVAudioEngine, custom mixing, audio session routing) adds complexity with zero benefit for a simple looping ambient + one-shot chime pattern.

---

## Common Pitfalls

### Pitfall 1: AVAudioPlayer Deallocated Silently (Critical)

**What goes wrong:** `AVAudioPlayer` created inside a method scope plays for 0–2 seconds (buffered data), then stops silently. No error, no crash, no delegate callback.

**Why it happens:** ARC releases the local variable immediately after the function returns. This is the single most common AVAudioPlayer bug in Swift.

**How to avoid:** `ambientPlayer` and `chimePlayer` are `private var` stored properties on `AudioEngine`. Never `let player = AVAudioPlayer(...)` inside a function body.

**Warning signs:** Rain plays for 1–2 seconds then stops. Chime plays once then "breaks" on the next session end.

Source: [AVAudioPlayer deallocation — Apple Developer Forums](https://developer.apple.com/forums/thread/92672) (HIGH confidence)

---

### Pitfall 2: Audio Files Missing from Bundle (SPM-Specific, Critical)

**What goes wrong:** `Bundle.main.url(forResource: "rain", withExtension: "m4a")` returns `nil`. Silent failure — no audio, no crash.

**Why it happens:** In an Xcode project, audio files are added via "Copy Bundle Resources" build phase. In SPM, resources must be explicitly declared in `Package.swift` with `resources: [.process("Resources/")]`. If the `resources:` array is missing, files exist on disk but are excluded from the built app bundle.

**How to avoid:** Add `resources: [.process("Resources/")]` to the `PomodoroApp` target in `Package.swift` BEFORE adding audio files. Verify with `assertionFailure` guard on nil URL.

**Warning signs:** Build succeeds, app runs, no audio plays, no crash. Adding a debug print shows `Bundle.main.url(...)` returns nil.

Source: [Swift Package Manager Resources — Swift.org documentation](https://www.swift.org/documentation/package-manager/) (HIGH confidence)

---

### Pitfall 3: Ambient + Chime Overlap

**What goes wrong:** At work-session end, the ambient sound continues looping while the chime plays. Both sounds play simultaneously, creating noise.

**Why it happens:** `AVAudioPlayer` instances are independent. `ambientPlayer` loops indefinitely until explicitly stopped. Calling `chimePlayer?.play()` without first calling `ambientPlayer?.stop()` means both play at once.

**How to avoid:** Always call `audioEngine.stopAmbient()` first, then `audioEngine.playChime()`. Order matters. These two lines are always sequential.

**Warning signs:** Session-end chime is heard but so is the ambient sound underneath it.

---

### Pitfall 4: Swift 6 Strict Concurrency on AudioEngine

**What goes wrong:** `Package.swift` sets `swiftLanguageMode(.v6)`. Any `AVAudioPlayer` method call from a non-isolated context produces a Sendable error. `AVAudioPlayer` is not `Sendable`.

**Why it happens:** Swift 6 enforces actor isolation. `AVAudioPlayer` is an Objective-C class with no Swift concurrency annotations.

**How to avoid:** Mark `AudioEngine` as `@MainActor final class`. All calls to `startAmbient()`, `stopAmbient()`, `playChime()` are then on the main actor. `TimerEngine` is already `@MainActor`, so calling `audioEngine.startAmbient()` from `TimerEngine` is safe.

**Warning signs:** Build errors mentioning "Call to main actor-isolated..." or "Passing value of type 'AVAudioPlayer' over actor boundary."

Source: PITFALLS.md Mistake 6 (project research) — @MainActor pattern already established in project (HIGH confidence)

---

### Pitfall 5: Ambient Sound Starts During Break Sessions

**What goes wrong:** User starts a break; ambient sound plays during break. AUDO-02 specifies ambient during focus sessions only.

**Why it happens:** `TimerEngine.start()` is called for both work and break sessions. If `startAmbient()` is called unconditionally in `start()`, it plays during breaks.

**How to avoid:** Gate `startAmbient()` on `currentMode == .work`. In `start()`:
```swift
if currentMode == .work {
    audioEngine.startAmbient()
}
```

**Warning signs:** Ambient rain plays during the 5-minute break countdown.

---

### Pitfall 6: startBreak() Path Misses stopAmbient()

**What goes wrong:** User manually triggers a break mid-session (presses the break button). The ambient sound continues because the stop-ambient call is only in `stop()` and `handleSessionComplete()` — not in `startBreak()`.

**Why it happens:** `startBreak()` is a separate code path from `pause()`, `stop()`, and `handleSessionComplete()`. Easy to miss when wiring audio.

**How to avoid:** Add `audioEngine.stopAmbient()` to `startBreak()` as well. Audit every code path that transitions away from an active work session.

**Warning signs:** Manual break button leaves ambient playing through the break.

---

## Code Examples

### AudioEngine Complete Implementation

```swift
// Source: STACK.md + PITFALLS.md Pitfall 4 (project research)
import AVFoundation
import SwiftUI

@MainActor
final class AudioEngine: ObservableObject {
    @Published var selectedSound: AmbientSound

    private var ambientPlayer: AVAudioPlayer?
    private var chimePlayer: AVAudioPlayer?

    init() {
        let saved = UserDefaults.standard.string(forKey: "selectedSound") ?? ""
        selectedSound = AmbientSound(rawValue: saved) ?? .rain
    }

    func startAmbient() {
        guard let url = Bundle.main.url(forResource: selectedSound.filename, withExtension: "m4a") else {
            assertionFailure("Missing audio: \(selectedSound.filename).m4a — check Resources/ and Package.swift resources:")
            return
        }
        ambientPlayer?.stop()
        ambientPlayer = nil
        ambientPlayer = try? AVAudioPlayer(contentsOf: url)
        ambientPlayer?.numberOfLoops = -1
        ambientPlayer?.volume = 0.7
        ambientPlayer?.prepareToPlay()
        ambientPlayer?.play()
    }

    func stopAmbient() {
        ambientPlayer?.stop()
        ambientPlayer = nil
    }

    func playChime() {
        guard let url = Bundle.main.url(forResource: "chime", withExtension: "m4a") else {
            assertionFailure("Missing audio: chime.m4a — check Resources/ and Package.swift resources:")
            return
        }
        chimePlayer?.stop()
        chimePlayer = nil
        chimePlayer = try? AVAudioPlayer(contentsOf: url)
        chimePlayer?.numberOfLoops = 0
        chimePlayer?.prepareToPlay()
        chimePlayer?.play()
    }

    func select(_ sound: AmbientSound) {
        selectedSound = sound
        UserDefaults.standard.set(sound.rawValue, forKey: "selectedSound")
        if ambientPlayer?.isPlaying == true {
            startAmbient()  // switch track if currently playing
        }
    }
}
```

### Package.swift Resource Declaration

```swift
// Source: Swift Package Manager resources documentation
.executableTarget(
    name: "PomodoroApp",
    path: "PomodoroApp",
    exclude: [
        "Info.plist",
        "PomodoroApp.entitlements",
    ],
    resources: [
        .process("Resources/")   // bundles all files in PomodoroApp/Resources/
    ],
    swiftSettings: [
        .swiftLanguageMode(.v6),
    ]
),
```

### AppDelegate Wiring

```swift
// AppDelegate.swift additions
var audioEngine: AudioEngine?

func applicationDidFinishLaunching(_ notification: Notification) {
    // ... existing engine + statusItem setup ...

    let audio = AudioEngine()
    audioEngine = audio

    let engine = TimerEngine(audioEngine: audio)
    timerEngine = engine

    // ... rest of existing setup ...

    // FloatingPanel also needs audioEngine for SoundPickerView
    let panel = FloatingPanelWindow(timerEngine: engine, audioEngine: audio)
    floatingPanel = panel
}
```

### TimerEngine Additions for Audio

```swift
// TimerEngine.swift: add at top of class
unowned let audioEngine: AudioEngine

init(audioEngine: AudioEngine) {
    self.audioEngine = audioEngine
}

// In start():
func start() {
    // ... existing logic first (set currentMode, targetDuration) ...
    if currentMode == .work {
        audioEngine.startAmbient()
    }
    beginSession()
}

// In pause():
func pause() {
    guard timerState == .running else { return }
    pausedRemaining = timeRemaining
    ticker?.invalidate()
    ticker = nil
    timerState = .paused
    audioEngine.stopAmbient()
}

// In stop():
func stop() {
    // ... existing cleanup ...
    audioEngine.stopAmbient()
}

// In startBreak():
func startBreak() {
    // ... existing logic ...
    audioEngine.stopAmbient()
    // ... then begin break session ...
}

// In handleSessionComplete(), work-mode branch:
if currentMode == .work {
    audioEngine.stopAmbient()   // FIRST: stop ambient
    audioEngine.playChime()     // THEN: play chime
    canResumeWork = false
    currentMode = .break_
    targetDuration = breakDuration * 60
    beginSession()
}
```

---

## Audio File Sourcing

The blocking concern from STATE.md: royalty-free audio files must be obtained before implementation.

**Recommended sources (CC0 / royalty-free):**
- [Freesound.org](https://freesound.org) — filter by CC0 license; search "rain loop", "ocean loop", "forest ambience", "fireplace crackling", "white noise", "coffee shop ambience"
- [Pixabay Audio](https://pixabay.com/music/) — royalty-free, no attribution required
- [Zapsplat](https://www.zapsplat.com) — free tier with attribution

**Format guidance:**
- Download as highest quality available (WAV or FLAC)
- Convert to `.m4a` (AAC, 128kbps or 192kbps stereo) using `ffmpeg` or macOS's `afconvert`
- Target duration: 60–120 seconds per loop (long enough to avoid noticeable repetition)
- Keep file sizes under 5MB each; total bundle addition under 35MB

**Chime file:** A single clear tone, 2–4 seconds. Search "meditation bell" or "tibetan bowl" CC0 on Freesound.

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| NSSound (AppKit) | AVAudioPlayer (AVFoundation) | AVAudioPlayer has `numberOfLoops`, `volume`, `prepareToPlay()` for gapless start; NSSound is a thinner wrapper with no looping control |
| AVAudioSession (iOS pattern) | No session config needed on macOS | AVAudioSession does not exist on macOS; macOS audio routes automatically |
| Streaming audio URLs | Bundled .m4a files | No network dependency, instant playback, works offline |
| Xcode "Copy Bundle Resources" | SPM `resources: [.process("Resources/")]` | SPM-specific requirement; same behavior as Xcode build phase |

---

## Open Questions

1. **Audio file availability**
   - What we know: STATE.md flags this as a blocker — files must be sourced before Phase 3 implementation
   - What's unclear: Whether Rod has already sourced files or needs to do so before Wave 0
   - Recommendation: Wave 0 task — source and convert 7 files (6 ambient + 1 chime) before writing any Swift code

2. **Volume level for ambient**
   - What we know: `AVAudioPlayer.volume` accepts 0.0–1.0; system volume applies on top
   - What's unclear: Appropriate default volume; user may want a volume slider
   - Recommendation: Default to `0.7`; don't add a slider (out of scope per project simplicity requirement). Keep it as a constant in `AudioEngine`.

3. **Sound switch behavior mid-session**
   - What we know: User selects a new sound while rain is playing
   - Recommendation: Switch immediately — call `startAmbient()` with the new sound when `select(_:)` is called and `ambientPlayer?.isPlaying == true`. No fade. No crossfade (would require AVAudioEngine). Instant switch is simpler and matches the app's zero-friction philosophy.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (confirmed from `TimerEngineTests.swift`) |
| Config file | `Package.swift` — `PomodoroAppTests` target already exists |
| Quick run command | `swift test --filter PomodoroAppTests 2>&1` |
| Full suite command | `swift test 2>&1` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUDO-01 | Chime plays on work-session end | Manual smoke | Let 1-second test session expire; verify chime audible | ❌ Wave 0 (manual — requires audio hardware) |
| AUDO-01 | Chime does not play on break-session end | Manual smoke | Let break timer expire; verify silence | ❌ Wave 0 (manual) |
| AUDO-02 | Ambient sound loops during work session | Manual smoke | Start work session; verify ambient plays and loops | ❌ Wave 0 (manual) |
| AUDO-02 | Ambient does not play during break | Manual smoke | Start break session; verify silence | ❌ Wave 0 (manual) |
| AUDO-03 | Sound picker shows in floating window | Manual smoke | Open panel; verify picker is visible and lists 6 sounds | ❌ Wave 0 (manual — UI) |
| AUDO-03 | Selection persists across restart | Manual smoke | Select ocean; quit app; relaunch; verify ocean is selected | ❌ Wave 0 (manual) |
| AUDO-04 | Ambient stops on pause | Manual smoke | Start work + ambient; press pause; verify ambient stops | ❌ Wave 0 (manual) |
| AUDO-04 | Ambient stops on stop | Manual smoke | Start work + ambient; press stop; verify ambient stops | ❌ Wave 0 (manual) |
| AUDO-04 | No overlap at session end | Manual smoke | Ambient stops before chime plays; no simultaneous audio | ❌ Wave 0 (manual) |
| AUDO-01/04 | AudioEngine initializes without crash | Unit test | `swift test --filter AudioEngineTests 2>&1` | ❌ Wave 0 |

**Note:** Audio playback cannot be meaningfully unit-tested without a running audio system and real audio files. All AUDO requirements are manual smoke tests. One unit-testable surface: `AudioEngine.select(_:)` persists the correct `rawValue` to UserDefaults.

### Sampling Rate

- **Per task commit:** `swift build 2>&1` (build check — no compilation errors)
- **Per wave merge:** `swift test 2>&1` (existing `TimerEngineTests` remain green; new `AudioEngineTests` if added)
- **Phase gate:** Full manual smoke checklist passes before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `PomodoroApp/Engine/AudioEngine.swift` — new file, does not exist yet
- [ ] `PomodoroApp/UI/SoundPickerView.swift` — new file, does not exist yet
- [ ] `PomodoroApp/Resources/Sounds/` directory — does not exist yet
- [ ] 7 audio files (6 ambient + 1 chime) — must be sourced, converted to .m4a, placed in Resources/Sounds/
- [ ] `Package.swift` resources array — not yet present in target declaration
- [ ] `PomodoroAppTests/AudioEngineTests.swift` — optional unit test for UserDefaults persistence

---

## Sources

### Primary (HIGH confidence)

- `PomodoroApp/Engine/TimerEngine.swift` — current source, all lifecycle methods read directly
- `PomodoroApp/AppDelegate.swift` — current source, injection pattern confirmed
- `PomodoroApp/UI/ControlsView.swift` — current source, TokyoNight theme + button styles confirmed
- `PomodoroApp/UI/FloatingPanelWindow.swift` — current source, constructor signature confirmed
- `PomodoroApp/Package.swift` — current source, missing `resources:` array confirmed
- `.planning/research/STACK.md` — AVAudioPlayer recommendation with rationale, SPM bundle pattern
- `.planning/research/PITFALLS.md` — Pitfall 4 (AVAudioPlayer deallocation), Mistake 7 (Copy Bundle Resources)
- `.planning/research/ARCHITECTURE.md` — AudioEngine pattern, TimerEngine → AudioEngine integration flow
- [AVAudioPlayer — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avaudioplayer) — `numberOfLoops`, `prepareToPlay`, `volume`
- [Swift Package Manager Resources — Swift.org](https://www.swift.org/documentation/package-manager/) — `resources: [.process()]` syntax

### Secondary (MEDIUM confidence)

- [How to loop audio using AVAudioPlayer — Hacking with Swift](https://www.hackingwithswift.com/example-code/media/how-to-loop-audio-using-avaudioplayer-and-numberofloops) — `numberOfLoops = -1` pattern
- [AVAudioPlayer deallocation — Apple Developer Forums](https://developer.apple.com/forums/thread/92672) — silent deallocation behavior documented

### Tertiary (LOW confidence)

- None — all claims verified against source code or official Apple documentation

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — AVAudioPlayer is stable macOS API since 10.7; SPM resources declaration is documented; no third-party libraries needed
- Architecture: HIGH — AudioEngine pattern is drawn from project's own ARCHITECTURE.md + confirmed against current source code; all integration points verified against live Swift files
- Pitfalls: HIGH — AVAudioPlayer deallocation is Apple-documented; SPM resources gap confirmed by reading Package.swift directly; concurrency issues follow same @MainActor pattern already established in project

**Research date:** 2026-03-13
**Valid until:** 2026-09-13 (AVAudioPlayer is stable; SPM resource syntax is stable since tools-version 5.3)
