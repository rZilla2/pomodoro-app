# Native macOS Liquid Glass Restyle + Full-Screen Notification

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the Pomodoro app from Tokyo Night custom theme to native macOS Liquid Glass, and add a Dato-style full-screen notification when the timer ends.

**Architecture:** Two-part change. Part 1 replaces all custom UI with native macOS 26 Liquid Glass controls (glass buttons, native Stepper/Picker, traffic light window buttons, system semantic colors). Part 2 adds a full-screen borderless window with Monterey wallpaper background that appears when work sessions end, offering Dismiss/Snooze actions.

**Tech Stack:** Swift 6, SwiftUI, AppKit (NSPanel, NSWindow), macOS 26 Liquid Glass APIs (.glassEffect, .glassProminent, .glass)

**Spec:** `docs/superpowers/specs/2026-03-24-native-macos-restyle-design.md`

---

## File Map

### Part 1: Restyle

| Action | File | Responsibility |
|--------|------|----------------|
| DELETE | `PomodoroApp/UI/Theme.swift` | Custom TokyoNight color enum — replaced by system colors |
| DELETE | `PomodoroApp/UI/SoundPickerView.swift` | Custom sound picker — inlined as native `Picker(.menu)` |
| REWRITE | `PomodoroApp/UI/ControlsView.swift` | Floating panel content: timer, buttons, tray with settings |
| EDIT | `PomodoroApp/UI/MenuBarView.swift` | Menu bar popover: remove TokyoNight refs, native Stepper |
| EDIT | `PomodoroApp/UI/FloatingPanelWindow.swift` | Add traffic light titlebar, fullSizeContentView |
| EDIT | `PomodoroApp/AppDelegate.swift` | Remove hidePanelRequested plumbing |

### Part 2: Full-Screen Notification

| Action | File | Responsibility |
|--------|------|----------------|
| CREATE | `PomodoroApp/UI/FullScreenNotificationWindow.swift` | Borderless NSWindow covering entire screen |
| CREATE | `PomodoroApp/UI/FullScreenNotificationView.swift` | SwiftUI view: wallpaper bg, title, buttons |
| EDIT | `PomodoroApp/Engine/TimerEngine.swift` | Add `.waitingForUser` state, `snooze()`, post notification |
| EDIT | `PomodoroApp/AppDelegate.swift` | Observe `.workSessionComplete`, show/dismiss notification |
| EDIT | `PomodoroAppTests/TimerEngineTests.swift` | Tests for new state, snooze, notification posting |

---

## Task 1: Bump Deployment Target to macOS 26

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Change macOS platform to v26**

Change:
```swift
.macOS(.v13)
```
To:
```swift
.macOS(.v26)
```

This is required for Liquid Glass APIs (`.glassEffect`, `.glassProminent`, `.glass`).

- [ ] **Step 2: Commit**

```bash
git add Package.swift
git commit -m "chore: bump deployment target to macOS 26 for Liquid Glass APIs"
```

---

## Task 2: Delete Custom Theme and Sound Picker

**Files:**
- Delete: `PomodoroApp/UI/Theme.swift`
- Delete: `PomodoroApp/UI/SoundPickerView.swift`

- [ ] **Step 1: Delete Theme.swift**

```bash
rm PomodoroApp/UI/Theme.swift
```

- [ ] **Step 2: Delete SoundPickerView.swift**

```bash
rm PomodoroApp/UI/SoundPickerView.swift
```

- [ ] **Step 3: Commit deletions**

```bash
git rm PomodoroApp/UI/Theme.swift PomodoroApp/UI/SoundPickerView.swift
git commit -m "refactor: delete TokyoNight theme and custom SoundPickerView"
```

> Note: The build will NOT compile after this commit until Task 2 completes. That's expected — these files are prerequisites for the rewrite.

---

## Task 3: Rewrite ControlsView with Native Controls

**Files:**
- Rewrite: `PomodoroApp/UI/ControlsView.swift`

- [ ] **Step 1: Replace ControlsView.swift with native Liquid Glass implementation**

Write the complete file. Key changes from the old version:
- All `TokyoNight.*` color references → `.primary`, `.secondary`, `.tertiary`
- `IconButtonStyle`, `ThemeButtonStyle`, `StepperButtonStyle`, `TrayActionStyle`, `StepperRow` — all deleted
- Buttons use `.buttonStyle(.glassProminent)` / `.buttonStyle(.glass)`
- Custom `StepperRow` → native `Stepper`
- Custom `SoundPickerView` → native `Picker(.menu)` inlined
- Custom X close button overlay → deleted (traffic lights handle close)
- Timer font → `.system(size: 48, weight: .ultraLight)` with `.monospacedDigit()` and `.contentTransition(.numericText())`
- Root view → `.glassEffect(.regular, in: .rect(cornerRadius: 14))`
- `.padding(.top, 28)` for traffic light titlebar clearance

