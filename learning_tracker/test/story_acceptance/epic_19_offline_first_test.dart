import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/content_result.dart';
import 'package:learning_tracker/core/database/seed_version.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/services/calendar_program_registry.dart';
import 'package:learning_tracker/core/services/local_calendar_engine.dart';
import 'package:learning_tracker/features/auth/domain/models/app_auth_state.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';

import '../helpers/test_database.dart';

void main() {
  // ─── Story 19.1: Calendar Registry Bugs ──────────────────────────
  group('Story 19.1 — Calendar Registry Bugs Fixed', () {
    test('all 12 programs are registered', () {
      expect(CalendarProgramRegistry.programs.length, 12);
    });

    test('Sefaria programs have correct apiKeys', () {
      expect(
        CalendarProgramRegistry.byApiKey('Daily Mishnah')?.id,
        'mishna_yomit',
      );
      expect(
        CalendarProgramRegistry.byApiKey('Daily Rambam')?.id,
        'rambam_1_chapter',
      );
      expect(
        CalendarProgramRegistry.byApiKey('Daily Rambam (3 Chapters)')?.id,
        'rambam_3_chapters',
      );
    });

    test('Nach Yomi is on Hebcal, not Sefaria', () {
      final def = CalendarProgramRegistry.byId('nach_yomi');
      expect(def?.apiSource, 'hebcal');
      expect(def?.hebcalCategory, 'nachyomi');
    });

    test('all 3 Hebcal programs have hebcalCategory', () {
      expect(
        CalendarProgramRegistry.byHebcalCategory('nachyomi')?.id,
        'nach_yomi',
      );
      expect(
        CalendarProgramRegistry.byHebcalCategory('chofetzChaim')?.id,
        'chofetz_chaim_daily',
      );
      expect(
        CalendarProgramRegistry.byHebcalCategory('kitzurShulchanAruch')?.id,
        'kitzur_shulchan_aruch_yomi',
      );
    });
  });

  // ─── Story 19.2: Two-Database Split ──────────────────────────────
  group('Story 19.2 — Two-Database Split', () {
    late UserDatabase userDb;
    late ContentDatabase contentDb;

    setUp(() {
      userDb = createTestUserDatabase();
      contentDb = createTestContentDatabase();
    });

    tearDown(() async {
      await userDb.close();
      await contentDb.close();
    });

    test('UserDatabase creates with user tables', () async {
      await userDb.into(userDb.userProfiles).insert(
            UserProfilesCompanion.insert(
              localUid: 'test-uid-123',
              displayName: 'Test User',
              userMode: 'adult',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      final profiles = await userDb.select(userDb.userProfiles).get();
      expect(profiles, hasLength(1));
      expect(profiles.first.localUid, 'test-uid-123');
    });

    test('ContentDatabase creates with content tables', () async {
      final programs =
          await contentDb.contentLearningProgramDao.getAllPrograms();
      expect(programs, isList);
    });

    test('UserProfiles has localUid and nullable firebaseUid', () async {
      await userDb.into(userDb.userProfiles).insert(
            UserProfilesCompanion.insert(
              localUid: 'local-only-user',
              displayName: 'Local User',
              userMode: 'adult',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      final profile =
          await userDb.select(userDb.userProfiles).getSingle();
      expect(profile.localUid, 'local-only-user');
      expect(profile.firebaseUid, isNull);
      expect(profile.hasAccount, isFalse);
    });
  });

  // ─── Story 19.2b: SeedManager ────────────────────────────────────
  group('Story 19.2b — Seed Version Constant', () {
    test('bundledSeedVersion is a positive integer', () {
      expect(bundledSeedVersion, greaterThan(0));
    });
  });

  // ─── Story 19.4: Local Calendar Engine ───────────────────────────
  group('Story 19.4 — Local Calendar Engine', () {
    late ContentDatabase contentDb;

    setUp(() {
      contentDb = createTestContentDatabase();
    });

    tearDown(() async {
      await contentDb.close();
    });

    test('returns empty list for empty DB', () async {
      final engine = LocalCalendarEngine(contentDb);
      final results = await engine.getTodayPrograms();
      expect(results, isEmpty);
    });

    test('returns entry when data exists', () async {
      final now = DateTime.now();
      final dateKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await contentDb.customInsert(
        'INSERT INTO calendar_cycles (program_key, date_key, sefaria_ref, display_name) '
        'VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString('daf_yomi'),
          Variable.withString(dateKey),
          Variable.withString('Berakhot 2a'),
          Variable.withString('Daf Yomi'),
        ],
      );

      final engine = LocalCalendarEngine(contentDb);
      final results = await engine.getTodayPrograms();
      expect(results, isNotEmpty);
      expect(results.first.todayRef, 'Berakhot 2a');
    });
  });

  // ─── Story 19.5: Local-First Auth ────────────────────────────────
  group('Story 19.5 — Local-First Auth Abstraction', () {
    test('LocalAuthState has no cloud account', () {
      const state = LocalAuthState(
        localUid: 'test-uid',
        displayName: 'Test',
      );
      expect(state.hasCloudAccount, isFalse);
      expect(state.firebaseUid, isNull);
      expect(state.displayUid, 'test-uid');
    });

    test('CloudAuthState has cloud account', () {
      const state = CloudAuthState(
        localUid: 'test-uid',
        firebaseUid: 'firebase-uid',
        displayName: 'Test',
        email: 'test@example.com',
      );
      expect(state.hasCloudAccount, isTrue);
      expect(state.firebaseUid, 'firebase-uid');
      expect(state.displayUid, 'test-uid');
    });
  });

  // ─── Story 19.8: SyncEngine Conditional ──────────────────────────
  group('Story 19.8 — SyncEngine Conditional Activation', () {
    test('SyncStatus.localOnly represents no-account state', () {
      const status = SyncStatus.localOnly();
      expect(status, isA<SyncStatusLocalOnly>());
    });
  });

  // ─── Story 19.12: Content DB Resilience ──────────────────────────
  group('Story 19.12 — Content DB Resilience', () {
    test('ContentResult.loaded carries data', () {
      const result = ContentLoaded<String>('hello');
      expect(result.data, 'hello');
    });

    test('ContentResult.notFound carries ref string', () {
      const result = ContentNotFound<String>('Berakhot 2a');
      expect(result.ref, 'Berakhot 2a');
    });

    test('ContentResult can be pattern matched', () {
      const ContentResult<String> result = ContentLoaded<String>('data');
      final value = switch (result) {
        ContentLoaded<String>(:final data) => data,
        ContentNotFound<String>(:final ref) => 'missing: $ref',
      };
      expect(value, 'data');
    });
  });
}
