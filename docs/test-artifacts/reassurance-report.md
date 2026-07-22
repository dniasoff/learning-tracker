# Release Reassurance — final report

> **STATUS: all six run-10 device reports are in; the fix wave is complete.** Remaining
> open items are named explicitly in *Still open* and *Residual risk* below — they are
> stated, not hidden. This document is the campaign's deliverable: an honest account of
> what is now trustworthy, what is not, and what remains unknown.

## Still open at time of writing

1. **2nd P0 — false "Chumash complete" siyum** (below): root-caused and specified, fix in
   progress. Carries an **open product decision for the repo owner** (should a Chumash
   chapter be its own siyum tier?), with the conservative default applied meanwhile.
2. **Chevron fix has no on-device confirmation** — it rests on unit evidence alone
   (6/6 green, red-demoed at 3/6 on revert, verified twice independently). A live
   spot-check of wizard step 7 was requested.
3. **`run9-learn-eager-load` deliberately not merged** — see the section below for why.
4. Nothing has been pushed. `dev` holds the campaign's work locally, pending a green
   `make ci` on the fully integrated tree.

## What was asked

> *"guarantee an amazingly reliable product"*

No honest engineer can guarantee that, and this report does not pretend to. What it
*can* do — and what the campaign was designed to deliver — is stated in the plan:

> For each top risk surface, an **independent, repeatable line of evidence** that the
> surface's **demonstrated** failure mode is now caught before ship — plus a **live
> gate** that keeps it caught.

The distinction matters. "All tests pass" was already true at the start of this
campaign: ~10,370 green tests coexisted with a claimed ship-blocking P0 and a batch of
real device defects. Green was not the same as safe.

## The campaign's central finding

**Verification was sitting at the wrong layer, and several "guards" were inert.**
Concrete, demonstrated instances — each proven by reintroducing the defect and
watching the guard fail to notice:

1. **Tautological acceptance tests.** 43 test files read `lib/` *source text* at runtime
   and asserted on the string. Two proofs of how little that guarantees: a dead-code
   `if (false) { TrackManagementBody(...) }` and a **stray comment substring** each kept
   an "acceptance" test passing while the behaviour was broken.
2. **A privacy guard that shipped a false promise.** The PV-1 standard was flipped from
   `[Pending]` to `[Enforced]` while a **live `child_profile_id` PII leak still shipped**,
   because the banned-key rule was exact-match, so `child_profile_id` sailed past
   `profile_id`. 19 events were parked in a "covered elsewhere" allowlist; on audit only
   **5** were genuinely covered.
3. **A "fix" branch that was never implemented.** `run9-learn-eager-load` pointed at a
   docs-only commit, so the eager load it claimed to fix was untouched.
4. **Crash attribution that could not tell the app from the host.** See R9 below.
5. **An order-dependent test** asserting against a builder-mutated set instead of
   registration-time state (failed 6/6 seeds once ordering was randomized), and a
   **`--exclude-tags` bug** silently dropping a whole test lane because the flag takes a
   single value and was passed twice.

## Scorecard

🟢 reassured (systemic guard + red-demo + in the gate) · 🟠 partial · 🔴 unguarded

| Surface | State | Basis |
|---|:--:|---|
| **R1** Child-data integrity | 🟢 | Property sweep over all 9 curricula × collision levels 2/3/4. Red-demo: naive keying → 18/20 fail with authentic over-counting. |
| **R2** Device reality (RTL/overflow/goldens) | 🟠 | Golden matrix now en+he × light/dark with real pixel assertions; brightness axis proven to discriminate, plus a structural guard that it stays registered. Device sweep ⏳. |
| **R3** Parent-PIN / privacy | 🟢 | Live PII leak closed; substring rule; real tests for 14 previously-uncovered events; de-tautologized PIN guard; route-wiring + guard-chain tests. Red-demo: reintroducing `child_profile_id` fails the sweep. |
| **R4** Sync / cloud / rules | 🟢 | **Correction — this was already covered and the campaign failed to credit it.** See below. |
| **R5** Reactivity / staleness | 🟢 | `expectRebuildsOn()` contract + 7 adoptions — first systemic guard for a class with 63 prior escapes. Red-demo: all 7 go red when the invalidation watch is removed. |
| **R6** Gate & flake trust | 🟢 | 2m global timeout, randomized ordering, quarantine lane, coverage-denominator ratchet. Found two real bugs en route. |
| **R7** Full-journey acceptance | 🟠 | Ratchet pins source-assert growth (baseline 43); 4 exemplar conversions. The remaining 43 still need burning down. |
| **R8** Memory / OOM on low-end devices | 🟢 | **Run-8's P0 REFUTED on device, no residual gap.** Both aggregate OOM paths bounded (Parts A+B). |
| **R9** Crash attribution *(new meta-surface)* | 🟢 | Guest-side attribution replaces host-process inference. Red-demoed both directions. |