```swift
import SwiftUI

struct ControlsView: View {
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var audioEngine: AudioEngine
    @State private var trayOpen = false

    var body: some View {
        VStack(spacing: 0) {
            // --- Core (always visible) ---
            VStack(spacing: 8) {
                if !modeLabel.isEmpty {
                    Text(modeLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(formatTime(timerEngine.timeRemaining))
                    .font(.system(size: 48, weight: .ultraLight))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                HStack(spacing: 8) {
                    if timerEngine.timerState == .idle
                        || timerEngine.timerState == .paused {
                        Button { timerEngine.start() } label: {
                            Label("Start", systemImage: "play.fill")
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                    }

                    if timerEngine.timerState == .running {
                        Button { timerEngine.pause() } label: {
                            Label("Pause", systemImage: "pause.fill")
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                    }

                    if timerEngine.timerState == .idle
                        || (timerEngine.timerState == .running
                            && timerEngine.currentMode == .work) {
                        Button { timerEngine.startBreak() } label: {
                            Label("Break", systemImage: "cup.and.saucer.fill")
                        }
                        .buttonStyle(.glass)
                    }

                    if timerEngine.canResumeWork
                        && timerEngine.currentMode == .break_ {
                        Button { timerEngine.resumeWork() } label: {
                            Label("Resume", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.glass)
                    }

                    if timerEngine.timerState == .running
                        || timerEngine.timerState == .paused
                        || timerEngine.timerState == .onBreak {
                        Button { timerEngine.stop() } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.glass)
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        trayOpen.toggle()
                    }
                } label: {
                    Image(systemName: trayOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 32, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 28)
            .padding(.horizontal, 18)
            .padding(.bottom, trayOpen ? 8 : 18)

            // --- Tray (toggled) ---
            if trayOpen {
                VStack(spacing: 10) {
                    Divider()

                    Picker(selection: $audioEngine.selectedSound) {
                        ForEach(AmbientSound.allCases) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    } label: {
                        Label("Sound", systemImage: "speaker.wave.2")
                    }
                    .pickerStyle(.menu)

                    Stepper(
                        "Focus: \(timerEngine.workDuration)m",
                        value: $timerEngine.workDuration,
                        in: 5...120, step: 5
                    )
                    .font(.system(size: 12))

                    Stepper(
                        "Break: \(timerEngine.breakDuration)m",
                        value: $timerEngine.breakDuration,
                        in: 1...30, step: 5
                    )
                    .font(.system(size: 12))

                    Divider()

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Quit", systemImage: "power")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: 200)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private var modeLabel: String {
        switch timerEngine.timerState {
        case .idle: return ""
        case .running:
            return timerEngine.currentMode == .work ? "" : "Break"
        case .paused: return "Paused"
        case .onBreak: return "Break"
        case .waitingForUser: return "Time's Up"
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PomodoroApp/UI/ControlsView.swift
git commit -m "refactor: rewrite ControlsView with Liquid Glass native controls"
```

---

## Task 4: Update MenuBarView with System Colors and Native Stepper

**Files:**
- Modify: `PomodoroApp/UI/MenuBarView.swift`

- [ ] **Step 1: Replace MenuBarView.swift contents**

Remove `TokyoNight` and `StepperRow` references. Use native `Stepper`, system colors, and the same timer font as ControlsView.

```swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var timerEngine: TimerEngine

    var body: some View {
        VStack(spacing: 12) {
            Text(modeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formatTime(timerEngine.timeRemaining))
                .font(.system(size: 48, weight: .ultraLight))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            HStack(spacing: 16) {
                if timerEngine.timerState == .idle
                    || timerEngine.timerState == .paused {
                    Button("Start") { timerEngine.start() }
                        .keyboardShortcut(.defaultAction)
                }
                if timerEngine.timerState == .running {
                    Button("Pause") { timerEngine.pause() }
                }
                if timerEngine.timerState == .running
                    || timerEngine.timerState == .paused
                    || timerEngine.timerState == .onBreak {
                    Button("Stop") { timerEngine.stop() }
                }
            }
            .controlSize(.large)

            Divider()

            Stepper(
                "Focus: \(timerEngine.workDuration)m",
                value: $timerEngine.workDuration,
                in: 5...120, step: 5
            )
            Stepper(
                "Break: \(timerEngine.breakDuration)m",
                value: $timerEngine.breakDuration,
                in: 1...30, step: 5
            )

            Divider()

            Button("Toggle Panel") {
                (NSApp.delegate as? AppDelegate)?.togglePanel()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 220)
    }

    private var modeLabel: String {
        switch timerEngine.timerState {
        case .idle: return ""
        case .running:
            return timerEngine.currentMode == .work ? "" : "Break"
        case .paused: return "Paused"
        case .onBreak: return "Break"
        case .waitingForUser: return "Time's Up"
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PomodoroApp/UI/MenuBarView.swift
git commit -m "refactor: MenuBarView uses system colors and native Stepper"
```

