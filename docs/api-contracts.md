# API & Sync Contracts — Learning Tracker

> Part of the Learning Tracker project documentation. Start at [index.md](./index.md).
> Generated 2026-05-19 by an exhaustive codebase scan (BMAD `document-project` workflow).

> **AUD-docs-07 partial refresh (2026-07-13):** §2 (Cloud Functions) and the indexes claim in §3 are re-verified below and current. **§1.2's per-profile collection table (`streak`, `notification_settings`, `gamification_settings`, `ui_preferences`, `curriculum_import_metadata`, ...) and §3's non-tutor rules summary still describe a pre-rebuild layout** — the live collections are `streak_events`, `preferences/{scope}` (scopes `notification_settings`/`gamification_settings`/`ui_preferences`), `import_metadata`, plus `points_ledger`, `reward_redemptions`, `stage_definitions`, `curriculum_scopes` and `study_day_configs`, none of which have rows here. That is separate, wider drift than this finding's scope (AUD-docs-07 covers only Cloud Functions + tutor-mode collections + the indexes claim) — see `learning_tracker/firestore.rules` for the authoritative current layout until §1/§3 get their own regeneration pass.

This is an **offline-first mobile app** — it exposes no HTTP API of its own. Its external "contracts" are:

1. **Firestore document model** — the cloud schema the app reads/writes for tier-gated sync.
2. **Cloud Functions** — 27 callable/trigger endpoints: 4 deletion-cascade endpoints, 8 tutor invite/grant-lifecycle endpoints, 13 tutor write-proxy endpoints, plus `purgeExpiredAuditLogs` and `tutorBulkPriorCompletions` (§2).
3. **Firestore security rules** — server-side access control.
4. **Sefaria API** — used only by build-time tooling, not at runtime.

Sync internals (push/pull/merge flows) are in [architecture.md](./architecture.md) §6. Local Drift schema is in [data-models.md](./data-models.md).

---

## 1. Firestore document model

Firebase project: **`torah-study-tracker`**. All per-profile data lives under `users/{uid}/learner_profiles/{profileId}/<collection>`; account-level data lives under `users/{uid}`. The single Firestore I/O seam is `FirestoreGatewayImpl` (`core/sync/firestore_gateway_impl.dart`) — the only `lib/` file allowed to import `cloud_firestore`.

Gateway conventions applied on every push: keys starting with `_` are stripped; a `synced_at` `serverTimestamp()` is added. On read: every `Timestamp` is converted to an ISO-8601 string and `firestore_id` (the doc id) is injected.

### 1.1 Account-level

| Path | Doc ID | Shape |
|---|---|---|
| `users/{uid}` | uid | Account user profile; arbitrary caller fields + `updatedAt`. |
| `users/{uid}/profile/data` | `data` | `firebase_uid`, `display_name`, `user_mode`, `updated_at`, `synced_at`. |
| `users/{uid}/learner_profiles/{profileId}` | profileId | `id`, `account_id`, `display_name`, `mode`, `avatar_index`, `created_at`, `updated_at`, `settings_snapshot` (map), optional `streak_summary`, `reward_configuration`. |
| `users/{uid}/diagnostic_logs/{auto}` | auto | Diagnostic-log upload; caller fields + `captured_at`. 7-day TTL. |

### 1.2 Per-profile subcollections (`users/{uid}/learner_profiles/{profileId}/...`)

| Collection | Doc ID derivation | Key fields |
|---|---|---|
| `completions` | percent-encoded `profileId_sefariaRef_stageId_trackType_curriculumId` | `profile_id`, `curriculum_id`, `sefaria_ref`, `stage_id`, `track_type`, `track_id?`, `completed_at` (Timestamp), `points?`, `purged_at?`. |
| `bookmarks` | `{curriculumId}_{trackType}` | `curriculum_id`, `track_type`, `sefaria_ref`, `updated_at`. |
| `settings` | `curriculum_id` (else `default`) | `curriculum_id`, `track_id`, `stages` (array), `study_day_config?`, `updated_at`. |
| `streak` | single doc `data` | `current_count`, `max_count`, `last_completion_date`, `grace_used_date`, `grace_period_days`. Also receives streak-event rows on the listener path. |
| `curriculum_tracks` | `{curriculumId}_{trackType}` | `profile_id`, `track_id`, `curriculum_id`, `track_type`, `is_active`, `activated_at`, `deactivated_at?`, `pace_reset_date?`, `progress_schema_version`, progress maps. |
| `goals` | deterministic `{curriculumId}_{targetPercent}_{createdAtMs}` | `id`, `profile_id`, `track_id`, `curriculum_id`, `target_percent`, `target_date`, `goal_type`, `pace_*`, `created_at`, `updated_at`. |
| `profile_programs` | `curriculum_id` | `profile_id`, `curriculum_id`, `program_id`, `tracking_start_date?`, `tracking_start_ref?`. |
| `learning_order` | `{curriculumId}_{sefariaRef}` | `curriculum_id`, `sefaria_ref`, `user_sort_order`, `updated_at`. |
| `learning_ledger` | auto (`add()`) | `curriculumId`, `entryScope`, `unitIdentifier`, `unitDisplayNameHe/En`, `trackType`, `trackId?`, `completedAt`, `completionNumber`, `markedBy`, `isManual`, `ulid`, `profileId`. |
| `notification_settings` | single doc `preferences` | `schema_version`, `daily_reminder`, `streak_alert`, `reward_notifications`, `updated_at`. |
| `gamification_settings` | single doc `config` | `schema_version`, `points_config` (array), `reward_settings`, `lifetime_stats`, `updated_at`. |
| `ui_preferences` | single doc `data` | `schema_version`, `profile_id`, `app_locale`, `use_hebrew_calendar`, `text_display`, `hebrew_terms_script`, and (profile 0 only) `sacred_time`. |
| `curriculum_import_metadata` | `curriculum_id` (else `default`) | `curriculum_id`, `item_count`, `imported_at`. |

