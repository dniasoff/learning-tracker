import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/active_curriculum_dao.dart';
import 'package:learning_tracker/core/database/daos/bookmark_dao.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/content_download_status_dao.dart';
import 'package:learning_tracker/core/database/daos/curriculum_scope_dao.dart';
import 'package:learning_tracker/core/database/daos/goal_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_ledger_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_order_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_program_dao.dart';
import 'package:learning_tracker/core/database/daos/point_config_dao.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/daos/profile_program_dao.dart';
import 'package:learning_tracker/core/database/daos/reward_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/daos/streak_dao.dart';
import 'package:learning_tracker/core/database/daos/sync_queue_dao.dart';
import 'package:learning_tracker/core/database/daos/test_date_dao.dart';
import 'package:learning_tracker/core/database/daos/test_score_dao.dart';
import 'package:learning_tracker/core/database/daos/text_cache_dao.dart';
import 'package:learning_tracker/core/database/daos/text_download_status_dao.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/seed/learning_program_seeds.dart';
import 'package:learning_tracker/core/database/seed/test_date_seeds.dart';
import 'package:learning_tracker/core/database/tables/active_curricula.dart';
import 'package:learning_tracker/core/database/tables/bookmarks.dart';
import 'package:learning_tracker/core/database/tables/completions.dart';
import 'package:learning_tracker/core/database/tables/content_download_statuses.dart';
import 'package:learning_tracker/core/database/tables/curriculum_scopes.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/goals.dart';
import 'package:learning_tracker/core/database/tables/learning_ledger.dart';
import 'package:learning_tracker/core/database/tables/learning_order.dart';
import 'package:learning_tracker/core/database/tables/learning_programs.dart';
import 'package:learning_tracker/core/database/tables/point_configs.dart';
import 'package:learning_tracker/core/database/tables/profile_programs.dart';
import 'package:learning_tracker/core/database/tables/profiles.dart';
import 'package:learning_tracker/core/database/tables/rewards.dart';
import 'package:learning_tracker/core/database/tables/stage_definitions.dart';
import 'package:learning_tracker/core/database/tables/streaks.dart';
import 'package:learning_tracker/core/database/tables/sync_queue.dart';
import 'package:learning_tracker/core/database/tables/test_dates.dart';
import 'package:learning_tracker/core/database/tables/test_scores.dart';
import 'package:learning_tracker/core/database/tables/text_cache.dart';
import 'package:learning_tracker/core/database/tables/text_download_status.dart';
import 'package:learning_tracker/core/database/tables/user_profiles.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    ActiveCurricula,
    CurriculumScopes,
    CurriculumTracks,
    StageDefinitions,
    Completions,
    LearningLedger,
    Bookmarks,
    Goals,
    LearningOrder,
    PointConfigs,
    Profiles,
    UserProfiles,
    Rewards,
    SyncQueue,
    TextCache,
    Streaks,
    TextDownloadStatuses,
    ContentDownloadStatuses,
    LearningPrograms,
    ProfilePrograms,
    TestDates,
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
    SyncQueueDao,
    TextCacheDao,
    TextDownloadStatusDao,
    ContentDownloadStatusDao,
    LearningProgramDao,
    ProfileProgramDao,
    TestDateDao,
    TestScoreDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedLearningPrograms();
        await _seedTestDates();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 3) {
          // Migration from schema v2 to v3: Remove content_items and
          // curriculum_hierarchy_config tables, change FK columns to sefariaRef

          // Step 1: Create temporary tables with new schema
          await m.createTable($CompletionsTable(attachedDatabase));
          await m.createTable($BookmarksTable(attachedDatabase));
          await m.createTable($LearningOrderTable(attachedDatabase));

          // Step 2: Migrate data from old tables (requires content lookup)
          // This is handled by a separate data migration script since we need
          // to map contentItemId -> sefariaRef using the old content_items table

          // For now, we'll drop and recreate (data loss acceptable for dev)
          // Production migration would need custom SQL to preserve data

          await customStatement('DROP TABLE IF EXISTS completions');
          await customStatement('DROP TABLE IF EXISTS bookmarks');
          await customStatement('DROP TABLE IF EXISTS learning_order');
          await customStatement('DROP TABLE IF EXISTS content_items');
          await customStatement(
            'DROP TABLE IF EXISTS curriculum_hierarchy_config',
          );

          // Recreate with new schema
          await m.createTable($CompletionsTable(attachedDatabase));
          await m.createTable($BookmarksTable(attachedDatabase));
          await m.createTable($LearningOrderTable(attachedDatabase));
        }
        if (from < 4) {
          // Migration from schema v3 to v4: Add text_download_statuses table
          await m.createTable($TextDownloadStatusesTable(attachedDatabase));
        }
        if (from < 5) {
          // Migration from schema v4 to v5: Add goals table
          await m.createTable($GoalsTable(attachedDatabase));
        }
        if (from < 6) {
          // Migration from schema v5 to v6: Add point_configs table
          await m.createTable($PointConfigsTable(attachedDatabase));
        }
        if (from < 7) {
          // Migration from schema v6 to v7: Add streaks table
          await m.createTable($StreaksTable(attachedDatabase));
        }
        if (from < 8) {
          // Migration from schema v7 to v8: Add rewards table
          await m.createTable($RewardsTable(attachedDatabase));
        }
        if (from < 9) {
          // Migration from schema v8 to v9: Add updatedAt column to rewards
          await customStatement(
            'ALTER TABLE rewards ADD COLUMN updated_at INTEGER NOT NULL '
            "DEFAULT (strftime('%s', 'now'))",
          );
        }
        if (from < 10) {
          // Migration from schema v9 to v10: Multi-profile support
          // Step 1: Create profiles table
          await m.createTable($ProfilesTable(attachedDatabase));

          // Step 2: Create default profile for each existing user
          await customStatement(
            'INSERT INTO profiles (account_id, display_name, mode, avatar_index, created_at, updated_at) '
            'SELECT id, display_name, user_mode, 0, created_at, updated_at FROM user_profiles',
          );

          // If no user profiles exist, create a fallback default profile
          await customStatement(
            'INSERT INTO profiles (account_id, display_name, mode, avatar_index, created_at, updated_at) '
            "SELECT 0, 'Default', 'adult', 0, strftime('%s', 'now'), strftime('%s', 'now') "
            'WHERE NOT EXISTS (SELECT 1 FROM profiles)',
          );

          // Step 3: Add profile_id column to all data tables with default = first profile id
          final tables = [
            'completions',
            'bookmarks',
            'goals',
            'rewards',
            'stage_definitions',
            'streaks',
            'learning_order',
            'point_configs',
          ];
          for (final table in tables) {
            await customStatement(
              'ALTER TABLE $table ADD COLUMN profile_id INTEGER NOT NULL '
              'DEFAULT 1',
            );
          }

          // Step 4: Recreate active_curricula and curriculum_tracks with profile_id in PK
          // Active curricula: backup, drop, recreate, restore
          await customStatement(
            'CREATE TABLE active_curricula_backup AS SELECT * FROM active_curricula',
          );
          await customStatement('DROP TABLE active_curricula');
          await m.createTable($ActiveCurriculaTable(attachedDatabase));
          await customStatement(
            'INSERT INTO active_curricula (profile_id, curriculum_id, activated_at) '
            'SELECT (SELECT MIN(id) FROM profiles), curriculum_id, activated_at FROM active_curricula_backup',
          );
          await customStatement('DROP TABLE active_curricula_backup');

          // Curriculum tracks: backup, drop, recreate, restore
          await customStatement(
            'CREATE TABLE curriculum_tracks_backup AS SELECT * FROM curriculum_tracks',
          );
          await customStatement('DROP TABLE curriculum_tracks');
          await m.createTable($CurriculumTracksTable(attachedDatabase));
          await customStatement(
            'INSERT INTO curriculum_tracks (profile_id, curriculum_id, track_type, is_active, activated_at, deactivated_at) '
            'SELECT (SELECT MIN(id) FROM profiles), curriculum_id, track_type, is_active, activated_at, deactivated_at FROM curriculum_tracks_backup',
          );
          await customStatement('DROP TABLE curriculum_tracks_backup');

          // Step 5: Update profile_id in all tables to the actual first profile id
          await customStatement(
            'UPDATE completions SET profile_id = (SELECT MIN(id) FROM profiles) WHERE profile_id = 1',
          );
          await customStatement(
            'UPDATE bookmarks SET profile_id = (SELECT MIN(id) FROM profiles) WHERE profile_id = 1',
          );
          await customStatement(
            'UPDATE goals SET profile_id = (SELECT MIN(id) FROM profiles) WHERE profile_id = 1',
          );
          await customStatement(
            'UPDATE rewards SET profile_id = (SELECT MIN(id) FROM profiles) WHERE profile_id = 1',
          );
          await customStatement(
            'UPDATE stage_definitions SET profile_id = (SELECT MIN(id) FROM profiles) WHERE profile_id = 1',
          );
          await customStatement(
            'UPDATE streaks SET profile_id = (SELECT MIN(id) FROM profiles) WHERE profile_id = 1',
          );
          await customStatement(
            'UPDATE learning_order SET profile_id = (SELECT MIN(id) FROM profiles) WHERE profile_id = 1',
          );
          await customStatement(
            'UPDATE point_configs SET profile_id = (SELECT MIN(id) FROM profiles) WHERE profile_id = 1',
          );
        }
        if (from < 11) {
          // Migration from schema v10 to v11: Add content_download_statuses table
          await m.createTable($ContentDownloadStatusesTable(attachedDatabase));
        }
        if (from < 12) {
          // Migration from schema v11 to v12: Add learning_programs and profile_programs tables
          await m.createTable($LearningProgramsTable(attachedDatabase));
          await m.createTable($ProfileProgramsTable(attachedDatabase));
          await _seedLearningPrograms();
        }
        if (from < 13) {
          // Migration from schema v12 to v13: Add test_dates, test_scores,
          // and expanded stage scheduling columns
          await m.createTable($TestDatesTable(attachedDatabase));
          await m.createTable($TestScoresTable(attachedDatabase));
          await _seedTestDates();
          await customStatement(
            "ALTER TABLE stage_definitions ADD COLUMN schedule_type TEXT NOT NULL DEFAULT 'delay'",
          );
          await customStatement(
            'ALTER TABLE stage_definitions ADD COLUMN days_of_week TEXT',
          );
          await customStatement(
            'ALTER TABLE stage_definitions ADD COLUMN rolling_window_size INTEGER',
          );
        }
        if (from < 14) {
          // Migration from schema v13 to v14: Add curriculum_scopes table
          await m.createTable($CurriculumScopesTable(attachedDatabase));
        }
        if (from < 15) {
          // Migration from schema v14 to v15: Add learning_ledger table
          await m.createTable($LearningLedgerTable(attachedDatabase));
        }
      },
    );
  }

  /// Seeds test dates for Dirshu programs (first Sunday of each month).
  Future<void> _seedTestDates() async {
    final seeds = generateTestDateSeeds();
    for (final seed in seeds) {
      // Look up program ID by name
      final program =
          await (select($LearningProgramsTable(attachedDatabase))
                ..where((t) => t.name.equals(seed['program_name']! as String)))
              .getSingleOrNull();
      if (program != null) {
        await into($TestDatesTable(attachedDatabase)).insert(
          TestDatesCompanion.insert(
            programId: program.id,
            testDate: seed['test_date']! as DateTime,
            materialDescription: Value(seed['material_description']! as String),
          ),
        );
      }
    }
  }

  /// Seeds the 9 learning program presets into the database.
  Future<void> _seedLearningPrograms() async {
    final now = DateTime.now().toUtc();
    for (final seed in learningProgramSeeds) {
      await into($LearningProgramsTable(attachedDatabase)).insert(
        LearningProgramsCompanion.insert(
          name: seed['name']! as String,
          displayName: seed['display_name']! as String,
          description: Value(seed['description']! as String),
          curriculumType: seed['curriculum_type']! as String,
          isActive: Value(seed['is_active']! as bool),
          stagesConfig: seed['stages_config']! as String,
          hasTests: Value(seed['has_tests']! as bool),
          testConfig: Value(seed['test_config']! as String),
          createdAt: now,
        ),
      );
    }
  }
}
