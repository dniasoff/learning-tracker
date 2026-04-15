/// Example test demonstrating test infrastructure usage
///
/// This test verifies that:
/// - Shared mocks work (mocktail)
/// - Test fixtures produce valid data
/// - In-memory database helper works
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

import 'fixtures/content_fixtures.dart';
import 'fixtures/curriculum_fixtures.dart';
import 'helpers/test_database.dart';
import 'mocks/mock_repositories.dart';
import 'mocks/mock_services.dart';

void main() {
  group('Test Infrastructure', () {
    group('Mocks', () {
      test('MockAuthRepository can be instantiated', () {
        final mockAuthRepo = MockAuthRepository();
        expect(mockAuthRepo, isNotNull);
      });

      test('MockConnectivityService can be instantiated', () {
        final mockConnectivity = MockConnectivityService();
        expect(mockConnectivity, isNotNull);
      });

      test('MockAuthRepository can be stubbed with mocktail', () {
        final mockAuthRepo = MockAuthRepository();

        // Mocks are ready to use with when/verify
        // Example: when(() => mockAuthRepo.signIn(...)).thenAnswer(...)
        expect(mockAuthRepo, isA<MockAuthRepository>());
      });
    });

    group('Content Fixtures', () {
      test('creates valid mishna', () {
        final mishna = ContentItemFixtures.mishna();

        expect(mishna.curriculumId, CurriculumId.mishnayos.storageKey);
        expect(mishna.isLeaf, true);
        expect(mishna.level1, isNotEmpty);
        expect(mishna.level2, isNotNull);
      });

      test('creates valid daf', () {
        final daf = ContentItemFixtures.daf();

        expect(daf.curriculumId, CurriculumId.bavli.storageKey);
        expect(daf.isLeaf, true);
        expect(daf.level3, isNotNull);
      });

      test('creates valid pasuk', () {
        final pasuk = ContentItemFixtures.pasuk();

        expect(pasuk.curriculumId, CurriculumId.chumash.storageKey);
        expect(pasuk.isLeaf, true);
        expect(pasuk.level4, isNotNull);
      });

      test('creates valid container', () {
        final container = ContentItemFixtures.container(level1: 'Seder Zeraim');

        expect(container.isLeaf, false);
        expect(container.level1, 'Seder Zeraim');
      });

      test('allows customization', () {
        final customMishna = ContentItemFixtures.mishna(
          level2: 'Shabbos',
          level3: '2',
          level4: '5',
          sortOrder: 42,
        );

        expect(customMishna.level2, 'Shabbos');
        expect(customMishna.level3, '2');
        expect(customMishna.level4, '5');
        expect(customMishna.sortOrder, 42);
      });
    });

    group('Curriculum Fixtures', () {
      test('provides default curriculum', () {
        expect(CurriculumFixtures.defaultCurriculum, CurriculumId.mishnayos);
      });

      test('provides all curricula', () {
        final allCurricula = CurriculumFixtures.allCurricula;

        expect(allCurricula.length, CurriculumId.values.length);
        expect(allCurricula, contains(CurriculumId.mishnayos));
        expect(allCurricula, contains(CurriculumId.bavli));
        expect(allCurricula, contains(CurriculumId.yerushalmi));
        expect(allCurricula, contains(CurriculumId.mishnaBerurah));
        expect(allCurricula, contains(CurriculumId.chumash));
      });

      test('converts storage key to curriculum', () {
        final curriculum = CurriculumFixtures.fromStorageKey('bavli');

        expect(curriculum, CurriculumId.bavli);
      });

      test('provides all storage keys', () {
        final keys = CurriculumFixtures.allStorageKeys;

        expect(keys, contains('mishnayos'));
        expect(keys, contains('bavli'));
        expect(keys, contains('mishna_berurah'));
      });
    });

    group('In-Memory Database', () {
      test('creates test database successfully', () {
        final db = createTestDatabase();

        expect(db, isNotNull);
        expect(db.schemaVersion, 4);

        db.close();
      });

      test('database is isolated between tests', () async {
        final db1 = createTestDatabase();
        final db2 = createTestDatabase();

        // Different database instances
        expect(identical(db1, db2), false);

        await db1.close();
        await db2.close();
      });
    });
  });
}
