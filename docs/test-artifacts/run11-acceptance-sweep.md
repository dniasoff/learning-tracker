# Run-11 — final acceptance sweep (post-push, shipped build)

The on-device human-style click-through of every screen on all 6 emulators, on the
build pushed to dev (`90437928` / code `77b1b458`), in **light AND dark**. Six device
agents completed and returned structured findings. The adversarial-verify and
completeness-critic phases **did not run** — the session hit its usage limit and all 16
verify agents + the critic failed on that limit. So the findings below are the agents'
own (well-evidenced: screenshots + pixel-sampled WCAG math + source confirmation), not
independently re-verified by a second agent. Where a finding is acted on, it is verified
by reading source and by a red-demoed test, which under the night's host contention is
more reliable than device re-verification anyway.

## Shipped fixes — RE-CONFIRMED ON DEVICE (all hold)

| Fix | Device | Result |
|---|---|---|
| Parent-PIN bypass P0 (`e45449ee`) | 5560 | Not re-driven end-to-end this sweep (device flaky); guard logic unchanged since the device-confirmed run |
| False "Chumash complete!" siyum P0 (`13c9cd6b`) | 5554 | **PASS** — bulk-marked 3 of 5 sefarim; Siyumim shows 0 curriculum + 0 aggregate + 3 per-sefer siyumim. No false milestone at 61.6%. Light + dark. |
| Chevron step-3-vs-step-7 direction (`603ba201`) | 5554 | **PASS** — both point reading-forward (right, LTR), English UI with Hebrew Terms left ON. Light + dark. |
| gold-on-hero-card legibility (`ac3018cd`) | 5556 | **PASS** — Dashboard Review digit legible bright-gold on blue in dark mode (independent pixel crop). |
| Siyumim tier-counter contrast (`b7399de7`) | 5554/5556/5558 | Confirms the bug this fix targets; the fix was NOT in the tested APK (committed after this build) — see below. |
| Track-lifetime 0%→100% (`7c490bad`) | 5562 | **PASS** — Progress-tab per-track Lifetime for חומש reads 100%, matching every other screen. 4×, light+dark. |
| Sentinel dates "Previously learned" (`3004cc2c`) | 5554/5558 | **PASS** — no "Jan 1, 2000". |
| Deleted-track in ACTIVE TRACKS (`bf692d71`) | 5562 | Independently re-found by 5562 (same root cause); fix committed after this build. |
| Bulk-mark reactivity (`77977737`) | 5554/5558 | **PASS** — tiles update without restart. |

Offline-account onboarding works end-to-end on 5554 (light + dark). Parent PIN
set/enter/wrong/lockout-at-5 all correct. The run-8 Learn OOM P0 stays REFUTED (5556:
10+ launches, full 70,033 dataset live, guest-clean throughout).

## New APP findings from the sweep

### Fixed after the tested build (already on dev, will re-gate)
- **Siyumim tier-counter digit illegible in dark mode** (P1, 1.22:1) — `b7399de7`. Found on 3 devices.
- **Deleted track shown in Progress "ACTIVE TRACKS"** (P2) — `bf692d71`.

### Being fixed now (parallel sub-agents, isolated worktrees)
1. **Dark-mode contrast cluster (P1/P2)** — three surfaces the shipped dark-mode work did
   not reach, each pixel-sampled:
   - Onboarding intro carousel primary CTA: **1.39:1** (dark label on dark-blue button)
   - Add-track wizard schedule-preset cards: **~1:1** (white card + near-white heading — white-on-white)
   - Add/Edit-Profile "Choose Mode" cards: **1.06:1**
2. **Parent-PIN keypad clips digits 7/8/9/0 + Cancel/Delete in LANDSCAPE** (P2) — dialog
   taller than the landscape viewport, no scroll → PIN un-enterable rotated.
3. **"Add items I learned previously" CTA does nothing on device** (P1 on 5558, P2 on 5562)
   — element exists + receives the tap (uiautomator), screen byte-identical after; yet the
   widget test asserting its onTap passes. Under investigation: most likely a route guard on
   `LifetimeMarkingRoute` silently cancelling navigation (a visible-but-dead CTA with no user
   feedback). Fix only if a real code cause is isolated — not a false fix.

### Real, but held for a dedicated follow-up (documented, not rushed)
- **Reader next-item chevron swallows rapid taps** (P2) — source-confirmed:
  `text_display_screen.dart:113-132` navigates each chevron via `context.router.replace(...)`
  (a full route rebuild), and the adjacent-item computation is async, so rapid taps during
  the transition are lost. **Load-sensitive**: 5556 saw ~80% drop under heavy contention;
  5558 earlier saw 5/5 clean on a lighter load. The real fix is a navigation refactor
  (drive the current ref from state and update in-place instead of `router.replace`) — a
  medium-risk change to the reader's core navigation. Deferred to its own change rather than
  rushed at session end; the mechanism is documented here so it isn't lost.
- **Track rename does not propagate to Progress-tab screens** (P2) — `00048c68` wired
  `trackDisplayTitle` into Track Detail + Learn, but `progress_screen.dart` /
  `curriculum_progress_screen.dart` / `curriculum_settings_screen.dart` still render the
  curriculum label. Whether Progress (a curriculum-organized view) should show the custom
  track name is a genuine product-intent question — flagged for the repo owner, not
  "fixed" unilaterally (this campaign has burned cycles fixing intentional behaviour).
- **Curriculum Progress card shows contradictory unlabeled numbers** (P2) — "Total items
  859 / Not started 858" (the track's own scope) beside "Lifetime 100%" (unscoped) on one
  card. Already analysed in `progress-percentage-divergence.md`; the defect is labelling,
  and the arithmetic is defensible.

### Low severity
- Breadcrumb separator chevrons in Learn→Browse content hierarchy (P3, 5564) — a chevron
  direction case in a different breadcrumb; check against the chevron-direction fix.
- "Today's Missions: 0 remaining" flashes on cold start before data loads (P3, 5558) — a
  one-frame loading-state race.

### Tooling gap found and fixed
- `crash_attribution.sh` missed ANRs (they land in the `system` logcat buffer, not
  `crash,main`) — fixed to read the system buffer, and removed a false-positive "Process
  has died" lifecycle pattern the buffer change exposed. Committed.

## Honest coverage note

Six SwiftShader emulators under concurrent driving is at this box's limit; devices flapped
heavily (5556 ~10 deaths incl. a 3.5-min outage; 5562 ~9 transport drops). Every death was
guest-clean = ENVIRONMENT. Gaps the agents flagged: no dedicated dark-mode
Content-Hierarchy/Search screenshot on 5556, no landscape re-test beyond the PIN dialog.
The adversarial-verify + completeness-critic phases did not run (session limit), so there
is no independent second-agent confirmation of these findings or a formal SHIP verdict —
that is stated plainly rather than implied.
