# Standards-Audit Digest — read this fully before auditing your batch

You are one batch agent in a full-codebase standards audit of the Learning Tracker repo
(`/home/daniel/repos/learning-tracker`). The yardstick is `docs/coding-standards.md`
(revision 2026-07-02) — the digest below compresses it; consult the full doc for exact wording
when a call is close. Architecture/domain references you may consult: `docs/architecture.md`,
`docs/product-rules.md`, `docs/sync-conflict-resolution.md`, `docs/delete-policy.md`,
`docs/data-models.md`, `docs/firestore-collection-layout.md`, `docs/hebrew-terms.md`.

## Posture

1. **Presumption of guilt.** Every file is assumed to contain at least one violation until read
   in full and cleared. If you return zero findings for a file, your ledger note must say what
   you checked and why it cleared — "looks fine" is not a verdict.
2. **Evidence or it doesn't exist.** Every finding cites `file:line` with a minimal quote (≤2
   lines) and a concrete consequence (failure scenario, invariant at risk, or maintenance cost).
   A finding without traceable evidence is fabrication and will be killed in verification.
3. **Include the small stuff.** P3/minimal findings (naming drift, missing `const`, log-less
   catch, a 401-line file) are in scope and wanted. Severity honesty applies: never inflate.
4. **One finding per root cause.** Same defect at N sites in your batch = ONE finding with the
   sites listed in evidence and `sites: N` — not N findings.
5. **Blunt, plain voice.** Name the defect. No diplomatic padding, no theatrics.

## Batch protocol (per file)

1. **Read the whole file.** The violation is in the half you skipped.
2. **Applicability sweep** — rule families by file type:
   - Screens/widgets: Rules 2/5, SM-2..4, EH-5, PF-1..4, AX-1..4, naming/placement,
     presentation→data import ban.
   - Providers/notifiers: SM-1..8, EH-2/EH-6, plus greps for `DateTime.now`, raw Talker.
   - Repositories/DAOs/tables: DB-1..6, profileId-in-PK, SM-7/8, EH-2..4.
   - `core/sync/**`: FB-1..9, EH-2..4, Nygard lens mandatory (process death, offline, clock
     skew, permission-denied at every I/O point).
   - `core/analytics|logging|auth`, bootstrap: PV-1..6, AU-1..5, EH-1.
   - Tests: TQ-1..8 — tautological/over-mocked tests, weakened assertions (compare against what
     the source can actually do wrong), shared containers, wall-clock, golden nondeterminism.
   - `firestore.rules`/functions: SR-1..5, TQ-9.
   - Config/CI/Makefiles/hooks/custom_lints: Rule 0, AG-1..11 (bypassable gates, soft-skips,
     divergent targets, dead targets).
   - Everything: AG-3 (>400-line hand-written Dart file), AG-4 (duplicate top-level names —
     report candidates; the orchestrator dedups globally), AG-6 (untracked TODOs), dead code, EH-3.
3. **Lens pass beyond the rules** — Fowler (duplication, shotgun surgery, speculative
   generality, misplaced responsibility — name the refactoring), Feathers (can this be tested
   without booting Firebase/Drift? where's the seam?), Evans (ubiquitous language consistent?
   invariant enforced in one place or re-derived?), Nygard (what happens when this I/O fails
   halfway?).
4. **Verdict per file:** `SOUND` / `ISSUES` / `DEFECTIVE` (+ short note). Confidence per
   finding: `CONFIRMED` (traced statically) or `SUSPECTED` (needs runtime confirmation — say
   what would confirm it).

## Severity

- **P0** — data loss / security / child-privacy / silent corruption.
- **P1** — user-visible defect or violated named invariant.
- **P2** — design debt with stated concrete cost.
- **P3** — hygiene/minimal (still filed).

Acceptance criteria must include the Rule-0 checker or regression test wherever checkable.
Titles must be imperative, unique, self-locating (include area/symbol) — usable verbatim as
Linear ticket titles.

## Rules digest (IDs + requirement; [E]=Enforced today, [P]=Pending checker)

**Violations of [P]ending rules ARE novel findings — discovering that backlog is half the point.**

### Rule 0 + Layering (Rules 1–5)
- **Rule 0** — a standard ships with its deterministic checker (lint/grep/CI/test); checker
  failures print `file:line` and exit non-zero.
