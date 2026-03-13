# Phase 2: Floating Panel - Research

**Researched:** 2026-03-13
**Domain:** NSPanel floating always-on-top window, SwiftUI bridging via NSHostingView, non-activating panel behavior, SPM build context
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| UIFP-01 | User can see and interact with a floating always-on-top window showing timer and controls | NSPanel subclass with `.floating` window level + `.nonactivatingPanel` style mask (set at init); `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` for fullscreen spaces; `NSHostingView` embeds SwiftUI content; panel observes existing `TimerEngine` via `@MainActor` reference |
</phase_requirements>

---

## Summary

Phase 2 adds a floating NSPanel window that stays above all other apps — including fullscreen spaces — and shows the live timer with start/pause/stop/break controls. The timer engine already exists and works. This phase is pure UI infrastructure: create the panel wrapper, wire it to `TimerEngine`, and add a toggle mechanism.

The entire implementation is AppKit (NSPanel subclass) with SwiftUI content hosted via `NSHostingView`. No new frameworks, no third-party libraries. The NSPanel approach is the only correct option for macOS 13 compatibility — the pure SwiftUI `.windowLevel(.floating)` modifier requires macOS 15+ and is therefore out of scope for this project's macOS 13 deployment target.

The single highest-risk item is the `.nonactivatingPanel` style mask flag: it MUST be passed during `NSPanel` initialization, not set afterward. Setting it post-init is a documented AppKit bug — the window server tag is not updated and the panel will steal keyboard focus from whatever app the user is working in.

**Primary recommendation:** Subclass `NSPanel` with the correct init-time flags, host `ControlsView` (a new SwiftUI view) inside it via `NSHostingView`, inject the existing `TimerEngine` as an `@ObservedObject`, and add a toggle button to the existing menu bar popover.

---

## What Phase 1 Built (Current State)

Understanding the existing codebase is essential before adding the panel.

| File | Role | Relevant to Phase 2 |
|------|------|---------------------|
| `PomodoroApp.swift` | `@main` struct, `@NSApplicationDelegateAdaptor`, `Settings { EmptyView() }` scene | Panel must be created and shown from `AppDelegate`, not from a new `Window` scene |
| `AppDelegate.swift` | Owns `NSStatusItem`, `NSPopover`, `TimerEngine`, Combine subscriptions | Panel instance lives here as a stored property; toggle action goes on status item or popover button |
| `TimerEngine.swift` | `@MainActor ObservableObject` with `timerState`, `timeRemaining`, `currentMode`, `start/pause/stop` | Panel's SwiftUI view observes this directly |
| `MenuBarView.swift` | SwiftUI view inside the `NSPopover` — already has start/pause/stop/break controls | May add a "Show Panel" button here, or the controls view can live only in the panel |

The `TimerEngine` instance is created in `AppDelegate.applicationDidFinishLaunching` and stored as `timerEngine`. The panel's SwiftUI content receives a reference to this same instance — no second engine, no duplication.

---

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| AppKit NSPanel | macOS 10.15+ | Floating always-on-top window container | Only macOS-native way to get true floating behavior on macOS 13; NSPanel subclass with `isFloatingPanel = true` and `level = .floating` |
| NSHostingView | macOS 10.15+ | Bridge SwiftUI views into AppKit window | Standard Apple pattern for embedding SwiftUI in NSWindow/NSPanel subclasses |
| SwiftUI | macOS 13+ | Panel content (timer display + controls) | Declarative views that observe TimerEngine via `@ObservedObject` |
| AppKit NSWindowLevel | macOS 10.15+ | `.floating` window level constant | `panel.level = .floating` pins the window above all normal windows |
| NSWindow.CollectionBehavior | macOS 10.15+ | `.canJoinAllSpaces + .fullScreenAuxiliary` | Required for panel to appear above fullscreen apps on other spaces |

### Why NOT Pure SwiftUI WindowLevel

The pure SwiftUI `.windowLevel(.floating)` modifier (`Window { }.windowLevel(.floating)`) requires **macOS 15.0**. This project targets macOS 13.0. NSPanel is the correct choice and is stable AppKit API with no deprecation concerns.

### Alternatives Considered

| Recommended | Alternative | Why Alternative Loses |
|-------------|-------------|----------------------|
| NSPanel subclass | SwiftUI `Window { }.windowLevel(.floating)` | Requires macOS 15+; project deploys to macOS 13 |
| NSPanel subclass | NSWindow at `.floating` level | NSWindow lacks `isFloatingPanel`, `nonactivatingPanel` style mask, and utility window animation; fights SwiftUI's WindowGroup management |
| NSHostingView in NSPanel | NSHostingController as sheet | Sheet presentation doesn't produce floating windows |