---

## Task 5: Add Traffic Lights to FloatingPanelWindow

**Files:**
- Modify: `PomodoroApp/UI/FloatingPanelWindow.swift`

- [ ] **Step 1: Update styleMask and titlebar**

In `FloatingPanelWindow.init`, change the `styleMask` parameter and add titlebar configuration after `super.init`:

Change:
```swift
styleMask: [.nonactivatingPanel],
```
To:
```swift
styleMask: [.titled, .closable,
            .nonactivatingPanel, .fullSizeContentView],
```

Add after `defer: false)`:
```swift
titleVisibility = .hidden
titlebarAppearsTransparent = true
```

- [ ] **Step 2: Commit**

```bash
git add PomodoroApp/UI/FloatingPanelWindow.swift
git commit -m "feat: traffic light window buttons on floating panel"
```

---

## Task 6: Clean Up AppDelegate — Remove hidePanelRequested

**Files:**
- Modify: `PomodoroApp/AppDelegate.swift`

- [ ] **Step 1: Remove hidePanelRequested notification observer**

Delete the `NotificationCenter.default.addObserver(forName: .hidePanelRequested, ...)` block (lines 75-83 in current file).

- [ ] **Step 2: Remove hidePanelAction method**

Delete the `@objc func hidePanelAction()` method (line 156-158). Also remove the call to `hidePanelAction()` in `togglePanel()` — replace with `floatingPanel?.orderOut(nil)` inline.

- [ ] **Step 3: Remove Notification.Name extension**

Delete the `extension Notification.Name` block at the top that defines `.hidePanelRequested`.

- [ ] **Step 4: Add `.waitingForUser` case to `updateStatusTitle()`**

In `updateStatusTitle()`, the `switch engine.timerState` must be exhaustive. Add a case for `.waitingForUser` — show a clock symbol:

In the `switch engine.timerState` block, add:
```swift
case .waitingForUser:
    symbolName = "bell.fill"
```

- [ ] **Step 5: Build and verify**

```bash
cd ~/Projects/pomodoro-app && swift build 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 6: Commit**

```bash
git add PomodoroApp/AppDelegate.swift
git commit -m "refactor: remove hidePanelRequested, handle waitingForUser state"
```

---

## Task 7: Add waitingForUser State and Snooze to TimerEngine

**Files:**
- Modify: `PomodoroApp/Engine/TimerEngine.swift`
- Modify: `PomodoroAppTests/TimerEngineTests.swift`

- [ ] **Step 1: Write failing tests for new behavior**

Add these tests to `PomodoroAppTests/TimerEngineTests.swift`:

```swift
@Test func workSessionPostsNotificationInsteadOfAutoBreak() async throws {
    let engine = TimerEngine(audioEngine: AudioEngine())
    var notificationPosted = false
    let observer = NotificationCenter.default.addObserver(
        forName: .workSessionComplete, object: nil, queue: .main
    ) { _ in notificationPosted = true }
    defer { NotificationCenter.default.removeObserver(observer) }

    engine.startWithDuration(seconds: 1)
    try await Task.sleep(for: .seconds(2))

    #expect(notificationPosted == true)
    #expect(engine.timerState == .waitingForUser)
    engine.stop()
}

@Test func snoozeStartsCountdownWithoutAmbient() {
    let engine = TimerEngine(audioEngine: AudioEngine())
    engine.snooze(minutes: 5)
    #expect(engine.timerState == .running)
    #expect(engine.timeRemaining == 300)
    #expect(engine.currentMode == .work)
    engine.stop()
}

