---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built into Xcode — no separate install) |
| **Config file** | None yet — created when Xcode project is created in Wave 0 |
| **Quick run command** | `xcodebuild test -scheme PomodoroApp -destination 'platform=macOS' -testPlan UnitTests 2>&1 \| xcpretty` |
| **Full suite command** | Same as quick (no integration tests in Phase 1) |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** `xcodebuild build -scheme PomodoroApp -destination 'platform=macOS'` (build check)
- **After every plan wave:** Full unit test suite on TimerEngine
- **Before `/gsd:verify-work`:** All TimerEngine unit tests green + manual smoke of menu bar countdown + manual smoke of launch at login
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | TIMR-01 | Manual smoke | Build and observe menu bar | ❌ W0 | ⬜ pending |
| 1-01-02 | 01 | 1 | TIMR-02 | Unit | `xcodebuild test -only-testing PomodoroAppTests/TimerEngineTests` | ❌ W0 | ⬜ pending |
| 1-01-03 | 01 | 1 | TIMR-03 | Unit | `xcodebuild test -only-testing PomodoroAppTests/TimerEngineTests/testWorkDurationPersists` | ❌ W0 | ⬜ pending |
| 1-01-04 | 01 | 1 | TIMR-04 | Unit | `xcodebuild test -only-testing PomodoroAppTests/TimerEngineTests/testBreakDurationPersists` | ❌ W0 | ⬜ pending |
| 1-01-05 | 01 | 1 | TIMR-05 | Unit | `xcodebuild test -only-testing PomodoroAppTests/TimerEngineTests/testAutoBreakTransition` | ❌ W0 | ⬜ pending |
| 1-01-06 | 01 | 1 | UIFP-02 | Manual smoke | Check System Settings > General > Login Items | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `PomodoroApp.xcodeproj` — Xcode project with macOS app target
- [ ] `PomodoroAppTests/TimerEngineTests.swift` — covers TIMR-02, TIMR-03, TIMR-04, TIMR-05
- [ ] Test scheme with unit test target

*XCTest is built-in — no framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Menu bar countdown updates live | TIMR-01 | Requires running macOS app with NSStatusItem UI | Build, launch, start timer, verify countdown ticks in menu bar |
| App appears in Login Items | UIFP-02 | Requires System Settings inspection | Launch app, check System Settings > General > Login Items |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
