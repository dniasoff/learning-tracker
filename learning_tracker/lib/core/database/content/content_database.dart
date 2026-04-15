import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/content/daos/seed_metadata_dao.dart';
import 'package:learning_tracker/core/database/content/daos/text_cache_dao.dart';
import 'package:learning_tracker/core/database/tables/seed_metadata.dart';
import 'package:learning_tracker/core/database/tables/text_cache.dart';

part 'content_database.g.dart';

/// Read-only database containing bundled Sefaria text content.
///
/// Ships as a pre-built seed file (`content.db.gz`) in the APK.
///
/// Tables:
/// - [TextCache]: ~52K rows of Sefaria text (Hebrew + English)
/// - [SeedMetadata]: Version tracking for seed replacement
///
/// Calendar cycles, learning programs, and test dates are now computed at
/// runtime — see [LocalCalendarEngine], [learningProgramSeeds], and
/// [generateTestDateSeeds].
@DriftDatabase(
  tables: [TextCache, SeedMetadata],
  daos: [ContentTextCacheDao, SeedMetadataDao],
)
class ContentDatabase extends _$ContentDatabase {
  ContentDatabase(super.e);

  /// Open from a prepared seed file in read-only mode.
  factory ContentDatabase.openReadOnly(File file) {
    return ContentDatabase(
      NativeDatabase(
        file,
        setup: (db) {
          db.execute('PRAGMA query_only = ON');
        },
      ),
    );
  }

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(seedMetadata, seedMetadata.contentHash);
          await m.addColumn(seedMetadata, seedMetadata.minAppVersion);
        }
        if (from < 3) {
          // v3: calendar_cycles, learning_programs, test_dates moved to
          // runtime computation. Drop the tables if they exist.
          for (final table in [
            'calendar_cycles',
            'learning_programs',
            'test_dates',
          ]) {
            try {
              await customStatement('DROP TABLE IF EXISTS $table');
            } catch (_) {}
          }
        }
      },
    );
  }
}
