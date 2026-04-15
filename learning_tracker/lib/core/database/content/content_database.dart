import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/content/daos/calendar_cycle_dao.dart';
import 'package:learning_tracker/core/database/content/daos/learning_program_dao.dart';
import 'package:learning_tracker/core/database/content/daos/seed_metadata_dao.dart';
import 'package:learning_tracker/core/database/content/daos/test_date_dao.dart';
import 'package:learning_tracker/core/database/content/daos/text_cache_dao.dart';
import 'package:learning_tracker/core/database/seed/learning_program_seeds.dart';
import 'package:learning_tracker/core/database/seed/test_date_seeds.dart';
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
/// - [LearningPrograms]: 18 program presets
/// - [SeedMetadata]: Version tracking for seed replacement (incl. contentHash)
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

  /// Open a ContentDatabase from a prepared seed file in read-only mode
  /// (Story 19.3 AC-10).
  ///
  /// Executes `PRAGMA query_only = ON` at the SQLite level via Drift's
  /// native setup hook, so any accidental writes will raise
  /// `SqliteException` at runtime.
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
  int get schemaVersion => 2;

  // In production, this DB is opened from a pre-built seed file so
  // onCreate is never invoked. In tests, NativeDatabase.memory() triggers
  // onCreate, so we seed LearningPrograms and TestDates here to keep
  // tests working the same way the old AppDatabase did.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedLearningPrograms();
        await _seedTestDates();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // v2: add contentHash + minAppVersion to seed_metadata.
          await m.addColumn(seedMetadata, seedMetadata.contentHash);
          await m.addColumn(seedMetadata, seedMetadata.minAppVersion);
        }
      },
      beforeOpen: (details) async {
        // Always re-seed learning programs to ensure data is current.
        // Uses INSERT OR REPLACE keyed on `name` so updated seed data
        // (e.g. Oraysa review stages — DNI-201) propagates to existing installs.
        try {
          await _upsertLearningPrograms();
        } catch (_) {
          // Table might not exist yet on very old installs; try full seed.
          try {
            await _seedLearningPrograms();
          } catch (_) {}
        }
        try {
          final count = await customSelect(
            'SELECT COUNT(*) AS c FROM test_dates',
          ).getSingle();
          if ((count.read<int>('c')) == 0) {
            await _seedTestDates();
          }
        } catch (_) {
          await _seedTestDates();
        }
      },
    );
  }

  Future<void> _seedLearningPrograms() async {
    for (final program in learningProgramSeeds) {
      await _insertProgram(program, replace: false);
    }
  }

  /// Upsert all learning program seeds — updates existing rows keyed on `name`.
  Future<void> _upsertLearningPrograms() async {
    for (final program in learningProgramSeeds) {
      await _insertProgram(program, replace: true);
    }
  }

  Future<void> _insertProgram(
    Map<String, Object?> program, {
    required bool replace,
  }) async {
    final verb = replace ? 'INSERT OR REPLACE' : 'INSERT';
    final apiSource = program['api_source'] as String?;
    final apiKey = program['api_program_key'] as String?;
    final isCalendar = (program['is_calendar_program'] as bool?) ?? false;
    final apiSourceSql = apiSource == null ? 'NULL' : '?';
    final apiKeySql = apiKey == null ? 'NULL' : '?';
    final variables = <Variable<Object>>[
      Variable.withString(program['name']! as String),
      Variable.withString(program['display_name']! as String),
      Variable.withString(program['description']! as String),
      Variable.withString(program['curriculum_type']! as String),
      Variable.withBool(program['is_active']! as bool),
      Variable.withBool(program['has_tests']! as bool),
      Variable.withString(program['stages_config']! as String),
      Variable.withString(program['test_config']! as String),
      Variable.withDateTime(DateTime.now().toUtc()),
      if (apiSource != null) Variable.withString(apiSource),
      if (apiKey != null) Variable.withString(apiKey),
      Variable.withBool(isCalendar),
    ];
    await customInsert(
      '$verb INTO learning_programs '
      '(name, display_name, description, curriculum_type, is_active, '
      'has_tests, stages_config, test_config, created_at, api_source, '
      'api_program_key, is_calendar_program) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, $apiSourceSql, $apiKeySql, ?)',
      variables: variables,
    );
  }

  Future<void> _seedTestDates() async {
    final seeds = generateTestDateSeeds();
    for (final testDate in seeds) {
      // Look up program ID from program name
      final programName = testDate['program_name'] as String?;
      if (programName == null) continue;
      final programRows = await customSelect(
        'SELECT id FROM learning_programs WHERE name = ?',
        variables: [Variable.withString(programName)],
      ).get();
      if (programRows.isEmpty) continue;
      final programId = programRows.first.read<int>('id');

      await customInsert(
        'INSERT INTO test_dates (program_id, test_date, material_description) '
        'VALUES (?, ?, ?)',
        variables: [
          Variable.withInt(programId),
          Variable.withDateTime(testDate['test_date']! as DateTime),
          Variable.withString(
            testDate['material_description'] as String? ?? '',
          ),
        ],
      );
    }
  }
}
