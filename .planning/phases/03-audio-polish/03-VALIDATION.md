---
phase: 3
slug: audio-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (confirmed from `TimerEngineTests.swift`) |
| **Config file** | `Package.swift` — `PomodoroAppTests` target already exists |
| **Quick run command** | `swift build 2>&1` |
| **Full suite command** | `swift test 2>&1` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `swift build 2>&1`
- **After every plan wave:** Run `swift test 2>&1`
- **Before `/gsd:verify-work`:** Full suite must be green + manual smoke checklist
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | AUDO-01/04 | unit | `swift test --filter AudioEngineTests` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | AUDO-01 | manual | Chime plays on work-session end | N/A | ⬜ pending |
| 03-01-03 | 01 | 1 | AUDO-02 | manual | Ambient loops during work session | N/A | ⬜ pending |
| 03-01-04 | 01 | 1 | AUDO-03 | manual | Sound picker visible with 6 sounds | N/A | ⬜ pending |
| 03-01-05 | 01 | 1 | AUDO-03 | manual | Selection persists across restart | N/A | ⬜ pending |
| 03-01-06 | 01 | 1 | AUDO-04 | manual | Ambient stops on pause/stop | N/A | ⬜ pending |
| 03-01-07 | 01 | 1 | AUDO-04 | manual | No overlap at session end | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `PomodoroApp/Engine/AudioEngine.swift` — new file stub
- [ ] `PomodoroApp/Resources/Sounds/` — directory with 7 audio files (6 ambient + 1 chime)
- [ ] `Package.swift` — add `resources: [.process("Resources/")]` to target
- [ ] `PomodoroAppTests/AudioEngineTests.swift` — unit test for UserDefaults persistence

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Chime plays on work-session end | AUDO-01 | Requires audio hardware | Let 1s test session expire; verify chime audible |
| Chime silent on break end | AUDO-01 | Requires audio hardware | Let break expire; verify silence |
| Ambient loops during work | AUDO-02 | Requires audio hardware | Start work; verify ambient plays and loops |
| Sound picker in floating window | AUDO-03 | UI verification | Open panel; verify picker lists 6 sounds |
| Selection persists across restart | AUDO-03 | App lifecycle | Select ocean; quit; relaunch; verify ocean selected |
| Ambient stops on pause/stop | AUDO-04 | Requires audio hardware | Start work + ambient; pause; verify stops |
| No overlap at session end | AUDO-04 | Timing-sensitive audio | Ambient stops before chime; no simultaneous audio |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