## R8: the question that blocked two runs

Run-8 filed a P0 — "opening Learn OOM-kills the app on API 29". Run-9 could neither
confirm nor refute it. Run-10 settled it as **REFUTED**, on three independent lines:

- **Measurement.** Native heap (the arena holding materialized `ContentItem`s):
  48–62 MB fresh → ~76 MB on Learn → ~82 MB with the reader → **~90 MB peak** with
  search. Under the deepest drill available (Bava Batra, a 176-daf tractate, 34 dapim
  paged across 68 taps) the session-wide peak was **125,566 KB — ~24% of the 512 MB
  limit** — growth-then-plateau with GC recovery back to ~110 MB. Java/Dalvik heap flat
  at 3–7 MB throughout. (Raw KB quoted deliberately: ~123 MB and ~125 MB both appear in
  source notes, being the MiB and decimal readings of the same sample.)
- **Attribution.** Guest logcat checked after *every* scenario across multiple app
  launches — clean every time. No `FATAL EXCEPTION`, `am_crash`, ANR, or `lmkd` kill
  naming our package, ever.
- **Mechanism.** `contentIndexProvider` loops `CurriculumId.all`, so **all 9 curricula
  are materialized on the first Learn open regardless of what is browsed**. The
  refutation therefore does not depend on which curriculum was exercised.

**Consequence for shipping:** the pending Learn eager-load change is a **performance
improvement, not a crash fix**, and must not ship claiming to fix a P0.

The most important judgement in the whole campaign was made here. A genuine guest-level
SIGKILL of the app's PID appeared — on the exact device and feature everyone expected to
fail. It was *excluded on evidence*: no `lmkd` line named our package, ~40 unrelated
processes were reaped with signal 9 in the same ~45s window just after `lmkd` initialized
post-cold-boot on a 2 GB AVD, and the app's own logs put it on **Dashboard** providers
with `contentIndex` never touched at 53 MB. Confirmation bias had every opportunity here
and did not win.

## R9: why the earlier runs could not be trusted

The emulator fleet is forced onto `-gpu swiftshader_indirect` — the only renderer that
starts headless on this host (`-gpu host` and `swangle_indirect` both die with
`Could not start renderer (-2)`, **including under Xvfb**; the emulator ships its own EGL
stack). SwiftShader emits host-side RenderThread SEGFAULT storms that look exactly like
app crashes if you judge by the emulator process dying. That is why run-8's P0 and two
run-9 P1s were all re-classified ENVIRONMENT.

Fix: attribute from **inside the guest**. Host-renderer segfaults never reach guest
logcat; real app failures always do. Two supporting pieces:
- `tool/device_e2e/crash_attribution.sh` — package-scoped, kill-matching, red-demoed
  (normal launch → clean; `am crash` → `FATAL EXCEPTION` + our package).
- `tool/device_e2e/logcat_recorder.sh` — mirrors guest logcat to the host so the record
  **survives the emulator dying**, which is precisely when the evidence used to vanish.

⚠️ The first draft of the attribution script **failed its own self-test**, reporting a
"REAL APP FAILURE" on an idle device by matching benign `lowmemorykiller` write-errors and
unrelated `tombstoned` plumbing. It is worth stating plainly: the tool built to stop false
positives began by producing one. Patterns are now package-scoped and match kills, not chatter.

