# Project Research Summary

**Project:** pomodoro-app
**Domain:** macOS menu bar Pomodoro timer with floating window and ambient audio
**Researched:** 2026-03-13
**Confidence:** HIGH

## Executive Summary

This is a native macOS menu bar utility — an agent-style app with no Dock icon, a status bar countdown, a floating always-on-top window, and ambient audio looping during focus sessions. The field is crowded (TomatoBar, Session, Be Focused) but none of the major competitors offer bundled ambient sound during sessions. That gap, combined with ADHD-first zero-friction UX, is the primary competitive position. The stack is entirely Apple-native: Swift 6.2 + SwiftUI for views, AppKit NSPanel for the floating window, AVAudioPlayer for looping audio, UserDefaults for settings. No third-party risk; no package manager ceremony; no web runtime.

The recommended architecture centers on a `TimerEngine` ObservableObject as the single source of truth for all timer state. Both UI surfaces (menu bar icon and floating panel) observe the same published state. `AudioEngine` and `SessionStore` are satellite ObservableObjects that react to timer lifecycle events. The entire Engine layer is free of SwiftUI imports and testable in isolation. Views are thin — they observe state and dispatch actions, nothing more.

The highest risks are not architectural — they are AppKit-specific gotchas that cause silent, hard-to-debug failures: timer drift from tick-counting instead of clock-based elapsed time; `NSStatusItem` vanishing due to ARC deallocation; `NSPanel` focus-stealing because `.nonactivatingPanel` was set post-init instead of in the initializer; and `AVAudioPlayer` being silently deallocated mid-playback. All four are preventable with known patterns documented in PITFALLS.md. The Settings window is a known rough edge in menu bar apps — the recommendation is to keep settings inside the floating panel itself and skip the SwiftUI `Settings` scene entirely.

## Key Findings

### Recommended Stack

The stack is fully Apple-native. Swift 6.2 (Xcode 26.3) is required — Swift 6 strict concurrency is the default and opting out produces warnings that become errors. All Engine classes must be `@MainActor` from the start. `MenuBarExtra` (SwiftUI) works for simple popover menus but cannot produce a true always-on-top floating window — that requires a subclassed `NSPanel` with `isFloatingPanel = true` and `level = .floating`, hosting SwiftUI via `NSHostingView`. AVAudioPlayer handles ambient audio looping natively (`numberOfLoops = -1`); no additional audio library is needed. Persistence is UserDefaults for settings and a JSON file (or keyed UserDefaults) for the today-only session log.

**Core technologies:**
- Swift 6.2: Primary language — strict concurrency model, `@MainActor` annotation required throughout
- SwiftUI (macOS 13+): Views, menu bar popover content — declarative, minimal boilerplate
- AppKit NSPanel: Floating always-on-top window — SwiftUI alone cannot achieve this; NSPanel subclass is required
- AppKit NSStatusItem: Menu bar icon + live countdown text — direct control over status bar button label
- AVFoundation AVAudioPlayer: Looping ambient audio — built-in loop support, no extra libraries
- UserDefaults / AppStorage: Settings persistence — sufficient for durations and last-used sound
- UNUserNotificationCenter: End-of-session notification — NSUserNotificationCenter deprecated, do not use

### Expected Features

Research confirmed the core feature set from competitor analysis and ADHD-specific UX patterns.

**Must have (table stakes):**
- Menu bar countdown — the entire reason for the app to exist
- Start / pause / stop controls — non-negotiable basics
- Configurable work and break durations — without this it's a toy
- Auto-transition work → break when timer expires — users should not have to manually switch modes
- End-of-session chime — auditory signal is required when users are heads-down
- Launch at login — menu bar utilities that don't survive reboot feel broken

**Should have (competitive differentiators):**
- Ambient sound playback (rain, ocean, forest, fireplace, white noise, coffee shop) — no competitor offers this; it is the primary differentiator and must ship in v1, not be deferred
- Floating always-on-top window with controls — reduces friction for ADHD users who forget the timer is running
- ADHD-first UX: one click to start, no task entry required — the explicit absence of friction is the design philosophy
- Session log (today only, simple count/list) — lightweight positive reinforcement without becoming analytics

**Defer (v2+):**
- Global keyboard shortcut — requires accessibility permission prompt; add if users request it
- Notification center alert — easy but not required to validate the concept
- Long break auto-trigger after N sessions — adds configuration complexity; let users trigger manually
- Additional ambient sounds — easy to add once the audio pipeline is proven
- Menubar icon styles / themes — scope creep, zero impact on core value

**Anti-features to explicitly avoid:**
- Task / project labeling — adds friction at session start
- Statistics, charts, analytics — becomes a separate product; today's session count is enough
- Cross-device sync / cloud — accounts, networking, server costs; entirely out of scope
- App / website blocking — requires system content filter extension; separate concern

### Architecture Approach

