# Phase 1: Foundation - Research

**Researched:** 2026-03-13
**Domain:** macOS menu bar timer engine — Swift/SwiftUI/AppKit, clock-based countdown, launch-at-login, agent-mode app
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TIMR-01 | User can see countdown in the macOS menu bar | NSStatusItem with `button?.title` updated from @MainActor timer tick; strong stored property on AppDelegate prevents ARC deallocation |
| TIMR-02 | User can start, pause, and stop the timer from the floating window | TimerEngine state machine (idle/running/paused/onBreak); floating panel is Phase 1 infrastructure — basic start/stop exposed via menu bar for now |
| TIMR-03 | User can configure work duration (default 25 min) | @AppStorage("workDuration") persists to UserDefaults; TimerEngine reads on start() |
| TIMR-04 | User can configure break duration (default 5 min) | @AppStorage("breakDuration") same pattern |
| TIMR-05 | Timer auto-transitions from work to break when work timer ends | TimerEngine detects timeRemaining == 0, calls transitionToBreak(), resets and starts break countdown |
| UIFP-02 | App launches at login automatically | SMAppService.mainAppService.register() on macOS 13+; requires sandbox entitlement |
</phase_requirements>

---

## Summary

Phase 1 delivers the beating heart of the app: a working timer engine visible in the macOS menu bar, with clock-based elapsed time, auto work-to-break transitions, configurable durations that persist across restarts, and launch-at-login. No floating window yet — that is Phase 2. The menu bar countdown and a bare-minimum menu for start/pause/stop are the interaction surface for this phase.

The entire phase is Apple-native Swift with no third-party dependencies. The three highest-risk problems — timer drift on sleep/wake, NSStatusItem ARC deallocation, and Swift 6 concurrency isolation errors in Timer closures — are all well-understood with verified prevention patterns. They must be addressed from the very first line of code, not retrofitted.

`TimerEngine` is the single most important artifact in the project. Every other component observes it. Getting it right in Phase 1 (clock-based elapsed time, @MainActor isolation, sleep/wake handling) prevents expensive rewrites in every subsequent phase.

**Primary recommendation:** Build TimerEngine first with clock-based elapsed time and @MainActor from day one. Wire NSStatusItem to display the countdown. Add SMAppService for launch-at-login. Settings via @AppStorage in a placeholder panel or menu. Do not touch NSPanel (Phase 2) or audio files (Phase 3).

---

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| Swift | 6.2 (Xcode 26.3) | Primary language | Native macOS; strict concurrency (default in Xcode 26) catches data races at compile time; @MainActor model fits timer state well |
| SwiftUI | macOS 13+ | App scene, menu bar popover content, settings fields | MenuBarExtra (.window style) for the status bar icon integration; @AppStorage for settings; declarative, minimal boilerplate |
| AppKit NSStatusItem | macOS 13+ | Live countdown text in menu bar | Direct control over `button?.title`; MenuBarExtra alone cannot update the status item title dynamically on each tick |
| AppKit NSApplication | macOS 13+ | Activation policy (agent mode) | `NSApp.setActivationPolicy(.accessory)` hides Dock icon and App Switcher presence |
| SMAppService | macOS 13+ | Launch at login | Successor to SMLoginItemSetEnabled; handles sandbox + sandboxless; requires `com.apple.security.app-sandbox` entitlement enabled |
| UserDefaults / @AppStorage | macOS 13+ | Persist work/break durations | Zero external dependency; @AppStorage wraps UserDefaults with SwiftUI binding automatically |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| NSWorkspace.didWakeNotification | macOS 13+ | Force UI refresh after Mac wakes from sleep | Required — subscribe in TimerEngine.start() to handle sleep/wake drift |
| Foundation.Timer | macOS 13+ | Display refresh trigger (1-second interval) | Not the timekeeping source of truth — only drives UI redraws |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NSStatusItem (manual) | SwiftUI MenuBarExtra only | MenuBarExtra alone cannot update the status item title on each tick without MenuBarExtraAccess library; manual NSStatusItem is simpler and more direct for this use case |
| SMAppService | LSSharedFileList / SMLoginItemSetEnabled | Both deprecated; SMAppService is the current standard on macOS 13+ |
| @AppStorage | UserDefaults directly | @AppStorage provides SwiftUI binding automatically; both write to the same store; @AppStorage is preferred inside SwiftUI views |

**No package manager setup required.** All APIs are Apple-native frameworks.

---

