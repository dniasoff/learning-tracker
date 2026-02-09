import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_import/domain/models/import_progress.dart';
import 'package:learning_tracker/features/content_import/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';

import '../../helpers/test_database.dart';

class MockCurriculumContentFetcher extends Mock
    implements CurriculumContentFetcher {}

class MockSyncEngine extends Mock implements SyncEngine {}

class MockTalker extends Mock implements Talker {}

void main() {
  late CurriculumImportService importService;
  late MockCurriculumContentFetcher mockFetcher;
  late MockSyncEngine mockSyncEngine;
  late MockTalker mockLogger;

  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  setUp(() {
    mockFetcher = MockCurriculumContentFetcher();
    mockSyncEngine = MockSyncEngine();
    mockLogger = MockTalker();

    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.debug(any())).thenReturn(null);
    when(() => mockLogger.warning(any(), any())).thenReturn(null);
    when(() => mockLogger.error(any())).thenReturn(null);
  });

  tearDown(() async {
    await importService.dispose();
  });

  group('CurriculumImportService', () {
    test('imports curriculum with correct item count (AC: Unit test)', () async {
      final database = await createTestDatabase();
      addTearDown(database.close);

      // Create mock fetcher that returns Mishnayos data
      final mockItems = List.generate(
        4192,
        (i) => ContentItem(
          curriculumId: CurriculumId.mishnayos.storageKey,
          level1: 'Seder ${i ~/ 1000}',
          level2: 'Masechta ${i ~/ 100}',
          level3: 'Perek ${i ~/ 10}',
          level4: 'Mishna ${i % 10}',
          displayNameHe: 'משנה $i',
          displayNameEn: 'Mishna $i',
          sefariaRef: 'Mishnah.Test.$i',
          sortOrder: i,
          isLeaf: true,
        ),
      );

      final mockHierarchyConfig = CurriculumHierarchyConfig(
        curriculumId: CurriculumId.mishnayos.storageKey,
        levelLabels: const ['Seder', 'Masechta', 'Perek', 'Mishna'],
        totalItems: 4192,
      );

      when(() => mockFetcher.curriculumId)
          .thenReturn(CurriculumId.mishnayos.storageKey);
      when(() => mockFetcher.fetchAllContent()).thenAnswer(
        (_) async => FetchResult(
          items: mockItems,
          hierarchyConfig: mockHierarchyConfig,
        ),
      );

      when(() => mockSyncEngine.pushCurriculumImportMetadata(
            curriculumId: any(named: 'curriculumId'),
            itemCount: any(named: 'itemCount'),
            importedAt: any(named: 'importedAt'),
          )).thenAnswer((_) async {});

      importService = CurriculumImportService(
        database: database,
        fetchers: {CurriculumId.mishnayos.storageKey: mockFetcher},
        syncEngine: mockSyncEngine,
        logger: mockLogger,
      );

      // Import the curriculum
      final success = await importService.importCurriculum(CurriculumId.mishnayos);

      expect(success, isTrue);

      // Verify correct number of items were inserted
      final count = await database.contentDao
          .getContentItemCountByCurriculum(CurriculumId.mishnayos.storageKey);
      expect(count, equals(4192));

      // Verify hierarchy config was stored
      final hierarchyConfigData = await database
          .select(database.curriculumHierarchyConfig)
          .get();
      expect(hierarchyConfigData.length, equals(1));
      expect(hierarchyConfigData.first.maxLevels, equals(4));
    });

    test('import is idempotent - no duplicates on second run (AC: Unit test)',
        () async {
      final database = await createTestDatabase();
      addTearDown(database.close);

      final mockItems = List.generate(
        100,
        (i) => ContentItem(
          curriculumId: CurriculumId.mishnayos.storageKey,
          level1: 'Seder1',
          level2: 'Masechta1',
          level3: 'Perek${i ~/ 10}',
          level4: 'Mishna${i % 10}',
          displayNameHe: 'משנה $i',
          displayNameEn: 'Mishna $i',
          sefariaRef: 'Mishnah.Test.$i',
          sortOrder: i,
          isLeaf: true,
        ),
      );

      final mockHierarchyConfig = CurriculumHierarchyConfig(
        curriculumId: CurriculumId.mishnayos.storageKey,
        levelLabels: const ['Seder', 'Masechta', 'Perek', 'Mishna'],
        totalItems: 100,
      );

      when(() => mockFetcher.curriculumId)
          .thenReturn(CurriculumId.mishnayos.storageKey);
      when(() => mockFetcher.fetchAllContent()).thenAnswer(
        (_) async => FetchResult(
          items: mockItems,
          hierarchyConfig: mockHierarchyConfig,
        ),
      );

      when(() => mockSyncEngine.pushCurriculumImportMetadata(
            curriculumId: any(named: 'curriculumId'),
            itemCount: any(named: 'itemCount'),
            importedAt: any(named: 'importedAt'),
          )).thenAnswer((_) async {});

      importService = CurriculumImportService(
        database: database,
        fetchers: {CurriculumId.mishnayos.storageKey: mockFetcher},
        syncEngine: mockSyncEngine,
        logger: mockLogger,
      );

      // First import
      await importService.importCurriculum(CurriculumId.mishnayos);
      final firstCount = await database.contentDao
          .getContentItemCountByCurriculum(CurriculumId.mishnayos.storageKey);

      // Second import (idempotent)
      await importService.importCurriculum(CurriculumId.mishnayos);
      final secondCount = await database.contentDao
          .getContentItemCountByCurriculum(CurriculumId.mishnayos.storageKey);

      expect(firstCount, equals(secondCount));
      expect(secondCount, equals(100));
    });

    test('seeds default stage definitions on import (AC: Unit test)', () async {
      final database = await createTestDatabase();
      addTearDown(database.close);

      final mockItems = [
        ContentItem(
          curriculumId: CurriculumId.mishnayos.storageKey,
          level1: 'Seder1',
          displayNameHe: 'סדר',
          displayNameEn: 'Seder',
          sefariaRef: 'Mishnah.Test',
          sortOrder: 0,
          isLeaf: false,
        ),
      ];

      final mockHierarchyConfig = CurriculumHierarchyConfig(
        curriculumId: CurriculumId.mishnayos.storageKey,
        levelLabels: const ['Seder'],
        totalItems: 1,
      );

      when(() => mockFetcher.curriculumId)
          .thenReturn(CurriculumId.mishnayos.storageKey);
      when(() => mockFetcher.fetchAllContent()).thenAnswer(
        (_) async => FetchResult(
          items: mockItems,
          hierarchyConfig: mockHierarchyConfig,
        ),
      );

      when(() => mockSyncEngine.pushCurriculumImportMetadata(
            curriculumId: any(named: 'curriculumId'),
            itemCount: any(named: 'itemCount'),
            importedAt: any(named: 'importedAt'),
          )).thenAnswer((_) async {});

      importService = CurriculumImportService(
        database: database,
        fetchers: {CurriculumId.mishnayos.storageKey: mockFetcher},
        syncEngine: mockSyncEngine,
        logger: mockLogger,
      );

      await importService.importCurriculum(CurriculumId.mishnayos);

      // Verify stage definitions were seeded
      final stages = await database.stageDao
          .getStageDefinitionsByCurriculum(CurriculumId.mishnayos.storageKey);

      expect(stages.length, equals(3));
      expect(stages[0].stageName, equals('learn'));
      expect(stages[0].delayDays, equals(0));
      expect(stages[1].stageName, equals('chazara1'));
      expect(stages[1].delayDays, equals(1));
      expect(stages[2].stageName, equals('chazara2'));
      expect(stages[2].delayDays, equals(7));
    });

    test('rolls back transaction on API error (AC: Unit test)', () async {
      final database = await createTestDatabase();
      addTearDown(database.close);

      when(() => mockFetcher.curriculumId)
          .thenReturn(CurriculumId.mishnayos.storageKey);
      when(() => mockFetcher.fetchAllContent()).thenThrow(
        const SefariaApiException('Network error', statusCode: 500),
      );

      importService = CurriculumImportService(
        database: database,
        fetchers: {CurriculumId.mishnayos.storageKey: mockFetcher},
        syncEngine: mockSyncEngine,
        logger: mockLogger,
      );

      // Attempt import - should fail
      expect(
        () => importService.importCurriculum(CurriculumId.mishnayos),
        throwsA(isA<SefariaApiException>()),
      );

      // Verify no items were inserted (transaction rolled back)
      final count = await database.contentDao
          .getContentItemCountByCurriculum(CurriculumId.mishnayos.storageKey);
      expect(count, equals(0));
    });

    test('handles cancellation mid-import (AC: Unit test)', () async {
      final database = await createTestDatabase();
      addTearDown(database.close);

      final mockItems = List.generate(
        1000,
        (i) => ContentItem(
          curriculumId: CurriculumId.mishnayos.storageKey,
          level1: 'Test',
          displayNameHe: 'Test $i',
          displayNameEn: 'Test $i',
          sefariaRef: 'Test.$i',
          sortOrder: i,
          isLeaf: true,
        ),
      );

      final mockHierarchyConfig = CurriculumHierarchyConfig(
        curriculumId: CurriculumId.mishnayos.storageKey,
        levelLabels: const ['Test'],
        totalItems: 1000,
      );

      when(() => mockFetcher.curriculumId)
          .thenReturn(CurriculumId.mishnayos.storageKey);
      when(() => mockFetcher.fetchAllContent()).thenAnswer(
        (_) async {
          // Simulate delay to allow cancellation
          await Future.delayed(const Duration(milliseconds: 100));
          return FetchResult(
            items: mockItems,
            hierarchyConfig: mockHierarchyConfig,
          );
        },
      );

      importService = CurriculumImportService(
        database: database,
        fetchers: {CurriculumId.mishnayos.storageKey: mockFetcher},
        syncEngine: mockSyncEngine,
        logger: mockLogger,
      );

      // Start import and cancel immediately
      final importFuture =
          importService.importCurriculum(CurriculumId.mishnayos);
      importService.cancelImport();

      final result = await importFuture;

      // Should return false (cancelled)
      expect(result, isFalse);

      // Database should be clean (no partial items)
      final count = await database.contentDao
          .getContentItemCountByCurriculum(CurriculumId.mishnayos.storageKey);
      expect(count, equals(0));
    });

    test('uses chunked inserts for large curricula (AC: Unit test)', () async {
      final database = await createTestDatabase();
      addTearDown(database.close);

      // Simulate Chumash with 5,845 items (requires batching)
      final mockItems = List.generate(
        5845,
        (i) => ContentItem(
          curriculumId: CurriculumId.chumash.storageKey,
          level1: 'Sefer${i ~/ 1000}',
          level2: 'Parsha${i ~/ 100}',
          level3: 'Perek${i ~/ 10}',
          level4: 'Pasuk${i % 10}',
          displayNameHe: 'פסוק $i',
          displayNameEn: 'Pasuk $i',
          sefariaRef: 'Torah.Test.$i',
          sortOrder: i,
          isLeaf: true,
        ),
      );

      final mockHierarchyConfig = CurriculumHierarchyConfig(
        curriculumId: CurriculumId.chumash.storageKey,
        levelLabels: const ['Sefer', 'Parsha', 'Perek', 'Pasuk'],
        totalItems: 5845,
      );

      when(() => mockFetcher.curriculumId)
          .thenReturn(CurriculumId.chumash.storageKey);
      when(() => mockFetcher.fetchAllContent()).thenAnswer(
        (_) async => FetchResult(
          items: mockItems,
          hierarchyConfig: mockHierarchyConfig,
        ),
      );

      when(() => mockSyncEngine.pushCurriculumImportMetadata(
            curriculumId: any(named: 'curriculumId'),
            itemCount: any(named: 'itemCount'),
            importedAt: any(named: 'importedAt'),
          )).thenAnswer((_) async {});

      importService = CurriculumImportService(
        database: database,
        fetchers: {CurriculumId.chumash.storageKey: mockFetcher},
        syncEngine: mockSyncEngine,
        logger: mockLogger,
      );

      // Listen to progress to verify batching
      final progressEvents = <ImportProgress>[];
      importService.progressStream.listen(progressEvents.add);

      await importService.importCurriculum(CurriculumId.chumash);

      // Verify all items were inserted
      final count = await database.contentDao
          .getContentItemCountByCurriculum(CurriculumId.chumash.storageKey);
      expect(count, equals(5845));

      // Verify we saw storing progress events (indicating batching)
      final storingEvents = progressEvents.where((e) => e is ImportProgress && e.maybeWhen(storing: (_, __, ___) => true, orElse: () => false));
      expect(storingEvents.isNotEmpty, isTrue);
    });

    test('emits correct progress states during import (AC: Widget test prep)',
        () async {
      final database = await createTestDatabase();
      addTearDown(database.close);

      final mockItems = List.generate(
        10,
        (i) => ContentItem(
          curriculumId: CurriculumId.mishnayos.storageKey,
          level1: 'Test',
          displayNameHe: 'Test $i',
          displayNameEn: 'Test $i',
          sefariaRef: 'Test.$i',
          sortOrder: i,
          isLeaf: true,
        ),
      );

      final mockHierarchyConfig = CurriculumHierarchyConfig(
        curriculumId: CurriculumId.mishnayos.storageKey,
        levelLabels: const ['Test'],
        totalItems: 10,
      );

      when(() => mockFetcher.curriculumId)
          .thenReturn(CurriculumId.mishnayos.storageKey);
      when(() => mockFetcher.fetchAllContent()).thenAnswer(
        (_) async => FetchResult(
          items: mockItems,
          hierarchyConfig: mockHierarchyConfig,
        ),
      );

      when(() => mockSyncEngine.pushCurriculumImportMetadata(
            curriculumId: any(named: 'curriculumId'),
            itemCount: any(named: 'itemCount'),
            importedAt: any(named: 'importedAt'),
          )).thenAnswer((_) async {});

      importService = CurriculumImportService(
        database: database,
        fetchers: {CurriculumId.mishnayos.storageKey: mockFetcher},
        syncEngine: mockSyncEngine,
        logger: mockLogger,
      );

      final progressEvents = <ImportProgress>[];
      final subscription = importService.progressStream.listen(progressEvents.add);
      addTearDown(subscription.cancel);

      await importService.importCurriculum(CurriculumId.mishnayos);

      // Give stream events time to propagate
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify we have progress events
      expect(progressEvents.isNotEmpty, isTrue);

      // Verify we saw completed state at minimum
      final hasCompleted = progressEvents.any((e) => e.maybeWhen(completed: (_, __) => true, orElse: () => false));
      expect(hasCompleted, isTrue);
    });
  });
}
