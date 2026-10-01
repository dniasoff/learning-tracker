---
title: Review — Sub-tracks architecture spine (rubric + currency)
target: docs/planning/architecture/architecture-sub-tracks-2026-09-30/ARCHITECTURE-SPINE.md
reviewed: 2026-09-30
lenses: [good-spine rubric, currency]
inputs:
  - ARCHITECTURE-SPINE.md, .memlog.md (same folder)
  - docs/planning/architecture/architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md (parent)
  - docs/planning/prds/prd-sub-tracks-2026-09-30/prd.md, addendum.md
  - learning_tracker/ source (pubspec, lib/, functions/, firestore.rules, firestore.indexes.json, firebase.json, Makefile, .github/workflows)
  - pub.dev package API/changelogs; firebase.google.com rules/Admin SDK/FCM/Analytics docs (fetched 2026-09-30)
---

# Review — Sub-tracks spine: good-spine rubric + currency

## Verdict

**Not ready to bind epics.** The paradigm (one event log, one pure engine, one command layer) is sound, and AD-31–AD-48 hit most of the real divergence points. Four structural gaps would still let epics diverge:

1. The pre-existing `learning_ledger` / `completions` / streak / pace machinery is never retired, so there would be two stores of "learnt".
2. The field-naming convention contradicts the codebase.
3. The AD-38 `existsAfter` rule is bypassable, and the tutor path escapes rules entirely.
4. There is no operational envelope: environments, deploys, indexes, emulator tests, rollout, batch/query limits.

Three Stack pins are stale. Every finding below has a concrete fix, and none needs a redesign.

Severity scale:
- **Critical:** epics will diverge or lose data.
- **High:** a real divergence or enforcement hole.
- **Medium:** silent area or a stale/incorrect claim.
- **Low:** precision.

---

## Top findings

