/// Extended DataClass round-trip tests for the remaining tables in
/// user_database.g.dart that are not yet covered by
/// user_database_dataclass_test.dart.
///
/// Covers: StageDefinition, PointConfig, StudyDayConfig, Completion,
/// CompletionEvent, Bookmark, LearningOrderData, TrackLearningOrderData,
/// Streak, StreakEvent, SyncQueueData, TextDownloadStatuse, OutboxData,
/// SacredWindowEntry.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  final now = DateTime.utc(2026, 1, 15, 10);

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<int> insertAccount({String email = 'a@test.local'}) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: email,
          tier: 'localBorn',
          displayName: 'Test User',
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> insertProfile(int accountId, {String mode = 'adult'}) => db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Profile',
          mode: mode,
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> insertTrack(int profileId, {String curriculumId = 'bavli'}) => db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          stateChangedAt: now,
          activatedAt: now,
        ),
      );

  Future<int> insertStageDef(
    int profileId,
    int trackId, {
    int stageOrder = 1,
    String stageName = 'limud',
  }) => db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: profileId,
          trackId: trackId,
          curriculumId: 'bavli',
          stageName: stageName,
          stageOrder: stageOrder,
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );

  // ─── StageDefinition DataClass ────────────────────────────────────────────

  group('StageDefinition DataClass', () {
    Future<StageDefinition> getStageDef(int id) async {
      final rows = await (db.select(
        db.stageDefinitions,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(email: 'sd@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);
      final sdId = await insertStageDef(profileId, trackId);
      final sd = await getStageDef(sdId);

      final json = sd.toJson();
      expect(json['stageName'], 'limud');
      expect(json['stageOrder'], 1);
      // W3.27: delayDays/daysOfWeek/rollingWindowSize replaced by JSON schedule
      expect(json['schedule'], contains('delay_days'));

      final restored = StageDefinition.fromJson(json);
      expect(restored.stageName, sd.stageName);
      expect(restored.curriculumId, sd.curriculumId);
    });

    test('copyWith and nullable fields', () async {
      final accId = await insertAccount(email: 'sd2@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);
      final sdId = await db
          .into(db.stageDefinitions)
          .insert(
            StageDefinitionsCompanion.insert(
              profileId: profileId,
              trackId: trackId,
              curriculumId: 'bavli',
              stageName: 'chazara',
              stageOrder: 2,
              schedule: const Value('{"type":"delay","delay_days":3}'),
            ),
          );
      final sd = await getStageDef(sdId);

      // W3: daysOfWeek/rollingWindowSize/delayDays replaced by schedule JSON
      expect(sd.schedule, contains('delay_days'));

      final copy = sd.copyWith(stageName: 'review');
      expect(copy.stageName, 'review');
      expect(copy.schedule, sd.schedule);
    });

    test('toColumns covers nullable daysOfWeek / rollingWindowSize', () async {
      final accId = await insertAccount(email: 'sd3@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);
      final sdId = await insertStageDef(profileId, trackId);
      final sd = await getStageDef(sdId);

      // W3: schedule replaces all old quartet columns
      final cols = sd.toColumns(true);
      expect(cols.containsKey('schedule'), isTrue);
      expect(cols.containsKey('stage_name'), isTrue);
    });

    test('toCompanion, equality, hashCode, toString', () async {
      final accId = await insertAccount(email: 'sd4@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);
      final sdId = await insertStageDef(profileId, trackId);
      final sd1 = await getStageDef(sdId);
      final sd2 = await getStageDef(sdId);

      expect(sd1, equals(sd2));
      expect(sd1.hashCode, equals(sd2.hashCode));
      expect(sd1.toString(), contains('limud'));

      final companion = sd1.toCompanion(true);
      expect(companion.stageName.value, 'limud');
    });

    test('copyWithCompanion', () async {
      final accId = await insertAccount(email: 'sd5@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);
      final sdId = await insertStageDef(profileId, trackId);
      final sd = await getStageDef(sdId);

      final copy = sd.copyWithCompanion(
        const StageDefinitionsCompanion(
          schedule: Value('{"type":"delay","delay_days":14}'),
        ),
      );
      expect(copy.schedule, contains('delay_days":14'));
      expect(copy.stageName, sd.stageName);
    });

    test('StageDefinitionsCompanion.copyWith', () {
      const original = StageDefinitionsCompanion(
        stageName: Value('limud'),
        stageOrder: Value(1),
      );
      final copy = original.copyWith(stageOrder: const Value(2));
      expect(copy.stageName.value, 'limud');
      expect(copy.stageOrder.value, 2);
    });
  });

  // ─── PointConfig DataClass ────────────────────────────────────────────────

  group('PointConfig DataClass', () {
    Future<PointConfig> getPointConfig(int id) async {
      final rows = await (db.select(
        db.pointConfigs,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(email: 'pc@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);

      final pcId = await db
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
      final pc = await getPointConfig(pcId);

      final json = pc.toJson();
      expect(json['points'], 10);
      expect(json['curriculumId'], 'bavli');

      final restored = PointConfig.fromJson(json);
      expect(restored.points, pc.points);
      expect(restored.stageOrder, pc.stageOrder);
    });

    test('copyWith, toColumns, equality, hashCode, toString', () async {
      final accId = await insertAccount(email: 'pc2@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);

      final pcId = await db
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
      final pc1 = await getPointConfig(pcId);
      final pc2 = await getPointConfig(pcId);

      expect(pc1, equals(pc2));
      expect(pc1.hashCode, equals(pc2.hashCode));
      expect(pc1.toString(), contains('5'));

      final copy = pc1.copyWith(points: 20);
      expect(copy.stageOrder, pc1.stageOrder);
      expect(copy.points, 20);

      final cols = pc1.toColumns(true);
      expect(cols['points'], isNotNull);
    });

    test('toCompanion and copyWithCompanion', () async {
      final accId = await insertAccount(email: 'pc3@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);

      final pcId = await db
          .into(db.pointConfigs)
          .insert(
            PointConfigsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              stageOrder: 1,
              points: 15,
            ),
          );
      final pc = await getPointConfig(pcId);

      final companion = pc.toCompanion(true);
      expect(companion.points.value, 15);

      final copy = pc.copyWithCompanion(
        const PointConfigsCompanion(points: Value(25)),
      );
      expect(copy.points, 25);
      expect(copy.curriculumId, pc.curriculumId);
    });

    test('PointConfigsCompanion.copyWith', () {
      const original = PointConfigsCompanion(
        curriculumId: Value('bavli'),
        points: Value(10),
      );
      final copy = original.copyWith(points: const Value(20));
      expect(copy.curriculumId.value, 'bavli');
      expect(copy.points.value, 20);
    });
  });

  // ─── StudyDayConfig DataClass ─────────────────────────────────────────────

  group('StudyDayConfig DataClass', () {
    Future<StudyDayConfig> getStudyDayConfig(
      int profileId,
      int dayOfWeek,
    ) async {
      final rows =
          await (db.select(db.studyDayConfigs)..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.dayOfWeek.equals(dayOfWeek),
              ))
              .get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(email: 'sdc@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);

      await db
          .into(db.studyDayConfigs)
          .insert(
            StudyDayConfigsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              dayOfWeek: 1,
              dayType: const Value('study'),
              updatedAt: now,
            ),
          );
      final sdc = await getStudyDayConfig(profileId, 1);

      final json = sdc.toJson();
      expect(json['dayType'], 'study');
      expect(json['dayOfWeek'], 1);

      final restored = StudyDayConfig.fromJson(json);
      expect(restored.dayType, sdc.dayType);
      expect(restored.curriculumId, sdc.curriculumId);
    });

    test('copyWith, equality, hashCode, toString', () async {
      final accId = await insertAccount(email: 'sdc2@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);

      await db
          .into(db.studyDayConfigs)
          .insert(
            StudyDayConfigsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              dayOfWeek: 5,
              dayType: const Value('rest'),
              updatedAt: now,
            ),
          );
      final sdc1 = await getStudyDayConfig(profileId, 5);
      final sdc2 = await getStudyDayConfig(profileId, 5);

      expect(sdc1, equals(sdc2));
      expect(sdc1.hashCode, equals(sdc2.hashCode));
      expect(sdc1.toString(), contains('rest'));

      final copy = sdc1.copyWith(dayType: 'study');
      expect(copy.dayOfWeek, sdc1.dayOfWeek);
      expect(copy.dayType, 'study');
    });

    test('toCompanion, copyWithCompanion, toColumns', () async {
      final accId = await insertAccount(email: 'sdc3@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);

      await db
          .into(db.studyDayConfigs)
          .insert(
            StudyDayConfigsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              dayOfWeek: 7,
              dayType: const Value('study'),
              updatedAt: now,
            ),
          );
      final sdc = await getStudyDayConfig(profileId, 7);

      final companion = sdc.toCompanion(true);
      expect(companion.dayType.value, 'study');

      final copy = sdc.copyWithCompanion(
        const StudyDayConfigsCompanion(dayType: Value('flex')),
      );
      expect(copy.dayType, 'flex');

      final cols = sdc.toColumns(true);
      expect(cols['day_type'], isNotNull);
    });

    test('StudyDayConfigsCompanion.copyWith', () {
      final original = StudyDayConfigsCompanion(
        dayType: const Value('study'),
        dayOfWeek: const Value(1),
        updatedAt: Value(now),
      );
      final copy = original.copyWith(dayType: const Value('rest'));
      expect(copy.dayOfWeek.value, 1);
      expect(copy.dayType.value, 'rest');
    });
  });

  // ─── Completion DataClass ─────────────────────────────────────────────────

  group('Completion DataClass', () {
    Future<CompletionEvent> getCompletion(int id) async {
      final rows = await (db.select(
        db.completionEvents,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    Future<int> insertCompletion({
      required int profileId,
      required int trackId,
      String ref = 'Berakhot 2a',
      int stageId = 1,
    }) => db
        .into(db.completionEvents)
        .insert(
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: 'bavli',
            sefariaRef: ref,
            stageId: stageId,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: now,
            points: const Value(10),
          ),
        );

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(email: 'c@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);
      final cId = await insertCompletion(
        profileId: profileId,
        trackId: trackId,
        ref: 'Berakhot 5a',
      );
      final c = await getCompletion(cId);

      final json = c.toJson();
      expect(json['sefariaRef'], 'Berakhot 5a');
      expect(json['points'], 10);

      final restored = CompletionEvent.fromJson(json);
      expect(restored.sefariaRef, c.sefariaRef);
      expect(restored.curriculumId, c.curriculumId);
    });

    test('copyWith, equality, hashCode, toString', () async {
      final accId = await insertAccount(email: 'c2@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);
      final cId = await insertCompletion(
        profileId: profileId,
        trackId: trackId,
      );
      final c1 = await getCompletion(cId);
      final c2 = await getCompletion(cId);

      expect(c1, equals(c2));
      expect(c1.hashCode, equals(c2.hashCode));
      expect(c1.toString(), contains('Berakhot 2a'));

      final copy = c1.copyWith(points: 20, sefariaRef: 'Berakhot 3a');
      expect(copy.curriculumId, c1.curriculumId);
      expect(copy.points, 20);
      expect(copy.sefariaRef, 'Berakhot 3a');
    });

    test('toCompanion, copyWithCompanion, toColumns', () async {
      final accId = await insertAccount(email: 'c3@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);
      final cId = await insertCompletion(
        profileId: profileId,
        trackId: trackId,
      );
      final c = await getCompletion(cId);

      final companion = c.toCompanion(true);
      expect(companion.sefariaRef.value, 'Berakhot 2a');

      final copy = c.copyWithCompanion(
        const CompletionEventsCompanion(points: Value(50)),
      );
      expect(copy.points, 50);

      final cols = c.toColumns(true);
      expect(cols['sefaria_ref'], isNotNull);
    });

    test('CompletionEventsCompanion.copyWith', () {
      const original = CompletionEventsCompanion(
        sefariaRef: Value('Berakhot 2a'),
        points: Value(10),
      );
      final copy = original.copyWith(points: const Value(20));
      expect(copy.sefariaRef.value, 'Berakhot 2a');
      expect(copy.points.value, 20);
    });
  });

  // ─── CompletionEvent DataClass ────────────────────────────────────────────

  group('CompletionEvent DataClass', () {
    Future<CompletionEvent> getCompletionEvent(int id) async {
      final rows = await (db.select(
        db.completionEvents,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    Future<int> insertCompletionEvent({
      required int profileId,
      String ref = 'Berakhot 2a',
    }) => db
        .into(db.completionEvents)
        .insert(
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: 'bavli',
            sefariaRef: ref,
            stageId: 1,
            trackType: 'personal',
            eventTimestamp: now,
            createdAt: Value(now),
          ),
        );

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(email: 'ce@test.local');
      final profileId = await insertProfile(accId);
      final ceId = await insertCompletionEvent(
        profileId: profileId,
        ref: 'Shabbat 2a',
      );
      final ce = await getCompletionEvent(ceId);

      final json = ce.toJson();
      expect(json['sefariaRef'], 'Shabbat 2a');
      expect(json['trackType'], 'personal');

      final restored = CompletionEvent.fromJson(json);
      expect(restored.sefariaRef, ce.sefariaRef);
    });

    test('copyWith, equality, hashCode, toString', () async {
      final accId = await insertAccount(email: 'ce2@test.local');
      final profileId = await insertProfile(accId);
      final ceId = await insertCompletionEvent(profileId: profileId);
      final ce1 = await getCompletionEvent(ceId);
      final ce2 = await getCompletionEvent(ceId);

      expect(ce1, equals(ce2));
      expect(ce1.hashCode, equals(ce2.hashCode));
      expect(ce1.toString(), contains('Berakhot 2a'));

      final copy = ce1.copyWith(sefariaRef: 'Berakhot 3a');
      expect(copy.profileId, ce1.profileId);
      expect(copy.sefariaRef, 'Berakhot 3a');
    });

    test('toCompanion, copyWithCompanion, toColumns', () async {
      final accId = await insertAccount(email: 'ce3@test.local');
      final profileId = await insertProfile(accId);
      final ceId = await insertCompletionEvent(profileId: profileId);
      final ce = await getCompletionEvent(ceId);

      final companion = ce.toCompanion(true);
      expect(companion.sefariaRef.value, 'Berakhot 2a');

      final copy = ce.copyWithCompanion(
        const CompletionEventsCompanion(sefariaRef: Value('Eruvin 2a')),
      );
      expect(copy.sefariaRef, 'Eruvin 2a');

      final cols = ce.toColumns(true);
      expect(cols['sefaria_ref'], isNotNull);
    });

    test('CompletionEventsCompanion.copyWith', () {
      const original = CompletionEventsCompanion(
        sefariaRef: Value('Berakhot 2a'),
        stageId: Value(1),
      );
      final copy = original.copyWith(stageId: const Value(2));
      expect(copy.sefariaRef.value, 'Berakhot 2a');
      expect(copy.stageId.value, 2);
    });
  });

  // ─── Bookmark DataClass ───────────────────────────────────────────────────

  group('Bookmark DataClass', () {
    Future<Bookmark> getBookmark(int id) async {
      final rows = await (db.select(
        db.bookmarks,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(email: 'bm@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);

      final bmId = await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot 10a',
              updatedAt: now,
            ),
          );
      final bm = await getBookmark(bmId);

      final json = bm.toJson();
      expect(json['sefariaRef'], 'Berakhot 10a');
      expect(json['curriculumId'], 'bavli');

      final restored = Bookmark.fromJson(json);
      expect(restored.sefariaRef, bm.sefariaRef);
    });

    test('copyWith, equality, hashCode, toString', () async {
      final accId = await insertAccount(email: 'bm2@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);

      final bmId = await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot 20a',
              updatedAt: now,
            ),
          );
      final bm1 = await getBookmark(bmId);
      final bm2 = await getBookmark(bmId);

      expect(bm1, equals(bm2));
      expect(bm1.hashCode, equals(bm2.hashCode));
      expect(bm1.toString(), contains('Berakhot 20a'));

      final copy = bm1.copyWith(sefariaRef: 'Shabbat 5a');
      expect(copy.profileId, bm1.profileId);
      expect(copy.sefariaRef, 'Shabbat 5a');
    });

    test('toCompanion, copyWithCompanion, toColumns', () async {
      final accId = await insertAccount(email: 'bm3@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);

      final bmId = await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot 30a',
              updatedAt: now,
            ),
          );
      final bm = await getBookmark(bmId);

      final companion = bm.toCompanion(true);
      expect(companion.sefariaRef.value, 'Berakhot 30a');

      final copy = bm.copyWithCompanion(
        const BookmarksCompanion(sefariaRef: Value('Eruvin 10a')),
      );
      expect(copy.sefariaRef, 'Eruvin 10a');

      final cols = bm.toColumns(true);
      expect(cols['sefaria_ref'], isNotNull);
    });

    test('BookmarksCompanion.copyWith', () {
      final original = BookmarksCompanion(
        sefariaRef: const Value('Berakhot 2a'),
        updatedAt: Value(now),
      );
      final copy = original.copyWith(sefariaRef: const Value('Shabbat 2a'));
      expect(copy.sefariaRef.value, 'Shabbat 2a');
      expect(copy.updatedAt.value, now);
    });
  });

  // ─── LearningOrderData DataClass ──────────────────────────────────────────

  group('LearningOrderData DataClass', () {
    Future<LearningOrderData> getLearningOrder(int id) async {
      final rows = await (db.select(
        db.learningOrder,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(email: 'lo@test.local');
      final profileId = await insertProfile(accId);

      final loId = await db
          .into(db.learningOrder)
          .insert(
            LearningOrderCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot 2a',
              userSortOrder: 1,
              updatedAt: Value(now),
            ),
          );
      final lo = await getLearningOrder(loId);

      final json = lo.toJson();
      expect(json['sefariaRef'], 'Berakhot 2a');
      expect(json['userSortOrder'], 1);

      final restored = LearningOrderData.fromJson(json);
      expect(restored.sefariaRef, lo.sefariaRef);
    });

    test('copyWith, equality, hashCode, toString', () async {
      final accId = await insertAccount(email: 'lo2@test.local');
      final profileId = await insertProfile(accId);

      final loId = await db
          .into(db.learningOrder)
          .insert(
            LearningOrderCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              sefariaRef: 'Shabbat 2a',
              userSortOrder: 2,
              updatedAt: Value(now),
            ),
          );
      final lo1 = await getLearningOrder(loId);
      final lo2 = await getLearningOrder(loId);

      expect(lo1, equals(lo2));
      expect(lo1.hashCode, equals(lo2.hashCode));
      expect(lo1.toString(), contains('Shabbat 2a'));

      final copy = lo1.copyWith(userSortOrder: 5);
      expect(copy.sefariaRef, lo1.sefariaRef);
      expect(copy.userSortOrder, 5);
    });

    test('toCompanion, copyWithCompanion, toColumns', () async {
      final accId = await insertAccount(email: 'lo3@test.local');
      final profileId = await insertProfile(accId);

      final loId = await db
          .into(db.learningOrder)
          .insert(
            LearningOrderCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              sefariaRef: 'Eruvin 2a',
              userSortOrder: 3,
              updatedAt: Value(now),
            ),
          );
      final lo = await getLearningOrder(loId);

      final companion = lo.toCompanion(true);
      expect(companion.userSortOrder.value, 3);

      final copy = lo.copyWithCompanion(
        const LearningOrderCompanion(userSortOrder: Value(10)),
      );
      expect(copy.userSortOrder, 10);

      final cols = lo.toColumns(true);
      expect(cols['sefaria_ref'], isNotNull);
    });

    test('LearningOrderCompanion.copyWith', () {
      final original = LearningOrderCompanion(
        sefariaRef: const Value('Berakhot 2a'),
        userSortOrder: const Value(1),
        updatedAt: Value(now),
      );
      final copy = original.copyWith(userSortOrder: const Value(5));
      expect(copy.sefariaRef.value, 'Berakhot 2a');
      expect(copy.userSortOrder.value, 5);
    });
  });

  // ─── TrackLearningOrderData DataClass ────────────────────────────────────

  group('TrackLearningOrderData DataClass', () {
    Future<TrackLearningOrderData> getTrackLearningOrder(int id) async {
      final rows = await (db.select(
        db.trackLearningOrder,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(email: 'tlo@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);

      final tloId = await db
          .into(db.trackLearningOrder)
          .insert(
            TrackLearningOrderCompanion.insert(
              trackId: trackId,
              sefariaRef: 'Berakhot 2a',
              sortOrder: 1,
            ),
          );
      final tlo = await getTrackLearningOrder(tloId);

      final json = tlo.toJson();
      expect(json['sefariaRef'], 'Berakhot 2a');
      expect(json['sortOrder'], 1);

      final restored = TrackLearningOrderData.fromJson(json);
      expect(restored.sefariaRef, tlo.sefariaRef);
    });

    test('copyWith, equality, hashCode, toString', () async {
      final accId = await insertAccount(email: 'tlo2@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);

      final tloId = await db
          .into(db.trackLearningOrder)
          .insert(
            TrackLearningOrderCompanion.insert(
              trackId: trackId,
              sefariaRef: 'Shabbat 2a',
              sortOrder: 2,
            ),
          );
      final tlo1 = await getTrackLearningOrder(tloId);
      final tlo2 = await getTrackLearningOrder(tloId);

      expect(tlo1, equals(tlo2));
      expect(tlo1.hashCode, equals(tlo2.hashCode));
      expect(tlo1.toString(), contains('Shabbat 2a'));

      final copy = tlo1.copyWith(sortOrder: 10);
      expect(copy.sefariaRef, tlo1.sefariaRef);
      expect(copy.sortOrder, 10);
    });

    test('toCompanion, copyWithCompanion, toColumns', () async {
      final accId = await insertAccount(email: 'tlo3@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);

      final tloId = await db
          .into(db.trackLearningOrder)
          .insert(
            TrackLearningOrderCompanion.insert(
              trackId: trackId,
              sefariaRef: 'Eruvin 2a',
              sortOrder: 3,
            ),
          );
      final tlo = await getTrackLearningOrder(tloId);

      final companion = tlo.toCompanion(true);
      expect(companion.sortOrder.value, 3);

      final copy = tlo.copyWithCompanion(
        const TrackLearningOrderCompanion(sortOrder: Value(99)),
      );
      expect(copy.sortOrder, 99);

      final cols = tlo.toColumns(true);
      expect(cols['sort_order'], isNotNull);
    });

    test('TrackLearningOrderCompanion.copyWith', () {
      const original = TrackLearningOrderCompanion(
        sefariaRef: Value('Berakhot 2a'),
        sortOrder: Value(1),
      );
      final copy = original.copyWith(sortOrder: const Value(5));
      expect(copy.sefariaRef.value, 'Berakhot 2a');
      expect(copy.sortOrder.value, 5);
    });
  });

  // ─── StreakEvent DataClass ────────────────────────────────────────────────

  group('StreakEvent DataClass', () {
    Future<StreakEvent> getStreakEvent(int id) async {
      final rows = await (db.select(
        db.streakEvents,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(email: 'se@test.local');
      final profileId = await insertProfile(accId);

      final seId = await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profileId,
              eventType: 'completion',
              dayUtc: DateTime.utc(2026, 1, 14),
              eventTimestamp: now,
              createdAt: Value(now),
            ),
          );
      final se = await getStreakEvent(seId);

      final json = se.toJson();
      expect(json['eventType'], 'completion');
      expect(json['clientDeviceId'], isNull);

      final restored = StreakEvent.fromJson(json);
      expect(restored.eventType, se.eventType);
      expect(restored.profileId, se.profileId);
    });

    test('copyWith with nullable clientDeviceId', () async {
      final accId = await insertAccount(email: 'se2@test.local');
      final profileId = await insertProfile(accId);

      final seId = await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profileId,
              eventType: 'day_boundary',
              dayUtc: DateTime.utc(2026, 1, 13),
              eventTimestamp: now,
              createdAt: Value(now),
              clientDeviceId: const Value('device-abc'),
            ),
          );
      final se = await getStreakEvent(seId);

      expect(se.clientDeviceId, 'device-abc');

      final copy = se.copyWith(eventType: 'manual_adjust');
      expect(copy.eventType, 'manual_adjust');
      expect(copy.clientDeviceId, se.clientDeviceId);
    });

    test('toColumns with nullable clientDeviceId', () async {
      final accId = await insertAccount(email: 'se3@test.local');
      final profileId = await insertProfile(accId);

      final seId = await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profileId,
              eventType: 'completion',
              dayUtc: DateTime.utc(2026, 1, 12),
              eventTimestamp: now,
              createdAt: Value(now),
            ),
          );
      final se = await getStreakEvent(seId);

      // nullToAbsent=true, clientDeviceId is null
      final cols = se.toColumns(true);
      expect(cols.containsKey('client_device_id'), isFalse);

      final colsAll = se.toColumns(false);
      expect(colsAll.containsKey('client_device_id'), isTrue);
    });

    test('equality, hashCode, toString, toCompanion', () async {
      final accId = await insertAccount(email: 'se4@test.local');
      final profileId = await insertProfile(accId);

      final seId = await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profileId,
              eventType: 'completion',
              dayUtc: DateTime.utc(2026, 1, 11),
              eventTimestamp: now,
              createdAt: Value(now),
            ),
          );
      final se1 = await getStreakEvent(seId);
      final se2 = await getStreakEvent(seId);

      expect(se1, equals(se2));
      expect(se1.hashCode, equals(se2.hashCode));
      expect(se1.toString(), contains('completion'));

      final companion = se1.toCompanion(true);
      expect(companion.eventType.value, 'completion');
    });

    test('StreakEventsCompanion.copyWith', () {
      final original = StreakEventsCompanion(
        eventType: const Value('completion'),
        dayUtc: Value(DateTime.utc(2026, 1, 14)),
      );
      final copy = original.copyWith(eventType: const Value('day_boundary'));
      expect(copy.eventType.value, 'day_boundary');
      expect(copy.dayUtc.value, DateTime.utc(2026, 1, 14));
    });
  });

  // ─── TextDownloadStatuse DataClass ────────────────────────────────────────

  group('TextDownloadStatuse DataClass', () {
    Future<TextDownloadStatuse> getTextDownloadStatus(
      String curriculumId,
    ) async {
      final rows = await (db.select(
        db.textDownloadStatuses,
      )..where((t) => t.curriculumId.equals(curriculumId))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      await db
          .into(db.textDownloadStatuses)
          .insert(
            TextDownloadStatusesCompanion.insert(
              curriculumId: 'bavli',
              itemCount: 1000,
              textVersion: '2.1.0',
              downloadedAt: now,
            ),
          );
      final tds = await getTextDownloadStatus('bavli');

      final json = tds.toJson();
      expect(json['curriculumId'], 'bavli');
      expect(json['itemCount'], 1000);
      expect(json['storedItemCount'], isNull);

      final restored = TextDownloadStatuse.fromJson(json);
      expect(restored.itemCount, tds.itemCount);
      expect(restored.textVersion, tds.textVersion);
    });

    test('copyWith with nullable storedItemCount', () async {
      await db
          .into(db.textDownloadStatuses)
          .insert(
            TextDownloadStatusesCompanion.insert(
              curriculumId: 'mishnah',
              itemCount: 500,
              textVersion: '1.0.0',
              downloadedAt: now,
              storedItemCount: const Value(250),
            ),
          );
      final tds = await getTextDownloadStatus('mishnah');

      expect(tds.storedItemCount, 250);

      final copy = tds.copyWith(itemCount: 600);
      expect(copy.itemCount, 600);
      expect(copy.storedItemCount, tds.storedItemCount);

      final cleared = tds.copyWith(storedItemCount: const Value(null));
      expect(cleared.storedItemCount, isNull);
    });

    test('toColumns with nullable storedItemCount', () async {
      await db
          .into(db.textDownloadStatuses)
          .insert(
            TextDownloadStatusesCompanion.insert(
              curriculumId: 'yerushalmi',
              itemCount: 200,
              textVersion: '1.2.3',
              downloadedAt: now,
            ),
          );
      final tds = await getTextDownloadStatus('yerushalmi');

      final cols = tds.toColumns(true);
      expect(cols.containsKey('stored_item_count'), isFalse);

      final colsAll = tds.toColumns(false);
      expect(colsAll.containsKey('stored_item_count'), isTrue);
    });

    test(
      'equality, hashCode, toString, toCompanion, copyWithCompanion',
      () async {
        await db
            .into(db.textDownloadStatuses)
            .insert(
              TextDownloadStatusesCompanion.insert(
                curriculumId: 'tanach',
                itemCount: 750,
                textVersion: '3.0.0',
                downloadedAt: now,
              ),
            );
        final tds1 = await getTextDownloadStatus('tanach');
        final tds2 = await getTextDownloadStatus('tanach');

        expect(tds1, equals(tds2));
        expect(tds1.hashCode, equals(tds2.hashCode));
        expect(tds1.toString(), contains('tanach'));

        final companion = tds1.toCompanion(true);
        expect(companion.itemCount.value, 750);

        final copy = tds1.copyWithCompanion(
          const TextDownloadStatusesCompanion(itemCount: Value(900)),
        );
        expect(copy.itemCount, 900);
      },
    );

    test('TextDownloadStatusesCompanion.copyWith', () {
      final original = TextDownloadStatusesCompanion(
        curriculumId: const Value('bavli'),
        itemCount: const Value(100),
        downloadedAt: Value(now),
      );
      final copy = original.copyWith(itemCount: const Value(200));
      expect(copy.curriculumId.value, 'bavli');
      expect(copy.itemCount.value, 200);
    });
  });

  // ─── OutboxData DataClass ─────────────────────────────────────────────────

  group('OutboxData DataClass', () {
    Future<OutboxData> getOutbox(int id) async {
      final rows = await (db.select(
        db.outbox,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(email: 'ob@test.local');
      final profileId = await insertProfile(accId);

      final obId = await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              profileId: profileId,
              entityKind: 'completion',
              entityKey: 'bavli-Berakhot 2a-1',
              payload: '{"ref":"Berakhot 2a"}',
              createdAt: now,
            ),
          );
      final ob = await getOutbox(obId);

      final json = ob.toJson();
      expect(json['entityKind'], 'completion');
      expect(json['attempts'], 0);
      expect(json['lastError'], isNull);
      expect(json['lastAttemptAt'], isNull);

      final restored = OutboxData.fromJson(json);
      expect(restored.entityKind, ob.entityKind);
      expect(restored.entityKey, ob.entityKey);
    });

    test('copyWith with nullable lastError and lastAttemptAt', () async {
      final accId = await insertAccount(email: 'ob2@test.local');
      final profileId = await insertProfile(accId);

      final obId = await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              profileId: profileId,
              entityKind: 'streak',
              entityKey: 'streak-1',
              payload: '{}',
              createdAt: now,
              lastError: const Value('Push failed'),
              lastAttemptAt: Value(now),
            ),
          );
      final ob = await getOutbox(obId);

      expect(ob.lastError, 'Push failed');
      expect(ob.lastAttemptAt, isNotNull);

      final copy = ob.copyWith(attempts: 3);
      expect(copy.attempts, 3);
      expect(copy.lastError, ob.lastError);

      final cleared = ob.copyWith(
        lastError: const Value(null),
        lastAttemptAt: const Value(null),
      );
      expect(cleared.lastError, isNull);
      expect(cleared.lastAttemptAt, isNull);
    });

    test('toColumns with nullable fields', () async {
      final accId = await insertAccount(email: 'ob3@test.local');
      final profileId = await insertProfile(accId);

      final obId = await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              profileId: profileId,
              entityKind: 'settings',
              entityKey: 'settings-1',
              payload: '{}',
              createdAt: now,
            ),
          );
      final ob = await getOutbox(obId);

      final cols = ob.toColumns(true);
      expect(cols.containsKey('last_error'), isFalse);
      expect(cols.containsKey('last_attempt_at'), isFalse);

      final colsAll = ob.toColumns(false);
      expect(colsAll.containsKey('last_error'), isTrue);
      expect(colsAll.containsKey('last_attempt_at'), isTrue);
    });

    test(
      'equality, hashCode, toString, toCompanion, copyWithCompanion',
      () async {
        final accId = await insertAccount(email: 'ob4@test.local');
        final profileId = await insertProfile(accId);

        final obId = await db
            .into(db.outbox)
            .insert(
              OutboxCompanion.insert(
                profileId: profileId,
                entityKind: 'track',
                entityKey: 'track-1',
                payload: '{"trackId":1}',
                createdAt: now,
              ),
            );
        final ob1 = await getOutbox(obId);
        final ob2 = await getOutbox(obId);

        expect(ob1, equals(ob2));
        expect(ob1.hashCode, equals(ob2.hashCode));
        expect(ob1.toString(), contains('track'));

        final companion = ob1.toCompanion(true);
        expect(companion.entityKind.value, 'track');

        final copy = ob1.copyWithCompanion(
          const OutboxCompanion(attempts: Value(2)),
        );
        expect(copy.attempts, 2);
      },
    );

    test('OutboxCompanion.copyWith', () {
      const original = OutboxCompanion(
        entityKind: Value('completion'),
        attempts: Value(0),
      );
      final copy = original.copyWith(attempts: const Value(3));
      expect(copy.entityKind.value, 'completion');
      expect(copy.attempts.value, 3);
    });
  });

  // ─── SacredWindowEntry DataClass ──────────────────────────────────────────

  group('SacredWindowEntry DataClass', () {
    Future<SacredWindowEntry> getSacredWindowEntry(int id) async {
      final rows = await (db.select(
        db.sacredWindowEntries,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final start = DateTime.utc(2026, 3, 27, 18);
      final end = DateTime.utc(2026, 3, 28, 20);

      final sweId = await db
          .into(db.sacredWindowEntries)
          .insert(
            SacredWindowEntriesCompanion.insert(
              startUtc: start,
              endUtc: end,
              kind: 'shabbos',
              inIsrael: true,
              createdAt: Value(now),
            ),
          );
      final swe = await getSacredWindowEntry(sweId);

      final json = swe.toJson();
      expect(json['kind'], 'shabbos');
      expect(json['inIsrael'], isTrue);
      expect(json['lat'], isNull);
      expect(json['lng'], isNull);

      final restored = SacredWindowEntry.fromJson(json);
      expect(restored.kind, swe.kind);
      expect(restored.inIsrael, swe.inIsrael);
    });

    test('copyWith with nullable lat/lng', () async {
      final start = DateTime.utc(2026, 4, 10, 19);
      final end = DateTime.utc(2026, 4, 11, 21);

      final sweId = await db
          .into(db.sacredWindowEntries)
          .insert(
            SacredWindowEntriesCompanion.insert(
              startUtc: start,
              endUtc: end,
              kind: 'yomTov',
              inIsrael: false,
              createdAt: Value(now),
              lat: const Value(51.5),
              lng: const Value(-0.1),
            ),
          );
      final swe = await getSacredWindowEntry(sweId);

      expect(swe.lat, closeTo(51.5, 0.01));
      expect(swe.lng, closeTo(-0.1, 0.01));

      final copy = swe.copyWith(kind: 'shabbosYomTov');
      expect(copy.kind, 'shabbosYomTov');
      expect(copy.lat, swe.lat);

      final cleared = swe.copyWith(
        lat: const Value(null),
        lng: const Value(null),
      );
      expect(cleared.lat, isNull);
      expect(cleared.lng, isNull);
    });

    test('toColumns with nullable lat/lng', () async {
      final start = DateTime.utc(2026, 9, 22, 18);
      final end = DateTime.utc(2026, 9, 23, 19);

      final sweId = await db
          .into(db.sacredWindowEntries)
          .insert(
            SacredWindowEntriesCompanion.insert(
              startUtc: start,
              endUtc: end,
              kind: 'yomKippur',
              inIsrael: true,
              createdAt: Value(now),
            ),
          );
      final swe = await getSacredWindowEntry(sweId);

      // nullToAbsent=true, no lat/lng
      final cols = swe.toColumns(true);
      expect(cols.containsKey('lat'), isFalse);
      expect(cols.containsKey('lng'), isFalse);

      final colsAll = swe.toColumns(false);
      expect(colsAll.containsKey('lat'), isTrue);
      expect(colsAll.containsKey('lng'), isTrue);
    });

    test(
      'equality, hashCode, toString, toCompanion, copyWithCompanion',
      () async {
        final start = DateTime.utc(2026, 2, 6, 17);
        final end = DateTime.utc(2026, 2, 7, 18);

        final sweId = await db
            .into(db.sacredWindowEntries)
            .insert(
              SacredWindowEntriesCompanion.insert(
                startUtc: start,
                endUtc: end,
                kind: 'shabbos',
                inIsrael: false,
                createdAt: Value(now),
              ),
            );
        final swe1 = await getSacredWindowEntry(sweId);
        final swe2 = await getSacredWindowEntry(sweId);

        expect(swe1, equals(swe2));
        expect(swe1.hashCode, equals(swe2.hashCode));
        expect(swe1.toString(), contains('shabbos'));

        final companion = swe1.toCompanion(true);
        expect(companion.kind.value, 'shabbos');
        expect(companion.lat.present, isFalse);

        final copy = swe1.copyWithCompanion(
          const SacredWindowEntriesCompanion(inIsrael: Value(true)),
        );
        expect(copy.inIsrael, isTrue);
      },
    );

    test('SacredWindowEntriesCompanion.copyWith', () {
      final original = SacredWindowEntriesCompanion(
        kind: const Value('shabbos'),
        inIsrael: const Value(true),
        createdAt: Value(now),
      );
      final copy = original.copyWith(inIsrael: const Value(false));
      expect(copy.kind.value, 'shabbos');
      expect(copy.inIsrael.value, isFalse);
    });
  });

  // ─── Managers API for remaining tables ────────────────────────────────────

  group('UserDatabase managers — remaining tables', () {
    test('managers.completions.filter works', () async {
      final accId = await insertAccount(email: 'mgr-c@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);

      await db
          .into(db.completionEvents)
          .insert(
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot 2a',
              stageId: 1,
              trackType: 'personal',
              trackId: Value(trackId),
              eventTimestamp: now,
              points: const Value(10),
            ),
          );

      final rows = await db.managers.completionEvents
          .filter((f) => f.profileId.id(profileId))
          .get();
      expect(rows, hasLength(1));
    });

    test('managers.streakEvents.filter works (snapshot)', () async {
      final accId = await insertAccount(email: 'mgr-str@test.local');
      final profileId = await insertProfile(accId);

      await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profileId,
              eventType: 'completion',
              dayUtc: DateTime.utc(2026, 1, 14),
              eventTimestamp: now,
            ),
          );

      final rows = await db.managers.streakEvents
          .filter((f) => f.eventType('completion'))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.eventType, 'completion');
    });

    test('managers.streakEvents.filter works', () async {
      final accId = await insertAccount(email: 'mgr-se@test.local');
      final profileId = await insertProfile(accId);

      await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profileId,
              eventType: 'completion',
              dayUtc: DateTime.utc(2026, 1, 14),
              eventTimestamp: now,
              createdAt: Value(now),
            ),
          );

      final rows = await db.managers.streakEvents
          .filter((f) => f.profileId.id(profileId))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.eventType, 'completion');
    });

    test('managers.outbox.filter works', () async {
      final accId = await insertAccount(email: 'mgr-ob@test.local');
      final profileId = await insertProfile(accId);

      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              profileId: profileId,
              entityKind: 'completion',
              entityKey: 'k1',
              payload: '{}',
              createdAt: now,
            ),
          );

      final rows = await db.managers.outbox
          .filter((f) => f.profileId(profileId))
          .get();
      expect(rows, hasLength(1));
    });

    test('managers.bookmarks.filter works', () async {
      final accId = await insertAccount(email: 'mgr-bm@test.local');
      final profileId = await insertProfile(accId);
      final trackId = await insertTrack(profileId);

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
      expect(rows.first.sefariaRef, 'Berakhot 5a');
    });

    test('managers.textDownloadStatuses.filter works', () async {
      await db
          .into(db.textDownloadStatuses)
          .insert(
            TextDownloadStatusesCompanion.insert(
              curriculumId: 'mgr-tds',
              itemCount: 100,
              textVersion: '1.0',
              downloadedAt: now,
            ),
          );

      final rows = await db.managers.textDownloadStatuses
          .filter((f) => f.curriculumId('mgr-tds'))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.itemCount, 100);
    });

    test('managers.sacredWindowEntries.filter works', () async {
      final start = DateTime.utc(2026, 1, 9, 17);
      final end = DateTime.utc(2026, 1, 10, 18);

      await db
          .into(db.sacredWindowEntries)
          .insert(
            SacredWindowEntriesCompanion.insert(
              startUtc: start,
              endUtc: end,
              kind: 'shabbos',
              inIsrael: true,
              createdAt: Value(now),
            ),
          );

      final rows = await db.managers.sacredWindowEntries
          .filter((f) => f.kind('shabbos'))
          .get();
      expect(rows, isNotEmpty);
    });
  });
}