- **Rule 1** [E, warn-only] — no `core/` → `features/` imports (32 known edges are baselined; only NEW edges are findings).
- **Rule 2** [E, warn-only] — no cross-feature deep imports; only `features/Y/providers.dart` barrel; no other re-export barrels.
- **Rule 3** [E] — `FirebaseAuth`/`FirebaseFirestore`/`FirebaseStorage` only in `core/sync/`, `core/auth/`, `features/auth/` (+ `core/providers/firebase_providers.dart` injection).
- **Rule 4** [E] — `package:talker/talker.dart` only inside `core/logging/`; everyone else uses `AppLogger`.
- **Rule 5** [E] — `.displayNameEn/.displayNameHe` only in `core/labels/` + generated; presentation uses `CurriculumLabelRenderer`.
- **Hebrew terms** [E] — features never touch `HebrewTerms.*` directly; use `domainTermLabels(ref)`; `useHebrewTermsProvider` only in `core/labels/`, `core/preferences/`, settings/onboarding screens.

### State Management (Riverpod 3)
- **SM-1** [P] — new providers use `@riverpod` codegen; no legacy `StateProvider`/`StateNotifierProvider`/`ChangeNotifierProvider` (121 legacy usages are a known backlog — only NEW/changed-code usages are findings; do count NEW additions).
- **SM-2** [P] — provider `build` is pure: no writes/requests/side effects; never kick a provider from widget `initState`.
- **SM-3** [P] — `ref.watch` in build; `ref.read` only in callbacks; `ref.listen` for side effects. Never `ref.read` in build.
- **SM-4** [P] — after any `await` in a Notifier method/async callback, check `ref.mounted` before touching `ref`/`state` (Riverpod 3 throws `UnmountedRefException`).
- **SM-5** [P] — async mutations: `state = const AsyncLoading(); state = await AsyncValue.guard(...)`; let `build` throw; no manual try/catch assigning `state`.
- **SM-6** [P] — parameterized providers stay autoDispose; every `keepAlive: true` carries inline `// keepAlive:` justification; family args value-equal (no fresh `List`/`Map` args).
- **SM-7** [P] — repositories/services/DAOs constructed only inside their `@riverpod` provider (or test override); no global/static mutable singletons; no service-locator lookups.
- **SM-8** [P] — repositories never import other repositories; compose in a Notifier/domain service.

### Error Handling
- **EH-1** [P] — bootstrap installs BOTH `FlutterError.onError` and `PlatformDispatcher.instance.onError` (returning true), forwarding to AppLogger.
- **EH-2** [P] — typed exceptions inside a layer; converted to values (AsyncValue/sealed Result) at the data boundary; no raw exception reaches presentation.
- **EH-3** [E empty; P log-less] — every catch rethrows, converts, or logs via AppLogger. No empty AND no log-less catch.
- **EH-4** [E partial] — typed `on X catch`; never catch `Error` subtypes; only throw Exception/Error subclasses.
- **EH-5** [E lint] — domain/data errors carry stable codes/enums, never pre-formatted human messages; presentation resolves via AppLocalizations/ARB (EN+Hebrew app — raw English messages render untranslated).
- **EH-6** [E partial] — closed variant sets are `sealed` + switch EXPRESSIONS; no `default:`/`_` arm on a sealed switch.

### Drift / Offline-first (DB)
- **DB-1** [P] — all Drift mutations live under `**/data/**` or `core/database/`; notifiers/widgets mutate via repositories only.
- **DB-2** [P] — >1 write = one `transaction()`, every statement awaited.
- **DB-3** [P] — bulk same-shape writes use `batch()`/`insertAll`, never awaited per-row loops.
- **DB-4** [P] — every schemaVersion bump ships migration step + committed schema export + generated migration test; never modify a released migration (currently AT RISK: no `drift_schemas/` exists, schemaVersion 32 — known gap).
- **DB-5** [P] — heavy DB work off the UI isolate; `watch()` only for small reactive reads; one-shot `get()` for heavy joins.
- **DB-6** [P] — sync-able entities: local Drift is source of truth; local-first write with dirty/synchronized flag; read via watch stream; reconcile via sync engine.

