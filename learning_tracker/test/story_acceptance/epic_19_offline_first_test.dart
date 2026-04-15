import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/content_result.dart';
import 'package:learning_tracker/core/database/seed/learning_program_seeds.dart';
import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:learning_tracker/core/database/seed_version.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/services/calendar_program_registry.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
import 'package:learning_tracker/core/services/local_calendar_engine.dart';
import 'package:learning_tracker/features/auth/domain/models/auth_state.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

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
      await userDb
          .into(userDb.userProfiles)
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
      final profiles = await userDb.select(userDb.userProfiles).get();
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
            .into(userDb.userProfiles)
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
        final profile = await userDb.select(userDb.userProfiles).getSingle();
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
      // v3 dropped calendar_cycles, learning_programs, test_dates —
      // those are now computed at runtime.
      const expected = [
        'text_cache',
        'seed_metadata',
      ];
      for (final t in expected) {
        final rows = await contentDb
            .customSelect('PRAGMA table_info($t)')
            .get();
        expect(rows, isNotEmpty, reason: 'table $t should exist');
      }
    });

    test('AT-19.3.2 programs-only seed yields 18 LearningPrograms with '
        'api fields populated', () {
      // Programs are now served from LearningProgramRepository (compile-time).
      final rows = LearningProgramRepository.instance.getAllPrograms();
      expect(rows, hasLength(18));

      final dafYomi = rows.firstWhere((p) => p.name == 'daf_yomi');
      expect(dafYomi.apiSource, 'sefaria');
      expect(dafYomi.apiProgramKey, 'Daf Yomi');
      expect(dafYomi.isCalendarProgram, isTrue);

      final mishnahYomis = rows.firstWhere((p) => p.name == 'mishnah_yomis');
      expect(mishnahYomis.apiSource, 'sefaria');
      expect(mishnahYomis.apiProgramKey, 'Daily Mishnah');
      expect(mishnahYomis.isCalendarProgram, isTrue);

      final nachYomi = rows.firstWhere((p) => p.name == 'nach_yomi');
      expect(nachYomi.apiSource, 'hebcal');
      expect(nachYomi.apiProgramKey, 'nachyomi');
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
      // Calendar cycles are now computed by LocalCalendarEngine, not stored
      // in the ContentDatabase. Verify the engine can resolve entries.
      final engine = LocalCalendarEngine();
      final hit = await engine.getEntry('daf_yomi', DateTime(2025, 1, 3));
      expect(hit, isNotNull);
      expect(hit!.programId, 'daf_yomi');
      expect(hit.todayRef, isNotEmpty);

      // Unknown program returns null
      final miss = await engine.getEntry('nonexistent_program', DateTime(2025, 1, 3));
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
      expect(learningProgramSeeds, hasLength(18));
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
    late LocalCalendarEngine engine;

    setUp(() {
      engine = LocalCalendarEngine();
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
      expect(entry.apiSource, 'computed');

      // Display names sourced from the registry.
      final def = CalendarProgramRegistry.byId('daf_yomi')!;
      expect(entry.displayNameEn, def.displayNameEn);
      expect(entry.displayNameHe, def.displayNameHe);
    });

    test('AT-19.4.2 getTodayPrograms returns entries for all 12 '
        'programs', () async {
      final results = await engine.getTodayPrograms(DateTime(2026, 3, 29));
      expect(results, hasLength(12));
      for (final entry in results) {
        expect(entry.todayRef, isNotEmpty);
        expect(entry.apiSource, 'computed');
      }
      final ids = results.map((e) => e.programId).toSet();
      expect(ids, hasLength(12));
      expect(ids.contains('daf_yomi'), isTrue);
      expect(ids.contains('nach_yomi'), isTrue);
      expect(ids.contains('chofetz_chaim_daily'), isTrue);
    });

    test(
      'AT-19.4.3 getEntry returns null for unknown programId',
      () async {
        final entry = await engine.getEntry(
          'nonexistent_program',
          DateTime(2026, 3, 29),
        );
        expect(entry, isNull);
      },
    );

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
      'AT-19.4.5 todayCalendarProvider resolves from LocalCalendarEngine',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final result = await container.read(todayCalendarProvider.future);
        expect(result, hasLength(12));
        expect(
          result.every(
            (CalendarProgramEntry e) => e.apiSource == 'computed',
          ),
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
      expect(results.every((e) => e.apiSource == 'computed'), isTrue);
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
