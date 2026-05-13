import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/active_curriculum_dao.dart';
import 'package:learning_tracker/core/database/daos/bookmark_dao.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/curriculum_scope_dao.dart';
import 'package:learning_tracker/core/database/daos/daily_plan_dao.dart';
import 'package:learning_tracker/core/database/daos/goal_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_ledger_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_order_dao.dart';
import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/database/daos/point_config_dao.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/daos/profile_program_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/daos/streak_dao.dart';
import 'package:learning_tracker/core/database/daos/study_day_config_dao.dart';
import 'package:learning_tracker/core/database/daos/sync_queue_dao.dart';
import 'package:learning_tracker/core/database/daos/text_download_status_dao.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/daos/track_learning_order_dao.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/tables/accounts.dart';
import 'package:learning_tracker/core/database/tables/bookmarks.dart';
import 'package:learning_tracker/core/database/tables/completions.dart';
import 'package:learning_tracker/core/database/tables/curriculum_scopes.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/daily_plans.dart';
import 'package:learning_tracker/core/database/tables/goals.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';
import 'package:learning_tracker/core/database/tables/learning_ledger.dart';
import 'package:learning_tracker/core/database/tables/learning_order.dart';
import 'package:learning_tracker/core/database/tables/outbox_table.dart';
import 'package:learning_tracker/core/database/tables/point_configs.dart';
import 'package:learning_tracker/core/database/tables/profile_programs.dart';
import 'package:learning_tracker/core/database/tables/stage_definitions.dart';
import 'package:learning_tracker/core/database/tables/streak_events.dart';
import 'package:learning_tracker/core/database/tables/streaks.dart';
import 'package:learning_tracker/core/database/tables/study_day_configs.dart';
import 'package:learning_tracker/core/database/tables/sync_queue.dart';
import 'package:learning_tracker/core/database/tables/text_download_status.dart';
import 'package:learning_tracker/core/database/tables/track_learning_order.dart';

part 'user_database.g.dart';

/// Mutable database containing all user data.
///
/// Schema v1 (DNI-322, E25 wipe-install boundary):
/// - Tables renamed: UserProfiles → Accounts, Profiles → LearnerProfiles
/// - profileId is now required (no withDefault) on all profile-scoped tables
/// - Bookmarks uses trackId FK instead of trackType TEXT
/// - schemaVersion bumped to 12; all old migration steps deleted
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
    Completions,
    DailyPlans,
    LearningLedger,
    Bookmarks,
    LearningOrder,
    TrackLearningOrder,
    Goals,
    Streaks,
    StreakEvents,
    SyncQueue,
    TextDownloadStatuses,
    Outbox,
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
    TrackLearningOrderDao,
    TrackDao,
    ProfileDao,
    UserProfileDao,
    StreakDao,
    SyncQueueDao,
    TextDownloadStatusDao,
    StudyDayConfigDao,
    ProfileProgramDao,
    OutboxDao,
  ],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.e);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) => m.createAll(),
    );
  }
}
