# Stack Research

**Domain:** macOS menu bar timer app with floating window and ambient audio
**Researched:** 2026-03-13
**Confidence:** HIGH (core stack is Apple-native, no third-party risk)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift | 6.2 (Xcode 26.3) | Primary language | Native macOS, best-in-class AppKit/SwiftUI integration, concurrency model fits timer state management well |
| SwiftUI | macOS 13+ | UI framework | Declarative views for menu popover and floating window content; less boilerplate than UIKit/AppKit for simple layouts |
| AppKit (NSPanel) | macOS 13+ | Floating always-on-top window | SwiftUI `MenuBarExtra` can't produce a true floating panel — requires `NSPanel` subclass with `level = .floating` and `isFloatingPanel = true`. SwiftUI renders into it via `NSHostingView`. |
| AppKit (NSStatusItem) | macOS 13+ | Menu bar icon + countdown label | Direct access to status item button for live text updates (the countdown). `MenuBarExtra` with `.window` style works for popover but NSStatusItem gives finer control over the label. |
| AVFoundation (AVAudioPlayer) | macOS 13+ | Ambient sound looping | Built-in `-1` loop count, simple ObservableObject wrapper, no overhead of AVAudioEngine graph setup. Apple recommends AVAudioPlayer for local file playback. |
| UserDefaults | macOS 13+ | Persisting user preferences | Timer durations and last-used sound setting. Zero external dependency. Not suitable for session log — use a simple JSON file instead. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| MenuBarExtraAccess (orchetect) | 0.0.6+ | Access underlying NSStatusItem/NSWindow from SwiftUI MenuBarExtra | Use if you adopt MenuBarExtra for popover — gives bindings to show/hide state and access to the underlying window. Skip if going full AppKit for status item. |
| No SPM audio libraries needed | — | AVAudioPlayer handles looping natively | Add only if you need crossfade or multiple simultaneous tracks. For this app: unnecessary. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 26.3 | IDE, build, sign, archive | Current stable (Feb 2026). Requires macOS 15.6 Sequoia. |
| SwiftLint | Code quality / style enforcement | Optional but worthwhile for a clean codebase. Add via SPM. |
| Instruments (Xcode) | Memory and audio profiling | Use early to verify AVAudioPlayer doesn't leak on repeated sound switches |

## Installation

This is a native Xcode project — no `npm install`. Setup steps:

