# Test-Framework Architecture Validation Report

**Scope:** Validates the Learning Tracker test-framework architecture (Dart/Flutter, package `learning_tracker/`) against the BMAD test-framework best-practice checklist, **translated from its npm/Playwright/Cypress origin** to this stack. Evidence grounded in current `dev` at **HEAD `f8b42240`** (verified: `git rev-parse` = `f8b42240`, branch `dev`). The 2026-07-09 TEA audit (a different branch, ~1953 commits behind) is treated as a *hypothesis to re-verify*, not as current state.

---

## 1. Executive summary

**Overall gate: CONCERNS (WARN).** Ship-blocking? No. Complacency-justifying? Also no.

The framework is architecturally sound and, in places, best-in-class: a 9-job parallel CI pipeline gates production deploys (fail-closed), every external seam (network, Firestore, auth, storage, clock, prefs, fonts) has a functional, error-capable fake, a 10-rung fidelity ladder genuinely exists with 8 rungs in CI, and the ~10.4k-test suite is assertion-rich (≈4.3 `expect()`/widget test). One section is PASS (helper utilities/fakes); the other seven assessed sections are WARN; none is FAIL. The gate is CONCERNS rather than PASS because real best-practice intent is unmet in five areas that a green test count hides:

1. **Verification placement.** 63 files / 122 sites assert on `lib/` **source text** (`contains('...extends ConsumerWidget')`) instead of behavior — a TEA-009 tautology, institutionalized by `test/helpers/lib_source.dart` and concentrated in the `story_acceptance` layer (21/58 files).
2. **No flake strategy at any layer.** `dart_test.yaml` has no `timeout`/`retry`/`concurrency`; 0 `@Timeout()` across the tree; no order-randomization, retry, burn-in, or quarantine lane in CI. A hung test burns the whole job budget (the very failure that forced the 30→60→split CI rework).
3. **The TEA-002 P0 collision class is regression-tested but its systemic remedy is unbuilt** — no property-based/collision fixture; the shared data-factory layer is fractured (15 files hand-roll `ContentItem _leaf()`; shared fixture used by 2).
4. **Golden/pixel coverage is thin** — 18 of 22 registered pixel sub-tests are `skipGolden:true`; only 3 real product surfaces have live baselines.
5. **The top of the ladder (on-device / integration E2E) has no CI path** — 1 proven device journey of 232; `integration_test/` is a lone smoke test.

TEA reconciliation: of the 41 audit findings, **9 CLOSED, 12 PARTIAL, 20 OPEN** on `dev`. Adversarial-verify spot-checked the two highest-value CLOSED reversals (both P1, TEA-015 and TEA-031) and **upheld both**; no CLOSED was overturned and no section FAIL was refuted.

---

## 2. Section-by-section verdicts

Eight genuine sections were assessed (a ninth data entry, `section:"test"` / summary `"probe"` with evidence `"one"/"two"`, is a non-substantive probe artifact and is **excluded**). No section verdict was overturned by adversarial-verify (verify examined only recon CLOSED items).

| # | Section | Verdict | One-line rationale |
|---|---------|:------:|--------------------|
| 1 | Config & tooling (steps 4/5/11) | **WARN** | Strong CI-aware execution + self-enforcing tag registry, but **zero flake/retry/timeout policy** (step 11 unmet) and TEA-037 `make ci` format-check divergence. |
| 2 | Directory structure / "support" pattern (step 3) | **WARN** | `test/` mirrors `lib/`; four clean support layers heavily reused (helpers imported by 370 files) — but test-TYPE buckets overlap the feature tree with no documented placement rule. |
| 3 | Fixture architecture & data factories (steps 6/7) | **WARN** | TEA-002 P0 collision materially remediated (structural fix + regression test), but the **systemic collision/property-based fixture is unbuilt** and the shared factory layer is fractured/near-dead. |
| 4 | Helper utilities / fakes (step 9) | **PASS** | Every external seam has a functional, error-capable, centralized double; TEA-019 remediated; TEA-020/040 are small residual seam-hygiene notes, not broken fakes. |
| 5 | Test quality & best-practices | **WARN** | Assertion-rich behavioral core (TEA-010/028/036 refuted as defects), but **source-text tautology assertions** (TEA-009) institutionalized across 63 files. |
| 6 | Layered E2E fidelity (differentiator) | **WARN** | All 10 rungs exist, 8 run in CI, Firestore-rules doubly exercised — but top rungs (on-device, integration_test) nascent/not-in-CI, plus doc-path drift in `test-options.md`. |
| 7 | Golden / pixel layer (TEA-008/031) | **WARN** | Harness working & portable, TEA-008/031 refuted on dev — but 18/22 pixel sub-tests `skipGolden`, only 3 live product-surface baselines. |
| 8 | CI integration ("Integration Points") | **WARN** | 9 parallel jobs, fail-closed deploy gate (TEA-018 fixed), emulator rungs hard-fail — but no on-device/integration CI path and **zero flake tooling** (TEA-038/047). |