---

## Architecture Patterns

### Recommended New Files

```
PomodoroApp/
├── AppDelegate.swift          # ADD: floatingPanel stored property + show/hide logic
├── Engine/
│   └── TimerEngine.swift      # NO CHANGES — already complete
└── UI/
    ├── MenuBarView.swift       # OPTIONAL: add "Show Panel" button
    ├── FloatingPanelWindow.swift  # NEW: NSPanel subclass
    └── ControlsView.swift     # NEW: SwiftUI timer display + controls for the panel
```

### Pattern 1: NSPanel Subclass (FloatingPanelWindow)

**What:** A generic or typed `NSPanel` subclass that sets all required flags at init time and hosts SwiftUI content via `NSHostingView`.

**When to use:** This is the only correct approach for macOS 13+ floating always-on-top windows.

**Critical init-time flags (cannot be set after init):**
- `.nonactivatingPanel` — prevents focus steal; must be in init's style mask
- `isFloatingPanel = true` — must be set in init body before window is shown

```swift
// Source: PITFALLS.md (Pitfall 3) + cindori.com/developer/floating-panel
import AppKit
import SwiftUI

final class FloatingPanelWindow: NSPanel {

    init(timerEngine: TimerEngine) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 200),
            styleMask: [
                .titled,
                .closable,
                .nonactivatingPanel,   // MUST be here — not post-init
                .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )

        // MUST be set in init, before the panel is shown
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false        // panel stays visible when app loses focus
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true

        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        let contentView = ControlsView(timerEngine: timerEngine)
        self.contentView = NSHostingView(rootView: contentView)
    }

    // Allow panel to become key window for button interaction, without activating parent app
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
```

### Pattern 2: Panel Lifecycle in AppDelegate

**What:** `AppDelegate` owns the panel as a stored property (ARC retention). A single `togglePanel()` method shows/hides it.

**When to use:** Panel is created once at launch. Show/hide is cheap — no allocation per toggle.

```swift
// AppDelegate additions
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var timerEngine: TimerEngine?
    private var popover: NSPopover?
    private var floatingPanel: FloatingPanelWindow?   // strong stored property

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ... existing setup ...
        let engine = TimerEngine()
        timerEngine = engine

        floatingPanel = FloatingPanelWindow(timerEngine: engine)
        floatingPanel?.center()   // initial position: screen center
    }

    func showPanel() {
        floatingPanel?.orderFrontRegardless()  // show without activating app
        floatingPanel?.makeKey()
    }

    func hidePanel() {
        floatingPanel?.orderOut(nil)
    }

    func togglePanel() {
        guard let panel = floatingPanel else { return }
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }
}
```

**Key:** `orderFrontRegardless()` brings the panel forward WITHOUT activating the app. `makeKeyAndOrderFront()` would activate the app and potentially disrupt the user's focus.

### Pattern 3: ControlsView (SwiftUI)

**What:** A new SwiftUI view that displays the timer and provides start/pause/stop/break buttons. Observes the injected `TimerEngine`.

**When to use:** This is the floating panel's entire content.

```swift
// Source: Follows existing MenuBarView.swift patterns
import SwiftUI

struct ControlsView: View {
    @ObservedObject var timerEngine: TimerEngine

    var body: some View {
        VStack(spacing: 12) {
            Text(modeLabel)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(formatTime(timerEngine.timeRemaining))
                .font(.system(size: 56, weight: .light, design: .monospaced))
                .monospacedDigit()

            HStack(spacing: 16) {
                if timerEngine.timerState == .idle || timerEngine.timerState == .paused {
                    Button("Start") { timerEngine.start() }
                        .keyboardShortcut(.defaultAction)
                }
                if timerEngine.timerState == .running {
                    Button("Pause") { timerEngine.pause() }
                }
                if timerEngine.timerState == .running || timerEngine.timerState == .paused {
                    Button("Stop") { timerEngine.stop() }
                }
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(minWidth: 220, idealWidth: 240, maxWidth: 300)
    }

    // ... formatTime + modeLabel helpers same as MenuBarView ...
}
```

### Anti-Patterns to Avoid

