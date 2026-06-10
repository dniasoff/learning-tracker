# Recalibration Report — Detectability Audit of Escaped Bugs

**Author:** Murat (Master Test Architect)
**Date:** 2026-06-10
**Scope:** 75 manual bug fixes Daniel shipped by hand between 2026-05-13 and 2026-06-09 — i.e. the bugs that *escaped* the automated test loop and had to be caught by a human.
**Question:** Given how the current loop actually works, how many of these could it ever have caught, and what does it have to become to close the gap?

---

## 0. TL;DR

Of **75** human-caught bugs, the current text-only scripted loop would have **reliably caught exactly 1 (1.3%)**. A further 22 are *theoretically* catchable but only under fixtures, flows, or assertions the loop does not run — so in practice **74 of 75 (99%) escaped**, and even on the most generous reading **52 of 75 (69%) are structurally invisible** to it no matter how the existing catalog is tuned.

The loop converged to "47 fixes / green" not because the app got correct, but because the loop was **measuring the one dimension the app was already passing** (string presence on a happy path) and **blind to the four dimensions where the bugs actually lived** (pixels, meaning, timing, and the second device). The convergence was real *work* but **false confidence** about quality. Details below.

---

## 1. Headline: what % the current loop misses, by detectability class

The loop's own per-fix verdicts (`caughtByCurrentLoop`):

