import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/active_curriculum_dao.dart';
import 'package:learning_tracker/core/database/daos/bookmark_dao.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/curriculum_scope_dao.dart';
import 'package:learning_tracker/core/database/daos/goal_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_ledger_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_order_dao.dart';
import 'package:learning_tracker/core/database/daos/point_config_dao.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/daos/profile_program_dao.dart';
import 'package:learning_tracker/core/database/daos/reward_dao.dart';
import 'package:learning_tracker/core/database/daos/reward_pool_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/daos/streak_dao.dart';
import 'package:learning_tracker/core/database/daos/study_day_config_dao.dart';
import 'package:learning_tracker/core/database/daos/sync_queue_dao.dart';
import 'package:learning_tracker/core/database/daos/test_score_dao.dart';
import 'package:learning_tracker/core/database/daos/text_download_status_dao.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/tables/active_curricula.dart';
import 'package:learning_tracker/core/database/tables/bookmarks.dart';
import 'package:learning_tracker/core/database/tables/completions.dart';
import 'package:learning_tracker/core/database/tables/curriculum_scopes.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/goals.dart';
import 'package:learning_tracker/core/database/tables/learning_ledger.dart';
import 'package:learning_tracker/core/database/tables/learning_order.dart';
import 'package:learning_tracker/core/database/tables/point_configs.dart';
import 'package:learning_tracker/core/database/tables/profile_programs.dart';
import 'package:learning_tracker/core/database/tables/profiles.dart';
import 'package:learning_tracker/core/database/tables/reward_pool_items.dart';
import 'package:learning_tracker/core/database/tables/reward_pools.dart';
import 'package:learning_tracker/core/database/tables/rewards.dart';
import 'package:learning_tracker/core/database/tables/stage_definitions.dart';
import 'package:learning_tracker/core/database/tables/streaks.dart';
import 'package:learning_tracker/core/database/tables/study_day_configs.dart';
import 'package:learning_tracker/core/database/tables/sync_queue.dart';
import 'package:learning_tracker/core/database/tables/test_scores.dart';
import 'package:learning_tracker/core/database/tables/text_download_status.dart';
import 'package:learning_tracker/core/database/tables/user_profiles.dart';

part 'user_database.g.dart';

/// Mutable database containing all user data.
///
/// This database uses standard Drift migrations and holds all user-generated
/// content: profiles, progress, configuration, gamification, and sync state.
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
    LearningLedger,
    Bookmarks,
    LearningOrder,
    Goals,
    Rewards,
    RewardPools,
    RewardPoolItems,
    Streaks,
    SyncQueue,
    TextDownloadStatuses,
    TestScores,
  ],
  daos: [
    ActiveCurriculumDao,
    CurriculumScopeDao,
    CompletionDao,
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
    RewardDao,
    RewardPoolDao,
    SyncQueueDao,
    TextDownloadStatusDao,
    TestScoreDao,
    StudyDayConfigDao,
    ProfileProgramDao,
  ],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
    );
  }
}
