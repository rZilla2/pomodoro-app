# Architecture Research

**Domain:** macOS menu bar timer app (Swift/SwiftUI)
**Researched:** 2026-03-13
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        UI Layer                                  │
├───────────────────────┬─────────────────────────────────────────┤
│  Menu Bar Icon        │  Floating Panel Window                  │
│  (NSStatusItem)       │  (NSPanel subclass)                     │
│  - Countdown text     │  - Timer display                        │
│  - Click to toggle    │  - Start/Pause/Stop/Break controls      │
│                       │  - Sound picker                         │
│                       │  - Always-on-top, draggable             │
└───────────┬───────────┴──────────────┬──────────────────────────┘
            │                          │
            │    (observes state)      │    (sends actions)
            ▼                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TimerEngine (ObservableObject)                │
│  - @Published timerState (idle/running/paused/break)            │
│  - @Published timeRemaining                                     │
│  - @Published currentMode (work/break)                          │
│  - Timer tick logic (Timer.scheduledTimer)                      │
│  - Session lifecycle (start, pause, stop, transition to break)  │
└───────────────────────────┬─────────────────────────────────────┘
                            │
              ┌─────────────┴──────────────┐
              ▼                            ▼
┌─────────────────────────┐  ┌────────────────────────────────────┐
│  AudioEngine            │  │  SessionStore                      │
│  (ObservableObject)     │  │  (ObservableObject)                │
│  - AVAudioPlayer        │  │  - [CompletedSession] today's log  │
│  - numberOfLoops = -1   │  │  - persist to UserDefaults         │
│  - play/stop/swap sound │  │  - append on timer completion      │
│  - bundled audio files  │  │                                    │
└─────────────────────────┘  └────────────────────────────────────┘
                            │
              ┌─────────────┘
              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Persistence Layer                             │
│  - UserDefaults: settings (work duration, break duration)       │
│  - UserDefaults: today's session log (keyed by date)            │
│  No external database needed                                    │
└─────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| App entry point | Declare MenuBarExtra scene, suppress Dock icon | `@main` struct + `LSUIElement = YES` in Info.plist |
| Menu bar icon | Display countdown in status bar; toggle panel | `MenuBarExtra` with `.window` style or NSStatusItem |
| Floating panel | Always-on-top control window | `NSPanel` subclass with `.floating` window level |
| TimerEngine | All timer state and countdown logic | `ObservableObject` with `@Published` properties |
| AudioEngine | Looping ambient sound playback | `ObservableObject` wrapping `AVAudioPlayer` |
| SessionStore | Today's completed session log | `ObservableObject` backed by UserDefaults |
| Settings | Work/break durations, last-used sound | UserDefaults via `@AppStorage` |

---

## Recommended Project Structure

```
PomodoroApp/
├── PomodoroApp.swift          # @main, App scene, MenuBarExtra declaration
├── AppDelegate.swift          # NSApplicationDelegateAdaptor for lifecycle hooks
│
├── Engine/
│   ├── TimerEngine.swift      # Core timer state machine — the heart of the app
│   ├── AudioEngine.swift      # AVAudioPlayer wrapper, sound management
│   └── SessionStore.swift     # Today's completed session log + persistence
│
├── UI/
│   ├── MenuBarView.swift      # Countdown label shown in the menu bar
│   ├── FloatingPanel.swift    # NSPanel subclass + ViewModifier bridge
│   ├── ControlsView.swift     # Start/Pause/Stop/Break buttons + timer face
│   ├── SoundPickerView.swift  # Ambient sound selection row
│   └── SessionLogView.swift   # Simple list of today's sessions
│
├── Settings/
│   └── SettingsView.swift     # Work/break duration inputs (@AppStorage)
│
└── Resources/
    └── Sounds/                # Bundled .mp3/.m4a ambient audio files
        ├── rain.m4a
        ├── ocean.m4a
        ├── forest.m4a
        ├── fireplace.m4a
        ├── whitenoise.m4a
        └── coffeeshop.m4a
```

### Structure Rationale