**Aggregate: 1 PASS, 7 WARN, 0 FAIL, 0 N/A** across assessed sections.

---

## 3. TEA-audit reconciliation (41 findings)

**Count summary on current `dev` (HEAD f8b42240): 9 CLOSED · 12 PARTIAL · 20 OPEN.**
Adversarial-verify checked the two P1 CLOSED items (TEA-015, TEA-031) and **upheld both** (only cosmetic wording nits — see notes). **No CLOSED was overturned.**

### CLOSED (9) — fixed on dev with positive evidence

| ID | Sev | Evidence (current dev) |
|----|:--:|------------------------|
| TEA-015 | P1 | Unsafe casts → `FirestoreCodec.parseInt/parseDouble/parseBool`; regression test `track_and_goal_codec_malformed_numeric_test.dart` **passes** (6/6). **Verify upheld**; nit: 14 (not "16") codec files carry malformed coverage; the crash branch is a `TypeError` (Error, not Exception), so the parser fix — not a `catch` — is the correct remedy. |
| TEA-031 | P1 | `store_screenshots_test.dart` relocated `test/`→`tool/screenshots/` (out of the CI test tree); font path portable via `FLUTTER_ROOT`/`resolvedExecutable`, guarded by `golden_font_loader_test.dart`. **Verify upheld**; nit: `/home/daniel` appears on 2 lines of the guard test (comment + assertion), not 1 — neither is a live path. |
| TEA-018 | P2 | `deploy-play-store.yml` `gate-ci-status` job requires a completed+successful `ci.yml` run for the exact SHA (fail-closed, unit-tested). Deploy cannot ship on red CI. |
| TEA-027 | P2 | `study_day_config_merger.dart:100` now uses convergent `DriftMergeStore.remoteIsNewer`; no production caller of the divergent bare `merge_rules.dart` remains. |
| TEA-041 | P2 | Wave-4 test-quality backlog landed on dev (ledger baseSha is ancestor of HEAD; 1323 AUD-* commits reachable). Coordination hazard moot. |
| TEA-042 | P2 | TQ-8 substring-match backlog (122 merged) delivered on dev. Coordination hazard moot. |
| TEA-017 | P3 | `ci.yml` now has a `functions` job (`make test-functions`, no soft-skip) closing AUD-firebase-04. |
| TEA-044 | P3 | `test/core/ids/natural_key_test.dart` (161 lines) directly asserts each `NaturalKey` factory's exact key string. |
| TEA-045 | P3 | Dead ~200-line `PinFlowMachine` copy removed; live logic extracted to tested `PinEntryMachine` (93.6% LH). |

### PARTIAL (12) — materially improved, systemic remedy incomplete

| ID | Sev | Evidence (current dev) |
|----|:--:|------------------------|
| TEA-002 | **P0** | Collision **structurally fixed** (`scopeUnitIdentifier` qualifies ancestor paths) + dedicated regression test for both classes (cross-masechta daf '2', cross-sefer perek '1') + read-time assertion. **NOT closed:** no property-based framework (grep glados/quickcheck = 0), no shared collision fixture — a new colliding curriculum shape is not auto-swept. |
| TEA-014 | P1 | `merge_router` coverage tripled (0→100% on router provider); missing-merger halt branch tested. Still no test asserting the correct merger **value** bound to each kind; orchestrator end-to-end still ~10.6%. |
| TEA-005 | P2 | Real `.en/.he` RTL badge goldens exist; he-locale e2e checker added. Still ~3% RTL behavioral coverage, no ~30-screen golden sweep, no hardcoded-Latin-under-`he` lint. |
| TEA-008 | P2 | Golden layer no longer 100% inert (default `skipGolden=false`, 8 real baselines). Canonical-screen `goldenTest()` suites (10 calls) **still `skipGolden:true`**. |
| TEA-016 | P2 | Flagship R-IC11 skip fixed & reactivated. Two `skip:true` live-overflow-bug tests remain (disable-instead-of-track anti-pattern); others reframed as defensible device-only. |
| TEA-021 | P2 | Both named coverage holes closed (`sefaria_mongo` parser test, `GoalRepositoryImpl` not-found/delete-sync). Remainder is a planning-ledger artifact off-branch. |
| TEA-023 | P2 | FK-adversarial delete-order escapes now covered (`foreign_keys=ON`). Reachability half partial: `check_orphaned_screens.dart` treats any `@RoutePage` as reachable, so the exact registered-but-never-pushed case still slips. |
| TEA-024 | P2 | Search flood fixed (leaf-segment-only cache) + ancestor-qualified fixtures. **No negative assertion** that an ancestor query excludes descendants — a regression could still pass. |
| TEA-032 | P2 | `firebase_auth_gateway_impl` now in lcov at 100% + mirror test. `google_sign_in_gateway_impl.dart` **still 0/19 = 0%** (impl never exercised, only mocked). |
| TEA-034 | P2 | `upgrade_to_cloud_screen` 28%→51.7%; new domain-service test covers profileId scoping / rollback. Screen still ~48% untested. |
| TEA-046 | P3 | `sync_rework_engine_test.dart` (dead) removed. `v18_to_v19_test.dart` **still a 100%-skipped placeholder** (4 empty bodies). |
| TEA-049 | P3 | firestore-rules hardened to hard-fail (TQ-9); arb-parity de-risked. `audit` + `lint` jobs **still soft-skip**; no centralized required-files manifest. |