> ⚠️ **Known mismatch:** `pushCurriculumImportMetadata` writes `curriculum_import_metadata` but `fetchCurriculumImportMetadata` reads `curriculum_imports` — reads will never find pushed docs. See [architecture.md](./architecture.md) §9.

### 1.3 Tutor Mode — top-level collections (AUD-docs-07)

Tutor cross-user access is **not** part of the owner-gated `users/{uid}/...` tree above — it lives in two top-level collections, both Admin-SDK-write-only (no client ever creates/updates/deletes either):

| Collection | Doc ID | Written by | Key fields |
|---|---|---|---|
| `tutor_grants/{grantId}` | `{encodedEmail}__{parentUid}__{childProfileId}` | Cloud Functions only (`tutor_invites.ts`) | `tutor_uid?`, `tutor_email`, `parent_uid`, `child_profile_id`, `state` (`pending`/`active`/`revoked`/...), `tutor_name_snapshot?`, `accepted_at?`, `invite_token?`, `updated_at`. Readable by the referenced tutor (`tutor_uid`) or parent (`parent_uid`). |
| `tutor_grants/{grantId}/audit_log/{entryId}` | auto | Cloud Functions only | `tutor_uid`, `action`, `target`, `after_value`, `created_at`. Readable by the grant's parent/tutor. 12-month retention (`purgeExpiredAuditLogs`, see below). |
| `tutor_active_access/{tutorUid}_{parentUid}_{profileId}` | deterministic (no `grantId` needed) | `acceptTutorInvite` (write) / `revokeTutorGrant`, `resignTutorGrant`, `expirePendingInvites` (delete) | `tutor_uid`, `parent_uid`, `child_profile_id`, `grant_id`, `created_at`. **O(1) existence-checked secondary index** — `firestore.rules`' `hasActiveTutorAccess()` grants a tutor read access to a learner's profile/subcollections purely by this doc's presence; there is no `state`/`expires_at` field to check because absence of the doc *is* "revoked or expired" (SR-5, `docs/coding-standards.md`). |

Once `hasActiveTutorAccess(ownerUid, profileId)` is true, the tutor gets READ access to `users/{ownerUid}/learner_profiles/{profileId}` and its subcollections (never write — `completions` etc. are owner-write-only even for an active tutor; tutor-authored changes go through the `tutor_*` Cloud Function proxies in §2, which write as the owner uid via Admin SDK).

---

## 2. Cloud Functions

Source: `learning_tracker/functions/src/index.ts` — a re-export barrel (kept under 300 lines, AUD-firebase-15) over 5 focused modules: `deletes.ts`, `audit_log_purge.ts`, `tutor_bulk_completions.ts`, `tutor_invites.ts`, `tutor_writes.ts`. TypeScript → `tsc` → `lib/`. Runtime Node 20+. `firebase-admin ^13.10.0`, `firebase-functions ^7.2.5`. **27 exported functions total** (deletion cascades use `db.recursiveDelete` so the client never enumerates subcollections).

**Deletion cascades (4)** — `deletes.ts`:

| Function | Type | Input | Behavior |
|---|---|---|---|
| `onUserDeleted` | Auth trigger (`auth.user().onDelete`, v1) | Auth `user` | Cascades `recursiveDelete` on `users/{uid}` after an Auth account is deleted (safety net). |
| `deleteLearnerProfile` | Callable (v2 https) | `{ profileId: number }` | Recursively deletes `users/{uid}/learner_profiles/{profileId}`; also removes the caller's `tutor_active_access` lookup docs for that profile. Throws `unauthenticated` / `invalid-argument`. |
| `deleteCurriculumTrack` | Callable (v2) | `{ profileId, curriculumId, trackType }` | Deletes `curriculum_tracks/{curriculumId}_{trackType}` under the profile. |
| `deleteAccountData` | Callable (v2) | `{}` (identity from `request.auth.uid`) | Recursively deletes all data under `users/{uid}`; called before Auth-account deletion. |

**Audit log retention (1)** — `audit_log_purge.ts`: `purgeExpiredAuditLogs` (scheduled) — deletes `tutor_grants/*/audit_log` entries past the 12-month retention window (W3.42).

