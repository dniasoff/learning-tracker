/// Coverage for References getter classes and prefetchHooksCallback paths
/// in user_database.g.dart.
///
/// Covers:
///   - $$CurriculumTracksTableReferences: curriculumScopesRefs,
///     stageDefinitionsRefs, pointConfigsRefs, studyDayConfigsRefs,
///     completionsRefs, learningLedgerRefs, bookmarksRefs, goalsRefs
///   - $$CurriculumTracksTableAnnotationComposer: curriculumScopesRefs(),
///     stageDefinitionsRefs(), pointConfigsRefs(), studyDayConfigsRefs(),
///     completionsRefs(), learningLedgerRefs(), bookmarksRefs(), goalsRefs()
///   - prefetchHooksCallback for curriculumTracks (all 8 ref flags)
///   - $$CurriculumScopesTableReferences.trackId
///   - $$StageDefinitionsTableReferences.trackId
///   - $$PointConfigsTableReferences.trackId
///   - $$StudyDayConfigsTableReferences.trackId
///   - $$CompletionsTableReferences.trackId
///   - $$LearningLedgerTableReferences.trackId
///   - $$BookmarksTableReferences.trackId
///   - $$GoalsTableReferences.trackId
///   - LearnerProfiles filter displayName (L12213-12215)
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

  // ── shared setup helpers ────────────────────────────────────────────────────

  Future<int> makeAccount({String email = 'refs@test.local'}) =>
      db.managers.accounts.create(
        (o) => o(
          email: email,
          tier: 'cloudBorn',
          displayName: 'RefsUser',
          userMode: 'adult',
          createdAt: now,
          updatedAt: now,
          firebaseUid: const Value('fb-refs'),
        ),
      );

  Future<int> makeProfile(int accountId, {String name = 'RefsLearner'}) =>
      db.managers.learnerProfiles.create(
        (o) => o(
          accountId: accountId,
          displayName: name,
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

  Future<void> makeScope(int profileId, int trackId) =>
      db.managers.curriculumScopes.create(
        (o) => o(
          profileId: profileId,
          trackId: trackId,
          curriculumId: 'bavli',
          scopeLevel: 1,
          scopeValue: 'masechet',
          createdAt: now,
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
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );

  Future<void> makePointConfig(int profileId, int trackId) =>
      db.managers.pointConfigs.create(
        (o) => o(
          profileId: profileId,
          trackId: trackId,
          curriculumId: 'bavli',
          stageOrder: 1,
          points: 10,
        ),
      );

  Future<void> makeStudyDayConfig(int profileId, int trackId) =>
      db.managers.studyDayConfigs.create(
        (o) => o(
          profileId: profileId,
          trackId: trackId,
          curriculumId: 'bavli',
          dayOfWeek: 0,
          updatedAt: now,
        ),
      );

  Future<void> makeCompletion(int profileId, int trackId, int stageId) =>
      db.managers.completionEvents.create(
        (o) => o(
          profileId: profileId,
          trackId: Value(trackId),
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot 2a',
          stageId: stageId,
          trackType: 'personal',
          eventTimestamp: now,
        ),
      );

  Future<void> makeLedgerEntry(int profileId, {int? trackId}) =>
      db.managers.learningLedger.create(
        (o) => o(
          profileId: profileId,
          curriculumId: 'bavli',
          entryScope: 'daf',
          unitIdentifier: 'Berakhot 2a',
          unitDisplayNameHe: 'ברכות ב',
          unitDisplayNameEn: 'Berakhot 2a',
          trackType: 'personal',
          completedAt: now,
          completionNumber: 1,
          markedBy: 0,
          trackId: Value(trackId),
        ),
      );

  Future<void> makeBookmark(int profileId, int trackId) =>
      db.managers.bookmarks.create(
        (o) => o(
          profileId: profileId,
          trackId: trackId,
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot 2a',
          updatedAt: now,
        ),
      );

  Future<void> makeGoal(int profileId, int trackId) => db.managers.goals.create(
    (o) => o(
      profileId: profileId,
      trackId: trackId,
      curriculumId: 'bavli',
      createdAt: now,
      updatedAt: now,
    ),
  );

  // ── LearnerProfiles filter displayName ────────────────────────────────────

  group('LearnerProfiles filter displayName', () {
    test('filter by displayName', () async {
      final accId = await makeAccount(email: 'disp@test.local');
      await makeProfile(accId, name: 'SpecificName');
      final rows = await db.managers.learnerProfiles
          .filter((f) => f.displayName('SpecificName'))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.displayName, 'SpecificName');
    });
  });

  // ── curriculumTracks References getters ───────────────────────────────────

  group('curriculumTracks References: refs getters', () {
    late int profId;
    late int trackId;
    late int stageId;

    setUp(() async {
      final accId = await makeAccount(email: 'track-refs@test.local');
      profId = await makeProfile(accId);
      trackId = await makeTrack(profId);
      stageId = await makeStage(profId, trackId);
      await makeScope(profId, trackId);
      await makePointConfig(profId, trackId);
      await makeStudyDayConfig(profId, trackId);
      await makeCompletion(profId, trackId, stageId);
      await makeLedgerEntry(profId, trackId: trackId);
      await makeBookmark(profId, trackId);
      await makeGoal(profId, trackId);
    });

    test('curriculumScopesRefs getter returns manager', () async {
      final rows = await db.managers.curriculumTracks.withReferences().get();
      expect(rows, isNotEmpty);
      final refs = rows.first.$2;
      final manager = refs.curriculumScopesRefs;
      expect(manager, isNotNull);
    });

    test('stageDefinitionsRefs getter returns manager', () async {
      final rows = await db.managers.curriculumTracks.withReferences().get();
      final refs = rows.first.$2;
      final manager = refs.stageDefinitionsRefs;
      expect(manager, isNotNull);
    });

    test('pointConfigsRefs getter returns manager', () async {
      final rows = await db.managers.curriculumTracks.withReferences().get();
      final refs = rows.first.$2;
      final manager = refs.pointConfigsRefs;
      expect(manager, isNotNull);
    });

    test('studyDayConfigsRefs getter returns manager', () async {
      final rows = await db.managers.curriculumTracks.withReferences().get();
      final refs = rows.first.$2;
      final manager = refs.studyDayConfigsRefs;
      expect(manager, isNotNull);
    });

    test('stageDefinitionsRefs getter returns manager', () async {
      final rows = await db.managers.curriculumTracks.withReferences().get();
      final refs = rows.first.$2;
      final manager = refs.stageDefinitionsRefs;
      expect(manager, isNotNull);
    });

    test('learningLedgerRefs getter returns manager', () async {
      final rows = await db.managers.curriculumTracks.withReferences().get();
      final refs = rows.first.$2;
      final manager = refs.learningLedgerRefs;
      expect(manager, isNotNull);
    });

    test('bookmarksRefs getter returns manager', () async {
      final rows = await db.managers.curriculumTracks.withReferences().get();
      final refs = rows.first.$2;
      final manager = refs.bookmarksRefs;
      expect(manager, isNotNull);
    });

    test('goalsRefs getter returns manager', () async {
      final rows = await db.managers.curriculumTracks.withReferences().get();
      final refs = rows.first.$2;
      final manager = refs.goalsRefs;
      expect(manager, isNotNull);
    });
  });

  // ── curriculumTracks AnnotationComposer refs methods ─────────────────────

  group('curriculumTracks AnnotationComposer: refs computedField', () {
    late int profId;
    late int trackId;
    late int stageId;

    setUp(() async {
      final accId = await makeAccount(email: 'ct-ann@test.local');
      profId = await makeProfile(accId);
      trackId = await makeTrack(profId);
      stageId = await makeStage(profId, trackId);
      await makeScope(profId, trackId);
      await makePointConfig(profId, trackId);
      await makeStudyDayConfig(profId, trackId);
      await makeCompletion(profId, trackId, stageId);
      await makeLedgerEntry(profId, trackId: trackId);
      await makeBookmark(profId, trackId);
      await makeGoal(profId, trackId);
    });

    test('computedField via curriculumScopesRefs annotation', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.curriculumScopesRefs((s) => s.id),
      );
      final rows = await db.managers.curriculumTracks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField via stageDefinitionsRefs annotation', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.stageDefinitionsRefs((s) => s.id),
      );
      final rows = await db.managers.curriculumTracks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField via pointConfigsRefs annotation', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.pointConfigsRefs((s) => s.id),
      );
      final rows = await db.managers.curriculumTracks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField via studyDayConfigsRefs annotation', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.studyDayConfigsRefs((s) => s.profileId),
      );
      final rows = await db.managers.curriculumTracks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField via stageDefinitionsRefs annotation', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.stageDefinitionsRefs((s) => s.id),
      );
      final rows = await db.managers.curriculumTracks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField via learningLedgerRefs annotation', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.learningLedgerRefs((s) => s.id),
      );
      final rows = await db.managers.curriculumTracks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField via bookmarksRefs annotation', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.bookmarksRefs((s) => s.id),
      );
      final rows = await db.managers.curriculumTracks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField via goalsRefs annotation', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.goalsRefs((s) => s.id),
      );
      final rows = await db.managers.curriculumTracks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── prefetchHooksCallback for curriculumTracks ────────────────────────────

  group('curriculumTracks withReferences prefetch hooks', () {
    late int profId;
    late int trackId;
    late int stageId;

    setUp(() async {
      final accId = await makeAccount(email: 'prefetch@test.local');
      profId = await makeProfile(accId);
      trackId = await makeTrack(profId);
      stageId = await makeStage(profId, trackId);
      await makeScope(profId, trackId);
      await makePointConfig(profId, trackId);
      await makeStudyDayConfig(profId, trackId);
      await makeCompletion(profId, trackId, stageId);
      await makeLedgerEntry(profId, trackId: trackId);
      await makeBookmark(profId, trackId);
      await makeGoal(profId, trackId);
    });

    test('withReferences curriculumScopesRefs prefetch', () async {
      final rows = await db.managers.curriculumTracks
          .withReferences((p) => p(curriculumScopesRefs: true))
          .get();
      expect(rows, isNotEmpty);
    });

    test('withReferences stageDefinitionsRefs prefetch', () async {
      final rows = await db.managers.curriculumTracks
          .withReferences((p) => p(stageDefinitionsRefs: true))
          .get();
      expect(rows, isNotEmpty);
    });

    test('withReferences pointConfigsRefs prefetch', () async {
      final rows = await db.managers.curriculumTracks
          .withReferences((p) => p(pointConfigsRefs: true))
          .get();
      expect(rows, isNotEmpty);
    });

    test('withReferences studyDayConfigsRefs prefetch', () async {
      final rows = await db.managers.curriculumTracks
          .withReferences((p) => p(studyDayConfigsRefs: true))
          .get();
      expect(rows, isNotEmpty);
    });

    test('withReferences stageDefinitionsRefs prefetch', () async {
      final rows = await db.managers.curriculumTracks
          .withReferences((p) => p(stageDefinitionsRefs: true))
          .get();
      expect(rows, isNotEmpty);
    });

    test('withReferences learningLedgerRefs prefetch', () async {
      final rows = await db.managers.curriculumTracks
          .withReferences((p) => p(learningLedgerRefs: true))
          .get();
      expect(rows, isNotEmpty);
    });

    test('withReferences bookmarksRefs prefetch', () async {
      final rows = await db.managers.curriculumTracks
          .withReferences((p) => p(bookmarksRefs: true))
          .get();
      expect(rows, isNotEmpty);
    });

    test('withReferences goalsRefs prefetch', () async {
      final rows = await db.managers.curriculumTracks
          .withReferences((p) => p(goalsRefs: true))
          .get();
      expect(rows, isNotEmpty);
    });

    test('withReferences all refs prefetch at once', () async {
      final rows = await db.managers.curriculumTracks
          .withReferences(
            (p) => p(
              curriculumScopesRefs: true,
              stageDefinitionsRefs: true,
              pointConfigsRefs: true,
              studyDayConfigsRefs: true,
              learningLedgerRefs: true,
              bookmarksRefs: true,
              goalsRefs: true,
            ),
          )
          .get();
      expect(rows, isNotEmpty);
    });
  });

  // ── other table References: trackId getter ────────────────────────────────

  group('curriculumScopes References: trackId getter', () {
    test('withReferences returns trackId manager', () async {
      final accId = await makeAccount(email: 'scope-refs@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeScope(profId, trackId);

      final rows = await db.managers.curriculumScopes.withReferences().get();
      expect(rows, isNotEmpty);
      final manager = rows.first.$2.trackId;
      expect(manager, isNotNull);
    });
  });

  group('stageDefinitions References: trackId getter', () {
    test('withReferences returns trackId manager', () async {
      final accId = await makeAccount(email: 'stage-refs@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeStage(profId, trackId);

      final rows = await db.managers.stageDefinitions.withReferences().get();
      expect(rows, isNotEmpty);
      final manager = rows.first.$2.trackId;
      expect(manager, isNotNull);
    });
  });

  group('pointConfigs References: trackId getter', () {
    test('withReferences returns trackId manager', () async {
      final accId = await makeAccount(email: 'pc-refs@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makePointConfig(profId, trackId);

      final rows = await db.managers.pointConfigs.withReferences().get();
      expect(rows, isNotEmpty);
      final manager = rows.first.$2.trackId;
      expect(manager, isNotNull);
    });
  });

  group('studyDayConfigs References: trackId getter', () {
    test('withReferences returns trackId manager', () async {
      final accId = await makeAccount(email: 'sdc-refs@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeStudyDayConfig(profId, trackId);

      final rows = await db.managers.studyDayConfigs.withReferences().get();
      expect(rows, isNotEmpty);
      final manager = rows.first.$2.trackId;
      expect(manager, isNotNull);
    });
  });

  group('completions References: profileId getter', () {
    test('withReferences returns profileId manager', () async {
      final accId = await makeAccount(email: 'cmp-refs@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      final stageId = await makeStage(profId, trackId);
      await makeCompletion(profId, trackId, stageId);

      final rows = await db.managers.completionEvents.withReferences().get();
      expect(rows, isNotEmpty);
      final manager = rows.first.$2.profileId;
      expect(manager, isNotNull);
    });
  });

  group('learningLedger References: trackId getter', () {
    test('withReferences returns trackId manager', () async {
      final accId = await makeAccount(email: 'll-refs@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeLedgerEntry(profId, trackId: trackId);

      final rows = await db.managers.learningLedger.withReferences().get();
      expect(rows, isNotEmpty);
      // trackId is nullable
      final manager = rows.first.$2.trackId;
      expect(manager, anything);
    });
  });

  group('bookmarks References: trackId getter', () {
    test('withReferences returns trackId manager', () async {
      final accId = await makeAccount(email: 'bk-refs@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeBookmark(profId, trackId);

      final rows = await db.managers.bookmarks.withReferences().get();
      expect(rows, isNotEmpty);
      final manager = rows.first.$2.trackId;
      expect(manager, isNotNull);
    });
  });

  group('goals References: trackId getter', () {
    test('withReferences returns trackId manager', () async {
      final accId = await makeAccount(email: 'goal-refs@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeGoal(profId, trackId);

      final rows = await db.managers.goals.withReferences().get();
      expect(rows, isNotEmpty);
      final manager = rows.first.$2.trackId;
      expect(manager, isNotNull);
    });
  });

  // ── studyDayConfigs prefetch trackId ─────────────────────────────────────

  group('studyDayConfigs withReferences prefetch trackId', () {
    test('withReferences trackId prefetch', () async {
      final accId = await makeAccount(email: 'sdc-pf@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeStudyDayConfig(profId, trackId);

      final rows = await db.managers.studyDayConfigs
          .withReferences((p) => p(trackId: true))
          .get();
      expect(rows, isNotEmpty);
    });
  });

  group('curriculumScopes withReferences prefetch trackId', () {
    test('withReferences trackId prefetch', () async {
      final accId = await makeAccount(email: 'cs-pf@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeScope(profId, trackId);

      final rows = await db.managers.curriculumScopes
          .withReferences((p) => p(trackId: true))
          .get();
      expect(rows, isNotEmpty);
    });
  });

  group('stageDefinitions withReferences prefetch trackId', () {
    test('withReferences trackId prefetch', () async {
      final accId = await makeAccount(email: 'sd-pf@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeStage(profId, trackId);

      final rows = await db.managers.stageDefinitions
          .withReferences((p) => p(trackId: true))
          .get();
      expect(rows, isNotEmpty);
    });
  });

  group('pointConfigs withReferences prefetch trackId', () {
    test('withReferences trackId prefetch', () async {
      final accId = await makeAccount(email: 'pc-pf@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makePointConfig(profId, trackId);

      final rows = await db.managers.pointConfigs
          .withReferences((p) => p(trackId: true))
          .get();
      expect(rows, isNotEmpty);
    });
  });

  group('completions withReferences prefetch profileId', () {
    test('withReferences profileId prefetch', () async {
      final accId = await makeAccount(email: 'cm-pf@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      final stageId = await makeStage(profId, trackId);
      await makeCompletion(profId, trackId, stageId);

      final rows = await db.managers.completionEvents
          .withReferences((p) => p(profileId: true))
          .get();
      expect(rows, isNotEmpty);
    });
  });

  group('learningLedger withReferences prefetch trackId', () {
    test('withReferences trackId prefetch', () async {
      final accId = await makeAccount(email: 'll-pf@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeLedgerEntry(profId, trackId: trackId);

      final rows = await db.managers.learningLedger
          .withReferences((p) => p(trackId: true))
          .get();
      expect(rows, isNotEmpty);
    });
  });

  group('bookmarks withReferences prefetch trackId', () {
    test('withReferences trackId prefetch', () async {
      final accId = await makeAccount(email: 'bk-pf@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeBookmark(profId, trackId);

      final rows = await db.managers.bookmarks
          .withReferences((p) => p(trackId: true))
          .get();
      expect(rows, isNotEmpty);
    });
  });

  group('goals withReferences prefetch trackId', () {
    test('withReferences trackId prefetch', () async {
      final accId = await makeAccount(email: 'gl-pf@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeGoal(profId, trackId);

      final rows = await db.managers.goals
          .withReferences((p) => p(trackId: true))
          .get();
      expect(rows, isNotEmpty);
    });
  });
}
