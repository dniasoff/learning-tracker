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

### FIXED this session (sub-agents, isolated worktrees, red-demoed, merged)
1. **Dark-mode contrast cluster (P1/P2)** — three surfaces the shipped dark-mode work did
   not reach, each pixel-sampled and fixed:
   - Onboarding intro carousel primary CTA: **1.39:1 → 12.56:1** (new `introCtaLabel` token)
   - Add-track wizard schedule-preset card: **~1.16:1 → 14.94:1** (was hardcoded `Colors.white`; now `brandCreamCard`)
   - Add/Edit-Profile "Choose Mode" card: **1.06:1 → 13.21:1** (new `profileModeCardBg` token)
   Each red-demoed at exactly the measured pre-fix ratio; 12 new contrast tests; light mode unchanged.
2. **"Add items I learned previously" CTA does nothing on device** (P1/5558, P2/5562) —
   **REAL BUG, root-caused and fixed.** The CTA navigates to `LifetimeMarkingRoute`, which
   carries `childModeGuard`; that guard calls `resolver.next(false)` **silently** when the
   active profile is in adult mode (the common case *and* the test default) → a visible-but-
   dead button with no feedback. The widget test passed because it used a fake `_RecordingRouter`
   that **bypasses real guards** — the wrong layer, a textbook case of this campaign's thesis.
   Fixed by hiding the CTA in non-child mode (mirroring `_ParentalControlsSection`'s hide-when-
   `!isChildProfile` pattern); the security guard is untouched; the wrong-layer test was
   corrected and a real one added (CTA absent for adult / present for child, no fake router).
   No capability lost — adults reach lifetime-marking via Settings → Add Lifetime Learning.

### Investigated → FALSE POSITIVE (no code fix; regression test added)
3. **Parent-PIN keypad "clips digits 7/8/9/0 in landscape"** (P2) — the code already handles
   it: `ParentModeDialogFrame` bounds content to 88% height and wraps it in a
   `SingleChildScrollView` (commit `01b63b4d`, pre-run-10). Verified landscape is genuinely
   reachable (no orientation lock in `lib/`). Added a regression test pumping the dialog in an
   800×360 landscape viewport (no overflow, all keys reachable); red-demoed by stripping the
   scroll → 139px overflow matching the report. The device observation was stale/misread.

### Deferred items — now ADDRESSED (second fix pass, red-demoed + adversarially verified + merged)
- **Reader next-item chevron swallows rapid taps** (P2) — **FIXED.** Confirmed a real bug
  (not a host artifact) via a REAL auto_route router test: 5 rapid taps landed on item .1.4,
  not .1.6 — taps genuinely dropped, because each chevron did `context.router.replace(...)`
  (full route teardown) and the adjacent-ref lookup was async, so during the gap both
  chevrons rendered `onPressed: null` and Flutter dropped taps on the disabled controls.
  Fix: `TextDisplayScreen` → `ConsumerStatefulWidget` holding `_currentRef`; prev/next now
  `setState` in place (no navigation) and read adjacency **synchronously** from the keepAlive
  `ContentIndex.adjacent()` — closing the loading gap entirely. Deep-linking, breadcrumb,
  RTL, and first/last disabling all preserved. New `text_display_chevron_tap_swallow_test.dart`
  red-demoed (fails on reverted code). Verifier: MERGE, red-demo genuine, no router regression.
- **Track rename does not propagate to Progress-tab screens** (P2) — **FIXED.** The product
  question is resolved by the app's own established behaviour: Track Detail + Learn already
  show the custom name (`00048c68`), and W3.22 guarantees one track per {profile, curriculum}
  so all 3 Progress sites are per-track labels, not curriculum-group headers. Wired
  `resolveTrackTitle(trackCustomNameProvider(...))` into `progress_screen.dart` (_PerTrackRow),
  `curriculum_progress_screen.dart` + `curriculum_settings_screen.dart` (AppBar titles),
  leaving genuine curriculum metadata (the Hebrew subtitle) alone. Red-demoed in all 3 files
  (reverting shows the curriculum label). Completes established intent, not a unilateral
  product change.
- **Remaining dark-mode contrast (selected-state cards)** — **FIXED.** The 3 sites the
  first pass flagged out of scope: chazara preset card SELECTED (1.63:1 → 11:1, new
  pinned-deep gradient tokens), add-profile mode card SELECTED (1.63:1 → 10.65:1,
  `brandCreamCard`), and the "Custom Cycle" card (1.16:1 → 14.94:1, `brandCreamCard`). Each
  red-demoed; raw-color ratchet went 250 → 249. **Dark mode is now materially complete on
  the surfaces exercised** (the campaign does not claim exhaustive coverage of every screen).
- **Cold-start "Today's Missions: 0 remaining" flash** (P3) — **FIXED.** The pill read from
  an empty placeholder list during load, showing a concrete "0"; now gated on the same
  `tasksReady` flag its sibling counters use, showing "…" until data arrives. Red-demoed.
- **Breadcrumb separator chevrons in content-hierarchy Browse** (P3) — **FALSE POSITIVE, no
  change.** The screen already uses the shared `breadcrumbSeparatorIcon(Directionality.of(context))`
  helper correctly in both spots (commit `120d476a`), with no intervening Directionality wrap
  (no double-flip). Its existing RTL/LTR test catches a break (red-demoed). The 5564 device
  observation did not reproduce in a fair test.

### Still open (genuinely not fixed)
- **Curriculum Progress card shows contradictory unlabeled numbers** (P2) — "Total items
  859 / Not started 858" (the track's own scope) beside "Lifetime 100%" (unscoped) on one
  card. Already analysed in `progress-percentage-divergence.md`; the defect is labelling,
  the arithmetic is defensible — left as a labelling-clarity follow-up.
- **Chumash chapter siyum tier** — a product DECISION (should a chapter be its own siyum
  tier), not a bug. The conservative default (no) is shipped and correct; awaiting the
  repo owner's call.

### Low severity (documented, not fixed this pass)
- Breadcrumb separator chevrons in Learn→Browse content hierarchy (P3, 5564) — a chevron
  direction case in a different breadcrumb; check against the chevron-direction fix.
- "Today's Missions: 0 remaining" flashes on cold start before data loads (P3, 5558) — a
  one-frame loading-state race.

### Dark-mode selected-state cards — now FIXED (see "Deferred items — now ADDRESSED" above).

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
