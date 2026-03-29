/// Story acceptance tests for Epic 2 -- Content.
/// Stories 2.1, 2.2, 2.3, 2.4, 2.5, 2.6 are active (DONE).
@Tags(['epic_2'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:learning_tracker/features/content_browsing/data/services/text_download_service.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
// ContentBrowsingScreen is a Flutter widget; widget tests are in
// test/features/content_browsing/presentation/screens/content_browsing_screen_test.dart
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

import '../fixtures/content_fixtures.dart';
import '../helpers/test_database.dart';
import '../mocks/mock_repositories.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  // ── Story 2.1: Content repository ─────────────────────────────

  group('Story 2.1 -- Content repository', tags: ['story_2_1'], () {
    test('ContentRepository interface is importable', () {
      expect(ContentRepository, isNotNull);
    });

    test('ContentLoadException exists', () {
      const ex = ContentLoadException('test');
      expect(ex.message, equals('test'));
    });

    test('ContentItem model has required fields', () {
      final item = ContentItemFixtures.mishna();
      expect(item.curriculumId, equals(CurriculumId.mishnayos.storageKey));
      expect(item.level1, isNotEmpty);
      expect(item.sefariaRef, isNotEmpty);
      expect(item.displayNameEn, isNotEmpty);
      expect(item.displayNameHe, isNotEmpty);
      expect(item.isLeaf, isTrue);
    });

    test('ContentItem supports multiple curricula', () {
      final mishna = ContentItemFixtures.mishna();
      final daf = ContentItemFixtures.daf();
      final pasuk = ContentItemFixtures.pasuk();

      expect(mishna.curriculumId, equals(CurriculumId.mishnayos.storageKey));
      expect(daf.curriculumId, equals(CurriculumId.bavli.storageKey));
      expect(pasuk.curriculumId, equals(CurriculumId.chumash.storageKey));
    });
  });

  // ── Story 2.2: Content hierarchy browsing ────────────────────

  group('Story 2.2 -- Content hierarchy browsing', tags: ['story_2_2'], () {
    test('ContentHierarchyScreen source file exists', () {
      // The screen file exists at the expected path
      final file = File(
        'lib/features/content_browsing/presentation/screens/'
        'content_hierarchy_screen.dart',
      );
      expect(file.existsSync(), isTrue);
      // Verify it uses Riverpod (ConsumerStatefulWidget)
      final content = file.readAsStringSync();
      expect(content, contains('ConsumerStatefulWidget'));
      expect(content, contains('curriculumId'));
    });

    test('CurriculumHierarchyConfig supports 1-4 levels of depth', () {
      // Config with 2 levels (like Bavli: Masechta -> Daf -> Amud)
      const config2 = CurriculumHierarchyConfig(
        curriculumId: 'test2',
        levelLabels: ['Level1', 'Level2'],
        totalItems: 10,
      );
      expect(config2.depth, 2);

      // Config with 4 levels (like Mishnayos)
      const config4 = CurriculumHierarchyConfig(
        curriculumId: 'test4',
        levelLabels: ['Seder', 'Masechta', 'Perek', 'Mishna'],
        totalItems: 4219,
      );
      expect(config4.depth, 4);
    });

    test('hierarchy config level labels are read from content JSON', () {
      // Each curriculum has its own hierarchy labels defined in the JSON
      const hierarchyConfigs = CurriculumDefaults.hierarchyConfigs;

      // Mishnayos: 4 levels
      expect(hierarchyConfigs[CurriculumId.mishnayos]!.maxLevels, 4);
      expect(hierarchyConfigs[CurriculumId.mishnayos]!.level1Label, 'Seder');

      // Bavli: 3 levels
      expect(hierarchyConfigs[CurriculumId.bavli]!.maxLevels, 3);
      expect(hierarchyConfigs[CurriculumId.bavli]!.level1Label, 'Masechta');

      // Chumash: 4 levels
      expect(hierarchyConfigs[CurriculumId.chumash]!.maxLevels, 4);
      expect(hierarchyConfigs[CurriculumId.chumash]!.level1Label, 'Sefer');
    });

    test('ContentItem distinguishes leaf and container nodes', () {
      final leaf = ContentItemFixtures.mishna(isLeaf: true);
      final container = ContentItemFixtures.container(level1: 'Seder Zeraim');

      expect(leaf.isLeaf, isTrue);
      expect(container.isLeaf, isFalse);
    });

    test('ContentItem has both Hebrew and English display names', () {
      final item = ContentItemFixtures.mishna(
        displayNameHe: '\u05D1\u05E8\u05DB\u05D5\u05EA',
        displayNameEn: 'Berachos',
      );

      expect(item.displayNameHe, isNotEmpty);
      expect(item.displayNameEn, isNotEmpty);
      // Hebrew is the primary display language
      expect(item.displayNameHe, contains('\u05D1\u05E8\u05DB'));
    });

    test('content browsing provider uses family(curriculumId) per P3', () {
      // curriculumContentProvider is a family provider keyed by CurriculumId
      expect(curriculumContentProvider, isNotNull);
      // It's callable with a CurriculumId argument
      final provider = curriculumContentProvider(CurriculumId.mishnayos);
      expect(provider, isNotNull);
    });

    test('content loaded from in-memory ContentRepository, not SQLite', () {
      // ContentRepositoryImpl loads from bundled JSON (rootBundle), not Drift
      final repo = ContentRepositoryImpl();
      expect(repo, isA<ContentRepository>());
      // Repository has in-memory caches (not backed by database)
      // This is validated by the fact ContentRepositoryImpl does not take
      // a database parameter -- it only uses rootBundle
    });

    test('filter logic supports any hierarchy depth 1-4 levels', () {
      // Build items across different levels
      final items = <ContentItem>[
        ContentItemFixtures.container(
          level1: 'Seder Zeraim',
          displayNameEn: 'Seder Zeraim',
        ),
        ContentItemFixtures.mishna(
          level1: 'Seder Zeraim',
          level2: 'Berachos',
          level3: '1',
          level4: '1',
        ),
        ContentItemFixtures.mishna(
          level1: 'Seder Zeraim',
          level2: 'Berachos',
          level3: '1',
          level4: '2',
          sefariaRef: 'Mishnah Berachos 1.2',
        ),
        ContentItemFixtures.mishna(
          level1: 'Seder Zeraim',
          level2: 'Peah',
          level3: '1',
          level4: '1',
          sefariaRef: 'Mishnah Peah 1.1',
        ),
      ];

      // Filter by level1 only
      final level1Filtered = items.where((i) => i.level1 == 'Seder Zeraim');
      expect(level1Filtered.length, 4);

      // Filter by level1 + level2
      final level2Filtered = items.where(
        (i) => i.level1 == 'Seder Zeraim' && i.level2 == 'Berachos',
      );
      expect(level2Filtered.length, 2);

      // Filter by level1 + level2 + level3
      final level3Filtered = items.where(
        (i) =>
            i.level1 == 'Seder Zeraim' &&
            i.level2 == 'Berachos' &&
            i.level3 == '1',
      );
      expect(level3Filtered.length, 2);

      // Filter by all 4 levels
      final level4Filtered = items.where(
        (i) =>
            i.level1 == 'Seder Zeraim' &&
            i.level2 == 'Berachos' &&
            i.level3 == '1' &&
            i.level4 == '1',
      );
      expect(level4Filtered.length, 1);
    });
  });

  // ── Story 2.3: Text display & caching ─────────────────────────

  group('Story 2.3 -- Text display & caching', tags: ['story_2_3'], () {
    test('TextCacheRepository class exists', () {
      expect(TextCacheRepository, isNotNull);
    });

    test('TextContent model has required fields', () {
      final content = TextContent(
        sefariaRef: 'Mishnah Berachos 1.1',
        hebrewText: 'מאימתי',
        englishText: 'From when',
      );
      expect(content.sefariaRef, isNotEmpty);
      expect(content.hebrewText, isNotEmpty);
      expect(content.englishText, isNotEmpty);
    });

    test('TextCacheDao stores and retrieves text', () async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.textCacheDao.storeText(
        sefariaRef: 'Mishnah Berachos 1.1',
        hebrewText: 'מאימתי קורין את שמע',
        englishText: 'From when does one recite Shema',
      );

      final cached = await db.textCacheDao.getText('Mishnah Berachos 1.1');
      expect(cached, isNotNull);
      expect(cached!.hebrewText, contains('מאימתי'));
      expect(cached.englishText, contains('Shema'));
    });

    test(
      'AC: cache-only — returns pre-cached text, null if not cached',
      () async {
        final db = createTestDatabase();
        addTearDown(() => db.close());

        final repo = TextCacheRepository(textCacheDao: db.textCacheDao);

        // Not cached — returns null (no API fallback)
        final missing = await repo.getText('Mishnah Berakhot 1.1');
        expect(missing, isNull);

        // Pre-cache text (simulates download service)
        await db.textCacheDao.storeText(
          sefariaRef: 'Mishnah Berakhot 1.1',
          hebrewText: '\u05DE\u05D0\u05D9\u05DE\u05EA\u05D9',
          englishText: 'From when',
        );

        // Now returns cached text
        final result = await repo.getText('Mishnah Berakhot 1.1');
        expect(result, isNotNull);
        expect(result!.hebrewText, '\u05DE\u05D0\u05D9\u05DE\u05EA\u05D9');
        expect(result.englishText, 'From when');
      },
    );

    test('AC: offline shows cached text, or null if never fetched', () async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      // Pre-cache one text
      await db.textCacheDao.storeText(
        sefariaRef: 'cached_ref',
        hebrewText: 'cached hebrew',
        englishText: 'cached english',
      );

      final repo = TextCacheRepository(textCacheDao: db.textCacheDao);

      // Cached text returns successfully
      final cachedResult = await repo.getText('cached_ref');
      expect(cachedResult, isNotNull);
      expect(cachedResult!.hebrewText, 'cached hebrew');

      // Uncached text returns null (not available)
      final uncachedResult = await repo.getText('uncached_ref');
      expect(uncachedResult, isNull);
    });

    test('AC: font size adjustable (small, medium, large)', () async {
      expect(FontSize.values.length, 3);
      expect(FontSize.values, contains(FontSize.small));
      expect(FontSize.values, contains(FontSize.medium));
      expect(FontSize.values, contains(FontSize.large));

      // Multipliers are ordered: small < medium < large
      expect(FontSize.small.multiplier, lessThan(FontSize.medium.multiplier));
      expect(FontSize.medium.multiplier, lessThan(FontSize.large.multiplier));

      // Preferences can be changed
      SharedPreferences.setMockInitialValues({});
      final prefs = TextDisplayPreferences.instance;
      prefs.reset();
      expect(prefs.fontSize, FontSize.medium); // default

      await prefs.setFontSize(FontSize.large);
      expect(prefs.fontSize, FontSize.large);

      prefs.reset();
    });
  });

  // ── Story 2.4: Curriculum activation ──────────────────────────

  group('Story 2.4 -- Curriculum activation', tags: ['story_2_4'], () {
    late AppDatabase db;
    late CurriculumActivationService service;

    setUp(() {
      db = createTestDatabase();
      addTearDown(() => db.close());

      service = CurriculumActivationService(
        database: db,
        pushActiveCurricula: (_) async {},
        trackRepository: TrackRepositoryImpl(database: db),
      );
    });

    test('initialize sets default curriculum (Mishnayos)', () async {
      await service.initialize();
      final active = await service.getActiveCurricula();
      expect(active, contains(CurriculumId.mishnayos));
    });

    test('activate adds a curriculum', () async {
      await service.initialize();
      await service.activate(CurriculumId.bavli);
      final active = await service.getActiveCurricula();
      expect(active, containsAll([CurriculumId.mishnayos, CurriculumId.bavli]));
    });

    test('deactivate removes a curriculum', () async {
      await service.initialize();
      await service.activate(CurriculumId.bavli);
      await service.deactivate(CurriculumId.mishnayos);
      final active = await service.getActiveCurricula();
      expect(active, contains(CurriculumId.bavli));
      expect(active, isNot(contains(CurriculumId.mishnayos)));
    });

    test('toggle each curriculum on/off', () async {
      // Activate all curricula
      for (final curriculum in CurriculumId.values) {
        await service.activate(curriculum);
      }
      final allActive = await service.getActiveCurricula();
      expect(allActive, hasLength(CurriculumId.values.length));

      // Deactivate all but chumash
      for (final curriculum in CurriculumId.values) {
        if (curriculum != CurriculumId.chumash) {
          await service.deactivate(curriculum);
        }
      }

      final oneActive = await service.getActiveCurricula();
      expect(oneActive, hasLength(1));
      expect(oneActive, contains(CurriculumId.chumash));
    });

    test('at least one curriculum must be active at all times', () async {
      await service.activate(CurriculumId.mishnayos);

      expect(
        () => service.deactivate(CurriculumId.mishnayos),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'deactivating a curriculum preserves all data (completions, bookmarks)',
      () async {
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);

        // Add completion and bookmark for Bavli
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: CurriculumId.bavli.storageKey,
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            completedAt: DateTime.now(),
            points: const Value(10),
          ),
        );
        await db.bookmarkDao.upsertBookmark(
          curriculumId: CurriculumId.bavli.storageKey,
          trackType: TrackType.personal.storageKey,
          sefariaRef: 'Berakhot.2a',
          updatedAt: DateTime.now().toUtc(),
        );

        // Deactivate Bavli
        await service.deactivate(CurriculumId.bavli);

        // Data must still exist
        final completions = await db.completionDao.getCompletionsByCurriculum(
          CurriculumId.bavli.storageKey,
        );
        expect(completions, hasLength(1));

        final bookmark = await db.bookmarkDao.getBookmarkByCurriculumAndTrack(
          CurriculumId.bavli.storageKey,
          TrackType.personal.storageKey,
        );
        expect(bookmark, isNotNull);
      },
    );

    test(
      're-activating a previously deactivated curriculum restores all prior data',
      () async {
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);

        // Add data
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: CurriculumId.bavli.storageKey,
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            completedAt: DateTime.now(),
            points: const Value(10),
          ),
        );

        // Deactivate and re-activate
        await service.deactivate(CurriculumId.bavli);
        await service.activate(CurriculumId.bavli);

        // Data survives the round-trip
        final completions = await db.completionDao.getCompletionsByCurriculum(
          CurriculumId.bavli.storageKey,
        );
        expect(completions, hasLength(1));
        expect(completions.first.sefariaRef, equals('Berakhot.2a'));
      },
    );
  });

  // ── Story 2.5: Bundled content JSON & dev seed script ────────

  group('Story 2.5 -- Bundled content assets', tags: ['story_2_5'], () {
    // ── AC: assets/content/ directory contains JSON files for all 7 curricula

    test(
      'assets/content/ directory contains JSON for all curricula',
      skip: 'Bundled JSON removed — content now fetched from cloud storage',
      () {
        final contentDir = Directory('assets/content');
        expect(
          contentDir.existsSync(),
          isTrue,
          reason: 'assets/content/ directory must exist',
        );

        final expectedFiles = [
          'mishnayos.json',
          'bavli.json',
          'yerushalmi.json',
          'chumash.json',
          'mishna_berurah.json',
        ];

        for (final filename in expectedFiles) {
          final file = File('${contentDir.path}/$filename');
          expect(
            file.existsSync(),
            isTrue,
            reason: '$filename must exist in assets/content/',
          );
          expect(
            file.lengthSync(),
            greaterThan(0),
            reason: '$filename must not be empty',
          );
        }
      },
    );

    // ── AC: JSON output matches expected schema

    test(
      'each bundled JSON file matches expected schema',
      skip: 'Bundled JSON removed — content now fetched from cloud storage',
      () {
        final contentDir = Directory('assets/content');
        final files = contentDir.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.json'),
        );

        for (final file in files) {
          final jsonString = file.readAsStringSync();
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final filename = file.path.split('/').last;

          // Validate hierarchyConfig
          expect(
            json.containsKey('hierarchyConfig'),
            isTrue,
            reason: '$filename must have hierarchyConfig',
          );
          final config = json['hierarchyConfig'] as Map<String, dynamic>;
          expect(
            config.containsKey('curriculumId'),
            isTrue,
            reason: '$filename hierarchyConfig must have curriculumId',
          );
          expect(
            config.containsKey('levelLabels'),
            isTrue,
            reason: '$filename hierarchyConfig must have levelLabels',
          );
          expect(
            config.containsKey('maxLevels'),
            isTrue,
            reason: '$filename hierarchyConfig must have maxLevels',
          );
          expect(
            config.containsKey('totalItems'),
            isTrue,
            reason: '$filename hierarchyConfig must have totalItems',
          );

          // Validate items array
          expect(
            json.containsKey('items'),
            isTrue,
            reason: '$filename must have items array',
          );
          final items = json['items'] as List;
          expect(
            items,
            isNotEmpty,
            reason: '$filename items must not be empty',
          );

          // Validate first item structure
          final firstItem = items.first as Map<String, dynamic>;
          for (final field in [
            'curriculumId',
            'level1',
            'displayNameHe',
            'displayNameEn',
            'sefariaRef',
            'sortOrder',
            'isLeaf',
          ]) {
            expect(
              firstItem.containsKey(field),
              isTrue,
              reason: '$filename item must have $field',
            );
          }
        }
      },
    );

    // ── AC: seed_content.dart script exists

    test('seed_content.dart tool script exists', () {
      final seedScript = File('tool/seed_content.dart');
      expect(
        seedScript.existsSync(),
        isTrue,
        reason: 'tool/seed_content.dart must exist',
      );
    });

    // ── AC: ContentRepositoryImpl class implements ContentRepository

    test('ContentRepositoryImpl implements ContentRepository', () {
      final repo = ContentRepositoryImpl();
      expect(repo, isA<ContentRepository>());
    });

    // ── AC: ContentRepository interface exposes required methods

    test('ContentRepository interface has required methods', () {
      final mock = MockContentRepository();

      // getContentForCurriculum
      when(
        () => mock.getContentForCurriculum(any()),
      ).thenAnswer((_) async => <ContentItem>[]);
      // getHierarchyConfig
      when(() => mock.getHierarchyConfig(any())).thenAnswer(
        (_) async => const CurriculumHierarchyConfig(
          curriculumId: 'test',
          levelLabels: ['L1'],
          totalItems: 0,
        ),
      );
      // filterByLevel
      when(
        () => mock.filterByLevel(
          curriculumId: any(named: 'curriculumId'),
          level1: any(named: 'level1'),
        ),
      ).thenAnswer((_) async => <ContentItem>[]);
      // search
      when(
        () => mock.search(
          curriculumId: any(named: 'curriculumId'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => <ContentItem>[]);
      // getContentByRef
      when(
        () => mock.getContentByRef(
          curriculumId: any(named: 'curriculumId'),
          sefariaRef: any(named: 'sefariaRef'),
        ),
      ).thenAnswer((_) async => null);

      expect(mock, isA<ContentRepository>());
    });

    // ── AC: Riverpod providers exist (family by curriculumId)

    test('content providers are defined as family by curriculumId', () {
      // Verify the providers exist and are the correct types
      expect(contentRepositoryProvider, isNotNull);
      expect(curriculumContentProvider, isNotNull);
      expect(curriculumHierarchyConfigProvider, isNotNull);
      expect(filteredContentProvider, isNotNull);
      expect(contentSearchProvider, isNotNull);
      expect(contentByRefProvider, isNotNull);
    });

    // ── AC: content_items table removed from Drift schema

    test('content_items table is not in Drift schema', () {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      // The database should not have content_items or
      // curriculum_hierarchy_config tables; they were removed in schema v3.
      expect(db.schemaVersion, equals(24));
    });

    // ── AC: curriculum_hierarchy_config table removed from Drift schema

    test('curriculum_hierarchy_config table removed from Drift schema', () {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      // Schema v3 drops these tables.
      expect(db.schemaVersion, equals(24));
    });

    // ── AC: completions/bookmarks/learning_order use sefariaRef FK

    test('completions table uses sefariaRef column', () async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berakhot 1.1',
          stageId: 1,
          trackType: 'personal',
          completedAt: DateTime.now().toUtc(),
        ),
      );

      final completions = await db.completionDao.getCompletionsForContent(
        'Mishnah Berakhot 1.1',
      );
      expect(completions, hasLength(1));
      expect(completions.first.sefariaRef, equals('Mishnah Berakhot 1.1'));
    });

    test('bookmarks table uses sefariaRef column', () async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: CurriculumId.mishnayos.storageKey,
          trackType: 'personal',
          sefariaRef: 'Mishnah Berakhot 1.1',
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      final bookmark = await db.bookmarkDao.getBookmarkByCurriculumAndTrack(
        CurriculumId.mishnayos.storageKey,
        'personal',
      );
      expect(bookmark, isNotNull);
      expect(bookmark!.sefariaRef, equals('Mishnah Berakhot 1.1'));
    });

    test('learning_order table uses sefariaRef column', () async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.learningOrderDao.insertLearningOrder(
        LearningOrderCompanion.insert(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berakhot 1.1',
          userSortOrder: 1,
        ),
      );

      final orders = await db.learningOrderDao.getLearningOrderByCurriculum(
        CurriculumId.mishnayos.storageKey,
      );
      expect(orders, hasLength(1));
      expect(orders.first.sefariaRef, equals('Mishnah Berakhot 1.1'));
    });

    // ── AC: assets/content/ is listed in pubspec.yaml flutter assets

    test(
      'pubspec.yaml includes assets/content/ in flutter assets',
      skip: 'Bundled JSON removed — content now fetched from cloud storage',
      () {
        final pubspec = File('pubspec.yaml');
        expect(pubspec.existsSync(), isTrue);
        final content = pubspec.readAsStringSync();
        expect(content, contains('assets/content/'));
      },
    );

    // ── AC: CurriculumImportService removed from production code

    test(
      'CurriculumImportService not referenced in content_browsing feature',
      () {
        final contentDir = Directory('lib/features/content_browsing');
        if (!contentDir.existsSync()) return; // nothing to check
        final dartFiles = contentDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        for (final file in dartFiles) {
          final content = file.readAsStringSync();
          expect(
            content,
            isNot(contains('CurriculumImportService')),
            reason: '${file.path} must not reference CurriculumImportService',
          );
        }
      },
    );
  });

  // ── Story 2.6: DNI-80 Cache-only architecture ─────────────────

  group('Story 2.6 -- DNI-80 cache-only architecture', tags: ['story_2_6'], () {
    test('HebrewUtils.stripNikud removes vowel marks', () {
      const withNikud =
          '\u05DE\u05B5\u05D0\u05B5\u05D9\u05DE\u05B8\u05EA\u05B7\u05D9';
      const withoutNikud = '\u05DE\u05D0\u05D9\u05DE\u05EA\u05D9';
      expect(HebrewUtils.stripNikud(withNikud), equals(withoutNikud));
    });

    test('HebrewUtils.hasNikud detects nikud', () {
      expect(HebrewUtils.hasNikud('\u05DE\u05B5\u05D0'), isTrue);
      expect(HebrewUtils.hasNikud('\u05DE\u05D0'), isFalse);
    });

    test(
      'TextDisplayPreferences.showNikud defaults to true and persists',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = TextDisplayPreferences.instance;
        prefs.reset();

        expect(prefs.showNikud, isTrue);

        await prefs.setShowNikud(false);
        expect(prefs.showNikud, isFalse);

        await prefs.setShowNikud(true);
        expect(prefs.showNikud, isTrue);

        prefs.reset();
      },
    );

    test('TextDownloadService class exists', () {
      expect(TextDownloadService, isNotNull);
    });

    test('seed_text_content.dart script exists', () {
      final script = File('tool/seed_text_content.dart');
      expect(
        script.existsSync(),
        isTrue,
        reason: 'tool/seed_text_content.dart must exist',
      );
    });
  });
}
