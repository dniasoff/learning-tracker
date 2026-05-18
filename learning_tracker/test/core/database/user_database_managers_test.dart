/// Tests that exercise the Drift TableManager API (`db.managers.*`) for all
/// UserDatabase tables. Each filter/orderBy call covers the generated
/// FilterComposer, OrderingComposer, AnnotationComposer, and TableManager
/// classes in user_database.g.dart (lines 9900+, ~3000 lines).
///
/// Also covers DataClass serialization for tables not covered in
/// user_database_dataclass_test.dart.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
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

  // ─── Shared helpers ──────────────────────────────────────────────────────

  Future<int> makeAccount({String email = 'a@test.local'}) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: email,
          tier: 'localBorn',
          displayName: 'Test',
          userMode: 'adult',
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> makeProfile(int accountId, {String mode = 'adult'}) => db
      .into(db.learnerProfiles)
      .insert(
        ProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Learner',
          mode: mode,
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> makeTrack(int profileId, {String curriculum = 'bavli'}) => db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculum,
          trackType: 'personal',
          activatedAt: now,
        ),
      );

  // ─── Managers for core identity tables ──────────────────────────────────

  group('managers — accounts', () {
    test('filter + count', () async {
      await makeAccount(email: 'a1@test.local');
      await makeAccount(email: 'a2@test.local');
      final rows = await db.managers.accounts.get();
      expect(rows, hasLength(2));
    });

    test('filter by tier', () async {
      await makeAccount(email: 'local@test.local');
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'cloud@test.local',
              tier: 'cloudBorn',
              displayName: 'Cloud',
              userMode: 'adult',
              createdAt: now,
              updatedAt: now,
              firebaseUid: const Value('fb-1'),
            ),
          );

      final localRows = await db.managers.accounts
          .filter((f) => f.tier('localBorn'))
          .get();
      expect(localRows, hasLength(1));

      final cloudRows = await db.managers.accounts
          .filter((f) => f.tier('cloudBorn'))
          .get();
      expect(cloudRows, hasLength(1));
    });

    test('orderBy email ascending', () async {
      await makeAccount(email: 'z@test.local');
      await makeAccount(email: 'a@test.local');
      final rows = await db.managers.accounts
          .orderBy((o) => o.email.asc())
          .get();
      expect(rows.first.email, 'a@test.local');
    });
  });

  group('managers — learnerProfiles', () {
    test('filter by mode', () async {
      final accId = await makeAccount();
      await makeProfile(accId, mode: 'child');
      await makeProfile(accId, mode: 'adult');

      final children = await db.managers.learnerProfiles
          .filter((f) => f.mode('child'))
          .get();
      expect(children, hasLength(1));
    });

    test('orderBy displayName desc', () async {
      final accId = await makeAccount();
      await db
          .into(db.learnerProfiles)
          .insert(
            ProfilesCompanion.insert(
              accountId: accId,
              displayName: 'Alice',
              mode: 'adult',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.learnerProfiles)
          .insert(
            ProfilesCompanion.insert(
              accountId: accId,
              displayName: 'Zach',
              mode: 'adult',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final rows = await db.managers.learnerProfiles
          .orderBy((o) => o.displayName.desc())
          .get();
      expect(rows.first.displayName, 'Zach');
    });
  });

  group('managers — curriculumTracks', () {
    test('filter by curriculumId', () async {
      final accId = await makeAccount();
      final profileId = await makeProfile(accId);
      await makeTrack(profileId, curriculum: 'bavli');
      await makeTrack(profileId, curriculum: 'mishnah');

      final bavliTracks = await db.managers.curriculumTracks
          .filter((f) => f.curriculumId('bavli'))
          .get();
      expect(bavliTracks, hasLength(1));
    });

    test('filter by isActive', () async {
      final accId = await makeAccount();
      final profileId = await makeProfile(accId);
      await makeTrack(profileId);

      final active = await db.managers.curriculumTracks
          .filter((f) => f.isActive(true))
          .get();
      expect(active, hasLength(1));
    });
  });

  // ─── StageDefinition DataClass + managers ────────────────────────────────

  group('StageDefinition DataClass + managers', () {
    Future<int> makeStageDef(
      int profileId,
      int trackId, {
      String stageName = 'limud',
      int stageOrder = 1,
    }) => db
        .into(db.stageDefinitions)
        .insert(
          StageDefinitionsCompanion.insert(
            profileId: profileId,
            trackId: trackId,
            curriculumId: 'bavli',
            stageName: stageName,
            stageOrder: stageOrder,
            delayDays: 0,
          ),
        );

    test('toJson / fromJson round-trip', () async {
      final accId = await makeAccount(email: 'sd@test.local');
      final profileId = await makeProfile(accId);
      final trackId = await makeTrack(profileId);
      final sdId = await makeStageDef(profileId, trackId);

      final rows = await (db.select(
        db.stageDefinitions,
      )..where((t) => t.id.equals(sdId))).get();
      final sd = rows.first;

      final json = sd.toJson();
      expect(json['stageName'], 'limud');
      expect(json['stageOrder'], 1);

      final restored = StageDefinition.fromJson(json);
      expect(restored.stageName, sd.stageName);
    });

    test('copyWith, equality, toString', () async {
      final accId = await makeAccount(email: 'sd2@test.local');
      final profileId = await makeProfile(accId);
      final trackId = await makeTrack(profileId);
      final sdId = await makeStageDef(
        profileId,
        trackId,
        stageName: 'chazara1',
      );

      final sd = await (db.select(
        db.stageDefinitions,
      )..where((t) => t.id.equals(sdId))).getSingle();
      final sd2 = await (db.select(
        db.stageDefinitions,
      )..where((t) => t.id.equals(sdId))).getSingle();

      expect(sd, equals(sd2));
      expect(sd.hashCode, equals(sd2.hashCode));
      expect(sd.toString(), contains('chazara1'));

      final copy = sd.copyWith(delayDays: 3);
      expect(copy.stageName, sd.stageName);
      expect(copy.delayDays, 3);
    });

    test('toCompanion and copyWithCompanion', () async {
      final accId = await makeAccount(email: 'sd3@test.local');
      final profileId = await makeProfile(accId);
      final trackId = await makeTrack(profileId);
      final sdId = await makeStageDef(profileId, trackId);

      final sd = await (db.select(
        db.stageDefinitions,
      )..where((t) => t.id.equals(sdId))).getSingle();

      final companion = sd.toCompanion(true);
      expect(companion.profileId.value, profileId);

      final copy = sd.copyWithCompanion(
        const StageDefinitionsCompanion(delayDays: Value(7)),
      );
      expect(copy.delayDays, 7);
    });

    test('managers.stageDefinitions.filter', () async {
      final accId = await makeAccount(email: 'sd4@test.local');
      final profileId = await makeProfile(accId);
      final trackId = await makeTrack(profileId);
      await makeStageDef(profileId, trackId, stageName: 'limud', stageOrder: 1);
      await makeStageDef(
        profileId,
        trackId,
        stageName: 'chazara1',
        stageOrder: 2,
      );

      final rows = await db.managers.stageDefinitions
          .filter((f) => f.profileId.id(profileId))
          .orderBy((o) => o.stageOrder.asc())
          .get();
      expect(rows, hasLength(2));
      expect(rows.first.stageName, 'limud');

      final StageDefinitionsCompanion(:delayDays) = rows.first.toCompanion(
        true,
      );
      expect(delayDays.value, 0);
    });
  });

  // ─── PointConfig DataClass + managers ────────────────────────────────────

  group('PointConfig DataClass + managers', () {
    test('toJson / fromJson, copyWith, equality, managers', () async {
      final accId = await makeAccount(email: 'pc@test.local');
      final profileId = await makeProfile(accId);
      final trackId = await makeTrack(profileId);

      await db
          .into(db.pointConfigs)
          .insert(
            PointConfigsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              stageOrder: 1,
              points: 10,
            ),
          );
      await db
          .into(db.pointConfigs)
          .insert(
            PointConfigsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              stageOrder: 2,
              points: 5,
            ),
          );

      final rows = await db.managers.pointConfigs
          .filter((f) => f.profileId(profileId))
          .orderBy((o) => o.stageOrder.asc())
          .get();
      expect(rows, hasLength(2));
      expect(rows.first.points, 10);

      final pc = rows.first;
      final json = pc.toJson();
      expect(json['points'], 10);
      final restored = PointConfig.fromJson(json);
      expect(restored.points, pc.points);

      final copy = pc.copyWith(points: 20);
      expect(copy.stageOrder, pc.stageOrder);
      expect(copy.points, 20);

      final pc2 = rows.first;
      expect(pc, equals(pc2));
      expect(pc.hashCode, equals(pc2.hashCode));
      expect(pc.toString(), contains('bavli'));

      final companion = pc.toCompanion(true);
      expect(companion.points.value, 10);

      final copyComp = pc.copyWithCompanion(
        const PointConfigsCompanion(points: Value(15)),
      );
      expect(copyComp.points, 15);
    });

    test('PointConfigsCompanion.copyWith', () {
      const original = PointConfigsCompanion(
        curriculumId: Value('bavli'),
        points: Value(5),
      );
      final copy = original.copyWith(points: const Value(10));
      expect(copy.curriculumId.value, 'bavli');
      expect(copy.points.value, 10);
    });
  });

  // ─── StudyDayConfig DataClass + managers ─────────────────────────────────

  group('StudyDayConfig DataClass + managers', () {
    test('toJson / fromJson, copyWith, equality, managers', () async {
      final accId = await makeAccount(email: 'sdc@test.local');
      final profileId = await makeProfile(accId);
      final trackId = await makeTrack(profileId);

      for (var day = 1; day <= 5; day++) {
        await db
            .into(db.studyDayConfigs)
            .insert(
              StudyDayConfigsCompanion.insert(
                profileId: profileId,
                curriculumId: 'bavli',
                trackId: trackId,
                dayOfWeek: day,
                updatedAt: now,
              ),
            );
      }

      final rows = await db.managers.studyDayConfigs
          .filter((f) => f.profileId(profileId))
          .orderBy((o) => o.dayOfWeek.asc())
          .get();
      expect(rows, hasLength(5));
      expect(rows.first.dayOfWeek, 1);

      final sdc = rows.first;
      final json = sdc.toJson();
      expect(json['dayOfWeek'], 1);
      final restored = StudyDayConfig.fromJson(json);
      expect(restored.dayOfWeek, sdc.dayOfWeek);

      final copy = sdc.copyWith(dayType: 'review');
      expect(copy.dayOfWeek, sdc.dayOfWeek);
      expect(copy.dayType, 'review');

      final sdc2 = rows.first;
      expect(sdc, equals(sdc2));
      expect(sdc.hashCode, equals(sdc2.hashCode));
      expect(sdc.toString(), contains('bavli'));

      final companion = sdc.toCompanion(true);
      expect(companion.dayOfWeek.value, 1);

      final copyComp = sdc.copyWithCompanion(
        const StudyDayConfigsCompanion(dayType: Value('review')),
      );
      expect(copyComp.dayType, 'review');
    });

    test('StudyDayConfigsCompanion.copyWith', () {
      const original = StudyDayConfigsCompanion(
        curriculumId: Value('bavli'),
        dayOfWeek: Value(1),
      );
      final copy = original.copyWith(dayType: const Value('review'));
      expect(copy.dayOfWeek.value, 1);
      expect(copy.dayType.value, 'review');
    });
  });

  // ─── Completion DataClass + managers ─────────────────────────────────────

  group('Completion DataClass + managers', () {
    test('toJson / fromJson, copyWith, equality, managers', () async {
      final accId = await makeAccount(email: 'comp@test.local');
      final profileId = await makeProfile(accId);
      final trackId = await makeTrack(profileId);

      await db
          .into(db.completions)
          .insert(
            CompletionsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot 2a',
              stageId: 1,
              trackType: 'personal',
              trackId: trackId,
              completedAt: now,
            ),
          );

      final rows = await db.managers.completions
          .filter((f) => f.profileId.id(profileId))
          .get();
      expect(rows, hasLength(1));

      final c = rows.first;
      final json = c.toJson();
      expect(json['sefariaRef'], 'Berakhot 2a');
      final restored = Completion.fromJson(json);
      expect(restored.sefariaRef, c.sefariaRef);

      final copy = c.copyWith(points: 5);
      expect(copy.sefariaRef, c.sefariaRef);
      expect(copy.points, 5);

      final c2 = rows.first;
      expect(c, equals(c2));
      expect(c.hashCode, equals(c2.hashCode));
      expect(c.toString(), contains('Berakhot 2a'));

      final companion = c.toCompanion(true);
      expect(companion.sefariaRef.value, 'Berakhot 2a');

      final copyComp = c.copyWithCompanion(
        const CompletionsCompanion(points: Value(10)),
      );
      expect(copyComp.points, 10);
    });

    test('CompletionsCompanion.copyWith', () {
      const original = CompletionsCompanion(
        sefariaRef: Value('Berakhot 2a'),
        points: Value(5),
      );
      final copy = original.copyWith(points: const Value(10));
      expect(copy.sefariaRef.value, 'Berakhot 2a');
      expect(copy.points.value, 10);
    });
  });

  // ─── CompletionEvent DataClass + managers ─────────────────────────────────

  group('CompletionEvent DataClass + managers', () {
    test('toJson / fromJson, copyWith, equality, managers', () async {
      final accId = await makeAccount(email: 'ce@test.local');
      final profileId = await makeProfile(accId);

      await db
          .into(db.completionEvents)
          .insert(
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot 3a',
              stageId: 1,
              trackType: 'personal',
              eventTimestamp: now,
            ),
          );

      final rows = await db.managers.completionEvents
          .filter((f) => f.profileId.id(profileId))
          .get();
      expect(rows, hasLength(1));

      final ce = rows.first;
      final json = ce.toJson();
      expect(json['sefariaRef'], 'Berakhot 3a');
      final restored = CompletionEvent.fromJson(json);
      expect(restored.sefariaRef, ce.sefariaRef);

      final copy = ce.copyWith(trackType: 'other');
      expect(copy.sefariaRef, ce.sefariaRef);
      expect(copy.trackType, 'other');

      final ce2 = rows.first;
      expect(ce, equals(ce2));
      expect(ce.hashCode, equals(ce2.hashCode));
      expect(ce.toString(), contains('Berakhot 3a'));

      final companion = ce.toCompanion(true);
      expect(companion.sefariaRef.value, 'Berakhot 3a');

      final copyComp = ce.copyWithCompanion(
        const CompletionEventsCompanion(trackType: Value('chazara')),
      );
      expect(copyComp.trackType, 'chazara');
    });

    test('CompletionEventsCompanion.copyWith', () {
      const original = CompletionEventsCompanion(
        sefariaRef: Value('Berakhot 3a'),
        trackType: Value('personal'),
      );
      final copy = original.copyWith(trackType: const Value('chazara'));
      expect(copy.sefariaRef.value, 'Berakhot 3a');
      expect(copy.trackType.value, 'chazara');
    });
  });

  // ─── Bookmark DataClass + managers ───────────────────────────────────────

  group('Bookmark DataClass + managers', () {
    test('toJson / fromJson, copyWith, equality, managers', () async {
      final accId = await makeAccount(email: 'bm@test.local');
      final profileId = await makeProfile(accId);
      final trackId = await makeTrack(profileId);

      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot 5a',
              updatedAt: now,
            ),
          );

      final rows = await db.managers.bookmarks
          .filter((f) => f.profileId.id(profileId))
          .get();
      expect(rows, hasLength(1));

      final bm = rows.first;
      final json = bm.toJson();
      expect(json['sefariaRef'], 'Berakhot 5a');
      final restored = Bookmark.fromJson(json);
      expect(restored.sefariaRef, bm.sefariaRef);

      final copy = bm.copyWith(sefariaRef: 'Berakhot 6a');
      expect(copy.curriculumId, bm.curriculumId);
      expect(copy.sefariaRef, 'Berakhot 6a');

      final bm2 = rows.first;
      expect(bm, equals(bm2));
      expect(bm.hashCode, equals(bm2.hashCode));
      expect(bm.toString(), contains('Berakhot 5a'));

      final companion = bm.toCompanion(true);
      expect(companion.sefariaRef.value, 'Berakhot 5a');

      final copyComp = bm.copyWithCompanion(
        const BookmarksCompanion(sefariaRef: Value('Berakhot 7a')),
      );
      expect(copyComp.sefariaRef, 'Berakhot 7a');
    });

    test('BookmarksCompanion.copyWith', () {
      const original = BookmarksCompanion(
        curriculumId: Value('bavli'),
        sefariaRef: Value('Berakhot 5a'),
      );
      final copy = original.copyWith(sefariaRef: const Value('Berakhot 6a'));
      expect(copy.curriculumId.value, 'bavli');
      expect(copy.sefariaRef.value, 'Berakhot 6a');
    });
  });

  // ─── LearningOrder DataClass + managers ──────────────────────────────────

  group('LearningOrderData DataClass + managers', () {
    test('toJson / fromJson, copyWith, equality, managers', () async {
      final accId = await makeAccount(email: 'lo@test.local');
      final profileId = await makeProfile(accId);

      await db
          .into(db.learningOrder)
          .insert(
            LearningOrderCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot 2a',
              userSortOrder: 1,
            ),
          );

      final rows = await db.managers.learningOrder
          .filter((f) => f.profileId(profileId))
          .get();
      expect(rows, hasLength(1));

      final lo = rows.first;
      final json = lo.toJson();
      expect(json['sefariaRef'], 'Berakhot 2a');
      expect(json['userSortOrder'], 1);
      final restored = LearningOrderData.fromJson(json);
      expect(restored.sefariaRef, lo.sefariaRef);

      final copy = lo.copyWith(userSortOrder: 99);
      expect(copy.sefariaRef, lo.sefariaRef);
      expect(copy.userSortOrder, 99);

      final lo2 = rows.first;
      expect(lo, equals(lo2));
      expect(lo.hashCode, equals(lo2.hashCode));
      expect(lo.toString(), contains('bavli'));

      final companion = lo.toCompanion(true);
      expect(companion.sefariaRef.value, 'Berakhot 2a');

      final copyComp = lo.copyWithCompanion(
        const LearningOrderCompanion(userSortOrder: Value(50)),
      );
      expect(copyComp.userSortOrder, 50);
    });

    test('LearningOrderCompanion.copyWith', () {
      const original = LearningOrderCompanion(
        curriculumId: Value('bavli'),
        userSortOrder: Value(1),
      );
      final copy = original.copyWith(userSortOrder: const Value(2));
      expect(copy.curriculumId.value, 'bavli');
      expect(copy.userSortOrder.value, 2);
    });
  });

  // ─── TrackLearningOrder DataClass + managers ──────────────────────────────

  group('TrackLearningOrderData DataClass + managers', () {
    test('toJson / fromJson, copyWith, equality, managers', () async {
      final accId = await makeAccount(email: 'tlo@test.local');
      final profileId = await makeProfile(accId);
      final trackId = await makeTrack(profileId);

      await db
          .into(db.trackLearningOrder)
          .insert(
            TrackLearningOrderCompanion.insert(
              trackId: trackId,
              sefariaRef: 'Berakhot 10a',
              sortOrder: 1,
            ),
          );

      final rows = await db.managers.trackLearningOrder
          .filter((f) => f.trackId(trackId))
          .get();
      expect(rows, hasLength(1));

      final tlo = rows.first;
      final json = tlo.toJson();
      expect(json['sefariaRef'], 'Berakhot 10a');
      expect(json['sortOrder'], 1);
      final restored = TrackLearningOrderData.fromJson(json);
      expect(restored.sefariaRef, tlo.sefariaRef);

      final copy = tlo.copyWith(sortOrder: 5);
      expect(copy.sefariaRef, tlo.sefariaRef);
      expect(copy.sortOrder, 5);

      final tlo2 = rows.first;
      expect(tlo, equals(tlo2));
      expect(tlo.hashCode, equals(tlo2.hashCode));
      expect(tlo.toString(), contains('Berakhot 10a'));

      final companion = tlo.toCompanion(true);
      expect(companion.sefariaRef.value, 'Berakhot 10a');

      final copyComp = tlo.copyWithCompanion(
        const TrackLearningOrderCompanion(sortOrder: Value(10)),
      );
      expect(copyComp.sortOrder, 10);
    });

    test('TrackLearningOrderCompanion.copyWith', () {
      const original = TrackLearningOrderCompanion(
        sefariaRef: Value('Berakhot 10a'),
        sortOrder: Value(1),
      );
      final copy = original.copyWith(sortOrder: const Value(2));
      expect(copy.sefariaRef.value, 'Berakhot 10a');
      expect(copy.sortOrder.value, 2);
    });
  });

  // ─── Streak DataClass + managers ─────────────────────────────────────────

  group('Streak DataClass + managers', () {
    test('toJson / fromJson, copyWith, equality, managers', () async {
      final accId = await makeAccount(email: 'str@test.local');
      final profileId = await makeProfile(accId);

      await db
          .into(db.streaks)
          .insert(
            StreaksCompanion.insert(
              profileId: profileId,
              currentStreak: const Value(5),
              maxStreak: const Value(10),
              lastCompletionDate: Value(DateTime.utc(2026, 3, 1)),
            ),
          );

      final rows = await db.managers.streaks
          .filter((f) => f.profileId(profileId))
          .get();
      expect(rows, hasLength(1));

      final s = rows.first;
      final json = s.toJson();
      expect(json['currentStreak'], 5);
      expect(json['maxStreak'], 10);
      final restored = Streak.fromJson(json);
      expect(restored.currentStreak, s.currentStreak);

      final copy = s.copyWith(currentStreak: 6);
      expect(copy.maxStreak, s.maxStreak);
      expect(copy.currentStreak, 6);

      final s2 = rows.first;
      expect(s, equals(s2));
      expect(s.hashCode, equals(s2.hashCode));
      expect(s.toString(), contains('5'));

      final companion = s.toCompanion(true);
      expect(companion.profileId.value, profileId);

      final copyComp = s.copyWithCompanion(
        const StreaksCompanion(currentStreak: Value(7)),
      );
      expect(copyComp.currentStreak, 7);
    });

    test('Streak.toColumns with nullable lastCompletionDate', () async {
      final accId = await makeAccount(email: 'str2@test.local');
      final profileId = await makeProfile(accId);

      await db
          .into(db.streaks)
          .insert(StreaksCompanion.insert(profileId: profileId));

      final rows = await db.managers.streaks
          .filter((f) => f.profileId(profileId))
          .get();
      final s = rows.first;

      // nullable field absent when nullToAbsent=true
      final colsAbsent = s.toColumns(true);
      expect(colsAbsent.containsKey('last_completion_date'), isFalse);

      // included when nullToAbsent=false
      final colsAll = s.toColumns(false);
      expect(colsAll.containsKey('last_completion_date'), isTrue);
    });

    test('StreaksCompanion.copyWith', () {
      const original = StreaksCompanion(
        currentStreak: Value(5),
        maxStreak: Value(10),
      );
      final copy = original.copyWith(currentStreak: const Value(6));
      expect(copy.maxStreak.value, 10);
      expect(copy.currentStreak.value, 6);
    });
  });

  // ─── StreakEvent DataClass + managers ────────────────────────────────────

  group('StreakEvent DataClass + managers', () {
    test('toJson / fromJson, copyWith, equality, managers', () async {
      final accId = await makeAccount(email: 'sev@test.local');
      final profileId = await makeProfile(accId);

      await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profileId,
              eventType: 'completion',
              dayUtc: DateTime.utc(2026, 3, 1),
              eventTimestamp: now,
              clientDeviceId: const Value('device-123'),
            ),
          );

      final rows = await db.managers.streakEvents
          .filter((f) => f.profileId.id(profileId))
          .get();
      expect(rows, hasLength(1));

      final se = rows.first;
      final json = se.toJson();
      expect(json['eventType'], 'completion');
      final restored = StreakEvent.fromJson(json);
      expect(restored.eventType, se.eventType);

      final copy = se.copyWith(eventType: 'manual_adjust');
      expect(copy.profileId, se.profileId);
      expect(copy.eventType, 'manual_adjust');

      final se2 = rows.first;
      expect(se, equals(se2));
      expect(se.hashCode, equals(se2.hashCode));
      expect(se.toString(), contains('completion'));

      final companion = se.toCompanion(true);
      expect(companion.eventType.value, 'completion');
      // clientDeviceId is non-null, so it should be present
      expect(companion.clientDeviceId.value, 'device-123');

      final copyComp = se.copyWithCompanion(
        const StreakEventsCompanion(eventType: Value('day_boundary')),
      );
      expect(copyComp.eventType, 'day_boundary');
    });

    test('StreakEvent.toColumns with nullable clientDeviceId', () async {
      final accId = await makeAccount(email: 'sev2@test.local');
      final profileId = await makeProfile(accId);

      await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profileId,
              eventType: 'completion',
              dayUtc: DateTime.utc(2026, 3, 2),
              eventTimestamp: now,
            ),
          );

      final rows = await db.managers.streakEvents
          .filter((f) => f.profileId.id(profileId))
          .get();
      final se = rows.first;

      // clientDeviceId is null → absent when nullToAbsent=true
      final colsAbsent = se.toColumns(true);
      expect(colsAbsent.containsKey('client_device_id'), isFalse);

      final colsAll = se.toColumns(false);
      expect(colsAll.containsKey('client_device_id'), isTrue);
    });

    test('StreakEventsCompanion.copyWith', () {
      const original = StreakEventsCompanion(
        eventType: Value('completion'),
        profileId: Value(1),
      );
      final copy = original.copyWith(eventType: const Value('day_boundary'));
      expect(copy.profileId.value, 1);
      expect(copy.eventType.value, 'day_boundary');
    });
  });

  // ─── DailyPlan managers ───────────────────────────────────────────────────

  group('managers — dailyPlans', () {
    test('filter and orderBy', () async {
      final accId = await makeAccount(email: 'dp@test.local');
      final profileId = await makeProfile(accId);
      final trackId = await makeTrack(profileId);
      final sdId = await db
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

      for (var i = 1; i <= 3; i++) {
        await db
            .into(db.dailyPlans)
            .insert(
              DailyPlansCompanion.insert(
                profileId: profileId,
                curriculumId: 'bavli',
                planDate: DateTime.utc(2026, 3, i),
                sefariaRef: 'Berakhot ${i}a',
                stageOrder: 1,
                stageDefinitionId: sdId,
                trackId: trackId,
                priority: 'newLearning',
                createdAt: now,
              ),
            );
      }

      final rows = await db.managers.dailyPlans
          .filter((f) => f.profileId(profileId))
          .orderBy((o) => o.planDate.asc())
          .get();
      expect(rows, hasLength(3));
      expect(rows.first.sefariaRef, 'Berakhot 1a');
    });
  });

  // ─── LearningLedger managers ─────────────────────────────────────────────

  group('managers — learningLedger', () {
    test('filter and orderBy', () async {
      final accId = await makeAccount(email: 'llm@test.local');
      final profileId = await makeProfile(accId);

      for (var i = 1; i <= 3; i++) {
        await db
            .into(db.learningLedger)
            .insert(
              LearningLedgerCompanion.insert(
                profileId: profileId,
                curriculumId: 'bavli',
                entryScope: 'masechta',
                unitIdentifier: 'Berakhot',
                unitDisplayNameHe: 'ברכות',
                unitDisplayNameEn: 'Berakhot',
                trackType: 'personal',
                completedAt: DateTime.utc(2026, 3, i),
                completionNumber: i,
                markedBy: profileId,
              ),
            );
      }

      final rows = await db.managers.learningLedger
          .filter((f) => f.profileId.id(profileId))
          .orderBy((o) => o.completionNumber.asc())
          .get();
      expect(rows, hasLength(3));
      expect(rows.first.completionNumber, 1);
    });
  });

  // ─── CurriculumScopes managers ────────────────────────────────────────────

  group('managers — curriculumScopes', () {
    test('filter and get', () async {
      final accId = await makeAccount(email: 'csm@test.local');
      final profileId = await makeProfile(accId);
      final trackId = await makeTrack(profileId);

      await db
          .into(db.curriculumScopes)
          .insert(
            CurriculumScopesCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              scopeLevel: 1,
              scopeValue: 'Moed',
              createdAt: now,
            ),
          );

      final rows = await db.managers.curriculumScopes
          .filter((f) => f.profileId(profileId))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.scopeValue, 'Moed');
    });
  });

  // ─── ProfilePrograms managers ─────────────────────────────────────────────

  group('managers — profilePrograms', () {
    test('filter by curriculumType', () async {
      final accId = await makeAccount(email: 'ppm@test.local');
      final profileId = await makeProfile(accId);

      await db
          .into(db.profilePrograms)
          .insert(
            ProfileProgramsCompanion.insert(
              profileId: profileId,
              curriculumType: 'bavli',
              programId: 1,
            ),
          );

      final rows = await db.managers.profilePrograms
          .filter((f) => f.curriculumType('bavli'))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.programId, 1);
    });
  });

  // ─── Goals managers ───────────────────────────────────────────────────────

  group('managers — goals', () {
    test('filter and orderBy targetPercent', () async {
      final accId = await makeAccount(email: 'gm@test.local');
      final profileId = await makeProfile(accId);
      final trackId = await makeTrack(profileId);

      for (final pct in [50.0, 80.0, 100.0]) {
        await db
            .into(db.goals)
            .insert(
              GoalsCompanion.insert(
                profileId: profileId,
                curriculumId: 'bavli',
                trackId: trackId,
                targetPercent: Value(pct),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      final rows = await db.managers.goals
          .filter((f) => f.profileId.id(profileId))
          .orderBy((o) => o.targetPercent.asc())
          .get();
      expect(rows, hasLength(3));
      expect(rows.first.targetPercent, 50.0);
    });
  });

  // ─── Bookmarks managers ───────────────────────────────────────────────────

  group('managers — bookmarks', () {
    test('filter and orderBy', () async {
      final accId = await makeAccount(email: 'bmm@test.local');
      final profileId = await makeProfile(accId);
      final trackId = await makeTrack(profileId);

      for (final ref in ['Berakhot 2a', 'Shabbat 1a']) {
        await db
            .into(db.bookmarks)
            .insert(
              BookmarksCompanion.insert(
                profileId: profileId,
                curriculumId: ref.contains('Shabbat') ? 'mishnah' : 'bavli',
                trackId: trackId,
                sefariaRef: ref,
                updatedAt: now,
              ),
            );
      }

      final rows = await db.managers.bookmarks
          .filter((f) => f.profileId.id(profileId))
          .orderBy((o) => o.sefariaRef.asc())
          .get();
      expect(rows, hasLength(2));
    });
  });

  // ─── LearningOrder managers ───────────────────────────────────────────────

  group('managers — learningOrder', () {
    test('filter and orderBy userSortOrder', () async {
      final accId = await makeAccount(email: 'lom@test.local');
      final profileId = await makeProfile(accId);

      for (var i = 3; i >= 1; i--) {
        await db
            .into(db.learningOrder)
            .insert(
              LearningOrderCompanion.insert(
                profileId: profileId,
                curriculumId: 'bavli',
                sefariaRef: 'Berakhot ${i}a',
                userSortOrder: i,
              ),
            );
      }

      final rows = await db.managers.learningOrder
          .filter((f) => f.profileId(profileId))
          .orderBy((o) => o.userSortOrder.asc())
          .get();
      expect(rows, hasLength(3));
      expect(rows.first.userSortOrder, 1);
    });
  });

  // ─── TrackLearningOrder managers ─────────────────────────────────────────

  group('managers — trackLearningOrder', () {
    test('filter and orderBy sortOrder', () async {
      final accId = await makeAccount(email: 'tlom@test.local');
      final profileId = await makeProfile(accId);
      final trackId = await makeTrack(profileId);

      for (var i = 3; i >= 1; i--) {
        await db
            .into(db.trackLearningOrder)
            .insert(
              TrackLearningOrderCompanion.insert(
                trackId: trackId,
                sefariaRef: 'Ref $i',
                sortOrder: i,
              ),
            );
      }

      final rows = await db.managers.trackLearningOrder
          .filter((f) => f.trackId(trackId))
          .orderBy((o) => o.sortOrder.asc())
          .get();
      expect(rows, hasLength(3));
      expect(rows.first.sortOrder, 1);
    });
  });
}