- **Engine/:** Pure logic with no SwiftUI imports. Testable in isolation. These are the only files that need to be stable before UI work begins.
- **UI/:** SwiftUI views only. Thin — they observe Engine objects and dispatch actions, no business logic lives here.
- **Settings/:** Isolated because `@AppStorage` wrappers are simple but settings behavior (e.g., applying duration mid-session) needs clear rules.
- **Resources/Sounds/:** Bundled assets, not streamed. Keeps audio architecture dead simple.

---

## Architectural Patterns

### Pattern 1: ObservableObject as State Machine

**What:** `TimerEngine` is a single `ObservableObject` that owns all timer state. It exposes `@Published` properties. Views observe it via `@StateObject` (owned at app level) and `@EnvironmentObject` (injected into child views).

**When to use:** Single source of truth for anything that drives multiple UI surfaces (the menu bar icon AND the floating panel both need to display `timeRemaining`).

**Trade-offs:** Simple to reason about. Slightly over-notifies on every tick, but for a timer app updating once per second this is a complete non-issue.

**Example:**
```swift
final class TimerEngine: ObservableObject {
    enum State { case idle, running, paused, onBreak }

    @Published var state: State = .idle
    @Published var timeRemaining: Int = 25 * 60  // seconds

    private var ticker: Timer?

    func start() {
        state = .running
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard timeRemaining > 0 else { transitionToBreak(); return }
        timeRemaining -= 1
    }
}
```

### Pattern 2: NSPanel Subclass for Floating Window

**What:** Create a generic `FloatingPanel<Content: View>` that subclasses `NSPanel`, sets `level = .floating`, and uses `NSHostingView` to embed SwiftUI content. Expose it via a SwiftUI `ViewModifier` so it integrates cleanly with the scene graph.

**When to use:** Required for always-on-top behavior. Pure SwiftUI `Window` scene does not support floating window level without AppKit involvement (except on macOS 15+ with `.windowLevel(.floating)` modifier — use that if targeting 15+ only).

**Trade-offs:** A few dozen lines of AppKit glue code. Unavoidable for this feature. Stable and well-understood pattern.

### Pattern 3: Agent App (No Dock Icon)

**What:** Set `Application is agent (UIElement) = YES` in Info.plist. The app lives only in the menu bar.

**When to use:** Always, for a menu bar utility. Without this, the app shows a Dock icon which looks wrong and clutters the user's Dock.

**Trade-offs:** Losing Dock presence means window management (Cmd+Tab, Expose) requires extra configuration to work correctly. Manage with `NSApp.setActivationPolicy(.accessory)`.

---

## Data Flow

### Timer Tick Flow

```
Timer.scheduledTimer fires every 1s
    ↓
TimerEngine.tick() decrements timeRemaining
    ↓
@Published timeRemaining fires objectWillChange
    ↓
MenuBarView re-renders countdown text
FloatingPanel ControlsView re-renders timer face
    ↓
At timeRemaining == 0:
    TimerEngine fires completion chime (delegates to AudioEngine)
    TimerEngine appends session to SessionStore
    TimerEngine transitions state → .onBreak (auto-starts break timer)
```

### User Action Flow

```
User taps Start in ControlsView
    ↓
TimerEngine.start() called
    ↓
AudioEngine.play(sound: selectedSound) called
    ↓
@Published state changes → .running
    ↓
Both UI surfaces (menu bar + panel) react to new state
```

### Settings Change Flow

```
User edits work duration in SettingsView
    ↓
@AppStorage writes to UserDefaults immediately
    ↓
TimerEngine reads duration from UserDefaults on next start()
    (No live injection — settings take effect on next session start)
```

---

## Build Order (Phase Dependencies)

Build in this order — each layer depends on the one before it.

| Step | Component | Why First |
|------|-----------|-----------|
| 1 | `TimerEngine` | Everything else observes it. No UI dependency. |
| 2 | `SessionStore` | Pure data model. Needed by TimerEngine on completion. |
| 3 | `AudioEngine` | Independent of timer, but needs bundled audio files present. |
| 4 | App entry point + Dock suppression | Must exist before any UI runs. |
| 5 | `FloatingPanel` infrastructure | NSPanel wrapper needed before building views into it. |
| 6 | `ControlsView` + `MenuBarView` | Wire to TimerEngine. Core UX is now usable. |
| 7 | `SoundPickerView` | Wire to AudioEngine. |
| 8 | `SessionLogView` | Wire to SessionStore. |
| 9 | `SettingsView` | Last — depends on @AppStorage shape being stable. |

