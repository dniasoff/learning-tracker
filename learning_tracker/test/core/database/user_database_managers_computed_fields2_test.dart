/// Additional coverage for annotation composer getters that were missed in
/// the first computed fields test — focuses on fields like id, profileId,
/// and other missed fields per table.
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

  Future<int> makeAccount({String email = 'cf2@test.local'}) => db
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

  // ── accounts — remaining annotation fields ────────────────────────────────

  group('accounts remaining annotation composer fields', () {
    setUp(() async {
      await makeAccount(email: 'acf2@test.local');
    });

    test('computedField id', () async {
      final field = db.managers.accounts.computedField((a) => a.id);
      expect(await db.managers.accounts.withFields([field]).get(), isNotEmpty);
    });

    test('computedField passwordHash', () async {
      final field = db.managers.accounts.computedField((a) => a.passwordHash);
      expect(await db.managers.accounts.withFields([field]).get(), isNotEmpty);
    });

    test('computedField userMode', () async {
      final field = db.managers.accounts.computedField((a) => a.userMode);
      expect(await db.managers.accounts.withFields([field]).get(), isNotEmpty);
    });
  });

  // ── learnerProfiles — remaining annotation fields ─────────────────────────

  group('learnerProfiles remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'lpcf2@test.local');
      await makeProfile(accId);
    });

    test('computedField id', () async {
      final field = db.managers.learnerProfiles.computedField((a) => a.id);
      expect(
        await db.managers.learnerProfiles.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField accountId', () async {
      final field = db.managers.learnerProfiles.computedField(
        (a) => a.accountId,
      );
      expect(
        await db.managers.learnerProfiles.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField avatarIndex', () async {
      final field = db.managers.learnerProfiles.computedField(
        (a) => a.avatarIndex,
      );
      expect(
        await db.managers.learnerProfiles.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField updatedAt', () async {
      final field = db.managers.learnerProfiles.computedField(
        (a) => a.updatedAt,
      );
      expect(
        await db.managers.learnerProfiles.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── curriculumTracks — remaining annotation fields ─────────────────────────

  group('curriculumTracks remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'ctcf2@test.local');
      final profId = await makeProfile(accId);
      await makeTrack(profId);
    });

    test('computedField id', () async {
      final field = db.managers.curriculumTracks.computedField((a) => a.id);
      expect(
        await db.managers.curriculumTracks.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField profileId', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.profileId,
      );
      expect(
        await db.managers.curriculumTracks.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField trackType', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.trackType,
      );
      expect(
        await db.managers.curriculumTracks.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField isActive', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.isActive,
      );
      expect(
        await db.managers.curriculumTracks.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField deactivatedAt', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.deactivatedAt,
      );
      expect(
        await db.managers.curriculumTracks.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField paceResetDate', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.paceResetDate,
      );
      expect(
        await db.managers.curriculumTracks.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField deletedAt', () async {
      final field = db.managers.curriculumTracks.computedField(
        (a) => a.deletedAt,
      );
      expect(
        await db.managers.curriculumTracks.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── curriculumScopes — remaining annotation fields ─────────────────────────

  group('curriculumScopes remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'cscf2@test.local');
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

    test('computedField id', () async {
      final field = db.managers.curriculumScopes.computedField((a) => a.id);
      expect(
        await db.managers.curriculumScopes.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField profileId', () async {
      final field = db.managers.curriculumScopes.computedField(
        (a) => a.profileId,
      );
      expect(
        await db.managers.curriculumScopes.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField scopeLevel', () async {
      final field = db.managers.curriculumScopes.computedField(
        (a) => a.scopeLevel,
      );
      expect(
        await db.managers.curriculumScopes.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── profilePrograms — remaining annotation fields ─────────────────────────

  group('profilePrograms remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'ppcf2@test.local');
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

    test('computedField id', () async {
      final field = db.managers.profilePrograms.computedField((a) => a.id);
      expect(
        await db.managers.profilePrograms.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField profileId', () async {
      final field = db.managers.profilePrograms.computedField(
        (a) => a.profileId,
      );
      expect(
        await db.managers.profilePrograms.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField programId', () async {
      final field = db.managers.profilePrograms.computedField(
        (a) => a.programId,
      );
      expect(
        await db.managers.profilePrograms.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField trackingStartDate', () async {
      final field = db.managers.profilePrograms.computedField(
        (a) => a.trackingStartDate,
      );
      expect(
        await db.managers.profilePrograms.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField trackingStartRef', () async {
      final field = db.managers.profilePrograms.computedField(
        (a) => a.trackingStartRef,
      );
      expect(
        await db.managers.profilePrograms.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── stageDefinitions — remaining annotation fields ─────────────────────────

  group('stageDefinitions remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'sdcf2@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeStage(profId, trackId);
    });

    test('computedField id', () async {
      final field = db.managers.stageDefinitions.computedField((a) => a.id);
      expect(
        await db.managers.stageDefinitions.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField profileId', () async {
      final field = db.managers.stageDefinitions.computedField(
        (a) => a.profileId.id,
      );
      expect(
        await db.managers.stageDefinitions.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField stageOrder', () async {
      final field = db.managers.stageDefinitions.computedField(
        (a) => a.stageOrder,
      );
      expect(
        await db.managers.stageDefinitions.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField delayDays', () async {
      final field = db.managers.stageDefinitions.computedField(
        (a) => a.delayDays,
      );
      expect(
        await db.managers.stageDefinitions.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField isDefault', () async {
      final field = db.managers.stageDefinitions.computedField(
        (a) => a.isDefault,
      );
      expect(
        await db.managers.stageDefinitions.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField scheduleType', () async {
      final field = db.managers.stageDefinitions.computedField(
        (a) => a.scheduleType,
      );
      expect(
        await db.managers.stageDefinitions.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField daysOfWeek', () async {
      final field = db.managers.stageDefinitions.computedField(
        (a) => a.daysOfWeek,
      );
      expect(
        await db.managers.stageDefinitions.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField rollingWindowSize', () async {
      final field = db.managers.stageDefinitions.computedField(
        (a) => a.rollingWindowSize,
      );
      expect(
        await db.managers.stageDefinitions.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── pointConfigs — remaining annotation fields ────────────────────────────

  group('pointConfigs remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'pccf2@test.local');
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

    test('computedField id', () async {
      final field = db.managers.pointConfigs.computedField((a) => a.id);
      expect(
        await db.managers.pointConfigs.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField profileId', () async {
      final field = db.managers.pointConfigs.computedField((a) => a.profileId);
      expect(
        await db.managers.pointConfigs.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField stageOrder', () async {
      final field = db.managers.pointConfigs.computedField((a) => a.stageOrder);
      expect(
        await db.managers.pointConfigs.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── studyDayConfigs — remaining annotation fields ─────────────────────────

  group('studyDayConfigs remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'sdccf2@test.local');
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

    test('computedField profileId', () async {
      final field = db.managers.studyDayConfigs.computedField(
        (a) => a.profileId,
      );
      expect(
        await db.managers.studyDayConfigs.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField curriculumId', () async {
      final field = db.managers.studyDayConfigs.computedField(
        (a) => a.curriculumId,
      );
      expect(
        await db.managers.studyDayConfigs.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField dayType', () async {
      final field = db.managers.studyDayConfigs.computedField((a) => a.dayType);
      expect(
        await db.managers.studyDayConfigs.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── completions — remaining annotation fields ─────────────────────────────

  group('completions remaining annotation composer fields', () {
    late int profId;
    late int trackId;
    late int stageId;

    setUp(() async {
      final accId = await makeAccount(email: 'cmcf2@test.local');
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

    test('computedField id', () async {
      final field = db.managers.completions.computedField((a) => a.id);
      expect(
        await db.managers.completions.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField profileId', () async {
      final field = db.managers.completions.computedField(
        (a) => a.profileId.id,
      );
      expect(
        await db.managers.completions.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField curriculumId', () async {
      final field = db.managers.completions.computedField(
        (a) => a.curriculumId,
      );
      expect(
        await db.managers.completions.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField stageId', () async {
      final field = db.managers.completions.computedField((a) => a.stageId);
      expect(
        await db.managers.completions.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField trackType', () async {
      final field = db.managers.completions.computedField((a) => a.trackType);
      expect(
        await db.managers.completions.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField points', () async {
      final field = db.managers.completions.computedField((a) => a.points);
      expect(
        await db.managers.completions.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── completionEvents — remaining annotation fields ────────────────────────

  group('completionEvents remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'cecf2@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      final stageId = await makeStage(profId, trackId);
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

    test('computedField id', () async {
      final field = db.managers.completionEvents.computedField((a) => a.id);
      expect(
        await db.managers.completionEvents.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField profileId', () async {
      final field = db.managers.completionEvents.computedField(
        (a) => a.profileId.id,
      );
      expect(
        await db.managers.completionEvents.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField curriculumId', () async {
      final field = db.managers.completionEvents.computedField(
        (a) => a.curriculumId,
      );
      expect(
        await db.managers.completionEvents.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField stageId', () async {
      final field = db.managers.completionEvents.computedField(
        (a) => a.stageId,
      );
      expect(
        await db.managers.completionEvents.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField trackType', () async {
      final field = db.managers.completionEvents.computedField(
        (a) => a.trackType,
      );
      expect(
        await db.managers.completionEvents.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField createdAt', () async {
      final field = db.managers.completionEvents.computedField(
        (a) => a.createdAt,
      );
      expect(
        await db.managers.completionEvents.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── dailyPlans — remaining annotation fields ──────────────────────────────

  group('dailyPlans remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'dpcf2@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      final stageId = await makeStage(profId, trackId);
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

    test('computedField id', () async {
      final field = db.managers.dailyPlans.computedField((a) => a.id);
      expect(
        await db.managers.dailyPlans.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField profileId', () async {
      final field = db.managers.dailyPlans.computedField((a) => a.profileId);
      expect(
        await db.managers.dailyPlans.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField curriculumId', () async {
      final field = db.managers.dailyPlans.computedField((a) => a.curriculumId);
      expect(
        await db.managers.dailyPlans.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField stageOrder', () async {
      final field = db.managers.dailyPlans.computedField((a) => a.stageOrder);
      expect(
        await db.managers.dailyPlans.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField stageDefinitionId', () async {
      final field = db.managers.dailyPlans.computedField(
        (a) => a.stageDefinitionId,
      );
      expect(
        await db.managers.dailyPlans.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField trackId', () async {
      final field = db.managers.dailyPlans.computedField((a) => a.trackId);
      expect(
        await db.managers.dailyPlans.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField trackLabel', () async {
      final field = db.managers.dailyPlans.computedField((a) => a.trackLabel);
      expect(
        await db.managers.dailyPlans.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField isOverdue', () async {
      final field = db.managers.dailyPlans.computedField((a) => a.isOverdue);
      expect(
        await db.managers.dailyPlans.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField reason', () async {
      final field = db.managers.dailyPlans.computedField((a) => a.reason);
      expect(
        await db.managers.dailyPlans.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField stageName', () async {
      final field = db.managers.dailyPlans.computedField((a) => a.stageName);
      expect(
        await db.managers.dailyPlans.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField estimatedEffortMinutes', () async {
      final field = db.managers.dailyPlans.computedField(
        (a) => a.estimatedEffortMinutes,
      );
      expect(
        await db.managers.dailyPlans.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField sortOrder', () async {
      final field = db.managers.dailyPlans.computedField((a) => a.sortOrder);
      expect(
        await db.managers.dailyPlans.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField createdAt', () async {
      final field = db.managers.dailyPlans.computedField((a) => a.createdAt);
      expect(
        await db.managers.dailyPlans.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── learningLedger — remaining annotation fields ──────────────────────────

  group('learningLedger remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'llcf2@test.local');
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

    test('computedField id', () async {
      final field = db.managers.learningLedger.computedField((a) => a.id);
      expect(
        await db.managers.learningLedger.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField profileId', () async {
      final field = db.managers.learningLedger.computedField(
        (a) => a.profileId.id,
      );
      expect(
        await db.managers.learningLedger.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField ulid', () async {
      final field = db.managers.learningLedger.computedField((a) => a.ulid);
      expect(
        await db.managers.learningLedger.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField unitIdentifier', () async {
      final field = db.managers.learningLedger.computedField(
        (a) => a.unitIdentifier,
      );
      expect(
        await db.managers.learningLedger.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField unitDisplayNameEn', () async {
      final field = db.managers.learningLedger.computedField(
        (a) => a.unitDisplayNameEn,
      );
      expect(
        await db.managers.learningLedger.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField trackType', () async {
      final field = db.managers.learningLedger.computedField(
        (a) => a.trackType,
      );
      expect(
        await db.managers.learningLedger.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField completedAt', () async {
      final field = db.managers.learningLedger.computedField(
        (a) => a.completedAt,
      );
      expect(
        await db.managers.learningLedger.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField completionNumber', () async {
      final field = db.managers.learningLedger.computedField(
        (a) => a.completionNumber,
      );
      expect(
        await db.managers.learningLedger.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField markedBy', () async {
      final field = db.managers.learningLedger.computedField((a) => a.markedBy);
      expect(
        await db.managers.learningLedger.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField isManual', () async {
      final field = db.managers.learningLedger.computedField((a) => a.isManual);
      expect(
        await db.managers.learningLedger.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField createdAt', () async {
      final field = db.managers.learningLedger.computedField(
        (a) => a.createdAt,
      );
      expect(
        await db.managers.learningLedger.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── learningOrder — remaining annotation fields ───────────────────────────

  group('learningOrder remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'locf2@test.local');
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

    test('computedField id', () async {
      final field = db.managers.learningOrder.computedField((a) => a.id);
      expect(
        await db.managers.learningOrder.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField profileId', () async {
      final field = db.managers.learningOrder.computedField((a) => a.profileId);
      expect(
        await db.managers.learningOrder.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField curriculumId', () async {
      final field = db.managers.learningOrder.computedField(
        (a) => a.curriculumId,
      );
      expect(
        await db.managers.learningOrder.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField updatedAt', () async {
      final field = db.managers.learningOrder.computedField((a) => a.updatedAt);
      expect(
        await db.managers.learningOrder.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── trackLearningOrder — remaining annotation fields ──────────────────────

  group('trackLearningOrder remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'tlocf2@test.local');
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

    test('computedField id', () async {
      final field = db.managers.trackLearningOrder.computedField((a) => a.id);
      expect(
        await db.managers.trackLearningOrder.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField trackId', () async {
      final field = db.managers.trackLearningOrder.computedField(
        (a) => a.trackId,
      );
      expect(
        await db.managers.trackLearningOrder.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── goals — remaining annotation fields ───────────────────────────────────

  group('goals remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'glcf2@test.local');
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

    test('computedField id', () async {
      final field = db.managers.goals.computedField((a) => a.id);
      expect(await db.managers.goals.withFields([field]).get(), isNotEmpty);
    });

    test('computedField profileId', () async {
      final field = db.managers.goals.computedField((a) => a.profileId.id);
      expect(await db.managers.goals.withFields([field]).get(), isNotEmpty);
    });

    test('computedField targetPercent', () async {
      final field = db.managers.goals.computedField((a) => a.targetPercent);
      expect(await db.managers.goals.withFields([field]).get(), isNotEmpty);
    });

    test('computedField targetDate', () async {
      final field = db.managers.goals.computedField((a) => a.targetDate);
      expect(await db.managers.goals.withFields([field]).get(), isNotEmpty);
    });

    test('computedField description', () async {
      final field = db.managers.goals.computedField((a) => a.description);
      expect(await db.managers.goals.withFields([field]).get(), isNotEmpty);
    });

    test('computedField dateType', () async {
      final field = db.managers.goals.computedField((a) => a.dateType);
      expect(await db.managers.goals.withFields([field]).get(), isNotEmpty);
    });

    test('computedField goalType', () async {
      final field = db.managers.goals.computedField((a) => a.goalType);
      expect(await db.managers.goals.withFields([field]).get(), isNotEmpty);
    });

    test('computedField paceValue', () async {
      final field = db.managers.goals.computedField((a) => a.paceValue);
      expect(await db.managers.goals.withFields([field]).get(), isNotEmpty);
    });

    test('computedField pacePeriod', () async {
      final field = db.managers.goals.computedField((a) => a.pacePeriod);
      expect(await db.managers.goals.withFields([field]).get(), isNotEmpty);
    });

    test('computedField paceGranularity', () async {
      final field = db.managers.goals.computedField((a) => a.paceGranularity);
      expect(await db.managers.goals.withFields([field]).get(), isNotEmpty);
    });

    test('computedField updatedAt', () async {
      final field = db.managers.goals.computedField((a) => a.updatedAt);
      expect(await db.managers.goals.withFields([field]).get(), isNotEmpty);
    });
  });

  // ── streaks — remaining annotation fields ──────────────────────────────────

  group('streaks remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'skcf2@test.local');
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

    test('computedField id', () async {
      final field = db.managers.streaks.computedField((a) => a.id);
      expect(await db.managers.streaks.withFields([field]).get(), isNotEmpty);
    });

    test('computedField profileId', () async {
      final field = db.managers.streaks.computedField((a) => a.profileId);
      expect(await db.managers.streaks.withFields([field]).get(), isNotEmpty);
    });

    test('computedField lastCompletionDate', () async {
      final field = db.managers.streaks.computedField(
        (a) => a.lastCompletionDate,
      );
      expect(await db.managers.streaks.withFields([field]).get(), isNotEmpty);
    });

    test('computedField graceUsedDate', () async {
      final field = db.managers.streaks.computedField((a) => a.graceUsedDate);
      expect(await db.managers.streaks.withFields([field]).get(), isNotEmpty);
    });
  });

  // ── streakEvents — remaining annotation fields ────────────────────────────

  group('streakEvents remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'secf2@test.local');
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

    test('computedField id', () async {
      final field = db.managers.streakEvents.computedField((a) => a.id);
      expect(
        await db.managers.streakEvents.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField profileId', () async {
      final field = db.managers.streakEvents.computedField(
        (a) => a.profileId.id,
      );
      expect(
        await db.managers.streakEvents.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField eventType', () async {
      final field = db.managers.streakEvents.computedField((a) => a.eventType);
      expect(
        await db.managers.streakEvents.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField dayUtc', () async {
      final field = db.managers.streakEvents.computedField((a) => a.dayUtc);
      expect(
        await db.managers.streakEvents.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField createdAt', () async {
      final field = db.managers.streakEvents.computedField((a) => a.createdAt);
      expect(
        await db.managers.streakEvents.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── syncQueue — remaining annotation fields ───────────────────────────────

  group('syncQueue remaining annotation composer fields', () {
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

    test('computedField id', () async {
      final field = db.managers.syncQueue.computedField((a) => a.id);
      expect(await db.managers.syncQueue.withFields([field]).get(), isNotEmpty);
    });

    test('computedField payload', () async {
      final field = db.managers.syncQueue.computedField((a) => a.payload);
      expect(await db.managers.syncQueue.withFields([field]).get(), isNotEmpty);
    });

    test('computedField queuedAt', () async {
      final field = db.managers.syncQueue.computedField((a) => a.queuedAt);
      expect(await db.managers.syncQueue.withFields([field]).get(), isNotEmpty);
    });

    test('computedField lastError', () async {
      final field = db.managers.syncQueue.computedField((a) => a.lastError);
      expect(await db.managers.syncQueue.withFields([field]).get(), isNotEmpty);
    });
  });

  // ── textDownloadStatuses — remaining annotation fields ────────────────────

  group('textDownloadStatuses remaining annotation composer fields', () {
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

    test('computedField itemCount', () async {
      final field = db.managers.textDownloadStatuses.computedField(
        (a) => a.itemCount,
      );
      expect(
        await db.managers.textDownloadStatuses.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });

  // ── outbox — remaining annotation fields ──────────────────────────────────

  group('outbox remaining annotation composer fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'obcf2@test.local');
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

    test('computedField id', () async {
      final field = db.managers.outbox.computedField((a) => a.id);
      expect(await db.managers.outbox.withFields([field]).get(), isNotEmpty);
    });

    test('computedField profileId', () async {
      final field = db.managers.outbox.computedField((a) => a.profileId);
      expect(await db.managers.outbox.withFields([field]).get(), isNotEmpty);
    });

    test('computedField lastError', () async {
      final field = db.managers.outbox.computedField((a) => a.lastError);
      expect(await db.managers.outbox.withFields([field]).get(), isNotEmpty);
    });
  });

  // ── sacredWindowEntries — remaining annotation fields ────────────────────

  group('sacredWindowEntries remaining annotation composer fields', () {
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

    test('computedField id', () async {
      final field = db.managers.sacredWindowEntries.computedField((a) => a.id);
      expect(
        await db.managers.sacredWindowEntries.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField lat', () async {
      final field = db.managers.sacredWindowEntries.computedField((a) => a.lat);
      expect(
        await db.managers.sacredWindowEntries.withFields([field]).get(),
        isNotEmpty,
      );
    });

    test('computedField lng', () async {
      final field = db.managers.sacredWindowEntries.computedField((a) => a.lng);
      expect(
        await db.managers.sacredWindowEntries.withFields([field]).get(),
        isNotEmpty,
      );
    });
  });
}