| # | Sev | Finding | Fix |
|---|---|---|---|
| 1 | Critical | Several existing stores and services are left undecided:<br>• `learning_ledger/{ulid}` is an existing append-only, ULID-keyed learning log. It has `source` (live/bulkInTrack/lifetimeOnly), `purged_at` and siyum-retraction logic, and it drives the lifetime, journey and items-learned providers (`lib/features/learning/domain/entities/learning_ledger_entry.dart`, ~188 refs).<br>• `completions` / `completion_orchestrator`, `streak_reducer`, `pace_calculator`, the `bulkBaseline` 2000-01-01 sentinel, and the tutor callables `tutorResetCompletion` / `tutorBulkPriorCompletions`.<br>The spine only says "completions receives no new writes". One epic will read the ledger and another the events. | Add an AD naming each superseded store, service and callable for the Mishnayos goal: stop writing it, switch readers to `LearnerState`, and delete or retire it. Map `bulkBaseline` to `dateState = beforeTracking`. State "no data migration: greenfield per parent AD-13", or specify the one-shot conversion. |
| 2 | High | AD-38's rule `existsAfter(change_log/{lastChangeId})` is satisfied by any **old** change-log id, so a config write can skip its log entry. Other gaps:<br>• The tutor path uses the Admin SDK, which bypasses rules (confirmed in the Firebase docs). Nothing enforces the co-write there, and existing callables such as `tutorUpsertGoal` / `tutorSetProfileProgram` don't do it.<br>• "Main-track settings" is not named as a document.<br>• The goal rules whitelist (`firestore.rules:571-596`) lacks `last_change_id`. | Rule:<br>`last_change_id is string && last_change_id != resource.data.last_change_id && !exists(p) && existsAfter(p) && getAfter(p).data.entity_id == docId`.<br>Also:<br>• Name the exact main-track docs.<br>• Mandate one functions helper (`writeWithChangeLog`) used by every tutor callable that touches these entities, with emulator tests (parent AD-29).<br>• Amend the goal/track rules and callables. |
| 3 | High | Naming contradiction. AD-31/33/38/44 name fields in camelCase (`learnedOn`, `dateState`, `recordedAt`, `lastChangeId`, `windowStart`, `ratePerWeek`, `endedAt`, `entityId`). Consistency Conventions and the codebase use snake_case (`sefaria_ref`, `goal_type`, `created_at`), and the rules whitelist field names with `hasOnly`. Rules, codecs and functions written by different epics will disagree. | Add a canonical Firestore schema table (collection → snake_case field → type → required/optional) for `learning_events`, `sub_tracks`, `change_log`, the goal/profile/account additions and the new `points_ledger` kind. Say ADs use Dart names and the table is authoritative for storage. |
| 4 | High | No operational envelope. Current state:<br>• One Firebase project (`torah-study-tracker`); no `.firebaserc`, flavors or staging.<br>• CI deploys hosting only; there is no deploy path for rules, functions or indexes.<br>• No composite index is named. Change-log history by actor, and any events query ordered or filtered server-side, need one; today's 12 indexes don't cover them.<br>• Parent AD-29 (emulator evidence) isn't inherited.<br>• No rollout order (rules and functions before client).<br>• Existing rules cap list queries at 500, but the engine needs every event.<br>• A batch holds at most 500 writes, but FR-3 "mark a seder / whole corpus before tracking" plus points entries can exceed it. | Add an operational AD covering:<br>• environments (at minimum an emulator plus a prod gate);<br>• `firebase deploy --only firestore:rules,firestore:indexes,functions` as a gated CI step, run before the app release;<br>• the exact `firestore.indexes.json` entries, or "all history filtering is client-side, no new indexes";<br>• a `make test-rules` plus `check_rule_coverage.mjs` obligation for all three collections and the `existsAfter` path;<br>• paginated full-log reads (≤500 per page);<br>• chunking of bulk captures (≤ ~450 docs per batch, each chunk self-contained), noted as a declared AD-8 carve-out. |
| 5 | High | Stale Stack pins (pub.dev, 2026-09-30):<br>• `firebase_analytics` ^12.3.0: current is **12.6.0**, the release-train match for core 4.14+.<br>• `flutter_local_notifications` ^21.0.0: current is **22.3.1**; 22.0.0 has no breaking changes.<br>• `share_plus` ^12.0.2: current is **13.3.0**; 13.0 is breaking (iOS 13, macOS 10.15, win32 6).<br>• `firebase_core` is 4.15.0; the ^4.14.0 caret already covers it.<br>• Bumping core forces the co-released `cloud_firestore` 6.10.0, `firebase_auth` 6.7.0 and `cloud_functions` 6.5.0, none of which are listed.<br>• `pdf` 3.13.1 needs Dart ≥3.12, while pubspec says `sdk: ^3.10.8`. | Pin:<br>• `firebase_analytics ^12.6.0`<br>• `flutter_local_notifications ^22.3.1`<br>• `share_plus ^13.3.0` (or record why 12.x is kept)<br>Also:<br>• List the full FlutterFire train (core ^4.15.0, firestore ^6.10.0, auth ^6.7.0, functions ^6.5.0, messaging ^16.7.0) as one atomic bump.<br>• Raise the Dart SDK lower bound to ^3.12.0.<br>• Note pdf's lack of GSUB/GPOS shaping: test Hebrew with nikud, or ban nikud in reports. |

---

## Lens 1 — Good-spine rubric (full findings)

### 1.1 Divergence points fixed / missed