```bash
# 1. Create new Xcode project
#    File > New > Project > macOS > App
#    Interface: SwiftUI, Language: Swift

# 2. Set deployment target in project settings
#    Target > General > Minimum Deployments: macOS 13.0

# 3. Set LSUIElement = YES in Info.plist
#    Hides the app from Dock and App Switcher (menu bar only)

# 4. If using MenuBarExtraAccess via SPM:
#    File > Add Package Dependencies
#    https://github.com/orchetect/MenuBarExtraAccess
#    Up To Next Major Version: 0.0.6

# 5. Bundle audio files
#    Add .mp3 or .m4a files to the Xcode project
#    Ensure "Copy Bundle Resources" is checked in Build Phases
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| NSPanel (AppKit) for floating window | SwiftUI MenuBarExtra `.window` style | Use MenuBarExtra if you don't need always-on-top — it's simpler but can't float above all windows including fullscreen spaces |
| AVAudioPlayer | AVAudioEngine | Use AVAudioEngine only if you need crossfade between tracks, real-time effects, or mixing multiple audio streams simultaneously |
| NSStatusItem (manual) | SwiftUI MenuBarExtra | MenuBarExtra is fine for simple menu-only apps; NSStatusItem gives direct control over the countdown text in the status bar icon |
| UserDefaults + JSON file | Core Data | Core Data is heavy for a session log that's just "today's timestamps". A flat JSON file or even AppStorage is plenty. |
| Swift / SwiftUI | Electron / web | Electron adds 200MB runtime, poor menu bar integration, no native audio session control. Ruled out in PROJECT.md. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Electron / Tauri | Overkill runtime for a menu bar app; poor OS-level audio session integration; slower cold start | Native Swift/SwiftUI |
| React Native for macOS | Immature macOS support; menu bar apps require AppKit primitives that RN abstracts badly | Native Swift |
| Core Data | Massive overhead for a list of today's session timestamps; requires migration planning | Array stored as JSON in app support directory |
| AVAudioSession (iOS API) | Does not exist on macOS — iOS-only | AVAudioPlayer directly on macOS needs no session configuration |
| NSUserNotificationCenter | Deprecated since macOS 11 | UserNotifications framework (UNUserNotificationCenter) |
| Swift 5 strict concurrency opt-outs | Produces data race warnings in Xcode 26; will become errors | Mark timer state as @MainActor, use actors for audio state |

## Stack Patterns by Variant

**For the floating window (always-on-top):**
- Subclass `NSPanel` with `isFloatingPanel = true`, `level = .floating`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
- Host SwiftUI content via `NSHostingView`
- Bridge open/close state with a `@Published` bool on your AppDelegate or a shared environment object
- Reference: https://cindori.com/developer/floating-panel

**For the menu bar countdown text:**
- Store `NSStatusItem` on AppDelegate (retain strongly — goes nil if deallocated)
- Update `statusItem.button?.title` from a `@MainActor` timer tick
- Use a template image + title, or title-only with monospaced font for clean alignment

**For ambient audio:**
- Wrap `AVAudioPlayer` in an `@MainActor` class conforming to `ObservableObject`
- `numberOfLoops = -1` for infinite loop
- Load from `Bundle.main.url(forResource:withExtension:)`
- One player instance per sound; stop old player before starting new one

**For session log:**
- Simple `[Date]` array stored as JSON in `FileManager.default.urls(for: .applicationSupportDirectory)`
- Load on launch, append on session complete, show in a `List` in the floating panel
- No migration path needed — purge entries older than 7 days on load

## Version Compatibility

| Component | Minimum macOS | Notes |
|-----------|--------------|-------|
| SwiftUI MenuBarExtra | macOS 13.0 | Introduced WWDC 2022. Window style supported from 13.0. |
| NSPanel floating window | macOS 10.15+ | Long-stable AppKit API, no version concern |
| AVAudioPlayer (local files, looping) | macOS 10.7+ | Completely stable |
| Swift 6.2 (language) | Any — compiler version | Language version set per target; concurrency features compile to all supported OS versions |
| UNUserNotificationCenter (end chime) | macOS 10.14+ | Current standard; NSUserNotificationCenter removed |

**Recommended deployment target: macOS 13.0** — captures MenuBarExtra (modern SwiftUI menu bar API), covers all Apple Silicon Macs and most Intel Macs still in service as of 2026.

## Sources

- https://cindori.com/developer/floating-panel — NSPanel floating window pattern for SwiftUI macOS apps (MEDIUM confidence, well-regarded dev blog)
- https://developer.apple.com/documentation/SwiftUI/MenuBarExtra — Apple official docs, macOS 13.0+ availability (HIGH confidence)
- https://github.com/orchetect/MenuBarExtraAccess — MenuBarExtraAccess library, workaround for MenuBarExtra limitations (MEDIUM confidence)
- https://www.hackingwithswift.com/example-code/media/how-to-loop-audio-using-avaudioplayer-and-numberofloops — AVAudioPlayer looping (HIGH confidence, Apple-backed API)
- https://xcodereleases.com/ — Xcode 26.3 current stable, Swift 6.2, macOS 15.6 required (HIGH confidence)
- https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items — MenuBarExtra SettingsLink limitation (MEDIUM confidence, experienced developer post-mortem)

---
*Stack research for: macOS menu bar pomodoro timer with floating window and ambient audio*
*Researched: 2026-03-13*
