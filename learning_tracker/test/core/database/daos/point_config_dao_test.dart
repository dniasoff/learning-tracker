import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

void main() {
  late UserDatabase database;
  late int trackId;

  setUp(() async {
    database = UserDatabase(NativeDatabase.memory());
    trackId = await database
        .into(database.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            curriculumId: 'bavli',
            trackType: 'personal',
            activatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  group('PointConfigDao', () {
    test('insertConfig and getConfig returns the inserted config', () async {
      await database.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'bavli',
          trackId: trackId,
          stageOrder: 1,
          points: 10,
        ),
      );

      final config = await database.pointConfigDao.getConfig(
        'bavli',
        1,
        profileId: 0,
        trackId: trackId,
      );
      expect(config, isNotNull);
      expect(config!.curriculumId, 'bavli');
      expect(config.stageOrder, 1);
      expect(config.points, 10);
    });

    test('getConfig returns null for non-existent config', () async {
      final config = await database.pointConfigDao.getConfig(
        'bavli',
        1,
        profileId: 0,
        trackId: trackId,
      );
      expect(config, isNull);
    });

    test('getConfigsByCurriculum returns configs ordered by stage', () async {
      await database.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'bavli',
          trackId: trackId,
          stageOrder: 3,
          points: 3,
        ),
      );
      await database.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'bavli',
          trackId: trackId,
          stageOrder: 1,
          points: 10,
        ),
      );
      await database.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'bavli',
          trackId: trackId,
          stageOrder: 2,
          points: 5,
        ),
      );

      final configs = await database.pointConfigDao.getConfigsByCurriculum(
        'bavli',
      );
      expect(configs, hasLength(3));
      expect(configs[0].stageOrder, 1);
      expect(configs[1].stageOrder, 2);
      expect(configs[2].stageOrder, 3);
    });

    test('getConfigsByCurriculum filters by curriculum', () async {
      await database.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'bavli',
          trackId: trackId,
          stageOrder: 1,
          points: 10,
        ),
      );
      await database.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'mishnayos',
          trackId: trackId,
          stageOrder: 1,
          points: 8,
        ),
      );

      final configs = await database.pointConfigDao.getConfigsByCurriculum(
        'bavli',
      );
      expect(configs, hasLength(1));
      expect(configs.first.curriculumId, 'bavli');
    });

    test('upsertConfig inserts when config does not exist', () async {
      await database.pointConfigDao.upsertConfig(
        PointConfigsCompanion.insert(
          profileId: const Value(0),
          curriculumId: 'bavli',
          trackId: trackId,
          stageOrder: 1,
          points: 10,
        ),
      );

      final config = await database.pointConfigDao.getConfig(
        'bavli',
        1,
        profileId: 0,
        trackId: trackId,
      );
      expect(config, isNotNull);
      expect(config!.points, 10);
    });

    test('upsertConfig updates points when config already exists', () async {
      await database.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'bavli',
          trackId: trackId,
          stageOrder: 1,
          points: 10,
        ),
      );

      await database.pointConfigDao.upsertConfig(
        PointConfigsCompanion.insert(
          profileId: const Value(0),
          curriculumId: 'bavli',
          trackId: trackId,
          stageOrder: 1,
          points: 20,
        ),
      );

      final config = await database.pointConfigDao.getConfig(
        'bavli',
        1,
        profileId: 0,
        trackId: trackId,
      );
      expect(config!.points, 20);
    });

    test(
      'deleteAllForCurriculum removes only that curriculum configs',
      () async {
        await database.pointConfigDao.insertConfig(
          PointConfigsCompanion.insert(
            curriculumId: 'bavli',
            trackId: trackId,
            stageOrder: 1,
            points: 10,
          ),
        );
        await database.pointConfigDao.insertConfig(
          PointConfigsCompanion.insert(
            curriculumId: 'mishnayos',
            trackId: trackId,
            stageOrder: 1,
            points: 8,
          ),
        );

        final deleted = await database.pointConfigDao.deleteAllForCurriculum(
          'bavli',
          profileId: 0,
        );
        expect(deleted, 1);

        final bavliConfigs = await database.pointConfigDao
            .getConfigsByCurriculum('bavli');
        expect(bavliConfigs, isEmpty);

        final mishnayosConfigs = await database.pointConfigDao
            .getConfigsByCurriculum('mishnayos');
        expect(mishnayosConfigs, hasLength(1));
      },
    );

    test(
      'seedDefaults creates fallback configs when no stages exist',
      () async {
        await database.pointConfigDao.seedDefaults(
          'bavli',
          trackId,
          profileId: 0,
        );

        final configs = await database.pointConfigDao.getConfigsByCurriculum(
          'bavli',
        );
        expect(configs, hasLength(3));
        expect(configs[0].points, 10);
        expect(configs[1].points, 5);
        expect(configs[2].points, 3);
      },
    );

    test('seedDefaults uses only stages for the target track when multiple '
        'profiles share a curriculum', () async {
      final trackAdult = await database
          .into(database.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: const Value(1),
              curriculumId: 'mishnayos',
              trackType: 'personal',
              activatedAt: DateTime.now(),
            ),
          );
      final trackChild = await database
          .into(database.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: const Value(2),
              curriculumId: 'mishnayos',
              trackType: 'personal',
              activatedAt: DateTime.now(),
            ),
          );

      for (final tid in [trackAdult, trackChild]) {
        await database.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            curriculumId: 'mishnayos',
            trackId: tid,
            stageOrder: 1,
            stageName: 'Learn',
            delayDays: 0,
          ),
        );
        await database.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            curriculumId: 'mishnayos',
            trackId: tid,
            stageOrder: 2,
            stageName: 'Review',
            delayDays: 1,
          ),
        );
      }

      await database.pointConfigDao.seedDefaults(
        'mishnayos',
        trackChild,
        profileId: 2,
      );

      final childConfigs = await database.pointConfigDao.getConfigsByCurriculum(
        'mishnayos',
        profileId: 2,
        trackId: trackChild,
      );
      expect(childConfigs, hasLength(2));
      expect(childConfigs[0].stageOrder, 1);
      expect(childConfigs[1].stageOrder, 2);
    });
  });
}