## Data-consistency finding: labels, not arithmetic

Run-9 flagged "Track progress: 0.1%" vs ~3% for the same track and could not explain it.
Cause: **at least four progress aggregators are live** (the code's own doc comment admits
they were meant to be unified and were not), differing on denominator, tier filter,
`since` gate, and `requireAllStages`. Track-scoped surfaces divide by the track's scope
(~230 items); Lifetime Knowledge and Curriculum Progress divide by the **full unscoped
curriculum** (~5,846). Same 7 completions → 3% and 0.1%.

**The arithmetic is largely defensible; the labelling is not.** "How much of this track?"
and "how much of the whole curriculum?" are genuinely different questions. The fix
therefore makes an identical label yield an identical number, and keeps the genuinely
different quantity separately labelled — it does **not** equalise the denominators, which
would destroy a real distinction. Related: bulk-marked siyumim rendered the raw sentinel
`2000-01-01` as a milestone date; the sentinel is load-bearing, so only its *presentation*
changed ("Previously learned").

## Device findings — run-10 (all 6 devices reported)

Six emulators: API 28 / 29 / 31 / 33 / 34 / 36-tablet. Every verdict below is
**guest-attributed** — the first run in this campaign for which that is true.

| Device | Surface | Result |
|---|---|---|
| 5560 (API 34) | Settings, parent mode, PIN boundary | **1 × P0** (fixed), 1 × P2, 1 × P3 |
| 5558 (API 31) | Dashboard, progress, charts | **1 × P1** |
| 5556 (API 29) | Learn, reader, hierarchy, search | 1 × P2, run-8 P0 **refuted** |
| 5554 (API 28) | Onboarding, account, PIN entry | **none** (4 pre-existing P3s reconfirmed) |
| 5564 (API 36) | Hebrew/RTL, tablet layout | **none** |
| 5562 (API 33) | Tracks, data consistency | **2 × P1**, 3 × P2 |

### P0 — Parent-PIN bypass after a profile-switch round trip *(fixed, `e45449ee`)*

A child who watched a parent unlock Parent Mode once could re-enter **full admin
controls with no PIN** later in the same session — while the UI still showed a lock
icon, a "PIN-guarded" subtitle and a CHILD MODE badge. Reproduced twice, including from
a cold start.

Cause: `_switchProfile()` cleared the banner's reactive flag but not the guard's cached
scope, on the reasoning (stated in its own comment) that "the scope id changes". True
switching *to another* profile; false on a **round trip back** to the previously-elevated
child, where the scope id is identical and `PinGuard` waved the navigation through.

**Fixed AND regression-proofed** — but only after catching a bad guard on the way.

The first test written for it pinned the `PinGuard` contract and did **not** fail when the
production fix was reverted (verified, not assumed) — because the bug lived in the caller.
Rather than ship a green test that cannot fail for its own bug — the exact pattern this
report criticises elsewhere — it was labelled as insufficient and a **caller-level** test
was written: it pumps the real `ProfileSwitcherSheet`, taps a real profile row, and spies
on a real `AppRouter`'s `PinGuard.onSessionLocked`. Red-demoed twice independently (by its
author, and again by the coordinator against the pre-fix file): `Expected: <1> Actual: <0>`
→ restore → green.

### P0 (2nd) — a FALSE "Chumash complete!" siyum can fire at 61.6% actual completion

Found by pulling on a loose thread: an auditor noticed a bulk-mark of 3 Chumash sefarim
produced **zero** siyum entries, was told not to assume a bug, and traced it through the
real production path instead of reading code.

**A stale comment turned out to be load-bearing.** `completion_detection_service.dart:44-48`
asserts that Chumash / Nach / Tanach / Mussar "have no level-2 in their content data". The
shipped assets say otherwise: **5,844 of 5,846** Chumash items carry a `level2` (the chapter
— the real shape is sefer → chapter → verse). So the level-2 branch *does* fire, calls
`unitScopeFor(chumash, level: 2)`, and gets back scope `'masechta'` with a **bare chapter
number** (`'1'`) as the unit identifier.

