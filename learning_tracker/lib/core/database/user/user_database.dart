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
/// Schema v26 (WS9.enum):
/// - Added CHECK constraint on learner_profiles.mode: only 'adult' | 'child'
///   are valid values. Enforced at DB level; the old free-text column accepted
///   any string. No data migration needed (all existing rows use 'adult' or
///   'child'). SQLite does not support adding a CHECK constraint via ALTER
///   TABLE, so we recreate the table in-place for upgraded DBs.
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
  int get schemaVersion => 26;

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
      // WS9 (v26): added CHECK constraint on learner_profiles.mode.
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 25) {
          await m.createTable(pointsBalance);
          await m.createTable(pointsLedger);
          await m.createTable(rewardRedemptions);
        }
        if (from < 26) {
          // WS9.enum: rebuild learner_profiles to add the CHECK constraint on
          // the mode column (SQLite cannot add CHECK via ALTER TABLE).
          await m.deleteTable('learner_profiles');
          await m.createTable(learnerProfiles);
          // WS9.flows: rebuild accounts to drop the vestigial user_mode column.
          // Mode belongs to learner_profiles.mode, not to an account.
          await m.deleteTable('accounts');
          await m.createTable(accounts);
        }
      },
    );
  }
}