| # | Sev | Finding | Fix |
|---|---|---|---|
| R1 | Critical | Top finding 1 (existing ledger, completion, streak and pace machinery not retired). | See top table. |
| R2 | High | The relationship between planner and engine is undefined. `daily_task_projection_service` (first-stage "done", `:105-123`) and `pace_calculator` already compute schedule and pace. AD-35 says the engine is "the only place" the daily target is computed, and AD-32 only changes the planner's "done" check. Which one owns the daily target, the schedulable set, FR-12a's one-masechta rule and returned-ground ordering? | Rule: the planner consumes `LearnerState.schedulableSet` and `dailyTarget` and only lays out tasks (including FR-12a). `pace_calculator` is deleted for the Mishnayos goal. |
| R3 | High | Two freezes are unspecified:<br>• FR-23: the on-track indicator must not change during the lock.<br>• FR-24: the planned list is frozen at lock start.<br>The engine takes `today`, so a day rollover inside a 3-day yom tov changes the target, projection and planned list. | Rule: during an active lock window, the engine is evaluated with `today = lockStart`'s date, and the planned view renders the engine output at lock start for each locked day. |
| R4 | High | AD-40 doesn't say how a streak day is keyed. A `dated` free tick with an edited `learnedOn` (FR-3 "date editable") can fill a past streak gap, which contradicts FR-3 ("date is the day being counted") and FR-4 ("never creates a streak day for another date"). | Rule: a `dated` main event counts toward the streak on `learnedOn` only if `learnedOn` equals the learner-local date of `recordedAt`. A `catchUp` event counts only for a locked day, within its catch-up window. Backdated `dated` events count for progress and velocity, never for the streak. |
| R5 | High | Child and parent authority is silent:<br>• FR-4: the child may re-date only within the catch-up window; older changes are removal only.<br>• FR-18/FR-21: the child never sees on-track status or shortfall.<br>The history also must say who acted. `actor.role` has only `owner \| tutor`, but child and parent share the owner account. Profile `mode` (child/adult) and the parent-PIN namespace exist (parent AD-15). | Add an AD: `actor.role ∈ {learner, parent, tutor}`, where "parent" means the PIN-unlocked mode. `CaptureGate`/`LearningCommands` enforce the FR-4 child limits, and presentation gates parent-only surfaces on the same mode source. |
| R6 | Medium | Location changes apply retroactively. The engine re-evaluates every historical event's `recordedAt` against lock windows computed from **current** profile location, so moving or editing the location silently voids past events and streak days. | Rule: the engine applies lock filtering using the settings in effect at `recordedAt`. Put profile location/`in_israel` changes in `change_log` (entity `profileLocation`). Alternatively, only lock-filter events recorded after the last location change. |
| R7 | Medium | The lock's scope is events only. AD-36's derivation-level enforcement covers `learn`/`void` events. Config writes (sub-track, goal, main track) stamped inside a lock by a bad-clock or offline client are accepted, although FR-23 says "any write … rejected on sync". | Either extend the rule so the engine and history ignore `change_log` entries whose `at` is inside a lock (and the doc reverts to the prior logged `after`), or record this explicitly as the same accepted risk as a forged `recordedAt`. |
| R8 | Medium | FR-25's reminder notification has no AD. `flutter_local_notifications` is in the Stack, but nothing says who schedules it, from which lock calendar, per profile, or on multi-profile or tutor devices. The existing notification suppression uses `sacred_window_repository`, which fails **open** with no location (`:62`, `:89`). | Rule: one scheduler derives catch-up reminders from the same lock-window function, per learner profile on devices where that profile is active, and not on tutor devices. The current fail-open path is replaced by the FR-23 fail-closed fallback. |
| R9 | Medium | AD-43 "whole-corpus deadline goal" has no predicate. Goals allow many per profile, with `goal_type ∈ {deadline, pace, none}` and `target_percent`. Epics will define "whole corpus" differently. | Rule: `curriculum_id = mishnayos && goal_type = 'deadline' && target_percent = 100`. The first such goal by id wins if concurrent offline creates produce two, so the engine is deterministic. |
| R10 | Medium | Tutor capture is online-only. AD-22 routes tutor mutations through callables, which cannot run offline, but PRD §4.9 says "all capture works offline". The callables' idempotency on the client ULID is also unspecified. | State it: tutor writes require connectivity (an accepted PRD deviation), the UI disables them offline, and the callable does create-if-absent on the client ULID and returns success on an identical replay. |
| R11 | Medium | Scale and cache:<br>• One document per mishna per event means a ≥4,192-doc backfill and a lifetime log in the tens of thousands.<br>• The tutor list (FR-29) reads every talmid's full log.<br>• Parent AD-18 caps the cache at 20 MiB per account, so multi-profile and tutor use can evict it, which breaks offline reads.<br>The memlog's <1 s assumption is unmeasured. | Either (a) make an event carry `refs: [..]` per gesture, with a void targeting `(eventId, ref)`, or (b) keep per-mishna docs and state a budget: max events per learner, a cache-size check, and a perf test at 20 talmidim × 10k events as an acceptance gate. |
| R12 | Low | AD-44 is imprecise: inclusive vs exclusive day counting, and rounding of capacity and daily target (ceil?), are unstated. The PRD's "Days to deadline counts study days" isn't linked to `activeWeeksLeft`. | Say it: day intervals are inclusive of both ends, `capacity` is floored, and `dailyTarget = ceil(numerator / studyDaysToDeadline)`, clamped at ≥ 0. |
| R13 | Low | Deleting a track: `deleteCurriculumTrack` uses an explicit collection list (`deletes.ts:161`), and `learning_events` / `sub_tracks` carry no `curriculum_id` (parent AD-25). | Either add `curriculum_id` to events and sub-tracks and include them in the track-scoped deletion list, or state that track deletion doesn't touch them and why. |

