# Pitfalls Research

**Domain:** macOS menu bar pomodoro timer (Swift/SwiftUI)
**Researched:** 2026-03-13
**Confidence:** HIGH (most pitfalls confirmed via Apple Developer Forums, open-source app issues, and post-mortems)

---

## Critical Pitfalls

### Pitfall 1: Timer Drift — Counting Ticks Instead of Measuring Elapsed Time

**Risk Level:** HIGH

**What goes wrong:** `Timer.scheduledTimer` fires approximately once per second, but is not guaranteed exact. If you decrement a counter on each tick (`timeRemaining -= 1`), any delayed or skipped tick causes permanent drift. After 25 minutes, visible inaccuracy accumulates. Worse: if the display sleeps or the Mac goes to sleep mid-session, the timer stops firing entirely. When the system wakes, it resumes where it left off — 5 minutes of sleep looks like 0 seconds elapsed.

**Warning signs:**
- Timer visibly jumps or lags after a brief screen lock
- Timer shows 24:58 remaining after the Mac woke from a 2-minute nap
- QA finds sessions logging as longer than set duration

**Prevention:**
Record `startDate = Date()` when the session begins. On each tick, compute `timeRemaining = targetDuration - Int(Date().timeIntervalSince(startDate))`. The absolute clock always advances. The Timer is only a display refresh trigger — not the source of truth. Register for `NSWorkspace.didWakeNotification` to force a UI refresh immediately on wake.

```swift
// Wrong — tick-counting
private func tick() { timeRemaining -= 1 }

// Right — clock-based
private func tick() {
    guard let start = startDate else { return }
    timeRemaining = max(0, targetDuration - Int(Date().timeIntervalSince(start)))
}
```

**Phase relevance:** Phase 1 (TimerEngine). This is foundational — get it right before any UI is built on top.

---

### Pitfall 2: NSStatusItem Vanishing Due to Deallocation

**Risk Level:** HIGH

**What goes wrong:** `NSStatusItem` is reference-counted. If you create it inside a method scope (or as a local variable in `applicationDidFinishLaunching`), ARC deallocates it when the method returns. The menu bar icon disappears immediately or within seconds of launch, with no error or crash. Extremely confusing to debug.

**Warning signs:**
- Menu bar icon appears briefly then vanishes
- Icon never appears but no crash is logged
- Bug only manifests on clean launch; debug sessions may differ

**Prevention:**
Store `NSStatusItem` as a `strong` stored property on your `AppDelegate` (or the top-level app class). Never create it in a local scope. Same rule applies if you hold a reference to `NSStatusBar`.

```swift
// Wrong — local scope, ARC kills it
func applicationDidFinishLaunching(_ notification: Notification) {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
}

// Right — stored property on AppDelegate
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }
}
```

**Phase relevance:** Phase 1 / App entry point setup. Covered before any UI work begins.

---

### Pitfall 3: NSPanel Style Mask Set After Initialization

**Risk Level:** HIGH

**What goes wrong:** `NSPanel` uses a window server tag set during `init` to control activation behavior. If you add `.nonactivatingPanel` to the style mask *after* the panel is initialized, the window server tag is not updated. The panel then activates the app (steals focus, brings it to front) when clicked or shown — the opposite of what you want for a floating utility panel. This bug is documented and will not be fixed by Apple.

**Warning signs:**
- Clicking the floating panel steals focus from the user's active app
- Other apps lose keyboard focus unexpectedly when panel appears
- The panel toggles correctly but feels intrusive

**Prevention:**
Pass the full style mask including `.nonactivatingPanel` directly to `NSPanel`'s `init(contentRect:styleMask:backing:defer:)`. Never configure it after the fact. Use `isFloatingPanel = true` in `init` as well.

```swift
// Wrong — setting after init
let panel = NSPanel(...)
panel.styleMask.insert(.nonactivatingPanel) // has no effect

// Right — set in init
let panel = NSPanel(
    contentRect: .zero,
    styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
    backing: .buffered,
    defer: false
)
panel.isFloatingPanel = true
```

**Phase relevance:** Phase 2 / FloatingPanel infrastructure. Build the panel wrapper correctly once; don't retrofit it.

---

### Pitfall 4: AVAudioPlayer Deallocated Silently Mid-Playback

**Risk Level:** HIGH

**What goes wrong:** `AVAudioPlayer` created inside a function scope or as a local `let` is released by ARC the moment the function returns. On some systems, you hear a fraction of audio (buffered data plays briefly), then silence. No error is thrown. There is no delegate callback. The player just stops. This is the single most-reported audio bug in Swift forum posts.

**Warning signs:**
- Audio plays for 0–2 seconds then stops
- No crash, no console error
- Bug disappears if you add a breakpoint (changes timing)

**Prevention:**
Hold `AVAudioPlayer` as a `strong` stored property on `AudioEngine`. Never create it in a method. Set delegate to `nil` explicitly when stopping to prevent a dangling weak pointer.

