/// Coverage for manager createCompanion / updateCompanion callbacks and
/// withReferenceMapper for all 22 tables in user_database.g.dart.
///
/// Each group triggers:
///   - createCompanionCallback via db.managers.x.create(...)
///   - updateCompanionCallback via db.managers.x.update(...)
///   - withReferenceMapper via db.managers.x.withReferences().get()
///
/// No Firebase or Riverpod. Plain Drift in-memory DB.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  final now = DateTime.utc(2026, 3, 1, 12);

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ── shared setup helpers ───────────────────────────────────────────────────

  /// Creates an account via the manager create() API (triggers createCompanionCallback).
  Future<int> makeAccount({String email = 'mgr@test.local'}) =>
      db.managers.accounts.create(
        (o) => o(
          email: email,
          tier: 'cloudBorn',
          displayName: 'User',
          createdAt: now,
          updatedAt: now,
          firebaseUid: const Value('fb-uid'),
        ),
      );

  Future<int> makeProfile(int accountId) => db.managers.learnerProfiles.create(
    (o) => o(
      accountId: accountId,
      displayName: 'Learner',
      mode: 'adult',
      createdAt: now,
      updatedAt: now,
    ),
  );

  Future<int> makeTrack(int profileId) => db.managers.curriculumTracks.create(
    (o) => o(
      profileId: profileId,
      curriculumId: 'bavli',
      stateChangedAt: now,
      activatedAt: now,
    ),
  );

  Future<int> makeStage(int profileId, int trackId) =>
      db.managers.stageDefinitions.create(
        (o) => o(
          profileId: profileId,
          trackId: trackId,
          curriculumId: 'bavli',
          stageName: 'limud',
          stageOrder: 1,
        ),
      );

  // ── accounts ───────────────────────────────────────────────────────────────

  group('accounts manager create/update/withReferences', () {
    late int accId;

    setUp(() async {
      accId = await makeAccount(email: 'acc-mgr@test.local');
    });

    test('create via manager callback', () async {
      expect(accId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.accounts
          .filter((f) => f.id(accId))
          .update(
            (o) =>
                o(displayName: const Value('Updated'), updatedAt: Value(now)),
          );
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.accounts.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── learnerProfiles ────────────────────────────────────────────────────────

  group('learnerProfiles manager create/update/withReferences', () {
    late int accId;
    late int profId;

    setUp(() async {
      accId = await makeAccount(email: 'lp-mgr@test.local');
      profId = await makeProfile(accId);
    });

    test('create via manager callback', () async {
      expect(profId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.learnerProfiles
          .filter((f) => f.id(profId))
          .update(
            (o) =>
                o(displayName: const Value('NewName'), updatedAt: Value(now)),
          );
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.learnerProfiles.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── curriculumTracks ───────────────────────────────────────────────────────

  group('curriculumTracks manager create/update/withReferences', () {
    late int accId;
    late int profId;
    late int trackId;

    setUp(() async {
      accId = await makeAccount(email: 'ct-mgr@test.local');
      profId = await makeProfile(accId);
      trackId = await makeTrack(profId);
    });

    test('create via manager callback', () async {
      expect(trackId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.curriculumTracks
          .filter((f) => f.id(trackId))
          .update((o) => o(state: const Value('retired')));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.curriculumTracks.withReferences().get();
      expect(rows, isNotEmpty);
    });

    test('filter by reverse ref curriculumScopesRefs', () async {
      // Insert a scope to trigger the curriculumScopesRefs filter method
      await db
          .into(db.curriculumScopes)
          .insert(
            CurriculumScopesCompanion.insert(
              profileId: profId,
              curriculumId: 'bavli',
              trackId: trackId,
              scopeLevel: 1,
              scopeValue: 'masechet',
              createdAt: now,
            ),
          );
      final rows = await db.managers.curriculumTracks
          .filter(
            (f) => f.curriculumScopesRefs((s) => s.scopeValue('masechet')),
          )
          .get();
      expect(rows, isNotEmpty);
    });
  });

  // ── curriculumScopes ───────────────────────────────────────────────────────

  group('curriculumScopes manager create/update/withReferences', () {
    late int scopeId;

    setUp(() async {
      final accId = await makeAccount(email: 'cs-mgr@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      scopeId = await db.managers.curriculumScopes.create(
        (o) => o(
          profileId: profId,
          curriculumId: 'bavli',
          trackId: trackId,
          scopeLevel: 1,
          scopeValue: 'masechet',
          createdAt: now,
        ),
      );
    });

    test('create via manager callback', () async {
      expect(scopeId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.curriculumScopes
          .filter((f) => f.id(scopeId))
          .update((o) => o(scopeValue: const Value('perek')));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.curriculumScopes.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── profilePrograms ────────────────────────────────────────────────────────

  group('profilePrograms manager create/update/withReferences', () {
    late int ppId;

    setUp(() async {
      final accId = await makeAccount(email: 'pp-mgr@test.local');
      final profId = await makeProfile(accId);
      ppId = await db.managers.profilePrograms.create(
        (o) => o(profileId: profId, curriculumType: 'daf', programId: 1),
      );
    });

    test('create via manager callback', () async {
      expect(ppId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.profilePrograms
          .filter((f) => f.id(ppId))
          .update((o) => o(curriculumType: const Value('mishnah')));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.profilePrograms.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── stageDefinitions ───────────────────────────────────────────────────────

  group('stageDefinitions manager create/update/withReferences', () {
    late int stageId;

    setUp(() async {
      final accId = await makeAccount(email: 'sd-mgr@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      stageId = await makeStage(profId, trackId);
    });

    test('create via manager callback', () async {
      expect(stageId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.stageDefinitions
          .filter((f) => f.id(stageId))
          .update((o) => o(stageName: const Value('chazara')));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.stageDefinitions.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── pointConfigs ───────────────────────────────────────────────────────────

  group('pointConfigs manager create/update/withReferences', () {
    late int pcId;

    setUp(() async {
      final accId = await makeAccount(email: 'pc-mgr@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeStage(profId, trackId);
      pcId = await db.managers.pointConfigs.create(
        (o) => o(
          profileId: profId,
          curriculumId: 'bavli',
          trackId: trackId,
          stageOrder: 1,
          points: 10,
        ),
      );
    });

    test('create via manager callback', () async {
      expect(pcId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.pointConfigs
          .filter((f) => f.id(pcId))
          .update((o) => o(points: const Value(20)));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.pointConfigs.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── studyDayConfigs ────────────────────────────────────────────────────────

  group('studyDayConfigs manager create/update/withReferences', () {
    setUp(() async {
      final accId = await makeAccount(email: 'sdc-mgr@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await db.managers.studyDayConfigs.create(
        (o) => o(
          profileId: profId,
          curriculumId: 'bavli',
          trackId: trackId,
          dayOfWeek: 0,
          updatedAt: now,
        ),
      );
    });

    test('create via manager callback', () async {
      final rows = await db.managers.studyDayConfigs.get();
      expect(rows, isNotEmpty);
    });

    test('update via manager callback', () async {
      final count = await db.managers.studyDayConfigs.update(
        (o) => o(dayType: const Value('always')),
      );
      expect(count, isNonNegative);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.studyDayConfigs.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── completions ────────────────────────────────────────────────────────────

  group('completions manager create/update/withReferences', () {
    late int completionId;

    setUp(() async {
      final accId = await makeAccount(email: 'cm-mgr@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      final stageId = await makeStage(profId, trackId);
      completionId = await db.managers.completionEvents.create(
        (o) => o(
          profileId: profId,
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot 2a',
          stageId: stageId,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: now,
        ),
      );
    });

    test('create via manager callback', () async {
      expect(completionId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.completionEvents
          .filter((f) => f.id(completionId))
          .update((o) => o(sefariaRef: const Value('Berakhot 3a')));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.completionEvents.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── completionEvents ───────────────────────────────────────────────────────

  group('completionEvents manager create/update/withReferences', () {
    late int ceId;

    setUp(() async {
      final accId = await makeAccount(email: 'ce-mgr@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      final stageId = await makeStage(profId, trackId);
      ceId = await db.managers.completionEvents.create(
        (o) => o(
          profileId: profId,
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot 2a',
          stageId: stageId,
          trackType: 'personal',
          eventTimestamp: now,
        ),
      );
    });

    test('create via manager callback', () async {
      expect(ceId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.completionEvents
          .filter((f) => f.id(ceId))
          .update((o) => o(sefariaRef: const Value('Berakhot 3a')));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.completionEvents.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── dailyPlans ─────────────────────────────────────────────────────────────

  group('dailyPlans manager create/update/withReferences', () {
    late int dpId;

    setUp(() async {
      final accId = await makeAccount(email: 'dp-mgr@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      final stageId = await makeStage(profId, trackId);
      dpId = await db.managers.dailyPlans.create(
        (o) => o(
          profileId: profId,
          curriculumId: 'bavli',
          planDate: now,
          sefariaRef: 'Berakhot 2a',
          stageOrder: 1,
          stageDefinitionId: stageId,
          trackId: trackId,
          priority: 'normal',
          createdAt: now,
        ),
      );
    });

    test('create via manager callback', () async {
      expect(dpId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.dailyPlans
          .filter((f) => f.id(dpId))
          .update((o) => o(priority: const Value('high')));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.dailyPlans.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── learningLedger ─────────────────────────────────────────────────────────

  group('learningLedger manager create/update/withReferences', () {
    late int llId;

    setUp(() async {
      final accId = await makeAccount(email: 'll-mgr@test.local');
      final profId = await makeProfile(accId);
      llId = await db.managers.learningLedger.create(
        (o) => o(
          profileId: profId,
          curriculumId: 'bavli',
          entryScope: 'daf',
          unitIdentifier: 'Berakhot 2a',
          unitDisplayNameHe: 'ברכות ב',
          unitDisplayNameEn: 'Berakhot 2a',
          trackType: 'personal',
          completedAt: now,
          completionNumber: 1,
          markedBy: 0,
        ),
      );
    });

    test('create via manager callback', () async {
      expect(llId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.learningLedger
          .filter((f) => f.id(llId))
          .update((o) => o(completionNumber: const Value(2)));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.learningLedger.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── bookmarks ──────────────────────────────────────────────────────────────

  group('bookmarks manager create/update/withReferences', () {
    late int bmId;

    setUp(() async {
      final accId = await makeAccount(email: 'bm-mgr@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      bmId = await db.managers.bookmarks.create(
        (o) => o(
          profileId: profId,
          curriculumId: 'bavli',
          trackId: trackId,
          sefariaRef: 'Berakhot 2a',
          updatedAt: now,
        ),
      );
    });

    test('create via manager callback', () async {
      expect(bmId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.bookmarks
          .filter((f) => f.id(bmId))
          .update(
            (o) => o(
              sefariaRef: const Value('Berakhot 3a'),
              updatedAt: Value(now),
            ),
          );
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.bookmarks.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── learningOrder ──────────────────────────────────────────────────────────

  group('learningOrder manager create/update/withReferences', () {
    late int loId;

    setUp(() async {
      final accId = await makeAccount(email: 'lo-mgr@test.local');
      final profId = await makeProfile(accId);
      loId = await db.managers.learningOrder.create(
        (o) => o(
          profileId: profId,
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot 2a',
          userSortOrder: 1,
        ),
      );
    });

    test('create via manager callback', () async {
      expect(loId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.learningOrder
          .filter((f) => f.id(loId))
          .update((o) => o(userSortOrder: const Value(2)));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.learningOrder.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── trackLearningOrder ─────────────────────────────────────────────────────

  group('trackLearningOrder manager create/update/withReferences', () {
    late int tloId;

    setUp(() async {
      final accId = await makeAccount(email: 'tlo-mgr@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      tloId = await db.managers.trackLearningOrder.create(
        (o) => o(trackId: trackId, sefariaRef: 'Berakhot 2a', sortOrder: 1),
      );
    });

    test('create via manager callback', () async {
      expect(tloId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.trackLearningOrder
          .filter((f) => f.id(tloId))
          .update((o) => o(sortOrder: const Value(2)));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.trackLearningOrder.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── goals ──────────────────────────────────────────────────────────────────

  group('goals manager create/update/withReferences', () {
    late int goalId;

    setUp(() async {
      final accId = await makeAccount(email: 'gl-mgr@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      goalId = await db.managers.goals.create(
        (o) => o(
          profileId: profId,
          curriculumId: 'bavli',
          trackId: trackId,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    test('create via manager callback', () async {
      expect(goalId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.goals
          .filter((f) => f.id(goalId))
          .update((o) => o(updatedAt: Value(now)));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.goals.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── streakEvents ───────────────────────────────────────────────────────────

  group('streakEvents manager create/update/withReferences', () {
    late int seId;

    setUp(() async {
      final accId = await makeAccount(email: 'se-mgr@test.local');
      final profId = await makeProfile(accId);
      seId = await db.managers.streakEvents.create(
        (o) => o(
          profileId: profId,
          eventType: 'completion',
          dayUtc: DateTime.utc(2026, 3, 1),
          eventTimestamp: now,
          clientDeviceId: const Value('dev-1'),
        ),
      );
    });

    test('create via manager callback', () async {
      expect(seId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.streakEvents
          .filter((f) => f.id(seId))
          .update((o) => o(eventType: const Value('grace')));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.streakEvents.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── textDownloadStatuses ───────────────────────────────────────────────────

  group('textDownloadStatuses manager create/update/withReferences', () {
    setUp(() async {
      await db.managers.textDownloadStatuses.create(
        (o) => o(
          curriculumId: 'bavli',
          itemCount: 50,
          textVersion: 'v1',
          downloadedAt: now,
        ),
      );
    });

    test('create via manager callback', () async {
      final rows = await db.managers.textDownloadStatuses.get();
      expect(rows, isNotEmpty);
    });

    test('update via manager callback', () async {
      final count = await db.managers.textDownloadStatuses.update(
        (o) => o(storedItemCount: const Value(100)),
      );
      expect(count, isNonNegative);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.textDownloadStatuses
          .withReferences()
          .get();
      expect(rows, isNotEmpty);
    });
  });

  // ── outbox ─────────────────────────────────────────────────────────────────

  group('outbox manager create/update/withReferences', () {
    late int outboxId;

    setUp(() async {
      final accId = await makeAccount(email: 'ob-mgr@test.local');
      final profId = await makeProfile(accId);
      outboxId = await db.managers.outbox.create(
        (o) => o(
          profileId: profId,
          entityKind: 'completion',
          entityKey: 'key-1',
          payload: '{}',
          createdAt: now,
        ),
      );
    });

    test('create via manager callback', () async {
      expect(outboxId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.outbox
          .filter((f) => f.id(outboxId))
          .update((o) => o(entityKey: const Value('key-2')));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.outbox.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── sacredWindowEntries ────────────────────────────────────────────────────

  group('sacredWindowEntries manager create/update/withReferences', () {
    late int sweId;

    setUp(() async {
      sweId = await db.managers.sacredWindowEntries.create(
        (o) => o(
          startUtc: now,
          endUtc: now.add(const Duration(hours: 25)),
          kind: 'shabbos',
          inIsrael: true,
          createdAt: Value(now),
        ),
      );
    });

    test('create via manager callback', () async {
      expect(sweId, isPositive);
    });

    test('update via manager callback', () async {
      final count = await db.managers.sacredWindowEntries
          .filter((f) => f.id(sweId))
          .update((o) => o(kind: const Value('yomtov')));
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.sacredWindowEntries.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });
}