@Test func dismissAfterWorkStartsBreak() async throws {
    let engine = TimerEngine(audioEngine: AudioEngine())
    engine.startWithDuration(seconds: 1)
    try await Task.sleep(for: .seconds(2))
    #expect(engine.timerState == .waitingForUser)
    // Simulate user dismissing — starts break
    engine.startBreak()
    #expect(engine.timerState == .running)
    #expect(engine.currentMode == .break_)
    engine.stop()
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ~/Projects/pomodoro-app && swift test 2>&1 | tail -20
```

Expected: FAIL — `.workSessionComplete` not defined, `.waitingForUser` not defined, `snooze(minutes:)` not defined.

- [ ] **Step 3: Add Notification.Name extension**

At the top of `TimerEngine.swift`, add:

```swift
extension Notification.Name {
    static let workSessionComplete = Notification.Name("workSessionComplete")
}
```

- [ ] **Step 4: Add waitingForUser to TimerState enum**

Change:
```swift
enum TimerState: Sendable { case idle, running, paused, onBreak }
```
To:
```swift
enum TimerState: Sendable { case idle, running, paused, onBreak, waitingForUser }
```

- [ ] **Step 5: Add snooze method**

Add to the public API section:

```swift
func snooze(minutes: Int) {
    ticker?.invalidate()
    ticker = nil
    currentMode = .work
    canResumeWork = false
    targetDuration = minutes * 60
    beginSession()
    // No ambient audio during snooze
}
```

- [ ] **Step 6: Modify handleSessionComplete for work mode**

Replace the work-mode branch in `handleSessionComplete()`:

Change:
```swift
if currentMode == .work {
    // Stop ambient FIRST, then chime — ordering critical (AUDO-04)
    audioEngine.stopAmbient()
    audioEngine.playChime()
    canResumeWork = false
    currentMode = .break_
    targetDuration = breakDuration * 60
    beginSession()
}
```

To:
```swift
if currentMode == .work {
    audioEngine.stopAmbient()
    audioEngine.playChime()
    canResumeWork = false
    timerState = .waitingForUser
    NotificationCenter.default.post(name: .workSessionComplete, object: nil)
}
```

- [ ] **Step 7: Update autoBreakTransition and breakCompletionReturnsToIdle tests**

Both existing tests expect auto-break behavior. Update them to match the new notification-based flow.

**autoBreakTransition:**

```swift
@Test func autoBreakTransition() async throws {
    let engine = TimerEngine(audioEngine: AudioEngine())
    engine.startWithDuration(seconds: 1)
    try await Task.sleep(for: .seconds(2))
    // Work session now waits for user instead of auto-starting break
    #expect(engine.timerState == .waitingForUser)
    // Simulate user dismissing — starts break
    engine.startBreak()
    #expect(engine.currentMode == .break_)
    #expect(engine.timerState == .running)
    engine.stop()
}
```

**breakCompletionReturnsToIdle:** Update to go through waitingForUser first:

```swift
@Test func breakCompletionReturnsToIdle() async throws {
    let engine = TimerEngine(audioEngine: AudioEngine())
    engine.startWithDuration(seconds: 1)
    try await Task.sleep(for: .seconds(2))
    // Now in waitingForUser — simulate dismiss to start break
    #expect(engine.timerState == .waitingForUser)
    engine.startBreakWithDuration(seconds: 1)
    try await Task.sleep(for: .seconds(2))
    #expect(engine.timerState == .idle)
    #expect(engine.currentMode == .work)
}
```

- [ ] **Step 8: Run tests to verify they pass**

```bash
cd ~/Projects/pomodoro-app && swift test 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 9: Commit**

```bash
git add PomodoroApp/Engine/TimerEngine.swift PomodoroAppTests/TimerEngineTests.swift
git commit -m "feat: TimerEngine posts notification on work complete, adds snooze"
```

---

## Task 8: Create Full-Screen Notification Window

**Files:**
- Create: `PomodoroApp/UI/FullScreenNotificationWindow.swift`

- [ ] **Step 1: Write FullScreenNotificationWindow.swift**

```swift
import AppKit
import SwiftUI

@MainActor
final class FullScreenNotificationWindow: NSWindow {

    init(view: some View) {
        guard let screen = NSScreen.main else {
            super.init(
                contentRect: .zero,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            return
        }

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        isMovable = false

        let hosting = NSHostingView(rootView: view)
        hosting.frame = screen.frame
        contentView = hosting
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
```

- [ ] **Step 2: Commit**

```bash
git add PomodoroApp/UI/FullScreenNotificationWindow.swift
git commit -m "feat: FullScreenNotificationWindow — borderless screenSaver-level overlay"
```

---

## Task 9: Create Full-Screen Notification View

**Files:**
- Create: `PomodoroApp/UI/FullScreenNotificationView.swift`

- [ ] **Step 1: Write FullScreenNotificationView.swift**

```swift
import SwiftUI

struct FullScreenNotificationView: View {
    let onDismiss: @MainActor () -> Void
    let onSnooze: @MainActor () -> Void

    private var backgroundImage: NSImage? {
        let path = "/System/Library/Desktop Pictures/.thumbnails/Monterey Graphic Dark.heic"
        return NSImage(contentsOfFile: path)
    }

    var body: some View {
        ZStack {
            // Background — Monterey wallpaper or fallback
            if let image = backgroundImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } else {
                Color(nsColor: NSColor(red: 0.06, green: 0.04, blue: 0.1, alpha: 1))
                    .ignoresSafeArea()
            }

            // Centered content — no card
            VStack(spacing: 0) {
                Image(systemName: "timer")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 28)

                Text("Time's Up")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 10)

                Text("Your focus session has ended.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.bottom, 44)

                HStack(spacing: 14) {
                    Button { onSnooze() } label: {
                        Text("Snooze 5m")
                            .frame(minWidth: 120)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)

                    Button { onDismiss() } label: {
                        Text("Dismiss")
                            .frame(minWidth: 120)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }
                .padding(.bottom, 32)

                HStack(spacing: 4) {
                    KeyboardHint(key: "Return", label: "to snooze")
                    Text("·")
                        .foregroundStyle(.white.opacity(0.2))
                        .font(.system(size: 11))
                    KeyboardHint(key: "Esc", label: "to dismiss")
                }
            }
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress(.return) {
            onSnooze()
            return .handled
        }
    }
}

private struct KeyboardHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.05))
                        .stroke(.white.opacity(0.08), lineWidth: 0.5)
                )
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(.white.opacity(0.2))
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PomodoroApp/UI/FullScreenNotificationView.swift
git commit -m "feat: FullScreenNotificationView — Monterey wallpaper, glass buttons"
```

---

## Task 10: Wire Full-Screen Notification into AppDelegate

**Files:**
- Modify: `PomodoroApp/AppDelegate.swift`

- [ ] **Step 1: Add notification window property**

Add after `var floatingPanel: FloatingPanelWindow?`:

```swift
var notificationWindow: FullScreenNotificationWindow?
```

- [ ] **Step 2: Observe workSessionComplete notification**

In `applicationDidFinishLaunching`, add after the floating panel setup:

```swift
NotificationCenter.default.addObserver(
    forName: .workSessionComplete,
    object: nil,
    queue: .main
) { [weak self] _ in
    Task { @MainActor in
        self?.showFullScreenNotification()
    }
}
```

- [ ] **Step 3: Add show/dismiss methods**

Add these methods to `AppDelegate`:

```swift
// MARK: - Full-Screen Notification

private func showFullScreenNotification() {
    let view = FullScreenNotificationView(
        onDismiss: { [weak self] in
            self?.dismissNotification()
            self?.timerEngine?.startBreak()
        },
        onSnooze: { [weak self] in
            self?.dismissNotification()
            self?.timerEngine?.snooze(minutes: 5)
        }
    )
    let window = FullScreenNotificationWindow(view: view)
    notificationWindow = window
    window.makeKeyAndOrderFront(nil)
}

private func dismissNotification() {
    notificationWindow?.orderOut(nil)
    notificationWindow = nil
}
```

- [ ] **Step 4: Build and verify**

```bash
cd ~/Projects/pomodoro-app && swift build 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 5: Run all tests**

```bash
cd ~/Projects/pomodoro-app && swift test 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add PomodoroApp/AppDelegate.swift
git commit -m "feat: wire full-screen notification into AppDelegate lifecycle"
```

---

## Task 11: Manual Smoke Test

- [ ] **Step 1: Build and run the app**

```bash
cd ~/Projects/pomodoro-app && swift build && .build/debug/PomodoroApp &
```

- [ ] **Step 2: Verify Part 1 — Liquid Glass restyle**

Check:
- [ ] Floating panel has traffic light buttons (red/yellow/green)
- [ ] Timer shows in SF Pro ultraLight font
- [ ] Start/Pause buttons use glass prominent style
- [ ] Break/Stop buttons use glass style
- [ ] Tray expands with native Stepper and Picker controls
- [ ] No Tokyo Night colors visible anywhere

- [ ] **Step 3: Verify Part 2 — Full-screen notification**

- Set Focus duration to 5m (minimum) via the tray stepper
- Click Start, wait for timer to end (or use a short test duration)
- Check:
  - [ ] Full-screen overlay covers entire screen including menu bar
  - [ ] Monterey wallpaper background visible
  - [ ] "Time's Up" text centered
  - [ ] Snooze and Dismiss buttons visible and clickable
  - [ ] ESC key dismisses
  - [ ] Return key snoozes
  - [ ] After dismiss, break timer starts automatically
  - [ ] After snooze, 5-minute countdown starts, notification re-appears when done