The architecture is a three-engine model: `TimerEngine` as the central state machine, `AudioEngine` and `SessionStore` as satellites that react to timer lifecycle events. All engine classes are `@MainActor`-annotated ObservableObjects injected as `@EnvironmentObject` at the app root. Views observe and call methods — no logic lives in views. The floating panel is an `NSPanel` subclass with SwiftUI content embedded via `NSHostingView`. The menu bar and floating window share state through `TimerEngine` with no direct coupling to each other.

**Major components:**
1. `TimerEngine` — all timer state (idle/running/paused/break), clock-based elapsed time calculation, session lifecycle, delegates completion to AudioEngine and SessionStore
2. `AudioEngine` — AVAudioPlayer wrapper, looping ambient sound, play/stop/swap on timer events; strong stored property to prevent ARC deallocation
3. `SessionStore` — today's completed session log, persisted to UserDefaults, appended on timer completion
4. `FloatingPanel` — NSPanel subclass, `.nonactivatingPanel` in init, `level = .floating`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
5. `MenuBarView` + `ControlsView` + `SoundPickerView` + `SessionLogView` — thin SwiftUI views, observe engines, dispatch actions

### Critical Pitfalls

1. **Timer drift from tick-counting** — use clock-based elapsed time (`Date().timeIntervalSince(startDate)`) not `timeRemaining -= 1`; register for `NSWorkspace.didWakeNotification` to handle sleep/wake; implement this in Phase 1 before any UI
2. **NSStatusItem ARC deallocation** — hold `NSStatusItem` as a `strong` stored property on AppDelegate; never create it in a local scope; icon vanishes silently with no error
3. **NSPanel focus stealing** — pass `.nonactivatingPanel` in `NSPanel`'s init; setting it post-init has no effect (documented Apple API bug); panel will steal keyboard focus from active apps if this is wrong
4. **AVAudioPlayer silent deallocation** — hold the player as a strong property on `AudioEngine`; nil the delegate before stopping; local scope creation produces 0-2 seconds of audio then silence with no error
5. **Settings window silent failure** — `SettingsLink` and the SwiftUI `Settings` scene fail silently in agent-mode apps (`.accessory` activation policy); avoid by embedding settings directly in the floating panel using `@AppStorage` fields

## Implications for Roadmap

Based on research, the dependency graph is clear: TimerEngine is the primitive everything else depends on. Build engines before UI. Build FloatingPanel infrastructure before populating it with views. Settings last (depends on stable `@AppStorage` shape).

### Phase 1: Engine Core

**Rationale:** TimerEngine is the foundation everything observes. AudioEngine and SessionStore are also pure logic with no UI dependency. All three must be solid before UI work begins — and all three have the highest-risk pitfalls that must be addressed here, not retrofitted later.

**Delivers:** A working timer engine, audio looping, and session logging — testable in a Swift playground or with print statements before any UI exists.

**Addresses features:** Timer state machine (work/break/paused/stopped), configurable durations, end chime, ambient sound, session log recording

**Avoids:**
- Timer drift: clock-based elapsed time from day one
- AVAudioPlayer deallocation: strong stored property from day one
- Swift 6 concurrency errors: `@MainActor` on all engine classes from day one
- Audio file not found: assert non-nil URL in AudioEngine, verify Copy Bundle Resources

### Phase 2: App Shell + Menu Bar

**Rationale:** Before building any windows, the app must exist as an agent-mode process with `LSUIElement = YES`, a stable NSStatusItem, and a working menu bar countdown. This is the "skeleton" every subsequent phase attaches to.

**Delivers:** App launches to menu bar only (no Dock icon), countdown text updates live in the status bar, basic start/stop accessible from a menu.

**Addresses features:** Menu bar countdown, launch at login (SMAppService)

**Avoids:**
- Dock icon appearing: `LSUIElement = YES` in Info.plist + `NSApp.setActivationPolicy(.accessory)` set before any UI runs
- NSStatusItem vanishing: strong stored property on AppDelegate

### Phase 3: Floating Panel

**Rationale:** The floating always-on-top window is the primary user interaction surface. It must be built as an NSPanel subclass with correct initialization before any controls are placed inside it. Retrofitting the panel's activation behavior after building views into it is expensive.

**Delivers:** Floating window appears above all other windows including fullscreen Spaces; contains Start/Pause/Stop/Break controls and live timer display; connected to TimerEngine.

**Addresses features:** Floating always-on-top window, start/pause/stop/break controls, ADHD-first one-click start

