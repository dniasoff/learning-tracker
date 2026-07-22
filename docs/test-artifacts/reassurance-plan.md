---
title: "Release Reassurance Plan"
author: "Murat — Master Test Architect"
date: 2026-07-22
status: active
scope: "Learning Tracker (Flutter, offline-first Firebase sync, Hebrew/RTL-first, children's data). Current dev HEAD f8b42240."
---

# Release Reassurance Plan

> **The purpose of this plan is one thing: to let Daniel trust a green build.**
> Today he cannot, and he is right not to. This document defines what would have
> to be *true* — with evidence — for that trust to be earned, and the campaign to
> get there.

---

## 0. What "reassured" means (and what it does not)

**Reassurance is not a green test count.** The defining fact of this codebase:

| Signal | Value |
|---|---|
| Green automated tests | ~10,370 |
| On-device audit runs to date | 7 (run 8 in flight) |
| Real defects those on-device runs found | **107** |
| Of run-6's 22 on-device defects, caught by the suite first | **0** |
| P0 child-data-corruption escapes that shipped past all 10,370 tests | **3** (lifetime total inflated ~3.8×) |
| `fix(...)`/bug/regress commits in history | ~1,713 |
| l10n/RTL/overflow fix commits | ~160 |
| Suite's RTL/Hebrew behavioural coverage (the app's PRIMARY locale) | ~3% |

A green suite that misses the bugs that actually ship is *anti*-reassurance: it
manufactures false confidence. So this plan does **not** chase a higher test
count. It defines reassurance as:

> **For each top risk surface, an INDEPENDENT, REPEATABLE line of evidence that
> the surface's DEMONSTRATED failure mode is now caught *before* ship — plus a
> live gate that keeps it caught — each gate proven by a RED DEMO.**

