## 3. Meta-recommendations — build the checkers

Rule 0 says a standard ships with its checker. The audit confirmed violations for every rule family below while its checker is still [Pending] — each row is an enforcement ticket: build the checker, burn down the backlog it reveals. Counts are verified findings in this register (a finding may cover many sites).

| Rule | Checker to build | Verified findings | Known backlog |
|---|---|---|---|
| TQ-6 | extend check 6 to test/; grep real HTTP clients; randomized test ordering in CI | 47 | 377 DateTime.now() sites in test/ |
| AG-8 | audit rule pairing diff paths with doc paths | 27 | — |
| EH-3 | tighten audit check 9 to log-less (not just empty) catch bodies | 21 | — |
| AX-2 | custom_lint flagging string literals to Text(/SnackBar(/Tooltip( | 21 | — |
| EH-2 | review-checklist + custom_lint idea: data-layer methods return Result/AsyncValue | 20 | — |
| TQ-3 | pump_app.dart convention + CI Hebrew golden/widget test | 20 | — |
| EH-5 | audit grep: human-sentence literals in throw/exception constructors under features/**/{data,domain} | 16 | — |
| SM-4 | custom_lint: ref./state= after await without ref.mounted guard | 14 | — |
| TQ-7 | expect-count ratchet per file without weaken-ok marker | 14 | — |
| AG-6 | TODO/FIXME without DNI- fails; commented-out-code grep | 12 | 8 untracked TODOs (lib) + finder-reported extras |
| AG-4 | duplicate exported top-level identifier script | 10 | — |
| SM-7 | audit grep: static final .*(Repository|Service|Dao) + construction outside providers | 9 | — |
| AX-3 | audit grep: IconButton( lacking tooltip/semanticLabel | 9 | — |
| Rule 0 | meta: burn down this table | 9 | — |
| SM-6 | audit grep: keepAlive:true requires inline justification; riverpod_lint provider_parameters | 8 | — |
| EH-4 | enable avoid_catches_without_on_clauses + avoid_catching_errors | 8 | — |
| Rule 2 | fix check 15 awk; align barrel convention doc↔code | 8 | — |
| SM-2 | custom_lint: flag ref.read(x).method()/writes inside build()/initState | 7 | — |
| DB-2 | audit grep: DAO methods with ≥2 writes and no transaction(/batch( | 7 | — |
| AG-1 | audit grep over ci.yml/docs for raw flutter/dart invocations bypassing targets | 7 | — |
| AX-1 | port root RTL grep into inner audit (consolidation) | 6 | — |
| profileId | extend tool/schema_check.dart coverage (Goals gap) + DAO-scoping grep | 6 | — |
| SM-5 | audit grep: try blocks assigning state= inside @riverpod Notifier methods | 5 | — |
| TQ-4 | audit grep rejecting new mockito imports in test/ | 5 | — |
| EH-6 | non_exhaustive_switch_statement → error; grep wildcard arms on sealed switches | 4 | — |
| DB-1 | audit grep: Drift write calls outside **/data/** and core/database/ | 4 | — |
| DB-3 | audit grep: for/forEach blocks containing await into( | 4 | — |
| PF-2 | audit grep for scrollables with large concrete children | 4 | — |
| FB-2 | audit grep: no client clocks in sync codec ordering fields; emulator server-Timestamp test | 3 | — |
| AU-4 | grep on auth gate + setPersistence under lib/ | 3 | — |
| PF-3 | custom_lint idea: no await/DB call in build( | 3 | — |
| SM-8 | audit grep: *_repository*.dart importing another *_repository*.dart | 2 | — |
| SM-1 | diff-scoped grep for legacy provider constructors; riverpod_lint backstop | 2 | 109 hand-written provider constructors |
| DB-6 | review-checklist per synced entity | 2 | — |
| SR-2 | assertFails tests for oversized/wrong-typed fields | 2 | — |
| AX-4 | widget test at TextScaler 2.0 + tap-target/contrast guidelines | 2 | — |
| TQ-2 | audit grep: ProviderContainer( in test/ must be .test( or addTearDown( | 2 | — |
| TQ-5 | grep DateTime.now(/Random( in files calling matchesGoldenFile | 2 | — |
| AG-7 | git diff --exit-code freshness gate after CI codegen | 2 | — |
| AG-11 | deny-pattern on bypass flags; guardrail-path PR alert | 2 | — |
| SM-3 | custom_lint (DCM prior art: avoid-ref-read-inside-build) | 1 | — |
| DB-4 | make schema-check requires drift_schemas/ export + generated migration tests in make ci | 1 | — |
| DB-5 | review-checklist on bulk-write/aggregation paths | 1 | — |
| FB-3 | grep: mergers read snapshot metadata before LWW; two-device echo emulator test | 1 | — |
| FB-4 | audit grep: .add( under core/sync returns zero for event codecs; idempotency test | 1 | — |
| FB-5 | committed MAX_BATCH_OPS=500 + 501-op split property test | 1 | — |
| FB-9 | CI diff of deployed vs committed indexes; rules test denying client profile deletes | 1 | — |
| SR-1 | deny-tests: changed-value update assertFails, identical replay assertSucceeds | 1 | — |
| SR-4 | rules test: limit(500) succeeds, limit(1000)/unbounded fails | 1 | — |
| SR-5 | rules tests seeding expired vs active grants; access-call budget grep | 1 | — |
| PV-1 | audit grep over core/analytics banning identifiers in params + setCustomKey | 1 | — |
| PV-5 | grep: logEvent( call sites reference AnalyticsEvent.; regex unit test | 1 | — |
| PV-6 | App Check symbol confinement greps + secret-scan CI step | 1 | — |
| AU-1 | grep in auth module; emulator link-preserves-uid test | 1 | — |
| AU-2 | grep link error handler for both codes; emulator merge test | 1 | — |
| AU-3 | grep guarding signOut call sites; unit test asserting the block | 1 | — |
| AU-5 | grep on push-pipeline error handler + token writes to storage | 1 | — |
| PF-1 | enable the 2 remaining const lints; .select review-checklist | 1 | — |
| TQ-9 | test-rules into make ci; CI hard-fail; ruleCoverage gate | 1 | — |
| AG-2 | line-count cap on CLAUDE.md; doc-lint asserting referenced targets exist | 1 | — |
| AG-3 | wc -l ratchet check (warn → hard-fail) | 1 | 327 files (deterministic scan) |
| AG-5 | unmirrored-test check with ratchet | 1 | 537 unmirrored lib files |
| AG-9 | PR template Verification section (process) | 1 | — |

Priority order for checker work: (1) repair what exists and is broken — custom_lint toolchain, audit check 15, schema_check Goals gap (see AUD-guardrails-*); (2) checkers whose rule guards data integrity or privacy (profileId scoping, PV-1 params, FB-2/FB-3, SR-1..5); (3) the big-backlog ratchets (TQ-6, AG-3, AG-5) as warn-then-fail ratchets; (4) the rest in table order.
