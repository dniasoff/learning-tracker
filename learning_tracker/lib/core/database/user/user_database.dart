import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/active_curriculum_dao.dart';
import 'package:learning_tracker/core/database/daos/bookmark_dao.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/curriculum_scope_dao.dart';
import 'package:learning_tracker/core/database/daos/daily_plan_dao.dart';
import 'package:learning_tracker/core/database/daos/goal_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_ledger_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_order_dao.dart';
import 'package:learning_tracker/core/database/daos/point_config_dao.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/daos/profile_program_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/daos/streak_dao.dart';
import 'package:learning_tracker/core/database/daos/study_day_config_dao.dart';
import 'package:learning_tracker/core/database/daos/sync_queue_dao.dart';
import 'package:learning_tracker/core/database/daos/text_download_status_dao.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/tables/active_curricula.dart';
import 'package:learning_tracker/core/database/tables/bookmarks.dart';
import 'package:learning_tracker/core/database/tables/completions.dart';
import 'package:learning_tracker/core/database/tables/curriculum_scopes.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/daily_plans.dart';
import 'package:learning_tracker/core/database/tables/goals.dart';
import 'package:learning_tracker/core/database/tables/learning_ledger.dart';
import 'package:learning_tracker/core/database/tables/learning_order.dart';
import 'package:learning_tracker/core/database/tables/point_configs.dart';
import 'package:learning_tracker/core/database/tables/profile_programs.dart';
import 'package:learning_tracker/core/database/tables/profiles.dart';
import 'package:learning_tracker/core/database/tables/stage_definitions.dart';
import 'package:learning_tracker/core/database/tables/streak_events.dart';
import 'package:learning_tracker/core/database/tables/streaks.dart';
import 'package:learning_tracker/core/database/tables/study_day_configs.dart';
import 'package:learning_tracker/core/database/tables/sync_queue.dart';
import 'package:learning_tracker/core/database/tables/text_download_status.dart';
import 'package:learning_tracker/core/database/tables/user_profiles.dart';

part 'user_database.g.dart';

/// Mutable database containing all user data.
///
/// This database uses standard Drift migrations and holds all user-generated
/// content: profiles, progress, configuration, streaks, and sync state.
/// It is the only database that accepts writes at runtime.
@DriftDatabase(
  tables: [
    UserProfiles,
    Profiles,
    ActiveCurricula,
    CurriculumTracks,
    CurriculumScopes,
    ProfilePrograms,
    StageDefinitions,
    PointConfigs,
    StudyDayConfigs,
    Completions,
    DailyPlans,
    LearningLedger,
    Bookmarks,
    LearningOrder,
    Goals,
    Streaks,
    StreakEvents,
    SyncQueue,
    TextDownloadStatuses,
  ],
  daos: [
    ActiveCurriculumDao,
    CurriculumScopeDao,
    CompletionDao,
    DailyPlanDao,
    LearningLedgerDao,
    GoalDao,
    PointConfigDao,
    StageDao,
    BookmarkDao,
    LearningOrderDao,
    TrackDao,
    ProfileDao,
    UserProfileDao,
    StreakDao,
    SyncQueueDao,
    TextDownloadStatusDao,
    StudyDayConfigDao,
    ProfileProgramDao,
  ],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // v2 → v3: Epic 23 (DNI-223) hard-tier auth refactor.
        // Drops the anonymous-localUid schema and rebuilds UserProfiles
        // with email + passwordHash + tier. Pre-launch data is wiped —
        // any user must re-sign-up post-upgrade.
        // Originally filed in Linear as "Epic 20"; renamed to Epic 23
        // on 2026-04-19 to resolve the DNI-210 / DNI-223 numbering
        // collision.
        if (from < 3) {
          await m.deleteTable('user_profiles');
          await m.createTable(userProfiles);
        }
        // v3 → v4: Epic 23 event log for streaks + XP (see v2 spec §4.1
        // conflict resolution). Append-only tables; no backfill —
        // existing state tables remain authoritative until a synthetic
        // "initial state" event is written per profile in a follow-up.
        if (from < 4) {
          await m.createTable(streakEvents);
        }
        // v4 → v5: V1 simplification — drop rewards, reward_pools,
        // reward_pool_items, xp_events, and test_scores. Points now
        // derive from completions.points directly; rewards system
        // removed entirely.
        if (from < 5) {
          await m.deleteTable('rewards');
          await m.deleteTable('reward_pools');
          await m.deleteTable('reward_pool_items');
          await m.deleteTable('xp_events');
          await m.deleteTable('test_scores');
        }
        // v5 → v6: daily_plans snapshot table — today's task list is
        // materialized once per local day; completions no longer regenerate
        // the plan.
        if (from < 6) {
          await m.createTable(dailyPlans);
        }
      },
    );
  }
}
