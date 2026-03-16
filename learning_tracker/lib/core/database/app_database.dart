import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/active_curriculum_dao.dart';
import 'package:learning_tracker/core/database/daos/bookmark_dao.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/goal_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_order_dao.dart';
import 'package:learning_tracker/core/database/daos/point_config_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/daos/sync_queue_dao.dart';
import 'package:learning_tracker/core/database/daos/text_cache_dao.dart';
import 'package:learning_tracker/core/database/daos/text_download_status_dao.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/tables/active_curricula.dart';
import 'package:learning_tracker/core/database/tables/bookmarks.dart';
import 'package:learning_tracker/core/database/tables/completions.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/goals.dart';
import 'package:learning_tracker/core/database/tables/learning_order.dart';
import 'package:learning_tracker/core/database/tables/point_configs.dart';
import 'package:learning_tracker/core/database/tables/rewards.dart';
import 'package:learning_tracker/core/database/tables/stage_definitions.dart';
import 'package:learning_tracker/core/database/tables/sync_queue.dart';
import 'package:learning_tracker/core/database/tables/text_cache.dart';
import 'package:learning_tracker/core/database/tables/text_download_status.dart';
import 'package:learning_tracker/core/database/tables/user_profiles.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    ActiveCurricula,
    CurriculumTracks,
    StageDefinitions,
    Completions,
    Bookmarks,
    Goals,
    LearningOrder,
    PointConfigs,
    UserProfiles,
    Rewards,
    SyncQueue,
    TextCache,
    TextDownloadStatuses,
  ],
  daos: [
    ActiveCurriculumDao,
    CompletionDao,
    GoalDao,
    PointConfigDao,
    StageDao,
    BookmarkDao,
    LearningOrderDao,
    TrackDao,
    UserProfileDao,
    SyncQueueDao,
    TextCacheDao,
    TextDownloadStatusDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
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
      },
    );
  }
}
