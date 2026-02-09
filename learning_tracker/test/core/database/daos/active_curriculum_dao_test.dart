import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('ActiveCurriculumDao', () {
    test('getActiveCurriculaIds returns empty list initially', () async {
      final ids = await database.activeCurriculumDao.getActiveCurriculaIds();
      expect(ids, isEmpty);
    });

    test('activate adds curriculum to active list', () async {
      await database.activeCurriculumDao.activate(
        CurriculumId.bavli.storageKey,
      );

      final ids = await database.activeCurriculumDao.getActiveCurriculaIds();
      expect(ids, contains(CurriculumId.bavli.storageKey));
    });

    test('isActive returns true for active curriculum', () async {
      await database.activeCurriculumDao.activate(
        CurriculumId.mishnayos.storageKey,
      );

      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.mishnayos.storageKey,
      );
      expect(isActive, isTrue);
    });

    test('isActive returns false for inactive curriculum', () async {
      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.yerushalmi.storageKey,
      );
      expect(isActive, isFalse);
    });

    test('deactivate removes curriculum from active list', () async {
      await database.activeCurriculumDao.activate(
        CurriculumId.bavli.storageKey,
      );
      await database.activeCurriculumDao.activate(
        CurriculumId.mishnayos.storageKey,
      );

      await database.activeCurriculumDao.deactivate(
        CurriculumId.bavli.storageKey,
      );

      final ids = await database.activeCurriculumDao.getActiveCurriculaIds();
      expect(ids, isNot(contains(CurriculumId.bavli.storageKey)));
      expect(ids, contains(CurriculumId.mishnayos.storageKey));
    });

    test(
      'deactivate throws when attempting to deactivate last curriculum',
      () async {
        await database.activeCurriculumDao.activate(
          CurriculumId.bavli.storageKey,
        );

        expect(
          () => database.activeCurriculumDao.deactivate(
            CurriculumId.bavli.storageKey,
          ),
          throwsException,
        );
      },
    );

    test('getActiveCount returns correct count', () async {
      await database.activeCurriculumDao.activate(
        CurriculumId.bavli.storageKey,
      );
      await database.activeCurriculumDao.activate(
        CurriculumId.mishnayos.storageKey,
      );

      final count = await database.activeCurriculumDao.getActiveCount();
      expect(count, equals(2));
    });

    test('activate is idempotent', () async {
      await database.activeCurriculumDao.activate(
        CurriculumId.bavli.storageKey,
      );
      await database.activeCurriculumDao.activate(
        CurriculumId.bavli.storageKey,
      );

      final count = await database.activeCurriculumDao.getActiveCount();
      expect(count, equals(1));
    });
  });
}