**Avoids:**
- Focus stealing: `.nonactivatingPanel` in init, not post-init
- Panel absent from fullscreen Spaces: `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
- NSWindow instead of NSPanel: subclass NSPanel from the start

### Phase 4: Audio + Session UI

**Rationale:** AudioEngine exists from Phase 1; this phase wires the sound picker UI and session log view into the floating panel. These are low-complexity additions once the panel infrastructure is in place.

**Delivers:** User can select ambient sound from the floating window before or during a session; session log shows today's completed sessions in the panel.

**Addresses features:** Ambient sound selection in-app (core differentiator), session log display

**Avoids:**
- Ambient sound overlapping end chime: explicit audio coordination — stop ambient before firing chime, don't restart until next session start

### Phase 5: Settings + Polish

**Rationale:** Settings come last because `@AppStorage` keys must be stable — changing them after other phases are built requires migration. This phase also includes launch-at-login (SMAppService), end chime, and any UX polish.

**Delivers:** Configurable work/break durations in the floating panel (not a separate Settings window), launch at login, end chime on session completion, app is shippable.

**Addresses features:** Configurable durations, launch at login, end chime

**Avoids:**
- SettingsLink silent failure: settings live inside the floating panel as `@AppStorage` text fields; no SwiftUI `Settings` scene

### Phase Ordering Rationale

- Engines before UI: all pitfalls in Phase 1 are foundational — timer drift, audio deallocation, Swift 6 concurrency — retrofitting these is expensive
- Shell before windows: `LSUIElement` and NSStatusItem must be correct before any window is tested
- Panel infrastructure before panel content: NSPanel init behavior cannot be changed post-init; get it right once
- Audio/session UI before settings: settings keys should be stable before other features bind to them
- This order produces a working, usable app at the end of Phase 3 (the "minimum shippable slice" identified in ARCHITECTURE.md)

### Research Flags

Phases with standard, well-documented patterns (deeper research not needed):
- **Phase 1 (Engine Core):** All patterns are documented; code examples exist in PITFALLS.md and ARCHITECTURE.md
- **Phase 2 (App Shell):** LSUIElement, NSStatusItem, SMAppService are stable Apple APIs with clear docs
- **Phase 4 (Audio + Session UI):** Straightforward SwiftUI views wiring to existing ObservableObjects

Phases that may benefit from targeted research during planning:
- **Phase 3 (Floating Panel):** NSPanel + SwiftUI on macOS 15 has a newer path (`.windowLevel(.floating)` SwiftUI modifier) — worth checking if deployment target is raised to 15+ during planning; Cindori's floating panel implementation is the reference
- **Phase 5 (Settings):** SMAppService for launch-at-login has subtle sandbox entitlement requirements; verify before implementation

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Entirely Apple-native APIs; official docs + Xcode releases confirm versions |
| Features | HIGH | Broad competitor analysis across 7+ sources; ADHD UX patterns well-documented |
| Architecture | HIGH | Pattern confirmed across multiple open-source menu bar apps and Apple sample code |
| Pitfalls | HIGH | All 5 critical pitfalls confirmed via Apple Developer Forums, first-person post-mortems, and Apple docs |

**Overall confidence:** HIGH

### Gaps to Address

- **Audio file licensing:** Research did not identify specific royalty-free sources for the 6 bundled ambient sounds. Source these before Phase 4 begins. Options: Freesound.org (CC0), Pixabay, or record original audio.
- **macOS 15 floating window shortcut:** On macOS 15+, SwiftUI's `.windowLevel(.floating)` modifier may replace the NSPanel subclass pattern. If the deployment target is raised above 13.0, evaluate this during Phase 3 planning to reduce AppKit glue code.
- **Notarization requirements:** Bundling audio files and using `SMAppService` for launch-at-login requires a valid Apple Developer account and notarization. Not a blocker for development but must be in place before distribution.

## Sources

### Primary (HIGH confidence)
- https://developer.apple.com/documentation/SwiftUI/MenuBarExtra — MenuBarExtra official docs, macOS 13.0+ availability
- https://developer.apple.com/documentation/appkit/nsstatusitem — NSStatusItem retention requirement
- https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification — sleep/wake notification
- https://xcodereleases.com/ — Xcode 26.3, Swift 6.2, macOS 15.6 requirement confirmed
- https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html — timer polling energy cost
- https://forums.developer.apple.com/forums/thread/713625 — SettingsLink crash confirmed in Apple Developer Forums
- https://focuspasta.substack.com/p/behind-the-timer-building-a-reliable — timer drift, clock-based approach (first-person post-mortem)
- https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items — SettingsLink 5-hour post-mortem (2025)
- https://philz.blog/nspanel-nonactivating-style-mask-flag/ — NSPanel post-init style mask bug documented

### Secondary (MEDIUM confidence)
- https://cindori.com/developer/floating-panel — NSPanel floating window pattern (well-regarded dev blog)
- https://github.com/orchetect/MenuBarExtraAccess — MenuBarExtraAccess workaround library
- https://www.hackingwithswift.com/example-code/media/how-to-loop-audio-using-avaudioplayer-and-numberofloops — AVAudioPlayer looping
- https://www.polpiella.dev/creating-a-floating-window-using-swiftui-in-macos-15 — macOS 15 `.windowLevel` alternative
- https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/ — menu bar app structure reference
- https://github.com/stevenselcuk/Pomosh-macOS — open-source Pomodoro reference implementation
- https://zapier.com/blog/best-pomodoro-apps/ — competitor feature analysis
- https://focuskeeper.co/blog/pomodoro-timer-for-adhd-adults — ADHD-specific feature priorities

---
*Research completed: 2026-03-13*
*Ready for roadmap: yes*