Two consequences, the second serious:
1. **Duplicate aggregate entries** — the sefer-level siyum fires once per dispatched
   (sefer, chapter) pair rather than once per bulk-mark.
2. **Collisions corrupt the denominator.** `journey_providers.dart` dedupes unit entries by
   bare identifier and counts distinct level-2 strings, so for Chumash the total becomes
   `{'1'…'50'}` = **50** (Genesis's chapter count, every other sefer's numbers being a
   subset) instead of **5** sefarim. Worked through for a real 3-of-5-sefarim mark:
   `completedUnits` = 50 chapter strings + 3 sefer names = **53**, against a corrupted
   `totalUnits` = **50** → `53 >= 50` fires a **curriculum-completion milestone at 61.6%
   actual progress**.

In a Torah-study tracker a siyum is a meaningful milestone; inventing one a child has not
earned is a correctness failure with real weight — worse than the missing-siyum symptom
that led here. Mishnayos is unaffected (its level-2 genuinely names the masechta, so no
numeric collision).

**Why the suite could not catch it:** `bulk_prior_completion_siyum_detection_test.dart` only
ever used a **2-tier Mishnayos-shaped fixture**. No test had a fixture whose *shape* could
expose a 3-tier curriculum's level-2 collision. The gap was in the fixture, not the assertions.

**Open product decision, deliberately not made unilaterally:** should a Chumash *chapter*
have its own siyum tier? The conservative default applied meanwhile is to skip the level-2
branch for these curricula (restoring what the code always documented as intent), because
emitting per-perek siyumim would be a new feature shipped as a side effect of a bug fix.

### P1 — bulk-mark does not invalidate the summary/header aggregates

After bulk-marking a full masechta, Dashboard / Progress / per-track / Lifetime-header
showed pre-bulk numbers, while the per-curriculum rows **below the stale header on the
same screen** were already correct; a restart fixed everything. That isolates it to
reactivity, not data. The live single-mark path *does* invalidate the same providers, and
the confirm dialog explicitly promises immediate effect — so the asymmetry contradicts a
documented promise.

Root cause found independently by code trace: the live path calls
`completionCommittedProvider.increment()`; the bulk path never does, invalidating only a
hand-picked list that omits three aggregates. **Both existing tests were structurally
blind to it** — one increments the signal manually, the other only cold-builds providers.
Fix in flight.

### Lower severity

- **Reader input loss (P2)** — 5 taps → 1 advance, and 68 taps → 34 advances (~2 eaten
  per page) on the primary *reading* surface.
- **PIN dialog in landscape (P2)** — taller than the viewport, keys and title scroll out
  of view with no scroll affordance. Makes entry harder, not bypassable.
- **P3s**: 1-frame blank Settings after profile select; chevron direction inconsistency in
  the LTR wizard (**third occurrence across runs**); stale "Torah Study Tracker" footer
  branding; intro-carousel chip clipping.

### What the clean runs are worth

5554 and 5564 returned **no findings**, and that is a load-bearing result rather than an
empty one, because both demonstrated they *would* have reported one:
- 5564 investigated five suspicious-looking RTL behaviours (Row child-order reversal,
  `Switch` thumb positions, right-to-left progress fill, date-stepper arrow semantics,
  RTL-start icon placement) and confirmed each correct instead of filing it;
- both correctly declined to report the intentionally-hidden Hebrew Terms toggle;
- 5554 checked "STEP X OF 6" against `computeWizardStepTotal()`'s doc comment before
  considering it a defect, and declined to reproduce a CTA truncation, correctly scoping
  it back to API 31 rather than assuming it was fleet-wide.

### Environment, not defects

Emulators died repeatedly (5558 ×7, 5556 ×6, others less). **All classified ENVIRONMENT
on evidence**, via the host-side logcat mirror that survives device death: package-scoped
failure patterns across whole sessions returned zero matches. One genuine guest-level
SIGKILL was traced and *excluded* — a post-cold-boot mass reap of ~40 unrelated processes,
with our app on Dashboard providers at 53 MB and `contentIndex` never touched.

