import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';

void main() {
  late AppDatabase database;
  late CurriculumActivationService service;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    service = CurriculumActivationService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('CurriculumActivationService', () {
    test('getActiveCurricula returns empty list initially', () async {
      final curricula = await service.getActiveCurricula();
      expect(curricula, isEmpty);
    });

    test('activate adds curriculum to active list', () async {
      await service.activate(CurriculumId.bavli);

      final curricula = await service.getActiveCurricula();
      expect(curricula, contains(CurriculumId.bavli));
    });

    test('isActive returns true for active curriculum', () async {
      await service.activate(CurriculumId.mishnayos);

      final isActive = await service.isActive(CurriculumId.mishnayos);
      expect(isActive, isTrue);
    });

    test('isActive returns false for inactive curriculum', () async {
      final isActive = await service.isActive(CurriculumId.yerushalmi);
      expect(isActive, isFalse);
    });

    test('deactivate removes curriculum from active list', () async {
      await service.activate(CurriculumId.bavli);
      await service.activate(CurriculumId.mishnayos);

      await service.deactivate(CurriculumId.bavli);

      final curricula = await service.getActiveCurricula();
      expect(curricula, isNot(contains(CurriculumId.bavli)));
      expect(curricula, contains(CurriculumId.mishnayos));
    });

    test(
      'deactivate throws when attempting to deactivate last curriculum',
      () async {
        await service.activate(CurriculumId.bavli);

        expect(() => service.deactivate(CurriculumId.bavli), throwsException);
      },
    );

    test('toggle activates inactive curriculum', () async {
      await service.activate(CurriculumId.mishnayos); // Ensure not last

      await service.toggle(CurriculumId.bavli);

      final isActive = await service.isActive(CurriculumId.bavli);
      expect(isActive, isTrue);
    });

    test('toggle deactivates active curriculum', () async {
      await service.activate(CurriculumId.bavli);
      await service.activate(CurriculumId.mishnayos); // Ensure not last

      await service.toggle(CurriculumId.bavli);

      final isActive = await service.isActive(CurriculumId.bavli);
      expect(isActive, isFalse);
    });

    test('initializeDefaults activates Mishnayos if none active', () async {
      await service.initializeDefaults();

      final curricula = await service.getActiveCurricula();
      expect(curricula, contains(CurriculumId.mishnayos));
    });

    test(
      'initializeDefaults does not change active curricula if some exist',
      () async {
        await service.activate(CurriculumId.bavli);

        await service.initializeDefaults();

        final curricula = await service.getActiveCurricula();
        expect(curricula, contains(CurriculumId.bavli));
        expect(curricula, isNot(contains(CurriculumId.mishnayos)));
      },
    );
  });
}
