import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/dao_invariant_error.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase database;

  setUp(() {
    database = inMemoryDb();
  });

  tearDown(() async {
    await database.close();
  });

  group('ActiveCurriculumDao', () {
    test('activating a curriculum adds it to active curricula', () async {
      // Activate Bavli
      await database.activeCurriculumDao.activate(CurriculumId.bavli);

      final activeCurricula = await database.activeCurriculumDao
          .getActiveCurricula();
      expect(activeCurricula, contains(CurriculumId.bavli.storageKey));
    });

    test(
      'deactivating a curriculum removes it from active curricula',
      () async {
        // Activate Bavli and Yerushalmi
        await database.activeCurriculumDao.activate(CurriculumId.bavli);
        await database.activeCurriculumDao.activate(CurriculumId.yerushalmi);

        // Deactivate Bavli
        await database.activeCurriculumDao.deactivate(CurriculumId.bavli);

        final activeCurricula = await database.activeCurriculumDao
            .getActiveCurricula();
        expect(activeCurricula, isNot(contains(CurriculumId.bavli.storageKey)));
        expect(activeCurricula, contains(CurriculumId.yerushalmi.storageKey));
      },
    );

    test('attempting to deactivate the last curriculum throws a typed '
        'DaoInvariantError with a stable code, not a raw English message '
        '(AUD-core-database-14, EH-5)', () async {
      // Activate only Mishnayos
      await database.activeCurriculumDao.activate(CurriculumId.mishnayos);

      // Try to deactivate it
      expect(
        () => database.activeCurriculumDao.deactivate(CurriculumId.mishnayos),
        throwsA(
          isA<DaoInvariantError>().having(
            (e) => e.code,
            'code',
            DaoErrorCode.lastActiveCurriculum,
          ),
        ),
      );
    });

    test('isActive returns true for active curriculum', () async {
      await database.activeCurriculumDao.activate(CurriculumId.bavli);

      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.bavli,
      );
      expect(isActive, isTrue);
    });

    test('isActive returns false for inactive curriculum', () async {
      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.bavli,
      );
      expect(isActive, isFalse);
    });

    test('getActiveCurricula returns empty list initially', () async {
      final activeCurricula = await database.activeCurriculumDao
          .getActiveCurricula();
      expect(activeCurricula, isEmpty);
    });

    test('activating an already-active curriculum is idempotent', () async {
      await database.activeCurriculumDao.activate(CurriculumId.bavli);
      await database.activeCurriculumDao.activate(CurriculumId.bavli);

      final activeCurricula = await database.activeCurriculumDao
          .getActiveCurricula();
      expect(
        activeCurricula
            .where((id) => id == CurriculumId.bavli.storageKey)
            .length,
        1,
      );
    });

    test('watchActiveCurricula emits updates on activation', () async {
      final stream = database.activeCurriculumDao.watchActiveCurricula();

      expect(
        stream,
        emitsInOrder([
          <String>[], // Initial empty state
          [CurriculumId.bavli.storageKey], // After activation
        ]),
      );

      await Future<void>.delayed(
        Duration.zero,
      ); // Let stream emit initial value
      await database.activeCurriculumDao.activate(CurriculumId.bavli);
    });
  });
}
