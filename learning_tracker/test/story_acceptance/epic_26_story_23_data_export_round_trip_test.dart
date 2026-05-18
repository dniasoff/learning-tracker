/// Story acceptance tests for Epic 26, Story 23 — Data export rewrite.
///
/// DNI-366: all tables, profileId on every row, no PII, round-trip test.
@Tags(['epic_26', 'story_26_23'])
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';

/// Helper: create an in-memory UserDatabase for tests.
UserDatabase _db() => UserDatabase(NativeDatabase.memory());

/// Helper: create a [DataExportImportService] with a fixed appVersion
/// so tests are deterministic without a platform channel.
DataExportImportService _service(UserDatabase db) => DataExportImportService(
  database: db,
  appVersionFetcher: () async => '2.0.0-test',
);

void main() {
  group('Story 26.23 — Data export rewrite (DNI-366)', tags: ['story_26_23'], () {
    // ── 26.23.1: Format version is schemaV1 ────────────────────────
    test('export uses formatVersion: schemaV1', () async {
      final db = _db();
      addTearDown(db.close);

      final jsonStr = await _service(db).exportData();
      final data = json.decode(jsonStr) as Map<String, dynamic>;

      expect(data['formatVersion'], equals('schemaV1'));
    });

    // ── 26.23.2: appVersion comes from the injected fetcher ─────────
    test('appVersion is populated from appVersionFetcher', () async {
      final db = _db();
      addTearDown(db.close);

      final svc = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '3.4.5',
      );

      final data = json.decode(await svc.exportData()) as Map<String, dynamic>;

      expect(data['appVersion'], equals('3.4.5'));
    });

    // ── 26.23.3: No PII in export ──────────────────────────────────
    test('export omits firebaseUid, email, and passwordHash', () async {
      final db = _db();
      addTearDown(db.close);

      // Insert an account with PII
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'user@example.com',
              firebaseUid: const Value('firebase-uid-123'),
              tier: 'cloudBorn',
              displayName: 'Alice',
              userMode: 'adult',
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
            ),
          );

      final jsonStr = await _service(db).exportData();
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final profiles = data['userProfiles'] as List;

      expect(profiles, hasLength(1));
      final profile = profiles.first as Map<String, dynamic>;

      // PII must not be present
      expect(profile.containsKey('firebaseUid'), isFalse);
      expect(profile.containsKey('email'), isFalse);
      expect(profile.containsKey('passwordHash'), isFalse);

      // Non-PII must be present
      expect(profile['displayName'], equals('Alice'));
      expect(profile['userMode'], equals('adult'));
    });

    // ── 26.23.4: profileId on every user-data row ──────────────────
    test('every user-data row carries profileId', () async {
      final db = _db();
      addTearDown(db.close);
      await seedProfile(db);
      const pid = 1;

      // Insert a curriculum track (needed as FK)
      final trackId = await db
          .into(db.curriculumTracks)
          .insertReturning(
            CurriculumTracksCompanion.insert(
              profileId: pid,
              curriculumId: 'mishnayos',
              trackType: 'personal',
              activatedAt: DateTime(2026, 1, 1),
            ),
          )
          .then((r) => r.id);

      // Insert one row per profileId-bearing table
      await seedCompletion(
        db,
        CompletionsCompanion.insert(
          profileId: pid,
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah_Berakhot.1.1',
          stageId: 1,
          trackType: 'personal',
          trackId: trackId,
          completedAt: DateTime(2026, 3, 1),
        ),
      );

      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: pid,
              curriculumId: 'mishnayos',
              trackId: trackId,
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
            ),
          );

      await db
          .into(db.streaks)
          .insert(
            StreaksCompanion.insert(
              profileId: pid,
              currentStreak: const Value(3),
            ),
          );

      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              profileId: pid,
              curriculumId: 'mishnayos',
              trackId: trackId,
              sefariaRef: 'Mishnah_Berakhot.1.1',
              updatedAt: DateTime(2026, 3, 1),
            ),
          );

      final jsonStr = await _service(db).exportData();
      final data = json.decode(jsonStr) as Map<String, dynamic>;

      // Check profileId is present and correct in every exported section
      for (final row in data['curriculumTracks'] as List) {
        expect((row as Map<String, dynamic>)['profileId'], equals(pid));
      }
      for (final row in data['completions'] as List) {
        expect((row as Map<String, dynamic>)['profileId'], equals(pid));
      }
      for (final row in data['goals'] as List) {
        expect((row as Map<String, dynamic>)['profileId'], equals(pid));
      }
      for (final row in data['streaks'] as List) {
        expect((row as Map<String, dynamic>)['profileId'], equals(pid));
      }
      for (final row in data['bookmarks'] as List) {
        expect((row as Map<String, dynamic>)['profileId'], equals(pid));
      }
    });

    // ── 26.23.5: All expected tables in export ─────────────────────
    test('export includes all expected data-section keys', () async {
      final db = _db();
      addTearDown(db.close);

      final data =
          json.decode(await _service(db).exportData()) as Map<String, dynamic>;

      // All user-data sections must be present (even if empty lists)
      const expectedSections = [
        'userProfiles',
        'learnerProfiles',
        'curriculumTracks',
        'curriculumScopes',
        'profilePrograms',
        'stageDefinitions',
        'pointConfigs',
        'studyDayConfigs',
        'completions',
        'completionEvents',
        'dailyPlans',
        'learningLedger',
        'bookmarks',
        'learningOrder',
        'trackLearningOrder',
        'goals',
        'streaks',
        'streakEvents',
      ];

      for (final section in expectedSections) {
        expect(
          data.containsKey(section),
          isTrue,
          reason: 'Export must include section: $section',
        );
        expect(data[section], isList, reason: '$section must be a list');
      }

      // System-transit tables must NOT be exported
      expect(data.containsKey('syncQueue'), isFalse);
      expect(data.containsKey('textDownloadStatuses'), isFalse);
      expect(data.containsKey('outbox'), isFalse);
    });

    // ── 26.23.6: Non-trivial multi-profile round-trip ──────────────
    //
    // This is the core AC: import(export(state)) == state for a
    // multi-profile fixture with data across two profiles.
    test(
      'round-trip: import(export(state)) preserves multi-profile data exactly',
      () async {
        final db = _db();
        addTearDown(db.close);

        // ── Seed two profiles' worth of data ──────────────────────
        // Account 1
        final acct1Id = await db
            .into(db.accounts)
            .insertReturning(
              AccountsCompanion.insert(
                email: 'alice@placeholder.local',
                tier: 'localBorn',
                displayName: 'Alice',
                userMode: 'adult',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
            )
            .then((r) => r.id);

        // Account 2
        final acct2Id = await db
            .into(db.accounts)
            .insertReturning(
              AccountsCompanion.insert(
                email: 'bob@placeholder.local',
                tier: 'localBorn',
                displayName: 'Bob',
                userMode: 'adult',
                createdAt: DateTime(2026, 2, 1),
                updatedAt: DateTime(2026, 2, 1),
              ),
            )
            .then((r) => r.id);

        // Learner profile for account 1
        await db
            .into(db.learnerProfiles)
            .insertReturning(
              LearnerProfilesCompanion.insert(
                accountId: acct1Id,
                displayName: 'Alice (Learner)',
                mode: 'adult',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
            )
            .then((r) => r.id);

        // Learner profile for account 2
        await db
            .into(db.learnerProfiles)
            .insertReturning(
              LearnerProfilesCompanion.insert(
                accountId: acct2Id,
                displayName: 'Bob (Learner)',
                mode: 'child',
                createdAt: DateTime(2026, 2, 1),
                updatedAt: DateTime(2026, 2, 1),
              ),
            )
            .then((r) => r.id);

        // Curriculum tracks for profile 1 (acct1 / lp1)
        final track1Id = await db
            .into(db.curriculumTracks)
            .insertReturning(
              CurriculumTracksCompanion.insert(
                profileId: acct1Id,
                curriculumId: 'mishnayos',
                trackType: 'personal',
                activatedAt: DateTime(2026, 1, 5),
              ),
            )
            .then((r) => r.id);

        // Curriculum tracks for profile 2 (acct2 / lp2)
        final track2Id = await db
            .into(db.curriculumTracks)
            .insertReturning(
              CurriculumTracksCompanion.insert(
                profileId: acct2Id,
                curriculumId: 'bavli',
                trackType: 'personal',
                activatedAt: DateTime(2026, 2, 10),
              ),
            )
            .then((r) => r.id);

        // Completions for profile 1
        await seedCompletion(
          db,
          CompletionsCompanion.insert(
            profileId: acct1Id,
            curriculumId: 'mishnayos',
            sefariaRef: 'Mishnah_Berakhot.1.1',
            stageId: 1,
            trackType: 'personal',
            trackId: track1Id,
            completedAt: DateTime(2026, 1, 10),
            points: const Value(10),
          ),
        );

        // Completions for profile 2
        await seedCompletion(
          db,
          CompletionsCompanion.insert(
            profileId: acct2Id,
            curriculumId: 'bavli',
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: 'personal',
            trackId: track2Id,
            completedAt: DateTime(2026, 2, 15),
            points: const Value(5),
          ),
        );

        // Streaks for both profiles
        await db
            .into(db.streaks)
            .insert(
              StreaksCompanion.insert(
                profileId: acct1Id,
                currentStreak: const Value(7),
                maxStreak: const Value(12),
                lastCompletionDate: Value(DateTime(2026, 3, 1)),
              ),
            );

        await db
            .into(db.streaks)
            .insert(
              StreaksCompanion.insert(
                profileId: acct2Id,
                currentStreak: const Value(3),
                maxStreak: const Value(5),
                lastCompletionDate: Value(DateTime(2026, 3, 2)),
              ),
            );

        // Goals for profile 1
        await db
            .into(db.goals)
            .insert(
              GoalsCompanion.insert(
                profileId: acct1Id,
                curriculumId: 'mishnayos',
                trackId: track1Id,
                targetPercent: const Value(80.0),
                targetDate: Value(DateTime(2026, 12, 31)),
                description: const Value('Finish 80% by year end'),
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 2),
              ),
            );

        // Bookmarks for profile 2
        await db
            .into(db.bookmarks)
            .insert(
              BookmarksCompanion.insert(
                profileId: acct2Id,
                curriculumId: 'bavli',
                trackId: track2Id,
                sefariaRef: 'Berakhot.2a',
                updatedAt: DateTime(2026, 2, 20),
              ),
            );

        // ── Snapshot pre-export counts ─────────────────────────────
        final preCounts = {
          'accounts': (await db.select(db.accounts).get()).length,
          'learnerProfiles': (await db.select(db.learnerProfiles).get()).length,
          'curriculumTracks':
              (await db.select(db.curriculumTracks).get()).length,
          'completions':
              (await db.completionDao.internalGetAllCompletionsCrossProfile(
                scope: CrossProfileScope.dataExport,
              )).length,
          'streaks': (await db.select(db.streaks).get()).length,
          'goals': (await db.goalDao.getAllGoals()).length,
          'bookmarks': (await db.bookmarkDao.getAllBookmarks()).length,
        };

        // ── Export ────────────────────────────────────────────────
        final jsonStr = await _service(db).exportData();

        // ── Verify JSON structure ─────────────────────────────────
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        expect(data['formatVersion'], equals('schemaV1'));
        expect(data['appVersion'], equals('2.0.0-test'));

        // Verify multi-profile data is present in the export
        final exportedProfiles = data['userProfiles'] as List;
        expect(exportedProfiles, hasLength(2));
        expect(
          exportedProfiles.map((p) => (p as Map)['displayName']),
          containsAll(['Alice', 'Bob']),
        );

        // No PII
        for (final profile in exportedProfiles) {
          expect(
            (profile as Map<String, dynamic>).containsKey('firebaseUid'),
            isFalse,
          );
          expect(profile.containsKey('email'), isFalse);
        }

        // ── Wipe the DB ───────────────────────────────────────────
        await db.transaction(() async {
          await db.delete(db.streakEvents).go();
          await db.delete(db.streaks).go();
          await db.delete(db.completionEvents).go();
          await db.delete(db.completions).go();
          await db.delete(db.learningLedger).go();
          await db.delete(db.dailyPlans).go();
          await db.delete(db.trackLearningOrder).go();
          await db.delete(db.learningOrder).go();
          await db.delete(db.bookmarks).go();
          await db.delete(db.goals).go();
          await db.delete(db.studyDayConfigs).go();
          await db.delete(db.pointConfigs).go();
          await db.delete(db.stageDefinitions).go();
          await db.delete(db.profilePrograms).go();
          await db.delete(db.curriculumScopes).go();
          await db.delete(db.curriculumTracks).go();
          await db.delete(db.learnerProfiles).go();
          await db.delete(db.accounts).go();
        });

        // ── Verify DB is empty ────────────────────────────────────
        expect(await db.select(db.accounts).get(), isEmpty);
        expect(await db.select(db.curriculumTracks).get(), isEmpty);
        expect(
          await db.completionDao.internalGetAllCompletionsCrossProfile(
            scope: CrossProfileScope.dataExport,
          ),
          isEmpty,
        );

        // ── Import ────────────────────────────────────────────────
        await _service(db).importData(jsonStr);

        // ── Verify restored counts match pre-export ────────────────
        expect(
          (await db.select(db.accounts).get()).length,
          equals(preCounts['accounts']),
          reason: 'accounts count must survive round-trip',
        );
        expect(
          (await db.select(db.learnerProfiles).get()).length,
          equals(preCounts['learnerProfiles']),
          reason: 'learnerProfiles count must survive round-trip',
        );
        expect(
          (await db.select(db.curriculumTracks).get()).length,
          equals(preCounts['curriculumTracks']),
          reason: 'curriculumTracks count must survive round-trip',
        );
        expect(
          (await db.completionDao.internalGetAllCompletionsCrossProfile(
            scope: CrossProfileScope.dataExport,
          )).length,
          equals(preCounts['completions']),
          reason: 'completions count must survive round-trip',
        );
        expect(
          (await db.select(db.streaks).get()).length,
          equals(preCounts['streaks']),
          reason: 'streaks count must survive round-trip',
        );
        expect(
          (await db.goalDao.getAllGoals()).length,
          equals(preCounts['goals']),
          reason: 'goals count must survive round-trip',
        );
        expect(
          (await db.bookmarkDao.getAllBookmarks()).length,
          equals(preCounts['bookmarks']),
          reason: 'bookmarks count must survive round-trip',
        );

        // ── Verify profile isolation: each profile's data is scoped ──
        // Streaks: one per profile, with correct counts
        final streakRows = await db.select(db.streaks).get();
        final streaksByProfile = {for (final s in streakRows) s.profileId: s};

        // Profile IDs are re-inserted with auto-increment from 1
        // The two accounts get IDs (they may be different from original
        // but profileId in other tables must match).
        final restoredAccounts = await db.select(db.accounts).get();
        expect(restoredAccounts, hasLength(2));

        // Each account must have its streak row
        for (final acct in restoredAccounts) {
          expect(
            streaksByProfile.containsKey(acct.id),
            isTrue,
            reason: 'Account ${acct.displayName} must have a streak row',
          );
        }

        // Verify streak values are preserved
        final aliceAcct = restoredAccounts.firstWhere(
          (a) => a.displayName == 'Alice',
        );
        final bobAcct = restoredAccounts.firstWhere(
          (a) => a.displayName == 'Bob',
        );

        expect(streaksByProfile[aliceAcct.id]!.currentStreak, equals(7));
        expect(streaksByProfile[aliceAcct.id]!.maxStreak, equals(12));
        expect(streaksByProfile[bobAcct.id]!.currentStreak, equals(3));
        expect(streaksByProfile[bobAcct.id]!.maxStreak, equals(5));

        // Completions: profile-scoped
        final allCompletions = await db.completionDao
            .internalGetAllCompletionsCrossProfile(
              scope: CrossProfileScope.dataExport,
            );
        expect(allCompletions, hasLength(2));

        final aliceCompletion = allCompletions.firstWhere(
          (c) => c.curriculumId == 'mishnayos',
        );
        expect(aliceCompletion.profileId, equals(aliceAcct.id));
        expect(aliceCompletion.points, equals(10));

        final bobCompletion = allCompletions.firstWhere(
          (c) => c.curriculumId == 'bavli',
        );
        expect(bobCompletion.profileId, equals(bobAcct.id));
        expect(bobCompletion.points, equals(5));
      },
    );

    // ── 26.23.7: Import validates JSON structure ────────────────────
    test('importData rejects JSON missing required sections', () async {
      final db = _db();
      addTearDown(db.close);

      expect(
        () => _service(db).importData('not json'),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => _service(db).importData(
          json.encode({
            'formatVersion': 'schemaV1',
            'completions': <dynamic>[],
            // Missing other required sections
          }),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    // ── 26.23.8: C3 purgedAt tombstone survives export/import round-trip ─
    //
    // HIGH finding (adversarial review): before this fix, the export omitted
    // purgedAt from the completionEvents map, so a re-import would resurrect
    // purged history as active rows — contradicting the C3 tombstone invariant.
    test(
      'C3 purgedAt tombstone is preserved across export/import round-trip',
      () async {
        final db = _db();
        addTearDown(db.close);

        await seedProfile(db);

        // Seed a curriculum track so FK constraints are satisfied.
        await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'bavli',
                trackType: 'programmed',
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        final trackId = await (db.select(
          db.curriculumTracks,
        )..where((t) => t.profileId.equals(1))).getSingle().then((r) => r.id);

        final purgedAt = DateTime.utc(2026, 3, 1, 12);

        // Insert two events: one active, one purged (C3 tombstone).
        await db
            .into(db.completionEvents)
            .insert(
              CompletionEventsCompanion.insert(
                profileId: 1,
                curriculumId: 'bavli',
                sefariaRef: 'Berakhot 2a',
                stageId: 1,
                trackType: 'programmed',
                trackId: Value<int?>(trackId),
                points: const Value(10),
                eventTimestamp: DateTime.utc(2026, 2, 1),
              ),
            );
        await db
            .into(db.completionEvents)
            .insert(
              CompletionEventsCompanion.insert(
                profileId: 1,
                curriculumId: 'bavli',
                sefariaRef: 'Berakhot 3a',
                stageId: 1,
                trackType: 'programmed',
                trackId: Value<int?>(trackId),
                points: const Value(5),
                eventTimestamp: DateTime.utc(2026, 2, 2),
                purgedAt: Value(purgedAt),
              ),
            );

        // Confirm pre-export state: completions_view only shows the active row.
        final prePurge = await db.completionDao
            .internalGetAllCompletionsCrossProfile(
              scope: CrossProfileScope.dataExport,
            );
        expect(prePurge, hasLength(1), reason: 'view hides purged row');

        // Export then wipe then import.
        final jsonStr = await _service(db).exportData();
        final exported = json.decode(jsonStr) as Map<String, dynamic>;
        final exportedEvents = exported['completionEvents'] as List;
        expect(exportedEvents, hasLength(2), reason: 'both rows exported');
        final exportedPurged =
            exportedEvents.firstWhere(
                  (e) => (e as Map)['sefariaRef'] == 'Berakhot 3a',
                )
                as Map<String, dynamic>;
        // The ISO-8601 string in the export may use local-time notation
        // depending on how Drift round-tripped the DateTime — compare
        // the parsed instant in UTC to avoid tz-offset mismatches.
        final exportedPurgedAt = DateTime.parse(
          exportedPurged['purgedAt'] as String,
        ).toUtc();
        expect(
          exportedPurgedAt,
          equals(purgedAt),
          reason: 'purgedAt must be serialised into the export',
        );

        await db.transaction(() async {
          await db.delete(db.completionEvents).go();
          await db.delete(db.completions).go();
          await db.delete(db.streakEvents).go();
          await db.delete(db.streaks).go();
          await db.delete(db.learningLedger).go();
          await db.delete(db.dailyPlans).go();
          await db.delete(db.trackLearningOrder).go();
          await db.delete(db.learningOrder).go();
          await db.delete(db.bookmarks).go();
          await db.delete(db.goals).go();
          await db.delete(db.studyDayConfigs).go();
          await db.delete(db.pointConfigs).go();
          await db.delete(db.stageDefinitions).go();
          await db.delete(db.profilePrograms).go();
          await db.delete(db.curriculumScopes).go();
          await db.delete(db.curriculumTracks).go();
          await db.delete(db.learnerProfiles).go();
          await db.delete(db.accounts).go();
        });

        await _service(db).importData(jsonStr);

        // After import, completions_view must still show only the active row.
        final postImport = await db.completionDao
            .internalGetAllCompletionsCrossProfile(
              scope: CrossProfileScope.dataExport,
            );
        expect(
          postImport,
          hasLength(1),
          reason:
              'purgedAt tombstone must be restored on import so the purged '
              'row stays hidden from the view — no resurrection',
        );

        // The raw completion_events table must still hold both rows.
        final rawEvents = await db.select(db.completionEvents).get();
        expect(rawEvents, hasLength(2), reason: 'both rows survive round-trip');

        // The purged row must have its purgedAt restored.
        final restoredPurged = rawEvents.firstWhere(
          (e) => e.sefariaRef == 'Berakhot 3a',
        );
        expect(
          restoredPurged.purgedAt?.toUtc(),
          equals(purgedAt),
          reason: 'purgedAt must be restored exactly after import',
        );
      },
    );
  });
}
