import 'package:drift/drift.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/database/daos/active_curriculum_dao.dart';
import 'package:learning_tracker/core/database/daos/bookmark_dao.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/completion_event_dao.dart';
import 'package:learning_tracker/core/database/daos/curriculum_scope_dao.dart';
import 'package:learning_tracker/core/database/daos/daily_plan_dao.dart';
import 'package:learning_tracker/core/database/daos/goal_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_ledger_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_order_dao.dart';
import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/database/daos/point_config_dao.dart';
import 'package:learning_tracker/core/database/daos/points_balance_dao.dart';
import 'package:learning_tracker/core/database/daos/prior_completion_import_dao.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/daos/profile_program_dao.dart';
import 'package:learning_tracker/core/database/daos/sacred_window_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/daos/streak_event_dao.dart';
import 'package:learning_tracker/core/database/daos/study_day_config_dao.dart';
import 'package:learning_tracker/core/database/daos/sync_kv_dao.dart';
import 'package:learning_tracker/core/database/daos/text_download_status_dao.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/daos/track_learning_order_dao.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/tables/accounts.dart';
import 'package:learning_tracker/core/database/tables/bookmarks.dart';
import 'package:learning_tracker/core/database/tables/completion_events.dart';
import 'package:learning_tracker/core/database/tables/curriculum_scopes.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/daily_plans.dart';
import 'package:learning_tracker/core/database/tables/goals.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';
import 'package:learning_tracker/core/database/tables/learning_ledger.dart';
import 'package:learning_tracker/core/database/tables/learning_order.dart';
import 'package:learning_tracker/core/database/tables/outbox.dart';
import 'package:learning_tracker/core/database/tables/point_configs.dart';
import 'package:learning_tracker/core/database/tables/points_balance.dart';
import 'package:learning_tracker/core/database/tables/prior_completion_imports.dart';
import 'package:learning_tracker/core/database/tables/profile_programs.dart';
import 'package:learning_tracker/core/database/tables/sacred_window_entries.dart';
import 'package:learning_tracker/core/database/tables/stage_definitions.dart';
import 'package:learning_tracker/core/database/tables/streak_events.dart';
import 'package:learning_tracker/core/database/tables/study_day_configs.dart';
import 'package:learning_tracker/core/database/tables/sync_kv.dart';
import 'package:learning_tracker/core/database/tables/text_download_statuses.dart';
import 'package:learning_tracker/core/database/tables/track_learning_order.dart';
import 'package:learning_tracker/core/database/views/completions_view.dart';
import 'package:learning_tracker/core/time/ulid.dart';

part 'user_database.g.dart';

