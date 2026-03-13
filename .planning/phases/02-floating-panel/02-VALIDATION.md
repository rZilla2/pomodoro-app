---
phase: 2
slug: floating-panel
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (pending Xcode install) / swift build for compilation checks |
| **Config file** | `Package.swift` — test target exists |
| **Quick run command** | `swift build 2>&1` |
| **Full suite command** | `swift test 2>&1` (blocked until Xcode installed) |
| **Estimated runtime** | ~3 seconds (build only) |

---

## Sampling Rate

- **After every task commit:** `swift build 2>&1` (compilation check)
- **After every plan wave:** `swift build 2>&1` + existing TimerEngine tests if available
- **Before `/gsd:verify-work`:** Full manual smoke checklist
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 2-01-01 | 01 | 1 | UIFP-01 | Manual smoke | Build + launch + verify panel floats | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `PomodoroApp/UI/FloatingPanelWindow.swift` — NSPanel subclass
- [ ] `PomodoroApp/UI/ControlsView.swift` — SwiftUI controls for panel

*No new test framework needed — build check is sufficient for this UI-only phase.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Panel visible above all windows | UIFP-01 | Requires real window manager | Open apps, verify panel floats above |
| Panel visible in fullscreen | UIFP-01 | Requires fullscreen Space | Enter fullscreen app, verify panel persists |
| Controls work from panel | UIFP-01 | Requires running app | Start/pause/stop from panel, verify menu bar updates |
| No focus steal | UIFP-01 | Requires active text input | Type in another app, click panel, verify cursor stays |
| Live timer sync | UIFP-01 | Requires visual comparison | Compare panel and menu bar countdown simultaneously |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Manual smoke tests documented
- [ ] Wave 0 covers all MISSING references
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
