# TEA Audit — Test Architecture Review

**Project:** Learning Tracker (Flutter, offline-first Firebase sync, Hebrew/RTL-first, children's data)
**Date:** 2026-07-09 · **Branch audited:** `audit-fix/2026-07-03` (HEAD 4cf217ec)
**Companion artifacts:** [`findings.json`](findings.json) (machine register) · [`coverage-risk-map.md`](coverage-risk-map.md)
**Coordination:** 2026-07-03 standards audit register (748 findings) + delivery wave ledger

---

## 1. Executive summary

**The core problem is not test quantity, it is verification placement.** The suite holds ~10,370 green tests, yet in three months ~931 fix/bug/regress-flavoured commits shipped, the on-device E2E programme confirmed **107 defects across 7 runs** (run 6 alone: 22 defects, **0** caught by the suite; runs 6/7 together: 35), and a vision audit remediated a further 63 bugs. The suite systematically verifies code-shape at the unit/widget level, in English/LTR, against friendly fixtures and fully-stubbed providers — while the defects the product actually ships live on the other side of five seams the suite never crosses:

1. **Device reality (~60% of escapes).** 71 fix commits were explicitly root-caused via on-device/logcat because the harness could not reproduce them: RTL/BiDi/overflow (118 l10n/RTL fixes vs 13/429 feature test files exercising `TextDirection.rtl` — TEA-011, TEA-005), and async nav-guard/lifecycle races on the parent-PIN auth gate (4+ escapes in one controller — TEA-006). The golden layer built precisely for this is inert: **every `goldenTest()` call passes `skipGolden:true`, zero en/he baselines exist** (TEA-008), and the only live pixel suite hardcodes `/home/daniel/...` font paths (TEA-031).
2. **Weak fixtures (~10%, but the worst bugs).** Three separate **P0 data-corruption escapes** in lifetime scope-id keying (e22fb126, bf92cde9, 98d5e64b — a child's headline total inflated ~3.8x, 1542→5852) got through because every fixture used globally-unique IDs; no collision or property-based fixture exists anywhere (TEA-002). The two migrations that repair that corruption have **zero assertion coverage** (TEA-007).
3. **No test for the path (~15%).** 63 provider-staleness escapes share one root cause — a derived provider never watches its mutation tick — and each got its bespoke regression test only *after* the bug; no systemic reactivity contract exists (TEA-004).
4. **Over-stubbing.** Canonical screen tests override 100% of the providers under test and assert `find.byType(Scaffold)`; 312/429 (73%) feature test files have zero user interaction (TEA-010). Error/loading branches are touched by only ~6%/~10% of feature files (TEA-030).
5. **Coverage that measures volume, not risk.** 81.97% headline coverage sits over a denominator that silently omits 123 never-executed files; the sync composition root (`merge_router_provider.dart`) is at **0%** while the mergers it wires are at 94.8% (TEA-013/014/015).

### Final counts

| Severity | Verified findings | Of which CONFIRMED (3-lens survived) | PLAUSIBLE (unverified P3) |
|---|---:|---:|---:|
| P0 | 1 | 1 | 0 |
| P1 | 8 | 8 | 0 |
| P2 | 21 | 21 | 0 |
| P3 | 11 | 4 | 7 |
| **Total** | **41** | **34** | **7** |

8 additional candidate findings were **refuted** under adversarial verification and are reported transparently in Appendix A.

### The 10 most important findings

| # | ID | Sev | Finding |
|---:|---|---|---|
| 1 | TEA-002 | P0 | Three P0 lifetime over-counting escapes; fixtures use globally-unique IDs — no collision/property-based fixtures exist |
| 2 | TEA-004 | P1 | 63 provider-staleness escapes; no "re-executes on its invalidation tick" contract harness |
| 3 | TEA-010 | P1 | Screen tests override 100% of data providers and assert only that a Scaffold exists; 73% of feature tests have zero interaction |
| 4 | TEA-006 | P1 | Parent-PIN auth gate regressed 4+ times on AutoRoute completer/keepAlive timing seams widget tests cannot reach |
| 5 | TEA-009 | P1 | Parent-PIN escalation guard test stubs the guard decision and re-implements its logic inside the test — a tautology on a P0 child-privacy path |
| 6 | TEA-014 | P1 | `core/sync/providers` at 15.8% / merge router at 0% — the entity→merger wiring is the P0 sync-corruption class the suite is blind to |
| 7 | TEA-011 | P1 | RTL/Hebrew behavioural coverage is ~3% of feature tests despite Hebrew being the primary locale with a confirmed RTL bug history |
| 8 | TEA-015 | P1 | 88% line coverage on merge codecs still misses the malformed-input branch AUD-core-sync-05 confirms crashes — line % overstates risk coverage |
| 9 | TEA-031 | P1 | The only live golden suite hardcodes a `/home/daniel` font path — pixel results are a property of one machine's filesystem |
| 10 | TEA-007 | P2 | The v30/v31 P0 over-credit repair migrations have zero assertion coverage; no drift schema snapshots, no `verifySelfMigration` |

### What to do first

- **Collision fixtures + read-time migration assertions** on the lifetime ledger (TEA-002, TEA-007) — this is the signature recurring P0 bug class.
- **One reactivity contract test** enumerating derived providers (TEA-004) — converts 63 one-offs into one enforced invariant.
- **Baseline and enable the en/he goldens** (TEA-008, TEA-031, TEA-005) and add he/RTL as a standard harness variant (TEA-011).
- **Table-driven merge-router binding test** (TEA-014) and malformed-payload codec fixtures (TEA-015).
- **Risk-tiered coverage floors + every-file-in-lcov check** (TEA-013).
- Coordinate everything else through the standards-register wave ledger (TEA-021/041/042): 86% of registered test-quality findings sit in un-started wave 4; the 19 parked items are the only non-overlapping fix targets.

---

## 2. Escaped-defect taxonomy

Baseline: ~930 fix/bug/regress commits since 2026-04-01; 107 on-device defects confirmed across runs 1-7; 63 vision-audit bugs; 71 commits explicitly root-caused via on-device/logcat.

### 2.1 Escape classes

| Class | Share | Description and evidence |
|---|---|---|
| (e) Only-on-device | ~60% (dominant) | 118 l10n/RTL/BiDi/overflow fixes + PIN/nav lifecycle races + sync identity/connectivity races; 71 commits explicitly on-device root-caused ("static analysis could not pin it down", b8464ccc) |
| (a) No test for path | ~15% | 63 provider-staleness fixes; dead routes (81bad6f9); FK-order crashes (b659b430, 8e2bdf6f, f3b837ed, f0901b77) |
| (b) Mocked-away seam | ~10% | fake_cloud_firestore is rules-blind (8a765dc6); search fixture used leaf names vs production ancestor-qualified shape (run6 #5 / 34616dfd) |
| (c) Weak fixtures/assertions | ~10% | 3 P0 scope-id collision/over-count escapes used globally-unique fixture IDs (e22fb126, bf92cde9, 98d5e64b) |
| (d) Wrong level | ~5% | firestore-rules emulator suite outside `make ci` (now gated in a separate GH Actions job); per-provider reactivity never integration-tested |
| (f) Skipped/disabled | ~0% in unit tests | 0 `skip:true` in unit tests; the skip problem lives in E2E journeys (TEA-016) and in expensive real-seam suites (goldens, emulator) barely existing |

### 2.2 Escapes per module

| Module | Fix commits | | Module | Fix commits |
|---|---:|---|---|---:|
| sync | 47 | | scheduler | 15 |
| tracks | 21 | | auth | 15 |
| progress | 21 | | account | 14 |
| profiles | 16 | | learning | 13 |
| labels | 16 | | gamification | 12 |
| dashboard | 16 | | settings | 11 |

### 2.3 Test-infrastructure gaps behind the taxonomy

| Gap | Value |
|---|---|
| Committed en/he golden baseline files | 0 |
| `matchesGoldenFile` call sites | 2 (one machine-locked, one behind `skipGolden:true`) |
| Test files pumping `Locale('he')` | 101 |
| Hebrew-script `find.text` assertions | 188 (vs 2,010 English) |
| Files using fake_cloud_firestore | 7 |
| Files using real in-memory sqlite | 111 |
| CI runs Firebase emulator in `make ci` | No (separate GH Actions job only) |

### 2.4 Top 10 escape case studies

| SHA | Bug | Class | Missing test |
|---|---|---|---|
| bf92cde9 | P0: Chumash perek scope-id collision cross-credited +170 pesukim across all 5 sefarim | (c) | collision fixture with shared bare level2 ids (Bereishis/Shemos perek 1) |
| e22fb126 | P0: bare level3/4 daf id credited daf 2 into every masechta | (c) | Berakhos-vs-Shabbos daf-2 collision fixture |
| 98d5e64b | P0: Tanach over-count passed CI, failed on-device — migration ran but ledger row honoured at read time (5852 vs 1542) | (e)+(c) | read-time aggregation assertion after migration on real per-account DB |
| 8a765dc6 | goal_codec/learning_order_codec emitted rule-illegal keys; PERMISSION_DENIED swallowed | (b)+(d) | codec↔firestore.rules contract + emulator rules gate (since added) |
| b8464ccc | P0: parent-PIN first-time setup loops forever (push-result completer never completed) | (e) | integration test of AutoRoute guard push-and-await |
| a0c85409 | Set-Parent-PIN freezes at 4 dots (keepAlive default mode=verify race) | (e) | synchronous digit-gesture-before-microtask race test |
| d5b53992 | progress providers stale after completion — never watched completion tick | (a) | provider re-executes-on-invalidation-tick contract |
| 3b600217 | notification times reset to defaults every launch (cold-start sentinel profileId=0 via ref.read) | (e)+(a) | cold-start 0→real-id transition rebuild test |
| 34616dfd | content search 'b' returned 1,325 wrong rows (matched ancestor-qualified displayNameEn) | (b) | search test seeded from real content.db data shape |
| 15672dc7 | revoked tutored child's mirror left on disk (wrong id key) | (b)+(e) | multi-role fixture where profile id ≠ account id (note: TEA-025's framing of this was refuted — see Appendix A) |

**Through-line:** the suite proves code-shape at unit/widget level in the default English locale against friendly fixtures; real defects live in device lifecycle, the real Firestore-rules boundary, the real seeded DB's data shapes, Hebrew visual layout, and cross-provider reactivity — levels the current suite does not touch.

---
## 3. Dimension chapters

Ten recon dimensions ran in parallel. Each chapter gives the dimension digest and its confirmed findings.

### 3.1 Escaped bugs (what shipped despite green)

The green 10,370-test suite misses real bugs because its verification seams sit on the wrong side of the defects the product ships. Three months produced ~930 fix/bug/regress commits while the suite stayed green; the on-device E2E programme alone confirmed 107 defects across 7 runs (run 6: 22 defects, 0 caught by the suite) plus a 63-bug vision-audit remediation. Dominated by "only manifests on-device" (71 commits explicitly root-caused via logcat), then mocked-away seams, weak fixtures (three P0 corruption escapes), and no-test-for-path (63 provider-staleness escapes). Full taxonomy in chapter 2.

| ID | Sev | Finding |
|---|---|---|
| TEA-002 | P0 | Three P0 over-counting escapes; fixtures used globally-unique IDs — no collision/property-based fixtures (`content_grouping.dart`; e22fb126, bf92cde9, 98d5e64b) |
| TEA-004 | P1 | 63 provider-staleness escapes; no systemic "re-executes on tick" harness (`items_learned_providers.dart`; d5b53992 et al.) |
| TEA-006 | P1 | Parent-PIN nav-guard/lifecycle regressions widget tests structurally cannot reproduce (b8464ccc, a0c85409, 24acaf78, 56a6ff50) |
| TEA-005 | P2 | Hebrew/RTL surface has ~101 string-presence tests but no active golden pixel comparison — visual defects only catchable on-device (118 l10n/RTL fixes) |
| TEA-023 | P2 | Navigation reachability untested: dead route shipped (81bad6f9); FK-order crashes on the real DB (b659b430, 8e2bdf6f, f3b837ed, f0901b77) |
| TEA-024 | P2 | Content-search flood: fixture stored leaf names, production stores ancestor-qualified displayNameEn — 1,325 wrong rows (34616dfd) |

Refuted in this dimension: TEA-001 (rules-blind fake — already remediated and gated by 8a765dc6/76fb1d5f), TEA-022 (device-race fixes actually shipped with regression tests), TEA-025 (tutored-mirror id premise false). See Appendix A.

### 3.2 Unit quality — core (DAO / sync / merge / migration)

Architecturally healthier than the bug history suggests: zero mockito `verify()`/`when()` stub-echo tests across all 116 target files; DAO/sync/merge tests run a real in-memory Drift DB at the current schemaVersion with `PRAGMA foreign_keys=ON` (user_database.dart:182). LWW symmetry, merge roundtrip, and tutored_pull_isolation tests genuinely drive codec→merger→DriftMergeStore→DB paths with fixed UTC timestamps. The weaknesses are narrow and sharp: the migration suite (no drift schema snapshots, no `verifySelfMigration`, the two P0 over-credit repair migrations never asserted); tautological profile-scoping negative tests; divergent `remoteIsNewer` tie-break semantics; seven DAOs with wall-clock `now()` baked in.

Key stats: 69 core/database test files (47 DAO), 32 sync, 15 sync/merge, 11 migration; 0/11 migration files use drift schema snapshots; 2 P0 migration steps with zero assertion coverage; 7 DAOs with non-injectable clock.

| ID | Sev | Finding |
|---|---|---|
| TEA-007 | P2 | v30/v31 P0 over-credit migrations have ZERO assertion coverage; hand-built approximate schemas; no `verifySelfMigration` (user_database.dart:284-338) |
| TEA-026 | P2 | completion_dao "is scoped to the given profile" tests place profile-2 data on a different track — the profileId predicate is never exercised (completion_dao_extra_test.dart:138,205) |
| TEA-027 | P2 | Two divergent `remoteIsNewer` implementations with opposite tie-break semantics; study_day_config_merger alone uses the non-convergent one, tie path untested (merge_rules.dart:66-73) |
| TEA-043 | P3 (plausible) | Seven DAOs bake wall-clock `now()` into production code, forcing isNotNull-only timestamp assertions |

### 3.3 Unit quality — features (widget/screen suite)

Broad but shallow: optimised for green, not signal — the direct mechanism behind 931 fix-commits landing while 10k tests stayed green. Dominant anti-pattern: screen tests override 100% of providers and assert only that a Scaffold exists. 953 arbitrary `pump(const Duration(seconds:1))` settle-substitutes; finders 97% English strings; RTL behavioural coverage ~3%; golden layer inert; error/loading branches at ~6%/~10%. Good templates exist (tutor_pin_entry_gate_l1_test.dart covers loading/error/wrong-PIN/lockout/raw-leak+RTL; active_tracks_carousel_rtl_test.dart asserts real chevron mirroring) but are exceptions.

Key stats: 429 feature test files; 312 (73%) zero-interaction; 34+ files override ≥8 providers; 2,972 `find.text` vs 98 `find.byKey`; 13 files (3%) use `TextDirection.rtl`; 90 (21%) pass `Locale('he')`; 27 (6%) exercise an error state, 42 (10%) a loading state; 3 `goldenTest()` callers, all `skipGolden:true`, 0 en/he baselines.

| ID | Sev | Finding |
|---|---|---|
| TEA-009 | P1 | Parent-PIN escalation guard test stubs the decision and re-implements the logic inside the test — tautology on a P0 child-privacy path (an2_switcher_pin_guard_test.dart:72) |
| TEA-010 | P1 | Screen tests override 100% of data providers, assert `find.byType(Scaffold)` only (dashboard_screen_test.dart:66) |
| TEA-011 | P1 | RTL/Hebrew behavioural coverage ~3% of feature tests despite Hebrew-primary audience and confirmed RTL bug history |
| TEA-031 | P1 | Only live golden suite hardcodes /home/daniel font path — goldens are machine-dependent (store_screenshots_test.dart:25) |
| TEA-008 | P2 | 100% of `goldenTest()` calls pass `skipGolden:true` — the RTL/EN golden layer asserts nothing (golden_runner.dart:36) |
| TEA-028 | P2 | 953 `pump(const Duration(seconds:1))` settle-substitutes mask async races |
| TEA-029 | P2 | Finders 97% localised-English-string based — brittle to copy edits, structurally en-locked |
| TEA-030 | P2 | Error/loading states exercised in only ~6%/~10% of feature files — happy-path bias on an offline-first app |

### 3.4 Acceptance journeys

The recon digest for this dimension was not delivered (placeholder output). Its only candidate finding (TEA-012) was an empty stub and is refuted in Appendix A. Journey-level observations that did survive arrived via other dimensions: E2E journey skips citing live product bugs (TEA-016, filed under flakiness-determinism) and the E2E-vs-suite reality gap quantified in chapter 2. **A re-run of this dimension is recommended before planning acceptance-journey work.**

### 3.5 Coverage-vs-risk map

Headline 81.97% line coverage is structurally misleading: computed over 697 instrumented files while 820 exist — 123 files (15%) executed by no test and invisible to the denominator, including all of `lib/app/bootstrap/` and `lib/app/sync_runtime/`. A single global 60% floor cannot protect small critical modules (core/auth + core/sync/providers dropping to zero moves the global figure 0.2pp). The risk pattern is bimodal: merge algorithms 94.8% / DAOs 88-100% vs composition root 15.8% and merge router 0%. Full table in [`coverage-risk-map.md`](coverage-risk-map.md).

| ID | Sev | Finding |
|---|---|---|
| TEA-014 | P1 | core/sync/providers 15.8%; merge_router_provider 0/26 — entity→merger wiring unguarded against mis-binding |
| TEA-015 | P1 | 88% codec line coverage misses the malformed-input branch AUD-core-sync-05 confirms crashes |
| TEA-013 | P2 | Flat 60% floor + 123 files absent from lcov = a gate measuring volume, not risk |
| TEA-032 | P2 | core/auth lowest real-logic module (68.7%); Google sign-in gateway 0% |
| TEA-034 | P2 | Offline→cloud conversion screen (data-migration path) 28.2% covered, largest under-covered hand-written file (433 LF) |
| TEA-044 | P3 (plausible) | core/ids natural-key factories at 10%, no test/core/ids |
| TEA-045 | P3 (plausible) | 0% PIN/tutor-audit/scheduler domain files are dead duplicates — live paths lack a canonical tested domain layer |

Refuted in this dimension: TEA-033 (mischaracterised a keep-alive wrapper as the sync-lifecycle decision point; the real observer is tested). See Appendix A.

### 3.6 E2E reality

The recon digest for this dimension was not delivered (placeholder output); its only candidate finding (TEA-003) was an empty stub, refuted in Appendix A. The escaped-bugs dimension supplies the E2E reality picture indirectly (107 on-device defects vs 0 suite catches in run 6). **A re-run of this dimension is recommended.**

### 3.7 Flakiness and determinism

Mechanical scan of 780 test files (~305,731 lines). Classic async races are rare (8 `Future.delayed`, 0 `sleep()`); `DateTime.now()` and `Random()` are well-contained in lib/ (5 and 2 raw call sites, sanctioned abstractions) — genuine strengths. Risk concentrates in: 2,453 magic-number `pump(Duration(...))` calls; 350 `pumpAndSettle(` calls (332 bare, zero bounded-timeout); 41% of files >300 lines (max 3,588); 100 real skips, several citing unfixed product bugs; no retry/quarantine infrastructure. The 21 apparently zero-assertion files are mostly helper-masked false positives, except 2 dead placeholder files. `setUpAll` usage (229x) sampled low-risk.

| ID | Sev | Finding |
|---|---|---|
| TEA-016 | P2 | Skips citing live, unfixed product bugs (R-IC11, BUG-NEW) silently disabled rather than tracked as expected-failures (infra_p1_test.dart:864) |
| TEA-036 | P2 | 332 bare `pumpAndSettle()` calls, zero bounded-timeout overrides — hang class unguarded |
| TEA-046 | P3 (plausible) | Two dead, 100%-skipped placeholder test files inflating the headline count |
| TEA-047 | P3 (plausible) | No retry/quarantine lane for acknowledged flaky tests |
| TEA-048 | P3 (plausible) | 41% of test files exceed 300 lines; several exceed 1,600-3,600 |

Refuted: TEA-035 (magic-pump flake claim — `tester.pump(Duration)` advances a deterministic fake clock; count inflated by `Duration.zero` flushes). See Appendix A.

### 3.8 CI gates

Good bones — 7 jobs, hard fail-fast analyze/audit/test, a real codegen-freshness gate — with three live bypass risks: `make ci` does not match its own documentation (no format step, hook not installed); no burn-in/order-randomisation/flake-quarantine anywhere despite ≥10 catalogued TQ-6 wall-clock flake risks; and the deploy workflow ships to Google Play production with zero dependency on a green CI run (tag pushes never trigger ci.yml at all). Re-verified live: AUD-firebase-04 (Cloud Functions have zero CI gate) still true at HEAD, with the verified fix stranded unmerged in an unlocked worktree; AUD-guardrails-14 (deploy gate) parked. The 9 custom_lint rules never enforce (documented no-op); 2 of the 25 audit greps are warn-only.

| ID | Sev | Finding |
|---|---|---|
| TEA-018 | P2 | deploy-play-store.yml ships to production with no CI dependency — registered as AUD-guardrails-14 but parked; recommend re-promotion to P1 |
| TEA-037 | P2 | `make ci` omits format-check, contradicting CLAUDE.md's documented workflow (Makefile:214) |
| TEA-038 | P2 | No burn-in / test-order randomisation / flake quarantine; catalogued flake risks can never turn CI red |
| TEA-017 | P3 | Verified AUD-firebase-04 fix (c13e6623) unmerged in unlocked worktree wf_911a9826-c9a-3; ledger still `todo` — harvest before cleanup |
| TEA-049 | P3 (plausible) | Skip-if-absent soft-gate pattern copy-pasted into 3 ci.yml jobs with no single point of control |

### 3.9 Testability seams

Bimodal. The Firebase surface is well-sealed: gateway interfaces with constructor injection, only 3+3 `Firestore/Auth.instance` callsites all inside gateway impls, enforced by lint Rule 3 — Firebase coupling is *not* where escapes come from. The untestable surfaces are TIME and NETWORK-GATING: a global-mutable clock (`currentLocalDayClock` read by `DateTimeFactory` across 63 files/139 callsites, vs 7 files on the clean Riverpod provider); connectivity fragmented across three mechanisms; the onboarding offline-vs-cloud submit fallback reading an unmockable static (`InternetConnectionChecker.instance`); and process-wide mutable caches scrubbed only by 17 debug reset hooks.

| ID | Sev | Finding |
|---|---|---|
| TEA-019 | P3 | Onboarding online-form submit reads `InternetConnectionChecker.instance.hasConnection` (signup_screen.dart:97) — the race-fallback branch is untestable (primary offline path is testable; severity corrected P1→P3 in verification) |
| TEA-020 | P3 | Global-mutable clock is the dominant time seam (63 vs 7 files) — order-dependent test state; duplicate-adjacent to AUD-core-time-01 (P3), aligned |
| TEA-040 | P3 | `_lastKnownOnline` process-wide cache not reset by provider overrides; 17 debug reset/set hooks scrub globals between tests |

Refuted: TEA-039 (ConnectivityGateway is not consumed by the sync orchestrator; consumers already mock at the provider seam). See Appendix A.

### 3.10 Standards-register ingest (coordination)

Coordination-only dimension: joining the 748-finding standards register against the delivery ledger to prevent double-fixing. 257 test/quality-guardrail findings all have ledger rows: wave0=1 (merged), waves1-3=15, **wave4=222 (86%, not started)**, parked=19. TQ-8 (tautological/weaker-than-claimed tests) dominates at 122-125 findings — the register-level confirmation of the "931 fix commits, suite stayed green" mechanism. Severity skews P2/P3 (1 P0, 13 P1). Implication: the TEA plan must not propose per-file tautological-test fixes wave 4 will already make; its marginal value is the systemic patterns per-file findings cannot see, plus the 19 parked items nothing else will fix.

| ID | Sev | Finding |
|---|---|---|
| TEA-021 | P2 | 19 test-quality/guardrail findings are parked with no wave — the only non-overlapping TEA fix targets (incl. AUD-guardrails-04, AUD-scheduler-04 real coverage holes) |
| TEA-041 | P2 | 86% (222/257) of test-quality findings stacked in un-started wave 4 — TEA fixes touching those files collide with queued work; carry `aud_overlap` instead |
| TEA-042 | P2 | TQ-8 is the dominant register theme (~122-125 findings) — the direct mechanism behind "931 fix commits, suite stayed green" |

---
## 4. Full findings register

Machine-readable copy with full evidence, impacts, proposed fixes and verifier notes: [`findings.json`](findings.json).

| ID | Sev | Verdict | Title | File | Effort | aud_overlap |
|---|---|---|---|---|---|---|
| TEA-002 | P0 | CONFIRMED | Progress/lifetime over-counting (three P0 escapes) — no collision or property-based fixtures exist | learning_tracker/lib/core/content/content_grouping.dart:1 | M | — |
| TEA-004 | P1 | CONFIRMED | 63 provider-staleness escapes — no systemic reactivity-tick harness | learning_tracker/lib/features/progress/presentation/providers/items_learned_providers.dart:1 | M | — |
| TEA-006 | P1 | CONFIRMED | Parent-PIN async nav-guard/lifecycle regressions unreachable from widget tests | learning_tracker/lib/features/profiles/presentation/providers/pin_flow_controller.dart:1 | M | — |
| TEA-009 | P1 | CONFIRMED | Parent-PIN escalation guard test is a tautology (stubbed decision + re-implemented logic) | test/features/profiles/presentation/an2_switcher_pin_guard_test.dart:72 | M | TQ-8 |
| TEA-010 | P1 | CONFIRMED | Screen tests override 100% of data providers, assert tree assembly only | test/features/dashboard/presentation/screens/dashboard_screen_test.dart:66 | L | TQ-8 |
| TEA-011 | P1 | CONFIRMED | RTL/Hebrew behavioural coverage ~3% of feature tests | test/features/dashboard/presentation/widgets/active_tracks_carousel_rtl_test.dart:1 | L | AX-1 |
| TEA-014 | P1 | CONFIRMED | core/sync/providers 15.8% — merge-router composition root nearly untested | lib/core/sync/providers/merge_router_provider.dart:1 | M | AUD-core-sync-05 |
| TEA-015 | P1 | CONFIRMED | 88% codec line coverage misses the confirmed-crashing malformed-input branch | lib/core/sync/codec/goal_codec.dart:1 | M | AUD-core-sync-05 |
| TEA-031 | P1 | CONFIRMED | Only live golden suite hardcodes a /home/daniel font path | test/golden/store_screenshots_test.dart:25 | S | AUD-t-cross-03 |
| TEA-005 | P2 | CONFIRMED | Hebrew/RTL surface: string-presence tests only, no active golden pixel comparison | learning_tracker/lib/l10n/app_he.arb:1 | L | AUD-t-cross-51 |
| TEA-007 | P2 | CONFIRMED | v30/v31 P0 over-credit migrations zero assertion coverage; no schema snapshots / verifySelfMigration | lib/core/database/user/user_database.dart:284 | L | AUD-t-cross-25 (partial) |
| TEA-008 | P2 | CONFIRMED | 100% of goldenTest() calls pass skipGolden:true — golden layer asserts nothing | test/helpers/golden_runner.dart:36 | M | AUD-t-cross-51 |
| TEA-013 | P2 | CONFIRMED | Flat 60% floor cannot protect small high-risk modules; 123 lib files absent from lcov | learning_tracker/coverage/lcov.info:1 | M | AUD-app-05 |
| TEA-016 | P2 | CONFIRMED | Skips citing live product bugs silently disabled, not tracked as expected-failures | learning_tracker/test/e2e/journeys/infra_p1_test.dart:864 | M | AUD-settings-01 |
| TEA-018 | P2 | CONFIRMED | deploy-play-store.yml has zero dependency on a green CI run — parked, not scheduled | .github/workflows/deploy-play-store.yml:28 | M | AUD-guardrails-14 |
| TEA-021 | P2 | CONFIRMED | 19 parked test-quality/guardrail findings — the safe non-overlapping TEA target set | delivery/ledger.json | — | AUD-guardrails-04 |
| TEA-023 | P2 | CONFIRMED | Navigation reachability untested; FK-order paths crashed on the real DB | learning_tracker/lib/features/scheduler/presentation/screens/track_detail_screen.dart:1 | M | — |
| TEA-024 | P2 | CONFIRMED | Content-search flood hidden by leaf-name fixtures vs ancestor-qualified production shape | learning_tracker/lib/features/content/data/repositories/content_repository_impl.dart:145 | S | AUD-t-content_browsing-04 (adjacent) |
| TEA-026 | P2 | CONFIRMED | completion_dao profile-scoping negative tests never exercise the profileId predicate | test/core/database/daos/completion_dao_extra_test.dart:138 | S | — |
| TEA-027 | P2 | CONFIRMED | Divergent remoteIsNewer tie-break semantics; study_day_config tie path untested | lib/core/sync/merge/merge_rules.dart:66 | M | AUD-docs-08, AUD-core-sync-03 (adjacent) |
| TEA-028 | P2 | CONFIRMED | 953 pump(1s) settle-substitutes masking async races | test/features/tutoring/tutor_pin_entry_gate_l1_test.dart:225 | L | — |
| TEA-029 | P2 | CONFIRMED | Finders 97% localised-English-string based | test/features/learning/presentation/screens/learning_screen_test.dart:61 | L | — |
| TEA-030 | P2 | CONFIRMED | Error/loading states exercised in ~6%/~10% of feature files | test/features/dashboard/presentation/screens/dashboard_screen_test.dart:68 | M | EH-5 |
| TEA-032 | P2 | CONFIRMED | core/auth lowest real-logic module; Google sign-in gateway 0% | lib/core/auth/google_sign_in_gateway_impl.dart:31 | S | — |
| TEA-034 | P2 | CONFIRMED | Offline→cloud conversion screen 28.2% covered — largest under-covered hand-written file | lib/features/settings/presentation/screens/upgrade_to_cloud_screen.dart:1 | M | — |
| TEA-036 | P2 | CONFIRMED | 332 bare pumpAndSettle() calls, zero bounded-timeout overrides | learning_tracker/test/features/profiles/presentation/screens/manage_learners_screen_l1_test.dart | M | — |
| TEA-037 | P2 | CONFIRMED | `make ci` omits format-check, contradicting CLAUDE.md | learning_tracker/Makefile:214 | S | — |
| TEA-038 | P2 | CONFIRMED | No burn-in / order randomisation / flake quarantine despite catalogued flake surface | .github/workflows/ci.yml:227 | M | — |
| TEA-041 | P2 | CONFIRMED | 86% of test-quality findings stacked in un-started wave 4 — collision risk for TEA fixes | delivery/ledger.json | — | wave-4 set |
| TEA-042 | P2 | CONFIRMED | TQ-8 dominant register theme (~122-125) — the mechanism behind "green suite, 931 fixes" | findings.json (standards) | — | TQ-8 |
| TEA-017 | P3 | CONFIRMED | Verified AUD-firebase-04 fix stranded in unlocked worktree; ledger still todo | .github/workflows/ci.yml | S | AUD-firebase-04 |
| TEA-019 | P3 | CONFIRMED | Onboarding submit race-fallback reads unmockable connectivity static | learning_tracker/lib/features/account/onboarding/presentation/screens/signup_screen.dart:97 | S | AUD-t-account-01 (link) |
| TEA-020 | P3 | CONFIRMED | Global-mutable clock is the dominant time seam (63 vs 7 files) | learning_tracker/lib/core/time/local_day_clock.dart:73 | M | AUD-core-time-01 |
| TEA-040 | P3 | CONFIRMED | Process-wide mutable caches guarded only by debug reset hooks | learning_tracker/lib/features/account/presentation/providers/connectivity_providers.dart:36 | S | — |
| TEA-043 | P3 | PLAUSIBLE | Seven DAOs with non-injectable wall-clock now() → isNotNull-only timestamp assertions | lib/core/database/daos/track_dao.dart:1 | M | AUD-t-cross-83 |
| TEA-044 | P3 | PLAUSIBLE | core/ids natural-key factories at 10%, no test/core/ids | lib/core/ids/natural_key.dart:1 | S | — |
| TEA-045 | P3 | PLAUSIBLE | 0% PIN/tutor-audit/scheduler files are dead duplicates; live paths lack tested domain layer | lib/features/profiles/domain/services/pin_flow_machine.dart:138 | M | AUD-profiles-06/07, AUD-tutoring-06, AUD-scheduler-06 |
| TEA-046 | P3 | PLAUSIBLE | Two dead, 100%-skipped placeholder test files | learning_tracker/test/sync/sync_rework_engine_test.dart | S | — |
| TEA-047 | P3 | PLAUSIBLE | No retry/quarantine infrastructure for flaky tests | learning_tracker/test/core/analytics/streak_milestone_analytics_observer_test.dart:128 | M | — |
| TEA-048 | P3 | PLAUSIBLE | 41% of test files >300 lines; several 1,600-3,600 | learning_tracker/test/story_acceptance/epic_15_multi_profile_test.dart | L | — |
| TEA-049 | P3 | PLAUSIBLE | Skip-if-absent soft-gate copy-pasted across 3 ci.yml jobs | .github/workflows/ci.yml | S | TQ-9 |

---

## Appendix A. Refuted findings

Eight candidates did not survive adversarial verification. They are reported here for transparency; do not action them as written.

| ID | Claimed sev | Claim | Why refuted |
|---|---|---|---|
| TEA-001 | (P0→) P2 | Sync-write correctness verified against a rules-blind fake; Firestore rules/permission drift sails through green | **Stale + duplicate.** The finding's own cited commits are the remediation: 8a765dc6 added the codec↔rules contract oracle (runs in the default gate — `dart_test.yaml` has no exclude_tags) and fixed both latent drifts; 76fb1d5f wired the 70-test live-rules emulator suite into a dedicated GH Actions `firestore-rules` job that runs on every PR/push. Residual non-codec write paths are P2 at most and already owned by AUD-firebase-04/05/13, AUD-core-sync-01. |
| TEA-003 | — | (empty stub, dimension e2e-reality) | Placeholder with no content: title "t", file "f:1", evidence "e". Nothing to verify. |
| TEA-012 | — | (empty stub, dimension acceptance-journeys) | Placeholder with no content; all fields the literal token "test". |
| TEA-022 | P2 | Device-race fixes ship with zero regression test | **False premise.** The flagship (c8433457 SYNC-DRAIN-DELAY-01) was pinned by 66a3e0b0's dedicated regression group in sync_orchestrator_drain_triggers_test.dart; injectable seams (resolveIdentityStatus) exist precisely to simulate the trigger; every other cited commit shipped with substantial tests (+84/+91/+104/+249/+255 lines). |
| TEA-025 | P3 | Tutored-mirror wipe used the wrong id key — child-privacy escape | **Premise false.** `currentAccountIdProvider` always resolves accounts.id (from authState), never a learner_profiles.id; the "reproducing" test hand-feeds a wrong argument no production path makes. Residue (orphaned test, dead fix symbols) already owned by the standards register, whose own adversarial note refutes the same premise. |
| TEA-033 | P3 | Live sync-lifecycle observer (decides WHEN sync fires) has zero coverage | **Mischaracterised.** lib/app/sync_runtime/sync_lifecycle_observer.dart is a 30-line keep-alive wrapper (`ref.watch(syncOrchestratorProvider); return child;`). The real timing logic lives in lib/core/sync/lifecycle_observer.dart, which is in lcov and directly tested (lifecycle_observer_test.dart, orchestrator connectivity/drain tests). |
| TEA-035 | P3 | 2,453 magic-number pump(Duration) calls are a flake source | **Wrong mechanism.** `tester.pump(Duration)` in testWidgets advances the deterministic FakeAsync clock — it cannot flake on wall-clock load. 549 of the count are `pump(Duration.zero)` (canonical frame flush); a pump-until helper (pumpUntilSettled) already exists and is used. The genuine kernel (fixed duration shorter than a debounce = deterministic soft-test) is TQ-8 territory already covered by the register's TQ-6/TQ-8 clusters. |
| TEA-039 | P3 | Three competing connectivity mechanisms; ConnectivityGateway unmockable | **Materiality false.** The sync orchestrator does not consume ConnectivityGateway (its gate uses the overridable internetConnectionCheckerProvider); the gateway's only production consumer is a settings util, and consumers already mock it at the Riverpod provider seam. Residue duplicates AUD-t-cross-41. |

---

## 5. Method

**Scope.** Test architecture of `/home/daniel/repos/learning-tracker` (Flutter app in `learning_tracker/`), audited on branch `audit-fix/2026-07-03`, HEAD 4cf217ec, on 2026-07-09.

**Recon: 10 parallel dimensions.** Independent Claude (Fable 5) recon agents each scanned one dimension with a defined evidence protocol (grep/lcov/git-forensics/file reads):

1. **escaped-bugs** — git forensics over ~930 fix/bug/regress commits + on-device audit reports; escape-class taxonomy
2. **unit-quality-core** — DAO/sync/merge/migration test deep reads (116 files, 12 deep)
3. **unit-quality-features** — widget/screen suite (429 files, 22 deep reads)
4. **acceptance-journeys** — *not delivered (placeholder output); re-run recommended*
5. **coverage-risk-map** — lcov aggregation vs app risk model
6. **e2e-reality** — *not delivered (placeholder output); re-run recommended*
7. **flakiness-determinism** — mechanical scan of 780 test files (~305k lines)
8. **ci-gates** — gate inventory across ci.yml / Makefiles / hooks / deploy workflows
9. **testability-seams** — production-code seam analysis (clock, network, Firebase)
10. **standards-ingest** — coordination join of the 748-finding standards register against the delivery ledger

**Adversarial verification: 3 lenses.** Every candidate finding was attacked by independent verifier agents, one per lens:

- **Correctness** — re-derive every factual claim from the working tree / git (file:line reads, grep count reproduction, commit-hash resolution).
- **Materiality** — attempt to downgrade against this app's threat model (children's-data privacy, offline-first sync integrity, parent-PIN auth); a finding is refuted only if severity is inflated ≥2 levels or the impact is not real for this app.
- **Duplication/staleness** — check the finding is not already registered in the 2026-07-03 standards register (748 findings), not already fixed by wave-0 commits (git log --since=2026-07-01), and not remediated pre-audit.

**Vote budget.** P0/P1 candidates (and contested P2s) received all 3 verifier votes; remaining P2/P3 candidates received 1 targeted combined-lens vote. Verdicts: **CONFIRMED** = survived its full vote allocation (`votes_real`/`votes_cast` recorded per finding); **PLAUSIBLE** = unverified P3s carried forward without a vote (budget triage) — treat as leads, not proven defects; **REFUTED** = failed any lens decisively (Appendix A, with full verifier notes preserved in `findings.json` for confirmed items). Where verifiers corrected severity (e.g. TEA-019 P1→P3, TEA-017 P1→P3, TEA-005/TEA-008 P1→P2), the register carries the corrected value.

**Coordination with the standards delivery engine.** Every finding overlapping the 2026-07-03 register carries an `aud_overlap` tag. Per TEA-021/041/042: 86% of the register's 257 test-quality items sit in un-started wave 4, so this audit deliberately reports systemic patterns (fixture design, harness variants, contract tests, gate design) rather than re-listing per-file tautological tests wave 4 will fix; the 19 parked items (TEA-021) are the only register territory where new TEA fix work is non-overlapping. TEA-017 flags a delivery-process risk in the fix engine itself (verified fix stranded in an unlocked worktree).

**Known limitations.** Two of ten dimensions (acceptance-journeys, e2e-reality) returned placeholder digests and contributed no verified findings; lcov artefact is dated 2026-07-03 (local, untracked) — coverage numbers were spot-verified but not regenerated; PLAUSIBLE findings carried zero verification votes.
