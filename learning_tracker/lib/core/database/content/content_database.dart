import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/content/daos/calendar_cycle_dao.dart';
import 'package:learning_tracker/core/database/content/daos/learning_program_dao.dart';
import 'package:learning_tracker/core/database/content/daos/seed_metadata_dao.dart';
import 'package:learning_tracker/core/database/content/daos/test_date_dao.dart';
import 'package:learning_tracker/core/database/content/daos/text_cache_dao.dart';
import 'package:learning_tracker/core/database/tables/calendar_cycles.dart';
import 'package:learning_tracker/core/database/tables/learning_programs.dart';
import 'package:learning_tracker/core/database/tables/seed_metadata.dart';
import 'package:learning_tracker/core/database/tables/test_dates.dart';
import 'package:learning_tracker/core/database/tables/text_cache.dart';

part 'content_database.g.dart';

/// Read-only database containing all bundled content.
///
/// This database ships as a pre-built seed file (`content.db.gz`) in the APK
/// and is replaced wholesale on app updates. It is never written to at runtime.
///
/// Tables:
/// - [TextCache]: ~52K rows of Sefaria text (Hebrew + English)
/// - [CalendarCycles]: ~30K rows of pre-computed calendar program cycles
/// - [LearningPrograms]: 9 program presets
/// - [SeedMetadata]: Version tracking for seed replacement
@DriftDatabase(
  tables: [
    TextCache,
    CalendarCycles,
    LearningPrograms,
    SeedMetadata,
    TestDates,
  ],
  daos: [
    ContentTextCacheDao,
    CalendarCycleDao,
    ContentLearningProgramDao,
    SeedMetadataDao,
    ContentTestDateDao,
  ],
)
class ContentDatabase extends _$ContentDatabase {
  ContentDatabase(super.e);

  @override
  int get schemaVersion => 1;

  // No migration strategy needed — DB is replaced, not migrated.
  // Drift requires schemaVersion but will call onCreate on a fresh file.
  // Since we copy a pre-built file, onCreate is never actually invoked
  // in production. In tests, NativeDatabase.memory() triggers onCreate.
}