### 1.2 Rule enforceability

- AD-31 create-only with identical replay: this matches the existing SR-1 pattern (`update: if request.resource.data == resource.data`). The pattern needs a spelled-out ban on `FieldValue.serverTimestamp()` and on any wall-clock stamp added at retry time for owner writes; otherwise replays are permanently rejected (parent AD-30). Low.
- AD-38: not enforceable as written (top finding 2).
- AD-45 and AD-43: command-layer only by design, and the engine tolerates excess. Enforceable, but the tutor callables must share the validation. Name a shared validator module or a mirrored test suite so Dart and TypeScript don't drift. Medium.
- AD-47: enforceable through the existing `tool/check_analytics_catalog.dart`. The rule should say the new events are added to `AnalyticsEvent`. Low.
- AD-35 "engine never imports cloud_firestore/Riverpod/Flutter": `check_dependency_direction.dart` and `check_firebase_confinement.dart` don't cover the new `lib/domain/**`. Add a checker, or extend one, to fail on those imports under `lib/domain/`. Medium.

### 1.3 Brownfield ratification (claim checks)

| Spine claim | Reality | Status |
|---|---|---|
| "existing `sacred_time` `kosher_dart` service" | `ZmanimWindowService` (`lib/features/sacred_time/domain/services/zmanim_window_service.dart:27`) uses kosher_dart and has a polar over-block fallback. The no-location path fails **open** (`sacred_window_repository.dart:62,89`). | Correct name/feature; the fail-open behavior must be replaced explicitly (R8). |
| `TutorWriteService` → owner-scoped CFs | `lib/features/tutoring/data/services/tutor_write_service.dart:56`; 14 callables in `functions/src/tutor_writes.ts` / `tutor_bulk_completions.ts`; App Check enforced. | Correct. |
| Points stay in `points_ledger`; void co-writes a reversal in the same batch | The path is correct. The **completion write is not batched with points** today (`completion_orchestrator.dart:98-132`, best-effort). There is **no reversal entry kind** (`completion`, `redemption_debit`, `redemption_refund`, `parent_add`, `parent_deduct`). The production provider is not wired (`firestore_points_ledger_repository.dart:25-34`). | The spine describes new behavior as if it existed. It must add the `completion_reversal` kind, rules for it, deterministic ids (`pts_{eventUlid}`, `pts_rev_{voidUlid}`), and say whether `beforeTracking` events earn points. Otherwise a 4,192-mishna backfill farms points. **Medium** |
| Goals collection path | `users/{uid}/learner_profiles/{pid}/goals/{goalId}`, snake_case, `goal_type` exists, multiple goals allowed. | Consistent; see R9 and top finding 2 for the `last_change_id` whitelist. |
| `lib/domain/` absent | Confirmed absent; parent AD-3/AD-23 name `lib/domain` as the intended target. | The seed creating `lib/domain/learner_state/` ratifies the parent. OK. |
| Content DB is the corpus source (AD-16, AD-42) | Content DB (`assets/db/content.db`) has `sefariaRef` in `daily_content`, but corpus **hierarchy and order** come from `assets/content/hierarchy/mishnayos.json` (4,192 leaves, `sortOrder`) via `ContentIndex` (`lib/core/content/content_index.dart`). | **Incorrect.** Rebind AD-42/AD-34 to `ContentIndex` + `mishnayos.json` `sortOrder`. **Medium** |
| Location/timezone move from SharedPreferences | Location and `in_israel` are in SharedPreferences (`sacred_time_preferences.dart:9-15`). The timezone is **never stored**; it's runtime-detected (`notification_initializer.dart:46`). The profile doc has only `display_name, mode, avatar, created_at, updated_at`. | Partially wrong: the timezone is a new field, not a move. Name the profile fields (`latitude`, `longitude`, `time_zone` IANA, `in_israel`), add them to the rules whitelist, and say what seeds them on first run (device tz; the location prompt from FR-23). **Medium** |
| FCM token on account doc | No token field exists; `users/{uid}` has `email, display_name, created_at, updated_at`. | New. Needs a whitelist and a multi-device shape (`fcm_tokens: map<installId, {token, updated_at}>`) with stale-token pruning on send failure. **Medium** |
| Firestore fields snake_case | Confirmed snake_case (legacy camel aliases accepted on read). | ADs contradict this (top finding 3). |
| `activeAccountFirebaseProvider`, `resilient*Stream` | Exist (`active_account_providers.dart:118`, `resilient_doc_stream.dart:60,105`). | Correct. Note that parent AD-1/AD-24 say production sign-in is not yet on named apps, so new repositories may hit `AccountNotAuthenticatedException`. Declare the dependency on that completion. **Medium** |
| Recursive deletion covers new collections (AD-46) | `recursiveDelete(users/{uid})` and `recursiveDelete(profileRef)` cover new subcollections automatically (`deletes.ts:34,128,533`). | Correct for account/profile; see R13 for tracks. |