| Verdict | Count | % of 75 | Meaning |
|---|---:|---:|---|
| **yes** — reliably caught | 1 | **1.3%** | A weekly-pace overdue count inflation; plain integer text the loop already asserts. |
| **maybe** — only if catalog changes | 22 | 29.3% | Catchable *in principle*, but needs a fixture/flow/assertion the scripted happy-path catalog does not run. In practice these escaped. |
| **no** — structurally invisible | 52 | **69.3%** | The bug has no string/bounds footprint the loop inspects (it's a pixel, a transient frame, a second account, or a correctness judgment). No amount of catalog tuning catches these. |

**Headline number: the current text-only scripted loop misses 99% of these bugs in practice (74/75), and at least 69% (52/75) are impossible for it to catch by design.**

### Miss rate by detectability class

Every fix is tagged with *why* it is hard to see. The miss is near-total in every class:

| Detectability class | Count | % of 75 | Reliably caught (`yes`) | Why it's missed |
|---|---:|---:|---:|---|
| **exploratory-timing-race** | 20 | **27%** | 0 | Transient frames, races, interrupted/rapid input, clock/midnight, network-flap. The loop runs paced happy-path input and samples one settled state. |
| **domain-semantic** | 17 | **23%** | 0 | A *present, valid-looking* string that is the *wrong* string for the user's nusach / Hebrew-terms toggle / locale / tutor scope. No oracle = can't grade. |
| **visual-perceptual** | 13 | **17%** | 0 | Overflow stripes, 1.0:1 contrast, clipping, missing ink splash, lingering UI. None of these exist in the uiautomator tree. |
| **pure-logic** | 13 | **17%** | **1** | Merge/LWW, seed-version gates, FK/registry integrity, scheduler arithmetic. Mostly need destructive/edge fixtures or unit assertions, not a UI walk. |
| **cross-device-cloud** | 12 | **16%** | 0 | Owner device looks correct; the bug lives in the round-trip to a *second* account/device the single emulator never exercises. |
| **TOTAL** | **75** | 100% | **1** | |

The single `yes` (commit `1e59855e`, weekly-pace overdue inflation) is the exception that proves the rule: it is catchable *only* because the symptom is an integer rendered as text **and** a back-dated weekly fixture happens to expose it — the loop's one native competency (read a number) intersecting one in-catalog fixture. Nothing else lines up.

---

## 2. Concrete examples the loop is blind to — grouped by *why*

These are real commit subjects, chosen to show each blind spot at its sharpest.

### A. NO VISION — the bug is a rendered pixel, not a tree node (visual-perceptual)

The uiautomator tree contains text, resource-ids, and bounds. It does **not** contain color, compositing, overflow stripes, clipping, ripples, or single-frame states. Every one of these passed a text assert while a human saw something broken.

1. **`25170b17` — switcher header opaque/readable on all routes (dark-on-dark 1.0:1 contrast).** The header text string *is* present in the tree, so the assert passes. Its contrast against a bled-through dark route is **1.0:1 — literally invisible to a human**. Pure alpha-compositing fact; zero textual footprint.
2. **`329f78f0` — migrate all 26 audited overflow risks to overflow-safe layouts.** RenderFlex overflow paints yellow/black stripes that **never appear in the widget tree**. The team's own fix was a dedicated multi-device widget-test harness (`expectNoOverflowAcrossDevices`) — an admission that the on-device loop is structurally blind to overflow.
3. **`23536160` — Exit-Track dialog 82px overflow under keyboard.** A layout exception with no node. Same story: caught by a device×textScale widget matrix, not the loop.
4. **`37dd7046` — Daily Tasks Hebrew title overflow (clipped breadcrumb).** The *full* string stays in the tree, so a text assert sees complete text — while the user sees a cut-off ellipsis. The clip is rendered-only.
5. **`acdaa8db` — clear keypad digits so setup screen doesn't linger at 4 dots.** For one frame the screen shows 4 filled dots before pop — reads as "my PIN didn't save". The loop's eventual-state dump samples the *popped* screen and passes.
6. **`ca3a038f` — missing ink splash on ListTiles.** Tap works, tree unchanged; only the ripple fails to paint. Pure animation feedback, no signal at all.

### B. NO DOMAIN ORACLE — the string is present but *wrong* (domain-semantic)

"String present" ≠ "string correct." The loop confirms a term exists; it cannot judge that it's the *right* term for the user's nusach, toggle, locale, or session scope.

7. **`2e3de9fe` — transliterate masechta names per nusach (Berakhos vs Berakhot).** `Berakhot` is a perfectly valid, present, non-empty string. Only an oracle that *knows an Ashkenazi user should read Berakhos* can tell correct from wrong. uiautomator just confirms text exists.
8. **`9a5151b5` — make CurriculumLabel + edit-track Shabbos nusach-aware.** Sephardi users saw `Mishnayos` instead of `Mishnayot` across 6 surfaces. Both are valid present strings; presence passes everywhere.
9. **`5b98b32c` / `0dd1abe2` — Hebrew-terms toggle doesn't flip stage/unit words live.** Catchable *only* if a scenario toggles Hebrew-terms and re-asserts the same node *changed to the correct expected term* — the happy-path catalog never drives the toggle, and even if it did it needs the variant-correct expected value.
10. **`4fc15e33` — hide tutor's OWN account header in a talmid session.** The header string *is* present (presence assert passes); judging it as the *wrong account's* surface is an identity/context-correctness call that needs both an oracle and an active tutored session.

### C. NO EXPLORATION — the bug needs junk input, interruption, races, clock, or a second account

The loop runs a scripted catalog: center-of-element taps, paced input, one assertion per cell, happy-path single-account fixtures, steady network, fixed clock. Anything off that rail never triggers.

11. **`a0c85409` — Set-Parent-PIN freezes at 4 digits (keepAlive mode race).** Reproduces only when 4 digits are tapped **before** an initState microtask drains. Paced scripted input lets the microtask settle first — the wrong-handler routing never fires.
12. **`68487cf4` — self-heal stuck offline banner.** The banner latches ON only over a **flaky** link where the reachability host keeps timing out *after* real recovery. Needs network-flap fault injection + a wait for auto-recovery; steady-state emulators never reach it.
13. **`c1b683cc` — tear down listeners before account switch (stale-uid PERMISSION_DENIED flood).** Needs **two real cloud accounts on one device** to flip the uid under live listeners. The single-account loop cannot construct the state.
14. **`b73ab3bf` — kill star-counter staleness after redemption.** A single counter read sees a valid number and passes. Only a **redeem → pop back → re-read the same card** sequence exposes the stale value — a mutate-then-re-read the one-assertion-per-cell catalog doesn't perform.
15. **`7d455c5d` — streak buckets by LOCAL day + lapses across midnight.** Diverges only in negative-UTC offsets and only lapses wrong across midnight on a screen left open. Needs TZ-set + clock-roll the fixed-clock run never does.
16. **`ec7cc908` — push seeded stages to Firestore so tutors/2nd device project.** The owner's own device projects fine (local stages present). Only a **tutor mirror / 2nd device** pulling from Firestore sees zero stages. One emulator shows correct UI and passes green.

These 16 cover all four blind spots. The pattern is identical every time: the loop asserts the one property the app already satisfies and is silent on the property that broke.

---

## 3. The Redesign — a worker protocol that would actually catch these

The fix is **not** "write more cells." It is to give the worker the **four senses it lacks** and to spend its budget on **depth, not breadth**. All four run on the existing Android-emulator + Sonnet-worker setup with modest additions.

### (a) VISION pass — screenshot every screen × state, judge with a vision-capable agent

**Why:** the entire visual-perceptual class (17%) and the visual half of the timing class are invisible to text. A pixel judge is the only thing that sees them.

**How, concretely:**
- For every screen *and every meaningful state* (empty / one item / huge data / keyboard-up / long Hebrew label / dark route / large text-scale), capture `adb exec-out screencap -p > state.png`.
- **Downscale on-device/off-device to a safe size** (e.g. longest edge ≤ 1024px, strip EXIF) before it ever reaches a model — this satisfies the original image-safety constraint that drove the text-only rule. The reason the loop went text-only was image-safety; **downscaling is the unlock that lets vision back in safely.** The vision step is run by a *separate* vision-capable agent (not the driving Sonnet worker), so the driver stays image-free.
- The vision agent answers a fixed rubric per shot, like a human reviewer: *Any text clipped / ellipsized where it shouldn't be? Any overflow stripes? Any text with contrast too low to read? Any overlapping tap targets? Any element half-off-screen? Any leftover/lingering state (filled PIN dots, spinner, stale banner)? Does anything look like nonsense / wrong-account / placeholder?* Each "yes" is a finding with the screenshot attached.
- **Catch the transient frames** by capturing a short burst (e.g. screencap every ~150ms for ~1.5s, or `screenrecord` then sample frames) across launch, PIN completion, and navigation transitions — this is how you finally see `acdaa8db` (lingering dots), `29b18fa8` (offline flicker), `fdf33709` ('All caught up' flash) that a single settled dump can never sample.

This single capability moves all 6 examples in §2.A and several timing flickers from NO to caught.

### (b) DOMAIN ORACLE — a reference of correct terms, checked against the rendered string

**Why:** the domain-semantic class (23%) is the second-largest, and **zero** are caught today because "present" is the only test. You must supply ground truth.

**How, concretely:**
- Build a **term reference table** (CSV/JSON) keyed by `(canonical_key, nusach, hebrew_terms_toggle, locale)` → `expected_rendered_string`. e.g. `(berakhot, ashkenazi, off, en) → "Berakhos"`, `(berakhot, sephardi, off, en) → "Berakhot"`, `(masechta, *, on, *) → "מסכת"`, `(seder_zeraim, ashkenazi, off, en) → "Seder Zeraim"`. This is exactly the data Daniel encoded *into the fixes* — harvest it from the shared rendering library the fixes built (`e49bdb14`, `7c49a292`) so the oracle and the app share one source of truth.
- For each labeled scenario, set the controlling settings explicitly: **drive the nusach setting, flip the Hebrew-terms toggle, and run the locale in `he` as well as `en`.** Then assert the rendered node equals the **variant-correct expected string from the table** — not merely that *a* string is present.
- Add **negative locale assertions**: in an `he` build, assert the absence of known English literals on each screen (this catches the i18n leaks `e42364db`/`7676207d` that a positive presence check sails past).
- Add a **toggle-diff assertion**: read the node, flip Hebrew-terms, re-read, assert it *changed* to the expected Hebrew form (catches the "didn't re-render live" cluster `5b98b32c`/`0dd1abe2`/`425b8a38`).

This is the only way to move §2.B from NO to caught; it requires no vision, just ground truth + driving the settings.

### (c) EXPLORATORY / adversarial protocol — break the happy path on purpose

**Why:** exploratory-timing-race (27%) is the single largest class and **zero** are caught. The whole class exists because the loop never leaves the rail.

**How, concretely, per probe type:**
- **Rapid/racy input:** fire 4 PIN digits with **no settle delay** (back-to-back `adb shell input`), and tap before transitions complete — reproduces `a0c85409`, `7c63fc70`, the PIN keepAlive races in `56a6ff50`/`4a2faf8b`.
- **Interrupted flows:** start a flow, then background (`adb shell input keyevent KEYCODE_HOME`) and resume; dismiss a sheet mid-async; rotate (`adb shell settings put system user_rotation` / `wm` orientation) — reproduces `0e0e2327` (sheet popped before dialog mounted), `a8f182d4`/`1c5d3503` (keyboard-up overflow once you actually focus a field).
- **Junk / edge input:** paste huge strings, empty values, emoji, very long Hebrew labels into every field; feed empty-vs-huge data fixtures (0 items, 500 items) to every list — surfaces overflow and empty/inflated-count bugs.
- **Clock & timezone manipulation:** set the emulator to a negative-UTC offset and roll the clock across local midnight (`adb shell su 0 date` / `settings`), and create "yesterday" fixtures relative to *now* — reproduces `7d455c5d` (streak TZ), `2ede6492`/`db4d3178`/`d9cc16b2` (back-dated overdue / reorder amnesty / anchor-advance).
- **Network-flap injection:** toggle `adb shell svc wifi`/`svc data` off→on with delays, and induce a flaky-reachability condition — reproduces `29b18fa8` (startup blip) and `68487cf4` (latched banner self-heal).
- **Destructive / corrupt-state fixtures:** seed a profile with tracks+scopes+study_day_configs and **delete it**; remove the active account and relaunch; inject a route-guard throw — reproduces `8e2bdf6f` (FK delete order), `a777ffa9` (dangling lastActiveAccountId), `c8203d81` (route-guard lockout), `2fbe2f9e`/`944db04c` (registry dedupe).
- **Mutate-then-re-read on the SAME screen** (the cheapest, highest-value upgrade): every counter/card scenario must perform a state-changing action and re-assert the *same* node updated — reproduces the entire staleness cluster (`b73ab3bf`, `31f125f7`, `44f9b78b`).
- **Two-account / two-device cloud harness:** stand up a **second real (or emulated) cloud account on a second emulator**, write data on device A, pull on device B, and run revoke / account-switch / re-auth sequences while grepping logcat for `PERMISSION_DENIED`. This is the *only* thing that reaches the cross-device-cloud class (16%): `c1b683cc`, `ec7cc908`, `87e7327a`, `38bdbfa3`, `9497b9e4`, `00fa0e81`, and the tutor-projection cluster. Pair it with a logcat watch (not a one-shot grep) so the `profileId=0` / stale-uid floods (`35d193b3`) actually register.

### (d) DEPTH over sampling — one screen walked exhaustively per iteration

**Why:** the current catalog spreads one assertion across many cells, so each surface gets a shallow glance and the *combinations* that break (this label × that nusach × keyboard-up × small device) are never visited.

**How, concretely:** flip the unit of work from "a cell" to "**a screen, exhausted**." Per iteration, pick one screen and walk the **full matrix on it**: every state (empty/one/huge), every device profile (small/large), every text-scale (1.0/1.3/2.0), both locales (`en`/`he`), both nusach values, both Hebrew-terms toggle positions — and on each, run the vision rubric (a), the oracle check (b), and at least one adversarial probe (c). One screen done this way produces dozens of high-signal findings and *reproduces the real combinations the fixes addressed*, instead of one green checkmark per surface. Rotate screens across iterations; a screen isn't "done" until it has survived the full matrix, not a single tap.

**Net effect of the redesign on this corpus:** vision (a) recovers ~17% (visual) + several timing flickers; the oracle (b) recovers ~23% (domain-semantic); exploration + two-device (c) recovers most of the 27% timing and 16% cross-device classes and the destructive-fixture pure-logic items; depth (d) is the delivery mechanism that ensures the right *combinations* are actually visited. Together they would have plausibly caught the **large majority of the 74 escapes** — versus the 1 the current loop caught.

---

## 4. Blunt assessment: was "47 fixes / convergence" real progress or false confidence?

**It was real work and false confidence — and it is important not to confuse the two.**

Real, in a narrow sense: the loop did exercise the app, did run scenarios, and the 47 fixes/convergence reflects genuine effort and presumably did clean up some text-and-logic defects on the happy path (the kind of thing the one `yes` represents). That work is not worthless.

False, in the sense that matters: **convergence measured the loop's agreement with itself, not the app's correctness.** This audit is the control group — 75 bugs that were *in the app the whole time the loop was going green*, and the loop would have caught **1 of them**. A test suite that converges while 99% of the live defects sail past it has converged on **the wrong invariant**: "every scripted string is present on the happy path." That invariant was *already true* for almost every one of these bugs — `Berakhot` was present, the header text was present, the counter showed *a* number, the owner's device projected fine. The app was green on the dimension the loop measured and broken on the four it didn't.

The danger is precise: **green from this loop is an anti-signal if read as "quality is high."** It tells you the happy-path strings exist. It tells you nothing about whether they're the *right* strings (domain), whether the screen is *readable* (vision), whether it survives a *real user's* fat-fingers / interruptions / midnight / flaky wifi (exploration), or whether it works *for the second person on the second device* (cloud) — and that is where 99% of the actual bugs lived. Convergence here was a thermometer reading room temperature and reporting the patient is fine.

**Verdict:** treat the prior convergence as "happy-path text smoke passed," not as a quality gate, and do **not** let a green run from the old loop gate a release. Adopt the four-sense redesign (vision + oracle + exploration + depth) before any future convergence number is allowed to mean "ready."

---

*Appendix data: 75 fixes; classes — exploratory-timing-race 20 (27%), domain-semantic 17 (23%), pure-logic 13 (17%), visual-perceptual 13 (17%), cross-device-cloud 12 (16%); current-loop verdicts — yes 1, no 52, maybe 22.*
