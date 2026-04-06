import 'package:drift/drift.dart';
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
      await customInsert(
        'INSERT INTO learning_programs (name, display_name, description, '
        'curriculum_type, is_active, has_tests, stages_config, test_config, '
        'created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(program['name']! as String),
          Variable.withString(program['display_name']! as String),
          Variable.withString(program['description']! as String),
          Variable.withString(program['curriculum_type']! as String),
          Variable.withBool(program['is_active']! as bool),
          Variable.withBool(program['has_tests']! as bool),
          Variable.withString(program['stages_config']! as String),
          Variable.withString(program['test_config']! as String),
          Variable.withDateTime(DateTime.now().toUtc()),
        ],
      );
    }
  }

  /// Upsert all learning program seeds — updates existing rows keyed on `name`.
  Future<void> _upsertLearningPrograms() async {
    for (final program in learningProgramSeeds) {
      await customInsert(
        'INSERT OR REPLACE INTO learning_programs '
        '(name, display_name, description, curriculum_type, is_active, '
        'has_tests, stages_config, test_config, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(program['name']! as String),
          Variable.withString(program['display_name']! as String),
          Variable.withString(program['description']! as String),
          Variable.withString(program['curriculum_type']! as String),
          Variable.withBool(program['is_active']! as bool),
          Variable.withBool(program['has_tests']! as bool),
          Variable.withString(program['stages_config']! as String),
          Variable.withString(program['test_config']! as String),
          Variable.withDateTime(DateTime.now().toUtc()),
        ],
      );
    }
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