### 1.4 PRD FR coverage

| FR | Covered by | Gap |
|---|---|---|
| FR-1–FR-3, FR-2a | AD-31, 33, 34, 36 | Batch chunking for large up-to/free-tick captures (top finding 4). |
| FR-4 | AD-31, 38, 40 | Child vs parent limits (R5); streak keying (R4). |
| FR-4a | none needed (UI) | none |
| FR-5–FR-9, FR-6a/6b | AD-33, 44, 45 | FR-7 "Add next year" keeps edited months: fine via `window_start`/`window_end`. |
| FR-10–FR-13, FR-12a | AD-32–34 | Planner ownership (R2). |
| FR-14–FR-17 | AD-32, 35, 40 | The existing siyum logic (learning_ledger retraction) is not retired (R1). |
| FR-18, FR-20, FR-21 | AD-35 | Child-visibility gating (R5); lock freeze (R3). |
| FR-19 | AD-35, 44 | Rounding (R12). |
| FR-22 | withdrawn | none |
| FR-23–FR-25 | AD-36, 37, 40, 41 | Freeze (R3), reminder (R8), fail-open replacement (R8), retroactivity (R6). |
| FR-26–FR-28 | AD-22, 38, 39, 46 | Revocation: the tutor callables must check `tutor_active_access` on every call; `hasActiveTutorAccess` already covers reads. Low; make it explicit. |
| FR-29 | AD-35 | Scale (R11). |
| FR-30–FR-32 | AD-31, 48 | Hebrew shaping (top finding 5). |
| §4.9 | AD-8, 33, 38 | Tutor offline (R10). |
| §4.10 | AD-46, 47 | Analytics child-directed config (below); the privacy policy update is non-architectural. |
| SM-1–SM-5 | AD-47 | **SM-1, SM-2 and SM-3 are per-learner ratios**, but AD-47 forbids profile ids in payloads and GA's app-instance id conflates profiles on a shared device. They can't be measured as written. Allow a salted, per-install hashed profile key as a user property, or redefine the metrics per app instance. **Medium** |

