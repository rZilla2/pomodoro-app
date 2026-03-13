# Roadmap: Pomodoro App

## Overview

Three phases that build the app from the inside out: a solid engine and menu bar shell first, then the floating window that users actually touch, then the ambient audio that makes it a differentiator. After Phase 3 the app is shippable — one click to start a focused session with rain in the background, countdown in the menu bar, zero friction.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Timer engine + menu bar shell — the invisible core everything else depends on
- [ ] **Phase 2: Floating Panel** - The always-on-top window users actually touch to start, pause, and stop
- [ ] **Phase 3: Audio + Polish** - Ambient sounds, end chime, sound picker — makes the app shippable

## Phase Details

### Phase 1: Foundation
**Goal**: Users can see a live countdown in the menu bar and the timer engine correctly handles work/break cycles with configurable durations
**Depends on**: Nothing (first phase)
**Requirements**: TIMR-01, TIMR-02, TIMR-03, TIMR-04, TIMR-05, UIFP-02
**Success Criteria** (what must be TRUE):
  1. Countdown ticks down live in the macOS menu bar while a session is running
  2. Timer auto-transitions from work to break without user action when work timer ends
  3. Work duration and break duration are configurable and persist across app restarts
  4. App launches at login with no Dock icon — it just appears in the menu bar
  5. Timer uses clock-based elapsed time and survives sleep/wake without drifting
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md — Xcode project scaffold + TimerEngine state machine with unit tests
- [x] 01-02-PLAN.md — Wire live countdown to menu bar, add controls, launch-at-login

### Phase 2: Floating Panel
**Goal**: Users can control the timer from an always-on-top floating window that stays visible above all other apps including fullscreen spaces
**Depends on**: Phase 1
**Requirements**: UIFP-01
**Success Criteria** (what must be TRUE):
  1. Floating window appears above all other windows and fullscreen spaces
  2. User can start, pause, stop, and trigger a break from the floating window
  3. Floating window does not steal keyboard focus from whatever app the user is working in
  4. Window shows the live timer matching the menu bar countdown
**Plans**: 1 plan

Plans:
- [ ] 02-01-PLAN.md — NSPanel floating window with SwiftUI controls, wired to existing TimerEngine

### Phase 3: Audio + Polish
**Goal**: Users can play ambient sound during focus sessions and hear a chime when sessions end — the app is fully shippable
**Depends on**: Phase 2
**Requirements**: AUDO-01, AUDO-02, AUDO-03, AUDO-04
**Success Criteria** (what must be TRUE):
  1. User can select an ambient sound (rain, ocean, forest, fireplace, white noise, coffee shop) from the floating window
  2. Selected ambient sound loops during active focus sessions and stops on pause, stop, or session end
  3. A chime plays when a work session ends without overlapping or mixing with ambient audio
  4. Ambient sound selection persists across sessions (last-used sound remembered)
**Plans**: 1 plan

Plans:
- [ ] 03-01-PLAN.md — AudioEngine + SoundPickerView, wired into TimerEngine lifecycle and floating panel

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 2/2 | Complete | 2026-03-13 |
| 2. Floating Panel | 0/1 | Not started | - |
| 3. Audio + Polish | 0/1 | Not started | - |