### OPEN (20) — unremediated on dev

| ID | Sev | Evidence (current dev) |
|----|:--:|------------------------|
| TEA-004 | P1 | No generic reactivity-contract/derived-provider-registry harness; reactivity tested one bug at a time (8 `*reactiv*` + 5 `*stale*` bespoke files). |
| TEA-006 | P1 | No `integration_test/` on-device coverage of the AutoRoute PIN nav-guard push-result timing; `integration_test/` has 0 PIN references. |
| TEA-009 | P1 | `an2_switcher_pin_guard_test.dart` still overrides the guard provider with a hardcoded bool + hand-copied (and infidelic) logic returning `true;// would call...` — a genuine tautology. |
| TEA-010 | P1 | Override-everything / assert-only-Scaffold pattern persists and grew: files overriding ≥8 providers 34→**80**; 71% of feature files have zero interaction. |
| TEA-011 | P1 | RTL behavioral coverage ~3.2% (16/493 feature files use `TextDirection.rtl`); no both-directions shared harness. |
| TEA-007 | P2 | Two P0 over-credit migration deletions (`from<30`/`from<31`) have **zero** assertion coverage; no `SchemaVerifier`/self-migration equivalence test. |
| TEA-013 | P2 | Single global 60% line floor; no per-directory/risk-tier floors, no every-file-in-lcov guard (zero-coverage files vanish from the denominator). |
| TEA-026 | P2 | "Scoped to profile" DAO tests place profile-2 data on a **different track**, so dropping the `profileId` predicate wouldn't fail them — the cross-profile-leak defense is never exercised. |
| TEA-028 | P2 | `pump(const Duration(seconds:1))` as settle grew to 1080 in `test/features`; no pump-until-condition helper. (Deterministic on virtual clock — smell, not defect.) |
| TEA-029 | P2 | ~97% localized-string finders (`find.text` 3269 vs `find.byKey` 94, which *decreased*); no key-based finder migration. |
| TEA-030 | P2 | Happy-path bias: error-state ~7.7%, loading-state ~12.6% of feature files; no shared loading/data/error triad harness. |
| TEA-036 | P2 | 358 unguarded `pumpAndSettle()`; no bounding/burn-in policy. |
| TEA-037 | P2 | Inner `make ci` omits `format-check`; root `make ci` includes it; `learning_tracker/CLAUDE.md` documents neither accurately. (Backstopped by the `format-check` GHA job + pre-commit hook.) |
| TEA-038 | P2 | Zero flake management: no `--test-randomize-ordering-seed`, no retry/burn-in/quarantine lane anywhere. |
| TEA-019 | P3 | `signup_screen.dart:99` still reads static `InternetConnectionChecker.instance.hasConnection` at the offline-vs-cloud decision, bypassing the injectable provider (used for display only). |
| TEA-020 | P3 | Process-global mutable `currentLocalDayClock`; `DateTimeFactory` 61 files/138 sites vs provider 8/10. Mitigated by `installFakeClock` but the raw seam is public/unguarded. |
| TEA-040 | P3 | `_lastKnownOnline` / `_offlineRecoveryProbeInterval` process-wide caches reset only by `@visibleForTesting` debug hooks; a provider override doesn't reset them. |
| TEA-043 | P3 | 7 DAOs bake `DateTimeFactory.nowUtc()` with no injectable clock; tests assert `isNotNull` not equality against an injected instant. |
| TEA-047 | P3 | No `@Retry`/quarantine test-infra; only production `retry()` and prose about past flakiness. |
| TEA-048 | P3 | 338/922 test files >300 lines (largest 3587); no decomposition. |

