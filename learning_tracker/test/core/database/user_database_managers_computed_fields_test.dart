/// Coverage for annotation composer ($$XxxAnnotationComposer) getters
/// in user_database.g.dart.
///
/// Each test calls db.managers.x.computedField((a) => a.fieldName) which
/// triggers the createComputedFieldComposer factory and then accesses each
/// getter on the annotation composer, covering the GeneratedColumn getter
/// accessors.
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

  // ── shared helpers ─────────────────────────────────────────────────────────

  Future<int> makeAccount({String email = 'cf@test.local'}) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: email,
          tier: 'cloudBorn',
          displayName: 'User',
          userMode: 'adult',
          createdAt: now,
          updatedAt: now,
          firebaseUid: const Value('fb-uid'),
        ),
      );

  Future<int> makeProfile(int accountId) => db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Learner',
          mode: 'adult',
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> makeTrack(int profileId) => db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: 'bavli',
          trackType: 'personal',
          activatedAt: now,
        ),
      );

  Future<int> makeStage(int profileId, int trackId) => db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: profileId,
          trackId: trackId,
          curriculumId: 'bavli',
          stageName: 'limud',
          stageOrder: 1,
          delayDays: 0,
        ),
      );

  // ── accounts annotation composer ───────────────────────────────────────────

  group('accounts annotation composer fields', () {
    setUp(() async {
      await makeAccount(email: 'acf@test.local');
    });

    test('computedField email', () async {
      final field = db.managers.accounts.computedField((a) => a.email);
      final rows = await db.managers.accounts.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField firebaseUid', () async {
      final field = db.managers.accounts.computedField((a) => a.firebaseUid);
      final rows = await db.managers.accounts.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField tier', () async {
      final field = db.managers.accounts.computedField((a) => a.tier);
      final rows = await db.managers.accounts.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField displayName', () async {
      final field = db.managers.accounts.computedField((a) => a.displayName);
      final rows = await db.managers.accounts.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField createdAt', () async {
      final field = db.managers.accounts.computedField((a) => a.createdAt);
      final rows = await db.managers.accounts.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField updatedAt', () async {
      final field = db.managers.accounts.computedField((a) => a.updatedAt);
      final rows = await db.managers.accounts.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── learnerProfiles annotation composer ────────────────────────────────────

  group('learnerProfiles annotation composer fields', () {
    late int accId;

    setUp(() async {
      accId = await makeAccount(email: 'lpcf@test.local');
      await makeProfile(accId);
    });

    test('computedField displayName', () async {
      final field = db.managers.learnerProfiles.computedField(
        (a) => a.displayName,
      );
      final rows = await db.managers.learnerProfiles.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField mode', () async {
      final field = db.managers.learnerProfiles.computedField((a) => a.mode);
      final rows = await db.managers.learnerProfiles.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField createdAt', () async {
      final field = db.managers.learnerProfiles.computedField(
        (a) => a.createdAt,
      );
      final rows = await db.managers.learnerProfiles.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── curriculumTracks annotation composer ───────────────────────────────────

  group('curriculumTracks annotation composer fields', () {
    late int accId;
    late int profId;

    setUp(() async {
      accId = await makeAccount(email: 'ctcf@test.local');
      profId = await makeProfile(accId);
      await makeTrack(profId);
    });

    test('computedField curriculumId', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.curriculumId,
      );
      final rows = await db.managers.curriculumTracks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField activatedAt', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.activatedAt,
      );
      final rows = await db.managers.curriculumTracks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── curriculumScopes annotation composer ───────────────────────────────────

  group('curriculumScopes annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'cscf@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
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
    });

    test('computedField curriculumId', () async {
      final field = db.managers.curriculumScopes.computedField(
        (a) => a.curriculumId,
      );
      final rows = await db.managers.curriculumScopes.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField scopeValue', () async {
      final field = db.managers.curriculumScopes.computedField(
        (a) => a.scopeValue,
      );
      final rows = await db.managers.curriculumScopes.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField createdAt', () async {
      final field = db.managers.curriculumScopes.computedField(
        (a) => a.createdAt,
      );
      final rows = await db.managers.curriculumScopes.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── profilePrograms annotation composer ───────────────────────────────────

  group('profilePrograms annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'ppcf@test.local');
      final profId = await makeProfile(accId);
      await db
          .into(db.profilePrograms)
          .insert(
            ProfileProgramsCompanion.insert(
              profileId: profId,
              curriculumType: 'daf',
              programId: 1,
            ),
          );
    });

    test('computedField curriculumType', () async {
      final field = db.managers.profilePrograms.computedField(
        (a) => a.curriculumType,
      );
      final rows = await db.managers.profilePrograms.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── stageDefinitions annotation composer ──────────────────────────────────

  group('stageDefinitions annotation composer fields', () {
    late int accId;
    late int profId;
    late int trackId;

    setUp(() async {
      accId = await makeAccount(email: 'sdcf@test.local');
      profId = await makeProfile(accId);
      trackId = await makeTrack(profId);
      await makeStage(profId, trackId);
    });

    test('computedField curriculumId', () async {
      final field = db.managers.stageDefinitions.computedField(
        (a) => a.curriculumId,
      );
      final rows = await db.managers.stageDefinitions.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField stageName', () async {
      final field = db.managers.stageDefinitions.computedField(
        (a) => a.stageName,
      );
      final rows = await db.managers.stageDefinitions.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── pointConfigs annotation composer ──────────────────────────────────────

  group('pointConfigs annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'pccf@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeStage(profId, trackId);
      await db
          .into(db.pointConfigs)
          .insert(
            PointConfigsCompanion.insert(
              profileId: profId,
              curriculumId: 'bavli',
              trackId: trackId,
              stageOrder: 1,
              points: 10,
            ),
          );
    });

    test('computedField curriculumId', () async {
      final field = db.managers.pointConfigs.computedField(
        (a) => a.curriculumId,
      );
      final rows = await db.managers.pointConfigs.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField points', () async {
      final field = db.managers.pointConfigs.computedField((a) => a.points);
      final rows = await db.managers.pointConfigs.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── studyDayConfigs annotation composer ───────────────────────────────────

  group('studyDayConfigs annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'sdccf@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await db
          .into(db.studyDayConfigs)
          .insert(
            StudyDayConfigsCompanion.insert(
              profileId: profId,
              curriculumId: 'bavli',
              trackId: trackId,
              dayOfWeek: 0,
              updatedAt: now,
            ),
          );
    });

    test('computedField dayOfWeek', () async {
      final field = db.managers.studyDayConfigs.computedField(
        (a) => a.dayOfWeek,
      );
      final rows = await db.managers.studyDayConfigs.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField updatedAt', () async {
      final field = db.managers.studyDayConfigs.computedField(
        (a) => a.updatedAt,
      );
      final rows = await db.managers.studyDayConfigs.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── completions annotation composer ───────────────────────────────────────

  group('completions annotation composer fields', () {
    late int accId;
    late int profId;
    late int trackId;
    late int stageId;

    setUp(() async {
      accId = await makeAccount(email: 'cmcf@test.local');
      profId = await makeProfile(accId);
      trackId = await makeTrack(profId);
      stageId = await makeStage(profId, trackId);
      await db
          .into(db.completions)
          .insert(
            CompletionsCompanion.insert(
              profileId: profId,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot 2a',
              stageId: stageId,
              trackType: 'personal',
              trackId: trackId,
              completedAt: now,
            ),
          );
    });

    test('computedField sefariaRef', () async {
      final field = db.managers.completions.computedField((a) => a.sefariaRef);
      final rows = await db.managers.completions.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField completedAt', () async {
      final field = db.managers.completions.computedField((a) => a.completedAt);
      final rows = await db.managers.completions.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── completionEvents annotation composer ──────────────────────────────────

  group('completionEvents annotation composer fields', () {
    late int accId;
    late int profId;
    late int trackId;
    late int stageId;

    setUp(() async {
      accId = await makeAccount(email: 'cecf@test.local');
      profId = await makeProfile(accId);
      trackId = await makeTrack(profId);
      stageId = await makeStage(profId, trackId);
      await db
          .into(db.completionEvents)
          .insert(
            CompletionEventsCompanion.insert(
              profileId: profId,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot 2a',
              stageId: stageId,
              trackType: 'personal',
              eventTimestamp: now,
            ),
          );
    });

    test('computedField sefariaRef', () async {
      final field = db.managers.completionEvents.computedField(
        (a) => a.sefariaRef,
      );
      final rows = await db.managers.completionEvents.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField eventTimestamp', () async {
      final field = db.managers.completionEvents.computedField(
        (a) => a.eventTimestamp,
      );
      final rows = await db.managers.completionEvents.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── dailyPlans annotation composer ────────────────────────────────────────

  group('dailyPlans annotation composer fields', () {
    late int accId;
    late int profId;
    late int trackId;
    late int stageId;

    setUp(() async {
      accId = await makeAccount(email: 'dpcf@test.local');
      profId = await makeProfile(accId);
      trackId = await makeTrack(profId);
      stageId = await makeStage(profId, trackId);
      await db
          .into(db.dailyPlans)
          .insert(
            DailyPlansCompanion.insert(
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

    test('computedField sefariaRef', () async {
      final field = db.managers.dailyPlans.computedField((a) => a.sefariaRef);
      final rows = await db.managers.dailyPlans.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField planDate', () async {
      final field = db.managers.dailyPlans.computedField((a) => a.planDate);
      final rows = await db.managers.dailyPlans.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField priority', () async {
      final field = db.managers.dailyPlans.computedField((a) => a.priority);
      final rows = await db.managers.dailyPlans.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── learningLedger annotation composer ────────────────────────────────────

  group('learningLedger annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'llcf@test.local');
      final profId = await makeProfile(accId);
      await db
          .into(db.learningLedger)
          .insert(
            LearningLedgerCompanion.insert(
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

    test('computedField curriculumId', () async {
      final field = db.managers.learningLedger.computedField(
        (a) => a.curriculumId,
      );
      final rows = await db.managers.learningLedger.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField entryScope', () async {
      final field = db.managers.learningLedger.computedField(
        (a) => a.entryScope,
      );
      final rows = await db.managers.learningLedger.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField unitDisplayNameHe', () async {
      final field = db.managers.learningLedger.computedField(
        (a) => a.unitDisplayNameHe,
      );
      final rows = await db.managers.learningLedger.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── bookmarks annotation composer ─────────────────────────────────────────

  group('bookmarks annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'bmcf@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              profileId: profId,
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot 2a',
              updatedAt: now,
            ),
          );
    });

    test('computedField sefariaRef', () async {
      final field = db.managers.bookmarks.computedField((a) => a.sefariaRef);
      final rows = await db.managers.bookmarks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField updatedAt', () async {
      final field = db.managers.bookmarks.computedField((a) => a.updatedAt);
      final rows = await db.managers.bookmarks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── learningOrder annotation composer ─────────────────────────────────────

  group('learningOrder annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'locf@test.local');
      final profId = await makeProfile(accId);
      await db
          .into(db.learningOrder)
          .insert(
            LearningOrderCompanion.insert(
              profileId: profId,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot 2a',
              userSortOrder: 1,
            ),
          );
    });

    test('computedField curriculumId', () async {
      final field = db.managers.learningOrder.computedField(
        (a) => a.curriculumId,
      );
      final rows = await db.managers.learningOrder.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField sefariaRef', () async {
      final field = db.managers.learningOrder.computedField(
        (a) => a.sefariaRef,
      );
      final rows = await db.managers.learningOrder.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField userSortOrder', () async {
      final field = db.managers.learningOrder.computedField(
        (a) => a.userSortOrder,
      );
      final rows = await db.managers.learningOrder.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── trackLearningOrder annotation composer ────────────────────────────────

  group('trackLearningOrder annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'tlocf@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await db
          .into(db.trackLearningOrder)
          .insert(
            TrackLearningOrderCompanion.insert(
              trackId: trackId,
              sefariaRef: 'Berakhot 2a',
              sortOrder: 1,
            ),
          );
    });

    test('computedField sefariaRef', () async {
      final field = db.managers.trackLearningOrder.computedField(
        (a) => a.sefariaRef,
      );
      final rows = await db.managers.trackLearningOrder.withFields([
        field,
      ]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField sortOrder', () async {
      final field = db.managers.trackLearningOrder.computedField(
        (a) => a.sortOrder,
      );
      final rows = await db.managers.trackLearningOrder.withFields([
        field,
      ]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── goals annotation composer ──────────────────────────────────────────────

  group('goals annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'glcf@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: profId,
              curriculumId: 'bavli',
              trackId: trackId,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    test('computedField curriculumId', () async {
      final field = db.managers.goals.computedField((a) => a.curriculumId);
      final rows = await db.managers.goals.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField createdAt', () async {
      final field = db.managers.goals.computedField((a) => a.createdAt);
      final rows = await db.managers.goals.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── streaks annotation composer ────────────────────────────────────────────

  group('streaks annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'skcf@test.local');
      final profId = await makeProfile(accId);
      await db
          .into(db.streaks)
          .insert(
            StreaksCompanion.insert(
              profileId: profId,
              currentStreak: const Value(3),
              maxStreak: const Value(5),
              gracePeriodDays: const Value(1),
            ),
          );
    });

    test('computedField currentStreak', () async {
      final field = db.managers.streaks.computedField((a) => a.currentStreak);
      final rows = await db.managers.streaks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField maxStreak', () async {
      final field = db.managers.streaks.computedField((a) => a.maxStreak);
      final rows = await db.managers.streaks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField gracePeriodDays', () async {
      final field = db.managers.streaks.computedField((a) => a.gracePeriodDays);
      final rows = await db.managers.streaks.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── streakEvents annotation composer ──────────────────────────────────────

  group('streakEvents annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'secf@test.local');
      final profId = await makeProfile(accId);
      await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profId,
              eventType: 'completion',
              dayUtc: DateTime.utc(2026, 3, 1),
              eventTimestamp: now,
              clientDeviceId: const Value('dev-1'),
            ),
          );
    });

    test('computedField eventTimestamp', () async {
      final field = db.managers.streakEvents.computedField(
        (a) => a.eventTimestamp,
      );
      final rows = await db.managers.streakEvents.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField clientDeviceId', () async {
      final field = db.managers.streakEvents.computedField(
        (a) => a.clientDeviceId,
      );
      final rows = await db.managers.streakEvents.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── syncQueue annotation composer ─────────────────────────────────────────

  group('syncQueue annotation composer fields', () {
    setUp(() async {
      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              operationType: 'upsert',
              payload: '{}',
              queuedAt: now,
            ),
          );
    });

    test('computedField operationType', () async {
      final field = db.managers.syncQueue.computedField((a) => a.operationType);
      final rows = await db.managers.syncQueue.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField retryCount', () async {
      final field = db.managers.syncQueue.computedField((a) => a.retryCount);
      final rows = await db.managers.syncQueue.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── textDownloadStatuses annotation composer ──────────────────────────────

  group('textDownloadStatuses annotation composer fields', () {
    setUp(() async {
      await db
          .into(db.textDownloadStatuses)
          .insert(
            TextDownloadStatusesCompanion.insert(
              curriculumId: 'bavli',
              itemCount: 50,
              textVersion: 'v1',
              downloadedAt: now,
            ),
          );
    });

    test('computedField curriculumId', () async {
      final field = db.managers.textDownloadStatuses.computedField(
        (a) => a.curriculumId,
      );
      final rows = await db.managers.textDownloadStatuses.withFields([
        field,
      ]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField textVersion', () async {
      final field = db.managers.textDownloadStatuses.computedField(
        (a) => a.textVersion,
      );
      final rows = await db.managers.textDownloadStatuses.withFields([
        field,
      ]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField downloadedAt', () async {
      final field = db.managers.textDownloadStatuses.computedField(
        (a) => a.downloadedAt,
      );
      final rows = await db.managers.textDownloadStatuses.withFields([
        field,
      ]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField storedItemCount', () async {
      final field = db.managers.textDownloadStatuses.computedField(
        (a) => a.storedItemCount,
      );
      final rows = await db.managers.textDownloadStatuses.withFields([
        field,
      ]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── outbox annotation composer ────────────────────────────────────────────

  group('outbox annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'obcf@test.local');
      final profId = await makeProfile(accId);
      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              profileId: profId,
              entityKind: 'completion',
              entityKey: 'key-1',
              payload: '{}',
              createdAt: now,
            ),
          );
    });

    test('computedField entityKind', () async {
      final field = db.managers.outbox.computedField((a) => a.entityKind);
      final rows = await db.managers.outbox.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField entityKey', () async {
      final field = db.managers.outbox.computedField((a) => a.entityKey);
      final rows = await db.managers.outbox.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField payload', () async {
      final field = db.managers.outbox.computedField((a) => a.payload);
      final rows = await db.managers.outbox.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField createdAt', () async {
      final field = db.managers.outbox.computedField((a) => a.createdAt);
      final rows = await db.managers.outbox.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField attempts', () async {
      final field = db.managers.outbox.computedField((a) => a.attempts);
      final rows = await db.managers.outbox.withFields([field]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField lastAttemptAt', () async {
      final field = db.managers.outbox.computedField((a) => a.lastAttemptAt);
      final rows = await db.managers.outbox.withFields([field]).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── sacredWindowEntries annotation composer ───────────────────────────────

  group('sacredWindowEntries annotation composer fields', () {
    setUp(() async {
      await db
          .into(db.sacredWindowEntries)
          .insert(
            SacredWindowEntriesCompanion.insert(
              startUtc: now,
              endUtc: now.add(const Duration(hours: 25)),
              kind: 'shabbos',
              inIsrael: true,
              createdAt: Value(now),
            ),
          );
    });

    test('computedField startUtc', () async {
      final field = db.managers.sacredWindowEntries.computedField(
        (a) => a.startUtc,
      );
      final rows = await db.managers.sacredWindowEntries.withFields([
        field,
      ]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField endUtc', () async {
      final field = db.managers.sacredWindowEntries.computedField(
        (a) => a.endUtc,
      );
      final rows = await db.managers.sacredWindowEntries.withFields([
        field,
      ]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField kind', () async {
      final field = db.managers.sacredWindowEntries.computedField(
        (a) => a.kind,
      );
      final rows = await db.managers.sacredWindowEntries.withFields([
        field,
      ]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField inIsrael', () async {
      final field = db.managers.sacredWindowEntries.computedField(
        (a) => a.inIsrael,
      );
      final rows = await db.managers.sacredWindowEntries.withFields([
        field,
      ]).get();
      expect(rows, isNotEmpty);
    });

    test('computedField createdAt', () async {
      final field = db.managers.sacredWindowEntries.computedField(
        (a) => a.createdAt,
      );
      final rows = await db.managers.sacredWindowEntries.withFields([
        field,
      ]).get();
      expect(rows, isNotEmpty);
    });
  });
}