**Tutor invite / grant lifecycle (8)** — `tutor_invites.ts`, all Callable (v2): `inviteTutor`, `acceptTutorInvite`, `declineTutorInvite`, `rescindTutorInvite`, `revokeTutorGrant`, `resignTutorGrant`, `listTutorGrants`, `expirePendingInvites`. These are the only writers of `tutor_grants` and `tutor_active_access` (§1.3) — `acceptTutorInvite` also writes `tutor_active_access`; `revokeTutorGrant`/`resignTutorGrant`/`expirePendingInvites` delete it.

**Tutor bulk-prior-completions proxy (1)** — `tutor_bulk_completions.ts`: `tutorBulkPriorCompletions` — writes `completions` **as the owner uid** via Admin SDK (the client-side rule denies a tutor's own uid from writing completions — W3.43). Enforces `canMarkLiveCompletion=false`.

**Tutor write proxies (13)** — `tutor_writes.ts`, all Callable (v2), each writes as the owner uid via Admin SDK after checking the caller has an active grant: `tutorResetCompletion`, `tutorUpsertGoal`, `tutorDeleteGoal`, `tutorUpsertTrack`, `tutorDeleteTrack`, `tutorUpsertStageDefinition`, `tutorUpsertStudyDayConfig`, `tutorDeleteStudyDayConfig`, `tutorUpdateGamificationSettings`, `tutorUpsertBookmark`, `tutorSetProfileProgram`, `tutorUpsertCurriculumScope`, `tutorEditProfile`.

Callers: `AccountManagementService` / `AccountLifecycleService` invoke `deleteAccountData`; `ProfileRepositoryImpl` invokes `deleteLearnerProfile` (via the gateway); the `tutoring` feature module invokes the invite/grant and `tutor_*` write-proxy functions.

---

## 3. Firestore security rules

`learning_tracker/firestore.rules` (`rules_version='2'`). Global default-deny first (`match /{document=**} { allow read, write: if false; }`).

**Live layout — `users/{uid}/...`** — every path is owner-gated by `isOwner(uid)`:
- `users/{uid}`, `profile/{docId}` — read/create/update by owner; delete denied.
- `diagnostic_logs/{logId}` — append-only (create only).
- `learner_profiles/{profileId}` — read/create/update; delete denied (Cloud Function does deletion).
- Per-profile subcollections:
  - `completions`, `learning_ledger` — append-only; `completions` validates `points` (0-100) and `completed_at <= request.time`.
  - `streak/{docId}` — create+update allowed (counter advances in place), delete denied.
  - `settings`, `notification_settings`, `gamification_settings`, `ui_preferences` — owner-gated, **no** field whitelist (open-ended payloads).
  - `curriculum_tracks`, `bookmarks`, `learning_order`, `goals`, `curriculum_import_metadata` — snapshot collections gated by `.hasOnly(...)` field whitelists; delete denied.
  - `profile_programs/{curriculumId}` — whitelisted; delete **permitted** (app removes assignments).

**Deprecated top-level blocks** (`accounts`, `learner_profiles`, `completion_events`, `streak_events`, `learning_ledger`, `track_configs`, `bookmarks`, `settings`) — this description is stale (AUD-t-cross-18, 2026-07-13). It previously claimed these were retained because `test/firestore-rules/` and the Story 27.8 acceptance test pinned them; `test/firestore-rules/` was a dead Jest suite (obsolete `accounts/{uid}` model, non-existent rules path) and has been deleted. A direct read of `firestore.rules` confirms none of these top-level blocks are actually defined there — only the nested `users/{uid}/...` collections above exist. See the AUD-docs-07 note above for the pending full regeneration of this section.

**Indexes:** `firestore.indexes.json` (AUD-docs-07, corrected 2026-07-13) defines **6 composite indexes, all on `tutor_grants`** — supporting the tutor-read (`tutor_uid`+`state`), parent-lookup (`parent_uid`+`child_profile_id`+`state`), pending-invite (`tutor_email`+`state`), expiry-sweep (`state`+`updated_at`), and two recency-ordered (`tutor_uid`/`parent_uid` + `updated_at` DESC) queries the tutor invite/grant Cloud Functions (§2) run. No other collection has a composite index defined.

---

## 4. Sefaria API (build-time only)

The app does **not** call the Sefaria API at runtime — all Torah text and calendar data is bundled in the Content DB (`content.db.gz`). The `core/network/sefaria/` package only defines the abstract `CurriculumContentFetcher` interface (the seed-pipeline contract). Concrete Sefaria HTTP fetching lives entirely in build tooling — `learning_tracker/tool/` (`seed_content*.dart`, `seed_text_content.dart`, `sefaria_fetch/main.go`, `hebcal_fetch/main.mjs`) — and runs offline against a local Mongo or the public Sefaria API to (re)build the seed. Story 19.4 removed all runtime Sefaria/Hebcal clients.

`ConnectivityService` (`core/network/connectivity_service.dart`) is the only runtime network touch besides Firebase — a lightweight `InternetAddress.lookup('dns.google')` reachability probe.