Some churn was self-inflicted (my APK deployment force-stopping apps mid-audit; failed
relaunches counted repeatedly). Two auditors independently diagnosed the deployment from
`installPackageLI` in guest logcat rather than filing it as a crash.

## Deliberately NOT merged

**`reassurance/run9-learn-eager-load`** — bounds `contentIndexProvider` to the curricula
backing a profile's coarse-paced tracks, instead of materialising all 9. It is well built
(a 260-line test, a clear correctness argument that every ref `collapseDafTasks` looks up
comes from those tracks' own daily tasks). It is held anyway, for three reasons:

1. **Its justification was refuted.** It was written to fix run-8's Learn OOM P0. Run-10
   measured that path at ~24% of the heap limit at its worst — so this is a memory
   optimisation for a problem that does not exist on the tested devices.
2. **It changes behaviour on the app's core surface.** The bound rests on an invariant
   ("the bound never misses"); if it is ever wrong, daf grouping silently degrades on the
   Learn tab. That is a poor trade for a saving we have measured as unnecessary.
3. **It would invalidate fresh evidence.** Run-10's Learn validation — including the
   176-daf Bava Batra drill — was performed on the *unbounded* path. Merging without
   re-testing would leave the campaign's strongest device evidence describing code that no
   longer ships.

It should be revisited on its own merits as a performance change, with its own device
validation — not carried in on a crash-fix rationale that no longer holds.

## Residual risk — what this campaign does NOT cover

Stated plainly, because a reassurance report that hides its gaps is worthless:

1. ~~**R4 (sync / cloud / Firestore rules) was never started.**~~ **RETRACTED — this claim
   was wrong, and it was the headline gap in earlier drafts of this report.** A
   comprehensive rules matrix already exists at
   `learning_tracker/functions/test/firestore_rules.test.mjs` (48 KB, ~94 cases): owner-write
   / tutor-read / stranger-and-anon-deny per collection across **24/24 match paths** in
   `firestore.rules`, SR-1..SR-5 boundary tests, a zero-denial oracle, and a cross-device
   round-trip. It runs against the **real Firestore emulator**, is gated by a TQ-9
   rule-coverage check (`functions/tool/check_rule_coverage.mjs`) asserting every
   conditional allow rule is evaluated, and **is wired into `make ci`** via `test-rules`.
   It predates this campaign (first committed 2026-05-29). Independently re-verified this
   run: 104/104 pass, and red-demoed by widening the completions tutor-write block, which
   failed exactly one test, then reverted clean.
   **The failure here was the campaign's tracking, not the codebase** — the scorecard
   carried "Phase 2 not started" and never checked. A reassurance exercise that
   under-credits existing coverage is making the same class of error as one that
   over-credits it: both mean the stated risk picture does not match reality.
   *Genuinely still open on this surface:* an on-device real-Firestore round-trip and the
   offline→cloud account-convert path.
   ⚠️ Note also that my own `make ci` run never executed these tests: `ci` runs
   `… test test-serial-tools test-rules test-functions`, and it aborted at the failing
   `test` target, so `test-rules` never ran. A green `test` is a precondition for the rules
   matrix being exercised at all.
2. **R7 is a ratchet, not a cure.** 43 source-text assertion files remain; growth is
   blocked, the existing debt is not paid.
3. **Emulator-only.** Nothing here was verified on physical hardware, by explicit
   instruction. Real-device GPU, memory pressure, and vendor Android skins are untested.
4. **Fleet instability.** Emulators died repeatedly during run-10 (some genuinely, some
   from the recovery loop itself). Device coverage is therefore less even than the matrix
   implies, and some scenarios were cut short.
5. **A debug build was measured, not release.** Release builds differ in memory and
   tree-shaking. The OOM refutation is conservative in that direction (debug uses more),
   but release was not directly measured.
6. **Load-sensitive tests exist.** One was found and fixed; others may lurk, and CI ran on
   a heavily loaded box.
