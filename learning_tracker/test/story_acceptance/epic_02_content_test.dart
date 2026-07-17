/// Story acceptance tests for Epic 2 -- Content.
/// Stories 2.1, 2.2, 2.3, 2.4, 2.5, 2.6 are active (DONE).
@Tags(['epic_2'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
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
import 'package:learning_tracker/features/settings/domain/exceptions/last_active_curriculum_exception.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

import '../fixtures/content_fixtures.dart';
import '../helpers/drift_memory.dart';
import '../helpers/test_database.dart';
import '../mocks/mock_repositories.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  // ── Story 2.1: Content repository ─────────────────────────────

  group('Story 2.1 -- Content repository', tags: ['story_2_1'], () {
    test('MockContentRepository implements ContentRepository', () {
      // AUD-t-story-acceptance-06: `expect(ContentRepository, isNotNull)` on
      // an abstract class Type literal is a compile-time tautology. Verify
      // the actual runtime relationship on a concrete implementation.
      expect(MockContentRepository(), isA<ContentRepository>());
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

    test('hierarchy level labels come from the central CurriculumLabels', () {
      // Mishnayos: 4 levels, top label "Seder"
      expect(CurriculumLabels.depth(CurriculumId.mishnayos), 4);
      expect(CurriculumLabels.level(CurriculumId.mishnayos, 1).en, 'Seder');

      // Bavli: 4 levels (Seder > Masechta > Daf > Amud)
      expect(CurriculumLabels.depth(CurriculumId.bavli), 4);
      expect(CurriculumLabels.level(CurriculumId.bavli, 1).en, 'Seder');

      // Chumash: 3 levels (Sefer > Perek > Pasuk) — the bundled chumash.json
      // does not include a Parsha level, so the metadata models 3 levels.
      expect(CurriculumLabels.depth(CurriculumId.chumash), 3);
      expect(CurriculumLabels.level(CurriculumId.chumash, 1).en, 'Sefer');
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
      // AUD-t-story-acceptance-06: both `curriculumContentProvider` (a
      // non-nullable top-level provider constant) and its family-invocation
      // result are compile-time non-null, so `isNotNull` on either is a
      // tautology. Assert the actual family contract instead -- equal
      // curriculumId arguments must resolve to the identical provider
      // (Riverpod's per-argument caching), distinct arguments to distinct
      // providers.
      final mishnayos = curriculumContentProvider(CurriculumId.mishnayos);
      final mishnayosAgain = curriculumContentProvider(CurriculumId.mishnayos);
      final bavli = curriculumContentProvider(CurriculumId.bavli);

      expect(mishnayos, equals(mishnayosAgain));
      expect(mishnayos, isNot(equals(bavli)));
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
    test('TextCacheRepository queries a real content database', () async {
      // AUD-t-story-acceptance-06: `expect(TextCacheRepository, isNotNull)`
      // on a Type literal is a compile-time tautology. Construct a real
      // repository backed by an in-memory content database and exercise an
      // actual method/return value.
      final contentDb = createTestContentDatabase();
      addTearDown(() => contentDb.close());
      final repo = TextCacheRepository(
        textCacheDao: contentDb.contentTextCacheDao,
        dailyContentDao: contentDb.dailyContentDao,
      );

      expect(await repo.getCachedRefs(), isEmpty);
    });

    test('TextContent model has required fields', () {
      final content = TextContent.single(
        sefariaRef: 'Mishnah Berachos 1.1',
        hebrewText: 'מאימתי',
        englishText: 'From when',
      );
      expect(content.sefariaRef, isNotEmpty);
      expect(content.hebrewText, isNotEmpty);
      expect(content.englishText, isNotEmpty);
    });

    test('ContentTextCacheDao reads text from content database', () async {
      final contentDb = createTestContentDatabase();
      addTearDown(() => contentDb.close());

      // Fresh content DB has no cached text (seeded DB would have data)
      final cached = await contentDb.contentTextCacheDao.getText(
        'Mishnah Berachos 1.1',
      );
      expect(cached, isNull);
    });

    test(
      'AC: cache-only — returns null if not cached (no API fallback)',
      () async {
        final contentDb = createTestContentDatabase();
        addTearDown(() => contentDb.close());

        final repo = TextCacheRepository(
          textCacheDao: contentDb.contentTextCacheDao,
          dailyContentDao: contentDb.dailyContentDao,
        );

        // Not cached — returns null (no API fallback)
        final missing = await repo.getText('Mishnah Berakhot 1.1');
        expect(missing, isNull);
      },
    );

    test('AC: offline shows null if never fetched', () async {
      final contentDb = createTestContentDatabase();
      addTearDown(() => contentDb.close());

      final repo = TextCacheRepository(
        textCacheDao: contentDb.contentTextCacheDao,
        dailyContentDao: contentDb.dailyContentDao,
      );

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
    late UserDatabase db;
    late int trackId;
    late CurriculumActivationService service;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      // seedProfileZero needed: CurriculumActivationService defaults to
      // profileId=0; StudyDayConfigDao.seedDefaults inserts with profile_id=0.
      await seedProfileZero(db);
      trackId = await seedTrack(db, profileId: 1);
      addTearDown(() => db.close());

      service = CurriculumActivationService(
        database: db,
        pushCurriculumTrack: (_) async {},
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
        throwsA(isA<LastActiveCurriculumException>()),
      );
    });

    test(
      'deactivating a curriculum preserves all data (completions, bookmarks)',
      () async {
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);

        // Look up the bavli track created by service.activate
        final bavliTrackId = (await db.trackDao.getAllTracks(
          CurriculumId.bavli,
        )).first.id;

        // Add completion and bookmark for Bavli
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.bavli.storageKey,
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: 'personal',
            trackId: Value(bavliTrackId),
            eventTimestamp: DateTime.now(),
            points: const Value(10),
          ),
        );
        await db.bookmarkDao.upsertBookmark(
          curriculumId: CurriculumId.bavli.storageKey,
          trackId: bavliTrackId,
          profileId: 1,
          sefariaRef: 'Berakhot.2a',
          updatedAt: DateTime.now().toUtc(),
        );

        // Deactivate Bavli
        await service.deactivate(CurriculumId.bavli);

        // Data must still exist
        final completions = await db.completionDao
            .internalGetCompletionsByCurriculumCrossProfile(
              CurriculumId.bavli.storageKey,
              scope: CrossProfileScope.dataExport,
            );
        expect(completions, hasLength(1));

        final bookmark = await db.bookmarkDao.getBookmarkByCurriculumAndTrack(
          CurriculumId.bavli.storageKey,
          bavliTrackId,
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
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.bavli.storageKey,
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: DateTime.now(),
            points: const Value(10),
          ),
        );

        // Deactivate and re-activate
        await service.deactivate(CurriculumId.bavli);
        await service.activate(CurriculumId.bavli);

        // Data survives the round-trip
        final completions = await db.completionDao
            .internalGetCompletionsByCurriculumCrossProfile(
              CurriculumId.bavli.storageKey,
              scope: CrossProfileScope.dataExport,
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

    // ── Regression: every bundled item ships a Hebrew displayNameHe
    //
    // Mishneh Torah's L1 sefer rows historically shipped English in
    // BOTH displayNameHe and displayNameEn (e.g. "Sefer Madda" twice),
    // which made the unified label renderer return English in Hebrew
    // mode regardless of which screen it was called from. This test
    // walks every curriculum's bundled JSON and fails if any item's
    // displayNameHe lacks a Hebrew character.
    test('every bundled item has a Hebrew displayNameHe', () {
      // Hebrew block: U+0590..U+05FF
      bool hasHebrewChar(String s) => s.runes.any((r) {
        return r >= 0x0590 && r <= 0x05FF;
      });

      final dir = Directory('assets/content/hierarchy');
      if (!dir.existsSync()) return; // skip when bundled assets removed

      final failures = <String>[];
      for (final file in dir.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.json'),
      )) {
        final data =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final items = (data['items'] as List).cast<Map<String, dynamic>>();
        for (final item in items) {
          final he = item['displayNameHe'] as String? ?? '';
          if (!hasHebrewChar(he)) {
            failures.add(
              '${file.path.split('/').last}: '
              'sefariaRef=${item['sefariaRef']}, '
              'displayNameHe=$he',
            );
            if (failures.length >= 10) break;
          }
        }
        if (failures.length >= 10) break;
      }

      expect(
        failures,
        isEmpty,
        reason:
            'Items shipping with English-only displayNameHe '
            '(first 10 shown):\n${failures.join('\n')}',
      );
    });

    // ── Regression: Shaarei Teshuvah hierarchy is clean (no "h" placeholder)

    test(
      'Shaarei Teshuvah entries in mussar.json have valid level2 values',
      () {
        final file = File('assets/content/hierarchy/mussar.json');
        if (!file.existsSync()) return; // skip when bundled assets removed
        final data =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final items = (data['items'] as List).cast<Map<String, dynamic>>();
        final stItems = items
            .where((i) => i['level1'] == 'Shaarei Teshuvah')
            .toList();

        // The root sefer entry exists (no level2/3) plus actual structured
        // gates and verses.
        expect(stItems.length, greaterThan(50));

        for (final item in stItems) {
          final level2 = item['level2'] as String?;
          // The historical bug placed the literal letter 'h' here as a
          // placeholder. After the data fix, level2 must be either null
          // (root sefer entry) or a numeric gate index.
          expect(
            level2 == null || int.tryParse(level2) != null,
            isTrue,
            reason:
                'Shaarei Teshuvah item has invalid level2=$level2 in '
                '${item['sefariaRef']}',
          );
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

    // ── AC: seed_content.dart reuses the tested Sefaria Dio client
    // (AUD-core-network-02: it must not hand-roll its own untested,
    // retry-less, logger-less Dio() -- that bypasses createSefariaClient's
    // retry interceptor and redacted logging, both fully covered by
    // test/core/network/dio_client_test.dart).

    test(
      'seed_content.dart wires the tested createSefariaClient() Dio client',
      () {
        final source = File('tool/seed_content.dart').readAsStringSync();
        expect(
          source,
          contains('createSefariaClient('),
          reason:
              'tool/seed_content.dart must call createSefariaClient() from '
              'tool/lib/dio_client.dart instead of constructing its own Dio '
              'inline (AUD-core-network-02)',
        );
        expect(
          RegExp(r'Dio\(\s*BaseOptions\(').hasMatch(source),
          isFalse,
          reason:
              'tool/seed_content.dart must not hand-roll Dio(BaseOptions(...)) '
              '-- reuse createSefariaClient() so the retry interceptor and '
              'redacted logging actually apply (AUD-core-network-02)',
        );
      },
    );

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

    test('content providers are defined as family by curriculumId', () async {
      // AUD-t-story-acceptance-06: every provider referenced here is a
      // non-nullable top-level constant, so `isNotNull` on any of them is a
      // compile-time tautology. Override the repository with a mock and
      // read each provider through a real ProviderContainer instead,
      // verifying it actually dispatches to the repository with the
      // curriculumId (and other args) it was invoked with.
      final mockRepo = MockContentRepository();
      when(
        () => mockRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => <ContentItem>[]);
      when(() => mockRepo.getHierarchyConfig(any())).thenAnswer(
        (_) async => const CurriculumHierarchyConfig(
          curriculumId: 'test',
          levelLabels: ['L1'],
          totalItems: 0,
        ),
      );
      when(
        () => mockRepo.filterByLevel(
          curriculumId: any(named: 'curriculumId'),
          level1: any(named: 'level1'),
          level2: any(named: 'level2'),
          level3: any(named: 'level3'),
          level4: any(named: 'level4'),
        ),
      ).thenAnswer((_) async => <ContentItem>[]);
      when(
        () => mockRepo.search(
          curriculumId: any(named: 'curriculumId'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => <ContentItem>[]);
      when(
        () => mockRepo.getContentByRef(
          curriculumId: any(named: 'curriculumId'),
          sefariaRef: any(named: 'sefariaRef'),
        ),
      ).thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [contentRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      expect(container.read(contentRepositoryProvider), same(mockRepo));

      await container.read(
        curriculumContentProvider(CurriculumId.bavli).future,
      );
      verify(
        () => mockRepo.getContentForCurriculum(CurriculumId.bavli),
      ).called(1);

      await container.read(
        curriculumHierarchyConfigProvider(CurriculumId.bavli).future,
      );
      verify(() => mockRepo.getHierarchyConfig(CurriculumId.bavli)).called(1);

      await container.read(
        filteredContentProvider(curriculumId: CurriculumId.bavli).future,
      );
      verify(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.bavli,
          level1: null,
          level2: null,
          level3: null,
          level4: null,
        ),
      ).called(1);

      await container.read(
        contentSearchProvider(
          curriculumId: CurriculumId.bavli,
          query: 'x',
        ).future,
      );
      verify(
        () => mockRepo.search(curriculumId: CurriculumId.bavli, query: 'x'),
      ).called(1);

      await container.read(
        contentByRefProvider(
          curriculumId: CurriculumId.bavli,
          sefariaRef: 'Mishnah Berachos 1.1',
        ).future,
      );
      verify(
        () => mockRepo.getContentByRef(
          curriculumId: CurriculumId.bavli,
          sefariaRef: 'Mishnah Berachos 1.1',
        ),
      ).called(1);
    });

    // ── AC: content_items table removed from Drift schema

    test('content_items table is not in Drift schema', () async {
      // AUD-t-story-acceptance-06 (mergedFrom): `schemaVersion >= 1` never
      // actually inspected the schema for the claimed table removal -- it's
      // true regardless of whether content_items exists. Walk the actual
      // set of live tables instead.
      final db = createTestDatabase();
      await seedProfile(db);
      addTearDown(() => db.close());
      final tableNames = db.allTables.map((t) => t.actualTableName);
      // The database should not have content_items or
      // curriculum_hierarchy_config tables; they were removed in schema v3.
      // v10 adds deleted_at to curriculum_tracks (DNI-317).
      expect(tableNames, isNot(contains('content_items')));
    });

    // ── AC: curriculum_hierarchy_config table removed from Drift schema

    test(
      'curriculum_hierarchy_config table removed from Drift schema',
      () async {
        final db = createTestDatabase();
        await seedProfile(db);
        addTearDown(() => db.close());
        final tableNames = db.allTables.map((t) => t.actualTableName);
        // Schema v3 drops these tables.
        // v10 adds deleted_at to curriculum_tracks (DNI-317).
        expect(tableNames, isNot(contains('curriculum_hierarchy_config')));
      },
    );

    // ── AC: completions/bookmarks/learning_order use sefariaRef FK

    test('completions table uses sefariaRef column', () async {
      final db = createTestDatabase();
      await seedProfile(db);
      addTearDown(() => db.close());
      final trackId = await seedTrack(db, profileId: 1);

      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berakhot 1.1',
          stageId: 1,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: DateTime.now().toUtc(),
        ),
      );

      final completions = await db.completionDao
          .internalGetCompletionsForContentCrossProfile(
            'Mishnah Berakhot 1.1',
            scope: CrossProfileScope.dataExport,
          );
      expect(completions, hasLength(1));
      expect(completions.first.sefariaRef, equals('Mishnah Berakhot 1.1'));
    });

    test('bookmarks table uses sefariaRef column', () async {
      final db = createTestDatabase();
      await seedProfile(db);
      addTearDown(() => db.close());
      final bTrackId = await seedTrack(db, profileId: 1);
      await db.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          trackId: bTrackId,
          sefariaRef: 'Mishnah Berakhot 1.1',
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      final bookmark = await db.bookmarkDao.getBookmarkByCurriculumAndTrack(
        CurriculumId.mishnayos.storageKey,
        bTrackId,
      );
      expect(bookmark, isNotNull);
      expect(bookmark!.sefariaRef, equals('Mishnah Berakhot 1.1'));
    });

    test('learning_order table uses sefariaRef column', () async {
      final db = createTestDatabase();
      await seedProfile(db);
      addTearDown(() => db.close());
      await db.learningOrderDao.insertLearningOrder(
        LearningOrderCompanion.insert(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berakhot 1.1',
          userSortOrder: 1,
        ),
      );

      final orders = await db.learningOrderDao.getLearningOrderByCurriculum(
        CurriculumId.mishnayos.storageKey,
        profileId: 1,
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

    test(
      'TextDownloadService reports not-downloaded for a fresh profile',
      () async {
        // AUD-t-story-acceptance-06: `expect(TextDownloadService, isNotNull)`
        // on a Type literal is a compile-time tautology. Construct a real
        // service backed by an in-memory database and exercise an actual
        // method/return value.
        final db = createTestDatabase();
        await seedProfile(db);
        addTearDown(() => db.close());
        final service = TextDownloadService(
          textDownloadStatusDao: db.textDownloadStatusDao,
        );

        final downloaded = await service.isDownloaded(CurriculumId.mishnayos);

        expect(downloaded, isFalse);
      },
    );

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