```swift
// Wrong
func play(sound: Sound) {
    let player = try? AVAudioPlayer(contentsOf: url)
    player?.play() // player dies immediately after this line
}

// Right
final class AudioEngine: ObservableObject {
    private var player: AVAudioPlayer?  // strong property keeps it alive

    func play(sound: Sound) {
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.play()
    }
}
```

**Phase relevance:** Phase 1 / AudioEngine. Test early with an Instruments allocation trace to confirm the player object persists.

---

### Pitfall 5: Settings Window Failing to Open (Activation Policy Trap)

**Risk Level:** HIGH

**What goes wrong:** Menu bar apps run with `NSApplication.ActivationPolicy.accessory` — they have no Dock icon and are not "active" in the macOS sense. `SettingsLink` (SwiftUI's built-in settings trigger) silently fails in this context because it assumes a standard app lifecycle. The settings window either never appears, appears behind other windows, or causes a crash (`App Terminates when using Window and Settings Scene` — confirmed Apple Developer Forums thread). Peter Steinberger documented spending 5 hours on this in 2025.

**Warning signs:**
- Settings window never opens when clicked
- Window appears briefly, then disappears
- App crashes with an uncaught exception when `SettingsLink` is tapped

**Prevention:**
Use `orchetect/SettingsAccess` (proven community workaround) or implement the manual workaround: switch activation policy to `.regular`, `NSApp.activate()`, open the window, then switch back to `.accessory`. Scene declaration order matters: the hidden bridge window must be declared *before* the `Settings` scene in your `@main` struct body.

Alternatively: keep settings inside the floating panel itself (just a few `@AppStorage` number fields) and skip the `Settings` scene entirely. For this app's limited settings surface, that's the cleanest option.

**Phase relevance:** Phase 3 / SettingsView. Decide early: in-panel settings vs. separate Settings window. The latter requires the workaround.

---

## Common Mistakes

### Mistake 1: Logic Inside SwiftUI Views

**What goes wrong:** Putting timer countdown logic, audio start/stop, or session log appending directly in a SwiftUI `View` body or `.onAppear`. SwiftUI recreates views frequently. Timer references go nil, audio stops unexpectedly, sessions double-log.

**Prevention:** All logic in `Engine/` classes. Views observe `@EnvironmentObject` and call methods only. No business logic in view files.

**Phase relevance:** All phases. Enforce the boundary from the first view built.

---

### Mistake 2: Using `NSWindow` Instead of `NSPanel` for Floating Windows

**What goes wrong:** A standard `NSWindow` at `.floating` level lacks panel-specific behavior — it doesn't respect `hidesOnDeactivate`, has wrong animation (`utilityWindow` style), and competes with SwiftUI's `WindowGroup` management. The floating behavior is also inconsistent across Spaces.

**Prevention:** Subclass `NSPanel` with `isFloatingPanel = true`. Set `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` so it appears in fullscreen Spaces too.

**Phase relevance:** Phase 2 / FloatingPanel infrastructure.

---

### Mistake 3: Missing `LSUIElement` — Dock Icon Appears

**What goes wrong:** Without `Application is agent (UIElement) = YES` in Info.plist, the app shows a Dock icon, appears in Cmd+Tab, and behaves like a regular app instead of a menu bar utility. Users also get a second activation path (clicking the Dock icon) with no corresponding window.

**Prevention:** Set `LSUIElement` to `YES` in Info.plist before any testing. Pair with `NSApp.setActivationPolicy(.accessory)` in code as a belt-and-suspenders measure.

**Phase relevance:** Phase 1 / App entry point. Must be set before any UI testing.

---

### Mistake 4: Polling Timer for Countdown Display

**What goes wrong:** Using a 0.01s timer to "smooth" the countdown or check for expiry. Burns CPU every 10ms, prevents the system from sleeping the CPU, drains battery.

**Prevention:** 1-second `Timer.scheduledTimer` is plenty for a seconds-resolution display. The timer is a display refresh trigger only — not the timekeeping mechanism (see Pitfall 1).

**Phase relevance:** Phase 1 / TimerEngine.

---

### Mistake 5: AVAudioPlayer Delegate Left Dangling

**What goes wrong:** `AVAudioPlayer`'s delegate is a weak reference (`assign` in ObjC terms). If the delegate object is deallocated but the player is still alive, calling delegate methods produces a crash or EXC_BAD_ACCESS.

**Prevention:** Set `player.delegate = nil` explicitly before stopping or replacing the player. In `AudioEngine.stop()`, nil the delegate before calling `player?.stop()`.

**Phase relevance:** Phase 1 / AudioEngine.

---

### Mistake 6: Swift 6 Concurrency — Timer Closure Accessing Main Actor State

**What goes wrong:** In Swift 6 strict concurrency (the default in Xcode 26), a `Timer` closure is non-isolated by default. Accessing `@Published` properties or any `@MainActor`-isolated state from inside a `Timer` closure produces a Sendable or actor isolation error. In Xcode 26 / Swift 6.2, these are errors, not warnings.

**Prevention:** Annotate `TimerEngine` (and `AudioEngine`, `SessionStore`) as `@MainActor`. Use `Timer.scheduledTimer` with a `[weak self]` closure, and since the class is `@MainActor`, calls into it from the closure are safe. Alternatively use `MainActor.assumeIsolated {}` inside the closure body.

```swift
// Correct: @MainActor class + weak self capture
@MainActor
final class TimerEngine: ObservableObject {
    private var ticker: Timer?

    func start() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
}
```

**Phase relevance:** Phase 1 / Engine classes. Set `@MainActor` from the start; retrofitting it later breaks callers.

---

### Mistake 7: Audio Files Not Added to "Copy Bundle Resources"

**What goes wrong:** Audio files added to the Xcode project navigator but not checked in Build Phases > Copy Bundle Resources are not bundled in the app. `Bundle.main.url(forResource:withExtension:)` returns nil at runtime. The failure is silent — no crash, just no audio.

**Prevention:** After adding each `.m4a` to the project, immediately verify it appears in Build Phases > Copy Bundle Resources. Add a `precondition` or assertion during development that the URL is non-nil.

```swift
guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else {
    assertionFailure("Audio file '\(name).m4a' not found in bundle — check Copy Bundle Resources")
    return
}
```

**Phase relevance:** Phase 1 / AudioEngine, when adding bundled audio files.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| TimerEngine (Phase 1) | Tick-counting drift; sleep/wake blindness | Clock-based elapsed time; `NSWorkspace.didWakeNotification` |
| TimerEngine (Phase 1) | Swift 6 actor isolation errors on Timer closure | `@MainActor` on all Engine classes from day one |
| App entry point (Phase 1) | Dock icon appears; NSStatusItem disappears | `LSUIElement = YES`; strong stored property for NSStatusItem |
| AudioEngine (Phase 1) | Player deallocated silently; dangling delegate | Strong stored property; nil delegate on stop |
| AudioEngine (Phase 1) | Audio files not found at runtime | Assert non-nil URL; verify Copy Bundle Resources |
| FloatingPanel (Phase 2) | Focus stealing; panel activates main app | `.nonactivatingPanel` in init, not post-init |
| FloatingPanel (Phase 2) | Panel absent from fullscreen Spaces | `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` |
| SettingsView (Phase 3) | `SettingsLink` silent failure | Use in-panel settings or `orchetect/SettingsAccess` |

---

## Sources

- [Behind the Timer: Building a Reliable Pomodoro Countdown in Swift — FocusPasta](https://focuspasta.substack.com/p/behind-the-timer-building-a-reliable) — timer drift and clock-based approach (HIGH confidence, first-person post-mortem)
- [Showing Settings from macOS Menu Bar Items: A 5-Hour Journey — Peter Steinberger](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items) — activation policy and SettingsLink pitfalls (HIGH confidence, 2025 post-mortem)
- [The Curious Case of NSPanel's Nonactivating Style Mask Flag — philz.blog](https://philz.blog/nspanel-nonactivating-style-mask-flag/) — NSPanel init vs post-init style mask bug (HIGH confidence, documents Apple API behavior)
- [Make a floating panel in SwiftUI for macOS — Cindori](https://cindori.com/developer/floating-panel) — NSPanel subclass pattern (MEDIUM confidence)
- [NSStatusItem Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsstatusitem) — retention requirement documented (HIGH confidence)
- [NSWorkspace.didWakeNotification Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification) — sleep/wake notification API (HIGH confidence)
- [Approachable Concurrency in Swift 6.2 — Antoine van der Lee](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/) — Swift 6.2 MainActor patterns (HIGH confidence)
- [Solving "Main actor-isolated property can not be referenced from a Sendable closure" — Donny Wals](https://www.donnywals.com/solving-main-actor-isolated-property-can-not-be-referenced-from-a-sendable-closure-in-swift/) — Swift 6 concurrency fix patterns (HIGH confidence)
- [AVAudioPlayer deallocation — Apple Developer Forums thread](https://developer.apple.com/forums/thread/92672) — silent deallocation behavior (HIGH confidence, Apple forums)
- [App Terminates when using Window and Settings Scene — Apple Developer Forums](https://forums.developer.apple.com/forums/thread/713625) — SettingsLink crash in menu bar apps (HIGH confidence, Apple forums)
- [FB10184971: No way to open settings window from MenuBarExtra-only app — feedback-assistant/reports](https://github.com/feedback-assistant/reports/issues/327) — Apple bug report, unresolved (HIGH confidence)
- [Energy Efficiency Guide for Mac Apps: Minimize Timer Usage — Apple](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html) — timer polling cost (HIGH confidence, Apple docs)
- [How to loop audio using AVAudioPlayer — Hacking with Swift](https://www.hackingwithswift.com/example-code/media/how-to-loop-audio-using-avaudioplayer-and-numberofloops) — numberOfLoops = -1 (HIGH confidence)

---
*Pitfalls research for: macOS menu bar pomodoro timer (Swift/SwiftUI)*
*Researched: 2026-03-13*
