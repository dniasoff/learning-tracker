# TEA Audit — Supplement 1: Acceptance Journeys & E2E Reality (dimension re-run)

**Date:** 2026-07-09 · **Parent report:** [`_TEA-AUDIT.md`](_TEA-AUDIT.md) — chapters **3.4 (Acceptance journeys)** and **3.6 (E2E reality)** were placeholder outputs in the original run (candidate findings TEA-012/TEA-003 were empty stubs, refuted in Appendix A there). This supplement is the recommended re-run of those two dimensions. It does **not** modify the parent report; read it as the content of those two chapters.
**Branch audited:** `audit-fix/2026-07-03`, HEAD `4cf217ec` · **Register:** [`findings-supplement.json`](findings-supplement.json) · **Plan cross-check:** [test-turnaround-plan-2026-07-09.md](../../test-design/test-turnaround-plan-2026-07-09.md) (see §6, Plan impact)

---

## 1. Executive summary

**Acceptance-journeys verdict.** The three acceptance-flavoured suites are real at the data/merge layer and ceremony-leaning at the journey layer. `test/integration/` (10 files) is the healthiest: `two_device_sync_test.dart` drives the real `MergeRouter` + `EntityMerger` + `DriftMergeStore` across two real in-memory Drift DBs; Firestore is fake/absent by documented design. `test/story_acceptance/` uses real in-memory Drift at DAO/domain level, but its P0 cloud-sync acceptance (stories 13.1–13.3 + invariant N1) is skipped placeholder groups. `test/e2e/journeys/` boots the REAL `AppRouter` + guards + Riverpod graph over in-memory Drift — genuinely real shell wiring — but the harness stubs all eight core seams (auth, PIN — `hasParentPin` is ALWAYS false so the PIN guard never fires — sync facade/orchestrator null, analytics/streak no-op), journeys routinely override the very data providers under test, and verification is render-check-dominated: **535 `expectOnScreen` vs 49 DB assertions and 11 `router.currentPath` assertions across 34 files; 18/34 files make zero DB assertions**. None of 3 sampled run-6/7 escaped defects is catchable by this layer. Two make-target story gates (`test-story-6.5`, `test-story-10.5`) filter on `--name` values matching zero tests and pass green having executed nothing.

