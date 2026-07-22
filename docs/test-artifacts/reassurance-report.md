# Release Reassurance — final report

> **STATUS: IN PROGRESS.** Sections marked ⏳ are awaiting run-10 device reports and
> the final fix wave. Everything else is settled and evidenced. This document is the
> campaign's deliverable: an honest account of what is now trustworthy, what is not,
> and what remains unknown.

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
| **R4** Sync / cloud / rules | 🔴 | **Not started.** See Residual Risk. |
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

## Device findings ⏳

Run-10 covered six emulators (API 28/29/31/33/34/36-tablet). Reports pending for five.

Confirmed so far:
- **Reader input loss (P2)** — measured across two rounds: 5 taps → 1 advance, and
  68 taps → 34 advances (~2 taps eaten per page) on the app's primary *reading* surface.
- **Reader memory retention** — grows then plateaus under sustained paging; perf item, not a risk.

## Residual risk — what this campaign does NOT cover

Stated plainly, because a reassurance report that hides its gaps is worthless:

1. **R4 (sync / cloud / Firestore rules) was never started.** No rules matrix, no
   on-device real-Firestore round-trip, no account-convert path verification. This is the
   largest untested surface and it touches data durability.
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