## Architecture Patterns

### Recommended Project Structure

```
PomodoroApp/
├── PomodoroApp.swift          # @main, MenuBarExtra scene, environment object injection
├── AppDelegate.swift          # NSApplicationDelegateAdaptor — NSStatusItem stored here
│
├── Engine/
│   ├── TimerEngine.swift      # @MainActor ObservableObject — the entire timer state machine
│   └── SessionStore.swift     # Today's session log (appended on completion)
│
├── UI/
│   └── MenuBarView.swift      # Content of the MenuBarExtra popover (start/stop/durations for now)
│
└── Info.plist                 # LSUIElement = YES — hides Dock icon
```

Phase 1 only builds Engine/ and the app entry point. UI/ is minimal — just enough to expose start/stop and the countdown. FloatingPanel, AudioEngine, SoundPickerView, SessionLogView, and SettingsView are later phases.

### Pattern 1: Clock-Based Elapsed Time (Critical)

**What:** TimerEngine records `startDate = Date()` when a session starts. Each 1-second Timer tick computes `timeRemaining = targetDuration - Int(Date().timeIntervalSince(startDate))`. The Timer is a display refresh trigger only — the clock is the source of truth.

**When to use:** Always. Never use `timeRemaining -= 1`. The clock always advances; Timer ticks do not.

**Example:**
```swift
// Source: PITFALLS.md — clock-based elapsed time pattern
@MainActor
final class TimerEngine: ObservableObject {
    enum State { case idle, running, paused, onBreak }

    @Published var state: State = .idle
    @Published var timeRemaining: Int = 25 * 60

    @AppStorage("workDuration") var workDuration: Int = 25
    @AppStorage("breakDuration") var breakDuration: Int = 5

    private var startDate: Date?
    private var targetDuration: Int = 0
    private var ticker: Timer?

    func start() {
        targetDuration = workDuration * 60
        timeRemaining = targetDuration
        startDate = Date()
        state = .running
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // Subscribe to wake notification to force refresh
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    private func tick() {
        guard let start = startDate else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        timeRemaining = max(0, targetDuration - elapsed)
        if timeRemaining == 0 { transitionToBreak() }
    }

    @objc private func systemDidWake() {
        tick() // Force immediate refresh after wake
    }
}
```

### Pattern 2: NSStatusItem as Strong Stored Property

**What:** `NSStatusItem` is reference-counted. It must live as a stored property on `AppDelegate` or the top-level app class — never in a method scope.

**When to use:** Always. Creating it in a local scope causes it to be deallocated and vanish from the menu bar silently.

**Example:**
```swift
// Source: PITFALLS.md — NSStatusItem retention pattern
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?  // strong stored property

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "25:00"
    }
}
```

### Pattern 3: @MainActor on All Engine Classes

**What:** Annotate `TimerEngine` (and all Engine classes) with `@MainActor`. Swift 6 strict concurrency (default in Xcode 26) treats Timer closures as non-isolated by default. Without `@MainActor` on the class, accessing `@Published` properties from a Timer closure produces compilation errors.

**When to use:** From the very first line of TimerEngine. Cannot be retrofitted cheaply.

**Example:**
```swift
// Source: PITFALLS.md — Swift 6 concurrency pattern
@MainActor
final class TimerEngine: ObservableObject {
    // @Published properties are now main-actor-isolated
    // Timer closure calling self?.tick() is safe
}
```

### Pattern 4: Agent App — No Dock Icon

**What:** Set `LSUIElement = YES` (Application is agent UIElement) in Info.plist AND call `NSApp.setActivationPolicy(.accessory)` in code. Belt-and-suspenders approach.

**When to use:** Phase 1, before any UI testing. Setting it later after seeing the Dock icon appear is fine but wastes time.

**Example:**
```swift
// In AppDelegate.applicationDidFinishLaunching
NSApp.setActivationPolicy(.accessory)
```

```xml
<!-- Info.plist -->
<key>LSUIElement</key>
<true/>
```

### Pattern 5: SMAppService for Launch at Login

**What:** Call `SMAppService.mainAppService.register()` to add the app to Login Items. No UI needed beyond calling the method. Check status with `SMAppService.mainAppService.status`.

**When to use:** Called once on first launch, or when user enables the option. Does not re-register if already registered.