- **`.nonactivatingPanel` after init:** Has no effect — window server tag is not updated. Always in the `NSPanel.init()` call.
- **`makeKeyAndOrderFront()` to show panel:** Activates the app, disrupts user's active window. Use `orderFrontRegardless()` instead.
- **`floatingPanel` as local variable:** ARC deallocates it immediately. Must be a stored property on `AppDelegate`.
- **New `TimerEngine` instance:** Panel must share the existing engine instance, not create its own. One engine drives both menu bar label and panel display.
- **`WindowGroup` or `Window` scene for panel:** SwiftUI scenes are managed by macOS window controller and cannot be set to `.floating` level on macOS 13.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Floating window that stays above fullscreen spaces | Custom window level management | `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` | These are the exact AppKit flags for this behavior — all other approaches break in edge cases (Stage Manager, different Space, etc.) |
| Non-focus-stealing window | Trying to resign/restore focus manually | `.nonactivatingPanel` in init + `orderFrontRegardless()` | Manual focus management races with the OS; the style mask flag is architecturally correct |
| SwiftUI in AppKit window | Custom rendering or view bridging | `NSHostingView(rootView:)` | Apple's official bridge — handles layout, @State, observation, environment injection correctly |
| Retained panel instance | Re-creating NSPanel on each toggle | Store as `var floatingPanel: FloatingPanelWindow?` on AppDelegate | NSPanel is lightweight to keep alive; re-creation is wasteful and loses window position |

**Key insight:** NSPanel's `nonactivatingPanel` flag and `orderFrontRegardless()` are the entire solution to non-focus-stealing. Any other approach fights the OS window manager.

---

## Common Pitfalls

### Pitfall 1: `.nonactivatingPanel` Set After Init (Critical)

**What goes wrong:** Panel appears but steals keyboard focus from whatever the user is typing in. Clicking the panel activates the pomodoro app, sending the user's front app to the background.

**Why it happens:** `.nonactivatingPanel` is a window server flag set during window creation. Setting `panel.styleMask.insert(.nonactivatingPanel)` after `super.init()` completes has no effect — documented AppKit behavior.

**How to avoid:** Pass the complete style mask to `NSPanel.init(contentRect:styleMask:backing:defer:)`. Never set it afterward.

**Warning signs:** Clicking the floating panel causes other app windows to drop behind it; the Dock icon (if any) flashes active; menu bar changes to the pomodoro app's menus.

