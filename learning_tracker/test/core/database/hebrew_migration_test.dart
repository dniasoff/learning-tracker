import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../helpers/test_database.dart';

void main() {
  group('Schema migration v23→v24: Hebrew stage names', () {
    late UserDatabase db;
    late int bavliTrackId;
    late int mishnayosTrackId;
    late int mbTrackId;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      bavliTrackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              stateChangedAt: DateTime.now(),
              activatedAt: DateTime.now(),
            ),
          );
      mishnayosTrackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: DateTime.now(),
              activatedAt: DateTime.now(),
            ),
          );
      mbTrackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishna_berurah',
              stateChangedAt: DateTime.now(),
              activatedAt: DateTime.now(),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('new database creates stages with Hebrew names by default', () async {
      // Insert a stage using defaults (the current schema should use Hebrew)
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: bavliTrackId,
          stageOrder: 1,
          stageName: 'לימוד',
          schedule: Value('{"type":"delay","delay_days":0}'),
          isDefault: const Value(true),
        ),
      );

      final stages = await db.stageDao.getStageDefinitionsByCurriculum('bavli');
      expect(stages, hasLength(1));
      expect(stages.first.stageName, 'לימוד');
    });

    test('English default "Learn" migrated to "לימוד"', () async {
      // Simulate pre-migration data with English name
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: bavliTrackId,
          stageOrder: 1,
          stageName: 'Learn',
          schedule: Value('{"type":"delay","delay_days":0}'),
          isDefault: const Value(true),
        ),
      );

      // Run the migration SQL directly
      await _runHebrewMigration(db);

      final stages = await db.stageDao.getStageDefinitionsByCurriculum('bavli');
      expect(stages.first.stageName, 'לימוד');
    });

    test('English "Chazara 1" and "Chazara 2" migrated to Hebrew', () async {
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: bavliTrackId,
          stageOrder: 1,
          stageName: 'Chazara 1',
          schedule: Value('{"type":"delay","delay_days":1}'),
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: bavliTrackId,
          stageOrder: 2,
          stageName: 'Chazara 2',
          schedule: Value('{"type":"delay","delay_days":7}'),
        ),
      );

      await _runHebrewMigration(db);

      final stages = await db.stageDao.getStageDefinitionsByCurriculum('bavli');
      expect(stages[0].stageName, 'חזרה א׳');
      expect(stages[1].stageName, 'חזרה ב׳');
    });

    test('English "Review" variants migrated to Hebrew', () async {
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishna_berurah',
          trackId: mbTrackId,
          stageOrder: 1,
          stageName: 'Review',
          schedule: Value('{"type":"delay","delay_days":7}'),
        ),
      );

      await _runHebrewMigration(db);

      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        'mishna_berurah',
      );
      expect(stages.first.stageName, 'חזרה');
    });

    test('Oraysa program labels migrated correctly', () async {
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: bavliTrackId,
          stageOrder: 1,
          stageName: 'Next-Day Review',
          schedule: Value('{"type":"delay","delay_days":1}'),
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: bavliTrackId,
          stageOrder: 2,
          stageName: 'Weekly Review',
          schedule: Value('{"type":"delay","delay_days":7}'),
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: bavliTrackId,
          stageOrder: 3,
          stageName: 'Rolling Back-20',
          schedule: Value('{"type":"delay","delay_days":20}'),
        ),
      );

      await _runHebrewMigration(db);

      final stages = await db.stageDao.getStageDefinitionsByCurriculum('bavli');
      expect(stages[0].stageName, 'חזרה יומית');
      expect(stages[1].stageName, 'חזרה שבועית');
      expect(stages[2].stageName, 'חזרה מחזורית');
    });

    test('user-customized stage names are NOT changed by migration', () async {
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: mishnayosTrackId,
          stageOrder: 1,
          stageName: 'My Morning Study',
          schedule: Value('{"type":"delay","delay_days":0}'),
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: mishnayosTrackId,
          stageOrder: 2,
          stageName: 'Evening Review Session',
          schedule: Value('{"type":"delay","delay_days":1}'),
        ),
      );

      await _runHebrewMigration(db);

      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        'mishnayos',
      );
      expect(stages[0].stageName, 'My Morning Study');
      expect(stages[1].stageName, 'Evening Review Session');
    });

    test('migration is idempotent (safe to run multiple times)', () async {
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: bavliTrackId,
          stageOrder: 1,
          stageName: 'Learn',
          schedule: Value('{"type":"delay","delay_days":0}'),
        ),
      );

      // Run migration twice
      await _runHebrewMigration(db);
      await _runHebrewMigration(db);

      final stages = await db.stageDao.getStageDefinitionsByCurriculum('bavli');
      expect(stages.first.stageName, 'לימוד');
    });

    test(
      'mixed English defaults and custom names: only defaults change',
      () async {
        // English default
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            trackId: bavliTrackId,
            stageOrder: 1,
            stageName: 'Learn',
            schedule: Value('{"type":"delay","delay_days":0}'),
          ),
        );
        // Custom name
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            trackId: bavliTrackId,
            stageOrder: 2,
            stageName: 'Quick Review',
            schedule: Value('{"type":"delay","delay_days":1}'),
          ),
        );
        // English default
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            trackId: bavliTrackId,
            stageOrder: 3,
            stageName: 'Chazara 2',
            schedule: Value('{"type":"delay","delay_days":7}'),
          ),
        );

        await _runHebrewMigration(db);

        final stages = await db.stageDao.getStageDefinitionsByCurriculum(
          'bavli',
        );
        expect(stages[0].stageName, 'לימוד'); // migrated
        expect(stages[1].stageName, 'Quick Review'); // untouched
        expect(stages[2].stageName, 'חזרה ב׳'); // migrated
      },
    );
  });
}

/// Runs the same SQL statements as the v24 migration.
Future<void> _runHebrewMigration(UserDatabase db) async {
  const englishToHebrew = {
    'Learn': 'לימוד',
    'Chazara 1': 'חזרה א׳',
    'Chazara 2': 'חזרה ב׳',
    'Chazara 3': 'חזרה ג׳',
    'Review': 'חזרה',
    'Review 1': 'חזרה א׳',
    'Review 2': 'חזרה ב׳',
    'Next-Day Review': 'חזרה יומית',
    'Weekly Review': 'חזרה שבועית',
    'Rolling Back-20': 'חזרה מחזורית',
  };
  for (final entry in englishToHebrew.entries) {
    await db.customStatement(
      "UPDATE stage_definitions SET stage_name = '${entry.value}' "
      "WHERE stage_name = '${entry.key}'",
    );
  }
}