**Example:**
```swift
// Source: Apple Developer Documentation — SMAppService
import ServiceManagement

func enableLaunchAtLogin() {
    do {
        try SMAppService.mainAppService.register()
    } catch {
        print("Failed to register launch at login: \(error)")
    }
}

func disableLaunchAtLogin() {
    do {
        try SMAppService.mainAppService.unregister()
    } catch {
        print("Failed to unregister: \(error)")
    }
}
```

**Entitlement required:** `com.apple.security.app-sandbox` must be enabled in the app entitlements file. Without sandboxing, SMAppService.register() fails silently or throws.

### Anti-Patterns to Avoid

- **Tick-counting (`timeRemaining -= 1`):** Timer fires are not guaranteed exact. Drift accumulates. Sleep/wake breaks the timer. Use clock-based elapsed time instead.
- **Local NSStatusItem variable:** ARC deallocates it; icon vanishes with no error or crash. Always a stored property.
- **Timer closure without @MainActor class:** Swift 6 strict concurrency produces compilation errors when Timer closure touches @Published state on a non-isolated class.
- **Polling timer (< 1 second interval):** Wastes CPU, prevents system sleep, drains battery. 1-second interval is plenty for a seconds-resolution countdown.
- **Logic in SwiftUI views:** Views are recreated frequently. Timer references and state management in views cause subtle bugs. All logic belongs in Engine classes.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Launch at login | Custom plist manipulation or helper app | `SMAppService.mainAppService.register()` | System API handles sandbox entitlements, user permission UI, and system-managed state correctly |
| Sleep/wake detection | Polling Date() in a tight loop | `NSWorkspace.didWakeNotification` | System posts this notification on wake; polling burns CPU and misses exact wake moment |
| Settings persistence | Custom serialization, file I/O, property lists | `@AppStorage` / `UserDefaults` | @AppStorage provides SwiftUI bindings automatically; UserDefaults handles atomic writes and migration |
| Timer accuracy | Compensation math for tick jitter | Clock-based elapsed time (`Date().timeIntervalSince`) | Absolute clock is always accurate; Timer tick compensation math is complex and still breaks on sleep |

**Key insight:** Every "clever" solution to timer reliability ends up being a worse version of just measuring elapsed time against the absolute clock.

---

## Common Pitfalls

### Pitfall 1: Timer Drift and Sleep/Wake Blindness

**What goes wrong:** `timeRemaining -= 1` drifts over time because Timer fires are approximate. Worse: Timer stops firing during sleep. When the Mac wakes, the timer resumes from where it left off — a 20-minute nap looks like 0 seconds elapsed.

**Why it happens:** `Timer.scheduledTimer` is a display refresh aid, not a high-accuracy timekeeping mechanism.

**How to avoid:** Record `startDate = Date()` on session start. Each tick: `timeRemaining = targetDuration - Int(Date().timeIntervalSince(startDate))`. Register for `NSWorkspace.didWakeNotification` to force a tick immediately on wake.

**Warning signs:** Timer shows wrong time after screen lock; QA finds sessions logging as longer than expected.

### Pitfall 2: NSStatusItem Vanishing

**What goes wrong:** Menu bar icon appears briefly then disappears. No crash, no log entry.

**Why it happens:** ARC deallocates `NSStatusItem` when the method that created it returns.

**How to avoid:** Store it as `var statusItem: NSStatusItem?` on AppDelegate. Never create in a local scope.

**Warning signs:** Icon appears at launch for < 1 second then disappears; doesn't happen in debug sessions (timing differs).

### Pitfall 3: Swift 6 Concurrency Errors in Timer Closure

**What goes wrong:** Compilation error: "Main actor-isolated property can not be referenced from a Sendable closure" — or similar. Xcode 26 / Swift 6.2 treats these as errors, not warnings.

**Why it happens:** Timer closures are non-isolated by default. Accessing @Published state from a non-isolated closure violates Swift 6 actor isolation rules.

**How to avoid:** Annotate the engine class `@MainActor`. Timer closure calling `self?.tick()` is safe because the class is main-actor-isolated.

**Warning signs:** Build fails immediately after adding Timer logic; error references Sendable or actor isolation.

### Pitfall 4: SMAppService Failing Silently Without Sandbox

**What goes wrong:** `SMAppService.mainAppService.register()` throws or does nothing. App does not appear in Login Items.

**Why it happens:** SMAppService requires the app sandbox entitlement to be enabled. Without it, the call fails.

**How to avoid:** Enable the App Sandbox capability in Xcode before calling SMAppService. Check `SMAppService.mainAppService.status` to confirm registration.

