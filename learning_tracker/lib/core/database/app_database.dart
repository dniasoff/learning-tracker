import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/bookmark_dao.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/content_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_order_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/tables/bookmarks.dart';
import 'package:learning_tracker/core/database/tables/completions.dart';
import 'package:learning_tracker/core/database/tables/content_items.dart';
import 'package:learning_tracker/core/database/tables/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/database/tables/learning_order.dart';
import 'package:learning_tracker/core/database/tables/rewards.dart';
import 'package:learning_tracker/core/database/tables/stage_definitions.dart';
import 'package:learning_tracker/core/database/tables/user_profiles.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    ContentItems,
    CurriculumHierarchyConfig,
    StageDefinitions,
    Completions,
    Bookmarks,
    LearningOrder,
    UserProfiles,
    Rewards,
  ],
  daos: [
    ContentDao,
    CompletionDao,
    StageDao,
    BookmarkDao,
    LearningOrderDao,
    UserProfileDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