Source: [The Curious Case of NSPanel's Nonactivating Style Mask Flag — philz.blog](https://philz.blog/nspanel-nonactivating-style-mask-flag/) (HIGH confidence, documents Apple API behavior)

---

### Pitfall 2: Panel Hidden on App Deactivation

**What goes wrong:** The floating panel disappears whenever the user clicks into another app. This defeats the purpose of a floating panel.

**Why it happens:** `NSPanel.hidesOnDeactivate` defaults to `true`. When the app goes from active to inactive (which happens immediately in an accessory-mode app when user clicks elsewhere), panels with this flag set hide automatically.

**How to avoid:** Set `hidesOnDeactivate = false` in the panel's `init`. Since the app runs in `.accessory` activation policy, it is essentially always "inactive" in the macOS sense — the panel must opt out of the default hide behavior.

**Warning signs:** Panel shows briefly then disappears the moment the user clicks into another app.

---

### Pitfall 3: Panel Absent from Fullscreen Spaces

**What goes wrong:** The floating panel disappears or moves to a different Space when the user enters fullscreen mode in another app.

**Why it happens:** Without `collectionBehavior` configured correctly, macOS parks the panel in its originating Space. Fullscreen apps get their own Space and the panel doesn't follow.

**How to avoid:** `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`. Both flags are required:
- `.canJoinAllSpaces`: panel appears in every Space
- `.fullScreenAuxiliary`: panel overlays fullscreen app Spaces without entering their Space

**Warning signs:** Panel is visible on desktop but disappears when user enters fullscreen mode in another app (e.g., entering fullscreen in a browser).

---

### Pitfall 4: Second TimerEngine Instance

**What goes wrong:** The floating panel's SwiftUI view has its own `@StateObject var timerEngine = TimerEngine()`. The panel's timer display is always stuck at 25:00 and doesn't reflect what the menu bar is counting.

**Why it happens:** `@StateObject` creates and owns a new object instance. The panel's engine is completely independent of the AppDelegate's engine.

**How to avoid:** Inject the existing engine. `NSHostingView` receives the existing instance as a parameter; the panel view uses `@ObservedObject` (not `@StateObject`).

**Warning signs:** Menu bar shows "23:45" but panel shows "25:00"; pressing Start in the panel has no effect on the menu bar label.

---

### Pitfall 5: Panel Close Button Deallocates It

**What goes wrong:** User clicks the panel's close button (red traffic light). The panel closes and cannot be reopened via the toggle — or worse, crashes because the stored reference is dangling.

**Why it happens:** By default, clicking the close button calls `NSWindow.close()` which releases the window. If your code expects the stored `floatingPanel` reference to remain valid, it may now be nil or deallocated.

**How to avoid:** Either (a) disable the close button (`panel.standardWindowButton(.closeButton)?.isHidden = true`) and control visibility only via toggle, or (b) override `windowShouldClose` to call `orderOut(nil)` instead of `close()`, keeping the panel allocated. Option (a) is simpler for this use case.

---

## Code Examples

### Complete FloatingPanelWindow Init

```swift
// Combines all required flags in one place
// Source: PITFALLS.md Pitfall 3 + cindori.com/developer/floating-panel + Apple NSPanel docs
final class FloatingPanelWindow: NSPanel {

    init(timerEngine: TimerEngine) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 200),
            styleMask: [
                .titled,
                .closable,
                .nonactivatingPanel,     // MUST be here at init — cannot be set later
                .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true           // set in init body, before first display
        level = .floating
        hidesOnDeactivate = false        // stay visible when app is inactive
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true

        // Visual polish
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .windowBackgroundColor

        // Hide close button — toggle is the only way to show/hide
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        contentView = NSHostingView(rootView: ControlsView(timerEngine: timerEngine))
    }

    override var canBecomeKey: Bool { true }   // allows button keyboard focus
    override var canBecomeMain: Bool { false }  // does not become main window
}
```

### Show Panel Without Activating App

```swift
// orderFrontRegardless brings window forward without activating the app
// Source: NSWindow documentation — the distinction matters for accessory-mode apps
func showPanel() {
    floatingPanel?.orderFrontRegardless()
}

// DO NOT use this — activates the app, stealing focus from user's active app:
// floatingPanel?.makeKeyAndOrderFront(nil)
```

### Panel Toggle in AppDelegate

```swift
// Call this from menu bar button or popover button
@objc func togglePanel() {
    guard let panel = floatingPanel else { return }
    if panel.isVisible {
        panel.orderOut(nil)
    } else {
        panel.orderFrontRegardless()
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSWindow at `.floating` level | NSPanel subclass with `isFloatingPanel = true` | N/A (both exist) | NSPanel provides correct `nonactivatingPanel` semantics and utility window animation |
| Manual focus management | `.nonactivatingPanel` at init time | Long-standing AppKit behavior | System handles focus correctly without custom code |
| SwiftUI `.windowLevel(.floating)` | N/A for this project (macOS 15+ only) | macOS 15.0 (2024) | Available on macOS 15+ as a pure-SwiftUI alternative, but not applicable here |
| `makeKeyAndOrderFront()` | `orderFrontRegardless()` for non-activating panels | Long-standing AppKit behavior | Correct method for showing panel without activating the app |

**Note on macOS 15+ pure SwiftUI path:** If the deployment target is ever raised to macOS 15+, the NSPanel subclass can be replaced with `Window { ControlsView() }.windowLevel(.floating).windowStyle(.plain)`. Research this change at that time — it is not applicable now.

---

## Open Questions

1. **Toggle trigger: menu bar click vs. popover button vs. both**
   - What we know: The menu bar icon currently toggles the NSPopover. Phase 2 needs a way to show the floating panel.
   - What's unclear: Should the panel be shown by clicking the menu bar icon (replacing the popover), by a button inside the popover, or by a separate mechanism?
   - Recommendation: Add a "Float" button inside the existing `MenuBarView` popover. Keeps the popover for settings/quit; the panel for active use. Simplest change.

2. **Initial panel position**
   - What we know: `floatingPanel?.center()` puts it at the center of the screen. `NSPanel` remembers its position between show/hide (as long as it's not deallocated).
   - What's unclear: Whether to persist position across app restarts (window frame autosave).
   - Recommendation: Call `panel.setFrameAutosaveName("FloatingPanel")` in init. AppKit automatically saves and restores position. Zero-cost feature.

3. **Panel content: duplicate of MenuBarView controls or separate view?**
   - What we know: `MenuBarView` already has start/pause/stop controls. The panel needs the same.
   - What's unclear: Whether to extract shared buttons into a shared `ControlsView` or duplicate the code.
   - Recommendation: Create a standalone `ControlsView.swift` for the panel. It can be larger and more visually prominent than the popover version. The popover keeps its controls for users who prefer that interaction surface.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (via `swift test`) — confirmed in Phase 1 |
| Config file | `Package.swift` — `PomodoroAppTests` target already exists |
| Quick run command | `swift test --filter PomodoroAppTests 2>&1` |
| Full suite command | `swift test 2>&1` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UIFP-01 (panel visible above all windows) | Panel stays above other windows and fullscreen spaces | Manual smoke | Launch app, open two apps, verify panel floats above both; enter fullscreen, verify panel persists | ❌ Wave 0 (manual only) |
| UIFP-01 (start/pause/stop/break from panel) | Tapping controls in panel changes TimerEngine state | Manual smoke | Click Start in panel, verify menu bar label starts counting; click Pause, verify countdown freezes | ❌ Wave 0 (manual only) |
| UIFP-01 (no focus steal) | Clicking panel does not steal focus from active app | Manual smoke | Type in TextEdit, click panel — verify TextEdit cursor remains active | ❌ Wave 0 (manual only) |
| UIFP-01 (live timer sync) | Panel shows same time as menu bar label | Manual smoke | Observe menu bar and panel simultaneously while running | ❌ Wave 0 (manual only) |

**Note:** All UIFP-01 behaviors require a running macOS GUI app with real window management — they cannot be unit tested. These are all manual smoke tests.

Unit tests for `TimerEngine` already exist in `PomodoroAppTests/TimerEngineTests.swift` from Phase 1 and continue to validate that the engine backing both surfaces is correct.

### Sampling Rate

- **Per task commit:** `swift build 2>&1` (build check — ensures no compilation errors)
- **Per wave merge:** `swift test 2>&1` (existing TimerEngine unit tests remain green)
- **Phase gate:** Full manual smoke checklist above passes before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `PomodoroApp/UI/FloatingPanelWindow.swift` — new file, does not exist yet
- [ ] `PomodoroApp/UI/ControlsView.swift` — new file, does not exist yet
- [ ] No new test framework needed — `swift test` already works

---

## Sources

### Primary (HIGH confidence)

- STACK.md (project research) — NSPanel pattern, AppKit/SwiftUI bridging, collection behavior
- ARCHITECTURE.md (project research) — FloatingPanel pattern, NSHostingView, panel lifecycle
- PITFALLS.md (project research) — Pitfall 3 (nonactivatingPanel post-init bug), Pitfall 2 (NSPanel vs NSWindow), Phase 2 specific warnings table
- Existing Phase 1 source code (`AppDelegate.swift`, `TimerEngine.swift`, `PomodoroApp.swift`) — confirmed actual build state
- [NSPanel — Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nspanel) — `isFloatingPanel`, `hidesOnDeactivate`, style mask behavior
- [NSWindow.CollectionBehavior.canJoinAllSpaces — Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces) — all-spaces behavior
- [NSWindow.CollectionBehavior.fullScreenAuxiliary — Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary) — fullscreen overlay behavior
- [NSWindow.StyleMask.nonactivatingPanel — Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel) — non-activating panel flag

### Secondary (MEDIUM confidence)

- [Make a floating panel in SwiftUI for macOS — Cindori](https://cindori.com/developer/floating-panel) — NSPanel subclass pattern, `hidesOnDeactivate`, `orderFrontRegardless` usage
- [Creating a floating window using SwiftUI in macOS 15 — Pol Piella](https://www.polpiella.dev/creating-a-floating-window-using-swiftui-in-macos-15) — confirms `.windowLevel(.floating)` requires macOS 15.0
- [Window visible on all spaces — Apple Developer Forums](https://developer.apple.com/forums/thread/26677) — `canJoinAllSpaces + fullScreenAuxiliary` combination confirmed

### Tertiary (LOW confidence)

- WebSearch results confirming `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]` pattern in community apps — partially verified against Apple docs

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — NSPanel is stable AppKit API, confirmed macOS 13+ compatible; no third-party libraries needed
- Architecture: HIGH — NSHostingView + NSPanel pattern is well-documented and used in multiple production apps; current source code read confirms Phase 1 state accurately
- Pitfalls: HIGH — `.nonactivatingPanel` post-init bug is documented in Apple internals and multiple developer post-mortems; `hidesOnDeactivate` default behavior is documented Apple API behavior

**Research date:** 2026-03-13
**Valid until:** 2026-09-13 (180 days — NSPanel is stable API; no deprecation concerns for macOS 13 target)