**Warning signs:** No error in console but app doesn't appear in System Settings > General > Login Items; `status` returns `.notRegistered` after calling `register()`.

### Pitfall 5: Dock Icon Appearing

**What goes wrong:** App shows a Dock icon and appears in Cmd+Tab, looking like a standard app.

**Why it happens:** `LSUIElement` not set in Info.plist, or `setActivationPolicy` not called before UI runs.

**How to avoid:** Set `LSUIElement = YES` in Info.plist immediately when creating the Xcode project. Add `NSApp.setActivationPolicy(.accessory)` in `applicationDidFinishLaunching`.

**Warning signs:** Dock icon appears on first launch.

---

## Code Examples

Verified patterns from research:

### Timer State Machine Shell

```swift
// Source: ARCHITECTURE.md + PITFALLS.md — verified pattern
@MainActor
final class TimerEngine: ObservableObject {
    enum TimerState { case idle, running, paused, onBreak }

    @Published var timerState: TimerState = .idle
    @Published var timeRemaining: Int = 25 * 60
    @Published var currentMode: Mode = .work

    enum Mode { case work, break_ }

    @AppStorage("workDuration") var workDuration: Int = 25
    @AppStorage("breakDuration") var breakDuration: Int = 5

    private var startDate: Date?
    private var targetDuration: Int = 0
    private var ticker: Timer?

    func start() {
        targetDuration = (currentMode == .work ? workDuration : breakDuration) * 60
        startDate = Date()
        timerState = .running
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(onWake),
                                               name: NSWorkspace.didWakeNotification, object: nil)
    }

    func pause() {
        ticker?.invalidate()
        ticker = nil
        timerState = .paused
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        startDate = nil
        currentMode = .work
        timeRemaining = workDuration * 60
        timerState = .idle
    }

    private func tick() {
        guard let start = startDate else { return }
        timeRemaining = max(0, targetDuration - Int(Date().timeIntervalSince(start)))
        if timeRemaining == 0 { handleSessionComplete() }
    }

    @objc private func onWake() { tick() }

    private func handleSessionComplete() {
        ticker?.invalidate()
        ticker = nil
        if currentMode == .work {
            currentMode = .break_
            // auto-start break
            start()
        } else {
            currentMode = .work
            timeRemaining = workDuration * 60
            timerState = .idle
        }
    }
}
```

### NSStatusItem — Live Countdown Update

```swift
// Source: STACK.md + PITFALLS.md — NSStatusItem stored property pattern
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var timerEngine: TimerEngine!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "▶ 25:00"
    }
}

// To update the countdown text from TimerEngine observation:
// In MenuBarView or via Combine sink:
func formatTime(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%02d:%02d", m, s)
}
```

### @AppStorage Settings

