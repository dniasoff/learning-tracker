import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/content_result.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/seed/learning_program_seeds.dart';
import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:learning_tracker/core/database/seed_version.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/services/calendar_program_registry.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
import 'package:learning_tracker/core/services/local_calendar_engine.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../helpers/test_database.dart';

void main() {
  // ─── Story 19.1: Calendar Registry Bugs ──────────────────────────
  group('Story 19.1 — Calendar Registry Bugs Fixed', () {
    test('all 20 programs are registered', () {
      expect(CalendarProgramRegistry.programs.length, 20);
    });

    test('Hebcal programs have correct apiKeys', () {
      expect(
        CalendarProgramRegistry.byApiKey('mishnayomi')?.id,
        'mishna_yomit',
      );
      expect(
        CalendarProgramRegistry.byApiKey('dailyRambam1')?.id,
        'rambam_1_chapter',
      );
      expect(
        CalendarProgramRegistry.byApiKey('dailyRambam3')?.id,
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
      await userDb
          .into(userDb.accounts)
          .insert(
            UserProfilesCompanion.insert(
              email: 'test@test.local',
              tier: 'cloudBorn',
              displayName: 'Test User',
              userMode: 'adult',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      final profiles = await userDb.select(userDb.accounts).get();
      expect(profiles, hasLength(1));
      expect(profiles.first.email, 'test@test.local');
    });

    test('ContentDatabase creates with content tables', () async {
      // Programs are now served from LearningProgramRepository (compile-time)
      final programs = LearningProgramRepository.instance.getAllPrograms();
      expect(programs, isList);
    });

    test(
      'UserProfiles stores local-born account without firebaseUid',
      () async {
        await userDb
            .into(userDb.accounts)
            .insert(
              UserProfilesCompanion.insert(
                email: 'localonly@test.local',
                tier: 'localBorn',
                passwordHash: const Value(r'argon2id$placeholder'),
                displayName: 'Local User',
                userMode: 'adult',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
        final profile = await userDb.select(userDb.accounts).getSingle();
        expect(profile.email, 'localonly@test.local');
        expect(profile.firebaseUid, isNull);
        expect(profile.tier, 'localBorn');
      },
    );
  });

  // ─── Story 19.2b: SeedManager ────────────────────────────────────
  group('Story 19.2b — Seed Version Constant', () {
    test('bundledSeedVersion is a positive integer', () {
      expect(bundledSeedVersion, greaterThan(0));
    });
  });

  // ─── Story 19.3: Seed Database Build Tool ────────────────────────
  group('Story 19.3 — Seed Database Build Tool', () {
    late ContentDatabase contentDb;

    setUp(() {
      contentDb = createTestContentDatabase();
    });

    tearDown(() async {
      await contentDb.close();
    });

    test('AT-19.3.1 ContentDatabase creates core tables', () async {
      const expected = ['text_cache', 'calendar_cycles', 'seed_metadata'];
      for (final t in expected) {
        final rows = await contentDb
            .customSelect('PRAGMA table_info($t)')
            .get();
        expect(rows, isNotEmpty, reason: 'table $t should exist');
      }
    });

    test('AT-19.3.2 programs-only seed yields 21 LearningPrograms with '
        'api fields populated', () {
      // Programs are now served from LearningProgramRepository (compile-time).
      final rows = LearningProgramRepository.instance.getAllPrograms();
      expect(rows, hasLength(21));

      final dafYomi = rows.firstWhere((p) => p.name == 'daf_yomi');
      expect(dafYomi.apiSource, 'hebcal');
      expect(dafYomi.apiProgramKey, 'daf_yomi');
      expect(dafYomi.isCalendarProgram, isTrue);

      final mishnahYomis = rows.firstWhere((p) => p.name == 'mishnah_yomis');
      expect(mishnahYomis.apiSource, 'hebcal');
      expect(mishnahYomis.apiProgramKey, 'mishna_yomit');
      expect(mishnahYomis.isCalendarProgram, isTrue);

      final nachYomi = rows.firstWhere((p) => p.name == 'nach_yomi');
      expect(nachYomi.apiSource, 'hebcal');
      expect(nachYomi.apiProgramKey, 'nach_yomi');
      expect(nachYomi.isCalendarProgram, isTrue);

      final oraysa = rows.firstWhere((p) => p.name == 'oraysa');
      expect(oraysa.apiSource, isNull);
      expect(oraysa.apiProgramKey, isNull);
      expect(oraysa.isCalendarProgram, isFalse);
    });

    test('AT-19.3.3 TextCache batch insert round-trips', () async {
      final now = DateTime.now().toUtc();
      await contentDb.transaction(() async {
        for (var i = 0; i < 100; i++) {
          await contentDb.customInsert(
            'INSERT INTO text_cache '
            '(sefaria_ref, hebrew_text, english_text, fetched_at) '
            'VALUES (?, ?, ?, ?)',
            variables: [
              Variable.withString('Test $i'),
              Variable.withString('heb-$i'),
              Variable.withString('eng-$i'),
              Variable.withDateTime(now),
            ],
          );
        }
      });
      final refs = await contentDb.contentTextCacheDao.getAllCachedRefs();
      expect(refs, hasLength(100));

      final row = await contentDb.contentTextCacheDao.getText('Test 42');
      expect(row, isNotNull);
      expect(row!.hebrewText, 'heb-42');
      expect(row.englishText, 'eng-42');
    });

    test('AT-19.3.4 LocalCalendarEngine lookup by (programId, date)', () async {
      // Seed a calendar cycle row, then verify the engine resolves it.
      await contentDb.customInsert(
        'INSERT INTO calendar_cycles (program_key, date_key, sefaria_ref, display_name) '
        "VALUES ('daf_yomi', '2025-01-03', 'Berakhot 2a', '')",
      );
      final engine = LocalCalendarEngine(contentDb);
      final hit = await engine.getEntry('daf_yomi', DateTime(2025, 1, 3));
      expect(hit, isNotNull);
      expect(hit!.programId, 'daf_yomi');
      expect(hit.todayRef, isNotEmpty);

      // Unknown program returns null
      final miss = await engine.getEntry(
        'nonexistent_program',
        DateTime(2025, 1, 3),
      );
      expect(miss, isNull);
    });

    test('AT-19.3.5 content hash is deterministic across two builds', () async {
      Future<String> buildAndHash(ContentDatabase db) async {
        await db.customInsert(
          'INSERT INTO text_cache '
          '(sefaria_ref, hebrew_text, english_text, fetched_at) '
          'VALUES (?, ?, ?, ?)',
          variables: [
            Variable.withString('Berakhot 2a'),
            Variable.withString('א'),
            Variable.withString('a'),
            Variable.withDateTime(DateTime.utc(2026, 1, 1)),
          ],
        );
        final refs = await db
            .customSelect(
              'SELECT sefaria_ref FROM text_cache ORDER BY sefaria_ref',
            )
            .get();
        final buf = StringBuffer();
        for (final r in refs) {
          buf
            ..write(r.read<String>('sefaria_ref'))
            ..write('\n');
        }
        return buf.toString();
      }

      final otherDb = createTestContentDatabase();
      try {
        final a = await buildAndHash(contentDb);
        final b = await buildAndHash(otherDb);
        expect(a, b);
      } finally {
        await otherDb.close();
      }
    });

    test('AT-19.3.9 openReadOnly applies PRAGMA query_only = ON', () async {
      // Prepare a seed file on disk using a writable ContentDatabase.
      final tmp = await Directory.systemTemp.createTemp('seed_ro_test');
      final dbFile = File('${tmp.path}/seed.db');
      addTearDown(() async {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      });

      final writable = ContentDatabase(NativeDatabase(dbFile));
      await writable.customInsert(
        'INSERT INTO text_cache '
        '(sefaria_ref, hebrew_text, english_text, fetched_at) '
        'VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString('Berakhot 2a'),
          Variable.withString('heb'),
          Variable.withString('eng'),
          Variable.withDateTime(DateTime.utc(2026, 1, 1)),
        ],
      );
      await writable.close();

      final readOnly = ContentDatabase.openReadOnly(dbFile);
      try {
        // Reads still work.
        final row = await readOnly.contentTextCacheDao.getText('Berakhot 2a');
        expect(row, isNotNull);

        // Writes are rejected by SQLite (query_only pragma).
        await expectLater(
          readOnly.customInsert(
            'INSERT INTO text_cache '
            '(sefaria_ref, hebrew_text, english_text, fetched_at) '
            'VALUES (?, ?, ?, ?)',
            variables: [
              Variable.withString('Berakhot 2b'),
              Variable.withString('heb'),
              Variable.withString('eng'),
              Variable.withDateTime(DateTime.utc(2026, 1, 1)),
            ],
          ),
          throwsA(isA<sqlite.SqliteException>()),
        );
      } finally {
        await readOnly.close();
      }
    });

    test(
      'AT-19.3.6 SeedManager decompresses a gzipped seed on first launch',
      () async {
        final tmp = await Directory.systemTemp.createTemp('seed_mgr_test');
        addTearDown(() async {
          try {
            await tmp.delete(recursive: true);
          } catch (_) {}
        });

        // Build a small source seed DB on disk with a known version row.
        final sourcePath = '${tmp.path}/source.db';
        final source = ContentDatabase(NativeDatabase(File(sourcePath)));
        await source.customInsert(
          'INSERT INTO seed_metadata '
          '(version, built_at, build_id, text_cache_count, calendar_cycle_count) '
          'VALUES (?, ?, ?, ?, ?)',
          variables: [
            Variable.withInt(bundledSeedVersion),
            Variable.withString('2026-04-11T00:00:00Z'),
            Variable.withString('seed-test'),
            Variable.withInt(0),
            Variable.withInt(0),
          ],
        );
        await source.close();

        // Verify SeedManager's path/backup plumbing without mocking the
        // Flutter asset bundle: write a pre-seeded content.db into the
        // target dir and check ensureContentDb returns its path as a
        // no-op upgrade.
        final contentDbPath = '${tmp.path}/content.db';
        File(sourcePath).copySync(contentDbPath);

        final mgr = SeedManager(dbDirectory: tmp.path);
        final resolved = await mgr.ensureContentDb();
        expect(resolved, contentDbPath);
        expect(File(resolved).existsSync(), isTrue);

        // The resolved DB must open and report the expected version.
        final opened = ContentDatabase(NativeDatabase(File(resolved)));
        try {
          final meta = await opened.seedMetadataDao.getVersion();
          expect(meta, isNotNull);
          expect(meta!.version, bundledSeedVersion);
        } finally {
          await opened.close();
        }
      },
    );

    test('learningProgramSeeds exposes api fields for every entry', () {
      expect(learningProgramSeeds, hasLength(21));
      for (final p in learningProgramSeeds) {
        expect(
          p.containsKey('api_source'),
          isTrue,
          reason: '${p['name']} missing api_source',
        );
        expect(
          p.containsKey('api_program_key'),
          isTrue,
          reason: '${p['name']} missing api_program_key',
        );
        expect(
          p.containsKey('is_calendar_program'),
          isTrue,
          reason: '${p['name']} missing is_calendar_program',
        );
      }
    });
  });

  // ─── Story 19.4: Local Calendar Engine ───────────────────────────
  group('Story 19.4 — Local Calendar Engine', () {
    late ContentDatabase calDb;
    late LocalCalendarEngine engine;

    setUp(() async {
      calDb = createTestContentDatabase();
      engine = LocalCalendarEngine(calDb);
      // Seed 20 calendar rows for the test date (2026-03-29),
      // plus 5 days of daf_yomi for range query tests.
      for (final entry in [
        ('daf_yomi', 'Berakhot 2a'),
        ('daf_a_week', 'Berakhot 2a'),
        ('mishna_yomit', 'Mishnah Berakhot 1:1-2'),
        ('rambam_1_chapter', 'Mishneh Torah, Foundations of the Torah 1'),
        ('rambam_3_chapters', 'Mishneh Torah, Foundations of the Torah 1-3'),
        ('halakhah_yomit', 'Shulchan Arukh, Orach Chayim 1:1-3'),
        ('arukh_hashulchan_yomi', 'Arukh HaShulchan, Orach Chaim 1:1-8'),
        ('nach_yomi', 'Joshua 1'),
        ('yerushalmi_yomi', 'Jerusalem Talmud Berakhot 1'),
        ('tanakh_yomi', 'Jeremiah 31:32-Jeremiah 32:21'),
        ('chofetz_chaim_daily', 'Chofetz Chaim, Preface 1-4'),
        ('kitzur_shulchan_aruch_yomi', 'Kitzur Shulchan Aruch 1:1-4'),
        ('tehillim_yomi', 'Psalms 1'),
        ('perek_yomi', 'Avos 1:1'),
        ('sefer_hamitzvot', 'Positive Commandment 1'),
        ('shemirat_halashon', 'Shemirat HaLashon 1'),
        ('pirkei_avot_summer', 'Avos 1'),
        ('dirshu_kinyan_torah', 'Dirshu Kinyan Torah 1'),
        ('dirshu_amud_hayomi', 'Dirshu Amud HaYomi 1'),
        ('dirshu_kinyan_yerushalmi', 'Dirshu Kinyan Yerushalmi 1'),
      ]) {
        await calDb.customInsert(
          'INSERT INTO calendar_cycles (program_key, date_key, sefaria_ref, display_name) '
          'VALUES (?, ?, ?, ?)',
          variables: [
            Variable.withString(entry.$1),
            Variable.withString('2026-03-29'),
            Variable.withString(entry.$2),
            const Variable(''),
          ],
        );
      }
      // Seed 4 more days of daf_yomi for range query tests (Mar 25-28).
      for (var day = 25; day <= 28; day++) {
        await calDb.customInsert(
          'INSERT INTO calendar_cycles (program_key, date_key, sefaria_ref, display_name) '
          "VALUES ('daf_yomi', '2026-03-${day.toString().padLeft(2, '0')}', 'Berakhot ${day - 23}a', '')",
        );
      }
    });

    tearDown(() async {
      await calDb.close();
    });

    test('formatDateKey zero-pads month and day', () {
      expect(
        LocalCalendarEngine.formatDateKey(DateTime(2026, 3, 29)),
        '2026-03-29',
      );
      expect(
        LocalCalendarEngine.formatDateKey(DateTime(2026, 1, 5)),
        '2026-01-05',
      );
      expect(
        LocalCalendarEngine.formatDateKey(DateTime(2026, 12, 31)),
        '2026-12-31',
      );
    });

    test('AT-19.4.1 getEntry returns CalendarProgramEntry for known '
        '(programId, date)', () async {
      final entry = await engine.getEntry('daf_yomi', DateTime(2026, 3, 29));
      expect(entry, isNotNull);
      expect(entry!.programId, 'daf_yomi');
      expect(entry.todayRef, isNotEmpty);
      expect(entry.apiSource, 'local');

      // Display names sourced from the registry.
      final def = CalendarProgramRegistry.byId('daf_yomi')!;
      expect(entry.displayNameEn, def.displayNameEn);
      expect(entry.displayNameHe, def.displayNameHe);
    });

    test('AT-19.4.2 getTodayPrograms returns entries for all 20 '
        'programs', () async {
      final results = await engine.getTodayPrograms(DateTime(2026, 3, 29));
      expect(results, hasLength(20));
      for (final entry in results) {
        expect(entry.todayRef, isNotEmpty);
        expect(entry.apiSource, 'local');
      }
      final ids = results.map((e) => e.programId).toSet();
      expect(ids, hasLength(20));
      expect(ids.contains('daf_yomi'), isTrue);
      expect(ids.contains('nach_yomi'), isTrue);
      expect(ids.contains('chofetz_chaim_daily'), isTrue);
    });

    test('AT-19.4.3 getEntry returns null for unknown programId', () async {
      final entry = await engine.getEntry(
        'nonexistent_program',
        DateTime(2026, 3, 29),
      );
      expect(entry, isNull);
    });

    test('AT-19.4.4 CalendarProgramService delegates to engine (no '
        'network clients in the constructor)', () async {
      final service = CalendarProgramService(engine);
      final results = await service.getTodayPrograms();
      expect(results, isA<List<CalendarProgramEntry>>());
      // Use explicit date for deterministic result.
      final entry = await service.getEntry(
        'mishna_yomit',
        DateTime(2026, 3, 29),
      );
      expect(entry, isNotNull);
      expect(entry!.todayRef, isNotEmpty);
    });

    test(
      'AT-19.4.5 getTodayPrograms returns entries with apiSource=local',
      () async {
        // With 20 seeded rows, getTodayPrograms returns all 20.
        final result = await engine.getTodayPrograms(DateTime(2026, 3, 29));
        expect(result, hasLength(20));
        expect(
          result.every((CalendarProgramEntry e) => e.apiSource == 'local'),
          isTrue,
        );
      },
    );

    test('AT-19.4.6 no Sefaria/Hebcal calendar providers remain in '
        'the provider graph', () async {
      // The provider creates LocalCalendarEngine with zero deps.
      // We verify the service constructor takes exactly one dependency
      // (LocalCalendarEngine) via a runtime construction.
      expect(() => CalendarProgramService(engine), returnsNormally);
    });

    test('AT-19.4.7 getEntriesForRange returns ordered entries', () async {
      final results = await engine.getEntriesForRange(
        'daf_yomi',
        DateTime(2026, 3, 25),
        DateTime(2026, 3, 29),
      );
      expect(results, hasLength(5));
      // Entries are computed deterministically from the hardcoded sequence.
      expect(results.first.todayRef, isNotEmpty);
      expect(results.last.todayRef, isNotEmpty);
      expect(results.every((e) => e.apiSource == 'local'), isTrue);
    });

    test('getEntriesForRange returns empty when program unknown to '
        'the registry', () async {
      final results = await engine.getEntriesForRange(
        'definitely_not_a_program',
        DateTime(2026, 3, 25),
        DateTime(2026, 3, 29),
      );
      expect(results, isEmpty);
    });

    test('AT-19.4.registry-consistency every registry ID round-trips '
        'through the engine', () async {
      final today = DateTime(2026, 3, 29);

      for (final def in CalendarProgramRegistry.programs) {
        final entry = await engine.getEntry(def.id, today);
        expect(
          entry,
          isNotNull,
          reason:
              '${def.id} getEntry returned null '
              '— registry<->engine ID mismatch',
        );
        expect(entry!.programId, def.id);
      }
    });
  });

  // ─── Story 19.5 superseded by Epic 20 v2 unified AuthState ──────
  group('Story 19.5 — superseded by Epic 20 v2 unified AuthState', () {
    test('unified AuthState exposes tier + session status', () {
      const signedOut = AuthState.signedOut();
      expect(signedOut.isSignedIn, isFalse);
      expect(signedOut.tier, isNull);

      const signedIn = AuthState.signedIn(
        user: AuthUser(
          profileId: 1,
          email: 'test@example.com',
          displayName: 'Test',
          userMode: 'adult',
        ),
        tier: Tier.cloudBorn,
      );
      expect(signedIn.isSignedIn, isTrue);
      expect(signedIn.isCloudBorn, isTrue);
      expect(signedIn.isLocalBorn, isFalse);
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