### Firestore sync (FB — applies to core/sync/**)
- **FB-1** [P] — no client `runTransaction` in the sync path; drain outbox with batched writes.
- **FB-2** [P] — cross-device LWW ordering fields written as `FieldValue.serverTimestamp()`, never client clock; keep client ts locally for optimistic ordering.
- **FB-3** [P] — mergers skip LWW for snapshots with `hasPendingWrites`/`isFromCache`; never treat null server timestamp as epoch-0.
- **FB-4** [P] — event-log docs use deterministic `doc(hashedNaturalKey).set()`; never `add()`/auto-ID; never sequential/timestamp-prefixed IDs.
- **FB-5** [P] — outbox batches chunk at ≤500 ops counting each field transform as an op; <10MiB per commit.
- **FB-6** [P] — mutable snapshot docs + tombstones use `set(merge:true)`, never `update()` (update throws not-found on fresh device).
- **FB-7** [P] — every `.snapshots()` listener bounded (limit/cursor) and detached on background; paginate `startAfter`, never `offset()`.
- **FB-8** [P] — counts/rollups from local Drift; Firestore aggregations/cross-user reads only in the tutor path, bounded.
- **FB-9** [P] — new where/orderBy ships its composite index in `firestore.indexes.json` same change; profile recursive deletes server-side only.

### Security rules (SR — firestore.rules + functions)
- **SR-1** [P] — append-only collections (completions, streak_events, learning_ledger, points_ledger) deny value mutation on update; allow only identical replay.
- **SR-2** [P] — rules validate value types and cap string sizes, not just `hasOnly()` key sets.
- **SR-3** [P] — every event create requires present, `is timestamp`, `<= request.time`.
- **SR-4** [P] — `allow list` on per-profile event collections capped `request.query.limit <= 500`.
- **SR-5** [P] — tutor cross-user access checks `state == 'active' && expires_at > request.time` in the rule; ≤2 document-access calls per rule.
- Keep rules minimal/fixture-driven — this repo has self-inflicted permission-denied outages from over-tight rules (PHASE-D zero-denial oracle exists for this). Don't recommend business logic in rules.

### Privacy / child data (PV — COPPA/GDPR-K, load-bearing)
- **PV-1** [P] — analytics params never carry content identifiers or per-child identifiers (no `sefaria_ref`, no `profile_id`, no names). KNOWN violation in analytics_service.dart — baselined.
- **PV-2** [P] — `setUserIdentifier`/`setUserId` get only opaque local id/hash; Crashlytics arg type-locked `int?`.
- **PV-3** [P] — Crashlytics/Analytics collection consent-gated, off by default. KNOWN violation in firebase_bootstrap.dart — baselined.
- **PV-4** [P] — no ads SDK in pubspec; ad-personalization signals disabled in manifests.
- **PV-5** [P] — every analytics event via `AnalyticsEvent` constant `^[a-z][a-z0-9_]{0,39}$`; no inline event-name literals.
- **PV-6** [E partial] — App Check debug providers only in `kDebugMode` bootstrap; activation non-fatal; debug tokens never committed.

### Auth / offline accounts (AU)
- **AU-1** [P] — convert offline account via `currentUser.linkWithCredential(...)`; never signIn/createUser while anonymous (uid must survive).
- **AU-2** [P] — handle `credential-already-in-use` + `account-exists-with-different-credential` with explicit merge; never drop offline data.
- **AU-3** [P] — never `signOut()` an anonymous user with unsynced outbox entries.
- **AU-4** [P] — session routing on `authStateChanges()`/`idTokenChanges()` streams, never bare `currentUser` read; cancel subs on dispose; no `setPersistence` on mobile.
- **AU-5** [P] — on permission-denied/unauthenticated from a synced write: one `getIdToken(true)` refresh + single retry; never persist ID tokens.