**E2E-reality verdict.** There is no on-device gate today: `integration_test/` holds exactly one 30-line smoke test asserting only that the app widget mounts, run by nothing in CI (the `make ci` canonical gate is analyze + validate-calendar + lint-rules-test + `flutter test`, and ci.yml's 7 jobs contain no integration/device step). The turnaround plan's device lane is directionally right (patrol correctly rejected for the in-Dart seams) but tiny — 3 journeys against a documented 232-journey catalog and 40 confirmed run-6/7 on-device defects that the 10,370 green tests caught zero of; the lane maps to **0 of 18 run-7 findings and ~2 of 22 run-6 findings**. Three load-bearing enablers are under-specified enough to block execution as written: an on-device state seed/reset seam (the flagship PIN journey targets a first-time-setup seam unreachable on seeded @5556), a Hebrew locale-override code seam (the app hardcodes `locale: null` by design), and result-artifact collection (no screenshots/logcat/JUnit mechanism, making TEA-FIX-014's own acceptance uncheckable).

### Counts (this supplement)

| Metric | Value |
|---|---:|
| Candidate findings raised | 17 |
| Confirmed after adversarial verification | 13 |
| Refuted (Appendix, §5) | 4 |
| P1 | 1 |
| P2 | 7 |
| P3 | 5 |
| — dimension: acceptance-journeys | 6 confirmed |
| — dimension: e2e-reality | 7 confirmed |

Severities shown are the **post-verification** severities (several were trimmed one level by verifiers; trims are recorded in the register's `verifier_notes`).

---

## 2. Chapter 3.4 (supplement) — Acceptance journeys

### 2.1 What is real, what is ceremony

| Suite | Verdict | Evidence |
|---|---|---|
| `test/integration/` (10 files) | **REAL** (healthiest) | `two_device_sync_test.dart` drives real MergeRouter + EntityMerger + DriftMergeStore across two in-memory Drift DBs; `firestore_wipe_install` uses `fake_cloud_firestore` + 4 real DBs. Firestore fake/absent by documented design. |
| `test/story_acceptance/` | **MIXED** — real DB, hollow at sync | Real in-memory Drift at DAO/domain level (invariants N3–N6/N8, restore logic). But 24 `skip:` sites including the 4 P0-sync placeholder groups (13.1/13.2/13.3 + N1); N2 is a source-text grep; N7 a pure-arithmetic tautology (already registered as AUD-t-story-acceptance-02). |
| `test/e2e/journeys/` (34 files) | **CEREMONY-LEANING** — real shell, mocked core | Boots the real `AppRouter` + AuthGuard/RestoreGuard/ProfileGuard/ChildModeGuard/PinGuard over in-memory Drift (`e2e_harness.dart:274-664`), but `_buildOverrides` (line 559) stubs every core seam; data providers overridden by the journeys themselves; assertions are render checks. |

### 2.2 Journey census (34 files, `test/e2e/journeys/`)

| Measure | Count |
|---|---:|
| `testWidgets` total | 366 |
| `skip: true` device-only stubs | 66 |
| `expectOnScreen` render-checks | 535 |
| `.dao.` / `h.db.` data assertions | 49 |
| `router.currentPath` assertions | 11 |
| Tap interactions | 179 |
| Files with **zero** DB assertions | 18 / 34 |
| `IntegrationTestWidgetsFlutterBinding` in the whole `e2e` tree | 0 |
| Render-to-DB assertion ratio | ~11:1 |

Harness seams stubbed (`e2e_harness.dart`): `authStateProvider` fixed value (:600), `_StubAuthRepository` (:601), `_NullPinService.hasParentPin()` always false (:191-200/:535 → **the PIN guard never activates in any journey**), `NullAnalyticsService` (:623), streak observer `Stream.empty` (:631-633), `syncWriteFacadeProvider = null` (:636), `syncOrchestratorProvider = null` (:637). Representative: `auth_p0_test.dart:100-125` asserts the "Welcome Back!" heading and "Sign In" button render; the actual submit→dashboard flow is `skip: true` device-only (:148-153), with a comment citing exactly the stubbed seams as the reason.

### 2.3 Invariant net N1–N8 (in default `make test` scope)

| Invariant | Status |
|---|---|
| N3, N4, N5, N6, N8 | Real behavioural tests against in-memory Drift |
| N1 (offline-queue drains to 0) | Skipped placeholder (`regression_invariants_test.dart:37-45`) — retirement is honest (drain covered by `sync_orchestrator_drain_triggers_test.dart`), but the named invariant asserts nothing |
| N2 | Source-text grep of the provider file, no runtime path |
| N7 | Pure-arithmetic tautology invoking zero production code — already registered as **AUD-t-story-acceptance-02** (P1) |

### 2.4 Dead make-target gates

Spot-check of 6 `--name`-filtered story gates found 2 dead and 2 soft-dead. `flutter test --name X` with no match exits 0, and `learning_tracker/CLAUDE.md` documents `make test-story-X.Y … fix until green` as the pre-done gate — so these gates pass green having run nothing.

| Target | Location | State |
|---|---|---|
| `test-story-6.5` | `learning_tracker/Makefile:41` | `--name "Story 6.5"` matches **zero** tests (file holds 6.1–6.4 only; `daily_schedule_composer.dart` is shipped production code) |
| `test-story-10.5` | `learning_tracker/Makefile:65` | `--name "Story 10.5"` matches **zero** tests (file holds 10.1/10.2/10.4/10.6; 10.5 is backlog) |
| `test-story-13.1` / `test-story-13.2` | `learning_tracker/Makefile:76-80` | `--name` now matches **only skipped placeholder groups** (see TEA-S02) |

### 2.5 Escaped-bug cross-check

None of the 3 sampled run-6/7 defects (commits `34616dfd`/`1fead3de`) is catchable by this layer: (1) the RTL PIN-keypad mirror — the keypad IS rendered by a journey (`profiles_p0_test.dart:562-604`) but the assertion checks digit presence, never LTR ordering under `Locale('he')` (the file never sets a locale); (2) IME-covers-CTA — no soft keyboard exists in headless `flutter test`, structurally unreachable; (3) content-search flood — the journey overrides `contentRepositoryProvider` with a fake whose `search()` re-implements the pre-fix buggy filter inline, so production search never runs (residual owned by TEA-024 / AUD-t-cross-10; see refuted TEA-S04).

### 2.6 Confirmed findings (dimension: acceptance-journeys)

| ID | Sev | Finding |
|---|---|---|
| TEA-S01 | P1 | `e2e/journeys` is a headless widget suite with a real router shell but a mocked core — 535 render-checks vs 49 DB assertions; PIN guard never fires; 18/34 files zero DB assertions (`e2e_harness.dart:559`) |
| TEA-S03 | P2 | `test-story-6.5` / `test-story-10.5` filter on `--name` values matching zero tests — silent green gates over nothing (`Makefile:41`, `:65`) |
| TEA-S11 | P2 | 0 of 3 sampled run-6/7 escapes catchable by the journey suite; even reachable surfaces assert presence, not the failing property (`profiles_p0_test.dart:588`) |
| TEA-S02 | P3 | Cloud-sync acceptance gate hollow: stories 13.1–13.3 + invariant N1 are skipped placeholders; `test-story-13.1/13.2` match only the placeholders and pass green (`epic_13_cloud_sync_test.dart:118`) — sync behaviour IS covered by unit/integration suites elsewhere, so this is a false-green-gate hygiene defect, not a coverage hole |
| TEA-S09 | P3 | "e2e" naming is dishonest: zero integration_test bindings in the tree; the harness itself documents the device-only surfaces it cannot reach; 66/366 tests are device-only skips (`e2e_harness.dart:67`) |
| TEA-S12 | P3 | The flagship reference journey silences the dashboard data providers (`dashboardSilenceOverrides`) and asserts navigation via persistent bottom-nav labels that cannot distinguish success from failure (`reference_onboarding_to_dashboard_journey_test.dart:60`) |

---

## 3. Chapter 3.6 (supplement) — E2E reality

### 3.1 Ground truth (verified against the tree)

| Fact | Value |
|---|---|
| `integration_test/` contents | exactly one file, `app_test.dart` (30 lines) — asserts only `find.byType(LearningTrackerApp)`; `TODO(DNI-393)` open since March |
| `test_driver/` | absent — no `flutter drive` path, therefore no on-device screenshot mechanism |
| CI jobs (ci.yml) | format-check, analyze, audit, lint, test, firestore-rules, arb-parity — **none** runs integration_test |
| Canonical gate | `learning_tracker/Makefile:214` — `ci: analyze validate-calendar lint-rules-test test`; `flutter test --coverage` never touches `integration_test/` |
| Only integration runner | root `Makefile:41-43` `test-integration` — manual, absent from every workflow |
| Documented journey catalog | 232 journeys (`docs/planning/e2e-test-suite-plan.md`) |
| On-device defects, runs 6+7 | 22 + 18 = 40; suite catches: **0** |
| Planned device-lane journeys | 3 (TEA-FIX-013 PIN, TEA-FIX-014 Hebrew smoke, TEA-FIX-015 sync roundtrip) |
| Lane coverage of run-7 findings | 0 / 18 (run-6: ~2 / 22) |
| Existing black-box driver | `tool/device_e2e/` (driver.py + journey_01 + run2–run7 suites; per-step screenshots to `/tmp/device_e2e/`) — proven, handles native dialogs, not referenced by the lane's artifact story |

### 3.2 Escape-class coverage of the planned lane

| Escape class (run-6/7 evidence) | Priority | Planned journey | Gap |
|---|---|---|---|
| First-time parent-PIN setup + keepAlive digit race (b8464ccc/a0c85409) | P0 | TEA-FIX-013 | Target no-PIN seam **unreachable on seeded @5556** (PIN 2580 set → guard takes the verify path; the mandated red demo — reverting b8464ccc — cannot fire) |
| Add-Track wizard step-count / smart-default (run7 H1–H3 on all 3 devices; H7) | P0 | none | Recurring escape, identical on every device → host-catchable state logic; belongs in the T2 host-screen scope, currently owned by no wave |
| Tutoring invite/accept/decline/enter-session + error mapping (run6 22% pass, run7 1/7 — worst suite both runs; catalog P0 highest-risk) | P0 | none | No UI journey anywhere in the plan |
| Google Sign-Up new user + OS permission prompt (E2E-114/1206/1107) | P0/P1 | none | Catalog implements these via stub overrides headlessly (see refuted TEA-S15) — native driving is NOT required for the in-scope seams |
| Per-entity sync round-trip (TEA-014) | P0 | TEA-FIX-015 | No data isolation/teardown, no verified-email provisioning, no positive write-auth pre-check (TEA-S08) |
| Auth/onboarding forms under IME on small screens (run6 #1/#2) | P1 | none | Device-reality class; a11y-tree hit-test assertable on-device |
| Small-screen clipping without overflow exceptions (run7 H4 Friday row 9px ShaderMask clip, H11 invisible Taharos seder) | P1 | partial (TEA-FIX-014) | These throw **no** RenderFlex overflow — the smoke's overflow-only assertion structurally misses them (TEA-S16) |
| Hebrew/RTL visual correctness (run6 #9/#11, run7 H5/H8/H14) | P1 | TEA-FIX-014 + host goldens | Keypad/progress-tree surfaces not among the 4 golden baselines; smoke asserts overflow only |
| Accessibility semantics (run6 #4/#8; run7 H10/H16/M2) | P1 | none | integration_test can assert semantics; no a11y journey |
| Offline-first device paths (E2E-113/212/810/923/1015, Area 13) | P0/P1 | none | No deterministic offline seam on-device: connectivity check is an unmockable static (TEA-019/040) and airplane mode also kills App Check (TEA-S14) |

### 3.3 Under-specified enablers that block execution as written

1. **On-device state seed/reset.** `integration_test` boots `app.main()` against the device's real persistent Drift DB + SecureStorage. @5556 holds Parent PIN 2580, and the plan forbids wiping it (App Check debug token). No per-journey seed/reset hook is specified, yet the flagship journey needs the no-PIN state. A targeted SecureStorage parent-PIN-key delete (no wipe, token survives) or reassignment to clean @5554 resolves it — the plan just has to say which (TEA-S05).
2. **Hebrew locale-override seam.** `learning_tracker_app.dart:84` hardcodes `locale: null` ("no in-app language switcher" by design); `LearningTrackerApp` takes no locale parameter; production images can't `setprop` locale. The plan's "test-only locale-override entrypoint" therefore names a seam that does not exist yet — buildable cheaply (`tester.platformDispatcher.localeTestValue`, an emulator device-locale set, or a debug locale param) but it must be sequenced inside TEA-FIX-012 before TEA-FIX-014 (TEA-S06).
3. **Result artifacts.** No `test_driver/` exists; `flutter test -d` cannot capture on-device screenshots (needs `flutter drive` + `integrationDriver(onScreenshot:)`, or the existing `tool/device_e2e` screencap path). TEA-FIX-014's acceptance ("logcat shows zero RenderFlex overflow") specifies no logcat capture/parse mechanism; `run_lane.sh` defines no screenshot/logcat/JUnit output — the run-6/7 evidence trail is discarded (TEA-S13).
4. **Cloud journey hygiene.** TEA-FIX-015 hits live Firestore with shared `test-loop-a/c@orvex.test` accounts, no teardown/namespacing, no verified-email provisioning, and App Check failures are swallowed silently with a 10s timeout (`firebase_bootstrap.dart:39-41`) — a stale token surfaces as a confusing merge failure, not an auth error (TEA-S08).
5. **Offline/network seam.** The in-app connectivity check is a process-global static (`InternetConnectionChecker.instance` / `_lastKnownOnline`) not overridable from an integration_test driving `app.main()`; airplane mode conflates "offline UI" with "auth denied" (TEA-S14).

### 3.4 Confirmed findings (dimension: e2e-reality)

| ID | Sev | Finding |
|---|---|---|
| TEA-S07 | P2 | Device lane covers none of the dominant run-6/7 escape classes — no journey for wizard-state logic, tutoring, IME/small-screen, or a11y (plan line 27); verifiers note the wizard item belongs in the **host** T2 scope, tutoring in the device lane |
| TEA-S08 | P2 | TEA-FIX-015 hits production Firestore with shared accounts; no isolation, no verified-account provisioning, no positive App-Check pre-check — failures silently swallowed (plan line 118; `firebase_bootstrap.dart:39-41`) |
| TEA-S13 | P2 | Device lane produces no durable result artifacts — no screenshots, no logcat capture, no JUnit; TEA-FIX-014's acceptance is uncheckable as specified (plan line 116) |
| TEA-S14 | P2 | No offline/network-state device journey despite offline-first being the core model; the on-device connectivity seam is unmockable and airplane mode kills App Check (plan line 112) |
| TEA-S16 | P2 | TEA-FIX-014's overflow-only assertion cannot catch the actual run-7 Hebrew/small-screen defects (H4/H8/H11 throw no overflow) and duplicates headless `overflow_sweep_p2_test.dart` without stating the device delta (plan line 117) |
| TEA-S05 | P3 | Flagship PIN journey (TEA-FIX-013) cannot reach its target first-time-setup seam on seeded @5556; no state seed/reset seam specified (plan line 74) — resolvable with a targeted PIN-key clear or reassignment to @5554 |
| TEA-S06 | P3 | Hebrew locale-override entrypoint has no supporting code seam — `locale: null` hardcoded by design (`learning_tracker_app.dart:84`); the seam is in-scope for TEA-FIX-012 but is net-new work that must be sequenced before TEA-FIX-014 |

---

## 4. Full findings register (supplement)

All 13 confirmed findings, ranked. Full evidence, impact, proposed fixes, and complete verifier notes (including severity-trim rationales) are in [`findings-supplement.json`](findings-supplement.json).

| ID | Sev | Dim | Category | Location | Finding | Verification |
|---|---|---|---|---|---|---|
| TEA-S01 | P1 | acceptance | acceptance-ceremony | `test/e2e/harness/e2e_harness.dart:559` | Real router shell, mocked core; render-check-dominated verification (535:49) | CONFIRMED 3/3 |
| TEA-S03 | P2 | acceptance | dead-gate | `learning_tracker/Makefile:41,65` | Two story gates match zero tests, exit green | CONFIRMED 3/3 (trimmed P1→P2: backlog-story blast radius) |
| TEA-S07 | P2 | e2e | coverage-gap | plan `:27` | Lane maps to 0/18 run-7 escapes; wizard/tutoring/IME/a11y uncovered | CONFIRMED 3/3 (trimmed P1→P2; wizard item re-attributed to host T2 scope) |
| TEA-S08 | P2 | e2e | lane-design-blocker | plan `:118` | Sync roundtrip vs prod Firestore: no isolation/provisioning/positive auth pre-check | CONFIRMED 3/3 (trimmed P1→P2: false-red flakiness, not false-green) |
| TEA-S11 | P2 | acceptance | escaped-bug-blindness | `profiles_p0_test.dart:588` | 0/3 sampled escapes catchable; presence asserted, not the failing property | CONFIRMED 1/1 |
| TEA-S13 | P2 | e2e | lane-design-blocker | plan `:116` | No screenshots/logcat/JUnit; TEA-FIX-014 acceptance uncheckable | CONFIRMED 1/1 |
| TEA-S14 | P2 | e2e | coverage-gap | plan `:112` | No offline device journey; connectivity seam unmockable on-device | CONFIRMED 1/1 |
| TEA-S16 | P2 | e2e | assertion-gap | plan `:117` | Overflow-only smoke misses H4/H8/H11 defect classes; duplicates headless sweep | CONFIRMED 1/1 |
| TEA-S02 | P3 | acceptance | skipped-gate | `epic_13_cloud_sync_test.dart:118` | 13.1–13.3 + N1 placeholders; make gates match only placeholders | CONFIRMED 2/3 (trimmed P1→P3: composed sync path IS covered by `two_device_sync_test` et al.; residual = Makefile hygiene) |
| TEA-S05 | P3 | e2e | lane-design-blocker | plan `:74` | PIN journey's no-PIN seam unreachable on seeded @5556 | CONFIRMED 2/3 (trimmed P1→P3: targeted PIN-key clear avoids the wipe dilemma; spec omission, not hard blocker) |
| TEA-S06 | P3 | e2e | lane-design-blocker | `learning_tracker_app.dart:84` | Locale-override seam does not exist yet; must be built and sequenced | CONFIRMED 2/3 (trimmed P1→P3: no-code alternatives exist; seam already in TEA-FIX-012's deliverables) |
| TEA-S09 | P3 | acceptance | naming-honesty | `e2e_harness.dart:67` | "e2e" tree has zero integration bindings; runs headless | CONFIRMED 1/1 (trimmed P2→P3: harness code is self-honest; risk is dashboard over-read) |
| TEA-S12 | P3 | acceptance | over-stubbing | `reference_onboarding_to_dashboard_journey_test.dart:60` | Reference exemplar silences data providers; navigation assertion non-discriminating | CONFIRMED 1/1 (trimmed P2→P3: documented smoke intent; tautological nav assertion is the durable residue) |

---

## 5. Appendix — Refuted findings

Four candidates did not survive adversarial verification. Reported for transparency; do not action as written.

| ID | Claimed sev | Claim | Why refuted |
|---|---|---|---|
| TEA-S04 | P1 | Content-search journey overrides the repo with a fake that re-implements search — tautology that cannot catch the flood bug | **Duplicate + misattributed evidence.** The single-leaf 'BerakhotSeder' fixture cited belongs to E2E-307 (stage breakdown), not the search journey E2E-306, which seeds a full ancestor-qualified item. The flood bug IS regression-guarded by a real unit test executing production `ContentRepositoryImpl.search()` (`content_repository_impl_logic_test.dart:260-280`). Residual (E2E fake diverges from production) already owned by TEA-024 + AUD-t-cross-10 / AUD-t-content_browsing-04. |
| TEA-S10 | P2 | N1–N8 invariant net partly inert (N1 skipped, N2 grep, N7 tautology) | **Duplicate.** The material core (N7 invokes zero production code) is AUD-t-story-acceptance-02 (P1, CONFIRMED) verbatim. N1's retirement is honest hygiene with a live replacement (`sync_orchestrator_drain_triggers_test.dart`); N2's grep does guard the literal symbol. |
| TEA-S15 | P2 | Decision (a) rejects native automation on a false premise; Google-Sign-Up/permission journeys need native driving | **Premise wrong.** E2E-114/1206/1107 are specified as stub-override headless journeys in the catalog itself; no native dialog driving is needed for the in-scope seams. E2E-1107 is P1, not P0; and the plan does not ignore `tool/device_e2e` — TEA-FIX-012 builds `run_lane.sh` in that directory. The deferral of broader acceptance investment is a documented non-goal (g)(4) + human decision point 5. |
| TEA-S17 | P2 | `integration_test/app_test.dart` is a dead smoke stub run by no CI job | **Duplicate.** Every fact verified true, but the actionable substance (no on-device CI gate; app_test only asserts the widget mounts) is AUD-t-cross-48 (P2) plus AUD-guardrails-16 (the DNI-393 TODO). The stub is an intentional, Linear-tracked placeholder. |

---

## 6. PLAN IMPACT — what waves T0G / T2 / T3 must absorb

Cross-checked against [test-turnaround-plan-2026-07-09.md](../../test-design/test-turnaround-plan-2026-07-09.md). **The plan's architecture survives this re-run**: decision (a) (patrol rejected) stands — TEA-S15, the only challenge to it, was refuted; the T0/T1 host spine is untouched by any supplement finding. The changes below are corrections and additions inside the existing waves, not restructuring.

### 6.1 Wave T0G — TEA-FIX-013 (parent-PIN nav-guard journey)

**One correction, blocking as written (TEA-S05).** On seeded @5556 (Parent PIN 2580 in SecureStorage), `pin_guard.dart:101-113` takes the **verify** path, so the journey never reaches the first-time-setup push-result-completer seam it targets, and the mandated red demo (revert b8464ccc, which touched only the setup path) cannot fire — the gate would go green-but-wrong. Absorb into the item's builder instruction, either:

- **(preferred)** a targeted `setUp` step deleting only the parent-PIN key from `FlutterSecureStorage` (no wipe; child Drift data and the App Check debug token survive — the "never wipe @5556" constraint is not in conflict), restoring PIN 2580 in `tearDown`; **or**
- run the no-PIN setup case on clean **@5554** and keep @5556 for a seeded verify-path case.

Either way, make the state precondition explicit in the acceptance and verify the red demo actually fires before recording it.

### 6.2 Wave T2 — screen-integration scope

1. **Add the Add-Track wizard to the canonical screen set (or as a 4th T2 item).** The recurring TS-11 step-count no-op (run7 H1–H3, reproduced identically on all 3 devices; plus the H7 snackbar/hub mismatch) is host-catchable state logic — verifiers explicitly re-attributed it from the device lane to T2's remit. It is currently owned by **no** wave. Acceptance: stable step denominator across the wizard, correct post-create hub/snackbar label. (From TEA-S07.)
2. **Fix the reference journey the T2 pattern is copied from (TEA-S12).** `reference_onboarding_to_dashboard_journey_test.dart` pumps `/dashboard` under `dashboardSilenceOverrides` and asserts navigation via persistent bottom-nav labels (cannot distinguish success from failure). Have TEA-FIX-010's builder also convert this exemplar: seed real dashboard data, assert `router.currentPath` (getter already exists at `e2e_harness.dart:411`, unused) or a route-unique widget. Small delta on an item already editing these patterns.
3. **PIN-keypad RTL ordering assertion (TEA-S11).** Where a run-6 escape surface IS headless-reachable, assert the failing property: add an LTR digit-order assertion for the PIN keypad under `Locale('he')` to the TEA-FIX-009 `pump_both_directions` harness set (or add the keypad as a 5th golden surface in TEA-FIX-004's set if T0 hasn't shipped). Do **not** otherwise expand headless journeys expecting them to catch RTL/IME/overflow classes — TEA-S11 confirms they are orthogonal.

### 6.3 Wave T3 — device lane

1. **TEA-FIX-012 must build and sequence the locale seam first (TEA-S06).** The "test-only locale-override entrypoint" names a seam that does not exist (`learning_tracker_app.dart:84` hardcodes `locale: null`; `LearningTrackerApp` has no locale param). Pick one mechanism explicitly — `tester.platformDispatcher.localeTestValue` in the harness (zero app-code change), setting the emulator's device locale (the app is device-follows-locale by design), or a debug-only locale parameter threaded through `bootstrap()` — and land it inside TEA-FIX-012 **before** TEA-FIX-014 dispatches.
2. **TEA-FIX-012 must specify artifact collection (TEA-S13).** `run_lane.sh` gains: `adb logcat` capture to a per-journey file + a RenderFlex/overflow grep (otherwise TEA-FIX-014's acceptance is uncheckable), a screenshot mechanism (either `test_driver/integration_test.dart` + `flutter drive` with `integrationDriver(onScreenshot:)`, or reuse the proven `tool/device_e2e` screencap path), and a JUnit/exit-status artifact per journey. The universal red-demo rule requires recorded evidence; the lane currently cannot produce any.
3. **TEA-FIX-014 assertion upgrade (TEA-S16).** The run-7 Hebrew/small-screen defects (H4 9px ShaderMask clip, H11 invisible Taharos seder, H8 "daf ב" word-break) throw **no** RenderFlex overflow. Augment the overflow assertion with: visibility/hit-test assertions on the last item of scrollable lists (Friday row, 6th seder), an NBSP/word-integrity check on breadcrumbs, and a stated device delta vs the existing headless `overflow_sweep_p2_test.dart` so scope isn't duplicated.
4. **TEA-FIX-015 hardening (TEA-S08).** Add: a scripted positive pre-flight performing one known authorized write and asserting it lands (a stale App Check token currently surfaces as a silent merge failure — `firebase_bootstrap.dart:39-41` swallows activate() failures); idempotent verified-email provisioning of the test accounts (run-6/7 required the gcloud admin email-verify step per `tool/device_e2e/README.md:24`); per-run doc namespacing or teardown on the shared `test-loop-a/c@orvex.test` data; consider the Firestore emulator for the full matrix and reserve prod for a thin smoke.
5. **Journey-set decision (TEA-S07/S14) — route explicitly, don't leave silent.** The 3-journey lane maps to 0/18 run-7 escapes. Recommend adding **one tutoring journey** (invite→accept→enter-session; worst-passing suite both runs, catalog P0-highest-risk, covered by nothing in the 18-item plan) and **one IME/small-screen form journey** (primary CTA hit-testable with the keyboard open) to T3 — or, at minimum, record their deferral under human decision point 5 so the gap is a decision, not an omission. The **offline device journey** (TEA-S14) is blocked on a debug connectivity-override seam (the static `InternetConnectionChecker` singleton, TEA-019/040); log the seam as a prerequisite item and forbid the airplane-mode shortcut (it conflates offline with App-Check denial).

### 6.4 Wave T4 (dead-gate cleanups — natural home, noted for completeness)

Extend **TEA-FIX-018** (which already deletes the two TEA-046/049 placeholder files) with the supplement's dead-gate set, all S-effort: (a) fix or remove `test-story-6.5` / `test-story-10.5` (`Makefile:41/:65` — `--name` matches zero tests, TEA-S03); (b) delete or repoint `test-story-13.1`/`test-story-13.2` plus the epic_13 skipped placeholder groups and invariant N1 at the live sync suites that replaced them (TEA-S02); (c) add a zero-tests-ran guard to the `test-story-%` pattern so a `--name` filter matching nothing fails instead of passing. Optionally ride the same item: rename `test/e2e/` → `test/widget_journeys/` or add a README disclaimer (TEA-S09).

### 6.5 What does NOT change

- **Decision (a) stands.** TEA-S15 (the patrol/native challenge) was refuted on its premise; the catalog's Google-Sign-Up/permission journeys are stub-driven headless designs.
- **No new register work for N7 or app_test.dart** — TEA-S10 and TEA-S17 are duplicates of AUD-t-story-acceptance-02 and AUD-t-cross-48/AUD-guardrails-16 respectively, already owned by the standards trains.
- **Non-goal (g)(4) is now discharged** by this supplement; human decision point 5 (acceptance-journey investment beyond T3) can be ruled on with this evidence in hand. The headline input to that ruling: the headless journey layer's coverage is orthogonal to where the product actually fails (TEA-S01/S11), so further investment should go to the device lane + goldens, not to more headless journeys.

---

*Refs: all TEA-S* ids resolve in [`findings-supplement.json`](findings-supplement.json); TEA-* in the parent [`findings.json`](findings.json); AUD-* in the standards register + delivery ledger. Method: two independent recon agents (one per dimension), 13+ deep file reads each, followed by adversarial verification (1–3 verifier votes per finding; severity trims recorded). Branch `audit-fix/2026-07-03` @ `4cf217ec`, 2026-07-09.*
