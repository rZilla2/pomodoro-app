# Native macOS Restyle + Full-Screen Notification

**Date:** 2026-03-24
**Status:** Approved
**Deployment Target:** macOS 26 (Tahoe) — required for Liquid Glass APIs

## Summary

Restyle the Pomodoro app from a custom Tokyo Night theme to native macOS Liquid Glass design, and add a full-screen Dato-style notification when the timer ends.

## Part 1: Liquid Glass Restyle

### Design Principles

- All custom colors removed — system semantic colors only (`.primary`, `.secondary`, `.tertiary`)
- All custom button styles removed — native `.glassProminent` and `.glass` button styles
- Native controls replace custom implementations (Stepper, Picker)
- Traffic light window buttons (close/minimize/zoom) replace custom X button
- SF Pro system font throughout, `.ultraLight` weight for countdown
- `.glassEffect(.regular)` on the panel background

### File Changes

#### DELETE: `Theme.swift`
The `TokyoNight` enum is removed entirely. No custom colors anywhere.

#### DELETE: `SoundPickerView.swift`
Inlined into ControlsView as a native `Picker(.menu)`.

#### REWRITE: `ControlsView.swift`

**Timer display:**
```swift
Text(formatTime(timerEngine.timeRemaining))
    .font(.system(size: 48, weight: .ultraLight))
    .monospacedDigit()
    .foregroundStyle(.primary)
    .contentTransition(.numericText())
```

**Action buttons:**
- Primary action (Start, Pause): `.buttonStyle(.glassProminent).controlSize(.large)`
- Secondary action (Break, Stop, Resume): `.buttonStyle(.glass)`
- All buttons use `Label("Name", systemImage: "sf.symbol")` for icon + text
- Tray toggle chevron: `.buttonStyle(.plain)`, `.foregroundStyle(.tertiary)`

**Sound picker (inlined):**
```swift
Picker(selection: $audioEngine.selectedSound) {
    ForEach(AmbientSound.allCases) { sound in
        Text(sound.displayName).tag(sound)
    }
} label: {
    Label("Sound", systemImage: "speaker.wave.2")
}
.pickerStyle(.menu)
```

**Duration steppers:**
```swift
Stepper("Focus: \(timerEngine.workDuration)m",
        value: $timerEngine.workDuration, in: 5...120, step: 5)
Stepper("Break: \(timerEngine.breakDuration)m",
        value: $timerEngine.breakDuration, in: 1...30, step: 5)
```

**Quit button:** `.buttonStyle(.plain)`, `.foregroundStyle(.secondary)`

**Root container:**
```swift
.frame(width: 200)
.glassEffect(.regular, in: .rect(cornerRadius: 14))
```

**Padding:** `.padding(.top, 28)` on core content for traffic light titlebar clearance.

**Removed:** Custom `IconButtonStyle`, `ThemeButtonStyle`, `StepperButtonStyle`, `TrayActionStyle`, `StepperRow`. All deleted.

#### EDIT: `FloatingPanelWindow.swift`

**styleMask change:**
```swift
styleMask: [.titled, .closable, .miniaturizable,
            .nonactivatingPanel, .fullSizeContentView]
```

**Titlebar blending:**
```swift
titleVisibility = .hidden
titlebarAppearsTransparent = true
```

This gives traffic light buttons (red/yellow/green) that blend into the glass panel. The red close button's default NSPanel behavior is `orderOut` (hides the panel), which matches the existing hide behavior.

**Cleanup:** Remove the `hidePanelRequested` notification observer from `AppDelegate` and the custom X button overlay from `ControlsView` — the traffic light close button replaces both.

#### EDIT: `MenuBarView.swift`

- Remove all `TokyoNight` color references
- Replace custom `StepperRow` usage with native `Stepper`
- Timer font: `.system(size: 48, weight: .ultraLight)` with `.monospacedDigit()` and `.contentTransition(.numericText())`
- Text colors: `.foregroundStyle(.primary)`, `.foregroundStyle(.secondary)`

#### EDIT: `AppDelegate.swift`

- Remove `hidePanelRequested` notification observer (traffic light close replaces it)
- Remove `hidePanelAction()` method (no longer needed — NSPanel handles close)
- Add full-screen notification support (see Part 2)