Three non-negotiable principles (carried from the TEA audit's own rules):

1. **Red-demo every gate.** A new quality gate ships only with recorded proof that
   it fails when the bug class is (re)introduced, and passes when reverted. A gate
   never demonstrated red is presumed inert (this app already has an inert golden
   layer and once had a rules job that read a non-existent path for months).
2. **Verify at the layer the bug lives.** ~60% of escapes are device-reality
   (RTL/overflow/lifecycle). No amount of over-stubbed widget tests reaches them.
   Depth follows risk, at the correct rung.
3. **Evidence, not vibes.** Every claim of "reassured" points to an artifact
   (a failing-then-passing test, a golden diff, a device screenshot + backend
   assertion, a coverage delta) — reviewable, re-runnable.

The deliverable of this plan is a **Reassurance Scorecard** (§4): per surface,
RED / AMBER / GREEN, each cell linking to its evidence. Daniel is "reassured"
when the surfaces that matter for the decision-at-hand are GREEN and the gate
that holds them there is proven.

---

## 1. Risk model — calibrated to THIS app's demonstrated escapes

Not a generic checklist. These are the seams the product has actually shipped
bugs through, ranked by (impact × escape-frequency). Impact is weighted for a
**children's app handling their learning data** — silent data corruption and a
broken parent-PIN gate are the top of the scale.

| # | Risk surface | Demonstrated failure mode | Evidence | Sev |
|---|---|---|---|:--:|
| R1 | **Child-data integrity** | Lifetime/progress over-counting via scope-id collision + ledger corruption | 3 P0 escapes; fixtures use globally-unique ids so collision is structurally invisible (TEA-002) | **P0** |
| R2 | **Device-reality rendering** | RTL/BiDi/overflow across API 9–16 + tablet; text clipped, mirrored wrong, off-screen controls | ~60% of escapes; 160 RTL fixes vs ~3% suite RTL coverage (TEA-011/005) | **P0** |
| R3 | **Parent-PIN / child-mode / privacy** | Auth-gate regressions on AutoRoute completer/keepAlive timing; escalation guard tested tautologically | P0 auth surface regressed 4+ times (TEA-006/009) | **P0** |
| R4 | **Offline-first sync & cloud correctness** | Offline-first *swallows* cloud failures; codec emits field rules reject → PERMISSION_DENIED invisible to fakes; App Check blocks real device | recurring "sync never works on my phone"; merge/codec escapes (TEA-014/015/027) | **P1** |
| R5 | **Reactivity / staleness** | Derived provider never re-executes on its mutation tick → stale UI | 63 escapes, each fixed after the fact; no systemic contract (TEA-004) | **P1** |
| R6 | **Release gate & flake trust** | "Green" can be green-by-luck: no flake policy, coverage hides never-run files, CI once inert | 0 `@Timeout()`, no retry/randomize/quarantine; 123 files absent from lcov denominator (TEA-013/038) | **P1** |
| R7 | **Full-journey acceptance** | End-to-end user journeys (onboard→learn→sync→redeem) never exercised whole | 1 of 232 device journeys proven; over-stubbed screen tests assert only a Scaffold exists (TEA-010) | **P1** |

Everything below maps back to closing these seven.

---

## 2. The campaign (phased)

Each phase lists **activities**, the **evidence artifact** it produces, and its
**exit criterion** (the measurable thing that flips a Scorecard cell to GREEN).
Phases 0–1 are the foundation; 2–3 are the safety-critical core; 4–5 make the
gate trustworthy and produce the sign-off.

### Phase 0 — Baseline & instrument *(what is our REAL defect rate?)*
You cannot be reassured about a number you have never measured. First, measure.

- **A0.1 On-device reality run** — 6-device audit (Android 9/10/12/13/14/16),
  offline-account seed, every screen, adversarial-verified. *(Run 8 — in flight.)*
- **A0.2 Coverage-by-risk map** — lcov re-computed with an *every-`lib/*.dart`-in-denominator* guard; per-risk-surface coverage (not one global 60%). Surfaces R1–R7 each of `lib/` mapped to their real % + escaped-bug list.
- **A0.3 Flake baseline** — run the suite 5× with `--test-randomize-ordering-seed=random`; record any order-dependent or intermittent failures. Establishes whether "green" is even *stable*.
- **Evidence:** `device-audit-run8/_REPORT.md`; `coverage-risk-map.md`; `flake-baseline.md`.
- **Exit:** we have a *quantified* current defect rate per surface, and know whether the suite is deterministic.

### Phase 1 — Close the highest-leverage layer gaps *(the 5 P1s from the framework validation)*
These are where the escapes concentrate. Each ships with a red-demo.

- **A1.1 De-tautologize acceptance (R7).** Convert the 67 source-text-grep "tests" (esp. 21 `story_acceptance`) into behavioural tests (pump + assert observable effect). Move genuine structural checks to `make audit`/custom-lint. **Ratchet:** forbid new `readAsStringSync`-of-`lib` asserts under `test/`.
- **A1.2 Collision / property-based fixture (R1).** A generator that, for any `CurriculumId`, emits sibling leaves sharing a level-N id across distinct parents + matching ledger scope-mark, and asserts only the targeted parent is credited. Driven over `CurriculumId.values` → future curricula auto-swept. **Red-demo:** reintroduce the scope-id bug, watch it fail.
- **A1.3 Repair the shared data-factory layer (R1).** One `ContentItem`/`LearningLedger` factory; migrate the 15 hand-rolled `_leaf()` reimplementations; ratchet adoption.
- **A1.4 Re-enable the golden matrix (R2).** Baseline the 9 `skipGolden:true` canonical screens in **en AND he**; flip to `false`. Fonts/harness already support it. Track as a story so the deferral can't become permanent.
- **A1.5 RTL behavioural harness (R2).** A both-directions pump harness over the hotspot screens; a `make audit` lint forbidding hardcoded Latin under `he`. Target: RTL behavioural coverage 3% → the screens that matter, not 100% for its own sake.
- **A1.6 Reactivity contract (R5).** `expectRebuildsOn(container, provider, trigger)`; adopt across the ~70 ad-hoc counter sites so every reactive provider gets the contract by construction. **Red-demo:** drop a `ref.watch`, watch it fail.
- **Evidence:** failing→passing test PRs per item; golden baselines committed; two new ratchets in `make audit`.
- **Exit:** R1/R2/R5/R7 each have a systemic (not per-bug) guard with a recorded red-demo.

### Phase 2 — Cloud / sync / rules reality *(the invisible class, R4)*
Offline-first hides these; only real backends surface them.

- **A2.1 Rules-emulator matrix** — owner/tutor/stranger × every collection × `hasOnly` field-set, incl. the codec↔rules contract kept in lockstep. Hard-fail in CI (already is; extend coverage).
- **A2.2 On-device real-Firestore round-trip** — on a debug build with App Check debug token registered: seed → mutate → assert the write **landed in live Firestore** and **pulled back** correctly (the genuine end-to-end the fakes cannot prove). This is where the `tool/device_e2e` driver earns its keep.
- **A2.3 Convert-offline→cloud path** — the data-migration seam (lowest-covered screen at ~51%): create offline account + data, go online, upgrade, assert zero data loss / no duplication.
- **A2.4 Outbox / merge property tests** — LWW convergence + tie-break under reordering/duplication (fold in the divergent `remoteIsNewer` history).
- **Evidence:** `rules-matrix-report.md`; on-device round-trip screenshots + Firestore assertions; convert-path evidence.
- **Exit:** R4 has a proven real-backend line of evidence, not just fakes.

### Phase 3 — Safety-critical: parent-PIN, child-mode, privacy *(R3)*
The one surface where a bug is a child-safety incident, not a UX nit.

- **A3.1 De-tautologize the PIN/escalation guard tests** — remove the stub-the-decision-and-re-implement-it tautologies; assert the *real* guard against a real container.
- **A3.2 On-device nav-guard timing** — `integration_test/` coverage of the AutoRoute PIN push-result/keepAlive races that widget tests provably cannot reach (the exact seam that regressed 4×).
- **A3.3 Privacy invariants** — child profiles never expose parent-only surfaces; PIN required for every escalation path; no child PII in logs/analytics/crash payloads. Assert as invariants, red-demo each.
- **Evidence:** integration_test run on device; invariant test suite with red-demos.
- **Exit:** R3 GREEN with on-device + invariant evidence; zero tautologies on the child-safety path.

### Phase 4 — Make "green" mean green *(R6 — the meta-gate)*
Until this phase, a green run is not trustworthy. This phase makes it so.

- **A4.1 Flake policy** — `dart_test.yaml` global `timeout:`; `--test-randomize-ordering-seed=random` in CI; a `quarantine` tag + non-blocking quarantine lane; a PR burn-in job re-running changed `*_test.dart` N×.
- **A4.2 Coverage gate by risk** — per-directory/risk-tier floors; every-`lib`-file-in-lcov guard so 0%-covered files (e.g. `google_sign_in_gateway_impl`) cannot vanish from the denominator.
- **A4.3 On-device / integration E2E in CI** — an emulator-runner job (`android-emulator-runner` + `flutter test integration_test/`, and/or the `device_e2e` harness against the Firebase emulator suite). At minimum, wire the device-suite size check + expand beyond the lone smoke test.
- **A4.4 CI honesty** — reconcile `make ci` (add `format-check`), fix the `CLAUDE.md` claims, de-soft-skip the `audit`/`lint` jobs, single required-files manifest.
- **Evidence:** CI config diffs + a red-demo per new gate (introduce a flake / a 0%-file / an overflow, watch the right job fail).
- **Exit:** R6 GREEN — a green CI run is demonstrably order-independent, denominator-honest, and device-inclusive.

### Phase 5 — Release-readiness gate & sign-off
- **A5.1 Trace the release** — map the release's must-work journeys (R7's top ~20 of 232) to the evidence proving each, on device.
- **A5.2 NFR evidence** — performance (cold start, large-curriculum scroll), reliability (offline→online, kill-restart mid-write), security (rules, App Check, no child PII leak).
- **A5.3 The Scorecard** (§4) filled, every cell GREEN or an explicit, accepted WAIVER with rationale.
- **Evidence:** `release-trace.md`, `nfr-evidence.md`, the signed Scorecard.
- **Exit:** a single page Daniel can read in two minutes that says, with links, *why* this build is trustworthy.

