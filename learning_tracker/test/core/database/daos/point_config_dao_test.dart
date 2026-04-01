import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

void main() {
  late UserDatabase database;

  setUp(() {
    database = UserDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('PointConfigDao', () {
    test('insertConfig and getConfig returns the inserted config', () async {
      await database.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'bavli',
          stageOrder: 1,
          points: 10,
        ),
      );

      final config = await database.pointConfigDao.getConfig('bavli', 1);
      expect(config, isNotNull);
      expect(config!.curriculumId, 'bavli');
      expect(config.stageOrder, 1);
      expect(config.points, 10);
    });

    test('getConfig returns null for non-existent config', () async {
      final config = await database.pointConfigDao.getConfig('bavli', 1);
      expect(config, isNull);
    });

    test('getConfigsByCurriculum returns configs ordered by stage', () async {
      await database.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'bavli',
          stageOrder: 3,
          points: 3,
        ),
      );
      await database.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'bavli',
          stageOrder: 1,
          points: 10,
        ),
      );
      await database.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'bavli',
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
          stageOrder: 1,
          points: 10,
        ),
      );
      await database.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'mishnayos',
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
          curriculumId: 'bavli',
          stageOrder: 1,
          points: 10,
        ),
      );

      final config = await database.pointConfigDao.getConfig('bavli', 1);
      expect(config, isNotNull);
      expect(config!.points, 10);
    });

    test('upsertConfig updates points when config already exists', () async {
      await database.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'bavli',
          stageOrder: 1,
          points: 10,
        ),
      );

      await database.pointConfigDao.upsertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'bavli',
          stageOrder: 1,
          points: 20,
        ),
      );

      final config = await database.pointConfigDao.getConfig('bavli', 1);
      expect(config!.points, 20);
    });

    test(
      'deleteAllForCurriculum removes only that curriculum configs',
      () async {
        await database.pointConfigDao.insertConfig(
          PointConfigsCompanion.insert(
            curriculumId: 'bavli',
            stageOrder: 1,
            points: 10,
          ),
        );
        await database.pointConfigDao.insertConfig(
          PointConfigsCompanion.insert(
            curriculumId: 'mishnayos',
            stageOrder: 1,
            points: 8,
          ),
        );

        final deleted = await database.pointConfigDao.deleteAllForCurriculum(
          'bavli',
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
        await database.pointConfigDao.seedDefaults('bavli');

        final configs = await database.pointConfigDao.getConfigsByCurriculum(
          'bavli',
        );
        expect(configs, hasLength(3));
        expect(configs[0].points, 10);
        expect(configs[1].points, 5);
        expect(configs[2].points, 3);
      },
    );
  });
}
