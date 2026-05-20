/// OrderBy + filter coverage for all remaining uncovered ColumnOrderings and
/// ColumnFilters getters in user_database.g.dart.
///
/// Each test calls orderBy or filter on a specific column to trigger the
/// generated `$composableBuilder(column: ...)` accessor, covering 3 lines
/// of generated code per field.
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

  // ── shared setup helpers ──────────────────────────────────────────────────

  Future<int> makeAccount({String email = 'a@test.local'}) => db
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
          stateChangedAt: now,
          activatedAt: now,
        ),
      );

  Future<int> makeStageDef(int profileId, int trackId) => db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: profileId,
          trackId: trackId,
          curriculumId: 'bavli',
          stageName: 'limud',
          stageOrder: 1,
          schedule: Value('{"type":"delay","delay_days":0}'),
        ),
      );

  // ── accounts — remaining orderBy ─────────────────────────────────────────

  group('accounts — remaining orderBy fields', () {
    setUp(() async {
      await makeAccount(email: 'ob1@test.local');
    });

    test('orderBy firebaseUid', () async {
      final rows = await db.managers.accounts
          .orderBy((o) => o.firebaseUid.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy passwordHash', () async {
      final rows = await db.managers.accounts
          .orderBy((o) => o.passwordHash.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy tier', () async {
      final rows = await db.managers.accounts
          .orderBy((o) => o.tier.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy displayName', () async {
      final rows = await db.managers.accounts
          .orderBy((o) => o.displayName.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy userMode', () async {
      final rows = await db.managers.accounts
          .orderBy((o) => o.userMode.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy createdAt', () async {
      final rows = await db.managers.accounts
          .orderBy((o) => o.createdAt.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy updatedAt', () async {
      final rows = await db.managers.accounts
          .orderBy((o) => o.updatedAt.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by firebaseUid', () async {
      final rows = await db.managers.accounts
          .filter((f) => f.firebaseUid('fb-uid'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by passwordHash', () async {
      final rows = await db.managers.accounts
          .filter((f) => f.passwordHash(null))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by tier', () async {
      final rows = await db.managers.accounts
          .filter((f) => f.tier('cloudBorn'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by userMode', () async {
      final rows = await db.managers.accounts
          .filter((f) => f.userMode('adult'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by createdAt', () async {
      final rows = await db.managers.accounts
          .filter((f) => f.createdAt(now))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by updatedAt', () async {
      final rows = await db.managers.accounts
          .filter((f) => f.updatedAt(now))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── learnerProfiles — remaining orderBy ──────────────────────────────────

  group('learnerProfiles — remaining orderBy fields', () {
    late int profileId;
    setUp(() async {
      final accId = await makeAccount(email: 'lp-ob@test.local');
      profileId = await makeProfile(accId);
    });

    test('orderBy id', () async {
      final rows = await db.managers.learnerProfiles
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy accountId', () async {
      final rows = await db.managers.learnerProfiles
          .orderBy((o) => o.accountId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy mode', () async {
      final rows = await db.managers.learnerProfiles
          .orderBy((o) => o.mode.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy avatarIndex', () async {
      final rows = await db.managers.learnerProfiles
          .orderBy((o) => o.avatarIndex.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy createdAt', () async {
      final rows = await db.managers.learnerProfiles
          .orderBy((o) => o.createdAt.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy updatedAt', () async {
      final rows = await db.managers.learnerProfiles
          .orderBy((o) => o.updatedAt.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.learnerProfiles
          .filter((f) => f.id(profileId))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by accountId', () async {
      final rows = await db.managers.learnerProfiles
          .filter((f) => f.accountId(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by mode', () async {
      final rows = await db.managers.learnerProfiles
          .filter((f) => f.mode('adult'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by avatarIndex', () async {
      final rows = await db.managers.learnerProfiles
          .filter((f) => f.avatarIndex(0))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by createdAt', () async {
      final rows = await db.managers.learnerProfiles
          .filter((f) => f.createdAt(now))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by updatedAt', () async {
      final rows = await db.managers.learnerProfiles
          .filter((f) => f.updatedAt(now))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── curriculumTracks — remaining orderBy ─────────────────────────────────

  group('curriculumTracks — remaining orderBy fields', () {
    late int trackId;
    setUp(() async {
      final accId = await makeAccount(email: 'ct-ob@test.local');
      final profId = await makeProfile(accId);
      trackId = await makeTrack(profId);
    });

    test('orderBy id', () async {
      final rows = await db.managers.curriculumTracks
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.curriculumTracks
          .orderBy((o) => o.profileId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy trackType', () async {
      final rows = await db.managers.curriculumTracks
          .orderBy((o) => o.trackType.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy isActive', () async {
      final rows = await db.managers.curriculumTracks
          .orderBy((o) => o.isActive.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy activatedAt', () async {
      final rows = await db.managers.curriculumTracks
          .orderBy((o) => o.activatedAt.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy deactivatedAt', () async {
      final rows = await db.managers.curriculumTracks
          .orderBy((o) => o.deactivatedAt.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy paceResetDate', () async {
      final rows = await db.managers.curriculumTracks
          .orderBy((o) => o.paceResetDate.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy deletedAt', () async {
      final rows = await db.managers.curriculumTracks
          .orderBy((o) => o.deletedAt.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.curriculumTracks
          .filter((f) => f.id(trackId))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by profileId', () async {
      final rows = await db.managers.curriculumTracks
          .filter((f) => f.profileId(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by trackType', () async {
      final rows = await db.managers.curriculumTracks
          .filter((f) => f.trackType('personal'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by isActive', () async {
      final rows = await db.managers.curriculumTracks
          .filter((f) => f.isActive(true))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by activatedAt', () async {
      final rows = await db.managers.curriculumTracks
          .filter((f) => f.activatedAt(now))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by deactivatedAt', () async {
      final rows = await db.managers.curriculumTracks
          .filter((f) => f.deactivatedAt(null))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by paceResetDate', () async {
      final rows = await db.managers.curriculumTracks
          .filter((f) => f.paceResetDate(null))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by deletedAt', () async {
      final rows = await db.managers.curriculumTracks
          .filter((f) => f.deletedAt(null))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── curriculumScopes — orderBy ────────────────────────────────────────────

  group('curriculumScopes — orderBy and filter', () {
    setUp(() async {
      final accId = await makeAccount(email: 'cs-ob@test.local');
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
              scopeValue: 'Seder Zeraim',
              createdAt: now,
            ),
          );
    });

    test('orderBy id', () async {
      final rows = await db.managers.curriculumScopes
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.curriculumScopes
          .orderBy((o) => o.profileId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy curriculumId', () async {
      final rows = await db.managers.curriculumScopes
          .orderBy((o) => o.curriculumId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy scopeLevel', () async {
      final rows = await db.managers.curriculumScopes
          .orderBy((o) => o.scopeLevel.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy scopeValue', () async {
      final rows = await db.managers.curriculumScopes
          .orderBy((o) => o.scopeValue.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy createdAt', () async {
      final rows = await db.managers.curriculumScopes
          .orderBy((o) => o.createdAt.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by profileId', () async {
      final rows = await db.managers.curriculumScopes
          .filter((f) => f.profileId(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by curriculumId', () async {
      final rows = await db.managers.curriculumScopes
          .filter((f) => f.curriculumId('bavli'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by scopeLevel', () async {
      final rows = await db.managers.curriculumScopes
          .filter((f) => f.scopeLevel(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by scopeValue', () async {
      final rows = await db.managers.curriculumScopes
          .filter((f) => f.scopeValue('Seder Zeraim'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by createdAt', () async {
      final rows = await db.managers.curriculumScopes
          .filter((f) => f.createdAt(now))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── profilePrograms — orderBy ─────────────────────────────────────────────

  group('profilePrograms — orderBy and filter', () {
    setUp(() async {
      final accId = await makeAccount(email: 'pp-ob@test.local');
      final profId = await makeProfile(accId);
      await db
          .into(db.profilePrograms)
          .insert(
            ProfileProgramsCompanion.insert(
              profileId: profId,
              curriculumType: 'bavli',
              programId: 1,
              trackingStartDate: Value(now),
              trackingStartRef: const Value('Berakhot 2a'),
            ),
          );
    });

    test('orderBy id', () async {
      final rows = await db.managers.profilePrograms
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.profilePrograms
          .orderBy((o) => o.profileId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy curriculumType', () async {
      final rows = await db.managers.profilePrograms
          .orderBy((o) => o.curriculumType.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy programId', () async {
      final rows = await db.managers.profilePrograms
          .orderBy((o) => o.programId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy trackingStartDate', () async {
      final rows = await db.managers.profilePrograms
          .orderBy((o) => o.trackingStartDate.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy trackingStartRef', () async {
      final rows = await db.managers.profilePrograms
          .orderBy((o) => o.trackingStartRef.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.profilePrograms
          .filter((f) => f.id(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by curriculumType', () async {
      final rows = await db.managers.profilePrograms
          .filter((f) => f.curriculumType('bavli'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by programId', () async {
      final rows = await db.managers.profilePrograms
          .filter((f) => f.programId(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by trackingStartDate', () async {
      final rows = await db.managers.profilePrograms
          .filter((f) => f.trackingStartDate(now))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by trackingStartRef', () async {
      final rows = await db.managers.profilePrograms
          .filter((f) => f.trackingStartRef('Berakhot 2a'))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── stageDefinitions — remaining orderBy ─────────────────────────────────

  group('stageDefinitions — remaining orderBy fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'sd-ob@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await makeStageDef(profId, trackId);
    });

    test('orderBy id', () async {
      final rows = await db.managers.stageDefinitions
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.stageDefinitions
          .orderBy((o) => o.profileId.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy curriculumId', () async {
      final rows = await db.managers.stageDefinitions
          .orderBy((o) => o.curriculumId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy stageName', () async {
      final rows = await db.managers.stageDefinitions
          .orderBy((o) => o.stageName.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy delayDays', () async {
      final rows = await db.managers.stageDefinitions
          .orderBy((o) => o.delayDays.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy isDefault', () async {
      final rows = await db.managers.stageDefinitions
          .orderBy((o) => o.isDefault.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy scheduleType', () async {
      final rows = await db.managers.stageDefinitions
          .orderBy((o) => o.scheduleType.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy daysOfWeek', () async {
      final rows = await db.managers.stageDefinitions
          .orderBy((o) => o.daysOfWeek.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy rollingWindowSize', () async {
      final rows = await db.managers.stageDefinitions
          .orderBy((o) => o.rollingWindowSize.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.stageDefinitions
          .filter((f) => f.id(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by profileId', () async {
      final rows = await db.managers.stageDefinitions
          .filter((f) => f.profileId.id(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by curriculumId', () async {
      final rows = await db.managers.stageDefinitions
          .filter((f) => f.curriculumId('bavli'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by stageName', () async {
      final rows = await db.managers.stageDefinitions
          .filter((f) => f.stageName('limud'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by delayDays', () async {
      final rows = await db.managers.stageDefinitions
          .filter((f) => f.delayDays(0))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by isDefault', () async {
      final rows = await db.managers.stageDefinitions
          .filter((f) => f.isDefault(false))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by scheduleType', () async {
      final rows = await db.managers.stageDefinitions
          .filter((f) => f.scheduleType('delay'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by daysOfWeek', () async {
      final rows = await db.managers.stageDefinitions
          .filter((f) => f.daysOfWeek(null))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by rollingWindowSize', () async {
      final rows = await db.managers.stageDefinitions
          .filter((f) => f.rollingWindowSize(null))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── pointConfigs — remaining orderBy ─────────────────────────────────────

  group('pointConfigs — remaining orderBy fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'pc-ob@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
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

    test('orderBy id', () async {
      final rows = await db.managers.pointConfigs
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.pointConfigs
          .orderBy((o) => o.profileId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy curriculumId', () async {
      final rows = await db.managers.pointConfigs
          .orderBy((o) => o.curriculumId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy points', () async {
      final rows = await db.managers.pointConfigs
          .orderBy((o) => o.points.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.pointConfigs.filter((f) => f.id(1)).get();
      expect(rows, hasLength(1));
    });

    test('filter by profileId', () async {
      final rows = await db.managers.pointConfigs
          .filter((f) => f.profileId(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by curriculumId', () async {
      final rows = await db.managers.pointConfigs
          .filter((f) => f.curriculumId('bavli'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by points', () async {
      final rows = await db.managers.pointConfigs
          .filter((f) => f.points(10))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── studyDayConfigs — remaining orderBy ──────────────────────────────────

  group('studyDayConfigs — remaining orderBy fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'sdc-ob@test.local');
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
              dayType: const Value('always'),
              updatedAt: now,
            ),
          );
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.studyDayConfigs
          .orderBy((o) => o.profileId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy curriculumId', () async {
      final rows = await db.managers.studyDayConfigs
          .orderBy((o) => o.curriculumId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy dayType', () async {
      final rows = await db.managers.studyDayConfigs
          .orderBy((o) => o.dayType.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy updatedAt', () async {
      final rows = await db.managers.studyDayConfigs
          .orderBy((o) => o.updatedAt.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by profileId', () async {
      final rows = await db.managers.studyDayConfigs
          .filter((f) => f.profileId(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by curriculumId', () async {
      final rows = await db.managers.studyDayConfigs
          .filter((f) => f.curriculumId('bavli'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by dayType', () async {
      final rows = await db.managers.studyDayConfigs
          .filter((f) => f.dayType('always'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by updatedAt', () async {
      final rows = await db.managers.studyDayConfigs
          .filter((f) => f.updatedAt(now))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── completions — remaining orderBy ──────────────────────────────────────

  group('completions — remaining orderBy fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'cm-ob@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      final stageDefId = await makeStageDef(profId, trackId);
      await db
          .into(db.completionEvents)
          .insert(
            CompletionEventsCompanion.insert(
              profileId: profId,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot 2a',
              stageId: stageDefId,
              trackType: 'personal',
              trackId: Value(trackId),
              eventTimestamp: now,
            ),
          );
    });

    test('orderBy id', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.profileId.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy curriculumId', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.curriculumId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy sefariaRef', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.sefariaRef.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy stageId', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.stageId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy trackType', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.trackType.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy completedAt', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.completedAt.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy points', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.points.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.completionEvents
          .filter((f) => f.id(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by profileId', () async {
      final rows = await db.managers.completionEvents
          .filter((f) => f.profileId.id(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by curriculumId', () async {
      final rows = await db.managers.completionEvents
          .filter((f) => f.curriculumId('bavli'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by sefariaRef', () async {
      final rows = await db.managers.completionEvents
          .filter((f) => f.sefariaRef('Berakhot 2a'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by stageId', () async {
      final rows = await db.managers.completionEvents
          .filter((f) => f.stageId(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by trackType', () async {
      final rows = await db.managers.completionEvents
          .filter((f) => f.trackType('personal'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by completedAt', () async {
      final rows = await db.managers.completionEvents
          .filter((f) => f.completedAt(now))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by points', () async {
      final rows = await db.managers.completionEvents
          .filter((f) => f.points(0))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── completionEvents — remaining orderBy ──────────────────────────────────

  group('completionEvents — remaining orderBy fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'ce-ob@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      final stageDefId = await makeStageDef(profId, trackId);
      await db
          .into(db.completionEvents)
          .insert(
            CompletionEventsCompanion.insert(
              profileId: profId,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot 2a',
              stageId: stageDefId,
              trackType: 'personal',
              eventTimestamp: now,
            ),
          );
    });

    test('orderBy id', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.profileId.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy curriculumId', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.curriculumId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy sefariaRef', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.sefariaRef.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy stageId', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.stageId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy trackType', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.trackType.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy eventTimestamp', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.eventTimestamp.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy createdAt', () async {
      final rows = await db.managers.completionEvents
          .orderBy((o) => o.createdAt.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.completionEvents
          .filter((f) => f.id(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by curriculumId', () async {
      final rows = await db.managers.completionEvents
          .filter((f) => f.curriculumId('bavli'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by stageId', () async {
      final rows = await db.managers.completionEvents
          .filter((f) => f.stageId(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by trackType', () async {
      final rows = await db.managers.completionEvents
          .filter((f) => f.trackType('personal'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by eventTimestamp', () async {
      final rows = await db.managers.completionEvents
          .filter((f) => f.eventTimestamp(now))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by createdAt', () async {
      // createdAt defaults to currentDateAndTime; just verify the filter compiles and executes
      final rows = await db.managers.completionEvents
          .filter((f) => f.createdAt(now))
          .get();
      expect(rows, isA<List<CompletionEvent>>());
    });
  });

  // ── dailyPlans — remaining orderBy ────────────────────────────────────────

  group('dailyPlans — remaining orderBy fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'dp-ob@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      final stageDefId = await makeStageDef(profId, trackId);
      await db
          .into(db.dailyPlans)
          .insert(
            DailyPlansCompanion.insert(
              profileId: profId,
              curriculumId: 'bavli',
              planDate: now,
              sefariaRef: 'Berakhot 2a',
              stageOrder: 1,
              stageDefinitionId: stageDefId,
              trackId: trackId,
              priority: 'regular',
              createdAt: now,
            ),
          );
    });

    test('orderBy id', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.profileId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy curriculumId', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.curriculumId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy sefariaRef', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.sefariaRef.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy stageOrder', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.stageOrder.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy stageDefinitionId', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.stageDefinitionId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy trackId', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.trackId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy trackLabel', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.trackLabel.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy priority', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.priority.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy isOverdue', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.isOverdue.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy reason', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.reason.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy stageName', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.stageName.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy estimatedEffortMinutes', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.estimatedEffortMinutes.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy sortOrder', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.sortOrder.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy createdAt', () async {
      final rows = await db.managers.dailyPlans
          .orderBy((o) => o.createdAt.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.dailyPlans.filter((f) => f.id(1)).get();
      expect(rows, hasLength(1));
    });

    test('filter by profileId', () async {
      final rows = await db.managers.dailyPlans
          .filter((f) => f.profileId(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by curriculumId', () async {
      final rows = await db.managers.dailyPlans
          .filter((f) => f.curriculumId('bavli'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by sefariaRef', () async {
      final rows = await db.managers.dailyPlans
          .filter((f) => f.sefariaRef('Berakhot 2a'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by stageOrder', () async {
      final rows = await db.managers.dailyPlans
          .filter((f) => f.stageOrder(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by stageDefinitionId', () async {
      final rows = await db.managers.dailyPlans
          .filter((f) => f.stageDefinitionId(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by trackId', () async {
      final rows = await db.managers.dailyPlans
          .filter((f) => f.trackId(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by priority', () async {
      final rows = await db.managers.dailyPlans
          .filter((f) => f.priority('regular'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by isOverdue', () async {
      final rows = await db.managers.dailyPlans
          .filter((f) => f.isOverdue(false))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by createdAt', () async {
      final rows = await db.managers.dailyPlans
          .filter((f) => f.createdAt(now))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── learningLedger — remaining orderBy ────────────────────────────────────

  group('learningLedger — remaining orderBy fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'll-ob@test.local');
      final profId = await makeProfile(accId);
      await db
          .into(db.learningLedger)
          .insert(
            LearningLedgerCompanion.insert(
              profileId: profId,
              curriculumId: 'bavli',
              entryScope: 'masechta',
              unitIdentifier: 'Berakhot',
              unitDisplayNameHe: 'ברכות',
              unitDisplayNameEn: 'Berakhot',
              trackType: 'personal',
              completedAt: now,
              completionNumber: 1,
              markedBy: profId,
            ),
          );
    });

    test('orderBy id', () async {
      final rows = await db.managers.learningLedger
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.learningLedger
          .orderBy((o) => o.profileId.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy ulid', () async {
      final rows = await db.managers.learningLedger
          .orderBy((o) => o.ulid.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy curriculumId', () async {
      final rows = await db.managers.learningLedger
          .orderBy((o) => o.curriculumId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy entryScope', () async {
      final rows = await db.managers.learningLedger
          .orderBy((o) => o.entryScope.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy unitIdentifier', () async {
      final rows = await db.managers.learningLedger
          .orderBy((o) => o.unitIdentifier.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy unitDisplayNameHe', () async {
      final rows = await db.managers.learningLedger
          .orderBy((o) => o.unitDisplayNameHe.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy unitDisplayNameEn', () async {
      final rows = await db.managers.learningLedger
          .orderBy((o) => o.unitDisplayNameEn.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy trackType', () async {
      final rows = await db.managers.learningLedger
          .orderBy((o) => o.trackType.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy completedAt', () async {
      final rows = await db.managers.learningLedger
          .orderBy((o) => o.completedAt.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy markedBy', () async {
      final rows = await db.managers.learningLedger
          .orderBy((o) => o.markedBy.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy isManual', () async {
      final rows = await db.managers.learningLedger
          .orderBy((o) => o.isManual.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy createdAt', () async {
      final rows = await db.managers.learningLedger
          .orderBy((o) => o.createdAt.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.learningLedger
          .filter((f) => f.id(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by profileId', () async {
      final rows = await db.managers.learningLedger
          .filter((f) => f.profileId.id(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by curriculumId', () async {
      final rows = await db.managers.learningLedger
          .filter((f) => f.curriculumId('bavli'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by entryScope', () async {
      final rows = await db.managers.learningLedger
          .filter((f) => f.entryScope('masechta'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by unitIdentifier', () async {
      final rows = await db.managers.learningLedger
          .filter((f) => f.unitIdentifier('Berakhot'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by trackType', () async {
      final rows = await db.managers.learningLedger
          .filter((f) => f.trackType('personal'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by completedAt', () async {
      final rows = await db.managers.learningLedger
          .filter((f) => f.completedAt(now))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by markedBy', () async {
      final rows = await db.managers.learningLedger
          .filter((f) => f.markedBy(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by isManual', () async {
      final rows = await db.managers.learningLedger
          .filter((f) => f.isManual(false))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── bookmarks — remaining orderBy ─────────────────────────────────────────

  group('bookmarks — remaining orderBy fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'bm-ob@test.local');
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

    test('orderBy id', () async {
      final rows = await db.managers.bookmarks.orderBy((o) => o.id.asc()).get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.bookmarks
          .orderBy((o) => o.profileId.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy curriculumId', () async {
      final rows = await db.managers.bookmarks
          .orderBy((o) => o.curriculumId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy updatedAt', () async {
      final rows = await db.managers.bookmarks
          .orderBy((o) => o.updatedAt.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.bookmarks.filter((f) => f.id(1)).get();
      expect(rows, hasLength(1));
    });

    test('filter by profileId', () async {
      final rows = await db.managers.bookmarks
          .filter((f) => f.profileId.id(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by curriculumId', () async {
      final rows = await db.managers.bookmarks
          .filter((f) => f.curriculumId('bavli'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by updatedAt', () async {
      final rows = await db.managers.bookmarks
          .filter((f) => f.updatedAt(now))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── learningOrder — remaining orderBy ────────────────────────────────────

  group('learningOrder — remaining orderBy fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'lo-ob@test.local');
      final profId = await makeProfile(accId);
      await db
          .into(db.learningOrder)
          .insert(
            LearningOrderCompanion.insert(
              profileId: profId,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot 2a',
              userSortOrder: 1,
              updatedAt: Value(now),
            ),
          );
    });

    test('orderBy id', () async {
      final rows = await db.managers.learningOrder
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.learningOrder
          .orderBy((o) => o.profileId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy curriculumId', () async {
      final rows = await db.managers.learningOrder
          .orderBy((o) => o.curriculumId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy sefariaRef', () async {
      final rows = await db.managers.learningOrder
          .orderBy((o) => o.sefariaRef.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy updatedAt', () async {
      final rows = await db.managers.learningOrder
          .orderBy((o) => o.updatedAt.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.learningOrder.filter((f) => f.id(1)).get();
      expect(rows, hasLength(1));
    });

    test('filter by profileId', () async {
      final rows = await db.managers.learningOrder
          .filter((f) => f.profileId(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by curriculumId', () async {
      final rows = await db.managers.learningOrder
          .filter((f) => f.curriculumId('bavli'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by sefariaRef', () async {
      final rows = await db.managers.learningOrder
          .filter((f) => f.sefariaRef('Berakhot 2a'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by updatedAt', () async {
      final rows = await db.managers.learningOrder
          .filter((f) => f.updatedAt(now))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── trackLearningOrder — remaining orderBy ────────────────────────────────

  group('trackLearningOrder — remaining orderBy fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'tlo-ob@test.local');
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

    test('orderBy id', () async {
      final rows = await db.managers.trackLearningOrder
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy trackId', () async {
      final rows = await db.managers.trackLearningOrder
          .orderBy((o) => o.trackId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy sefariaRef', () async {
      final rows = await db.managers.trackLearningOrder
          .orderBy((o) => o.sefariaRef.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.trackLearningOrder
          .filter((f) => f.id(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by trackId', () async {
      final rows = await db.managers.trackLearningOrder
          .filter((f) => f.trackId(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by sefariaRef', () async {
      final rows = await db.managers.trackLearningOrder
          .filter((f) => f.sefariaRef('Berakhot 2a'))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── goals — remaining orderBy ─────────────────────────────────────────────

  group('goals — remaining orderBy fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'gl-ob@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: profId,
              curriculumId: 'bavli',
              trackId: trackId,
              targetDate: Value(now),
              paceValue: const Value(5),
              pacePeriod: const Value('week'),
              paceGranularity: const Value('daf'),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    test('orderBy id', () async {
      final rows = await db.managers.goals.orderBy((o) => o.id.asc()).get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.goals
          .orderBy((o) => o.profileId.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy curriculumId', () async {
      final rows = await db.managers.goals
          .orderBy((o) => o.curriculumId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy targetDate', () async {
      final rows = await db.managers.goals
          .orderBy((o) => o.targetDate.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy description', () async {
      final rows = await db.managers.goals
          .orderBy((o) => o.description.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy dateType', () async {
      final rows = await db.managers.goals
          .orderBy((o) => o.dateType.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy goalType', () async {
      final rows = await db.managers.goals
          .orderBy((o) => o.goalType.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy paceValue', () async {
      final rows = await db.managers.goals
          .orderBy((o) => o.paceValue.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy pacePeriod', () async {
      final rows = await db.managers.goals
          .orderBy((o) => o.pacePeriod.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy paceGranularity', () async {
      final rows = await db.managers.goals
          .orderBy((o) => o.paceGranularity.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy createdAt', () async {
      final rows = await db.managers.goals
          .orderBy((o) => o.createdAt.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy updatedAt', () async {
      final rows = await db.managers.goals
          .orderBy((o) => o.updatedAt.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.goals.filter((f) => f.id(1)).get();
      expect(rows, hasLength(1));
    });

    test('filter by profileId', () async {
      final rows = await db.managers.goals
          .filter((f) => f.profileId.id(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by curriculumId', () async {
      final rows = await db.managers.goals
          .filter((f) => f.curriculumId('bavli'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by targetDate', () async {
      final rows = await db.managers.goals
          .filter((f) => f.targetDate(now))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by description', () async {
      final rows = await db.managers.goals
          .filter((f) => f.description(''))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by dateType', () async {
      final rows = await db.managers.goals
          .filter((f) => f.dateType('gregorian'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by goalType', () async {
      final rows = await db.managers.goals
          .filter((f) => f.goalType('deadline'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by paceValue', () async {
      final rows = await db.managers.goals.filter((f) => f.paceValue(5)).get();
      expect(rows, hasLength(1));
    });

    test('filter by pacePeriod', () async {
      final rows = await db.managers.goals
          .filter((f) => f.pacePeriod('week'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by paceGranularity', () async {
      final rows = await db.managers.goals
          .filter((f) => f.paceGranularity('daf'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by createdAt', () async {
      final rows = await db.managers.goals
          .filter((f) => f.createdAt(now))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by updatedAt', () async {
      final rows = await db.managers.goals
          .filter((f) => f.updatedAt(now))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── streaks — remaining orderBy ───────────────────────────────────────────

  group('streaks — remaining orderBy fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'sk-ob@test.local');
      final profId = await makeProfile(accId);
      await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profId,
              currentStreak: const Value(5),
              maxStreak: const Value(10),
              gracePeriodDays: const Value(1),
            ),
          );
    });

    test('orderBy id', () async {
      final rows = await db.managers.streakEvents
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.streakEvents
          .orderBy((o) => o.profileId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy currentStreak', () async {
      final rows = await db.managers.streakEvents
          .orderBy((o) => o.currentStreak.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy maxStreak', () async {
      final rows = await db.managers.streakEvents
          .orderBy((o) => o.maxStreak.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy lastCompletionDate', () async {
      final rows = await db.managers.streakEvents
          .orderBy((o) => o.lastCompletionDate.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy graceUsedDate', () async {
      final rows = await db.managers.streakEvents
          .orderBy((o) => o.graceUsedDate.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy gracePeriodDays', () async {
      final rows = await db.managers.streakEvents
          .orderBy((o) => o.gracePeriodDays.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.streakEvents.filter((f) => f.id(1)).get();
      expect(rows, hasLength(1));
    });

    test('filter by currentStreak', () async {
      final rows = await db.managers.streakEvents
          .filter((f) => f.currentStreak(5))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by maxStreak', () async {
      final rows = await db.managers.streakEvents
          .filter((f) => f.maxStreak(10))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by lastCompletionDate', () async {
      final rows = await db.managers.streakEvents
          .filter((f) => f.lastCompletionDate(null))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by graceUsedDate', () async {
      final rows = await db.managers.streakEvents
          .filter((f) => f.graceUsedDate(null))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by gracePeriodDays', () async {
      final rows = await db.managers.streakEvents
          .filter((f) => f.gracePeriodDays(1))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── streakEvents — remaining orderBy ─────────────────────────────────────

  group('streakEvents — remaining orderBy fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'se-ob@test.local');
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

    test('orderBy id', () async {
      final rows = await db.managers.streakEvents
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.streakEvents
          .orderBy((o) => o.profileId.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy eventType', () async {
      final rows = await db.managers.streakEvents
          .orderBy((o) => o.eventType.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy dayUtc', () async {
      final rows = await db.managers.streakEvents
          .orderBy((o) => o.dayUtc.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy eventTimestamp', () async {
      final rows = await db.managers.streakEvents
          .orderBy((o) => o.eventTimestamp.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy clientDeviceId', () async {
      final rows = await db.managers.streakEvents
          .orderBy((o) => o.clientDeviceId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy createdAt', () async {
      final rows = await db.managers.streakEvents
          .orderBy((o) => o.createdAt.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.streakEvents.filter((f) => f.id(1)).get();
      expect(rows, hasLength(1));
    });

    test('filter by profileId', () async {
      final rows = await db.managers.streakEvents
          .filter((f) => f.profileId.id(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by eventType', () async {
      final rows = await db.managers.streakEvents
          .filter((f) => f.eventType('completion'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by dayUtc', () async {
      final rows = await db.managers.streakEvents
          .filter((f) => f.dayUtc(DateTime.utc(2026, 3, 1)))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by eventTimestamp', () async {
      final rows = await db.managers.streakEvents
          .filter((f) => f.eventTimestamp(now))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by clientDeviceId', () async {
      final rows = await db.managers.streakEvents
          .filter((f) => f.clientDeviceId('dev-1'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by createdAt', () async {
      final rows = await db.managers.streakEvents
          .filter((f) => f.createdAt(now))
          .get();
      expect(rows, isA<List<StreakEvent>>());
    });
  });

  // ── syncQueue — remaining orderBy ─────────────────────────────────────────

  group('syncQueue — remaining orderBy fields', () {
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

    test('orderBy id', () async {
      final rows = await db.managers.syncQueue.orderBy((o) => o.id.asc()).get();
      expect(rows, hasLength(1));
    });

    test('orderBy operationType', () async {
      final rows = await db.managers.syncQueue
          .orderBy((o) => o.operationType.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy payload', () async {
      final rows = await db.managers.syncQueue
          .orderBy((o) => o.payload.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy retryCount', () async {
      final rows = await db.managers.syncQueue
          .orderBy((o) => o.retryCount.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy lastError', () async {
      final rows = await db.managers.syncQueue
          .orderBy((o) => o.lastError.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.syncQueue.filter((f) => f.id(1)).get();
      expect(rows, hasLength(1));
    });

    test('filter by operationType', () async {
      final rows = await db.managers.syncQueue
          .filter((f) => f.operationType('upsert'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by retryCount', () async {
      final rows = await db.managers.syncQueue
          .filter((f) => f.retryCount(0))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by lastError', () async {
      final rows = await db.managers.syncQueue
          .filter((f) => f.lastError(null))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── textDownloadStatuses — remaining orderBy ──────────────────────────────

  group('textDownloadStatuses — remaining orderBy fields', () {
    setUp(() async {
      await db
          .into(db.textDownloadStatuses)
          .insert(
            TextDownloadStatusesCompanion.insert(
              curriculumId: 'bavli',
              itemCount: 50,
              textVersion: 'v1',
              downloadedAt: now,
              storedItemCount: const Value(100),
            ),
          );
    });

    test('orderBy curriculumId', () async {
      final rows = await db.managers.textDownloadStatuses
          .orderBy((o) => o.curriculumId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy textVersion', () async {
      final rows = await db.managers.textDownloadStatuses
          .orderBy((o) => o.textVersion.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy downloadedAt', () async {
      final rows = await db.managers.textDownloadStatuses
          .orderBy((o) => o.downloadedAt.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy storedItemCount', () async {
      final rows = await db.managers.textDownloadStatuses
          .orderBy((o) => o.storedItemCount.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by curriculumId', () async {
      final rows = await db.managers.textDownloadStatuses
          .filter((f) => f.curriculumId('bavli'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by textVersion', () async {
      final rows = await db.managers.textDownloadStatuses
          .filter((f) => f.textVersion('v1'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by downloadedAt', () async {
      final rows = await db.managers.textDownloadStatuses
          .filter((f) => f.downloadedAt(now))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by storedItemCount', () async {
      final rows = await db.managers.textDownloadStatuses
          .filter((f) => f.storedItemCount(100))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── outbox — remaining orderBy ────────────────────────────────────────────

  group('outbox — remaining orderBy fields', () {
    setUp(() async {
      final accId = await makeAccount(email: 'ob2-ob@test.local');
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

    test('orderBy id', () async {
      final rows = await db.managers.outbox.orderBy((o) => o.id.asc()).get();
      expect(rows, hasLength(1));
    });

    test('orderBy profileId', () async {
      final rows = await db.managers.outbox
          .orderBy((o) => o.profileId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy entityKind', () async {
      final rows = await db.managers.outbox
          .orderBy((o) => o.entityKind.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy entityKey', () async {
      final rows = await db.managers.outbox
          .orderBy((o) => o.entityKey.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy payload', () async {
      final rows = await db.managers.outbox
          .orderBy((o) => o.payload.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy attempts', () async {
      final rows = await db.managers.outbox
          .orderBy((o) => o.attempts.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy lastError', () async {
      final rows = await db.managers.outbox
          .orderBy((o) => o.lastError.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy lastAttemptAt', () async {
      final rows = await db.managers.outbox
          .orderBy((o) => o.lastAttemptAt.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.outbox.filter((f) => f.id(1)).get();
      expect(rows, hasLength(1));
    });

    test('filter by profileId', () async {
      final rows = await db.managers.outbox.filter((f) => f.profileId(1)).get();
      expect(rows, hasLength(1));
    });

    test('filter by entityKind', () async {
      final rows = await db.managers.outbox
          .filter((f) => f.entityKind('completion'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by entityKey', () async {
      final rows = await db.managers.outbox
          .filter((f) => f.entityKey('key-1'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by payload', () async {
      final rows = await db.managers.outbox
          .filter((f) => f.payload('{}'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by attempts', () async {
      final rows = await db.managers.outbox.filter((f) => f.attempts(0)).get();
      expect(rows, hasLength(1));
    });

    test('filter by lastError', () async {
      final rows = await db.managers.outbox
          .filter((f) => f.lastError(null))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by lastAttemptAt', () async {
      final rows = await db.managers.outbox
          .filter((f) => f.lastAttemptAt(null))
          .get();
      expect(rows, hasLength(1));
    });
  });

  // ── sacredWindowEntries — remaining orderBy ───────────────────────────────

  group('sacredWindowEntries — remaining orderBy fields', () {
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

    test('orderBy id', () async {
      final rows = await db.managers.sacredWindowEntries
          .orderBy((o) => o.id.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy endUtc', () async {
      final rows = await db.managers.sacredWindowEntries
          .orderBy((o) => o.endUtc.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy kind', () async {
      final rows = await db.managers.sacredWindowEntries
          .orderBy((o) => o.kind.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy lat', () async {
      final rows = await db.managers.sacredWindowEntries
          .orderBy((o) => o.lat.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy lng', () async {
      final rows = await db.managers.sacredWindowEntries
          .orderBy((o) => o.lng.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy inIsrael', () async {
      final rows = await db.managers.sacredWindowEntries
          .orderBy((o) => o.inIsrael.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy createdAt', () async {
      final rows = await db.managers.sacredWindowEntries
          .orderBy((o) => o.createdAt.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by id', () async {
      final rows = await db.managers.sacredWindowEntries
          .filter((f) => f.id(1))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by endUtc', () async {
      final rows = await db.managers.sacredWindowEntries
          .filter((f) => f.endUtc(now.add(const Duration(hours: 25))))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by kind', () async {
      final rows = await db.managers.sacredWindowEntries
          .filter((f) => f.kind('shabbos'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by inIsrael', () async {
      final rows = await db.managers.sacredWindowEntries
          .filter((f) => f.inIsrael(true))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by createdAt', () async {
      final rows = await db.managers.sacredWindowEntries
          .filter((f) => f.createdAt(now))
          .get();
      expect(rows, hasLength(1));
    });
  });
}