```swift
// Source: ARCHITECTURE.md — settings persistence pattern
// These live in TimerEngine or a SettingsView — same UserDefaults key, same value
@AppStorage("workDuration") var workDuration: Int = 25   // minutes
@AppStorage("breakDuration") var breakDuration: Int = 5  // minutes
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SMLoginItemSetEnabled | SMAppService | macOS 13.0 (2022) | Old API deprecated; SMAppService handles sandboxed and non-sandboxed apps cleanly |
| NSUserNotificationCenter | UNUserNotificationCenter | macOS 11 | Old API removed entirely; must use UserNotifications framework |
| Swift 5 concurrency opt-outs | @MainActor required (errors, not warnings) | Xcode 26 / Swift 6.2 | Cannot ignore concurrency warnings; must annotate from day one |

**Deprecated/outdated:**
- `SMLoginItemSetEnabled`: Deprecated macOS 13, use `SMAppService`
- `NSUserNotificationCenter`: Removed macOS 11, use `UNUserNotificationCenter`
- Swift 5 `nonisolated` workarounds: Produce errors in Swift 6.2 strict mode

---

## Open Questions

1. **MenuBarExtra vs. NSStatusItem for countdown display**
   - What we know: MenuBarExtra with `.window` style gives SwiftUI integration but `MenuBarExtraAccess` library is needed to update the status item title dynamically on each tick; pure NSStatusItem is simpler and fully direct
   - What's unclear: Whether the plan should use MenuBarExtra + MenuBarExtraAccess or pure NSStatusItem — both work; the question is code simplicity
   - Recommendation: Use pure NSStatusItem for Phase 1 (direct `button?.title` update, no library needed); if the planner wants MenuBarExtra, add MenuBarExtraAccess via SPM

2. **SMAppService timing — first launch vs. explicit user action**
   - What we know: SMAppService.register() should be called once; calling it on every launch is safe (idempotent for already-registered apps) but unnecessary
   - What's unclear: Whether Phase 1 should auto-enable launch-at-login on first launch or expose it as a toggle
   - Recommendation: Auto-register on first launch (zero-friction, ADHD goal); no toggle needed in Phase 1

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (built into Xcode — no separate install) |
| Config file | None yet — created when Xcode project is created in Wave 0 |
| Quick run command | `xcodebuild test -scheme PomodoroApp -destination 'platform=macOS' -testPlan UnitTests 2>&1 \| xcpretty` |
| Full suite command | Same as quick (no integration tests in Phase 1) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TIMR-01 | NSStatusItem button title updates on tick | Manual smoke | Build and observe menu bar | ❌ Wave 0 |
| TIMR-02 | Start/pause/stop transitions state correctly | Unit | `xcodebuild test -only-testing PomodoroAppTests/TimerEngineTests` | ❌ Wave 0 |
| TIMR-03 | Work duration persists across launch | Unit | `xcodebuild test -only-testing PomodoroAppTests/TimerEngineTests/testWorkDurationPersists` | ❌ Wave 0 |
| TIMR-04 | Break duration persists across launch | Unit | `xcodebuild test -only-testing PomodoroAppTests/TimerEngineTests/testBreakDurationPersists` | ❌ Wave 0 |
| TIMR-05 | Work timer auto-transitions to break at zero | Unit | `xcodebuild test -only-testing PomodoroAppTests/TimerEngineTests/testAutoBreakTransition` | ❌ Wave 0 |
| UIFP-02 | App appears in Login Items after register | Manual smoke | Check System Settings > General > Login Items after launch | ❌ Wave 0 (manual only) |

**Note on TIMR-01 and UIFP-02:** These require a running macOS app with UI — they are manual smoke tests, not unit tests. All timer state machine tests (TIMR-02 through TIMR-05) are fully unit-testable against TimerEngine in isolation.

### Sampling Rate

- **Per task commit:** `xcodebuild build -scheme PomodoroApp -destination 'platform=macOS'` (build check only until test target exists)
- **Per wave merge:** Full unit test suite on TimerEngine
- **Phase gate:** All TimerEngine unit tests green + manual smoke of menu bar countdown + manual smoke of launch at login before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `PomodoroApp.xcodeproj` — Xcode project does not exist; must be created first
- [ ] `PomodoroAppTests/TimerEngineTests.swift` — covers TIMR-02, TIMR-03, TIMR-04, TIMR-05
- [ ] Test scheme with unit test target — created alongside Xcode project
- [ ] Framework install: XCTest is built-in — no install needed; test target added in Xcode project creation

---

## Sources

### Primary (HIGH confidence)

- STACK.md (project research) — Swift 6.2/Xcode 26.3 versions, NSStatusItem pattern, SMAppService, AVAudioPlayer
- ARCHITECTURE.md (project research) — TimerEngine ObservableObject pattern, project structure, build order
- PITFALLS.md (project research) — Clock-based elapsed time, NSStatusItem ARC deallocation, Swift 6 @MainActor pattern, NSWorkspace.didWakeNotification
- SUMMARY.md (project research) — Phase ordering rationale, critical pitfalls summary
- https://developer.apple.com/documentation/appkit/nsstatusitem — NSStatusItem retention requirement
- https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification — sleep/wake notification API
- https://developer.apple.com/documentation/servicemanagement/smappservice — SMAppService launch at login
- https://focuspasta.substack.com/p/behind-the-timer-building-a-reliable — clock-based timer, first-person post-mortem

### Secondary (MEDIUM confidence)

- https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/ — menu bar app structure
- https://xcodereleases.com/ — Xcode 26.3, Swift 6.2 version confirmation
- https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/ — Swift 6.2 @MainActor patterns

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — entirely Apple-native APIs; no third-party risk; Xcode version confirmed
- Architecture: HIGH — TimerEngine pattern confirmed across multiple open-source macOS timer apps and official docs
- Pitfalls: HIGH — all critical pitfalls confirmed via Apple Developer Forums, first-person post-mortems, and Apple documentation

**Research date:** 2026-03-13
**Valid until:** 2026-09-13 (180 days — Apple APIs are stable; Swift 6.2 patterns are current)
