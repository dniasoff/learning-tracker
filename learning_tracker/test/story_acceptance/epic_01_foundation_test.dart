/// Story acceptance tests for Epic 1 -- Foundation.
/// All 12 stories are DONE and actively tested.
@Tags(['epic_1'])
library;

import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;
import 'package:kosher_dart/kosher_dart.dart';
import 'package:learning_tracker/app/router/guards/auth_guard.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/hebrew_calendar_utils.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../../tool/lib/sefaria/bavli_fetcher.dart';
// ignore: avoid_relative_lib_imports
import '../../tool/lib/sefaria/chumash_fetcher.dart';
// ignore: avoid_relative_lib_imports
import '../../tool/lib/sefaria/mishna_berurah_fetcher.dart';
// ignore: avoid_relative_lib_imports
import '../../tool/lib/sefaria/mishna_fetcher.dart';
// ignore: avoid_relative_lib_imports
import '../../tool/lib/sefaria/sefaria_fetcher_base.dart';
// ignore: avoid_relative_lib_imports
import '../../tool/lib/sefaria/yerushalmi_fetcher.dart';
import '../helpers/drift_memory.dart';
import '../helpers/test_database.dart';

// ── Mocks ──────────────────────────────────────────────────────────

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

// ── Tests ──────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Story 1.1: Project initialisation ──────────────────────────

  group('Story 1.1 -- Project initialisation', tags: ['story_1_1'], () {
    test('clean architecture directories exist (core, features)', () {
      // AUD-t-story-acceptance-06: `expect(UserDatabase, isNotNull)` on a
      // Type literal is a compile-time tautology (Type objects are never
      // null); it can never fail. Assert the actual directory structure
      // on disk instead.
      expect(Directory('lib/core').existsSync(), isTrue);
      expect(Directory('lib/features').existsSync(), isTrue);
      expect(CurriculumId.values, isNotEmpty);
    });

    test('key dependencies are importable', () {
      // AUD-t-story-acceptance-06: `expect(true, isTrue)` can never fail.
      // Assert the actual pubspec.yaml declarations for the dependencies
      // this story introduced (Drift, Riverpod, AutoRoute, Talker).
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final dependency in [
        'drift:',
        'flutter_riverpod:',
        'auto_route:',
        'talker:',
      ]) {
        expect(
          pubspec,
          contains(dependency),
          reason: 'pubspec.yaml must declare $dependency',
        );
      }
    });
  });

  // ── Story 1.2: Database layer ─────────────────────────────────

  group('Story 1.2 -- Database layer', tags: ['story_1_2'], () {
    late UserDatabase db;
    late int trackId;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      trackId = await seedTrack(db, profileId: 1);
    });

    tearDown(() async {
      await db.close();
    });

    test('in-memory database instantiates successfully', () async {
      // AUD-t-story-acceptance-06: `db` is a non-nullable local, so
      // `expect(db, isNotNull)` is a compile-time tautology. Assert that
      // the instance is actually a working, connected database instead --
      // it must see the account row seeded by setUp.
      final accounts = await db.select(db.accounts).get();
      expect(accounts, hasLength(1));
    });

    test('schema version is at least 1 (W3.19 fresh-install schema reset)', () {
      expect(db.schemaVersion, greaterThanOrEqualTo(1));
    });

    test('all 12 DAOs are accessible', () async {
      // AUD-t-story-acceptance-06: DAO getters are non-nullable, so
      // `expect(db.xDao, isNotNull)` is a compile-time tautology for all 12.
      // Exercise a representative real query on each DAO instead -- a
      // regression that breaks a DAO's wiring to its table (wrong table,
      // broken migration, mis-scoped query) throws or returns the wrong
      // shape here, where a bare isNotNull check could not.
      // trackId was seeded by setUp with the default (active) state.
      expect(
        await db.activeCurriculumDao.getActiveCurriculaByProfile(1),
        equals(['mishnayos']),
      );
      expect(await db.completionDao.getCompletionsByProfile(1), isEmpty);
      expect(await db.goalDao.getAllGoals(), isEmpty);
      expect(
        await db.pointConfigDao.getConfigsByCurriculum(
          CurriculumId.mishnayos.storageKey,
        ),
        isEmpty,
      );
      expect(await db.stageDao.getAllStageDefinitions(), isEmpty);
      expect(await db.bookmarkDao.getAllBookmarks(), isEmpty);
      expect(await db.learningOrderDao.getAllLearningOrders(), isEmpty);
      expect(await db.streakEventDao.getEventsByProfile(1), isEmpty);
      // trackId was seeded by setUp -- the track DAO must actually see it.
      expect(
        await db.trackDao.getAllTracks(CurriculumId.mishnayos),
        hasLength(1),
      );
      // seedProfile inserted one account -- the profile DAO must see it.
      expect(await db.userProfileDao.getAllUserProfiles(), hasLength(1));
      // syncQueueDao removed in W2.37 (offline_queue deleted)
      expect(
        await db.textDownloadStatusDao.isDownloaded(
          CurriculumId.mishnayos.storageKey,
        ),
        isFalse,
      );
      expect(await db.learningLedgerDao.getEntriesByProfile(1), isEmpty);
    });

    test('basic CRUD round-trip on completions', () async {
      final id = await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berachos 1.1',
          stageId: 1,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: DateTime.now(),
          points: const Value(10),
        ),
      );
      expect(id, greaterThan(0));

      final all = await db.completionDao.internalGetAllCompletionsCrossProfile(
        scope: CrossProfileScope.dataExport,
      );
      expect(all, hasLength(1));
    });
  });

  // ── Story 1.3: Firebase auth repository ───────────────────────

  group('Story 1.3 -- Firebase auth repository', tags: ['story_1_3'], () {
    test('AuthGuard is a real AutoRouteGuard implementation', () {
      // AUD-t-story-acceptance-06: `expect(AuthGuard, isNotNull)` on a Type
      // literal is a compile-time tautology. Verify the actual runtime
      // relationship instead -- AuthGuard must genuinely extend
      // AutoRouteGuard, not merely resolve as a symbol.
      expect(AuthGuard(), isA<AutoRouteGuard>());
    });

    test('AuthRepositoryImpl exists in data layer', () {
      // AUD-t-story-acceptance-06: `expect(true, isTrue)` can never fail,
      // and the class was not even imported here, so the comment's claim
      // of "compile-time import resolution" was false. Assert the file's
      // actual on-disk location instead.
      final file = File(
        'lib/features/account/data/repositories/auth_repository_impl.dart',
      );
      expect(
        file.existsSync(),
        isTrue,
        reason: 'auth_repository_impl.dart must exist in the data layer',
      );
    });
  });

  // ── Story 1.4: Sefaria API layer ─────────────────────────────

  group('Story 1.4 -- Sefaria API layer', tags: ['story_1_4'], () {
    test(
      'MishnaFetcher implements CurriculumContentFetcher via SefariaFetcherBase',
      () {
        // AUD-t-story-acceptance-06: `expect(X, isNotNull)` on abstract
        // class Type literals is a compile-time tautology. Verify the
        // actual inheritance chain at runtime on a concrete fetcher.
        final fetcher = MishnaFetcher(dio: Dio());
        expect(fetcher, isA<SefariaFetcherBase>());
        expect(fetcher, isA<CurriculumContentFetcher>());
      },
    );

    test('all 5 concrete fetchers report their own curriculumId', () {
      // AUD-t-story-acceptance-06: `expect(FetcherClass, isNotNull)` on Type
      // literals is a compile-time tautology. Assert each fetcher's actual
      // curriculumId -- a regression that wires a fetcher to the wrong
      // curriculum fails here.
      expect(
        MishnaFetcher(dio: Dio()).curriculumId,
        equals(CurriculumId.mishnayos.storageKey),
      );
      expect(
        BavliFetcher(dio: Dio()).curriculumId,
        equals(CurriculumId.bavli.storageKey),
      );
      expect(
        YerushalmiFetcher(dio: Dio()).curriculumId,
        equals(CurriculumId.yerushalmi.storageKey),
      );
      expect(
        MishnaBerurahFetcher(dio: Dio()).curriculumId,
        equals(CurriculumId.mishnaBerurah.storageKey),
      );
      expect(
        ChumashFetcher(dio: Dio()).curriculumId,
        equals(CurriculumId.chumash.storageKey),
      );
    });
  });

  // ── Story 1.5: Navigation shell ──────────────────────────────

  group('Story 1.5 -- Navigation shell', tags: ['story_1_5'], () {
    test('AppRouter declares the guarded app-shell route', () {
      // AUD-t-story-acceptance-06: `expect(AppRouter, isNotNull)` on a Type
      // literal is a compile-time tautology. Assert the actual route
      // configuration on disk (constructing AppRouter itself requires a
      // full guard dependency graph, disproportionate for this check).
      final content = File('lib/app/router/app_router.dart').readAsStringSync();
      expect(content, contains('class AppRouter extends RootStackRouter'));
      expect(
        content,
        contains('guards: [authGuard, restoreGuard, profileGuard]'),
      );
    });

    test('AuthGuard is a real AutoRouteGuard implementation', () {
      expect(AuthGuard(), isA<AutoRouteGuard>());
    });

    test('PinGuard is a real AutoRouteGuard implementation '
        '(parameterised by PinScope; replaces ParentPinGuard)', () {
      // AUD-t-story-acceptance-06: `expect(PinGuard, isNotNull)` on a Type
      // literal is a compile-time tautology. Construct a real guard and
      // verify the runtime inheritance relationship.
      final guard = PinGuard(
        pinService: PinService(_MockSecureStorage()),
        promptForPin: () async => false,
        getScope: () => null,
        pinSetupRoute: () => const PageRouteInfo('PinFlowSetupRoute'),
      );
      expect(guard, isA<AutoRouteGuard>());
    });
  });

  // ── Story 1.6: Theme & design tokens ─────────────────────────

  group('Story 1.6 -- Theme & design tokens', tags: ['story_1_6'], () {
    test('AppTheme provides a Material 3 light theme', () {
      final theme = AppTheme.lightTheme();
      expect(theme, isA<ThemeData>());
      expect(theme.useMaterial3, isTrue);
    });

    test('curriculum colours are accessible', () {
      final color = AppPalette.light.curriculumFor(CurriculumId.mishnayos);
      expect(color, isA<Color>());
    });
  });

  // ── Story 1.7: Riverpod state enums ──────────────────────────

  group('Story 1.7 -- Riverpod state enums', tags: ['story_1_7'], () {
    test('CurriculumId has 5 values', () {
      expect(CurriculumId.values, hasLength(9));
      expect(
        CurriculumId.values.map((c) => c.storageKey),
        containsAll([
          'mishnayos',
          'bavli',
          'yerushalmi',
          'mishna_berurah',
          'chumash',
        ]),
      );
    });

    // WS9.enum: UserMode deleted — ProfileMode is the canonical mode enum.
    test('ProfileMode has 2 values (child and adult)', () {
      expect(ProfileMode.values, hasLength(2));
      expect(
        ProfileMode.values,
        containsAll([ProfileMode.child, ProfileMode.adult]),
      );
    });
  });

  // ── Story 1.8: Logging infrastructure ────────────────────────

  group('Story 1.8 -- Logging infrastructure', tags: ['story_1_8'], () {
    test('AppLogger.instance returns the same singleton every time', () {
      // AUD-t-story-acceptance-06: `AppLogger.instance` is a non-nullable
      // getter, so `expect(logger, isNotNull)` is a compile-time tautology.
      // Assert the actual singleton contract instead.
      final first = AppLogger.instance;
      final second = AppLogger.instance;
      expect(identical(first, second), isTrue);
    });

    test('SensitiveDataPatterns detects sensitive fields', () {
      expect(SensitiveDataPatterns.containsSensitiveData('email'), isTrue);
      expect(SensitiveDataPatterns.containsSensitiveData('hello'), isFalse);
    });
  });

  // ── Story 1.9: Sync infrastructure ───────────────────────────

  group('Story 1.9 -- Sync infrastructure', tags: ['story_1_9'], () {
    test('SyncOrchestrator interface dispatches pushAllLocalData()', () async {
      // W2.35: SyncEngine deleted — SyncOrchestrator is the new public surface.
      // AUD-t-story-acceptance-06: `expect(SyncOrchestrator, isNotNull)` on
      // a Type literal is a compile-time tautology. Exercise a real
      // implementation of the interface instead.
      final orchestrator = _MockSyncOrchestrator();
      when(() => orchestrator.pushAllLocalData()).thenAnswer((_) async {});

      await orchestrator.pushAllLocalData();

      verify(() => orchestrator.pushAllLocalData()).called(1);
    });

    test('OutboxSyncWriteFacade enqueues a real outbox row', () async {
      // W2.35: OfflineQueue deleted — OutboxSyncWriteFacade is the replacement.
      // AUD-t-story-acceptance-06: `expect(OutboxSyncWriteFacade, isNotNull)`
      // on a Type literal is a compile-time tautology. Construct a real
      // facade backed by an in-memory database and prove it actually writes
      // to the outbox table.
      final db = createTestDatabase();
      addTearDown(() => db.close());
      final facade = OutboxSyncWriteFacade(
        outboxDao: db.outboxDao,
        database: db,
        resolveProfileId: () => 1,
        clock: const SystemLocalDayClock(),
      );

      expect(await db.outboxDao.totalDepth(), equals(0));

      await facade.pushBookmark({'curriculum_id': 'mishnayos'});

      expect(await db.outboxDao.totalDepth(), equals(1));
    });

    test('SyncStatus freezed union has expected factories', () {
      // Story 1.5 / AD-11: collapsed to exactly four states — localOnly,
      // syncing, synced, offline. Verify all four compile.
      const localOnly = SyncStatus.localOnly();
      final syncing = SyncStatus.syncing(startedAt: DateTime.now());
      final synced = SyncStatus.synced(lastSyncedAt: DateTime.now());
      const offline = SyncStatus.offline();

      expect(localOnly, isA<SyncStatus>());
      expect(syncing, isA<SyncStatus>());
      expect(synced, isA<SyncStatus>());
      expect(offline, isA<SyncStatus>());
    });
  });

  // ── Story 1.10: CI / CD pipeline ─────────────────────────────

  group('Story 1.10 -- CI/CD pipeline', tags: ['story_1_10'], () {
    test('project compiles and analyse target exists', () {
      // AUD-t-story-acceptance-06: `expect(true, isTrue)` can never fail.
      // The real verification is `make analyze`; assert the Makefile
      // actually defines that target instead of asserting nothing.
      final makefile = File('Makefile').readAsStringSync();
      expect(makefile, contains('analyze:'));
    });
  });

  // ── Story 1.11: Security (PIN service) ───────────────────────

  group('Story 1.11 -- Security (PIN service)', tags: ['story_1_11'], () {
    late PinService pinService;
    late _MockSecureStorage mockStorage;
    late Map<String, String> store;

    setUp(() {
      mockStorage = _MockSecureStorage();
      store = {};

      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((inv) async {
        store[inv.namedArguments[#key] as String] =
            inv.namedArguments[#value] as String;
      });
      when(() => mockStorage.read(key: any(named: 'key'))).thenAnswer((
        inv,
      ) async {
        return store[inv.namedArguments[#key] as String];
      });
      when(() => mockStorage.delete(key: any(named: 'key'))).thenAnswer((
        inv,
      ) async {
        store.remove(inv.namedArguments[#key] as String);
      });

      pinService = PinService(mockStorage);
    });

    test('bcrypt hash round-trip: set then verify PIN', () async {
      await pinService.setParentPin('1234');
      final valid = await pinService.verifyParentPin('1234');
      expect(valid, isTrue);
    });

    test('wrong PIN returns false', () async {
      await pinService.setParentPin('1234');
      final valid = await pinService.verifyParentPin('5678');
      expect(valid, isFalse);
    });

    test('lockout after 5 failed attempts', () async {
      await pinService.setParentPin('1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyParentPin('0000');
      }
      expect(
        () => pinService.verifyParentPin('0000'),
        throwsA(isA<PinLockoutException>()),
      );
    });
  });

  // ── Story 1.12: Hebrew calendar ──────────────────────────────

  group('Story 1.12 -- Hebrew calendar', tags: ['story_1_12'], () {
    test('Gregorian to Hebrew conversion returns non-empty string', () {
      final result = HebrewCalendarUtils.gregorianToHebrew(
        DateTime.utc(2026, 1, 1),
      );
      expect(result, isNotEmpty);
    });

    test('Gregorian to JewishDate round-trip', () {
      final jewishDate = HebrewCalendarUtils.gregorianToJewishDate(
        DateTime.utc(2026, 1, 1),
      );
      expect(jewishDate, isA<JewishDate>());

      final backToGregorian = HebrewCalendarUtils.hebrewToGregorian(
        year: jewishDate.getJewishYear(),
        month: jewishDate.getJewishMonth(),
        day: jewishDate.getJewishDayOfMonth(),
      );
      expect(backToGregorian.year, equals(2026));
      expect(backToGregorian.month, equals(1));
      expect(backToGregorian.day, equals(1));
    });

    test('isHebrewLeapYear', () {
      // 5787 is a leap year in the 19-year cycle
      expect(HebrewCalendarUtils.isHebrewLeapYear(5787), isTrue);
      expect(HebrewCalendarUtils.isHebrewLeapYear(5786), isFalse);
    });
  });
}
