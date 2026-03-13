# Requirements: Pomodoro App

**Defined:** 2026-03-13
**Core Value:** Start a focus timer in under 2 seconds with zero friction

## v1 Requirements

### Timer

- [ ] **TIMR-01**: User can see countdown in the macOS menu bar
- [x] **TIMR-02**: User can start, pause, and stop the timer from the floating window
- [x] **TIMR-03**: User can configure work duration (default 25 min)
- [x] **TIMR-04**: User can configure break duration (default 5 min)
- [x] **TIMR-05**: Timer auto-transitions from work to break when work timer ends

### Audio

- [ ] **AUDO-01**: User hears a chime when a session ends
- [ ] **AUDO-02**: User can play ambient sound (rain, ocean, forest, fireplace, white noise, coffee shop) during focus sessions
- [ ] **AUDO-03**: User can select ambient sound from the floating window
- [ ] **AUDO-04**: Ambient sound stops on pause/stop/session end and doesn't overlap chime

### UI

- [ ] **UIFP-01**: User can see and interact with a floating always-on-top window showing timer and controls
- [ ] **UIFP-02**: App launches at login automatically

## v2 Requirements

### Session Tracking

- **SESS-01**: User can see today's completed sessions with timestamps in the floating window

### Controls

- **CTRL-01**: User can start/pause timer via global keyboard shortcut
- **CTRL-02**: User receives a macOS notification when a session ends

## Out of Scope

| Feature | Reason |
|---------|--------|
| Statistics / charts / analytics | Not a productivity tracker — violates simplicity contract |
| Task / project labeling | Adds friction at the worst moment (before starting) |
| Cloud sync / accounts | Local-only personal tool |
| App / website blocking | Separate concern — use macOS Focus Mode |
| Gamification (streaks, badges) | Creates anxiety; conflicts with zero-friction goal |
| Customizable themes | Scope creep with zero impact on core value |
| iOS / cross-platform | macOS only |
| Long break after N sessions | Manual long break is fine — user hits break when they want |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TIMR-01 | Phase 1 | Pending |
| TIMR-02 | Phase 1 | Complete |
| TIMR-03 | Phase 1 | Complete |
| TIMR-04 | Phase 1 | Complete |
| TIMR-05 | Phase 1 | Complete |
| UIFP-02 | Phase 1 | Pending |
| UIFP-01 | Phase 2 | Pending |
| AUDO-01 | Phase 3 | Pending |
| AUDO-02 | Phase 3 | Pending |
| AUDO-03 | Phase 3 | Pending |
| AUDO-04 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0

---
*Requirements defined: 2026-03-13*
*Last updated: 2026-03-13 after roadmap creation*