### 1.5 Parent AD integrity

- **AD-4:** the only declared supersession is the streak half, and the parent has been amended to match. OK.
- **AD-8:** weakened implicitly. Bulk captures must chunk across batches (top finding 4), and the spine claims a same-batch points reversal that the current code doesn't do. Declare the chunking carve-out explicitly.
- **AD-30:** at risk. Adding a required `last_change_id` to goal and track rules makes any queued goal write from an un-upgraded client permanently rejected. The product is greenfield (parent AD-13), so state "no supported old clients; rules and client ship together", or keep the rule tolerant until the client ships.
- **AD-12:** "native SDK writes use real Firestore timestamps" versus the client-stamped `recordedAt`. Compatible, since a client `Timestamp` is a real Timestamp, but existing rules check timestamps `<= request.time`. A device clock ahead of server time gets permanently rejected (AD-30). Allow a skew tolerance (e.g. `<= request.time + duration.value(10, 'm')`) or drop that check for `recorded_at`. **Medium**
- **AD-5, AD-18, AD-29, AD-1/AD-24** are not in the inheritance table but bind this feature (deterministic ids, cache budget, emulator evidence, production auth wiring). Add them. Frontmatter `binds` also omits AD-28, which the table lists. Low.

### 1.6 Operational envelope

This section is entirely absent; see top finding 4. Also:

- **App Check:** callables enforce it, but rules have no `request.app` check (parent AD-12 partial). State whether the new collections add one.
- **FCM setup:** APNs `.p8` key upload, Push and Background Modes capabilities, waiting for `getAPNSToken()` on iOS, and `requestPermission()` for iOS and Android 13+ (firebase.google.com/docs/cloud-messaging/flutter/client, /receive). Also, pushes to "the owner" land on **every device signed into the owner account, including the child's phone** (child and parent share the account). Target tokens registered from parent mode only.
- **Children's data / Analytics:** disable AAID collection and ad personalization. On Android set manifest `google_analytics_adid_collection_enabled=false` and `google_analytics_default_allow_ad_personalization_signals=false`; on iOS set the matching Info.plist key. Don't request `AD_ID` (Google Play Families policy). Turn off Google Signals in GA4. Whether GA4 is permitted for under-13 users under Google's terms was **not verified**; it needs a legal/doc check before release.

---

## Lens 2 — Currency (verified 2026-09-30)

### 2.1 Stack

| Package | Spine pin | Repo lock today | Latest stable (date) | Verdict |
|---|---|---|---|---|
| firebase_core | ^4.14.0 | 4.9.0 (pin ^4.4.0) | 4.15.0 (2026-09-14) | OK (the caret resolves to 4.15). Say "^4.15.0" for clarity. |
| firebase_messaging | ^16.7.0 (new) | absent | 16.7.0 (2026-09-14), needs core ^4.14.0 | **Current.** |
| firebase_analytics | ^12.3.0 | 12.4.1 | 12.6.0 (2026-09-14), needs core ^4.14.0 | **Stale.** 12.3.0 is the April train (core ^4.7.0). Pin ^12.6.0. |
| kosher_dart | ^2.0.18 | 2.0.20 | 2.0.20 (2026-04-21) | OK (the caret resolves). Could say ^2.0.20. |
| flutter_local_notifications | ^21.0.0 | 21.0.0 | 22.3.1 (2026-09-13) | **Stale (a major behind).** 22.x has no breaking changes. 23.0.0-dev needs Dart 3.12 / Flutter 3.44. |
| pdf | ^3.13.1 (new) | absent | 3.13.1 (2026-09-19), Dart ≥3.12, `bidi ^2.0.10` | **Current**, but the repo SDK constraint `^3.10.8` must rise to ^3.12.0. The repo Flutter pin is 3.47.0; that its bundled Dart is ≥3.12 is likely but **unverified**. |
| share_plus | ^12.0.2 | 12.0.2 | 13.3.0 (2026-07-23) | **Stale (a major behind).** 13.0 is breaking (iOS 13, macOS 10.15, win32 6). Upgrade or record why not. |
| cloud_firestore / firebase_auth / cloud_functions | not listed | 6.4.1 / 6.5.1 / 6.3.1 | 6.10.0 / 6.7.0 / 6.5.0 (all 2026-09-14, all need core ^4.14.0) | **Missing from Stack.** The core bump forces them; list the whole FlutterFire train as one bump. |