### Build Order

Files must be updated in this order to avoid compilation breaks:
1. Delete `Theme.swift` and `SoundPickerView.swift`
2. Rewrite `ControlsView.swift` (removes `StepperRow`, `IconButtonStyle`, etc.)
3. Edit `MenuBarView.swift` (depends on `StepperRow` being gone)
4. Edit `FloatingPanelWindow.swift`
5. Edit `AppDelegate.swift`

### Files Untouched
- `TimerEngine.swift` — engine logic unchanged for restyle (modified in Part 2)
- `AudioEngine.swift` — audio logic unchanged
- `PomodoroApp.swift` — app entry unchanged

---

## Part 2: Full-Screen Timer Notification

### Behavior

When the timer reaches zero (work session ends), a full-screen overlay appears covering the entire screen including menu bar and Dock. The user can dismiss or snooze.

### Visual Design

- **Background:** macOS Monterey Dark wallpaper loaded from system path `/System/Library/Desktop Pictures/.thumbnails/Monterey Graphic Dark.heic`, scaled to cover full screen. Fallback: dark solid `#0f0a1a`.
- **No card/box** — content floats directly on the wallpaper
- **Centered vertically and horizontally:**
  - SF Symbol timer icon (white, ~56pt)
  - "Time's Up" — SF Pro, 32pt, weight 500, white 90% opacity
  - "Your focus session has ended." — SF Pro, 16pt, weight 400, white 45% opacity
  - Buttons: "Snooze 5m" (`.glassProminent`) + "Dismiss" (`.glass`)
  - Keyboard hint: `Return` to snooze, `Esc` to dismiss — 11pt, white 20% opacity

### TimerEngine Changes

`handleSessionComplete()` currently auto-starts the break when work ends. This must change:

**When work session ends:**
1. Stop ambient audio, play chime (unchanged)
2. Post `Notification.Name.workSessionComplete` instead of auto-starting break
3. Timer enters a new waiting state — NOT idle, NOT running

**AppDelegate** listens for `.workSessionComplete` and shows the full-screen notification.

**On Dismiss:** AppDelegate tells TimerEngine to auto-start break (previous behavior, just deferred).

**On Snooze:** AppDelegate tells TimerEngine to start a 5-minute snooze countdown. When snooze ends, show the notification again. The snooze uses a simple `snooze(minutes:)` method that starts a countdown without ambient audio.

### Implementation

**New file: `FullScreenNotificationWindow.swift`**

```swift
// Borderless window covering entire screen
guard let screen = NSScreen.main else { return }
let window = NSWindow(
    contentRect: screen.frame,  // full frame, covers menu bar + Dock
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)
window.level = .screenSaver           // above everything
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
window.backgroundColor = .black
window.isOpaque = true
window.hasShadow = false
```

**New file: `FullScreenNotificationView.swift`**

SwiftUI view with:
- Background: Monterey Dark wallpaper from `/System/Library/Desktop Pictures/.thumbnails/Monterey Graphic Dark.heic` via `NSImage(contentsOfFile:)`, scaled to fill. Fallback: solid `Color(nsColor: NSColor(red: 0.06, green: 0.04, blue: 0.1, alpha: 1))`.
- No card/box — content floats directly on background
- VStack centered: SF Symbol timer icon (white, 56pt), title, subtitle, glass buttons
- Keyboard: `.onKeyPress(.escape)` dismiss, `.onKeyPress(.return)` snooze

**AppDelegate** holds `var notificationWindow: FullScreenNotificationWindow?` as a strong reference.

### Integration

1. `TimerEngine.handleSessionComplete()` posts `.workSessionComplete` notification (work mode only)
2. `AppDelegate` observes `.workSessionComplete`, creates and shows `FullScreenNotificationWindow`
3. Dismiss callback: close window, call `timerEngine.startBreak()` (existing method)
4. Snooze callback: close window, call `timerEngine.snooze(minutes: 5)` (new method)
5. When snooze timer ends, `TimerEngine` posts `.workSessionComplete` again → notification re-appears

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Return` | Snooze 5m |
| `Esc` | Dismiss |