---

## 4. Prioritized remediation backlog (still-open, deduped across assessors + recon)

Ranked by risk. TEA-002 is nominally P0 but its *specific* data-corruption bug is now regression-caught; only its **systemic** remedy is outstanding, so it lands at P1. No genuinely-open P0 remains.

### P1 — do first

1. **De-tautologize the acceptance layer (TEA-009 / TEA-010).** Convert the highest-value source-grep "acceptance" tests (esp. `story_acceptance`, `tutoring`) into behavioral tests: pump the widget/provider and assert the observable effect (as `dashboard_screen_test.dart` already does for `ref.invalidate`). Move genuine structural checks out of the suite into `custom_lint`/a named `tool/` meta-check. **Add a ratchet forbidding new `readAsStringSync`-of-`lib` assertions** in `test/story_acceptance` and `test/features`.
2. **Build the systemic collision / property-based fixture (TEA-002 residual).** Add a generator to `test/fixtures/`/`test/helpers/` that, for any `CurriculumId`, emits sibling leaves sharing a level-N id across distinct parents plus a matching `LearningLedger` scope-mark, and asserts `computeLearnedLeafRefs` credits only the targeted parent. Drive it over `CurriculumId.values` so future curricula are auto-swept.
3. **Repair the shared data-factory layer.** Add a `LearningLedger` scope-mark factory + richer `ContentItem` builders to the shared fixtures; migrate the 15 local `_leaf()` / 3 local `_ledger()` reimplementations onto them; guard adoption with a ratchet in the mold of `tool/check_tq3_pump_app_migration.dart`.
4. **Re-enable the golden catalog (TEA-008).** After the Epic 26/27 canonical-screen rebuild stabilizes, baseline the 9 `skipGolden:true` sites (`--update-goldens`) and flip to `false`. Harness + fonts already support it — this is baseline capture, not new infra. Track as a story so the deferral doesn't become permanent.
5. **Close the RTL/Hebrew behavioral gap (TEA-011 / TEA-029).** Add a both-directions shared pump harness (or extend the existing `Locale('he')` pattern) to the hotspot screens so ~79% of feature screens are no longer verified only in `en`; prefer stable `Key`/semantics finders over exact English copy on high-churn widgets.

### P2 — do next

6. **Adopt a flake policy (TEA-038 / TEA-047, config + CI).** Add a `dart_test.yaml` global `timeout:` so a hung test fails fast instead of consuming the job budget; add `--test-randomize-ordering-seed=random` to the test job; register a `quarantine` tag with an `--exclude-tags quarantine` main lane + non-blocking quarantine job; add a PR burn-in job re-running changed `*_test.dart`. Document the policy in `docs/coding-standards.md`.
7. **Wire on-device / integration E2E into CI (TEA-006, E2E + CI).** Add an emulator-driven job (`android-emulator-runner` + `flutter test integration_test/`, or the `device_e2e` harness against the Firebase emulator suite); at minimum wire `make check-device-e2e-suite-size` into CI and expand beyond the single `integration_test/app_test.dart` smoke test.
8. **Add a shared reactivity/invalidation harness (TEA-004).** `expectRebuildsOn(container, provider, trigger)` (or a build-counter override factory); adopt across the 70 ad-hoc counter sites so every reactive provider gets the contract by construction.
9. **Fix the coverage gate (TEA-013).** Add per-directory/risk-tier floors and an every-`lib/*.dart`-in-lcov guard so small high-risk modules (e.g. `lib/app/bootstrap/`, `google_sign_in_gateway_impl` at 0%) can't vanish from the denominator.
10. **Make the profile-scoping and search tests actually adversarial (TEA-026 / TEA-024).** Add a profile-2 completion on the **same** `trackId` so removing the `profileId` predicate fails; add a **negative** search assertion that an ancestor-name query excludes its descendants.
11. **Cover the migration deletions (TEA-007).** Seed `learning_ledger` with bare vs qualified rows at `from<30`/`from<31` and assert the deletion behavior; introduce migration-equivalence (schema-snapshot) testing.
12. **Reconcile `make ci` (TEA-037).** Add `format-check` to `learning_tracker/Makefile:260`; fix the `CLAUDE.md` `make ci` row; state that the GHA job set (not `make ci`) is the CI source of truth.
13. **Document the test-layout rule & consolidate buckets (structure).** One rule in `docs/developer-handbook.md`: feature behavior → `test/features/<module>`; top-level dirs reserved for cross-cutting suites. Fold `test/sync`→`features/sync`, `test/scheduler`→`features/scheduler`, `test/track_setup`→`features/track_setup`, absorb `test/widget`.
14. **Harden clock/connectivity seams (TEA-020 / TEA-040).** Zone-scope the day clock (or add a `make audit` grep forbidding bare `useLocalDayClock()` outside `fake_clock.dart`); fold `_lastKnownOnline` into container state or auto-reset it in a shared connectivity harness.