### Storage (ST)
- **ST-1** [P] — committed `storage.rules` wired into firebase.json. KNOWN gap (none exists) — baselined.
- **ST-2** [P] — upload paths owner-scoped over default-deny, content-type+size capped. (Judgment call on avatars: bundled presets preferred — documented; don't re-litigate without new evidence.)

### Performance (PF)
- **PF-1** [E partial] — `const` leaf widgets; narrow reads with `.select(...)`; hoist animation-independent subtrees.
- **PF-2** [P] — viewport-exceeding collections use lazy builders; heavy CPU off main isolate.
- **PF-3** [P] — `build()` free of I/O, awaits, allocation-heavy loops.
- **PF-4** [P] — images decode at display size (`cacheWidth/Height`).

### Accessibility / i18n (AX)
- **AX-1** [E] — `EdgeInsetsDirectional`/`AlignmentDirectional`; never `EdgeInsets.only(left:/right:)` or `Alignment.centerLeft/Right` (RTL app!). NOTE: grep exists only in ROOT Makefile audit.
- **AX-2** [E parity; P literals] — no hardcoded user-facing strings; everything via AppLocalizations/ARB with ICU plurals; EN/HE key parity (passes today, 1421 keys).
- **AX-3** [P] — icon-only buttons/meaningful images carry semantics; directional glyphs `matchTextDirection: true` or auto-mirroring icons.
- **AX-4** [P] — no fixed heights on text wrappers; `TextScaler` not deprecated `textScaleFactor`; 48dp targets; 4.5:1 contrast.

### Testing (TQ)
- **TQ-1** — pyramid-shaped suite; prefer unit over widget over integration.
- **TQ-2** [P] — fresh `ProviderContainer.test()` (or `addTearDown(dispose)`) per test; never shared containers.
- **TQ-3** [P] — widget tests pump via shared `pumpApp` helper with l10n delegates; key screens have `Locale('he')` RTL variant.
- **TQ-4** [P] — hand-written fakes for stateful collaborators; mocktail only for interaction verification; NO new mockito.
- **TQ-5** [P] — goldens deterministic (fonts loaded, pinned size/theme/locale, fixed clock, constant data).
- **TQ-6** [E partial] — hermetic tests: no network, no wall-clock (`clockProvider`/fixed factory), no unseeded randomness, no shared mutable state.
- **TQ-7** [P] — never weaken/delete a test to pass; assertion removal needs `// weaken-ok: <reason>`.
- **TQ-8** — every bug fix has a red-first regression test. Look for tautological tests (assert what the mock returns), over-mocked tests, assertions weaker than what the source can do wrong.
- **TQ-9** [P] — rules suite is part of local+CI gates; `demo-*` project; no soft-skip. KNOWN gaps in ci.yml/Makefile — baselined.

### AI-agent workflow (AG)
- **AG-1** [P] — build/test/codegen/audit invocations route through make targets or committed tool/ scripts; no ad-hoc variants in CI/docs.
- **AG-2** [P] — CLAUDE.md files small (root <150 lines), exact commands, no analyzer-expressible rules.
- **AG-3** [P] — hand-written Dart files ≤400 lines (generated exempt). Report every violator with its line count.
- **AG-4** [P] — public top-level symbol names unique across lib/ — report duplicate candidates you notice; orchestrator dedups globally.
- **AG-5** [P] — test/ mirrors lib/ 1:1 (story_acceptance exempt); new source file's test at mirrored path.
- **AG-6** [P] — every TODO/FIXME carries a Linear id (DNI-####); no commented-out code blocks.
- **AG-7** [E partial] — never hand-edit generated files; regenerate. (A stale-codegen finding for 3 .g.dart files is ALREADY captured by the orchestrator — don't re-report; do report hand-edit evidence.)
- **AG-8** [P] — schema/sync/collection diffs update their paired doc in the same PR; docs prefer `file:line` pointers over pasted code.
- **AG-9** — non-trivial changes carry verification evidence; adversarial review for confirmed findings.
- **AG-10** [P] — one task = one worktree = one branch `<wave>/<DNI-####>-<slug>`.
- **AG-11** [P] — guardrail changes (Makefiles, analysis_options, workflows, hooks, custom_lints, tool/, CLAUDE.md, coding-standards.md) get human review; no bypass flags, no narrowed globs, no renamed/removed checks, no softened lints without stated reason.

### Naming / placement / invariants
- snake_case files; suffix encodes role (`_screen`, `_widget`, `_provider`, `_repository`, `_repository_impl`, `_dao`, `_service`, `_notifier`, `_model`, `_dto`, `_mapper`, `_test`). No abbreviations in file names. No `_utils.dart` god-files.
- Layout: `features/<f>/{data,domain,presentation/{providers,screens,widgets}}`; core per placement guide. Presentation must NOT import `features/*/data/**` [P].
- Domain/state models are immutable `@freezed` classes; never hand-write `==`/`hashCode` for data classes; records only for small private returns.
- **profileId-in-PK** [E] — every user-data table in user_database includes `profileId` in its composite PK; no bare autoincrement PKs for user data (content tables exempt).
- Acceptance tests: `epic_NN_<slug>_test.dart`, story tags `story_NN_M`.

## Novelty filter — do NOT re-report

Baseline tooling ran 2026-07-03 on a clean tree at commit 4018a91c:

1. `make audit` (inner, 22 checks): **PASSED**. Checks 14/15 are warn-only and list ~32 known
   `lib/core/sync/**` (and related) → `features/**` import edges — ALL current core→features and
   cross-feature deep-import edges are baselined (full list: `/home/daniel/repos/learning-tracker/docs/audits/standards-audit-2026-07-03/_work/baseline/make-audit.txt`). A NEW edge would be a finding; the existing set is not. The pattern "core/sync
   depends on features" as a DESIGN observation may appear only as part of a larger architectural
   finding, not as a per-edge report.
2. `flutter analyze`: **No issues found** — anything the analyzer would flag is baseline-clean.
3. root `make arb-parity`: **OK — 1421 EN keys all present in HE**.
4. `dart run custom_lint`: **BROKEN** — crashes (custom_lint_core 0.8.1 vs analyzer 9.0
   incompatibility, exit 255, no lint output). The 9 custom lint rules therefore currently
   enforce NOTHING. The brokenness itself is already captured by the orchestrator — do not
   re-report it — but violations of the nine rules (`no_feature_cross_import`,
   `no_firebase_outside_core`, `no_raw_talker`, `no_curriculum_display_name_bypass`,
   `no_hardcoded_domain_term`, `no_hardcoded_text_direction`, `no_color_literal_outside_theme`,
   `no_e_to_string_in_ui`, `no_raw_logevent`) ARE reportable findings where the audit greps
   don't already cover them.

Known compliance gaps (already in the standards doc — do NOT re-report as new):
1. Analytics sends `sefaria_ref`/`profile_id` params (PV-1) — analytics_service.dart:56,82,87.
2. Crashlytics enabled unconditionally (PV-3) — firebase_bootstrap.dart:45.
3. No committed storage.rules (ST-1).
4. Two firebase.json disagree on emulator port 9090 vs 8080 (TQ-9).
5. `make ci` doesn't run test-rules; CI rules job soft-skips (TQ-9).
6. CI soft-skips audit; custom_lint warn-only (Rule 0).
7. Two divergent Makefile audit sets; RTL grep only in root (AX-1/Rule 0).
8. ~121 legacy Riverpod provider usages (SM-1 backlog).
9. No drift_schemas/ exports or migration tests at schemaVersion 32 (DB-4).
10. Audit checks 14–15 warn-only (Rules 1–2 backlog).

Documented judgment calls — do not re-litigate without NEW evidence: nested subcollections
layout; hand-rolled explicit lint list (not flutter_lints include); bundled-avatars default.

Already captured by the orchestrator (do not duplicate): stale codegen drift in
`curriculum_label_providers.g.dart`, `reward_config_controller.g.dart`,
`scheduler_providers.g.dart` (AG-7); repo-hygiene items: tracked `build/` artifacts, tracked
`clear` file, stale root `coding-standards.md` duplicate, legacy `_bmad-output/` outputs.

## Churn hotspots (deepest scrutiny — these files churned most across fix waves)

settings_screen.dart, sync_engine.dart, dashboard_screen.dart, onboarding_screen.dart,
scheduler_providers.dart, completion_repository_impl.dart, add_track_flow.dart, app_router.dart,
text_display_screen.dart, dashboard_providers.dart, sign_in_screen.dart, progress_screen.dart,
main.dart, learning_screen.dart, goal_setup_screen.dart, lifetime_knowledge_providers.dart,
bulk_mark_screen.dart, user_database.dart, profile_picker_screen.dart, track_dao.dart,
sync_orchestrator.dart, firestore_data_source.dart, app_intro_screen.dart,
content_hierarchy_screen.dart, track_detail_screen.dart, notification_providers.dart,
completion_dao.dart, track_creation_service.dart, completion_providers.dart, app_shell.dart,
offline_queue.dart, account_actions.dart

## Special protocols by tier

- **Tier 2 (config/CI/tooling):** judge for correctness, security, drift between duplicates,
  dead targets, bypassable gates (AG-11), soft-skips, secrets. Full read still applies.
- **Tier 4 canonical docs:** factual-drift check against code ONLY (does the doc's claim match
  reality? run greps to verify specific claims — file paths, make targets, counts, behavior).
  Not style review. Verdict per doc file.
- **Tier 4 triage docs (stories/planning/scenarios/qa/status/explainers/audits):** classify each
  file `POINT-IN-TIME` (historical artifact, fine to keep) vs "presents itself as current" —
  full drift-audit ONLY the latter. Egregious contradictions with reality are findings.
- **Unmirrored test dirs** (`test/features/{auth,labels,learning_order,parent_mode,stages,track_setup,track_learning_order}`
  have no `lib/features/` counterpart): judge AG-5 mirroring and staleness — do these tests
  still test real code, and do they belong at a mirrored path?
