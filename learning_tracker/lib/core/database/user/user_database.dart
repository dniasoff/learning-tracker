import 'package:drift/drift.dart';
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
import 'package:learning_tracker/core/database/tables/outbox_table.dart';
import 'package:learning_tracker/core/database/tables/point_configs.dart';
import 'package:learning_tracker/core/database/tables/points_balance.dart';
import 'package:learning_tracker/core/database/tables/prior_completion_imports.dart';
import 'package:learning_tracker/core/database/tables/profile_programs.dart';
import 'package:learning_tracker/core/database/tables/sacred_window_entries.dart';
import 'package:learning_tracker/core/database/tables/stage_definitions.dart';
import 'package:learning_tracker/core/database/tables/streak_events.dart';
import 'package:learning_tracker/core/database/tables/study_day_configs.dart';
import 'package:learning_tracker/core/database/tables/sync_kv.dart';
import 'package:learning_tracker/core/database/tables/text_download_status.dart';
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
  int get schemaVersion => 28;

  // drift_dev cannot express WHERE in a Dart-defined view's `as()` body
  // (cascade `..where()` confuses the generator).  The auto-generated SQL for
  // completions_view therefore omits the filter.  We drop and recreate the
  // view with this explicit SQL on fresh install.
  static const _completionsViewSql =
      'CREATE VIEW completions_view AS '
      'SELECT id, profile_id, curriculum_id, sefaria_ref, stage_id, '
      'track_type, track_id, points, event_timestamp '
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
          await m.alterTable(
            TableMigration(learnerProfiles),
          );

          // (b) accounts → drop the vestigial user_mode column. The new
          //     `accounts` table definition has no userMode; copying only the
          //     surviving columns drops it while keeping all rows + ids.
          await m.alterTable(
            TableMigration(accounts),
          );

          // Integrity gate: no child row may be orphaned by the rebuilds.
          final orphans = await customSelect(
            'PRAGMA foreign_key_check',
          ).get();
          assert(
            orphans.isEmpty,
            'v26 migration orphaned ${orphans.length} row(s): '
            '${orphans.map((r) => r.data).toList()}',
          );

          await customStatement('PRAGMA foreign_keys = ON');
        }
        if (from < 27) {
          // WS9 Wave-B prep: additive nullable columns for points cloud sync.
          // Safe on existing rows (NULL default); Wave-B backfills/populates.
          await m.addColumn(pointsLedger, pointsLedger.ulid);
          await m.addColumn(rewardRedemptions, rewardRedemptions.ulid);
        }
        if (from < 28) {
          // Tutor "talmid view" mirror columns on learner_profiles. Additive +
          // nullable/defaulted, safe on existing rows.
          await m.addColumn(learnerProfiles, learnerProfiles.isTutored);
          await m.addColumn(learnerProfiles, learnerProfiles.tutorParentUid);
          await m.addColumn(
            learnerProfiles,
            learnerProfiles.tutorRemoteProfileId,
          );
          await m.addColumn(learnerProfiles, learnerProfiles.tutorGrantId);
        }
      },
    );
  }
}
