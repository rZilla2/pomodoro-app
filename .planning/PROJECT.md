# Pomodoro App

## What This Is

A minimal, ADHD-friendly pomodoro timer for macOS. Lives in the menu bar, shows a countdown in the menu bar icon area and a floating window with controls. Plays ambient sounds (rain, ocean, etc.) during focus sessions. Built as a native Swift/SwiftUI app — clean design, zero clutter, the anti-Session.

## Core Value

Start a focus timer in under 2 seconds with zero friction. Nothing else matters if starting a session feels heavy.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Menu bar app with countdown visible in the menu bar
- [ ] Floating always-on-top window showing timer + start/pause/stop/break controls
- [ ] Configurable timer durations (work and break lengths)
- [ ] Ambient sound playback (rain, ocean, forest, fireplace, white noise, coffee shop) looping during active sessions
- [ ] Basic session log — simple list of today's completed sessions with timestamps
- [ ] Break mode — automatic transition from work to break timer
- [ ] Sound stops when timer stops or break starts

### Out of Scope

- Statistics / analytics / charts — this isn't a productivity tracker
- Task/project management — no labels, categories, or integrations
- Sync / cloud / accounts — local only
- Notifications beyond a simple chime when timer ends
- iOS / cross-platform — macOS only
- Keyboard shortcuts for global control — maybe v2

## Context

- Rod has ADHD — the app must minimize decision points and friction to start
- Session app (inspiration) is good but bloated with features Rod doesn't use
- This is a personal tool, not a commercial product
- SwiftUI + macOS menu bar extra is the natural platform choice
- Ambient sounds need to be royalty-free audio files bundled with the app

## Constraints

- **Platform**: macOS only, SwiftUI, menu bar app (NSStatusItem)
- **Simplicity**: Every feature added must justify its friction cost
- **Audio**: Bundled audio files (not streaming), loopable, royalty-free

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native macOS (Swift/SwiftUI) over Electron/web | Menu bar integration, floating window, system audio — all native. No bloated runtime. | — Pending |
| Bundled audio over streaming | No network dependency, instant playback, simpler architecture | — Pending |
| Configurable durations over fixed 25/5 | Rod wants flexibility, but UI stays simple (just number inputs) | — Pending |

---
*Last updated: 2026-03-13 after initialization*