The minimum shippable slice is steps 1–6 (timer works, sounds play, menu bar shows countdown). Steps 7–9 are complete but not blocking.

---

## Anti-Patterns

### Anti-Pattern 1: Logic in Views

**What people do:** Put timer countdown logic, audio start/stop, or session logging directly inside SwiftUI views.

**Why it's wrong:** Views are recreated frequently. Timer references get lost, audio stops unexpectedly, and testing becomes impossible.

**Do this instead:** All logic lives in Engine objects. Views only call methods and observe state.

### Anti-Pattern 2: Local AVAudioPlayer Variable

**What people do:** Create `AVAudioPlayer` inside a function scope.

**Why it's wrong:** ARC deallocates the player immediately after the function returns, silently killing playback.

**Do this instead:** Hold the player as a strong property on `AudioEngine`. This is documented behavior.

### Anti-Pattern 3: NSWindow Instead of NSPanel for Floating

**What people do:** Use a standard `NSWindow` and try to manage window level manually.

**Why it's wrong:** `NSWindow` at `.floating` level loses focus properly but lacks panel-specific behavior (hidesOnDeactivate, utility window animation). It also fights with SwiftUI's WindowGroup management.

**Do this instead:** Subclass `NSPanel`. Set `isFloatingPanel = true` and `animationBehavior = .utilityWindow`. Use `NSHostingView` to embed SwiftUI.

### Anti-Pattern 4: Polling Timer Instead of Scheduled Timer

**What people do:** Use a 0.1s polling loop to check elapsed time.

**Why it's wrong:** Burns CPU, drain battery, causes drift.

**Do this instead:** Use `Timer.scheduledTimer(withTimeInterval: 1, repeats: true)`. Track absolute start time as a fallback for drift correction if needed.

---

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| TimerEngine → AudioEngine | Method call on completion/stop | TimerEngine does not import audio logic — calls a protocol method or closure |
| TimerEngine → SessionStore | Method call on completion | `sessionStore.append(CompletedSession(date: ..., duration: ...))` |
| Views → TimerEngine | `@EnvironmentObject` | Inject at app root, observe everywhere |
| Views → AudioEngine | `@EnvironmentObject` | Same pattern |
| FloatingPanel ↔ MenuBarView | Shared state via TimerEngine | No direct coupling between the two UI surfaces |

### External Services

None. This app is intentionally local-only.

---

## Scaling Considerations

This is a personal tool, not a multi-user service. Scaling is not a concern. The relevant "scale" question is feature creep:

| Scope | Architecture Holds? | What Would Break First |
|-------|--------------------|-----------------------|
| Current requirements | Yes, cleanly | Nothing |
| + Global keyboard shortcuts | Yes | Add `HotKeyEngine`, wire to TimerEngine |
| + iCloud sync | Stress on SessionStore | Replace UserDefaults with CloudKit-backed store |
| + iOS companion | Engine layer is reusable | UI layer needs full rewrite (different platform) |

---

## Sources

- [Build a macOS menu bar utility in SwiftUI — nil coalescing](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/)
- [Make a floating panel in SwiftUI for macOS — Cindori](https://cindori.com/developer/floating-panel)
- [MenuBarExtra Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/menubarextra)
- [SwiftUI MenuBarExtra limitations (2025) — Peter Steinberger](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items)
- [How to create a SwiftUI floating window in macOS 15 — pol piella dev](https://www.polpiella.dev/creating-a-floating-window-using-swiftui-in-macos-15)
- [How to loop audio using AVAudioPlayer — Hacking with Swift](https://www.hackingwithswift.com/example-code/media/how-to-loop-audio-using-avaudioplayer-and-numberofloops)
- [Pomosh macOS — open-source reference implementation](https://github.com/stevenselcuk/Pomosh-macOS)

---
*Architecture research for: macOS menu bar pomodoro timer (Swift/SwiftUI)*
*Researched: 2026-03-13*
