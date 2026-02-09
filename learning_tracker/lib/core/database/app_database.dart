import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/active_curriculum_dao.dart';
import 'package:learning_tracker/core/database/daos/bookmark_dao.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/content_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_order_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/daos/sync_queue_dao.dart';
import 'package:learning_tracker/core/database/tables/active_curricula.dart';
import 'package:learning_tracker/core/database/tables/bookmarks.dart';
import 'package:learning_tracker/core/database/tables/completions.dart';
import 'package:learning_tracker/core/database/tables/content_items.dart';
import 'package:learning_tracker/core/database/tables/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/learning_order.dart';
import 'package:learning_tracker/core/database/tables/rewards.dart';
import 'package:learning_tracker/core/database/tables/stage_definitions.dart';
import 'package:learning_tracker/core/database/tables/user_profiles.dart';
import 'package:learning_tracker/core/database/tables/sync_queue.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    ActiveCurricula,
    ContentItems,
    CurriculumHierarchyConfig,
    CurriculumTracks,
    StageDefinitions,
    Completions,
    Bookmarks,
    LearningOrder,
    UserProfiles,
    Rewards,
    SyncQueue,
  ],
  daos: [
    ActiveCurriculumDao,
    ContentDao,
    CompletionDao,
    StageDao,
    BookmarkDao,
    LearningOrderDao,
    TrackDao,
    UserProfileDao,
    SyncQueueDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;
}