### P3 — hygiene

15. **Doc-path fixes (E2E).** `test-options.md`: correct layer-2 path to `test/core/sync/codec_rules_contract_test.dart`; rewrite the stale CI summary to list the 9 real jobs (layer 7 functions IS in CI).
16. **Retire dead/placeholder tests (TEA-046 / TEA-048).** Remove or implement `v18_to_v19_test.dart`; decompose the largest oversized test files.
17. **De-soft-skip the audit/lint jobs (TEA-049).** Build a centralized required-files manifest instead of per-job existence guards.
18. **Golden doc/naming drift (golden P3).** Fix `golden_runner.dart` comments to the colocated `goldens/` convention; fix the stale `.gitignore` failures path; resolve the `test/golden` vs `test/goldens` naming split.
19. **Remove empty scaffolding (fixture/helpers P3).** Populate or delete near-empty `test/mocks/*` and the empty `test/fixtures/audit/guarded_persist/`; promote the highest-fanout hand-rolled mocks (`StackRouter`, `ContentRepository`, `AuthRepository`) into `test/mocks/`.
20. **DAO clock injection (TEA-043) & signup static seam (TEA-019).** Inject a `Clock` into the 7 DAOs and assert against a fixed instant; route the `signup_screen.dart:99` offline decision through the overridable provider.

---

## 5. Note on the npm→Flutter translation and genuinely N/A items

This checklist originated for an **npm/Playwright/Cypress** stack and was translated element-by-element to Dart/Flutter. Mappings applied throughout this report:

| Checklist (npm origin) | This stack (Dart/Flutter) |
|------------------------|---------------------------|
| `playwright.config.ts` / `cypress.config` | `dart_test.yaml` + `test/flutter_test_config.dart` |
| `tests/support/` global setup | `test/flutter_test_config.dart` `testExecutable()` |
| `support/` single folder | `test/fixtures/` + `test/helpers/` + `test/mocks/` + `test/e2e/harness/` |
| faker factories | mocktail inline doubles + Drift in-memory seed helpers + Riverpod provider overrides |
| `package.json` scripts | `Makefile` targets (root + authoritative `learning_tracker/Makefile`) |
| API/network/auth helpers (step 9) | `connectivity_gateway`, `firestore_fake`, `no_op_firestore_gateway`, `fake_secure_storage`, `fake_clock` |
| `page.waitForTimeout` (real sleep) | `tester.pump(Duration)` — advances the **virtual** fake-async clock instantly (**not** a real wait) |

**Genuinely N/A / non-translating items** (assessed, not penalized):

- **Playwright-style "hard wait" defects (TEA-028/036 as originally framed).** `tester.pump(Duration(...))` and `pumpAndSettle()` advance Flutter's virtual clock; they are **not** real wall-clock sleeps, so the Playwright `waitForTimeout` anti-pattern does not translate to a flakiness defect. The residual concern is a *readability* smell (magic durations) and an *unbounded-hang* risk on continuous animations — retained at P2/P3, not treated as the Playwright defect.
- **`page.route`/network interception.** Not applicable; the equivalent seam is provider override + injected gateway, which exists and is exercised.
- **Browser-matrix / cross-browser config (`test_on`, projects).** N/A to a single-Flutter-engine target; the analogous axis (locale/direction `en`+`he`, light/dark) IS realized in the golden harness.
- **`custom_lint` analyzer-plugin CLI marker.** Deliberately omitted (crashes `dart analyze --fatal-infos`); layering enforcement runs as `make audit` greps + `packages/custom_lints` unit tests — a documented, intentional no-op at the CLI layer, not a gap.

All other checklist intents **do** translate and were held to their full standard; nothing was excused as N/A merely because the stack differs.

---

*Report compiled by the Master Test Architect from per-section assessor findings, the 41-finding TEA-audit reconciliation, and adversarial-verify verdicts. All counts and file:line citations were sourced from current `dev` (HEAD f8b42240); key structural claims (flake config, CI job set, HEAD) were independently re-verified for this report.*
