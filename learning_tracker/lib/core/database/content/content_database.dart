import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/content/daos/calendar_cycle_dao.dart';
import 'package:learning_tracker/core/database/content/daos/seed_metadata_dao.dart';
import 'package:learning_tracker/core/database/content/daos/text_cache_dao.dart';
import 'package:learning_tracker/core/database/tables/calendar_cycles.dart';
import 'package:learning_tracker/core/database/tables/seed_metadata.dart';
import 'package:learning_tracker/core/database/tables/text_cache.dart';

part 'content_database.g.dart';

/// Read-only database containing bundled content.
///
/// Ships as a pre-built seed file (`content.db.gz`) in the APK.
///
/// Tables:
/// - [TextCache]: ~52K rows of Sefaria text (Hebrew + English)
/// - [CalendarCycles]: ~35K rows of pre-computed calendar program cycles
/// - [SeedMetadata]: Version tracking for seed replacement
///
/// Learning programs and test dates are computed at runtime — see
/// [LearningProgramRepository] and [generateTestDateSeeds].
@DriftDatabase(
  tables: [TextCache, CalendarCycles, SeedMetadata],
  daos: [ContentTextCacheDao, CalendarCycleDao, SeedMetadataDao],
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

  /// The schema version the running code expects. Exposed as a const so
  /// [SeedManager] can compare against the on-device DB without instantiating
  /// Drift (which would otherwise trigger migrations against a read-only
  /// seed).
  static const int expectedSchemaVersion = 4;

  @override
  int get schemaVersion => expectedSchemaVersion;

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
          // v3: learning_programs + test_dates moved to runtime.
          // calendar_cycles stays. Create it if missing (upgrading from v2
          // where it already exists is a no-op).
          try {
            await customStatement(
              'CREATE TABLE IF NOT EXISTS calendar_cycles ('
              'program_key TEXT NOT NULL, '
              'date_key TEXT NOT NULL, '
              'sefaria_ref TEXT NOT NULL, '
              'display_name TEXT NOT NULL DEFAULT \'\', '
              'PRIMARY KEY (program_key, date_key))',
            );
          } catch (_) {}
          for (final table in ['learning_programs', 'test_dates']) {
            try {
              await customStatement('DROP TABLE IF EXISTS $table');
            } catch (_) {}
          }
        }
        if (from < 4) {
          // v4: calendar_cycles gains sefaria_ref_he (heRef from Sefaria's
          // /api/calendars). Existing rows get an empty string so the seed
          // builder can backfill on next run.
          try {
            await customStatement(
              'ALTER TABLE calendar_cycles '
              "ADD COLUMN sefaria_ref_he TEXT NOT NULL DEFAULT ''",
            );
          } catch (_) {}
        }
      },
    );
  }
}