Sources: `https://pub.dev/api/packages/<name>`, `https://pub.dev/packages/<name>/versions` and `/changelog`. A FlutterFire BoM page was not fetched; the train membership is inferred from shared publish dates and constraints.

`pdf` for Hebrew: bidi and RTL are supported (changelog 3.9.0 / 3.10.5). A Hebrew TTF must be embedded (the built-in Helvetica has no Unicode). There is no GSUB/GPOS shaping (DavBfr/dart_pdf#1929 unmerged), so **nikud and te'amim placement is at risk (unverified for Hebrew specifically)**. AD-48 should either require an unpointed text rendering or add a golden test with pointed text.

### 2.2 `existsAfter` (AD-38)

| Question | Answer | Source | Spine impact |
|---|---|---|---|
| Sees documents written in the same client batch or transaction? | **Yes.** `existsAfter(path)` ≡ `getAfter(path) != null`, evaluated against the state after the batch but before commit. | firebase.google.com/docs/firestore/security/rules-conditions; /docs/reference/rules/rules.firestore | The owner path works as assumed, but see the stale-id hole (top finding 2). |
| Offline-queued batch stays atomic on sync? | Batched writes work offline and are atomic. That a queued batch reaches the server as one commit is **inferred, not stated**. | /docs/firestore/manage-data/transactions | Needs emulator/instrumented evidence per parent AD-29. |
| Applies to Admin SDK writes from Cloud Functions? | **No.** "The server client libraries bypass all Cloud Firestore Security Rules." | /docs/firestore/security/get-started | The spine says "same function transaction (tutor)" but gives no enforcement mechanism: rules can't see it, and no helper or test is mandated. See top finding 2. |
| Access-call limits | 10 per single-doc request or query; 20 per batch or transaction, with 10 per operation. Over the limit means denied, and each call is billed as a read. | /docs/firestore/security/rules-conditions | The owner batch of N events + N points + sub_track + change_log uses `existsAfter` once per config doc, and `exists` is needed for the stale-id fix. Fine if a batch has ≤ ~9 config docs, but say one config doc per batch. |
| Path built from `request.resource.data.last_change_id` | No documented caveat. A missing or non-string value errors, and an error means deny. A `/` in the value would alter the path (**unverified in docs**). | inference from rules semantics | Guard with `is string` plus a ULID regex `matches('^[0-9A-HJKMNP-TV-Z]{26}$')`. |
| Identical replay of `set()` on an existing doc | Evaluated as **update** (create applies only to nonexistent docs), so `allow update: if request.resource.data == resource.data` is needed. Whether the SDK re-sends after a lost acknowledgement is **unverified**. | /docs/firestore/security/rules-structure | AD-46 says "identical replay allowed": correct. Make `change_log` and `learning_events` use the same SR-1 pattern. |

### 2.3 Other currency notes

- The FCM Flutter requirements (APNs key, capabilities, `getAPNSToken()` before other calls, `requestPermission()` on iOS and Android 13+) are not reflected in the spine; add them to AD-39 or the operational AD.
- Analytics for a child-directed audience: see 1.6. The COPPA / Google terms question is **unverified**.

## Items not verified

- The Dart version bundled with Flutter 3.47.0 (needed for `pdf` 3.13.1's Dart ≥3.12).
- An official FlutterFire BoM listing for the 2026-09-14 train.
- Server-side atomicity of an offline-queued batch, and SDK re-send behavior after a lost acknowledgement.
- Hebrew nikud rendering quality in `pdf` 3.13.1.
- Whether Google Analytics for Firebase is permitted for under-13 users, and whether Google Signals must be disabled.