---

## 3. How it runs (orchestration & realism)

- **Engine.** Each phase is one or more `Workflow` fan-outs: parallel builders in
  isolated worktrees, opus adversarial verifiers, serialized merges onto a
  `reassurance/*` branch, `make ci` green as the wave-exit gate. Same discipline
  that ran the standards/TEA fixes.
- **On-device constraint (measured today).** 6 concurrent emulators driven through
  one adb server *flap* under load on this box (not OOM — 123 GB free). The
  on-device rungs run **3–4 devices concurrently**, tolerate transient blips with
  retries, and pin serials. This is a capacity fact, folded into A0.1/A2.2/A4.3.
- **No commits to `dev` without green + review.** Every wave rebased, `make ci`
  green, adversarially verified, human-reviewed at the wave summary.
- **Red-demo ledger.** Every new gate's red-demo is recorded in
  `docs/test-artifacts/red-demos/` — the proof the gate is not inert.

---

## 4. The Reassurance Scorecard *(the deliverable Daniel reads)*

Filled as phases land. GREEN = systemic guard + recorded red-demo + in the gate.

| Surface | Today | Target evidence | Status |
|---|:--:|---|:--:|
| R1 Child-data integrity | 🔴 | Property/collision fixture over `CurriculumId.values` + migration-equivalence, red-demoed | ⬜ |
| R2 Device-reality (RTL/overflow, API 9–16) | 🔴 | en+he golden matrix live + RTL behavioural harness + multi-device on-device run | ⬜ |
| R3 Parent-PIN / privacy | 🔴 | On-device nav-guard timing + de-tautologized guards + privacy invariants | ⬜ |
| R4 Sync / cloud / rules | 🟠 | Rules matrix + on-device real-Firestore round-trip + convert-path | ⬜ |
| R5 Reactivity | 🔴 | `expectRebuildsOn` contract adopted, red-demoed | ⬜ |
| R6 Gate & flake trust | 🟠 | Flake policy + risk-tier coverage + device-in-CI, each red-demoed | ⬜ |
| R7 Full-journey acceptance | 🔴 | Top-20 journeys traced to on-device evidence; acceptance de-tautologized | ⬜ |

*(🔴 unguarded · 🟠 partial · 🟢 reassured. Today's colours are the honest
starting point from the framework validation + TEA reconciliation.)*

---

## 5. Sequencing

```
Phase 0 (baseline) ─┬─► Phase 1 (layer gaps) ─┬─► Phase 4 (trustworthy gate) ─► Phase 5 (sign-off)
                    │                          │
                    └─► Phase 2 (cloud/sync) ──┤
                    └─► Phase 3 (PIN/privacy) ─┘
```

Phase 0 first (measure). Phases 1/2/3 parallelizable after it. Phase 4 needs 1–3's
guards to exist before it can gate on them. Phase 5 is the closeout.

**Order of execution chosen for fastest reassurance-per-unit-effort:**
0 → 1 (R1, R2, R5, R7 systemic guards) → 3 (child safety) → 2 (cloud reality) →
4 (make green mean green) → 5 (sign-off). R1 and R3 are sequenced early because
they are the two P0s where a miss is a data-corruption or child-safety incident.

---

*Authored by the Master Test Architect. This is a living plan; the Scorecard is
updated as each phase produces its evidence. "Reassured" is declared per surface,
against artifacts — never against a count.*
