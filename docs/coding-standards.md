---
title: Coding Standards
description: Layering rules, Riverpod/Drift/Firebase discipline, privacy, testing, AI-agent workflow standards, and enforcement guidance for the Learning Tracker codebase.
date: 2026-07-02
---

# Coding Standards

This document is the authoritative reference for code style, structure, and layering discipline in the Learning Tracker Flutter application. It supplements the [Developer Handbook](developer-handbook.md) (Part 4) and the [Architecture](architecture.md) document.

**Revision 2026-07-02** — expanded with research-sourced standards for Riverpod 3, Drift/offline-first, Firebase/Firestore, child-data privacy, testing, and AI-agent workflows (primary sources listed in [Sources](#sources)); enforcement sections corrected to match the real `make audit` (22 checks) and the landed custom_lint package (9 rules).

## How to read a rule

Every rule carries an enforcement status:

- **[Enforced]** — a checker exists today (analyzer lint, custom_lint, audit grep, CI step, or test). The checker is named.
- **[Pending]** — the rule is normative now, but its checker still needs to be built. The proposed checker is named. Per Rule 0, build the checker when you first apply the rule.

## Table of Contents

- [Rule 0 — A standard ships with its checker](#rule-0--a-standard-ships-with-its-checker)
- [Layering Rules](#layering-rules) (Rules 1–5)
- [State Management — Riverpod 3](#state-management--riverpod-3) (SM)
- [Error Handling](#error-handling) (EH)
- [Drift & Offline-First Data](#drift--offline-first-data) (DB)
- [Firestore Sync Discipline](#firestore-sync-discipline) (FB)
- [Firestore Security Rules](#firestore-security-rules) (SR)
- [Privacy & Child Data](#privacy--child-data) (PV)
- [Auth & Offline Accounts](#auth--offline-accounts) (AU)
- [Storage](#storage) (ST)
- [Performance](#performance) (PF)
- [Accessibility & i18n](#accessibility--i18n) (AX)
- [Testing Standards](#testing-standards) (TQ)
- [AI-Agent Workflow Standards](#ai-agent-workflow-standards) (AG)
- [File Naming Conventions](#file-naming-conventions)
- [File Placement Guide](#file-placement-guide)
- [profileId-in-PK Invariant](#profileid-in-pk-invariant)
- [Lint Baseline](#lint-baseline)
- [Enforcement — `make audit` and CI](#enforcement--make-audit-and-ci)
- [Custom Lints Reference](#custom-lints-reference)
- [Current Compliance Gaps](#current-compliance-gaps-2026-07-02)
- [Sources](#sources)

---

## Rule 0 — A standard ships with its checker

A coding standard is not adopted until it ships with a deterministic checker — an analyzer lint, a custom_lint rule, a `make audit` grep, a CI step, or a test — ideally in the same PR. Prose-only entries in this document are non-normative examples, not rules.

**Why:** this codebase is built largely by AI agents in iterative waves. Agents reliably conform to what fails their loop (lint/test/CI), not to what prose suggests; a documented-but-unenforced rule drifts silently across waves. This is the organizing principle behind everything below.

Corollaries:

- Every checker failure prints `file:line` and a one-line reason, and exits non-zero — agents self-correct only on signals they can read.
- Promote high-value audit greps into custom_lint rules over time so violations surface in-editor while the grep remains the CI backstop.
- Rules in this doc marked **[Pending]** are debt against Rule 0; burn the list down.

---

## Layering Rules

The dependency direction is strictly `app → features → core`. These five rules are **invariants** — violations must never be committed. Each rule is enforced by a custom lint in `packages/custom_lints/` (landed; see [Custom Lints Reference](#custom-lints-reference)) plus a `make audit` grep. Note: CI currently runs custom_lint **warn-only**, and the tool cannot presently discover this project at all (see "custom_lint toolchain status" under [Enforcement](#enforcement--make-audit-and-ci)) — the audit greps are the hard gate until that resolves.

### Rule 1 — No `core/` → `features/` imports

`lib/core/` MUST NOT import anything from `lib/features/`.

Core is shared infrastructure (database, logging, navigation, theme, sync gateway, etc.). It cannot depend on feature business logic. Any data a core module needs from a feature must be provided via dependency injection (constructor parameter or Riverpod provider), not by importing the feature directly.

**Lint:** `no_feature_cross_import` · **Audit:** inner check 14 (currently warn-only pending legacy cleanup)

```bash
grep -r "import 'package:learning_tracker/features/" \
  lib/core/ --include="*.dart"
```

### Rule 2 — No cross-feature deep imports

`lib/features/X/` MUST NOT import directly from `lib/features/Y/<anything-other-than-Y.dart>`.

Features are independent vertical slices. The only permitted cross-feature reference is the feature's public surface file `lib/features/Y/Y.dart` (e.g. `lib/features/tutoring/tutoring.dart`) — named after the feature directory itself, per `learning_tracker/CLAUDE.md`. If that file does not exist yet, the importing feature must go through a core provider or core service instead.

The `Y.dart` barrel is the **only** sanctioned re-export file per feature. Do not add other barrel/re-export files — deep re-export chains defeat "where is X defined?" search and hide layering violations from both agents and reviewers.

*(AUD-learning-02: this rule previously named the barrel `providers.dart`, contradicting `learning_tracker/CLAUDE.md`'s `Y.dart` and matching zero of the 15 barrel files that actually exist in `lib/features/*/` — all 15 are `Y.dart`. Reconciled to the convention already in universal use rather than proposing a 15-file, all-consumers rename.)*

**Lint:** `no_feature_cross_import` · **Audit:** inner check 15 (currently warn-only pending legacy cleanup)

### Rule 3 — Firebase symbols confined to auth and sync modules

`FirebaseAuth`, `FirebaseFirestore`, and `FirebaseStorage` MUST only appear inside:

- `lib/core/sync/` — Firestore gateway implementation
- `lib/core/auth/` and `lib/features/auth/` — authentication repository and providers

All other code receives Firebase instances through injected Riverpod providers (`lib/core/providers/firebase_providers.dart`). No file outside these trees may import `firebase_auth`, `cloud_firestore`, or `firebase_storage` packages directly.

**Lint:** `no_firebase_outside_core` · **Audit:** inner checks 1–3

### Rule 4 — Raw Talker confined to `core/logging/`

`package:talker/talker.dart` MUST only be imported inside `lib/core/logging/`.

All other code logs through `AppLogger` (`lib/core/logging/logger.dart`). Importing the raw `Talker` instance bypasses PII redaction, log-level filtering, and Crashlytics breadcrumb integration that `AppLogger` provides.

**Lint:** `no_raw_talker` · **Audit:** inner check 4

### Rule 5 — `.displayNameEn` / `.displayNameHe` confined to `core/labels/` and generated files

Direct access to `.displayNameEn` or `.displayNameHe` on `CurriculumId` or related enums MUST only appear in `lib/core/labels/` (the canonical label layer) and generated files.

All presentation code MUST use `CurriculumLabelRenderer` (`lib/core/labels/curriculum_label_renderer.dart`), which resolves the correct locale-aware string and applies display overrides. Bypassing it produces inconsistent labels and breaks Hebrew/English locale switching.

**Lint:** `no_curriculum_display_name_bypass` · **Audit:** inner checks 8, 20–22

### Hebrew Terms and domainTermLabels

All presentation code that renders Jewish learning terms (stage names, masechet/perek/daf labels, חזרה, etc.) MUST use `domainTermLabels(ref)` from `lib/core/labels/domain_term_labels.dart`. Never access `HebrewTerms.*` directly in `lib/features/` — enforced by inner audit check 13. Widgets that need `domainTermLabels` must be `ConsumerWidget` or `ConsumerStatefulWidget`.

**Why:** `HebrewTerms.*` are raw constants that ignore the user's Hebrew-terms toggle. `domainTermLabels(ref)` reads `useHebrewTermsProvider` and returns the correct script (Hebrew ↔ transliteration) at runtime, including live re-render when the toggle changes mid-session.

The only permitted call sites for `useHebrewTermsProvider` are `lib/core/labels/`, `lib/core/preferences/`, and settings/onboarding screen files (inner check 7) — all other code goes through `domainTermLabels(ref)`.

**Lint:** `no_hardcoded_domain_term` · **Audit:** inner checks 7, 13, 19

---

## State Management — Riverpod 3

**SM-1 — Declare every new provider with `@riverpod` codegen; no hand-written provider constructors and no `legacy.dart` primitives** (`StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider`).
**Why:** codegen gives autoDispose-by-default, stateful hot-reload, and safe args; the legacy primitives were demoted to `legacy.dart` in Riverpod 3. ~121 legacy usages remain in `lib/` — this rule is diff-scoped (new/changed code) with a migration backlog; do not add to the count.
**Enforce:** [Pending] diff-scoped audit grep for legacy provider constructors in changed non-generated files; backstop by adding `riverpod_lint` to the custom_lint run.
**Source:** riverpod.dev/docs/concepts/about_code_generation

**SM-2 — Keep provider `build` pure: no writes, no request-firing, no side effects; never kick a provider off from a widget's `initState`.**
**Why:** side effects in `build` race and get skipped or duplicated on rebuild — the documented cause of "unexpected behaviors" in the Riverpod do/don't guide.
**Enforce:** [Pending] review-checklist + custom_lint idea flagging `ref.read(x).method()` inside `build`/`initState`.
**Source:** riverpod.dev/docs/root/do_dont

**SM-3 — `ref.watch` in `build`, `ref.read` only in callbacks, `ref.listen` for side effects (snackbars/navigation). Never `ref.read` in `build` to dodge a rebuild.**
**Why:** `ref.read` in `build` desyncs the UI from provider state — it silently renders stale data after updates.
**Enforce:** [Pending] custom_lint rule (DCM has `avoid-ref-read-inside-build` as prior art).
**Source:** riverpod.dev/docs/root/do_dont

**SM-4 — After any `await` in a Notifier method or async callback, check `ref.mounted` before touching `ref` or `state`.**
**Why:** Riverpod 3 throws `UnmountedRefException` when a disposed Ref is touched — an autoDispose provider can be torn down mid-`await` and crash the app. (The `BuildContext` analog is covered by the enabled `use_build_context_synchronously` lint.)
**Enforce:** [Enforced] two complementary custom_lint rules: `no_unguarded_state_touch_after_await` (AUD-onboarding-01) flags `state =`/`setState(...)` after an `await` in a Notifier/State method with no intervening `mounted`/`ref.mounted` guard (scoped to the method body's own statement sequence, including `try`/`catch`); `no_ref_after_await_without_mounted_check` (AUD-sync-04) flags `ref.read`/`ref.watch`/`ref.invalidate`/`ref.refresh`/`ref.listen`/`state = ...` after an earlier `await` in the same async method/closure with no `ref.mounted` guard in between (`outboxDrainAndRecordAttempt` in `features/sync/presentation/providers/sync_providers.dart` is the reference fix).
**Source:** riverpod.dev/docs/whats_new

**SM-5 — Async mutations follow `state = const AsyncLoading(); state = await AsyncValue.guard(() => …)`. Let `build` throw; never hand-manage loading/error with a try/catch that assigns `state`.**
**Why:** `guard` funnels failures into `AsyncError` with the stack so the error branch always renders; manual try/catch routinely drops the stack or leaves the spinner stuck. The split is deliberate: a failed *load* errors the screen, a failed *mutation* errors the action.
**Enforce:** `no_hand_rolled_async_state_notifier` custom_lint rule (INFO — migration-candidate nudge, see [Custom Lints Reference](#custom-lints-reference)); `SignInController` (`lib/features/account/presentation/notifiers/sign_in_controller.dart`) is the reference fix (AUD-account-14) — every `signInWith*` action now derives its terminal state from one `AsyncValue.guard(() => _bodyFn(...))` call instead of scattered `state = ...` assignments.
**Source:** pub.dev/documentation/riverpod — AsyncValue.guard

**SM-6 — Keep parameterized providers autoDispose; every `keepAlive: true` carries an inline `// keepAlive:` justification. Family arguments must be value-equal (primitives, records, freezed) — never a freshly built `List`/`Map`.**
**Why:** a non-autoDispose family leaks one state object per unique argument forever; a non-`==` argument makes every build a new family member, firing an infinite request loop (permanent spinner).
**Enforce:** [Pending] audit grep requiring the justification comment beside `keepAlive: true`; `riverpod_lint: provider_parameters` for the equality half.
**Source:** riverpod.dev — passing_args

**SM-7 — Construct repositories, services, and DAOs only inside their `@riverpod` provider (or a test override). No global/static mutable singletons; no service-locator lookups inside methods.**
**Why:** globals can't be overridden in tests and reintroduce exactly the coupling the layering rules remove.
**Enforce:** [Pending] audit grep for `static final .*(Repository|Service|Dao)` and direct construction outside provider files/tests.
**Source:** docs.flutter.dev/app-architecture/case-study/dependency-injection

**SM-8 — Repositories never import or depend on other repositories; compose multi-source data in a Notifier or domain service.**
**Why:** repo→repo edges create hidden coupling and cycles, and make each repository un-fakeable in isolation. The Flutter architecture guide: repositories "should never be aware of each other."
**Enforce:** [Pending] audit grep — a `*_repository*.dart` must not import another `*_repository*.dart`.
**Source:** docs.flutter.dev/app-architecture/guide

---

## Error Handling

**EH-1 — Bootstrap installs both `FlutterError.onError` and `PlatformDispatcher.instance.onError` (returning `true`), each forwarding to `AppLogger`.**
**Why:** framework build/layout errors reach only the first; async/platform errors reach only the second. Wire one and the other class of error becomes an invisible production crash.
**Enforce:** [Pending] audit grep asserting both assignments exist in the bootstrap file.
**Source:** docs.flutter.dev/testing/errors

**EH-2 — Throw typed exceptions inside a layer; convert to a value (`AsyncValue` via provider, or a sealed `Result`) at the data-layer boundary. A raw exception must never propagate into presentation.**
**Why:** undocumented exceptions crossing layers are the architecture guide's named crash source; an exhaustive switch on a sealed result forces the caller to handle the failure branch.
**Enforce:** [Pending] review-checklist ("data converts, presentation surfaces"); custom_lint idea: public data-layer methods return `Result`/`AsyncValue`, not bare throwing `Future<T>`.
**Source:** docs.flutter.dev/app-architecture/design-patterns/result

**EH-3 — Never swallow an error: every `catch` rethrows, converts, or logs through `AppLogger`. No empty and no log-less catch blocks.**
**Enforce:** [Enforced] `empty_catches` analyzer lint + inner audit check 9 (literally-empty bodies) + `no_log_less_catch` custom_lint rule (AUD-onboarding-11) for the log-less half — flags any `catch` under `lib/` with no `AppLogger` call and no `rethrow`, including the comment-only shape that dodges `empty_catches`.
**Source:** dart.dev/effective-dart/usage

**EH-4 — Catch with typed `on <Type> catch` clauses; never catch `Error` subtypes; throw only `Exception`/`Error` subclasses.**
**Why:** a bare catch traps programming-error `Error`s that should crash loudly with a stack, masking real bugs; thrown strings defeat every typed `on` clause downstream.
**Enforce:** [Enforced] `only_throw_errors` (enabled). [Enforced, scoped] `make audit` check 27 (`tool/check_eh4_typed_catches.dart`) requires every named `catch`/`catchError` in `lib/core/sync/{sync_orchestrator,pull_pipeline}.dart` and `lib/core/sync/tutored_listener_supervisor.dart` to carry an `on <Type>` clause (or a `catchError` `test:` filter), or an inline `// audit:eh4-broad-catch-ok` marker documenting why it must stay broad (AUD-core-sync-26). [Pending] the project-wide `avoid_catches_without_on_clauses` + `avoid_catching_errors` analyzer lints remain pending — ~150 bare `catch` sites exist outside core/sync (see [Lint Baseline](#lint-baseline)); enabling them globally is a separate, larger sweep.
**Source:** dart.dev/tools/linter-rules/only_throw_errors

**EH-5 — Domain/data errors carry a stable error code or enum, never a pre-formatted human message. Presentation resolves the code through `AppLocalizations`/ARB.**
**Why:** the app ships EN + Hebrew — an English `exception.message` surfaced raw renders untranslated (and un-RTL-shaped) to Hebrew users. This is the recurring "raw sync exception string" defect class (ST-4, SY-3 fixes).
**Enforce:** [Enforced] `no_e_to_string_in_ui` custom lint. [Pending] audit grep for human-sentence literals in `throw`/exception constructors under `features/**/{data,domain}`.
**Source:** docs.flutter.dev — internationalization

**EH-6 — Model every closed set of variants (result kinds, UI union states, domain modes) as a `sealed` hierarchy and switch over it with switch *expressions*; never add a `default:`/`_` arm to such a switch.**
**Why:** `sealed` + expression switches make missing variants a compile-time **error** at every call site; a wildcard arm silently absorbs future variants and destroys that guarantee. (This is how `ProfileMode`/`AccountTier` raw-string drift — audit checks 16–17 — is prevented at the type level.)
**Enforce:** [Enforced] `exhaustive_cases` (enabled). [Pending] escalate `non_exhaustive_switch_statement` to error in `analysis_options.yaml`; audit grep for wildcard arms in switches over sealed domain types.
**Source:** dart.dev/language/class-modifiers, dart.dev/language/branches

---

## Drift & Offline-First Data

**DB-1 — All Drift mutations (`into().insert`, `update`, `delete`, `.write`, `customUpdate`) live under `**/data/**` (feature data layer) or `core/database/`; Notifiers and widgets mutate only via repository methods.**
**Why:** single-source-of-truth — if more than one class can write an entity you get divergent copies of state, the exact bug the layering exists to prevent.
**Enforce:** [Pending] audit grep for Drift write calls outside sanctioned directories.
**Source:** docs.flutter.dev/app-architecture/design-patterns/offline-first

**DB-2 — Any operation performing more than one write runs inside a single `transaction()`, with every statement awaited.**
**Why:** with no server to reconcile, a crash mid-sequence leaves the local DB permanently half-written; Drift also throws if a transaction is touched after close (the un-awaited-write bug).
**Enforce:** [Pending] audit grep flagging DAO method bodies with ≥2 write calls and no enclosing `transaction(`/`batch(`.
**Source:** drift.simonbinder.eu/dart_api/transactions

**DB-3 — Bulk same-shape writes use `batch()`/`insertAll`, never a loop of individually awaited inserts.**
**Why:** a per-row awaited loop re-prepares the same SQL N times — write amplification that janks seed imports; a batch prepares once and commits atomically.
**Enforce:** [Pending] audit grep for `for`/`.forEach(` blocks containing `await into(`.
**Source:** drift.simonbinder.eu/dart_api/writes

**DB-4 — Every `schemaVersion` bump ships three things together: a migration step, a committed schema export (`drift_schemas/drift_schema_v<N>.json` via `drift_dev schema dump`), and a generated migration test (`migrateAndValidate` per step plus a data-preservation case). Never modify a released migration or a committed schema JSON.**
**Why:** the user DB is at schemaVersion 32 with real on-device data and no server backup — editing a shipped migration diverges installed devices from their history and corrupts silently on the next upgrade. Adopt the schema-export workflow first (no `drift_schemas/` directory exists yet).
**Enforce:** [Pending] extend `make schema-check` to require the matching schema JSON; CI diff-guard rejecting edits to existing `drift_schema_v*.json`; wire `test/generated_migrations/` into `make ci`; debug backstop `if (kDebugMode) await validateDatabaseSchema();` in `beforeOpen`.
**Source:** drift.simonbinder.eu/migrations/exports, /migrations/tests

**DB-5 — Heavy DB work (seed imports, large batches, expensive aggregations) runs off the UI isolate (`computeWithDatabase`/`Isolate.run`). Reserve `watch()` streams for reactive reads returning few rows; use one-shot `get()` for heavy joins.**
**Why:** main-isolate work beyond the frame budget drops frames, and a watched heavy join re-executes on every write to any tracked table — jank on every unrelated insert.
**Enforce:** [Pending] review-checklist on bulk-write/aggregation paths.
**Source:** drift.simonbinder.eu/isolates

**DB-6 — For every sync-able entity, the local Drift DB is the source of truth: write local-first with a dirty/`synchronized` flag, read via a stream over a Drift `watch` query, reconcile through the sync engine.**
**Why:** writing remote-first or reading remote-only stalls or loses data whenever the device is offline — unacceptable in an offline-first app.
**Enforce:** [Pending] review-checklist per new synced entity (local write path + flag + watch stream + reconciler).
**Source:** docs.flutter.dev/app-architecture/design-patterns/offline-first

---

## Firestore Sync Discipline

These rules govern `lib/core/sync/` — the only place Firestore is touched (Rule 3).

**FB-1 — Never use client transactions (`runTransaction`) anywhere in the sync path; drain the outbox with batched writes.**
**Why:** client transactions fail when offline, silently blocking the user until connectivity returns; batched writes queue durably and execute offline.
**Enforce:** [Pending] audit grep: `runTransaction` under `core/sync/` returns zero.
**Source:** firebase.google.com/docs/firestore/manage-data/transactions

**FB-2 — Every cross-device LWW ordering field is written as `FieldValue.serverTimestamp()`, never a client clock. Keep a client timestamp locally for optimistic ordering; reconcile to the server-resolved value on write-ack.**
**Why:** two devices with skewed clocks writing client timestamps make last-write-wins non-deterministic — the faster clock always wins and silently overwrites newer data.
**Enforce:** [Enforced] for `pushTrack`/`pushSettings`/`pushBookmark`/`pushGoal` (AUD-core-sync-13): `make audit` check 28 greps `firestore_gateway_impl.dart` for the `FieldValue.serverTimestamp()` overwrite on each method's LWW field (`state_changed_at` for tracks, `updated_at` for the rest — `pushLearnerProfile` already did this); matching emulator tests live in `firestore_gateway_impl_test.dart` group "2a". [Pending] elsewhere: other `push*` methods whose entity is LWW-merged by a client-set timestamp (e.g. the gamification/UI-preferences snapshot pushes) are not yet covered — extend the same pattern before relying on their ordering fields.
**Source:** firebase.google.com/docs/firestore/manage-data/add-data

**FB-3 — Mergers skip LWW resolution for snapshots with `metadata.hasPendingWrites` or `metadata.isFromCache`, and never treat an unresolved (null) server timestamp as epoch-0.**
**Why:** a locally-originated write echoes back through the listener with its `serverTimestamp()` still null; resolving LWW against that snapshot drops the write you just made.
**Enforce:** [Pending] grep that mergers read snapshot metadata before LWW; two-device emulator test: offline write → reconnect → own echo must not trigger an overwrite.
**Source:** firebase.google.com/docs/firestore/query-data/listen

**FB-4 — Event-log documents are written with deterministic `doc(id).set()` on a hashed natural key — never `add()`/auto-ID, and never a raw sequential/timestamp-prefixed document ID.**
**Why:** `add()` on retry creates duplicate events (idempotency requires a stable ID); but monotonic IDs hotspot one tablet and cap the collection at ~500 writes/sec during backfill bursts. Hash the natural key: deterministic *and* scattered.
**Enforce:** [Pending] audit grep: `.add(` under `core/sync/` returns zero for event codecs; emulator idempotency test (same event pushed twice → one doc); review-checklist on any new event collection's key scheme.
**Source:** firebase.google.com/docs/firestore/best-practices

**FB-5 — Chunk outbox batches at ≤ 500 operations counting each field transform (`serverTimestamp`, `increment`, `arrayUnion`) as an operation, and keep each commit under 10 MiB.**
**Why:** the server rejects an oversized commit outright, failing the whole atomic batch and stalling the queue on a large offline backlog.
**Enforce:** [Pending] committed `MAX_BATCH_OPS = 500` constant + property test committing 501 ops asserting the drainer splits.
**Source:** firebase.google.com/docs/firestore/quotas

**FB-6 — Mutable snapshot docs and tombstone fields (`deletedAt`, `purgedAt`) are written with `set(..., SetOptions(merge: true))`, never `update()`.**
**Why:** `update()` throws `not-found` when the doc doesn't exist yet (fresh device, first sync), silently failing tombstone/snapshot propagation per the [delete policy](delete-policy.md); `set(merge:true)` creates-if-missing.
**Enforce:** [Pending] audit grep: `.update(` under `core/sync/` returns zero; emulator test writing a tombstone to a non-existent path.
**Source:** firebase.google.com/docs/firestore/manage-data/add-data

**FB-7 — Every `.snapshots()` listener is bounded (`limit()`/cursor) and detached on app background; never an unfiltered listener on an unbounded event collection. Paginate with `startAfter(cursor)` over an explicit `orderBy` — never `offset()`.**
**Why:** a listener bills the full matching set on attach and every change thereafter, forever; `offset(n)` reads and bills the n skipped docs server-side. Costs scale with history size instead of delta size.
**Enforce:** [Pending] audit grep pairing `.snapshots(` with `.limit(` and forbidding `.offset(`; integration test asserting `ListenerSupervisor` detaches on the lifecycle background signal.
**Source:** firebase.google.com/docs/firestore/pricing, /query-data/query-cursors

**FB-8 — Answer counts and rollups from local Drift. Firestore aggregations (`count()`/`sum()`) and any cross-user reads are reserved for the tutor path, bounded by page size; never fan out N per-doc `get()`s where one bounded query suffices.**
**Why:** local counts are free and offline-capable; the tutor feature is the only place the app reads data it doesn't hold locally, so it's the only place server reads earn their cost.
**Enforce:** [Pending] grep confining `AggregateQuery`/cross-user `get()` to the tutoring module.
**Source:** firebase.google.com/docs/firestore/understand-reads-writes-scale

**FB-9 — Any new Firestore `where`/`orderBy` ships its composite index in `firestore.indexes.json` in the same change. Recursive deletion of a profile stays server-side (Cloud Function); clients never deep-delete subcollections.**
**Why:** a missing composite index fails at runtime with `FAILED_PRECONDITION` in exactly the environments you didn't test; a client-side recursive delete that dies mid-loop orphans privacy-sensitive child data.
**Enforce:** [Pending] CI diff of deployed vs committed indexes; rules test asserting client `delete` on profile docs is denied.
**Source:** firebase.google.com/docs/firestore/query-data/indexing, /manage-data/delete-data

---

## Firestore Security Rules

The sync engine writes ordinary collections as the owner, so for those paths `firestore.rules` is the **only** server-side gate. Keep rule validation minimal and fixture-driven (this repo has self-inflicted `permission-denied` outages by over-tightening rules against schema drift — the PHASE-D zero-denial oracle in the rules suite exists to prevent that); never encode business logic in rules. Within that budget:

**SR-1 — Append-only collections (`completions`, `streak_events`, `learning_ledger`, `points_ledger`) deny value mutation on update: allow only idempotent identical replay (`request.resource.data == resource.data`).**
**Why:** previously an owner token could silently rewrite a past completion's points or timestamp — the document ID was the only thing making these "append-only," so a child's study record was tamperable.
**Enforce:** [Enforced] `firestore.rules` gates `update` on each of the 4 collections with `request.resource.data == resource.data` (split from `create`, which alone carries field validation); deny-tests in `functions/test/firestore_rules.test.mjs` (`make test-rules`) — changed-value update `assertFails`, identical replay `assertSucceeds` — for all 4 collections (AUD-docs-01).
**Source:** firebase.google.com/docs/rules/data-validation

**SR-2 — Validate value types and cap string sizes in rules (`is timestamp`, `is number`, `s.size() <= N`), not just key sets via `hasOnly()`.**
**Why:** `hasOnly()` gates keys, never values — a compromised client can store a several-hundred-KB string, driving docs toward the 1 MiB ceiling on children's data.
**Enforce:** [Pending] `assertFails` tests for oversized and wrong-typed fields, guarded by the zero-denial oracle for canonical fixtures.
**Source:** firebase.google.com/docs/rules/data-validation

**SR-3 — Every event create requires a server-bounded timestamp: present, `is timestamp`, and `<= request.time`.**
**Why:** an offline device with a skewed clock (or a malicious client) can otherwise plant events at arbitrary times, corrupting streaks and the points economy; `request.time` is the only trustworthy clock.
**Enforce:** [Pending] per-collection deny-tests for missing/wrong-typed/future timestamps.
**Source:** firebase.google.com/docs/firestore/security/rules-conditions

**SR-4 — Cap `list` queries on per-profile event collections: `allow list: if <cond> && request.query.limit <= 500`; single-doc reads stay on `allow get`.**
**Why:** without the cap, one unbounded `list` exfiltrates (and bills) a child's entire history; the app already paginates at 500, so the cap costs nothing.
**Enforce:** [Enforced] `firestore.rules` splits `read` into `get` (unrestricted) and `list` (`request.query.limit <= 500`) on `completions`, `streak_events`, `learning_ledger`, `points_ledger`; deny-tests in `functions/test/firestore_rules.test.mjs` (`make test-rules`) assert `limit(500)` succeeds and `limit(501)`/unbounded fails, for all 4 collections (AUD-firebase-09).
**Source:** firebase.google.com/docs/firestore/security/rules-query

**SR-5 — Tutor cross-user access checks state and expiry in the rule itself (`state == 'active' && expires_at > request.time` via `get()`), with ≤ 2 document-access calls per rule and same-path reads deduped.**
**Why:** trusting the mere existence of the CF-maintained access doc means a missed revoke leaves a tutor with indefinite read access to a child's records; and `get()`/`exists()` are billed reads capped at 10 per request — duplicates multiply cost and risk denial at scale.
**Enforce:** [Pending] rules tests seeding expired vs active grants; grep on `firestore.rules` for the access-call budget.
**Source:** firebase.google.com/docs/firestore/security/rules-conditions

---

## Privacy & Child Data

This is a children's app (COPPA / GDPR-K / Play Families posture). These rules are load-bearing for store presence, not style.

**PV-1 — Analytics event parameters never include content identifiers or per-child identifiers: no `sefaria_ref`, no `profile_id`, no names. Params are coarse, low-cardinality categories (`track_type`, `curriculum_id`).**
**Why:** "which religious text a specific child studied" is sensitive personal information about a child; exporting it to Google Analytics is what Play Families / COPPA disclosure rules restrict. **Live violation:** `analytics_service.dart`'s 3 Story 27.14 convenience methods still send `sefaria_ref`/`profile_id` (see [Compliance Gaps](#current-compliance-gaps-2026-07-02)). AUD-core-analytics-01 (2026-07) closed the larger gap: 7 call sites reached via the uncatalogued `.logEvent()` bypass (PV-5) that combined `entity_key`/`profile_id`/`target`/raw exception text with analytics events — `entity_key` alone combined a per-child id with the exact content studied in one string.
**Enforce:** [Pending] audit grep over `core/analytics/` banning the identifiers in `logEvent`/param maps and Crashlytics `setCustomKey`/`.log(`. PV-5's catalog checker (`make audit` check 26/26) is a partial backstop — it forces every event through the reviewed `AnalyticsEvent` catalog, but doesn't itself inspect parameter contents.
**Source:** support.google.com/googleplay/android-developer/answer/9893335

**PV-2 — `setUserIdentifier`/`setUserId` receive only an opaque local id or hash — never a display name, email, or phone. Keep the Crashlytics arg type-locked to `int?`.**
**Why:** Google's terms forbid identifiers a third party could resolve to a person; leaking a child's name to crash tooling is a reportable violation.
**Enforce:** [Pending] audit grep on `setUserIdentifier(`/`setUserId(` arguments.
**Source:** firebase.google.com/docs/analytics/userid

**PV-3 — Crashlytics and Analytics collection are consent-gated and off by default; bootstrap must read a consent provider, never call `set*CollectionEnabled(true)` unconditionally.**
**Why:** GDPR-K requires meaningful consent before processing a child's data; consent for crash reporting cannot be assumed. **Live violation:** `firebase_bootstrap.dart` enables Crashlytics unconditionally.
**Enforce:** [Pending] audit grep banning the unconditional literal; bootstrap test asserting collection stays off until the consent flag flips.
**Source:** firebase.google.com/docs/analytics/configure-data-collection

**PV-4 — No ads SDK in `pubspec.yaml`, and ad-personalization signals disabled by default in the Android manifest / iOS plist.**
**Why:** Play Families forbids interest-based advertising to children; a bundled ad SDK can pull the app from the store.
**Enforce:** [Pending] CI config check for the manifest flag; audit grep on `pubspec.yaml` for ad SDKs.
**Source:** firebase.google.com/docs/analytics/configure-data-collection

**PV-5 — Every Analytics event routes through an `AnalyticsEvent` constant matching `^[a-z][a-z0-9_]{0,39}$` (no reserved `firebase_`/`google_`/`ga_` prefixes); no inline event-name literals at call sites.**
**Why:** ad-hoc names risk truncation and reserved-prefix rejection, and a single registry keeps every event auditable for PII in one place. AUD-core-analytics-01 found ~15 `.logEvent()` call sites bypassing the catalog entirely by passing `LogEvents.*` constants (a *separate* catalog scoped to `AppLogger` structured logs) straight through to real Firebase Analytics — several combined with per-child/content identifiers with zero PV-1 review.
**Enforce:** [Enforced] `dart run tool/check_analytics_catalog.dart` (wired into `make audit` check 26/26) fails with `file:line` on any `.logEvent()` call site in `lib/` whose event-name argument is not an `AnalyticsEvent.*` member.
**Source:** firebase.google.com/docs/analytics/flutter/events

**PV-6 — App Check: debug providers and emulator wiring appear only in the `kDebugMode`-guarded bootstrap; activation is non-fatal (a failed attestation never blocks local-first startup); debug tokens are injected via `FIREBASE_APPCHECK_DEBUG_TOKEN` from secrets and never committed; enforcement flips only after CI/device tokens are registered and metrics reviewed, recorded in `docs/appcheck-enforcement.md`.**
**Why:** shipping a debug provider disables real attestation on children's data; a hard-fail on `activate()` locks children out over a transient Play-Integrity failure; and the known wipe-regenerates-token incident means premature enforcement re-triggers the 403 outage for everyone.
**Enforce:** [Enforced] bootstrap is `kDebugMode`-gated and non-fatal today — lock in with: [Pending] audit greps (App Check symbols confined to bootstrap; UUID-shaped token pattern returns zero tracked lines), a secret-scanning CI step, and the committed enforcement-status doc.
**Source:** firebase.google.com/docs/app-check/flutter/debug-provider, /monitor-metrics

---

## Auth & Offline Accounts

The offline account model (credential-less local account, converted on reconnect) makes these non-negotiable:

**AU-1 — Convert an offline account by calling `currentUser.linkWithCredential(...)`; never `signInWithCredential`/`createUser*` while `currentUser.isAnonymous`.**
**Why:** linking preserves the uid so all data written under the anonymous uid carries over; a fresh sign-in mints a new uid and orphans every offline learner profile.
**Enforce:** [Pending] grep in the auth module; auth-emulator test: anonymous → write → link → uid unchanged, data intact.
**Source:** firebase.google.com/docs/auth/flutter/anonymous-auth

**AU-2 — Handle `credential-already-in-use` and `account-exists-with-different-credential` on link with an explicit merge flow that migrates offline profiles into the existing account. Never drop the offline data.**
**Why:** linking fails when the Google account already backs a Firebase user; without a merge, the child's offline study history is silently lost.
**Enforce:** [Pending] grep that the link error handler matches both codes; emulator merge test asserting row counts preserved.
**Source:** firebase.google.com/docs/auth — account-linking

**AU-3 — Never `signOut()` an anonymous (unlinked) user that still has unsynced outbox entries; block or force a link prompt first.**
**Why:** an anonymous session cannot be signed back into — sign-out orphans the data permanently (and Identity Platform auto-deletes anonymous accounts after 30 days).
**Enforce:** [Pending] grep guarding `signOut` call sites; unit test asserting the block.
**Source:** firebase.google.com/docs/auth — anonymous-auth

**AU-4 — Gate startup/session routing on `authStateChanges()`/`idTokenChanges()` streams, never a bare `currentUser` read; cancel subscriptions on dispose; no `setPersistence` in mobile code.**
**Why:** `currentUser` can be null before auth finishes initializing (startup race); `setPersistence` is a no-op on mobile that misleads reviewers.
**Enforce:** [Pending] grep on the auth gate and on `setPersistence` under `lib/`.
**Source:** firebase.google.com/docs/auth/flutter/start

**AU-5 — On `permission-denied`/`unauthenticated` from a synced write, force-refresh once with `getIdToken(true)` before the single retry. Never persist an ID token in Drift/SharedPreferences.**
**Why:** ID tokens last one hour; a cached token guarantees replaying an expired credential, and clock skew shifts `request.time` checks.
**Enforce:** [Pending] grep on the push-pipeline error handler and on token writes to storage.
**Source:** firebase.google.com/docs/auth/admin/verify-id-tokens

---

## Storage

> **Judgment call first:** `avatar_url` exists but no upload code is built. For a COPPA/GDPR-K app, a child's uploaded photo is sensitive image PII. **Default to a bundled preset-avatar picker** — it eliminates the entire Storage-rules / moderation / image-PII surface. Adopt the rules below only if photo upload becomes a hard product requirement.

**ST-1 — Storage is governed by a committed `storage.rules` wired into `firebase.json` — never console-only rules.** **Live gap:** no `storage.rules` exists while Storage already serves `content/v1/...`.
**Enforce:** [Pending] CI gate failing if the file or the `firebase.json` block is absent.
**Source:** firebase.google.com/docs/storage/security/get-started

**ST-2 — User-upload paths are owner-scoped over a global default-deny (`users/{uid}/…`, `request.auth.uid == uid`), capped by content-type (`image/*`) and size, with deterministic paths built from `uid`/`profileId` (never raw user strings), resumable `putFile`, and explicit `SettableMetadata(contentType:)`.**
**Why:** without owner-scoping any authenticated user can read another child's avatar; without type/size caps a compromised client hosts arbitrary files; without an explicit content-type the type rule is unenforceable.
**Enforce:** [Pending] `storage_rules.test.mjs` under the Storage emulator (owner succeeds / non-owner, oversized, non-image fail).
**Source:** firebase.google.com/docs/storage/security

---

## Performance

**PF-1 — `const` leaf widgets by default; narrow provider reads with `ref.watch(p.select(...))` so a widget rebuilds only on the fields it uses; hoist animation-independent subtrees into `child:` params.**
**Why:** `const` short-circuits rebuilds — the single biggest rebuild lever; whole-provider watches on hot screens cause rebuild storms.
**Enforce:** [Enforced] `prefer_const_constructors`, `prefer_const_declarations` (enabled). [Pending] enable the two remaining const lints (see [Lint Baseline](#lint-baseline)); review-checklist for `.select` on list/detail watches.
**Source:** docs.flutter.dev/perf/best-practices

**PF-2 — Any collection that can exceed the viewport uses a lazy builder (`ListView.builder`/slivers); heavy CPU work (bulk JSON parse, chart aggregation) runs off the main isolate.**
**Why:** concrete-children lists build every row up front; any main-isolate computation past the frame budget freezes the UI — the docs name local-DB reads and large parses as canonical isolate cases.
**Enforce:** [Enforced] `no_eager_list_in_non_lazy_scroll_container` custom lint (AUD-tutoring-08) — flags a `for`/`.map()` widget expansion fed into a non-lazy `ListView(children:)` or a scrollable `Column` under `lib/features/**`, exempting provably-bounded sources (`SomeEnum.values`, `.take(n)`, literal lists). [Pending] review item for >16 ms computations (the off-main-isolate half of this rule).
**Source:** docs.flutter.dev/perf/isolates

**PF-3 — `build()` stays free of I/O, awaits, and allocation-heavy loops.**
**Why:** `build()` runs on every rebuild; expensive work there janks every frame.
**Enforce:** [Pending] custom_lint idea: no `await`/DB call originating in a `build(` body.
**Source:** docs.flutter.dev/perf/best-practices

**PF-4 — Images decode at display size (`cacheWidth`/`cacheHeight`) with resolution-aware asset variants.**
**Why:** full-resolution decodes blow up `ImageCache` memory on profile/avatar grids.
**Enforce:** [Pending] audit grep for `Image.asset(`/`Image.network(` lacking cache sizing.
**Source:** docs.flutter.dev/perf/best-practices

---

## Accessibility & i18n

**AX-1 — Horizontal spacing and alignment use `EdgeInsetsDirectional` / `AlignmentDirectional` (`start`/`end`); never `EdgeInsets(left:/right:)` or `Alignment.centerLeft/Right`.**
**Why:** directional geometry flips automatically under `TextDirection.rtl`; hardcoded left/right renders on the wrong side in Hebrew.
**Enforce:** [Enforced] `no_hardcoded_text_direction` custom lint + **root** audit check 10. ⚠️ This check exists only in the root Makefile's audit, not the inner 23 — see [Enforcement](#enforcement--make-audit-and-ci).
**Source:** api.flutter.dev — EdgeInsetsDirectional

**AX-2 — No hardcoded user-facing strings: every displayed string, date, number, and plural comes from `AppLocalizations`/ARB (ICU plurals, not hand-built), with `app_en.arb` and `app_he.arb` key-for-key in sync.**
**Why:** a literal in `Text()` ships English into the Hebrew build — the single most recurring defect class in this app's audit history (IL-9 et al.); hand-built plurals produce wrong Hebrew forms.
**Enforce:** [Enforced] `make arb-parity` (EN/HE key parity) + `no_hardcoded_domain_term` custom lint for domain terms. [Pending] custom_lint flagging string literals passed to `Text(`/`SnackBar(content:`/`Tooltip(message:`.
**Source:** docs.flutter.dev — internationalization

**AX-3 — Icon-only buttons, meaningful images, and charts carry `semanticLabel`/`Semantics(label:)` (decorative visuals wrapped in `ExcludeSemantics`); directional glyphs (arrows/chevrons) set `matchTextDirection: true` or use auto-mirroring Material icons.**
**Why:** TalkBack/VoiceOver announce nothing for unlabeled icon controls, and a non-mirrored forward arrow points backward in Hebrew (the IL-7 breadcrumb-chevron defect class).
**Enforce:** [Pending] audit grep for `IconButton(` lacking `tooltip`/`semanticLabel`; review-checklist for directional icons.
**Source:** api.flutter.dev — Semantics

**AX-4 — Text containers size from content (no fixed `height:` on text wrappers); use `TextScaler` (never the deprecated `textScaleFactor`); interactive targets meet 48×48 dp and 4.5:1 contrast.**
**Why:** fixed heights clip enlarged Hebrew/English glyphs at accessibility text sizes; sub-48 dp targets fail store accessibility guidelines.
**Enforce:** [Pending] widget test pumping key screens at `TextScaler.linear(2.0)` asserting no overflow, plus `meetsGuideline(androidTapTargetGuideline)`/`textContrastGuideline`.
**Source:** docs.flutter.dev — accessibility

---

## Testing Standards

**TQ-1 — Keep the suite pyramid-shaped: many unit tests, fewer widget tests, a handful of `integration_test` flows. Before writing a widget/integration test, ask whether a unit test proves the same thing.**
**Why:** Flutter's own tradeoff table rates integration tests highest-maintenance and slowest; inverting the pyramid makes a 780-file suite slow and flaky with no added confidence.
**Enforce:** review-checklist.
**Source:** docs.flutter.dev/testing/overview

**TQ-2 — Provider tests create a fresh `ProviderContainer.test()` per test (or a helper with `addTearDown(container.dispose)`), inject collaborators via `overrides`, and never share a container between tests.**
**Why:** Riverpod's docs state in capitals "DO NOT share ProviderContainers between tests" — leaked provider state produces order-dependent flakes that pass locally and fail in CI. (78 test files already use containers; standardize on `.test()`.)
**Enforce:** [Pending] audit grep: `ProviderContainer(` in `test/` must be `.test(` or paired with `addTearDown(`.
**Source:** riverpod.dev/docs/how_to/testing

**TQ-3 — Widget tests pump through a shared `pumpApp` helper (ProviderScope overrides + localization delegates), and key screens include a `Locale('he')` (RTL) variant.**
**Why:** without delegates the widget throws or renders untranslated; RTL-only layout and overflow bugs — which this app ships fixes for every audit wave — are invisible to LTR-only tests.
**Enforce:** [Pending] `test/helpers/pump_app.dart` as the reviewed convention; CI golden/widget test of a key screen under Hebrew.
**Source:** docs.flutter.dev/app-architecture/case-study/testing

**TQ-4 — Prefer hand-written fakes (`class FakeX implements X`) for stateful collaborators; reserve mocktail for interaction verification; no new mockito.**
**Why:** mock-every-method setups re-break on every refactor and drift toward testing the mock; fakes reuse across viewmodel and widget tests.
**Enforce:** [Pending] audit grep rejecting new `import 'package:mockito` in `test/`.
**Source:** docs.flutter.dev/app-architecture/case-study/testing

**TQ-5 — Goldens are deterministic (fonts loaded in `flutter_test_config.dart`; pinned size/theme/locale; fixed clock; constant data) and reserved for genuinely visual widgets — not text-heavy screens.**
**Why:** platform font differences make cross-machine goldens randomly red, and golden churn is this repo's documented stale-test tax.
**Enforce:** [Pending] audit grep for `DateTime.now(`/`Random(` in files calling `matchesGoldenFile`; goldens run on one pinned CI platform.
**Source:** verygood.ventures — golden tests

**TQ-6 — Tests are hermetic: no network, no wall-clock (`clockProvider`/fixed `DateTimeFactory` only), no unseeded randomness, no shared mutable state; CI runs with randomized test ordering.**
**Why:** order- and time-dependent tests fail nondeterministically under parallel runs — and agents respond to flakes by weakening or disabling the test.
**Enforce:** [Enforced] inner check 6 keeps `DateTime.now()` out of `lib/`. [Pending] extend to `test/`; grep for real HTTP clients in `test/`; add `--test-randomize-ordering-seed=random` to CI.
**Source:** martinfowler.com/articles/nonDeterminism.html

**TQ-7 — Never weaken or delete a test to make a suite pass. Removing an assertion requires an explicit `// weaken-ok: <reason>` marker in the diff; deleting a test file requires the reason in the commit message.**
**Why:** the canonical AI-agent failure mode — "fixing" red tests by loosening assertions satisfies the gate while destroying the contract. This repo's stale-test churn history makes it a live risk, not a hypothetical.
**Enforce:** [Pending] audit ratchet: per-file `expect(` count must not decrease without the marker; human review on `test/**` deletions.
**Source:** anthropic.com/engineering — long-running agents; thoughtworks.com Radar v34

**TQ-8 — Every bug fix lands with a regression test that fails without the fix (red-first), and every audit finding states its repro (observed vs expected).**
**Why:** without a repro, fixes address symptoms; a red-first test proves the bug existed and the fix bites. This codifies the existing device-audit → adversarial-verify → fix loop.
**Enforce:** review-checklist: fix PRs show the failing-then-passing test.
**Source:** code.claude.com/docs — best practices

**TQ-9 — The Firestore rules suite is part of the local and CI gates: `test-rules` joins `make ci`'s prerequisites; the CI rules job hard-fails if the suite file is missing (no soft-skip); tests run against a `demo-*` project with seeding only via `withSecurityRulesDisabled`; and the emulator's `ruleCoverage` report fails the job on never-evaluated rule expressions.**
**Why:** today `make ci` doesn't run the rules suite and the CI job soft-skips itself if the file moves — a rules regression can reach `dev` unflagged. The `demo-` prefix makes the emulator physically unable to touch production data.
**Enforce:** [Pending] Makefile + `ci.yml` edits (see [Compliance Gaps](#current-compliance-gaps-2026-07-02)).
**Source:** firebase.google.com/docs/firestore/security/test-rules-emulator

---

## AI-Agent Workflow Standards

**AG-1 — All build/test/codegen/audit invocations route through `make` targets (or committed `tool/` scripts); CI and docs never carry ad-hoc command variants.**
**Why:** the single entry point is the only thing agent, CI, and human all share; bespoke variants make "it passed for me" unreproducible.
**Enforce:** [Pending] audit grep over `ci.yml`/docs for raw `flutter`/`dart` invocations that bypass an existing target.
**Source:** code.claude.com/docs — best practices

**AG-2 — CLAUDE.md files stay small (root well under 150 lines), list the exact commands that work, and contain no rule the analyzer/formatter can express. Treat them like code: human-reviewed, pruned each retro, never wholesale auto-generated.**
**Why:** a bloated instruction file blows the model's reliable-adherence budget and it silently ignores half; stale instructions cause exactly the cross-wave drift this doc fights. (Current sizes: root 18, app 87 lines — keep it that way.)
**Enforce:** [Pending] audit line-count cap on `CLAUDE.md` files; doc-lint asserting referenced make targets exist.
**Source:** humanlayer.dev — writing a good CLAUDE.md

**AG-3 — Hand-written Dart files stay under 400 lines (generated files exempt).**
**Why:** oversized files exceed per-file agent read budgets (content past the window is invisible), become dumping grounds, and drive re-implementation elsewhere. 400 is a chosen ratchet point, not a sourced constant — the enforcement matters more than the number.
**Enforce:** [Pending] audit check: `find lib test -name '*.dart' ! -name '*.g.dart' ! -name '*.freezed.dart' | xargs wc -l | awk '$1>400'` (introduce as warn-only, ratchet down existing violations, then hard-fail).
**Source:** practitioner consensus (see Sources)

**AG-4 — Public top-level symbol names are unique across `lib/` — no class/function name reused in two features.**
**Why:** agents locate code by grep; duplicate names send them to the wrong definition and breed divergent parallel copies — this repo's known accretion failure.
**Enforce:** [Pending] audit script diffing duplicate exported top-level identifiers.
**Source:** factory.ai — linters direct agents

**AG-5 — `test/` mirrors `lib/` 1:1 (`lib/a/b/foo.dart` ↔ `test/a/b/foo_test.dart`, story-acceptance suites exempt); a new source file's test goes at the mirrored path, nowhere else.**
**Why:** predictable structure lets agents glob straight to the right test and know where a new one belongs; scattered tests cause missing or duplicated coverage.
**Enforce:** `dart run tool/check_test_mirroring.dart` (learning_tracker/), wired into `make audit` (check 27/27). It is a RATCHET, not a full-repo hard-fail: `tool/ag5_unmirrored_baseline.txt` tracks the pre-existing backlog, and the gate fails only when a NEW unmirrored file appears outside that backlog — burn the backlog down incrementally, finding by finding (AUD-app-05 burned down `lib/core/sync/merge/` and `lib/core/sync/codec/` to zero as the first tranche).
**Source:** anthropic.com/engineering — context engineering

**AG-6 — Every `TODO`/`FIXME` carries a Linear id (`DNI-####`); no commented-out code blocks.**
**Why:** agents park half-finished work as untracked TODOs and comment out superseded code instead of deleting it — permanent cross-wave noise. (Inner check 10 bans only three specific phrases today; this generalizes it.)
**Enforce:** [Pending] audit grep: `TODO`/`FIXME` without `DNI-` fails; grep for commented-out code blocks.
**Source:** thoughtworks.com Radar v34

**AG-7 — Never hand-edit generated files (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, generated l10n); change the source and regenerate. CI regenerates (`build_runner`, `gen-l10n`) and fails on a non-empty `git diff`.**
**Why:** hand edits are silently overwritten on the next codegen run; stale generated code means the next wave builds on types that don't match their sources.
**Enforce:** [Enforced] CI already regenerates before analyze. [Pending] add the `git diff --exit-code` freshness gate.
**Source:** practitioner consensus (regenerate-and-diff pattern)

**AG-8 — Change types bind to docs: a schema/migration diff updates [data-models](data-models.md); a sync-behavior diff updates [sync-conflict-resolution](sync-conflict-resolution.md); a collection-shape diff updates [firestore-collection-layout](firestore-collection-layout.md); a new invariant updates this file (with its checker — Rule 0). Doc updates ship in the same PR. In docs, prefer pointers (`file:line`, symbol names) over pasted code.**
**Why:** agents trust docs; a doc that lies is worse than no doc. Pasted snippets drift the moment the code changes.
**Enforce:** [Pending] audit rule pairing diff paths with doc paths; review-checklist.
**Source:** anthropic.com/engineering — context engineering

**AG-9 — Non-trivial agent changes get (a) verification evidence in the PR/commit — the command run and its output, not an assertion of success — and (b) an adversarial review by a fresh-context reviewer that sees only the diff + spec, scoped to correctness and stated requirements (style belongs to the linter).**
**Why:** agents declare "done" when it looks done, and a model reviewing its own reasoning in-session misses what a fresh context catches. Scoping the reviewer prevents the over-engineering spiral of chasing speculative findings.
**Enforce:** PR/commit template with a Verification section; the existing audit-wave adversarial-verify stage, kept mandatory for confirmed findings.
**Source:** code.claude.com/docs — best practices

**AG-10 — One task = one worktree = one branch, named `<wave>/<DNI-####>-<slug>`; agent branches integrate onto `dev` at each wave boundary (no long divergence); merged branches and stale worktrees are pruned at wave end.**
**Why:** shared checkouts let parallel agents clobber each other; long-diverged waves are where duplicated logic and divergent idioms breed; orphaned worktrees confuse the next agent about which copy is canonical.
**Enforce:** [Pending] `make worktree-prune` target; branch-name check in the pre-push hook.
**Source:** code.claude.com/docs — worktrees

**AG-11 — Guardrail infrastructure changes get explicit human review, and gates are never bypassed: no `--no-verify`, no narrowed audit globs, no renamed/removed CI checks, no softened lints without a stated reason in the PR.**
**Why:** the subtle agent bypass isn't skipping the hook — it's narrowing a grep's scope or renaming a required check so the gate still "passes" while gutted. Guardrail files: `Makefile`s, `analysis_options.yaml`, `.github/workflows/`, `hooks/`, `packages/custom_lints/`, `tool/`, all `CLAUDE.md`, this document.
**Enforce:** [Pending] deny-pattern on bypass flags in the agent harness/hook; PR-template alert when guardrail paths change.
**Source:** stevekinney.com — guardrail bypass

---

## File Naming Conventions

All Dart files use **snake_case**. The file suffix encodes its architectural role:

| Suffix | Role | Example |
|--------|------|---------|
| `_screen.dart` | Routable screen widget (annotated `@RoutePage()`) | `dashboard_screen.dart` |
| `_widget.dart` | Reusable non-routable widget | `streak_badge_widget.dart` |
| `_provider.dart` | Riverpod provider definitions | `completion_providers.dart` |
| `_repository.dart` | Repository interface (domain layer) | `completion_repository.dart` |
| `_repository_impl.dart` | Repository implementation (data layer) | `completion_repository_impl.dart` |
| `_dao.dart` | Drift DAO | `completion_dao.dart` |
| `_service.dart` | Domain or application service | `streak_service.dart` |
| `_notifier.dart` | Riverpod `Notifier` or `AsyncNotifier` subclass | `profile_notifier.dart` |
| `_model.dart` | Freezed value object / domain entity | `streak_snapshot_model.dart` |
| `_dto.dart` | Data Transfer Object (Firestore / JSON boundary) | `completion_dto.dart` |
| `_mapper.dart` | Converts between layers (DTO ↔ domain) | `completion_mapper.dart` |
| `_test.dart` | Test file | `completion_dao_test.dart` |
| `.g.dart` | Generated file — never edit by hand | `completion_providers.g.dart` |
| `.freezed.dart` | Freezed-generated file — never edit by hand | `streak_snapshot.freezed.dart` |

Additional conventions:

- **No abbreviations** in file names. `authentication_repository.dart`, not `auth_repo.dart`.
- **No `_utils.dart` god-files.** Each utility gets a focused name: `hebrew_calendar_utils.dart`, not `utils.dart`.
- **Acceptance test files** follow the pattern `epic_NN_<slug>_test.dart`. Story-level tests inside the file are tagged with `tags: ['story_NN_M']`.
- Domain/state models are immutable `@freezed` classes (generated `==`/`copyWith`); never hand-write `==`/`hashCode` for data classes — hand-rolled equality drifts from the fields and silently breaks rebuild-skipping. Records are for small private multi-value returns only; promote to a named class the moment the tuple crosses a public API.

---

## File Placement Guide

```
lib/
  main.dart                          — App entry point; minimal (wires providers + router)
  app.dart                           — MaterialApp + theme + locale; calls core providers

  core/                              — Shared infrastructure; no feature business logic
    analytics/                       — Analytics events and repository
    constants/                       — App-wide constants (no logic)
    content/                         — Content index and curriculum content loading
    database/                        — Drift database definitions, DAOs, migrations
      daos/                          — One DAO per table group
      tables/                        — Drift Table classes
      user_database.dart             — User DB (schemaVersion managed here)
      content_database.dart          — Content DB
      device_registry_database.dart  — Device DB
    enums/                           — Shared enums (CurriculumId, etc.)
    exceptions/                      — Typed exception classes
    labels/                          — CurriculumLabelRenderer + domain term labels
    logging/                         — AppLogger, Crashlytics service (only Talker import)
    navigation/                      — AppRouter (auto_route)
    network/                         — Sefaria fetchers, HTTP utilities
    preferences/                     — SharedPreferences wrappers and keys
    providers/                       — Cross-cutting Riverpod providers (firebase_providers, etc.)
    services/                        — Cross-cutting application services (aggregators)
    streak/                          — Streak event log and reducer (pure domain logic)
    sync/                            — Firestore gateway interface + impl (only Firebase import)
    theme/                           — AppTheme, colour tokens
    time/                            — Clock abstraction (never use DateTime.now() directly)
    utils/                           — Focused utility files (hebrew_calendar_utils, etc.)
    widgets/                         — Shared UI widgets used by multiple features

  features/                          — One directory per product feature
    <feature_name>/
      data/                          — Repositories (impl), data sources, DTOs, mappers
      domain/                        — Entities, repository interfaces, use cases, services
      presentation/
        providers/                   — Riverpod providers for this feature
        screens/                     — Routable screen widgets
        widgets/                     — Feature-local widgets

test/
  story_acceptance/                  — One file per epic: epic_NN_<slug>_test.dart
  core/                              — Unit tests mirroring lib/core/ structure
  features/                          — Unit / widget tests for feature modules
  integration/                       — Cross-feature integration tests (in-memory DB)
  helpers/                           — TestDatabase, fixture builders
  fixtures/                          — Static JSON / Dart fixture data
  mocks/                             — Mocktail mock classes
```

### Where does a new file go?

| What you are adding | Where it lives |
|---------------------|----------------|
| New screen | `lib/features/<feature>/presentation/screens/<name>_screen.dart` |
| New widget shared across features | `lib/core/widgets/` |
| New widget used by one feature only | `lib/features/<feature>/presentation/widgets/` |
| New Riverpod provider | `lib/features/<feature>/presentation/providers/<name>_provider.dart` |
| New repository interface | `lib/features/<feature>/domain/repositories/<name>_repository.dart` |
| New repository implementation | `lib/features/<feature>/data/repositories/<name>_repository_impl.dart` |
| New Drift DAO | `lib/core/database/daos/<name>_dao.dart` |
| New Drift table | `lib/core/database/tables/<name>.dart` |
| New domain service (cross-feature) | `lib/core/services/<name>_service.dart` |
| New domain service (feature-local) | `lib/features/<feature>/domain/services/<name>_service.dart` |
| New enum used by multiple features | `lib/core/enums/<name>.dart` |
| New utility | `lib/core/utils/<focused_name>_utils.dart` |

Presentation code (`features/*/presentation/**`) must not import from `features/*/data/**` — data access flows through providers over domain interfaces (this is the vertical complement to Rules 1–2). **[Pending]** audit grep.

---

## profileId-in-PK Invariant

Every user-data table in the user database MUST include `profileId` as part of its composite primary key. This is the enforcement of multi-profile isolation at the data layer.

**Rule:** No user-facing Drift table may use a single-column autoincrement primary key without also specifying `profileId` as part of a composite key override.

**Correct pattern:**
```dart
class CompletionsTable extends Table {
  TextColumn get profileId => text().references(ProfilesTable, #id)();
  TextColumn get contentItemId => text()();
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId, contentItemId, completedAt};
}
```

**Wrong pattern (bare autoincrement — forbidden for user data):**
```dart
class CompletionsTable extends Table {
  IntColumn get id => integer().autoIncrement()();  // WRONG — no profileId
  ...
}
```

Content tables (read-only, shared across profiles) are exempt. The invariant applies to all tables in `user_database.dart`.

**Enforcement:** `make audit` flags any user-DB table without a `profileId` column.

---

## Lint Baseline

The analyzer baseline is a **deliberately hand-rolled explicit list** (83 rules in `analysis_options.yaml`) plus `strict-casts` / `strict-inference` / `strict-raw-types` — not a `flutter_lints`/`very_good_analysis` include. Keep it explicit: every enabled rule is a decision, not an inheritance.

Adopted additions (each closes a gap named by the rules above) — **[Pending]** until enabled:

| Lint | Closes |
|------|--------|
| `discarded_futures` | the un-awaited-future gap `unawaited_futures` alone leaves in sync/async fields |
| `avoid_catches_without_on_clauses` (project-wide) | EH-4 — scoped equivalent already enforced for core/sync via `make audit` check 27, see EH-4 above |
| `avoid_catching_errors` (project-wide) | EH-4 — scoped equivalent already enforced for core/sync via `make audit` check 27, see EH-4 above |
| `prefer_const_constructors_in_immutables` | PF-1 |
| `prefer_const_literals_to_create_immutables` | PF-1 |
| `non_exhaustive_switch_statement` → **error** severity | EH-6 |
| `riverpod_lint` (dev-dependency; runs under the existing custom_lint process) | SM-1, SM-2, SM-6 backstops |

Already enabled and load-bearing (do not remove): `unawaited_futures`, `use_build_context_synchronously`, `avoid_dynamic_calls`, `avoid_print`, `avoid_slow_async_io`, `cancel_subscriptions`, `close_sinks`, `empty_catches`, `exhaustive_cases`, `only_throw_errors`, `prefer_const_constructors`, `require_trailing_commas`.

---

## Enforcement — `make audit` and CI

> ⚠️ **Two Makefiles currently exist with divergent audit sets.** The **authoritative** target is `learning_tracker/Makefile`'s `audit` (27 checks, below). The repo-root `Makefile` carries an older 12-grep variant whose RTL check (`EdgeInsets.only(left:/right:)`) was never ported to the inner set. **Consolidation is required** (tracked in [Compliance Gaps](#current-compliance-gaps-2026-07-02)): union the check sets into one target, renumber sequentially, and have the other Makefile delegate.

Run before pushing:

```bash
cd learning_tracker && make audit   # 27 enforcement checks + packages/custom_lints unit tests
dart run custom_lint                # currently non-functional — see "custom_lint toolchain status" below; do not rely on its exit code
```

`make audit` (and `make ci`) depend on `lint-rules-test`, which runs `dart test` inside `packages/custom_lints/` — the unit-test suite that exercises each of the 10 custom lint rules' own matching/whitelist logic (independent of whether the `custom_lint` plugin itself can attach to the analyzer — see the warn-only note below). This is a hard gate: it never soft-skips (AUD-guardrails-17).

### The 27 enforcement checks (`learning_tracker/Makefile`)

Each check must return zero matching lines (except the two marked warn-only). The odd numbering (`1/15 … 27/27`) is accretion from fix waves — renumber on consolidation.

| # | What it checks |
|---|----------------|
| 1 | No `firebase_auth` imports outside `core/auth`, `features/auth` |
| 2 | No `FirebaseFirestore`/`FirebaseStorage` outside `core/sync`, `core/auth`, `core/providers` |
| 3 | No `FirebaseAuth.instance.signOut` outside `core/auth` |
| 4 | No raw `talker` import outside `core/logging` |
| 5 | No `debugPrint` / bare `print()` in production code |
| 6 | No `DateTime.now()` outside `core/time` |
| 7 | No `useHebrewTermsProvider` read outside `core/labels`, `core/preferences`, settings/onboarding screens |
| 8 | No `displayNameEn/He` outside `core/labels` (non-generated) |
| 9 | No empty catch blocks |
| 10 | No banned `XXX: temporary` marker; every `// TODO`/`// FIXME` comment carries a `DNI-####` Linear id (AG-6, AUD-repo-02) |
| 11 | No `.withDefault(const Constant(0))` in database tables |
| 12 | No `currentAccountId` hardcoded to 1 |
| 13 | No raw `HebrewTerms.` calls in `lib/features/` |
| 14 | No `features/` imports inside `lib/core/` — **warn-only** pending legacy cleanup (Rule 1) |
| 15 | No cross-feature deep imports (must use `Y.dart` barrel) — **warn-only** pending legacy cleanup (Rule 2) |
| 16 | No raw `profile.mode` string comparisons (use `ProfileMode` enum) |
| 17 | No raw `account.tier` string comparisons (use `AccountTier`/`UserTier` enum) |
| 18 | No direct `FirestoreGateway.push*` outside `lib/core/sync/` |
| 19 | No hardcoded Torah domain-term literals in presentation strings |
| 20 | No raw `curriculumId`/`storageKey` rendered in `Text()` |
| 21 | No nusach-specific domain-term ARB getter used directly in feature presentation |
| 22 | Every `lib/core/labels/` file touching `displayNameEn/He` must be variant-aware |
| 23 | No `custom_lint` analyzer plugin marker in `analysis_options.yaml` (AUD-guardrails-03 — breaks the `dart analyze --fatal-infos` hard gate; see "custom_lint toolchain status" below) |
| 24 | No duplicate public top-level type (`class`/`enum`/`mixin`) names across `lib/` (AG-4, AUD-repo-01) |
| 25 | Only one file named `coding-standards.md` exists outside `docs/_archive/` (AG-8, AUD-docs-04) |
| 26 | Every `.logEvent()` call site in `lib/` passes an `AnalyticsEvent.*` catalog member as the event name — `tool/check_analytics_catalog.dart` (PV-5, AUD-core-analytics-01) |
| 27 | Every `SeedManager(` construction site in `lib/` passes a `logger:` argument (EH-3, AUD-app-07) |

Root-Makefile-only check to port on consolidation: **No `EdgeInsets.only(left:|right:)`** (RTL violation — AX-1).

### CI matrix (`.github/workflows/ci.yml`)

| Step | Command | Status |
|------|---------|--------|
| format-check | `dart format --set-exit-if-changed .` | hard gate |
| analyze | codegen (`build_runner`, asset prep) then `dart analyze --fatal-infos` | hard gate |
| audit | `make audit` (includes `lint-rules-test` — `packages/custom_lints/` unit tests, AUD-guardrails-17) | ⚠️ job **soft-skips** if target considered absent — must hard-fail; `lint-rules-test` itself never soft-skips |
| custom_lint | `dart run custom_lint` | ⚠️ **non-functional** — the compile crash is fixed (AUD-guardrails-03), but the CLI cannot currently run at all in CI/local without also breaking the `analyze` hard gate; it silently reports "No issues found!" (0 projects discovered, not 0 violations) — see "custom_lint toolchain status" below |
| test + coverage | `make ci` (also includes `lint-rules-test`) then lcov floor | hard gate, line coverage ≥ 60% (generated files excluded), cannot drop on a PR |
| firestore-rules | emulator + `firestore_rules.test.mjs` | ⚠️ **soft-skips** if the suite file is missing — must hard-fail (TQ-9) |

Until the soft-skips are removed, **local `make audit` is the real gate** — run it. (`dart run custom_lint` is currently a no-op; do not treat its exit code as a signal — see below.)

#### custom_lint toolchain status (AUD-guardrails-03, partially resolved 2026-07-03 — CLI currently non-functional)

pub.dev's latest `custom_lint`/`custom_lint_core` (0.8.1) only support analyzer
`^8`, but this project pins analyzer `^9` (forced by `json_serializable` /
`riverpod_generator`) — running `dart run custom_lint` used to crash with exit
255 compiling `custom_lint_core` against analyzer 9 (`Element2` was removed).
Upstream (`invertase/dart_custom_lint`) merged analyzer-9 support as 0.8.2
("Handle analyzer 9.0", PR #374, 2025-12-30) but never published it to
pub.dev — the repo's README now says the project is "no longer under active
development" in favour of `package:analysis_server_plugin`. Until this repo
migrates off custom_lint (a rewrite of all 9 rules — tracked as a follow-up,
not done here), `learning_tracker/pubspec.yaml` and
`packages/custom_lints/pubspec.yaml` pin the unreleased 0.8.2 commit via
`dependency_overrides` (`git:` + `path:`, see the comments in both files for
the exact ref). **This part of the fix is real and stands**: `custom_lint_core`
now compiles cleanly against analyzer 9, confirmed via `dart test` in
`packages/custom_lints` (88/88 passing) and by manually enabling the plugin
marker in a scratch run and injecting a deliberate raw-`talker`-import
violation, which the tool correctly caught.

That manual scratch run, however, surfaced a second, blocking problem: making
`dart run custom_lint` actually discover this project requires
`analyzer: plugins: [custom_lint]` in `learning_tracker/analysis_options.yaml`
(confirmed in custom_lint's own source — `CustomLintWorkspace._isCustomLintEnabled`
gates workspace discovery on this exact marker, identically in both the
pub.dev 0.8.1 release and the git-pinned 0.8.2 commit; without it the CLI
finds zero projects and prints a **false** "No issues found!"). But enabling
that marker breaks the real CI hard gate: analysis_server's *legacy plugin
loader* (a separate code path from custom_lint's own CLI, used by `dart
analyze`/`flutter analyze` when `analyzer: plugins:` is set) re-resolves
`custom_lint` in its own isolated pub context under
`~/.dartServer/.plugin_manager/`, ignoring this project's
`dependency_overrides` entirely, and tries to fetch `custom_lint 0.8.2`
straight from pub.dev — which doesn't exist there (only 0.8.1 is published).
Version solving fails and `dart analyze --fatal-infos` (the actual CI gate,
`.github/workflows/ci.yml` `analyze` job, `make analyze`) exits non-zero
(verified: exit 4) **even on an otherwise zero-diagnostic tree** — a crash
message, not a real diagnostic. `flutter analyze` swallows this crash and
still exits 0, which is why it is not a reliable substitute for verifying
this gate.

Because of that conflict, `learning_tracker/analysis_options.yaml` keeps the
plugin marker **omitted** (see the comment above the `analyzer:` block there)
and `make audit` check 23/23 fails the build if it is ever re-added. The
consequence: `dart run custom_lint` cannot currently discover this project at
all and silently reports "No issues found!" — not because the codebase is
clean, but because the tool finds no workspace to scan. Do not read a green
`dart run custom_lint` as a passing signal; it is not currently a working
checker. During the scratch run with the marker manually (temporarily)
enabled, the tool reported **1,840 issues** across 8 of the 9 rules (only
`no_hardcoded_domain_term` was clean): `no_feature_cross_import` (1,193),
`no_color_literal_outside_theme` (474), `no_curriculum_display_name_bypass`
(114), `no_e_to_string_in_ui` (32), `no_raw_talker` (13), `no_raw_logevent`
(8), `no_firebase_outside_core` (5), `no_hardcoded_text_direction` (1) — real,
pre-existing debt the rules had never been able to see before, not a
regression from this fix, and it mirrors `make audit` checks #14–15, which
already tolerate the same cross-feature/core-import legacy violations as
warn-only. That count is a one-time observation, not a live/enforced number:
it cannot be reproduced via the normal CLI or CI path today, because doing so
requires the same marker that breaks `analyze`. Remediating the 1,840
violations is moot until the CLI can run without breaking the hard gate —
either a real analyzer-9-compatible pub.dev release of custom_lint, or
migrating off it entirely (both out of scope here; the latter is already
tracked above as a follow-up). CI's `custom_lint` step stays warn-only and is
not currently a meaningful check either way.

**AUD-tutoring-08 update (2026-07-10):** the same manual-marker scratch-run
technique was used to validate the new `no_eager_list_in_non_lazy_scroll_container`
rule (PF-2) against real `lib/` code, since the normal CLI path above cannot
be trusted. With the marker temporarily enabled, the rule correctly found
**zero** hits at AUD-tutoring-08's own evidence sites (all already fixed —
`ManageGrantsScreen`, Settings' `_PendingInvitesSection`,
`manage_tutors_screen.dart`) and **10** genuine pre-existing hits of the same
eager-list-into-non-lazy-scroll-container pattern elsewhere in the codebase,
outside this finding's declared scope: `account_picker_screen.dart`,
`parent_track_management_screen.dart`, `profile_switcher_sheet.dart`,
`curriculum_progress_screen.dart`, `grouped_daily_view.dart`,
`track_management_hub_screen.dart`, `curriculum_picker_step.dart` (×2),
`program_selection_step.dart`, and `track_management_body.dart`. These mirror
the `no_feature_cross_import` / `no_color_literal_outside_theme` etc. debt
above — real, pre-existing, not a regression from this rule's addition, and
not remediated here (out of scope for a single-finding checker delivery);
tracked as a follow-up once the toolchain itself is fixed and this rule can
run live in CI.

**AUD-onboarding-13 update (2026-07-11):** the same manual-marker scratch-run
technique was used to verify the `no_color_literal_outside_theme` fix for
this finding. The finding's own acceptance criterion reads "...reports zero
`no_color_literal_outside_theme` violations under
`lib/features/onboarding/presentation/widgets/`" — i.e. the whole directory
is the AC's scope, not merely the 3 files named in the finding's evidence
(`intro_mishna_page.dart`, `intro_page_indicator.dart`,
`intro_rewards_page.dart`). A first delivery attempt fixed only those 3
files and deferred the other 2 files in the same directory
(`glowing_cta_button.dart`, 1 hit; `intro_daily_plan_page.dart`, 12 hits) as
"out of scope"; that was incorrect — deferring part of a finding's own AC is
fake-done, not a scope call — and was bounced. All 5 files are now fixed:
every hand-typed `Color(0x...)` literal across the directory (32 total: the
original 19 plus these 13) references the "Onboarding intro carousel"
section of `AppColors`. With the marker temporarily enabled, the rule found
**zero** hits across all 5 files post-fix.

---

## Custom Lints Reference

Twelve+ custom lint rules live in `packages/custom_lints/` (landed) and run via `dart run custom_lint`:

| Rule | What it catches |
|------|-----------------|
| `no_feature_cross_import` | `features/X/` importing `features/Y/` internals; `core/` importing `features/` (Rules 1–2) |
| `no_firebase_outside_core` | Firebase SDK symbols outside `core/sync/`, auth modules (Rule 3) |
| `no_raw_talker` | `package:talker/talker.dart` outside `core/logging/` (Rule 4) |
| `no_curriculum_display_name_bypass` | `.displayNameEn`/`.displayNameHe` outside `core/labels/` (Rule 5) |
| `no_hardcoded_domain_term` | Torah domain-term literals bypassing `domainTermLabels` |
| `no_hardcoded_text_direction` | Hardcoded LTR geometry breaking RTL (AX-1) |
| `no_color_literal_outside_theme` | Color literals bypassing `core/theme/` tokens |
| `no_e_to_string_in_ui` | Raw exception `.toString()` surfaced in UI (EH-5) |
| `no_raw_logevent` | Analytics events bypassing the typed event layer (PV-5) |
| `no_hand_rolled_async_state_notifier` | `Notifier<T>` whose state is a hand-rolled sealed Idle/Loading/Error union — SM-5 AsyncNotifier-migration candidate, INFO severity (AUD-account-14) |
| `no_eager_list_in_non_lazy_scroll_container` | A `for`/`.map()` widget expansion fed into a non-lazy `ListView(children:)` or a scrollable `Column` under `lib/features/**` (PF-2, AUD-tutoring-08) |
| `no_unguarded_state_touch_after_await` | `state =`/`setState(...)` after an `await` in a Notifier/State method with no intervening `mounted`/`ref.mounted` guard (SM-4, AUD-onboarding-01) |
| `no_log_less_catch` | A `catch` under `lib/` with no `AppLogger` call and no `rethrow` — the log-less half of EH-3, including the comment-only shape `empty_catches` misses (AUD-onboarding-11) |
| `no_ref_after_await_without_mounted_check` | `ref.read`/`ref.watch`/`ref.invalidate`/`ref.refresh`/`ref.listen`/`state = ...` after an earlier `await` in the same async method/closure with no `ref.mounted` guard in between (SM-4, AUD-sync-04) |

(This table is not exhaustive of every registered rule — see `packages/custom_lints/lib/learning_tracker_lints.dart` for the authoritative list.)

Each rule's own matching/whitelist logic has a `package:test` unit-test file under `packages/custom_lints/test/`, run via `make lint-rules-test` (`cd learning_tracker && make lint-rules-test`, or `cd packages/custom_lints && dart test` directly). This is wired into `make audit` / `make ci` and runs on every PR — independent of whether the `custom_lint` plugin itself can attach to the analyzer (AUD-guardrails-17).

---

## Current Compliance Gaps (2026-07-02)

Live violations of the rules above, verified in the working tree on this date. Each needs a fix PR; none invalidate the rule.

| Gap | Violates | Detail |
|-----|----------|--------|
| Analytics sends `sefaria_ref` and `profile_id` as event params on the 3 Story 27.14 convenience methods (`logCompletionRecorded`, `logPinLockedOut`, `logParentModeEntered`) | PV-1 | `lib/core/analytics/analytics_service.dart:86,112,117` — narrower than it was: AUD-core-analytics-01 (2026-07) closed the larger uncatalogued-`.logEvent()` bypass (see PV-5 row below); these 3 catalog-native sites are the remaining known gap |
| Crashlytics enabled unconditionally at bootstrap | PV-3 | `lib/app/bootstrap/firebase_bootstrap.dart:45` |
| No committed `storage.rules` | ST-1 | Storage serves `content/v1/...` on console-only rules |
| `make ci` doesn't run `test-rules`; CI rules job soft-skips | TQ-9 | `learning_tracker/Makefile` `ci:` target; `ci.yml` |
| CI soft-skips `audit` | Rule 0 | `ci.yml` — local `make audit` is the real gate meanwhile |
| custom_lint compile crash is fixed (AUD-guardrails-03) but the CLI still can't run: it needs an analysis_options.yaml marker that breaks the `dart analyze --fatal-infos` hard gate, so it silently discovers 0 projects; ~1,840 pre-existing violations across 8/9 rules were observed in a one-time manual scratch run and are not currently re-checkable via CLI/CI | Rule 0 | see "custom_lint toolchain status" under Enforcement above |
| Two divergent Makefile audit sets; RTL grep only in root | AX-1, Rule 0 | consolidate into one authoritative target |
| ~121 legacy Riverpod provider usages | SM-1 | migration backlog; diff-scoped enforcement meanwhile |
| No `drift_schemas/` exports or generated migration tests (schemaVersion 32) | DB-4 | adopt `drift_dev schema dump` workflow |
| Audit checks 14–15 warn-only | Rules 1–2 | pre-existing violations pending cleanup wave |

---

## Sources

Load-bearing primary sources behind the 2026-07-02 revision (full per-rule citations in the research reports):

- **Flutter team** — App Architecture guide & recommendations, offline-first and Result design patterns, testing overview, performance best practices, accessibility & internationalization (docs.flutter.dev)
- **Dart team** — Effective Dart, class modifiers (sealed), patterns/records, linter-rules reference (dart.dev)
- **Riverpod** — v3 what's-new (`ref.mounted`, legacy demotion), do/don't, code generation, testing, `AsyncValue.guard` (riverpod.dev)
- **Drift** — transactions, writes/batching, migration exports & generated tests, isolates (drift.simonbinder.eu)
- **Firebase/Google Cloud** — Firestore best practices, quotas, pricing, query cursors/indexing, security-rules data validation & query conditions, rules emulator testing, App Check debug provider & enforcement, Auth anonymous/linking, Analytics data collection & Play Families policy, Storage security (firebase.google.com, cloud.google.com)
- **AI-agent engineering** — Anthropic engineering (Claude Code best practices, effective context engineering, long-running agents), HumanLayer (CLAUDE.md), Factory.ai (linters direct agents), Thoughtworks Tech Radar v34 (AI cognitive debt, mutation testing), Armin Ronacher (agentic coding), Steve Kinney (guardrail bypass), Martin Fowler (test non-determinism)
