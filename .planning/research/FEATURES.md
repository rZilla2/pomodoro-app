# Feature Research

**Domain:** macOS menu bar pomodoro / focus timer
**Researched:** 2026-03-13
**Confidence:** HIGH — broad competitor coverage, clear category patterns

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Countdown visible in menu bar | Every menu bar timer shows time remaining — it's the whole point | LOW | NSStatusItem title or icon with text |
| Start / pause / stop controls | Non-negotiable basic timer controls | LOW | Menu or floating window |
| Configurable work duration | Default 25 min is wrong for many users; ADHD especially needs flexibility | LOW | Simple number input, not a wizard |
| Configurable break duration | Short break (5m) and long break (15-30m) expected by any Pomodoro user | LOW | Same as work duration — simple inputs |
| Break mode with auto-transition | App should know when to switch from work to break without user intervention | MEDIUM | State machine: work → short break → work → ... → long break |
| End-of-session sound/chime | Users need an auditory signal — critical when they're heads-down | LOW | NSSound or AVAudioPlayer, one bundled chime |
| Notification when timer ends | macOS notification center alert as fallback/supplement to chime | LOW | UNUserNotificationCenter |
| Launch at login | Users set it and forget it — if it's not in the menu bar on boot, it's broken | LOW | SMAppService (macOS 13+) or LoginItems |
| Persistent settings | Timer durations and preferences survive app restarts | LOW | UserDefaults |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Ambient sound playback during sessions | Most competitors offer end chimes only; bundled loopable ambient audio (rain, ocean, fire, coffee shop) is a real differentiator for focus and ADHD | MEDIUM | AVAudioPlayer with looping; needs royalty-free audio bundled in app bundle |
| Floating always-on-top window | Keeps timer visible without having to click the menu bar — reduces friction for ADHD users who forget the timer is running | MEDIUM | NSPanel with .floatingWindowLevel, borderless or minimal chrome |
| ADHD-first UX: zero friction start | One click or keyboard shortcut to start — no task entry, no project selection, no setup required | LOW | Design decision, not a feature per se — but intentional omission of barriers is the differentiator |
| Session log (today's sessions) | Simple "you did 4 sessions today" feedback loop without charts or dashboards — motivating without being a productivity tracker | LOW | In-memory list persisted to UserDefaults or a small JSON file; display in popover |
| Sound selection in-app | Choosing ambient sound before starting keeps the flow unbroken — don't require a settings screen visit | LOW | Sound picker in the floating window or popover |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Task / project labeling | Users want to attribute sessions to work items | Requires naming a task before you start — adds friction at the worst moment; becomes a mini todo app | Session log shows timestamps only; no labels required |
| Statistics, charts, analytics | "How productive was I this week?" feels useful | Becomes the product instead of the timer; invites compulsive checking; violates the minimalism contract | Today's session count is enough; no history beyond today |
| Cross-device sync / cloud | Users want sessions on iPhone too | Adds account system, networking, auth, server costs — completely out of scope for a personal tool | macOS only; zero cloud; zero accounts |
| App / website blocking | Session does this; users of that app love it | Requires system permissions (content filtering extension), dramatically increases complexity and maintenance burden | Separate concern — use Focus Mode (macOS built-in) |
| Global keyboard shortcuts for timer control | Convenient | Requires accessibility permissions, which triggers macOS permission prompts and security friction on first launch | Menu bar click is fast enough; defer to v2 if demanded |
| Gamification (streaks, badges, points) | Engagement mechanic popular in ADHD-adjacent apps | Creates anxiety when streaks break; adds cognitive load; conflicts with "start in 2 seconds" goal | Session count feedback is sufficient positive reinforcement |
| Customizable themes / color schemes | Users like personalization | Scope creep with zero impact on the core value; design time that could ship the timer | Ship with one clean design; don't add theming |
| Long break after N sessions (auto) | True Pomodoro technique includes a long break after 4 pomodoros | Requires session counter logic and yet another configurable, adds UI for "long break interval" | Manual long break is fine — user hits break when they want a longer one |

## Feature Dependencies

```
[Menu bar countdown]
    └──requires──> [Timer state machine (work/break/paused/stopped)]
                       └──requires──> [Configurable durations]

[Floating window]
    └──requires──> [Timer state machine]
    └──enhances──> [Start/pause/stop controls] (controls live here)

[Ambient sound playback]
    └──requires──> [Timer state machine] (play on start, stop on pause/end)
    └──requires──> [Bundled audio files]

[Auto break transition]
    └──requires──> [Timer state machine]
    └──requires──> [Break duration config]

[Session log]
    └──requires──> [Timer state machine] (records on session complete event)

[End chime]
    └──requires──> [Timer state machine] (fires on transition to break/stopped)
    └──conflicts──> [Ambient sound] (need to duck or pause ambient on chime)
```

### Dependency Notes

- **Timer state machine is the core primitive:** Everything else — menu bar display, floating window, sounds, session log, auto-transitions — reads from or reacts to timer state. Build this first, well.
- **Ambient sound conflicts with end chime:** When the session ends, ambient sound must pause/stop before or during the chime, then not restart until a new session starts. Needs explicit audio coordination logic.
- **Floating window requires timer state:** The floating window is a view layer over the state machine — no extra data model needed, just observe the same published state.
- **Session log enhances motivation without requiring any other feature:** It's a passive side effect of timer completions. Cheap to add alongside the state machine.

## MVP Definition

### Launch With (v1)

Minimum viable product — validates the core concept.

- [ ] Menu bar countdown — the whole reason to exist
- [ ] Floating always-on-top window with start/pause/stop/break controls — primary interaction surface
- [ ] Configurable work and break durations — without this it's a toy, not a tool
- [ ] Auto-transition from work to break when timer ends
- [ ] End-of-session chime — auditory signal is table stakes
- [ ] Ambient sound playback (rain, ocean, forest, fireplace, white noise, coffee shop) — core differentiator; include in v1 or the app is indistinguishable from TomatoBar
- [ ] Sound stops on pause/end, doesn't overlap chime
- [ ] Session log (today only, simple list) — lightweight positive reinforcement
- [ ] Launch at login — required for a menu bar utility to feel permanent

### Add After Validation (v1.x)

- [ ] Global keyboard shortcut to start/pause — add if users report reaching for it; gated behind accessibility permission prompt
- [ ] Notification center alert on session end — supplement to chime; easy to add but not needed to validate

### Future Consideration (v2+)

- [ ] Long break auto-trigger after N sessions — true Pomodoro cycle; adds config complexity; defer until users ask
- [ ] Additional ambient sounds — easy to add more audio files once pipeline is proven
- [ ] Menubar icon styles (minimal, tomato, progress arc) — personalization; zero-impact on core value

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Menu bar countdown | HIGH | LOW | P1 |
| Timer state machine (work/break/pause) | HIGH | MEDIUM | P1 |
| Floating window with controls | HIGH | MEDIUM | P1 |
| Configurable durations | HIGH | LOW | P1 |
| End chime | HIGH | LOW | P1 |
| Ambient sounds | HIGH | MEDIUM | P1 |
| Launch at login | HIGH | LOW | P1 |
| Auto work→break transition | HIGH | LOW | P1 |
| Session log (today) | MEDIUM | LOW | P1 |
| Notification center alert | MEDIUM | LOW | P2 |
| Global keyboard shortcut | MEDIUM | MEDIUM | P2 |
| Long break after N sessions | LOW | MEDIUM | P3 |
| Additional ambient sounds | LOW | LOW | P3 |
| Menubar icon styles | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | TomatoBar | Session | Be Focused | Our Approach |
|---------|-----------|---------|------------|--------------|
| Menu bar countdown | Yes | Yes | Yes | Yes — the baseline |
| Configurable durations | Yes | Yes | Yes | Yes |
| Ambient sounds | No (chime only) | No (chime only) | No (chime only) | YES — core differentiator |
| Floating window | No | Yes (dockable) | No | Yes, always-on-top |
| Session log / history | JSON log file | Full analytics + charts | Task-level tracking | Today only, simple list |
| Task / project labels | No | Yes | Yes | No — explicitly excluded |
| App blocking | No | Yes | No | No — explicitly excluded |
| Cloud sync | No | Yes (iOS sync) | Yes (iCloud) | No — explicitly excluded |
| Global hotkey | Yes | Yes | Yes | v2 only |
| ADHD-first UX (zero friction start) | Partial | No (task required) | No | YES — design philosophy |

## Sources

- [TomatoBar GitHub](https://github.com/ivoronin/TomatoBar) — feature inventory, minimalist approach
- [Zapier: 6 best Pomodoro timer apps](https://zapier.com/blog/best-pomodoro-apps/) — market overview
- [Best Pomodoro Apps for Mac — FocusedWork](https://focusedwork.app/blog/best-pomodoro-apps-for-mac) — macOS-specific comparison
- [Best Pomodoro Apps 2026 — Paymo](https://www.paymoapp.com/blog/pomodoro-apps/) — feature landscape
- [Reclaim: Top 11 Pomodoro Timer Apps](https://reclaim.ai/blog/best-pomodoro-timer-apps) — ambient sound / focus feature coverage
- [FocusKeeper: Pomodoro for ADHD](https://focuskeeper.co/blog/pomodoro-timer-for-adhd-adults) — ADHD-specific feature priorities
- [Peachy Timer](https://peachytimer.com/blog/best-timer-apps-mac-2025) — gesture-based UX patterns, friction reduction

---
*Feature research for: macOS pomodoro menu bar app (ADHD-friendly)*
*Researched: 2026-03-13*
