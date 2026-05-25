# API & Sync Contracts — Learning Tracker

> Part of the Learning Tracker project documentation. Start at [index.md](./index.md).
> Generated 2026-05-19 by an exhaustive codebase scan (BMAD `document-project` workflow).

This is an **offline-first mobile app** — it exposes no HTTP API of its own. Its external "contracts" are:

1. **Firestore document model** — the cloud schema the app reads/writes for tier-gated sync.
2. **Cloud Functions** — 4 callable/trigger endpoints (deletion cascades).
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

---

## 2. Cloud Functions

Source: `learning_tracker/functions/src/index.ts` (TypeScript → `tsc` → `lib/`). Runtime Node 20. `firebase-admin ^13.7.0`, `firebase-functions ^7.2.3`. All use `db.recursiveDelete` so the client never enumerates subcollections.

| Function | Type | Input | Behavior |
|---|---|---|---|
| `onUserDeleted` | Auth trigger (`auth.user().onDelete`, v1) | Auth `user` | Cascades `recursiveDelete` on `users/{uid}` after an Auth account is deleted (safety net). |
| `deleteLearnerProfile` | Callable (v2 https) | `{ profileId: number }` | Recursively deletes `users/{uid}/learner_profiles/{profileId}`. Throws `unauthenticated` / `invalid-argument`. |
| `deleteCurriculumTrack` | Callable (v2) | `{ profileId, curriculumId, trackType }` | Deletes `curriculum_tracks/{curriculumId}_{trackType}` under the profile. |
| `deleteAccountData` | Callable (v2) | `{}` (identity from `request.auth.uid`) | Recursively deletes all data under `users/{uid}`; called before Auth-account deletion. |

Callers: `AccountManagementService` / `AccountLifecycleService` invoke `deleteAccountData`; `ProfileRepositoryImpl` invokes `deleteLearnerProfile` (via the gateway).

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

**Deprecated top-level blocks** (`accounts`, `learner_profiles`, `completion_events`, `streak_events`, `learning_ledger`, `track_configs`, `bookmarks`, `settings`) are retained because the Story 27.8 acceptance test and `test/firestore-rules/` pin them, even though the app no longer writes that layout.

**Indexes:** `firestore.indexes.json` is empty (`{"indexes":[],"fieldOverrides":[]}`) — no composite indexes defined.

---

## 4. Sefaria API (build-time only)

The app does **not** call the Sefaria API at runtime — all Torah text and calendar data is bundled in the Content DB (`content.db.gz`). The `core/network/sefaria/` package only defines the abstract `CurriculumContentFetcher` interface (the seed-pipeline contract). Concrete Sefaria HTTP fetching lives entirely in build tooling — `learning_tracker/tool/` (`seed_content*.dart`, `seed_text_content.dart`, `sefaria_fetch/main.go`, `hebcal_fetch/main.mjs`) — and runs offline against a local Mongo or the public Sefaria API to (re)build the seed. Story 19.4 removed all runtime Sefaria/Hebcal clients.

`ConnectivityService` (`core/network/connectivity_service.dart`) is the only runtime network touch besides Firebase — a lightweight `InternetAddress.lookup('dns.google')` reachability probe.