/// Mutable database containing all user data.
///
/// Schema v1 (W3.19 rebuild):
/// - Dropped legacy tables: completions, streaks, sync_queue.
/// - curriculum_tracks: removed trackType, isActive, deletedAt, deactivatedAt;
///   added state (enum text) + stateChangedAt; UNIQUE now (profileId, curriculumId).
/// - stage_definitions: replaced schedule quartet with JSON `schedule` column;
///   added updatedAt; dropped supersededAt.
/// - goals/learning_ledger: dropped .named() column aliases (T4).
/// - learner_profiles → accounts FK added (W3.25).
/// - curriculum_scopes + learning_order → learner_profiles FK added (W3.25).
/// - curriculum_scopes: added updatedAt (W3.23).
/// - calendar_cycles.sefariaRefHe + seed_metadata.contentHash: now nullable (W3.26).
///
/// Schema v25 (WS7):
/// - Added points_balance, points_ledger, reward_redemptions tables for the
///   stored debitable points balance and the redeem→fulfil loop.
///
/// Schema v26 (WS9.enum / WS9.flows):
/// - Added a CHECK constraint on learner_profiles.mode: only 'adult' | 'child'
///   are valid values. Enforced at DB level; the old free-text column accepted
///   any string.
/// - Dropped the vestigial accounts.userMode column (mode belongs to
///   learner_profiles.mode, not to an account).
///   SQLite cannot add a CHECK constraint or drop a column via ALTER TABLE,
///   so both changes use the SQLite-recommended table-rebuild recipe:
///   create a new-shape table, copy ALL existing rows via INSERT…SELECT
///   (preserving ids so child FKs stay valid), drop the old table, rename.
///   FK enforcement is disabled for the duration of the rebuild and a
///   `PRAGMA foreign_key_check` is run afterward to guarantee no orphans.
///   13+ child tables FK-reference learner_profiles(id) ON DELETE CASCADE —
///   the previous deleteTable()+createTable() approach destroyed those rows
///   (cascade does not fire while foreign_keys is OFF during onUpgrade),
///   so it has been replaced with this row-preserving rebuild.
///
/// Schema v27 (WS9 Wave-B points-sync prep — additive, no data loss):
/// - Added a nullable `ulid` text column to points_ledger (deterministic
///   doc id for append-only cloud sync).
/// - Added a nullable `ulid` text column to reward_redemptions (its
///   `updated_at` LWW column already existed). Columns only — the Wave-B
///   sync agent wires the DAO/sync and backfills these going forward.
///
/// Schema v33 (AUD-guardrails-01 — profileId-in-PK invariant gap closure):
/// - Added a non-unique composite index `goals_profile_curriculum` on
///   `goals(profile_id, curriculum_id)` so `profileId` structurally
///   participates in the Goals table's profile-scoping key, matching every
///   other profile-scoped table. Additive index only — no data loss.
///
/// Schema v34 (AUD-core-database-03 — sync merge double-credit gap closure):
/// - Added UNIQUE composite indexes `points_ledger_profile_ulid` on
///   `points_ledger(profile_id, ulid)` and
///   `reward_redemptions_profile_ulid` on
///   `reward_redemptions(profile_id, ulid)`, mirroring the UNIQUE
///   `learning_ledger_profile_ulid` index `LearningLedger` already has. Any
///   pre-existing duplicate `(profile_id, ulid)` rows (the exact double-
///   credit this defect could already have produced) are deduplicated —
///   keeping the lowest `id` — before the unique index is created, and every
///   profile with a `points_ledger` duplicate has its `points_balance`
///   re-derived from the deduplicated ledger so no stale over-credit
///   survives the upgrade. Rows with a `NULL` ulid (not yet backfilled by
///   the Wave-B sync agent) are never deduplicated — SQLite treats each NULL
///   as distinct in a UNIQUE index, matching the pre-existing
///   `learning_ledger` precedent.
///
/// Schema v35 (AUD-core-database-09 - comment-only FK gap closure):
/// - `points_ledger.redemptionId` was documented as "FK to
///   RewardRedemptions.id" in a doc comment only - nothing at the DB layer
///   stopped it from pointing at a nonexistent (or wrong-profile) redemption
///   row. Declares a real `.references(RewardRedemptions, #id,
///   onDelete: KeyAction.restrict)`. SQLite cannot ALTER TABLE an existing
///   column to add a REFERENCES clause, so this uses the same table-rebuild
///   recipe as v26/v34 (`TableMigration`, which also re-creates the table's
///   `points_ledger_profile_ulid` UNIQUE index). Any pre-existing bogus
///   `redemptionId` (pointing at a row that does not exist in
///   `reward_redemptions`) is nulled out defensively before the rebuild -
///   the exact gap this migration closes could already have let one in -
///   so the rebuild's `PRAGMA foreign_key_check` never trips on stale data.
///
/// Schema v36 (AUD-t-cross-06 — track_learning_order profileId-in-PK gap
/// closure):
/// - `track_learning_order` was the one user_database table with a bare
///   autoincrement PK and no `profileId` — isolation depended entirely on
///   `trackId` never being confused across profiles, with no schema-level
///   guard. Declares `profileId` (`.references(LearnerProfiles, #id,
///   onDelete: KeyAction.cascade)`) and folds it into `uniqueKeys` with
///   `trackId`/`sefariaRef`. `profileId` is backfilled per-row from the
///   owning `curriculum_tracks` row via a correlated subquery; rows whose
///   `trackId` no longer resolves to a real `curriculum_tracks` row (never
///   possible before this fix, since nothing purged this table on
///   track/profile delete) are dropped first, since their owning profile is
///   unrecoverable.
///
/// Schema v37 (AUD-scheduler-15 — completion_events.stage_id format
/// disambiguation):
/// - Added a nullable `stage_id_format` column to `completion_events` and
///   backfilled it deterministically for every pre-existing row that can be
///   classified with certainty. See the `onUpgrade` block for the full
///   reasoning.
///
/// Schema v38 (Firestore-rewrite transition, Epic C):
/// - Added a nullable `ulid` text column to `learner_profiles`, pairing a
///   row's Drift autoincrement `id` with its Firestore
///   `learner_profiles/{ulid}` doc-id during the migration. Additive only —
///   existing rows get NULL (meaning "not yet migrated", never "no
///   profile"). Mirrors the v27 points_ledger/reward_redemptions precedent.
///   Transition cruft: removed along with the rest of the Drift user
///   database once the app is fully cut over to Firestore-native profile
///   identity — see `learner_profiles.dart`'s `ulid` column doc comment.
///
/// This database uses standard Drift migrations and holds all user-generated
/// content: profiles, progress, configuration, streaks, and sync state.
/// It is the only database that accepts writes at runtime.
@DriftDatabase(
  tables: [
    Accounts,
    LearnerProfiles,
    CurriculumTracks,
    CurriculumScopes,
    ProfilePrograms,
    StageDefinitions,
    PointConfigs,
    StudyDayConfigs,
    CompletionEvents,
    DailyPlans,
    LearningLedger,
    Bookmarks,
    LearningOrder,
    TrackLearningOrder,
    Goals,
    StreakEvents,
    TextDownloadStatuses,
    Outbox,
    SacredWindowEntries,
    PriorCompletionImports,
    SyncKv,
    // WS7: stored debitable balance + ledger + redemptions
    PointsBalance,
    PointsLedger,
    RewardRedemptions,
  ],
  views: [CompletionsView],
  daos: [
    ActiveCurriculumDao,
    CurriculumScopeDao,
    CompletionDao,
    CompletionEventDao,
    DailyPlanDao,
    LearningLedgerDao,
    GoalDao,
    PointConfigDao,
    PointsBalanceDao,
    StageDao,
    BookmarkDao,
    LearningOrderDao,
    TrackLearningOrderDao,
    TrackDao,
    ProfileDao,
    UserProfileDao,
    StreakEventDao,
    TextDownloadStatusDao,
    StudyDayConfigDao,
    ProfileProgramDao,
    OutboxDao,
    SacredWindowDao,
    PriorCompletionImportDao,
    SyncKvDao,
  ],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.e);

  @override
  int get schemaVersion => 38;

  // drift_dev cannot express WHERE in a Dart-defined view's `as()` body
  // (cascade `..where()` confuses the generator).  The auto-generated SQL for
  // completions_view therefore omits the filter.  We drop and recreate the
  // view with this explicit SQL on fresh install.
  static const _completionsViewSql =
      'CREATE VIEW completions_view AS '
      'SELECT id, profile_id, curriculum_id, sefaria_ref, stage_id, '
      'track_type, track_id, points, event_timestamp, stage_id_format '
      'FROM completion_events '
      'WHERE purged_at IS NULL';

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      // C2: enable FK enforcement on every connection open (connection-level).
      beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
      onCreate: (Migrator m) async {
        await m.createAll();
        // Replace the auto-generated completions_view (no WHERE) with the
        // filtered version.
        await customStatement('DROP VIEW IF EXISTS completions_view');
        await customStatement(_completionsViewSql);
      },
      // W3.19: fresh-install schema only — no upgrade path needed (pre-launch).
      // WS7 (v25): added points_balance, points_ledger, reward_redemptions.
      // WS9 (v26): CHECK on learner_profiles.mode + drop accounts.userMode
      //            (row-preserving rebuilds).
      // WS9 (v27): additive ulid columns for Wave-B points sync.
      // AUD-guardrails-01 (v33): additive composite index on goals.
      // AUD-core-database-09 (v35): real FK on points_ledger.redemptionId.
      // AUD-t-cross-06 (v36): profileId FK added to track_learning_order.
      // AUD-scheduler-15 (v37): additive stage_id_format marker on
      //            completion_events, one-time-tagged for pre-existing rows.
      // Epic C (v38): additive nullable `ulid` on learner_profiles —
      //            Firestore-rewrite transition column, removed with the
      //            Drift user database (see learner_profiles.dart).
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 25) {
          await m.createTable(pointsBalance);
          await m.createTable(pointsLedger);
          await m.createTable(rewardRedemptions);
        }
        if (from < 26) {
          // WS9 (v26): rebuild learner_profiles + accounts WITHOUT data loss.
          //
          // SQLite cannot add a CHECK constraint or drop a column via ALTER
          // TABLE, so we use the table-rebuild recipe. Crucially we PRESERVE
          // all existing rows (ids included) — 13+ child tables FK-reference
          // learner_profiles(id) ON DELETE CASCADE, and the old
          // deleteTable()+createTable() approach destroyed those child rows
          // (cascade does not fire because PRAGMA foreign_keys is OFF during
          // onUpgrade) and reset AUTOINCREMENT, orphaning every child row.
          //
          // foreign_keys MUST be OFF for the rename step (it is already off
          // inside the onUpgrade transaction, but we assert it explicitly so
          // child FKs are not transiently violated mid-rebuild). We re-check
          // integrity with PRAGMA foreign_key_check afterward and only then
          // restore enforcement (beforeOpen also re-enables it per-connection).
          await customStatement('PRAGMA foreign_keys = OFF');

          // (a) learner_profiles → add CHECK (mode IN ('adult','child')).
          //     createNewTable: false copies from the existing table; we keep
          //     every column 1:1 (mode is unchanged data-wise, only the
          //     constraint is new), preserving ids so child FKs stay valid.
          //
          //     columnTransformer provides literal defaults for v28 mirror
          //     columns (isTutored, tutor*) that did not exist in the v25/v26
          //     table, so the INSERT…SELECT never reads a non-existent column.
          await m.alterTable(
            TableMigration(
              learnerProfiles,
              columnTransformer: {
                learnerProfiles.isTutored: const CustomExpression('0'),
                learnerProfiles.tutorParentUid: const CustomExpression('NULL'),
                learnerProfiles.tutorRemoteProfileId: const CustomExpression(
                  'NULL',
                ),
                learnerProfiles.tutorGrantId: const CustomExpression('NULL'),
              },
            ),
          );

          // (b) accounts → drop the vestigial user_mode column. The new
          //     `accounts` table definition has no userMode; copying only the
          //     surviving columns drops it while keeping all rows + ids.
          await m.alterTable(TableMigration(accounts));

          // Integrity gate: no child row may be orphaned by the rebuilds.
          final orphans = await customSelect('PRAGMA foreign_key_check').get();
          assert(
            orphans.isEmpty,
            'v26 migration orphaned ${orphans.length} row(s): '
            '${orphans.map((r) => r.data).toList()}',
          );

          await customStatement('PRAGMA foreign_keys = ON');
        }
        if (from >= 25 && from < 27) {
          // WS9 Wave-B prep: additive nullable columns for points cloud sync.
          // Safe on existing rows (NULL default); Wave-B backfills/populates.
          //
          // Guard `from >= 25`: a database upgrading from < 25 already received
          // points_ledger/reward_redemptions from the `from < 25` createTable
          // block above, which builds them from the CURRENT Dart table
          // definition — `ulid` INCLUDED. Re-adding it here would throw
          // "duplicate column name: ulid" and abort the whole upgrade (the
          // AUD-t-cross-62 follow-up bug). Only a database created at exactly
          // v25/v26 (the pre-ulid schema) still needs this addColumn. Same
          // reasoning as the `from >= 26 && from < 28` tutor-column block below.
          await m.addColumn(pointsLedger, pointsLedger.ulid);
          await m.addColumn(rewardRedemptions, rewardRedemptions.ulid);
        }
        if (from >= 25 && from < 29) {
          // D14: additive nullable marker so the points-ledger sync
          // reconciliation knows which rows have never been queued for push.
          // Safe on existing rows (NULL default).
          //
          // Guard `from >= 25`: as with the ulid block above, a < 25 upgrade
          // already has `sync_enqueued_at` from the current-schema createTable,
          // so re-adding it would throw "duplicate column name" (AUD-t-cross-62
          // follow-up). Only v25–v28 databases (pre-sync_enqueued_at) need it.
          await m.addColumn(pointsLedger, pointsLedger.syncEnqueuedAt);
          // Backfill the marker for rows that were ALREADY pushed under
          // v27/v28 (they carry a non-NULL `ulid`, which is stamped on insert
          // and was the deterministic cloud doc-id used to push them). Without
          // this, reEnqueueUnsyncedLedgerRows — which selects rows WHERE
          // sync_enqueued_at IS NULL AND ulid IS NOT NULL — would treat every
          // pre-existing synced row as "never queued" and re-push the entire
          // historical ledger on first post-upgrade launch (a needless one-time
          // outbox spike / burst of redundant Firestore writes). Stamping the
          // marker from created_at leaves only genuinely never-enqueued rows
          // (ulid NULL, or future rows) for the reconciliation to pick up.
          await customStatement(
            'UPDATE points_ledger '
            'SET sync_enqueued_at = created_at '
            'WHERE ulid IS NOT NULL AND sync_enqueued_at IS NULL',
          );
        }
        if (from < 30) {
          // Collision fix: lifetime level3/level4 scope marks were stored with
          // a BARE unitIdentifier (e.g. daf '2', no parent context), so a daf-2
          // mark in one masechta credited daf 2 in EVERY masechta (the "1.3%
          // after one daf" over-crediting bug). New marks store the QUALIFIED
          // path id (level1|level2|level3[|level4]). The legacy bare rows are
          // unrecoverable (the parent context was never persisted), so drop
          // them: rows whose scope (minus any 'unmark_' prefix) is a level3/
          // level4 scope AND whose unitIdentifier has no '|' separator.
          // level1/level2 (seder/masechta/sefer/siman) and sefariaRef/leaf rows
          // are unique and left untouched.
          // Guard: partial-schema migration paths (e.g. older upgrade tests)
          // may not have created learning_ledger yet, so only run when present.
          final hasLedger = await customSelect(
            // Guard on the entry_scope COLUMN, not merely the table: these are
            // legacy-bare-row cleanups keyed on entry_scope. A schema old enough
            // to lack that column (a pre-rename learning_ledger, or a partial
            // upgrade-test fixture) predates the bare-row problem entirely — so
            // there is nothing to clean and the DELETE must be skipped rather
            // than crash with "no such column: entry_scope".
            "SELECT 1 FROM pragma_table_info('learning_ledger') "
            "WHERE name = 'entry_scope'",
          ).get();
          if (hasLedger.isNotEmpty) {
            await customStatement(
              'DELETE FROM learning_ledger '
              "WHERE REPLACE(entry_scope, 'unmark_', '') IN "
              "('level3', 'perek', 'daf', 'halacha', 'pasuk', "
              "'level4', 'amud', 'mishna', 'seif', 'seif_katan') "
              'AND instr(unit_identifier, ?) = 0',
              [kScopeIdSeparator],
            );
          }
        }
        if (from < 31) {
          // Collision fix, part 2 (level2): v30 left level2 marks BARE on the
          // assumption level2 is unique within a curriculum. That holds for
          // Talmud/Mishnayos (level2 = masechta, globally unique) but NOT for
          // sefer>perek curricula (Chumash/Tanach/Nach: level2 = perek, and
          // perek '1' exists in all five chumashim). A bare level2 'perek 1'
          // mark therefore cross-credited perek 1 of every sefer (marking
          // Bereishis perek 1 credited 170 pesukim across all five sefarim).
          // New marks store the QUALIFIED path id (level1|level2). The legacy
          // bare level2 rows are unrecoverable (the parent sefer/seder was never
          // persisted), so drop them — same treatment v30 gave bare level3/4.
          final hasLedger = await customSelect(
            // Guard on the entry_scope COLUMN, not merely the table: these are
            // legacy-bare-row cleanups keyed on entry_scope. A schema old enough
            // to lack that column (a pre-rename learning_ledger, or a partial
            // upgrade-test fixture) predates the bare-row problem entirely — so
            // there is nothing to clean and the DELETE must be skipped rather
            // than crash with "no such column: entry_scope".
            "SELECT 1 FROM pragma_table_info('learning_ledger') "
            "WHERE name = 'entry_scope'",
          ).get();
          if (hasLedger.isNotEmpty) {
            // Only the current numeric 'level2' scope: legacy named level2
            // scopes that repeat (Chumash 'perek') were already swept by v30's
            // list, and level1 roots (seder/sefer) must NOT be touched.
            await customStatement(
              'DELETE FROM learning_ledger '
              "WHERE REPLACE(entry_scope, 'unmark_', '') = 'level2' "
              'AND instr(unit_identifier, ?) = 0',
              [kScopeIdSeparator],
            );
          }
        }
        if (from < 32) {
          // Composite over-credit fix (P0): a COMPOSITE curriculum (Tanach) is
          // assembled at runtime from real source curricula (Chumash + Nach)
          // with the Chumash books re-parented under a SYNTHETIC level1 section
          // container 'Torah' that exists in no real curriculum. A lifetime mark
          // recorded directly against that synthetic container —
          // `curriculum_id='tanach', entry_scope='level1', unit_identifier='Torah'`
          // — blanket-credited the ENTIRE Torah (all five chumashim, ~5846
          // pesukim) even when the user had only marked a single book. The
          // canonical place to record "I learned Torah/Chumash" is the real
          // `chumash` curriculum, which now propagates UP to Tanach by canonical
          // leaf (sefariaRef) via the subset-ledger union in
          // lifetime_knowledge_providers — so these synthetic-container rows are
          // redundant at best and an over-credit at worst.
          //
          // Conservative + reversible: scoped to the single known synthetic
          // preamble container (composite key 'tanach', level1 'Torah'). Real
          // marks (any chumash/nach row, any deeper Tanach scope, any other
          // curriculum) are left untouched. This does NOT delete legitimate
          // book/perek/pasuk marks — only the blanket synthetic-section row.
          // Guard: only run when learning_ledger exists (partial-schema upgrade
          // paths in older tests may not have created it yet).
          final hasLedger = await customSelect(
            // Guard on the entry_scope COLUMN, not merely the table: these are
            // legacy-bare-row cleanups keyed on entry_scope. A schema old enough
            // to lack that column (a pre-rename learning_ledger, or a partial
            // upgrade-test fixture) predates the bare-row problem entirely — so
            // there is nothing to clean and the DELETE must be skipped rather
            // than crash with "no such column: entry_scope".
            "SELECT 1 FROM pragma_table_info('learning_ledger') "
            "WHERE name = 'entry_scope'",
          ).get();
          if (hasLedger.isNotEmpty) {
            await customStatement(
              'DELETE FROM learning_ledger '
              "WHERE curriculum_id = 'tanach' "
              "AND REPLACE(entry_scope, 'unmark_', '') = 'level1' "
              "AND unit_identifier = 'Torah'",
            );
          }
        }
        if (from >= 26 && from < 28) {
          // Tutor "talmid view" mirror columns on learner_profiles (v28).
          // Guard: from >= 26 because migrations from v25 or earlier already
          // receive these columns via the v26 alterTable rebuild (columnTransformer
          // supplies literal defaults for all four tutor columns). A v26 database
          // skips that rebuild entirely (from < 26 is false), so we must addColumn
          // here. The guard from < 28 avoids double-adding on databases that were
          // already at v28 or later.
          await m.addColumn(learnerProfiles, learnerProfiles.isTutored);
          await m.addColumn(learnerProfiles, learnerProfiles.tutorParentUid);
          await m.addColumn(
            learnerProfiles,
            learnerProfiles.tutorRemoteProfileId,
          );
          await m.addColumn(learnerProfiles, learnerProfiles.tutorGrantId);
        }
        if (from < 33) {
          // AUD-guardrails-01: Goals lacked profileId in its profile-scoping
          // key (schema_check.dart whitelist gap). Additive, non-unique
          // composite index — no data loss, no uniqueness change.
          // Guard: partial-schema migration paths (e.g. older upgrade tests
          // that model only their own migration's tables) may not have
          // created `goals` yet, so only run when present — same pattern as
          // the `hasLedger` guards above.
          final hasGoals = await customSelect(
            'SELECT 1 FROM sqlite_master '
            "WHERE type = 'table' AND name = 'goals'",
          ).get();
          if (hasGoals.isNotEmpty) {
            await m.createIndex(goalsProfileCurriculum);
          }
        }
        if (from < 34) {
          // NB (AUD-t-cross-62 follow-up): unlike the ulid/sync_enqueued_at
          // COLUMNS, the points_ledger_profile_ulid @TableIndex is NOT created
          // by the `from < 25` createTable in this Drift version, so a pre-v25
          // upgrade genuinely needs the createIndex below — this block stays
          // ungated on `from` (only the addColumn branches above needed the
          // `from >= 25` guard). A freshly-created pre-v25 table simply has no
          // duplicate (profile_id, ulid) rows, so the dedup is a harmless no-op.
          //
          // AUD-core-database-03: points_ledger / reward_redemptions lacked
          // the UNIQUE(profileId, ulid) companion index every other
          // sync-able entity has (learning_ledger), leaving a
          // SELECT-then-INSERT TOCTOU window in which a racing merge
          // (concurrent pulls, a retried tutored pull) could double-credit
          // a child's points balance.
          // Guard: partial-schema migration paths (e.g. older upgrade
          // tests that model only their own migration's tables) may not
          // have created these tables yet — same pattern as the
          // hasLedger/hasGoals guards above.
          final hasPointsLedger = await customSelect(
            'SELECT 1 FROM sqlite_master '
            "WHERE type = 'table' AND name = 'points_ledger'",
          ).get();
          if (hasPointsLedger.isNotEmpty) {
            // Defensive dedup FIRST: a pre-existing duplicate
            // (profile_id, ulid) pair — the exact double-credit this
            // defect could already have produced on a device that hit the
            // race — would make CREATE UNIQUE INDEX fail outright. Keep
            // the lowest id per (profile_id, ulid) pair; NULL-ulid rows
            // (not yet backfilled by the Wave-B sync agent) are left
            // untouched — SQLite treats each NULL as distinct in a UNIQUE
            // index, so they can never collide (same as learning_ledger).
            //
            // Capture the affected profiles BEFORE deleting so the balance
            // re-derivation below only touches profiles whose ledger
            // actually had a duplicate removed.
            await customStatement(
              'CREATE TEMP TABLE _v34_ledger_dupe_profiles AS '
              'SELECT DISTINCT profile_id FROM points_ledger '
              'WHERE ulid IS NOT NULL AND id NOT IN ('
              '  SELECT MIN(id) FROM points_ledger '
              '  WHERE ulid IS NOT NULL GROUP BY profile_id, ulid'
              ')',
            );
            await customStatement(
              'DELETE FROM points_ledger '
              'WHERE ulid IS NOT NULL AND id NOT IN ('
              '  SELECT MIN(id) FROM points_ledger '
              '  WHERE ulid IS NOT NULL GROUP BY profile_id, ulid'
              ')',
            );
            await m.createIndex(pointsLedgerProfileUlid);
            // Re-derive points_balance for every profile that had a
            // duplicate removed, so no stale over-credit survives the
            // upgrade (mirrors PointsBalanceDao.reDeriveBalanceFromLedger:
            // sum of all remaining ledger deltas, clamped at 0). Guarded
            // separately: some partial-schema migration test fixtures model
            // points_ledger without points_balance.
            final hasPointsBalance = await customSelect(
              'SELECT 1 FROM sqlite_master '
              "WHERE type = 'table' AND name = 'points_balance'",
            ).get();
            if (hasPointsBalance.isNotEmpty) {
              await customStatement(
                'INSERT INTO points_balance (profile_id, balance, updated_at) '
                'SELECT pl.profile_id, '
                '       MAX(0, COALESCE(SUM(pl.delta), 0)), '
                "       CAST(strftime('%s','now') AS INTEGER) "
                'FROM points_ledger pl '
                'WHERE pl.profile_id IN '
                '  (SELECT profile_id FROM _v34_ledger_dupe_profiles) '
                'GROUP BY pl.profile_id '
                'ON CONFLICT(profile_id) DO UPDATE SET '
                '  balance = excluded.balance, '
                '  updated_at = excluded.updated_at',
              );
            }
            await customStatement('DROP TABLE _v34_ledger_dupe_profiles');
          }

          final hasRewardRedemptions = await customSelect(
            'SELECT 1 FROM sqlite_master '
            "WHERE type = 'table' AND name = 'reward_redemptions'",
          ).get();
          if (hasRewardRedemptions.isNotEmpty) {
            // Same defensive dedup for reward_redemptions. It is an LWW
            // state-machine (not append-only), so keep the row with the
            // latest `updated_at` per (profile_id, ulid), tie-broken by the
            // lowest id, rather than always keeping the lowest id.
            await customStatement(
              'DELETE FROM reward_redemptions '
              'WHERE ulid IS NOT NULL AND id NOT IN ('
              '  SELECT r1.id FROM reward_redemptions r1 '
              '  WHERE r1.id = ('
              '    SELECT r2.id FROM reward_redemptions r2 '
              '    WHERE r2.profile_id = r1.profile_id '
              '      AND r2.ulid = r1.ulid '
              '    ORDER BY r2.updated_at DESC, r2.id ASC LIMIT 1'
              '  )'
              ')',
            );
            await m.createIndex(rewardRedemptionsProfileUlid);
          }
        }
        if (from < 35) {
          // AUD-core-database-09: points_ledger.redemptionId was a
          // comment-only reference to reward_redemptions.id — nothing at
          // the DB layer stopped it from pointing at a nonexistent (or
          // wrong-profile) redemption row. Declare a real FK.
          // Guard: partial-schema migration paths (e.g. older upgrade
          // tests that model only their own migration's tables, such as
          // v27_to_v28_test / v27_to_v29_test which create points_ledger
          // WITHOUT reward_redemptions) may not have created one or both
          // tables yet — same pattern as the hasLedger/hasGoals/
          // hasPointsLedger guards above. On a real device both tables are
          // always created together (v25), so this only ever narrows what
          // partial test fixtures exercise, never real upgrades.
          final hasPointsLedgerV35 = await customSelect(
            'SELECT 1 FROM sqlite_master '
            "WHERE type = 'table' AND name = 'points_ledger'",
          ).get();
          final hasRewardRedemptionsV35 = await customSelect(
            'SELECT 1 FROM sqlite_master '
            "WHERE type = 'table' AND name = 'reward_redemptions'",
          ).get();
          if (hasPointsLedgerV35.isNotEmpty &&
              hasRewardRedemptionsV35.isNotEmpty) {
            await customStatement('PRAGMA foreign_keys = OFF');

            // Defensive cleanup FIRST: any pre-existing bogus redemptionId
            // (pointing at a reward_redemptions row that does not exist —
            // exactly the gap this migration closes could already have let
            // through) would make the rebuilt table's FK a lie the moment
            // it is created, and would trip the foreign_key_check below.
            // Legitimate rows (redemptionId NULL, or pointing at a real
            // redemption) are left untouched.
            await customStatement(
              'UPDATE points_ledger SET redemption_id = NULL '
              'WHERE redemption_id IS NOT NULL '
              'AND redemption_id NOT IN (SELECT id FROM reward_redemptions)',
            );

            // SQLite cannot ALTER TABLE an existing column to add a
            // REFERENCES clause, so this uses the same table-rebuild
            // recipe as v26/v34: alterTable re-creates the table from its
            // current Dart definition (now carrying the FK) and also
            // re-creates the table's indexes/triggers (the
            // points_ledger_profile_ulid UNIQUE index survives).
            await m.alterTable(TableMigration(pointsLedger));

            final orphans = await customSelect(
              'PRAGMA foreign_key_check',
            ).get();
            assert(
              orphans.isEmpty,
              'v35 migration orphaned ${orphans.length} row(s): '
              '${orphans.map((r) => r.data).toList()}',
            );

            await customStatement('PRAGMA foreign_keys = ON');
          }
        }
        if (from < 36) {
          // AUD-t-cross-06: track_learning_order was the one user_database
          // table with a bare autoincrement PK and no profileId — isolation
          // depended entirely on trackId never being confused across
          // profiles, with no schema-level guard. Backfill profileId from
          // the owning curriculum_tracks row, then rebuild with the new FK.
          // Guard: partial-schema migration paths (e.g. older upgrade tests
          // that model only their own migration's tables) may not have
          // created track_learning_order yet — same pattern as the
          // hasLedger/hasGoals/hasPointsLedger guards above.
          final hasTrackLearningOrder = await customSelect(
            'SELECT 1 FROM sqlite_master '
            "WHERE type = 'table' AND name = 'track_learning_order'",
          ).get();
          if (hasTrackLearningOrder.isNotEmpty) {
            await customStatement('PRAGMA foreign_keys = OFF');

            // Defensive cleanup FIRST: a row whose trackId no longer
            // resolves to a real curriculum_tracks row (e.g. a track
            // hard-deleted by an older app version — track_learning_order
            // was never cleaned up on track/profile delete before this fix)
            // has no profileId to backfill and is unrecoverable (the owning
            // profile is unknown), so it must be dropped or the rebuild's
            // NOT NULL profileId column would fail on it.
            await customStatement(
              'DELETE FROM track_learning_order '
              'WHERE track_id NOT IN (SELECT id FROM curriculum_tracks)',
            );

            // Backfill: profileId is the owning track's profileId, read via
            // a correlated subquery against curriculum_tracks (untouched by
            // this migration, so it still reflects the real owner).
            await m.alterTable(
              TableMigration(
                trackLearningOrder,
                columnTransformer: {
                  trackLearningOrder.profileId: const CustomExpression(
                    '(SELECT profile_id FROM curriculum_tracks '
                    'WHERE curriculum_tracks.id = track_learning_order.track_id)',
                  ),
                },
              ),
            );

            final orphans = await customSelect(
              'PRAGMA foreign_key_check',
            ).get();
            assert(
              orphans.isEmpty,
              'v36 migration orphaned ${orphans.length} row(s): '
              '${orphans.map((r) => r.data).toList()}',
            );

            await customStatement('PRAGMA foreign_keys = ON');
          }
        }
        if (from < 37) {
          // AUD-scheduler-15: completion_events.stage_id has always been
          // ambiguous — CompletionWriter only ever writes a stageOrder
          // ordinal, but older app versions wrote a stage_definitions.id.
          // Both value spaces are small positive integers that can
          // coincide (most sharply once StageDefinitionRepository.
          // reorderStages moves a stage's order away from its id), so
          // SchedulerCompletionRepositoryImpl.resolveStageOrder's per-read
          // "does this look like a known stageOrder" guess could silently
          // resolve to the WRONG stage.
          //
          // Additive nullable column (safe: existing rows get NULL, and
          // readers fall back to the historical guess for NULL rows —
          // unchanged behaviour, no regression). We then run a ONE-TIME
          // backfill that tags every row we CAN classify deterministically:
          //  - stage_id matches a CURRENT stageOrder for that row's own
          //    (profile_id, curriculum_id) -> 'stageOrder' (mirrors
          //    resolveStageOrder's pre-v37 priority, so already-correct
          //    rows stay correct).
          //  - else stage_id matches a CURRENT stage id for that row's own
          //    (profile_id, curriculum_id) -> 'legacyId' (the previously-
          //    ambiguous, now-disambiguated case).
          //  - else (the stage no longer exists) -> left NULL; already
          //    unresolvable today, unaffected.
          // A row whose stage_id coincidentally matches BOTH a stageOrder
          // and a different stage's id is tagged 'stageOrder' (same as
          // today's guess) — a true collision carries no surviving signal
          // to reconstruct after the fact, so this migration does not (and
          // cannot) resolve it, but it also does not regress it. No NEW
          // ambiguous row can ever be created again: CompletionWriter now
          // stamps every insert with an explicit tag.
          //
          // Guard: partial-schema migration paths (e.g. older upgrade tests
          // that model only their own migration's tables) may not have
          // created completion_events yet — same pattern as the
          // hasTrackLearningOrder guard above (v36) and the
          // hasLedger/hasGoals/hasPointsLedger guards elsewhere in this
          // method.
          final hasCompletionEvents = await customSelect(
            'SELECT 1 FROM sqlite_master '
            "WHERE type = 'table' AND name = 'completion_events'",
          ).get();
          if (hasCompletionEvents.isNotEmpty) {
            await m.addColumn(completionEvents, completionEvents.stageIdFormat);

            final hasStageDefinitions = await customSelect(
              'SELECT 1 FROM sqlite_master '
              "WHERE type = 'table' AND name = 'stage_definitions'",
            ).get();
            if (hasStageDefinitions.isNotEmpty) {
              await customStatement(
                "UPDATE completion_events SET stage_id_format = 'stageOrder' "
                'WHERE stage_id_format IS NULL AND EXISTS ('
                '  SELECT 1 FROM stage_definitions sd '
                '  WHERE sd.profile_id = completion_events.profile_id '
                '    AND sd.curriculum_id = completion_events.curriculum_id '
                '    AND sd.stage_order = completion_events.stage_id'
                ')',
              );
              await customStatement(
                "UPDATE completion_events SET stage_id_format = 'legacyId' "
                'WHERE stage_id_format IS NULL AND EXISTS ('
                '  SELECT 1 FROM stage_definitions sd '
                '  WHERE sd.profile_id = completion_events.profile_id '
                '    AND sd.curriculum_id = completion_events.curriculum_id '
                '    AND sd.id = completion_events.stage_id'
                ')',
              );
            }
          }
        }
        if (from < 38) {
          // Firestore-rewrite transition (Epic C): additive nullable `ulid`
          // column on learner_profiles, pairing a row's Drift autoincrement
          // id with its Firestore `learner_profiles/{ulid}` doc-id. Mirrors
          // the same additive-nullable-ULID shape v27 already added to
          // points_ledger/reward_redemptions — see this column's own doc
          // comment (`learner_profiles.dart`) for the full "why a column,
          // why nullable, why deleted with the Drift user database"
          // reasoning. Existing rows get NULL — "not yet migrated to
          // Firestore", not "no profile" (profile existence is, and always
          // was, governed by the row itself, never by this column).
          // Guard #1: partial-schema migration paths (e.g. older upgrade
          // tests that model only their own migration's tables) may not
          // have created learner_profiles yet — same pattern as every guard
          // above.
          final hasLearnerProfiles = await customSelect(
            'SELECT 1 FROM sqlite_master '
            "WHERE type = 'table' AND name = 'learner_profiles'",
          ).get();
          if (hasLearnerProfiles.isNotEmpty) {
            // Guard #2: a long-jump upgrade starting below v26 already hit
            // the `if (from < 26)` rebuild above, which
            // `TableMigration(learnerProfiles)`s from the LIVE (current)
            // Dart table definition — which already declares `ulid` — so
            // that rebuild has ALREADY materialised this column (as NULL,
            // same end state `addColumn` would produce) before execution
            // ever reaches here. Re-running `addColumn` in that case fails
            // with "duplicate column name: ulid" (SqliteException 1). A
            // short-hop upgrade starting at v26..v37 never went through
            // that rebuild, so its `learner_profiles` genuinely lacks the
            // column and `addColumn` is the only thing that adds it.
            final hasUlidColumn = await customSelect(
              "SELECT 1 FROM pragma_table_info('learner_profiles') "
              "WHERE name = 'ulid'",
            ).get();
            if (hasUlidColumn.isEmpty) {
              await m.addColumn(learnerProfiles, learnerProfiles.ulid);
            }
          }
        }
      },
    );
  }
}
